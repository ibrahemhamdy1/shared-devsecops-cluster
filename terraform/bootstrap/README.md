# Terraform State Bootstrap

Creates the S3 bucket, KMS key, and DynamoDB table required for Terraform remote state.

## Bootstrap Runbook

### Prerequisites
- AWS CLI v2 configured with admin credentials
- Terraform >= 1.5.7

### Step 1: Initialize and Apply (Local State)
```bash
cd terraform/bootstrap
terraform init
terraform plan
terraform apply
```

### Step 2: Migrate to Remote State
1. Uncomment the `backend "s3"` block in `main.tf`
2. Run migration:
```bash
terraform init -migrate-state
# Confirm: yes
```

### Step 3: Cleanup
```bash
rm -f terraform.tfstate terraform.tfstate.backup
```

### Step 4: Verify
```bash
terraform plan
# Should show: No changes.
```

## Resources Created
| Resource | Purpose |
|----------|---------|
| S3 Bucket | Terraform state storage (versioned, encrypted) |
| KMS Key | Encryption for state files |
| DynamoDB Table | State locking (PAY_PER_REQUEST) |

## Cost
- S3: Pennies/month for state files
- DynamoDB: < $1/month (PAY_PER_REQUEST)
- KMS: $1/month per key
