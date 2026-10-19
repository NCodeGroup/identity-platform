aws_account_id        = "276115452055"
aws_region            = "us-west-2"
name_prefix           = "nidentity-platform"
domain                = "nidentity.io"
cloudflare_account_id = "65ff5e83ff7a063cde090a3079d487ec"

# security@ for security.txt, platform@ as the owner of every resource, postmaster@ and abuse@ (RFC 2142 / RFC 5321),
# and one per vendor account.
email_aliases = [
  "abuse",
  "docker-ncodegroup",
  "gitlab",
  "npm",
  "platform",
  "postmaster",
  "security",
]
