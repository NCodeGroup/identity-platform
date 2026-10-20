# identity-platform

Infrastructure as code for the hosted [NCode.Identity](https://github.com/NCodeGroup/Identity) platform at
`nidentity.io`: reusable OpenTofu components and the live configuration of the platform's own environments.

The repository is public on purpose: the platform's security must not depend on hiding how it is built. It never holds
credentials, state, plans, or backups — CI authenticates with short-lived OIDC tokens and reads vendor tokens from
encrypted SSM parameters
([ADR-0132](https://github.com/NCodeGroup/Identity/blob/main/docs/adr/0132-platform-infrastructure-as-code-is-public-on-github.md)).
Report vulnerabilities privately as described in [SECURITY.md](SECURITY.md).

## Layout

| Path       | Holds                                                                                              |
| ---------- | -------------------------------------------------------------------------------------------------- |
| `modules/` | Components: one concern each, no platform-specific defaults, tested with mocked providers          |
| `live/`    | Roots for the platform's own environments; [`live/bootstrap`](live/bootstrap) is the root of trust |

Stacks, in-cluster components, and Flux cluster configuration (`stacks/`, `kubernetes/`, `clusters/`) follow as the
platform grows
([ADR-0133](https://github.com/NCodeGroup/Identity/blob/main/docs/adr/0133-we-ship-and-run-the-same-deployment-artifacts.md)).

### Components

| Component                                        | Purpose                                                                |
| ------------------------------------------------ | ---------------------------------------------------------------------- |
| [`tags`](modules/tags)                           | The shared tags, rendered for each vendor                              |
| [`aws-state-backend`](modules/aws-state-backend) | S3 bucket and KMS key for OpenTofu state                               |
| [`aws-backup-bucket`](modules/aws-backup-bucket) | Object Lock bucket for database backups                                |
| [`aws-kms-key`](modules/aws-kms-key)             | Customer-managed KMS key                                               |
| [`aws-github-oidc`](modules/aws-github-oidc)     | IAM roles GitHub Actions assumes through OIDC                          |
| [`cloudflare-zone`](modules/cloudflare-zone)     | DNS zone with DNSSEC, CAA, and DMARC                                   |
| [`github-repository`](modules/github-repository) | Hardened repository: rulesets, Actions policy, deployment environments |

### Live roots

| Root                               | Applied by                               | Manages                                                     |
| ---------------------------------- | ---------------------------------------- | ----------------------------------------------------------- |
| [`live/bootstrap`](live/bootstrap) | the owner, by hand                       | State, backups, CI roles and tokens, zone, repository rules |
| [`live/global`](live/global)       | CI, through the `production` environment | Inbound email; later, records for each environment          |

The [`deploy`](.github/workflows/deploy.yml) workflow plans every CI root on pull requests, applies the reviewed plan
after a merge to `main` (production applies wait for approval), and runs a daily drift check. CI authenticates to AWS
through GitHub OIDC with run-named sessions and reads vendor tokens from SSM — there are no stored secrets.

## Environments

The platform has exactly these environments: **`production`** (every customer tenant), **`lab`** (the owner's private
proving ground), and ephemeral **`ci`** runs; cross-environment foundations are **`shared`**. A customer's dev, test,
and staging are tenants on production — those words never name a platform environment
([ADR-0131](https://github.com/NCodeGroup/Identity/blob/main/docs/adr/0131-hosted-platform-environment-model-and-hostname-scheme.md)).

## Conventions

- **Deletion protection.** Every stateful component takes `deletion_protection` (default `true`). It drives the
  provider's own safeguards (no force-destroy, archive instead of delete) and a `terraform_data.deletion_guard` whose
  `prevent_destroy` makes any plan that would destroy the component fail. The lab sets it to `false`; production and
  shared foundations keep `true`.
- **Tags.** Every resource carries the same `snake_case` tags — `application`, `environment`, `owner_email`, `account`,
  `managed_by`, `source`, plus the component's `component`, `role`, `data_classification`, and `deletion_protection`.
  Values are static so plans never drift
  ([ADR-0135](https://github.com/NCodeGroup/Identity/blob/main/docs/adr/0135-one-resource-tagging-strategy-across-every-vendor.md)).
- **Versions.** The OpenTofu version is pinned in `.opentofu-version`. Components declare provider version ranges whose
  floor is the first release with every resource and attribute they use (check the provider's tagged sources, not
  just the current docs); each live root pins exact providers in its committed `.terraform.lock.hcl`.
- **Releases.** The repository releases with one semantic version; release tags are immutable. Live roots consume
  components only by released version — `git::https://github.com/NCodeGroup/identity-platform.git//modules/<name>?ref=vX.Y.Z`
  — and CI rejects local paths there (the member rule,
  [ADR-0133](https://github.com/NCodeGroup/Identity/blob/main/docs/adr/0133-we-ship-and-run-the-same-deployment-artifacts.md)).
  The steps are in [Releasing](#releasing).
- **Documentation.** Each component and root has a README; the section between `BEGIN_TF_DOCS` and `END_TF_DOCS` is
  generated by terraform-docs and checked in CI.

## Working locally

Install the tools — on Windows with winget and [uv](https://docs.astral.sh/uv/):

```powershell
winget install --exact Tofuutils.Tenv Terraform-docs.Terraform-docs Gitleaks.Gitleaks astral-sh.uv
uv tool install pre-commit --python 3.14   # uv-managed Python: PyYAML ships no Python 3.15 wheels, so 3.15 needs a C compiler
uv tool update-shell                        # puts uv's tool directory on PATH
```

On macOS: `brew install tenv terraform-docs gitleaks pre-commit`.

The installers change the user `PATH`, which running shells don't see — and VS Code terminals inherit it from VS Code,
so they don't see it until VS Code restarts. Reload it in the current PowerShell session instead:

```powershell
$env:PATH = [Environment]::GetEnvironmentVariable('Path', 'User') + ';' + [Environment]::GetEnvironmentVariable('Path', 'Machine')
```

Then, in the repository:

```powershell
tenv tofu install      # the version in .opentofu-version, signature-verified
pre-commit install     # gitleaks, tofu fmt, and terraform-docs on every commit; strips agent co-author trailers
```

Check a component or root the way CI does:

```powershell
tofu fmt -check -recursive
tofu -chdir=modules/tags init -backend=false
tofu -chdir=modules/tags validate
tofu -chdir=modules/tags test
```

Regenerate the docs after changing variables or outputs:

```powershell
terraform-docs --config .terraform-docs.yml --recursive --recursive-path modules --recursive-include-main=false .
terraform-docs --config .terraform-docs.yml --recursive --recursive-path live --recursive-include-main=false .
```

After changing a live root's providers, record checksums for every platform CI and contributors use:

```powershell
tofu -chdir=live/<root> providers lock -platform=linux_amd64 -platform=linux_arm64 -platform=windows_amd64 -platform=darwin_arm64
```

The [`validate`](.github/workflows/validate.yml) workflow runs all of this on every pull request and is required to
merge into `main`.

Two `tofu test` limits shape the tests:

- Mocked providers can't import, and an `import` block crashes `tofu test`. A root that adopts existing resources gates
  its imports behind a variable its tests set to `false` (`adopt_existing_repository` in `live/bootstrap`).
- A mocked attribute of nested type needs every one of its fields, or OpenTofu rejects the mock with
  "Invalid mock/override field".

## Releasing

A component change reaches a live root in two pull requests with a release between them: the change merges, `main` is
tagged, and a second pull request moves the live roots to the tag. Changes outside `modules/` — docs, CI, the live
roots themselves — need no release.

1. **Merge the component change** in its own pull request: `feat(<component>): …` or `fix(<component>): …`, with `!`
   when it breaks consumers.
2. **Choose the version** from what changed under `modules/` since the last tag — not from pull request titles. List
   it with `git log --oneline <last tag>..main -- modules`. The repository has one version for every component. Before
   1.0, a breaking change bumps the minor version (`v0.3.0` → `v0.4.0`) and anything else bumps the patch (`v0.3.1`).
   Breaking means a consumer must act to adopt the release: a removed or reshaped input or output, a new required
   input, a forced resource replacement, a raised provider or OpenTofu floor, or a new permission for the credentials
   that apply it.
3. **Tag `main`.** The `release-tags` ruleset protects `v*` tags from deletion and from being moved, so a pushed tag is
   permanent — tag the merged commit, never a local one:

   ```powershell
   git switch main; git pull --ff-only
   git tag -a v0.4.0 -m "v0.4.0"
   git push origin v0.4.0
   ```

4. **Publish the release** on GitHub — Releases → Draft a new release → the tag, titled with the version. Write the
   notes by hand for whoever adopts the release, under `## Breaking`, `## Added`, and `## Fixed`: each bullet starts
   with the component in backticks and says what the consumer must do — a token permission, a provider floor, an input
   that changed shape (see [v0.3.0](https://github.com/NCodeGroup/identity-platform/releases/tag/v0.3.0)).
5. **Adopt the release** in each live root that uses components, in a pull request titled
   `chore(<root>): consume vX.Y.Z`:
   - Move every `?ref=` in the root to the new tag — unchanged components too, so a root runs a single release.
   - Regenerate the root's docs with the `terraform-docs` command above.
   - Run `init -backend=false -lockfile=readonly`, `validate`, and `test` on the root. If the release raises a provider
     floor above the root's `.terraform.lock.hcl`, the read-only init fails: run `init -backend=false -upgrade`, then
     the `providers lock` command above, and commit the lock file.
   - In the description, carry over the release's consumer actions and state the expected plan.

   Dependabot's weekly `opentofu` run proposes the same bumps a week after a release, one component at a time and
   without the docs. Adopt by hand instead; Dependabot closes its pull requests once the root already uses the release.

6. **Apply.** After the adoption merges, `deploy` applies a CI root once the `production` environment is approved;
   [`live/bootstrap`](live/bootstrap#later-runs) is applied by hand.

## Working with agents

Coding agents start from [AGENTS.md](AGENTS.md) and [`.github/copilot-instructions.md`](.github/copilot-instructions.md).
Multi-step changes run as plan-and-execute: Claude Opus plans into `PLAN.md`, a lower-cost Copilot model executes it
one verified step at a time, and Opus re-plans any step that comes back
([ADR-0170](https://github.com/NCodeGroup/Identity/blob/main/docs/adr/0170-agent-work-is-planned-on-a-frontier-model-and-executed-step-by-step-on-a-cheaper-one.md)).
Agents validate locally only; they never plan or apply against live state.

## Building the platform from zero

Follow the [platform bootstrap runbook](https://github.com/NCodeGroup/Identity/blob/main/docs/platform-bootstrap.md):
the vendor sign-ups and other one-time manual steps, then [`live/bootstrap`](live/bootstrap), after which everything
runs from GitHub Actions.

## License

[Apache-2.0](LICENSE).
