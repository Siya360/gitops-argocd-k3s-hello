#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

echo "Demo GitOps change: updating env-a greeting message..."

# Update the greeting in the configmap
sed -i '' 's/GREETING_MESSAGE: "Hello from env-a. I depend on env-d."/GREETING_MESSAGE: "Hello from env-a. GitOps config change demo applied!"/' environments/env-a/configmap.yaml

echo ""
echo "--- git diff ---"
git diff environments/env-a/configmap.yaml || true

echo ""
echo "--- Committing and pushing ---"
git add environments/env-a/configmap.yaml
git commit -m "Demo GitOps config change for env-a"
git push origin feature/bancx-gitops-simulation

echo ""
echo "=== Change pushed ==="
echo "Next steps:"
echo "  argocd app get env-a"
echo "  argocd app sync env-a"
echo "  kubectl rollout status deployment/hello-app -n env-a"
echo "  kubectl port-forward svc/hello-app -n env-a 8083:80"
echo "  curl http://localhost:8083"
