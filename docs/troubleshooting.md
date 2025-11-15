# Troubleshooting Guide

## Common Issues and Solutions

### 1. Cluster Status Checks

**Check if cluster nodes are running:**
```bash
kubectl get nodes
kubectl get nodes -o wide
```

**Check all pods across namespaces:**
```bash
kubectl get pods -A
kubectl get pods -A -o wide
```

**Check specific namespace:**
```bash
kubectl get pods -n kube-system
kubectl get pods -n kub-app
```

### 2. Pod Troubleshooting

**Describe a pod for detailed information:**
```bash
kubectl describe pod <pod-name> -n <namespace>
```

**View pod logs:**
```bash
kubectl logs <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> -f  # Follow logs
```

**Execute commands inside a pod:**
```bash
kubectl exec -it <pod-name> -n <namespace> -- sh
kubectl exec -it <pod-name> -n <namespace> -- /bin/bash
```

### 3. Service and Network Checks

**List all services:**
```bash
kubectl get svc -A
kubectl get svc -n kub-app
```

**Check ingress resources:**
```bash
kubectl get ingress -A
kubectl describe ingress <ingress-name> -n <namespace>
```

**Port forward to test services locally:**
```bash
kubectl port-forward svc/<service-name> 8080:80 -n <namespace>
```

### 4. Resource Status

**Check deployments:**
```bash
kubectl get deployments -A
kubectl rollout status deployment/<deployment-name> -n <namespace>
```

**Check replica sets:**
```bash
kubectl get rs -A
```

**Check horizontal pod autoscalers:**
```bash
kubectl get hpa -A
kubectl describe hpa <hpa-name> -n <namespace>
```

### 5. Cluster Events

**View recent cluster events:**
```bash
kubectl get events --sort-by='.lastTimestamp'
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

### 6. Resource Usage

**Check node resource usage:**
```bash
kubectl top nodes
```

**Check pod resource usage:**
```bash
kubectl top pods -A
kubectl top pods -n <namespace>
```

### 7. Common Error Solutions

#### ERR_EMPTY_RESPONSE on localhost:8080
- **Cause:** No application deployed or service not exposed
- **Solution:** Deploy application manifests and ensure service/ingress is configured

#### Pods in Pending state
- **Check:** `kubectl describe pod <pod-name>`
- **Common causes:** Resource constraints, scheduling issues, PVC binding problems

#### Pods in CrashLoopBackOff
- **Check:** `kubectl logs <pod-name>`
- **Common causes:** Application configuration errors, missing dependencies

#### ImagePullBackOff errors
- **Check:** Image name and tag are correct
- **Solution:** Verify image exists in registry or use different image

### 8. K3d Specific Commands

**List k3d clusters:**
```bash
k3d cluster list
```

**Stop/Start cluster:**
```bash
k3d cluster stop demo
k3d cluster start demo
```

**Delete and recreate cluster:**
```bash
k3d cluster delete demo
./scripts/setup-cluster.sh
```

### 9. Reset Commands

**Delete all resources in namespace:**
```bash
kubectl delete all --all -n <namespace>
```

**Reset cluster (nuclear option):**
```bash
./scripts/cleanup-cluster.sh
./scripts/setup-cluster.sh
```