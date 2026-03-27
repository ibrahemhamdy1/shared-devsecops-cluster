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
├── docs/
│   ├── architecture.md          # Architecture overview
│   ├── decisions.md             # Platform decision log (ADR-lite)
│   ├── bootstrap-runbook.md     # Step-by-step deployment guide
│   ├── upgrade-strategy.md      # EKS upgrade procedures
│   └── promotion-flow.md        # Environment promotion guide
├── terraform/
│   ├── bootstrap/               # State backend (S3 + DynamoDB)
│   ├── environments/
│   │   └── shared-devsecops/    # Environment composition
│   └── modules/
│       ├── vpc/                 # VPC, subnets, NAT, flow logs
│       ├── iam-baseline/        # IAM roles (cluster, node, CI/CD, DevOps)
│       ├── kms/                 # KMS keys (EBS, S3, Secrets, EKS)
│       ├── ecr/                 # ECR repositories with lifecycle
│       ├── route53/             # DNS zones (public, private)
│       ├── security-groups/     # Baseline security groups
│       ├── eks/                 # EKS cluster + node groups + core addons
│       └── eks-addons/          # Storage classes, metrics-server
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

## Production Hardening Checklist

- [ ] Restrict `eks_public_access_cidrs` to known IPs
- [ ] Set `single_nat_gateway = false` for HA
- [ ] Configure `eks_access_entries` for team RBAC
- [ ] Install Karpenter for dynamic scaling
- [ ] Install AWS Load Balancer Controller
- [ ] Install cert-manager + external-dns
- [ ] Set up Velero for cluster backup
- [ ] Configure network policies

## Documentation

- [Architecture](docs/architecture.md)
- [Decisions](docs/decisions.md)
- [Bootstrap Runbook](docs/bootstrap-runbook.md)
- [Upgrade Strategy](docs/upgrade-strategy.md)
- [Promotion Flow](docs/promotion-flow.md)
