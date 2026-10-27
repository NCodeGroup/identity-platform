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
  the [project template](https://github.com/polewskm/project-template). Template updates replace it; never edit it.
- @.github/instructions/identity-platform.instructions.md — posture, security defaults, the no-live-infrastructure
  rule, where knowledge lives, commit attribution, and the pull-request protocol.
- `.github/instructions/opentofu.instructions.md` — OpenTofu conventions; read it before editing `*.tf` or
  `*.tftest.hcl` files.

## Layout

| Path                    | Holds                                                                                           |
| ----------------------- | ----------------------------------------------------------------------------------------------- |
| `modules/<component>/`  | One concern each, no platform-specific defaults, tested with mocked providers                   |
| `live/<root>/`          | Roots for the platform's environments; `bootstrap` is applied by hand, `global` by CI           |
| `.github/workflows/`    | `validate` (required), `deploy` (plan on pull request, apply after merge), `ci` (attribution)   |
| `.github/instructions/` | Scoped coding conventions, auto-applied by path                                                 |
| `.claude/`              | Claude Code commands, `plan-executor` agent, and settings; template-owned except settings       |
| `.template/`            | Project-template scripts such as `Update-Project.ps1` and `Get-PlanState.ps1`; template-owned   |

## Rules and conventions

- Decisions and pending work live in the library repository — its
  [`docs/adr/`](https://github.com/NCodeGroup/Identity/tree/main/docs/adr) and
  [`BACKLOG.md`](https://github.com/NCodeGroup/Identity/blob/main/BACKLOG.md).

## Local checks

Install the tools once as described in the README's [Working locally](README.md#working-locally) section (`tenv`,
`terraform-docs`, `gitleaks`, `pre-commit`). The [`validate`](.github/workflows/validate.yml) workflow runs these on
every pull request; run the same before opening one:

```powershell
pwsh -NoProfile -File .\build\tests\agent-customizations.tests.ps1

tofu fmt -check -recursive

# Each component under modules/, and each root under live/ (add -lockfile=readonly to a live root's init).
tofu -chdir=modules/<name> init -backend=false
tofu -chdir=modules/<name> validate
tofu -chdir=modules/<name> test

# The generated README sections are current.
terraform-docs --config .terraform-docs.yml --recursive --recursive-path modules --recursive-include-main=false --output-check .
terraform-docs --config .terraform-docs.yml --recursive --recursive-path live --recursive-include-main=false --output-check .
```

`validate` also rejects a `source` under `live/` that is not a registry module or a released component
(`git::https://github.com/NCodeGroup/identity-platform.git//modules/<name>?ref=vX.Y.Z`). After changing variables or
outputs, regenerate the docs (the same `terraform-docs` commands without `--output-check`); after changing a live root's
providers, record lock-file checksums with the `tofu providers lock` command in the README.

## Landing

How `/ship-plan` lands a reviewed plan. `integrate`: `pull-request` pushes the plan's branch and opens a pull request;
`direct` pushes to the default branch. `release`: `none`; `tag` tags the plan's `Release:` version; `tag+release` also
publishes a release from that version's section of `changelog`. `protect`: `none`; `hook` makes `.githooks/pre-push`
refuse any push to the default branch, for a host that can't require pull requests, such as a private repository on
GitHub Free. `/run-issues` runs only when the host requires pull requests into the default branch, or `protect` is
`hook` and the hooks are enabled.

In this repository, `main`'s ruleset requires pull requests, so `protect` stays `none`. `release` stays `none`: a
release tags components, by hand and only when the user asks ([Releasing](README.md#releasing)), and this repository
keeps no changelog, so `changelog` is unused. The pull request's title, description and follow-ups follow the
[pull-request protocol](.github/instructions/identity-platform.instructions.md#pull-requests).

- integrate: pull-request
- release: none
- changelog: CHANGELOG.md
- protect: none

## Plan-and-execute workflow

Multi-step changes run as **plan-and-execute**
([ADR-0170](https://github.com/NCodeGroup/Identity/blob/main/docs/adr/0170-agent-work-is-planned-on-a-frontier-model-and-executed-step-by-step-on-a-cheaper-one.md)):
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
  to open the pull request, and `/finish-plan` after the merge.
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
  (Claude Code only) takes issues from planning to a draft pull request, one at a time, and lands each once you merge
  it. See [`CLAUDE.md`](CLAUDE.md).
- **Issues and template updates:** `/plan-issue #42` plans one issue, choosing the kind of plan from its labels;
  `/triage-issues <filter>` lists the open issues ready to plan and changes nothing; `/plan-template-update` plans the
  next project-template update from a trial run on a clone. The commands exist in all three runtimes.
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
  [project template](https://github.com/polewskm/project-template) and are **template-owned**: never hand-edit them;
  `.\.template\Update-Project.ps1` updates them to the template's newest release. Repository rules belong in the
  instruction files, which every agent in the loop already loads.

### Local and Copilot customizations

**Both session targets are intentionally supported.** The 22 workflow pairs under
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
[ADR-0170](https://github.com/NCodeGroup/Identity/blob/main/docs/adr/0170-agent-work-is-planned-on-a-frontier-model-and-executed-step-by-step-on-a-cheaper-one.md#dual-runtime-customization-contract);
no upstream fix is required to support either runtime.
