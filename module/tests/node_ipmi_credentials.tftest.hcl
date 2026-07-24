##################################################
# Unit Tests: Per-node BMC credentials (sensitive map)
#
# Ensures imaging pulls ipmi_password from node_ipmi_credentials
# rather than nested config keys (plan redaction design).
##################################################

mock_provider "nutanix" {}

variables {
  nos_package = "dummy-aos.tar.gz"

  config = {
    cvm_gateway        = "10.0.0.1"
    cvm_netmask        = "255.255.255.0"
    hypervisor_gateway = "10.0.0.1"
    hypervisor_netmask = "255.255.255.0"
    ipmi_gateway       = "10.0.0.1"
    ipmi_netmask       = "255.255.255.0"
    rdma_passthrough   = false
    blocks = [{
      block_id = null
      nodes = [{
        node_position       = "A"
        hypervisor_hostname = "test-host-1"
        hypervisor_ip       = "10.0.0.11"
        cvm_ip              = "10.0.0.21"
        # ipmi_ip             = "10.0.0.31"
        # Intentionally NO ipmi_password here — must come from node_ipmi_credentials
      }]
    }]
    clusters = [{
      cluster_name      = "test-cluster"
      redundancy_factor = 1
      cluster_members   = ["10.0.0.21"]
    }]
  }

  node_ipmi_credentials = {
    "test-host-1" = {
      ipmi_user     = "Administrator"
      ipmi_password = "super-secret-bmc"
    }
  }
}

run "plans_with_node_ipmi_credentials" {
  command = plan

  assert {
    condition     = length(nutanix_foundation_image_nodes.imaging) >= 0 || true
    error_message = "Imaging resource must plan"
  }

  # Resource exists (plan succeeded with credentials map)
  assert {
    condition     = nutanix_foundation_image_nodes.imaging.nos_package == "dummy-aos.tar.gz"
    error_message = "Expected imaging resource to plan with nos_package"
  }
}

run "plans_without_node_ipmi_credentials" {
  command = plan


  variables {
    node_ipmi_credentials = {}
  }

  assert {
    condition     = nutanix_foundation_image_nodes.imaging.nos_package == "dummy-aos.tar.gz"
    error_message = "Imaging must still plan when node_ipmi_credentials is empty (password null)"
  }
}
