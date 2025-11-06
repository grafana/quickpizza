resource "kubernetes_namespace" "quickpizza" {
  metadata {
    name = var.kubernetes_namespace
  }
}