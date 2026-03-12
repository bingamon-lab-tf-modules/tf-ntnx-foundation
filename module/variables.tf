variable "config" {
  description = "The .config object from the Foundation preconfiguration JSON export (install.nutanix.com). Passed through as-is."
  type        = any

  validation {
    condition     = can(var.config.cvm_gateway) && can(var.config.cvm_netmask) && can(var.config.hypervisor_gateway) && can(var.config.hypervisor_netmask)
    error_message = "config must contain cvm_gateway, cvm_netmask, hypervisor_gateway, and hypervisor_netmask."
  }

  validation {
    condition     = can(var.config.blocks) && length(var.config.blocks) > 0
    error_message = "config must contain at least one block with nodes."
  }

  validation {
    condition     = can(var.config.clusters) && length(var.config.clusters) > 0
    error_message = "config must contain at least one cluster definition."
  }
}

variable "nos_package" {
  description = "NOS package filename on the Foundation VM. If empty, auto-discovered from the Foundation server."
  type        = string
  default     = ""
}
