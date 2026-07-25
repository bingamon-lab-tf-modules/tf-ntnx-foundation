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

It also wraps `nutanix_foundation_ipmi_config` for the **pre-imaging** IPMI/BMC
network setup step (see [IPMI Pre-Imaging Configuration](#ipmi-pre-imaging-configuration)).

> **Foundation Central is intentionally out of scope.** The `nutanix_foundation_central_*`
> resources (API key, image cluster, onboard nodes) are **not** implemented — no Foundation
> Central server exists in the lab, and an unreachable FC endpoint would fail every plan/apply.
> This is recorded in `docs/spec.md` §12 and a Foundation Central scope ADR (re-evaluate when
> an FC server is deployed or on each `nutanix` provider minor release).

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

## IPMI Pre-Imaging Configuration

`nutanix_foundation_ipmi_config` sets a **factory-fresh** node's out-of-band BMC
(IPMI) IP, netmask, and gateway via the Foundation VM. It gives a BMC that has no
address yet a network identity so the node becomes reachable.

This is **not** the same as `nutanix_foundation_image_nodes` (the `imaging`
resource): that images nodes and forms clusters via the Foundation VM **after**
IPMI is already reachable. The two hit different Foundation endpoints
(`/foundation/ipmi_config` vs `/foundation/image_nodes`), and only `image_nodes`
writes a record to Foundation's **Deployment History** — a green Deployment
History therefore says nothing about whether `ipmi_config` succeeded.

### Opt-in per node — off by default

A node is included **only** when it carries `ipmi_configure_now = true`:

```json
{
  "node_position": "A",
  "hypervisor_hostname": "ntnx-01",
  "ipmi_ip": "10.0.100.11",
  "ipmi_mac": "00:11:22:33:44:55",
  "ipmi_configure_now": true
}
```

Exports from <https://install.nutanix.com> do **not** emit `ipmi_configure_now`,
so the step is off for every wizard-generated config and the module plans zero
IPMI resources. That default is deliberate: the overwhelmingly common case is a
BMC that already holds its IP — which is precisely how Foundation reaches the
node to image it. Re-configuring an already-configured BMC is at best a no-op and
at worst fails the apply.

BMC logins come from the sensitive `var.node_ipmi_credentials`, keyed by
`hypervisor_hostname`, sourced from the SOPS-encrypted foundation JSON — IPMI
credentials must never appear in plaintext YAML or the wizard file.

### Prerequisites

All three must hold, or `configure_node` fails on the Foundation VM:

| Requirement | Why |
| ----------- | --- |
| Foundation VM in the **same broadcast domain** as the IPMI interfaces | An unconfigured BMC has no IP, so Foundation addresses it at layer 2. A routed IPMI VLAN will not work. |
| `ipmi_mac` known for each opted-in node | The MAC is the only handle on an unconfigured BMC. |
| IPMI-over-LAN enabled on the BMC | A BMC factory reset disables it. |

The module enforces the second at **plan** time via resource preconditions, along
with the presence of credentials and of `ipmi_netmask` / `ipmi_gateway`. This is
worth the noise: Foundation reports failures as an opaque Python function repr —
`Failed to execute <function configure_node at 0x...>` — with the traceback
discarded. When it does fail at apply, the real error is on the Foundation VM in
`/home/nutanix/foundation/log/service.log` and the per-node logs.

### One-shot, create-only semantics

Applying configures the physical BMC out-of-band. The provider implements
**neither Read nor Delete** for this resource ("there is no read API for IPMI
config"), which has two consequences:

- `tofu destroy` removes the resource from state only — it does **not** reset or
  de-configure the hardware IPMI interface, and drift is never detected.
- A **failed** create never lands in state, so it re-fires on every subsequent
  apply. A misconfigured opt-in will block the landing zone indefinitely until
  the node is opted back out.

`imaging` declares an explicit `depends_on` for this resource, so opted-in BMCs
are configured before imaging starts rather than concurrently with it.

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
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10.0 |
| <a name="requirement_nutanix"></a> [nutanix](#requirement\_nutanix) | >= 2.4.2 |

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
| [nutanix_foundation_ipmi_config.ipmi_config](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/resources/foundation_ipmi_config) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_ahv_iso_checksum"></a> [ahv\_iso\_checksum](#input\_ahv\_iso\_checksum) | MD5 checksum of the AHV ISO. Optional. | `string` | `null` | no |
| <a name="input_ahv_iso_filename"></a> [ahv\_iso\_filename](#input\_ahv\_iso\_filename) | AHV (kvm) ISO filename on the Foundation VM. | `string` | `""` | no |
| <a name="input_ahv_iso_local_path"></a> [ahv\_iso\_local\_path](#input\_ahv\_iso\_local\_path) | Local path to AHV ISO. If set, Terraform uploads it and uses the result. | `string` | `""` | no |
| <a name="input_bond_lacp_rate"></a> [bond\_lacp\_rate](#input\_bond\_lacp\_rate) | LACP rate override ('fast' or 'slow'). Only relevant when bond\_mode is '802.3ad'. Overrides the value from the JSON config export. | `string` | `null` | no |
| <a name="input_bond_mode"></a> [bond\_mode](#input\_bond\_mode) | Bond mode override (e.g. 'active-backup', 'balance-slb', '802.3ad'). Overrides the value from the JSON config export. Use 'active-backup' for single-NIC or when the switch is not running LACP. | `string` | `null` | no |
| <a name="input_config"></a> [config](#input\_config) | The .config object from the Foundation preconfiguration JSON export (install.nutanix.com).<br/><br/>Non-secret geometry only: gateways, blocks/nodes (IPs, hostnames, positions), clusters.<br/>Do NOT pass node BMC passwords here — they would appear in clear text in plans.<br/>Supply per-node BMC login via var.node\_ipmi\_credentials (keyed by hypervisor\_hostname).<br/>Hypervisor password after imaging is var.hypervisor\_password.<br/><br/>Optional per-node key `ipmi_configure_now = true` opts that node in to the<br/>pre-imaging nutanix\_foundation\_ipmi\_config step (default: false — see<br/>"IPMI Pre-Imaging Configuration" in the module README). Wizard exports from<br/>install.nutanix.com do not emit this key, so the step is off unless added. | `any` | n/a | yes |
| <a name="input_esx_iso_checksum"></a> [esx\_iso\_checksum](#input\_esx\_iso\_checksum) | MD5 checksum of the ESXi ISO. Optional. | `string` | `null` | no |
| <a name="input_esx_iso_filename"></a> [esx\_iso\_filename](#input\_esx\_iso\_filename) | ESXi ISO filename on the Foundation VM. | `string` | `""` | no |
| <a name="input_esx_iso_local_path"></a> [esx\_iso\_local\_path](#input\_esx\_iso\_local\_path) | Local path to ESXi ISO. If set, Terraform uploads it and uses the result. | `string` | `""` | no |
| <a name="input_hyperv_iso_checksum"></a> [hyperv\_iso\_checksum](#input\_hyperv\_iso\_checksum) | MD5 checksum of the Hyper-V ISO. Optional. | `string` | `null` | no |
| <a name="input_hyperv_iso_filename"></a> [hyperv\_iso\_filename](#input\_hyperv\_iso\_filename) | Hyper-V ISO filename on the Foundation VM. | `string` | `""` | no |
| <a name="input_hyperv_iso_local_path"></a> [hyperv\_iso\_local\_path](#input\_hyperv\_iso\_local\_path) | Local path to Hyper-V ISO. If set, Terraform uploads it and uses the result. | `string` | `""` | no |
| <a name="input_hypervisor_nameserver"></a> [hypervisor\_nameserver](#input\_hypervisor\_nameserver) | DNS server for the hypervisor. | `string` | `null` | no |
| <a name="input_hypervisor_password"></a> [hypervisor\_password](#input\_hypervisor\_password) | Password to set on the hypervisor after imaging. | `string` | `null` | no |
| <a name="input_layout_egg_uuid"></a> [layout\_egg\_uuid](#input\_layout\_egg\_uuid) | UUID of a custom disk layout. | `string` | `null` | no |
| <a name="input_node_ipmi_credentials"></a> [node\_ipmi\_credentials](#input\_node\_ipmi\_credentials) | Per-node BMC credentials for nutanix\_foundation\_image\_nodes, keyed by the node's<br/>hypervisor\_hostname (must match config.blocks[*].nodes[*].hypervisor\_hostname).<br/><br/>Sensitive — sourced from SOPS-encrypted foundation JSON by the caller, never left as<br/>nested keys on var.config (which would print in plan). | <pre>map(object({<br/>    ipmi_user     = optional(string, null)<br/>    ipmi_password = string<br/>  }))</pre> | `{}` | no |
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
| <a name="output_ipmi_config_ids"></a> [ipmi\_config\_ids](#output\_ipmi\_config\_ids) | Map of node label => nutanix\_foundation\_ipmi\_config resource id. |
| <a name="output_ipmi_configs"></a> [ipmi\_configs](#output\_ipmi\_configs) | Per-node IPMI configuration results keyed by node label (resource id + per-node BMC configure status). |
| <a name="output_session_id"></a> [session\_id](#output\_session\_id) | Foundation imaging session ID |
<!-- END_TF_DOCS -->
