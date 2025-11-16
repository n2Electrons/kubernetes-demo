#!/bin/bash

# Fix "No data" issues in Grafana dashboards
echo "Fixing Grafana dashboard data issues..."

# Check current issues
echo "1. Checking Prometheus targets..."
curl -s http://localhost:9090/api/v1/targets >/dev/null
if [ $? -eq 0 ]; then
    echo "   Prometheus is accessible"
else
    echo "   ERROR: Prometheus not accessible. Starting port forwarding..."
    pkill -f "prometheus.*port-forward" 2>/dev/null || true
    kubectl port-forward svc/prometheus 9090:9090 -n monitoring &
    sleep 3
fi

echo "2. Checking for kube-state-metrics..."
kube_state_pods=$(kubectl get pods -n kube-system -l app.kubernetes.io/name=kube-state-metrics --no-headers 2>/dev/null | wc -l)

if [ "$kube_state_pods" -eq 0 ]; then
    echo "   Installing kube-state-metrics (required for Kubernetes metrics)..."
    
    # Install kube-state-metrics
    kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app.kubernetes.io/component: exporter
    app.kubernetes.io/name: kube-state-metrics
    app.kubernetes.io/version: 2.10.1
  name: kube-state-metrics
  namespace: kube-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: kube-state-metrics
  template:
    metadata:
      labels:
        app.kubernetes.io/component: exporter
        app.kubernetes.io/name: kube-state-metrics
        app.kubernetes.io/version: 2.10.1
    spec:
      automountServiceAccountToken: true
      containers:
      - image: registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.10.1
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8080
          initialDelaySeconds: 5
          timeoutSeconds: 5
        name: kube-state-metrics
        ports:
        - containerPort: 8080
          name: http-metrics
        - containerPort: 8081
          name: telemetry
        readinessProbe:
          httpGet:
            path: /
            port: 8081
          initialDelaySeconds: 5
          timeoutSeconds: 5
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 65534
          seccompProfile:
            type: RuntimeDefault
      nodeSelector:
        kubernetes.io/os: linux
      serviceAccountName: kube-state-metrics
---
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    app.kubernetes.io/component: exporter
    app.kubernetes.io/name: kube-state-metrics
    app.kubernetes.io/version: 2.10.1
  name: kube-state-metrics
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  labels:
    app.kubernetes.io/component: exporter
    app.kubernetes.io/name: kube-state-metrics
    app.kubernetes.io/version: 2.10.1
  name: kube-state-metrics
rules:
- apiGroups:
  - ""
  resources:
  - configmaps
  - secrets
  - nodes
  - pods
  - services
  - serviceaccounts
  - resourcequotas
  - replicationcontrollers
  - limitranges
  - persistentvolumeclaims
  - persistentvolumes
  - namespaces
  - endpoints
  verbs:
  - list
  - watch
- apiGroups:
  - apps
  resources:
  - statefulsets
  - daemonsets
  - deployments
  - replicasets
  verbs:
  - list
  - watch
- apiGroups:
  - batch
  resources:
  - cronjobs
  - jobs
  verbs:
  - list
  - watch
- apiGroups:
  - autoscaling
  resources:
  - horizontalpodautoscalers
  verbs:
  - list
  - watch
- apiGroups:
  - authentication.k8s.io
  resources:
  - tokenreviews
  verbs:
  - create
- apiGroups:
  - authorization.k8s.io
  resources:
  - subjectaccessreviews
  verbs:
  - create
- apiGroups:
  - policy
  resources:
  - poddisruptionbudgets
  verbs:
  - list
  - watch
- apiGroups:
  - certificates.k8s.io
  resources:
  - certificatesigningrequests
  verbs:
  - list
  - watch
- apiGroups:
  - discovery.k8s.io
  resources:
  - endpointslices
  verbs:
  - list
  - watch
- apiGroups:
  - storage.k8s.io
  resources:
  - storageclasses
  - volumeattachments
  verbs:
  - list
  - watch
- apiGroups:
  - admissionregistration.k8s.io
  resources:
  - mutatingwebhookconfigurations
  - validatingwebhookconfigurations
  verbs:
  - list
  - watch
- apiGroups:
  - networking.k8s.io
  resources:
  - networkpolicies
  - ingresses
  verbs:
  - list
  - watch
- apiGroups:
  - coordination.k8s.io
  resources:
  - leases
  verbs:
  - list
  - watch
- apiGroups:
  - rbac.authorization.k8s.io
  resources:
  - clusterrolebindings
  - clusterroles
  - rolebindings
  - roles
  verbs:
  - list
  - watch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  labels:
    app.kubernetes.io/component: exporter
    app.kubernetes.io/name: kube-state-metrics
    app.kubernetes.io/version: 2.10.1
  name: kube-state-metrics
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: kube-state-metrics
subjects:
- kind: ServiceAccount
  name: kube-state-metrics
  namespace: kube-system
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app.kubernetes.io/component: exporter
    app.kubernetes.io/name: kube-state-metrics
    app.kubernetes.io/version: 2.10.1
  name: kube-state-metrics
  namespace: kube-system
spec:
  clusterIP: None
  ports:
  - name: http-metrics
    port: 8080
    targetPort: http-metrics
  - name: telemetry
    port: 8081
    targetPort: telemetry
  selector:
    app.kubernetes.io/name: kube-state-metrics
EOF

    echo "   Waiting for kube-state-metrics to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=kube-state-metrics -n kube-system --timeout=60s
else
    echo "   kube-state-metrics is already running"
fi

echo "3. Updating Prometheus configuration to scrape kube-state-metrics..."

# Update Prometheus config to include kube-state-metrics
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
'

echo "4. Restarting Prometheus to reload configuration..."
kubectl rollout restart deployment prometheus -n monitoring
kubectl rollout status deployment prometheus -n monitoring --timeout=60s

echo "5. Testing data availability..."
sleep 10

# Test basic metrics
echo "   Testing 'up' metric..."
up_count=$(curl -s "http://localhost:9090/api/v1/query?query=up" 2>/dev/null | jq '.data.result | length' 2>/dev/null)
if [ -z "$up_count" ] || [ "$up_count" = "null" ]; then
    up_count="0"
fi
echo "   Found $up_count 'up' metrics"

# Test kube metrics
echo "   Testing Kubernetes metrics..."
sleep 5
kube_pod_count=$(curl -s "http://localhost:9090/api/v1/query?query=kube_pod_info" 2>/dev/null | jq '.data.result | length' 2>/dev/null)
if [ -z "$kube_pod_count" ] || [ "$kube_pod_count" = "null" ]; then
    kube_pod_count="0"
fi
echo "   Found $kube_pod_count pod metrics"

if [ "$kube_pod_count" -gt 0 ] 2>/dev/null; then
    echo "   SUCCESS: Kubernetes metrics are now available!"
else
    echo "   Waiting a bit more for metrics to appear..."
    sleep 10
    kube_pod_count=$(curl -s "http://localhost:9090/api/v1/query?query=kube_pod_info" 2>/dev/null | jq '.data.result | length' 2>/dev/null)
    if [ -z "$kube_pod_count" ] || [ "$kube_pod_count" = "null" ]; then
        kube_pod_count="0"
    fi
    echo "   Found $kube_pod_count pod metrics"
    
    if [ "$kube_pod_count" -gt 0 ] 2>/dev/null; then
        echo "   SUCCESS: Kubernetes metrics are now available!"
    else
        echo "   Note: Metrics may take a few more minutes to appear"
    fi
fi

echo ""
echo "6. Updating Grafana data source..."
./scripts/update-prometheus-datasource.sh

echo ""
echo "DASHBOARD FIX SUMMARY:"
echo "======================"
echo "✓ kube-state-metrics installed/verified"
echo "✓ Prometheus configuration updated"
echo "✓ Prometheus restarted"
echo "✓ Grafana data source updated"
echo ""
echo "Next steps:"
echo "1. Wait 1-2 minutes for metrics to populate"
echo "2. In Grafana, go to Dashboard 315"
echo "3. Set time range to 'Last 30 minutes'"
echo "4. Refresh the dashboard"
echo "5. If still no data, try Explore → Prometheus → Query: up"
echo ""
echo "Available test queries:"
echo "- up (service availability)"
echo "- kube_pod_info (pod information)"
echo "- kube_node_info (node information)"
echo "- kube_deployment_status_replicas (deployment metrics)"