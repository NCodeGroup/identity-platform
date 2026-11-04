# Contributing to identity-platform

Issues and pull requests are welcome. [README.md](README.md) explains the project, and [AGENTS.md](AGENTS.md) holds
the rules every change follows, for people and coding agents alike. Report a vulnerability privately instead, as
[SECURITY.md](SECURITY.md) says.

## Prerequisites

- Git, and PowerShell 7 (`pwsh`): every command here runs from the repository root in PowerShell 7.
- OpenTofu (through `tenv`), `terraform-docs`, `gitleaks` and `pre-commit`, installed as the README's
  [Working locally](README.md#working-locally) section says.
- On Windows, `git config --global core.longpaths true`, once: a Claude Code plan's worktree under
  `.claude/worktrees/` can pass Windows' 260-character path limit.

## Set Up

Once in each clone, run `tenv tofu install` and `pre-commit install`. The hooks run gitleaks, `tofu fmt` and
terraform-docs on every commit, and `.githooks/commit-msg` strips AI attribution from commit messages. Leave
`core.hooksPath` unset: pre-commit refuses to install while it is set.

## Build and Test

There is no build. Before you push, run the [local checks](AGENTS.md#local-checks) in `AGENTS.md`: the
agent-customization tests, `tofu fmt -check -recursive`, `init -backend=false`, `validate` and `test` for each
component and root you changed, and the `terraform-docs --output-check` commands. The `validate` workflow runs the same
checks on every pull request, and `main` requires it to pass.

Never run `tofu plan`, `apply` or anything else that reaches live state: CI plans every pull request and applies after
merge, and [`live/bootstrap`](live/bootstrap) is applied by the owner.

## Make a Change

1. Pending work and decisions live in the library repository: its
   [issues](https://github.com/NCodeGroup/Identity/issues) and
   [`docs/decisions/`](https://github.com/NCodeGroup/Identity/tree/main/docs/decisions). A change consumers can
   observe, such as a component's inputs or outputs, a forced replacement or a live root's resources, starts as an
   issue there, and its decision is recorded as an ADR there before or with the pull request that builds it. Report a
   bug or ask a question there too.
2. Work on a short-lived branch from `main`.
3. Add an entry for each change consumers can see to [CHANGELOG.md](CHANGELOG.md), under `## [Unreleased]`, in the
   [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/) format: each starts with the component, root or area
   in backticks, and a breaking one with `**Breaking:**`. A release moves the entries into its version's section, as
   the README's [Releasing](README.md#releasing) section says.
4. Open a pull request into `main`, titled and described as the
   [pull-request protocol](.github/instructions/identity-platform.instructions.md#pull-requests) says: a conventional
   commit title, then **Why**, **Changes**, **Verified** and, for a change under `live/`, the expected deploy plan.
   `main` takes changes only through squash-merged pull requests: a maintainer merges yours once `validate` passes.

## Commit Attribution

Commits record the people who wrote them. Never add a `Co-authored-by:` trailer naming an AI agent (Copilot, Claude or
any other), a `Claude-Session:` trailer or a "Generated with" line; say which tools helped in the pull request
instead. The `commit-msg` hook strips them, and the `Commit attribution` check fails a pull request with a commit
authored, committed or co-authored by an AI agent. To fix one, run the command the check prints, then `git push --force-with-lease`:
`git rebase <base> --exec "git commit --amend --no-edit --reset-author"` re-authors a commit by an AI agent account, and
`git rebase <base> --exec "git -c core.hooksPath=.githooks commit --amend --no-edit"` runs the `commit-msg` hook on each
commit message, which strips the attribution lines `--no-edit` alone keeps. The check also reads the pull request's
title and description, which a squash merge can copy into the default branch: when it finds such a line there, edit the
pull request.
[The decision](docs/decisions/project-template/0002-commits-are-attributed-to-people-not-agents.md) says why.

## Conventions

[AGENTS.md](AGENTS.md) is the index of the conventions: the instruction files it lists, the OpenTofu conventions, and
the project template's decisions in [docs/decisions/](docs/decisions/README.md). Read the ones your change touches. It
also says which files the project template owns: template updates replace them, so never edit them.

## AI-Assisted Work

Most changes here are planned and executed with coding agents: a frontier model plans each change into `PLAN.md`, and
a cheaper one executes it one verified step at a time. [README.md](README.md#working-with-agents) and
[AGENTS.md](AGENTS.md#plan-and-execute-workflow) list the commands. The agents follow the rules above, and so does a
change written by hand.

## Maintainers and Scope

The repository's owners maintain identity-platform: they review pull requests, merge them and tag releases.
identity-platform covers what [README.md](README.md) describes; a change outside that starts as an issue in the
library repository.
