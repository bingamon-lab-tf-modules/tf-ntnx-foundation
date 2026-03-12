output "session_id" {
  description = "Foundation imaging session ID"
  value       = nutanix_foundation_image_nodes.imaging.session_id
}

output "cluster_urls" {
  description = "URLs of created clusters"
  value       = try(nutanix_foundation_image_nodes.imaging.cluster_urls, [])
}

output "foundation_status" {
  description = "Status summary of the foundation imaging operation"
  value = {
    id           = nutanix_foundation_image_nodes.imaging.id
    session_id   = nutanix_foundation_image_nodes.imaging.session_id
    cluster_urls = try(nutanix_foundation_image_nodes.imaging.cluster_urls, [])
  }
}
