# shared-devsecops — Architecture Document

## High-Level Architecture

**Purpose:** Shared AWS DevSecOps platform for hosting platform tools and future workloads.
**Region:** us-east-1 (3 AZs: us-east-1a, us-east-1b, us-east-1c)

```
┌─────────────────────────────────────────────────────────────────┐
│                        AWS Account                              │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                    VPC (10.0.0.0/16)                      │  │
│  │  Public /24 x3  — NAT GW, ALBs                           │  │
│  │  Private /19 x3 — EKS nodes, pods (8190 IPs/AZ)          │  │
│  │                                                           │  │
│  │  ┌─────────────────────────────────────────────────────┐  │  │
│  │  │              EKS Cluster (v1.35)                     │  │  │
│  │  │  System Nodes (t3.medium x2) — CoreDNS, metrics     │  │  │
│  │  │  Tools Nodes  (t3.large x2)  — ArgoCD, monitoring   │  │  │
│  │  └─────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────┘  │
│  IAM (4 roles) | KMS (4 keys) | ECR (5 repos) | Route53       │
└─────────────────────────────────────────────────────────────────┘
```

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Workload Identity | Pod Identity | AWS recommended, simpler than IRSA |
| Autoscaler | Karpenter (deferred) | Faster scaling, better cost optimization |
| NAT Strategy | Single (configurable) | Saves ~$64/mo, HA via variable |
| Node AMI | AL2023 | AL2 deprecated for k8s 1.34+ |
| Storage | gp3 default | 20% cheaper, better baseline IOPS |
| Access Mgmt | EKS Access Entries | Native API, replaces aws-auth |
| EKS Version | 1.35 | Latest standard support (until Mar 2027) |

## Cost Estimate

| Component | Monthly (est.) |
|-----------|---------------|
| EKS control plane | $73 |
| 4 worker nodes | $180 |
| NAT Gateway (single) | $32 |
| KMS + CloudWatch + misc | $15-25 |
| **Total** | **~$300-400** |

## Security Baseline

- KMS encryption for all data at rest
- IMDSv2 enforced on all nodes
- VPC flow logs (REJECT traffic)
- Private subnets for worker nodes
- S3 public access blocked
- Least-privilege IAM roles
- ECR scan-on-push + immutable tags
- EKS control plane audit logging
