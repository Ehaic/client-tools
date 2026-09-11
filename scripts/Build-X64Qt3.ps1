[CmdletBinding()]
param(
    [string]$VisualStudioRoot,

    [switch]$Clean
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-VisualStudioRoot {
    param([string]$RequestedRoot)

    if ($RequestedRoot) {
        $root = (Resolve-Path -LiteralPath $RequestedRoot).Path
        if (-not (Test-Path -LiteralPath (Join-Path $root "Common7\Tools\Launch-VsDevShell.ps1") -PathType Leaf)) {
            throw "VisualStudioRoot is not a Visual Studio installation: $root"
        }
        return $root
    }

    $vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path -LiteralPath $vswhere -PathType Leaf)) {
        throw "vswhere.exe was not found. Run .\scripts\Test-ClientBuildPrerequisites.ps1 for diagnostics or pass -VisualStudioRoot explicitly."
    }

    $root = (& $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath).Trim()
    if (-not $root) {
        throw "Visual Studio with the x64 C++ toolchain was not found. Run .\scripts\Test-ClientBuildPrerequisites.ps1 for diagnostics."
    }
    return $root
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

function Remove-QtGeneratedPath {
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][string]$QtRoot,
        [Parameter(Mandatory)][string]$RelativePath
    )

    $qtRootPrefix = [IO.Path]::GetFullPath($QtRoot).TrimEnd("\") + "\"
    $target = [IO.Path]::GetFullPath((Join-Path $QtRoot $RelativePath))
    if (-not $target.StartsWith($qtRootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to clean a path outside the prepared Qt tree: $target"
    }

    $repositoryRelativePath = "deps/qt3-win64-src/$($RelativePath -replace '\\', '/')"
    $trackedPaths = @(& git -C $RepositoryRoot ls-files -- $repositoryRelativePath)
    if ($LASTEXITCODE -ne 0) {
        throw "git ls-files failed while validating the Qt clean target: $target"
    }
    if ($trackedPaths.Count -ne 0) {
        throw "Refusing to remove a clean target that contains tracked files: $target"
    }

    if (Test-Path -LiteralPath $target) {
        Remove-Item -LiteralPath $target -Recurse -Force
    }
}

function Remove-IgnoredQtGeneratedFiles {
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][string]$QtRoot,
        [Parameter(Mandatory)][string]$RelativeDirectory,
        [Parameter(Mandatory)][string]$Extension
    )

    $qtRootPrefix = [IO.Path]::GetFullPath($QtRoot).TrimEnd("\") + "\"
    $directory = [IO.Path]::GetFullPath((Join-Path $QtRoot $RelativeDirectory))
    if (-not (($directory + "\").StartsWith($qtRootPrefix, [StringComparison]::OrdinalIgnoreCase))) {
        throw "Refusing to enumerate generated files outside the prepared Qt tree: $directory"
    }
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
        return
    }

    foreach ($item in Get-ChildItem -LiteralPath $directory -File) {
        if (-not $item.Extension.Equals($Extension, [StringComparison]::OrdinalIgnoreCase)) {
            continue
        }

        $repositoryRelativePath = $item.FullName.Substring($RepositoryRoot.Length).TrimStart("\") -replace '\\', '/'
        & git -C $RepositoryRoot check-ignore --quiet -- $repositoryRelativePath
        if ($LASTEXITCODE -ne 0) {
            throw "Refusing to remove a generated file that Git does not ignore: $($item.FullName)"
        }

        $qtRelativePath = $item.FullName.Substring($QtRoot.Length).TrimStart("\")
        Remove-QtGeneratedPath -RepositoryRoot $RepositoryRoot -QtRoot $QtRoot -RelativePath $qtRelativePath
    }
}

function Get-CoffLibraryMachine {
    param(
        [Parameter(Mandatory)][string]$DumpbinPath,
        [Parameter(Mandatory)][string]$Path
    )

    $output = @(& $DumpbinPath /nologo /headers $Path 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "dumpbin failed to inspect the Qt library: $Path"
    }

    $machines = @(
        $output |
            ForEach-Object {
                if ([string]$_ -match "^\s+([0-9A-Fa-f]+) machine \(") {
                    [Convert]::ToUInt16($Matches[1], 16)
                }
            } |
            Sort-Object -Unique
    )
    if ($machines.Count -ne 1) {
        throw "Expected one COFF machine type in '$Path', found: $($machines -join ', ')"
    }
    return $machines[0]
}

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$qtRoot = Join-Path $repoRoot "deps\qt3-win64-src"
$vsRoot = Get-VisualStudioRoot -RequestedRoot $VisualStudioRoot
$devShell = Join-Path $vsRoot "Common7\Tools\Launch-VsDevShell.ps1"

if (-not (Test-Path -LiteralPath (Join-Path $qtRoot "qmake\Makefile") -PathType Leaf)) {
    throw "The prepared local Qt 3 x64 source tree is incomplete: $qtRoot"
}
foreach ($marker in @("src\qt.pro", "src\qtmain.pro", "src\moc\moc.pro", "tools\designer\uilib\uilib.pro", "mkspecs\win32-msvc2005\qmake.conf")) {
    if (-not (Test-Path -LiteralPath (Join-Path $qtRoot $marker) -PathType Leaf)) {
        throw "The prepared local Qt 3 x64 source tree is missing its safety marker: $marker"
    }
}

if ($Clean) {
    $generatedPaths = @(
        ".qmake.cache",
        ".qtwinconfig",
        "bin\qmake.exe",
        "bin\moc.exe",
        "bin\qt-mt3.dll",
        "lib",
        "qmake\tmp",
        "src\.qmake.internal.cache",
        "src\moc\Makefile",
        "src\moc\tmp",
        "src\Makefile",
        "src\Makefile.main",
        "src\tmp",
        "tools\designer\uilib\Makefile",
        "tools\designer\uilib\tmp"
    )
    foreach ($relativePath in $generatedPaths) {
        Remove-QtGeneratedPath -RepositoryRoot $repoRoot -QtRoot $qtRoot -RelativePath $relativePath
    }
    # Qt 3's moc Makefile places its object files beside the tracked moc sources,
    # rather than in the configured tmp tree. Resolve each ignored object before
    # deleting it so a clean build cannot reuse stale compiler output.
    Remove-IgnoredQtGeneratedFiles `
        -RepositoryRoot $repoRoot `
        -QtRoot $qtRoot `
        -RelativeDirectory "src\moc" `
        -Extension ".obj"
    Write-Host "Removed ignored Qt 3 x64 build outputs from: $qtRoot"
}

& $devShell -Arch amd64 -HostArch amd64 -SkipAutomaticLocation
$env:QTDIR = $qtRoot
$env:QMAKESPEC = "win32-msvc2005"

# Qt 3's generated nmake files assume their output directories already exist.
$qtBuildDirectories = @(
    (Join-Path $qtRoot "bin"),
    (Join-Path $qtRoot "lib"),
    (Join-Path $qtRoot "qmake\tmp"),
    (Join-Path $qtRoot "src\moc\tmp\obj\release-shared-mt"),
    (Join-Path $qtRoot "src\moc\tmp\moc\release-shared-mt"),
    (Join-Path $qtRoot "src\tmp\obj\release-shared-mt"),
    (Join-Path $qtRoot "src\tmp\moc\release-shared-mt"),
    (Join-Path $qtRoot "tools\designer\uilib\tmp\obj\release-shared-mt"),
    (Join-Path $qtRoot "tools\designer\uilib\tmp\moc\release-shared-mt")
)
foreach ($directory in $qtBuildDirectories) {
    [void](New-Item -ItemType Directory -Path $directory -Force)
}

# qmake consumes this generated cache, so keep checkout-specific paths out of Git.
$qtPath = $qtRoot -replace '\\', '/'
$qmakeCache = @"
QMAKE_QT_VERSION_OVERRIDE=3
OBJECTS_DIR = tmp/obj/release-shared-mt
MOC_DIR = tmp/moc/release-shared-mt
DEFINES +=
INCLUDEPATH +=
sql-drivers +=
sql-plugins +=
styles += cde common compact interlace motifplus motif platinum sgi windows
style-plugins +=
imageformat-plugins +=
QT_PRODUCT=qt-free
CONFIG += enterprise nocrosscompiler rtti warn_off create_prl link_prl minimal-config small-config medium-config large-config full-config release shared thread no-exceptions no-incremental no-largefile no-gif no-tablet ipv6 zlib no-opengl sound precompile_header bigcodecs styles tools thread kernel widgets dialogs iconview workspace network canvas table xml opengl sql accessibility tablet sound png mng jpeg
QMAKESPEC=win32-msvc2005
QT_BUILD_TREE = $qtPath
QT_SOURCE_TREE = $qtPath
QT_INSTALL_PREFIX = $qtPath
QT_INSTALL_TRANSLATIONS = $qtPath/translations
QMAKE_LIBDIR_QT = $qtPath/lib
docs.path = $qtPath/doc
headers.path = $qtPath/include
plugins.path = $qtPath/plugins
libs.path = $qtPath/lib
bins.path = $qtPath/bin
data.path = $qtPath
translations.path = $qtPath/translations
CONFIG -=
CONFIG += shared thread release rtti
"@
[IO.File]::WriteAllText(
    (Join-Path $qtRoot ".qmake.cache"),
    $qmakeCache.TrimStart() + [Environment]::NewLine,
    [Text.Encoding]::ASCII)

$qmake = Join-Path $qtRoot "bin\qmake.exe"
if (-not (Test-Path -LiteralPath $qmake -PathType Leaf)) {
    Push-Location (Join-Path $qtRoot "qmake")
    try {
        & nmake.exe /NOLOGO
        if ($LASTEXITCODE -ne 0) {
            throw "The x64 Qt qmake build failed with exit code $LASTEXITCODE."
        }
    }
    finally {
        Pop-Location
    }
}

& $qmake -spec win32-msvc2005 -o (Join-Path $qtRoot "src\moc\Makefile") (Join-Path $qtRoot "src\moc\moc.pro")
if ($LASTEXITCODE -ne 0) {
    throw "qmake failed to generate the moc Makefile."
}

Push-Location (Join-Path $qtRoot "src\moc")
try {
    & nmake.exe /NOLOGO
    if ($LASTEXITCODE -ne 0) {
        throw "The x64 Qt moc build failed with exit code $LASTEXITCODE."
    }
}
finally {
    Pop-Location
}

& $qmake -spec win32-msvc2005 -o (Join-Path $qtRoot "src\Makefile") (Join-Path $qtRoot "src\qt.pro")
if ($LASTEXITCODE -ne 0) {
    throw "qmake failed to generate the Qt library Makefile."
}
& $qmake -spec win32-msvc2005 -o (Join-Path $qtRoot "src\Makefile.main") (Join-Path $qtRoot "src\qtmain.pro")
if ($LASTEXITCODE -ne 0) {
    throw "qmake failed to generate the qtmain Makefile."
}

Push-Location (Join-Path $qtRoot "src")
try {
    & nmake.exe /NOLOGO
    if ($LASTEXITCODE -ne 0) {
        throw "The x64 Qt library build failed with exit code $LASTEXITCODE."
    }
    & nmake.exe /NOLOGO /F Makefile.main
    if ($LASTEXITCODE -ne 0) {
        throw "The x64 Qt startup library build failed with exit code $LASTEXITCODE."
    }
}
finally {
    Pop-Location
}

$uiLibraryRoot = Join-Path $qtRoot "tools\designer\uilib"
$uiLibraryMakefile = Join-Path $uiLibraryRoot "Makefile"
& $qmake -spec win32-msvc2005 -o $uiLibraryMakefile (Join-Path $uiLibraryRoot "uilib.pro")
if ($LASTEXITCODE -ne 0) {
    throw "qmake failed to generate the Qt widget-factory library Makefile."
}

Push-Location $uiLibraryRoot
try {
    & nmake.exe /NOLOGO
    if ($LASTEXITCODE -ne 0) {
        throw "The x64 Qt widget-factory library build failed with exit code $LASTEXITCODE."
    }
}
finally {
    Pop-Location
}

$artifacts = @(
    $qmake,
    (Join-Path $qtRoot "bin\moc.exe"),
    (Join-Path $qtRoot "lib\qt-mt3.dll")
)
foreach ($path in $artifacts) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Expected x64 Qt artifact is missing: $path"
    }
    if ((Get-PeMachine -Path $path) -ne 0x8664) {
        throw "Expected an x64 Qt artifact: $path"
    }
}

$qtLibraries = @(
    (Join-Path $qtRoot "lib\qt-mt3.lib"),
    (Join-Path $qtRoot "lib\qtmain.lib"),
    (Join-Path $qtRoot "lib\qui.lib")
)
foreach ($path in $qtLibraries) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Expected x64 Qt import library is missing: $path"
    }
}

$dumpbin = (Get-Command dumpbin.exe -ErrorAction Stop).Source
foreach ($path in $qtLibraries) {
    if ((Get-CoffLibraryMachine -DumpbinPath $dumpbin -Path $path) -ne 0x8664) {
        throw "Expected an x64 Qt library: $path"
    }
}

$compiler = (Get-Command cl.exe -ErrorAction Stop).Source
$metadataArtifacts = @(
    $artifacts + $qtLibraries |
        ForEach-Object {
            $item = Get-Item -LiteralPath $_
            [ordered]@{
                path = $item.FullName.Substring($qtRoot.Length).TrimStart("\") -replace '\\', '/'
                bytes = $item.Length
                sha256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
                machine = "x64"
            }
        }
)
$metadata = [ordered]@{
    formatVersion = 1
    generatedAtUtc = [DateTime]::UtcNow.ToString("o")
    cleanBuild = [bool]$Clean
    visualStudioRoot = $vsRoot
    compilerPath = $compiler
    compilerFileVersion = (Get-Item -LiteralPath $compiler).VersionInfo.FileVersion
    qmakeSpec = $env:QMAKESPEC
    configuration = @("shared", "thread", "release", "rtti", "accessibility", "no-exceptions")
    artifacts = $metadataArtifacts
}
$metadataPath = Join-Path $qtRoot "lib\qt3-x64-build.json"
$utf8NoBom = [Text.UTF8Encoding]::new($false)
[IO.File]::WriteAllText(
    $metadataPath,
    ($metadata | ConvertTo-Json -Depth 5) + [Environment]::NewLine,
    $utf8NoBom)

Write-Host "Built local Qt 3 x64 runtime: $(Join-Path $qtRoot 'lib\qt-mt3.dll')"
Write-Host "Built local Qt 3 x64 widget-factory library: $(Join-Path $qtRoot 'lib\qui.lib')"
Write-Host "Build metadata: $metadataPath"
