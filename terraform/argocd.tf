resource "kubernetes_namespace_v1" "argocd" {
  metadata {
    name = var.argocd_namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version
  namespace  = kubernetes_namespace_v1.argocd.metadata[0].name

  values = [
    file("${path.module}/../argocd/values.yaml")
  ]

  depends_on = [kubernetes_namespace_v1.argocd]
}

resource "kubectl_manifest" "argocd_projects" {
  for_each = toset([
    "${path.module}/../argocd/project-infrastructure.yaml",
    "${path.module}/../argocd/project-apps.yaml",
    "${path.module}/../argocd/project-platform.yaml",
  ])
  yaml_body = file(each.value)

  depends_on = [helm_release.argocd]
}

resource "kubectl_manifest" "root_app" {
  yaml_body = file("${path.module}/../argocd/root-app.yaml")

  depends_on = [kubectl_manifest.argocd_projects]
}
