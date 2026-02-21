# Architecture Overview

## Summary

homelab-platform is a GitOps-driven Kubernetes platform running on k3d (local). Every component is managed declaratively — no manual `kubectl apply` after the initial bootstrap. ArgoCD is the single source of truth enforcer.

## Design Principles

1. **GitOps first** — all cluster state lives in this repository. Drift triggers automatic self-healing.
2. **Least privilege** — Kyverno enforces Pod Security Standards at `baseline`. ArgoCD AppProjects restrict what each project can deploy.
3. **Observability by default** — metrics, logs, and alerts are wired up at the platform layer so application teams get them for free.
4. **Immutable images** — the `:latest` tag is blocked cluster-wide by policy.
5. **Resource-bounded workloads** — all pods must declare CPU/memory requests and limits.

## High-Level Architecture

```text
┌─────────────────────────────────────────────────────────┐
│                        k3d cluster                       │
│                                                         │
│  ┌──────────┐   App of Apps   ┌────────────────────┐   │
│  │  ArgoCD  │ ──────────────► │   apps/**/app.yaml │   │
│  │ (GitOps) │                 └────────────────────┘   │
│  └──────────┘                          │                │
│       │                                ▼                │
│       │              ┌─────────────────────────────┐   │
│       │              │       Platform Layer         │   │
│       │              │                             │   │
│       │              │  cert-manager  Kyverno      │   │
│       │              │  Traefik       Fluent Bit   │   │
│       │              │  VictoriaMetrics             │   │
│       │              │  VictoriaLogs  Grafana      │   │
│       │              └─────────────────────────────┘   │
│       │                                                 │
│  ┌──────────┐                                          │
│  │Terraform │  bootstraps ArgoCD + Grafana secret      │
│  └──────────┘                                          │
└─────────────────────────────────────────────────────────┘
         ▲
         │  watches
         │
┌─────────────────┐
│  GitHub repo    │
│ (source of truth│
└─────────────────┘
```

## Request Flow (Ingress)

```text
Browser / curl
     │  HTTPS :443
     ▼
  Traefik (LoadBalancer on k3d)
     │  routes by Host header
     ├──► argocd.localhost  ──► ArgoCD server (NodePort 30080/30443)
     ├──► grafana.localhost ──► Grafana Service
     └──► *.localhost       ──► application ingresses
```

TLS is terminated at Traefik using certificates issued by `cert-manager` via the `homelab-ca-issuer` (a self-signed local CA).

## Sync Wave Order

ArgoCD sync waves control the deployment order of dependencies:

| Wave | Components |
|---|---|
| 1 | cert-manager |
| 2 | cert-manager-config (ClusterIssuers) |
| 3 (default) | Kyverno, Traefik middleware, Victoria Metrics, Victoria Logs, Fluent Bit |

This ensures the CA is ready before any component requests a certificate.

## Namespaces

| Namespace | Purpose |
|---|---|
| `argocd` | ArgoCD control plane |
| `cert-manager` | Certificate management |
| `kyverno` | Policy engine |
| `monitoring` | Victoria Metrics, Grafana, Alertmanager, VMAgent, kube-state-metrics, node-exporter |
| `logging` | Fluent Bit, Victoria Logs |
| `kube-system` | k3d system components (Traefik, CoreDNS, local-path-provisioner) |

## Related Documents

- [Component details](./components.md)
- [Networking](./networking.md)
- [ADR-001: App of Apps pattern](../adr/001-gitops-app-of-apps.md)
