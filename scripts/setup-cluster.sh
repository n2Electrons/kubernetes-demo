#!/bin/bash
# Setup k3d cluster with 1 server + 2 workers as per Phase 2

set -e

CLUSTER_NAME="kub-demo"
PORT_MAPPING="8080:80@loadbalancer"

echo "Creating k3d cluster: $CLUSTER_NAME"
k3d cluster create $CLUSTER_NAME --servers 1 --agents 2 -p "$PORT_MAPPING"

echo "Waiting for cluster to be ready..."
kubectl wait --for=condition=Ready node --all --timeout=300s

echo "Cluster nodes:"
kubectl get nodes -o wide

echo "Cluster ready! Access your apps at: http://localhost:8080"
