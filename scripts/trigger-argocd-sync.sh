#!/bin/bash
echo "=== Triggering ArgoCD Sync for kub-app Application ==="

# Method 1: Force refresh annotation
echo "Setting refresh annotation..."
kubectl annotate application kub-app -n argocd argocd.argoproj.io/refresh="$(date +%s)" --overwrite

# Method 2: Update application spec to trigger reconciliation  
echo "Updating application spec..."
kubectl patch application kub-app -n argocd --type='merge' --patch='{"spec":{"source":{"targetRevision":"HEAD"}}}'

# Method 3: Delete and recreate the application (if needed)
echo "Checking current status..."
kubectl get application kub-app -n argocd -o jsonpath='{.status.sync.status}'
echo

# Wait a moment for ArgoCD to process
echo "Waiting for ArgoCD to process changes..."
sleep 10

# Check final status
echo "Final status check:"
kubectl get applications -n argocd
echo

echo "=== Sync Commands Available ==="
echo "Manual sync options:"
echo "1. Via ArgoCD UI: Access ArgoCD UI and click 'SYNC' on kub-app"
echo "2. Via kubectl annotation: kubectl annotate app kub-app -n argocd argocd.argoproj.io/refresh=hard"
echo "3. Restart ArgoCD controller: kubectl rollout restart deployment argocd-application-controller -n argocd"