# TLS Certificates

## Certificate Chain

```text
selfsigned (ClusterIssuer)
  │
  └─► homelab-ca (Certificate)
        secretName: homelab-ca-secret
        namespace: cert-manager
        isCA: true
        algorithm: ECDSA P-256
        │
        └─► homelab-ca-issuer (ClusterIssuer)
              └─► Workload certificates (per Ingress / TLS secret)
```

All workload certificates are signed by the local CA (`homelab-ca-issuer`). The CA is self-signed and not trusted by default; see the [bootstrap guide](../operations/bootstrap.md#step-7--trust-the-local-ca-optional) for OS-level trust installation.

## Current Certificate Inventory

| Certificate | Namespace | Issuer | Used by |
|---|---|---|---|
| `homelab-ca` | `cert-manager` | `selfsigned` | CA for all workload certs |
| ArgoCD TLS | `argocd` | `homelab-ca-issuer` | `argocd.localhost` |

Grafana TLS is managed by Traefik using the cert-manager integration via Ingress `tls:` annotation.

## Issuing a Certificate for a New Service

Add a `tls` section to the Ingress manifest and annotate with the ClusterIssuer:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  namespace: my-namespace
  annotations:
    cert-manager.io/cluster-issuer: homelab-ca-issuer
spec:
  ingressClassName: traefik
  tls:
    - hosts:
        - my-app.localhost
      secretName: my-app-tls
  rules:
    - host: my-app.localhost
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app
                port:
                  number: 80
```

cert-manager will automatically create `my-app-tls` secret with the certificate.

## Certificate Renewal

cert-manager renews certificates automatically when they are within 30 days of expiry (configurable via `renewBefore`). The local CA has a default validity of 10 years; workload certs default to 90 days.

To check expiry:

```bash
kubectl get certificates -A -o custom-columns=\
'NS:.metadata.namespace,NAME:.metadata.name,READY:.status.conditions[0].status,EXPIRY:.status.notAfter'
```

## Inspecting a Certificate

```bash
kubectl get secret <tls-secret-name> -n <namespace> \
  -o jsonpath='{.data.tls\.crt}' | base64 -d | \
  openssl x509 -text -noout | grep -E "Subject:|Issuer:|Not After"
```

## Security Considerations

- The CA private key (`homelab-ca-secret`) uses ECDSA P-256 — smaller and faster than RSA-2048, appropriate for a local development CA.
- CA validity is set to cert-manager defaults (10 years for local CAs). This is acceptable for homelab; for production, use a shorter validity and set up an automated CA rotation process.
- Wildcard certificates are not issued — the `restrict-ingress-wildcard` Kyverno policy blocks wildcard Ingress hosts, making wildcard certs impractical anyway.
- `server.insecure: true` on the ArgoCD server means ArgoCD terminates its own TLS at the Traefik layer, not at the pod. This is a common and safe pattern when a reverse proxy handles TLS.

## Related Documents

- [cert-manager runbook](../runbooks/cert-manager.md)
- [Networking](../architecture/networking.md)
- [Bootstrap guide](../operations/bootstrap.md)
