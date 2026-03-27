# ArgoCD Webhook Integration

This document describes how to configure webhooks from Git repositories (GitHub, GitLab, Bitbucket) to trigger ArgoCD syncs.

## Overview

Webhooks enable automatic synchronization of ArgoCD applications when changes are pushed to your Git repository. This eliminates the need for polling and provides near-instant deployment feedback.

## Webhook URL

The ArgoCD webhook endpoint is:

```
https://argocd.internal.example.com/api/webhook
```

## Configuration by Git Provider

### GitHub

#### 1. Navigate to Repository Settings

1. Go to your repository on GitHub
2. Click **Settings** → **Webhooks**
3. Click **Add webhook**

#### 2. Configure Webhook

- **Payload URL:** `https://argocd.internal.example.com/api/webhook`
- **Content type:** `application/json`
- **Events:** Select "Let me select individual events"
  - ✓ Push events
  - ✓ Pull requests
- **Active:** ✓ Checked
- **Secret:** (Optional, see Secret Configuration section below)

#### 3. Verify Delivery

1. After adding the webhook, GitHub will attempt to deliver a test payload
2. Click on the webhook to view delivery history
3. Check the "Recent Deliveries" tab to confirm successful delivery (HTTP 200)

### GitLab

#### 1. Navigate to Project Settings

1. Go to your project on GitLab
2. Click **Settings** → **Webhooks**

#### 2. Configure Webhook

- **URL:** `https://argocd.internal.example.com/api/webhook`
- **Trigger events:**
  - ✓ Push events
  - ✓ Merge request events
- **SSL verification:** ✓ Enable (or disable if using self-signed certificates)
- **Secret token:** (Optional, see Secret Configuration section below)

#### 3. Test Webhook

1. Click **Test** → **Push events**
2. Verify the response is successful

### Bitbucket

#### 1. Navigate to Repository Settings

1. Go to your repository on Bitbucket
2. Click **Repository settings** → **Webhooks**
3. Click **Add webhook**

#### 2. Configure Webhook

- **Title:** ArgoCD Sync
- **URL:** `https://argocd.internal.example.com/api/webhook`
- **Events:**
  - ✓ Repository push
  - ✓ Pull request created
  - ✓ Pull request updated
- **Active:** ✓ Checked

#### 3. Test Webhook

1. Click on the webhook to view details
2. Click **Test** to send a test payload
3. Verify successful delivery

## Secret Configuration

### Webhook Secret Validation

To validate webhook payloads and prevent unauthorized requests, configure a secret:

#### 1. Create a Secret in ArgoCD

```bash
# Generate a random secret
SECRET=$(openssl rand -base64 32)
echo $SECRET

# Create the secret in ArgoCD
kubectl create secret generic argocd-webhook-secret \
  -n argocd \
  --from-literal=webhook-secret=$SECRET
```

#### 2. Configure ArgoCD Server

Add the webhook secret to the ArgoCD server configuration:

```yaml
# In values.yaml or via ConfigMap
server:
  extraArgs:
    - --webhook-secret=$WEBHOOK_SECRET
```

Or via ConfigMap:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cmd-params-cm
  namespace: argocd
data:
  server.webhook.secret: "your-webhook-secret-here"
```

#### 3. Configure Git Provider

Add the same secret to your Git provider's webhook configuration:

- **GitHub:** Secret field in webhook settings
- **GitLab:** Secret token field
- **Bitbucket:** Not directly supported; use IP whitelisting instead

### IP Whitelisting (Alternative)

If your Git provider doesn't support secrets, use IP whitelisting:

- **GitHub:** https://api.github.com/meta (check `hooks` field)
- **GitLab:** https://docs.gitlab.com/ee/user/gitlab_com/index.html#ip-range
- **Bitbucket:** https://confluence.atlassian.com/bitbucket/manage-webhooks-735643732.html

## Webhook Payload Format

ArgoCD expects webhook payloads in the following format:

```json
{
  "ref": "refs/heads/main",
  "repository": {
    "url": "https://github.com/ORG/shared-devsecops-gitops.git"
  }
}
```

The webhook will trigger a refresh of all applications that:
1. Use the specified repository URL
2. Target the specified branch/ref

## Troubleshooting

### Webhook Not Triggering Sync

#### 1. Verify Webhook Delivery

**GitHub:**
```bash
# Check webhook delivery history in GitHub UI
# Settings → Webhooks → Click webhook → Recent Deliveries
```

**GitLab:**
```bash
# Check webhook logs in GitLab UI
# Settings → Webhooks → Click webhook → Requests
```

#### 2. Check ArgoCD Logs

```bash
# View ArgoCD server logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server -f

# View ArgoCD application controller logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller -f
```

#### 3. Verify Webhook URL

```bash
# Test webhook endpoint
curl -X POST https://argocd.internal.example.com/api/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "ref": "refs/heads/main",
    "repository": {
      "url": "https://github.com/ORG/shared-devsecops-gitops.git"
    }
  }'
```

#### 4. Check Application Configuration

Verify that your ArgoCD Application has the correct repository URL:

```bash
kubectl get application -n argocd -o yaml | grep repoURL
```

The repository URL in the webhook payload must match exactly.

#### 5. Check Network Connectivity

```bash
# From ArgoCD pod, test connectivity to Git provider
kubectl exec -it -n argocd <argocd-server-pod> -- \
  curl -v https://github.com/ORG/shared-devsecops-gitops.git
```

### Webhook Secret Validation Failing

#### 1. Verify Secret Configuration

```bash
# Check if webhook secret is configured
kubectl get configmap argocd-cmd-params-cm -n argocd -o yaml | grep webhook
```

#### 2. Verify Secret Matches

Ensure the secret in your Git provider matches the secret configured in ArgoCD:

```bash
# Get the configured secret
kubectl get secret argocd-webhook-secret -n argocd -o jsonpath='{.data.webhook-secret}' | base64 -d
```

#### 3. Check Webhook Signature

GitHub includes a signature header in webhook requests:

```
X-Hub-Signature-256: sha256=<signature>
```

ArgoCD validates this signature against the configured secret.

### SSL/TLS Certificate Issues

If using self-signed certificates:

#### 1. Disable SSL Verification (Not Recommended)

In your Git provider's webhook settings, disable SSL verification.

#### 2. Add Certificate to ArgoCD (Recommended)

```bash
# Create a ConfigMap with the CA certificate
kubectl create configmap argocd-tls-certs \
  -n argocd \
  --from-file=ca.crt=/path/to/ca.crt
```

#### 3. Configure ArgoCD to Use Certificate

```yaml
# In values.yaml
server:
  extraArgs:
    - --tls-certs-dir=/etc/ssl/certs
  volumeMounts:
    - name: tls-certs
      mountPath: /etc/ssl/certs
volumes:
  - name: tls-certs
    configMap:
      name: argocd-tls-certs
```

## Best Practices

1. **Use HTTPS:** Always use HTTPS for webhook URLs
2. **Validate Secrets:** Configure and validate webhook secrets
3. **Monitor Deliveries:** Regularly check webhook delivery logs
4. **Rate Limiting:** Be aware of Git provider rate limits on webhook deliveries
5. **Retry Logic:** Configure appropriate retry policies in your Git provider
6. **Logging:** Enable detailed logging for webhook events
7. **Testing:** Test webhooks in a non-production environment first

## Advanced Configuration

### Webhook Filtering

To filter which applications are synced by webhooks, use the `--webhook-branch-filter` flag:

```yaml
server:
  extraArgs:
    - --webhook-branch-filter=main,develop
```

This ensures only changes to specified branches trigger syncs.

### Custom Webhook Handlers

For advanced use cases, you can implement custom webhook handlers:

```bash
# Example: Trigger sync only for specific paths
argocd app sync <app-name> --revision <commit-sha>
```

## References

- [ArgoCD Webhook Documentation](https://argo-cd.readthedocs.io/en/stable/operator-manual/webhook/)
- [GitHub Webhooks](https://docs.github.com/en/developers/webhooks-and-events/webhooks)
- [GitLab Webhooks](https://docs.gitlab.com/ee/user/project/integrations/webhooks.html)
- [Bitbucket Webhooks](https://confluence.atlassian.com/bitbucket/manage-webhooks-735643732.html)
