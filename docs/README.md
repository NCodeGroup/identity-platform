# Documentation

The documents that describe identity-platform. Every document in `docs/` has a line here.

## What Lives Where

- [decisions/](decisions/README.md): the project template's decision records, in
  [decisions/project-template/](decisions/project-template/README.md). The platform's own decisions are ADRs in the
  library repository's [`docs/adr/`](https://github.com/NCodeGroup/Identity/tree/main/docs/adr).
- Each component and live root documents itself in its `README.md`, under `modules/` and `live/`; the
  [README](../README.md) describes the layout, the conventions and how releases work.
- The platform's designs and runbooks, such as the
  [platform bootstrap runbook](https://github.com/NCodeGroup/Identity/blob/main/docs/platform-bootstrap.md), live in
  the library repository's `docs/`.

## Rules

- A document changes in the same pull request as the code it describes. A pull request that changes a documented
  behavior, contract or procedure and leaves its document unchanged is incomplete.
- A document claims only what is built. Planned work is named with the library backlog item that tracks it, never
  described as if it existed.
- A document links to a decision record rather than restating its reasoning, so the reasoning has one home.
- A new document gets a line in this index, in the same change.
