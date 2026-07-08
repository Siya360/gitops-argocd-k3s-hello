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
  pod=$(kubectl get pods -n "$src" -l app=hello-app -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  if [ -n "$pod" ]; then
    code=$(kubectl exec -n "$src" "$pod" -- wget -qO- http://hello-app.env-d.svc.cluster.local/healthz 2>/dev/null && echo "200" || echo "fail")
    echo "  Result: $code"
  else
    echo "  No pod found in $src"
  fi
  echo ""
done

echo "=== Verification Complete ==="
