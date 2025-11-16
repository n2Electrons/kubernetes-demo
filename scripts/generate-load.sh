#!/bin/bash

# Generate load to create dynamic dashboard data
echo "Generating load for dynamic Grafana dashboard content..."

# Check if we have deployments to work with
echo "Checking available deployments..."
kubectl get deployments -A

echo ""
echo "Available load generation options:"
echo "1. Create test pods that consume CPU/memory"
echo "2. Generate HTTP traffic to existing services"
echo "3. Scale deployments up and down"
echo "4. Create and delete resources"

# Function to create CPU load pods
create_cpu_load() {
    echo "Creating CPU load pods..."
    kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cpu-load-test
  namespace: default
spec:
  replicas: 3
  selector:
    matchLabels:
      app: cpu-load
  template:
    metadata:
      labels:
        app: cpu-load
    spec:
      containers:
      - name: cpu-load
        image: busybox
        command: ["sh", "-c", "while true; do echo 'generating cpu load'; done"]
        resources:
          requests:
            cpu: 100m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 128Mi
EOF
}

# Function to create memory load pods
create_memory_load() {
    echo "Creating memory load pods..."
    kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: memory-load-test
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: memory-load
  template:
    metadata:
      labels:
        app: memory-load
    spec:
      containers:
      - name: memory-load
        image: busybox
        command: ["sh", "-c", "for i in {1..10}; do dd if=/dev/zero of=/tmp/file\$i bs=1M count=50; done; sleep 300"]
        resources:
          requests:
            cpu: 50m
            memory: 128Mi
          limits:
            cpu: 100m
            memory: 256Mi
EOF
}

# Function to generate HTTP traffic
generate_http_traffic() {
    echo "Generating HTTP traffic..."
    
    # Check if nginx service exists
    nginx_service=$(kubectl get svc nginx-service -n default --no-headers 2>/dev/null | awk '{print $1}' || echo "")
    
    if [ -n "$nginx_service" ]; then
        echo "Found nginx service, generating traffic..."
        kubectl run traffic-generator --image=busybox --rm -it --restart=Never -- sh -c "
        for i in {1..1000}; do 
            wget -q -O- http://nginx-service.default.svc.cluster.local/ || true
            sleep 0.1
        done"
    else
        echo "No nginx service found, creating a simple web server for traffic..."
        kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-web-server
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: test-web
  template:
    metadata:
      labels:
        app: test-web
    spec:
      containers:
      - name: web
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: test-web-service
  namespace: default
spec:
  selector:
    app: test-web
  ports:
  - port: 80
    targetPort: 80
EOF
        
        echo "Waiting for web server to be ready..."
        kubectl wait --for=condition=ready pod -l app=test-web --timeout=60s
        
        echo "Generating traffic to test web server..."
        kubectl run traffic-generator --image=busybox --rm -it --restart=Never -- sh -c "
        for i in {1..500}; do 
            wget -q -O- http://test-web-service.default.svc.cluster.local/ || true
            sleep 0.2
        done"
    fi
}

# Function to scale deployments
scale_deployments() {
    echo "Scaling deployments to generate activity..."
    
    deployments=$(kubectl get deployments --no-headers -o custom-columns=":metadata.name")
    
    for deployment in $deployments; do
        echo "Scaling $deployment..."
        kubectl scale deployment $deployment --replicas=3
        sleep 2
        kubectl scale deployment $deployment --replicas=1
        sleep 2
    done
}

# Interactive menu
echo ""
read -p "Which load would you like to generate? (1-4): " choice

case $choice in
    1)
        create_cpu_load
        create_memory_load
        echo "CPU and memory load pods created. Check Dashboard 315 or 6336 for pod metrics."
        ;;
    2)
        generate_http_traffic
        echo "HTTP traffic generated. Check Dashboard 9614 for ingress metrics or 315 for general activity."
        ;;
    3)
        scale_deployments
        echo "Deployment scaling completed. Check Dashboard 747 for deployment activity."
        ;;
    4)
        create_cpu_load
        create_memory_load
        generate_http_traffic &
        scale_deployments
        echo "All load types generated! Your dashboards should show activity now."
        ;;
    *)
        echo "Invalid choice. Run the script again with a valid option (1-4)."
        ;;
esac

echo ""
echo "Load generation complete! Go to Grafana and check these dashboards:"
echo "- Dashboard 315: Kubernetes cluster monitoring (overall activity)"
echo "- Dashboard 747: Kubernetes deployments (scaling activity)" 
echo "- Dashboard 6336: Kubernetes pods (pod-level metrics)"
echo "- Dashboard 8588: All workload types"
echo ""
echo "To clean up test resources later:"
echo "kubectl delete deployment cpu-load-test memory-load-test test-web-server"
echo "kubectl delete service test-web-service"