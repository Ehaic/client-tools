# Drive AnimationEditor past launch.
#   File menu has NO accelerators, so navigate by arrows:
#     1 Open Shared Creature Template   2 New Ash   3 New Lat
#     4 Open...   5 Open Target ASH(s)  6 Open target LAT(s)  7 Close  8 Save
#   Open Target ASH/LAT act on networkScene->getPlayer(), so they need no file
#   dialog and no TreeFile path mapping (MainWindow.cpp openTargetLatFiles).
param([int]$Boot = 35)
$ErrorActionPreference = "Continue"
$dir = 'D:\Code\swg-qt-tools-worktree\src\build\win32\x64\Release'
$OutDir = Join-Path $dir 'logs\_shots'
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System; using System.Text; using System.Collections.Generic; using System.Runtime.InteropServices;
public struct RECT5 { public int Left, Top, Right, Bottom; }
public class Anm {
    delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc cb, IntPtr p);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassNameW(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT5 r);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    public static List<IntPtr> ForPid(uint want) {
        var f = new List<IntPtr>();
        EnumWindows(delegate(IntPtr h, IntPtr l) { uint pid; GetWindowThreadProcessId(h, out pid);
            if (pid == want && IsWindowVisible(h)) f.Add(h); return true; }, IntPtr.Zero);
        return f;
    }
    public static string TextOf(IntPtr h) { var t = new StringBuilder(512); GetWindowTextW(h, t, 512); return t.ToString(); }
    public static string ClassOf(IntPtr h) { var t = new StringBuilder(256); GetClassNameW(h, t, 256); return t.ToString(); }
}
"@
function Shot([IntPtr]$h, [string]$tag) {
    $r = New-Object RECT5; [void][Anm]::GetWindowRect($h, [ref]$r)
    $w = $r.Right-$r.Left; $ht = $r.Bottom-$r.Top
    if ($w -le 0 -or $ht -le 0) { return $null }
    $bmp = New-Object System.Drawing.Bitmap($w,$ht); $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($r.Left,$r.Top,0,0,$bmp.Size)
    $png = Join-Path $OutDir ("AnimationEditor_{0}.png" -f $tag)
    $bmp.Save($png,[System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()
    return $png
}
function ListWins([int]$thePid) {
    foreach ($h in [Anm]::ForPid([uint32]$thePid)) { Write-Host ("    [{0}] '{1}'" -f [Anm]::ClassOf($h), [Anm]::TextOf($h)) }
}
function MenuPick([IntPtr]$main, [int]$downs, [string]$what) {
    [void][Anm]::BringWindowToTop($main); [void][Anm]::SetForegroundWindow($main)
    Start-Sleep -Milliseconds 1000
    if ([Anm]::GetForegroundWindow() -ne $main) { Write-Host "  WARN: main window not focused, skipping $what" -ForegroundColor Yellow; return }
    Write-Host ("  menu: File -> {0} (Down x{1})" -f $what, $downs)
    [System.Windows.Forms.SendKeys]::SendWait("%f")
    Start-Sleep -Milliseconds 1200
    for ($i=0; $i -lt $downs; $i++) { [System.Windows.Forms.SendKeys]::SendWait("{DOWN}"); Start-Sleep -Milliseconds 250 }
    [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
    Start-Sleep -Seconds 6
}

$warn = Join-Path $dir 'logs\warning.log'
$before = if (Test-Path $warn) { (Get-Item $warn).LastWriteTime } else { [datetime]::MinValue }

$p = Start-Process -FilePath (Join-Path $dir 'AnimationEditor_r.exe') -WorkingDirectory $dir -PassThru
Start-Sleep -Seconds $Boot
$p.Refresh()
if ($p.HasExited) { Write-Host ("EXITED during boot, code 0x{0:X8}" -f $p.ExitCode) -ForegroundColor Red; exit 1 }
Write-Host "-- windows after boot --"; ListWins $p.Id

$main = $null; $best = 0
foreach ($h in [Anm]::ForPid([uint32]$p.Id)) {
    $r = New-Object RECT5; [void][Anm]::GetWindowRect($h, [ref]$r)
    $a = ($r.Right-$r.Left)*($r.Bottom-$r.Top)
    if ($a -gt $best) { $best = $a; $main = $h }
}
Write-Host ("main window: '{0}'" -f [Anm]::TextOf($main))
[void][Anm]::BringWindowToTop($main); [void][Anm]::SetForegroundWindow($main); Start-Sleep -Milliseconds 1200
Write-Host ("shot: {0}" -f (Shot $main 'a-boot'))

MenuPick $main 6 'Open target LAT(s)'
Write-Host "-- after LAT --"; ListWins $p.Id
Write-Host ("shot: {0}" -f (Shot $main 'b-lat'))

MenuPick $main 5 'Open Target ASH(s)'
Write-Host "-- after ASH --"; ListWins $p.Id
Write-Host ("shot: {0}" -f (Shot $main 'c-ash'))

$p.Refresh()
if ($p.HasExited) { Write-Host ("EXITED, code 0x{0:X8}" -f $p.ExitCode) -ForegroundColor Red; exit 1 }
if ((Test-Path $warn) -and ((Get-Item $warn).LastWriteTime -gt $before)) {
    Copy-Item $warn (Join-Path $dir 'logs\warning.animationeditor-drive.log') -Force
    Write-Host "-- warning.log hits --"
    $f = Select-String -Path $warn -Pattern 'FATAL','Failed to get the player','Could not get the NetworkScene','not mappable'
    if ($f) { $f | Select-Object -First 12 | ForEach-Object { Write-Host ("    " + $_.Line.Trim()) } } else { Write-Host "    none" }
}
Write-Host "ALIVE - left running; PID $($p.Id)"
