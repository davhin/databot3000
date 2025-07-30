terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.8.0"
    }
  }
}

variable "project_id" {
  type = string
}

provider "google" {
  project         = var.project_id
  billing_project = var.project_id
  user_project_override = true
}

module "gcp_apis" {
  source = "../../../modules/gcp-apis"
  
  project_id = var.project_id
  apis = [
    "cloudbuild.googleapis.com",
    "compute.googleapis.com",
    "storage-api.googleapis.com",
    "cloudresourcemanager.googleapis.com"
  ]
}

output "enabled_apis" {
  value = module.gcp_apis.enabled_apis
}