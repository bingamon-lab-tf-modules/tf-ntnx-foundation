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
