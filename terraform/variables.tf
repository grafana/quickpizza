variable "grafana_cloud_stack" {
  description = "The name of your Grafana Cloud Stack."
  sensitive   = true
  type        = string
}

variable "grafana_cloud_token" {
  description = "An Access Policy Token that includes the following scopes for the selected Grafana Cloud Stack."
  sensitive   = true
  type        = string
}

variable "quickpizza_conf_faro_url" {
  default     = null
  description = "The URL for the Faro configuration."
  sensitive   = true
  type        = string
}

variable "quickpizza_conf_faro_app_name" {
  default     = null
  description = "The App Name for the Faro configuration."
  sensitive   = true
  type        = string
}

variable "deployment_environment" {
  default     = "production"
  description = "The Environment name of your Kubernetes Cluster. Used to populate the 'env' Label / Attribute for all Metrics, Logs and Traces."
  nullable    = false
  type        = string
}
variable "kubernetes_namespace" {
  default     = "quickpizza"
  description = "The name of the Namespace to create and install the QuickPizza Application in."
  nullable    = false
  type        = string
}

variable "quickpizza_image" {
  default     = "ghcr.io/grafana/quickpizza-local:0.15.11"
  description = "The Image to use for the QuickPizza Demo Application."
  nullable    = false
  type        = string
}

variable "quickpizza_git_ref" {
  default     = "79a5de3"
  description = "The GitHub reference to the specific commit of the QuickPizza version"
  nullable    = false
  type        = string
}


variable "quickpizza_image_pull_policy" {
  default     = "IfNotPresent"
  description = "Specifies the Pull Policy for the QuickPizza Database (Postgres) Container Image, the available Pull Policy options are `Always` (pulls the image every time a pod is created), `IfNotPresent` (pulls the image only if it's not already available locally), and `Never` (uses only the locally available image, without pulling). If you use the `latest` Image Tag (or similar), its recommended you use `Always`."
  nullable    = false
  type        = string
}


variable "quickpizza_log_level" {
  default     = "info"
  description = "The Log Level to use for the QuickPizza Demo Application, for example \"info\" or \"debug\"."
  nullable    = false
  type        = string
}

variable "enable_k8s_monitoring" {
  description = "Enable or disable Kubernetes monitoring Helm chart"
  type        = bool
  default     = false
}

variable "cluster_name" {
  type    = string
  default     = null
}

variable "externalservices_prometheus_host" {
  type    = string
  default     = null
}

variable "externalservices_prometheus_basicauth_username" {
  default     = null
  type    = string
  sensitive   = true
}

variable "externalservices_prometheus_basicauth_password" {
  default     = null
  type    = string
  sensitive   = true
}

variable "externalservices_loki_host" {
  default     = null
  type    = string
  sensitive   = true
}

variable "externalservices_loki_basicauth_username" {
  default     = null
  type    = string
  sensitive   = true
}

variable "externalservices_loki_basicauth_password" {
  default     = null
  type    = string
  sensitive   = true
}