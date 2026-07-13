check "foundation_config_has_nodes" {
  assert {
    condition     = length(try(var.config.blocks, [])) > 0
    error_message = "Foundation config must contain at least one block with nodes."
  }
}

check "foundation_config_has_clusters" {
  assert {
    condition     = length(try(var.config.clusters, [])) > 0
    error_message = "Foundation config must contain at least one cluster definition."
  }
}

check "ipmi_configs_valid_ipv4" {
  assert {
    condition = alltrue([
      for k, v in var.ipmi_configs :
      can(regex("^(\\d{1,3}\\.){3}\\d{1,3}$", v.ipmi_ip)) &&
      can(regex("^(\\d{1,3}\\.){3}\\d{1,3}$", v.ipmi_netmask)) &&
      can(regex("^(\\d{1,3}\\.){3}\\d{1,3}$", v.ipmi_gateway))
    ])
    error_message = "Every ipmi_configs entry must carry valid IPv4 ipmi_ip, ipmi_netmask, and ipmi_gateway."
  }
}
