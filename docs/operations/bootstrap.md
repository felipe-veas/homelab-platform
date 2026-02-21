# Bootstrap Guide

Complete procedure to build the platform from zero to a fully running cluster.

## Prerequisites

| Tool | Minimum Version | Install |
|---|---|---|
| k3d | 5.x | `brew install k3d` |
| kubectl | 1.28+ | `brew install kubectl` |
| Terraform | 1.9+ | `brew install terraform` |
| Helm | 3.x | `brew install helm` |
| Git | any | system |

A Terraform Cloud account is required for the remote backend. Alternatively, replace `terraform/backend.tf` with a local backend block:

```hcl
terraform {
  backend "local" {}
}
```

## Step 1 — Create the k3d Cluster

```bash
k3d cluster create platform \
  --port "80:80@loadbalancer" \
  --port "443:443@loadbalancer" \
  --port "30080:30080@server:0" \
  --port "30443:30443@server:0"
```

Verify the cluster is healthy:

```bash
kubectl get nodes
# NAME                    STATUS   ROLES                  AGE
# k3d-platform-server-0   Ready    control-plane,master   30s
```

## Step 2 — Configure Terraform Backend

Edit `terraform/backend.tf` and replace:

- `idenx-platform` → your Terraform Cloud organization name
- `homelab-platform` → your Terraform Cloud workspace name

Or switch to local backend (see prerequisite note above).

## Step 3 — Set Required Variables

```bash
export TF_VAR_grafana_admin_password="<choose-a-strong-password>"

# Optional overrides
export TF_VAR_kubeconfig_context="k3d-platform"   # default
export TF_VAR_argocd_chart_version="9.4.3"        # default
```

If using Terraform Cloud, set `grafana_admin_password` as a sensitive workspace variable in the Terraform Cloud UI instead.

## Step 4 — Bootstrap with Terraform

```bash
cd terraform
terraform init
terraform apply
```

Terraform will:

1. Create the `argocd` and `monitoring` namespaces.
2. Install ArgoCD via Helm (`argo-cd` chart v9.4.3).
3. Apply the three AppProjects (`infrastructure`, `apps`, `platform`).
4. Apply `argocd/root-app.yaml` — this triggers the App of Apps sync.
5. Create the `grafana-admin-secret` in the `monitoring` namespace.

Expected apply time: 3–5 minutes.

## Step 5 — Wait for ArgoCD to Sync

```bash
# Watch all applications reach Synced + Healthy
kubectl get applications -n argocd -w
```

Typical sync order (driven by sync waves):

1. `cert-manager` (wave 1)
2. `cert-manager-config` (wave 2)
3. All remaining components (default wave)

Full convergence usually takes 5–10 minutes on first run (image pulls).

## Step 6 — Access the UIs

| UI | URL | Credentials |
|---|---|---|
| ArgoCD | `https://argocd.localhost` | `admin` / run command below |
| Grafana | `https://grafana.localhost` | `admin` / `$TF_VAR_grafana_admin_password` |

Get the initial ArgoCD admin password:

```bash
kubectl get secret argocd-initial-admin-secret \
  -n argocd \
  -o jsonpath='{.data.password}' | base64 -d && echo
```

> **Security:** Change the ArgoCD admin password after first login and delete `argocd-initial-admin-secret`.

## Step 7 — Trust the Local CA (Optional)

For a green browser padlock, trust the platform CA:

```bash
kubectl get secret homelab-ca-secret \
  -n cert-manager \
  -o jsonpath='{.data.tls\.crt}' | base64 -d > homelab-ca.crt

# macOS
sudo security add-trusted-cert -d -r trustRoot \
  -k /Library/Keychains/System.keychain homelab-ca.crt

# Linux (Debian/Ubuntu)
sudo cp homelab-ca.crt /usr/local/share/ca-certificates/homelab-ca.crt
sudo update-ca-certificates
```

## Adapt for Your Fork

Before applying to your own fork, update these values:

| Value | Files | Replace with |
|---|---|---|
| `https://github.com/felipe-veas/homelab-platform.git` | `argocd/*.yaml`, `apps/*/app.yaml` | Your repo URL |
| `idenx-platform` | `terraform/backend.tf` | Your TF Cloud org |
| `homelab-platform` | `terraform/backend.tf` | Your TF Cloud workspace |

## Teardown

```bash
# Destroy Terraform-managed resources first
cd terraform && terraform destroy

# Delete the k3d cluster
k3d cluster delete platform
```

> Terraform destroy removes ArgoCD and its CRDs. All PVCs (monitoring/logging data) are also deleted since they use `local-path` storage tied to the k3d node container.

## Related Documents

- [Day-2 operations](./day2-operations.md)
- [Disaster recovery](./disaster-recovery.md)
- [Architecture overview](../architecture/overview.md)
