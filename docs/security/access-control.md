# Access Control

## ArgoCD AppProjects (RBAC Boundary)

ArgoCD AppProjects are the primary access control mechanism. They define:

- Which Git repositories an Application can source from.
- Which destination namespaces/servers an Application can deploy to.
- Which Kubernetes resource kinds are allowed.

### `platform` Project

Manages only the root Application that drives the App of Apps pattern. Scoped to this repository and the `argocd` namespace. No cluster-scoped resources except those needed for ArgoCD itself.

### `infrastructure` Project

Manages all platform components. Allowed source repos include:

- This repository
- `charts.jetstack.io` (cert-manager)
- `victoriametrics.github.io/helm-charts/` (Victoria Metrics, Victoria Logs)
- `traefik.github.io/charts`
- `kyverno.github.io/kyverno`
- `fluent.github.io/helm-charts`

Allowed destinations: `cert-manager`, `monitoring`, `kube-system`, `kyverno`, `logging`.

Cluster-scoped resources allowed: Namespace, ClusterIssuer, ClusterPolicy, CRDs, RBAC, Admission Webhooks, Middleware, IngressClass.

### `apps` Project

Reserved for application workloads. Currently no Applications are in this project. When adding applications, restrict source repos to your application's repository only.

## Kubernetes RBAC

No custom ClusterRoles or ClusterRoleBindings are defined by this platform (beyond those created by Helm charts). All role assignments are upstream defaults.

### Recommended Hardening

For a production-like environment:

- Create a dedicated ArgoCD service account with minimal permissions.
- Add `NetworkPolicy` objects to isolate namespaces.
- Use `PodSecurityAdmission` labels as a defense-in-depth layer alongside Kyverno.
- Audit ClusterRoleBindings regularly:

  ```bash
  kubectl get clusterrolebindings -o json | \
    jq '.items[] | {name: .metadata.name, subjects: .subjects}'
  ```

## Secret Management

| Secret | Namespace | Created by | Contains |
|---|---|---|---|
| `grafana-admin-secret` | `monitoring` | Terraform | Grafana admin username/password |
| `homelab-ca-secret` | `cert-manager` | cert-manager | Local CA certificate and private key |
| `argocd-initial-admin-secret` | `argocd` | ArgoCD Helm chart | Initial admin password (delete after first login) |

### Secret Security Notes

- `homelab-ca-secret` contains a CA private key. Access is restricted to the `cert-manager` namespace. Do not copy this secret to other namespaces.
- `grafana-admin-password` is marked `sensitive = true` in Terraform. It is never logged.
- No secrets are stored in Git. The `.gitignore` and `gitleaks` pre-commit hook prevent accidental secret commits.

### Future Work: External Secrets

For production, replace Terraform-managed Kubernetes Secrets with [External Secrets Operator](https://external-secrets.io/) backed by a secret store (HashiCorp Vault, AWS SSM, etc.). This eliminates the need to pass sensitive values through Terraform state.

## Git Repository Access

The ArgoCD repo server accesses the repository over HTTPS (no credentials required for public repos). If you make the repository private:

1. Create a GitHub token with `repo:read` scope.
2. Add it as an ArgoCD repository credential:

   ```bash
   argocd repo add https://github.com/<your-org>/<your-repo>.git \
     --username <github-user> \
     --password <token>
   ```

## Related Documents

- [Policy catalog](./policy-catalog.md)
- [TLS certificates](./tls-certificates.md)
- [ArgoCD runbook](../runbooks/argocd.md)
