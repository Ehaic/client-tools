[CmdletBinding()]
param(
    [string]$VisualStudioRoot,

    [string]$ObjectDirectory,

    [string]$QtDllPath,

    [string]$QtImportLibraryPath,

    [string]$QtMainLibraryPath,

    [string]$GodClientPath,

    [string]$CompileTlogPath,

    [string]$LinkTlogPath,

    [string]$BuildMetadataPath,

    [string]$ContractPath,

    [switch]$AllowIncrementalQtBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-VisualStudioRoot {
    param([string]$RequestedRoot)

    if ($RequestedRoot) {
        if (-not (Test-Path -LiteralPath $RequestedRoot -PathType Container)) {
            throw "VisualStudioRoot was not found: $RequestedRoot"
        }
        return (Resolve-Path -LiteralPath $RequestedRoot).Path
    }

    $vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path -LiteralPath $vswhere -PathType Leaf)) {
        throw "Visual Studio could not be discovered because vswhere.exe was not found. Pass -VisualStudioRoot explicitly."
    }

    $installations = @(
        & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath |
            Where-Object { $_ }
    )
    if ($LASTEXITCODE -ne 0 -or $installations.Count -eq 0) {
        throw "Visual Studio with the C++ x64 toolchain was not found. Pass -VisualStudioRoot explicitly."
    }

    return $installations[0].Trim()
}

function Get-DumpbinPath {
    param([Parameter(Mandatory)][string]$Root)

    $toolRoot = Join-Path $Root "VC\Tools\MSVC"
    if (-not (Test-Path -LiteralPath $toolRoot -PathType Container)) {
        throw "The Visual Studio C++ tool directory was not found under VisualStudioRoot: $toolRoot"
    }

    $candidates = @(
        Get-ChildItem -LiteralPath $toolRoot -Directory |
            Sort-Object Name -Descending |
            ForEach-Object { Join-Path $_.FullName "bin\Hostx64\x64\dumpbin.exe" } |
            Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }
    )
    if ($candidates.Count -eq 0) {
        throw "dumpbin.exe for the x64 C++ toolchain was not found under VisualStudioRoot: $Root"
    }

    return $candidates[0]
}

function Invoke-Dumpbin {
    param(
        [Parameter(Mandatory)][string]$DumpbinPath,
        [Parameter(Mandatory)][string]$Mode,
        [Parameter(Mandatory)][string]$InputPath
    )

    $output = @(& $DumpbinPath /nologo $Mode $InputPath 2>&1)
    if ($LASTEXITCODE -ne 0) {
        $details = ($output | ForEach-Object { [string]$_ }) -join [Environment]::NewLine
        throw "dumpbin $Mode failed for '$InputPath' with exit code $LASTEXITCODE.$([Environment]::NewLine)$details"
    }
    return $output
}

function Get-PeMachine {
    param([Parameter(Mandatory)][string]$Path)

    $stream = [IO.File]::OpenRead($Path)
    $reader = [IO.BinaryReader]::new($stream)
    try {
        if ($reader.ReadUInt16() -ne 0x5a4d) {
            throw "Not a PE file: $Path"
        }
        $stream.Position = 0x3c
        $peOffset = $reader.ReadInt32()
        $stream.Position = $peOffset
        if ($reader.ReadUInt32() -ne 0x00004550) {
            throw "Invalid PE signature: $Path"
        }
        return $reader.ReadUInt16()
    }
    finally {
        $reader.Dispose()
        $stream.Dispose()
    }
}

function Get-CoffLibraryMachine {
    param(
        [Parameter(Mandatory)][string]$DumpbinPath,
        [Parameter(Mandatory)][string]$Path
    )

    $machines = [System.Collections.Generic.HashSet[uint16]]::new()
    $headerLines = Invoke-Dumpbin -DumpbinPath $DumpbinPath -Mode "/headers" -InputPath $Path
    foreach ($line in $headerLines) {
        if ([string]$line -match "^\s+([0-9A-Fa-f]+) machine \(") {
            [void]$machines.Add([Convert]::ToUInt16($Matches[1], 16))
        }
    }
    if ($machines.Count -ne 1) {
        throw "Expected one COFF machine type in '$Path', found: $(@($machines) -join ', ')"
    }
    return @($machines)[0]
}

function Sort-Ordinal {
    param([Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Values)

    $sorted = [string[]]$Values.Clone()
    [Array]::Sort($sorted, [StringComparer]::Ordinal)
    return $sorted
}

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
if (-not $ObjectDirectory) {
    $ObjectDirectory = Join-Path $repoRoot "src\build\win32\x64\Release\obj\SwgGodClient"
}
if (-not $QtDllPath) {
    $QtDllPath = Join-Path $repoRoot "deps\qt3-win64-src\lib\qt-mt3.dll"
}
if (-not $QtImportLibraryPath) {
    $QtImportLibraryPath = Join-Path $repoRoot "deps\qt3-win64-src\lib\qt-mt3.lib"
}
if (-not $QtMainLibraryPath) {
    $QtMainLibraryPath = Join-Path $repoRoot "deps\qt3-win64-src\lib\qtmain.lib"
}
if (-not $GodClientPath) {
    $GodClientPath = Join-Path $repoRoot "src\build\win32\x64\Release\SwgGodClient_r.exe"
}
if (-not $CompileTlogPath) {
    $CompileTlogPath = Join-Path $ObjectDirectory "SwgGodClient.tlog\CL.command.1.tlog"
}
if (-not $LinkTlogPath) {
    $LinkTlogPath = Join-Path $ObjectDirectory "SwgGodClient.tlog\link.command.1.tlog"
}
if (-not $BuildMetadataPath) {
    $BuildMetadataPath = Join-Path $repoRoot "deps\qt3-win64-src\lib\qt3-x64-build.json"
}
if (-not $ContractPath) {
    $ContractPath = Join-Path $PSScriptRoot "qt3-godclient-symbol-contract.txt"
}

if (-not (Test-Path -LiteralPath $ObjectDirectory -PathType Container)) {
    throw "The GodClient Release|x64 object directory was not found: $ObjectDirectory. Build SwgGodClient Release|x64 or pass -ObjectDirectory."
}
$ObjectDirectory = (Resolve-Path -LiteralPath $ObjectDirectory).Path

if (-not (Test-Path -LiteralPath $QtDllPath -PathType Leaf)) {
    throw "The Qt 3 x64 DLL was not found: $QtDllPath. Build the local Qt 3 x64 runtime or pass -QtDllPath."
}
$QtDllPath = (Resolve-Path -LiteralPath $QtDllPath).Path

foreach ($libraryVariable in @("QtImportLibraryPath", "QtMainLibraryPath")) {
    $path = Get-Variable -Name $libraryVariable -ValueOnly
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "The Qt 3 x64 library was not found: $path"
    }
    Set-Variable -Name $libraryVariable -Value (Resolve-Path -LiteralPath $path).Path
}

if (-not (Test-Path -LiteralPath $GodClientPath -PathType Leaf)) {
    throw "The linked GodClient Release|x64 executable was not found: $GodClientPath"
}
$GodClientPath = (Resolve-Path -LiteralPath $GodClientPath).Path

if (-not (Test-Path -LiteralPath $CompileTlogPath -PathType Leaf)) {
    throw "The GodClient Release|x64 compile command log was not found: $CompileTlogPath"
}
$CompileTlogPath = (Resolve-Path -LiteralPath $CompileTlogPath).Path

if (-not (Test-Path -LiteralPath $LinkTlogPath -PathType Leaf)) {
    throw "The GodClient Release|x64 link command log was not found: $LinkTlogPath"
}
$LinkTlogPath = (Resolve-Path -LiteralPath $LinkTlogPath).Path

if (-not (Test-Path -LiteralPath $BuildMetadataPath -PathType Leaf)) {
    throw "The Qt 3 x64 build metadata was not found: $BuildMetadataPath. Run Build-X64Qt3.ps1 -Clean."
}
$BuildMetadataPath = (Resolve-Path -LiteralPath $BuildMetadataPath).Path

if (-not (Test-Path -LiteralPath $ContractPath -PathType Leaf)) {
    throw "The checked-in GodClient Qt symbol contract was not found: $ContractPath. Pass -ContractPath to use another baseline."
}
$ContractPath = (Resolve-Path -LiteralPath $ContractPath).Path

$objects = @(
    Get-ChildItem -LiteralPath $ObjectDirectory -Filter "*.obj" -File |
        Sort-Object FullName
)
if ($objects.Count -eq 0) {
    throw "No .obj files were found in the GodClient Release|x64 object directory: $ObjectDirectory"
}

$vsRoot = Get-VisualStudioRoot -RequestedRoot $VisualStudioRoot
$dumpbin = Get-DumpbinPath -Root $vsRoot

$compileLogLines = @(Get-Content -LiteralPath $CompileTlogPath)
$compileSourceRecords = @($compileLogLines | Where-Object { $_.StartsWith("^", [StringComparison]::Ordinal) })
$compileCommandRecords = @(
    $compileLogLines |
        Where-Object { $_ -and -not $_.StartsWith("^", [StringComparison]::Ordinal) }
)
if ($compileSourceRecords.Count -ne $objects.Count -or $compileCommandRecords.Count -ne $objects.Count) {
    throw "Expected one source and command record per GodClient object. Objects: $($objects.Count); sources: $($compileSourceRecords.Count); commands: $($compileCommandRecords.Count)."
}
foreach ($requiredDefine in @("QT_DLL", "QT_NO_STL", "QT_ACCESSIBILITY_SUPPORT")) {
    $definePattern = '(?i)(?:^|\s)/D\s*"?{0}"?(?=\s|$)' -f [Regex]::Escape($requiredDefine)
    $missingDefineRecords = @($compileCommandRecords | Where-Object { $_ -notmatch $definePattern })
    if ($missingDefineRecords.Count -ne 0) {
        throw "$($missingDefineRecords.Count) of $($compileCommandRecords.Count) GodClient compile commands omit the required $requiredDefine definition: $CompileTlogPath"
    }
}

$buildMetadata = Get-Content -LiteralPath $BuildMetadataPath -Raw | ConvertFrom-Json
$metadataProperties = @($buildMetadata.PSObject.Properties.Name)
foreach ($requiredProperty in @("formatVersion", "cleanBuild", "artifacts")) {
    if ($metadataProperties -notcontains $requiredProperty) {
        throw "The Qt build metadata omits the required '$requiredProperty' property: $BuildMetadataPath"
    }
}
if ([int]$buildMetadata.formatVersion -ne 1) {
    throw "Unsupported Qt build metadata format version '$($buildMetadata.formatVersion)': $BuildMetadataPath"
}
if (-not $AllowIncrementalQtBuild -and -not [bool]$buildMetadata.cleanBuild) {
    throw "The Qt build metadata describes an incremental build. Run Build-X64Qt3.ps1 -Clean or pass -AllowIncrementalQtBuild."
}

$metadataQtRoot = [IO.Path]::GetFullPath((Split-Path -Parent (Split-Path -Parent $BuildMetadataPath)))
$metadataQtRootPrefix = $metadataQtRoot.TrimEnd("\") + "\"
$expectedArtifactPaths = [string[]]@(
    "bin/qmake.exe",
    "bin/moc.exe",
    "lib/qt-mt3.dll",
    "lib/qt-mt3.lib",
    "lib/qtmain.lib",
    "lib/qui.lib"
)
$expectedArtifactSet = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($path in $expectedArtifactPaths) {
    [void]$expectedArtifactSet.Add($path)
}
$metadataArtifacts = @($buildMetadata.artifacts)
if ($metadataArtifacts.Count -ne $expectedArtifactPaths.Count) {
    throw "Expected exactly $($expectedArtifactPaths.Count) stamped Qt artifacts, found $($metadataArtifacts.Count): $BuildMetadataPath"
}
$artifactByPath = [System.Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
foreach ($artifact in $metadataArtifacts) {
    $artifactProperties = @($artifact.PSObject.Properties.Name)
    foreach ($requiredProperty in @("path", "bytes", "sha256", "machine")) {
        if ($artifactProperties -notcontains $requiredProperty) {
            throw "A Qt metadata artifact omits the required '$requiredProperty' property: $BuildMetadataPath"
        }
    }

    $relativeArtifactPath = [string]$artifact.path
    if (-not $expectedArtifactSet.Contains($relativeArtifactPath)) {
        throw "The Qt metadata contains an unexpected artifact path: $relativeArtifactPath"
    }
    if ($artifactByPath.ContainsKey($relativeArtifactPath)) {
        throw "The Qt metadata contains a duplicate artifact path: $relativeArtifactPath"
    }
    $artifactByPath.Add($relativeArtifactPath, $artifact)

    $artifactPath = [IO.Path]::GetFullPath((Join-Path $metadataQtRoot ($relativeArtifactPath -replace '/', '\')))
    if (-not $artifactPath.StartsWith($metadataQtRootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "A stamped Qt artifact resolves outside its build tree: $relativeArtifactPath"
    }
    if (-not (Test-Path -LiteralPath $artifactPath -PathType Leaf)) {
        throw "A stamped Qt build artifact is missing: $artifactPath"
    }
    $artifactItem = Get-Item -LiteralPath $artifactPath
    if ($artifactItem.Length -ne [int64]$artifact.bytes) {
        throw "A Qt build artifact size does not match its metadata stamp: $artifactPath"
    }
    $actualHash = (Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256).Hash
    if (-not [string]::Equals($actualHash, [string]$artifact.sha256, [StringComparison]::OrdinalIgnoreCase)) {
        throw "A Qt build artifact does not match its metadata stamp: $artifactPath"
    }
    if (-not [string]::Equals([string]$artifact.machine, "x64", [StringComparison]::Ordinal)) {
        throw "A Qt metadata artifact is not stamped as x64: $relativeArtifactPath"
    }
}

$boundQtArtifacts = [ordered]@{
    "lib/qt-mt3.dll" = $QtDllPath
    "lib/qt-mt3.lib" = $QtImportLibraryPath
    "lib/qtmain.lib" = $QtMainLibraryPath
}
foreach ($relativeArtifactPath in $boundQtArtifacts.Keys) {
    $actualHash = (Get-FileHash -LiteralPath $boundQtArtifacts[$relativeArtifactPath] -Algorithm SHA256).Hash
    $expectedHash = [string]$artifactByPath[$relativeArtifactPath].sha256
    if (-not [string]::Equals($actualHash, $expectedHash, [StringComparison]::OrdinalIgnoreCase)) {
        throw "The supplied Qt input does not match its build metadata stamp: $($boundQtArtifacts[$relativeArtifactPath])"
    }
}

if ((Get-PeMachine -Path $QtDllPath) -ne 0x8664) {
    throw "Expected an x64 Qt DLL: $QtDllPath"
}
if ((Get-PeMachine -Path $GodClientPath) -ne 0x8664) {
    throw "Expected an x64 GodClient executable: $GodClientPath"
}
foreach ($libraryPath in @($QtImportLibraryPath, $QtMainLibraryPath)) {
    if ((Get-CoffLibraryMachine -DumpbinPath $dumpbin -Path $libraryPath) -ne 0x8664) {
        throw "Expected an x64 Qt COFF library: $libraryPath"
    }
}

$adjacentQtDllPath = Join-Path (Split-Path -Parent $GodClientPath) "qt-mt3.dll"
if (-not (Test-Path -LiteralPath $adjacentQtDllPath -PathType Leaf)) {
    throw "The Qt runtime DLL was not staged beside GodClient: $adjacentQtDllPath"
}
$adjacentQtDllPath = (Resolve-Path -LiteralPath $adjacentQtDllPath).Path
$builtQtDllHash = (Get-FileHash -LiteralPath $QtDllPath -Algorithm SHA256).Hash
$adjacentQtDllHash = (Get-FileHash -LiteralPath $adjacentQtDllPath -Algorithm SHA256).Hash
if (-not [string]::Equals($builtQtDllHash, $adjacentQtDllHash, [StringComparison]::OrdinalIgnoreCase)) {
    throw "The Qt runtime DLL beside GodClient does not match the validated build: $adjacentQtDllPath"
}
if ((Get-PeMachine -Path $adjacentQtDllPath) -ne 0x8664) {
    throw "Expected an x64 Qt runtime DLL beside GodClient: $adjacentQtDllPath"
}

$godClientTimestamp = (Get-Item -LiteralPath $GodClientPath).LastWriteTimeUtc
$linkTlogItem = Get-Item -LiteralPath $LinkTlogPath
$linkCommand = Get-Content -LiteralPath $LinkTlogPath -Raw
if ($linkCommand -notmatch "(?i)(?:^|\s)/MACHINE:X64(?=\s|$)") {
    throw "The GodClient link command is not explicitly x64: $LinkTlogPath"
}
if ($linkCommand -match "(?i)(?:^|\s)/FORCE(?::\S+)?(?=\s|$)") {
    throw "The GodClient link command uses /FORCE, so the linked executable cannot prove symbol completeness: $LinkTlogPath"
}
if ($linkCommand.IndexOf($GodClientPath, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
    throw "The link command log is not bound to the validated GodClient executable: $LinkTlogPath"
}
foreach ($requiredLibraryName in @("qt-mt3.lib", "qtmain.lib")) {
    $libraryPattern = '(?i)(?:^|\s)"?{0}"?(?=\s|$)' -f [Regex]::Escape($requiredLibraryName)
    if ($linkCommand -notmatch $libraryPattern) {
        throw "The GodClient link command omits the required $requiredLibraryName input: $LinkTlogPath"
    }
}
$linkTimestampDeltaSeconds = [Math]::Abs(($linkTlogItem.LastWriteTimeUtc - $godClientTimestamp).TotalSeconds)
if ($linkTimestampDeltaSeconds -gt 5) {
    throw "The GodClient link command log is not contemporaneous with the executable (delta: $linkTimestampDeltaSeconds seconds): $LinkTlogPath"
}

$newerLinkInput = @(
    @($objects.FullName) + @($QtDllPath, $QtImportLibraryPath, $QtMainLibraryPath, $CompileTlogPath) |
        Where-Object { (Get-Item -LiteralPath $_).LastWriteTimeUtc -gt $godClientTimestamp }
)
if ($newerLinkInput.Count -ne 0) {
    throw "The GodClient executable predates a required object/library input. Relink Release|x64:$([Environment]::NewLine)$($newerLinkInput -join [Environment]::NewLine)"
}

# Half A: harvest every undefined symbol and normalize import-pointer names to
# their linker target. The explicit decorated DLL-import subset is retained as
# a diagnostic, but it does not cover direct Qt references from all objects.
$normalizedUndefined = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$decoratedImports = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($object in $objects) {
    $symbolLines = Invoke-Dumpbin -DumpbinPath $dumpbin -Mode "/symbols" -InputPath $object.FullName
    foreach ($line in $symbolLines) {
        if ([string]$line -match "\bUNDEF\b.*\|\s+(\S+)") {
            $symbol = $Matches[1]
            if ($symbol -match "^__imp_(.+)$") {
                $symbol = $Matches[1]
            }
            [void]$normalizedUndefined.Add($symbol)
        }
        if ([string]$line -match "\|\s+(\S+)" -and $Matches[1] -match "^__imp_(\?.+)$") {
            [void]$decoratedImports.Add($Matches[1])
        }
    }
}

if ($normalizedUndefined.Count -eq 0) {
    throw "No undefined symbols were found in $($objects.Count) object files under: $ObjectDirectory"
}
if ($decoratedImports.Count -eq 0) {
    throw "No decorated C++ DLL imports matching '__imp_?...' were found in $($objects.Count) object files under: $ObjectDirectory"
}

# Half B: read the DLL's linker-visible export names. Keep all names in the
# set so the comparison mirrors the linker's exact, case-sensitive lookup.
$qtExports = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$decoratedExportCount = 0
$exportLines = Invoke-Dumpbin -DumpbinPath $dumpbin -Mode "/exports" -InputPath $QtDllPath
foreach ($line in $exportLines) {
    if ([string]$line -match "^\s+\d+\s+[0-9A-Fa-f]+\s+[0-9A-Fa-f]+\s+(\S+)(?:\s|$)") {
        $symbol = $Matches[1]
        if ($qtExports.Add($symbol) -and $symbol.StartsWith("?", [StringComparison]::Ordinal)) {
            $decoratedExportCount++
        }
    }
}

if ($qtExports.Count -eq 0) {
    throw "No exports were found in the Qt 3 x64 DLL: $QtDllPath"
}

$qtImportMembers = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$memberLines = Invoke-Dumpbin -DumpbinPath $dumpbin -Mode "/linkermember:1" -InputPath $QtImportLibraryPath
foreach ($line in $memberLines) {
    if ([string]$line -match "^\s+[0-9A-Fa-f]+\s+(\S+)\s*$") {
        $symbol = $Matches[1]
        if ($symbol.StartsWith("__imp_", [StringComparison]::Ordinal)) {
            $symbol = $symbol.Substring(6)
        }
        [void]$qtImportMembers.Add($symbol)
    }
}
if ($qtImportMembers.Count -eq 0) {
    throw "No linker members were found in the Qt 3 x64 import library: $QtImportLibraryPath"
}

$godClientQtImports = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$importLines = Invoke-Dumpbin -DumpbinPath $dumpbin -Mode "/imports:qt-mt3.dll" -InputPath $GodClientPath
foreach ($line in $importLines) {
    if ([string]$line -match "^\s+[0-9A-Fa-f]+\s+(\S+)\s*$") {
        $symbol = $Matches[1]
        if ($symbol.StartsWith("?", [StringComparison]::Ordinal)) {
            [void]$godClientQtImports.Add($symbol)
        }
    }
}
if ($godClientQtImports.Count -eq 0) {
    throw "The linked GodClient executable imports no symbols from qt-mt3.dll: $GodClientPath"
}

$baselineLines = @(
    Get-Content -LiteralPath $ContractPath |
        Where-Object { $_ -and -not $_.StartsWith("#", [StringComparison]::Ordinal) }
)
if ($baselineLines.Count -eq 0) {
    throw "The GodClient Qt symbol contract contains no symbols: $ContractPath"
}

$baseline = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($symbol in $baselineLines) {
    if (-not $baseline.Add($symbol)) {
        throw "The GodClient Qt symbol contract contains a duplicate symbol: $symbol"
    }
}
$sortedBaselineLines = @(Sort-Ordinal -Values $baselineLines)
for ($index = 0; $index -lt $baselineLines.Count; $index++) {
    if (-not [string]::Equals($baselineLines[$index], $sortedBaselineLines[$index], [StringComparison]::Ordinal)) {
        throw "The GodClient Qt symbol contract must be ordinal-sorted: $ContractPath"
    }
}

# The checked-in baseline is Half A: an authoritative demand set harvested
# after a successful non-/FORCE Release|x64 link. Intersections below detect
# current object drift, but never define the baseline from the candidate DLL.
$currentDirectQt = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($symbol in $normalizedUndefined) {
    if ($qtImportMembers.Contains($symbol)) {
        [void]$currentDirectQt.Add($symbol)
    }
}

$missingQtExports = @(Sort-Ordinal -Values @($baseline | Where-Object { -not $qtExports.Contains($_) }))
$missingImportMembers = @(Sort-Ordinal -Values @($baseline | Where-Object { -not $qtImportMembers.Contains($_) }))
$missingCurrentSymbols = @(Sort-Ordinal -Values @($baseline | Where-Object { -not $normalizedUndefined.Contains($_) }))
$unexpectedCurrentSymbols = @(Sort-Ordinal -Values @($currentDirectQt | Where-Object { -not $baseline.Contains($_) }))
$missingExecutableImports = @(Sort-Ordinal -Values @($baseline | Where-Object { -not $godClientQtImports.Contains($_) }))
$transitiveExecutableImports = @(Sort-Ordinal -Values @($godClientQtImports | Where-Object { -not $baseline.Contains($_) }))

Write-Host "GodClient object files: $($objects.Count)"
Write-Host "Normalized undefined symbols: $($normalizedUndefined.Count)"
Write-Host "Decorated __imp_ Qt diagnostics: $($decoratedImports.Count)"
Write-Host "Qt DLL exports: $($qtExports.Count) ($decoratedExportCount decorated C++)"
Write-Host "Qt import-library members: $($qtImportMembers.Count)"
Write-Host "Baseline direct Qt symbols: $($baseline.Count)"
Write-Host "Current direct Qt symbols: $($currentDirectQt.Count)"
Write-Host "Baseline symbols missing from Qt DLL: $($missingQtExports.Count)"
Write-Host "Baseline symbols missing from Qt import library: $($missingImportMembers.Count)"
Write-Host "Baseline symbols missing from current objects: $($missingCurrentSymbols.Count)"
Write-Host "Current direct symbols absent from baseline: $($unexpectedCurrentSymbols.Count)"
Write-Host "Baseline symbols missing from linked executable imports: $($missingExecutableImports.Count)"
Write-Host "qtmain/transitive executable imports: $($transitiveExecutableImports.Count)"

if (
    $missingQtExports.Count -ne 0 -or
    $missingImportMembers.Count -ne 0 -or
    $missingCurrentSymbols.Count -ne 0 -or
    $unexpectedCurrentSymbols.Count -ne 0 -or
    $missingExecutableImports.Count -ne 0
) {
    $residueSections = [System.Collections.Generic.List[string]]::new()
    if ($missingQtExports.Count -ne 0) {
        $residueSections.Add("Baseline symbols missing from Qt DLL:")
        $residueSections.AddRange([string[]]@($missingQtExports | ForEach-Object { "  $_" }))
    }
    if ($missingImportMembers.Count -ne 0) {
        $residueSections.Add("Baseline symbols missing from Qt import library:")
        $residueSections.AddRange([string[]]@($missingImportMembers | ForEach-Object { "  $_" }))
    }
    if ($missingCurrentSymbols.Count -ne 0) {
        $residueSections.Add("Baseline symbols missing from current objects:")
        $residueSections.AddRange([string[]]@($missingCurrentSymbols | ForEach-Object { "  $_" }))
    }
    if ($unexpectedCurrentSymbols.Count -ne 0) {
        $residueSections.Add("Current direct symbols absent from baseline:")
        $residueSections.AddRange([string[]]@($unexpectedCurrentSymbols | ForEach-Object { "  $_" }))
    }
    if ($missingExecutableImports.Count -ne 0) {
        $residueSections.Add("Baseline symbols missing from linked executable imports:")
        $residueSections.AddRange([string[]]@($missingExecutableImports | ForEach-Object { "  $_" }))
    }
    throw "Qt 3 x64 symbol contract failed.$([Environment]::NewLine)$($residueSections -join [Environment]::NewLine)"
}

[pscustomobject]@{
    ObjectCount = $objects.Count
    CompileCommandCount = $compileCommandRecords.Count
    NormalizedUndefinedCount = $normalizedUndefined.Count
    DecoratedImportCount = $decoratedImports.Count
    ExportCount = $qtExports.Count
    DecoratedExportCount = $decoratedExportCount
    ImportLibraryMemberCount = $qtImportMembers.Count
    BaselineDirectQtCount = $baseline.Count
    CurrentDirectQtCount = $currentDirectQt.Count
    MissingQtExportCount = $missingQtExports.Count
    MissingImportMemberCount = $missingImportMembers.Count
    MissingCurrentSymbolCount = $missingCurrentSymbols.Count
    UnexpectedCurrentSymbolCount = $unexpectedCurrentSymbols.Count
    LinkedQtImportCount = $godClientQtImports.Count
    MissingExecutableImportCount = $missingExecutableImports.Count
    TransitiveExecutableImportCount = $transitiveExecutableImports.Count
    ObjectDirectory = $ObjectDirectory
    QtDllPath = $QtDllPath
    QtImportLibraryPath = $QtImportLibraryPath
    QtMainLibraryPath = $QtMainLibraryPath
    AdjacentQtDllPath = $adjacentQtDllPath
    GodClientPath = $GodClientPath
    CompileTlogPath = $CompileTlogPath
    LinkTlogPath = $LinkTlogPath
    BuildMetadataPath = $BuildMetadataPath
    ContractPath = $ContractPath
    DumpbinPath = $dumpbin
}
