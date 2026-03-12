terraform {
  required_version = ">= 1.9.0"
}

locals {
  # Load the JSON exported from install.nutanix.com (Foundation preconfiguration app)
  config = jsondecode(file("config.json")).config
}

module "foundation" {
  source = "../module"

  config      = local.config
  nos_package = "" # Auto-discover from Foundation VM
}

output "session_id" {
  value = module.foundation.session_id
}

output "cluster_urls" {
  value = module.foundation.cluster_urls
}
