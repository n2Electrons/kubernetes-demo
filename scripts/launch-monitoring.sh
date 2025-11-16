#!/bin/bash

# Launch Prometheus and Grafana with Port Forwarding
# This script sets up access to both monitoring services

set -e

# Configuration
GRAFANA_PORT=3002
PROMETHEUS_PORT=9090
NAMESPACE="monitoring"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Starting Prometheus and Grafana Launcher${NC}"
echo "=================================================="

# Function to cleanup on exit
cleanup() {
    echo -e "\n${YELLOW}Cleaning up port forwarding processes...${NC}"
    pkill -f "port-forward.*grafana" 2>/dev/null || true
    pkill -f "port-forward.*prometheus" 2>/dev/null || true
    echo -e "${GREEN}Cleanup completed${NC}"
    exit 0
}

# Trap cleanup on script exit
trap cleanup EXIT INT TERM

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}kubectl is not installed or not in PATH${NC}"
    exit 1
fi

# Check cluster connectivity
echo -e "${BLUE}Checking cluster connectivity...${NC}"
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Cannot connect to Kubernetes cluster${NC}"
    echo "Make sure your cluster is running and kubectl is configured"
    exit 1
fi
echo -e "${GREEN}Cluster connectivity OK${NC}"

# Check if monitoring namespace exists
echo -e "${BLUE}Checking monitoring namespace...${NC}"
if ! kubectl get namespace $NAMESPACE &> /dev/null; then
    echo -e "${RED}Monitoring namespace '$NAMESPACE' not found${NC}"
    echo "Deploy the monitoring stack first: ./scripts/setup-monitoring.sh"
    exit 1
fi
echo -e "${GREEN}Monitoring namespace exists${NC}"

# Check if services are running
echo -e "${BLUE}Checking monitoring services...${NC}"

# Check Prometheus
if ! kubectl get svc prometheus -n $NAMESPACE &> /dev/null; then
    echo -e "${RED}Prometheus service not found${NC}"
    exit 1
fi

# Check Grafana
if ! kubectl get svc grafana -n $NAMESPACE &> /dev/null; then
    echo -e "${RED}Grafana service not found${NC}"
    exit 1
fi

echo -e "${GREEN}Monitoring services found${NC}"

# Check if pods are running
echo -e "${BLUE}Checking pod status...${NC}"

prometheus_pod=$(kubectl get pods -n $NAMESPACE -l app=prometheus --field-selector=status.phase=Running -o name 2>/dev/null | head -1)
grafana_pod=$(kubectl get pods -n $NAMESPACE -l app=grafana --field-selector=status.phase=Running -o name 2>/dev/null | head -1)

if [ -z "$prometheus_pod" ]; then
    echo -e "${RED}No running Prometheus pod found${NC}"
    kubectl get pods -n $NAMESPACE -l app=prometheus
    exit 1
fi

if [ -z "$grafana_pod" ]; then
    echo -e "${RED}No running Grafana pod found${NC}"
    kubectl get pods -n $NAMESPACE -l app=grafana
    exit 1
fi

echo -e "${GREEN}Prometheus pod: ${prometheus_pod#pod/}${NC}"
echo -e "${GREEN}Grafana pod: ${grafana_pod#pod/}${NC}"

# Kill existing port-forward processes
echo -e "${BLUE}Cleaning up existing port forwards...${NC}"
pkill -f "port-forward.*grafana" 2>/dev/null || true
pkill -f "port-forward.*prometheus" 2>/dev/null || true
sleep 2

# Check if ports are available
echo -e "${BLUE}Checking port availability...${NC}"

if lsof -i :$GRAFANA_PORT &> /dev/null; then
    echo -e "${YELLOW}Port $GRAFANA_PORT is in use, trying to free it...${NC}"
    pkill -f ":$GRAFANA_PORT" 2>/dev/null || true
    sleep 2
fi

if lsof -i :$PROMETHEUS_PORT &> /dev/null; then
    echo -e "${YELLOW}Port $PROMETHEUS_PORT is in use, trying to free it...${NC}"
    pkill -f ":$PROMETHEUS_PORT" 2>/dev/null || true
    sleep 2
fi

# Start Prometheus port forwarding
echo -e "${BLUE}Starting Prometheus port forwarding...${NC}"
kubectl port-forward svc/prometheus $PROMETHEUS_PORT:9090 -n $NAMESPACE &
PROMETHEUS_PF_PID=$!

# Start Grafana port forwarding
echo -e "${BLUE}Starting Grafana port forwarding...${NC}"
kubectl port-forward svc/grafana $GRAFANA_PORT:3000 -n $NAMESPACE &
GRAFANA_PF_PID=$!

# Wait for port forwards to establish
echo -e "${BLUE}Waiting for port forwards to establish...${NC}"
sleep 5

# Test connections
echo -e "${BLUE}Testing connections...${NC}"

# Test Prometheus
echo -e "${BLUE}  Testing Prometheus...${NC}"
if curl -s --connect-timeout 5 http://localhost:$PROMETHEUS_PORT/api/v1/status/config > /dev/null; then
    echo -e "${GREEN}  Prometheus is accessible at http://localhost:$PROMETHEUS_PORT${NC}"
else
    echo -e "${YELLOW}  Prometheus connection test failed (might need more time)${NC}"
fi

# Test Grafana
echo -e "${BLUE}  Testing Grafana...${NC}"
if curl -s --connect-timeout 5 http://localhost:$GRAFANA_PORT/api/health > /dev/null; then
    echo -e "${GREEN}  Grafana is accessible at http://localhost:$GRAFANA_PORT${NC}"
else
    echo -e "${YELLOW}  Grafana connection test failed (might need more time)${NC}"
fi

# Display access information
echo ""
echo "=================================================="
echo -e "${GREEN}Monitoring Services Launched Successfully!${NC}"
echo "=================================================="
echo ""
echo -e "${BLUE}Grafana Dashboard:${NC}"
echo -e "   URL: ${GREEN}http://localhost:$GRAFANA_PORT${NC}"
echo -e "   Username: ${GREEN}admin${NC}"
echo -e "   Password: ${GREEN}admin123${NC}"
echo ""
echo -e "${BLUE}Prometheus Metrics:${NC}"
echo -e "   URL: ${GREEN}http://localhost:$PROMETHEUS_PORT${NC}"
echo -e "   Targets: ${GREEN}http://localhost:$PROMETHEUS_PORT/targets${NC}"
echo -e "   Query: ${GREEN}http://localhost:$PROMETHEUS_PORT/graph${NC}"
echo ""
echo -e "${BLUE}Quick Actions:${NC}"
echo "   - Import Dashboard 315 for Kubernetes cluster monitoring"
echo "   - Import Dashboard 747 for deployment monitoring"
echo "   - Try Explore → Prometheus → Query: up"
echo ""
echo -e "${BLUE}Useful Prometheus Queries:${NC}"
echo "   - up - Service availability"
echo "   - kube_node_info - Node information"
echo "   - kube_pod_info - Pod information"
echo "   - rate(container_cpu_usage_seconds_total[5m]) - CPU usage"
echo ""
echo -e "${YELLOW}Tip: Keep this terminal open to maintain port forwarding${NC}"
echo "=================================================="

# Check if browser opening is available
if command -v xdg-open &> /dev/null || command -v open &> /dev/null; then
    echo ""
    read -p "Open Grafana in browser? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if command -v xdg-open &> /dev/null; then
            xdg-open "http://localhost:$GRAFANA_PORT" 2>/dev/null &
        elif command -v open &> /dev/null; then
            open "http://localhost:$GRAFANA_PORT" 2>/dev/null &
        fi
        echo -e "${GREEN}Browser opening...${NC}"
    fi
fi

# Keep the script running
echo ""
echo -e "${BLUE}Port forwarding is active. Press Ctrl+C to stop.${NC}"
echo ""

# Wait for the port-forward processes
wait $PROMETHEUS_PF_PID $GRAFANA_PF_PID