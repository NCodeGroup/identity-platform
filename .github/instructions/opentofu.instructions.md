---
applyTo: "**/*.tf,**/*.tftest.hcl"
description: "identity-platform OpenTofu conventions — component layout, naming, variables, tags, deletion protection, versions, live roots, tests, and generated docs."
---

# OpenTofu conventions

These rules describe how the existing components and roots are written; follow them, and imitate the closest existing
component (for example [`modules/aws-kms-key`](../../modules/aws-kms-key)) rather than inventing a new shape. The
reasoning behind them is in the README's Conventions section and the library repository's ADRs.

## Component layout — `modules/<component>/`

- One concern per component, with no platform-specific defaults: everything environment- or vendor-account-specific is
  an input.
- Files: `versions.tf` (the `terraform` block only), `variables.tf`, `main.tf` (locals, data sources, resources),
  `outputs.tf`, `tests/<component>.tftest.hcl` in snake_case (`kms_key.tftest.hcl` for `aws-kms-key`), and `README.md`.
- Name the sole or primary resource of a type `this`; name any other by its role (`state`, `caa`, `dmarc`, `trust`,
  `deletion_guard`). Module calls in a root are named by role in snake_case (`state_backend`, `secrets_key`).
- A comment explains **why** — a provider quirk, a security choice, a constraint — never what the next line does.
- Format with `tofu fmt` (two-space indent, aligned `=`).

## Variables and outputs

- Every variable has a `description` (a sentence ending in a period, literals in backticks) and an explicit `type`.
- Defaults are the secure choice (`deletion_protection = true`, `data_classification = "restricted"`, the longest
  deletion window); a required input has no default.
- Constrain every input whose valid values are narrower than its type with a `validation` block; its `error_message`
  names the variable and states what it must be: `"role must be lowercase kebab-case, at most 40 characters."`
- Mark a secret input `sensitive = true`, and document where its value comes from (an environment variable or SSM,
  never a committed file).
- Every output has a `description`.

## Tags

- A component takes `tags` (`map(string)`, default `{}`) and merges its own tags over the caller's in `locals.tags`:
  `component` (its directory name), `role`, `data_classification`, and
  `deletion_protection = tostring(var.deletion_protection)` — then applies `local.tags` to every taggable resource.
- Tag keys are `snake_case` and values are static, so plans never drift
  ([ADR-0135](https://github.com/NCodeGroup/Identity/blob/main/docs/adr/0135-one-resource-tagging-strategy-across-every-vendor.md));
  the shared tags come from the [`tags`](../../modules/tags) component.

## Deletion protection

Every stateful component takes `deletion_protection` (`bool`, default `true`). It drives the provider's own safeguards
(no force-destroy, archive instead of delete) and a guard that makes any plan destroying the component fail:

```hcl
# prevent_destroy can't take a variable, so a conditional guard blocks `tofu destroy` of the component while protected.
resource "terraform_data" "deletion_guard" {
  count = var.deletion_protection ? 1 : 0

  input = aws_kms_key.this.key_id # the primary resource's ID

  lifecycle {
    prevent_destroy = true
  }
}
```

A refactor that moves or renames a resource adds a `moved` block so existing state follows it instead of being
replaced.

## Versions

- Components: `required_version = ">= 1.13.0"` and provider ranges `">= <floor>, < <next major>"`, where the floor is
  the first provider release with every resource and attribute the component uses — check the provider's tagged
  sources, not just the current docs.
- Live roots: `required_version = "~> <minor>"` matching [`.opentofu-version`](../../.opentofu-version), `~>` provider
  constraints, and exact pins with checksums for every platform in the committed `.terraform.lock.hcl`.
- When adding or raising a version, pin the latest upstream release read from the registry or release feed at that
  moment.

## Live roots — `live/<root>/`

- Consume components only by released tag:
  `source = "git::https://github.com/NCodeGroup/identity-platform.git//modules/<name>?ref=vX.Y.Z"`. `validate` rejects
  a local path
  ([ADR-0133](https://github.com/NCodeGroup/Identity/blob/main/docs/adr/0133-we-ship-and-run-the-same-deployment-artifacts.md)).
- The `s3` backend uses `use_lockfile = true`, and the `encryption` block enforces `aes_gcm` with the KMS key provider
  for both `state` and `plan`.
- Providers are configured in `providers.tf` with credentials from the environment only; a comment says which variable
  supplies them and where CI reads it from.
- Adopting existing infrastructure uses an `import` block gated by a variable the tests set to `false`
  (`adopt_existing_repository` in `live/bootstrap`), because mocked providers can't import.

## Tests — `tests/*.tftest.hcl`

- `mock_provider "<provider>" {}` for every provider, and a top-level `variables` block with the minimal valid inputs.
- Each `run` is named for the behavior it proves in snake_case (`key_rotates_and_is_aliased`) and uses
  `command = plan`.
- Each `assert`'s `error_message` states the rule that broke, with "must" (`"Customer managed keys must rotate."`).
- Cover the secure defaults, the tag merge over the caller's tags, that `deletion_protection = false` removes the
  guard, and every `validation` block with an `expect_failures = [var.<name>]` run.
- A mocked attribute of nested type needs every one of its fields, or OpenTofu rejects the mock with
  "Invalid mock/override field".

## Documentation

Every component and root has a `README.md`: what it is for and why, a bullet list of its behaviors and safeguards, an
`hcl` usage example whose `source` ends in `?ref=<version>`, then the section between `BEGIN_TF_DOCS` and
`END_TF_DOCS`. That section is generated by terraform-docs and checked in CI — regenerate it, never edit it by hand.
