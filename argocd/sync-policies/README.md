# ArgoCD Sync Policies

This document defines the sync policy standards for different environments in ArgoCD.

## Overview

Sync policies control how ArgoCD synchronizes applications with their desired state. Different environments have different requirements for automation, safety, and control.

## Environment-Specific Policies

### Development Environment

**Characteristics:**
- Fully automated sync
- Aggressive pruning of resources
- Self-healing enabled
- Aggressive retry strategy

**Use Case:** Rapid iteration and testing

```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
  syncOptions:
    - CreateNamespace=true
    - ServerSideApply=true
    - PruneLast=true
  retry:
    limit: 5
    backoff:
      duration: 5s
      factor: 2
      maxDuration: 3m
```

### Staging Environment

**Characteristics:**
- Automated sync with moderate retry
- Pruning enabled
- Self-healing enabled
- More conservative retry strategy

**Use Case:** Pre-production validation

```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
  syncOptions:
    - CreateNamespace=true
    - ServerSideApply=true
    - PruneLast=true
  retry:
    limit: 3
    backoff:
      duration: 5s
      factor: 2
      maxDuration: 3m
```

### Production Environment

**Characteristics:**
- Manual sync required (no automation)
- Pruning enabled but careful
- Self-healing disabled (prevent unexpected changes)
- Sync windows enforced (business hours only)
- Minimal retry attempts

**Use Case:** Controlled, auditable deployments

```yaml
syncPolicy:
  automated: null  # Manual sync only
  syncOptions:
    - CreateNamespace=true
    - ServerSideApply=true
    - PruneLast=true
  retry:
    limit: 1
    backoff:
      duration: 5s
      factor: 2
      maxDuration: 1m
```

## Common Sync Options

All environments use these common sync options:

| Option | Purpose |
|--------|---------|
| `CreateNamespace=true` | Automatically create namespaces if they don't exist |
| `ServerSideApply=true` | Use server-side apply for better conflict resolution |
| `PruneLast=true` | Delete resources after new ones are created (safer) |

## Sync Window Configuration

Production environment enforces sync windows:

- **Days:** Monday - Friday
- **Time:** 09:00 - 17:00 UTC
- **Timezone:** UTC
- **Purpose:** Ensure deployments happen during business hours when support is available

## Application-Level Configuration

### Development Application Example

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-dev-app
  namespace: argocd
spec:
  project: dev
  source:
    repoURL: https://github.com/ORG/shared-devsecops-gitops.git
    targetRevision: main
    path: apps/dev/my-app
  destination:
    server: https://kubernetes.default.svc
    namespace: dev-my-app
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
      - PruneLast=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

### Staging Application Example

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-staging-app
  namespace: argocd
spec:
  project: staging
  source:
    repoURL: https://github.com/ORG/shared-devsecops-gitops.git
    targetRevision: main
    path: apps/staging/my-app
  destination:
    server: https://kubernetes.default.svc
    namespace: staging-my-app
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
      - PruneLast=true
    retry:
      limit: 3
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

### Production Application Example

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-prod-app
  namespace: argocd
spec:
  project: production
  source:
    repoURL: https://github.com/ORG/shared-devsecops-gitops.git
    targetRevision: v1.0.0  # Use semantic versioning for prod
    path: apps/production/my-app
  destination:
    server: https://kubernetes.default.svc
    namespace: prod-my-app
  syncPolicy:
    # Manual sync only - no automation
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
      - PruneLast=true
    retry:
      limit: 1
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 1m
```

## Best Practices

1. **Development:** Use aggressive automation to catch issues early
2. **Staging:** Mirror production settings but with slightly more automation
3. **Production:** Require manual approval for all changes
4. **Monitoring:** Monitor sync status and failures across all environments
5. **Rollback:** Have a clear rollback procedure for failed syncs
6. **Testing:** Test sync policies in staging before applying to production

## Troubleshooting

### Sync Failures

Check the application status:
```bash
kubectl get applications -n argocd
kubectl describe application <app-name> -n argocd
```

View sync logs:
```bash
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller -f
```

### Retry Behavior

- **Backoff:** Exponential backoff with configurable duration and max duration
- **Limit:** Maximum number of retry attempts
- **Factor:** Multiplier for backoff duration (default: 2)

### Manual Sync

For production applications, manually trigger sync:
```bash
argocd app sync <app-name>
```

With specific revision:
```bash
argocd app sync <app-name> --revision <commit-sha>
```

## References

- [ArgoCD Sync Policy Documentation](https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/)
- [ArgoCD Sync Windows](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-windows/)
- [ArgoCD Retry Configuration](https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/#automatic-sync-policy)
