#!/bin/bash

# Setup Monitoring Stack
# This script deploys Prometheus, Grafana, AlertManager, Jaeger, and Fluent Bit

set -e

echo "Setting up Monitoring Stack..."

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl first."
    exit 1
fi

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Cannot access Kubernetes cluster. Please ensure cluster is running."
    exit 1
fi

echo "Deploying monitoring components..."

# Create monitoring namespace and deploy components
kubectl apply -f apps/monitoring/namespace.yaml
echo "Monitoring namespace created"

# Deploy Prometheus stack
kubectl apply -f apps/monitoring/prometheus-config.yaml
kubectl apply -f apps/monitoring/prometheus.yaml
echo "Prometheus deployed"

# Deploy Grafana
kubectl apply -f apps/monitoring/grafana-config.yaml
kubectl apply -f apps/monitoring/grafana.yaml
echo "Grafana deployed"

# Deploy AlertManager
kubectl apply -f apps/monitoring/alertmanager-config.yaml
kubectl apply -f apps/monitoring/alertmanager.yaml
echo "AlertManager deployed"

# Deploy Jaeger
kubectl apply -f apps/monitoring/jaeger.yaml
echo "Jaeger deployed"

# Deploy Fluent Bit
kubectl apply -f apps/monitoring/fluent-bit-config.yaml
kubectl apply -f apps/monitoring/fluent-bit.yaml
echo "Fluent Bit deployed"

echo "Waiting for deployments to be ready..."

# Wait for deployments to be available
kubectl wait --for=condition=available --timeout=300s deployment/prometheus -n monitoring
kubectl wait --for=condition=available --timeout=300s deployment/grafana -n monitoring
kubectl wait --for=condition=available --timeout=300s deployment/alertmanager -n monitoring
kubectl wait --for=condition=available --timeout=300s deployment/jaeger -n monitoring

# Wait for DaemonSet to be ready
kubectl rollout status daemonset/fluent-bit -n monitoring --timeout=300s

echo ""
echo "Monitoring Stack deployed successfully!"
echo ""
echo "Access Services:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Grafana:      http://grafana.local:8080 (admin/admin123)"
echo "Prometheus:   kubectl port-forward svc/prometheus 9090:9090 -n monitoring"
echo "Jaeger:       http://jaeger.local:8080"
echo "AlertManager: kubectl port-forward svc/alertmanager 9093:9093 -n monitoring"
echo ""
echo "Add to /etc/hosts for ingress access:"
echo "127.0.0.1 grafana.local jaeger.local"
echo ""
echo "Run tests:"
echo "pytest test/t8-monitoring-tests.py -v"
echo ""
echo "Documentation: docs/phase8-monitoring.md"