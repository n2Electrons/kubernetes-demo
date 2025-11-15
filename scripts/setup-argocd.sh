#!/bin/bash

set -e

echo "=== Installing Argo CD for GitOps Workflow ==="
echo

# Check if cluster is running
if ! kubectl cluster-info &> /dev/null; then
    echo "Error: Cluster not accessible. Run ./scripts/setup-cluster.sh first"
    exit 1
fi

echo "Cluster is accessible"

# Create argocd namespace
echo "Creating argocd namespace..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Install Argo CD
echo "Installing Argo CD..."
echo "Choose installation type:"
echo "1) Core components only (CLI/kubectl management)"
echo "2) Full installation with UI server"
echo ""

# For automation, default to core unless UI is specifically requested
if [ "$1" = "--with-ui" ]; then
    echo "Installing full Argo CD with UI server..."
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    UI_ENABLED=true
else
    echo "Installing Argo CD (core components only)..."
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/core-install.yaml
    UI_ENABLED=false
fi

# Wait for Argo CD to be ready
echo "Waiting for Argo CD components to be ready..."
echo "This may take a few minutes..."

if [ "$UI_ENABLED" = true ]; then
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-applicationset-controller -n argocd
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-repo-server -n argocd
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-dex-server -n argocd
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-redis -n argocd
else
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-applicationset-controller -n argocd
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-repo-server -n argocd
    kubectl wait --for=condition=ready --timeout=300s pod -l app.kubernetes.io/name=argocd-application-controller -n argocd
fi

echo "Argo CD installation complete!"

# Apply project configuration
echo "Applying Argo CD project configuration..."
kubectl apply -f argocd/projects/kubernetes-demo.yaml

# Apply application configuration  
echo "Applying kub-app application configuration..."
kubectl apply -f argocd/applications/kub-app.yaml

# Get initial admin password
echo ""
echo "Getting initial admin password..."
sleep 10  # Wait for secret to be created
ARGO_PWD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null || echo "Password not ready yet")

echo ""
echo "=== Argo CD Setup Complete ==="
echo ""
echo "🚀 Argo CD is now running!"
echo ""
if [ "$UI_ENABLED" = true ]; then
    echo "📋 Access Information:"
    echo "   Argo CD UI: https://localhost:8080"
    echo "   Username: admin"
    if [ "$ARGO_PWD" != "Password not ready yet" ]; then
        echo "   Password: $ARGO_PWD"
    else
        echo "   Password: Run 'kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d' to get password"
    fi
    echo ""
    echo "🔧 To access the Argo CD UI:"
    echo "   1. Run: kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo "   2. Open: https://localhost:8080"
    echo "   3. Accept the self-signed certificate warning"
    echo "   4. Login with admin credentials above"
    echo ""
else
    echo "📋 Access Information:"
    echo "   Argo CD CLI: Use 'kubectl' commands directly"
    echo "   Username: admin"
    if [ "$ARGO_PWD" != "Password not ready yet" ]; then
        echo "   Password: $ARGO_PWD"
    else
        echo "   Password: Run 'kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d' to get password"
    fi
    echo ""
    echo "🔧 Core installation notes:"
    echo "   - This is the core Argo CD installation (no UI server)"
    echo "   - Use 'kubectl' commands for management"
    echo "   - To install UI later: ./scripts/setup-argocd.sh --with-ui"
    echo ""
fi
echo "📱 GitOps Application:"
echo "   Application: kub-app"
echo "   Repository: https://github.com/n2Electrons/kubernetes-demo.git"
echo "   Path: apps/kub-app"
echo "   Sync Policy: Automated (self-healing enabled)"
echo ""
echo "🔄 The kub-app application will be automatically synced from Git!"
echo "   Any changes to apps/kub-app/ will be automatically deployed."
echo ""
echo "💡 Useful commands:"
echo "   kubectl get applications -n argocd"
echo "   kubectl get appprojects -n argocd" 
echo "   kubectl logs -f deployment/argocd-application-controller -n argocd"