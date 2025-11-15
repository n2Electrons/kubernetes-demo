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
- **Phase 3** COMPLETE - Kubernetes App Deployment
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

### Phase 3 - Kubernetes App Deployment

This phase validates the deployed Kubernetes application through comprehensive testing and load validation procedures.

#### Deployment Validation

**Quick Deployment**
```bash
# Deploy the complete application stack
./scripts/deploy-app.sh

# Verify deployment status
kubectl get all -n kub-app
```

**Application Access**
```bash
# Test direct access via ingress
curl -H "Host: kub-app.local" http://localhost:8080

# Add local DNS resolution (optional)
echo "127.0.0.1 kub-app.local" | sudo tee -a /etc/hosts
```

#### Testing Framework

**Infrastructure Tests**
```bash
./test/run-t1-tests.sh  # Cluster and system validation
```

**Multi-node Deployment Tests**
```bash
./test/run-t2-tests.sh  # Application deployment validation
```

**NGINX Access Tests**
```bash
./test/run-t3-tests.sh  # HTTP access and performance validation
```

**Comprehensive Validation and Load Testing**
```bash
./test/run-t4-tests.sh  # Complete deployment validation and load testing
```

#### Manual Verification

**Deployment Health Check**
```bash
# Check all resources
kubectl get all -n kub-app

# Verify pod distribution
kubectl get pods -n kub-app -o wide
```

**Load Testing**
```bash
# Quick load test using Apache Bench
ab -t 10 -c 5 -H "Host: kub-app.local" http://localhost:8080/

# Monitor HPA scaling during load
kubectl get hpa -n kub-app -w
```

#### Test Report Generation

The testing framework includes comprehensive report generation capabilities that create detailed HTML dashboards and JSON data exports.

**Automated Reports**
```bash
# Run tests with automatic report generation
./test/run-t4-tests.sh  # Includes load testing and report generation

# Generate reports independently from existing test data  
./test/generate-reports.sh
```

**Report Features**
- **HTML Dashboards**: Visual reports with cluster status, application health, and performance metrics
- **JSON Data Exports**: Structured data for integration with monitoring systems
- **Load Test Analysis**: RPS metrics, response times, and success rates
- **Multi-node Validation**: Pod distribution and resource utilization across cluster nodes

**Report Location**
All generated reports are saved in `test/reports/` directory with timestamps for historical tracking.

For detailed testing procedures and report configuration options, see `test/TESTPLAN.md`.

#### Troubleshooting

**Common Issues**
- Check `docs/troubleshooting.md` for debugging procedures
- Verify cluster nodes are ready: `kubectl get nodes`
- Check pod logs: `kubectl logs -n kub-app -l app=kub-app`
- Validate ingress: `kubectl describe ingress -n kub-app`

**Health Checks**
- Application responds with HTTP 200 status
- All 3 replicas running and distributed across nodes
- HPA monitoring CPU utilization
- Service endpoints healthy and accessible

## NGINX Core Functions

### Main Features

**Web Server**
Serves static files (HTML, CSS, images, etc.) very efficiently.

**Reverse Proxy**
Receives client requests and redirects them to one or more internal servers.

**Load Balancer**
Distributes traffic to multiple replicas of an application.

**TLS/SSL Termination**
NGINX can handle certificates and encryption for your applications.

**Kubernetes Ingress**
In Kubernetes, NGINX is used as an Ingress Controller, allowing internal services to be exposed through HTTP/HTTPS routes.

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
