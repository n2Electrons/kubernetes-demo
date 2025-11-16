#!/bin/bash

# Quick Monitoring Access Script
# Provides shortcuts to monitoring tools

GRAFANA_PORT=3002
PROMETHEUS_PORT=9090

echo "Kubernetes Monitoring Quick Access"
echo "===================================="
echo ""

# Check if services are already port-forwarded
grafana_running=$(lsof -i :$GRAFANA_PORT 2>/dev/null | grep LISTEN || echo "")
prometheus_running=$(lsof -i :$PROMETHEUS_PORT 2>/dev/null | grep LISTEN || echo "")

if [ -n "$grafana_running" ] && [ -n "$prometheus_running" ]; then
    echo "Monitoring services are already running!"
    echo ""
    echo "Grafana: http://localhost:$GRAFANA_PORT (admin/admin123)"
    echo "Prometheus: http://localhost:$PROMETHEUS_PORT"
    echo ""
    echo "Quick Dashboard Import:"
    echo "   - Dashboard 315 - Kubernetes cluster monitoring"
    echo "   - Dashboard 747 - Kubernetes deployments"
    echo "   - Dashboard 6417 - Advanced cluster metrics"
    echo ""
    
    # Offer to open in browser
    if command -v xdg-open &> /dev/null || command -v open &> /dev/null; then
        read -p "Open Grafana in browser? (y/N): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if command -v xdg-open &> /dev/null; then
                xdg-open "http://localhost:$GRAFANA_PORT" 2>/dev/null &
            elif command -v open &> /dev/null; then
                open "http://localhost:$GRAFANA_PORT" 2>/dev/null &
            fi
            echo "Browser opening..."
        fi
    fi
else
    echo "Monitoring services not running"
    echo ""
    echo "To start monitoring services:"
    echo "   ./scripts/launch-monitoring.sh"
    echo ""
    echo "To deploy monitoring stack:"
    echo "   ./scripts/setup-monitoring.sh"
    echo ""
    echo "To run monitoring tests:"
    echo "   python3 test/t9-monitoring-status-tests.py"
fi

echo ""
echo "Available Scripts:"
echo "   - ./scripts/launch-monitoring.sh - Start Prometheus & Grafana"
echo "   - ./scripts/fix-prometheus-datasource.sh - Fix data source"
echo "   - ./scripts/grafana-dashboard-catalog.sh - Dashboard catalog"
echo "   - ./scripts/setup-monitoring.sh - Deploy monitoring stack"