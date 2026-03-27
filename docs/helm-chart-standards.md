# Helm Chart Layout Standards

**Platform:** AWS EKS 1.35 (us-east-1, 3 AZs)
**Last Updated:** 2026-03-27

---

## Overview

This document defines the standards for Helm chart structure, naming conventions, values organization, and security requirements for all applications deployed on the shared-devsecops platform.

---

## Chart Structure

Every application chart must follow this directory layout:

```
charts/{app-name}/
├── Chart.yaml              # Chart metadata (required)
├── values.yaml             # Default values (required)
├── .helmignore             # Files to exclude from packaging
├── templates/              # Kubernetes manifest templates
│   ├── _helpers.tpl        # Template helper functions (required)
│   ├── deployment.yaml     # Deployment (required)
│   ├── service.yaml        # Service (required)
│   ├── ingress.yaml        # Ingress (conditional)
│   ├── hpa.yaml            # HorizontalPodAutoscaler (conditional)
│   ├── serviceaccount.yaml # ServiceAccount (conditional)
│   ├── configmap.yaml      # ConfigMap (conditional)
│   ├── pdb.yaml            # PodDisruptionBudget (conditional)
│   ├── NOTES.txt           # Post-install instructions
│   └── tests/
│       └── test-connection.yaml
└── charts/                 # Sub-chart dependencies (if any)
```

### Base Chart

Use the provided `gitops/charts/base-app/` as the starting point for all new applications. It includes all standard templates with configurable toggles.

---

## Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Chart name | lowercase, hyphens | `my-api`, `web-frontend` |
| Template files | `{resource-type}.yaml` | `deployment.yaml`, `service.yaml` |
| Helper names | `{chart-name}.{helper}` | `my-api.fullname`, `my-api.labels` |
| Value keys | camelCase | `replicaCount`, `targetPort` |
| Label values | lowercase, hyphens | `my-api`, `web-frontend` |
| Namespace | `{env}-{app-name}` | `dev-my-api`, `prod-web-frontend` |

---

## Chart.yaml Standards

```yaml
apiVersion: v2                    # Always v2 for Helm 3
name: my-api                      # Lowercase, hyphens
description: My API service       # Brief description
type: application                 # 'application' or 'library'
version: 1.0.0                    # Chart version (semver)
appVersion: "2.1.0"               # Application version (string)

maintainers:
  - name: Platform Team
    email: platform@example.com

keywords:
  - api
  - backend
```

### Versioning Rules

| Version | When to Increment | Example |
|---------|------------------|---------|
| **MAJOR** (X.0.0) | Breaking changes to values schema | Renamed keys, removed features |
| **MINOR** (0.X.0) | New features, new templates | Added HPA support, new env vars |
| **PATCH** (0.0.X) | Bug fixes, documentation | Fixed label typo, updated comments |

---

## Values File Convention

### Hierarchy (Merge Order)

```
Layer 1: charts/base-app/values.yaml          ← Chart defaults
Layer 2: environments/{env}/values-common.yaml ← Environment defaults
Layer 3: apps/{env}/{app}/values.yaml          ← App-specific overrides
```

**Last layer wins.** Values in Layer 3 override Layer 2, which overrides Layer 1.

### What Goes Where

| Layer | Contents | Example |
|-------|----------|---------|
| **Layer 1** (Chart defaults) | Sane defaults that work for local dev | `replicaCount: 2`, `resources.requests.memory: 128Mi` |
| **Layer 2** (Environment) | Environment-wide settings | `replicaCount: 3` (prod), ALB group name, node selectors |
| **Layer 3** (App-specific) | Application-specific overrides | `image.tag: v1.2.3`, app env vars, ingress host |

### Rules

1. **Never put secrets in values files** — Use External Secrets Operator
2. **Always pin image tags** in staging and production (no `latest`)
3. **Keep overrides minimal** — Only override what differs from defaults
4. **Comment non-obvious values** — Explain why, not what
5. **Use consistent key structure** across all charts

---

## Required Labels

All Kubernetes resources **must** include these labels:

```yaml
metadata:
  labels:
    # Standard Kubernetes labels
    app.kubernetes.io/name: {{ include "chart.name" . }}
    app.kubernetes.io/instance: {{ .Release.Name }}
    app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
    app.kubernetes.io/managed-by: {{ .Release.Service }}
    app.kubernetes.io/part-of: {{ include "chart.name" . }}
    
    # Helm tracking
    helm.sh/chart: {{ include "chart.chart" . }}
    
    # Custom platform labels
    environment: {{ .Values.environment | default "dev" }}
```

### Selector Labels (immutable after creation)

```yaml
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: {{ include "chart.name" . }}
      app.kubernetes.io/instance: {{ .Release.Name }}
```

> ⚠ **Never change selector labels** after initial deployment — this causes deployment failures.

---

## Resource Standards

### Resource Requests and Limits (Required)

Every container **must** define resource requests and limits:

```yaml
resources:
  requests:
    memory: "128Mi"    # Minimum guaranteed memory
    cpu: "100m"        # Minimum guaranteed CPU
  limits:
    memory: "256Mi"    # Maximum memory (OOMKilled if exceeded)
    cpu: "250m"        # Maximum CPU (throttled if exceeded)
```

**Guidelines by environment:**

| Environment | CPU Request | CPU Limit | Memory Request | Memory Limit |
|-------------|-----------|-----------|---------------|-------------|
| Dev | 50m | 100m | 64Mi | 128Mi |
| Staging | 100m | 250m | 128Mi | 256Mi |
| Production | 250m | 500m | 256Mi | 512Mi |

### Health Checks (Required)

Every deployment **must** define liveness and readiness probes:

```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 3
```

### Pod Disruption Budget (Production Required)

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
spec:
  minAvailable: 1    # Or maxUnavailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: my-api
```

### Anti-Affinity (Production Recommended)

Spread pods across availability zones:

```yaml
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
              - key: app.kubernetes.io/name
                operator: In
                values:
                  - my-api
          topologyKey: topology.kubernetes.io/zone
```

---

## Security Standards

### Container Security Context (Required)

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  runAsGroup: 1000
  fsGroup: 1000
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
    # Add only what's needed:
    # add:
    #   - NET_BIND_SERVICE
```

### Pod Security Standards

All pods must comply with the **restricted** Pod Security Standard:

| Control | Requirement |
|---------|------------|
| Privileged | ✗ Not allowed |
| Host namespaces | ✗ Not allowed |
| Host networking | ✗ Not allowed |
| Host ports | ✗ Not allowed |
| Root user | ✗ Not allowed |
| Privilege escalation | ✗ Not allowed |
| Capabilities | Drop ALL, add only needed |
| Read-only root FS | ✓ Required where possible |
| Seccomp profile | RuntimeDefault |

### Network Policies

Every application namespace should have a default-deny policy:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
```

Then add explicit allow rules per application.

### Image Standards

| Rule | Requirement |
|------|------------|
| Registry | ECR only (`ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com`) |
| Tags | Semantic versioning (`v1.2.3`), never `latest` in staging/prod |
| Scanning | Trivy scan on push, no critical/high CVEs |
| Base images | Approved base images only (distroless, alpine) |
| Immutable tags | ECR immutable tags enabled |

---

## Template Best Practices

### Use Conditional Blocks

```yaml
{{- if .Values.ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
# ...
{{- end }}
```

### Use Helper Functions

```yaml
# Good: Use helpers for repeated logic
metadata:
  labels:
    {{- include "my-api.labels" . | nindent 4 }}

# Bad: Hardcoded labels everywhere
metadata:
  labels:
    app: my-api
    version: "1.0"
```

### Quote Strings Properly

```yaml
# Good: Quote values that might be interpreted as numbers/booleans
annotations:
  prometheus.io/port: {{ .Values.service.targetPort | quote }}

# Bad: Unquoted values
annotations:
  prometheus.io/port: {{ .Values.service.targetPort }}
```

### Use `toYaml` for Complex Structures

```yaml
resources:
  {{- toYaml .Values.resources | nindent 12 }}
```

---

## Validation Checklist

Before merging any chart changes:

- [ ] `helm lint charts/{app-name}/` passes
- [ ] `helm template charts/{app-name}/ --debug` renders correctly
- [ ] All required labels present
- [ ] Resource requests and limits defined
- [ ] Health checks configured
- [ ] Security context set (non-root, read-only FS)
- [ ] No secrets in values files
- [ ] Image tags pinned (staging/prod)
- [ ] NOTES.txt updated
- [ ] Chart version incremented

```bash
# Quick validation script
helm lint charts/my-api/
helm template test charts/my-api/ -f environments/dev/values-common.yaml -f apps/dev/my-api/values.yaml --debug
```
