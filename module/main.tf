resource "nutanix_foundation_image_nodes" "imaging" {
  timeouts {
    create = "120m"
  }

  # NOS package: use override if provided, otherwise auto-discover
  nos_package = local.nos_package

  # Common network settings from JSON config
  cvm_gateway        = var.config.cvm_gateway
  cvm_netmask        = var.config.cvm_netmask
  hypervisor_gateway = var.config.hypervisor_gateway
  hypervisor_netmask = var.config.hypervisor_netmask
  ipmi_gateway       = try(var.config.ipmi_gateway, null)
  ipmi_netmask       = try(var.config.ipmi_netmask, null)

  # Blocks and nodes from JSON config
  dynamic "blocks" {
    for_each = var.config.blocks
    content {
      block_id = try(blocks.value.block_id, null)

      dynamic "nodes" {
        for_each = try(blocks.value.nodes, [])
        content {
          node_position        = nodes.value.node_position
          hypervisor_hostname  = nodes.value.hypervisor_hostname
          hypervisor_ip        = nodes.value.hypervisor_ip
          cvm_ip               = nodes.value.cvm_ip
          ipmi_ip              = nodes.value.ipmi_ip
          ipmi_user            = try(nodes.value.ipmi_user, null)
          ipmi_password        = try(nodes.value.ipmi_password, null)
          ipmi_mac             = try(nodes.value.ipmi_mac, null) != "" ? try(nodes.value.ipmi_mac, null) : null
          cvm_gb_ram           = try(nodes.value.cvm_gb_ram, null)
          image_now            = try(nodes.value.image_now, true)
          hypervisor           = try(nodes.value.hypervisor, "kvm")
          bond_mode            = local.bond_mode
          bond_lacp_rate       = local.bond_lacp_rate
          rdma_passthrough     = try(var.config.rdma_passthrough, null)
          current_cvm_vlan_tag = try(tonumber(var.config.current_cvm_vlan_tag), null)
        }
      }
    }
  }

  # Clusters from JSON config
  dynamic "clusters" {
    for_each = var.config.clusters
    content {
      cluster_name           = clusters.value.cluster_name
      redundancy_factor      = clusters.value.redundancy_factor
      cluster_external_ip    = try(clusters.value.cluster_external_ip, null)
      cluster_members        = clusters.value.cluster_members
      cluster_init_now       = try(clusters.value.cluster_init_now, true)
      single_node_cluster    = try(clusters.value.single_node_cluster, length(clusters.value.cluster_members) == 1)
      enable_ns              = try(clusters.value.enable_ns, null)
      timezone               = try(clusters.value.timezone, null)
      cvm_ntp_servers        = try(clusters.value.cvm_ntp_servers, null)
      cvm_dns_servers        = try(clusters.value.cvm_dns_servers, null)
      hypervisor_ntp_servers = try(clusters.value.hypervisor_ntp_servers, null)
    }
  }

  # EOS metadata passthrough from JSON config
  dynamic "eos_metadata" {
    for_each = try(var.config.eos_metadata, null) != null ? [var.config.eos_metadata] : []
    content {
      config_id    = try(eos_metadata.value.config_id, null)
      account_name = try(eos_metadata.value.account_name, null)
      email        = try(eos_metadata.value.email, null)
    }
  }
}
