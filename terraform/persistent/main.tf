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
variable "region" {
  type = string
}
variable "zone" {
  type = string
}
variable "user_email" {
  type = string
}
resource "google_storage_bucket" "prod_data" {
  name          = "${var.project_id}-prod-data"
  project       = var.project_id
  location      = "US"
  storage_class = "STANDARD"
  
  uniform_bucket_level_access = true
  force_destroy = false  # Prevents accidental deletion
  
  versioning {
    enabled = true  # Keep version history for production data
  }
}

resource "google_storage_bucket" "dev_data" {
  name          = "${var.project_id}-dev-data"
    project       = var.project_id
  location      = "US"
  storage_class = "STANDARD"
  
  uniform_bucket_level_access = true
  force_destroy = true  # Allow deletion since it's ephemeral

  lifecycle_rule {
    condition {
      age = 90  # Days
    }
    action {
      type = "Delete"  # Delete old dev data automatically
    }
  }
}

resource "google_storage_bucket" "archive" {
  name          = "${var.project_id}-archive"
    project       = var.project_id
  location      = "US"
  storage_class = "COLDLINE"
  
  uniform_bucket_level_access = true
  force_destroy = false

  lifecycle_rule {
    condition {
      age = 365  # Days
    }
    action {
      type = "SetStorageClass"
      storage_class = "ARCHIVE"  # Move very old data to archive storage
    }
  }
}

# Output the bucket names
output "prod_bucket" {
  value = google_storage_bucket.prod_data.name
}

output "dev_bucket" {
  value = google_storage_bucket.dev_data.name
}

output "archive_bucket" {
  value = google_storage_bucket.archive.name
}