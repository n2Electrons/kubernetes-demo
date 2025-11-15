#!/bin/bash
# Test runner for Milestone 1: Base Infrastructure

set -e

echo "Running Milestone 1 Infrastructure Tests with pytest..."

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

# Create namespace...
echo "Setting up test environment..."
./scripts/deploy-app.sh

# Run pytest test suite
echo "Running pytest test suite..."
pytest test/t1-infrastructure.py -v

echo "Test execution complete!"