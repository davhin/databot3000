variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "apis" {
  description = "List of Google Cloud APIs to enable"
  type        = list(string)
  default     = []
}

resource "google_project_service" "apis" {
  for_each = toset(var.apis)
  
  project = var.project_id
  service = each.value

  disable_dependent_services = false
  disable_on_destroy        = false
}

output "enabled_apis" {
  description = "List of enabled APIs"
  value       = [for api in google_project_service.apis : api.service]
}