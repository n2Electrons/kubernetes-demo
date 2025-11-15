#!/bin/bash
# Test runner for Milestone 2: Multi-node Application Deployment

set -e

echo "Running Milestone 2 Multi-node Application Tests with pytest..."

# Ensure cluster is running
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo "Cluster is not accessible. Attempting to start cluster..."
    
    # Check if cluster exists but is stopped
    if k3d cluster list | grep -q "kub-demo.*stopped"; then
        echo "Starting existing cluster..."
        k3d cluster start kub-demo
        sleep 5
    else
        echo "No cluster found. Creating new cluster..."
        ./scripts/setup-cluster.sh
    fi
    
    # Verify cluster is now accessible
    if ! kubectl cluster-info >/dev/null 2>&1; then
        echo "[ERROR] Failed to start or create cluster"
        exit 1
    fi
    
    echo "Cluster is now running"
else
    echo "Cluster is accessible"
fi

# Deploy application
echo "Deploying application for testing..."
./scripts/deploy-app.sh

# Wait for deployment to be ready
echo "Waiting for deployment to stabilize..."
kubectl wait --for=condition=available deployment/kub-app -n kub-app --timeout=120s

# Check if pytest is installed
if ! command -v pytest &> /dev/null; then
    echo "Installing pytest..."
    pip3 install pytest
fi

# Run pytest test suite
echo "Running multi-node deployment tests..."
pytest test/t2-multi-node.py -v

echo "Multi-node test execution complete!"