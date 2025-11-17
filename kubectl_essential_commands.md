# Essential kubectl Commands - Curated History
# Most important commands by category (2-3 per section)

# === CLUSTER & NODES ===
kubectl get nodes -o wide
kubectl top nodes

# === APPLICATION DEPLOYMENT ===
kubectl get pods -n kub-app
kubectl describe deployment kub-app -n kub-app
kubectl rollout status deployment/kub-app -n kub-app

# === MONITORING STACK ===
kubectl get pods -n monitoring
kubectl port-forward -n monitoring svc/prometheus 9090:9090 &
kubectl port-forward svc/grafana 3002:3000 -n monitoring

# === ARGOCD GITOPS ===
kubectl get applications -n argocd
kubectl port-forward svc/argocd-server -n argocd 8080:80 &
kubectl apply -f argocd/applications/kub-app.yaml

# === SCALING & HPA ===
kubectl get hpa kub-app-hpa -n kub-app -o wide
kubectl scale deployment kub-app --replicas=3 -n kub-app

# === TROUBLESHOOTING ===
kubectl logs -n argocd argocd-application-controller-0 --tail=10
kubectl get events -n kub-app --sort-by='.lastTimestamp'

# === SERVICES & NETWORKING ===
kubectl get svc -n kub-app
kubectl port-forward -n kub-app svc/kub-app-service 10350:80 &