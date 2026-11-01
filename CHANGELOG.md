# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `agents`: `/audit-conventions`, in Claude Code, Copilot Chat and Copilot CLI, ranks where the code doesn't follow
  `AGENTS.md`, its instruction files and the decision records, without changing a file; `/address-feedback`, in
  Claude Code, answers every open comment on one pull request and pushes the fixes it judges sound.
- `ci`: The `template-update` workflow keeps one `template-update` issue open while a newer project-template version
  is out. `code-review-auto-merge` turns on auto-merge for a Dependabot pull request that only moves the NCode Review
  pin; until NCodeGroup/project-template#195 is fixed its run fails here, since `main` takes only squash merges, and
  the pull request waits for a person.
- `ci`: `copilot-setup-steps` prepares the Copilot cloud agent's runner with OpenTofu and terraform-docs, installed as
  `validate` installs them.
- `docs`: `CONTRIBUTING.md`, and the project template's decision records in `docs/decisions/project-template/`, with
  the two this repository overrides listed in `AGENTS.md`.

### Changed

- `bootstrap`: Consumes the components at v0.3.1 and turns on the repository's auto-merge (`allow_auto_merge = true`),
  so a pull request can be set to merge on its own once everything the default branch ruleset requires has passed.
- `agents`: The plan-and-execute workflow follows project-template v0.49.0. The Landing section adds `review-bots`,
  `max-review-rounds` and `prelude`, and `Get-PlanState.ps1` makes its network calls at the same time.
- `ci`: `ci` checks the decision index, cancels a run that a newer push supersedes (never a `main` commit's), and
  stops after 30 minutes. Dependabot gives the NCode Review action, and each ecosystem's security updates, pull
  requests of their own.

## [0.3.1] - 2026-10-28

### Added

- `docs`: This changelog. Every change adds its entries under `## [Unreleased]`, and a release moves them into its
  version's section, which becomes the release notes.
- `agents`: `/run-issues` runs in Copilot Chat and Copilot CLI as well as Claude Code.
- `docs`: Sections for v0.1.0, v0.2.0 and v0.3.0, taken from their GitHub release notes, so the changelog covers every
  release.
- `github-repository`: `allow_auto_merge` input, off by default. When set, a pull request can be put on auto-merge
  and merges once everything the default branch ruleset requires has passed.

### Changed

- `agents`: The plan-and-execute workflow follows project-template v0.37.0. `/ship-plan` titles and describes pull
  requests by this repository's pull-request protocol and files no follow-ups as issues.

## [0.3.0] - 2026-10-19

### Changed

- **Breaking:** `cloudflare-zone`: Universal SSL is always off (`cloudflare_universal_ssl_setting`), so the zone's CAA
  records are the only certificate authorities that can issue for it. Cloudflare otherwise publishes hidden CAA records
  for its own CAs. The token that applies the module needs *Zone → SSL and Certificates → Edit*, and the cloudflare
  provider must be `>= 5.13`.

## [0.2.0] - 2026-10-18

### Added

- `aws-github-oidc`: Every role requires the session name `gh-<run_id>-<run_attempt>` (`sts:RoleSessionName`), so
  CloudTrail ties each call to its workflow run.
- `github-repository`: The `repository_id` output.

### Changed

- **Breaking:** `aws-github-oidc`: `repository` is now `{ owner, owner_id, name, id }`. Trust policies match GitHub's
  immutable OIDC subject (`repo:<owner>@<owner_id>/<name>@<id>:<context>`), the default for repositories created after
  July 15, 2026; older repositories must opt in first.

## [0.1.0] - 2026-10-18

### Added

- `tags`: The shared tag set, rendered for each vendor.
- `aws-state-backend`: S3 bucket and KMS key for OpenTofu state.
- `aws-backup-bucket`: Object Lock bucket for database backups.
- `aws-kms-key`: Customer-managed KMS key.
- `aws-github-oidc`: IAM roles GitHub Actions assumes through OIDC.
- `cloudflare-zone`: DNS zone with DNSSEC, CAA, and DMARC.
- `github-repository`: Hardened repository: rulesets, Actions policy, environments.
- `modules`: Every component requires OpenTofu 1.13 or later.
- `modules`: Stateful components default to `deletion_protection = true`.

[unreleased]: https://github.com/NCodeGroup/identity-platform/compare/v0.3.1...HEAD
[0.3.1]: https://github.com/NCodeGroup/identity-platform/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/NCodeGroup/identity-platform/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/NCodeGroup/identity-platform/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/NCodeGroup/identity-platform/releases/tag/v0.1.0
