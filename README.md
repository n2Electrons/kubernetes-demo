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

- **Phase 1** COMPLETE - Environment Preparation - Bootstrap scripts and folder structure
- **Phase 2** TODO - Multi-node Cluster Setup 
- **Phase 3** TODO - Kubernetes App Deployment
- **Phase 4** TODO - Argo CD Setup (GitOps)
- **Phase 5** TODO - CI/CD Pipeline
- **Phase 6** TODO - Terraform + Ansible + Vault
- **Phase 7** TODO - Testing & Autoscaling Validation
- **Phase 8** TODO - Observability (Optional)

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
