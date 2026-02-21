# Runbook: Fluent Bit

## Overview

Fluent Bit is the log collection agent. In the current configuration it collects CPU and memory metrics via built-in inputs and writes them to stdout. Container log collection to Victoria Logs is a known gap.

| Property | Value |
|---|---|
| Chart | `fluent-bit` `0.47.1` |
| Namespace | `logging` |
| Mode | DaemonSet (one pod per node) |

## Health Checks

```bash
# Pod status
kubectl get pods -n logging -l app.kubernetes.io/name=fluent-bit

# Check Fluent Bit is processing records
kubectl logs -n logging -l app.kubernetes.io/name=fluent-bit | tail -20
```

The stdout output will show JSON records for CPU and memory metrics.

## Current Configuration

```text
INPUT: cpu (interval 1s, tag: cpu.usage)
INPUT: mem (interval 1s, tag: mem.usage)
FILTER: modify → adds host=$HOSTNAME to every record
OUTPUT: stdout (all tags)
```

## Known Gap: Container Log Collection

Fluent Bit is not collecting container logs from `/var/log/containers/` and is not forwarding anything to Victoria Logs. This is a development-only shortcut.

### Recommended Production Configuration

Replace the values section in `apps/fluent-bit/app.yaml` with:

```yaml
config:
  inputs: |
    [INPUT]
        Name              tail
        Tag               kube.*
        Path              /var/log/containers/*.log
        multiline.parser  docker, cri
        Refresh_Interval  5
        Mem_Buf_Limit     5MB
        Skip_Long_Lines   On

  filters: |
    [FILTER]
        Name                kubernetes
        Match               kube.*
        Kube_URL            https://kubernetes.default.svc:443
        Kube_CA_File        /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        Kube_Token_File     /var/run/secrets/kubernetes.io/serviceaccount/token
        Kube_Tag_Prefix     kube.var.log.containers.
        Merge_Log           On
        Keep_Log            Off
        Annotations         Off
        Labels              On

  outputs: |
    [OUTPUT]
        Name                 vlogs
        Match                kube.*
        Host                 vlogs-victoria-logs-single-server.logging.svc
        Port                 9428
        compress             gzip
        uri                  /insert/jsonline?_stream_fields=stream,kubernetes_namespace_name&_msg_field=log&_time_field=date
```

This requires the Fluent Bit ServiceAccount to have read access to Pod metadata (already created by the chart). Additionally, the DaemonSet needs host path mounts for `/var/log` — ensure the Kyverno policy for host path is not blocking this (the `monitoring` and `logging` namespaces are excluded from privileged policies).

## Troubleshooting

### Fluent Bit Pod Crash

```bash
kubectl describe pod -n logging -l app.kubernetes.io/name=fluent-bit
kubectl logs -n logging -l app.kubernetes.io/name=fluent-bit --previous
```

Common causes:

- YAML syntax error in config values (Fluent Bit config is embedded as a Helm values string).
- Memory limit too low — increase `resources.limits.memory` if you enable container log collection.

### Records Not Reaching Victoria Logs

```bash
# Check output plugin errors
kubectl logs -n logging -l app.kubernetes.io/name=fluent-bit | grep -i "error\|failed\|retry"
```

Verify Victoria Logs is reachable from the logging namespace:

```bash
kubectl run -it --rm debug --image=curlimages/curl -n logging -- \
  curl http://vlogs-victoria-logs-single-server.logging.svc:9428/health
```

## Logs

```bash
kubectl logs -n logging -l app.kubernetes.io/name=fluent-bit -f
```

## Related Documents

- [Victoria Logs runbook](./victoria-logs.md)
- [Architecture components](../architecture/components.md)
