# GitOps Argo CD K3s Hello — BancX DevOps Assessment Simulation

A lightweight local GitOps demo that simulates the BancX DevOps assessment scenario using **k3d** (K3s in Docker), **Argo CD**, and a simple Node.js **Hello** application.

## Overview

This project demonstrates a complete GitOps workflow on your local machine, mapped to a real-world DevOps assessment scenario:

- **Four test environments** (A, B, C, D) running on a single Kubernetes test cluster.
- **Env D** acts as a shared dependency that A, B, and C depend on.
- **Customer UAT** (simulated as a namespace) also needs access to env D.
- **Shared platform services** (Argo CD, automation) run alongside the test environments.
- **Scheduled shutdown/startup** is implemented via Kubernetes CronJobs.
- **Independent scaling** of any single environment without affecting others.
- **GitOps** is the single source of truth: Argo CD watches GitHub and syncs the cluster automatically.

## What the Demo Proves

| Requirement | Demo Implementation |
|-------------|---------------------|
| GitOps with Argo CD | App-of-apps model watching GitHub `feature/bancx-gitops-simulation` |
| Namespace isolation | Each environment is a dedicated namespace |
| Env D as shared dependency | `env-d` namespace hosts the shared service; others reach it via cluster DNS |
| A/B/C dependency on D | Readiness probes in A/B/C call `env-d/healthz`; fail if unreachable |
| Customer UAT needs D | `customer-uat` namespace configured with same dependency URL |
| Shared platform services | `argocd` and `automation` namespaces |
| Scheduled shutdown/startup | Kubernetes CronJobs with explicit ordering |
| Independent scaling | `kubectl scale deployment` per namespace; Argo CD self-heal restores Git-defined state |
| Safety | NetworkPolicy, ResourceQuota, LimitRange, and sync-wave ordering |

## Architecture

```
Local k3d/K3s cluster (gitops-local)
├── argocd namespace
│   └── Argo CD + app-of-apps (bancx-gitops-demo)
├── automation namespace
│   ├── env-scheduler ServiceAccount + RBAC
│   └── CronJobs: start-env-d, start-dependent-envs,
│                  stop-dependent-envs, stop-env-d
├── env-d namespace
│   └── hello-app (shared dependency)
├── env-a namespace ──┐
├── env-b namespace ──┼──> env-d (via cluster DNS + readiness)
├── env-c namespace ──┘
└── customer-uat namespace ──> env-d
```

## GitOps Layout

```
.
├── app/                          # Node.js application source
│   ├── Dockerfile
│   ├── package.json
│   └── server.js
├── apps/hello/base/              # Reusable Kustomize base
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
├── environments/                 # Per-environment Kustomize overlays
│   ├── env-a/
│   ├── env-b/
│   ├── env-c/
│   ├── env-d/
│   └── customer-uat/
├── policies/                     # Platform policies
│   ├── resourcequota.yaml
│   ├── limitrange.yaml
│   ├── env-d-networkpolicy.yaml
│   └── kustomization.yaml
├── automation/                   # Scheduled start/stop CronJobs
│   ├── namespace.yaml
│   ├── rbac.yaml
│   ├── start-env-d.yaml
│   ├── start-dependent-envs.yaml
│   ├── stop-dependent-envs.yaml
│   ├── stop-env-d.yaml
│   └── kustomization.yaml
├── argocd/                       # Argo CD app-of-apps
│   ├── root-application.yaml
│   └── apps/
│       ├── env-d.yaml
│       ├── env-a.yaml
│       ├── env-b.yaml
│       ├── env-c.yaml
│       ├── customer-uat.yaml
│       ├── policies.yaml
│       └── automation.yaml
├── scripts/                      # Demo & verification scripts
│   ├── verify.sh
│   ├── scale-down-env-a.sh
│   ├── scale-up-env-a.sh
│   ├── scale-down-all-test-envs.sh
│   ├── scale-up-all-test-envs.sh
│   ├── port-forward-argocd.sh
│   └── demo-gitops-change.sh
├── k8s/                          # Original simple demo manifests (kept for reference)
├── README.md
└── .gitignore
```

## Local Prerequisites

- Docker Desktop for Mac (running)
- Homebrew
- git
- GitHub CLI (`gh`) — authenticated
- kubectl
- k3d
- argocd CLI

Install missing tools:

```bash
brew install k3d kubectl argocd gh
```

## How to Deploy

### 1. Build the local image

```bash
docker build -t gitops-hello:local ./app
k3d image import gitops-hello:local -c gitops-local
```

> **Note:** Because the image is local-only, source code changes to `app/server.js` require rebuilding and re-importing. See the section **Next maturity step: CI image build and registry** below.

### 2. Apply the Argo CD root application

```bash
kubectl apply -f argocd/root-application.yaml
```

This creates the **app-of-apps** (`bancx-gitops-demo`), which in turn manages all child apps.

### 3. Sync via Argo CD CLI

```bash
argocd login localhost:8080 --username admin --password $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d) --insecure
argocd app sync bancx-gitops-demo
```

Or sync individual apps:

```bash
argocd app sync env-d
argocd app sync env-a env-b env-c customer-uat policies automation
```

## How to Verify

```bash
./scripts/verify.sh
```

This checks:
- Kubernetes nodes
- All Argo CD applications
- Pods in every environment
- Dependency reachability from A/B/C and customer-uat to env-d

Additional commands:

```bash
kubectl get applications -n argocd
kubectl get pods -A
```

## How to Prove Independent Scaling

Scale down **only env-a**:

```bash
./scripts/scale-down-env-a.sh
```

Verify env-b, env-c, env-d, and customer-uat are unaffected.

Scale env-a back up:

```bash
./scripts/scale-up-env-a.sh
```

> **Note:** Argo CD has `selfHeal: true`. If you scale a deployment manually, Argo CD will eventually restore it to the Git-defined replica count (`replicas: 1`). This is desired GitOps behavior. To intentionally leave an environment scaled down, temporarily disable auto-sync for that Application in Argo CD.

## How to Prove Env-D Dependency

Argo CD self-healing makes it hard to manually break env-d. Instead, you can demonstrate dependency logic inside the app:

```bash
# From env-a pod, test dependency reachability
kubectl exec -n env-a deployment/hello-app -- wget -qO- http://hello-app.env-d.svc.cluster.local/dependency-check
```

Or inspect readiness:

```bash
kubectl get pods -n env-a
kubectl describe pod -n env-a <pod-name>
```

The readiness probe in env-a/env-b/env-c/customer-uat calls `env-d/healthz`. If env-d becomes unreachable, the readiness probe returns 503 and Kubernetes removes the pod from the Service endpoints.

## How to Prove GitOps Sync from SCM

Run the demo script:

```bash
./scripts/demo-gitops-change.sh
```

This updates `environments/env-a/configmap.yaml`, commits, and pushes to GitHub.

Then watch Argo CD detect and sync:

```bash
argocd app get env-a
argocd app sync env-a
```

Restart the deployment so the new ConfigMap is picked up:

```bash
kubectl rollout restart deployment hello-app -n env-a
kubectl rollout status deployment hello-app -n env-a --timeout=120s
```

Port-forward and verify:

```bash
kubectl port-forward svc/hello-app -n env-a 8083:80
curl http://localhost:8083
```

The response should show the updated greeting message.

## Scheduled Automation

The `automation/` folder contains CronJobs that simulate working-hours scheduling.

| CronJob | Schedule | Action |
|---------|----------|--------|
| `start-env-d` | `30 6 * * 1-5` | Scale env-d to 1 replica |
| `start-dependent-envs` | `45 6 * * 1-5` | Wait for env-d, then scale A/B/C/customer-uat to 1 |
| `stop-dependent-envs` | `0 18 * * 1-5` | Scale A/B/C/customer-uat to 0 |
| `stop-env-d` | `15 18 * * 1-5` | Scale env-d to 0 |

> **Timezone:** `Africa/Johannesburg` (adjust to your needs).

This proves:
- **Env D starts first** and **stops last**.
- Dependent environments start after D is available and stop before D shuts down.

> **Production note:** Kubernetes CronJobs are a lightweight proof-of-concept. For production, prefer a declarative controller like **kube-downscaler**, **KEDA Cron Scalers**, or an external scheduler integrated with your cluster. CronJobs can become brittle and require broad RBAC permissions.

## Access Argo CD Locally

```bash
./scripts/port-forward-argocd.sh
```

Open: **https://localhost:8080**

Accept the self-signed certificate warning, then log in with:

| Username | `admin` |
| Password | Retrieved via `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" \| base64 -d` |

## Limitations of This Local Demo

1. **Single cluster:** Customer UAT is simulated as a namespace, not a separate cluster.
2. **NetworkPolicy enforcement:** K3s with Flannel does not enforce NetworkPolicies by default. The manifest is included as a design artifact, but in production you must validate it against your CNI (e.g., Calico, Cilium) or enforce rules at a gateway/firewall layer.
3. **CronJobs vs production scheduler:** CronJobs are acceptable for local demos but are not the enterprise recommendation for scheduled scaling.
4. **Local image lifecycle:** The `gitops-hello:local` image is built and imported manually. In production, use a CI pipeline (GitHub Actions) to build, tag, and push to a registry (GHCR, ACR, ECR), then update image tags in manifests.
5. **ConfigMap rolling updates:** Updating a ConfigMap referenced via `envFrom` does **not** automatically restart pods. A `rollout restart` or an operator (e.g., Reloader) is needed. This is standard Kubernetes behavior.
6. **Dependency readiness:** The readiness probe checks env-d reachability. If env-d is scaled to 0, the probe fails. However, Argo CD `selfHeal` will restore env-d to `replicas: 1`, making it hard to keep env-d down for extended testing without disabling auto-sync.

## Mapping to BancX Assessment

| BancX Requirement | Demo Implementation |
|-------------------|---------------------|
| Four test environments | `env-a`, `env-b`, `env-c`, `env-d` namespaces |
| A/B/C depend on D | Readiness probes call `env-d`; ConfigMap sets `DEPENDENCY_URL` |
| Customer UAT needs D | `customer-uat` namespace with same dependency config |
| Shared platform services | `argocd` and `automation` namespaces |
| Scheduled shutdown/startup | Kubernetes CronJobs with explicit ordering |
| Independent scaling | Per-namespace deployments; manual scale scripts |
| GitOps | Argo CD app-of-apps + GitHub repo |
| Safety | NetworkPolicy, ResourceQuota, LimitRange, sync waves, D readiness |

## Next Maturity Step: CI Image Build and Registry

In a production-like flow, you should not rely on local image imports. The recommended pipeline:

1. Developer pushes code to GitHub.
2. **GitHub Actions** builds the Docker image.
3. Image is pushed to **GHCR** (or Azure Container Registry, ECR, etc.).
4. A follow-up step (or separate pipeline) updates the image tag in `apps/hello/base/deployment.yaml`.
5. Argo CD detects the manifest change and syncs the new image.

A draft workflow is included in `.github/workflows/build-and-update-image.yaml` as a starting point. It is **optional** and does not need to be enabled for the local demo to work.

## Cleanup

Remove the BancX demo applications:

```bash
kubectl delete -f argocd/root-application.yaml || true
```

Delete the cluster:

```bash
k3d cluster delete gitops-local
```

Remove the local image:

```bash
docker image rm gitops-hello:local || true
```

## Useful Commands Quick Reference

| Action | Command |
|--------|---------|
| View Argo CD UI | `kubectl port-forward svc/argocd-server -n argocd 8080:443` → https://localhost:8080 |
| Port-forward env-d | `kubectl port-forward svc/hello-app -n env-d 8084:80` → http://localhost:8084 |
| Port-forward env-a | `kubectl port-forward svc/hello-app -n env-a 8083:80` → http://localhost:8083 |
| Verify everything | `./scripts/verify.sh` |
| Scale down env-a only | `./scripts/scale-down-env-a.sh` |
| Scale up env-a | `./scripts/scale-up-env-a.sh` |
| Scale all down safely | `./scripts/scale-down-all-test-envs.sh` |
| Scale all up safely | `./scripts/scale-up-all-test-envs.sh` |
| Demo GitOps change | `./scripts/demo-gitops-change.sh` |
| Argo CD app status | `argocd app get env-a` |
| Argo CD sync app | `argocd app sync env-a` |
| Restart deployment | `kubectl rollout restart deployment hello-app -n env-a` |
