variable "ipmi_password" {
  description = "BMC password for the harness node. Never inline a credential in var.config."
  type        = string
  default     = "dummy-not-a-real-secret"
  sensitive   = true
}

module "test" {
  source = "../module"

  # Geometry only — no BMC credentials. Anything nested here is printed in clear
  # text at plan time, so passwords must travel via node_ipmi_credentials instead.
  config = {
    cvm_gateway        = "10.0.0.1"
    cvm_netmask        = "255.255.255.0"
    hypervisor_gateway = "10.0.0.1"
    hypervisor_netmask = "255.255.255.0"
    ipmi_gateway       = "10.0.0.1"
    ipmi_netmask       = "255.255.255.0"
    bond_mode          = "dynamic"
    bond_lacp_rate     = "fast"
    rdma_passthrough   = false
    blocks = [{
      block_id = null
      nodes = [{
        node_position       = "A"
        hypervisor_hostname = "test-host-1"
        hypervisor_ip       = "10.0.0.11"
        cvm_ip              = "10.0.0.21"
        ipmi_ip             = "10.0.0.31"
        cvm_gb_ram          = 12
        # No ipmi_configure_now: this node's BMC already holds 10.0.0.31, so the
        # pre-imaging nutanix_foundation_ipmi_config step stays off (the default).
      }]
    }]
    clusters = [{
      cluster_name        = "test-cluster"
      redundancy_factor   = 1
      cluster_external_ip = "10.0.0.5"
      cluster_members     = ["10.0.0.21"]
    }]
  }

  # Sensitive plane — keyed by hypervisor_hostname, redacted in plan output.
  node_ipmi_credentials = {
    "test-host-1" = {
      ipmi_user     = "admin"
      ipmi_password = var.ipmi_password
    }
  }
}
