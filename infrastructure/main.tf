terraform {
  required_providers {
    google = {
      version = ">= 3.67.0"
      source  = "hashicorp/google"
    }
  }
  required_version = ">= 0.12"
}

data "google_project" "project" {
  project_id = var.project_id
}

data "google_client_config" "default" {}

provider "google" {
  region  = var.region
  project = var.project_id
}

provider "kubernetes" {
  host                   = "https://${module.gke.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.gke.ca_certificate)
}

module "project_services" {
  source                      = "terraform-google-modules/project-factory/google//modules/project_services"
  version                     = "10.3.2"
  project_id                  = var.project_id
  disable_services_on_destroy = false
  activate_apis = [
    "compute.googleapis.com",
    "iam.googleapis.com",
    "anthos.googleapis.com",
    "meshca.googleapis.com",
  ]
}

module "gke" {
  source                  = "terraform-google-modules/kubernetes-engine/google"
  version                 = "15.0.0"
  project_id              = var.project_id
  name                    = "${var.deployment_name}-cluster"
  regional                = false
  region                  = var.region
  zones                   = [var.zone]
  release_channel         = "REGULAR"
  network                 = "default"
  subnetwork              = "default"
  ip_range_pods           = ""
  ip_range_services       = ""
  network_policy          = false
  cluster_resource_labels = { "mesh-id" : "proj-${data.google_project.project.number}" }
  create_service_account  = false
  node_pools = [
    {
      name         = "${var.deployment_name}-node-pool"
      autoscaling  = false
      auto_upgrade = true
      node_count   = 4
      machine_type = "e2-standard-4"
    }
  ]

  node_pools_oauth_scopes = {
    all = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  depends_on = [
    module.project_services
  ]
}

module "asm" {
  source                = "terraform-google-modules/kubernetes-engine/google//modules/asm"
  version               = "15.0.0"
  project_id            = var.project_id
  cluster_name          = module.gke.name
  location              = module.gke.location
  cluster_endpoint      = module.gke.endpoint
  enable_all            = true
}

module "hub" {
  source           = "terraform-google-modules/kubernetes-engine/google//modules/hub"
  version          = "15.0.0"
  project_id       = var.project_id
  cluster_name     = module.gke.name
  location         = module.gke.location
  cluster_endpoint = module.gke.endpoint
}

module "workload_identity" {
  source       = "terraform-google-modules/kubernetes-engine/google//modules/workload-identity"
  version      = "15.0.0"
  project_id   = var.project_id
  cluster_name = module.gke.name
  location     = module.gke.location
  name         = "${var.deployment_name}-sa"
  namespace    = "default"

  roles = [
    "roles/cloudtrace.agent",
    "roles/monitoring.metricWriter",
    "roles/logging.logWriter"
  ]
}
