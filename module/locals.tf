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
  ##################################################
  ipmi_geometry = merge([
    for b in try(var.config.blocks, []) : {
      for n in try(b.nodes, []) : n.hypervisor_hostname => {
        ipmi_ip            = try(n.ipmi_ip, null)
        ipmi_mac           = try(n.ipmi_mac, "")
        ipmi_configure_now = try(n.ipmi_configure_now, true)
        ipmi_netmask       = try(var.config.ipmi_netmask, null)
        ipmi_gateway       = try(var.config.ipmi_gateway, null)
        block_id           = try(b.block_id, null)
      } if try(n.ipmi_ip, null) != null
    }
  ]...)
}
