#!/bin/bash

echo "=== Creating Enhanced kub-app Pod Monitoring Dashboard with Server Pods ==="
echo

# Configuration
GRAFANA_URL="http://localhost:3002"
USERNAME="admin"
PASSWORD="admin123"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}Creating comprehensive pod monitoring dashboard...${NC}"

# Enhanced dashboard JSON with server pods and per-pod grouping
dashboard_json=$(cat <<'EOF'
{
  "dashboard": {
    "id": null,
    "title": "Comprehensive Pod Monitoring (All Namespaces)",
    "tags": ["kubernetes", "pods", "system", "comprehensive"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "kub-app Pod CPU Usage (%)",
        "type": "stat",
        "targets": [
          {
            "expr": "sum(rate(container_cpu_usage_seconds_total{namespace=\"kub-app\",container!=\"\"}[5m])) by (pod) * 100",
            "legendFormat": "{{pod}}",
            "refId": "A"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "percent",
            "min": 0,
            "max": 100,
            "thresholds": {
              "mode": "absolute",
              "steps": [
                {"color": "green", "value": null},
                {"color": "yellow", "value": 50},
                {"color": "red", "value": 80}
              ]
            },
            "custom": {
              "displayMode": "gradient",
              "orientation": "horizontal"
            }
          }
        },
        "options": {
          "reduceOptions": {
            "values": false,
            "calcs": ["lastNotNull"],
            "fields": ""
          },
          "orientation": "auto",
          "textMode": "auto",
          "colorMode": "value",
          "graphMode": "area",
          "justifyMode": "auto"
        },
        "gridPos": {"h": 6, "w": 6, "x": 0, "y": 0}
      },
      {
        "id": 2,
        "title": "kub-app Pod Memory (MB)",
        "type": "stat",
        "targets": [
          {
            "expr": "sum(container_memory_usage_bytes{namespace=\"kub-app\",container!=\"\"}) by (pod) / 1024 / 1024",
            "legendFormat": "{{pod}}",
            "refId": "A"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "megabytes",
            "min": 0,
            "thresholds": {
              "mode": "absolute",
              "steps": [
                {"color": "green", "value": null},
                {"color": "yellow", "value": 100},
                {"color": "red", "value": 200}
              ]
            },
            "custom": {
              "displayMode": "gradient",
              "orientation": "horizontal"
            }
          }
        },
        "options": {
          "reduceOptions": {
            "values": false,
            "calcs": ["lastNotNull"],
            "fields": ""
          },
          "orientation": "auto",
          "textMode": "auto",
          "colorMode": "value",
          "graphMode": "area",
          "justifyMode": "auto"
        },
        "gridPos": {"h": 6, "w": 6, "x": 6, "y": 0}
      },
      {
        "id": 3,
        "title": "kube-system CPU (%)",
        "type": "stat",
        "targets": [
          {
            "expr": "sum(rate(container_cpu_usage_seconds_total{namespace=\"kube-system\",container!=\"\"}[5m])) * 100",
            "legendFormat": "kube-system",
            "refId": "A"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "percent",
            "min": 0,
            "thresholds": {
              "mode": "absolute",
              "steps": [
                {"color": "green", "value": null},
                {"color": "yellow", "value": 30},
                {"color": "red", "value": 60}
              ]
            },
            "custom": {
              "displayMode": "gradient",
              "orientation": "horizontal"
            }
          }
        },
        "options": {
          "reduceOptions": {
            "values": false,
            "calcs": ["lastNotNull"],
            "fields": ""
          },
          "orientation": "auto",
          "textMode": "auto",
          "colorMode": "value",
          "graphMode": "area",
          "justifyMode": "auto"
        },
        "gridPos": {"h": 6, "w": 4, "x": 8, "y": 0}
      },
      {
        "id": 4,
        "title": "kube-system Memory (MB)",
        "type": "stat",
        "targets": [
          {
            "expr": "sum(container_memory_usage_bytes{namespace=\"kube-system\",container!=\"\"}) / 1024 / 1024",
            "legendFormat": "kube-system",
            "refId": "A"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "megabytes",
            "min": 0,
            "thresholds": {
              "mode": "absolute",
              "steps": [
                {"color": "green", "value": null},
                {"color": "yellow", "value": 200},
                {"color": "red", "value": 500}
              ]
            },
            "custom": {
              "displayMode": "gradient",
              "orientation": "horizontal"
            }
          }
        },
        "options": {
          "reduceOptions": {
            "values": false,
            "calcs": ["lastNotNull"],
            "fields": ""
          },
          "orientation": "auto",
          "textMode": "auto",
          "colorMode": "value",
          "graphMode": "area",
          "justifyMode": "auto"
        },
        "gridPos": {"h": 6, "w": 4, "x": 12, "y": 0}
      },
      {
        "id": 5,
        "title": "monitoring CPU (%)",
        "type": "stat",
        "targets": [
          {
            "expr": "sum(rate(container_cpu_usage_seconds_total{namespace=\"monitoring\",container!=\"\"}[5m])) * 100",
            "legendFormat": "monitoring",
            "refId": "A"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "percent",
            "min": 0,
            "thresholds": {
              "mode": "absolute",
              "steps": [
                {"color": "green", "value": null},
                {"color": "yellow", "value": 30},
                {"color": "red", "value": 60}
              ]
            },
            "custom": {
              "displayMode": "gradient",
              "orientation": "horizontal"
            }
          }
        },
        "options": {
          "reduceOptions": {
            "values": false,
            "calcs": ["lastNotNull"],
            "fields": ""
          },
          "orientation": "auto",
          "textMode": "auto",
          "colorMode": "value",
          "graphMode": "area",
          "justifyMode": "auto"
        },
        "gridPos": {"h": 6, "w": 4, "x": 16, "y": 0}
      },
      {
        "id": 6,
        "title": "monitoring Memory (MB)",
        "type": "stat",
        "targets": [
          {
            "expr": "sum(container_memory_usage_bytes{namespace=\"monitoring\",container!=\"\"}) / 1024 / 1024",
            "legendFormat": "monitoring",
            "refId": "A"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "megabytes",
            "min": 0,
            "thresholds": {
              "mode": "absolute",
              "steps": [
                {"color": "green", "value": null},
                {"color": "yellow", "value": 200},
                {"color": "red", "value": 500}
              ]
            },
            "custom": {
              "displayMode": "gradient",
              "orientation": "horizontal"
            }
          }
        },
        "options": {
          "reduceOptions": {
            "values": false,
            "calcs": ["lastNotNull"],
            "fields": ""
          },
          "orientation": "auto",
          "textMode": "auto",
          "colorMode": "value",
          "graphMode": "area",
          "justifyMode": "auto"
        },
        "gridPos": {"h": 6, "w": 4, "x": 20, "y": 0}
      },
      {
        "id": 7,
        "title": "kub-app Pod CPU Over Time (Grouped by Pod)",
        "type": "timeseries",
        "targets": [
          {
            "expr": "sum(rate(container_cpu_usage_seconds_total{namespace=\"kub-app\",container!=\"\"}[5m])) by (pod) * 100",
            "legendFormat": "{{pod}}",
            "refId": "A"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "percent",
            "custom": {
              "drawStyle": "line",
              "lineInterpolation": "linear",
              "lineWidth": 2,
              "fillOpacity": 10,
              "gradientMode": "none",
              "spanNulls": false,
              "insertNulls": false,
              "showPoints": "never",
              "pointSize": 5,
              "stacking": {"mode": "none", "group": "A"},
              "axisPlacement": "auto",
              "axisLabel": "CPU %",
              "axisColorMode": "text",
              "scaleDistribution": {"type": "linear"},
              "axisCenteredZero": false,
              "hideFrom": {"legend": false, "tooltip": false, "vis": false},
              "thresholdsStyle": {"mode": "off"}
            }
          }
        },
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 6}
      },
      {
        "id": 8,
        "title": "kub-app Pod Memory Over Time (Grouped by Pod)",
        "type": "timeseries",
        "targets": [
          {
            "expr": "sum(container_memory_usage_bytes{namespace=\"kub-app\",container!=\"\"}) by (pod) / 1024 / 1024",
            "legendFormat": "{{pod}}",
            "refId": "A"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "megabytes",
            "custom": {
              "drawStyle": "line",
              "lineInterpolation": "linear",
              "lineWidth": 2,
              "fillOpacity": 10,
              "gradientMode": "none",
              "spanNulls": false,
              "insertNulls": false,
              "showPoints": "never",
              "pointSize": 5,
              "stacking": {"mode": "none", "group": "A"},
              "axisPlacement": "auto",
              "axisLabel": "Memory MB",
              "axisColorMode": "text",
              "scaleDistribution": {"type": "linear"},
              "axisCenteredZero": false,
              "hideFrom": {"legend": false, "tooltip": false, "vis": false},
              "thresholdsStyle": {"mode": "off"}
            }
          }
        },
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 6}
      },
      {
        "id": 9,
        "title": "All Pods CPU Usage (Grouped by Pod)",
        "type": "timeseries",
        "targets": [
          {
            "expr": "sum(rate(container_cpu_usage_seconds_total{container!=\"\",container!=\"POD\"}[5m])) by (pod, namespace) * 100",
            "legendFormat": "{{namespace}}/{{pod}}",
            "refId": "A"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "percent",
            "custom": {
              "drawStyle": "line",
              "lineInterpolation": "linear",
              "lineWidth": 1,
              "fillOpacity": 5,
              "gradientMode": "none",
              "spanNulls": false,
              "insertNulls": false,
              "showPoints": "never",
              "pointSize": 5,
              "stacking": {"mode": "none", "group": "A"},
              "axisPlacement": "auto",
              "axisLabel": "CPU %",
              "axisColorMode": "text",
              "scaleDistribution": {"type": "linear"},
              "axisCenteredZero": false,
              "hideFrom": {"legend": false, "tooltip": false, "vis": false},
              "thresholdsStyle": {"mode": "off"}
            }
          }
        },
        "gridPos": {"h": 10, "w": 12, "x": 0, "y": 14}
      },
      {
        "id": 10,
        "title": "All Pods Memory Usage (Grouped by Pod)",
        "type": "timeseries",
        "targets": [
          {
            "expr": "sum(container_memory_usage_bytes{container!=\"\",container!=\"POD\"}) by (pod, namespace) / 1024 / 1024",
            "legendFormat": "{{namespace}}/{{pod}}",
            "refId": "A"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "megabytes",
            "custom": {
              "drawStyle": "line",
              "lineInterpolation": "linear",
              "lineWidth": 1,
              "fillOpacity": 5,
              "gradientMode": "none",
              "spanNulls": false,
              "insertNulls": false,
              "showPoints": "never",
              "pointSize": 5,
              "stacking": {"mode": "none", "group": "A"},
              "axisPlacement": "auto",
              "axisLabel": "Memory MB",
              "axisColorMode": "text",
              "scaleDistribution": {"type": "linear"},
              "axisCenteredZero": false,
              "hideFrom": {"legend": false, "tooltip": false, "vis": false},
              "thresholdsStyle": {"mode": "off"}
            }
          }
        },
        "gridPos": {"h": 10, "w": 12, "x": 12, "y": 14}
      },
      {
        "id": 11,
        "title": "System Services Pod Details (CPU %)",
        "type": "timeseries",
        "targets": [
          {
            "expr": "sum(rate(container_cpu_usage_seconds_total{namespace=~\"kube-system|monitoring\",container!=\"\"}[5m])) by (pod, namespace) * 100",
            "legendFormat": "{{namespace}}/{{pod}}",
            "refId": "A"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "percent",
            "custom": {
              "drawStyle": "line",
              "lineInterpolation": "linear",
              "lineWidth": 1,
              "fillOpacity": 5,
              "gradientMode": "none",
              "spanNulls": false,
              "insertNulls": false,
              "showPoints": "never",
              "pointSize": 5,
              "stacking": {"mode": "none", "group": "A"},
              "axisPlacement": "auto",
              "axisLabel": "CPU %",
              "axisColorMode": "text",
              "scaleDistribution": {"type": "linear"},
              "axisCenteredZero": false,
              "hideFrom": {"legend": false, "tooltip": false, "vis": false},
              "thresholdsStyle": {"mode": "off"}
            }
          }
        },
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 24}
      },
      {
        "id": 12,
        "title": "System Services Pod Details (Memory MB)",
        "type": "timeseries",
        "targets": [
          {
            "expr": "sum(container_memory_usage_bytes{namespace=~\"kube-system|monitoring\",container!=\"\"}) by (pod, namespace) / 1024 / 1024",
            "legendFormat": "{{namespace}}/{{pod}}",
            "refId": "A"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "megabytes",
            "custom": {
              "drawStyle": "line",
              "lineInterpolation": "linear",
              "lineWidth": 1,
              "fillOpacity": 5,
              "gradientMode": "none",
              "spanNulls": false,
              "insertNulls": false,
              "showPoints": "never",
              "pointSize": 5,
              "stacking": {"mode": "none", "group": "A"},
              "axisPlacement": "auto",
              "axisLabel": "Memory MB",
              "axisColorMode": "text",
              "scaleDistribution": {"type": "linear"},
              "axisCenteredZero": false,
              "hideFrom": {"legend": false, "tooltip": false, "vis": false},
              "thresholdsStyle": {"mode": "off"}
            }
          }
        },
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 24}
      }
    ],
    "time": {"from": "now-15m", "to": "now"},
    "timepicker": {},
    "templating": {"list": []},
    "annotations": {"list": []},
    "refresh": "30s",
    "schemaVersion": 30,
    "version": 0,
    "links": [],
    "gnetId": null
  },
  "folderId": 0,
  "overwrite": true
}
EOF
)

echo -e "${BLUE}Updating dashboard in Grafana...${NC}"
response=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -u "$USERNAME:$PASSWORD" \
    -d "$dashboard_json" \
    "$GRAFANA_URL/api/dashboards/db")

if echo "$response" | grep -q "success"; then
    echo -e "${GREEN}✅ Comprehensive pod monitoring dashboard created successfully!${NC}"
    
    # Get dashboard URL
    dashboard_url=$(echo "$response" | jq -r '.url')
    echo -e "${GREEN}Dashboard URL: $GRAFANA_URL$dashboard_url${NC}"
else
    echo -e "${YELLOW}⚠ Dashboard creation response:${NC}"
    echo "$response" | jq '.'
fi

echo
echo -e "${BLUE}=== Enhanced Dashboard Features (with Server Pods) ===${NC}"
echo
echo -e "${GREEN}📊 DIALS/STATS (Top Row):${NC}"
echo "• kub-app Pod CPU % - Per-pod CPU usage with color coding"
echo "• kub-app Pod Memory - Per-pod memory consumption"  
echo "• System Pod CPU % - All system pods (kube-system, monitoring, default)"
echo "• System Pod Memory - All system pod memory usage"
echo
echo -e "${GREEN}📈 DETAILED TIME SERIES:${NC}"
echo "• kub-app Pod CPU/Memory Over Time - Focused on application pods"
echo "• All Pods CPU/Memory Usage - Every pod in cluster grouped by pod"
echo "• System Services Pod Details - Detailed system component breakdown"
echo
echo -e "${GREEN}🎨 GROUPING IMPROVEMENTS:${NC}"
echo "• CPU/Memory grouped BY POD (not by container)"
echo "• Includes server pods and all namespaces"
echo "• Legend format: namespace/pod for clarity"
echo "• Separate views for applications vs system services"
echo
echo -e "${GREEN}🔍 WHAT'S INCLUDED:${NC}"
echo "• kub-app pods: Your application containers"
echo "• kube-system pods: DNS, storage, networking, metrics"
echo "• monitoring pods: Prometheus, Grafana, AlertManager, etc."
echo "• default pods: Any pods in default namespace"
echo "• All server/worker node pods included automatically"
echo
echo -e "${YELLOW}Access at: $GRAFANA_URL${NC}"
echo -e "${YELLOW}Navigate to: Dashboards → Comprehensive Pod Monitoring (All Namespaces)${NC}"