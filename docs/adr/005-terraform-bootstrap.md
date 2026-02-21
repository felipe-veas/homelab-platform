# ADR-005: Terraform for ArgoCD Bootstrap

**Date:** 2025
**Status:** Accepted

## Context

ArgoCD must be installed before it can manage itself. Something outside GitOps must handle this initial bootstrap. The bootstrap also needs to create the `grafana-admin-secret` Kubernetes Secret without storing the password in Git.

## Decision

Use **Terraform** with the Kubernetes and Helm providers to:

1. Create the `argocd` and `monitoring` namespaces.
2. Install ArgoCD via Helm.
3. Apply ArgoCD AppProjects.
4. Apply the root Application.
5. Create `grafana-admin-secret`.

State is stored in **Terraform Cloud** (remote backend).

## Alternatives Considered

| Alternative | Notes |
|---|---|
| Helm CLI script | Imperative; no state tracking; no idempotency guarantees |
| ArgoCD CLI | Requires ArgoCD to already be running (circular) |
| Ansible | More suited for VM provisioning; heavy dependency for a simple Helm install |
| Shell script | Fast to write; hard to maintain; no drift detection |
| Cluster API | Overkill; designed for multi-cluster provisioning |

## Rationale

- Terraform is **idempotent** — re-running `terraform apply` is safe and will reconcile to the desired state.
- Terraform **state** tracks what was created, enabling clean `destroy`.
- The Helm provider handles the ArgoCD release. The Kubernetes provider handles namespace and secret creation.
- Sensitive variables (`grafana_admin_password`) are marked `sensitive = true` and never appear in plan output or state file in plaintext (when using Terraform Cloud).
- Terraform Cloud remote backend eliminates local state file management.

## Consequences

**Positive:**

- Bootstrap is reproducible: any operator with `terraform apply` access can recreate the cluster from scratch.
- Grafana password is not stored in Git.
- `terraform destroy` cleanly removes ArgoCD and lets ArgoCD delete all child resources via its finalizers.

**Negative:**

- Terraform Cloud dependency: if TFC is unavailable, `terraform apply` fails. Mitigated by allowing local backend fallback.
- ArgoCD upgrades require Terraform, not GitOps. This is a known limitation of the bootstrapping problem.
- Two IaC tools (Terraform + ArgoCD) require operators to be fluent in both.

## State Security

Terraform state may contain sensitive data (Kubernetes secret values encrypted by Terraform Cloud). Access to the Terraform Cloud workspace should be restricted to trusted operators.

For local development without Terraform Cloud, use a local backend and **never commit the `.terraform/` directory or `terraform.tfstate` to Git** (covered by `.gitignore`).
