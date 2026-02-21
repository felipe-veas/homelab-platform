# ADR-002: Victoria Metrics Over Prometheus

**Date:** 2025
**Status:** Accepted

## Context

The platform needs a metrics storage and alerting solution. The default Kubernetes monitoring stack is Prometheus + Alertmanager. Alternatives exist that are drop-in compatible with the Prometheus API.

## Decision

Use **Victoria Metrics k8s stack** (`victoria-metrics-k8s-stack` Helm chart) instead of `kube-prometheus-stack`.

## Alternatives Considered

| Alternative | Notes |
|---|---|
| `kube-prometheus-stack` | Industry standard; heavier resource footprint (~1-2Gi RAM for a minimal setup) |
| Thanos | Adds long-term storage capability but is overkill for homelab; adds operational complexity |
| Grafana Mimir | Cloud-native, excellent; too complex for single-node homelab |
| Datadog / New Relic | SaaS; not appropriate for a fully self-hosted homelab |

## Rationale

| Factor | VictoriaMetrics advantage |
|---|---|
| Resource usage | VMSingle uses ~50-70% less RAM than Prometheus for equivalent workloads |
| Compatibility | Fully Prometheus-compatible (PromQL, remote write, Grafana datasource) |
| Simplicity | VMSingle (single-node mode) is a single binary/pod vs. Prometheus + Thanos for HA |
| Grafana plugin | `victoriametrics-logs-datasource` unifies metrics and logs in one UI |
| Retention | Native support for per-metric retention without external tooling |

For a homelab where resources are constrained (k3d on a laptop), the lower memory footprint is the decisive factor.

## Consequences

**Positive:**

- VMAgent scrapes cluster metrics at lower cost than Prometheus.
- VMSingle stores 5Gi of metrics at 3-day retention without performance issues.
- Grafana already knows the VictoriaMetrics datasource format.
- Alertmanager is included in the stack.

**Negative:**

- VictoriaMetrics is not as widely documented as Prometheus. PromQL extensions (MetricsQL) are a superset — some advanced queries may behave differently.
- Community support (Stack Overflow, blog posts) is thinner than Prometheus.
- The `victoria-metrics-k8s-stack` chart is complex; upgrades require careful review of breaking changes.
