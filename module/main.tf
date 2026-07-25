resource "nutanix_foundation_image_nodes" "imaging" {
  depends_on = [
    nutanix_foundation_image.nos,
    nutanix_foundation_image.ahv,
    nutanix_foundation_image.esx,
    nutanix_foundation_image.hyperv,
    # BMC network identity must exist before Foundation can image over it. Without
    # this edge the two are independent graph nodes and OpenTofu runs them
    # concurrently — which would re-IP a BMC mid-imaging. No-op when no node opts
    # in to ipmi_config (the usual case).
    nutanix_foundation_ipmi_config.ipmi_config,
  ]

  timeouts {
    create = "${var.timeout_minutes}m"
  }

  # NOS package: YAML value wins, otherwise auto-discover from Foundation VM
  nos_package = local.nos_package

  # Common network settings from JSON config
  cvm_gateway        = var.config.cvm_gateway
  cvm_netmask        = var.config.cvm_netmask
  hypervisor_gateway = var.config.hypervisor_gateway
  hypervisor_netmask = var.config.hypervisor_netmask
  ipmi_gateway       = try(var.config.ipmi_gateway, null)
  ipmi_netmask       = try(var.config.ipmi_netmask, null)

  # Optional wizard fields
  skip_hypervisor     = var.skip_hypervisor ? true : null
  hypervisor_password = var.hypervisor_password
  layout_egg_uuid     = var.layout_egg_uuid

  # Optional: AOS installer arguments and hypervisor DNS
  svm_rescue_args       = var.svm_rescue_args
  hypervisor_nameserver = var.hypervisor_nameserver

  # Hypervisor ISO — only emitted when YAML specifies an ISO filename
  dynamic "hypervisor_iso" {
    for_each = local.needs_hypervisor_iso ? [1] : []
    content {
      dynamic "kvm" {
        for_each = local.ahv_iso_filename != null ? [1] : []
        content {
          filename = local.ahv_iso_filename
          checksum = local.ahv_iso_checksum
        }
      }
      dynamic "esx" {
        for_each = local.esx_iso_filename != null ? [1] : []
        content {
          filename = local.esx_iso_filename
          checksum = local.esx_iso_checksum
        }
      }
      dynamic "hyperv" {
        for_each = local.hyperv_iso_filename != null ? [1] : []
        content {
          filename = local.hyperv_iso_filename
          checksum = local.hyperv_iso_checksum
        }
      }
    }
  }

  # Blocks and nodes from JSON config
  dynamic "blocks" {
    for_each = var.config.blocks
    content {
      block_id = try(blocks.value.block_id, null)

      dynamic "nodes" {
        for_each = try(blocks.value.nodes, [])
        content {
          node_position       = nodes.value.node_position
          hypervisor_hostname = nodes.value.hypervisor_hostname
          hypervisor_ip       = nodes.value.hypervisor_ip
          cvm_ip              = nodes.value.cvm_ip
          ipmi_ip             = try(nodes.value.ipmi_ip, null)
          # BMC login comes from the sensitive map only (not nested config keys),
          # so plan redacts passwords without tainting booleans/IPs from config.
          ipmi_user = try(
            var.node_ipmi_credentials[nodes.value.hypervisor_hostname].ipmi_user,
            null
          )
          ipmi_password = try(
            var.node_ipmi_credentials[nodes.value.hypervisor_hostname].ipmi_password,
            null
          )
          ipmi_mac             = try(nodes.value.ipmi_mac, null) != "" ? try(nodes.value.ipmi_mac, null) : null
          cvm_gb_ram           = try(nodes.value.cvm_gb_ram, null)
          image_now            = try(nodes.value.image_now, true)
          hypervisor           = try(nodes.value.hypervisor, "kvm")
          bond_mode            = local.bond_mode != null && local.bond_mode != "" ? local.bond_mode : null
          bond_lacp_rate       = local.bond_lacp_rate != null && local.bond_lacp_rate != "" ? local.bond_lacp_rate : null
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

  # Post-imaging tests (only emitted when YAML configures them)
  dynamic "tests" {
    for_each = local.needs_tests ? [1] : []
    content {
      run_syscheck = var.run_syscheck
      run_ncc      = var.run_ncc
    }
  }
}

# Pre-imaging IPMI/BMC network configuration for factory-fresh nodes.
#
# One resource per OPTED-IN node (for_each over local.ipmi_geometry, which selects nodes
# carrying `ipmi_configure_now = true`). Nodes whose BMC is already on the network — the
# usual case, and the only case a wizard export produces — plan zero resources here.
# Per-node BMC credentials come from the sensitive var.node_ipmi_credentials (SOPS plane).
#
# NOT to be confused with nutanix_foundation_image_nodes.imaging above: that images nodes and
# forms clusters via the Foundation VM once IPMI is reachable. THIS resource is the earlier
# out-of-band step that gives each node's BMC its network identity, and `imaging` now has an
# explicit depends_on so the ordering the docs describe is the ordering the graph enforces.
#
# Foundation prerequisites for this to succeed (it drives `configure_node` on the Foundation
# VM, which reports failures as an opaque Python function repr — the real error is in
# /home/nutanix/foundation/log/service.log):
#   - The Foundation VM must be in the SAME BROADCAST DOMAIN as the target IPMI interfaces.
#     An unconfigured BMC has no IP, so Foundation addresses it at layer 2.
#   - Each node's ipmi_mac must be known; the MAC is the only handle on an unconfigured BMC.
#   - IPMI-over-LAN must be enabled on the BMC (a BMC factory reset disables it).
#
# One-shot: apply configures the hardware BMC; destroy drops state only and does not
# de-configure the physical IPMI interface. The provider implements neither Read nor Delete
# for this resource, so it is never refreshed and never detects drift.
resource "nutanix_foundation_ipmi_config" "ipmi_config" {
  # Geometry map only (hostnames → IPs). Credentials are a separate sensitive var.
  # nonsensitive(): OpenTofu rejects sensitive for_each maps; callers may pass
  # values derived from SOPS-decrypted JSON even after stripping BMC passwords.
  for_each = nonsensitive(local.ipmi_geometry)

  # Per-node credentials from var.node_ipmi_credentials.
  # try(): keep expression evaluation total so a missing entry surfaces as the
  # named precondition failure below rather than an "Invalid index" error.
  ipmi_user     = try(var.node_ipmi_credentials[each.key].ipmi_user, null)
  ipmi_password = try(var.node_ipmi_credentials[each.key].ipmi_password, null)

  # Network geometry is public — same values imaging prints in clear text.
  ipmi_netmask = each.value.ipmi_netmask
  ipmi_gateway = each.value.ipmi_gateway

  blocks {
    block_id = each.value.block_id

    nodes {
      ipmi_ip            = each.value.ipmi_ip
      ipmi_mac           = each.value.ipmi_mac
      ipmi_configure_now = each.value.ipmi_configure_now
    }
  }

  # Fail at PLAN with an actionable message rather than at apply with Foundation's
  # opaque "Failed to execute <function configure_node at 0x...>".
  lifecycle {
    precondition {
      condition     = each.value.ipmi_mac != ""
      error_message = "Node '${each.key}' sets ipmi_configure_now = true but has no ipmi_mac. Foundation reaches an unconfigured BMC over layer 2, so the MAC is mandatory. Set ipmi_mac on the node, or drop ipmi_configure_now if the BMC already holds its IP."
    }

    precondition {
      condition     = contains(local.ipmi_credential_hosts, each.key)
      error_message = "Node '${each.key}' sets ipmi_configure_now = true but has no entry in var.node_ipmi_credentials. Foundation needs BMC credentials to reconfigure the interface; add an entry keyed by this hypervisor_hostname."
    }

    precondition {
      condition     = each.value.ipmi_netmask != null && each.value.ipmi_gateway != null
      error_message = "Node '${each.key}' sets ipmi_configure_now = true but config.ipmi_netmask and/or config.ipmi_gateway is missing. Both are required to give the BMC a usable network identity."
    }
  }
}
