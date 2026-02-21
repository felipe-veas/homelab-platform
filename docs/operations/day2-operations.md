# Day-2 Operations

Routine operational procedures for a running cluster.

## Upgrading a Platform Component

All upgrades go through Git. Never `helm upgrade` directly.

1. Edit the `targetRevision` field in the relevant `apps/<component>/app.yaml`.
2. Open a pull request. Pre-commit hooks run YAML linting and secret scanning.
3. Merge to `main`. ArgoCD detects the diff within its polling interval (default: 3 min) and syncs.
4. Monitor the Application in ArgoCD UI or with:

```bash
kubectl get application <name> -n argocd -w
```

### Rollback

Because every state is a Git commit, rollback = revert the commit:

```bash
git revert <commit-sha>
git push origin main
```

ArgoCD will sync back to the previous `targetRevision` automatically.

## Forcing a Manual Sync

```bash
# Via CLI
argocd app sync <app-name>

# Via kubectl
kubectl patch application <app-name> -n argocd \
  --type merge \
  -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'
```

## Checking Cluster Health

```bash
# All ArgoCD applications
kubectl get applications -n argocd

# All pods across platform namespaces
kubectl get pods -n argocd
kubectl get pods -n cert-manager
kubectl get pods -n kyverno
kubectl get pods -n monitoring
kubectl get pods -n logging

# Node resource usage
kubectl top nodes

# Pod resource usage (all namespaces)
kubectl top pods -A
```

## Rotating the Grafana Admin Password

1. Generate a new password.
2. Update the Terraform variable:

```bash
export TF_VAR_grafana_admin_password="<new-password>"
cd terraform && terraform apply -target=kubernetes_secret_v1.grafana_admin
```

1. Restart Grafana to pick up the new secret:

```bash
kubectl rollout restart deployment -n monitoring -l app.kubernetes.io/name=grafana
```

## Viewing Logs

```bash
# ArgoCD application controller logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller

# Kyverno admission controller (policy decisions)
kubectl logs -n kyverno -l app.kubernetes.io/component=admission-controller

# Fluent Bit
kubectl logs -n logging -l app.kubernetes.io/name=fluent-bit

# cert-manager
kubectl logs -n cert-manager -l app.kubernetes.io/name=cert-manager
```

## Certificate Renewal

cert-manager handles renewal automatically 30 days before expiry. To trigger manual renewal:

```bash
# List certificates
kubectl get certificates -A

# Force renewal
kubectl delete secret <tls-secret-name> -n <namespace>
# cert-manager will re-issue immediately
```

## Adding a New Application

1. Create `apps/<your-app>/app.yaml` following the ArgoCD Application spec.
2. Set `spec.project: apps` to use the `apps` AppProject.
3. Ensure all pods define resource requests/limits and liveness/readiness probes (required by Kyverno).
4. Merge to `main` — the root Application's recursive directory watch picks it up automatically.

## Scaling Kyverno

The Kyverno admission controller is set to 1 replica (adequate for homelab). In a production cluster:

```yaml
# apps/kyverno/app.yaml
admissionController:
  replicas: 3
```

## Updating ArgoCD Helm Values

ArgoCD itself is bootstrapped by Terraform, not by an ArgoCD Application. To change `argocd/values.yaml`:

```bash
cd terraform
terraform apply -target=helm_release.argocd
```

## Pre-commit Checks

Run pre-commit locally before pushing:

```bash
pip install pre-commit
pre-commit install
pre-commit run --all-files
```

Hooks enforced:

- YAML lint (yamllint)
- Markdown lint (markdownlint)
- Secret scanning (gitleaks)
- No direct commits to `main`
- Trailing whitespace, line endings, merge conflict markers

## Related Documents

- [Bootstrap guide](./bootstrap.md)
- [Disaster recovery](./disaster-recovery.md)
- [ArgoCD runbook](../runbooks/argocd.md)
