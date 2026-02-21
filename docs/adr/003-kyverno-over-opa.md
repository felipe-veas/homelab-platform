# ADR-003: Kyverno Over OPA/Gatekeeper

**Date:** 2025
**Status:** Accepted

## Context

The platform requires a policy engine to enforce security standards (Pod Security Standards, resource limits, image tagging). Two main options exist in the Kubernetes ecosystem: OPA/Gatekeeper and Kyverno.

## Decision

Use **Kyverno** as the policy engine.

## Alternatives Considered

| Alternative | Notes |
|---|---|
| OPA + Gatekeeper | CNCF graduated; uses Rego for policy authoring |
| Pod Security Admission (built-in) | Limited to PSS levels; no custom rules |
| Admission Webhooks (custom) | Full control; requires building and maintaining webhook server |
| Kubewarden | Policy-as-Wasm; interesting but immature ecosystem |

## Rationale

| Factor | Kyverno advantage |
|---|---|
| Policy language | YAML-native; no separate language (Rego) to learn |
| Kubernetes-native | Policies are CRDs; managed by GitOps like any other resource |
| CEL expressions | Kyverno 1.12+ supports CEL for complex validations without Rego |
| Generate rules | Kyverno can generate resources (e.g., default NetworkPolicies) — OPA/Gatekeeper cannot |
| Mutate rules | Kyverno can inject sidecar containers, add labels — OPA/Gatekeeper cannot |
| Policy reports | Built-in PolicyReport CRD for background scan visibility |

**Decisive factor:** The team prefers YAML-based policy authoring. Rego has a steep learning curve and policies are harder to review in PRs. Kyverno policies are readable by anyone familiar with Kubernetes manifests.

## Consequences

**Positive:**

- Policies are readable, reviewable, and managed entirely via GitOps.
- CEL expressions cover the complex validation cases without Rego.
- Background scanning provides visibility into existing non-compliant resources.
- Kyverno is CNCF incubating with strong community momentum.

**Negative:**

- Kyverno admission controller is in the critical admission path. If it is unavailable and the webhook failOpen is set, policy enforcement is bypassed. If failClosed, admission breaks. This risk is mitigated by running a stable, well-tested version.
- CRD upgrades across major Kyverno versions require careful migration (CRD v1alpha2 → v1 etc.).
- Single replica in homelab (vs. 3+ for production HA).
