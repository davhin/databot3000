# # # Main Terraform configuration file (main.tf)




# Provider configuration
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  billing_project = var.project_id
}

# Variables
variable "project_id" {
  description = "The ID of the project"
  type        = string
}

variable "billing_account_id" {
  description = "The ID of the billing account"
  type        = string
}

variable "region" {
  description = "The region to create the resources in"
  type        = string
}

# Add this near the top of your file, after the provider block
resource "google_project_service" "billing_budget" {
  project = var.project_id
  service = "billingbudgets.googleapis.com"
  
  disable_on_destroy = false
}

# Network configuration
resource "google_compute_network" "vpc" {
  name                    = "gke-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = "gke-subnet"
  ip_cidr_range = "10.0.0.0/20"
  region        = var.region
  network       = google_compute_network.vpc.id

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.48.0.0/14"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.52.0.0/20"
  }

  private_ip_google_access = true
}

# NAT configuration
resource "google_compute_router" "router" {
  name    = "gke-router"
  region  = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "gke-nat"
  router                            = google_compute_router.router.name
  region                            = var.region
  nat_ip_allocate_option           = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# Firewall rules
resource "google_compute_firewall" "allow_internal" {
  name    = "allow-internal"
  network = google_compute_network.vpc.id

  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }

  source_ranges = [
    "10.0.0.0/20",    # Subnet range
    "10.48.0.0/14",   # Pod range
    "10.52.0.0/20"    # Service range
  ]
}

# Service Account for GKE nodes
resource "google_service_account" "gke_sa" {
  account_id   = "gke-service-account"
  display_name = "GKE Service Account"
}

# Grant necessary roles to the service account
resource "google_project_iam_member" "gke_sa_roles" {
  project = var.project_id
  role    = "roles/container.nodeServiceAccount"
  member  = "serviceAccount:${google_service_account.gke_sa.email}"
}

# GKE Cluster
resource "google_container_cluster" "cost_optimized" {
  name     = "cost-optimized-cluster"
  location = var.region

  # Network configuration
  network    = google_compute_network.vpc.id
  subnetwork = google_compute_subnetwork.subnet.id

  # IP allocation policy
  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  # Remove default node pool
  remove_default_node_pool = true
  initial_node_count       = 1

  # Enable workload identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Enable network policy
  network_policy {
    enabled  = true
    provider = "CALICO"
  }

  # Private cluster configuration
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block = "172.16.0.0/28"
  }

  # Cluster autoscaling configuration
  cluster_autoscaling {
    enabled = true
    
    resource_limits {
      resource_type = "cpu"
      minimum       = 1
      maximum       = 8
    }
    resource_limits {
      resource_type = "memory"
      minimum       = 2
      maximum       = 32
    }

    auto_provisioning_defaults {
      disk_size = 50
      disk_type = "pd-standard"
      service_account = google_service_account.gke_sa.email
      oauth_scopes = [
        "https://www.googleapis.com/auth/cloud-platform"
      ]
    }
  }
}

# Node Pool
resource "google_container_node_pool" "primary_nodes" {
  name       = "cost-optimized-pool"
  location   = var.region
  cluster    = google_container_cluster.cost_optimized.name
  
  initial_node_count = 1

  autoscaling {
    min_node_count = 0
    max_node_count = 5
    location_policy = "BALANCED"
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    spot         = true
    machine_type = "e2-medium"
    
    service_account = google_service_account.gke_sa.email

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = {
      environment = "production"
      team        = "engineering"
    }

    # Taint for spot instances
    taint {
      key    = "cloud.google.com/gke-spot"
      value  = "true"
      effect = "NO_SCHEDULE"
    }
  }
}

# # Billing configuration
# resource "google_service_account" "billing_admin" {
#   account_id   = "billing-admin"
#   display_name = "Billing Administrator"
# }

# resource "google_billing_account_iam_member" "billing_viewer" {
#   billing_account_id = var.billing_account_id
#   role               = "roles/billing.viewer"
#   member             = "serviceAccount:${google_service_account.billing_admin.email}"
# }

# resource "google_billing_account_iam_member" "billing_admin" {
#   billing_account_id = var.billing_account_id
#   role               = "roles/billing.admin"
#   member             = "serviceAccount:${google_service_account.billing_admin.email}"
# }

# # Budget configuration
# resource "google_billing_budget" "gke_budget" {
#   depends_on = [google_project_service.billing_budget]
#   billing_account = var.billing_account_id
#   display_name    = "GKE Cluster Budget"
  
#   budget_filter {
#     projects = ["projects/${var.project_id}"]
#     labels = {
#       environment = "production"
#       team        = "engineering"
#     }
#   }

#   amount {
#     specified_amount {
#       currency_code = "USD"
#       units        = "100"
#     }
#   }

#   threshold_rules {
#     threshold_percent = 0.5
#     spend_basis      = "CURRENT_SPEND"
#   }
#   threshold_rules {
#     threshold_percent = 0.8
#     spend_basis      = "CURRENT_SPEND"
#   }
#   threshold_rules {
#     threshold_percent = 1.0
#     spend_basis      = "CURRENT_SPEND"
#   }

#   all_updates_rule {
#     monitoring_notification_channels = []
#     disable_default_iam_recipients = true
#   }
# }

# Outputs
output "cluster_name" {
  value = google_container_cluster.cost_optimized.name
}

output "cluster_endpoint" {
  value = google_container_cluster.cost_optimized.endpoint
}

output "cluster_ca_certificate" {
  value = google_container_cluster.cost_optimized.master_auth[0].cluster_ca_certificate
}




# terraform {
#   required_providers {
#     google = {
#       source  = "hashicorp/google"
#       version = "~> 4.0"
#     }
#   }
# }

# provider "google" {
#   project                = var.project_id
#   region                 = var.region
#   billing_project        = var.project_id  # Add billing_project
#   user_project_override  = true            # Enable user_project_override
# }

# # If you also need the google-beta provider
# provider "google-beta" {
#   project                = var.project_id
#   region                 = var.region
#   billing_project        = var.project_id
#   user_project_override  = true
# }

# # Make sure you have these variables defined
# variable "project_id" {
#   description = "The ID of the project"
#   type        = string
# }

# variable "billing_account_id" {
#   description = "The ID of the billing account"
#   type        = string
# }

# variable "region"{
#   description = "The region to create the resources in"
#   type = string
# }


# resource "google_container_cluster" "cost_optimized" {
#   name     = "cost-optimized-cluster"
#   location = var.region

#   # Remove default node pool
#   remove_default_node_pool = true
#   initial_node_count       = 1

#   # Enable workload identity for better security
#   workload_identity_config {
#     workload_pool = "${var.project_id}.svc.id.goog"
#   }

#   # Enable cluster autoscaling
#   cluster_autoscaling {
#     enabled = true
#     resource_limits {
#       resource_type = "cpu"
#       minimum       = 1
#       maximum       = 8
#     }
#     resource_limits {
#       resource_type = "memory"
#       minimum       = 2
#       maximum       = 32
#     }
    
#     # Automatically scale down unused nodes
#     auto_provisioning_defaults {
#       disk_size = 50
#       disk_type = "pd-standard"
#       # Use spot instances for cost savings
#       oauth_scopes = [
#         "https://www.googleapis.com/auth/cloud-platform"
#       ]
#     }
#   }
# }

# resource "google_container_node_pool" "primary_nodes" {
#   name       = "cost-optimized-pool"
#   location   = var.region
#   cluster    = google_container_cluster.cost_optimized.name

#   # More aggressive autoscaling settings
#   autoscaling {
#     min_node_count = 0
#     max_node_count = 5
#     # Use a lower scale-up threshold and higher scale-down threshold
#     location_policy = "BALANCED"
#   }

#   management {
#     auto_repair  = true
#     auto_upgrade = true
#   }

#   node_config {
#     # Use spot instances for significant cost savings
#     spot = true
#     machine_type = "e2-standard-2"

#     # Labels for cost allocation
#     labels = {
#       environment = "production"
#       team        = "engineering"
#     }
#   }
# }

# # Create a service account for billing management
# resource "google_service_account" "billing_admin" {
#   account_id   = "billing-admin"
#   display_name = "Billing Administrator"
# }

# # Grant necessary roles
# resource "google_billing_account_iam_member" "billing_viewer" {
#   billing_account_id = var.billing_account_id
#   role               = "roles/billing.viewer"
#   member             = "serviceAccount:${google_service_account.billing_admin.email}"
# }

# resource "google_billing_account_iam_member" "billing_admin" {
#   billing_account_id = var.billing_account_id
#   role               = "roles/billing.admin"
#   member             = "serviceAccount:${google_service_account.billing_admin.email}"
# }

# # Budget configuration
# resource "google_billing_budget" "gke_budget" {
#   billing_account = var.billing_account_id
#   display_name    = "GKE Cluster Budget"
  
#   budget_filter {
#     projects = ["projects/${var.project_id}"]
#   }

#   amount {
#     specified_amount {
#       currency_code = "USD"
#       units        = "100"
#     }
#   }

#   threshold_rules {
#     threshold_percent = 0.5
#   }
#   threshold_rules {
#     threshold_percent = 0.8
#   }
#   threshold_rules {
#     threshold_percent = 1.0
#   }
# }