# homelab-platform

A GitOps-driven homelab Kubernetes platform built on [k3d](https://k3d.io/) with ArgoCD at the center.
All infrastructure and workloads are managed declaratively from this repository — no manual `kubectl apply` after the initial bootstrap.

## Design Principles

- **GitOps first.** Cluster state is a function of Git history. Drift is automatically corrected.
- **Policy as code.** Kyverno enforces security standards at admission time in `Enforce` mode — violations are rejected, not just reported.
- **Observability by default.** Metrics, logs, and alerting are wired at the platform layer. Applications get them for free.
- **Immutable artifacts.** The `:latest` image tag is blocked cluster-wide. Every workload must pin to a specific version.
- **Resource-bounded workloads.** CPU/memory requests and limits are required for all pods.

## Stack

| Layer | Tool | Version |
|---|---|---|
| Cluster | k3d (local Kubernetes / k3s in Docker) | 5.x |
| GitOps | ArgoCD | chart 9.4.3 |
| Ingress | Traefik (k3d built-in) | — |
| Certificates | cert-manager | v1.19.3 |
| Monitoring | Victoria Metrics k8s stack + Grafana | 0.71.1 |
| Logging | Fluent Bit + Victoria Logs | 0.47.1 / 0.11.26 |
| Policy | Kyverno | 3.7.0 |
| IaC | Terraform (Terraform Cloud backend) | >= 1.9 |

## Architecture

The platform follows the **App of Apps** pattern. A single root ArgoCD Application (`argocd/root-app.yaml`) recursively watches `apps/**/app.yaml` and automatically reconciles every child Application. Adding a component is as simple as dropping a new `app.yaml`.

```text
GitHub repository (source of truth)
        │
        │  watches (3 min polling)
        ▼
┌──────────────────────────────────────────────────────────┐
│                       k3d cluster                         │
│                                                          │
│  ┌──────────┐   App of Apps   ┌───────────────────────┐ │
│  │  ArgoCD  │ ──────────────► │   apps/**/app.yaml    │ │
│  │          │  self-heal      └───────────────────────┘ │
│  └──────────┘                           │                │
│  (bootstrapped                          ▼                │
│   by Terraform)         ┌──────────────────────────┐    │
│                         │      Platform Layer        │    │
│                         │                           │    │
│                         │  cert-manager  Kyverno    │    │
│                         │  Traefik MW    Fluent Bit │    │
│                         │  VictoriaMetrics  Grafana │    │
│                         │  VictoriaLogs             │    │
│                         └──────────────────────────┘    │
└──────────────────────────────────────────────────────────┘
```

### Sync Wave Order

Deployment order is controlled by ArgoCD sync waves to respect dependencies:

| Wave | Component | Reason |
|---|---|---|
| 1 | cert-manager | Must be ready before any certificate is requested |
| 2 | cert-manager-config | ClusterIssuers depend on cert-manager CRDs |
| default | Everything else | Ingress, Kyverno, monitoring, logging |

### Namespaces

| Namespace | Components |
|---|---|
| `argocd` | ArgoCD control plane |
| `cert-manager` | cert-manager + local CA |
| `kyverno` | Policy engine |
| `monitoring` | VMSingle, VMAgent, Alertmanager, Grafana, kube-state-metrics, node-exporter |
| `logging` | Fluent Bit, Victoria Logs |
| `kube-system` | Traefik, CoreDNS, local-path-provisioner (k3d built-ins) |

## Repository Structure

```text
.
├── apps/                        # ArgoCD Application manifests (App of Apps)
│   ├── cert-manager/            # cert-manager Helm release
│   ├── cert-manager-config/     # ClusterIssuers (depends on wave 1)
│   ├── fluent-bit/              # Log collector (DaemonSet)
│   ├── ingress/                 # Traefik Middleware (HTTPS redirect, security headers)
│   ├── k8s-debug/               # Debug workload
│   ├── kyverno/                 # Kyverno Helm release + custom ClusterPolicies
│   ├── kyverno-policies/        # Upstream baseline Pod Security Standard policies
│   ├── victoria-logs/           # Victoria Logs single-node (log storage)
│   └── victoria-metrics/        # Victoria Metrics stack + Grafana + Alertmanager
├── argocd/                      # ArgoCD Helm values and AppProjects
│   ├── project-apps.yaml        # AppProject: application workloads
│   ├── project-infrastructure.yaml  # AppProject: platform components
│   ├── project-platform.yaml    # AppProject: root Application itself
│   ├── root-app.yaml            # Root Application (App of Apps entry point)
│   └── values.yaml              # ArgoCD Helm values (ingress, resources, TLS)
├── terraform/                   # Bootstrap: ArgoCD install + Grafana secret
│   ├── argocd.tf                # Helm release + AppProjects + root-app
│   ├── secrets.tf               # grafana-admin-secret (sensitive, not in Git)
│   ├── variables.tf             # Input variables
│   ├── backend.tf               # Terraform Cloud remote backend
│   └── providers.tf             # Kubernetes + Helm + kubectl providers
└── docs/                        # Full operational documentation
    ├── architecture/            # System design, component reference, networking
    ├── operations/              # Bootstrap, day-2 ops, disaster recovery, incident response
    ├── runbooks/                # Per-component operational procedures
    ├── security/                # Policy catalog, access control, TLS certificates
    └── adr/                     # Architecture Decision Records
```

## Quick Start

> Full step-by-step guide: [docs/operations/bootstrap.md](docs/operations/bootstrap.md)

**Prerequisites:** k3d >= 5.x, kubectl, Terraform >= 1.9, Helm >= 3.x.

```bash
# 1. Create the cluster
k3d cluster create platform \
  --port "80:80@loadbalancer" \
  --port "443:443@loadbalancer" \
  --port "30080:30080@server:0" \
  --port "30443:30443@server:0"

# 2. Set the Grafana admin password (never committed to Git)
export TF_VAR_grafana_admin_password="<your-password>"

# 3. Bootstrap ArgoCD + secrets via Terraform
cd terraform && terraform init && terraform apply

# 4. Watch all applications converge (5-10 min on first run)
kubectl get applications -n argocd -w
```

After convergence:

| UI | URL | Credentials |
|---|---|---|
| ArgoCD | `https://argocd.localhost` | `admin` / see below |
| Grafana | `https://grafana.localhost` | `admin` / your password |

```bash
# Get initial ArgoCD admin password
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath='{.data.password}' | base64 -d && echo
```

> Change the ArgoCD password after first login and delete `argocd-initial-admin-secret`.

### Fork Adaptation

Replace these values before applying to your own fork:

| Value | Files | Replace with |
|---|---|---|
| `https://github.com/felipe-veas/homelab-platform.git` | `argocd/*.yaml`, `apps/*/app.yaml` | Your repo URL |
| `idenx-platform` | `terraform/backend.tf` | Your Terraform Cloud org |
| `homelab-platform` | `terraform/backend.tf` | Your Terraform Cloud workspace |

## Security Posture

All policies run in **Enforce** mode — non-compliant resources are rejected at admission.

| Layer | Mechanism |
|---|---|
| Pod Security | Kyverno enforces Kubernetes baseline Pod Security Standard |
| Image hygiene | `:latest` tag blocked; explicit image tag required |
| Resource safety | CPU/memory requests and limits required on all pods |
| Ingress control | LoadBalancer and NodePort service types blocked; all traffic via Traefik |
| Namespace hygiene | Workloads in `default` namespace are blocked |
| Ingress hygiene | Empty hosts, wildcard hosts, and non-`traefik` ingress classes blocked |
| Availability | PodDisruptionBudget required for Deployments with > 1 replica |
| Probes | Liveness and readiness probes required on all application pods |
| TLS | All ingress endpoints use certificates from the platform's local CA |
| Secrets | Sensitive values never committed to Git; managed by Terraform with `sensitive = true` |
| Pre-commit | `gitleaks` secret scanning + YAML/Markdown linting on every commit |

Full policy documentation: [docs/security/policy-catalog.md](docs/security/policy-catalog.md)

## Operations

| Topic | Document |
|---|---|
| First-time setup | [docs/operations/bootstrap.md](docs/operations/bootstrap.md) |
| Upgrading components, rotating secrets, adding apps | [docs/operations/day2-operations.md](docs/operations/day2-operations.md) |
| Recovering from failures | [docs/operations/disaster-recovery.md](docs/operations/disaster-recovery.md) |
| Diagnosing incidents | [docs/operations/incident-response.md](docs/operations/incident-response.md) |

### Runbooks

| Component | Runbook |
|---|---|
| ArgoCD | [docs/runbooks/argocd.md](docs/runbooks/argocd.md) |
| cert-manager | [docs/runbooks/cert-manager.md](docs/runbooks/cert-manager.md) |
| Kyverno | [docs/runbooks/kyverno.md](docs/runbooks/kyverno.md) |
| Victoria Metrics + Grafana | [docs/runbooks/victoria-metrics.md](docs/runbooks/victoria-metrics.md) |
| Victoria Logs | [docs/runbooks/victoria-logs.md](docs/runbooks/victoria-logs.md) |
| Fluent Bit | [docs/runbooks/fluent-bit.md](docs/runbooks/fluent-bit.md) |

## Architecture Decisions

Key decisions are recorded as Architecture Decision Records (ADRs) in [`docs/adr/`](docs/adr/):

| ADR | Decision |
|---|---|
| [ADR-001](docs/adr/001-gitops-app-of-apps.md) | ArgoCD with App of Apps pattern |
| [ADR-002](docs/adr/002-victoria-metrics-over-prometheus.md) | Victoria Metrics over kube-prometheus-stack |
| [ADR-003](docs/adr/003-kyverno-over-opa.md) | Kyverno over OPA/Gatekeeper |
| [ADR-004](docs/adr/004-k3d-local-cluster.md) | k3d as local Kubernetes distribution |
| [ADR-005](docs/adr/005-terraform-bootstrap.md) | Terraform for ArgoCD bootstrap |

## Contributing

All changes go through a pull request against `main`. Direct commits to `main` are blocked by pre-commit hook.

```bash
# Install pre-commit hooks (one-time setup)
pip install pre-commit
pre-commit install
```

Pre-commit checks: YAML lint, Markdown lint, secret scanning (gitleaks), trailing whitespace, line endings.

**Upgrade workflow:** edit `targetRevision` in the relevant `apps/<component>/app.yaml` → open PR → merge → ArgoCD syncs automatically. Never use `helm upgrade` directly.

## Known Limitations

- **Fluent Bit:** container log collection is not yet configured. Logs go to stdout only, not to Victoria Logs. See [runbook](docs/runbooks/fluent-bit.md) for the recommended fix.
- **Alertmanager:** all alerts route to a `null` receiver. No real notifications are configured.
- **Storage:** all PVC data uses `local-path` (inside the k3d Docker container). Data is lost if the cluster is deleted.
- **Single-node:** all components run with 1 replica. No HA. Acceptable for homelab; see runbooks for production guidance.
- **Default dashboards:** Grafana default dashboards are disabled to save resources. Import manually from the VictoriaMetrics Grafana catalog.

## License

[MIT](LICENSE)
