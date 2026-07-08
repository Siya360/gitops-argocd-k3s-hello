#!/usr/bin/env bash
set -euo pipefail

echo "Forwarding Argo CD UI to https://localhost:8080"
echo "Press Ctrl+C to stop."
kubectl port-forward svc/argocd-server -n argocd 8080:443
