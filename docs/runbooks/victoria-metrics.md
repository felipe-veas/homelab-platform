# Runbook: Victoria Metrics Stack

## Overview

The monitoring stack is deployed as `victoria-metrics-k8s-stack` and includes:

| Component | Role |
|---|---|
| VMSingle | Metrics storage (Prometheus-compatible TSDB) |
| VMAgent | Metrics scraping agent |
| Alertmanager | Alert routing |
| kube-state-metrics | Kubernetes object metrics |
| node-exporter | Host-level metrics |
| Grafana | Visualization UI |

## Health Checks

```bash
# All monitoring pods
kubectl get pods -n monitoring

# VMSingle status (custom resource)
kubectl get vmsingle -n monitoring

# VMAgent status
kubectl get vmagent -n monitoring

# Alertmanager status
kubectl get alertmanager -n monitoring
```

## Accessing Grafana

- **URL:** `https://grafana.localhost`
- **Username:** `admin`
- **Password:** the value of `TF_VAR_grafana_admin_password` set during bootstrap

If you forgot the password:

```bash
kubectl get secret grafana-admin-secret -n monitoring \
  -o jsonpath='{.data.admin-password}' | base64 -d && echo
```

## Accessing VictoriaMetrics API

Port-forward for direct API access:

```bash
kubectl port-forward svc/vm-victoria-metrics-k8s-stack-vmsingle \
  -n monitoring 8428:8428
```

Query example:

```bash
curl 'http://localhost:8428/api/v1/query?query=up'
```

## Storage

- **VMSingle:** 5Gi PVC (`local-path` StorageClass), 3-day retention.
- **Alertmanager:** 1Gi PVC, 360-hour retention.

Check PVC usage:

```bash
kubectl get pvc -n monitoring
kubectl exec -n monitoring \
  $(kubectl get pod -n monitoring -l app.kubernetes.io/name=vmsingle -o name | head -1) \
  -- df -h /storage
```

### Storage Full

If VMSingle PVC approaches capacity:

1. Reduce retention period in `apps/victoria-metrics/app.yaml` (`retentionPeriod: "1d"`).
2. Or increase PVC size (requires resizing the `local-path` PVC — delete and recreate the PVC, data will be lost).

For production: use an external object store (S3/GCS) via VMSingle's `--storageDataPath` remote write.

## Alertmanager

Current configuration routes all alerts to a `null` receiver (alerts fire but go nowhere). To add a real notification channel:

Edit `apps/victoria-metrics/app.yaml` under `alertmanager.config.receivers`:

```yaml
receivers:
  - name: "slack"
    slack_configs:
      - api_url: "<webhook-url>"
        channel: "#alerts"
        send_resolved: true
```

Then update the route to use `slack` instead of `null`.

## Grafana Datasources

Two datasources are provisioned automatically:

- **VictoriaMetrics** (default) — points to VMSingle at `http://vm-victoria-metrics-k8s-stack-vmsingle.monitoring.svc:8428`.
- **VictoriaLogs** — points to VictoriaLogs at `http://vlogs-victoria-logs-single-server.logging.svc:9428`.

If a datasource is missing, re-sync the `victoria-metrics` ArgoCD application:

```bash
argocd app sync victoria-metrics
```

## Upgrading

1. Update `targetRevision` in `apps/victoria-metrics/app.yaml`.
2. Merge to `main`.
3. Monitor the rollout — ArgoCD uses `ServerSideApply` and `RespectIgnoreDifferences` for this application.

Note: PVC `spec` changes are ignored by ArgoCD (`ignoreDifferences` on PVC `.spec`). To resize a PVC, do it manually via `kubectl`.

## Logs

```bash
# VMSingle
kubectl logs -n monitoring -l app.kubernetes.io/name=vmsingle -f

# VMAgent
kubectl logs -n monitoring -l app.kubernetes.io/name=vmagent -f

# Grafana
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana -f

# Alertmanager
kubectl logs -n monitoring -l app.kubernetes.io/name=alertmanager -f
```

## Known Limitations

- `defaultDashboards.enabled: false` — built-in dashboards are disabled to reduce resource usage. Import dashboards manually from the [VictoriaMetrics Grafana dashboards](https://grafana.com/orgs/victoriametrics/dashboards).
- Retention is 3 days — suitable for homelab; extend for longer-term trend analysis.

## Related Documents

- [Victoria Logs runbook](./victoria-logs.md)
- [Fluent Bit runbook](./fluent-bit.md)
- [Architecture components](../architecture/components.md)
