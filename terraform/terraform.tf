terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.1"
    }
  }
  required_version = ">= 1.8.0"
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "minikube"
}
