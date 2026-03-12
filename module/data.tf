# Only query Foundation VM for NOS packages when no explicit package is provided.
# This allows `tofu plan` to run without Foundation VM connectivity when
# var.nos_package is set to a known package filename.
data "nutanix_foundation_nos_packages" "nos" {
  count = var.nos_package != "" ? 0 : 1
}
