##################################################
# Unit Tests: Foundation IPMI pre-imaging config
# (nutanix_foundation_ipmi_config)
#
# The step is OPT-IN per node via `ipmi_configure_now = true`. These tests pin
# both halves of that contract: nodes that do not opt in plan zero resources,
# and nodes that DO opt in must carry everything Foundation needs or the plan
# fails with a named precondition rather than an opaque apply-time error.
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

  node_ipmi_credentials = {
    "test-host-1" = {
      ipmi_user     = "ADMIN"
      ipmi_password = "dummy-secret"
    }
  }
}

# Test 1: Missing ipmi_ip means no ipmi resource for that node.
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

# Test 2: REGRESSION — a reachable node that does not opt in plans nothing.
#
# This is the shape every install.nutanix.com export produces: ipmi_ip present
# (that is how Foundation reaches the node), no ipmi_configure_now key, and an
# empty ipmi_mac. Previously this planned one resource per node and every apply
# failed with "Failed to execute <function configure_node at 0x...>".
run "ipmi_config_not_opted_in" {
  command = plan

  assert {
    condition     = output.foundation_status.ipmi_config_count == 0
    error_message = "A node without ipmi_configure_now must plan 0 IPMI config resources"
  }

  assert {
    condition     = length(output.ipmi_configs) == 0
    error_message = "Expected an empty ipmi_configs output when no node opts in"
  }
}

# Test 3: Explicit opt-out is honoured even when the node is otherwise complete.
run "ipmi_config_explicit_opt_out" {
  command = plan

  variables {
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
          ipmi_mac            = "00:11:22:33:44:55"
          ipmi_configure_now  = false
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
    error_message = "ipmi_configure_now = false must plan 0 IPMI config resources"
  }
}

# Test 4: A fully specified opt-in node plans exactly one resource, correctly wired.
run "ipmi_config_opted_in" {
  command = plan

  variables {
    config = {
      cvm_gateway        = "10.0.0.1"
      cvm_netmask        = "255.255.255.0"
      hypervisor_gateway = "10.0.0.1"
      hypervisor_netmask = "255.255.255.0"
      ipmi_gateway       = "10.0.100.1"
      ipmi_netmask       = "255.255.255.0"
      blocks = [{
        block_id = "block-1"
        nodes = [{
          node_position       = "A"
          hypervisor_hostname = "test-host-1"
          hypervisor_ip       = "10.0.0.11"
          cvm_ip              = "10.0.0.21"
          ipmi_ip             = "10.0.100.31"
          ipmi_mac            = "00:11:22:33:44:55"
          ipmi_configure_now  = true
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
    condition     = output.foundation_status.ipmi_config_count == 1
    error_message = "Expected exactly 1 IPMI config resource for an opted-in node"
  }

  assert {
    condition     = nutanix_foundation_ipmi_config.ipmi_config["test-host-1"].ipmi_gateway == "10.0.100.1"
    error_message = "ipmi_gateway must come from config.ipmi_gateway"
  }

  assert {
    condition     = nutanix_foundation_ipmi_config.ipmi_config["test-host-1"].ipmi_netmask == "255.255.255.0"
    error_message = "ipmi_netmask must come from config.ipmi_netmask"
  }

  assert {
    condition     = one(nutanix_foundation_ipmi_config.ipmi_config["test-host-1"].blocks).block_id == "block-1"
    error_message = "block_id must be carried through from the enclosing block"
  }

  assert {
    condition     = one(one(nutanix_foundation_ipmi_config.ipmi_config["test-host-1"].blocks).nodes).ipmi_mac == "00:11:22:33:44:55"
    error_message = "ipmi_mac must be carried through from the node"
  }
}

# Test 5: Only the opted-in node of a mixed block gets a resource.
run "ipmi_config_mixed_nodes" {
  command = plan

  variables {
    config = {
      cvm_gateway        = "10.0.0.1"
      cvm_netmask        = "255.255.255.0"
      hypervisor_gateway = "10.0.0.1"
      hypervisor_netmask = "255.255.255.0"
      ipmi_gateway       = "10.0.100.1"
      ipmi_netmask       = "255.255.255.0"
      blocks = [{
        block_id = null
        nodes = [
          {
            node_position       = "A"
            hypervisor_hostname = "test-host-1"
            hypervisor_ip       = "10.0.0.11"
            cvm_ip              = "10.0.0.21"
            ipmi_ip             = "10.0.100.31"
            ipmi_mac            = "00:11:22:33:44:55"
            ipmi_configure_now  = true
          },
          {
            node_position       = "B"
            hypervisor_hostname = "test-host-2"
            hypervisor_ip       = "10.0.0.12"
            cvm_ip              = "10.0.0.22"
            ipmi_ip             = "10.0.100.32"
          },
        ]
      }]
      clusters = [{
        cluster_name      = "test-cluster"
        redundancy_factor = 2
        cluster_members   = ["10.0.0.21", "10.0.0.22"]
      }]
    }

    node_ipmi_credentials = {
      "test-host-1" = {
        ipmi_user     = "ADMIN"
        ipmi_password = "dummy-secret"
      }
      "test-host-2" = {
        ipmi_user     = "ADMIN"
        ipmi_password = "dummy-secret"
      }
    }
  }

  assert {
    condition     = output.foundation_status.ipmi_config_count == 1
    error_message = "Only the opted-in node must plan an IPMI config resource"
  }

  assert {
    condition     = keys(output.ipmi_configs) == ["test-host-1"]
    error_message = "Expected only test-host-1 in ipmi_configs"
  }
}

# Test 6: Opting in without an ipmi_mac fails at PLAN, not at apply.
run "ipmi_config_opted_in_without_mac" {
  command = plan

  variables {
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
          ipmi_mac            = ""
          ipmi_configure_now  = true
        }]
      }]
      clusters = [{
        cluster_name      = "test-cluster"
        redundancy_factor = 1
        cluster_members   = ["10.0.0.21"]
      }]
    }
  }

  expect_failures = [nutanix_foundation_ipmi_config.ipmi_config]
}

# Test 7: Opting in without BMC credentials fails at PLAN.
run "ipmi_config_opted_in_without_credentials" {
  command = plan

  variables {
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
          ipmi_mac            = "00:11:22:33:44:55"
          ipmi_configure_now  = true
        }]
      }]
      clusters = [{
        cluster_name      = "test-cluster"
        redundancy_factor = 1
        cluster_members   = ["10.0.0.21"]
      }]
    }
    node_ipmi_credentials = {}
  }

  expect_failures = [nutanix_foundation_ipmi_config.ipmi_config]
}

# Test 8: Opting in without IPMI netmask/gateway fails at PLAN.
run "ipmi_config_opted_in_without_network" {
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
          ipmi_ip             = "10.0.100.31"
          ipmi_mac            = "00:11:22:33:44:55"
          ipmi_configure_now  = true
        }]
      }]
      clusters = [{
        cluster_name      = "test-cluster"
        redundancy_factor = 1
        cluster_members   = ["10.0.0.21"]
      }]
    }
  }

  expect_failures = [nutanix_foundation_ipmi_config.ipmi_config]
}
