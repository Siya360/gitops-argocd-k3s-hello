#!/usr/bin/env bash
set -euo pipefail

echo "Scaling up all test environments in safe order..."
echo "  1. env-d (first)"
kubectl scale deployment hello-app -n env-d --replicas=1
kubectl rollout status deployment/hello-app -n env-d --timeout=120s

echo ""
echo "  2. env-a, env-b, env-c, customer-uat"
kubectl scale deployment hello-app -n env-a --replicas=1
kubectl scale deployment hello-app -n env-b --replicas=1
kubectl scale deployment hello-app -n env-c --replicas=1
kubectl scale deployment hello-app -n customer-uat --replicas=1

echo ""
for ns in env-a env-b env-c customer-uat; do
  kubectl rollout status deployment/hello-app -n "$ns" --timeout=120s
done

echo ""
echo "All test environments are up."
