# Agent guide — identity-platform

Infrastructure as code for the hosted [NCode.Identity](https://github.com/NCodeGroup/Identity) platform at
`nidentity.io`: reusable OpenTofu components and the live configuration of the platform's own environments. The
repository is public on purpose and never holds credentials, state, plans, or backups. The [README](README.md) is the
full description — layout, components, live roots, environments, conventions, and local setup.

## Layout

| Path                    | Holds                                                                                           |
| ----------------------- | ----------------------------------------------------------------------------------------------- |
| `modules/<component>/`  | One concern each, no platform-specific defaults, tested with mocked providers                   |
| `live/<root>/`          | Roots for the platform's environments; `bootstrap` is applied by hand, `global` by CI           |
| `.github/workflows/`    | `validate` (required on every pull request), `deploy` (plan on pull request, apply after merge) |
| `.github/instructions/` | Scoped coding conventions, auto-applied by path                                                 |

## Rules and conventions

- Posture, security defaults, the no-live-infrastructure rule, commit attribution, and the pull-request protocol:
  [`.github/copilot-instructions.md`](.github/copilot-instructions.md).
- OpenTofu conventions: [`.github/instructions/opentofu.instructions.md`](.github/instructions/opentofu.instructions.md).
- Decisions and pending work live in the library repository — its
  [`docs/adr/`](https://github.com/NCodeGroup/Identity/tree/main/docs/adr) and
  [`BACKLOG.md`](https://github.com/NCodeGroup/Identity/blob/main/BACKLOG.md).

## Local checks

Install the tools once as described in the README's [Working locally](README.md#working-locally) section (`tenv`,
`terraform-docs`, `gitleaks`, `pre-commit`). The [`validate`](.github/workflows/validate.yml) workflow runs these on
every pull request; run the same before opening one:

```powershell
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

## Plan-and-execute workflow

Multi-step changes run as **plan-and-execute**
([ADR-0170](https://github.com/NCodeGroup/Identity/blob/main/docs/adr/0170-agent-work-is-planned-on-a-frontier-model-and-executed-step-by-step-on-a-cheaper-one.md)):
Claude Opus plans into a root `PLAN.md`, a lower-cost Copilot model (Auto) executes it one verified step at a time, and
any step that needs a decision comes back to Opus to be re-planned.

- **VS Code** (session target Local): pick the **Copilot Planner** agent, or run a planning prompt — `/plan-feature`,
  `/plan-bugfix`, `/plan-refactor`, `/plan-tests`, `/plan-migration`, `/plan-performance`, `/plan-security`,
  `/plan-docs`, or `/handoff-plan` after planning in conversation. Review `PLAN.md`, then either **Run all steps with
  subagents** (the Copilot Orchestrator on Opus delegates each step to a Copilot Implementer subagent on Auto, runs the
  step's check, and re-plans escalations itself — enable the Run Subagent tool) or step through with **Execute next
  step** and **Re-plan with the planner**. Finish with **Review the work** (Sonnet) and execute the fix steps it queues.
- **Copilot CLI:** start on Opus — `copilot --model claude-opus-5.5 --reasoning-effort high` — then `/plan-feature …`,
  `/orchestrate-plan` (delegates each step to the `plan-executor` agent on `auto`), and `/review-plan-diff`.
- **Work on a branch.** The orchestrator commits a checkpoint per step; the squash merge folds them, and the pull
  request title and body supply the commit on `main`.
- **Done-when commands** prove one step with a local check — for example `tofu -chdir=modules/<name> test` after a
  one-time `init -backend=false`, `tofu fmt -check -recursive`, or a `terraform-docs … --output-check .` — never
  `tofu plan` or anything else that reaches live state. A `run` block that asserts the new behavior makes the best
  check: it fails until the step is done.
- **Split across releases.** A change to a component and its adoption by a live root are separate plans and pull
  requests, with a release tag between them ([Releasing](README.md#releasing)).
- **`PLAN.md` is transient:** the pull-request protocol in [`copilot-instructions.md`](.github/copilot-instructions.md)
  promotes its Decisions and deletes it before the pull request merges.
- The agents, prompts, and skills under `.github/` are **generated** (the installer command is in ADR-0170); change the
  templates and re-install rather than hand-editing them. Repository rules belong in the instruction files, which every
  agent in the loop already loads.
