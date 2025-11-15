#!/bin/bash
# Deploy the kub-app to the multi-node cluster

set -e

echo "Deploying kub-app to multi-node cluster..."

# Apply namespace first
kubectl apply -f apps/kub-app/namespace.yaml

# Wait a moment for namespace propagation
sleep 2

# Apply other resources
kubectl apply -f apps/kub-app/deployment.yaml
kubectl apply -f apps/kub-app/service.yaml
kubectl apply -f apps/kub-app/ingress.yaml
kubectl apply -f apps/kub-app/hpa.yaml

echo "Waiting for deployment to be ready..."
kubectl rollout status deployment/kub-app -n kub-app

echo "Checking pods distribution across nodes..."
kubectl get pods -n kub-app -o wide

echo "Checking service..."
kubectl get svc -n kub-app

echo "Checking ingress..."
kubectl get ingress -n kub-app

echo "Deployment complete!"
echo "Access your app at: http://kub-app.local:8080"
echo "Or add '127.0.0.1 kub-app.local' to your /etc/hosts file"
