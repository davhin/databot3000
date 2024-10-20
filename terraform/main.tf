# Main Terraform configuration file (main.tf)

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

# Load sensitive variables from a separate file
#variable "gcp_credentials_file" {}
variable "project_id" {}

provider "google" {
  #credentials = file(var.gcp_credentials_file)
  project     = var.project_id
  region      = "us-central1"
}

resource "google_container_cluster" "autopilot_cluster" {
  name     = "my-gke-cluster"
  location = "us-central1"

  # Enable Autopilot for the cluster
  enable_autopilot = true

}

resource "google_container_node_pool" "autoscaling_pool" {
  name       = "autoscaling-pool"
  cluster    = google_container_cluster.autopilot_cluster.id
  location   = "us-central1"

  autoscaling {
    min_node_count = 0
    max_node_count = 5
  }

  node_config {
    preemptible  = true
    machine_type = "e2-medium"

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}

# Separate file for sensitive variables (terraform.tfvars)
# gcp_credentials_file = "/path/to/your/service-account-key.json"
# project_id = "your-project-id"
