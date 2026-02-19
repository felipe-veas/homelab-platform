variable "argocd_namespace" {
  description = "Namespace where ArgoCD will be installed"
  type        = string
  default     = "argocd"
}

variable "argocd_chart_version" {
  description = "Helm chart version for ArgoCD"
  type        = string
  default     = "7.7.0"
}

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = "homelab"
}

variable "kubeconfig_path" {
  description = "Path to kubeconfig file. Empty string = use KUBECONFIG env var."
  type        = string
  default     = ""
}

variable "kubeconfig_context" {
  description = "Kubernetes context to use"
  type        = string
  default     = "k3d-platform"
}

variable "grafana_admin_password" {
  description = "Grafana admin password. Set via TF_VAR_grafana_admin_password or as sensitive variable in Terraform Cloud."
  type        = string
  sensitive   = true
}
