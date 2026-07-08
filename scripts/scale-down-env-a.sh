#!/usr/bin/env bash
set -euo pipefail

echo "Scaling down env-a only..."
kubectl scale deployment hello-app -n env-a --replicas=0

echo ""
echo "Checking other environments are unaffected:"
for ns in env-b env-c env-d customer-uat; do
  echo "  $ns:"
  kubectl get pods -n "$ns" 2>/dev/null || true
done

echo ""
echo "env-a scaled down."
