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

## Phase 4: Validate Infrastructure
```bash
kubectl get storageclass    # gp3 = default
kubectl top nodes           # metrics-server working
kubectl get pods -n kube-system -l app.kubernetes.io/name=eks-pod-identity-agent
```

## Phase 5: Pre-Deployment Prerequisites (ArgoCD)

> ⚠ **IMPORTANT:** Before deploying ArgoCD, the following must be in place.

### Required Placeholders to Replace

| Placeholder | File(s) | Replace With |
|-------------|---------|-------------|
| `${ACM_CERTIFICATE_ARN}` | `argocd/values.yaml` | Your ACM certificate ARN for the ArgoCD domain (e.g., `arn:aws:acm:us-east-1:123456789:certificate/abc-123`) |
| `argocd.internal.example.com` | `argocd/values.yaml`, `argocd/notifications/notifications-configmap.yaml` | Your actual ArgoCD domain |
| `https://github.com/ORG/shared-devsecops-gitops.git` | `argocd/projects/*.yaml`, `gitops/bootstrap/*.yaml` | Your actual GitOps repository URL |
| `ACCOUNT_ID` | `gitops/apps/*/sample-app/values.yaml` | Your AWS account ID (12-digit number) |
| `*.internal.example.com` | `gitops/apps/*/sample-app/values.yaml` | Your internal domain for application ingress |

### Required AWS Resources

| Resource | Purpose | How to Verify |
|----------|---------|---------------|
| **AWS Load Balancer Controller** | Required for ALB Ingress to work | `kubectl get deployment -n kube-system aws-load-balancer-controller` |
| **ACM Certificate** | TLS termination at ALB | `aws acm list-certificates --region us-east-1` |
| **Route53 DNS Zone** | DNS records for ArgoCD and apps | `aws route53 list-hosted-zones` |
| **ECR Repository** | Container image storage for sample-app | `aws ecr describe-repositories` |

### Validation Checklist (Pre-Deploy)

- [ ] AWS Load Balancer Controller is installed and running
- [ ] ACM certificate is issued and validated (status: ISSUED)
- [ ] DNS zone exists for your internal domain
- [ ] All placeholder values in `argocd/values.yaml` are replaced
- [ ] All placeholder values in `argocd/projects/*.yaml` are replaced
- [ ] All placeholder values in `gitops/bootstrap/applications/*.yaml` are replaced
- [ ] `argocd/install.sh` dry-run completes without errors

## Phase 6: Deploy ArgoCD

```bash
# 1. Replace placeholders first (see Phase 5)
# 2. Dry-run to verify
chmod +x argocd/install.sh
./argocd/install.sh --dry-run

# 3. Install ArgoCD
./argocd/install.sh

# 4. Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo  # newline

# 5. Port-forward for initial access
kubectl port-forward -n argocd svc/argocd-server 8080:80

# 6. Login (in another terminal)
# Open http://localhost:8080 — user: admin, password: from step 4
```

## Phase 7: Configure ArgoCD

```bash
# 1. Add Git repository credentials
argocd login localhost:8080 --username admin --password '<password>' --insecure
argocd repo add https://github.com/ORG/shared-devsecops-gitops.git \
  --username <git-username> --password <git-token>

# 2. Bootstrap the app-of-apps
kubectl apply -f gitops/bootstrap/app-of-apps.yaml

# 3. Verify applications are created
argocd app list

# 4. Change admin password immediately
argocd account update-password

# 5. Delete initial admin secret
kubectl -n argocd delete secret argocd-initial-admin-secret
```

## Phase 8: Validate ArgoCD Deployment

```bash
# All ArgoCD pods running
kubectl get pods -n argocd

# Projects created
kubectl get appprojects -n argocd

# Applications visible
argocd app list

# Ingress created (ALB provisioning may take 2-3 min)
kubectl get ingress -n argocd

# Notifications configured
kubectl get configmap argocd-notifications-cm -n argocd
```

### Post-Deployment Validation

| Check | Command | Expected |
|-------|---------|----------|
| Pods healthy | `kubectl get pods -n argocd` | All Running/Ready |
| Server accessible | `curl -s http://localhost:8080/healthz` | `ok` |
| Projects exist | `kubectl get appprojects -n argocd` | platform, dev, staging, production |
| RBAC applied | `kubectl get cm argocd-rbac-cm -n argocd` | ConfigMap exists |
| Ingress created | `kubectl get ingress -n argocd` | ALB address assigned |
| Notifications | `kubectl get cm argocd-notifications-cm -n argocd` | ConfigMap exists |
| Sample app (dev) | `argocd app get sample-app-dev` | Synced & Healthy |

### Chart Validation Results

The ArgoCD configuration has been validated against the official Helm chart:

| Validation | Result |
|-----------|--------|
| Helm chart version | argo/argo-cd v9.4.17 (ArgoCD v3.3.6) |
| Values render | ✓ 52 Kubernetes resources generated |
| ALB Ingress | ✓ Internal scheme, IP target, HTTPS:443 |
| Node placement | ✓ `role: tools` selector + toleration on all components |
| Server mode | ✓ `--insecure` flag (TLS at ALB) |
| RBAC | ✓ devops-admin + developer roles |
| Notifications | ✓ Slack + Teams templates configured |
| Base app chart | ✓ Lint clean, renders for all 3 environments |
| YAML syntax | ✓ All 13 manifest files valid |

## Troubleshooting
| Issue | Solution |
|-------|----------|
| terraform init fails | Verify S3 bucket exists |
| EKS timeout | Normal, 10-15 min |
| Nodes not joining | Check node IAM role |
| kubectl unauthorized | Re-run aws eks update-kubeconfig |
| ArgoCD pods pending | Check tools node selector — nodes need `role=tools` label |
| ALB not provisioning | Verify AWS Load Balancer Controller is installed |
| Ingress 404 | Check ACM cert ARN and domain match |
| ArgoCD sync fails | Check Git repo credentials: `argocd repo list` |
| Notifications not working | Update `argocd-notifications-secret` with real tokens |
| App OutOfSync | Check `argocd app diff <app>` for drift details |
