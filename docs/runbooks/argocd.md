# Runbook: ArgoCD

## Overview

ArgoCD is the GitOps engine. It watches this repository and reconciles cluster state to match. It is bootstrapped by Terraform and is the only component **not** managed by itself.

## Health Checks

```bash
# Pod status
kubectl get pods -n argocd

# Application sync status (all apps)
kubectl get applications -n argocd

# ArgoCD server health endpoint
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
curl -k https://localhost:8080/healthz
```

Expected output: all pods `Running`, all applications `Synced`/`Healthy`.

## Accessing the UI

- **URL:** `https://argocd.localhost`
- **Username:** `admin`
- **Password:**

  ```bash
  kubectl get secret argocd-initial-admin-secret \
    -n argocd \
    -o jsonpath='{.data.password}' | base64 -d && echo
  ```

After first login, change the admin password and delete the initial secret:

```bash
argocd account update-password
kubectl delete secret argocd-initial-admin-secret -n argocd
```

## Sync Troubleshooting

### Application is OutOfSync

```bash
argocd app diff <app-name>
argocd app sync <app-name>
```

If the application is stuck and manual sync does not help:

```bash
argocd app get <app-name> --hard-refresh
argocd app sync <app-name> --force
```

### Application is Degraded

```bash
argocd app get <app-name>
kubectl describe application <app-name> -n argocd
```

Drill into the failing resource:

```bash
kubectl get events -n <destination-namespace> --sort-by='.lastTimestamp'
```

### Sync Stuck / Pending

Common cause: a resource is waiting for a dependency that has not synced yet. Check sync waves and dependencies.

```bash
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller | tail -100
```

## Upgrading ArgoCD

ArgoCD is managed by Terraform (`terraform/argocd.tf`). To upgrade:

1. Update `argocd_chart_version` in `terraform/variables.tf` (or override via env).
2. Run:

   ```bash
   cd terraform
   terraform apply -target=helm_release.argocd
   ```

3. Monitor the rollout:

   ```bash
   kubectl rollout status deployment -n argocd -l app.kubernetes.io/name=argocd-server
   ```

## AppProject Reference

| Project | Manages | Source Repos Allowed |
|---|---|---|
| `platform` | Root Application itself | This repo |
| `infrastructure` | cert-manager, Kyverno, monitoring, logging | This repo + upstream Helm repos |
| `apps` | Application workloads | This repo (extensible) |

## Logs

```bash
# Application controller (sync decisions)
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller -f

# Repo server (Git operations)
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server -f

# API server
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server -f
```

## Known Behaviors

- **Self-heal interval:** ArgoCD re-checks and corrects drift every 3 minutes by default.
- **Prune enabled:** resources deleted from Git are deleted from the cluster on the next sync.
- **`ignoreDifferences`:** some CRDs (Kyverno, Victoria Metrics PVCs) have controller-managed fields excluded from drift detection to prevent noisy sync loops. See individual `app.yaml` files.

## Alerts (Future Work)

Recommended VMAlert rules to add:

- `argocd_app_info{sync_status!="Synced"}` → alert on any out-of-sync app for > 10 minutes.
- `argocd_app_info{health_status!="Healthy"}` → alert on any degraded app for > 5 minutes.

## Related Documents

- [Operations day-2](../operations/day2-operations.md)
- [Architecture overview](../architecture/overview.md)
