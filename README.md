# Container Farm with GitOps + Kubernetes

Multi-node Kubernetes cluster with GitOps workflow using Argo CD for cloud-native application deployment.

## Project Structure
```
├── apps/kub-app/        # Kubernetes manifests for demo application
├── argocd/              # Argo CD configuration
├── infra/
│   ├── terraform/       # Infrastructure as Code
│   └── ansible/         # Configuration management
├── scripts/             # Bootstrap and utility scripts
└── docs/                # Documentation
```

## Quick Start

1. **Prerequisites**
   
   Install required tools:
   ```bash
   # Docker
   curl -fsSL https://get.docker.com -o get-docker.sh
   sh get-docker.sh
   
   # kubectl
   curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
   chmod +x kubectl && sudo mv kubectl /usr/local/bin/
   
   # k3d
   curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
   
   # Load testing tool
   sudo apt install apache2-utils
   ```

2. **Create k3d Cluster**
   ```bash
   ./scripts/setup-cluster.sh
   ```

3. **Cleanup**
   ```bash
   ./scripts/cleanup-cluster.sh
   ```

## Project Phases

- **Phase 1** COMPLETE - Environment Preparation
- **Phase 2** COMPLETE - Multi-node Cluster Setup
- **Phase 3** TODO - Kubernetes App Deployment
- **Phase 4** TODO - Argo CD Setup (GitOps)
- **Phase 5** TODO - CI/CD Pipeline
- **Phase 6** TODO - Terraform + Ansible + Vault
- **Phase 7** TODO - Testing & Autoscaling Validation
- **Phase 8** TODO - Observability (Optional)

### Phase 2 - Multi-node Application Deployment

This phase implements a complete Kubernetes application stack with proper multi-node distribution. The following YAML components are included in `apps/kub-app/`:

#### Core Application Components

**namespace.yaml**
- Creates the `kub-app` namespace to isolate application resources
- Provides resource boundaries and security isolation

**deployment.yaml**
- **3 replicas** configured for high availability across nodes
- **NGINX Alpine** container image for lightweight demo application
- **Resource limits**: 100m CPU, 128Mi memory per pod
- **Health checks**: Readiness and liveness probes on port 80
- **Rolling update strategy** for zero-downtime deployments

**service.yaml**
- **ClusterIP service** exposing port 80 internally
- Load balances traffic across all healthy pods
- Selector matches deployment labels for automatic endpoint discovery

**ingress.yaml**
- **Traefik ingress controller** integration
- Routes external traffic to `kub-app.local` hostname
- Forwards HTTP traffic to the service on port 80
- Enables external access to the application

**hpa.yaml**
- **Horizontal Pod Autoscaler** for dynamic scaling
- Monitors CPU utilization with 70% target threshold
- Scales between 3-10 replicas based on load
- Enables automatic response to traffic spikes

#### Multi-node Distribution

The deployment ensures pods are distributed across all cluster nodes:
- **k3d-kub-demo-server-0** (control plane + worker)
- **k3d-kub-demo-agent-0** (worker node)
- **k3d-kub-demo-agent-1** (worker node)

This configuration provides fault tolerance and load distribution across the entire cluster infrastructure.

## Git Workflow

- **main**: Release branch for milestones
- **develop**: CI/CD integration branch 
- **feature/***: Development branches for daily commits

Each milestone represents a complete feature set ready for release.

## Core Components
- Multi-node Kubernetes cluster using **k3d**
- Demo application deployed with **Deployment**, **Service**, **Ingress**
- **Argo CD GitOps** for automated deployments, self-healing, and drift correction
- **Horizontal Pod Autoscaler (HPA)** for dynamic workload scaling
- Lightweight **CI/CD pipeline** structure (GitLab-compatible)
- Optional integrations: **Terraform**, **Ansible**, **Vault**
