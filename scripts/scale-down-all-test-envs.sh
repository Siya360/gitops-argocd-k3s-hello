#!/usr/bin/env bash
set -euo pipefail

echo "Scaling down all test environments in safe order..."
echo "  1. env-a"
kubectl scale deployment hello-app -n env-a --replicas=0
echo "  2. env-b"
kubectl scale deployment hello-app -n env-b --replicas=0
echo "  3. env-c"
kubectl scale deployment hello-app -n env-c --replicas=0
echo "  4. customer-uat"
kubectl scale deployment hello-app -n customer-uat --replicas=0
echo "  5. env-d (last)"
kubectl scale deployment hello-app -n env-d --replicas=0

echo ""
echo "All test environments scaled down."
