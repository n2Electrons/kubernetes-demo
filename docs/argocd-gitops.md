# Argo CD GitOps Documentation

## Overview

This document describes the GitOps implementation using Argo CD for automated application deployment and management.

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────────┐
│   Git Repository │    │     Argo CD      │    │   Kubernetes       │
│  (Source of Truth) │    │   (Controller)   │    │    Cluster         │
│                 │    │                  │    │                    │
│ apps/kub-app/   ├────┤ Application      ├────┤ Deployed Resources │
│ ├─deployment.yaml│    │ Controller       │    │ ├─ Namespace       │
│ ├─service.yaml  │    │                  │    │ ├─ Deployment      │
│ ├─ingress.yaml  │    │ Sync Policy:     │    │ ├─ Service         │
│ ├─hpa.yaml      │    │ - Automated      │    │ ├─ Ingress         │
│ └─namespace.yaml│    │ - Self-healing   │    │ └─ HPA             │
└─────────────────┘    └──────────────────┘    └─────────────────────┘
```

## Components

### 1. Argo CD Installation

**Location**: `argocd/install-argocd.yaml`
- Namespace configuration
- Installation script with wait conditions
- Initial admin password retrieval

### 2. Project Configuration

**Location**: `argocd/projects/kubernetes-demo.yaml`
- AppProject definition for the kubernetes-demo project
- Source repository permissions
- Destination cluster and namespace access
- RBAC roles and policies

### 3. Application Configuration

**Location**: `argocd/applications/kub-app.yaml`
- Application definition for kub-app
- Repository source configuration
- Automated sync policy with self-healing
- Sync options for namespace creation and pruning

### 4. Repository Configuration

**Location**: `argocd/repository/repo-config.yaml`
- Git repository credentials (HTTPS)
- Optional SSH configuration template

### 5. RBAC and Configuration

**Location**: `argocd/config/argocd-config.yaml`
- RBAC policies for admin, developer, and readonly roles
- Server configuration parameters
- Resource customizations

## Setup Instructions

### Prerequisites
- Kubernetes cluster running (k3d recommended)
- kubectl configured and accessible
- Git repository with Kubernetes manifests

### Installation

1. **Install Argo CD**
   ```bash
   ./scripts/setup-argocd.sh
   ```

2. **Verify Installation**
   ```bash
   kubectl get all -n argocd
   kubectl get applications -n argocd
   kubectl get appprojects -n argocd
   ```

3. **Access Argo CD UI**
   ```bash
   # Start port forwarding (use port 9090 to avoid conflicts with k3d)
   kubectl port-forward svc/argocd-server -n argocd 9090:443
   
   # Get admin password
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
   
   # Open browser to https://localhost:9090
   # Login with username: admin and the retrieved password
   ```

   **Login Credentials:**
   - **URL**: https://localhost:9090
   - **Username**: admin
   - **Password**: Use the command above to retrieve the initial admin password
   - **Note**: Accept the self-signed certificate warning in your browser

## GitOps Workflow

### Automated Deployment Process

1. **Developer commits changes** to `apps/kub-app/` directory
2. **Argo CD detects changes** via repository polling (default: 3 minutes)
3. **Application Controller compares** Git state vs cluster state
4. **Automatic synchronization** applies changes to cluster
5. **Self-healing** reverts any manual changes to maintain Git state

### Sync Policies

**Automated Sync**: Enabled with the following options:
- `prune: true` - Remove resources not in Git
- `selfHeal: true` - Revert manual cluster changes
- `allowEmpty: false` - Prevent sync if directory is empty

**Sync Options**:
- `CreateNamespace=true` - Auto-create target namespace
- `PrunePropagationPolicy=foreground` - Ordered resource deletion
- `PruneLast=true` - Delete application resources last

**Retry Policy**:
- 5 retry attempts with exponential backoff
- Initial delay: 5 seconds, max delay: 3 minutes

### Repository Structure

The GitOps workflow monitors the following path:
```
apps/kub-app/
├── namespace.yaml      # Application namespace
├── deployment.yaml     # Application deployment
├── service.yaml        # Service configuration  
├── ingress.yaml        # Ingress routing
└── hpa.yaml           # Horizontal Pod Autoscaler
```

## Testing

### Test Suite: T5 - Argo CD GitOps Tests

**Run Tests**:
```bash
./test/run-t5-tests.sh
```

**Test Coverage**:
- Argo CD namespace and component health
- Server accessibility
- Application and project configuration
- Sync status and health validation
- GitOps workflow configuration

### Manual Verification

**Check Application Status**:
```bash
# List applications
kubectl get applications -n argocd

# Get detailed application status
kubectl describe application kub-app -n argocd

# Check sync status
kubectl get application kub-app -n argocd -o jsonpath='{.status.sync.status}'
```

**Monitor Sync Activity**:
```bash
# Watch application sync events
kubectl logs -f deployment/argocd-application-controller -n argocd

# Check recent events
kubectl get events -n argocd --sort-by='.lastTimestamp'
```

## Troubleshooting

### Common Issues

**Application Not Syncing**:
1. Check repository access:
   ```bash
   kubectl logs deployment/argocd-repo-server -n argocd
   ```
2. Verify Git repository URL in application spec
3. Ensure target namespace exists or CreateNamespace is enabled

**Sync Failures**:
1. Check application controller logs:
   ```bash
   kubectl logs deployment/argocd-application-controller -n argocd
   ```
2. Review application status and conditions:
   ```bash
   kubectl describe application kub-app -n argocd
   ```

**UI Access Issues**:
1. Verify port-forward is active
2. Check if using correct port (9090 recommended to avoid conflicts with k3d)
3. Accept self-signed certificate in browser
4. If port 8080 is in use, try alternative ports:
   ```bash
   # Try different ports if 9090 is also busy
   kubectl port-forward svc/argocd-server -n argocd 9091:443
   kubectl port-forward svc/argocd-server -n argocd 9092:443
   ```

**Permission Errors**:
1. Verify AppProject permissions
2. Check RBAC configuration
3. Ensure service account has necessary cluster permissions

### Useful Commands

```bash
# Force sync application
kubectl patch application kub-app -n argocd --type merge -p='{"operation":{"sync":{"revision":"HEAD"}}}'

# Refresh application (fetch latest Git state)
kubectl patch application kub-app -n argocd --type merge -p='{"operation":{"refresh":{}}}'

# Get application sync status
kubectl get application kub-app -n argocd -o json | jq '.status.sync'

# List all Argo CD resources
kubectl get all,applications,appprojects -n argocd
```

## Security Considerations

### Repository Access
- Uses HTTPS for public repositories
- SSH key authentication available for private repositories
- Repository credentials stored as Kubernetes secrets

### RBAC Configuration
- Project-based access control
- Role-based permissions (admin, developer, readonly)
- Integration with external authentication systems

### Network Security
- Argo CD server runs with TLS (self-signed for development)
- Port-forwarding for UI access in development
- Ingress configuration available for production deployments

## Best Practices

### Repository Organization
- Keep application manifests in dedicated directories
- Use consistent naming conventions
- Include resource limits and health checks
- Implement proper labeling for resource management

### Sync Policies
- Enable automated sync for non-production environments
- Use manual sync for production environments
- Configure appropriate prune policies
- Set up proper retry mechanisms

### Monitoring
- Monitor application sync status
- Set up alerts for sync failures
- Track resource drift detection
- Monitor Argo CD component health

## Advanced Features

### Multi-Environment Support
- Use different branches for different environments
- Environment-specific application configurations
- Kustomize integration for configuration management

### Progressive Delivery
- Blue-green deployments with Argo Rollouts
- Canary deployments for gradual rollouts
- Automated rollback on failure detection

### Integration
- CI/CD pipeline integration for image updates
- Webhook configuration for immediate sync triggers
- Slack/Discord notifications for sync events