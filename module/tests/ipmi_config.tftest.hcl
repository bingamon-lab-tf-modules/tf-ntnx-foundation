##################################################
# Unit Tests: Foundation IPMI pre-imaging config
# (nutanix_foundation_ipmi_config)
#
# Pattern mirrors tf-ntnx-lcm/module/tests/prism_central.tftest.hcl.
##################################################

#########################
# Mock Data (Nutanix Provider)
#########################

mock_provider "nutanix" {}

#########################
# Shared variables
#
# The module always plans nutanix_foundation_image_nodes, so a minimal valid
# `config` and an explicit `nos_package` (which skips the NOS data-source lookup)
# are supplied to every run.
#########################

variables {
  nos_package = "dummy-aos.tar.gz"

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
        ipmi_ip             = "10.0.0.31"
      }]
    }]
    clusters = [{
      cluster_name      = "test-cluster"
      redundancy_factor = 1
      cluster_members   = ["10.0.0.21"]
    }]
  }
}

#########################
# Tests
#########################

# Test 1: Absent IPMI section plans zero resources.
run "ipmi_config_empty" {
  command = plan

  variables {
    ipmi_configs = {}
  }

  assert {
    condition     = length(output.ipmi_configs) == 0
    error_message = "Expected 0 IPMI config resources for an empty ipmi_configs map"
  }

  assert {
    condition     = output.foundation_status.ipmi_config_count == 0
    error_message = "Expected foundation_status.ipmi_config_count == 0"
  }
}

# Test 2: A single valid node plans exactly one IPMI config resource.
run "ipmi_config_single_node" {
  command = plan

  variables {
    ipmi_configs = {
      node_1 = {
        ipmi_ip      = "10.0.100.11"
        ipmi_netmask = "255.255.255.0"
        ipmi_gateway = "10.0.100.1"
      }
    }
    ipmi_credentials = {
      ipmi_user     = "ADMIN"
      ipmi_password = "dummy-secret"
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

  assert {
    condition     = contains(keys(output.ipmi_config_ids), "node_1")
    error_message = "Expected ipmi_config_ids to be keyed by the node label"
  }
}

# Test 3: Two nodes plan two IPMI config resources.
run "ipmi_config_two_nodes" {
  command = plan

  variables {
    ipmi_configs = {
      node_1 = {
        ipmi_ip      = "10.0.100.11"
        ipmi_netmask = "255.255.255.0"
        ipmi_gateway = "10.0.100.1"
        ipmi_mac     = "0c:c4:7a:00:00:01"
      }
      node_2 = {
        ipmi_ip            = "10.0.100.12"
        ipmi_netmask       = "255.255.255.0"
        ipmi_gateway       = "10.0.100.1"
        ipmi_configure_now = false
      }
    }
    ipmi_credentials = {
      ipmi_user     = "ADMIN"
      ipmi_password = "dummy-secret"
    }
  }

  assert {
    condition     = output.foundation_status.ipmi_config_count == 2
    error_message = "Expected 2 IPMI config resources"
  }
}

# Test 4: Invalid IPMI IP is rejected by variable validation.
run "ipmi_config_invalid_ip" {
  command = plan

  variables {
    ipmi_configs = {
      node_1 = {
        ipmi_ip      = "not-an-ip"
        ipmi_netmask = "255.255.255.0"
        ipmi_gateway = "10.0.100.1"
      }
    }
  }

  expect_failures = [var.ipmi_configs]
}

# Test 5: Invalid IPMI netmask is rejected by variable validation.
run "ipmi_config_invalid_netmask" {
  command = plan

  variables {
    ipmi_configs = {
      node_1 = {
        ipmi_ip      = "10.0.100.11"
        ipmi_netmask = "bogus"
        ipmi_gateway = "10.0.100.1"
      }
    }
  }

  expect_failures = [var.ipmi_configs]
}

# Test 6: Invalid IPMI gateway is rejected by variable validation.
run "ipmi_config_invalid_gateway" {
  command = plan

  variables {
    ipmi_configs = {
      node_1 = {
        ipmi_ip      = "10.0.100.11"
        ipmi_netmask = "255.255.255.0"
        ipmi_gateway = "999"
      }
    }
  }

  expect_failures = [var.ipmi_configs]
}
