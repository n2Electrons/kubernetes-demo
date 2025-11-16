#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "======================================================="
echo -e "${BLUE}Killing all kub-app pods${NC}"
echo "======================================================="

# Check if namespace exists
if ! kubectl get namespace kub-app &> /dev/null; then
    echo -e "${RED}Error: kub-app namespace not found${NC}"
    echo "Make sure the application is deployed first"
    exit 1
fi

# Get all pods in kub-app namespace
echo -e "${BLUE}Finding pods in kub-app namespace...${NC}"
pods=$(kubectl get pods -n kub-app -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)

if [[ -z "$pods" ]]; then
    echo -e "${YELLOW}No pods found in kub-app namespace${NC}"
    exit 0
fi

echo -e "${GREEN}Found pods:${NC} $pods"
echo

# Kill all pods
echo -e "${BLUE}Deleting all pods...${NC}"
for pod in $pods; do
    echo -e "  ${YELLOW}Deleting pod: $pod${NC}"
    kubectl delete pod $pod -n kub-app --grace-period=0 --force
done

echo
echo -e "${BLUE}Waiting for pods to be recreated...${NC}"
sleep 5

# Show current pod status
echo -e "${BLUE}Current pod status:${NC}"
kubectl get pods -n kub-app

echo
echo -e "${GREEN}Pod deletion completed!${NC}"
echo "New pods should be automatically recreated by the deployment."

# Optional: Check if ArgoCD is managing this and trigger a sync if needed
if kubectl get application kub-app -n argocd &> /dev/null; then
    echo
    echo -e "${BLUE}ArgoCD application detected. Checking sync status...${NC}"
    kubectl get application kub-app -n argocd -o jsonpath='{.status.sync.status}'
    echo
    
    echo -e "${YELLOW}Note: If pods don't recreate properly, ArgoCD will reconcile automatically.${NC}"
    echo -e "${YELLOW}You can also trigger manual sync via ArgoCD UI at http://localhost:8090${NC}"
fi