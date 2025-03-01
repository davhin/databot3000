terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.8.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# VPC network
resource "google_compute_network" "redis_network" {
  name                    = "redis-network"
  auto_create_subnetworks = false
}

# Subnet for Redis instance
resource "google_compute_subnetwork" "redis_subnet" {
  name          = "redis-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.redis_network.id
}

# Redis instance
resource "google_redis_instance" "cache" {
  name           = var.redis_instance_name
  tier           = "STANDARD_HA"  # High Availability for production
  memory_size_gb = 5

  region                  = var.region
  location_id             = "${var.region}-a"  # Specific zone in the region
  alternative_location_id = "${var.region}-c"  # Second zone for HA

  authorized_network = google_compute_network.redis_network.id
  
  redis_version     = "REDIS_6_X"
  display_name      = "Redis Cache for Cloud Run"
  
  # Private Service Access
  connect_mode = "PRIVATE_SERVICE_ACCESS"
  
  # Optional: Redis configuration parameters
  redis_configs = {
    maxmemory-policy = "allkeys-lru"
  }
  
  # Optional: Redis Auth enabled (more secure)
  auth_enabled = true
  
#   # Optional: Maintenance window
#   maintenance_policy {
#     weekly_maintenance_window {
#       day = "SUNDAY"
#       start_time {
#         hours   = 2
#         minutes = 0
#       }
#     }
#   }
  
  # Depends on VPC and subnet
  depends_on = [
    google_compute_network.redis_network,
    google_compute_subnetwork.redis_subnet
  ]
}

# Private service access for Redis
resource "google_compute_global_address" "redis_private_ip_address" {
  name          = "redis-private-ip-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.redis_network.id
}

resource "google_service_networking_connection" "redis_private_vpc_connection" {
  network                 = google_compute_network.redis_network.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.redis_private_ip_address.name]
}

# Serverless VPC Access connector for Cloud Run to access Redis
resource "google_vpc_access_connector" "connector" {
  name          = "vpc-connector"
  region        = var.region
  network       = google_compute_network.redis_network.name
  ip_cidr_range = "10.8.0.0/28"  # Must be /28 and not overlap with other subnets
}

# Output the Redis instance ID and connection info
output "redis_instance_id" {
  value = google_redis_instance.cache.id
}

output "redis_host" {
  value = google_redis_instance.cache.host
}

output "redis_port" {
  value = google_redis_instance.cache.port
}

# Variables
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "redis_instance_name" {
  description = "Name for the Redis instance"
  type        = string
  default     = "redis-cache"
}