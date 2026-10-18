variable "account_id" {
  description = "Cloudflare account ID that owns the zone."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{32}$", var.account_id))
    error_message = "account_id must be a 32-character Cloudflare account ID."
  }
}

variable "name" {
  description = "Apex domain of the zone, for example `example.com`."
  type        = string

  validation {
    condition     = can(regex("^([a-z0-9]([a-z0-9-]*[a-z0-9])?\\.)+[a-z]{2,}$", var.name))
    error_message = "name must be a lowercase domain name."
  }
}

variable "dnssec_enabled" {
  description = "Sign the zone with DNSSEC. The DS record from the `dnssec` output must then be added at the registrar."
  type        = bool
  default     = true
}

variable "caa_issuers" {
  description = "Certificate authorities allowed to issue certificates (and wildcards) for the zone."
  type        = list(string)
  default     = ["letsencrypt.org"]

  validation {
    condition     = length(var.caa_issuers) > 0
    error_message = "At least one CA must be allowed, or no certificate can ever be issued."
  }
}

variable "caa_iodef" {
  description = "Optional `mailto:` or `https:` URL where CAs report issuance violations."
  type        = string
  default     = null

  validation {
    condition     = var.caa_iodef == null || can(regex("^(mailto:|https://)", var.caa_iodef))
    error_message = "caa_iodef must start with mailto: or https://."
  }
}

variable "dmarc_policy" {
  description = "DMARC policy for the apex (`none`, `quarantine`, or `reject`), or null to leave DMARC unmanaged."
  type        = string
  default     = "reject"

  validation {
    condition     = var.dmarc_policy == null || contains(["none", "quarantine", "reject"], coalesce(var.dmarc_policy, "none"))
    error_message = "dmarc_policy must be none, quarantine, or reject."
  }
}

variable "dmarc_report_email" {
  description = "Optional address that receives aggregate DMARC reports."
  type        = string
  default     = null
}

variable "record_comment" {
  description = "Stable provenance comment for managed records (at most 100 characters on the Free plan)."
  type        = string
  default     = null

  validation {
    condition     = var.record_comment == null || length(coalesce(var.record_comment, "")) <= 100
    error_message = "record_comment must be at most 100 characters."
  }
}

variable "deletion_protection" {
  description = "Protect the zone from deletion: blocks `tofu destroy` of this component. Set false only for disposable zones."
  type        = bool
  default     = true
}
