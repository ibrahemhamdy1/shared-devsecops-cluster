# Drift Detection and Self-Healing

**Platform:** AWS EKS 1.35 (us-east-1, 3 AZs)
**GitOps Tool:** ArgoCD
**Last Updated:** 2026-03-27

---

## Overview

Configuration drift occurs when the actual state of the Kubernetes cluster diverges from the desired state defined in Git. ArgoCD continuously monitors for drift and can automatically remediate it (self-heal) or alert operators depending on the environment.

### Core Concept

```
Git (Desired State) ←→ ArgoCD (Reconciler) ←→ Kubernetes (Actual State)
                              ↓
                    Drift = Desired ≠ Actual
```

---

## How Drift Detection Works

### Reconciliation Loop

ArgoCD runs a continuous reconciliation loop:

1. **Poll Git** — Fetch latest manifests from Git repository (every 3 minutes by default)
2. **Render manifests** — Process Helm charts / Kustomize overlays
3. **Compare** — Diff rendered manifests against live cluster state
4. **Report** — Update sync status (Synced / OutOfSync)
5. **Act** — Auto-sync if enabled, or alert if manual

### Detection Methods

| Method | Trigger | Latency |
|--------|---------|---------|
| **Polling** | ArgoCD polls Git every 3 minutes | Up to 3 minutes |
| **Webhook** | Git push triggers immediate check | Seconds |
| **Manual refresh** | `argocd app get --refresh` | Immediate |
| **Hard refresh** | `argocd app get --hard-refresh` | Immediate (clears cache) |

### What's Compared

ArgoCD compares:
- Kubernetes resource specs (deployment, service, configmap, etc.)
- Labels and annotations (configurable)
- Resource counts (new/deleted resources)
- Helm release values

ArgoCD **ignores** by default:
- `status` fields
- `metadata.resourceVersion`
- `metadata.generation`
- `metadata.creationTimestamp`
- `metadata.uid`

---

## Drift Scenarios

### Scenario 1: Manual kubectl Changes

**Cause:** Someone runs `kubectl edit`, `kubectl scale`, or `kubectl set image` directly.

**Example:**
```bash
# Someone manually scales a deployment
kubectl scale deployment/sample-app -n prod-sample-app --replicas=5
```

**Detection:** ArgoCD detects replica count differs from Git-defined value.
**Resolution:** Self-heal reverts to Git-defined replica count (dev/staging) or alerts (production).

### Scenario 2: External Controller Modifications

**Cause:** HPA, VPA, or other controllers modify resource specs.

**Example:** HPA scales replicas beyond the Git-defined count.

**Resolution:** Use `ignoreDifferences` to exclude HPA-managed fields:
```yaml
spec:
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/replicas
```

### Scenario 3: Helm Hook Side Effects

**Cause:** Helm hooks create resources not tracked in the main manifest.

**Resolution:** Use proper resource tracking annotations:
```yaml
metadata:
  annotations:
    argocd.argoproj.io/hook: PostSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
```

### Scenario 4: Secret Rotation

**Cause:** External Secrets Operator updates secret values.

**Resolution:** Exclude secret data from drift detection:
```yaml
spec:
  ignoreDifferences:
    - group: ""
      kind: Secret
      jsonPointers:
        - /data
```

### Scenario 5: CRD Changes

**Cause:** CRD updates add new fields with defaults.

**Resolution:** Use `ServerSideApply` sync option to handle field ownership properly.

---

## Self-Heal Behavior by Environment

| Environment | Self-Heal | Prune | Behavior |
|-------------|-----------|-------|----------|
| **Dev** | ✓ Enabled | ✓ Enabled | Auto-revert any manual changes, delete orphaned resources |
| **Staging** | ✓ Enabled | ✓ Enabled | Auto-revert any manual changes, delete orphaned resources |
| **Production** | ✗ Disabled | ✓ Enabled | Alert only — manual intervention required |

### Why Self-Heal is Disabled in Production

- Prevents unexpected automated changes during incidents
- Allows operators to make temporary manual fixes during outages
- Gives time to investigate before reverting
- Reduces risk of cascading failures from automated remediation

---

## Configuring Drift Detection

### Dev Environment (Auto-heal)

```yaml
syncPolicy:
  automated:
    prune: true       # Delete resources not in Git
    selfHeal: true    # Revert manual changes automatically
    allowEmpty: false  # Don't sync if manifests render empty
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

### Staging Environment (Auto-heal)

```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
    allowEmpty: false
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

### Production Environment (Alert only)

```yaml
# No 'automated' block = manual sync only
syncPolicy:
  syncOptions:
    - CreateNamespace=true
    - ServerSideApply=true
    - PruneLast=true
    - PrunePropagationPolicy=foreground
  retry:
    limit: 3
    backoff:
      duration: 10s
      factor: 2
      maxDuration: 5m
```

---

## Excluding Resources from Drift Detection

### Application-Level Exclusions

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
spec:
  ignoreDifferences:
    # Ignore HPA-managed replica count
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/replicas
    # Ignore external secret data
    - group: ""
      kind: Secret
      jsonPointers:
        - /data
    # Ignore specific annotation
    - group: ""
      kind: Service
      jsonPointers:
        - /metadata/annotations/service.beta.kubernetes.io~1aws-load-balancer-type
```

### Global Exclusions (ArgoCD ConfigMap)

```yaml
# In argocd-cm ConfigMap
data:
  resource.exclusions: |
    - apiGroups:
        - "cilium.io"
      kinds:
        - CiliumIdentity
      clusters:
        - "*"
  resource.customizations.ignoreDifferences.all: |
    managedFieldsManagers:
      - kube-controller-manager
      - kube-scheduler
```

---

## Monitoring Drift

### Prometheus Metrics

ArgoCD exposes metrics for drift monitoring:

```promql
# Applications out of sync
argocd_app_info{sync_status="OutOfSync"}

# Sync failures
argocd_app_sync_total{phase="Error"}

# Health status
argocd_app_info{health_status="Degraded"}

# Reconciliation duration
argocd_app_reconcile_duration_seconds
```

### Alert Rules

```yaml
# Prometheus alert for production drift
groups:
  - name: argocd-drift
    rules:
      - alert: ArgoCDAppOutOfSync
        expr: argocd_app_info{sync_status="OutOfSync", project="production"} == 1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Production app {{ $labels.name }} is out of sync"
          description: "Application {{ $labels.name }} has been out of sync for more than 5 minutes"

      - alert: ArgoCDAppUnhealthy
        expr: argocd_app_info{health_status=~"Degraded|Missing"} == 1
        for: 3m
        labels:
          severity: critical
        annotations:
          summary: "App {{ $labels.name }} is unhealthy"
          description: "Application {{ $labels.name }} health status is {{ $labels.health_status }}"

      - alert: ArgoCDSyncFailed
        expr: increase(argocd_app_sync_total{phase="Error"}[10m]) > 0
        labels:
          severity: critical
        annotations:
          summary: "ArgoCD sync failed for {{ $labels.name }}"
```

### ArgoCD Notifications for Drift

Configured in `argocd/notifications/notifications-configmap.yaml`:
- Slack alert when production app goes OutOfSync
- Slack alert when any app health degrades
- Teams webhook for sync failures

---

## Testing Drift Detection

### Step-by-Step Test Procedure

**Prerequisites:** Sample app deployed in dev environment

#### Test 1: Manual Change Detection

```bash
# 1. Verify app is synced
argocd app get sample-app-dev
# Expected: Status: Synced, Health: Healthy

# 2. Make a manual change
kubectl scale deployment/sample-app -n dev-sample-app --replicas=5

# 3. Wait for detection (up to 3 minutes, or force refresh)
argocd app get sample-app-dev --refresh

# 4. Observe: App should show OutOfSync
argocd app get sample-app-dev
# Expected: Status: OutOfSync

# 5. Wait for self-heal (dev has selfHeal: true)
# Within seconds, ArgoCD should revert to Git-defined replica count
sleep 30
kubectl get deployment/sample-app -n dev-sample-app -o jsonpath='{.spec.replicas}'
# Expected: Original replica count from Git
```

#### Test 2: Resource Deletion Detection

```bash
# 1. Delete a resource managed by ArgoCD
kubectl delete configmap sample-app-config -n dev-sample-app

# 2. Force refresh
argocd app get sample-app-dev --refresh

# 3. Observe self-heal recreates the configmap
kubectl get configmap -n dev-sample-app
# Expected: ConfigMap recreated by ArgoCD
```

#### Test 3: Production Drift (Alert Only)

```bash
# 1. Make a manual change in production
kubectl annotate deployment/sample-app -n prod-sample-app test=drift

# 2. Refresh
argocd app get sample-app-production --refresh

# 3. Observe: OutOfSync status but NO auto-revert
argocd app get sample-app-production
# Expected: Status: OutOfSync (no self-heal)

# 4. Check Slack for drift alert

# 5. Manual remediation
argocd app sync sample-app-production
# Or: kubectl annotate deployment/sample-app -n prod-sample-app test-
```

---

## Best Practices

1. **Always use Git as source of truth** — Never make permanent changes via kubectl
2. **Configure ignoreDifferences** for fields managed by controllers (HPA, VPA, etc.)
3. **Use ServerSideApply** to handle field ownership conflicts
4. **Monitor drift metrics** in Prometheus/Grafana dashboards
5. **Alert on production drift** — OutOfSync in production is always worth investigating
6. **Test drift detection** regularly as part of platform validation
7. **Document exceptions** — If a resource is excluded from drift detection, document why
8. **Review exclusions quarterly** — Ensure exclusions are still needed
