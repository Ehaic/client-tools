[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$manifest = Get-Content (Join-Path $repoRoot 'deps/build-prerequisites/manifest.json') -Raw | ConvertFrom-Json
$package = $manifest.packages | Where-Object id -eq 'directx-sdk-june-2010'
$installer = Join-Path $env:RUNNER_TEMP $package.fileName

Invoke-WebRequest -Uri $package.url -OutFile $installer
if ((Get-FileHash $installer -Algorithm SHA256).Hash -ne $package.sha256) {
    throw 'DirectX SDK checksum does not match the prerequisite manifest.'
}
# The installer contains the headers and import libraries directly. Extract
# only those inputs; installing its obsolete system runtimes is unnecessary.
$sdkRoot = Join-Path $env:RUNNER_TEMP 'directx-sdk'
& 7z x $installer "-o$sdkRoot" 'DXSDK/Include/*' 'DXSDK/Lib/*' -y
if ($LASTEXITCODE -ne 0) { throw 'DirectX SDK extraction failed.' }
$env:DXSDK_DIR = (Join-Path $sdkRoot 'DXSDK') + '\'

& (Join-Path $PSScriptRoot 'Build-Client.ps1') -Configuration Release `
    -Architecture x64 -Renderer DX11 -AudioBackend Juce -MaxCpuCount 2

$output = Join-Path $repoRoot 'src/build/win32/x64/Release'
$stage = Join-Path $env:RUNNER_TEMP 'swg-dx11-x64'
New-Item -ItemType Directory -Path $stage -Force | Out-Null
Copy-Item (Join-Path $output 'SwgClient_r.exe') $stage
Copy-Item (Join-Path $output 'gl*_r.dll') $stage
Copy-Item (Join-Path $repoRoot 'deps/x64/bin/*.dll') $stage
Copy-Item (Join-Path $repoRoot 'stage-x64/D3DCompiler_47.dll') $stage

$prerequisites = & (Join-Path $PSScriptRoot 'Test-ClientBuildPrerequisites.ps1') -Quiet -PassThru
$redistRoot = Join-Path $prerequisites.VisualStudio.Root 'VC/Redist/MSVC'
$crt = Get-ChildItem "$redistRoot/*/x64/Microsoft.VC*.CRT" -Directory |
    Sort-Object FullName -Descending | Select-Object -First 1
if (-not $crt) { throw 'The app-local x64 Visual C++ runtime was not found.' }
Copy-Item (Join-Path $crt.FullName '*.dll') $stage

# Reject any accidental 32-bit DLL in the client overlay.
Get-ChildItem $stage -File | Where-Object Extension -in '.exe', '.dll' | ForEach-Object {
    $stream = [IO.File]::OpenRead($_.FullName)
    $reader = [IO.BinaryReader]::new($stream)
    try {
        if ($reader.ReadUInt16() -ne 0x5a4d) { throw "Invalid PE file: $_" }
        $stream.Position = 0x3c
        $stream.Position = $reader.ReadInt32()
        if ($reader.ReadUInt32() -ne 0x4550 -or $reader.ReadUInt16() -ne 0x8664) {
            throw "Not an x64 PE binary: $_"
        }
    } finally { $reader.Dispose() }
}

@"
Source repository: $env:GITHUB_REPOSITORY
Source commit: $env:GITHUB_SHA
Build: Release x64, DX11, JUCE audio

This is a binary overlay, not a complete game installation. Use a separate
copy of your game data with matching Galaxies Reborn client-assets. Select
rasterMajor=11 under [ClientGraphics]. Do not mix old 32-bit DLLs into it.
"@ | Set-Content (Join-Path $stage 'BUILD-INFO.txt')
Get-ChildItem $stage -File | Get-FileHash -Algorithm SHA256 |
    ForEach-Object { '{0}  {1}' -f $_.Hash, (Split-Path -Leaf $_.Path) } |
    Set-Content (Join-Path $stage 'SHA256SUMS.txt')
Compress-Archive -Path "$stage/*" -DestinationPath (Join-Path $env:RUNNER_TEMP 'swg-dx11-x64.zip')
