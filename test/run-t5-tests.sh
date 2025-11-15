#!/bin/bash

set -e

echo "=== Running Argo CD GitOps Tests ==="
echo

# Check if cluster is running
if ! kubectl cluster-info &> /dev/null; then
    echo "Error: Cluster not accessible. Run ./scripts/setup-cluster.sh first"
    exit 1
fi

echo "Cluster is accessible"

# Check if Argo CD is installed
if ! kubectl get namespace argocd &> /dev/null; then
    echo "Error: Argo CD not installed. Run ./scripts/setup-argocd.sh first"
    exit 1
fi

echo "Argo CD namespace found"

# Ensure Argo CD is ready
echo "Checking Argo CD readiness..."
kubectl wait --for=condition=available --timeout=60s deployment/argocd-applicationset-controller -n argocd > /dev/null
kubectl wait --for=condition=ready --timeout=60s pod -l app.kubernetes.io/name=argocd-application-controller -n argocd > /dev/null

echo "Running Argo CD GitOps tests with pytest..."

# Change to project root to run tests
cd "$(dirname "$0")/.."

python3 -m pytest test/t5-argocd-tests.py -v --tb=short

echo
echo "=== Argo CD GitOps Tests Complete ==="
echo 
echo "📋 Current GitOps Status:"

echo "  Applications:"
kubectl get applications -n argocd 2>/dev/null || echo "    No applications found"

echo "  Projects:"  
kubectl get appprojects -n argocd 2>/dev/null || echo "    No projects found"

echo "  Argo CD Pods:"
kubectl get pods -n argocd | grep -E "(NAME|argocd-)" || echo "    No Argo CD pods found"

echo
echo "🔧 To access Argo CD UI:"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  Then open: https://localhost:8080"
echo
echo "🔑 To get admin password:"
echo "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo