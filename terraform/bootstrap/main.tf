# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  Bootstrap: Terraform Remote State Infrastructure                          ║
# ║  Run with local state first: terraform init && terraform apply             ║
# ║  Then migrate: uncomment backend block, run terraform init -migrate-state  ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

terraform {
  required_version = ">= 1.5.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Uncomment after initial apply to migrate state to S3
  backend "s3" {
    bucket         = "shared-devsecops-terraform-state"
    key            = "bootstrap/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "shared-devsecops-terraform-lock"
    kms_key_id     = "alias/shared-devsecops-terraform-state"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "shared-devsecops"
      Environment = "shared"
      ManagedBy   = "terraform"
      Owner       = "platform-team"
      CostCenter  = "platform"
    }
  }
}

# ─── S3 Bucket for Terraform State ───────────────────────────────────────────

resource "aws_s3_bucket" "terraform_state" {
  bucket = var.state_bucket_name

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name = "Terraform State"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.terraform_state.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "cleanup-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# ─── KMS Key for State Encryption ────────────────────────────────────────────

resource "aws_kms_key" "terraform_state" {
  description             = "KMS key for Terraform state encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Name = "shared-devsecops-terraform-state"
  }
}

resource "aws_kms_alias" "terraform_state" {
  name          = "alias/shared-devsecops-terraform-state"
  target_key_id = aws_kms_key.terraform_state.key_id
}

# ─── DynamoDB Table for State Locking ────────────────────────────────────────

resource "aws_dynamodb_table" "terraform_lock" {
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name = "Terraform State Lock"
  }
}
