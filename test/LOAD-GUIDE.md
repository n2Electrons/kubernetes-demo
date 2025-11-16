# Load Generation Guide for Grafana Dashboards

This guide shows you how to generate dynamic data for your Grafana monitoring dashboards using existing test cases and load generation scripts.

## Quick Start

### Method 1: Automated Test Load (Recommended)
```bash
# Run the interactive test load generator
./scripts/generate-test-load.sh
```

### Method 2: Manual Load Generation
```bash
# Run the interactive load generator
./scripts/generate-load.sh
```

## Using Test Cases for Load Generation

Your existing test cases are excellent for generating realistic load patterns and dashboard activity.

### Available Test Cases

| Test File | Purpose | Dashboard Impact |
|---|---|---|
| `t1-infrastructure.py` | Cluster validation | Shows node status, cluster health metrics |
| `t2-multi-node.py` | Multi-node testing | Node distribution and scheduling activity |
| `t3-nginx-access.py` | HTTP traffic generation | Network metrics, service response times |
| `t4-validate-deployment.py` | Deployment validation | Deployment status, replica scaling |
| `t5-argocd-tests.py` | GitOps validation | ArgoCD activity, sync operations |
| `t6-cicd-tests.py` | CI/CD pipeline tests | Build and deployment metrics |
| `t8-monitoring-tests.py` | Monitoring stack tests | Prometheus scraping, alerting activity |
| `t9-monitoring-status-tests.py` | Status validation | Service health, endpoint monitoring |

### Test-Based Load Generation Patterns

#### 1. Continuous Single Test
```bash
# Run infrastructure tests repeatedly
for i in {1..10}; do 
    python3 -m pytest test/t1-infrastructure.py -v
    sleep 2
done
```

#### 2. HTTP Traffic Generation
```bash
# Generate network activity and service requests
for i in {1..15}; do 
    python3 -m pytest test/t3-nginx-access.py -v
    sleep 1
done
```

#### 3. Deployment Activity
```bash
# Create deployment validation activity
for i in {1..8}; do 
    python3 -m pytest test/t4-validate-deployment.py -v
    sleep 2
done
```

#### 4. Parallel Mixed Load
```bash
# Run multiple test types simultaneously
python3 -m pytest test/t1-infrastructure.py -v &
python3 -m pytest test/t3-nginx-access.py -v &
python3 -m pytest test/t4-validate-deployment.py -v &
python3 -m pytest test/t8-monitoring-tests.py -v &
wait
```

#### 5. Full Test Suite Loop
```bash
# Run comprehensive test cycles
for i in {1..3}; do
    echo "Test cycle $i/3"
    python3 -m pytest test/t1-infrastructure.py test/t3-nginx-access.py test/t4-validate-deployment.py test/t8-monitoring-tests.py -v --tb=no
    sleep 3
done
```

## Dashboard-Specific Load Generation

### For Infrastructure Dashboards (315, 6417, 7249)
**Best Tests**: `t1-infrastructure.py`, `t2-multi-node.py`
```bash
# Generate cluster-wide activity
./scripts/generate-test-load.sh  # Choose option 1
```
**Shows**: Node metrics, cluster health, resource utilization

### For Workload Dashboards (747, 8588, 6336)
**Best Tests**: `t4-validate-deployment.py`, `t3-nginx-access.py`
```bash
# Generate deployment and pod activity
./scripts/generate-test-load.sh  # Choose option 2 or 3
```
**Shows**: Deployment scaling, pod creation/deletion, workload distribution

### For Networking Dashboards (7645, 9614)
**Best Tests**: `t3-nginx-access.py`
```bash
# Generate HTTP traffic
for i in {1..20}; do 
    python3 -m pytest test/t3-nginx-access.py -v
    sleep 0.5
done
```
**Shows**: Network traffic, ingress metrics, service response times

### For Monitoring Dashboards (3662, 9578)
**Best Tests**: `t8-monitoring-tests.py`, `t9-monitoring-status-tests.py`
```bash
# Generate monitoring system activity
./scripts/generate-test-load.sh  # Choose option 4
```
**Shows**: Prometheus scraping, alerting activity, monitoring stack health

## Manual Load Generation Methods

### 1. CPU Load Generation
```bash
# Create CPU-intensive pods
kubectl run cpu-load-1 --image=busybox -- sh -c "while true; do :; done"
kubectl run cpu-load-2 --image=busybox -- sh -c "while true; do :; done"
kubectl run cpu-load-3 --image=busybox -- sh -c "while true; do :; done"
```

### 2. Memory Load Generation
```bash
# Create memory-intensive pods
kubectl run memory-load --image=busybox -- sh -c "for i in {1..10}; do dd if=/dev/zero of=/tmp/file\$i bs=1M count=50; done; sleep 300"
```

### 3. Network Traffic Generation
```bash
# Generate HTTP requests to existing services
kubectl run traffic-gen --image=busybox --rm -it -- sh -c "
for i in {1..100}; do 
    wget -q -O- http://nginx-service/ || true
    sleep 0.1
done"
```

### 4. Scaling Activity
```bash
# Create deployment scaling activity
kubectl scale deployment nginx-deployment --replicas=5
sleep 10
kubectl scale deployment nginx-deployment --replicas=2
sleep 10
kubectl scale deployment nginx-deployment --replicas=8
```

## Best Practices for Dashboard Testing

### 1. Grafana Settings for Load Testing
- **Time Range**: Set to "Last 15 minutes" or "Last 30 minutes"
- **Refresh Rate**: Set to 5s or 10s for real-time updates
- **Auto-refresh**: Enable for continuous monitoring

### 2. Monitoring Load Generation
```bash
# Watch pod activity during tests
kubectl get pods -w

# Monitor resource usage
kubectl top pods -A
kubectl top nodes

# Check test progress
watch kubectl get deployments
```

### 3. Load Generation Timing
- **Short bursts**: 1-2 minute test runs for immediate feedback
- **Sustained load**: 5-10 minute runs for trend analysis
- **Parallel execution**: Multiple test types for complex scenarios

### 4. Clean Up After Testing
```bash
# Remove test-generated pods
kubectl delete pod cpu-load-1 cpu-load-2 cpu-load-3 memory-load traffic-gen

# Remove test deployments
kubectl delete deployment cpu-load-test memory-load-test test-web-server

# Remove test services
kubectl delete service test-web-service
```

## Recommended Dashboard Import Order for Testing

1. **Dashboard 315** - Start here for overall cluster monitoring
2. **Dashboard 747** - Add for deployment activity visibility
3. **Dashboard 6336** - Include for pod-level metrics
4. **Dashboard 8588** - Comprehensive workload monitoring
5. **Dashboard 3662** - Prometheus monitoring metrics

## Troubleshooting Load Generation

### No Data Appearing in Dashboards
1. Check Prometheus data source connection
2. Verify time range is appropriate (last 15-30 minutes)
3. Ensure tests are actually running: `kubectl get pods`
4. Check Prometheus targets: http://localhost:9090/targets

### Low Activity in Dashboards
- Run parallel tests for more activity
- Use continuous test loops
- Combine test-based and manual load generation
- Scale up number of test iterations

### High Resource Usage
- Reduce test frequency (increase sleep intervals)
- Run fewer parallel tests
- Monitor cluster resources: `kubectl top nodes`
- Clean up test pods regularly

## Example Dashboard Testing Session

```bash
# 1. Start monitoring services
./scripts/launch-monitoring.sh

# 2. Import Dashboard 315 in Grafana
# 3. Set time range to "Last 15 minutes", refresh to 5s

# 4. Generate mixed load
./scripts/generate-test-load.sh  # Choose option 5 (parallel mixed)

# 5. Watch dashboards update in real-time
# 6. Try different test patterns for various metrics

# 7. Clean up when done
kubectl delete pod --all --selector='run in (cpu-load-1,cpu-load-2,memory-load,traffic-gen)'
```

This approach gives you realistic, varied load patterns that showcase all aspects of your Kubernetes monitoring stack in Grafana dashboards.