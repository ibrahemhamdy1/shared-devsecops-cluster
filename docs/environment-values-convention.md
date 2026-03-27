# Environment Values File Convention

**Platform:** AWS EKS 1.35 (us-east-1, 3 AZs)
**Last Updated:** 2026-03-27

---

## Overview

This document defines how environment-specific configuration values are organized, layered, and managed across the dev, staging, and production environments.

---

## File Hierarchy

```
gitops/
├── charts/
│   └── base-app/
│       └── values.yaml                      # Layer 1: Chart defaults
├── environments/
│   ├── dev/
│   │   └── values-common.yaml               # Layer 2: Dev environment defaults
│   ├── staging/
│   │   └── values-common.yaml               # Layer 2: Staging environment defaults
│   └── production/
│       └── values-common.yaml               # Layer 2: Production environment defaults
└── apps/
    ├── dev/
    │   └── {app-name}/
    │       └── values.yaml                  # Layer 3: App-specific dev overrides
    ├── staging/
    │   └── {app-name}/
    │       └── values.yaml                  # Layer 3: App-specific staging overrides
    └── production/
        └── {app-name}/
            └── values.yaml                  # Layer 3: App-specific production overrides
```

---

## Merge Order

```
Layer 1 (Chart defaults) → Layer 2 (Environment common) → Layer 3 (App-specific)
```

**Last layer wins.** If the same key exists in multiple layers, the value from the highest layer takes precedence.

### How ArgoCD Applies This

In the ArgoCD Application manifest:
```yaml
spec:
  source:
    path: gitops/charts/base-app          # Layer 1: values.yaml in chart
    helm:
      valueFiles:
        - ../../environments/dev/values-common.yaml    # Layer 2
        - ../../apps/dev/sample-app/values.yaml        # Layer 3
```

Helm processes these in order: chart `values.yaml` → first valueFile → second valueFile.

---

## What Goes Where

### Layer 1: Chart Defaults (`charts/base-app/values.yaml`)

**Purpose:** Sane defaults that work for local development and serve as documentation of all available options.

**Contains:**
- All configurable keys with default values
- Comprehensive comments explaining each option
- Feature toggles set to safe defaults (e.g., `ingress.enabled: false`)
- Moderate resource requests/limits

**Rules:**
- Must be self-contained (chart works with just defaults)
- Every key must have a comment
- No environment-specific values
- No secrets or credentials

**Example:**
```yaml
replicaCount: 2

image:
  repository: ""
  tag: ""
  pullPolicy: IfNotPresent

resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "250m"

ingress:
  enabled: false
  className: alb

autoscaling:
  enabled: false
  minReplicas: 2
  maxReplicas: 10
```

### Layer 2: Environment Common (`environments/{env}/values-common.yaml`)

**Purpose:** Environment-wide settings that apply to ALL applications in that environment.

**Contains:**
- Replica counts appropriate for the environment
- Resource sizing for the environment
- Ingress annotations (ALB group, scheme)
- Autoscaling settings
- PDB settings
- Node selectors / tolerations
- Affinity rules

**Rules:**
- Only override values that differ from chart defaults
- No application-specific values (image tags, app env vars)
- No secrets or credentials
- Keep it minimal — less is more

**Example (Production):**
```yaml
replicaCount: 3

resources:
  requests:
    memory: "256Mi"
    cpu: "250m"
  limits:
    memory: "512Mi"
    cpu: "500m"

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10

podDisruptionBudget:
  enabled: true
  minAvailable: 1

ingress:
  annotations:
    alb.ingress.kubernetes.io/group.name: prod-apps
```

### Layer 3: App-Specific (`apps/{env}/{app-name}/values.yaml`)

**Purpose:** Application-specific configuration for a particular environment.

**Contains:**
- Container image repository and tag
- Application-specific environment variables
- Ingress hostname
- ConfigMap data
- ServiceAccount annotations (IAM role ARN)
- Any app-specific resource overrides

**Rules:**
- Always pin image tags in staging/production
- Use `latest` only in dev (and set `pullPolicy: Always`)
- Reference secrets via External Secrets, never inline
- Keep comments explaining non-obvious values

**Example (Production):**
```yaml
image:
  repository: 123456789.dkr.ecr.us-east-1.amazonaws.com/sample-app
  tag: "v1.2.3"

ingress:
  enabled: true
  hosts:
    - host: sample-app.internal.example.com
      paths:
        - path: /
          pathType: Prefix

env:
  - name: LOG_LEVEL
    value: "warn"
  - name: ENVIRONMENT
    value: "production"

serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789:role/sample-app-prod
```

---

## Complete Example: Sample App Across All Environments

### Layer 1: Chart Defaults

```yaml
# charts/base-app/values.yaml (relevant excerpt)
replicaCount: 2
image:
  repository: ""
  tag: ""
  pullPolicy: IfNotPresent
resources:
  requests: { memory: "128Mi", cpu: "100m" }
  limits: { memory: "256Mi", cpu: "250m" }
ingress:
  enabled: false
env: []
```

### Layer 2: Environment Common

```yaml
# environments/dev/values-common.yaml
replicaCount: 1
resources:
  requests: { memory: "64Mi", cpu: "50m" }
  limits: { memory: "128Mi", cpu: "100m" }
```

```yaml
# environments/staging/values-common.yaml
replicaCount: 2
resources:
  requests: { memory: "128Mi", cpu: "100m" }
  limits: { memory: "256Mi", cpu: "250m" }
```

```yaml
# environments/production/values-common.yaml
replicaCount: 3
resources:
  requests: { memory: "256Mi", cpu: "250m" }
  limits: { memory: "512Mi", cpu: "500m" }
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
podDisruptionBudget:
  enabled: true
  minAvailable: 1
```

### Layer 3: App-Specific

```yaml
# apps/dev/sample-app/values.yaml
image:
  repository: 123456789.dkr.ecr.us-east-1.amazonaws.com/sample-app
  tag: "latest"
  pullPolicy: Always
ingress:
  enabled: true
  hosts:
    - host: sample-app.dev.internal.example.com
      paths: [{ path: /, pathType: Prefix }]
env:
  - { name: LOG_LEVEL, value: "debug" }
  - { name: ENVIRONMENT, value: "dev" }
```

```yaml
# apps/staging/sample-app/values.yaml
image:
  repository: 123456789.dkr.ecr.us-east-1.amazonaws.com/sample-app
  tag: "v1.2.3"
ingress:
  enabled: true
  hosts:
    - host: sample-app.staging.internal.example.com
      paths: [{ path: /, pathType: Prefix }]
env:
  - { name: LOG_LEVEL, value: "info" }
  - { name: ENVIRONMENT, value: "staging" }
```

```yaml
# apps/production/sample-app/values.yaml
image:
  repository: 123456789.dkr.ecr.us-east-1.amazonaws.com/sample-app
  tag: "v1.2.3"    # Same tag as staging (promoted after testing)
ingress:
  enabled: true
  hosts:
    - host: sample-app.internal.example.com
      paths: [{ path: /, pathType: Prefix }]
env:
  - { name: LOG_LEVEL, value: "warn" }
  - { name: ENVIRONMENT, value: "production" }
resources:    # Override production common for this specific app
  requests: { memory: "512Mi", cpu: "500m" }
  limits: { memory: "1Gi", cpu: "1000m" }
```

### Effective Values (What Gets Applied)

| Key | Dev | Staging | Production |
|-----|-----|---------|------------|
| `replicaCount` | 1 (L2) | 2 (L2) | 3 (L2) |
| `image.tag` | latest (L3) | v1.2.3 (L3) | v1.2.3 (L3) |
| `image.pullPolicy` | Always (L3) | IfNotPresent (L1) | IfNotPresent (L1) |
| `resources.requests.memory` | 64Mi (L2) | 128Mi (L2) | 512Mi (L3) |
| `resources.limits.memory` | 128Mi (L2) | 256Mi (L2) | 1Gi (L3) |
| `autoscaling.enabled` | false (L1) | false (L1) | true (L2) |
| `podDisruptionBudget.enabled` | false (L1) | false (L1) | true (L2) |
| `ingress.enabled` | true (L3) | true (L3) | true (L3) |
| `env[LOG_LEVEL]` | debug (L3) | info (L3) | warn (L3) |

---

## Adding a New Application

### Step 1: Create App Values Files

```bash
# Create values for each environment
mkdir -p gitops/apps/dev/my-new-app
mkdir -p gitops/apps/staging/my-new-app
mkdir -p gitops/apps/production/my-new-app

# Copy from sample-app and customize
cp gitops/apps/dev/sample-app/values.yaml gitops/apps/dev/my-new-app/values.yaml
cp gitops/apps/staging/sample-app/values.yaml gitops/apps/staging/my-new-app/values.yaml
cp gitops/apps/production/sample-app/values.yaml gitops/apps/production/my-new-app/values.yaml
```

### Step 2: Create ArgoCD Application Manifests

```bash
# Create application manifests for each environment
cp gitops/bootstrap/applications/sample-app-dev.yaml gitops/bootstrap/applications/my-new-app-dev.yaml
cp gitops/bootstrap/applications/sample-app-staging.yaml gitops/bootstrap/applications/my-new-app-staging.yaml
cp gitops/bootstrap/applications/sample-app-production.yaml gitops/bootstrap/applications/my-new-app-production.yaml

# Update names, namespaces, and value file paths in each
```

### Step 3: Customize Values

Edit each values file:
- Update `image.repository` to point to the correct ECR repo
- Set appropriate `image.tag`
- Configure `ingress.hosts` with the correct hostname
- Set application-specific `env` variables
- Adjust `resources` if the app has different requirements

### Step 4: Commit and Push

```bash
git add gitops/apps/*/my-new-app/ gitops/bootstrap/applications/my-new-app-*.yaml
git commit -m "feat: add my-new-app deployment configuration"
git push origin main
```

The app-of-apps pattern will automatically pick up the new application manifests.

---

## Rules Summary

| # | Rule | Rationale |
|---|------|-----------|
| 1 | Never put secrets in values files | Security — use External Secrets |
| 2 | Always pin image tags in staging/prod | Reproducibility — know exactly what's deployed |
| 3 | Keep overrides minimal | Maintainability — less to review and debug |
| 4 | Comment non-obvious values | Clarity — explain why, not what |
| 5 | Use consistent key structure | Consistency — same keys across all charts |
| 6 | Test with `helm template` before committing | Validation — catch errors early |
| 7 | One values file per app per environment | Organization — clear ownership |
| 8 | Environment common values are shared | DRY — don't repeat environment-wide settings |
