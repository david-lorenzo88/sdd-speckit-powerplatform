# SpecKit extension: Azure Boards Sync (`ado`)

This extension tracks SpecKit implementation progress in Azure Boards (Agile process). The sync is one-way: the repository is the source of truth, and Azure Boards is a view of it that the team and the customer can follow.

## Mapping

| SpecKit | Azure Boards (Agile) | Details |
|---|---|---|
| Feature folder `specs/NNN-name/` | **Feature** | Title `NNN · <spec title>`. The description links to `spec.md`. |
| User story in `spec.md` (US1, US2…) | **User Story** | Priority P1–P4 maps to Priority 1–4. Acceptance scenarios go to Acceptance Criteria. |
| Setup / Foundational / Polish phases in `tasks.md` | **User Story** tagged `technical` | Created only when the phase has tasks. |
| Task in `tasks.md` (T001…) | **Task** | Title `T001 · <description>`. `[P]` tasks get the tag `parallel`. |

Every item is tagged `speckit` and `spec-NNN`, and gets the configured area and iteration. Parent links follow the hierarchy Feature > User Story > Task.

## State rules

- **Task**
  - A checked task (`[x]`) moves to **Closed**.
  - A task that is unchecked again moves back to **Active**.
- **User Story**
  - Moves to **Active** when some of its tasks are done.
  - Moves to **Resolved** when all of them are done.
  - Goes back to **Active** if new tasks appear, for example after `/speckit-converge`.
  - Closing it after acceptance is left to a person.
- **Feature**
  - Moves to **Active** when work starts.
  - Moves to **Resolved** when all its stories are resolved or closed.
- **Removed items**
  - A task or phase that disappears from `tasks.md` moves to **Removed**.
- **Transitions**
  - If the process rejects a direct transition (for example New → Resolved), the script goes through Active first.

The sync only writes title, state and, on creation, description, priority, acceptance criteria, tags, area and iteration. Assignment, iteration changes, effort and comments made in Azure Boards are never overwritten.

## Install

```powershell
specify extension add --dev C:\path\to\spec-kit-ado
specify extension list
```

In GitHub Copilot and Claude Code, the commands are expected to appear as `/speckit-ado-setup` and `/speckit-ado-sync`. Other agents may show the dotted form, `/speckit.ado.setup`.

## Configure

Run `/speckit-ado-setup`. It does three things:
- asks for the organization, project, area, iteration and repository URL;
- writes `.specify/extensions/ado/ado-config.yml`;
- checks the connection and the process template.

To configure it by hand instead, copy `ado-config.template.yml` to that path.

Authentication, in this order:
1. `SYSTEM_ACCESSTOKEN` (pipelines);
2. `AZURE_DEVOPS_EXT_PAT`;
3. the current `az login` session.

No token is ever written to a file.

## Use

| When | What happens |
|---|---|
| After `/speckit-tasks` | The hook offers to run `/speckit-ado-sync`, which creates the Feature, User Stories and Tasks. |
| After `/speckit-implement` | The sync runs automatically and updates states from the checkboxes. |
| After `/speckit-converge` + implement | New tasks are created and removed ones are marked Removed. |
| Any time | `/speckit-ado-sync`, or a preview with `/speckit-ado-sync dry run`. |

Commit `specs/NNN-name/ado.json` with the feature: it stores the work item IDs and makes the sync idempotent.

Running the script directly:

```powershell
pwsh -File .specify/extensions/ado/scripts/powershell/ado-sync.ps1 -FeatureDir specs/001-my-feature -DryRun
pwsh -File .specify/extensions/ado/scripts/powershell/ado-sync.ps1 -Validate
```

It works with Windows PowerShell 5.1 and PowerShell 7+, and calls the Azure DevOps REST API (7.1) directly. The `azure-devops` CLI extension is not needed.

## Pipeline (optional)

`pipelines/azure-pipelines-ado-sync.yml` runs the sync on every push that changes a `spec.md` or `tasks.md`. It commits new IDs in `ado.json` back with `[skip ci]`. This keeps the board up to date even when someone forgets to sync.

The project build service needs two permissions:
- edit work items in the area path;
- **Contribute** on the repository, to push `ado.json`.

## Limitations

- Agile process only (Feature, User Story, Task). Scrum would need PBI instead of User Story.
- Moving a task to another story in `tasks.md` does not move its work item.
- Parsing follows the SpecKit templates. It accepts the English headings (`User Story`, `Phase`, `Acceptance Scenarios`) and their Spanish equivalents (`Historia de usuario`, `Fase`, `Escenarios de aceptación`).

## Tests

`tests/mock_ado.py` is a small mock of the work item API. To run it:
1. Point `organization` at `http://127.0.0.1:8765/<org>`.
2. Set `AZURE_DEVOPS_EXT_PAT=dummy`.
3. Run the script against the fixtures in `tests/fixtures/`.
