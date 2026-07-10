# Nutanix Foundation Module

## Table of Contents

- [Overview](#overview)
- [Usage](#usage)
- [Configuration](#configuration)
- [Environment Variables](#environment-variables)
- [Notes](#notes)

## Overview

This module wraps the `nutanix_foundation_image_nodes` resource to image
Nutanix nodes and optionally create clusters using a JSON configuration
exported from the [Nutanix Foundation preconfiguration app](https://install.nutanix.com).

The module accepts the `.config` object from the exported JSON as-is,
making it straightforward to go from the preconfiguration wizard to a
Terraform-managed deployment.

## Usage

```hcl
locals {
  config = jsondecode(file("foundation-config.json")).config
}

module "foundation" {
  source = "path/to/tf-ntnx-foundation/module"

  config      = local.config
  nos_package = "" # Auto-discover from Foundation VM
}

output "session_id" {
  value = module.foundation.session_id
}

output "cluster_urls" {
  value = module.foundation.cluster_urls
}
```

## Configuration

The module consumes the `.config` object from the JSON export produced by
<https://install.nutanix.com>. The JSON has the following top-level structure:

```json
{
  "config": {
    "bond_mode": "dynamic",
    "bond_lacp_rate": "fast",
    "rdma_passthrough": false,
    "hypervisor_netmask": "255.255.255.0",
    "cvm_netmask": "255.255.255.0",
    "hypervisor_gateway": "10.0.0.1",
    "cvm_gateway": "10.0.0.1",
    "ipmi_netmask": "255.255.255.0",
    "ipmi_gateway": "10.0.0.1",
    "clusters": [ ... ],
    "blocks": [ ... ],
    "eos_metadata": { ... }
  }
}
```

### Key Fields

| Field                  | Required | Description                                                                            |
| ---------------------- | -------- | -------------------------------------------------------------------------------------- |
| `cvm_gateway`          | Yes      | Default CVM gateway                                                                    |
| `cvm_netmask`          | Yes      | Default CVM netmask                                                                    |
| `hypervisor_gateway`   | Yes      | Default hypervisor gateway                                                             |
| `hypervisor_netmask`   | Yes      | Default hypervisor netmask                                                             |
| `ipmi_gateway`         | No       | Default IPMI gateway (required for IPMI-based imaging)                                 |
| `ipmi_netmask`         | No       | Default IPMI netmask (required for IPMI-based imaging)                                 |
| `bond_mode`            | No       | NIC bonding mode: `dynamic` (LACP) or `static` (LAG). Empty string is treated as null. |
| `bond_lacp_rate`       | No       | LACP rate: `slow` or `fast`. Only relevant when `bond_mode` is `dynamic`.              |
| `rdma_passthrough`     | No       | Passthrough RDMA NIC to CVM. Defaults to `false`.                                      |
| `current_cvm_vlan_tag` | No       | Current CVM VLAN tag. `0` removes the VLAN tag.                                        |
| `blocks`               | Yes      | Array of block objects, each containing a `nodes` array.                               |
| `clusters`             | Yes      | Array of cluster definitions.                                                          |
| `eos_metadata`         | No       | Metadata from the Nutanix Eos portal.                                                  |

### NOS Package Auto-Discovery

When `var.nos_package` is left empty (default), the module queries the
Foundation VM to discover available NOS packages using the
`nutanix_foundation_nos_packages` data source.

When `var.nos_package` is explicitly set, the data source is **not**
evaluated, allowing `tofu plan` to run without connectivity to a
Foundation VM.

## Environment Variables

The Nutanix provider reads the following environment variables for
Foundation connectivity:

| Variable              | Required | Default | Description                                                |
| --------------------- | -------- | ------- | ---------------------------------------------------------- |
| `FOUNDATION_ENDPOINT` | Yes      | —       | IP address or hostname of the Foundation VM                |
| `FOUNDATION_PORT`     | No       | `8000`  | Foundation API port                                        |
| `NUTANIX_ENDPOINT`    | Yes      | —       | Prism Central / Element endpoint (provider initialisation) |
| `NUTANIX_PORT`        | No       | `9440`  | Prism Central API port                                     |
| `NUTANIX_USERNAME`    | Yes      | —       | Prism Central username                                     |
| `NUTANIX_PASSWORD`    | Yes      | —       | Prism Central password                                     |
| `NUTANIX_INSECURE`    | No       | `false` | Skip TLS certificate verification                          |

## Notes

- Empty strings for `bond_mode` and `bond_lacp_rate` in the JSON config
  are automatically coalesced to `null` so the Foundation API does not
  receive invalid empty values.
- The imaging operation can take a significant amount of time. The
  resource timeout is set to **120 minutes**.
- All nodes default to `image_now = true` and `hypervisor = "kvm"` unless
  overridden in the JSON config.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0 |
| <a name="requirement_nutanix"></a> [nutanix](#requirement\_nutanix) | >= 1.9.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_nutanix"></a> [nutanix](#provider\_nutanix) | 2.4.2 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [nutanix_foundation_image.ahv](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/resources/foundation_image) | resource |
| [nutanix_foundation_image.esx](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/resources/foundation_image) | resource |
| [nutanix_foundation_image.hyperv](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/resources/foundation_image) | resource |
| [nutanix_foundation_image.nos](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/resources/foundation_image) | resource |
| [nutanix_foundation_image_nodes.imaging](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/resources/foundation_image_nodes) | resource |
| [nutanix_foundation_nos_packages.nos](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/data-sources/foundation_nos_packages) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_ahv_iso_checksum"></a> [ahv\_iso\_checksum](#input\_ahv\_iso\_checksum) | MD5 checksum of the AHV ISO. Optional. | `string` | `null` | no |
| <a name="input_ahv_iso_filename"></a> [ahv\_iso\_filename](#input\_ahv\_iso\_filename) | AHV (kvm) ISO filename on the Foundation VM. | `string` | `""` | no |
| <a name="input_ahv_iso_local_path"></a> [ahv\_iso\_local\_path](#input\_ahv\_iso\_local\_path) | Local path to AHV ISO. If set, Terraform uploads it and uses the result. | `string` | `""` | no |
| <a name="input_bond_lacp_rate"></a> [bond\_lacp\_rate](#input\_bond\_lacp\_rate) | LACP rate override ('fast' or 'slow'). Only relevant when bond\_mode is '802.3ad'. Overrides the value from the JSON config export. | `string` | `null` | no |
| <a name="input_bond_mode"></a> [bond\_mode](#input\_bond\_mode) | Bond mode override (e.g. 'active-backup', 'balance-slb', '802.3ad'). Overrides the value from the JSON config export. Use 'active-backup' for single-NIC or when the switch is not running LACP. | `string` | `null` | no |
| <a name="input_config"></a> [config](#input\_config) | The .config object from the Foundation preconfiguration JSON export (install.nutanix.com). Passed through as-is. | `any` | n/a | yes |
| <a name="input_esx_iso_checksum"></a> [esx\_iso\_checksum](#input\_esx\_iso\_checksum) | MD5 checksum of the ESXi ISO. Optional. | `string` | `null` | no |
| <a name="input_esx_iso_filename"></a> [esx\_iso\_filename](#input\_esx\_iso\_filename) | ESXi ISO filename on the Foundation VM. | `string` | `""` | no |
| <a name="input_esx_iso_local_path"></a> [esx\_iso\_local\_path](#input\_esx\_iso\_local\_path) | Local path to ESXi ISO. If set, Terraform uploads it and uses the result. | `string` | `""` | no |
| <a name="input_hyperv_iso_checksum"></a> [hyperv\_iso\_checksum](#input\_hyperv\_iso\_checksum) | MD5 checksum of the Hyper-V ISO. Optional. | `string` | `null` | no |
| <a name="input_hyperv_iso_filename"></a> [hyperv\_iso\_filename](#input\_hyperv\_iso\_filename) | Hyper-V ISO filename on the Foundation VM. | `string` | `""` | no |
| <a name="input_hyperv_iso_local_path"></a> [hyperv\_iso\_local\_path](#input\_hyperv\_iso\_local\_path) | Local path to Hyper-V ISO. If set, Terraform uploads it and uses the result. | `string` | `""` | no |
| <a name="input_hypervisor_nameserver"></a> [hypervisor\_nameserver](#input\_hypervisor\_nameserver) | DNS server for the hypervisor. | `string` | `null` | no |
| <a name="input_hypervisor_password"></a> [hypervisor\_password](#input\_hypervisor\_password) | Password to set on the hypervisor after imaging. | `string` | `null` | no |
| <a name="input_layout_egg_uuid"></a> [layout\_egg\_uuid](#input\_layout\_egg\_uuid) | UUID of a custom disk layout. | `string` | `null` | no |
| <a name="input_nos_package"></a> [nos\_package](#input\_nos\_package) | NOS .tar.gz filename on the Foundation VM. Empty = auto-discover. | `string` | `""` | no |
| <a name="input_nos_package_local_path"></a> [nos\_package\_local\_path](#input\_nos\_package\_local\_path) | Local path to NOS .tar.gz on the machine running tofu. If set, Terraform uploads it and uses the result as nos\_package. | `string` | `""` | no |
| <a name="input_run_ncc"></a> [run\_ncc](#input\_run\_ncc) | Run NCC checks after imaging. | `bool` | `null` | no |
| <a name="input_run_syscheck"></a> [run\_syscheck](#input\_run\_syscheck) | Run system health checks after imaging. | `bool` | `null` | no |
| <a name="input_skip_hypervisor"></a> [skip\_hypervisor](#input\_skip\_hypervisor) | If true, skip hypervisor installation (AOS-only reimaging). | `bool` | `false` | no |
| <a name="input_svm_rescue_args"></a> [svm\_rescue\_args](#input\_svm\_rescue\_args) | Extra arguments to pass to svm\_rescue during AOS install. | `list(string)` | `null` | no |
| <a name="input_timeout_minutes"></a> [timeout\_minutes](#input\_timeout\_minutes) | Imaging timeout in minutes. | `number` | `120` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_urls"></a> [cluster\_urls](#output\_cluster\_urls) | URLs of created clusters |
| <a name="output_foundation_status"></a> [foundation\_status](#output\_foundation\_status) | Status summary of the foundation imaging operation |
| <a name="output_session_id"></a> [session\_id](#output\_session\_id) | Foundation imaging session ID |
<!-- END_TF_DOCS -->
