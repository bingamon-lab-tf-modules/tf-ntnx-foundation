output "session_id" {
  description = "Foundation imaging session ID"
  value       = nutanix_foundation_image_nodes.imaging.session_id
}

output "cluster_urls" {
  description = "URLs of created clusters"
  value       = try(nutanix_foundation_image_nodes.imaging.cluster_urls, [])
}

output "ipmi_configs" {
  description = "Per-node IPMI configuration results keyed by node label (resource id + per-node BMC configure status)."
  value = {
    for k, r in nutanix_foundation_ipmi_config.ipmi_config : k => {
      id     = r.id
      blocks = r.blocks
    }
  }
}

output "ipmi_config_ids" {
  description = "Map of node label => nutanix_foundation_ipmi_config resource id."
  value       = { for k, r in nutanix_foundation_ipmi_config.ipmi_config : k => r.id }
}

output "foundation_status" {
  description = "Status summary of the foundation imaging operation"
  value = {
    id                = nutanix_foundation_image_nodes.imaging.id
    session_id        = nutanix_foundation_image_nodes.imaging.session_id
    cluster_urls      = try(nutanix_foundation_image_nodes.imaging.cluster_urls, [])
    ipmi_config_count = length(nutanix_foundation_ipmi_config.ipmi_config)
  }
}
