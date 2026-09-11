# Launch, dismiss any modal #32770 dialogs, then screenshot what is left.
param([Parameter(Mandatory=$true)][string]$Exe, [int]$Wait = 20, [int]$After = 12)
$ErrorActionPreference = "Continue"
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $dir
$OutDir = Join-Path $dir "logs\_shots"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public struct RECT2 { public int Left, Top, Right, Bottom; }
public class Shot2 {
    delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc cb, IntPtr p);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassNameW(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT2 r);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr PostMessageW(IntPtr h, uint msg, IntPtr wp, IntPtr lp);
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
    public static void ClickOk(IntPtr h) { PostMessageW(h, 0x0111, (IntPtr)1, IntPtr.Zero); }  // WM_COMMAND IDOK
}
"@
$name = [IO.Path]::GetFileNameWithoutExtension($Exe)
$proc = Start-Process -FilePath (Join-Path $dir $Exe) -WorkingDirectory $dir -PassThru
Start-Sleep -Seconds $Wait
$proc.Refresh()
if ($proc.HasExited) { Write-Host ("EXITED code {0}" -f $proc.ExitCode) -ForegroundColor Yellow; exit 1 }

foreach ($h in [Shot2]::ForPid([uint32]$proc.Id)) {
    if ([Shot2]::ClassOf($h) -eq "#32770") {
        Write-Host ("  dismissing: '{0}'" -f [Shot2]::TextOf($h)) -ForegroundColor DarkGray
        [void][Shot2]::BringWindowToTop($h)
        [void][Shot2]::SetForegroundWindow($h)
        Start-Sleep -Milliseconds 600
        [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
        Start-Sleep -Milliseconds 600
    }
}
Start-Sleep -Seconds $After
$proc.Refresh()
if ($proc.HasExited) { Write-Host ("EXITED after dismiss, code {0}" -f $proc.ExitCode) -ForegroundColor Yellow; exit 1 }

$n = 0
foreach ($h in [Shot2]::ForPid([uint32]$proc.Id)) {
    $n++
    [void][Shot2]::BringWindowToTop($h); [void][Shot2]::SetForegroundWindow($h)
    Start-Sleep -Milliseconds 700
    $r = New-Object RECT2
    [void][Shot2]::GetWindowRect($h, [ref]$r)
    $w = $r.Right - $r.Left; $ht = $r.Bottom - $r.Top
    if ($w -le 0 -or $ht -le 0) { continue }
    $bmp = New-Object System.Drawing.Bitmap($w, $ht)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($r.Left, $r.Top, 0, 0, $bmp.Size)
    $png = Join-Path $OutDir ("{0}_post{1}.png" -f $name, $n)
    $bmp.Save($png, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
    Write-Host ("  '{0}' [{1}] [{2}x{3}] -> {4}" -f [Shot2]::TextOf($h), [Shot2]::ClassOf($h), $w, $ht, $png) -ForegroundColor Cyan
}
Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
