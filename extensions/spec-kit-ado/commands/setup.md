---
description: "Configure the Azure Boards sync (organization, project, area, iteration, repository URL) and test the connection."
---

# Azure Boards sync setup

## User Input

$ARGUMENTS

You MUST consider the user input before proceeding (if not empty). It may already contain some of the values below.

## Steps

1. Read the template `.specify/extensions/ado/ado-config.template.yml` (search for `ado-config.template.yml` under `.specify/` if it is not there). If `.specify/extensions/ado/ado-config.yml` already exists, read its current values and treat them as defaults.
2. Ask the user only for the values that are missing, in one message:
   - `organization` (required): name or URL, for example `contoso` or `https://dev.azure.com/contoso`.
   - `project` (required): an Azure DevOps project that uses the **Agile** process.
   - `areaPath` (optional) and `iterationPath` (optional).
   - `repoUrl` (optional): propose the value of `git remote get-url origin` if it exists, without credentials embedded in the URL.
3. Write `.specify/extensions/ado/ado-config.yml` from the template with those values. Keep the comments. Never write tokens, passwords or PATs into the file.
4. Check the Azure CLI session with `az account show`. If it fails, ask the user to run `az login` and wait.
5. Run the script `.specify/extensions/ado/scripts/powershell/ado-sync.ps1 -Validate` (with `pwsh -NoProfile -File`, or `powershell -NoProfile -ExecutionPolicy Bypass -File` on Windows PowerShell). Report the project and process template it prints. If the process is not Agile, warn the user that the mapping uses Feature, User Story and Task.
6. Suggest adding `.specify/extensions/ado/ado-config.local.yml` to `.gitignore` for personal overrides, and committing `ado-config.yml`.
7. Tell the user the next step: run the sync command of this extension (`/speckit-ado-sync`) after `/speckit-tasks`. It also runs automatically after `/speckit-implement`.
