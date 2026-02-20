terraform {
  required_version = ">= 1.6.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.1"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = "~> 2.0"
    }
  }
}

locals {
  kubeconfig_path = var.kubeconfig_path != "" ? var.kubeconfig_path : null
  kubeconfig_ctx  = var.kubeconfig_context != "" ? var.kubeconfig_context : null
}

provider "kubernetes" {
  config_path    = local.kubeconfig_path
  config_context = local.kubeconfig_ctx
}

provider "helm" {
  kubernetes = {
    config_path    = local.kubeconfig_path
    config_context = local.kubeconfig_ctx
  }
}

provider "kubectl" {
  config_path    = local.kubeconfig_path
  config_context = local.kubeconfig_ctx
}
