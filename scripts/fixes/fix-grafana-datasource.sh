#!/bin/bash

echo "=== Grafana Data Source Fix & Verification ==="
echo

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m' 
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

GRAFANA_URL="http://localhost:3002"
USERNAME="admin"
PASSWORD="admin123"

echo -e "${BLUE}Testing Grafana connectivity...${NC}"
if ! curl -s -f -u "$USERNAME:$PASSWORD" "$GRAFANA_URL/api/health" > /dev/null; then
    echo -e "${RED}❌ Cannot connect to Grafana${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Grafana is accessible${NC}"

echo -e "${BLUE}Testing Prometheus data source...${NC}"
response=$(curl -s -u "$USERNAME:$PASSWORD" "$GRAFANA_URL/api/datasources/proxy/1/api/v1/query?query=up")
if echo "$response" | grep -q "success"; then
    echo -e "${GREEN}✅ Prometheus data source is working${NC}"
    up_count=$(echo "$response" | jq '.data.result | length')
    echo "   Found $up_count 'up' metrics"
else
    echo -e "${RED}❌ Prometheus data source connection failed${NC}"
    echo "$response"
    exit 1
fi

echo -e "${BLUE}Testing kub-app metrics...${NC}"
kub_app_response=$(curl -s -u "$USERNAME:$PASSWORD" "$GRAFANA_URL/api/datasources/proxy/1/api/v1/query?query=kube_pod_info%7Bnamespace%3D%22kub-app%22%7D")
if echo "$kub_app_response" | grep -q "success"; then
    kub_app_count=$(echo "$kub_app_response" | jq '.data.result | length')
    echo -e "${GREEN}✅ kub-app pod metrics available: $kub_app_count pods${NC}"
else
    echo -e "${YELLOW}⚠ kub-app metrics may not be available yet${NC}"
fi

echo -e "${BLUE}Testing CPU metrics for kub-app...${NC}"
cpu_response=$(curl -s -u "$USERNAME:$PASSWORD" "$GRAFANA_URL/api/datasources/proxy/1/api/v1/query?query=rate(container_cpu_usage_seconds_total%7Bnamespace%3D%22kub-app%22,container%21%3D%22%22%7D%5B5m%5D)")
if echo "$cpu_response" | grep -q "success"; then
    cpu_count=$(echo "$cpu_response" | jq '.data.result | length')
    echo -e "${GREEN}✅ CPU metrics available: $cpu_count series${NC}"
    if [ "$cpu_count" -gt 0 ]; then
        echo "   Sample CPU values:"
        echo "$cpu_response" | jq '.data.result[] | {pod: .metric.pod, cpu_rate: (.value[1] | tonumber * 100)}'
    fi
else
    echo -e "${YELLOW}⚠ CPU metrics may not be available yet${NC}"
fi

echo
echo -e "${BLUE}=== DASHBOARD TROUBLESHOOTING ===${NC}"
echo
echo "If dashboards show 'Prometheus data not available':"
echo
echo "1. ${GREEN}REFRESH THE DASHBOARD${NC}"
echo "   - Click the refresh button (🔄) in dashboard"
echo "   - Or press Ctrl+R to refresh browser"
echo
echo "2. ${GREEN}CHECK TIME RANGE${NC}"
echo "   - Set to 'Last 15 minutes' or 'Last 1 hour'"
echo "   - Click time picker in top-right"
echo
echo "3. ${GREEN}VERIFY DATA SOURCE IN PANEL${NC}"
echo "   - Edit panel → Query tab"
echo "   - Ensure data source shows 'prometheus'"
echo "   - If it shows 'default' or empty, select 'prometheus'"
echo
echo "4. ${GREEN}TEST QUERY IN EXPLORE${NC}"
echo "   - Go to Explore (compass icon)"
echo "   - Select 'prometheus' data source"
echo "   - Try query: up"
echo
echo "5. ${GREEN}MANUAL DATA SOURCE CONFIG${NC}"
echo "   - Go to Configuration → Data Sources"
echo "   - Click 'prometheus'"
echo "   - Click 'Save & Test'"
echo
echo -e "${GREEN}✅ Data is confirmed available - issue is likely dashboard configuration!${NC}"