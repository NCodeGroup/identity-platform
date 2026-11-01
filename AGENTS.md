# Agent guide — identity-platform

Infrastructure as code for the hosted [NCode.Identity](https://github.com/NCodeGroup/Identity) platform at
`nidentity.io`: reusable OpenTofu components and the live configuration of the platform's own environments. The
repository is public on purpose and never holds credentials, state, plans, or backups. The [README](README.md) is the
full description — layout, components, live roots, environments, conventions, and local setup.

## Instructions

Read each file listed here. Claude Code imports each `@` file through [`CLAUDE.md`](CLAUDE.md); GitHub Copilot loads
every `.github/instructions/*.instructions.md` file on its own. Where this repository's files and the template's differ,
this repository's win.

- @.github/instructions/project-template.instructions.md — the plan-then-execute workflow and base conventions, from
  the [project template](https://github.com/NCodeGroup/project-template). Template updates replace it; never edit it.
- @.github/instructions/identity-platform.instructions.md — posture, security defaults, the no-live-infrastructure
  rule, where knowledge lives, commit attribution, and the pull-request protocol.
- `.github/instructions/opentofu.instructions.md` — OpenTofu conventions; read it before editing `*.tf` or
  `*.tftest.hcl` files.
- `docs/decisions/project-template/` — the project template's decision records; read the ones a change touches.
  The overrides under [Rules and conventions](#rules-and-conventions) take precedence.

## Layout

| Path                    | Holds                                                                                           |
| ----------------------- | ----------------------------------------------------------------------------------------------- |
| `modules/<component>/`  | One concern each, no platform-specific defaults, tested with mocked providers                   |
| `live/<root>/`          | Roots for the platform's environments; `bootstrap` is applied by hand, `global` by CI           |
| `.github/workflows/`    | `validate` (required), `deploy` (plan; apply on merge), `ci`, `code-review`, `template-update`  |
| `.github/instructions/` | Scoped coding conventions, auto-applied by path                                                 |
| `.claude/`              | Claude Code commands, `plan-executor` agent, and settings; template-owned except settings       |
| `.template/`            | Project-template scripts such as `Update-Project.ps1` and `Get-PlanState.ps1`; template-owned   |
| `docs/`                 | `decisions/project-template/`: the project template's decision records; template-owned          |

## Rules and conventions

- Decisions and pending work live in the library repository — its
  [`docs/decisions/`](https://github.com/NCodeGroup/Identity/tree/main/docs/decisions) and
  [issues](https://github.com/NCodeGroup/Identity/issues).
- This repository overrides three of the project template's decisions in `docs/decisions/project-template/`:
  - ADR-0005: `main` takes only squash merges, with linear history, not merge commits or rebases, so each pull
    request's title and body become its one commit on `main`; the `Commit attribution` check on the pull request
    keeps agent trailers out
    ([Pull requests](.github/instructions/identity-platform.instructions.md#pull-requests)).
  - ADR-0007: pending work is an issue in the library repository, not here, and `/ship-plan` files a plan's
    follow-ups there.
  - ADR-0010: a change consumers can observe starts as a library issue, and its decision is recorded as a library ADR
    before or with the pull request, not in `docs/decisions/`; `/analyze-decision`, which writes a record there, isn't
    used here.

  [Where knowledge lives](.github/instructions/identity-platform.instructions.md#where-knowledge-lives) states the
  rule.

## Local checks

Install the tools once as described in the README's [Working locally](README.md#working-locally) section (`tenv`,
`terraform-docs`, `gitleaks`, `pre-commit`). The [`validate`](.github/workflows/validate.yml) workflow runs these on
every pull request; run the same before opening one:

```powershell
pwsh -NoProfile -File .\build\tests\agent-customizations.tests.ps1
bash build/tests/tofu-strict.tests.sh

tofu fmt -check -recursive

# Each component under modules/, and each root under live/ (add -lockfile=readonly to a live root's init).
bash build/tofu-strict.sh -chdir=modules/<name> init -backend=false
bash build/tofu-strict.sh -chdir=modules/<name> validate
bash build/tofu-strict.sh -chdir=modules/<name> test

# The generated README sections are current.
terraform-docs --config .terraform-docs.yml --recursive --recursive-path modules --recursive-include-main=false --output-check .
terraform-docs --config .terraform-docs.yml --recursive --recursive-path live --recursive-include-main=false --output-check .
```

A warning fails `validate` like an error. OpenTofu exits 0 on a warning, so `init`, `validate` and `test` run through
[`build/tofu-strict.sh`](build/tofu-strict.sh), which exits 1 when tofu prints one; a plain `tofu validate` can pass
locally where `validate` fails. On Windows, `bash` must be Git Bash: when it starts WSL instead, call Git's
`bin\bash.exe` by its full path.

`validate` also rejects a `source` under `live/` that is not a registry module or a released component
(`git::https://github.com/NCodeGroup/identity-platform.git//modules/<name>?ref=vX.Y.Z`). After changing variables or
outputs, regenerate the docs (the same `terraform-docs` commands without `--output-check`); after changing a live root's
providers, record lock-file checksums with the `tofu providers lock` command in the README.

## Landing

How `/ship-plan` lands a reviewed plan. `integrate`: `pull-request` pushes the plan's branch and opens a pull request;
`direct` pushes to the default branch. `release`: `none`; `tag` tags the plan's `Release:` version, or the next free
one when another plan landed it first; `tag+release` also publishes a release from that version's section of
`changelog`. `changelog`: the file every plan's last step writes, in the Keep a Changelog format, `CHANGELOG.md` by
default. `draft`: `no`; `yes` opens every pull request as a draft, as `/ship-plan draft` does. `follow-ups`: `issues`
files a plan's follow-ups as issues in this repository; `<owner/repo>` files them in that repository; `none` files
none, and `/ship-plan` lists them for you to record. `follow-up-label`: the label those issues get, `follow-up` by
default; write a name with spaces as it is, such as `tech debt`. `gate`: `none`; a command, such as
`./build/dod.ps1 -Fast`, that `/ship-plan` and `/run-issues` run from the repository root before each push, stopping
when it exits non-zero or changes a file. `protect`: `none`; `hook` makes `.githooks/pre-push` refuse any push to the
default branch, for a host that can't require pull requests, such as a private repository on GitHub Free.
`pr-format`: `none`; `<file>#<heading>`, such as `AGENTS.md#Pull requests`, names the section that sets the title and
description of the pull requests `/ship-plan` opens, which still end with their `Closes` lines. `review-bots`: the
review bots, by login and separated by commas, whose findings `/run-issues` and `/address-feedback` may fix,
`ncode-review` by default, or `none`; `/run-issues` acts only on NCode Review's `blocker` and `should-fix` findings,
and neither ever fixes a bot's finding on CI, the template, agent configuration, the build or the dependencies.
`max-review-rounds`: `3`; after that many rounds of review feedback on a pull request, `/run-issues` recommends the
merge and leaves the bots' further findings as follow-ups. `prelude`: `none`; one PowerShell command that sets up the
shell the workflow's commands run in, such as `./build/env.ps1`, a script in the repository, or `nvs use 26`, to put
a tool installed through a version manager on `PATH`. `/ship-plan` and `/run-issues` run it before the gate, and
executors and coordinators before each Done-when command, dot-sourced in the same PowerShell; a plan names it under
Context for the executor, so no step repeats it. When it fails, they stop and show its error. Write it on one line,
without a leading `. ` or `& ` operator, a `#` comment, or `;`, `|`, `&`, `&&` or `||`; `.template/Get-PlanState.ps1`
prints any other value as `prelude=invalid`, and `/ship-plan` stops on it. `/run-issues` runs only when the host
requires pull requests into the default branch, or `protect` is `hook` and the hooks are enabled.

In this repository, `main`'s ruleset requires pull requests, so `protect` stays `none`. `release` stays `none`: a
release tags components, by hand and only when the user asks, after a pull request moves the entries under
`## [Unreleased]` in [`CHANGELOG.md`](CHANGELOG.md) into the new version's section ([Releasing](README.md#releasing)).
Changelog entries are written for whoever consumes the components and roots: each starts with the component, root or
area (`ci`, `agents`, `docs`) in backticks, and a breaking one with `**Breaking:**`. `pr-format` names the
[pull-request protocol](.github/instructions/identity-platform.instructions.md#pull-requests), which sets each pull
request's title and description. `follow-ups` names `NCodeGroup/Identity`, because pending work is an issue in the
library repository, not here. `gate` stays `none`: the `validate` workflow runs the [local checks](#local-checks) on
every pull request.
`review-bots` names `ncode-review`, the bot [`code-review`](.github/workflows/code-review.yml) runs, and `prelude`
stays `none`: the tools are on `PATH` once [Working locally](README.md#working-locally) installs them.

- integrate: pull-request
- release: none
- changelog: CHANGELOG.md
- draft: no
- follow-ups: NCodeGroup/Identity
- follow-up-label: follow-up
- gate: none
- protect: none
- pr-format: .github/instructions/identity-platform.instructions.md#Pull requests
- review-bots: ncode-review
- max-review-rounds: 3
- prelude: none

## Plan-and-execute workflow

Multi-step changes run as **plan-and-execute**
([ADR-0170](https://github.com/NCodeGroup/Identity/blob/main/docs/decisions/0170-agent-work-is-planned-on-a-frontier-model-and-executed-step-by-step-on-a-cheaper-one.md)):
Claude Opus plans into a root `PLAN.md`, Claude Sonnet 5.5 executes it one verified step at a time, and
any step that needs a decision comes back to Opus to be re-planned.

- **VS Code** (session target Local): pick the **Copilot Planner** agent **and Claude Opus 5.5 in the model picker** —
  in a Local session, choosing an agent from the picker keeps the selected model (an agent file's `model` applies to it
  only as a subagent, and each handoff button selects its own). Review `PLAN.md`, then either **Run all steps with
  subagents** (the Copilot Orchestrator on Opus delegates each step to a Copilot Implementer subagent (Sonnet), runs the
  step's check, and re-plans escalations itself — its agent file grants the subagent tool, so nothing needs enabling)
  or step through with **Execute next step** and **Re-plan with the planner**. Finish with **Review the work** (Sonnet)
  and execute the fix steps it queues. The planning prompts — `/plan-feature`, `/plan-bugfix`, `/plan-refactor`,
  `/plan-tests`, `/plan-migration`, `/plan-performance`, `/plan-security`, `/plan-docs`, `/plan-issue`,
  `/plan-template-update`, and `/handoff-plan` after planning in conversation — select Opus themselves but run in the
  built-in Agent, which has no handoff buttons: continue by picking **Copilot Orchestrator** with Opus and asking it to
  execute `PLAN.md`. Land the reviewed plan with `/ship-plan`, and run `/finish-plan` after the merge.
- **Copilot CLI:** start on Opus — `copilot --model claude-opus-5.5 --reasoning-effort high` — then `/plan-feature …`,
  `/orchestrate-plan` (delegates each step to the `plan-executor` agent on Sonnet), `/review-plan-diff`, `/ship-plan`
  to open the pull request, and `/finish-plan` after the merge. `/run-issues` runs here too, and in a Local session
  in Copilot Chat: without approval prompts (`/allow-all`; Bypass Approvals or Autopilot), it works in the open
  folder, one `issue-<number>` branch at a time.
- **VS Code (session target Copilot):** use the same skills as Copilot CLI. Select **Claude Opus 5.5** before planning
  or orchestration and **Claude Sonnet 5.5** before review. Skills use the session's selected model; they cannot switch
  it using the corresponding Local prompt's metadata. Execution uses the delegated executor, or the model selected
  before invoking `/execute-step` directly. If the Sonnet executor is unavailable in the session, select an available
  lower-cost model, execute one step, then return to the planner for verification or re-planning. Do not hand-edit
  generated agents to work around session-specific model availability.
- **Claude Code:** a planning command (`/plan-feature …`, `/plan-migration …`) plans in a worktree under
  `.claude/worktrees/<name>/`; `/orchestrate-plan` runs each step on the `plan-executor` subagent (Sonnet 5.5),
  `/review-plan-diff` reviews, `/ship-plan` opens the pull request as [Landing](#landing) says, and `/finish-plan`
  cleans up after the merge; `/continue-plan` shows where each open plan stands and what to run next. `/run-issues`
  takes issues from planning to a draft pull request, one at a time, each in its own worktree, and lands each once
  you merge it. See [`CLAUDE.md`](CLAUDE.md).
- **Issues and template updates:** `/plan-issue #42` plans one issue, choosing the kind of plan from its labels;
  `/triage-issues <filter>` lists the open issues ready to plan and changes nothing; `/plan-template-update` plans the
  next project-template update from a trial run on a clone. The commands exist in all three runtimes.
- **Review feedback and conventions:** `/address-feedback <pull request>` answers every open review thread and
  comment on one pull request and pushes the fixes it judges sound (Claude Code only); `/audit-conventions` sweeps
  the codebase, or the part a request names, against `AGENTS.md`, its instruction files and the decision records,
  and ranks what doesn't follow them without changing a file (all three runtimes). The weekly `template-update`
  workflow opens a `template-update` issue when a newer project-template version is out; `/plan-issue` plans it.
- **Work on a branch.** The orchestrator commits a checkpoint per step; the squash merge folds them, and the pull
  request title and body supply the commit on `main`.
- **Done-when commands** prove one step with a local check — for example `tofu -chdir=modules/<name> test` after a
  one-time `init -backend=false`, `tofu fmt -check -recursive`, or a `terraform-docs … --output-check .` — never
  `tofu plan` or anything else that reaches live state. A `run` block that asserts the new behavior makes the best
  check: it fails until the step is done.
- **Split across releases.** A change to a component and its adoption by a live root are separate plans and pull
  requests, with a release tag between them ([Releasing](README.md#releasing)).
- **`PLAN.md` is transient:** it stays untracked in the plan's worktree; the pull-request protocol in
  [`identity-platform.instructions.md`](.github/instructions/identity-platform.instructions.md) promotes its Decisions
  before the pull request opens, and `/finish-plan` deletes it after the merge.
- The agents, prompts, skills and Claude Code commands under `.github/` and `.claude/` come from the
  [project template](https://github.com/NCodeGroup/project-template) and are **template-owned**: never hand-edit them;
  `.\.template\Update-Project.ps1` updates them to the template's newest release. Repository rules belong in the
  instruction files, which every agent in the loop already loads.

### Local and Copilot customizations

**Both session targets are intentionally supported.** The 24 workflow pairs under
[`.github/prompts/`](.github/prompts/) and [`.github/skills/`](.github/skills/) are runtime adapters, not unfinished
migration work. Local prompts retain their agent/model/tool selections; Copilot skills use the session model.
Duplicate commands in Local's slash menu and automatic skill selection are accepted behaviors. Skill descriptions
and workflow instructions guide appropriate use; they do not enforce permissions.

The [customization validator](build/agent-customizations.ps1) checks counterpart names, descriptions and ordered bodies,
allowing only argument syntax, relative Markdown-link depth, line endings and outer whitespace differences. It rejects
prompt-only settings and invocation-control flags in skills. The
[fixture tests](build/tests/agent-customizations.tests.ps1) cover the real pairs and success/failure fixtures, and run
first in `validate`, before infrastructure setup. These scripts mirror the library's tooling; keep them synchronized
when changing the shared validation contract. Run the tests after each template update.

**Do not bulk-migrate these prompts.** Copilot's migration banner identifies prompt files it does not read, but the
matching skills already exist. Use **Ignore** for the workspace **Convert Prompt to Skills** group;
**Show Ignored Migrations** restores it. Generic conversion drops agent/model/tool selection and adds
`disable-model-invocation: true`, which is outside the supported skill configuration. User-profile migration entries
are separate and must be reviewed individually. The rationale and completed decision are in the library's
[ADR-0170](https://github.com/NCodeGroup/Identity/blob/main/docs/decisions/0170-agent-work-is-planned-on-a-frontier-model-and-executed-step-by-step-on-a-cheaper-one.md#dual-runtime-customization-contract);
no upstream fix is required to support either runtime.
