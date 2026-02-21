# homelab-platform

A GitOps-driven homelab Kubernetes platform built on [k3d](https://k3d.io/) with ArgoCD at the center. All infrastructure and workloads are managed declaratively from this repository.

## Stack

| Layer | Tool |
|---|---|
| Cluster | k3d (local Kubernetes) |
| GitOps | ArgoCD |
| Ingress | Traefik |
| Certificates | cert-manager |
| Monitoring | Victoria Metrics + Grafana |
| Logging | Fluent Bit + Victoria Logs |
| Policy | Kyverno |
| IaC | Terraform (Terraform Cloud backend) |

## Repository Structure

```text
.
├── apps/                        # ArgoCD Application manifests (App of Apps)
│   ├── cert-manager/            # cert-manager + ClusterIssuer
│   ├── cert-manager-config/     # cert-manager configuration
│   ├── fluent-bit/              # Log collector
│   ├── ingress/                 # Traefik middleware
│   ├── k8s-debug/               # Debug workload
│   ├── kyverno/                 # Kyverno + policies
│   ├── kyverno-policies/        # Kyverno baseline policy exclusions
│   ├── victoria-logs/           # Victoria Logs (log storage)
│   └── victoria-metrics/        # Victoria Metrics + Grafana + Alertmanager
├── argocd/                      # ArgoCD Helm values and AppProjects
│   ├── project-apps.yaml
│   ├── project-infrastructure.yaml
│   ├── project-platform.yaml
│   └── root-app.yaml            # Root app (App of Apps entry point)
└── terraform/                   # Terraform: ArgoCD bootstrap + Grafana secret
```

## Architecture

This repo follows the **App of Apps** pattern. A single root ArgoCD Application (`argocd/root-app.yaml`) watches `apps/**/app.yaml` and automatically creates child Applications for every component.

```text
root-app (platform project)
└── apps/**/app.yaml
    ├── cert-manager
    ├── ingress (Traefik middleware)
    ├── kyverno + kyverno-policies
    ├── victoria-metrics (monitoring)
    └── victoria-logs (logging)
```

## Getting Started

### Prerequisites

- [k3d](https://k3d.io/) >= 5.x
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.9
- [Helm](https://helm.sh/docs/intro/install/) >= 3.x
- A Terraform Cloud account (or replace `terraform/backend.tf` with a local backend)

### Bootstrap

#### 1. Create the k3d cluster

```bash
k3d cluster create platform \
  --port "80:80@loadbalancer" \
  --port "443:443@loadbalancer" \
  --port "30080:30080@server:0" \
  --port "30443:30443@server:0"
```

#### 2. Install ArgoCD via Terraform

```bash
cd terraform
# Set required variables
export TF_VAR_grafana_admin_password="<your-password>"

terraform init
terraform apply
```

> **Note:** Update `terraform/backend.tf` with your own Terraform Cloud organization and workspace, or replace it with a local backend.

#### 3. Bootstrap the root Application

```bash
kubectl apply -f argocd/root-app.yaml
```

ArgoCD will automatically sync all components defined under `apps/`.

### Adapt for Your Fork

Before applying, replace these values with your own:

| Value | Files | Description |
|---|---|---|
| `https://github.com/felipe-veas/homelab-platform.git` | `argocd/*.yaml`, `apps/*/app.yaml` | Your repo URL |
| `idenx-platform` | `terraform/backend.tf` | Your Terraform Cloud org |
| `homelab-platform` | `terraform/backend.tf` | Your Terraform Cloud workspace |

## Security Policies (Kyverno)

The platform enforces Kubernetes [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/) at the `baseline` level using Kyverno, with `Enforce` mode. Selected system namespaces (`monitoring`, `kube-system`, `logging`) are excluded from specific policies to allow privileged workloads.

Custom policies in `apps/kyverno/policies/`:

| Policy | Description |
|---|---|
| `disallow-default-namespace` | Blocks workloads in `default` namespace |
| `disallow-image-latest` | Blocks `:latest` image tags |
| `disallow-loadbalancer` | Blocks `LoadBalancer` service type |
| `disallow-node-port` | Blocks `NodePort` service type |
| `disallow-empty-ingress-host` | Blocks Ingress with empty host |
| `restrict-ingress-classes` | Restricts allowed ingress classes |
| `restrict-ingress-wildcard` | Blocks wildcard ingress hosts |
| `require-pod-probes` | Requires liveness/readiness probes |
| `require-requests-limits` | Requires resource requests and limits |
| `pdb-min-available` | Requires PodDisruptionBudget |

## License

[MIT](LICENSE)
