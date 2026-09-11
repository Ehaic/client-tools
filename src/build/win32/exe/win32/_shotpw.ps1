# Capture a window's OWN pixels via PrintWindow - never grabs other windows,
# so it cannot capture unrelated desktop content and does not need foreground.
param([Parameter(Mandatory=$true)][string]$Exe, [int]$Wait = 25)
$ErrorActionPreference = "Continue"
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $dir
$OutDir = Join-Path $dir "logs\_shots"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System; using System.Text; using System.Collections.Generic; using System.Runtime.InteropServices;
public struct R6 { public int Left, Top, Right, Bottom; }
public class W6 {
  delegate bool EP(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] static extern bool EnumWindows(EP cb, IntPtr p);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassNameW(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out R6 r);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
  [DllImport("user32.dll")] public static extern IntPtr SendMessageW(IntPtr h, uint m, IntPtr w, IntPtr l);
  public static List<IntPtr> ForPid(uint want){ var f=new List<IntPtr>(); EnumWindows(delegate(IntPtr h, IntPtr l){ uint pid; GetWindowThreadProcessId(h,out pid); if(pid==want && IsWindowVisible(h)) f.Add(h); return true; }, IntPtr.Zero); return f; }
  public static string T(IntPtr h){ var s=new StringBuilder(512); GetWindowTextW(h,s,512); return s.ToString(); }
  public static string C(IntPtr h){ var s=new StringBuilder(256); GetClassNameW(h,s,256); return s.ToString(); }
  public static void Close(IntPtr h){ SendMessageW(h, 0x0010, IntPtr.Zero, IntPtr.Zero); }
}
"@
$name = [IO.Path]::GetFileNameWithoutExtension($Exe)
$p = Start-Process -FilePath (Join-Path $dir $Exe) -WorkingDirectory $dir -PassThru
Start-Sleep -Seconds $Wait
for ($i=0; $i -lt 5; $i++) {
  $p.Refresh(); if ($p.HasExited) { Write-Host "  EXITED code $($p.ExitCode)"; exit 1 }
  $d = @([W6]::ForPid([uint32]$p.Id) | Where-Object { [W6]::C($_) -eq "#32770" })
  if ($d.Count -eq 0) { break }
  foreach ($x in $d) { Write-Host ("  dismiss: '{0}'" -f [W6]::T($x)); [W6]::Close($x) }
  Start-Sleep -Seconds 3
}
$n = 0
foreach ($h in [W6]::ForPid([uint32]$p.Id)) {
  $n++
  $r = New-Object R6; [void][W6]::GetWindowRect($h, [ref]$r)
  $w=$r.Right-$r.Left; $ht=$r.Bottom-$r.Top; if ($w -le 0 -or $ht -le 0) { continue }
  $b = New-Object System.Drawing.Bitmap($w,$ht)
  $g = [System.Drawing.Graphics]::FromImage($b)
  $hdc = $g.GetHdc()
  [void][W6]::PrintWindow($h, $hdc, 2)   # PW_RENDERFULLCONTENT
  $g.ReleaseHdc($hdc)
  $f = Join-Path $OutDir ("{0}_pw{1}.png" -f $name, $n)
  $b.Save($f); $g.Dispose(); $b.Dispose()
  Write-Host ("  '{0}' [{1}] {2}x{3} -> {4}" -f [W6]::T($h), [W6]::C($h), $w, $ht, $f)
}
Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
