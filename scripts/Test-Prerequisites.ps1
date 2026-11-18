<#
.SYNOPSIS
    Comprueba que el equipo tiene todo lo necesario para el taller de Spec Driven Development con SpecKit
    en Power Platform. No instala nada.

.EXAMPLE
    pwsh -File .\scripts\Test-Prerequisites.ps1
#>
[CmdletBinding()]
param()

$results = New-Object System.Collections.Generic.List[object]

function Add-Result([string]$name, [string]$status, [string]$detail, [string]$fix) {
    $results.Add([pscustomobject]@{ Requisito = $name; Estado = $status; Detalle = $detail; Solucion = $fix })
}

function Get-FirstLine($scriptBlock) {
    try { $out = & $scriptBlock 2>&1 | Out-String } catch { return $null }
    if (-not $out) { return $null }
    return ($out -split "`r?`n" | Where-Object { $_.Trim() -ne '' } | Select-Object -First 1).Trim()
}

function Test-Tool([string]$name, [string]$command, [scriptblock]$version, [string]$minimum, [string]$fix) {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
        Add-Result $name 'FALTA' 'No encontrado en el PATH' $fix
        return
    }
    $text = Get-FirstLine $version
    if (-not $minimum) { Add-Result $name 'OK' $text ''; return }
    $m = [regex]::Match("$text", '(\d+)\.(\d+)(?:\.(\d+))?')
    if (-not $m.Success) { Add-Result $name 'AVISO' "Versión no reconocida: $text" $fix; return }
    $found = [version]("{0}.{1}.{2}" -f $m.Groups[1].Value, $m.Groups[2].Value, ($(if ($m.Groups[3].Success) { $m.Groups[3].Value } else { '0' })))
    if ($found -ge [version]$minimum) { Add-Result $name 'OK' "$found" '' }
    else { Add-Result $name 'ACTUALIZAR' "$found (mínimo $minimum)" $fix }
}

Write-Host 'Comprobando requisitos del taller...' -ForegroundColor Cyan

# PowerShell 7 (Copilot CLI lo necesita en Windows)
if (Get-Command pwsh -ErrorAction SilentlyContinue) {
    Test-Tool 'PowerShell 7' 'pwsh' { pwsh -NoProfile -Command '$PSVersionTable.PSVersion.ToString()' } '7.0.0' 'winget install --id Microsoft.PowerShell -e'
} else { Add-Result 'PowerShell 7' 'FALTA' 'No encontrado' 'winget install --id Microsoft.PowerShell -e' }

Test-Tool 'Git' 'git' { git --version } '2.22.0' 'winget install --id Git.Git -e'
Test-Tool 'Node.js' 'node' { node --version } '22.0.0' 'winget install --id OpenJS.NodeJS.LTS -e'
Test-Tool 'Python' 'python' { python --version } '3.11.0' 'winget install --id Python.Python.3.12 -e'
Test-Tool 'uv' 'uv' { uv --version } '' 'winget install --id astral-sh.uv -e'
Test-Tool 'Azure CLI' 'az' { az version --query '\"azure-cli\"' -o tsv } '' 'winget install --id Microsoft.AzureCLI -e'
Test-Tool 'VS Code' 'code' { code --version } '' 'winget install --id Microsoft.VisualStudioCode -e'
Test-Tool 'GitHub Copilot CLI' 'copilot' { copilot --version } '' 'winget install --id GitHub.Copilot -e'

# .NET 10 SDK
if (Get-Command dotnet -ErrorAction SilentlyContinue) {
    $sdks = (& dotnet --list-sdks 2>$null) -join ' '
    if ($sdks -match '(^|\s)10\.') { Add-Result '.NET 10 SDK' 'OK' (([regex]::Match($sdks, '10\.[\d\.]+')).Value) '' }
    else { Add-Result '.NET 10 SDK' 'FALTA' "SDKs: $sdks" 'winget install --id Microsoft.DotNet.SDK.10 -e' }
} else { Add-Result '.NET 10 SDK' 'FALTA' 'dotnet no encontrado' 'winget install --id Microsoft.DotNet.SDK.10 -e' }

# PAC CLI (el plugin de Copilot Studio necesita 2.9.3 o superior)
if (Get-Command pac -ErrorAction SilentlyContinue) {
    $pacOut = (& pac 2>&1 | Out-String)
    $m = [regex]::Match($pacOut, 'Version:\s*([\d\.]+)')
    if ($m.Success) {
        $v = [version](($m.Groups[1].Value -split '\.')[0..2] -join '.')
        if ($v -ge [version]'2.9.3') { Add-Result 'PAC CLI' 'OK' "$v" '' }
        else { Add-Result 'PAC CLI' 'ACTUALIZAR' "$v (mínimo 2.9.3)" 'dotnet tool update --global Microsoft.PowerApps.CLI.Tool' }
    } else { Add-Result 'PAC CLI' 'AVISO' 'Versión no reconocida' 'dotnet tool update --global Microsoft.PowerApps.CLI.Tool' }
} else { Add-Result 'PAC CLI' 'FALTA' 'No encontrado' 'dotnet tool install --global Microsoft.PowerApps.CLI.Tool' }

# Power Apps CLI (Code Apps)
if (Get-Command pa -ErrorAction SilentlyContinue) { Add-Result 'Power Apps CLI (pa)' 'OK' 'Instalado' '' }
else { Add-Result 'Power Apps CLI (pa)' 'FALTA' 'No encontrado' 'npm install --global @microsoft/power-apps-cli' }

# SpecKit
if (Get-Command specify -ErrorAction SilentlyContinue) {
    $sv = (& specify version 2>&1 | Out-String)
    $m = [regex]::Match($sv, 'CLI Version\D*([\d\.]+)')
    if ($m.Success) { Add-Result 'SpecKit (specify)' 'OK' $m.Groups[1].Value '' }
    else { Add-Result 'SpecKit (specify)' 'OK' 'Instalado' '' }
} else { Add-Result 'SpecKit (specify)' 'FALTA' 'No encontrado' 'uv tool install specify-cli' }

# Extensiones de VS Code
if (Get-Command code -ErrorAction SilentlyContinue) {
    $ext = (& code --list-extensions 2>$null) -join "`n"
    foreach ($e in @(
            @{ id = 'GitHub.copilot-chat'; name = 'Ext. GitHub Copilot Chat' },
            @{ id = 'microsoft-IsvExpTools.powerplatform-vscode'; name = 'Ext. Power Platform Tools' },
            @{ id = 'ms-CopilotStudio.vscode-copilotstudio'; name = 'Ext. Copilot Studio' })) {
        if ($ext -match [regex]::Escape($e.id)) { Add-Result $e.name 'OK' $e.id '' }
        else { Add-Result $e.name 'FALTA' $e.id "code --install-extension $($e.id)" }
    }
}

# Sesiones
if (Get-Command az -ErrorAction SilentlyContinue) {
    $acct = (& az account show --query user.name -o tsv 2>$null)
    if ($acct) { Add-Result 'Sesión Azure CLI' 'OK' $acct '' } else { Add-Result 'Sesión Azure CLI' 'AVISO' 'Sin sesión' 'az login' }
}
if (Get-Command pac -ErrorAction SilentlyContinue) {
    $auth = (& pac auth list 2>&1 | Out-String)
    if ($auth -match '\*') { Add-Result 'Perfil PAC activo' 'OK' 'Hay un perfil activo' '' }
    else { Add-Result 'Perfil PAC activo' 'AVISO' 'Sin perfil activo' 'pac auth create --environment <URL-del-entorno>' }
}

Write-Host ($results | Format-Table -AutoSize -Wrap | Out-String -Width 200)
$bad = @($results | Where-Object { $_.Estado -in @('FALTA', 'ACTUALIZAR') })
if ($bad.Count -gt 0) {
    Write-Host "Faltan $($bad.Count) requisitos. Ejecuta .\scripts\Install-Prerequisites.ps1 o la solución indicada en cada fila." -ForegroundColor Yellow
    exit 1
}
Write-Host 'Todo listo. Revisa también los plugins (docs/01-prerequisitos.md, pasos 7 y 8).' -ForegroundColor Green
exit 0
