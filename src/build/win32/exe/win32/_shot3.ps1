# Launch, dismiss stacked #32770 message boxes via WM_CLOSE, screenshot the real frame.
param([Parameter(Mandatory=$true)][string]$Exe, [int]$Wait = 18, [int]$Rounds = 6)
$ErrorActionPreference = "Continue"
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $dir
$OutDir = Join-Path $dir "logs\_shots"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System; using System.Text; using System.Collections.Generic; using System.Runtime.InteropServices;
public struct R5 { public int Left, Top, Right, Bottom; }
public class W5 {
  delegate bool EP(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] static extern bool EnumWindows(EP cb, IntPtr p);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassNameW(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out R5 r);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
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
for ($i=1; $i -le $Rounds; $i++) {
  $p.Refresh(); if ($p.HasExited) { Write-Host "  EXITED code $($p.ExitCode)"; exit 1 }
  $ws = [W5]::ForPid([uint32]$p.Id)
  $dlg = @($ws | Where-Object { [W5]::C($_) -eq "#32770" })
  if ($dlg.Count -eq 0) { break }
  foreach ($d in $dlg) { Write-Host ("  dismiss: '{0}'" -f [W5]::T($d)); [W5]::Close($d) }
  Start-Sleep -Seconds 3
}
$p.Refresh()
if ($p.HasExited) { Write-Host "  EXITED after dismiss, code $($p.ExitCode)"; exit 1 }
foreach ($h in [W5]::ForPid([uint32]$p.Id)) {
  [void][W5]::ShowWindow($h, 3)   # SW_MAXIMIZE
  [void][W5]::BringWindowToTop($h); [void][W5]::SetForegroundWindow($h)
  Start-Sleep -Seconds 2
  $r = New-Object R5; [void][W5]::GetWindowRect($h, [ref]$r)
  $w=$r.Right-$r.Left; $ht=$r.Bottom-$r.Top; if ($w -le 0 -or $ht -le 0) { continue }
  $b = New-Object System.Drawing.Bitmap($w,$ht); $g=[System.Drawing.Graphics]::FromImage($b)
  $g.CopyFromScreen($r.Left,$r.Top,0,0,$b.Size)
  $f = Join-Path $OutDir ($name + "_configured.png")
  $b.Save($f); $g.Dispose(); $b.Dispose()
  Write-Host ("  captured '{0}' [{1}] {2}x{3} -> {4}" -f [W5]::T($h), [W5]::C($h), $w, $ht, $f)
}
Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
