#!/bin/bash

# Fix Prometheus Data Source Configuration in Grafana
set -e

GRAFANA_URL="http://localhost:3002"
GRAFANA_USER="admin" 
GRAFANA_PASS="admin123"

echo "🔧 Fixing Prometheus data source configuration..."

# First, let's start Prometheus port forwarding for direct access
echo "Setting up Prometheus port forwarding..."
pkill -f "prometheus.*port-forward" 2>/dev/null || true
kubectl port-forward svc/prometheus 9090:9090 -n monitoring &
PF_PID=$!
sleep 3

echo "✅ Prometheus port forwarding started on localhost:9090"

# Test Grafana connectivity
echo "Testing Grafana connectivity..."
if ! curl -s --connect-timeout 5 --max-time 10 "$GRAFANA_URL/api/health" >/dev/null; then
    echo "❌ Cannot connect to Grafana at $GRAFANA_URL"
    echo "Starting Grafana port forwarding..."
    pkill -f "grafana.*port-forward" 2>/dev/null || true
    kubectl port-forward svc/grafana 3002:3000 -n monitoring &
    sleep 3
    
    if ! curl -s --connect-timeout 5 --max-time 10 "$GRAFANA_URL/api/health" >/dev/null; then
        echo "❌ Still cannot connect to Grafana"
        exit 1
    fi
fi

echo "✅ Grafana is accessible"

# Get existing data sources
echo "Checking existing data sources..."
datasources=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASS" "$GRAFANA_URL/api/datasources")

# Find Prometheus data source ID
prometheus_id=$(echo "$datasources" | grep -o '"id":[0-9]*[^}]*"name":"Prometheus"' | grep -o '"id":[0-9]*' | cut -d':' -f2 | tr -d ' ')

if [ -n "$prometheus_id" ]; then
    echo "Found existing Prometheus data source with ID: $prometheus_id"
    
    # Update the existing data source with correct URL
    echo "Updating Prometheus data source configuration..."
    update_response=$(curl -X PUT \
        -H "Content-Type: application/json" \
        -u "$GRAFANA_USER:$GRAFANA_PASS" \
        -d '{
            "id": '$prometheus_id',
            "name": "Prometheus",
            "type": "prometheus",
            "url": "http://prometheus.monitoring.svc.cluster.local:9090",
            "access": "proxy", 
            "isDefault": true,
            "basicAuth": false,
            "withCredentials": false,
            "jsonData": {
                "httpMethod": "POST",
                "timeInterval": "5s"
            }
        }' \
        "$GRAFANA_URL/api/datasources/$prometheus_id")
    
    if [[ "$update_response" == *'"message":"Datasource updated"'* ]]; then
        echo "✅ Prometheus data source updated successfully!"
    else
        echo "⚠️  Update response: $update_response"
    fi
else
    # Add new Prometheus data source
    echo "Adding new Prometheus data source..."
    add_response=$(curl -X POST \
        -H "Content-Type: application/json" \
        -u "$GRAFANA_USER:$GRAFANA_PASS" \
        -d '{
            "name": "Prometheus",
            "type": "prometheus",
            "url": "http://prometheus.monitoring.svc.cluster.local:9090", 
            "access": "proxy",
            "isDefault": true,
            "basicAuth": false,
            "withCredentials": false,
            "jsonData": {
                "httpMethod": "POST",
                "timeInterval": "5s"
            }
        }' \
        "$GRAFANA_URL/api/datasources")
    
    if [[ "$add_response" == *'"message":"Datasource added"'* ]] || [[ "$add_response" == *'"id":'* ]]; then
        echo "✅ Prometheus data source added successfully!"
    else
        echo "❌ Failed to add data source: $add_response"
    fi
fi

# Test Prometheus connectivity from within cluster
echo ""
echo "🧪 Testing Prometheus connectivity..."

# Get a prometheus pod to test internal connectivity
prometheus_pod=$(kubectl get pods -n monitoring -l app=prometheus -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -n "$prometheus_pod" ]; then
    echo "Testing Prometheus query from within cluster..."
    test_result=$(kubectl exec -n monitoring "$prometheus_pod" -- wget -qO- "http://prometheus:9090/api/v1/query?query=up" 2>/dev/null || echo "failed")
    
    if [[ "$test_result" == *'"status":"success"'* ]]; then
        echo "✅ Prometheus is responding correctly within cluster"
    else
        echo "⚠️  Prometheus internal test result: $test_result"
    fi
else
    echo "⚠️  Could not find Prometheus pod for testing"
fi

# Test local Prometheus access
echo "Testing local Prometheus access..."
if curl -s "http://localhost:9090/api/v1/query?query=up" >/dev/null; then
    echo "✅ Prometheus is accessible locally at http://localhost:9090"
else
    echo "⚠️  Prometheus not accessible locally (port forwarding may need time to establish)"
fi

echo ""
echo "🎯 Configuration Summary:"
echo "  📊 Grafana: http://localhost:3002 (admin/admin123)"
echo "  📈 Prometheus: http://localhost:9090 (direct access)"
echo "  🔗 Data Source URL: http://prometheus.monitoring.svc.cluster.local:9090"
echo ""
echo "🔧 Next Steps:"
echo "  1. Refresh your Grafana page (http://localhost:3002)"
echo "  2. Go to Configuration → Data Sources"
echo "  3. Click on Prometheus and test the connection"
echo "  4. Try Explore → Prometheus → Query: up"
echo ""
echo "📊 Popular queries to test:"
echo "  - up (shows all targets)"
echo "  - kube_node_info (node information)"
echo "  - kube_pod_info (pod information)"
echo "  - rate(container_cpu_usage_seconds_total[5m]) (CPU usage)"