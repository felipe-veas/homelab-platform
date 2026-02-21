# Runbook: Victoria Logs

## Overview

Victoria Logs is a log storage backend compatible with the Grafana `victoriametrics-logs-datasource` plugin. It provides a cost-efficient, single-node log store for the homelab.

| Property | Value |
|---|---|
| Chart | `victoria-logs-single` `0.11.26` |
| Namespace | `logging` |
| Retention | 7 days |
| Storage | 10Gi PVC (`local-path`) |
| HTTP port | `9428` |

## Health Checks

```bash
# Pod status
kubectl get pods -n logging -l app.kubernetes.io/name=victoria-logs

# PVC status
kubectl get pvc -n logging

# Health endpoint
kubectl port-forward svc/vlogs-victoria-logs-single-server -n logging 9428:9428 &
curl http://localhost:9428/health
```

Expected response: `OK`

## Querying Logs

Via Grafana:

1. Open `https://grafana.localhost`
2. Navigate to **Explore**
3. Select the **VictoriaLogs** datasource
4. Use LogQL-compatible queries

Via HTTP API (after port-forward):

```bash
# Fetch recent logs
curl 'http://localhost:9428/select/logsql/query?query=*&start=1h'

# Query by field
curl 'http://localhost:9428/select/logsql/query?query=namespace%3Dmonitoring'
```

## Storage Management

Check PVC usage:

```bash
kubectl exec -n logging \
  $(kubectl get pod -n logging -l app.kubernetes.io/name=victoria-logs -o name) \
  -- df -h /storage
```

If approaching capacity:

- Reduce `retentionPeriod` in `apps/victoria-logs/app.yaml` (value is in days).
- Or delete old data via the API:

  ```bash
  curl -X POST 'http://localhost:9428/internal/resetRollupResultCache'
  ```

- For a larger PVC, you must delete and recreate (data loss) since `local-path` does not support online resize.

## Log Ingestion

**Current state:** Fluent Bit is not yet configured to forward logs to Victoria Logs. Logs are currently written to stdout only.

To enable log forwarding, update `apps/fluent-bit/app.yaml` outputs:

```ini
[OUTPUT]
    Name                 vlogs
    Match                *
    Host                 vlogs-victoria-logs-single-server.logging.svc
    Port                 9428
    compress             gzip
    uri                  /insert/jsonline?_stream_fields=stream,node_name&_msg_field=log&_time_field=date
```

See the [Fluent Bit runbook](./fluent-bit.md) for complete configuration guidance.

## Logs

```bash
kubectl logs -n logging -l app.kubernetes.io/name=victoria-logs -f
```

## Related Documents

- [Fluent Bit runbook](./fluent-bit.md)
- [Victoria Metrics runbook](./victoria-metrics.md)
- [Architecture components](../architecture/components.md)
