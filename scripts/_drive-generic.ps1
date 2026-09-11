# Generic "open a file" driver for the Qt tools.
#   -Exe   tool exe name in the Release dir
#   -Path  absolute file to open
#   -Keys  keystroke that raises the open dialog (default ^o)
#   -Boot  seconds to wait for the main window
param(
  [Parameter(Mandatory=$true)][string]$Exe,
  [Parameter(Mandatory=$true)][string]$Path,
  [string]$Keys = "^o",
  [int]$Boot = 25,
  [int]$After = 8,
  [switch]$Keep
)
$ErrorActionPreference = "Continue"
$dir = 'D:\Code\swg-qt-tools-worktree\src\build\win32\x64\Release'
$OutDir = Join-Path $dir 'logs\_shots'
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System; using System.Text; using System.Collections.Generic; using System.Runtime.InteropServices;
public struct RECTG { public int Left, Top, Right, Bottom; }
public class Gen {
    delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc cb, IntPtr p);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassNameW(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECTG r);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
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
$name = [IO.Path]::GetFileNameWithoutExtension($Exe)
function Shot([IntPtr]$h,[string]$tag) {
    $r = New-Object RECTG; [void][Gen]::GetWindowRect($h,[ref]$r)
    $w=$r.Right-$r.Left; $ht=$r.Bottom-$r.Top
    if ($w -le 0 -or $ht -le 0) { return $null }
    $b = New-Object System.Drawing.Bitmap($w,$ht); $g=[System.Drawing.Graphics]::FromImage($b)
    $g.CopyFromScreen($r.Left,$r.Top,0,0,$b.Size)
    $p = Join-Path $OutDir ("{0}_{1}.png" -f $name,$tag)
    $b.Save($p,[System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $b.Dispose(); return $p
}
function Wins([int]$thePid){ foreach($h in [Gen]::ForPid([uint32]$thePid)){ Write-Host ("    [{0}] '{1}'" -f [Gen]::ClassOf($h),[Gen]::TextOf($h)) } }

Write-Host ("=== {0} <- {1}" -f $Exe, $Path) -ForegroundColor Cyan
Write-Host ("file exists: {0}" -f (Test-Path $Path))
$warn = Join-Path $dir 'logs\warning.log'
$before = if (Test-Path $warn) { (Get-Item $warn).LastWriteTime } else { [datetime]::MinValue }

$p = Start-Process -FilePath (Join-Path $dir $Exe) -WorkingDirectory $dir -PassThru
Start-Sleep -Seconds $Boot
$p.Refresh()
if ($p.HasExited) { Write-Host ("EXITED during boot 0x{0:X8}" -f $p.ExitCode) -ForegroundColor Red; exit 1 }
Write-Host "-- after boot --"; Wins $p.Id
$main=$null; $best=0
foreach($h in [Gen]::ForPid([uint32]$p.Id)){ $r=New-Object RECTG; [void][Gen]::GetWindowRect($h,[ref]$r)
  $a=($r.Right-$r.Left)*($r.Bottom-$r.Top); if($a -gt $best){$best=$a;$main=$h} }
[void][Gen]::ShowWindow($main,9); [void][Gen]::BringWindowToTop($main); [void][Gen]::SetForegroundWindow($main)
Start-Sleep -Milliseconds 1200
Write-Host ("boot shot: {0}" -f (Shot $main 'g1-boot'))

if ([Gen]::GetForegroundWindow() -ne $main) { Write-Host "WARN: main not focused" -ForegroundColor Yellow }
[System.Windows.Forms.SendKeys]::SendWait($Keys)
Start-Sleep -Seconds 3
Write-Host "-- after open-keys --"; Wins $p.Id
$fg=[Gen]::GetForegroundWindow()
Write-Host ("foreground: [{0}] '{1}'" -f [Gen]::ClassOf($fg),[Gen]::TextOf($fg))
Write-Host ("dialog shot: {0}" -f (Shot $fg 'g2-dialog'))

[System.Windows.Forms.SendKeys]::SendWait($Path)
Start-Sleep -Milliseconds 900
[System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
Start-Sleep -Seconds $After
$p.Refresh()
if ($p.HasExited) { Write-Host ("EXITED after open 0x{0:X8}" -f $p.ExitCode) -ForegroundColor Red; exit 1 }
Write-Host "-- after open --"; Wins $p.Id
[void][Gen]::BringWindowToTop($main); [void][Gen]::SetForegroundWindow($main); Start-Sleep -Seconds 1
Write-Host ("after shot: {0}" -f (Shot $main 'g3-after'))
foreach($h in [Gen]::ForPid([uint32]$p.Id)){ if($h -ne $main){ Write-Host ("extra: {0} '{1}'" -f (Shot $h ("g4-"+$h)), [Gen]::TextOf($h)) } }

if ((Test-Path $warn) -and ((Get-Item $warn).LastWriteTime -gt $before)) {
    Copy-Item $warn (Join-Path $dir ("logs\warning." + $name + "-drive.log")) -Force
    $f = Select-String -Path $warn -Pattern 'FATAL','not mappable','does not exist','WARNING: User'
    if ($f) { Write-Host "-- log hits --"; $f | Select-Object -First 8 | ForEach-Object { Write-Host ("    "+$_.Line.Trim()) } }
    else { Write-Host "-- no notable log lines --" }
}
if ($Keep) { Write-Host ("LEFT RUNNING pid {0}" -f $p.Id) -ForegroundColor Green }
else { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue; Write-Host "stopped" }
