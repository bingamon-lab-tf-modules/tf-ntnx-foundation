locals {
  # Coalesce empty strings to null for optional fields that the Foundation API
  # rejects when sent as "". The JSON export from install.nutanix.com sometimes
  # sets these to "" instead of omitting them.
  bond_mode      = try(var.config.bond_mode, null) != "" ? try(var.config.bond_mode, null) : null
  bond_lacp_rate = try(var.config.bond_lacp_rate, null) != "" ? try(var.config.bond_lacp_rate, null) : null

  # Resolve the NOS package: explicit variable wins, otherwise auto-discover
  nos_package = var.nos_package != "" ? var.nos_package : try(data.nutanix_foundation_nos_packages.nos[0].entities[0], null)
}
