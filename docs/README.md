# Documentation Index

This directory contains operational, architectural, and security documentation for the homelab-platform.

## Navigation

| Section | Description |
|---|---|
| [Architecture](./architecture/overview.md) | System design, components, and networking |
| [Operations](./operations/bootstrap.md) | Bootstrap, day-2 ops, and disaster recovery |
| [Runbooks](./runbooks/) | Component-level operational procedures |
| [Security](./security/policy-catalog.md) | Policy catalog, access control, and TLS |
| [ADRs](./adr/) | Architecture Decision Records |

## Quick Links

- [Bootstrap guide](./operations/bootstrap.md)
- [Disaster recovery](./operations/disaster-recovery.md)
- [Kyverno policy catalog](./security/policy-catalog.md)
- [ArgoCD runbook](./runbooks/argocd.md)
- [Incident response checklist](./operations/incident-response.md)

## Document Conventions

- **Runbooks** describe how to operate a component: health checks, common failures, escalation paths.
- **ADRs** record *why* a design decision was made, including the alternatives considered. They are immutable once accepted — open a new ADR to supersede an old one.
- **Operations guides** are step-by-step procedures for cluster lifecycle events.
