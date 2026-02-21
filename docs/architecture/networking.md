# Networking

## k3d Port Mappings

The k3d cluster exposes these ports on `localhost`:

| Host Port | Container Port | Target | Purpose |
|---|---|---|---|
| `80` | `80` | LoadBalancer (Traefik) | HTTP ingress |
| `443` | `443` | LoadBalancer (Traefik) | HTTPS ingress |
| `30080` | `30080` | `server:0` (control plane) | ArgoCD NodePort HTTP |
| `30443` | `30443` | `server:0` (control plane) | ArgoCD NodePort HTTPS |

## DNS Resolution

All ingress hostnames use `.localhost` TLD. No external DNS is required. Add entries to `/etc/hosts` if your OS does not resolve `*.localhost` automatically:

```text
127.0.0.1  argocd.localhost
127.0.0.1  grafana.localhost
```

macOS resolves `*.localhost` to `127.0.0.1` natively. Linux may require explicit entries or `systemd-resolved` configuration.

## TLS

All HTTPS traffic uses certificates issued by the local `homelab-ca-issuer`. The CA certificate is self-signed and must be trusted by your browser/OS for green-lock:

```bash
# Export the CA cert from the cluster
kubectl get secret homelab-ca-secret \
  -n cert-manager \
  -o jsonpath='{.data.tls\.crt}' | base64 -d > homelab-ca.crt

# macOS: trust the CA
sudo security add-trusted-cert -d -r trustRoot \
  -k /Library/Keychains/System.keychain homelab-ca.crt
```

## Internal Service DNS

Kubernetes in-cluster DNS follows the standard pattern:

```text
<service>.<namespace>.svc.cluster.local
```

Key internal endpoints used by platform components:

| Endpoint | Consumer |
|---|---|
| `vlogs-victoria-logs-single-server.logging.svc:9428` | Grafana VictoriaLogs datasource |
| `vm-victoria-metrics-k8s-stack-vmsingle.monitoring.svc:8428` | VMAgent remote write |
| `alertmanager.monitoring.svc:9093` | VMAgent alert routing |

## Network Policies

No explicit NetworkPolicies are defined at the platform layer. All namespaces are open for intra-cluster traffic. Adding NetworkPolicies is a recommended hardening step for production-like environments.

## Traefik Middleware

`apps/ingress/manifests/middleware.yaml` defines reusable Traefik `Middleware` objects:

- **HTTPS redirect** — any HTTP request is permanently redirected to HTTPS.
- **Security headers** — HSTS, X-Frame-Options, X-Content-Type-Options, and similar headers applied globally.

Reference these middlewares in Ingress annotations:

```yaml
annotations:
  traefik.ingress.kubernetes.io/router.middlewares: kube-system-redirect-to-https@kubernetescrd
```
