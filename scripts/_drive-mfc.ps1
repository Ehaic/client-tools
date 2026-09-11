# Drive an MFC tool: launch, dismiss every startup dialog, File>Open, type path.
#   MFC Swg* tools show one or two structural warning dialogs before the frame is
#   usable, and those are modal - they swallow any keys sent before dismissal.
param(
  [Parameter(Mandatory=$true)][string]$Exe,
  [Parameter(Mandatory=$true)][string]$Path,
  [string]$OpenKeys = '%f',          # menu to raise, then $OpenItem
  [string]$OpenItem = 'o',
  [int]$Boot = 25,
  [int]$After = 30,
  [switch]$Keep
)
$ErrorActionPreference = 'Continue'
$dir = 'D:\Code\swg-qt-tools-worktree\src\build\win32\x64\Release'
$out = Join-Path $dir 'logs\_shots'
New-Item -ItemType Directory -Force -Path $out | Out-Null
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System; using System.Text; using System.Collections.Generic; using System.Runtime.InteropServices;
public struct RECTM { public int Left, Top, Right, Bottom; }
public class Mfc {
    delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc cb, IntPtr p);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassNameW(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECTM r);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
    public static List<IntPtr> ForPid(uint w) { var f=new List<IntPtr>();
      EnumWindows(delegate(IntPtr h, IntPtr l){ uint p; GetWindowThreadProcessId(h,out p);
        if(p==w && IsWindowVisible(h)) f.Add(h); return true; }, IntPtr.Zero); return f; }
    public static string T(IntPtr h){ var s=new StringBuilder(512); GetWindowTextW(h,s,512); return s.ToString(); }
    public static string C(IntPtr h){ var s=new StringBuilder(256); GetClassNameW(h,s,256); return s.ToString(); }
}
"@
$name = [IO.Path]::GetFileNameWithoutExtension($Exe)
function Shot([IntPtr]$h,[string]$tag){
  $r=New-Object RECTM; [void][Mfc]::GetWindowRect($h,[ref]$r)
  $w=$r.Right-$r.Left; $ht=$r.Bottom-$r.Top
  if($w -le 0 -or $ht -le 0){ return $null }
  $b=New-Object System.Drawing.Bitmap($w,$ht); $g=[System.Drawing.Graphics]::FromImage($b)
  $g.CopyFromScreen($r.Left,$r.Top,0,0,$b.Size)
  $p=Join-Path $out ("{0}_{1}.png" -f $name,$tag)
  $b.Save($p,[System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $b.Dispose(); return $p
}
function Frame([int]$thePid){ [Mfc]::ForPid([uint32]$thePid) | Where-Object { [Mfc]::C($_) -like 'Afx*' } | Select-Object -First 1 }

Write-Host ("=== {0} <- {1}" -f $Exe,$Path) -ForegroundColor Cyan
Write-Host ("file exists: {0}" -f (Test-Path $Path))
Get-Process ([IO.Path]::GetFileNameWithoutExtension($Exe)) -ErrorAction SilentlyContinue | Stop-Process -Force
$warn = Join-Path $dir 'logs\warning.log'
$before = if (Test-Path $warn) { (Get-Item $warn).LastWriteTime } else { [datetime]::MinValue }

$p = Start-Process -FilePath (Join-Path $dir $Exe) -WorkingDirectory $dir -PassThru
Start-Sleep -Seconds $Boot
$p.Refresh(); if($p.HasExited){ Write-Host ("EXITED during boot 0x{0:X8}" -f $p.ExitCode) -ForegroundColor Red; exit 1 }

# dismiss every modal startup dialog
for ($round=0; $round -lt 6; $round++) {
  $dlg = [Mfc]::ForPid([uint32]$p.Id) | Where-Object { [Mfc]::C($_) -eq '#32770' } | Select-Object -First 1
  if (-not $dlg) { break }
  Write-Host ("  dismissing: '{0}'" -f [Mfc]::T($dlg)) -ForegroundColor DarkGray
  [void][Mfc]::BringWindowToTop($dlg); [void][Mfc]::SetForegroundWindow($dlg)
  Start-Sleep -Milliseconds 700
  [System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
  Start-Sleep -Milliseconds 900
}

$main = Frame $p.Id
if (-not $main) { Write-Host "no MFC frame" -ForegroundColor Red; Stop-Process -Id $p.Id -Force; exit 1 }
[void][Mfc]::ShowWindow($main,3); [void][Mfc]::BringWindowToTop($main); [void][Mfc]::SetForegroundWindow($main)
Start-Sleep -Milliseconds 1200
Write-Host ("boot shot: {0}" -f (Shot $main 'm1-boot'))

[System.Windows.Forms.SendKeys]::SendWait($OpenKeys); Start-Sleep -Milliseconds 900
[System.Windows.Forms.SendKeys]::SendWait($OpenItem)
$dlg=$null
for ($i=0; $i -lt 20; $i++) {
  Start-Sleep -Milliseconds 700
  $dlg = [Mfc]::ForPid([uint32]$p.Id) | Where-Object { [Mfc]::C($_) -eq '#32770' } | Select-Object -First 1
  if ($dlg) { break }
}
if (-not $dlg) { Write-Host "no Open dialog appeared" -ForegroundColor Yellow; Write-Host ("shot: {0}" -f (Shot $main 'm2-nodialog')); if(-not $Keep){Stop-Process -Id $p.Id -Force}; exit 2 }
Write-Host ("  open dialog: '{0}'" -f [Mfc]::T($dlg))
[void][Mfc]::BringWindowToTop($dlg); [void][Mfc]::SetForegroundWindow($dlg); Start-Sleep -Milliseconds 800
[System.Windows.Forms.SendKeys]::SendWait($Path)
Start-Sleep -Milliseconds 900
[System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
Start-Sleep -Seconds $After
$p.Refresh(); if($p.HasExited){ Write-Host ("EXITED after open 0x{0:X8}" -f $p.ExitCode) -ForegroundColor Red }
else {
  foreach($h in [Mfc]::ForPid([uint32]$p.Id)){ Write-Host ("    [{0}] '{1}'" -f [Mfc]::C($h),[Mfc]::T($h)) }
  $main = Frame $p.Id
  if ($main) { [void][Mfc]::SetForegroundWindow($main); Start-Sleep -Seconds 2; Write-Host ("after shot: {0}" -f (Shot $main 'm3-after')) }
}
if ((Test-Path $warn) -and ((Get-Item $warn).LastWriteTime -gt $before)) {
  Copy-Item $warn (Join-Path $dir ("logs\warning." + $name + "-drive.log")) -Force
  $f = Select-String -Path $warn -Pattern 'FATAL','not found','not mappable'
  if ($f) { Write-Host "-- log hits --"; $f | Select-Object -First 8 | ForEach-Object { Write-Host ("    "+$_.Line.Trim()) } }
}
if ($Keep) { Write-Host ("LEFT RUNNING pid {0}" -f $p.Id) -ForegroundColor Green }
else { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
