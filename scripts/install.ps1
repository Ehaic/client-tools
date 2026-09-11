# ================================================================================
# install.ps1 - lay out and verify the single-root SOE-shaped tools tree.
#
# PowerShell port of the manual install rehearsal (2026-09-01 handoff) and the
# prototype of the launcher wizard's first-run step list (INSTALLER-DESIGN.md).
# Every step is idempotent and completion is recorded in <root>\_install-state.json,
# so a crash, cancel, or power cut resumes where it left off. Re-run after
# deleting the state file to force a full re-lay (copies skip unchanged files).
#
# Run it from a clone of client-tools (branch x64-dx11-qt-tools) - configs,
# scripts and the exe\win32 store come from the clone itself. Two inputs are
# still machine-local until the real installer ships/downloads them:
#   -TreSource       dir holding the 209 *.tre + 4 *.toc
#   -AppSource       BUILT tools dir (*.exe, *.dll - build output, not in git)
#   -OverrideSource  the stage-B override corpus (no repo home yet - flagged)
# Requires: git, python 3 on PATH.
# ================================================================================
param(
    [string]$Root = 'C:\swg\current',
    [string]$TreSource = 'D:\Code\SWGSource Client v3.0',
    [string]$AppSource = 'D:\Code\swg-qt-tools-worktree\src\build\win32\x64\Release',
    [string]$OverrideSource = 'D:\Code\Galaxies-Reborn\stage-B-override',
    [string]$DsrcPin = 'a05279872',
    [string]$DsrcUrl = 'https://github.com/SWG-Source/dsrc.git',
    [string]$ServerdataUrl = 'https://github.com/SWG-Source/serverdata.git',
    [string]$PayloadUrl = 'https://github.com/Galaxies-Reborn/legacy-tools-payload.git',
    [switch]$SkipSmoke
)

$ErrorActionPreference = 'Stop'
# repo-relative sources: this script lives in <clone>\scripts\
$ScriptsDir = $PSScriptRoot
$RepoRoot = Split-Path -Parent $PSScriptRoot
$StoreSource = Join-Path $RepoRoot 'src\build\win32\exe\win32'
$CfgSource = Join-Path $RepoRoot 'src\build\win32\x64\Release'
$ReposDir = Join-Path (Split-Path -Parent $Root) 'repos'
$ExeDir = Join-Path $Root 'exe\win32'
$DataDir = Join-Path $Root 'data'
$StateFile = Join-Path $Root '_install-state.json'
$script:State = @{}

function Load-State {
    if (Test-Path $StateFile) {
        $json = Get-Content $StateFile -Raw | ConvertFrom-Json
        foreach ($p in $json.PSObject.Properties) { $script:State[$p.Name] = $p.Value }
    }
}

function Save-State {
    New-Object PSObject -Property $script:State | ConvertTo-Json | Out-File $StateFile -Encoding utf8
}

function Invoke-Step([string]$Name, [scriptblock]$Body) {
    if ($script:State[$Name] -eq 'done') { Write-Host ("  [skip] {0}" -f $Name) -ForegroundColor DarkGray; return }
    Write-Host ("  [step] {0}" -f $Name) -ForegroundColor Cyan
    $t = [Diagnostics.Stopwatch]::StartNew()
    & $Body
    $t.Stop()
    $script:State[$Name] = 'done'
    Save-State
    Write-Host ("         {0} done in {1:n1} min" -f $Name, $t.Elapsed.TotalMinutes) -ForegroundColor Green
}

function Copy-Tree([string]$Src, [string]$Dst, [string[]]$Extra) {
    $rcArgs = @($Src, $Dst) + $Extra + @('/NFL', '/NDL', '/NJH', '/NP', '/NJS')
    robocopy @rcArgs | Out-Null
    if ($LASTEXITCODE -ge 8) { throw ("robocopy {0} -> {1} failed with {2}" -f $Src, $Dst, $LASTEXITCODE) }
}

function Run-Python([string]$ScriptName, [string[]]$PyArgs) {
    & python (Join-Path $ScriptsDir $ScriptName) @PyArgs
    if ($LASTEXITCODE -ne 0) { throw ("{0} failed with {1}" -f $ScriptName, $LASTEXITCODE) }
}

Write-Host ("Installing SOE-shaped tools root at {0}" -f $Root)
if (-not (Test-Path $Root)) { New-Item -ItemType Directory -Force $Root | Out-Null }
Load-State

Invoke-Step 'skeleton' {
    foreach ($d in @('tre', 'exe\win32', 'data', 'dsrc')) {
        New-Item -ItemType Directory -Force (Join-Path $Root $d) | Out-Null
    }
    New-Item -ItemType Directory -Force $ReposDir | Out-Null
}

Invoke-Step 'tres' {
    Copy-Tree $TreSource (Join-Path $Root 'tre') @('*.tre', '*.toc')
}

Invoke-Step 'clone-dsrc' {
    $d = Join-Path $Root 'dsrc'
    if (-not (Test-Path (Join-Path $d '.git'))) { git clone $DsrcUrl $d; if ($LASTEXITCODE -ne 0) { throw 'dsrc clone failed' } }
    git -C $d checkout $DsrcPin --quiet
    if ($LASTEXITCODE -ne 0) { throw 'dsrc pin checkout failed' }
}

Invoke-Step 'clone-serverdata' {
    $d = Join-Path $ReposDir 'serverdata'
    if (-not (Test-Path (Join-Path $d '.git'))) { git clone $ServerdataUrl $d; if ($LASTEXITCODE -ne 0) { throw 'serverdata clone failed' } }
}

Invoke-Step 'clone-payload' {
    $d = Join-Path $ReposDir 'legacy-tools-payload'
    if (-not (Test-Path (Join-Path $d '.git'))) { git clone --depth 1 $PayloadUrl $d; if ($LASTEXITCODE -ne 0) { throw 'payload clone failed' } }
}

Invoke-Step 'apps' {
    # store first, then the repo's tracked cfgs: on name collisions the
    # Release-tree cfg is the one carrying the TreeFile keys (the SOE shape
    # merges the two SwgDraftSchematicEditor.cfg copies into one file).
    # Binaries (build output, not in git) come from AppSource last.
    Copy-Tree $StoreSource $ExeDir @('/E')
    Copy-Tree $CfgSource $ExeDir @('*.cfg', '*.ini', '/IS', '/IT')
    Copy-Tree $AppSource $ExeDir @('*.exe', '*.dll', '/IS', '/IT')
}

Invoke-Step 'lay-payload' {
    $p = Join-Path $ReposDir 'legacy-tools-payload'
    Copy-Tree (Join-Path $p 'data') $DataDir @('/E')
    Copy-Tree (Join-Path $p 'exe') (Join-Path $Root 'exe') @('/E')
}

Invoke-Step 'lay-serverdata' {
    # /XC /XN /XO: never overwrite - the payload's copies win the 41 known conflicts
    Copy-Tree (Join-Path $ReposDir 'serverdata') (Join-Path $DataDir 'sku.0\sys.client\compiled\game') @('/E', '/XC', '/XN', '/XO', '/XD', '.git', '/XF', 'README.md')
}

Invoke-Step 'override' {
    Copy-Tree $OverrideSource (Join-Path $DataDir 'override') @('/E')
    $ceeRoot = Join-Path $DataDir 'override-cee'
    $ceeTarget = Join-Path $DataDir 'sku.0\sys.client\compiled\game\clienteffect'
    New-Item -ItemType Directory -Force $ceeRoot | Out-Null
    New-Item -ItemType Directory -Force $ceeTarget | Out-Null
    $junction = Join-Path $ceeRoot 'clienteffect'
    if (-not (Test-Path $junction)) {
        New-Item -ItemType Junction -Path $junction -Target $ceeTarget | Out-Null
    }
}

Invoke-Step 'relativize-cfgs' {
    Run-Python 'relativize_cfgs.py' @($ExeDir)
}

Invoke-Step 'materialize-class-b' {
    Run-Python 'materialize_class_b.py' @($Root)
}

Invoke-Step 'rebuild-compiled' {
    Run-Python 'rebuild_compiled_data.py' @($Root)
}

Invoke-Step 'crc-tables' {
    Run-Python 'build_object_crc_tables.py' @($Root)
    Push-Location $ExeDir
    try {
        & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ExeDir 'BuildQuestCrcStringTables.ps1') -Root ($Root -replace '\\', '/')
        if ($LASTEXITCODE -ne 0) { throw 'quest CRC build failed' }
    }
    finally { Pop-Location }
}

if (-not $SkipSmoke) {
    Write-Host '  [step] smoke (16 editors, ~10 min)' -ForegroundColor Cyan
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ExeDir '_smoke-auto.ps1') -WaitSeconds 30
}

Write-Host 'Install complete.' -ForegroundColor Green
