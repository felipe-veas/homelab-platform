# Component Reference

Detailed breakdown of every platform component: version, configuration rationale, and dependencies.

## ArgoCD

| Property | Value |
|---|---|
| Chart | `argoproj/argo-helm` `argo-cd` |
| Version | `9.4.3` (chart) |
| Namespace | `argocd` |
| Bootstrapped by | Terraform |
| Ingress | `argocd.localhost` (HTTPS via Traefik) |

**Configuration notes:**

- `server.insecure: true` — ArgoCD server runs without its own TLS. Traefik terminates TLS upstream.
- NodePort `30080`/`30443` is exposed for kubectl port-forward fallback.
- Three AppProjects scope what each team/layer can deploy:
  - `platform` — manages the root Application itself.
  - `infrastructure` — cert-manager, Kyverno, monitoring, logging.
  - `apps` — workload namespace (reserved for future application teams).

## cert-manager

| Property | Value |
|---|---|
| Chart | `cert-manager` from `charts.jetstack.io` |
| Version | `v1.19.3` |
| Namespace | `cert-manager` |
| Sync wave | `1` |

**TLS chain:**

```text
selfsigned ClusterIssuer
    └─► homelab-ca Certificate (self-signed CA)
            └─► homelab-ca-issuer ClusterIssuer
                    └─► Certificates for workloads
```

All workload certificates are issued by `homelab-ca-issuer`. The CA secret (`homelab-ca-secret`) lives in the `cert-manager` namespace.

## Traefik (Ingress)

| Property | Value |
|---|---|
| Deployment | k3d built-in (not managed by ArgoCD) |
| Namespace | `kube-system` |
| Port mapping | `80→80`, `443→443` on the k3d load balancer |

ArgoCD manages only the `Middleware` custom resource in `apps/ingress/` (security headers, HTTPS redirect). Traefik itself is part of the k3d distribution.

## Kyverno

| Property | Value |
|---|---|
| Chart | `kyverno/kyverno` |
| Version | `3.7.0` |
| Namespace | `kyverno` |
| Mode | `Enforce` (all policies) |

Runs with a single admission controller replica (appropriate for local). Webhooks exclude `kube-system`, `kyverno`, and `kube-node-lease` to prevent bootstrap deadlocks.

See [policy catalog](../security/policy-catalog.md) for all enforced policies.

## Victoria Metrics Stack

| Property | Value |
|---|---|
| Chart | `victoria-metrics-k8s-stack` |
| Version | `0.71.1` |
| Namespace | `monitoring` |
| Retention | 3 days (VictoriaMetrics), 360h (Alertmanager) |
| Storage | 5Gi PVC (`local-path`) for VMSingle, 1Gi for Alertmanager |

**Included components:**

| Component | Purpose |
|---|---|
| `VMSingle` | Metrics storage (Prometheus-compatible) |
| `VMAgent` | Scrape agent (replaces Prometheus) |
| `Alertmanager` | Alert routing (currently null receiver — extend for real alerts) |
| `kube-state-metrics` | Kubernetes object metrics |
| `node-exporter` | Host-level metrics |
| `Grafana` | Visualization |

Grafana is exposed at `grafana.localhost`. The admin password is sourced from `grafana-admin-secret` (Kubernetes Secret, created by Terraform).

The `victoriametrics-logs-datasource` Grafana plugin is installed and wired to VictoriaLogs automatically.

## Victoria Logs

| Property | Value |
|---|---|
| Chart | `victoria-logs-single` |
| Version | `0.11.26` |
| Namespace | `logging` |
| Retention | 7 days |
| Storage | 10Gi PVC (`local-path`) |

Exposes HTTP on port `9428`. Grafana datasource URL: `http://vlogs-victoria-logs-single-server.logging.svc:9428`.

## Fluent Bit

| Property | Value |
|---|---|
| Chart | `fluent-bit` from `fluent.github.io/helm-charts` |
| Version | `0.47.1` |
| Namespace | `logging` |

**Current configuration (local/dev mode):**

- Inputs: CPU and memory metrics via built-in plugins (no container log collection configured yet).
- Output: `stdout` only — logs are not forwarded to VictoriaLogs yet.
- The `host` field is added to all records via a `modify` filter.

> **Note:** Container log collection to VictoriaLogs is a known gap. See [runbook](../runbooks/fluent-bit.md) for the recommended next configuration.

## Related Documents

- [Architecture overview](./overview.md)
- [Networking](./networking.md)
- [Fluent Bit runbook](../runbooks/fluent-bit.md)
- [Victoria Metrics runbook](../runbooks/victoria-metrics.md)
