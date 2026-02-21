# Kyverno Policy Catalog

All policies run in `Enforce` mode — violations are rejected at admission time.

## Baseline Pod Security Standard

The platform enforces Kubernetes [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/) at the `baseline` level via the `kyverno-policies` application (upstream `kyverno/kyverno-policies` chart).

Baseline prevents known privilege escalations:

- No privileged containers
- No host namespace sharing (`hostPID`, `hostIPC`, `hostNetwork`)
- No host path volume mounts
- Restricted capabilities (only allowed: `NET_BIND_SERVICE`)
- No `runAsRoot` without explicit allowance
- No unsafe sysctls

### Namespace Exclusions from Baseline

The following namespaces are excluded from select baseline policies to allow privileged system workloads:

| Namespace | Reason |
|---|---|
| `kube-system` | Traefik, CoreDNS, local-path-provisioner require host access |
| `monitoring` | node-exporter requires host network/PID |
| `logging` | Fluent Bit DaemonSet requires host log path access |

---

## Custom Platform Policies

Defined in `apps/kyverno/policies/`:

### `disallow-default-namespace`

| Property | Value |
|---|---|
| Kind | ClusterPolicy |
| Mode | Enforce |
| Subject | Pods |
| Excludes | — |

Blocks any Pod in the `default` namespace. All workloads must declare an explicit namespace.

**Reason:** The `default` namespace is a footgun. Requiring explicit namespaces enforces intentional resource placement.

---

### `disallow-image-latest`

| Property | Value |
|---|---|
| Kind | ClusterPolicy |
| Mode | Enforce |
| Subject | Pods (containers and init containers) |
| Excludes | — |

Two rules enforced via CEL:

1. Container image must contain a `:` (tag is required).
2. Container image must not end with `:latest`.

**Reason:** The `:latest` tag is mutable. Pinning to an immutable digest or semver tag ensures reproducible deployments and prevents unexpected image changes.

---

### `disallow-loadbalancer`

| Property | Value |
|---|---|
| Kind | ClusterPolicy |
| Mode | Enforce |
| Subject | Services |

Blocks `Service` objects with `type: LoadBalancer`.

**Reason:** k3d uses a single shared LoadBalancer (Traefik). Application-level LoadBalancer services would conflict with the platform's ingress model. Use Ingress instead.

---

### `disallow-node-port`

| Property | Value |
|---|---|
| Kind | ClusterPolicy |
| Mode | Enforce |
| Subject | Services |

Blocks `Service` objects with `type: NodePort`.

**Reason:** NodePort services bypass ingress-based routing and TLS termination. All external traffic should flow through Traefik.

---

### `disallow-empty-ingress-host`

| Property | Value |
|---|---|
| Kind | ClusterPolicy |
| Mode | Enforce |
| Subject | Ingress |

Blocks Ingress rules with an empty `host` field.

**Reason:** An empty host matches all traffic, which can cause routing conflicts with other services.

---

### `restrict-ingress-classes`

| Property | Value |
|---|---|
| Kind | ClusterPolicy |
| Mode | Enforce |
| Subject | Ingress |

Restricts `ingressClassName` to the platform-approved set (currently `traefik`).

**Reason:** Prevents workloads from accidentally or maliciously using an ingress class they do not own.

---

### `restrict-ingress-wildcard`

| Property | Value |
|---|---|
| Kind | ClusterPolicy |
| Mode | Enforce |
| Subject | Ingress |

Blocks Ingress hosts that start with `*` (wildcard).

**Reason:** Wildcard hosts can unintentionally expose routes. Each service must declare an explicit hostname.

---

### `require-pod-probes`

| Property | Value |
|---|---|
| Kind | ClusterPolicy |
| Mode | Enforce |
| Subject | Pods |
| Excludes | `argocd`, `cert-manager`, `kube-system`, `kyverno`, `monitoring`, `logging` |

Requires every container to define both `livenessProbe` and `readinessProbe`.

**Reason:** Without probes, Kubernetes cannot determine if a container is actually healthy and ready to serve traffic. Platform namespaces are excluded because some system containers run as Jobs or have non-standard lifecycle patterns.

---

### `require-requests-limits`

| Property | Value |
|---|---|
| Kind | ClusterPolicy |
| Mode | Enforce |
| Subject | Pods |
| Excludes | `argocd`, `cert-manager`, `kube-system`, `kyverno`, `monitoring`, `logging` |

Requires every container to declare:

- `resources.requests.cpu`
- `resources.requests.memory`
- `resources.limits.memory`

CPU limit is intentionally not required (CPU limits cause throttling; requests are sufficient for scheduling).

**Reason:** Resource requests are required for the scheduler to make correct placement decisions. Memory limits prevent runaway containers from consuming all node memory.

---

### `pdb-min-available`

| Property | Value |
|---|---|
| Kind | ClusterPolicy |
| Mode | Enforce |
| Subject | Deployments |
| Excludes | System namespaces |

Requires a `PodDisruptionBudget` for any `Deployment` with more than 1 replica.

**Reason:** PDBs protect availability during voluntary disruptions (node drains, rolling updates).

---

## Policy Compliance Checks

```bash
# View background scan results
kubectl get policyreports -A

# Detailed violations
kubectl get policyreports -A -o json | \
  jq '.items[].results[] | select(.result=="fail")'

# Check a specific namespace
kubectl get policyreport -n <namespace> -o yaml
```

## Related Documents

- [Kyverno runbook](../runbooks/kyverno.md)
- [Access control](./access-control.md)
