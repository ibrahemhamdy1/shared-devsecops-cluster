# Platform Decisions Log

## D001: Region — us-east-1
Broadest service availability, lowest latency for US teams.

## D002: EKS Version — 1.35
Latest standard support until March 2027. cgroup v2 default.

## D003: Pod Identity over IRSA
AWS recommended direction. Simpler trust policies, no OIDC management.

## D004: Karpenter over Cluster Autoscaler (Deferred)
Faster scaling, better bin-packing. Deferred until cluster is stable.

## D005: Single NAT Gateway
Saves ~$64/month. Configurable to multi-AZ via `single_nat_gateway = false`.

## D006: AL2023 over Amazon Linux 2
AL2 deprecated for EKS 1.34+. cgroup v2 by default.

## D007: gp3 over gp2
20% cheaper, better baseline (3000 IOPS + 125 MB/s).

## D008: EKS Access Entries over aws-auth ConfigMap
AWS-native, Terraform-manageable, fine-grained policies.

## D009: Private Subnets /19
8190 IPs per AZ for VPC CNI pod networking.

## D010: IMDSv2 Required
Prevents SSRF credential theft. hop_limit=2 for Pod Identity.

## D011: S3 + DynamoDB State Backend
Industry standard. Versioned, encrypted, locked.

## D012: ECR Immutable Tags
Prevents tag overwriting. Forces proper versioning.
