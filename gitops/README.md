# GitOps Repository

This is the **deployment configuration repository** - separate from application source code. It contains all Kubernetes manifests, Helm charts, and environment-specific configurations for deploying applications across dev, staging, and production environments.

## Repository Structure

```
gitops/
├── README.md                          # This file
├── bootstrap/                         # ArgoCD bootstrap configuration
│   ├── app-of-apps.yaml              # Root Application that manages all other apps
│   └── applications/                 # Individual application definitions
│       ├── sample-app-dev.yaml
│       ├── sample-app-staging.yaml
│       └── sample-app-production.yaml
├── charts/                           # Helm charts (reusable templates)
│   └── base-app/                     # Standard application chart
│       ├── Chart.yaml
│       ├── values.yaml
│       ├── .helmignore
│       └── templates/
│           ├── _helpers.tpl
│           ├── deployment.yaml
│           ├── service.yaml
│           ├── ingress.yaml
│           ├── hpa.yaml
│           ├── serviceaccount.yaml
│           ├── configmap.yaml
│           ├── pdb.yaml
│           └── NOTES.txt
├── environments/                     # Environment-specific common values
│   ├── dev/
│   │   └── values-common.yaml        # Dev defaults (1 replica, low resources)
│   ├── staging/
│   │   └── values-common.yaml        # Staging defaults (2 replicas, medium resources)
│   └── production/
│       └── values-common.yaml        # Prod defaults (3 replicas, high resources, autoscaling)
├── apps/                             # Application-specific configurations
│   ├── dev/
│   │   └── sample-app/
│   │       └── values.yaml           # Dev-specific overrides for sample-app
│   ├── staging/
│   │   └── sample-app/
│   │       └── values.yaml           # Staging-specific overrides for sample-app
│   └── production/
│       └── sample-app/
│           └── values.yaml           # Production-specific overrides for sample-app
├── infrastructure/                   # Infrastructure components (not app-specific)
│   ├── ingress-nginx/
│   ├── cert-manager/
│   ├── monitoring/
│   └── external-secrets/
└── namespace-standard.yaml           # Namespace naming convention documentation
```

## How Environments Are Organized

### Three-Tier Environment Strategy

1. **Development (`dev/`)**
   - Minimal resources (1 replica, 64Mi memory)
   - Latest image tags (`:latest`)
   - Automated sync in ArgoCD
   - Internal DNS only

2. **Staging (`staging/`)**
   - Medium resources (2 replicas, 128Mi memory)
   - Pinned image tags (e.g., `v1.0.0`)
   - Automated sync in ArgoCD
   - Internal DNS only
   - Used for pre-production testing

3. **Production (`production/`)**
   - Full resources (3 replicas, 256Mi memory)
   - Pinned image tags (same as staging after promotion)
   - **Manual sync** in ArgoCD (requires explicit approval)
   - Autoscaling enabled (2-10 replicas)
   - Pod Disruption Budgets for high availability
   - Internal DNS only

### Value Hierarchy

Each application deployment uses **layered values** (merged in order):

1. **Base chart defaults** (`charts/base-app/values.yaml`)
   - Generic defaults for all applications
   
2. **Environment common values** (`environments/{env}/values-common.yaml`)
   - Environment-specific defaults (replicas, resources, ingress group)
   - Applied to all apps in that environment
   
3. **Application-specific values** (`apps/{env}/{app-name}/values.yaml`)
   - App-specific overrides (image, env vars, specific ingress host)
   - Highest priority, overrides everything above

**Example merge for `sample-app` in production:**
```bash
helm template sample-app charts/base-app \
  -f environments/production/values-common.yaml \
  -f apps/production/sample-app/values.yaml
```

## How to Add a New Application

### Step 1: Create Application Directories

```bash
mkdir -p apps/dev/{app-name}
mkdir -p apps/staging/{app-name}
mkdir -p apps/production/{app-name}
```

### Step 2: Create Environment-Specific Values Files

Create `apps/{env}/{app-name}/values.yaml` for each environment:

```yaml
# apps/dev/my-app/values.yaml
image:
  repository: ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/my-app
  tag: latest
  pullPolicy: Always

replicaCount: 1

ingress:
  enabled: true
  hosts:
    - host: my-app.dev.internal.example.com
      paths:
        - path: /
          pathType: Prefix

env:
  - name: LOG_LEVEL
    value: debug
  - name: ENVIRONMENT
    value: dev
```

### Step 3: Create ArgoCD Application Definitions

Create `bootstrap/applications/{app-name}-{env}.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app-dev
  namespace: argocd
spec:
  project: dev
  source:
    repoURL: https://github.com/your-org/shared-devsecops.git
    targetRevision: main
    path: gitops/charts/base-app
    helm:
      valueFiles:
        - ../../environments/dev/values-common.yaml
        - ../../apps/dev/my-app/values.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: dev-my-app
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

### Step 4: Commit and Push

```bash
git add apps/ bootstrap/applications/
git commit -m "feat: add my-app deployment across all environments"
git push origin main
```

ArgoCD will automatically detect the new Application and sync it.

## How to Promote Between Environments

### Promotion Workflow: Dev → Staging → Production

#### 1. Test in Dev

- Deploy to dev with `:latest` tag
- Verify functionality
- Run integration tests

#### 2. Promote to Staging

Once dev is stable:

```bash
# Update staging values with the tested image tag
# apps/staging/sample-app/values.yaml
image:
  tag: "v1.0.0"  # Pin the tag that was tested in dev
```

```bash
git add apps/staging/sample-app/values.yaml
git commit -m "chore: promote sample-app to staging (v1.0.0)"
git push origin main
```

ArgoCD will automatically sync staging (automated sync enabled).

#### 3. Promote to Production

Once staging is verified:

```bash
# Update production values with the same tested tag
# apps/production/sample-app/values.yaml
image:
  tag: "v1.0.0"  # Same tag as staging
```

```bash
git add apps/production/sample-app/values.yaml
git commit -m "chore: promote sample-app to production (v1.0.0)"
git push origin main
```

**Important:** Production has **manual sync** enabled. You must explicitly approve the sync in ArgoCD:

```bash
# View the application status
argocd app get sample-app-production

# Manually sync (requires approval)
argocd app sync sample-app-production
```

Or use the ArgoCD UI to review changes and click "Sync".

### Rollback Procedure

If production deployment fails:

```bash
# Revert the commit
git revert <commit-hash>
git push origin main

# Manually sync to rollback
argocd app sync sample-app-production
```

## Namespace Naming Convention

All applications follow the namespace pattern: `{environment}-{app-name}`

Examples:
- `dev-sample-app`
- `staging-sample-app`
- `prod-sample-app`

See `namespace-standard.yaml` for the standard namespace template.

## Key Principles

1. **Separation of Concerns**
   - Charts are generic and reusable
   - Environment values are environment-specific
   - App values are app-specific

2. **GitOps Best Practices**
   - All configuration is in Git
   - ArgoCD is the source of truth
   - Changes are made via Git commits, not kubectl

3. **Environment Progression**
   - Dev: fast iteration, latest images
   - Staging: pre-production validation, pinned images
   - Production: stability, manual approval, high availability

4. **Security**
   - Secrets are managed via External Secrets Operator (not in Git)
   - RBAC is enforced via ArgoCD projects
   - Production requires manual approval

## Common Tasks

### View Application Status

```bash
argocd app list
argocd app get sample-app-dev
```

### View Deployment Logs

```bash
kubectl logs -n dev-sample-app deployment/sample-app
```

### Check Sync Status

```bash
argocd app wait sample-app-dev
```

### Manually Trigger Sync

```bash
argocd app sync sample-app-dev
```

### Refresh Application (pull latest from Git)

```bash
argocd app get sample-app-dev --refresh
```

## References

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Helm Documentation](https://helm.sh/docs/)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)
