# F5 Strategy Deployment Engineer – Project Summary

This repository presents a concise demonstration of a GitOps-driven Kubernetes workflow tailored for evaluating pre-release software.

## Core Components
- Multi-node Kubernetes cluster using **k3d**
- Demo application deployed with **Deployment**, **Service**, **Ingress**
- **Argo CD GitOps** for automated deployments, self-healing, and drift correction
- **Horizontal Pod Autoscaler (HPA)** for dynamic workload scaling
- Lightweight **CI/CD pipeline** structure (GitLab-compatible)
- Optional integrations: **Terraform**, **Ansible**, **Vault**
