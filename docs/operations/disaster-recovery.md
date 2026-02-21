# Disaster Recovery

Procedures for recovering the platform from partial or total failure.

## Recovery Tiers

| Scenario | Data Loss | RTO (estimated) | Procedure |
|---|---|---|---|
| Pod crash/OOMKill | None | Auto (ArgoCD self-heals) | None required |
| Node restart | None — PVCs survive | 5–10 min | [Node recovery](#node-restart) |
| Cluster deleted (PVCs lost) | Metrics/logs data | 15–20 min | [Full rebuild](#full-cluster-rebuild) |
| Corrupt ArgoCD state | None (Git is source of truth) | 10 min | [ArgoCD recovery](#argocd-recovery) |

> **Important:** This is a local homelab cluster backed by `local-path` storage. All PVC data lives inside the k3d Docker container. If the container is deleted (e.g., `k3d cluster delete` or Docker volume pruned), all metrics and log history is lost. This is acceptable for a homelab; for production, use an external storage backend.

---

## Node Restart

k3d containers may stop if Docker restarts or the host reboots.

```bash
# Check cluster status
k3d cluster list

# Start a stopped cluster
k3d cluster start platform

# Wait for nodes to become Ready
kubectl get nodes -w

# ArgoCD will self-heal all applications — no manual action needed
```

---

## ArgoCD Recovery

If the ArgoCD namespace is accidentally deleted or the ArgoCD Helm release is corrupted:

```bash
# Re-run Terraform (idempotent)
cd terraform
terraform apply
```

Terraform will re-create the ArgoCD namespace, re-install the Helm release, re-apply AppProjects, and re-apply the root Application. ArgoCD will then re-sync all applications from Git.

If Terraform state is also lost, run:

```bash
terraform init
terraform apply
```

Terraform will detect existing resources and import/reconcile them.

---

## Full Cluster Rebuild

Use this procedure when the k3d cluster is deleted and needs to be rebuilt from scratch.

### 1. Verify Git state

Confirm the main branch is clean and reflects the desired state:

```bash
git log --oneline -5
git status
```

### 2. Recreate the cluster

```bash
k3d cluster create platform \
  --port "80:80@loadbalancer" \
  --port "443:443@loadbalancer" \
  --port "30080:30080@server:0" \
  --port "30443:30443@server:0"
```

### 3. Bootstrap

Follow the full [bootstrap guide](./bootstrap.md) from Step 3 onwards.

### 4. Verify convergence

```bash
kubectl get applications -n argocd
# All should reach Synced + Healthy within 10 minutes
```

### 5. Restore Grafana dashboards

Default dashboards are not persisted (Grafana persistence is enabled but dashboards are managed in Grafana UI state). Re-import any custom dashboards from JSON exports stored outside the cluster.

> **Recommendation:** Export custom Grafana dashboards as JSON and commit them to this repository under `docs/grafana-dashboards/` or a dedicated dashboards directory. Configure Grafana provisioning to load them automatically.

---

## Recovering from a Bad Sync

If a bad commit causes ArgoCD to apply broken manifests:

```bash
# 1. Revert the bad commit
git revert <bad-commit-sha>
git push origin main

# 2. Force an immediate sync
argocd app sync <app-name> --revision HEAD

# 3. If the application is stuck in a degraded state, hard-refresh
argocd app get <app-name> --hard-refresh
```

## Recovering a Certificate

If a TLS secret is accidentally deleted:

```bash
# Delete the Certificate object to force re-issuance
kubectl delete certificate <name> -n <namespace>
# ArgoCD will re-create it from Git on the next sync
# cert-manager will then issue a new certificate automatically
```

---

## Backup Recommendations (Future Work)

| Item | Recommendation |
|---|---|
| Grafana dashboards | Export as JSON; commit to repo; use Grafana provisioning |
| ArgoCD Application state | Git is the backup — no separate backup needed |
| Kubernetes Secrets | Use External Secrets Operator + Vault/AWS SSM for production |
| Metrics/logs history | Use remote storage (S3, GCS) for VictoriaMetrics and VictoriaLogs in production |

## Related Documents

- [Bootstrap guide](./bootstrap.md)
- [Day-2 operations](./day2-operations.md)
- [Incident response](./incident-response.md)
