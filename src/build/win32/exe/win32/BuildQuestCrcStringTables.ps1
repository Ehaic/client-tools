# ================================================================================
#
# BuildQuestCrcStringTables.ps1 - rebuild misc/quest_crc_string_table.{tab,iff}
#
# PowerShell port (2026-08-29) of SOE's buildQuestCrcStringTables.pl +
# buildCrcStringTable.pl (Copyright 2004, Sony Online Entertainment Inc.;
# originals preserved in the SWGSource repos' tools/ dirs). Ported because the
# tool machines carry no perl, and the original outer script was a Perforce
# wrapper (p4 where/files/opened) that cannot run here. This port folds in the
# directory-walk replacement for the p4 enumeration (the same substitution the
# community made in swg-main/utils/build_quest_crc_string_tables.py) and writes
# the binary IFF directly, so neither perl nor Miff is needed.
#
# Byte-for-byte faithful to the perl pipeline, verified against the SOE
# reference tree's shipped quest_crc_string_table.iff (2736 entries,
# regenerated bit-identical from a walk of its questlist directory):
#   * CRC-32, MSB-first, init/xorout 0xFFFFFFFF, SOE's table (identical values
#     to the perl's inline @crctable)
#   * entries sorted by unsigned CRC ascending (perl sorted the "0x%08x"
#     strings lexicographically - same order)
#   * IFF: FORM CSTB { FORM 0000 { DATA int32 count; CRCT uint32[n];
#     STRT int32[n] offsets into STNG; STNG cstring[n] } }
#     - chunk/form sizes big-endian, chunk payload little-endian, cstrings
#     NUL-terminated
#   * tab file: "0x%08x<TAB>name" per line, CRLF (perl text-mode on Windows)
#   * a CRC clash between two different strings is fatal, like the perl die
#
# Usage (quest mode - what QuestEditor's "Build Quest CRC Tables" runs):
#   powershell -NoProfile -ExecutionPolicy Bypass -File BuildQuestCrcStringTables.ps1 [-Branch <branch>] [-Root <tree root>]
#     Walks <root>/data/sku.0/sys.shared/compiled/game/datatables/questlist and
#     writes  <root>/dsrc/sku.0/sys.shared/built/game/misc/quest_crc_string_table.tab
#         and <root>/data/sku.0/sys.shared/built/game/misc/quest_crc_string_table.iff
#     When -Root is not given it is derived from defaultListDirectory in the
#     [QuestEditor] section of QuestEditor.cfg in the current directory (the
#     text before /dsrc/), so the script tracks the tool's own configuration.
#     -Branch is accepted for CLI parity with the perl original and only echoed.
#
# Usage (generic mode - the inner buildCrcStringTable.pl, for other tables):
#   ... BuildQuestCrcStringTables.ps1 -InputFile names.txt -OutputIff out.iff [-OutputTab out.tab]
#
# ================================================================================

param(
    [string]$Branch = '',
    [string]$Root = '',
    [string]$InputFile = '',
    [string]$OutputIff = '',
    [string]$OutputTab = '',
    [string]$Config = 'QuestEditor.cfg',
    [switch]$Help
)

Set-StrictMode -Version 2

# SOE's CRC-32 table, transcribed mechanically from buildCrcStringTable.pl.
[long[]]$script:CrcTable = @(
    0x00000000L, 0x04C11DB7L, 0x09823B6EL, 0x0D4326D9L, 0x130476DCL, 0x17C56B6BL, 0x1A864DB2L, 0x1E475005L,
    0x2608EDB8L, 0x22C9F00FL, 0x2F8AD6D6L, 0x2B4BCB61L, 0x350C9B64L, 0x31CD86D3L, 0x3C8EA00AL, 0x384FBDBDL,
    0x4C11DB70L, 0x48D0C6C7L, 0x4593E01EL, 0x4152FDA9L, 0x5F15ADACL, 0x5BD4B01BL, 0x569796C2L, 0x52568B75L,
    0x6A1936C8L, 0x6ED82B7FL, 0x639B0DA6L, 0x675A1011L, 0x791D4014L, 0x7DDC5DA3L, 0x709F7B7AL, 0x745E66CDL,
    0x9823B6E0L, 0x9CE2AB57L, 0x91A18D8EL, 0x95609039L, 0x8B27C03CL, 0x8FE6DD8BL, 0x82A5FB52L, 0x8664E6E5L,
    0xBE2B5B58L, 0xBAEA46EFL, 0xB7A96036L, 0xB3687D81L, 0xAD2F2D84L, 0xA9EE3033L, 0xA4AD16EAL, 0xA06C0B5DL,
    0xD4326D90L, 0xD0F37027L, 0xDDB056FEL, 0xD9714B49L, 0xC7361B4CL, 0xC3F706FBL, 0xCEB42022L, 0xCA753D95L,
    0xF23A8028L, 0xF6FB9D9FL, 0xFBB8BB46L, 0xFF79A6F1L, 0xE13EF6F4L, 0xE5FFEB43L, 0xE8BCCD9AL, 0xEC7DD02DL,
    0x34867077L, 0x30476DC0L, 0x3D044B19L, 0x39C556AEL, 0x278206ABL, 0x23431B1CL, 0x2E003DC5L, 0x2AC12072L,
    0x128E9DCFL, 0x164F8078L, 0x1B0CA6A1L, 0x1FCDBB16L, 0x018AEB13L, 0x054BF6A4L, 0x0808D07DL, 0x0CC9CDCAL,
    0x7897AB07L, 0x7C56B6B0L, 0x71159069L, 0x75D48DDEL, 0x6B93DDDBL, 0x6F52C06CL, 0x6211E6B5L, 0x66D0FB02L,
    0x5E9F46BFL, 0x5A5E5B08L, 0x571D7DD1L, 0x53DC6066L, 0x4D9B3063L, 0x495A2DD4L, 0x44190B0DL, 0x40D816BAL,
    0xACA5C697L, 0xA864DB20L, 0xA527FDF9L, 0xA1E6E04EL, 0xBFA1B04BL, 0xBB60ADFCL, 0xB6238B25L, 0xB2E29692L,
    0x8AAD2B2FL, 0x8E6C3698L, 0x832F1041L, 0x87EE0DF6L, 0x99A95DF3L, 0x9D684044L, 0x902B669DL, 0x94EA7B2AL,
    0xE0B41DE7L, 0xE4750050L, 0xE9362689L, 0xEDF73B3EL, 0xF3B06B3BL, 0xF771768CL, 0xFA325055L, 0xFEF34DE2L,
    0xC6BCF05FL, 0xC27DEDE8L, 0xCF3ECB31L, 0xCBFFD686L, 0xD5B88683L, 0xD1799B34L, 0xDC3ABDEDL, 0xD8FBA05AL,
    0x690CE0EEL, 0x6DCDFD59L, 0x608EDB80L, 0x644FC637L, 0x7A089632L, 0x7EC98B85L, 0x738AAD5CL, 0x774BB0EBL,
    0x4F040D56L, 0x4BC510E1L, 0x46863638L, 0x42472B8FL, 0x5C007B8AL, 0x58C1663DL, 0x558240E4L, 0x51435D53L,
    0x251D3B9EL, 0x21DC2629L, 0x2C9F00F0L, 0x285E1D47L, 0x36194D42L, 0x32D850F5L, 0x3F9B762CL, 0x3B5A6B9BL,
    0x0315D626L, 0x07D4CB91L, 0x0A97ED48L, 0x0E56F0FFL, 0x1011A0FAL, 0x14D0BD4DL, 0x19939B94L, 0x1D528623L,
    0xF12F560EL, 0xF5EE4BB9L, 0xF8AD6D60L, 0xFC6C70D7L, 0xE22B20D2L, 0xE6EA3D65L, 0xEBA91BBCL, 0xEF68060BL,
    0xD727BBB6L, 0xD3E6A601L, 0xDEA580D8L, 0xDA649D6FL, 0xC423CD6AL, 0xC0E2D0DDL, 0xCDA1F604L, 0xC960EBB3L,
    0xBD3E8D7EL, 0xB9FF90C9L, 0xB4BCB610L, 0xB07DABA7L, 0xAE3AFBA2L, 0xAAFBE615L, 0xA7B8C0CCL, 0xA379DD7BL,
    0x9B3660C6L, 0x9FF77D71L, 0x92B45BA8L, 0x9675461FL, 0x8832161AL, 0x8CF30BADL, 0x81B02D74L, 0x857130C3L,
    0x5D8A9099L, 0x594B8D2EL, 0x5408ABF7L, 0x50C9B640L, 0x4E8EE645L, 0x4A4FFBF2L, 0x470CDD2BL, 0x43CDC09CL,
    0x7B827D21L, 0x7F436096L, 0x7200464FL, 0x76C15BF8L, 0x68860BFDL, 0x6C47164AL, 0x61043093L, 0x65C52D24L,
    0x119B4BE9L, 0x155A565EL, 0x18197087L, 0x1CD86D30L, 0x029F3D35L, 0x065E2082L, 0x0B1D065BL, 0x0FDC1BECL,
    0x3793A651L, 0x3352BBE6L, 0x3E119D3FL, 0x3AD08088L, 0x2497D08DL, 0x2056CD3AL, 0x2D15EBE3L, 0x29D4F654L,
    0xC5A92679L, 0xC1683BCEL, 0xCC2B1D17L, 0xC8EA00A0L, 0xD6AD50A5L, 0xD26C4D12L, 0xDF2F6BCBL, 0xDBEE767CL,
    0xE3A1CBC1L, 0xE760D676L, 0xEA23F0AFL, 0xEEE2ED18L, 0xF0A5BD1DL, 0xF464A0AAL, 0xF9278673L, 0xFDE69BC4L,
    0x89B8FD09L, 0x8D79E0BEL, 0x803AC667L, 0x84FBDBD0L, 0x9ABC8BD5L, 0x9E7D9662L, 0x933EB0BBL, 0x97FFAD0CL,
    0xAFB010B1L, 0xAB710D06L, 0xA6322BDFL, 0xA2F33668L, 0xBCB4666DL, 0xB8757BDAL, 0xB5365D03L, 0xB1F740B4L
)

# --------------------------------------------------------------------------------

function Show-Usage {
    [Console]::Error.WriteLine('Usage: BuildQuestCrcStringTables.ps1 [-Branch <branch>] [-Root <tree root>]')
    [Console]::Error.WriteLine('       BuildQuestCrcStringTables.ps1 -InputFile names.txt -OutputIff out.iff [-OutputTab out.tab]')
    [Console]::Error.WriteLine(' Quest mode walks <root>/data/sku.0/sys.shared/compiled/game/datatables/questlist')
    [Console]::Error.WriteLine(' and rebuilds misc/quest_crc_string_table.tab (dsrc) and .iff (data).')
    [Console]::Error.WriteLine(' Without -Root, the root is derived from defaultListDirectory in QuestEditor.cfg.')
    exit 1
}

# --------------------------------------------------------------------------------

function Get-SwgCrc([string]$s) {
    if ($s.Length -eq 0) { return [long]0 }
    $crc = [long]0xFFFFFFFFL
    foreach ($b in [System.Text.Encoding]::ASCII.GetBytes($s)) {
        $idx = (($crc -shr 24) -bxor $b) -band 0xFF
        $crc = $script:CrcTable[$idx] -bxor (($crc -shl 8) -band 0xFFFFFFFFL)
    }
    return $crc -bxor 0xFFFFFFFFL
}

# --------------------------------------------------------------------------------

# last occurrence of key in [section] wins, quotes stripped - mirrors how the
# engine's ConfigFile resolves a single-valued key
function Get-CfgKey([string]$cfgPath, [string]$section, [string]$key) {
    if (-not (Test-Path -LiteralPath $cfgPath)) { return $null }
    $current = ''
    $value = $null
    foreach ($line in Get-Content -LiteralPath $cfgPath) {
        $t = $line.Trim()
        if ($t -eq '' -or $t.StartsWith('#')) { continue }
        if ($t -match '^\[(.+)\]$') { $current = $matches[1]; continue }
        if ($current -eq $section -and $t -match ('^' + [regex]::Escape($key) + '\s*=\s*(.*)$')) {
            $v = $matches[1].Trim()
            if ($v.Length -ge 2 -and $v.StartsWith('"') -and $v.EndsWith('"')) {
                $v = $v.Substring(1, $v.Length - 2)
            }
            $value = $v
        }
    }
    return $value
}

# --------------------------------------------------------------------------------

function New-IffBlock([string]$tag, [byte[]]$payload) {
    $out = New-Object byte[] (8 + $payload.Length)
    [System.Text.Encoding]::ASCII.GetBytes($tag).CopyTo($out, 0)
    $size = [System.BitConverter]::GetBytes([uint32]$payload.Length)
    [System.Array]::Reverse($size)
    $size.CopyTo($out, 4)
    $payload.CopyTo($out, 8)
    return ,$out
}

# --------------------------------------------------------------------------------

if ($Help) { Show-Usage }

$genericMode = ($InputFile -ne '')
if ($genericMode -and $OutputIff -eq '') {
    [Console]::Error.WriteLine('error: generic mode needs both -InputFile and -OutputIff')
    Show-Usage
}

$names = $null

if ($genericMode) {
    if (-not (Test-Path -LiteralPath $InputFile)) {
        [Console]::Error.WriteLine("error: input file not found: $InputFile")
        exit 1
    }
    $names = @(Get-Content -LiteralPath $InputFile | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
}
else {
    if ($Branch -ne '') { Write-Output "branch: $Branch" }

    if ($Root -eq '') {
        $listDir = Get-CfgKey $Config 'QuestEditor' 'defaultListDirectory'
        if ($null -eq $listDir) {
            [Console]::Error.WriteLine("error: cannot read defaultListDirectory from [QuestEditor] in $Config; pass -Root")
            exit 1
        }
        $listDir = $listDir.Replace('\', '/')
        $idx = $listDir.IndexOf('/dsrc/', [System.StringComparison]::OrdinalIgnoreCase)
        if ($idx -lt 0) { $idx = $listDir.IndexOf('/data/', [System.StringComparison]::OrdinalIgnoreCase) }
        if ($idx -lt 0) {
            [Console]::Error.WriteLine("error: defaultListDirectory has no /dsrc/ or /data/ segment to derive the tree root from: $listDir")
            exit 1
        }
        $Root = $listDir.Substring(0, $idx)
    }
    $Root = $Root.Replace('\', '/').TrimEnd('/')

    $questListDir = "$Root/data/sku.0/sys.shared/compiled/game/datatables/questlist"
    if ($OutputTab -eq '') { $OutputTab = "$Root/dsrc/sku.0/sys.shared/built/game/misc/quest_crc_string_table.tab" }
    if ($OutputIff -eq '') { $OutputIff = "$Root/data/sku.0/sys.shared/built/game/misc/quest_crc_string_table.iff" }

    if (-not (Test-Path -LiteralPath $questListDir -PathType Container)) {
        [Console]::Error.WriteLine("error: questlist directory not found: $questListDir")
        exit 1
    }

    Write-Output 'building quest template strings:'
    Write-Output "`t$OutputTab"
    Write-Output "`t$OutputIff"

    $prefixLen = (Get-Item -LiteralPath $questListDir).FullName.Length
    $names = @(Get-ChildItem -LiteralPath $questListDir -Recurse -File | ForEach-Object {
        $_.FullName.Substring($prefixLen).TrimStart('\', '/').Replace('\', '/') -replace '(?i)\.iff$', ''
    })
}

# CRC every name; a clash between two different strings is fatal (perl die)
$crcToName = @{}
foreach ($name in $names) {
    $crc = Get-SwgCrc $name
    if ($crcToName.ContainsKey($crc) -and $crcToName[$crc] -cne $name) {
        $clashHex = '0x{0:x8}' -f $crc
        [Console]::Error.WriteLine("crc string clash for ${clashHex}:")
        [Console]::Error.WriteLine("`t$($crcToName[$crc])")
        [Console]::Error.WriteLine("`t$name")
        exit 1
    }
    $crcToName[$crc] = $name
}

$sortedCrcs = @($crcToName.Keys | Sort-Object)
$count = $sortedCrcs.Count

# build the four chunk payloads
$dataMs = New-Object System.IO.MemoryStream
$crctMs = New-Object System.IO.MemoryStream
$strtMs = New-Object System.IO.MemoryStream
$stngMs = New-Object System.IO.MemoryStream

$dataMs.Write([System.BitConverter]::GetBytes([int]$count), 0, 4)

$offset = 0
foreach ($crc in $sortedCrcs) {
    $crctMs.Write([System.BitConverter]::GetBytes([uint32]$crc), 0, 4)
    $strtMs.Write([System.BitConverter]::GetBytes([int]$offset), 0, 4)
    $nameBytes = [System.Text.Encoding]::ASCII.GetBytes([string]$crcToName[$crc])
    $stngMs.Write($nameBytes, 0, $nameBytes.Length)
    $stngMs.WriteByte(0)
    $offset += $nameBytes.Length + 1
}

# FORM CSTB { FORM 0000 { DATA CRCT STRT STNG } }
$innerMs = New-Object System.IO.MemoryStream
$innerMs.Write([System.Text.Encoding]::ASCII.GetBytes('0000'), 0, 4)
foreach ($pair in @(@('DATA', $dataMs), @('CRCT', $crctMs), @('STRT', $strtMs), @('STNG', $stngMs))) {
    $chunk = New-IffBlock $pair[0] $pair[1].ToArray()
    $innerMs.Write($chunk, 0, $chunk.Length)
}
$innerForm = New-IffBlock 'FORM' $innerMs.ToArray()

$outerMs = New-Object System.IO.MemoryStream
$outerMs.Write([System.Text.Encoding]::ASCII.GetBytes('CSTB'), 0, 4)
$outerMs.Write($innerForm, 0, $innerForm.Length)
$fileBytes = New-IffBlock 'FORM' $outerMs.ToArray()

# write outputs, creating directories as needed (the community wrapper did too)
$iffDir = Split-Path -Parent $OutputIff
if ($iffDir -ne '' -and -not (Test-Path -LiteralPath $iffDir)) {
    New-Item -ItemType Directory -Force -Path $iffDir | Out-Null
}
[System.IO.File]::WriteAllBytes($OutputIff, $fileBytes)

if ($OutputTab -ne '') {
    $tabDir = Split-Path -Parent $OutputTab
    if ($tabDir -ne '' -and -not (Test-Path -LiteralPath $tabDir)) {
        New-Item -ItemType Directory -Force -Path $tabDir | Out-Null
    }
    $sb = New-Object System.Text.StringBuilder
    foreach ($crc in $sortedCrcs) {
        [void]$sb.Append(('0x{0:x8}' -f $crc)).Append("`t").Append([string]$crcToName[$crc]).Append("`r`n")
    }
    [System.IO.File]::WriteAllText($OutputTab, $sb.ToString(), [System.Text.Encoding]::ASCII)
}

Write-Output "$count entries written"
exit 0
