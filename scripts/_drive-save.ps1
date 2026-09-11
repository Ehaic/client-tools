# Save-path driver. Drives File>New / File>Open / File>Save As via PostMessage
# WM_COMMAND (MFC frames) and fills the native file dialog via WM_SETTEXT + IDOK,
# so it does NOT need the foreground window - safe to run while the user works.
#
#   -Exe          tool exe name in the Release dir
#   -OpenPath     if set, post OpenCmd and fill the dialog with this path
#   -SavePath     target path for File>Save As (pre-deleted so no overwrite box)
#   -NewCmd       WM_COMMAND id posted before anything (0 = skip). MFC ID_FILE_NEW = 0xE100
#   -OpenCmd      WM_COMMAND id that raises the Open dialog. MFC ID_FILE_OPEN = 0xE101
#   -SaveAsCmd    WM_COMMAND id that raises the Save As dialog. MFC ID_FILE_SAVE_AS = 0xE104
#   -QtAccel      if set, raise dialogs with guarded SendKeys instead of WM_COMMAND
#                 (Qt menus ignore posted WM_COMMAND). '^s' etc.
#   -Boot         seconds to wait for the main window
param(
  [Parameter(Mandatory=$true)][string]$Exe,
  [string]$OpenPath = '',
  [Parameter(Mandatory=$true)][string]$SavePath,
  [int]$NewCmd = 0,
  [int]$OpenCmd = 0xE101,
  [int]$SaveAsCmd = 0xE104,
  [string]$QtOpenAccel = '',
  [string]$QtSaveAccel = '',
  [switch]$NoSaveDialog,      # save cmd writes directly (e.g. ID_FILE_SAVE to config paths)
  [switch]$NoDismiss,         # main window IS a #32770 (UIBuilder) - never WM_CLOSE it
  [int]$Boot = 25,
  [int]$AfterOpen = 20,
  [int]$AfterSave = 12,
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
public struct RECTS { public int Left, Top, Right, Bottom; }
public class Sv {
    delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc cb, IntPtr p);
    [DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr parent, EnumProc cb, IntPtr p);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassNameW(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECTS r);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr SendMessageW(IntPtr h, uint m, IntPtr w, string l);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern IntPtr SendMessageW(IntPtr h, uint m, IntPtr w, StringBuilder l);
    [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] public static extern IntPtr GetDlgItem(IntPtr h, int id);
    [DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr h);
    [StructLayout(LayoutKind.Sequential)] public struct LASTINPUTINFO { public uint cbSize; public uint dwTime; }
    [DllImport("user32.dll")] static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);
    public static uint IdleMs() {
        var lii = new LASTINPUTINFO(); lii.cbSize = (uint)Marshal.SizeOf(typeof(LASTINPUTINFO));
        if (!GetLastInputInfo(ref lii)) return 0;
        return (uint)Environment.TickCount - lii.dwTime; }
    public static string GT(IntPtr h) { var s = new StringBuilder(2048); SendMessageW(h, 0x000D, (IntPtr)2048, s); return s.ToString(); }
    public static string Chain(IntPtr h, IntPtr stop) {
        var sb = new StringBuilder(); IntPtr cur = GetParent(h);
        for (int i = 0; i < 12 && cur != IntPtr.Zero && cur != stop; i++) {
            if (sb.Length > 0) sb.Append(" < ");
            sb.Append(C(cur)); cur = GetParent(cur); }
        return sb.ToString(); }
    public static List<IntPtr> ForPid(uint want) {
        var f = new List<IntPtr>();
        EnumWindows(delegate(IntPtr h, IntPtr l) { uint pid; GetWindowThreadProcessId(h, out pid);
            if (pid == want && IsWindowVisible(h)) f.Add(h); return true; }, IntPtr.Zero);
        return f;
    }
    public static List<IntPtr> Kids(IntPtr parent) {
        var f = new List<IntPtr>();
        EnumChildWindows(parent, delegate(IntPtr h, IntPtr l) { f.Add(h); return true; }, IntPtr.Zero);
        return f;
    }
    public static string T(IntPtr h) { var s = new StringBuilder(512); GetWindowTextW(h, s, 512); return s.ToString(); }
    public static string C(IntPtr h) { var s = new StringBuilder(256); GetClassNameW(h, s, 256); return s.ToString(); }
}
"@
$name = [IO.Path]::GetFileNameWithoutExtension($Exe)
function Shot([IntPtr]$h,[string]$tag) {
    $r = New-Object RECTS; [void][Sv]::GetWindowRect($h,[ref]$r)
    $w=$r.Right-$r.Left; $ht=$r.Bottom-$r.Top
    if ($w -le 0 -or $ht -le 0) { return $null }
    $b = New-Object System.Drawing.Bitmap($w,$ht); $g=[System.Drawing.Graphics]::FromImage($b)
    $g.CopyFromScreen($r.Left,$r.Top,0,0,$b.Size)
    $p = Join-Path $out ("{0}_{1}.png" -f $name,$tag)
    $b.Save($p,[System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $b.Dispose(); return $p
}
function Wins([int]$thePid){ foreach($h in [Sv]::ForPid([uint32]$thePid)){ Write-Host ("    [{0}] '{1}'" -f [Sv]::C($h),[Sv]::T($h)) } }
function Dlg([int]$thePid,[IntPtr]$excl=[IntPtr]::Zero){ [Sv]::ForPid([uint32]$thePid) | Where-Object { [Sv]::C($_) -eq '#32770' -and $_ -ne $excl } | Select-Object -First 1 }
function MainWin([int]$thePid){
    $m=$null; $best=0
    foreach($h in [Sv]::ForPid([uint32]$thePid)){
        if ([Sv]::C($h) -eq '#32770') { continue }
        $r=New-Object RECTS; [void][Sv]::GetWindowRect($h,[ref]$r)
        $a=($r.Right-$r.Left)*($r.Bottom-$r.Top); if($a -gt $best){$best=$a;$m=$h} }
    if (-not $m) { $m = [Sv]::ForPid([uint32]$thePid) | Select-Object -First 1 }
    return $m
}
# Fill a native file dialog (classic or Vista-style): WM_SETTEXT the filename Edit,
# then click IDOK. Neither needs the dialog foregrounded.
function FillFileDialog([IntPtr]$dlg,[string]$path) {
    # The filename field varies (classic edt1 0x480 vs Vista ComboBox edit, plus a
    # deceptive search-box Edit). Set EVERY candidate, then read back and require
    # at least one to hold the exact path before clicking - a mis-filled dialog
    # with a default name would otherwise overwrite the ORIGINAL file.
    # ONLY the true filename edit: dlg item 0x480 (edt1), or the Edit inside the
    # filename ComboBox. NEVER an edit under the rebar (search box, address bar) -
    # touching those navigates the dialog or fools the verify.
    $edit = [IntPtr]::Zero
    for ($try = 0; $try -lt 8 -and $edit -eq [IntPtr]::Zero; $try++) {
        if ($try -gt 0) { Start-Sleep -Seconds 1 }
        $e1 = [Sv]::GetDlgItem($dlg, 0x480)
        if ($e1 -ne [IntPtr]::Zero) { $edit = $e1; break }
        $cmb = [Sv]::GetDlgItem($dlg, 0x47C)
        if ($cmb -ne [IntPtr]::Zero) {
            $e2 = [Sv]::Kids($cmb) | Where-Object { [Sv]::C($_) -eq 'Edit' } | Select-Object -First 1
            if ($e2) { $edit = $e2; break } }
        foreach ($k in [Sv]::Kids($dlg)) {
            if ([Sv]::C($k) -ne 'Edit') { continue }
            $chain = [Sv]::Chain($k, $dlg)
            if ($chain -match 'ReBarWindow32|SearchEditBox|Address|Breadcrumb') { continue }
            if ($chain -match 'ComboBox') { $edit = $k; break }
        }
    }
    if ($edit -eq [IntPtr]::Zero) {
        Write-Host 'no filename Edit found; all Edits with ancestor chains:' -ForegroundColor Red
        foreach ($k in [Sv]::Kids($dlg)) {
            if ([Sv]::C($k) -eq 'Edit') { Write-Host ("    {0} '{1}'  chain: {2}" -f $k, [Sv]::GT($k), [Sv]::Chain($k, $dlg)) } }
        return $false }
    Write-Host ("  filename edit {0} (had '{1}')" -f $edit, [Sv]::GT($edit)) -ForegroundColor DarkGray
    # EM_SETSEL all + EM_REPLACESEL: behaves like typing (EN_CHANGE, internal sync)
    [void][Sv]::SendMessage($edit, 0x00B1, [IntPtr]::Zero, [IntPtr](-1))   # EM_SETSEL 0,-1
    [void][Sv]::SendMessageW($edit, 0x00C2, [IntPtr]1, $path)              # EM_REPLACESEL
    Start-Sleep -Milliseconds 800
    $got = [Sv]::GT($edit)
    if ($got -ne $path) {
        Write-Host ("  EM_REPLACESEL readback '{0}' - retrying WM_SETTEXT" -f $got) -ForegroundColor Yellow
        [void][Sv]::SendMessageW($edit, 0x000C, [IntPtr]::Zero, $path)
        Start-Sleep -Milliseconds 800
        $got = [Sv]::GT($edit)
    }
    Write-Host ("  filename edit now: '{0}'" -f $got)
    if ($got -ne $path) { Write-Host 'FILL VERIFY FAILED - not clicking OK' -ForegroundColor Red; return $false }
    $ok = [Sv]::GetDlgItem($dlg, 1)                                   # IDOK
    if ($ok -eq [IntPtr]::Zero) { Write-Host 'no IDOK button' -ForegroundColor Red; return $false }
    # async click: BM_CLICK via SendMessage blocks if the save pops a modal box
    [void][Sv]::PostMessage($dlg, 0x0111, [IntPtr]1, [IntPtr]$ok)     # WM_COMMAND IDOK
    return $true
}
# After OK: if a 'Confirm Save As' overwrite prompt appears, the fill went to the
# wrong place (targets are pre-deleted) - answer NO and fail loudly.
function GuardOverwrite([int]$thePid,[int]$secs) {
    for ($i=0; $i -lt $secs; $i++) {
        Start-Sleep -Seconds 1
        $c = [Sv]::ForPid([uint32]$thePid) | Where-Object { [Sv]::T($_) -eq 'Confirm Save As' } | Select-Object -First 1
        if ($c) {
            Write-Host 'OVERWRITE PROMPT - fill went to the wrong file. Answering NO.' -ForegroundColor Red
            foreach ($k in [Sv]::Kids($c)) {
                if ([Sv]::C($k) -eq 'Static' -and [Sv]::T($k) -ne '') { Write-Host ("    confirm text: {0}" -f [Sv]::T($k)) } }
            [void][Sv]::PostMessage($c, 0x0111, [IntPtr]7, [IntPtr]::Zero)   # IDNO
            Start-Sleep -Seconds 1
            foreach ($h in [Sv]::ForPid([uint32]$thePid)) {
                if ([Sv]::C($h) -eq '#32770') { [void][Sv]::PostMessage($h, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) } }
            return $false
        }
    }
    return $true
}
function WaitDlg([int]$thePid,[int]$tries=25,[IntPtr]$excl=[IntPtr]::Zero) {
    for ($i=0; $i -lt $tries; $i++) { Start-Sleep -Milliseconds 600
        $d = Dlg $thePid $excl; if ($d) { return $d } }
    return $null
}
function GuardedKeys([IntPtr]$target,[string]$keys) {
    # $keys may be comma-separated chunks sent with a pause between them
    # (menu mnemonics need the popup to appear first, e.g. '%f,a').
    for ($i=0; $i -lt 60; $i++) {
        # never type while the user is active: require 8s of system-wide input idle
        if ([Sv]::IdleMs() -lt 8000) { Start-Sleep -Seconds 3; continue }
        [void][Sv]::BringWindowToTop($target); [void][Sv]::SetForegroundWindow($target)
        Start-Sleep -Milliseconds 500
        if ([Sv]::GetForegroundWindow() -eq $target -and [Sv]::IdleMs() -ge 8000) {
            foreach ($chunk in $keys -split ',') {
                [System.Windows.Forms.SendKeys]::SendWait($chunk)
                Start-Sleep -Milliseconds 1000
            }
            return $true }
        Start-Sleep -Seconds 2
    }
    Write-Host ('FOREGROUND GUARD FAILED for keys {0} - not sent' -f $keys) -ForegroundColor Red
    return $false
}

Write-Host ("=== SAVE SWEEP: {0}" -f $Exe) -ForegroundColor Cyan
if ((Test-Path $SavePath) -and ($SavePath -ne $OpenPath)) { Remove-Item $SavePath -Force }
Get-Process $name -ErrorAction SilentlyContinue | Stop-Process -Force
$warn = Join-Path $dir 'logs\warning.log'
$before = if (Test-Path $warn) { (Get-Item $warn).LastWriteTime } else { [datetime]::MinValue }

$p = Start-Process -FilePath (Join-Path $dir $Exe) -WorkingDirectory $dir -PassThru
Start-Sleep -Seconds $Boot
$p.Refresh(); if ($p.HasExited) { Write-Host ("EXITED during boot 0x{0:X8}" -f $p.ExitCode) -ForegroundColor Red; exit 1 }

# dismiss modal startup warnings without foreground: WM_CLOSE works on these boxes
if (-not $NoDismiss) {
    for ($round=0; $round -lt 6; $round++) {
        $d = Dlg $p.Id
        if (-not $d) { break }
        Write-Host ("  dismissing startup dialog: '{0}'" -f [Sv]::T($d)) -ForegroundColor DarkGray
        [void][Sv]::PostMessage($d, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)  # WM_CLOSE
        Start-Sleep -Milliseconds 1200
    }
}
$main = MainWin $p.Id
if ($NoDismiss -and (-not $main -or $main -eq [IntPtr]::Zero)) {
    $main = [Sv]::ForPid([uint32]$p.Id) | Select-Object -First 1 }
Write-Host "-- windows after boot --"; Wins $p.Id
Write-Host ("boot shot: {0}" -f (Shot $main 's1-boot'))

if ($NewCmd -ne 0) {
    Write-Host ("posting File>New 0x{0:X}" -f $NewCmd)
    [void][Sv]::PostMessage($main, 0x0111, [IntPtr]$NewCmd, [IntPtr]::Zero)   # WM_COMMAND
    Start-Sleep -Seconds 5
}
if ($OpenPath -ne '') {
    if ($QtOpenAccel -ne '') { if (-not (GuardedKeys $main $QtOpenAccel)) { exit 3 } }
    else { Write-Host ("posting File>Open 0x{0:X}" -f $OpenCmd)
           [void][Sv]::PostMessage($main, 0x0111, [IntPtr]$OpenCmd, [IntPtr]::Zero) }
    $d = WaitDlg $p.Id 25 $main
    if (-not $d) { Write-Host 'no Open dialog' -ForegroundColor Red; Shot $main 's2-noopen' | Out-Null; if(-not $Keep){Stop-Process -Id $p.Id -Force}; exit 2 }
    Write-Host ("  open dialog: '{0}'" -f [Sv]::T($d))
    if (-not (FillFileDialog $d $OpenPath)) { if(-not $Keep){Stop-Process -Id $p.Id -Force}; exit 2 }
    Start-Sleep -Seconds $AfterOpen
    $p.Refresh(); if ($p.HasExited) { Write-Host ("EXITED after open 0x{0:X8}" -f $p.ExitCode) -ForegroundColor Red; exit 1 }
    Write-Host "-- windows after open --"; Wins $p.Id
    Write-Host ("after-open shot: {0}" -f (Shot (MainWin $p.Id) 's3-opened'))
}

$saveTarget = if ($NoDismiss) { $main } else { MainWin $p.Id }
# snapshot existing #32770s so a pre-existing dialog-class window (UIBuilder's
# workspace) is never mistaken for the Save dialog
$preDlgs = @([Sv]::ForPid([uint32]$p.Id) | Where-Object { [Sv]::C($_) -eq '#32770' })
function WaitNewDlg([int]$thePid,[object[]]$known,[int]$tries=15) {
    for ($i=0; $i -lt $tries; $i++) { Start-Sleep -Milliseconds 600
        foreach ($h in ([Sv]::ForPid([uint32]$thePid) | Where-Object { [Sv]::C($_) -eq '#32770' })) {
            if ($known -notcontains $h) { return $h } } }
    return $null
}
if ($QtSaveAccel -ne '') { if (-not (GuardedKeys $saveTarget $QtSaveAccel)) { exit 3 } }
else { Write-Host ("posting save command 0x{0:X}" -f $SaveAsCmd)
       [void][Sv]::PostMessage($saveTarget, 0x0111, [IntPtr]$SaveAsCmd, [IntPtr]::Zero) }
if ($NoSaveDialog) {
    Start-Sleep -Seconds $AfterSave
    $d2 = Dlg $p.Id $main
    if ($d2) { Write-Host ("  post-save dialog: '{0}'" -f [Sv]::T($d2)) -ForegroundColor Yellow
               foreach ($k in [Sv]::Kids($d2)) { if ([Sv]::C($k) -eq 'Static' -and [Sv]::T($k) -ne '') { Write-Host ("    {0}" -f [Sv]::T($k)) } }
               Shot $d2 's6-postdlg' | Out-Null
               [void][Sv]::PostMessage($d2, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero); Start-Sleep -Seconds 2 }
    $p.Refresh(); if ($p.HasExited) { Write-Host ("EXITED after save 0x{0:X8}" -f $p.ExitCode) -ForegroundColor Red }
    if (Test-Path $SavePath) {
        $fi = Get-Item $SavePath
        Write-Host ("SAVED: {0}  {1} bytes  {2}" -f $fi.FullName, $fi.Length, $fi.LastWriteTime) -ForegroundColor Green
    } else { Write-Host ("NOT SAVED: {0} does not exist" -f $SavePath) -ForegroundColor Red }
    if ($Keep) { Write-Host ("LEFT RUNNING pid {0}" -f $p.Id) -ForegroundColor Green }
    else { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue; Write-Host 'stopped' }
    exit 0
}
$d = WaitNewDlg $p.Id $preDlgs
if (-not $d -and $QtSaveAccel -eq '') {
    # some frames route the command through a child window - try the others
    foreach ($w in $preDlgs) { if ($w -ne $saveTarget) {
        Write-Host ("retrying save command on {0} '{1}'" -f $w, [Sv]::T($w)) -ForegroundColor Yellow
        [void][Sv]::PostMessage($w, 0x0111, [IntPtr]$SaveAsCmd, [IntPtr]::Zero) } }
    $d = WaitNewDlg $p.Id $preDlgs
}
if (-not $d) { Write-Host 'no Save dialog' -ForegroundColor Red; Shot $saveTarget 's4-nosave' | Out-Null; if(-not $Keep){Stop-Process -Id $p.Id -Force}; exit 2 }
Write-Host ("  save dialog: '{0}'" -f [Sv]::T($d))
Shot $d 's5-savedlg' | Out-Null
if (-not (FillFileDialog $d $SavePath)) { if(-not $Keep){Stop-Process -Id $p.Id -Force}; exit 2 }
if (-not (GuardOverwrite $p.Id $AfterSave)) { if(-not $Keep){Stop-Process -Id $p.Id -Force}; exit 4 }

# a second #32770 after save is usually an overwrite/format prompt - report, close it
$d2 = Dlg $p.Id $main
if ($d2) { Write-Host ("  post-save dialog: '{0}' - closing" -f [Sv]::T($d2)) -ForegroundColor Yellow
           Shot $d2 's6-postdlg' | Out-Null
           [void][Sv]::PostMessage($d2, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero); Start-Sleep -Seconds 2 }

$p.Refresh(); if ($p.HasExited) { Write-Host ("EXITED after save 0x{0:X8}" -f $p.ExitCode) -ForegroundColor Red }
else { Write-Host "-- windows after save --"; Wins $p.Id
       Write-Host ("after-save shot: {0}" -f (Shot (MainWin $p.Id) 's7-saved')) }

if (Test-Path $SavePath) {
    $fi = Get-Item $SavePath
    Write-Host ("SAVED: {0}  {1} bytes  {2}" -f $fi.FullName, $fi.Length, $fi.LastWriteTime) -ForegroundColor Green
} else { Write-Host ("NOT SAVED: {0} does not exist" -f $SavePath) -ForegroundColor Red }

if ((Test-Path $warn) -and ((Get-Item $warn).LastWriteTime -gt $before)) {
    Copy-Item $warn (Join-Path $dir ("logs\warning." + $name + "-save.log")) -Force
    $f = Select-String -Path $warn -Pattern 'FATAL','WARNING'
    if ($f) { Write-Host "-- log hits --"; $f | Select-Object -First 10 | ForEach-Object { Write-Host ("    "+$_.Line.Trim()) } }
}
if ($Keep) { Write-Host ("LEFT RUNNING pid {0}" -f $p.Id) -ForegroundColor Green }
else { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue; Write-Host 'stopped' }
