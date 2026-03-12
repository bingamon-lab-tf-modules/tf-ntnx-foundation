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
| <a name="provider_nutanix"></a> [nutanix](#provider\_nutanix) | 2.4.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [nutanix_foundation_image_nodes.imaging](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/resources/foundation_image_nodes) | resource |
| [nutanix_foundation_nos_packages.nos](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/data-sources/foundation_nos_packages) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_config"></a> [config](#input\_config) | The .config object from the Foundation preconfiguration JSON export (install.nutanix.com). Passed through as-is. | `any` | n/a | yes |
| <a name="input_nos_package"></a> [nos\_package](#input\_nos\_package) | NOS package filename on the Foundation VM. If empty, auto-discovered from the Foundation server. | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_urls"></a> [cluster\_urls](#output\_cluster\_urls) | URLs of created clusters |
| <a name="output_foundation_status"></a> [foundation\_status](#output\_foundation\_status) | Status summary of the foundation imaging operation |
| <a name="output_session_id"></a> [session\_id](#output\_session\_id) | Foundation imaging session ID |
<!-- END_TF_DOCS -->
