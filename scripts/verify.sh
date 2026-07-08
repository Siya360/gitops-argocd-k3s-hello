#!/usr/bin/env bash
set -euo pipefail

echo "=== BancX GitOps Environment Verification ==="
echo ""

echo "--- Kubernetes Nodes ---"
kubectl get nodes
echo ""

echo "--- Argo CD Applications ---"
kubectl get applications -n argocd
echo ""

echo "--- Pods per Environment ---"
for ns in env-d env-a env-b env-c customer-uat; do
  echo "Namespace: $ns"
  kubectl get pods -n "$ns" 2>/dev/null || echo "  (no pods or namespace not ready)"
  echo ""
done

echo "--- Hello App Services ---"
kubectl get svc -A | grep hello-app || true
echo ""

echo "=== Dependency Reachability Tests ==="
for src in env-a env-b env-c customer-uat; do
  echo "--- Testing $src -> env-d ---"
  kubectl run "curl-test-$src" --rm -i --restart=Never \
    --image=curlimages/curl:latest -n "$src" \
    -- curl -s -o /dev/null -w "%{http_code}" http://hello-app.env-d.svc.cluster.local/healthz \
    2>/dev/null || echo "Test from $src failed"
  echo ""
done

echo "=== Verification Complete ==="
