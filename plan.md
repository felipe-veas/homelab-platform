# Homelab Platform — Mejoras SRE

> Auditoría realizada el 2026-02-19. Criterio: Principal SRE / producción.
> Estado: `[ ]` pendiente · `[x]` completado · `[~]` en progreso · `[-]` descartado

---

## CRÍTICO

| # | Tarea | Estado | Commit |
|---|-------|--------|--------|
| C1 | Crear `.gitignore` (tfstate, .terraform/, tfvars, keys) | `[x]` | — |
| C2 | Agregar remote backend para Terraform (Terraform Cloud) | `[x]` | — |
| C3 | Remover `terraform.tfstate` y `.terraform/` del historial de git | `[x]` | — |
| C4 | Mover Grafana `adminPassword` a un Kubernetes Secret (via Terraform) | `[x]` | — |
| C5 | Remover credenciales hardcodeadas de `outputs.tf` | `[x]` | — |
| C6 | Lockdown AppProjects: repos, namespaces y resource kinds explícitos | `[x]` | — |
| C7 | Mover `terraform.tfvars` fuera de git (agregar a `.gitignore`) | `[x]` | — |

---

## ALTO

| # | Tarea | Estado | Commit |
|---|-------|--------|--------|
| A1 | Mover root-app de `project: default` a proyecto `platform` con restricciones | `[ ]` | — |
| A2 | Habilitar TLS en ArgoCD ingress usando `homelab-ca-issuer` | `[ ]` | — |
| A3 | Habilitar Grafana persistence (`storageClassName: local-path`, 1Gi) | `[ ]` | — |
| A4 | Configurar al menos un receiver en Alertmanager (retención 3d → 15d) | `[ ]` | — |

---

## MEDIO

| # | Tarea | Estado | Commit |
|---|-------|--------|--------|
| M1 | Agregar `livenessProbe` y `readinessProbe` al deployment demo | `[ ]` | — |
| M2 | Agregar `PodDisruptionBudget` a todos los workloads | `[ ]` | — |
| M3 | Agregar `NetworkPolicy` default-deny por namespace | `[ ]` | — |
| M4 | Agregar `securityContext` al demo (non-root, drop ALL caps, readOnlyFS) | `[ ]` | — |
| M5 | Completar sync-wave annotations en monitoring, ingress, demo | `[ ]` | — |
| M6 | Actualizar cert-manager v1.14 → v1.17, kube-prometheus v57 → v70+ | `[ ]` | — |
| M7 | Ajustar `required_version = "~> 1.14"` en providers.tf | `[ ]` | — |
| M8 | Agregar resource limits para ArgoCD `server` y `controller` | `[ ]` | — |

---

## BAJO

| # | Tarea | Estado | Commit |
|---|-------|--------|--------|
| L1 | Referenciar `redirect-https` Middleware en los Ingress | `[ ]` | — |
| L2 | Eliminar `ClusterIssuer selfsigned-ca` duplicado | `[ ]` | — |
| L3 | Definir SLOs y recording rules custom en Prometheus | `[ ]` | — |
| L4 | Escribir README con bootstrap sequence y arquitectura | `[ ]` | — |

---

## Completados

| # | Tarea | Commit |
|---|-------|--------|
| ✓ | Estructura base del repositorio (terraform, argocd, apps) | `eda9589` |
| ✓ | Adaptar providers y tfvars para cluster k3d local | — |
| ✓ | Crear `argocd/values.yaml` con config local (NodePort, insecure) | — |
| ✓ | Reemplazar ingress-nginx por configuración Traefik | — |
| ✓ | Fix root-app: `include: "**/app.yaml"` (evitaba recoger manifests crudos) | — |
| ✓ | Separar `cert-manager-config` con sync-wave para ordenar CRDs | — |
| ✓ | Aplicar `argocd/projects.yaml` al cluster (infrastructure, apps) | — |
| ✓ | Fix pre-commit `check-yaml`: agregar `--allow-multiple-documents` | — |
| ✓ | Agregar `projects.yaml` a `argocd.tf` para bootstrap idempotente | — |
