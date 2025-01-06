terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.8.0"
    }
  }
}

variable "project" {
  type = string
}
variable "region" {
  type = string
}
variable "zone" {
  type = string
}
variable "user_email" {
  type = string
}
# variables.tf
variable "enable_gpu" {
  description = "Whether to attach a GPU to the instance"
  type        = bool
  default     = false
}

variable "gpu_type" {
  description = "Type of GPU to attach when enabled"
  type        = string
  default     = "NVIDIA_TESLA_T4"
}

variable "gpu_count" {
  description = "Number of GPUs to attach when enabled"
  type        = number
  default     = 1
}

provider "google" {
  project = var.project
  region  = var.region
}

# main.tf
resource "google_workbench_instance" "instance" {
  name     = "dev-vertex-workbench"
  location = var.zone
  gce_setup {
    machine_type = var.enable_gpu ? "n1-standard-4" : "e2-medium"
    dynamic "accelerator_configs" {
      for_each = var.enable_gpu ? [1] : []
      content {
        core_count = var.gpu_count
        type       = var.gpu_type
      }
    }
    vm_image {
      project = "cloud-notebooks-managed"
      family  = "workbench-instances"
    }
  }


  desired_state = "STOPPED"
}