# Monitoring Scripts Documentation

This directory contains scripts for managing the Kubernetes monitoring stack (Prometheus + Grafana).

## Quick Start

### Launch Monitoring Services
```bash
# Start both Prometheus and Grafana with port forwarding
./scripts/launch-monitoring.sh
```

### Check Status and Quick Access
```bash
# Check if services are running and get quick access
./scripts/monitoring-access.sh
```

## Available Scripts

### `launch-monitoring.sh`
Main launcher for Prometheus and Grafana with port forwarding setup.
- Usage: `./scripts/launch-monitoring.sh`
- Manages background processes with PID tracking
- Auto-cleanup on termination

### `create-pod-dashboard.sh`
Creates comprehensive pod monitoring dashboard with namespace summaries.
- Usage: `./scripts/create-pod-dashboard.sh`
- Features: kub-app pods, kube-system summary, monitoring summary
- Individual pod metrics and namespace-level aggregates

### `monitoring-access.sh`
Quick status check and access information for running services.
- Usage: `./scripts/monitoring-access.sh`

### `setup-monitoring.sh`
Deploy the complete monitoring stack (Prometheus, Grafana, AlertManager, Jaeger, Fluent Bit).
- Usage: `./scripts/setup-monitoring.sh`

### `update-prometheus-datasource.sh`
Configure Prometheus as data source in Grafana.
- Usage: `./scripts/update-prometheus-datasource.sh`

## Access Information

### Grafana Dashboard
- URL: http://localhost:3002
- Username: admin
- Password: admin123

### Prometheus Metrics
- URL: http://localhost:9090
- Targets: http://localhost:9090/targets
- Query Interface: http://localhost:9090/graph

## Grafana Dashboard Features

### Comprehensive Pod Monitoring Dashboard
Created by `./scripts/create-pod-dashboard.sh`:

**Top Row Stats (Namespace Summaries):**
- kub-app Pod CPU % - Application pod CPU usage 
- kub-app Pod Memory - Application pod memory consumption
- kube-system CPU % - System namespace total CPU
- kube-system Memory - System namespace total memory  
- monitoring CPU % - Monitoring stack total CPU
- monitoring Memory - Monitoring stack total memory

**Time Series Plots:**
- kub-app Pod CPU/Memory Over Time - Application trends
- All Pods CPU/Memory Usage - Cluster-wide pod metrics
- System Services Pod Details - Individual system component breakdown
- Monitoring Pods CPU/Memory Over Time - Dedicated monitoring stack plots

**Key Features:**
- Color-coded thresholds (Green/Yellow/Red)
- Individual pod breakdown with namespace/pod format
- Auto-refresh every 30 seconds
- 15-minute time window with real-time data
- Prometheus queries optimized for performance

### Access Points
```bash
# Launch monitoring and create dashboard
./scripts/launch-monitoring.sh
./scripts/create-pod-dashboard.sh

# Dashboard URL: http://localhost:3002/d/.../comprehensive-pod-monitoring-all-namespaces
```
1. Go to + → Import in Grafana
2. Enter Dashboard ID
3. Click Load
4. Select Prometheus as data source

### Infrastructure & Cluster Dashboards

| ID | Name | Description |
|---|---|---|
| **315** | Kubernetes cluster monitoring | **ESSENTIAL** - General Overview: Nodes, Pods, CPU, Memory, Network, Disk |
| **6417** | Kubernetes Cluster (Prometheus) | Advanced cluster metrics, resource utilization |
| **7249** | Kubernetes Cluster (by Node) | Per-node breakdown, detailed node metrics |
| **10000** | Kubernetes Cluster Monitoring | Comprehensive cluster overview with alerting |
| **12006** | Kubernetes / Views / Global | Global cluster view with multiple perspectives |

### Workload & Application Dashboards

| ID | Name | Description |
|---|---|---|
| **747** | Kubernetes Deployment | Deployment status, replica counts, rollouts |
| **8588** | Kubernetes Deployment/Statefulset/Daemonset | All workload types in one dashboard |
| **6336** | Kubernetes Pods | Pod-level metrics, restarts, resource usage |
| **1471** | Kubernetes Pod Resources | Detailed pod resource consumption |
| **12114** | Kubernetes / Views / Pods | Advanced pod monitoring and troubleshooting |

### Networking & Ingress Dashboards

| ID | Name | Description |
|---|---|---|
| **7645** | Kubernetes Networking (cluster) | Network traffic, bandwidth, connections |
| **9614** | Nginx Ingress Controller | Ingress metrics, requests, response times |
| **11462** | Traefik 2.0 Dashboard | Traefik ingress controller metrics |

### Storage & Persistent Volumes

| ID | Name | Description |
|---|---|---|
| **13646** | Kubernetes / Storage | PVC usage, storage metrics |
| **6739** | Kubernetes Persistent Volumes | Volume usage, capacity, performance |

### Monitoring & Alerting Dashboards

| ID | Name | Description |
|---|---|---|
| **3662** | Prometheus Stats | Prometheus performance, scrape metrics |
| **9578** | Prometheus Overview | Prometheus server health and performance |
| **11074** | Node Exporter / USE Method / Node | Node-level system metrics (requires node-exporter) |

### Specialized & Advanced Dashboards

| ID | Name | Description |
|---|---|---|
| **12740** | Kubernetes / System / API Server | API server performance and health |
| **13639** | Kubernetes / Views / Namespaces | Per-namespace resource breakdown |
| **10856** | Kubernetes HPA | Horizontal Pod Autoscaler metrics |

### Recommended Import Order

1. Dashboard 315 - Kubernetes cluster monitoring (Essential)
2. Dashboard 747 - Kubernetes Deployment  
3. Dashboard 6417 - Kubernetes Cluster Prometheus
4. Dashboard 8588 - All workload types
5. Dashboard 3662 - Prometheus Stats

### Useful Prometheus Queries for Testing

Test these queries in Grafana Explore or Prometheus:

```promql
# Service availability
up

# Node information
kube_node_info

# Pod information  
kube_pod_info

# CPU usage rate
rate(container_cpu_usage_seconds_total[5m])

# Memory usage
container_memory_usage_bytes
```

## Troubleshooting

### Services Not Running
```bash
# Check pod status
kubectl get pods -n monitoring

# Redeploy if needed
./scripts/setup-monitoring.sh
```

### Port Conflicts
```bash
# Kill existing port forwards
pkill -f "port-forward"

# Restart launcher
./scripts/launch-monitoring.sh
```

### Data Source Issues
```bash
# Update Prometheus data source
./scripts/update-prometheus-datasource.sh
```

### No Dashboard Data
1. Check Prometheus data source is working in Grafana
2. Test metrics: Go to Explore → Query `up`
3. Adjust time range to "Last 1 hour"
4. Verify required exporters are installed

#### Common Test Queries
```promql
up                                    # Shows all targets
kube_node_info                       # Node information
kube_pod_info                        # Pod information
container_cpu_usage_seconds_total    # CPU usage
container_memory_usage_bytes         # Memory usage
```

## Testing

### Run Monitoring Tests
```bash
# Test monitoring stack deployment
python3 test/t8-monitoring-tests.py

# Test monitoring stack status
python3 test/t9-monitoring-status-tests.py
```

## Notes

- Keep the launcher terminal open to maintain port forwarding
- Use `Ctrl+C` to stop port forwarding cleanly
- Services are accessible only while port forwarding is active
- The scripts include automatic cleanup and error handling