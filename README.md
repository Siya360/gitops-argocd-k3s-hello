# GitOps Argo CD K3s Hello

A lightweight local GitOps demo using **k3d** (K3s in Docker), **Argo CD**, and a simple Node.js **Hello** application.

## Overview

This project demonstrates a complete GitOps workflow on your local machine:

1. A local K3s cluster runs inside Docker via **k3d**.
2. **Argo CD** is installed inside the cluster and watches a GitHub repository.
3. The repository contains Kubernetes manifests for a simple Hello app.
4. Argo CD automatically deploys the app into the cluster.
5. The Hello app is accessible locally through your browser or `curl`.

## Architecture

```
┌──────────────┐
│   GitHub     │  ← Source of truth (K8s manifests)
│   (repo)     │
└──────┬───────┘
       │  pull
       ▼
┌──────────────┐
│   Argo CD    │  ← GitOps controller (inside K3s)
│   (argocd)   │
└──────┬───────┘
       │  sync
       ▼
┌──────────────┐
│   K3s / k3d  │  ← Local Kubernetes cluster (inside Docker)
│  (gitops-local)
└──────┬───────┘
       │  port-forward
       ▼
┌──────────────┐
│  Hello App   │  ← Node.js app on localhost:8082
│ (hello-gitops)
└──────────────┘
```

## Local Prerequisites

- Docker Desktop for Mac (running)
- Homebrew
- git
- GitHub CLI (`gh`)
- kubectl
- k3d
- argocd CLI

Install missing tools via Homebrew:

```bash
brew install k3d kubectl argocd gh
```

## Repository Structure

```
gitops-argocd-k3s-hello/
├── README.md
├── .gitignore
├── app/
│   ├── Dockerfile
│   ├── package.json
│   └── server.js
├── k8s/
│   ├── namespace.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
└── argocd/
    └── application.yaml
```

## Create the k3d Cluster

```bash
k3d cluster create gitops-local \
  --servers 1 \
  --agents 0 \
  --port "8081:80@loadbalancer"
```

Confirm context and nodes:

```bash
kubectl config current-context
kubectl get nodes
```

## Build and Import the Local Docker Image

```bash
docker build -t gitops-hello:local ./app
k3d image import gitops-hello:local -c gitops-local
```

## Install Argo CD

```bash
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply --server-side=true --force-conflicts -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Wait for core components:

```bash
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
kubectl wait --for=condition=available --timeout=300s deployment/argocd-repo-server -n argocd
kubectl wait --for=condition=ready --timeout=300s pod -l app.kubernetes.io/name=argocd-application-controller -n argocd
```

## Access Argo CD Locally

Port-forward the Argo CD UI:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Open: **https://localhost:8080**

Retrieve the initial admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

Log in via CLI:

```bash
argocd login localhost:8080 --username admin --password <INITIAL_PASSWORD> --insecure
```

## Deploy Using Argo CD

Apply the Argo CD Application manifest:

```bash
kubectl apply -f argocd/application.yaml
```

Sync and wait:

```bash
argocd app sync hello-gitops
argocd app wait hello-gitops --health --sync --timeout 180
```

## Access the Hello App Locally

Port-forward the app service:

```bash
kubectl port-forward svc/hello-app -n hello-gitops 8082:80
```

Open: **http://localhost:8082**

Or verify with curl:

```bash
curl http://localhost:8082
```

## Useful Commands

| Action | Command |
|--------|---------|
| View Argo CD UI | `kubectl port-forward svc/argocd-server -n argocd 8080:443` → https://localhost:8080 |
| View Hello app | `kubectl port-forward svc/hello-app -n hello-gitops 8082:80` → http://localhost:8082 |
| Check Argo CD app | `argocd app get hello-gitops` |
| Sync app manually | `argocd app sync hello-gitops` |
| Check K8s resources | `kubectl get all -n hello-gitops` |
| Check all pods | `kubectl get pods -A` |

## Troubleshooting

### Argo CD pods not starting

```bash
kubectl get pods -n argocd
kubectl describe pod -n argocd <pod-name>
kubectl logs -n argocd <pod-name>
```

### Hello app image not found

Ensure the image was imported into k3d after building:

```bash
docker build -t gitops-hello:local ./app
k3d image import gitops-hello:local -c gitops-local
kubectl rollout restart deployment/hello-app -n hello-gitops
```

### Argo CD cannot pull from GitHub

If the repo is private, make it public for this demo, or configure Argo CD repository credentials securely.

### Port-forward issues

If a port is already in use, find and stop existing processes:

```bash
lsof -i :8080
lsof -i :8082
```

## Cleanup

Remove the Argo CD Application:

```bash
kubectl delete -f argocd/application.yaml || true
```

Delete the k3d cluster:

```bash
k3d cluster delete gitops-local
```

Remove the local Docker image:

```bash
docker image rm gitops-hello:local || true
```
