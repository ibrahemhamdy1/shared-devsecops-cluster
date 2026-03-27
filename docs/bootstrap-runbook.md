# Bootstrap Runbook

## Prerequisites
- AWS CLI v2, Terraform >= 1.5.7, kubectl >= 1.35, Helm >= 3.x
- Admin-level AWS credentials

## Phase 1: Bootstrap State Backend
```bash
cd terraform/bootstrap
terraform init
terraform plan
terraform apply
# Uncomment backend "s3" block in main.tf
terraform init -migrate-state  # Answer: yes
rm -f terraform.tfstate terraform.tfstate.backup
terraform plan  # Should show no changes
```

## Phase 2: Deploy Platform
```bash
cd terraform/environments/shared-devsecops
cp example.tfvars terraform.tfvars
# Edit terraform.tfvars
terraform init
terraform plan
terraform apply  # ~15-20 min
```

## Phase 3: Configure kubectl
```bash
aws eks update-kubeconfig --region us-east-1 --name shared-devsecops-prod
kubectl get nodes       # 4 nodes Ready
kubectl get pods -n kube-system
```

## Phase 4: Validate
```bash
kubectl get storageclass    # gp3 = default
kubectl top nodes           # metrics-server working
kubectl get pods -n kube-system -l app.kubernetes.io/name=eks-pod-identity-agent
```

## Troubleshooting
| Issue | Solution |
|-------|----------|
| terraform init fails | Verify S3 bucket exists |
| EKS timeout | Normal, 10-15 min |
| Nodes not joining | Check node IAM role |
| kubectl unauthorized | Re-run aws eks update-kubeconfig |
