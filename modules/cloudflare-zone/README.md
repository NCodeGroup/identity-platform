# cloudflare-zone

A Cloudflare DNS zone with the records every zone should have from day one
([ADR-0131](https://github.com/NCodeGroup/Identity/blob/main/docs/adr/0131-hosted-platform-environment-model-and-hostname-scheme.md)).

- **DNSSEC** on by default. After the zone is active, publish the DS record from the `dnssec` output at the registrar.
- **CAA** records allow only the listed certificate authorities (Let's Encrypt by default) for both `issue` and
  `issuewild`, with an optional `iodef` address for violation reports.
- **Universal SSL** is off, always. While it is on, Cloudflare publishes hidden CAA records for its own CAs beside the
  listed ones, so the CAA records would no longer be the only CAs that can issue for the zone. A DNS-only host gets
  its certificate elsewhere and never uses it. A host proxied through Cloudflare needs its own edge certificate: an
  advanced certificate from a CA in `caa_issuers`, or an uploaded one.
- **DMARC** at `p=reject` with strict alignment, so nobody can send mail as the domain. Add a report address with
  `dmarc_report_email`.
- Records carry `record_comment` — pass the `comment` output of the [`tags`](../tags) module, since Cloudflare's Free
  plan has no record tags.
- While `deletion_protection` is `true`, a guard resource makes `tofu destroy` fail; deleting a zone takes the domain
  off the internet.

The zone is created as a full (authoritative) zone. Until the registrar points the domain at the zone's `name_servers`,
its status stays `pending`.

## Usage

```hcl
module "zone" {
  source = "git::https://github.com/NCodeGroup/identity-platform.git//modules/cloudflare-zone?ref=<version>"

  account_id     = "0123456789abcdef0123456789abcdef"
  name           = "example.com"
  caa_iodef      = "mailto:security@example.com"
  record_comment = module.tags.comment
}

output "registrar" {
  value = {
    name_servers = module.zone.name_servers
    ds           = module.zone.dnssec
  }
}
```

<!-- BEGIN_TF_DOCS -->
<!-- prettier-ignore-start -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.13.0 |
| cloudflare | >= 5.13, < 6.0 |

## Providers

| Name | Version |
| ---- | ------- |
| cloudflare | >= 5.13, < 6.0 |
| terraform | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [cloudflare_dns_record.caa](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/dns_record) | resource |
| [cloudflare_dns_record.dmarc](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/dns_record) | resource |
| [cloudflare_universal_ssl_setting.this](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/universal_ssl_setting) | resource |
| [cloudflare_zone.this](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/zone) | resource |
| [cloudflare_zone_dnssec.this](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/zone_dnssec) | resource |
| [terraform_data.deletion_guard](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| account\_id | Cloudflare account ID that owns the zone. | `string` | n/a | yes |
| name | Apex domain of the zone, for example `example.com`. | `string` | n/a | yes |
| caa\_iodef | Optional `mailto:` or `https:` URL where CAs report issuance violations. | `string` | `null` | no |
| caa\_issuers | Certificate authorities allowed to issue certificates (and wildcards) for the zone. | `list(string)` | ```[ "letsencrypt.org" ]``` | no |
| deletion\_protection | Protect the zone from deletion: blocks `tofu destroy` of this component. Set false only for disposable zones. | `bool` | `true` | no |
| dmarc\_policy | DMARC policy for the apex (`none`, `quarantine`, or `reject`), or null to leave DMARC unmanaged. | `string` | `"reject"` | no |
| dmarc\_report\_email | Optional address that receives aggregate DMARC reports. | `string` | `null` | no |
| dnssec\_enabled | Sign the zone with DNSSEC. The DS record from the `dnssec` output must then be added at the registrar. | `bool` | `true` | no |
| record\_comment | Stable provenance comment for managed records (at most 100 characters on the Free plan). | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| dnssec | DS record fields to add at the registrar, or null when DNSSEC is disabled. |
| name\_servers | Nameservers to set at the registrar. |
| status | Zone status; `pending` until the registrar delegates to the name\_servers. |
| zone\_id | Cloudflare zone ID. |
<!-- prettier-ignore-end -->
<!-- END_TF_DOCS -->
