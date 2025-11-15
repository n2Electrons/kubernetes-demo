#!/bin/bash

set -e

echo "Running NGINX Access Tests with pytest..."

# Check if cluster is running
if ! kubectl cluster-info &> /dev/null; then
    echo "Cluster not accessible. Starting cluster..."
    ./scripts/setup-cluster.sh
fi

echo "Cluster is accessible"

# Ensure application is deployed
echo "Ensuring application is deployed..."
./scripts/deploy-app.sh

echo "Waiting for deployment to stabilize..."
kubectl wait --for=condition=available --timeout=60s deployment/kub-app -n kub-app

echo "Checking application accessibility..."
# Test basic connectivity first
if curl -s -H "Host: kub-app.local" http://localhost:8080 > /dev/null; then
    echo "Application is accessible"
else
    echo "Application not accessible, waiting longer..."
    sleep 10
fi

echo "Running NGINX access and performance tests..."
cd "$(dirname "$0")/.."
python3 -m pytest test/t3-nginx-access.py -v

echo "NGINX access test execution complete!"