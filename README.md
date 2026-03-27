# shared-devsecops

Production-ready AWS DevSecOps platform foundation built with Terraform.

## Architecture

- **Region:** us-east-1 (3 AZs)
- **EKS:** v1.35 with Pod Identity, gp3 storage, metrics-server
- **Networking:** VPC with public/private subnets, cost-optimized NAT
- **Security:** KMS encryption, least-privilege IAM, IMDSv2, VPC flow logs

See [docs/architecture.md](docs/architecture.md) for full details.

## Repository Structure

```
shared-devsecops/
├── argocd/                          # ArgoCD platform configuration
│   ├── namespace.yaml               # ArgoCD namespace definition
│   ├── values.yaml                  # Helm values (ALB, RBAC, accounts)
│   ├── install.sh                   # Installation script
│   ├── projects/                    # AppProject definitions
│   │   ├── platform.yaml            # Platform tools project
│   │   ├── dev.yaml                 # Dev environment project
│   │   ├── staging.yaml             # Staging environment project
│   │   └── production.yaml          # Production project (sync windows)
│   ├── rbac/                        # RBAC configuration
│   │   └── rbac-configmap.yaml      # Roles: devops-admin, developer
│   ├── notifications/               # Notification templates
│   │   ├── notifications-configmap.yaml
│   │   └── notifications-secret.yaml
│   ├── sync-policies/               # Sync policy documentation
│   │   └── README.md
│   └── webhooks/                    # Webhook integration guide
│       └── README.md
├── gitops/                          # GitOps deployment repository
│   ├── charts/                      # Helm chart templates
│   │   └── base-app/               # Base application chart
│   │       ├── Chart.yaml
│   │       ├── values.yaml
│   │       └── templates/           # K8s manifest templates
│   ├── environments/                # Environment-common values
│   │   ├── dev/values-common.yaml
│   │   ├── staging/values-common.yaml
│   │   └── production/values-common.yaml
│   ├── apps/                        # App-specific values per env
│   │   ├── dev/{app}/values.yaml
│   │   ├── staging/{app}/values.yaml
│   │   └── production/{app}/values.yaml
│   ├── bootstrap/                   # App-of-apps bootstrap
│   │   ├── app-of-apps.yaml
│   │   └── applications/            # ArgoCD Application manifests
│   ├── infrastructure/              # Platform components
│   │   ├── ingress-nginx/
│   │   ├── cert-manager/
│   │   ├── monitoring/
│   │   └── external-secrets/
│   └── namespace-standard.yaml      # Namespace naming convention
├── docs/                            # Documentation
│   ├── architecture.md              # Architecture overview
│   ├── decisions.md                 # Platform decision log
│   ├── bootstrap-runbook.md         # Deployment guide
│   ├── upgrade-strategy.md          # EKS upgrade procedures
│   ├── promotion-flow.md            # Environment promotion
│   ├── gitops-operating-model.md    # GitOps operating model
│   ├── deployment-approval-model.md # Multi-gate approval process
│   ├── rollback-procedures.md       # Rollback procedures
│   ├── drift-detection.md           # Drift detection & self-heal
│   ├── helm-chart-standards.md      # Helm chart standards
│   └── environment-values-convention.md # Values file convention
├── terraform/                       # Infrastructure as Code
│   ├── bootstrap/                   # State backend (S3 + DynamoDB)
│   ├── environments/
│   │   └── shared-devsecops/        # Environment composition
│   └── modules/
│       ├── vpc/                     # VPC, subnets, NAT, flow logs
│       ├── iam-baseline/            # IAM roles
│       ├── kms/                     # KMS keys
│       ├── ecr/                     # ECR repositories
│       ├── route53/                 # DNS zones
│       ├── security-groups/         # Security groups
│       ├── eks/                     # EKS cluster + node groups
│       └── eks-addons/              # Storage classes, metrics-server
├── .gitignore
└── README.md
```

## Prerequisites

| Tool | Version |
|------|---------|
| Terraform | >= 1.5.7 |
| AWS CLI | v2.x |
| kubectl | >= 1.35 |
| Helm | >= 3.x |

## Quick Start

```bash
# 1. Bootstrap state backend
cd terraform/bootstrap
terraform init && terraform apply
# Uncomment backend block, then: terraform init -migrate-state

# 2. Deploy platform
cd terraform/environments/shared-devsecops
cp example.tfvars terraform.tfvars  # Edit with your values
terraform init && terraform plan && terraform apply

# 3. Connect to cluster
aws eks update-kubeconfig --region us-east-1 --name shared-devsecops-prod
kubectl get nodes
```

## Naming Convention

```
{project}-{environment}-{resource}
```

Examples: `shared-devsecops-prod-vpc`, `shared-devsecops-prod-eks-cluster`

## Tagging Policy

| Tag | Value | Purpose |
|-----|-------|---------|
| Project | shared-devsecops | Project identification |
| Environment | dev/staging/prod | Environment separation |
| ManagedBy | terraform | IaC tracking |
| Owner | platform-team | Ownership |
| CostCenter | platform | Cost allocation |

## Key Decisions

| Decision | Choice | Why |
|----------|--------|-----|
| Workload Identity | Pod Identity | AWS recommended, simpler than IRSA |
| Autoscaler | Karpenter (deferred) | Faster, better cost optimization |
| NAT Strategy | Single (configurable) | Cost savings, HA via variable |
| Node AMI | AL2023 | AL2 deprecated for k8s 1.34+ |
| Storage | gp3 | 20% cheaper, better baseline IOPS |
| Access Mgmt | EKS Access Entries | Native API, replaces aws-auth |

## Cost Estimate (~$300-400/month baseline)

| Component | Monthly |
|-----------|---------|
| EKS control plane | $73 |
| 4 worker nodes | $180 |
| NAT Gateway | $32 |
| KMS + misc | $15-25 |

## Security Baseline

- ✓ KMS encryption for all data at rest
- ✓ IMDSv2 enforced on all nodes
- ✓ VPC flow logs (REJECT traffic)
- ✓ Private subnets for worker nodes
- ✓ Least-privilege IAM roles
- ✓ ECR scan-on-push + immutable tags
- ✓ EKS control plane audit logging

## GitOps Model

This platform uses **ArgoCD** for GitOps-based continuous delivery:

| Component | Description |
|-----------|-------------|
| **ArgoCD** | GitOps controller, installed via Helm |
| **App of Apps** | Bootstrap pattern for managing all applications |
| **Base Chart** | Reusable Helm chart template for all apps |
| **3-Layer Values** | Chart defaults → Environment common → App-specific |

### Environment Strategy

| Environment | Namespace Pattern | Sync Policy | Approval |
|-------------|------------------|-------------|----------|
| Dev | `dev-{app}` | Auto (prune + self-heal) | None |
| Staging | `staging-{app}` | Auto (prune + self-heal) | 1 approval |
| Production | `prod-{app}` | Manual | 2 approvals + sync window |

### Quick Start: ArgoCD

```bash
# Install ArgoCD
chmod +x argocd/install.sh
./argocd/install.sh

# Bootstrap applications
kubectl apply -f gitops/bootstrap/app-of-apps.yaml

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port-forward for initial access
kubectl port-forward -n argocd svc/argocd-server 8080:80
```

### Placeholders to Replace

| Placeholder | Description |
|-------------|-------------|
| `${ACM_CERTIFICATE_ARN}` | Your ACM certificate ARN |
| `argocd.internal.example.com` | Your ArgoCD domain |
| `https://github.com/ORG/shared-devsecops-gitops.git` | Your GitOps repo URL |
| `ACCOUNT_ID` | Your AWS account ID |
| `*.internal.example.com` | Your internal domain |

## Production Hardening Checklist

- [ ] Restrict `eks_public_access_cidrs` to known IPs
- [ ] Set `single_nat_gateway = false` for HA
- [ ] Configure `eks_access_entries` for team RBAC
- [ ] Install Karpenter for dynamic scaling
- [ ] Install AWS Load Balancer Controller
- [ ] Install cert-manager + external-dns
- [ ] Set up Velero for cluster backup
- [ ] Configure network policies
- [ ] Replace ArgoCD placeholder values (ACM cert, domain, repo URL)
- [ ] Configure ArgoCD notifications (Slack/Teams tokens)
- [ ] Set up External Secrets Operator for secret management
- [ ] Configure Git webhooks for ArgoCD

## Documentation

### Infrastructure
- [Architecture](docs/architecture.md)
- [Decisions](docs/decisions.md)
- [Bootstrap Runbook](docs/bootstrap-runbook.md)
- [Upgrade Strategy](docs/upgrade-strategy.md)
- [Promotion Flow](docs/promotion-flow.md)

### GitOps & Deployment
- [GitOps Operating Model](docs/gitops-operating-model.md)
- [Deployment Approval Model](docs/deployment-approval-model.md)
- [Rollback Procedures](docs/rollback-procedures.md)
- [Drift Detection & Self-Healing](docs/drift-detection.md)
- [Helm Chart Standards](docs/helm-chart-standards.md)
- [Environment Values Convention](docs/environment-values-convention.md)
