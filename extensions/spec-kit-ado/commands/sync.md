---
description: "Create or update the Azure Boards work items (Feature > User Story > Task) of the current feature and sync their states from tasks.md."
---

# Azure Boards sync

## User Input

$ARGUMENTS

You MUST consider the user input before proceeding (if not empty). It may name a feature folder (for example `specs/001-my-feature`) or ask for a preview ("dry run", "preview", "simula").

## What this command does

One-way sync from the repository to Azure Boards (Agile process). The repository is the source of truth:

| SpecKit | Azure Boards |
|---|---|
| Feature folder `specs/NNN-name/` | Feature |
| User story in `spec.md` (US1, US2…) | User Story (priority, acceptance criteria) |
| Setup / Foundational / Polish phases | User Story tagged `technical` |
| Task in `tasks.md` (T001…) | Task (tag `parallel` for `[P]`) |

States: a checked task (`[x]`) closes its Task; a User Story is resolved when all its tasks are done; the Feature is resolved when all its stories are. Work item IDs are stored in `specs/NNN-name/ado.json`.

## Steps

1. Check the configuration. If `.specify/extensions/ado/ado-config.yml` does not exist (or has no `organization`/`project`) and the environment variables `SPECKIT_ADO_ORGANIZATION` and `SPECKIT_ADO_PROJECT` are not set, stop and tell the user to run the setup command of this extension first (`/speckit-ado-setup`, or `/speckit.ado.setup` depending on the agent).
2. Locate the script at `.specify/extensions/ado/scripts/powershell/ado-sync.ps1`. If it is not there, search for `ado-sync.ps1` under `.specify/`.
3. Run it from the repository root. Use `pwsh` when available, otherwise Windows PowerShell:
   - `pwsh -NoProfile -File <script> [-FeatureDir specs/NNN-name] [-DryRun]`
   - `powershell -NoProfile -ExecutionPolicy Bypass -File <script> [-FeatureDir specs/NNN-name] [-DryRun]`
   Pass `-FeatureDir` only if the user named a feature. Pass `-DryRun` only if the user asked for a preview.
4. Report the result briefly: work items created, titles updated, state changes, removed items, progress (done/total tasks) and the Feature link printed by the script.
5. If `ado.json` changed, remind the user to commit it together with the feature.
6. Do not edit `spec.md`, `tasks.md` or `ado.json` yourself, and do not change work items by any other means.

## Errors

- `No Azure DevOps credentials`: ask the user to run `az login` with an account that has access to the Azure DevOps organization.
- HTTP 401/403: the account lacks access to the project or permission to edit work items in the configured area path.
- HTTP 400 on create: usually a wrong `areaPath`/`iterationPath`, or a project that does not use the Agile process (check with `-Validate`).
