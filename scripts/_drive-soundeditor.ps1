# Drive SoundEditor past launch: Ctrl+O, type a .snd path, Enter, screenshot.
param(
  [string]$Snd = 'D:\SWG All Tools Working\swg\current\data\sku.0\sys.client\compiled\game\sound\music_combat_loop.snd',
  [int]$Boot = 25
)
$ErrorActionPreference = "Continue"
$dir = 'D:\Code\swg-qt-tools-worktree\src\build\win32\x64\Release'
$OutDir = Join-Path $dir 'logs\_shots'
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public struct RECT3 { public int Left, Top, Right, Bottom; }
public class Drv {
    delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc cb, IntPtr p);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassNameW(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT3 r);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    public static List<IntPtr> ForPid(uint want) {
        var found = new List<IntPtr>();
        EnumWindows(delegate(IntPtr h, IntPtr l) {
            uint pid; GetWindowThreadProcessId(h, out pid);
            if (pid == want && IsWindowVisible(h)) found.Add(h);
            return true;
        }, IntPtr.Zero);
        return found;
    }
    public static string TextOf(IntPtr h) { var t = new StringBuilder(512); GetWindowTextW(h, t, 512); return t.ToString(); }
    public static string ClassOf(IntPtr h) { var t = new StringBuilder(256); GetClassNameW(h, t, 256); return t.ToString(); }
}
"@
function Shot([IntPtr]$h, [string]$tag) {
    $r = New-Object RECT3
    [void][Drv]::GetWindowRect($h, [ref]$r)
    $w = $r.Right - $r.Left; $ht = $r.Bottom - $r.Top
    if ($w -le 0 -or $ht -le 0) { return $null }
    $bmp = New-Object System.Drawing.Bitmap($w, $ht)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($r.Left, $r.Top, 0, 0, $bmp.Size)
    $png = Join-Path $OutDir ("SoundEditor_{0}.png" -f $tag)
    $bmp.Save($png, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
    return $png
}
function Windows([int]$pid_) {
    foreach ($h in [Drv]::ForPid([uint32]$pid_)) {
        Write-Host ("    [{0}] '{1}'" -f [Drv]::ClassOf($h), [Drv]::TextOf($h))
    }
}

Write-Host ("target .snd: {0}" -f $Snd)
Write-Host ("exists: {0}" -f (Test-Path $Snd))

$p = Start-Process -FilePath (Join-Path $dir 'SoundEditor_r.exe') -WorkingDirectory $dir -PassThru
Start-Sleep -Seconds $Boot
$p.Refresh()
if ($p.HasExited) { Write-Host ("EXITED during boot, code 0x{0:X8}" -f $p.ExitCode) -ForegroundColor Red; exit 1 }
Write-Host "-- windows after boot --"; Windows $p.Id

# main window = the biggest visible one
$main = $null; $best = 0
foreach ($h in [Drv]::ForPid([uint32]$p.Id)) {
    $r = New-Object RECT3; [void][Drv]::GetWindowRect($h, [ref]$r)
    $area = ($r.Right-$r.Left) * ($r.Bottom-$r.Top)
    if ($area -gt $best) { $best = $area; $main = $h }
}
Write-Host ("main window: '{0}'" -f [Drv]::TextOf($main))
[void][Drv]::BringWindowToTop($main); [void][Drv]::SetForegroundWindow($main)
Start-Sleep -Milliseconds 1200
if ([Drv]::GetForegroundWindow() -ne $main) { Write-Host "WARN: main window did not take focus" -ForegroundColor Yellow }
$before = Shot $main 'a-before'
Write-Host ("shot: {0}" -f $before)

# Ctrl+O
[System.Windows.Forms.SendKeys]::SendWait("^o")
Start-Sleep -Seconds 3
Write-Host "-- windows after Ctrl+O --"; Windows $p.Id
$fg = [Drv]::GetForegroundWindow()
Write-Host ("foreground now: [{0}] '{1}'" -f [Drv]::ClassOf($fg), [Drv]::TextOf($fg))
$dlg = Shot $fg 'b-dialog'
Write-Host ("shot: {0}" -f $dlg)

# type the path and accept
[System.Windows.Forms.SendKeys]::SendWait($Snd)
Start-Sleep -Milliseconds 900
[System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
Start-Sleep -Seconds 6
$p.Refresh()
if ($p.HasExited) { Write-Host ("EXITED after open, code 0x{0:X8}" -f $p.ExitCode) -ForegroundColor Red; exit 1 }
Write-Host "-- windows after open --"; Windows $p.Id

[void][Drv]::BringWindowToTop($main); [void][Drv]::SetForegroundWindow($main)
Start-Sleep -Seconds 2
$after = Shot $main 'c-after'
Write-Host ("shot: {0}" -f $after)
foreach ($h in [Drv]::ForPid([uint32]$p.Id)) {
    if ($h -ne $main) { $x = Shot $h ("d-extra-" + $h.ToString()); Write-Host ("extra shot: {0}  '{1}'" -f $x, [Drv]::TextOf($h)) }
}
Write-Host "ALIVE - leaving it running for inspection; PID $($p.Id)"
