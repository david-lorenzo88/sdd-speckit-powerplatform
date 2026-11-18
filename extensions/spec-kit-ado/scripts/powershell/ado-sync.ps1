<#
.SYNOPSIS
    One-way sync of a SpecKit feature to Azure Boards (Agile process):
    spec folder -> Feature, user story / technical phase -> User Story, task -> Task.

.DESCRIPTION
    Reads specs/<feature>/spec.md and specs/<feature>/tasks.md, creates the missing work items,
    links them (Feature > User Story > Task), and updates states from the tasks.md checkboxes.
    The repository is the source of truth. Work item IDs are stored in specs/<feature>/ado.json.

    Compatible with Windows PowerShell 5.1 and PowerShell 7+.

.PARAMETER FeatureDir
    Feature folder (for example specs/001-solicitudes-contacto). If omitted, the folder that matches
    the current Git branch is used, otherwise the most recently modified folder under specs/ with a tasks.md.

.PARAMETER DryRun
    Show what would be created or changed without writing to Azure DevOps or ado.json.

.PARAMETER Offline
    With -DryRun: do not call Azure DevOps at all (no authentication, existing states unknown).

.PARAMETER Validate
    Only check the configuration and the connection to the project, and report the process template.

.EXAMPLE
    ./ado-sync.ps1 -FeatureDir specs/001-solicitudes-contacto -DryRun
#>
[CmdletBinding()]
param(
    [string]$FeatureDir,
    [switch]$DryRun,
    [switch]$Offline,
    [switch]$Validate
)

$ErrorActionPreference = 'Stop'
$Dot = [char]0x00B7
$AdoResource = '499b84ac-1321-427f-aa17-267ca6975798'
$ApiVersion = '7.1'

# ------------------------------------------------------------------ helpers

function Write-Info($msg) { Write-Host $msg }
function Write-Warn($msg) { Write-Host "WARNING: $msg" -ForegroundColor Yellow }

function Get-RepoRoot {
    $root = $null
    try { $root = (& git rev-parse --show-toplevel 2>$null) } catch { $root = $null }
    if ($root) { return ($root | Select-Object -First 1).Trim() }
    return (Get-Location).Path
}

function Read-FlatYaml([string]$path) {
    $h = @{}
    if (-not (Test-Path -LiteralPath $path)) { return $h }
    foreach ($line in (Get-Content -LiteralPath $path -Encoding UTF8)) {
        if ($line -match '^\s*#' -or $line -match '^\s*$') { continue }
        if ($line -match '^\s*([A-Za-z0-9_]+)\s*:\s*(.*?)\s*$') {
            $key = $Matches[1]; $val = $Matches[2]
            if ($val -match '^"([^"]*)"\s*(#.*)?$' -or $val -match "^'([^']*)'\s*(#.*)?$") { $val = $Matches[1] }
            elseif ($val -match '^#') { $val = '' }
            else { $val = ($val -replace '\s+#.*$', '').Trim() }
            $h[$key] = $val
        }
    }
    return $h
}

function Get-Config([string]$root) {
    $cfg = [ordered]@{
        organization     = ''
        project          = ''
        areaPath         = ''
        iterationPath    = ''
        repoUrl          = ''
        branch           = ''
        tags             = 'speckit'
        taskDoneState    = 'Closed'
        storyDoneState   = 'Resolved'
        featureDoneState = 'Resolved'
    }
    $dir = Join-Path $root '.specify/extensions/ado'
    foreach ($file in @('ado-config.yml', 'ado-config.local.yml')) {
        $values = Read-FlatYaml (Join-Path $dir $file)
        foreach ($k in $values.Keys) { if ($cfg.Contains($k) -and $values[$k] -ne '') { $cfg[$k] = $values[$k] } }
    }
    foreach ($k in @($cfg.Keys)) {
        $envName = 'SPECKIT_ADO_' + $k.ToUpperInvariant()
        $envVal = [Environment]::GetEnvironmentVariable($envName)
        if ($envVal) { $cfg[$k] = $envVal }
    }
    return $cfg
}

function ConvertTo-Html([string]$md) {
    $t = $md.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;').Replace('"', '&quot;')
    $t = [regex]::Replace($t, '\*\*(.+?)\*\*', '<b>$1</b>')
    $t = [regex]::Replace($t, '`([^`]+)`', '<code>$1</code>')
    return $t
}

function Get-Clean([string]$s) {
    $s = [regex]::Replace($s, '[\uD800-\uDFFF]', '')       # emoji (surrogate pairs)
    $s = [regex]::Replace($s, '\s+MVP\s*$', '')
    return $s.Trim()
}

function Limit([string]$s, [int]$n) { if ($s.Length -le $n) { return $s } return $s.Substring(0, $n - 3) + '...' }

$StoryHead = '^###\s+(?:User Story|Historia de usuario|Historia)\s+(\d+)\s*[-:\u2013\u2014]\s*(.+?)\s*(?:\((?:Priority|Prioridad)\s*:\s*P(\d)\))?\s*$'
$PhaseHead = '^##\s+(?:Phase|Fase)\s+(\d+)\s*[:\-\u2013\u2014]\s*(.+?)\s*$'
$StoryInPhase = '^(?:User Story|Historia de usuario|Historia)\s+(\d+)\s*[-:\u2013\u2014]?\s*(.*?)\s*(?:\((?:Priority|Prioridad)\s*:\s*P(\d)\))?\s*$'
$TaskLine = '^\s*[-*]\s+\[( |x|X)\]\s+(T\d{3,})\b\s*(.*)$'

# ------------------------------------------------------------------ parsing

function Read-Spec([string]$path) {
    $lines = Get-Content -LiteralPath $path -Encoding UTF8
    $spec = [ordered]@{ title = ''; summary = ''; stories = [ordered]@{} }
    foreach ($l in $lines) {
        if ($l -match '^#\s+(.+)$') {
            $t = $Matches[1].Trim()
            if ($t -match '^[^:]{0,60}:\s*(.+)$') { $t = $Matches[1].Trim() }
            $spec.title = Get-Clean $t
            break
        }
    }
    $current = $null; $inAcceptance = $false
    foreach ($l in $lines) {
        if ($l -match $StoryHead) {
            $n = [int]$Matches[1]
            $prio = 2
            if ($Matches[3]) { $prio = [Math]::Min([int]$Matches[3], 4) }
            $current = [ordered]@{ key = "US$n"; number = $n; title = (Get-Clean $Matches[2]); priority = $prio; body = @(); acceptance = @() }
            $spec.stories["US$n"] = $current
            $inAcceptance = $false
            continue
        }
        if ($l -match '^#{1,3}\s') { $current = $null; $inAcceptance = $false; continue }
        if ($null -eq $current) { continue }
        if ($l -match '^\s*\*\*(Acceptance Scenarios|Escenarios de aceptaci.n|Criterios de aceptaci.n)') { $inAcceptance = $true; continue }
        if ($inAcceptance) {
            if ($l -match '^\s*\d+\.\s+(.+)$') { $current.acceptance += $Matches[1].Trim() }
            elseif ($l -match '^\s*\*\*') { $inAcceptance = $false; $current.body += $l.Trim() }
            continue
        }
        if ($l.Trim() -ne '' -and $l.Trim() -ne '---') { $current.body += $l.Trim() }
    }
    return $spec
}

function Read-Tasks([string]$path) {
    $lines = Get-Content -LiteralPath $path -Encoding UTF8
    $phases = [ordered]@{}
    $tasks = [ordered]@{}
    $phaseKey = 'PHASE:unphased'; $phaseTitle = 'Unphased'
    $phaseStory = $null
    foreach ($l in $lines) {
        if ($l -match $PhaseHead) {
            $name = Get-Clean $Matches[2]
            $phaseStory = $null
            if ($name -match $StoryInPhase) {
                $n = [int]$Matches[1]
                $prio = 2
                if ($Matches[3]) { $prio = [Math]::Min([int]$Matches[3], 4) }
                $phaseStory = "US$n"
                $phaseKey = "US$n"
                if (-not $phases.Contains($phaseKey)) {
                    $phases[$phaseKey] = [ordered]@{ key = $phaseKey; title = (Get-Clean $Matches[2]); technical = $false; priority = $prio }
                }
            }
            else {
                $norm = ([regex]::Replace($name, '\s*\(.*?\)\s*', ' ')).Trim().ToLowerInvariant()
                $phaseKey = "PHASE:$norm"
                if (-not $phases.Contains($phaseKey)) {
                    $phases[$phaseKey] = [ordered]@{ key = $phaseKey; title = $name; technical = $true; priority = 2 }
                }
            }
            continue
        }
        if ($l -match $TaskLine) {
            $done = ($Matches[1] -ne ' ')
            $id = $Matches[2]
            $rest = $Matches[3]
            $parallel = ($rest -match '\[P\]')
            $story = $phaseKey
            if ($rest -match '\[US(\d+)\]') { $story = 'US' + [int]$Matches[1] }
            $desc = ([regex]::Replace($rest, '\[(P|US\d+)\]\s*', '')).Trim()
            if (-not $phases.Contains($phaseKey)) {
                $phases[$phaseKey] = [ordered]@{ key = $phaseKey; title = $phaseTitle; technical = $true; priority = 2 }
            }
            $tasks[$id] = [ordered]@{ id = $id; done = $done; parallel = $parallel; story = $story; desc = $desc; line = ("$id $rest").Trim() }
        }
    }
    return @{ phases = $phases; tasks = $tasks }
}

# ------------------------------------------------------------------ Azure DevOps REST

$script:Auth = $null
$script:FakeId = 0
$script:Stats = [ordered]@{ created = 0; updated = 0; stateChanges = 0; removed = 0 }

function Get-AuthHeader {
    if ($env:SYSTEM_ACCESSTOKEN) { return "Bearer $($env:SYSTEM_ACCESSTOKEN)" }
    if ($env:AZURE_DEVOPS_EXT_PAT) {
        $b = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":" + $env:AZURE_DEVOPS_EXT_PAT))
        return "Basic $b"
    }
    $token = $null
    try { $token = (& az account get-access-token --resource $AdoResource --query accessToken -o tsv 2>$null) } catch { $token = $null }
    if (-not $token) { throw "No Azure DevOps credentials. Run 'az login', or set AZURE_DEVOPS_EXT_PAT, or SYSTEM_ACCESSTOKEN in a pipeline." }
    return "Bearer $(($token | Select-Object -First 1).Trim())"
}

function Invoke-Ado([string]$method, [string]$url, $body) {
    $params = @{ Method = $method; Uri = $url; Headers = @{ Authorization = $script:Auth } }
    if ($null -ne $body) {
        $json = ConvertTo-Json -InputObject $body -Depth 10 -Compress
        $params.Body = [Text.Encoding]::UTF8.GetBytes($json)
        $params.ContentType = 'application/json-patch+json; charset=utf-8'
    }
    return Invoke-RestMethod @params
}

function New-WorkItem([string]$type, $fields, $parentId) {
    if ($DryRun) {
        $script:FakeId--
        $parentText = ''
        if ($parentId) { $parentText = " (parent $parentId)" }
        Write-Info ("  [dry-run] create {0}: {1}{2}" -f $type, $fields['System.Title'], $parentText)
        $script:Stats.created++
        return $script:FakeId
    }
    $ops = @()
    foreach ($k in $fields.Keys) {
        if ($null -ne $fields[$k] -and "$($fields[$k])" -ne '') { $ops += @{ op = 'add'; path = "/fields/$k"; value = $fields[$k] } }
    }
    if ($parentId) {
        $ops += @{ op = 'add'; path = '/relations/-'; value = @{ rel = 'System.LinkTypes.Hierarchy-Reverse'; url = "$($script:OrgUrl)/_apis/wit/workItems/$parentId" } }
    }
    $url = "$($script:OrgUrl)/$([uri]::EscapeDataString($script:Project))/_apis/wit/workitems/`$$([uri]::EscapeDataString($type))?api-version=$ApiVersion"
    $r = Invoke-Ado 'POST' $url $ops
    $script:Stats.created++
    Write-Info ("  created {0} {1}: {2}" -f $type, $r.id, $fields['System.Title'])
    return [int]$r.id
}

function Update-WorkItem([int]$id, $fields, [string]$why) {
    if ($DryRun) { Write-Info ("  [dry-run] update {0}: {1}" -f $id, $why); return }
    $ops = @()
    foreach ($k in $fields.Keys) { $ops += @{ op = 'add'; path = "/fields/$k"; value = $fields[$k] } }
    $null = Invoke-Ado 'PATCH' "$($script:OrgUrl)/_apis/wit/workitems/$($id)?api-version=$ApiVersion" $ops
    Write-Info ("  updated {0}: {1}" -f $id, $why)
}

function Get-WorkItemStates([int[]]$ids) {
    $result = @{}
    $real = @($ids | Where-Object { $_ -gt 0 } | Select-Object -Unique)
    if ($real.Count -eq 0 -or $Offline) { return $result }
    for ($i = 0; $i -lt $real.Count; $i += 200) {
        $chunk = $real[$i..([Math]::Min($i + 199, $real.Count - 1))]
        $url = "$($script:OrgUrl)/_apis/wit/workitems?ids=$($chunk -join ',')&fields=System.State,System.Title&errorPolicy=omit&api-version=$ApiVersion"
        $r = Invoke-Ado 'GET' $url $null
        foreach ($wi in $r.value) {
            if ($null -ne $wi) { $result[[int]$wi.id] = @{ state = $wi.fields.'System.State'; title = $wi.fields.'System.Title' } }
        }
    }
    return $result
}

function Set-State([int]$id, [string]$current, [string]$target, [string]$label) {
    if ($current -eq $target) { return $current }
    $why = "$label state $current -> $target"
    try {
        Update-WorkItem $id @{ 'System.State' = $target } $why
    }
    catch {
        if ($target -ne 'Active' -and $current -ne 'Active') {
            Update-WorkItem $id @{ 'System.State' = 'Active' } "$label state $current -> Active"
            Update-WorkItem $id @{ 'System.State' = $target } "$label state Active -> $target"
        }
        else { throw }
    }
    $script:Stats.stateChanges++
    return $target
}

# ------------------------------------------------------------------ main

$root = Get-RepoRoot
$cfg = Get-Config $root

$missing = @()
if (-not $cfg.organization) { $missing += 'organization' }
if (-not $cfg.project) { $missing += 'project' }
if ($missing.Count -gt 0 -and -not ($DryRun -and $Offline)) {
    Write-Host "Azure DevOps sync is not configured (missing: $($missing -join ', '))." -ForegroundColor Yellow
    Write-Host "Run the setup command (/speckit-ado-setup) or create .specify/extensions/ado/ado-config.yml."
    exit 1
}
if ($cfg.organization -match '^https?://') { $script:OrgUrl = $cfg.organization.TrimEnd('/') }
else { $script:OrgUrl = "https://dev.azure.com/$($cfg.organization)" }
$script:Project = $cfg.project

if (-not ($DryRun -and $Offline)) { $script:Auth = Get-AuthHeader }

if ($Validate) {
    $p = Invoke-Ado 'GET' "$($script:OrgUrl)/_apis/projects/$([uri]::EscapeDataString($script:Project))?includeCapabilities=true&api-version=$ApiVersion" $null
    $process = $p.capabilities.processTemplate.templateName
    Write-Info "Connected to $($script:OrgUrl) / $($p.name). Process template: $process"
    if ($process -notmatch 'Agile') { Write-Warn "This extension maps to the Agile process (Feature, User Story, Task). Current process: $process" }
    exit 0
}

# resolve feature folder
if (-not $FeatureDir) {
    $branch = $null
    try { $branch = (& git -C $root branch --show-current 2>$null) } catch { $branch = $null }
    if ($branch -and (Test-Path -LiteralPath (Join-Path $root "specs/$branch/tasks.md"))) { $FeatureDir = "specs/$branch" }
    elseif ($env:SPECIFY_FEATURE -and (Test-Path -LiteralPath (Join-Path $root "specs/$($env:SPECIFY_FEATURE)/tasks.md"))) { $FeatureDir = "specs/$($env:SPECIFY_FEATURE)" }
    else {
        $latest = Get-ChildItem -LiteralPath (Join-Path $root 'specs') -Directory -ErrorAction SilentlyContinue |
            Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'tasks.md') } |
            Sort-Object { (Get-Item -LiteralPath (Join-Path $_.FullName 'tasks.md')).LastWriteTime } -Descending |
            Select-Object -First 1
        if (-not $latest) { throw "No feature with tasks.md found under specs/. Run /speckit-tasks first or pass -FeatureDir." }
        $FeatureDir = "specs/$($latest.Name)"
    }
}
if ([IO.Path]::IsPathRooted($FeatureDir)) { $featurePath = $FeatureDir } else { $featurePath = Join-Path $root $FeatureDir }
$featurePath = (Resolve-Path -LiteralPath $featurePath).Path
$featureName = Split-Path $featurePath -Leaf
$specPath = Join-Path $featurePath 'spec.md'
$tasksPath = Join-Path $featurePath 'tasks.md'
$mapPath = Join-Path $featurePath 'ado.json'
if (-not (Test-Path -LiteralPath $specPath)) { throw "spec.md not found in $featurePath" }
if (-not (Test-Path -LiteralPath $tasksPath)) { throw "tasks.md not found in $featurePath. Run /speckit-tasks first." }
$relFeature = 'specs/' + $featureName

$num = $featureName
if ($featureName -match '^(\d+)') { $num = $Matches[1] }

# links to the repository
$branchName = $cfg.branch
if (-not $branchName) { try { $branchName = (& git -C $root branch --show-current 2>$null) } catch { $branchName = '' } }
function Get-RepoLink([string]$file) {
    if (-not $cfg.repoUrl) { return '' }
    $base = $cfg.repoUrl.TrimEnd('/')
    if ($base -match 'github\.com') { return "$base/blob/$branchName/$relFeature/$file" }
    return "$base`?path=/$relFeature/$file&version=GB$branchName"
}
function Get-SourceHtml([string]$file) {
    $link = Get-RepoLink $file
    if ($link) { return "<p>Source: <a href=`"$link`">$relFeature/$file</a></p>" }
    return "<p>Source: $relFeature/$file</p>"
}

$spec = Read-Spec $specPath
$parsed = Read-Tasks $tasksPath
$tasks = $parsed.tasks

# stories = spec stories + phases from tasks.md
$stories = [ordered]@{}
foreach ($k in $spec.stories.Keys) {
    $s = $spec.stories[$k]
    $stories[$k] = [ordered]@{ key = $k; title = "US$($s.number) $Dot $($s.title)"; technical = $false; priority = $s.priority; body = $s.body; acceptance = $s.acceptance }
}
foreach ($k in $parsed.phases.Keys) {
    if ($stories.Contains($k)) { continue }
    $p = $parsed.phases[$k]
    $title = $p.title
    if (-not $p.technical) { $title = "$k $Dot $($p.title)" }
    $stories[$k] = [ordered]@{ key = $k; title = $title; technical = $p.technical; priority = $p.priority; body = @(); acceptance = @() }
}
# drop technical phases without tasks
foreach ($k in @($stories.Keys)) {
    if ($stories[$k].technical) {
        $has = @($tasks.Values | Where-Object { $_.story -eq $k }).Count
        if ($has -eq 0) { $stories.Remove($k) }
    }
}

# load map
$map = [ordered]@{ organization = $script:OrgUrl; project = $script:Project; feature = $null; stories = [ordered]@{}; tasks = [ordered]@{}; removed = [ordered]@{}; lastSync = $null }
if (Test-Path -LiteralPath $mapPath) {
    $raw = Get-Content -LiteralPath $mapPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $map.feature = $raw.feature
    foreach ($section in @('stories', 'tasks', 'removed')) {
        if ($raw.$section) { foreach ($p in $raw.$section.PSObject.Properties) { $map[$section][$p.Name] = [int]$p.Value } }
    }
}

function Save-Map {
    if ($DryRun) { return }
    $map.lastSync = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    $json = ConvertTo-Json -InputObject $map -Depth 5
    [IO.File]::WriteAllText($mapPath, $json, (New-Object Text.UTF8Encoding $false))
}

Write-Info "Feature: $relFeature -> $($script:OrgUrl)/$($script:Project)"
if ($DryRun) { Write-Info "Mode: dry run (nothing is written)" }

# current states of known items
$allIds = @()
if ($map.feature) { $allIds += [int]$map.feature }
$allIds += @($map.stories.Values | ForEach-Object { [int]$_ })
$allIds += @($map.tasks.Values | ForEach-Object { [int]$_ })
$states = Get-WorkItemStates $allIds
function Set-Known($id, [string]$st) {
    if ($states.ContainsKey([int]$id)) { $states[[int]$id].state = $st }
    else { $states[[int]$id] = @{ state = $st; title = '' } }
}
function Get-StateOf($id) {
    if ($null -eq $id) { return $null }
    if ($states.ContainsKey([int]$id)) { return $states[[int]$id].state }
    if ($Offline -or [int]$id -lt 0) { return 'New' }
    return $null   # deleted or not accessible
}

$baseTags = $cfg.tags
$common = [ordered]@{}
if ($cfg.areaPath) { $common['System.AreaPath'] = $cfg.areaPath }
if ($cfg.iterationPath) { $common['System.IterationPath'] = $cfg.iterationPath }

# ---- Feature
$featureTitle = Limit "$num $Dot $($spec.title)" 255
if ($map.feature -and $null -eq (Get-StateOf $map.feature)) { Write-Warn "Feature $($map.feature) no longer exists; it will be created again."; $map.feature = $null }
if (-not $map.feature) {
    $f = [ordered]@{ 'System.Title' = $featureTitle; 'System.Description' = (Get-SourceHtml 'spec.md'); 'System.Tags' = "$baseTags; spec-$num" }
    foreach ($k in $common.Keys) { $f[$k] = $common[$k] }
    $map.feature = New-WorkItem 'Feature' $f $null
    $states[[int]$map.feature] = @{ state = 'New'; title = $featureTitle }
    Save-Map
}
elseif ($states.ContainsKey([int]$map.feature) -and $states[[int]$map.feature].title -ne $featureTitle) {
    Update-WorkItem $map.feature @{ 'System.Title' = $featureTitle } 'Feature title'
    $script:Stats.updated++
}

# ---- User Stories
foreach ($k in $stories.Keys) {
    $s = $stories[$k]
    $title = Limit "$num $Dot $($s.title)" 255
    $id = $null
    if ($map.stories.Contains($k)) { $id = $map.stories[$k] }
    if ($id -and $null -eq (Get-StateOf $id)) { Write-Warn "User Story $id ($k) no longer exists; it will be created again."; $id = $null }
    if (-not $id) {
        $desc = ''
        foreach ($b in $s.body) { $desc += '<p>' + (ConvertTo-Html $b) + '</p>' }
        $desc += Get-SourceHtml 'spec.md'
        $tags = "$baseTags; spec-$num"
        if ($s.technical) { $tags += '; technical' }
        $f = [ordered]@{ 'System.Title' = $title; 'System.Description' = $desc; 'Microsoft.VSTS.Common.Priority' = $s.priority; 'System.Tags' = $tags }
        if ($s.acceptance.Count -gt 0) {
            $ac = '<ol>'
            foreach ($a in $s.acceptance) { $ac += '<li>' + (ConvertTo-Html $a) + '</li>' }
            $f['Microsoft.VSTS.Common.AcceptanceCriteria'] = $ac + '</ol>'
        }
        foreach ($c in $common.Keys) { $f[$c] = $common[$c] }
        $id = New-WorkItem 'User Story' $f $map.feature
        $map.stories[$k] = $id
        $states[[int]$id] = @{ state = 'New'; title = $title }
        Save-Map
    }
    elseif ($states.ContainsKey([int]$id) -and $states[[int]$id].title -ne $title) {
        Update-WorkItem $id @{ 'System.Title' = $title } "User Story $k title"
        $script:Stats.updated++
    }
}

# ---- Tasks
foreach ($tid in $tasks.Keys) {
    $t = $tasks[$tid]
    $title = Limit "$tid $Dot $($t.desc)" 255
    $parent = $null
    if ($map.stories.Contains($t.story)) { $parent = $map.stories[$t.story] }
    $id = $null
    if ($map.tasks.Contains($tid)) { $id = $map.tasks[$tid] }
    if ($id -and $null -eq (Get-StateOf $id)) { Write-Warn "Task $id ($tid) no longer exists; it will be created again."; $id = $null }
    if (-not $id) {
        $tags = "$baseTags; spec-$num"
        if ($t.parallel) { $tags += '; parallel' }
        $f = [ordered]@{ 'System.Title' = $title; 'System.Description' = ('<p>' + (ConvertTo-Html $t.line) + '</p>' + (Get-SourceHtml 'tasks.md')); 'System.Tags' = $tags }
        foreach ($c in $common.Keys) { $f[$c] = $common[$c] }
        $id = New-WorkItem 'Task' $f $parent
        $map.tasks[$tid] = $id
        $states[[int]$id] = @{ state = 'New'; title = $title }
        Save-Map
    }
    elseif ($states.ContainsKey([int]$id) -and $states[[int]$id].title -ne $title) {
        Update-WorkItem $id @{ 'System.Title' = $title } "Task $tid title"
        $script:Stats.updated++
    }
}

# ---- Removed tasks and stories (in ado.json but no longer in the repo)
foreach ($tid in @($map.tasks.Keys)) {
    if ($tasks.Contains($tid)) { continue }
    $id = $map.tasks[$tid]
    $st = Get-StateOf $id
    if ($st -and $st -ne 'Removed') { $null = Set-State $id $st 'Removed' "Task $tid (no longer in tasks.md)" }
    $map.removed[$tid] = $id; $map.tasks.Remove($tid); $script:Stats.removed++
}
foreach ($k in @($map.stories.Keys)) {
    if ($stories.Contains($k)) { continue }
    $id = $map.stories[$k]
    $st = Get-StateOf $id
    if ($st -and $st -ne 'Removed') { $null = Set-State $id $st 'Removed' "User Story $k (no longer in spec or tasks)" }
    $map.removed[$k] = $id; $map.stories.Remove($k); $script:Stats.removed++
}

# ---- States: tasks
foreach ($tid in $tasks.Keys) {
    $t = $tasks[$tid]; $id = $map.tasks[$tid]
    $st = Get-StateOf $id
    if ($t.done -and $st -notin @($cfg.taskDoneState, 'Removed')) {
        Set-Known $id (Set-State $id $st $cfg.taskDoneState "Task $tid")
    }
    elseif (-not $t.done -and $st -eq $cfg.taskDoneState) {
        Set-Known $id (Set-State $id $st 'Active' "Task $tid (reopened in tasks.md)")
    }
}

# ---- States: user stories
$storyStates = @()
foreach ($k in $stories.Keys) {
    $id = $map.stories[$k]
    $st = Get-StateOf $id
    $children = @($tasks.Values | Where-Object { $_.story -eq $k })
    $doneCount = @($children | Where-Object { $_.done }).Count
    if ($children.Count -gt 0) {
        if ($doneCount -eq $children.Count) {
            if ($st -notin @($cfg.storyDoneState, 'Closed', 'Removed')) { $st = Set-State $id $st $cfg.storyDoneState "User Story $k (all tasks done)" }
        }
        elseif ($doneCount -gt 0 -and $st -eq 'New') { $st = Set-State $id $st 'Active' "User Story $k (in progress)" }
        elseif ($st -eq $cfg.storyDoneState) { $st = Set-State $id $st 'Active' "User Story $k (new or reopened tasks)" }
        elseif ($st -eq 'Closed') { Write-Warn "User Story $id ($k) is Closed but has open tasks in tasks.md." }
    }
    $storyStates += $st
}

# ---- State: feature
$fst = Get-StateOf $map.feature
$allDone = ($storyStates.Count -gt 0) -and (@($storyStates | Where-Object { $_ -notin @($cfg.storyDoneState, 'Closed', 'Removed') }).Count -eq 0)
$anyStarted = (@($storyStates | Where-Object { $_ -in @('Active', $cfg.storyDoneState, 'Closed') }).Count -gt 0)
if ($allDone -and $fst -notin @($cfg.featureDoneState, 'Closed')) { $null = Set-State $map.feature $fst $cfg.featureDoneState 'Feature (all stories done)' }
elseif (-not $allDone -and $anyStarted -and $fst -eq 'New') { $null = Set-State $map.feature $fst 'Active' 'Feature (in progress)' }
elseif (-not $allDone -and $fst -eq $cfg.featureDoneState) { $null = Set-State $map.feature $fst 'Active' 'Feature (reopened)' }

Save-Map

$doneTasks = @($tasks.Values | Where-Object { $_.done }).Count
Write-Info ''
Write-Info ("Summary: {0} created, {1} updated, {2} state changes, {3} removed." -f $script:Stats.created, $script:Stats.updated, $script:Stats.stateChanges, $script:Stats.removed)
Write-Info ("Progress: {0}/{1} tasks done across {2} user stories." -f $doneTasks, $tasks.Count, $stories.Count)
if (-not $DryRun) {
    Write-Info "Feature: $($script:OrgUrl)/$([uri]::EscapeDataString($script:Project))/_workitems/edit/$($map.feature)"
    Write-Info "Mapping saved to $relFeature/ado.json (commit it with the feature)."
}
