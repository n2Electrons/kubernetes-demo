#!/bin/bash
# Cleanup k3d cluster

set -e

CLUSTER_NAME="kub-demo"

echo "Deleting k3d cluster: $CLUSTER_NAME"
k3d cluster delete $CLUSTER_NAME

echo "Cluster deleted successfully!"