# ADR-004: k3d as Local Kubernetes Distribution

**Date:** 2025
**Status:** Accepted

## Context

A local Kubernetes cluster is needed to run the platform. The cluster must:

- Run on a developer laptop (macOS).
- Support multiple port mappings for ingress testing.
- Be fast to create and destroy.
- Be compatible with standard Kubernetes tooling (kubectl, Helm, ArgoCD).

## Decision

Use **k3d** (k3s in Docker) as the local Kubernetes distribution.

## Alternatives Considered

| Alternative | Notes |
|---|---|
| minikube | Mature; uses a VM or Docker driver; slower startup; less flexible port mapping |
| kind (Kubernetes in Docker) | Popular for CI; does not include a built-in ingress controller |
| k3s (bare) | Lightweight; requires a Linux VM on macOS |
| Docker Desktop Kubernetes | Easy; locked to Docker Desktop license; less configurable |
| Rancher Desktop | Good UX; containerd-based; somewhat heavier |

## Rationale

| Factor | k3d advantage |
|---|---|
| Speed | Cluster creates in ~30 seconds |
| Port mapping | Native support for mapping host ports to load balancer and node ports |
| Built-in Traefik | k3d ships with Traefik as the default ingress controller — matches the platform design |
| Built-in `local-path` | Storage provisioner included — no extra setup for PVCs |
| Lightweight | k3s removes unused features (cloud provider integrations, legacy APIs) reducing memory footprint |
| Multi-node | k3d supports multi-server/multi-agent clusters when needed |

**Decisive factor:** k3d's built-in Traefik ingress and `local-path` storage provisioner eliminate two additional setup steps compared to kind or minikube.

## Consequences

**Positive:**

- Cluster bootstrap takes ~30 seconds.
- `--port` flags in `k3d cluster create` cleanly map host ports for ingress testing.
- Matches a k3s-based production environment if the user runs k3s on edge/homelab servers.

**Negative:**

- All persistent storage (`local-path`) lives inside the k3d Docker container. Deleting the cluster or pruning Docker volumes destroys all data.
- Not bit-for-bit identical to upstream Kubernetes (k3s removes some features). This is acceptable for homelab; for production parity testing, use kind or a cloud cluster.
- macOS + Docker adds a layer of virtualization (Docker Desktop VM) that slightly degrades I/O performance for storage-intensive workloads.

## Migration Path

If the platform outgrows k3d (multi-node, persistent storage, bare-metal):

- Replace k3d with k3s directly on a homelab server (Raspberry Pi, mini PC).
- Replace `local-path` StorageClass with Longhorn or NFS-based provisioner.
- The rest of the GitOps stack (ArgoCD, Kyverno, monitoring) is distribution-agnostic.
