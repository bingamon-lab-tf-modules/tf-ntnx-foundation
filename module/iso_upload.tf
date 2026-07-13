# Upload NOS package and hypervisor ISOs to the Foundation VM
# when local_path is provided in the YAML wizard config.
#
# Outputs from these uploads (name, md5sum) are chained into
# nutanix_foundation_image_nodes via locals.tf.
#
# nutanix_foundation_image attributes:
#   name    — file location on the Foundation VM (used as nos_package / hypervisor_iso filename)
#   md5sum  — MD5 of the uploaded file (used as checksum)

# Upload NOS (AOS) package
resource "nutanix_foundation_image" "nos" {
  count = var.nos_package_local_path != "" ? 1 : 0

  installer_type = "nos"
  source         = var.nos_package_local_path
  filename       = basename(var.nos_package_local_path)
}

# Upload AHV ISO
resource "nutanix_foundation_image" "ahv" {
  count = var.ahv_iso_local_path != "" ? 1 : 0

  installer_type = "kvm"
  source         = var.ahv_iso_local_path
  filename       = basename(var.ahv_iso_local_path)
}

# Upload ESXi ISO (uncommon — only triggered if esx_iso_local_path is set)
resource "nutanix_foundation_image" "esx" {
  count = var.esx_iso_local_path != "" ? 1 : 0

  installer_type = "esx"
  source         = var.esx_iso_local_path
  filename       = basename(var.esx_iso_local_path)
}

# Upload Hyper-V ISO (uncommon — only triggered if hyperv_iso_local_path is set)
resource "nutanix_foundation_image" "hyperv" {
  count = var.hyperv_iso_local_path != "" ? 1 : 0

  installer_type = "hyperv"
  source         = var.hyperv_iso_local_path
  filename       = basename(var.hyperv_iso_local_path)
}
