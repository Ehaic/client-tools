# Steam Deck Release Package

The Steam Deck target is the 64-bit Windows gameplay client running through
Steam's Proton compatibility layer. The package uses the Direct3D 11 renderer,
JUCE audio, and the SDL3 mapped-gamepad backend already built into the client.
It does not include or launch the legacy `SwgClientSetup` utility because that
utility only understands the older Direct3D 9 renderer choices.

## Build and stage

Use legally obtained client data from a complete SWG installation. The data
directory must contain `client.cfg`, its included configuration files, the
`sku*_client.toc` files, and all referenced TRE archives. Client data is not
stored in this source repository and is never downloaded by these scripts.

From a Developer PowerShell prompt:

```powershell
.\scripts\Build-SteamDeckClient.ps1 `
    -ClientAssetRoot 'E:\SWG\Reborn\client-runtime-x64-dx11' `
    -OutputRoot 'E:\SWG\Reborn\SteamDeck'
```

The command creates two separate trees:

- `E:\SWG\Reborn\SteamDeck\build\Release` contains compiler and linker
  outputs.
- `E:\SWG\Reborn\SteamDeck\client` is the clean, copyable runtime package.

The staging step refuses a non-empty destination. This prevents an old DLL,
binary, profile, or configuration file from silently surviving into a release.
It copies only the required root data files and known loose-data directories,
then overlays the freshly built executable, renderer, runtime DLLs, and the Deck
configuration. `steamdeck-runtime-manifest.json` records source provenance,
file sizes, and SHA-256 hashes for the staged runtime.

JUCE is dual-licensed under AGPLv3 or a commercial JUCE license. Anyone
distributing this binary must choose and comply with an applicable license; see
`src/external/3rd/library/JUCE-8.0.14/LICENSE.md`. The original game data has its
own licensing requirements and is deliberately not committed to this repository.
The staged `licenses` directory also carries the SDL3, libxml2, zlib, GNU
libiconv/LGPL, and JUCE notices. A distributor remains responsible for the
source and relinking duties identified there.

## Configure the server

Before building the package, open `login.cfg` in the directory passed as
`ClientAssetRoot` and set `loginServerAddress0` and `loginServerPort0` to an
address reachable from the Deck. A loopback address such as `127.0.0.1` refers
to the Deck itself, not the Windows build machine. If the server changes later,
update the asset-source file and stage a new package into an absent or empty
destination. Editing the staged copy makes its per-file hash and the aggregate
payload hash in `steamdeck-runtime-manifest.json` intentionally stale.

The packaged `options.cfg` selects DX11, 1280x800 borderless output, SDL input,
the first gamepad, stereo speaker output, and skips the intro. The packaged
`user.cfg` intentionally contains no saved account, avatar, profile, or
developer-machine settings.

## Install in SteamOS

1. Copy the complete `client` directory to the Deck without changing its
   internal layout.
2. In Steam Desktop Mode, choose **Games > Add a Non-Steam Game**, browse to
   `SwgClient_r.exe`, and add it.
3. In the shortcut properties, set **Start In** to the package directory. The
   client also anchors its working directory to its executable as a safeguard.
4. Under **Compatibility**, enable **Force the use of a specific Steam Play
   compatibility tool** and select a current Proton release.
5. Return to Gaming Mode and launch the shortcut. No Winetricks setup and no
   `PROTON_USE_WINED3D` launch option are intended for the default DX11/DXVK path.

Valve documents non-Steam shortcuts and Proton on the
[Steam Deck developer documentation](https://partner.steamgames.com/doc/steamdeck/loadgames)
and [Proton documentation](https://partner.steamgames.com/doc/steamhardware/proton?l=english).
The Deck display's native resolution is 1280x800, which is the preset shipped
here.

The SDL backend exposes the Deck as a mapped gamepad. Steam Input can provide a
gamepad layout or keyboard/mouse mappings for any legacy action not covered by
the client's default bindings. `Steam+X` opens the on-screen keyboard.

## Release validation

The Windows build and staging scripts validate the expected x64 PE machine type,
required runtime files, configuration includes, data archives, and hashes. A
release still needs one clean-prefix test on real Steam Deck hardware because a
Windows host cannot validate Proton, DXVK, Steam Input, suspend/resume, or
dock/undock behavior.

For a diagnostic Deck launch only, Valve's Proton logging and DXVK HUD can be
enabled with:

```text
PROTON_LOG=1 DXVK_HUD=devinfo,fps %command%
```

Remove those options after diagnosis.
