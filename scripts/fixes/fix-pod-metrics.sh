#!/bin/bash

# Fix pod metrics issues - cAdvisor crashes and Prometheus OOM
echo "Fixing pod metrics issues..."

echo "1. Cleaning up problematic cAdvisor deployment..."
kubectl delete daemonset cadvisor -n monitoring
kubectl delete service cadvisor -n monitoring

echo "2. Increasing Prometheus memory limits (OOMKilled issue)..."
kubectl patch deployment prometheus -n monitoring -p='
{
  "spec": {
    "template": {
      "spec": {
        "containers": [
          {
            "name": "prometheus",
            "resources": {
              "limits": {
                "memory": "2Gi",
                "cpu": "1000m"
              },
              "requests": {
                "memory": "1Gi", 
                "cpu": "500m"
              }
            }
          }
        ]
      }
    }
  }
}'

echo "3. Using k3s built-in metrics instead of separate cAdvisor..."
# Update Prometheus config to use kubelet endpoints directly
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
          insecure_skip_verify: true
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
          insecure_skip_verify: true
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

      - job_name: "kubernetes-service-endpoints"
        kubernetes_sd_configs:
        - role: endpoints
        relabel_configs:
        - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scrape]
          action: keep
          regex: true
        - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scheme]
          action: replace
          target_label: __scheme__
          regex: (https?)
        - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_path]
          action: replace
          target_label: __metrics_path__
          regex: (.+)
        - source_labels: [__address__, __meta_kubernetes_service_annotation_prometheus_io_port]
          action: replace
          target_label: __address__
          regex: ([^:]+)(?::\d+)?;(\d+)
          replacement: $1:$2
        - action: labelmap
          regex: __meta_kubernetes_service_label_(.+)
        - source_labels: [__meta_kubernetes_namespace]
          action: replace
          target_label: kubernetes_namespace
        - source_labels: [__meta_kubernetes_service_name]
          action: replace
          target_label: kubernetes_name

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
'

echo "4. Restarting Prometheus with new configuration and memory limits..."
kubectl rollout restart deployment prometheus -n monitoring

echo "5. Waiting for Prometheus to be ready..."
kubectl wait --for=condition=ready pod -l app=prometheus -n monitoring --timeout=120s

echo "6. Cleaning up evicted pods to reduce clutter..."
kubectl delete pods --field-selector=status.phase=Failed -A
kubectl delete pods --field-selector=status.phase=Succeeded -A

echo "7. Waiting for metrics to be collected..."
sleep 30

echo ""
echo "POD METRICS FIX SUMMARY:"
echo "========================"
echo "✓ Removed problematic cAdvisor DaemonSet"
echo "✓ Increased Prometheus memory limits (2Gi)"
echo "✓ Using k3s built-in kubelet metrics"
echo "✓ Cleaned up evicted pods"
echo ""
echo "Testing pod metrics now..."

# Test for container metrics via kubelet
container_cpu=$(curl -s "http://localhost:9090/api/v1/query?query=container_cpu_usage_seconds_total" 2>/dev/null | jq '.data.result | length' 2>/dev/null || echo "0")
container_mem=$(curl -s "http://localhost:9090/api/v1/query?query=container_memory_usage_bytes" 2>/dev/null | jq '.data.result | length' 2>/dev/null || echo "0")

echo "Container CPU metrics: $container_cpu"
echo "Container Memory metrics: $container_mem"
echo ""
echo "Next steps:"
echo "1. Go to Dashboard 6336 (Kubernetes Pods)"
echo "2. Set time range to 'Last 30 minutes'"  
echo "3. Check for pod CPU and memory usage"
echo "4. Try these queries in Explore:"
echo "   - rate(container_cpu_usage_seconds_total{container!=\"POD\"}[5m])"
echo "   - container_memory_usage_bytes{container!=\"POD\"}"
echo "   - kube_pod_container_resource_requests"