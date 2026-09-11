# Qt save-sweep batch: waits for sustained desktop idle before each tool, then
# drives open + Save As via _drive-save.ps1 (whose GuardedKeys also refuses to
# type unless the system has been input-idle >= 8s and the target owns the
# foreground). Safe to leave running while the user works - it only acts in gaps.
$ErrorActionPreference = 'Continue'
$drive = Join-Path $PSScriptRoot '_drive-save.ps1'
$logFile = 'C:\save-test\_qt-batch.log'
function Log([string]$m) { $m | Add-Content -Path $logFile -Encoding Ascii; Write-Host $m }
Add-Type @"
using System; using System.Runtime.InteropServices;
public class IdleQ {
    [StructLayout(LayoutKind.Sequential)] public struct LASTINPUTINFO { public uint cbSize; public uint dwTime; }
    [DllImport("user32.dll")] static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);
    public static uint IdleMs() {
        var lii = new LASTINPUTINFO(); lii.cbSize = (uint)Marshal.SizeOf(typeof(LASTINPUTINFO));
        if (!GetLastInputInfo(ref lii)) return 0;
        return (uint)Environment.TickCount - lii.dwTime; }
}
"@
function WaitForIdle([int]$needSec, [int]$timeoutMin) {
    $deadline = (Get-Date).AddMinutes($timeoutMin)
    while ((Get-Date) -lt $deadline) {
        if (([IdleQ]::IdleMs() / 1000) -ge $needSec) { return $true }
        Start-Sleep -Seconds 5
    }
    return $false
}

$soeApp = 'D:\SWG All Tools Working\swg\current\data\sku.0\sys.client\compiled\game\appearance'
$soeSnd = 'D:\SWG All Tools Working\swg\current\data\sku.0\sys.client\compiled\game\sound'
$tools = @(
    @{ Name='ParticleEditor';  Args=@('-Exe','ParticleEditor_r.exe','-OpenPath',"$soeApp\pt_campfire_s01.prt",'-SavePath','C:\save-test\campfire-resave.prt','-QtOpenAccel','^o','-QtSaveAccel','%f,a','-Boot','40','-AfterOpen','25') },
    @{ Name='SwooshEditor';    Args=@('-Exe','SwooshEditor_r.exe','-OpenPath',"$soeApp\podracer_energy_binders.swh",'-SavePath','C:\save-test\podracer-resave.swh','-QtOpenAccel','^o','-QtSaveAccel','^a','-Boot','40','-AfterOpen','20') },
    @{ Name='LightningEditor'; Args=@('-Exe','LightningEditor_r.exe','-OpenPath',"$soeApp\force_lightning.ltn",'-SavePath','C:\save-test\force_lightning-resave.ltn','-QtOpenAccel','^o','-QtSaveAccel','^a','-Boot','40','-AfterOpen','20') },
    @{ Name='SoundEditor';     Args=@('-Exe','SoundEditor_r.exe','-OpenPath',"$soeSnd\music_combat_loop.snd",'-SavePath','C:\save-test\music-resave.snd','-QtOpenAccel','^o','-QtSaveAccel','%f,a','-Boot','30','-AfterOpen','20') }
)

foreach ($t in $tools) {
    Log ("##### {0}: waiting for 25s desktop idle (up to 90 min)" -f $t.Name)
    if (-not (WaitForIdle 25 90)) { Log ("##### {0}: NO IDLE WINDOW - skipped" -f $t.Name); continue }
    Log ("##### {0}: idle window found, driving" -f $t.Name)
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $drive @($t.Args) 2>&1
    $out | ForEach-Object { Log ("  " + $_) }
    Log ("##### {0}: exit {1}" -f $t.Name, $LASTEXITCODE)
}
Log '##### batch complete'
