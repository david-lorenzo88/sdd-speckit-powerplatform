<#
.SYNOPSIS
    Instala lo que falte para el taller de Spec Driven Development con SpecKit en Power Platform (Windows).

.DESCRIPTION
    Instala solo lo que no está ya instalado:
      1. Herramientas base con winget (PowerShell 7, Git, Node.js LTS, Python, uv, .NET 10 SDK, Azure CLI, VS Code, GitHub Copilot CLI).
      2. PAC CLI (dotnet tool) y Power Apps CLI (npm).
      3. SpecKit (uv tool).
      4. Extensiones de VS Code.
      5. Plugins de power-platform-skills (Microsoft) para GitHub Copilot.
    El plugin de Copilot Studio y los inicios de sesión se hacen a mano (ver docs/01-prerequisitos.md).

    Usa -WhatIf para ver qué haría sin instalar nada.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\scripts\Install-Prerequisites.ps1 -WhatIf
    powershell -ExecutionPolicy Bypass -File .\scripts\Install-Prerequisites.ps1
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$SkipPlugins
)

$ErrorActionPreference = 'Stop'
$script:Cmdlet = $PSCmdlet

function Update-SessionPath {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    $extra = @("$env:USERPROFILE\.dotnet\tools", "$env:USERPROFILE\.local\bin", "$env:APPDATA\npm")
    $env:Path = (@($machine, $user) + $extra | Where-Object { $_ }) -join ';'
}

function Test-Cmd([string]$name) { return [bool](Get-Command $name -ErrorAction SilentlyContinue) }

function Invoke-Step([string]$description, [scriptblock]$action) {
    if ($script:Cmdlet.ShouldProcess($description)) {
        Write-Host "-> $description" -ForegroundColor Cyan
        & $action
        if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { Write-Host "   Terminó con código $LASTEXITCODE. Revisa el mensaje anterior." -ForegroundColor Yellow }
    }
}

if (-not (Test-Cmd 'winget')) {
    throw 'winget no está disponible. Instala "App Installer" desde Microsoft Store y vuelve a ejecutar el script.'
}

# 1. Herramientas base
$winget = @(
    @{ id = 'Microsoft.PowerShell'; cmd = 'pwsh' },
    @{ id = 'Git.Git'; cmd = 'git' },
    @{ id = 'OpenJS.NodeJS.LTS'; cmd = 'node' },
    @{ id = 'Python.Python.3.12'; cmd = 'python' },
    @{ id = 'astral-sh.uv'; cmd = 'uv' },
    @{ id = 'Microsoft.DotNet.SDK.10'; cmd = $null },
    @{ id = 'Microsoft.AzureCLI'; cmd = 'az' },
    @{ id = 'Microsoft.VisualStudioCode'; cmd = 'code' },
    @{ id = 'GitHub.Copilot'; cmd = 'copilot' }
)
foreach ($p in $winget) {
    $installed = $false
    if ($p.cmd) { $installed = Test-Cmd $p.cmd }
    elseif ($p.id -eq 'Microsoft.DotNet.SDK.10' -and (Test-Cmd 'dotnet')) { $installed = ((& dotnet --list-sdks 2>$null) -join ' ') -match '(^|\s)10\.' }
    if ($installed) { Write-Host "OK  $($p.id) ya está instalado" -ForegroundColor DarkGray; continue }
    Invoke-Step "winget install $($p.id)" { winget install --id $p.id -e --accept-source-agreements --accept-package-agreements }
}
Update-SessionPath

# Node.js 22 o superior
if (Test-Cmd 'node') {
    $nodeMajor = [int](((& node --version) -replace '^v', '') -split '\.')[0]
    if ($nodeMajor -lt 22) {
        Invoke-Step "Actualizar Node.js (versión actual $nodeMajor, mínimo 22)" { winget upgrade --id OpenJS.NodeJS.LTS -e --accept-source-agreements --accept-package-agreements }
        Update-SessionPath
    }
}

# 2. PAC CLI y Power Apps CLI
if (Test-Cmd 'pac') { Invoke-Step 'Actualizar PAC CLI' { dotnet tool update --global Microsoft.PowerApps.CLI.Tool } }
else { Invoke-Step 'Instalar PAC CLI' { dotnet tool install --global Microsoft.PowerApps.CLI.Tool } }
if (-not (Test-Cmd 'pa')) { Invoke-Step 'Instalar Power Apps CLI (pa)' { npm install --global @microsoft/power-apps-cli } }
Update-SessionPath

# 3. SpecKit
if (Test-Cmd 'specify') { Invoke-Step 'Actualizar SpecKit' { uv tool install --force specify-cli } }
else { Invoke-Step 'Instalar SpecKit' { uv tool install specify-cli } }
Update-SessionPath

# 4. Extensiones de VS Code
if (Test-Cmd 'code') {
    foreach ($e in @('GitHub.copilot-chat', 'microsoft-IsvExpTools.powerplatform-vscode', 'ms-CopilotStudio.vscode-copilotstudio')) {
        Invoke-Step "Extensión de VS Code $e" { code --install-extension $e --force }
    }
}

# 5. Plugins de power-platform-skills (incluye Dataverse)
if (-not $SkipPlugins -and (Test-Cmd 'node')) {
    Invoke-Step 'Plugins de power-platform-skills para GitHub Copilot' {
        $tmp = Join-Path $env:TEMP 'pps-install.js'
        Invoke-WebRequest 'https://raw.githubusercontent.com/microsoft/power-platform-skills/main/scripts/install.js' -OutFile $tmp -UseBasicParsing
        node $tmp --include-dataverse
        Remove-Item $tmp -ErrorAction SilentlyContinue
    }
}

Write-Host ''
Write-Host 'Instalación terminada. Abre una terminal NUEVA (PowerShell 7) y sigue con:' -ForegroundColor Green
Write-Host '  1. Plugin de Copilot Studio y inicios de sesión: docs/01-prerequisitos.md, pasos 8 y 9'
Write-Host '  2. Comprobación:  pwsh -File .\scripts\Test-Prerequisites.ps1'
