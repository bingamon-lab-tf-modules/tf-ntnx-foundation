module "test" {
  source = "../module"

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
        ipmi_user           = "admin"
        ipmi_password       = "password"
        cvm_gb_ram          = 12
      }]
    }]
    clusters = [{
      cluster_name        = "test-cluster"
      redundancy_factor   = 1
      cluster_external_ip = "10.0.0.5"
      cluster_members     = ["10.0.0.21"]
    }]
  }
}
