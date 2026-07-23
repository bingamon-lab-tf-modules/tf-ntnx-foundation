variable "config" {
  description = <<-EOT
    The .config object from the Foundation preconfiguration JSON export (install.nutanix.com).

    Non-secret geometry only: gateways, blocks/nodes (IPs, hostnames, positions), clusters.
    Do NOT pass node BMC passwords here — they would appear in clear text in plans.
    Supply per-node BMC login via var.node_ipmi_credentials (keyed by hypervisor_hostname).
    Shared factory BMC login for nutanix_foundation_ipmi_config is var.ipmi_credentials.
    Hypervisor password after imaging is var.hypervisor_password.
  EOT
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

variable "node_ipmi_credentials" {
  description = <<-EOT
    Per-node BMC credentials for nutanix_foundation_image_nodes, keyed by the node's
    hypervisor_hostname (must match config.blocks[*].nodes[*].hypervisor_hostname).

    Sensitive — sourced from SOPS-encrypted foundation JSON by the caller, never left as
    nested keys on var.config (which would print in plan).
  EOT
  type = map(object({
    ipmi_user     = optional(string, null)
    ipmi_password = string
  }))
  default   = {}
  sensitive = true
}

##################################################
# Wizard fields (from <environment>.yaml)
##################################################

variable "nos_package" {
  description = "NOS .tar.gz filename on the Foundation VM. Empty = auto-discover."
  type        = string
  default     = ""
}

variable "bond_mode" {
  description = "Bond mode override (e.g. 'active-backup', 'balance-slb', '802.3ad'). Overrides the value from the JSON config export. Use 'active-backup' for single-NIC or when the switch is not running LACP."
  type        = string
  default     = null
}

variable "bond_lacp_rate" {
  description = "LACP rate override ('fast' or 'slow'). Only relevant when bond_mode is '802.3ad'. Overrides the value from the JSON config export."
  type        = string
  default     = null
}


variable "nos_package_local_path" {
  description = "Local path to NOS .tar.gz on the machine running tofu. If set, Terraform uploads it and uses the result as nos_package."
  type        = string
  default     = ""
}

variable "ahv_iso_filename" {
  description = "AHV (kvm) ISO filename on the Foundation VM."
  type        = string
  default     = ""
}

variable "ahv_iso_local_path" {
  description = "Local path to AHV ISO. If set, Terraform uploads it and uses the result."
  type        = string
  default     = ""
}

variable "ahv_iso_checksum" {
  description = "MD5 checksum of the AHV ISO. Optional."
  type        = string
  default     = null
}

variable "esx_iso_filename" {
  description = "ESXi ISO filename on the Foundation VM."
  type        = string
  default     = ""
}

variable "esx_iso_local_path" {
  description = "Local path to ESXi ISO. If set, Terraform uploads it and uses the result."
  type        = string
  default     = ""
}

variable "esx_iso_checksum" {
  description = "MD5 checksum of the ESXi ISO. Optional."
  type        = string
  default     = null
}

variable "hyperv_iso_local_path" {
  description = "Local path to Hyper-V ISO. If set, Terraform uploads it and uses the result."
  type        = string
  default     = ""
}

variable "hyperv_iso_filename" {
  description = "Hyper-V ISO filename on the Foundation VM."
  type        = string
  default     = ""
}

variable "hyperv_iso_checksum" {
  description = "MD5 checksum of the Hyper-V ISO. Optional."
  type        = string
  default     = null
}

variable "skip_hypervisor" {
  description = "If true, skip hypervisor installation (AOS-only reimaging)."
  type        = bool
  default     = false
}

variable "svm_rescue_args" {
  description = "Extra arguments to pass to svm_rescue during AOS install."
  type        = list(string)
  default     = null
}

variable "hypervisor_nameserver" {
  description = "DNS server for the hypervisor."
  type        = string
  default     = null
}

variable "hypervisor_password" {
  description = "Password to set on the hypervisor after imaging."
  type        = string
  default     = null
  sensitive   = true
}

variable "layout_egg_uuid" {
  description = "UUID of a custom disk layout."
  type        = string
  default     = null
}

variable "run_syscheck" {
  description = "Run system health checks after imaging."
  type        = bool
  default     = null
}

variable "run_ncc" {
  description = "Run NCC checks after imaging."
  type        = bool
  default     = null
}

variable "timeout_minutes" {
  description = "Imaging timeout in minutes."
  type        = number
  default     = 120
}

##################################################
# IPMI pre-imaging configuration
# (nutanix_foundation_ipmi_config — provider 2.4.2)
##################################################

variable "ipmi_configs" {
  description = <<-EOT
    Per-node IPMI/BMC network configuration for factory-fresh nodes, keyed by a node label.
    Populated from the SOPS-encrypted foundation JSON (config/foundation/<env>.sops.json) —
    the IPMI network fields carry no secrets, but they live beside the encrypted credentials.

    This drives nutanix_foundation_ipmi_config: the PRE-imaging step that sets a node's
    out-of-band BMC IP/netmask/gateway via the Foundation VM so the node becomes reachable.
    It is distinct from nutanix_foundation_image_nodes, which images the node and forms the
    cluster AFTER IPMI is reachable.

    One-shot / no-op destroy: applying configures the physical BMC out-of-band. `tofu destroy`
    removes the resource from state only — it does NOT reset or de-configure the hardware IPMI
    interface. Re-imaging or re-configuring is idempotent from the node's perspective.

    Leave the default {} to plan zero IPMI resources.
  EOT
  type = map(object({
    ipmi_ip            = string
    ipmi_netmask       = string
    ipmi_gateway       = string
    ipmi_mac           = optional(string, "")
    ipmi_configure_now = optional(bool, true)
    block_id           = optional(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.ipmi_configs : can(regex("^(\\d{1,3}\\.){3}\\d{1,3}$", v.ipmi_ip))
    ])
    error_message = "Every ipmi_configs entry must set ipmi_ip to a valid IPv4 address (n.n.n.n)."
  }

  validation {
    condition = alltrue([
      for k, v in var.ipmi_configs : can(regex("^(\\d{1,3}\\.){3}\\d{1,3}$", v.ipmi_netmask))
    ])
    error_message = "Every ipmi_configs entry must set ipmi_netmask to a valid IPv4 netmask (n.n.n.n)."
  }

  validation {
    condition = alltrue([
      for k, v in var.ipmi_configs : can(regex("^(\\d{1,3}\\.){3}\\d{1,3}$", v.ipmi_gateway))
    ])
    error_message = "Every ipmi_configs entry must set ipmi_gateway to a valid IPv4 address (n.n.n.n)."
  }
}

variable "ipmi_credentials" {
  description = <<-EOT
    IPMI/BMC login credentials applied to every ipmi_configs node. Factory-fresh nodes share a
    uniform default BMC credential, so a single shared user/password is supplied here.

    Secrets — sourced ONLY from the SOPS-encrypted foundation JSON, never from plaintext YAML or
    the wizard file. Consumed only when ipmi_configs is non-empty; the empty default plans no
    IPMI resources.
  EOT
  type = object({
    ipmi_user     = string
    ipmi_password = string
  })
  default = {
    ipmi_user     = ""
    ipmi_password = ""
  }
  sensitive = true
}
