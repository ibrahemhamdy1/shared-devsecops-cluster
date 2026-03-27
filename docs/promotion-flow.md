# Environment Promotion Flow

## State Layout
```
s3://shared-devsecops-terraform-state/
├── bootstrap/terraform.tfstate
├── environments/shared-devsecops-dev/terraform.tfstate
├── environments/shared-devsecops-staging/terraform.tfstate
└── environments/shared-devsecops-prod/terraform.tfstate
```

## Creating a New Environment
1. Copy environment directory
2. Update backend key in main.tf
3. Create environment-specific terraform.tfvars
4. `terraform init && terraform apply`

## Environment Sizing
| Setting | Dev | Staging | Prod |
|---------|-----|---------|------|
| System nodes | 1x t3.small | 2x t3.medium | 2x t3.medium |
| Tools nodes | 1x t3.medium | 2x t3.large | 2x t3.large |
| NAT | Single | Single | Multi-AZ |
| VPC CIDR | 10.2.0.0/16 | 10.1.0.0/16 | 10.0.0.0/16 |
