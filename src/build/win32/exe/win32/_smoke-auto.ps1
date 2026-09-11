# Non-interactive editor launch smoke.
#   .\_smoke-auto.ps1                 # all 16
#   .\_smoke-auto.ps1 -Only Particle  # substring filter
param([string]$Only = "", [int]$WaitSeconds = 14)

$ErrorActionPreference = "Continue"
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $dir

Add-Type @"
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public class Win32Enum {
    delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc cb, IntPtr p);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassNameW(IntPtr h, StringBuilder s, int n);
    public static string[] ForPid(uint want) {
        var found = new List<string>();
        EnumWindows(delegate(IntPtr h, IntPtr l) {
            uint pid; GetWindowThreadProcessId(h, out pid);
            if (pid == want && IsWindowVisible(h)) {
                var t = new StringBuilder(512); GetWindowTextW(h, t, 512);
                var c = new StringBuilder(256); GetClassNameW(h, c, 256);
                found.Add(c.ToString() + " | " + t.ToString());
            }
            return true;
        }, IntPtr.Zero);
        return found.ToArray();
    }
}
"@

$editors = @(
    "SwgGodClient_r.exe", "TerrainEditor_r.exe", "UIBuilder.exe", "ParticleEditor_r.exe",
    "AnimationEditor_r.exe", "LightningEditor_r.exe", "SwooshEditor_r.exe", "NpcEditor_r.exe",
    "SoundEditor_r.exe", "ClientEffectEditor_r.exe", "QuestEditor_r.exe", "ShipComponentEditor_r.exe",
    "SwgConversationEditor_r.exe", "SwgDraftSchematicEditor.exe", "SwgSpaceQuestEditor_r.exe",
    "SwgSpaceZoneEditor_r.exe"
)
if ($Only) { $editors = $editors | Where-Object { $_ -like "*$Only*" } }

$logDir  = Join-Path $dir "logs"
$keepDir = Join-Path $logDir "_smoke"
New-Item -ItemType Directory -Force -Path $keepDir | Out-Null
$crashDir = Join-Path $logDir "crash"
$out = Join-Path $dir "_smoke-results.csv"

$results = @()
$i = 0
foreach ($exe in $editors) {
    $i++
    $name = [IO.Path]::GetFileNameWithoutExtension($exe)
    Write-Host ""
    Write-Host ("[{0}/{1}] {2}" -f $i, $editors.Count, $exe) -ForegroundColor Cyan

    $warn = Join-Path $logDir "warning.log"
    if (Test-Path $warn) { Remove-Item $warn -Force -ErrorAction SilentlyContinue }
    $crashBefore = @()
    if (Test-Path $crashDir) { $crashBefore = @(Get-ChildItem $crashDir -File | Select-Object -ExpandProperty Name) }

    $alive=$false; $titles=""; $exitCode=""; $lifeSec=""; $verdict=""; $note=""
    try {
        $proc = Start-Process -FilePath (Join-Path $dir $exe) -WorkingDirectory $dir -PassThru -ErrorAction Stop
    } catch {
        $results += [pscustomobject]@{ Editor=$exe; Alive=$false; Verdict="x"; Windows=""; ExitCode=""; LifeSec=""; Note=("launch failed: " + $_.Exception.Message) }
        $results | Export-Csv -NoTypeInformation -Path $out
        continue
    }

    $deadline = $WaitSeconds
    for ($s = 0; $s -lt $deadline; $s++) {
        Start-Sleep -Seconds 1
        $proc.Refresh()
        if ($proc.HasExited) { break }
    }

    $proc.Refresh()
    if (-not $proc.HasExited) {
        $alive = $true
        $w = @(); try { $w = [Win32Enum]::ForPid([uint32]$proc.Id) } catch {}
        $titles = ($w -join " ;; ")
        Write-Host ("      ALIVE  windows: {0}" -f $titles) -ForegroundColor Green
    } else {
        $exitCode = $proc.ExitCode
        $lifeSec  = [math]::Round(($proc.ExitTime - $proc.StartTime).TotalSeconds, 1)
        Write-Host ("      EXITED after {0}s, exit code {1} (0x{1:X8})" -f $lifeSec, $exitCode) -ForegroundColor Yellow
    }

    # capture this tool's warning log before the next run truncates it
    if (Test-Path $warn) { Copy-Item $warn (Join-Path $keepDir ($name + ".warning.log")) -Force }
    $fatal = ""
    if (Test-Path $warn) {
        $f = Select-String -Path $warn -Pattern "FATAL" -SimpleMatch -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($f) { $fatal = $f.Line.Trim() }
    }
    $crashNew = @()
    if (Test-Path $crashDir) {
        $crashNew = @(Get-ChildItem $crashDir -File | Where-Object { $crashBefore -notcontains $_.Name } | Select-Object -ExpandProperty Name)
    }

    # verdict -- score on window TITLES, not window class.
    # #32770 is NOT proof of a complaint: MFC dialog-based apps (UIBuilder) have it
    # as their MAIN window. And Qt error boxes are class QWidget, not #32770.
    $errRe  = "Critical Error|Errors in |not properly configured|not running from|Cannot open|invalid"
    $hasApp = ($titles -match "Afx:") -or ($titles -match "QWidget")
    $onlyDlg = $alive -and ($titles -notmatch "Afx:") -and ($titles -notmatch "QWidget")

    if ($fatal)                    { $verdict = "x"; $note = "FATAL: $fatal" }
    elseif ($crashNew.Count -gt 0) { $verdict = "x"; $note = "crash artifact: " + ($crashNew -join ",") }
    elseif (-not $alive)           { $verdict = "x"; $note = "exited early, code $exitCode" }
    elseif ($titles -match $errRe) { $verdict = "c"; $note = "error/config dialog: $titles" }
    elseif ($onlyDlg)              { $verdict = "?"; $note = "dialog-only at ${WaitSeconds}s - dismiss it and re-check with _shot2.ps1: $titles" }
    elseif ($hasApp)               { $verdict = "w" }
    else                           { $verdict = "?"; $note = "alive, unrecognised windows: $titles" }

    Write-Host ("      => {0}  {1}" -f $verdict, $note) -ForegroundColor Magenta

    if ($alive) {
        try { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue } catch {}
        Start-Sleep -Milliseconds 800
    }

    $results += [pscustomobject]@{ Editor=$exe; Alive=$alive; Verdict=$verdict; Windows=$titles; ExitCode=$exitCode; LifeSec=$lifeSec; Note=$note }
    $results | Export-Csv -NoTypeInformation -Path $out
}

Write-Host ""
Write-Host ("results -> " + $out) -ForegroundColor Cyan
$results | Format-Table Editor, Verdict, Alive, ExitCode, LifeSec, Note -AutoSize
