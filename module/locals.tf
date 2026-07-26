locals {
  ##################################################
  # Bond mode
  ##################################################

  # Bond mode resolution: YAML var > JSON config > null (Foundation defaults)
  # Empty string from install.nutanix.com JSON ("") is treated as null (no preference).
  bond_mode = (
    var.bond_mode != null && var.bond_mode != ""
    ? var.bond_mode
    : try(var.config.bond_mode, null) != "" ? try(var.config.bond_mode, null) : null
  )
  bond_lacp_rate = (
    var.bond_lacp_rate != null && var.bond_lacp_rate != ""
    ? var.bond_lacp_rate
    : try(var.config.bond_lacp_rate, null) != "" ? try(var.config.bond_lacp_rate, null) : null
  )


  ##################################################
  # NOS package resolution
  # Priority: uploaded resource name > explicit filename var > auto-discover (null)
  ##################################################
  nos_package = (
    var.nos_package_local_path != ""
    ? nutanix_foundation_image.nos[0].name # use name from upload
    : var.nos_package != ""
    ? var.nos_package # use explicit filename
    : null            # let Foundation auto-discover
  )

  ##################################################
  # Hypervisor ISO filename resolution
  # Priority: uploaded resource name > explicit filename var > null (omit ISO block)
  ##################################################
  ahv_iso_filename = (
    var.ahv_iso_local_path != ""
    ? nutanix_foundation_image.ahv[0].name
    : var.ahv_iso_filename != "" ? var.ahv_iso_filename : null
  )
  ahv_iso_checksum = (
    var.ahv_iso_local_path != ""
    ? nutanix_foundation_image.ahv[0].md5sum # use checksum from upload
    : var.ahv_iso_checksum != null ? var.ahv_iso_checksum : ""
  )

  esx_iso_filename = (
    var.esx_iso_local_path != ""
    ? nutanix_foundation_image.esx[0].name
    : var.esx_iso_filename != "" ? var.esx_iso_filename : null
  )
  esx_iso_checksum = (
    var.esx_iso_local_path != ""
    ? nutanix_foundation_image.esx[0].md5sum
    : var.esx_iso_checksum != null ? var.esx_iso_checksum : ""
  )

  hyperv_iso_filename = (
    var.hyperv_iso_local_path != ""
    ? nutanix_foundation_image.hyperv[0].name
    : var.hyperv_iso_filename != "" ? var.hyperv_iso_filename : null
  )
  hyperv_iso_checksum = (
    var.hyperv_iso_local_path != ""
    ? nutanix_foundation_image.hyperv[0].md5sum
    : var.hyperv_iso_checksum != null ? var.hyperv_iso_checksum : ""
  )

  ##################################################
  # ISO block guards
  ##################################################
  needs_hypervisor_iso = (
    local.ahv_iso_filename != null ||
    local.esx_iso_filename != null ||
    local.hyperv_iso_filename != null
  )

  needs_tests = var.run_syscheck != null || var.run_ncc != null

  ##################################################
  # IPMI Geometry (built from config)
  #
  # Drives nutanix_foundation_ipmi_config — the PRE-imaging step that gives a
  # factory-fresh BMC its network identity. It is OPT-IN per node: a node is
  # included only when it sets `ipmi_configure_now = true`.
  #
  # The default is false because the overwhelmingly common case is a BMC that
  # already holds its IP (set by DHCP, the rack installer, or the hardware
  # vendor's own tooling) — which is precisely how Foundation reaches the node
  # to image it. Configuring an already-configured BMC is at best a no-op and
  # at worst fails the whole apply, and because the provider's ipmi_config
  # resource is create-only (no Read, no Delete) a failed create never lands in
  # state and re-fires on every subsequent apply.
  #
  # Exports from install.nutanix.com do not emit ipmi_configure_now, so this
  # defaults to "off" for every wizard-generated config.
  ##################################################
  ipmi_geometry = merge([
    for b in try(var.config.blocks, []) : {
      for n in try(b.nodes, []) : n.hypervisor_hostname => {
        ipmi_ip = try(n.ipmi_ip, null)
        # ipmi_mac is a REQUIRED argument on nutanix_foundation_ipmi_config's nodes
        # block, so it must be present (non-null). Default to "" when a node omits it;
        # null would fail provider schema validation ("Missing required argument").
        # An empty MAC is rejected by a precondition on the resource — Foundation
        # addresses an unconfigured BMC at layer 2, so it cannot act without one.
        ipmi_mac           = try(n.ipmi_mac, "")
        ipmi_configure_now = true
        ipmi_netmask       = try(var.config.ipmi_netmask, null)
        ipmi_gateway       = try(var.config.ipmi_gateway, null)
        block_id           = try(b.block_id, null)
      } if try(n.ipmi_ip, null) != null && try(n.ipmi_configure_now, false) == true
    }
  ]...)

  # Hostnames that have BMC credentials, as a plain (non-sensitive) set.
  # The keys are hypervisor hostnames — already public in var.config — so only
  # the map's *values* are secret. Preconditions reject sensitive conditions,
  # hence the unwrap.
  ipmi_credential_hosts = nonsensitive(toset(keys(var.node_ipmi_credentials)))
}
