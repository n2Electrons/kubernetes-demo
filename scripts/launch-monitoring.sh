#!/bin/bash

# Launch Prometheus and Grafana with Port Forwarding
# This script sets up access to both monitoring services

set -e

# Configuration
GRAFANA_PORT=3002
PROMETHEUS_PORT=9090
ARGOCD_PORT=8090
NAMESPACE="monitoring"
ARGOCD_NAMESPACE="argocd"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Starting Prometheus, Grafana, and ArgoCD Launcher${NC}"
echo "=========================================================="

# Function to cleanup on exit (only used for --stop command)
cleanup() {
    echo -e "\n${YELLOW}Cleaning up port forwarding processes...${NC}"
    pkill -f "port-forward.*grafana" 2>/dev/null || true
    pkill -f "port-forward.*prometheus" 2>/dev/null || true
    pkill -f "port-forward.*argocd" 2>/dev/null || true
    echo -e "${GREEN}Cleanup completed${NC}"
}

# Function to save PID files for background processes
save_pids() {
    mkdir -p ~/.kub-demo/pids
    echo $PROMETHEUS_PF_PID > ~/.kub-demo/pids/prometheus.pid
    echo $GRAFANA_PF_PID > ~/.kub-demo/pids/grafana.pid
    echo $ARGOCD_PF_PID > ~/.kub-demo/pids/argocd.pid
    echo -e "${GREEN}Process IDs saved for background monitoring${NC}"
}

# Function to check if monitoring processes are running
check_monitoring_status() {
    local prometheus_running=false
    local grafana_running=false
    local argocd_running=false
    
    if [ -f ~/.kub-demo/pids/prometheus.pid ]; then
        local prometheus_pid=$(cat ~/.kub-demo/pids/prometheus.pid)
        if kill -0 $prometheus_pid 2>/dev/null; then
            prometheus_running=true
        fi
    fi
    
    if [ -f ~/.kub-demo/pids/grafana.pid ]; then
        local grafana_pid=$(cat ~/.kub-demo/pids/grafana.pid)
        if kill -0 $grafana_pid 2>/dev/null; then
            grafana_running=true
        fi
    fi
    
    if [ -f ~/.kub-demo/pids/argocd.pid ]; then
        local argocd_pid=$(cat ~/.kub-demo/pids/argocd.pid)
        if kill -0 $argocd_pid 2>/dev/null; then
            argocd_running=true
        fi
    fi
    
    return $([ "$prometheus_running" = true ] && [ "$grafana_running" = true ] && [ "$argocd_running" = true ])
}

# Handle command line arguments first
case "${1:-}" in
    --status)
        echo -e "${BLUE}Checking monitoring service status...${NC}"
        if check_monitoring_status; then
            echo -e "${GREEN}Monitoring services are running${NC}"
            echo -e "Grafana: ${GREEN}http://localhost:$GRAFANA_PORT${NC}"
            echo -e "Prometheus: ${GREEN}http://localhost:$PROMETHEUS_PORT${NC}"
        else
            echo -e "${RED}Monitoring services are not running${NC}"
            echo "Use './scripts/launch-monitoring.sh' to start them"
        fi
        exit 0
        ;;
    --stop)
        echo -e "${BLUE}Stopping monitoring services...${NC}"
        cleanup
        if [ -d ~/.kub-demo/pids ]; then
            rm -f ~/.kub-demo/pids/prometheus.pid ~/.kub-demo/pids/grafana.pid
        fi
        echo -e "${GREEN}Monitoring services stopped${NC}"
        exit 0
        ;;
    --background)
        echo -e "${BLUE}Running in background mode${NC}"
        ;;
    *)
        # Default mode - continue with normal execution
        ;;
esac

# No automatic cleanup trap - let processes run in background

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
pkill -f "port-forward.*argocd" 2>/dev/null || true
sleep 2

# Clean up old PID files
if [ -d ~/.kub-demo/pids ]; then
    rm -f ~/.kub-demo/pids/prometheus.pid ~/.kub-demo/pids/grafana.pid ~/.kub-demo/pids/argocd.pid
fi

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

if lsof -i :$ARGOCD_PORT &> /dev/null; then
    echo -e "${YELLOW}Port $ARGOCD_PORT is in use, trying to free it...${NC}"
    pkill -f ":$ARGOCD_PORT" 2>/dev/null || true
    sleep 2
fi

# Start Prometheus port forwarding
echo -e "${BLUE}Starting Prometheus port forwarding...${NC}"
kubectl port-forward svc/prometheus $PROMETHEUS_PORT:9090 -n $NAMESPACE > /dev/null 2>&1 &
PROMETHEUS_PF_PID=$!

# Start Grafana port forwarding
echo -e "${BLUE}Starting Grafana port forwarding...${NC}"
kubectl port-forward svc/grafana $GRAFANA_PORT:3000 -n $NAMESPACE > /dev/null 2>&1 &
GRAFANA_PF_PID=$!

# Start ArgoCD port forwarding
echo -e "${BLUE}Starting ArgoCD port forwarding...${NC}"
kubectl port-forward svc/argocd-server $ARGOCD_PORT:80 -n $ARGOCD_NAMESPACE > /dev/null 2>&1 &
ARGOCD_PF_PID=$!

# Save PIDs for background monitoring
save_pids

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

# Test ArgoCD
echo -e "${BLUE}  Testing ArgoCD...${NC}"
if curl -s --connect-timeout 5 -k http://localhost:$ARGOCD_PORT > /dev/null; then
    echo -e "${GREEN}  ArgoCD is accessible at http://localhost:$ARGOCD_PORT${NC}"
else
    echo -e "${YELLOW}  ArgoCD connection test failed (might need more time)${NC}"
fi

# Display access information
echo ""
echo "==========================================================="
echo -e "${GREEN}Monitoring and GitOps Services Launched Successfully!${NC}"
echo "==========================================================="
echo ""
echo -e "${BLUE}Grafana Dashboard:${NC}"
echo -e "   URL: ${GREEN}http://localhost:$GRAFANA_PORT${NC}"
echo -e "   Username: ${GREEN}admin${NC}"
echo -e "   Password: ${GREEN}admin123${NC}"
echo ""
echo -e "${BLUE}Prometheus Metrics:${NC}"
echo -e "   URL: ${GREEN}http://localhost:$PROMETHEUS_PORT${NC}"
echo -e "   Targets: ${GREEN}http://localhost:$PROMETHEUS_PORT/targets${NC}"
echo ""
echo -e "${BLUE}ArgoCD GitOps:${NC}"
echo -e "   URL: ${GREEN}http://localhost:$ARGOCD_PORT${NC}"
echo -e "   Username: ${GREEN}admin${NC}"
echo -n "   Password: "
kubectl -n $ARGOCD_NAMESPACE get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null || echo "IXEjPVJD6O7TI3ve"
echo
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
echo -e "${BLUE}Management Commands:${NC}"
echo "   - Check status: ${GREEN}./scripts/launch-monitoring.sh --status${NC}"
echo "   - Stop monitoring: ${GREEN}./scripts/launch-monitoring.sh --stop${NC}"
echo ""
echo -e "${GREEN}Port forwarding is now running in the background.${NC}"
echo -e "${YELLOW}The monitoring services will continue running after this script exits.${NC}"
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

echo ""
echo -e "${GREEN}Script completed. Monitoring services are running in the background.${NC}"