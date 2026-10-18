# tags

The shared tags every platform resource carries
([ADR-0135](https://github.com/NCodeGroup/Identity/blob/main/docs/adr/0135-one-resource-tagging-strategy-across-every-vendor.md)),
produced once and rendered in each vendor's format. It has no provider, so any root can call it.

| Output    | Form                                  | Use it for                                             |
| --------- | ------------------------------------- | ------------------------------------------------------ |
| `map`     | `{ key = value }`                     | AWS provider `default_tags`, OCI freeform tags, labels |
| `list`    | sorted `["key:value", …]`             | Akamai/Linode tags (50-character limit per tag)        |
| `comment` | `managed_by=… source=…` (≤ 100 chars) | Cloudflare DNS record comments (no tags on Free plans) |

Rules the module enforces:

- Keys are `snake_case`; values are lowercased. Values are static — never timestamps, commit SHAs, or anything else that
  changes between plans, or every plan shows tag drift.
- `environment` is a **platform** environment — exactly `shared`, `lab`, `production`, or `ci`. A customer's `dev` or
  `test` is a tenant, never a platform environment
  ([ADR-0131](https://github.com/NCodeGroup/Identity/blob/main/docs/adr/0131-hosted-platform-environment-model-and-hostname-scheme.md)).
- `owner_email` is a role mailbox, never a person: tags are public.

Components add their own keys (`component`, `role`, `data_classification`, `deletion_protection`) on top of these.

## Usage

```hcl
module "tags" {
  source = "git::https://github.com/NCodeGroup/identity-platform.git//modules/tags?ref=<version>"

  application = "ncode-identity"
  environment = "lab"
  owner_email = "platform@nidentity.io"
  account     = "nidentity-platform"
  source_path = "NCodeGroup/identity-platform/live/lab"
}

provider "aws" {
  default_tags {
    tags = module.tags.map
  }
}
```

<!-- BEGIN_TF_DOCS -->
<!-- prettier-ignore-start -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.13.0 |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| account | Vendor account or tenancy the resources live in. | `string` | n/a | yes |
| application | Application or product the resources belong to. | `string` | n/a | yes |
| environment | Platform environment the resources serve. Never a customer's tenant environment such as `dev` or `test`. | `string` | n/a | yes |
| owner\_email | Role mailbox that owns the resources. Never a personal address: tag values are public. | `string` | n/a | yes |
| source\_path | Repository and path of the root that manages the resources, for example `NCodeGroup/identity-platform/live/lab`. | `string` | n/a | yes |
| managed\_by | Tool that owns the resources' desired state. | `string` | `"opentofu"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| comment | Stable one-line provenance for resources that only support a comment (Cloudflare DNS records, at most 100 characters). |
| list | Shared tags as sorted `key:value` strings (Akamai tags). |
| map | Shared tags as a key/value map (AWS `default_tags`, OCI freeform tags). |
<!-- prettier-ignore-end -->
<!-- END_TF_DOCS -->
