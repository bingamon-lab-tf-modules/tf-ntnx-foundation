##################################################
# Unit Tests: Foundation IPMI pre-imaging config
# (nutanix_foundation_ipmi_config)
#
# Pattern mirrors tf-ntnx-lcm/module/tests/prism_central.tftest.hcl.
##################################################

mock_provider "nutanix" {}

variables {
  nos_package = "dummy-aos.tar.gz"

  config = {
    cvm_gateway        = "10.0.0.1"
    cvm_netmask        = "255.255.255.0"
    hypervisor_gateway = "10.0.0.1"
    hypervisor_netmask = "255.255.255.0"
    ipmi_gateway       = "10.0.100.1"
    ipmi_netmask       = "255.255.255.0"
    blocks = [{
      block_id = null
      nodes = [{
        node_position       = "A"
        hypervisor_hostname = "test-host-1"
        hypervisor_ip       = "10.0.0.11"
        cvm_ip              = "10.0.0.21"
        ipmi_ip             = "10.0.100.31"
      }]
    }]
    clusters = [{
      cluster_name      = "test-cluster"
      redundancy_factor = 1
      cluster_members   = ["10.0.0.21"]
    }]
  }
}

# Test 1: Missing ipmi_ip means no ipmi resource for that node
run "ipmi_config_missing_ip" {
  command = plan
  variables {
    config = {
      cvm_gateway        = "10.0.0.1"
      cvm_netmask        = "255.255.255.0"
      hypervisor_gateway = "10.0.0.1"
      hypervisor_netmask = "255.255.255.0"
      blocks = [{
        block_id = null
        nodes = [{
          node_position       = "A"
          hypervisor_hostname = "test-host-1"
          hypervisor_ip       = "10.0.0.11"
          cvm_ip              = "10.0.0.21"
        }]
      }]
      clusters = [{
        cluster_name      = "test-cluster"
        redundancy_factor = 1
        cluster_members   = ["10.0.0.21"]
      }]
    }
  }

  assert {
    condition     = output.foundation_status.ipmi_config_count == 0
    error_message = "Expected 0 IPMI config resources"
  }
}

# Test 2: A single valid node plans exactly one IPMI config resource.
run "ipmi_config_single_node" {
  command = plan

  variables {
    node_ipmi_credentials = {
      "test-host-1" = {
        ipmi_user     = "ADMIN"
        ipmi_password = "dummy-secret"
      }
    }
  }

  assert {
    condition     = length(output.ipmi_configs) == 1
    error_message = "Expected exactly 1 IPMI config resource"
  }

  assert {
    condition     = output.foundation_status.ipmi_config_count == 1
    error_message = "Expected foundation_status.ipmi_config_count == 1"
  }
}
