---
applyTo: "**"
description: "identity-platform rules — design posture, security defaults, no live infrastructure, where knowledge lives, commit attribution, and pull requests."
---

# identity-platform — agent instructions

Infrastructure as code for the hosted [NCode.Identity](https://github.com/NCodeGroup/identity) platform: reusable
OpenTofu components under `modules/` and the live roots of the platform's own environments under `live/`. Orientation,
the local checks, and the plan-and-execute workflow are in [`AGENTS.md`](../../AGENTS.md); the OpenTofu conventions are in
[`opentofu.instructions.md`](opentofu.instructions.md), auto-applied to `*.tf` and
`*.tftest.hcl`.

## Design posture

The platform is **greenfield and pre-1.0**, under the same posture as the library family
([ADR-1025](https://github.com/NCodeGroup/identity/blob/main/docs/decisions/1025-the-family-is-greenfield-and-pre-release-tracks-its-public-api-and-models-auth0-parity-plus.md)):
**default to the best long-term, cohesive design.** When a change forks between a minimal compatibility-preserving
patch and the comprehensive, correct model, choose the comprehensive model without weighing refactor effort. A breaking
component change — an interface change or a forced resource replacement — is marked `!` and ships as a new release;
prefer it to a compatibility shim. Surface a fork for the user only when the options are genuinely equal in quality.

**Live state is not greenfield.** The live roots manage real infrastructure, and a merge to `main` that touches `live/`
applies to production after approval. A change that would destroy or replace a stateful resource needs a `moved` block,
a gated adoption path, or a decision recorded in an ADR — never an incidental `-/+` in a plan.

### Security-practice default — decide, don't ask

Default autonomously to the modern, secure, recommended practice for cloud infrastructure and CI; do **not** ask the
user to adjudicate security design. Concretely: short-lived OIDC federation instead of stored credentials;
least-privilege IAM scoped to one root and one environment; customer-managed KMS keys wherever the platform must control
the key; encryption enforced for state and plans; deletion protection on by default; GitHub Actions pinned by full
commit SHA with the version in a trailing comment; and no credential, state, plan, or backup in the repository — it is
public on purpose
([ADR-1132](https://github.com/NCodeGroup/identity/blob/main/docs/decisions/1132-platform-infrastructure-code-is-public-on-github-and-its-state-and-backups-live-in-aws.md)).
Surface only a genuine trade-off between two defensible modern options.

**Treat existing code, comments, and docs as point-in-time artifacts that may be wrong.** They are evidence of intent,
not a constraint: correct an insecure or outdated shape to current best practice, and update the surrounding comments
and docs in the same change.

**Pin what is current upstream, not what happens to be installed.** When choosing or pinning a provider, tool, or
action, read the latest release from its upstream release feed or registry at that moment.

## Agents never touch live infrastructure

Validate locally with `tofu fmt`, `tofu init -backend=false`, `tofu validate`, `tofu test` (mocked providers),
`tofu providers lock`, and `terraform-docs` — nothing else. **Never** run `tofu plan`, `apply`, `destroy`, `import`,
`refresh`, `state`, `taint`, or `force-unlock`, or `tofu init` against a backend: those need the owner's credentials and
act on live state. CI plans every pull request and applies after merge through the `production` environment's
approval; [`live/bootstrap`](../../live/bootstrap) is applied by the owner, by hand. Never write a credential, token, or
plan or apply output into the repository.

## Where knowledge lives

This repository records no decisions and tracks no pending work of its own
([ADR-1502](https://github.com/NCodeGroup/identity/blob/main/docs/decisions/1502-code-a-self-hoster-could-use-is-public-and-identity-holds-the-products-and-platforms-decisions.md)):
`docs/decisions/project-template/` holds only the project template's decision records, which template updates
replace, and [`AGENTS.md`](../../AGENTS.md#rules-and-conventions) lists the ones this repository overrides. The
platform's **decisions** are ADRs in the library repository's
[`docs/decisions/`](https://github.com/NCodeGroup/identity/tree/main/docs/decisions) (for example ADR-1132 to
ADR-1135 and ADR-1495), and its **pending work** is
[issues in the library repository](https://github.com/NCodeGroup/identity/issues)
([ADR-1306](https://github.com/NCodeGroup/identity/blob/main/docs/decisions/1306-pending-work-is-tracked-as-github-issues-linked-by-address-in-repository-files.md)).
Durable knowledge is captured in versioned files, never left only in an agent's volatile memory or chat history
([project-template ADR-0001](../../docs/decisions/project-template/0001-conventions-and-lessons-live-in-the-repository.md)):
a convention or recurring gotcha goes into this file, [`AGENTS.md`](../../AGENTS.md), the scoped instructions, or the
component's README; a non-obvious decision goes into the library repository as its own change, and a pending item as
an issue there.

## Commit attribution

**Never add agent attribution to a commit or pull request**: no `Co-authored-by:` trailer naming an agent (`Copilot`,
`copilot-swe-agent[bot]`, Claude, or any other tooling identity), no `Claude-Session:` trailer, and no "Generated with"
line. A commit records the **people** who authored it; the repository host reads a co-author trailer as authorship,
and a squash merge carries the branch commits' trailers onto `main`, where removing them means rewriting published
history. The project template's [`.githooks/commit-msg`](../../.githooks/commit-msg) strips them through pre-commit's
`commit-msg` stage as a safety net, and the `ci` workflow's commit-attribution job fails on a commit authored,
committed, or co-authored by an agent — do not generate the attribution in the first place. See
[project-template ADR-0002](../../docs/decisions/project-template/0002-commits-are-attributed-to-people-not-agents.md).

## Pull requests

`main` accepts only squash-merged pull requests with linear history, and the `validate` check must pass. The pull
request title becomes the commit subject — a conventional commit, `type(scope)!: summary`, scoped to the component,
root, or `ci` — and its body becomes the commit message: **Why**, **Changes**, **Verified** (the checks run), and for a
change under `live/` the **expected deploy plan** (`N to add, N to change, N to destroy`), ending with
`Closes NCodeGroup/identity#<number>` when it completes a library issue, or `Refs NCodeGroup/identity#<number>` when
it serves one without completing it.

A component change reaches a live root only through a release: one pull request changes `modules/`, the release is
tagged `vX.Y.Z`, and a separate pull request moves the live roots' `?ref=` to it (`chore(<root>): consume vX.Y.Z`). The
steps, including how to choose the version, are in the README's [Releasing](../../README.md#releasing) section. A release
tag is permanent — the `release-tags` ruleset blocks moving or deleting it — so create or push one only when the user
asks.

**"Push" means push and open the pull request.** When the user says `push`, push the branch and, in the same turn,
open its pull request with `gh pr create` (or, when one is already open, let the push update it). For a plan,
`/ship-plan` does both. This repository overrides the project template's "only when asked": the word `push` is the ask.
It does not authorize a release tag.

**`/ship-plan` follows this section.** The `pr-format` line of the [Landing](../../AGENTS.md#landing) section in
`AGENTS.md` names it, so the pull requests `/ship-plan` opens and the descriptions `/run-issues` refreshes take the
conventional-commit title and the **Why**, **Changes**, **Verified** body above, ending with
`Closes <issue reference>` on a line of its own when the plan has an `Issue:` line. Its
`follow-ups: NCodeGroup/identity` makes `/ship-plan` file a plan's follow-ups as issues in the library repository, not
here, because that is where pending work lives, as described under [Where knowledge lives](#where-knowledge-lives).

When the user authorizes opening or updating a pull request, first:

1. **Retire the plan.** If a `PLAN.md` exists, every step is `[x]` and a clean review (`/review-plan-diff`) has
   recorded its `Reviewed:` line, with every queued fix step done. Promote its Decisions in gate 2. `PLAN.md` is
   untracked and never reaches `main`: `/ship-plan` keeps it until `/finish-plan` deletes it after the merge, and a
   push made without `/ship-plan` deletes it first. The squash merge folds its `Plan step N` / `Re-plan step N`
   checkpoint commits
   ([ADR-1170](https://github.com/NCodeGroup/identity/blob/main/docs/decisions/1170-agent-work-is-planned-on-claude-opus-and-executed-step-by-step-on-claude-sonnet.md)).
2. **Persist lessons.** Promote every lesson learned into durable content, as described under
   [Where knowledge lives](#where-knowledge-lives).
3. **Drain volatile memory.** No durable knowledge may remain only in agent memory or chat history.
4. **Pass the local checks** in [`AGENTS.md`](../../AGENTS.md#local-checks) — the same checks the `validate` workflow runs.
