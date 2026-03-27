# EKS Upgrade Strategy

## Process
1. Review release notes for target version
2. Check cluster insights: `aws eks describe-cluster --name CLUSTER`
3. Update `cluster_version` in terraform.tfvars
4. `terraform plan` then `terraform apply` (control plane: 10-15 min)
5. Node groups auto-update via rolling replacement
6. Verify: `kubectl get nodes`, `kubectl get pods -A`

## Version Skew
- Control plane and nodes: max 2 minor versions apart
- kubectl: +/-1 minor version from control plane

## Cadence
Upgrade every 6-9 months. Standard support = 14 months per version.
