#!/bin/bash
# Deploy applications to the cluster

set -e

echo "Creating application namespaces..."

# Apply namespace first
kubectl apply -f apps/kub-app/namespace.yaml

echo "Namespace created successfully!"
