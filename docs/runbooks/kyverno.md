# Runbook: Kyverno

## Overview

Kyverno is the policy engine. It enforces admission control policies cluster-wide in `Enforce` mode — non-compliant resources are rejected at API admission, not just reported.

## Health Checks

```bash
# Pod status (admission controller, background controller, reports controller, cleanup controller)
kubectl get pods -n kyverno

# All cluster policies and their states
kubectl get clusterpolicies

# Policy reports (background scan results)
kubectl get policyreports -A
kubectl get clusterpolicyreports
```

Expected: all pods `Running`, all ClusterPolicies `Ready=True` with `READY` count matching cluster scope.

## Checking Policy Enforcement

### Was a resource rejected by Kyverno?

```bash
# Recent admission rejections appear as events
kubectl get events -A | grep -i "policy\|kyverno"

# Or check the API server audit log equivalent via events
kubectl get events -n <namespace> --field-selector reason=PolicyViolation
```

### Why was my pod rejected?

```bash
# Try applying your manifest and capture the error
kubectl apply -f my-pod.yaml
# Error will include the policy name and message

# Or describe an existing pod that failed to schedule
kubectl describe pod <name> -n <namespace>
```

### List all violations (background scan)

```bash
kubectl get policyreports -A -o json | \
  jq '.items[].results[] | select(.result=="fail") | {policy: .policy, message: .message, resource: .resources[0].name}'
```

## Policy Reference

See [Security: Policy Catalog](../security/policy-catalog.md) for the full list of enforced policies.

## Common Exemptions

Privileged system namespaces are excluded from specific policies. The exclude list is defined within each ClusterPolicy:

```text
argocd, cert-manager, kube-system, kyverno, monitoring, logging
```

### Adding a Namespace Exemption

If a legitimate workload needs to bypass a specific policy, add it to the `exclude` block in the policy YAML under `apps/kyverno/policies/<policy-name>.yaml`:

```yaml
exclude:
  any:
    - resources:
        namespaces:
          - my-special-namespace
```

> **Caution:** Exemptions reduce security posture. Document the reason in a code comment and PR description. Prefer fixing the workload to comply with the policy.

## Upgrading Kyverno

Kyverno CRDs are managed by the Helm chart. On upgrade, ArgoCD may show a diff on `CustomResourceDefinition` objects. These are covered by `ignoreDifferences` in `apps/kyverno/app.yaml` to suppress noisy diffs on controller-managed fields.

Major version upgrades (e.g., 3.x → 4.x) may require policy migration. Check the [Kyverno migration guide](https://kyverno.io/docs/installation/upgrading/) before bumping `targetRevision`.

## Logs

```bash
# Admission controller (real-time policy decisions)
kubectl logs -n kyverno -l app.kubernetes.io/component=admission-controller -f

# Background controller (periodic scans)
kubectl logs -n kyverno -l app.kubernetes.io/component=background-controller -f

# Reports controller
kubectl logs -n kyverno -l app.kubernetes.io/component=reports-controller -f
```

## Webhook Configuration

Kyverno installs `ValidatingWebhookConfiguration` and `MutatingWebhookConfiguration` objects. These are cluster-scoped and excluded from ArgoCD drift detection (covered by `ignoreDifferences`).

If Kyverno pods are down and the webhook is blocking all admission requests (rare but possible):

```bash
# Emergency: delete the webhook to unblock admission (pods won't be validated)
kubectl delete validatingwebhookconfigurations kyverno-resource-validating-webhook-cfg
# Immediately fix the Kyverno pod issue and re-sync
argocd app sync kyverno
```

## Version

Kyverno chart `3.7.0`. Requires Kubernetes 1.26+.

## Related Documents

- [Security policy catalog](../security/policy-catalog.md)
- [Incident response](../operations/incident-response.md)
