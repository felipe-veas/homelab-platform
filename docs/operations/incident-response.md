# Incident Response

Lightweight incident response checklist for this homelab platform. Adapted from SRE practices — right-sized for a single-operator environment.

## Severity Levels

| Severity | Definition | Example |
|---|---|---|
| P1 | Platform completely down | k3d cluster unreachable |
| P2 | Core component degraded | ArgoCD not syncing, Grafana unreachable |
| P3 | Non-critical component down | Fluent Bit crash, stale metrics |
| P4 | Advisory / future risk | Approaching storage limit, deprecated API warnings |

---

## First Response Checklist

Run these checks in order when something seems wrong:

```bash
# 1. Check cluster nodes
kubectl get nodes

# 2. Check all ArgoCD application statuses
kubectl get applications -n argocd

# 3. Check for failed pods across platform namespaces
kubectl get pods -A | grep -v Running | grep -v Completed

# 4. Check recent events (last 10 minutes)
kubectl get events -A --sort-by='.lastTimestamp' | tail -30

# 5. Check Kyverno for policy rejections
kubectl get events -A | grep "policy"
```

---

## Common Failure Scenarios

### ArgoCD Shows Application as "OutOfSync"

1. Check if there is an active sync operation running:

   ```bash
   kubectl get applications -n argocd -o wide
   ```

2. Look at the diff:

   ```bash
   argocd app diff <app-name>
   ```

3. If the diff is expected (someone applied manually), sync to reconcile:

   ```bash
   argocd app sync <app-name>
   ```

4. If the diff is unexpected drift, investigate who/what applied the change.

### Pod Stuck in `Pending`

```bash
kubectl describe pod <pod-name> -n <namespace>
```

Common causes:

- **Insufficient resources** — `kubectl top nodes` to check utilization.
- **PVC not bound** — `kubectl get pvc -n <namespace>`.
- **Kyverno blocking** — check events for `policy` violations.
- **Image pull failure** — `Events: Failed to pull image`.

### Pod in `CrashLoopBackOff`

```bash
kubectl logs <pod-name> -n <namespace> --previous
kubectl describe pod <pod-name> -n <namespace>
```

Common causes:

- OOMKill: increase memory limit in `app.yaml`.
- Missing ConfigMap/Secret: check mounts in pod spec.
- Application startup error: review application logs.

### Kyverno Blocking a Legitimate Workload

```bash
# Find the rejection event
kubectl get events -n <namespace> | grep -i "policy"

# Identify the policy
kubectl get clusterpolicies

# Check policy details
kubectl describe clusterpolicy <policy-name>
```

Options:

- Add a namespace-level exception in `apps/kyverno-policies/`.
- Fix the workload to comply with the policy (preferred).
- If the policy rule is too strict for your use case, adjust it in `apps/kyverno/policies/`.

### cert-manager Certificate Not Issued

```bash
kubectl describe certificate <name> -n <namespace>
kubectl describe certificaterequest -n <namespace>
kubectl logs -n cert-manager -l app.kubernetes.io/name=cert-manager
```

Common causes:

- `homelab-ca-issuer` not ready (check ClusterIssuer status).
- Secret `homelab-ca-secret` missing (re-run `terraform apply`).

### ArgoCD Cannot Reach Git

```bash
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server
```

Common causes:

- Docker network issue (check `docker network ls`).
- Rate limiting on GitHub (check for 403/429 in logs).
- Incorrect repo URL after a fork rename.

---

## Escalation Path

This is a single-operator homelab. "Escalation" means:

1. Check GitHub Issues on this repository for known problems.
2. Check upstream project issue trackers (ArgoCD, Kyverno, VictoriaMetrics).
3. Review component changelogs if a recent upgrade introduced the issue.

---

## Post-Incident Practice

Even for homelab incidents, a brief post-mortem improves future reliability:

1. **What happened?** (timeline)
2. **Why did it happen?** (root cause)
3. **How was it detected?** (or: how would monitoring have caught it sooner?)
4. **What is the corrective action?** (code change, runbook update, alert rule)

Document findings as comments in the relevant Git issue or PR.

## Related Documents

- [Day-2 operations](./day2-operations.md)
- [Disaster recovery](./disaster-recovery.md)
- [ArgoCD runbook](../runbooks/argocd.md)
- [Kyverno runbook](../runbooks/kyverno.md)
