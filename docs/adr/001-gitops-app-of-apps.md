# ADR-001: GitOps with App of Apps Pattern

**Date:** 2025
**Status:** Accepted

## Context

The platform needs a way to manage multiple Kubernetes components (cert-manager, monitoring, logging, policy) without manual `kubectl apply` steps. The solution must support:

- Automated sync from Git.
- Ordered deployment (dependencies between components).
- Easy addition of new components without changing bootstrap scripts.

## Decision

Use **ArgoCD** as the GitOps engine with the **App of Apps** pattern:

- A single root `Application` watches `apps/**/app.yaml` recursively.
- Each file under `apps/` defines one child `Application`.
- Sync waves (`argocd.argoproj.io/sync-wave`) control deployment order.
- ArgoCD's `automated` sync with `selfHeal: true` enforces continuous reconciliation.

## Alternatives Considered

| Alternative | Rejected because |
|---|---|
| Flux | ArgoCD has a richer UI and is more widely adopted in the homelab community |
| Helm umbrella chart | Cannot express per-component sync ordering; harder to inspect individual component status |
| Plain `kubectl apply` scripts | Imperative, fragile, not self-healing |
| Kustomize root | Would need a separate GitOps tool anyway |

## Consequences

**Positive:**

- Adding a new component requires only dropping a new `apps/<name>/app.yaml` — no changes to bootstrap scripts.
- ArgoCD UI provides per-component health, sync status, and diff view.
- Git history is the complete audit trail of cluster changes.
- Self-healing automatically corrects manual drift.

**Negative:**

- ArgoCD itself is bootstrapped by Terraform, not by itself (chicken-and-egg). This means an ArgoCD upgrade requires Terraform, not GitOps.
- The App of Apps pattern can become hard to navigate as the number of apps grows. Consider switching to ArgoCD ApplicationSet generators if the number of apps exceeds ~20.
