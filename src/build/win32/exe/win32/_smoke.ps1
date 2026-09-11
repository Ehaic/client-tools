# Editor launch smoke. Run from this directory:  .\_smoke.ps1
# Launches each editor in priority order, waits, reports, and lets you score it.
$ErrorActionPreference = "Continue"
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $dir
$out = Join-Path $dir "_smoke-results.csv"

$editors = @(
    "SwgGodClient_r.exe", "TerrainEditor_r.exe", "UIBuilder.exe", "ParticleEditor_r.exe",
    "AnimationEditor_r.exe", "LightningEditor_r.exe", "SwooshEditor_r.exe", "NpcEditor_r.exe",
    "SoundEditor_r.exe", "ClientEffectEditor_r.exe", "QuestEditor_r.exe", "ShipComponentEditor_r.exe",
    "SwgConversationEditor_r.exe", "SwgDraftSchematicEditor.exe", "SwgSpaceQuestEditor_r.exe",
    "SwgSpaceZoneEditor_r.exe"
)

$results = @()
$i = 0
foreach ($exe in $editors) {
    $i++
    Write-Host ""
    Write-Host ("[{0}/{1}] launching {2}" -f $i, $editors.Count, $exe) -ForegroundColor Cyan
    $proc = Start-Process -FilePath (Join-Path $dir $exe) -WorkingDirectory $dir -PassThru
    Start-Sleep -Seconds 8

    $alive = $false; $title = ""; $exitCode = ""
    $proc.Refresh()
    if (-not $proc.HasExited) {
        $alive = $true
        $title = $proc.MainWindowTitle
        Write-Host ("      ALIVE   window title: '{0}'" -f $title) -ForegroundColor Green
    } else {
        $exitCode = $proc.ExitCode
        Write-Host ("      EXITED  after {0:N1}s, exit code {1}" -f ($proc.ExitTime - $proc.StartTime).TotalSeconds, $exitCode) -ForegroundColor Yellow
    }

    $score = Read-Host "      score [w]indow / [c]onfig-complaint / [x]crash / [s]kip, then Enter"
    $note  = Read-Host "      note (dialog text if any, or blank)"

    $proc.Refresh()
    if (-not $proc.HasExited) {
        Write-Host "      (close it when you're done looking; press Enter to continue)" -ForegroundColor DarkGray
        Read-Host | Out-Null
        $proc.Refresh()
        if (-not $proc.HasExited) { Write-Host "      still running - leaving it open" -ForegroundColor DarkGray }
    }

    $results += [pscustomobject]@{ Editor=$exe; Alive8s=$alive; WindowTitle=$title; ExitCode=$exitCode; Score=$score; Note=$note }
    $results | Export-Csv -NoTypeInformation -Path $out
}

Write-Host ""
Write-Host "done. results -> $out" -ForegroundColor Cyan
$results | Format-Table -AutoSize
