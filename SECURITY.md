# Security policy

This repository holds the infrastructure code for the NCode.Identity hosted platform. It is public on purpose: the
platform's security must not depend on hiding how it is built
([ADR-0132](https://github.com/NCodeGroup/Identity/blob/main/docs/adr/0132-platform-infrastructure-as-code-is-public-on-github.md)).
Credentials, state, plans, and backups are never stored here.

## Reporting a vulnerability

Report suspected vulnerabilities **privately** through GitHub's
[private vulnerability reporting](https://github.com/NCodeGroup/identity-platform/security/advisories/new) — never in a
public issue or pull request. This covers misconfigurations in this repository as well as anything you find on the
running platform (`*.nidentity.io`).

Vulnerabilities in the identity server itself belong to the library repository's
[security policy](https://github.com/NCodeGroup/Identity/blob/main/SECURITY.md).

## If you find a credential

If you believe a credential has been committed or exposed, report it privately as above. It will be revoked and
rotated first, and investigated second.
