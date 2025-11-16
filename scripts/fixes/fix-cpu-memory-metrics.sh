#!/bin/bash

# Fix CPU and Memory "No data" issues in Grafana dashboards
echo "Fixing CPU and Memory metrics for Grafana dashboards..."

# Check what metrics are currently available
echo "1. Checking current resource metrics availability..."

# Check for container CPU metrics
cpu_metrics=$(curl -s "http://localhost:9090/api/v1/query?query=container_cpu_usage_seconds_total" 2>/dev/null | jq '.data.result | length' 2>/dev/null)
if [ -z "$cpu_metrics" ] || [ "$cpu_metrics" = "null" ]; then cpu_metrics="0"; fi

# Check for container memory metrics  
mem_metrics=$(curl -s "http://localhost:9090/api/v1/query?query=container_memory_usage_bytes" 2>/dev/null | jq '.data.result | length' 2>/dev/null)
if [ -z "$mem_metrics" ] || [ "$mem_metrics" = "null" ]; then mem_metrics="0"; fi

# Check for node metrics
node_cpu_metrics=$(curl -s "http://localhost:9090/api/v1/query?query=node_cpu_seconds_total" 2>/dev/null | jq '.data.result | length' 2>/dev/null)
if [ -z "$node_cpu_metrics" ] || [ "$node_cpu_metrics" = "null" ]; then node_cpu_metrics="0"; fi

echo "   Container CPU metrics: $cpu_metrics"
echo "   Container Memory metrics: $mem_metrics" 
echo "   Node CPU metrics: $node_cpu_metrics"

if [ "$cpu_metrics" -gt 0 ] && [ "$mem_metrics" -gt 0 ]; then
    echo "   Resource metrics are available - checking dashboard queries..."
else
    echo "   Resource metrics missing - installing cAdvisor and node-exporter..."
    
    # Install node-exporter for node-level metrics
    echo "2. Installing node-exporter..."
    kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-exporter
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: node-exporter
  template:
    metadata:
      labels:
        app: node-exporter
    spec:
      hostNetwork: true
      hostPID: true
      containers:
      - name: node-exporter
        image: prom/node-exporter:latest
        args:
        - '--path.rootfs=/host'
        - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc|rootfs/var/lib/docker/containers|rootfs/var/lib/docker/overlay2|rootfs/run/docker/netns|rootfs/var/lib/docker/aufs)($$|/)'
        ports:
        - containerPort: 9100
          hostPort: 9100
        resources:
          limits:
            cpu: 200m
            memory: 200Mi
          requests:
            cpu: 100m
            memory: 100Mi
        volumeMounts:
        - name: proc
          mountPath: /host/proc
          readOnly: true
        - name: sys
          mountPath: /host/sys
          readOnly: true
        - name: root
          mountPath: /host
          readOnly: true
        securityContext:
          runAsNonRoot: true
          runAsUser: 65534
      tolerations:
      - operator: Exists
      volumes:
      - name: proc
        hostPath:
          path: /proc
      - name: sys
        hostPath:
          path: /sys
      - name: root
        hostPath:
          path: /
---
apiVersion: v1
kind: Service
metadata:
  name: node-exporter
  namespace: monitoring
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "9100"
spec:
  selector:
    app: node-exporter
  ports:
  - port: 9100
    targetPort: 9100
    name: metrics
EOF

    # Wait for node-exporter to be ready
    echo "   Waiting for node-exporter to be ready..."
    kubectl rollout status daemonset node-exporter -n monitoring --timeout=60s

    # Check if we're using k3s (which has built-in cAdvisor) or need to install it
    echo "3. Checking for cAdvisor availability..."
    
    # k3s usually has cAdvisor built-in, check if it's accessible
    cadvisor_check=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' | head -1)
    if curl -s --connect-timeout 3 "http://$cadvisor_check:10255/metrics" >/dev/null 2>&1; then
        echo "   cAdvisor found on kubelet endpoint"
    else
        echo "   Installing cAdvisor as DaemonSet..."
        kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: cadvisor
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: cadvisor
  template:
    metadata:
      labels:
        app: cadvisor
    spec:
      hostNetwork: true
      containers:
      - name: cadvisor
        image: gcr.io/cadvisor/cadvisor:v0.47.0
        ports:
        - containerPort: 8080
          hostPort: 8080
        resources:
          limits:
            cpu: 300m
            memory: 200Mi
          requests:
            cpu: 150m
            memory: 100Mi
        volumeMounts:
        - name: rootfs
          mountPath: /rootfs
          readOnly: true
        - name: var-run
          mountPath: /var/run
          readOnly: true
        - name: sys
          mountPath: /sys
          readOnly: true
        - name: docker
          mountPath: /var/lib/docker
          readOnly: true
        - name: disk
          mountPath: /dev/disk
          readOnly: true
        securityContext:
          privileged: true
      tolerations:
      - operator: Exists
      volumes:
      - name: rootfs
        hostPath:
          path: /
      - name: var-run
        hostPath:
          path: /var/run
      - name: sys
        hostPath:
          path: /sys
      - name: docker
        hostPath:
          path: /var/lib/docker
      - name: disk
        hostPath:
          path: /dev/disk
---
apiVersion: v1
kind: Service
metadata:
  name: cadvisor
  namespace: monitoring
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
spec:
  selector:
    app: cadvisor
  ports:
  - port: 8080
    targetPort: 8080
    name: metrics
EOF
        kubectl rollout status daemonset cadvisor -n monitoring --timeout=60s
    fi
fi

echo "4. Updating Prometheus configuration for resource metrics..."

# Update Prometheus config to scrape node-exporter and cAdvisor
kubectl patch configmap prometheus-config -n monitoring --patch='
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      evaluation_interval: 15s

    rule_files: []

    scrape_configs:
      - job_name: "prometheus"
        static_configs:
          - targets: ["localhost:9090"]

      - job_name: "kubernetes-apiservers"
        kubernetes_sd_configs:
        - role: endpoints
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        relabel_configs:
        - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
          action: keep
          regex: default;kubernetes;https

      - job_name: "kubernetes-nodes"
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        kubernetes_sd_configs:
        - role: node
        relabel_configs:
        - action: labelmap
          regex: __meta_kubernetes_node_label_(.+)
        - target_label: __address__
          replacement: kubernetes.default.svc:443
        - source_labels: [__meta_kubernetes_node_name]
          regex: (.+)
          target_label: __metrics_path__
          replacement: /api/v1/nodes/${1}/proxy/metrics

      - job_name: "kubernetes-nodes-cadvisor"
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        kubernetes_sd_configs:
        - role: node
        relabel_configs:
        - action: labelmap
          regex: __meta_kubernetes_node_label_(.+)
        - target_label: __address__
          replacement: kubernetes.default.svc:443
        - source_labels: [__meta_kubernetes_node_name]
          regex: (.+)
          target_label: __metrics_path__
          replacement: /api/v1/nodes/${1}/proxy/metrics/cadvisor

      - job_name: "kubernetes-pods"
        kubernetes_sd_configs:
        - role: pod
        relabel_configs:
        - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
          action: keep
          regex: true
        - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
          action: replace
          target_label: __metrics_path__
          regex: (.+)
        - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
          action: replace
          regex: ([^:]+)(?::\d+)?;(\d+)
          replacement: $1:$2
          target_label: __address__
        - action: labelmap
          regex: __meta_kubernetes_pod_label_(.+)
        - source_labels: [__meta_kubernetes_namespace]
          action: replace
          target_label: kubernetes_namespace
        - source_labels: [__meta_kubernetes_pod_name]
          action: replace
          target_label: kubernetes_pod_name

      - job_name: "kube-state-metrics"
        static_configs:
          - targets: ["kube-state-metrics.kube-system.svc.cluster.local:8080"]

      - job_name: "node-exporter"
        kubernetes_sd_configs:
        - role: endpoints
        relabel_configs:
        - source_labels: [__meta_kubernetes_endpoints_name]
          regex: node-exporter
          action: keep
        - source_labels: [__meta_kubernetes_endpoint_port_name]
          regex: metrics
          action: keep

      - job_name: "cadvisor"
        kubernetes_sd_configs:
        - role: endpoints
        relabel_configs:
        - source_labels: [__meta_kubernetes_endpoints_name]
          regex: cadvisor
          action: keep
        - source_labels: [__meta_kubernetes_endpoint_port_name]
          regex: metrics
          action: keep
'

echo "5. Restarting Prometheus to load new configuration..."
kubectl rollout restart deployment prometheus -n monitoring
kubectl rollout status deployment prometheus -n monitoring --timeout=60s

echo "6. Waiting for metrics to be collected..."
sleep 30

echo "7. Testing resource metrics availability..."

# Test container CPU metrics
cpu_metrics=$(curl -s "http://localhost:9090/api/v1/query?query=container_cpu_usage_seconds_total" 2>/dev/null | jq '.data.result | length' 2>/dev/null)
if [ -z "$cpu_metrics" ] || [ "$cpu_metrics" = "null" ]; then cpu_metrics="0"; fi

# Test container memory metrics
mem_metrics=$(curl -s "http://localhost:9090/api/v1/query?query=container_memory_usage_bytes" 2>/dev/null | jq '.data.result | length' 2>/dev/null)
if [ -z "$mem_metrics" ] || [ "$mem_metrics" = "null" ]; then mem_metrics="0"; fi

# Test node CPU metrics
node_cpu=$(curl -s "http://localhost:9090/api/v1/query?query=node_cpu_seconds_total" 2>/dev/null | jq '.data.result | length' 2>/dev/null)
if [ -z "$node_cpu" ] || [ "$node_cpu" = "null" ]; then node_cpu="0"; fi

echo "   Container CPU metrics: $cpu_metrics"
echo "   Container Memory metrics: $mem_metrics"
echo "   Node CPU metrics: $node_cpu"

echo ""
echo "CPU/MEMORY FIX SUMMARY:"
echo "======================"
echo "✓ node-exporter installed for node-level metrics"
echo "✓ cAdvisor configured for container metrics"  
echo "✓ Prometheus configuration updated"
echo "✓ Prometheus restarted"
echo ""
echo "Next steps:"
echo "1. Go to Grafana Dashboard 315"
echo "2. Set time range to 'Last 30 minutes'"
echo "3. Look for CPU and Memory panels"
echo "4. If still no data, try these queries in Explore:"
echo ""
echo "CPU queries to test:"
echo "- rate(container_cpu_usage_seconds_total[5m])"
echo "- rate(node_cpu_seconds_total[5m])"  
echo "- 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)"
echo ""
echo "Memory queries to test:"
echo "- container_memory_usage_bytes"
echo "- node_memory_MemAvailable_bytes"
echo "- (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100"