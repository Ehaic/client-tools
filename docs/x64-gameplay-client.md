# x64 Gameplay Client

The `Release|x64` gameplay client builds from this repository with modern MSBuild. The port is self-contained under `client-tools`; it does not reference another source checkout at build time or runtime.

## Prerequisites

- Visual Studio 2026 or Build Tools 2026 with MSBuild 18, Desktop development with C++, and the v145 x64 MSVC toolset.
- Windows 10 SDK 10.0.19041 or newer.
- Microsoft DirectX SDK (June 2010). The similarly named DirectX redistributable is runtime-only and does not contain the build headers or libraries.
- The x64 Visual C++ runtime and the legacy DirectX runtime. The stage script verifies `vcruntime140.dll` and `d3dx9_43.dll` in `System32`.

The required non-system libraries and runtime DLLs, including libjpeg-turbo and SDL 3.4.10, are vendored in `deps/x64`. JUCE 8.0.14 audio modules are vendored under `src/external/3rd/library/JUCE-8.0.14`; no separate JUCE, SDL, or libjpeg-turbo installation is required.

Check or install the complete build profile from the repository root:

```powershell
.\scripts\Test-X64BuildPrerequisites.ps1
# Run this command from elevated PowerShell when anything is missing:
.\scripts\Setup-X64BuildPrerequisites.ps1 -Install
```

The setup script downloads Microsoft installers into the ignored `deps/source-cache/build-prerequisites` cache, verifies their signatures and pinned hashes, and installs only missing components. See [the prerequisite manifest guide](../deps/build-prerequisites/README.md) for direct links and offline-cache commands.

## Build

From the repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Build-X64Client.ps1
```

The script validates the complete x64 build profile, locates MSBuild 18 with v145, builds `SwgClient` as `Release|x64`, and verifies that the client and configured raster DLLs have the x64 PE machine type. It defaults to four MSBuild nodes to avoid exhausting memory while linking the legacy solution; use `-MaxCpuCount` to select another bounded value.

To select a Visual Studio installation or toolset explicitly:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Build-X64Client.ps1 `
  -VisualStudioRoot "C:\Program Files\Microsoft Visual Studio\18\Community" `
  -PlatformToolset v145
```

## Outputs

- `src/build/win32/x64/Release/SwgClient_r.exe`
- `src/build/win32/x64/Release/gl11_r.dll`
- `src/build/win32/x64/Release/DllExport.dll`

## Stage

Stage the built runtime into an existing client data directory:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Stage-X64Client.ps1 `
  -ClientRoot "E:\SWG\Reborn\client-runtime-x64-dx11"
```

For the dedicated Publish 14.1 client, stage the tracked Pre-CU configuration
profile with the x64 runtime:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Stage-X64Client.ps1 `
  -ClientRoot "E:\SWG\PRE-CU-Reborn\PreCU-Client" `
  -RuntimeProfile Precu
```

The profile owns the canonical tracked archive order, login/preload defaults,
1024x768 windowed settings, the legacy-interior Bloom compatibility lock, the
DX11 renderer selection, and the HLSL overrides that translate legacy D3D9
shader assembly for D3D11. It preserves `user.cfg`. Command, combat, buff,
status, progression, weapon-template, string, and UI restoration assets are
owned only by `precu_runtime.tre`; staging reads its response manifest, backs
up, and removes every stale loose copy that could shadow the archive.

Or build and stage in one command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Build-X64Client.ps1 `
  -StagePath "E:\SWG\PRE-CU-Reborn\PreCU-Client" `
  -RuntimeProfile Precu
```

Staging validates every copied PE as x64, backs up replaced runtime/profile/shader files under `.x64-backups` while preserving their relative paths, and writes `x64-runtime-manifest.json`. It deploys only `gl11`, removes backed-up `gl00`, `gl05`, `gl06`, and `gl07` renderer DLLs, installs `precu_runtime.tre` and `precu_worlds.tre`, and installs the complete tracked `scripts/asm2hlsl/converted` tree as loose shader overrides for the Pre-CU profile. It also backs up and removes incompatible local x86 copies of system DLLs such as `dbghelp.dll`, allowing the x64 process to use `System32`. The default `None` profile does not change client configuration, login settings, TOCs, TRE files, or shader assets; `-RuntimeProfile Precu` installs the tracked dedicated configuration, Pre-CU archives, and DX11 shader overrides without changing `user.cfg`.

SDL3 provides native input from as many as eight independent joysticks, throttles, rudder pedals, and gamepads. Existing keymaps continue to load; newly saved keymaps record stable device GUIDs so bindings can be restored after reconnecting or reordering controllers. See [the multi-controller input guide](inputreborn.md) for configuration and compatibility details.

## Current Limits

- x64 audio uses JUCE 8.0.14 with Windows Audio (WASAPI) and in-process WAV, MP3, and Ogg Vorbis decoding. The compatibility layer preserves sample callbacks, looping, seeking, playback-rate changes, 3D positioning, distance falloff, Doppler, obstruction/occlusion filtering, multichannel routing, and room reverb. No Miles DLL is required for x64.
- JUCE 8 modules are dual-licensed under AGPLv3 or the commercial JUCE licence. Anyone distributing this client must select and comply with an applicable JUCE licensing path; see `src/external/3rd/library/JUCE-8.0.14/LICENSE.md`.
- Vivox, Bink, and the retired TCG/browser components do not have usable x64 runtimes in this tree. Keep voice chat and intro video disabled.
- The regular gameplay runtime is DX11-only. The separate x64 God client retains its own renderer workflow; see [the God client guide](god-client.md).
