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

