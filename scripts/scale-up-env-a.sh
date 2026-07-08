#!/usr/bin/env bash
set -euo pipefail

echo "Scaling up env-a..."
kubectl scale deployment hello-app -n env-a --replicas=1
kubectl rollout status deployment/hello-app -n env-a --timeout=120s

echo ""
echo "env-a is back up."
