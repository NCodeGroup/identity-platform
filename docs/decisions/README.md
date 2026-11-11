# Architecture Decision Records

This repository records no decisions of its own. The platform's decisions are architecture decision records in the
library repository's [`docs/decisions/`](https://github.com/NCodeGroup/identity/tree/main/docs/decisions), and a new one is added
there as its own change, as
[Where knowledge lives](../../.github/instructions/identity-platform.instructions.md#where-knowledge-lives) says.

## The Template's Decisions

The project template's own decisions are in [project-template/](project-template/README.md). Template updates replace
that folder, so never edit a file in it. Where this repository decides otherwise, `AGENTS.md` lists the override under
[Rules and conventions](../../AGENTS.md#rules-and-conventions).

## Index

`.template/Test-AdrIndex.ps1`, which the `ci` workflow runs, fails on a record file in this folder that has no row
here. The index stays empty: the platform's records belong in the library repository.

| ADR | Decision | Status |
| --- | --- | --- |
