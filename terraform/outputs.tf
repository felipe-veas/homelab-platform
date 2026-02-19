output "argocd_url" {
  description = "ArgoCD UI URL"
  value       = "http://argocd.localhost"
}

output "argocd_initial_password_command" {
  description = "Command to retrieve the initial ArgoCD admin password"
  value       = "kubectl -n ${var.argocd_namespace} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}

output "grafana_url" {
  description = "Grafana UI URL"
  value       = "http://grafana.localhost"
}

output "grafana_credentials" {
  description = "Command to retrieve Grafana admin password from the cluster"
  value       = "kubectl -n monitoring get secret grafana-admin-secret -o jsonpath='{.data.admin-password}' | base64 -d"
}
