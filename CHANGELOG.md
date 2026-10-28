# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `docs`: This changelog. Every change adds its entries under `## [Unreleased]`, and a release moves them into its
  version's section, which becomes the release notes.
- `agents`: `/run-issues` runs in Copilot Chat and Copilot CLI as well as Claude Code.

### Changed

- `agents`: The plan-and-execute workflow follows project-template v0.37.0. `/ship-plan` titles and describes pull
  requests by this repository's pull-request protocol and files no follow-ups as issues.

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

[unreleased]: https://github.com/NCodeGroup/identity-platform/compare/v0.3.0...HEAD
[0.1.0]: https://github.com/NCodeGroup/identity-platform/releases/tag/v0.1.0
