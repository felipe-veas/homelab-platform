# Runbook: cert-manager

## Overview

cert-manager automates TLS certificate issuance and renewal. The platform uses a self-signed local CA chain:

```text
selfsigned (ClusterIssuer)
  └─► homelab-ca (Certificate, self-signed CA in cert-manager namespace)
        └─► homelab-ca-issuer (ClusterIssuer, issues workload certs)
```

## Health Checks

```bash
# Pod status
kubectl get pods -n cert-manager

# ClusterIssuers
kubectl get clusterissuers

# All certificates across the cluster
kubectl get certificates -A

# Check certificate readiness
kubectl get certificates -A -o wide
```

Expected: all ClusterIssuers `Ready=True`, all Certificates `Ready=True`.

## Common Operations

### Check Certificate Expiry

```bash
kubectl get certificates -A -o custom-columns=\
'NAMESPACE:.metadata.namespace,NAME:.metadata.name,READY:.status.conditions[0].status,EXPIRY:.status.notAfter'
```

### Force Certificate Renewal

cert-manager renews automatically 30 days before expiry. For immediate renewal:

```bash
# Delete the TLS secret — cert-manager reissues automatically
kubectl delete secret <tls-secret-name> -n <namespace>
```

### Inspect a CertificateRequest

```bash
kubectl get certificaterequests -n <namespace>
kubectl describe certificaterequest <name> -n <namespace>
```

### View Certificate Details (from the Secret)

```bash
kubectl get secret <tls-secret-name> -n <namespace> \
  -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout
```

## Troubleshooting

### ClusterIssuer Not Ready

```bash
kubectl describe clusterissuer homelab-ca-issuer
kubectl logs -n cert-manager -l app.kubernetes.io/name=cert-manager
```

Most common cause: `homelab-ca-secret` is missing from `cert-manager` namespace. Recreate:

```bash
cd terraform && terraform apply -target=helm_release.argocd
# Then force re-sync of cert-manager-config app
argocd app sync cert-manager-config
```

### Certificate Stuck in Pending

```bash
kubectl describe certificate <name> -n <namespace>
kubectl describe order -n <namespace>  # For ACME issuers (not used here)
```

Check the CertificateRequest and ClusterIssuer for error messages.

### Certificate Issued but Browser Shows Untrusted

The local CA is self-signed and not trusted by OS/browser by default. Trust it:

```bash
kubectl get secret homelab-ca-secret \
  -n cert-manager \
  -o jsonpath='{.data.tls\.crt}' | base64 -d > homelab-ca.crt

# macOS
sudo security add-trusted-cert -d -r trustRoot \
  -k /Library/Keychains/System.keychain homelab-ca.crt
```

## Logs

```bash
kubectl logs -n cert-manager -l app.kubernetes.io/name=cert-manager -f
kubectl logs -n cert-manager -l app.kubernetes.io/name=cert-manager-webhook -f
kubectl logs -n cert-manager -l app.kubernetes.io/name=cert-manager-cainjector -f
```

## Version

cert-manager `v1.19.3` (chart). CRDs are installed with `installCRDs: true`.

## Related Documents

- [Networking and TLS](../architecture/networking.md)
- [Architecture components](../architecture/components.md)
