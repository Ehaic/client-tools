# Launch an editor, screenshot each of its visible windows (window rect only).
#   .\_shot.ps1 -Exe QuestEditor_r.exe -Wait 20
param([Parameter(Mandatory=$true)][string]$Exe, [int]$Wait = 20)

$ErrorActionPreference = "Continue"
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $dir
$OutDir = Join-Path $dir "logs\_shots"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public struct RECT { public int Left, Top, Right, Bottom; }
public class ShotWin {
    delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc cb, IntPtr p);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
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
}
"@

$name = [IO.Path]::GetFileNameWithoutExtension($Exe)
$proc = Start-Process -FilePath (Join-Path $dir $Exe) -WorkingDirectory $dir -PassThru
Start-Sleep -Seconds $Wait
$proc.Refresh()
if ($proc.HasExited) {
    Write-Host ("{0}: EXITED code {1}" -f $Exe, $proc.ExitCode) -ForegroundColor Yellow
    exit 1
}

$wins = [ShotWin]::ForPid([uint32]$proc.Id)
$n = 0
foreach ($h in $wins) {
    $n++
    $t = [ShotWin]::TextOf($h)
    [void][ShotWin]::BringWindowToTop($h)
    [void][ShotWin]::SetForegroundWindow($h)
    Start-Sleep -Milliseconds 700
    $r = New-Object RECT
    [void][ShotWin]::GetWindowRect($h, [ref]$r)
    $w = $r.Right - $r.Left; $ht = $r.Bottom - $r.Top
    if ($w -le 0 -or $ht -le 0) { continue }
    $bmp = New-Object System.Drawing.Bitmap($w, $ht)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($r.Left, $r.Top, 0, 0, $bmp.Size)
    $png = Join-Path $OutDir ("{0}_{1}.png" -f $name, $n)
    $bmp.Save($png, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
    Write-Host ("  '{0}' [{1}x{2}] -> {3}" -f $t, $w, $ht, $png) -ForegroundColor Cyan
}
Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
