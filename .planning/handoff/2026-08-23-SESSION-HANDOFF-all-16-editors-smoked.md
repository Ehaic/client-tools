# Session handoff — 2026-08-23 — all 16 editors launch-smoked

Branch: `qt-tools-verify` (worktree `D:\Code\swg-qt-tools-worktree`, parent
`D:\Code\Galaxies-Reborn\client-tools`, main branch `x64-dx11-integration`).

**Write the handoff as you go.** Power has now cut three sessions running and
each time the next session had to reconstruct state from the jsonl transcript
under `C:\Users\kenne\.claude\projects\D--Code-swg-qt-tools-worktree\`.

## Where we are

Client visually validated (earlier session). Phase 3 = launch-smoke every
editor. **That is now DONE for all 16.**

Scoring: `w` = real main window up. `c` = runs, but complains about
config/paths. `x` = crash / FATAL / instant exit.

| # | Tool | Score | Evidence |
|---|------|-------|----------|
| 1 | SwgGodClient_r | w | title `SWG God Client - [[God Client Focus] Game Window]` |
| 2 | TerrainEditor_r | w | MFC frame `terrainEditor` + benign "Tip of the Day" |
| 3 | UIBuilder | w | screenshot: File/Edit/Insert/View, Objects tree, Perf Diagnostics |
| 4 | ParticleEditor_r | w | Qt window up |
| 5 | AnimationEditor_r | w | Qt window up |
| 6 | LightningEditor_r | w | Qt window up |
| 7 | SwooshEditor_r | w | Qt window up |
| 8 | NpcEditor_r | **w** | FIXED - 3 stacked defects; Qt chrome + live 3D viewport |
| 9 | SoundEditor_r | w* | alive, but see the client.cfg landmine below |
| 10 | ClientEffectEditor_r | w | Qt window up |
| 11 | QuestEditor_r | **w** | FIXED - QuestEditorConfig.xml ported from the SOE tree |
| 12 | ShipComponentEditor_r | **w** | FIXED - paths ported from the SOE tree |
| 13 | SwgConversationEditor_r | c | full MFC frame + cosmetic `<branch>\exe\win32` warning |
| 14 | SwgDraftSchematicEditor | **w** | FIXED - no dialog; 749 resourceTypes, 24 categories |
| 15 | SwgSpaceQuestEditor_r | **w** | FIXED - 20 mission categories; cosmetic warnings remain |
| 16 | SwgSpaceZoneEditor_r | c | full MFC frame + cosmetic `<branch>\exe\win32` warning |

**FINAL STATE (verified by a clean full-suite run, 2026-08-23 19:0x):**
**16 of 16 tools reach a working main window.**

Raw run: 13 x `w`, 2 x `?`, 1 x `x`.
* The two `?` are **UIBuilder** and **SwgSpaceQuestEditor** — both confirmed good
  by screenshot. They score `?` only because the runner will not guess about a
  process whose sole visible window is class `#32770`: UIBuilder's main window
  legitimately IS a `#32770` (MFC dialog app), and SpaceQuest hides its frame
  behind stacked cosmetic warnings. Dismiss with `_shot3.ps1` to see the frame.
* The one `x` is **NpcEditor** — crash fixed, now blocked on the missing
  `/AvView` UI page (content, not code).

Two defects remain open, both documented in detail below:
1. **NpcEditor** `/AvView` page ships in no dataset on this machine.
2. **SoundEditor** reads `client.cfg` with no skuBits -> mounts zero TREs.
   It launches fine and will fail on first file open. One-line fix + rebuild.

Nothing in the `c` column is a port defect — they are all missing or stale
config data inherited from the SOE build layout.

## NpcEditor — SOLVED end to end (2026-08-23)

**Working.** Qt chrome up (File / View / Zoom / Wearables / Tools / Backdrop,
toolbar, Wearable Customization + Avatar Customization panels) and the embedded
D3D11 viewport rendering the backdrop scene. Screenshot:
`logs/_shots/NpcEditor_r_pw1.png`.

Three separate defects were stacked behind one another. Each only became visible
once the one in front of it was fixed.

### Bug 1 (code) — `strlen(NULL)` in GameWidget's constructor

`GameWidget.cpp:263` assigned `ConfigFile::getKeyString("NpcEditor",
"wearableDirectory", 0, 0)` — whose 4th arg is the default, i.e. NULL — straight
into a `std::string`. cdb stack: `strlen` <- `basic_string::assign` <-
`GameWidget::GameWidget+0x2f3` <- `BaseMainWindow` <- `MainWindow` <- `main`.
**Fixed**: null-guarded with a release-visible `WARNING` (use `WARNING`,
Fatal.h:50 — `DEBUG_WARNING` compiles out in release and would have been silent).

### Bug 2 (content) — the `/AvView` UI page

`NpcCuiMediatorFactorySetup.cpp:74` maps the Viewer mediator to page `/AvView`;
`CuiMediatorFactory_Constructor.h:42` raises STRICT_DATA_FATAL if the page is
absent. It is in no TRE set on this machine.

**Fixed**: SOE's own `ui_root_npceditor.ui` — which defines `/AvView` inline —
was found **loose** in the reference tree at
`D:\SWG All Tools Working\swg\current\data\sku.0\sys.client\compiled\game\ui\`.
Copied to `D:\Code\Galaxies-Reborn\stage-B-override\ui\` (searchPath12,
priority 12, above swgsource_3.0.tre at 8 and the base TREs at 0) and selected
per-tool with `[ClientUserInterface] uiRootName=ui_root_npceditor.ui` in
NpcEditor.cfg. That is exactly how SOE did it — their `NpcEditorCommon.cfg`
carries the same key. Nothing else, client included, is affected.

A hand-authored `ui_npc.inc` was written first and then **discarded** in favour
of SOE's real page. Don't recreate it.

How the page satisfies the code, for future reference —
`CuiMediator::getCodeDataObject` (CuiMediator.cpp:1470) resolves a name by
looking for a property of that name on the page's `CodeData` object and treating
its value as a path; **failing that it falls back to `rootPage->GetChild(name)`**.
SOE's AvView uses the fallback: its children are named `viewerWidget`,
`sampleWearableBox`, `wearableVolumePage`, `currentVolumePage`, `pageWearables`
(plus `hiddenAvatarList` and a `CodeData` object, which must exist — a page with
no CodeData at all FATALs at CuiMediator.cpp:1474).

### Bug 3 (code + config) — `append(NULL)` on the backdrop

With `/AvView` present, construction got as far as
`MainWindow::slotChangeBackdrop`, which does
`getKeyString("NpcEditor", "backdrop", id, 0)` and hands the result to
`NpcCuiViewer::setEnvironmentTexture`, which does `fullpath.append(baseFilename)`
-> `strlen(NULL)`. Same defect class as Bug 1.

**Fixed** both ways: `setEnvironmentTexture` now null-guards and WARNs, and
NpcEditor.cfg gained `backdrop=jedi` (SOE's own value) plus the
defaultClient/Server/Shared/Weapon dsrc paths rebased onto the local tree.

`texture/jedi.dds` is not in the readable TREs, but that is harmless:
`TextureList::fetch(const char *)` passes `createTexture=true`, so a missing file
yields a created/default texture rather than NULL.

### wearableDirectory IS set — an earlier claim here was wrong

A previous revision of this document said there were "no `.lmg` files anywhere on
this machine" and left `wearableDirectory` unset. **That was wrong.** There are
**4,882 `.lmg` files** at

```
D:\SWG All Tools Working\swg\current\data\sku.0\sys.client\compiled\game\appearance\mesh
```

SOE's cfg points at `sys.client/exported/character/appearance/mesh`, which does
not exist here — but this is the *same* `exported/... -> compiled/game/...` remap
already documented above for the string paths. The earlier search covered only
the SWGSource client directory plus that one SOE path, then over-generalised to
"anywhere on this machine".

`wearableDirectory` now points there, and SOE's **60 wearable filter presets**
(30 Name/Expr pairs, verbatim from their `NpcEditorCommon.cfg`) are loaded: the
filter combo reads `Armor:Leg(F)` / `*leg*_f` instead of "Not available".

**Two ordering traps when editing these keys:**
1. `wearableFilterName` / `wearableFilterExpr` are read as parallel indexed lists
   (`GameWidget.cpp:1196,1214`), so each Name must be immediately followed by its
   own Expr.
2. `ConfigFile` sections are positional, so these keys must sit **inside
   `[NpcEditor]`**. They were briefly appended after `[ClientUserInterface]`,
   where they would have silently bound to the wrong section. Verify placement
   after any edit.

`NpcEditor.tab` (SOE's) is in place at `src\build\win32\exe\win32\`.

### CORRECTION to earlier claims in this document

An earlier revision said `/AvView` was absent from "184 UI files across all 209
TREs" and quoted similar totals for retail / SWGEmu / other datasets. **Those
sweeps were weaker than stated.** `scripts/trelist.py` implements TRE **0005**
only, and at the time it had no version guard, so v0006 archives were parsed with
the wrong layout and silently produced corrupt names instead of failing. The GR
client set alone is **72 v0005 + 137 v0006** — so ~two thirds of it was never
actually examined. The guard now makes trelist.py refuse v0006 loudly. The
conclusion happened to hold (the page really was only in the SOE loose tree), but
treat any pre-guard TRE census in this document as covering v0005 archives only.
For anything that must be exhaustive, use SOE's `TreeFileExtractor.exe`.

## Original triage notes: NpcEditor_r (superseded by the section above)

Exits after 5.9 s, code `0x80000003`. Log ends:

```
unknown location : WARNING 860d2942: Could not find skill DEPRECATED_SKILLS in DataTable
NpcEditor_r.exe: unknown.0
unknown location : FATAL be5fbc55: ExceptionHandler invoked
```

Notes for whoever picks this up:

- `NpcEditor_r.exe: unknown.0` is **not** an error — it is the
  `ApplicationVersion` banner (`ApplicationVersion.cpp:70`) that the exception
  handler prints. Don't chase it.
- `0x80000003` is STATUS_BREAKPOINT — the engine's own FATAL debug break, the
  same red herring that made the god client look like a crash yesterday. It is a
  *consequence*, not the cause. The cause is an unhandled SEH exception
  immediately before it.
- The god client logs the same `DEPRECATED_SKILLS` warning and survives, so
  that warning is not the trigger either.
- NpcEditor is the only Qt tool that boots the full client CUI stack
  (`NpcCuiManager`, `NpcCuiMediatorFactorySetup`). `logs/ext/ui.log` shows the
  entire UI type set and every font loading cleanly, so it dies *after* UI load.
- **No minidump was written** — `writeMiniDumps = ApplicationVersion::isBootlegBuild()`
  and this is not a bootleg build. To get a stack: flip that for a local build,
  or attach cdb/WinDbg (`NpcEditor_r.pdb` is right there in Release).

## The client.cfg landmine — SoundEditor (latent, will bite)

`SoundEditor.cpp:449` hardcodes `data.configFile = "client.cfg"`, but line 463
calls `SetupSharedFile::install(false)` — **no skuBits**. Verified by counting
keys: `client.cfg` has 70 `searchTree_00_N` and **zero** legacy `searchTreeN`.
So SoundEditor mounts **zero TREs**.

It still scored `w` because it never touches a TRE asset during startup — its
entire 7-line log is JUCE/WASAPI audio init. **Do not read "it launched" as
"it works."** It will fail the moment you open a sound file.

Fix: change `"client.cfg"` → `"SoundEditor.cfg"` at `SoundEditor.cpp:449` and
rebuild that project. `SoundEditor.cfg` already sits in Release in the correct
legacy form — it is simply never read today.

Related upstream quirk, harmless: `SwooshEditorGameWidget.cpp:18` passes
`"AnimationEditor.cfg"`, not its own. It works, because AnimationEditor.cfg is
in the fixed form. `SwooshEditor.cfg` on disk is dead weight.

## The SOE reference tree at `D:\SWG All Tools Working\swg\current` (found 2026-08-23)

**This is the single most useful thing found this session.** It is a complete
SOE-layout branch — `data/`, `dsrc/`, `exe/` — including `exe/win32/` with the
*original* SOE tool binaries **and their original .cfg / .ini / .xml files**:

```
QuestEditorConfig.xml          SwgDraftSchematicEditor.cfg + .ini
ShipComponentEditor.cfg        SwgSpaceQuestEditor.cfg      + .ini
QuestEditor.cfg + QuestEditorCommon.cfg
NpcEditor.cfg   + NpcEditorCommon.cfg + NpcEditor.tab
SwgSpaceZoneEditor.cfg + .ini  SwgConversationEditor.cfg    + .ini
TerrainEditor.ini              defaults.cfg (UIBuilder)
TreeFileExtractor.exe  TreeFileBuilder.exe  DataTableTool.exe  ViewIff.exe  miff.exe
```

When any tool complains about missing config, **look here first** — the answer
is usually the original file.

`TreeFileExtractor.exe` is SOE's own TRE extractor and handles every TRE
version. Prefer it over `scripts/trelist.py` for anything non-trivial:
trelist.py only implements TRE **0005**, and a large fraction of TREs in the
wild are **0006**, which is a different container entirely (the ones checked
decompress from offset 36 as a single zlib stream containing one IFF `FORM`,
not an archive with a TOC). trelist.py now refuses 0006 loudly rather than
emitting corrupt names.

### Path rebasing rule for this tree

SOE's cfgs use `h:/swg/current/...`. Rebase onto
`D:/SWG All Tools Working/swg/current/...`. One exception, verified by testing
every path: **`data/sku.0/sys.shared/built/game/...` does not exist here** (only
`.../built/game/misc`). The equivalent content lives under
**`data/sku.0/sys.client/compiled/game/...`** — confirmed for
`string/en`, `string/en/quest/ground`, `string/en/conversation`, and
`quest/nym_themepark`. Remap those keys accordingly.

Also absent: `h:/swg/current/tools/` (so `toolPath` / `toolDirectory` are left
unset — not validated by `testFolders()`, only the Compile / p4-edit buttons
use them), and `data/internal/sys.client/built/questeditor/image/...` (the
QuestEditor component icons — only `data/sku.0` exists, so icons will be blank;
not fatal, the fatal was the missing XML).

### AvView is not here either

The 71 readable (v0005) TREs in this tree hold 181 UI files and the same three
UI roots — **no `AvView`**. The other 137 TREs there are v0006 and were NOT
checked. If NpcEditor is ever revisited, `TreeFileExtractor.exe` on those 137
is the way to close that gap, along with reading this tree's `NpcEditor.cfg`
and `NpcEditorCommon.cfg`, which were not examined this session.

## Config gaps CLOSED (2026-08-23) — ported from the SOE reference tree

Four tools went from "complains" to working, by porting SOE's own configs
(see the SOE reference tree section above) rather than authoring anything.

| Tool | Before | After |
|------|--------|-------|
| QuestEditor | `Critical Error: Cannot open file [../../exe/win32/QuestEditorConfig.xml]` | title `QuestEditor Version 2.11` |
| ShipComponentEditor | `Errors in paths` (6 x `c:/projects/swg/x1/...`) | clean window, no dialog |
| SwgDraftSchematicEditor | `not properly configured`, pane `0 armorRatings / 0 craftingTypes / ...` | **no dialog at all**; tree shows all 24 schematic categories; pane reads `4 armorRatings / 29 craftingTypes / 13 damageTypes / 6 ingredientTypes / 749 resourceTypes / 13 stringTables / 61 xpTypes` |
| SwgSpaceQuestEditor | pane blank + `0 spaceZones / 0 questCategories / ...` | tree shows all 20 mission categories; Configuration pane parses real data (`questStringSuffix = [quest_location]`, ...) |

Also given their `[section]` keys and `.ini` files: SwgSpaceZoneEditor,
SwgConversationEditor.

### What was changed

* Six cfgs in `src\build\win32\x64\Release\` gained an **appended** tool section
  (`[QuestEditor]`, `[ShipComponentEditor]`, `[SwgDraftSchematicEditor]`,
  `[SwgSpaceQuestEditor]`, `[SwgSpaceZoneEditor]`, `[SwgConversationEditor]`).
  **Only appended** — the TreeFile keys were not touched.
* `src\build\win32\exe\win32\` created and populated: `QuestEditorConfig.xml`,
  `SwgDraftSchematicEditor.cfg` (tool-parser copy), `SwgDraftSchematicEditor.ini`,
  `SwgConversationEditor.ini`, `NpcEditor.tab`, `SwooshEditor.tab`.
* `.ini` files also copied to the Release dir: SwgSpaceQuestEditor,
  SwgSpaceZoneEditor, TerrainEditor.

### Two traps that cost real time — read before touching these cfgs

**1. Quote every value containing a space.** The local reference tree path is
`D:\SWG All Tools Working\...` — it has spaces. `ConfigFile` splits an unquoted
value on whitespace and keeps only the tail. The symptom is NOT an error: the
tool's own Configuration pane just showed a **silently truncated** path,
`Working/swg/current/data/...`, with the leading `D:/SWG All ` eaten, and every
count stayed 0. `ConfigFile.cpp:222-240` handles quoted values correctly, which
is why ShipComponentEditor (whose SOE cfg quotes its values) worked first try
while the others did not.

**2. Several tools read config from `../../exe/win32/`, NOT the working
directory.** Hardcoded `cms_root` under `#if 1`:

| Tool | File read from `../../exe/win32/` | Source |
|------|-----------------------------------|--------|
| SwgDraftSchematicEditor | `.cfg` **and** `.ini` | `Configuration.cpp:20,312,364` |
| SwgConversationEditor | `.ini` | `Configuration.cpp:20,78` |
| QuestEditor | `QuestEditorConfig.xml` | `QuestEditorConstants.h:30` |
| NpcEditor | `NpcEditor.tab` | `MainWindow.cpp:75` |
| SwooshEditor | `SwooshEditor.tab` | `MainWindow.cpp:856` |

From `src\build\win32\x64\Release` that resolves to `src\build\win32\exe\win32\`.
**SwgDraftSchematicEditor needs its cfg in BOTH places** and they are not
interchangeable: the engine reads the Release-cwd copy for TreeFile keys, while
`Configuration::loadCfg` reads the exe/win32 copy for `serverObjectTemplatePath`
and `draftSchematicDirectory`.

### Every startup dialog, identified (2026-08-23)

All confirmed by screenshot; the SpaceQuest branch box was read off-screen by the
user after a capture-tool artefact (below).

| Tool | Dialog | Status |
|------|--------|--------|
| TerrainEditor | "Tip of the Day" | benign MFC standard |
| UIBuilder | *(none)* - its `#32770` IS the main window | working |
| SwgConversationEditor | "...is not running from `<branch>\exe\win32`. You may be running an older version." | cosmetic |
| SwgSpaceZoneEditor | same | cosmetic |
| SwgSpaceQuestEditor | same, **plus a second, different box** (see below) | cosmetic x2 |
| SwgDraftSchematicEditor | was "not properly configured" | FIXED |
| QuestEditor | was "Cannot open file [../../exe/win32/QuestEditorConfig.xml]" | FIXED |
| ShipComponentEditor | was "Errors in paths" | FIXED |

### SwgSpaceQuestEditor's second dialog is permanent, and that is correct

Full text (read off-screen; see the capture caveat below):

> SwgSpaceQuestEditor is running out of the 'qt-tools-worktree' branch which does
> not match the directories specified by SwgSpaceQuestEditor.cfg. Make sure that
> SwgSpaceQuestEditor.cfg is configured appropriately for your machine.

`SwgSpaceQuestEditor.cpp:132-142` compares `extractBranch(cwd)` against
`extractBranch()` of four config paths. `extractBranch` takes everything after
the first literal `"swg"` substring up to the next `/`:

* cwd `D:\Code\swg-qt-tools-worktree\src\build\win32\x64\Release` -> `qt-tools-worktree`
* cfg `D:/SWG All Tools Working/swg/current/...`                  -> `current`

These can never match unless the tools are run from a path shaped like
`.../swg/<branch>/exe/win32`. **Do not try to "fix" this with config** - it is
structural, harmless, and dismissing it costs one click. (Two of the four paths
it compares, `getSharedQuestListDataTablePath` / `getSharedQuestTaskDataTablePath`,
are not even settable from the cfg - there is no `getKeyString` for them.)
`SwgSpaceZoneEditor.cpp:140` has the identical check.

### Capture-tool caveat: PrintWindow and message boxes

`_shotpw.ps1` uses `PrintWindow(hwnd, hdc, PW_RENDERFULLCONTENT)`. It is reliable
for the tools' own main windows - it captured the whole NpcEditor UI including
the live D3D11 viewport. **It is NOT reliable for MFC message boxes**: it
rendered only the first line of the SpaceQuest branch box, making a perfectly
normal message look truncated mid-sentence and briefly look like a string bug.
If a captured message box looks cut off, read it on-screen before believing it.

The screen-grab helpers (`_shot.ps1` / `_shot2.ps1` / `_shot3.ps1`) have the
opposite failure: `SetForegroundWindow` loses the foreground race often enough
that CopyFromScreen captures whatever else is on top. That happened twice and
both captures (a browser, a chat client) were deleted. Prefer PrintWindow for
app windows, prefer human eyes for message boxes, and trust the per-PID window
enumeration (class + title) over pixels in both cases.
## Original triage of the config gaps (superseded by the section above)

- **QuestEditor** — wants `../../exe/win32/QuestEditorConfig.xml`, a relative
  path from the old win32 layout. The exe now lives in `x64/Release`, so it
  resolves to nothing. Either drop the XML at that relative location or repoint it.
- **ShipComponentEditor** — the dialog lists six hardcoded `c:/projects/swg/x1/...`
  SOE paths: server dsrc + data, shared dsrc + data, clientdata dsrc, and the
  `object_template_crc_string_table.iff`. Needs repointing at this dataset.
- **SwgDraftSchematicEditor** — `Configuration::loadCfg` (`Configuration.cpp:308+`)
  parses its OWN key=value format and requires **`serverObjectTemplatePath`** and
  **`draftSchematicDirectory`**; ours has neither, so it returns false and you get
  the "not properly configured" box. It also wants a companion
  `SwgDraftSchematicEditor.ini` (`loadIni` — template-version and
  base-template keys). After OK the frame does come up, output pane honestly
  reporting `0 armorRatings / 0 craftingTypes / 0 damageTypes / ...`.
  Note `cms_root = "../../exe/win32/"` on one build branch (`Configuration.cpp:20`
  vs `:22`) — check which one this build compiled.
- **SwgSpaceQuestEditor** — same shape: Configuration tab shows empty
  `sharedStringFilePath` and `spaceQuestDirectory`, and 0 spaceZones /
  questCategories / spaceMobiles / factions / cargo files / missionTemplateTypes.
- **"X is not running from `<branch>\exe\win32`"** on Conversation / SpaceQuest /
  SpaceZone — purely cosmetic location check. SpaceQuest stacks three of them
  and does not create its frame until they are all dismissed.

## What is already fixed (don't redo)

Yesterday's session fixed the cfg sku-form bug across all 15 tool cfgs. See the
memory note `tool-cfgs-need-legacy-no-sku-treefile-keys`. Short version: tools
call `SetupSharedFile::install(useFileStreamer)` with no `skuBits`, so
`TreeFile::install` builds `searchTree0` / `searchPath12` / `searchTOC0`, while
only SwgClient passes real skuBits and reads the `_00_` form. **Never sync
`client.cfg` onto the tool cfgs.** Backup of the old sku-form file is
`_cfg.sku-form.bak`.

## Tooling added this session (`src/build/win32/x64/Release/`)

- `_smoke-auto.ps1` — non-interactive replacement for `_smoke.ps1`. Launches each
  editor, waits, enumerates that PID's visible windows (class + title via
  EnumWindows), copies `logs/warning.log` per tool into `logs/_smoke/`, scores,
  kills, writes `_smoke-results.csv`. `-Only <substr>` filters; `-WaitSeconds`
  defaults 14 — **use 30**, the god client is still on its splash at 14 s.
- `_shot.ps1` / `_shot2.ps1` — launch + screenshot each window by window rect.
  `_shot2` dismisses `#32770` message boxes first (via Enter; WM_COMMAND IDOK
  did not take, WM_CLOSE does).
- Screenshots in `logs/_shots/`, per-tool logs in `logs/_smoke/`.

**Known trap — fix before trusting the CSV verdicts.** The auto-verdict treats
any `#32770` window as a modal complaint. That is wrong in both directions:
MFC *dialog-based* apps (UIBuilder) legitimately have `#32770` as their MAIN
window, and Qt error boxes (QuestEditor's "Critical Error",
ShipComponentEditor's "Errors in paths") are class `QWidget` and were scored
`w`. **Score by reading window titles, not window class.** The table at the top
of this document is hand-corrected; the CSV's verdict column is not.

**Second trap:** `SetForegroundWindow` loses the foreground race often enough
that a screenshot can capture whatever else is on top — one capture came back as
the user's browser and was deleted. Treat the per-PID window enumeration
(class + title) as the evidence; the pixels are a bonus.

## Suggested next steps

Status at end of session: **16 of 16 editors launch to a working main window.**
Items 1 and 3 of the original list are DONE (NpcEditor solved; all config data
ported from the SOE tree) — see the sections above.

Remaining, in the order I would do them:

1. **SoundEditor** — the last known code defect. `SoundEditor.cpp:449` hardcodes
   `data.configFile = "client.cfg"` while line 463 calls
   `SetupSharedFile::install(false)` with no skuBits, so it mounts ZERO TREs. It
   launches fine and will fail on first file open. Change the string to
   `"SoundEditor.cfg"` (that file already exists in Release in the correct legacy
   key form) and rebuild just that project. The build path is proven: VS 18 on
   D:, `-p:Platform=x64`, vcxproj directly — see the rebuild section above.
2. **Commit.** Nothing from this session is committed. The working tree holds two
   source fixes (`GameWidget.cpp`, `NpcCuiViewer.cpp`), this `.planning/` handoff,
   `scripts/trelist.py`, `src/build/win32/exe/` (the `../../exe/win32/` config
   payload), and the smoke/screenshot tooling.
   **Watch out:** the tool cfgs under `src/build/win32/x64/Release/` and the loose
   UI override in `D:\Code\Galaxies-Reborn\stage-B-override\ui\` are OUTSIDE this
   repo's tracked tree. Back them up separately or they are lost on a clean
   checkout — and NpcEditor stops working without that UI file.
3. **Functional testing beyond launch.** Everything so far is launch-smoke plus
   screenshots: nothing has been exercised, no file opened, nothing saved. The
   one specific item flagged in the 2026-08-22 notes and still unverified is
   **ParticleEditor's embedded preview** — that is where the composite change
   shows, and it should be a 1:1 crop rather than a squeezed scene.
4. **The 137 v0006 TREs** in the GR client set remain unexamined; `trelist.py`
   implements TRE 0005 only. Use SOE's `TreeFileExtractor.exe` if a census must
   be exhaustive.
5. **Staging DLLs**, open since 2026-08-22: staging has the newer `gl11_r.dll`
   beside the older exe, and `stage-x64/gl05,06,07_r.dll` show as modified in git
   (rebuilt 08-20 18:25, byte-identical sizes to the 08-18 copies in Release).
   No ABI change, harmless — but unresolved.

## OPEN: renderer correctness — outside this session's mandate, unresolved

Reported by the user 2026-08-23 after the 16/16 launch verification, from visual
inspection of the tools that do a **serverless start** (ParticleEditor,
AnimationEditor and friends — engine boots standalone, no sign-in, a naked
character in the viewport). NOT the god client, which goes through the game
sign-in path and renders differently.

Two symptoms, both unexplained:

1. **The skybox renders magenta.**
2. **Terrain looks wrong** in the tools that display it.
3. **Particle effects render as plain rectangles** moving away from the
   character — i.e. unshaded/untextured quads.

**This does not contradict the 16/16 result.** That result means every tool
starts and presents a working UI. It was never a claim that the D3D11 output is
correct. These are different properties and only the first was tested.

### Ruled OUT (checked, with evidence — do not re-run these)

* Missing textures. Exactly one texture failure across every tool log
  (`texture/jedi.dds`, introduced by this session's NpcEditor backdrop config).
  `texture/defaulttexture.dds` is present.
* Missing shaders. `shader/skybox.sht` (data_other_00.tre) and
  `shader/skybox_6sided.sht` (patch_08.tre) both exist. The fallback in
  `ShaderTemplateList.cpp:225` WARNs on failure and never fires.
* Shader linkage. Zero "canonical interpolant signature" warnings — that path
  explicitly warns when a draw "will not render".
* Shader compile failures. Only benign X3206 truncation noise.

### Dead theories — three, all mine, all wrong. Don't repeat them.

1. *Cubemap sampling via the phantom-element path.* Wrong: the phantom layout
   decodes (VertexBufferFormat.h) as `0x1109` = position | color0 |
   texCoordCount1 | texCoordSet0_**2d**. The skybox uses a **3d** set
   (`SkyBoxAppearance.cpp:97-98`), so it is a different format entirely.
2. *The phantom element is the particle quads.* Also wrong. The comment at
   `Direct3d11_InputLayoutCache.cpp:~540` states the case explicitly: "the space
   nebula quads (position/color/texcoord) feed a_vertexlit.vsh, which also
   declares a normal, and retail drew them". `0x1109` matches that exactly, and
   the same log carries `could not open table [datatables/space/nebula/simple.iff]`.
   It is deliberate D3D9-behaviour emulation, fires once per unique layout
   (cached, not per draw), and is benign.
3. *The vacuous ABI guard is the cause.* Unproven and probably not. See below.

### The one real find, stated at its actual weight

`Direct3d11_ShaderReflection.cpp:449` warns that its own constant name table does
not match the shipped `.inc` files, so **the constant ABI guard checked nothing**
— shader constants are not being verified at all. That is a genuine hole in the
port's safety net and the code says it "must be corrected". It is a *diagnostic*
gap, NOT evidence of a render fault. Do not promote it to a cause without a
frame capture showing bad constant data.

### Cheapest next test (do this before anything expensive)

The ParticleEditor tree for a freshly-opened DEFAULT effect literally reads
`Particle Quad ( No Shader )`. An unshaded quad renders as a plain rectangle, so
the particle symptom may simply be an unconfigured default rather than a defect.
Falsify by loading a real effect — there are **1769 `.prt` files** in the
readable TREs, e.g. `appearance/pt_bolt_ion_cannon_proton.prt`. If a real effect
renders correctly, symptom 3 is a non-issue and the search narrows to sky+terrain.

### After that: RenderDoc, not more log archaeology

Logs have now produced three wrong answers. A frame capture answers directly what
they cannot: which draw emits the sky, what SRV/sampler is bound at that draw, and
what is actually in the constant buffer (the one thing nothing currently checks).
`D:\Code\renderdoc-mcp` exists but was NOT connected to this session's MCP servers.

### Capture caveat for whoever looks next

`PrintWindow` did NOT capture ParticleEditor's D3D viewport (came back blank),
though it captured NpcEditor's fine. Screen-region capture works but needs the
window foregrounded, and `SetForegroundWindow` loses the race often enough to
grab unrelated windows. Easiest reliable path is a human screenshot.

### RESOLVED 2026-08-23: symptom 3 (particles as rectangles) was NOT a defect

Loading a real effect settles it. `pt_campfire_s01.prt` (from the SOE tree's
2101 loose .prt files at
`data/sku.0/sys.client/compiled/game/appearance/`) loads and renders correctly —
the character stands in a working campfire, confirmed visually by the user.

The tree for the loaded effect names a shader per emitter:

```
Particle Effect ( Default ) 86
  Emitter -> Particle Quad ( fire )
  Emitter -> Particle Quad ( trailing embers )
  Emitter -> Particle Quad ( trailing smoke )
```

versus the freshly-opened DEFAULT effect, which reads `Particle Quad ( No Shader )`.
An unshaded quad draws as a plain rectangle, so "a bunch of rectangles moving away
from the character" was the unconfigured default behaving correctly.

**The particle rendering path in the DX11 port is working.** Remaining unexplained:
the magenta skybox and the terrain appearance, symptoms 1 and 2 only.

How it was driven, for repeatability: ParticleEditor ignores argv
(`main.cpp` passes it to QApplication only) and opens via `QFileDialog`
(`MainWindow.cpp:292`), so it needs a loose file and UI automation —
foreground the main window, `Ctrl+O` (accel from `ui/BaseMainWindow.ui`
`fileOpenAction`), type the full path, Enter. Guard the keystrokes on
`GetForegroundWindow()` actually being the target, or they land in whatever else
has focus.

Two false signals to ignore when checking whether a load worked: a SUCCESSFUL
load writes nothing to `warning.log` (an unchanged log is not failure), and the
window caption updates late — it read `ParticleEditor_r` for a while after the
load before becoming `... : pt_campfire_s01.prt`.

## RenderDoc setup + capture attempts (2026-08-23, written just before a restart)

Goal: find why the skybox renders magenta and the terrain looks wrong in the
serverless-start tools. Symptom 3 (particles) is already resolved above and was
not a defect.

### MCP is registered — it should be LIVE after the restart

```
claude mcp add --scope user renderdoc \
  "D:\Code\renderdoc-mcp\v0.3.0\renderdoc-mcp-windows-x64-v0.3.0\bin\renderdoc-mcp.exe"
```

Written to `C:\Users\kenne\.claude.json`; `claude mcp list` reports it Connected.
It exposes **52 tools** (open_capture, list_draws, get_pipeline_state,
get_bindings, get_shader, list_resources, export textures, pixel debug, frame
diff...). MCP servers bind at session start, which is why the restart was needed.
**Check the tool list first thing** — if the renderdoc tools are present, prefer
them; they likely include attach-to-a-running-process, which solves the capture
problem described below.

### The CLI works without any MCP and is often faster

`D:\Code\renderdoc-mcp\v0.3.0\renderdoc-mcp-windows-x64-v0.3.0\bin\renderdoc-cli.exe`

```
renderdoc-cli <capture.rdc> <command> [options]
  info | events | draws [--filter T] | pipeline [-e EID] | shader STAGE [-e EID]
  resources [--type T] | export-rt IDX -o DIR [-e EID] | pixel X Y [-e EID]
  pick-pixel X Y | debug pixel X Y -e EID [--trace] | debug vertex VTX -e EID
  mesh EID [--stage vs-out] | snapshot EID -o DIR | usage RES_ID | tex-stats
  assert-pixel EID X Y --expect R G B A | assert-state | assert-image
  capture EXE [-w DIR] [-a ARGS] [-d N] [-o PATH]
```

### THE CAPTURE PROBLEM — read this before retrying `capture`

`capture -d N` waits N **presented frames** then grabs one. There is no
`--timeout` flag and the internal timeout is fixed. Results measured:

| -d N  | outcome |
|-------|---------|
| 120   | SUCCEEDED, but the frame is mid-load: **2 events, 1 draw** — useless |
| 400   | timed out |
| 700   | timed out (even with the window force-foregrounded) |
| 1500  | timed out |
| 2500  | timed out |

Not linear, and the log says why:
`Direct3d11: no compiled shader manifest at 'compiled_shader/manifest.txt';
every program will be compiled at first use.` The first frames that actually
draw the scene each stall compiling shaders, so the frame rate collapses exactly
when the scene appears. "Late enough to show the sky" and "fast enough to beat
the timeout" do not overlap.

Ideas for next time, roughly in order:
1. Use the MCP's own capture tool — it may attach to an already-running process,
   which removes the timing race completely.
2. **Build the shader cache first** so frames stop stalling. The engine wants
   `compiled_shader/manifest.txt`; `ShaderBuilder.exe` exists in the SOE tree at
   `D:\SWG All Tools Working\swg\current\exe\win32\`. With a warm cache a much
   larger `-d` should complete.
3. Manual capture: `qrenderdoc.exe` IS installed at `C:\Program Files\RenderDoc`.
   Launch ParticleEditor from its Launch Application tab, wait until the magenta
   sky is visible, press **F12**. Then analyse the .rdc with the CLI — the
   analysis is the valuable part and needs no automation.

Also note: the app must be **foregrounded** to accumulate frames at a useful rate
(a background window presents very slowly). Force it with ShowWindow/
BringWindowToTop/SetForegroundWindow in a loop while the capture waits.

### CLI quirk that will waste your time

`-o foo.rdc` actually writes **`foo_frame0.rdc`**, then the CLI looks for
`foo.rdc` and reports `error: Capture completed but file not found on disk`.
The capture succeeded — look for the `_frame0` suffix. Confirm against the
RenderDoc log (`%TEMP%\RenderDoc\RenderDoc_<date>.log`), which prints
`Written to disk: <path>`.

### The one capture taken is NOT worth keeping

`pe_skybox_frame0.rdc` (3.6 MB, D3D11, 2 events / 1 draw) is a mid-load frame
with no scene. It lives in this session's scratchpad
(`%TEMP%\claude\D--Code-swg-qt-tools-worktree\<session-id>\scratchpad\`) which is
session-scoped and will be orphaned by the restart. No loss — recapture.

### The analysis plan, once a capture WITH the scene exists

1. `info` — sanity check event/draw counts (a real scene frame will have many).
2. `draws` — find the sky draw. It should be near the start of the frame,
   full-screen, likely depth-write off.
3. `pipeline -e EID` — what is bound: render targets, depth state, and crucially
   the SRVs.
4. `get_bindings` / `resources --type Texture` — is a cubemap actually bound at
   that draw, or the default texture? `SkyBoxAppearance.cpp:97-98` sets
   `setNumberOfTextureCoordinateSets(1)` +
   `setTextureCoordinateSetDimension(0, 3)`, i.e. a 3-component (cube) lookup;
   `SkyBox6SidedAppearance.cpp:271` instead builds six `texture/%s_%s.dds` names.
5. `shader ps -e EID` — the pixel shader for that draw.
6. `pixel X Y -e EID` — get the colour NUMERICALLY. This finally answers "is it
   literally magenta" instead of judging a screenshot.
7. `debug pixel X Y -e EID --trace` — trace the invocation that produced it.
8. If it turns out to be a constant-binding problem, remember the port already
   reports its **constant ABI guard is vacuous**
   (`Direct3d11_ShaderReflection.cpp:449`) — constants are not verified by
   anything, so a frame capture is the only source of truth for what is bound.
9. When the cause is found, `assert-pixel` / `assert-state` turn it into a
   regression check rather than something a human has to eyeball.

### Machine state at restart

No editor processes left running (all ParticleEditor instances stopped). The
working tree is clean and everything is committed. `warning.log` in Release holds
the last injected run; per-tool logs are in `logs/_smoke/`, screenshots in
`logs/_shots/`.

## SOLVED 2026-08-24: the magenta sky is a CLEAR COLOUR, not a failed skybox

Capture `D:\Code\Galaxies-Reborn\stage-B-x64\Capture250.rdc` (D3D11, 26 events,
21 draws, 1280x720) — a real scene frame, taken manually with F12 after the
automated `capture -d N` route proved unworkable (see the capture-problem section
above; the MCP's `capture_frame` is launch-and-delay only, it cannot attach, so
that escape does not exist).

### What the capture proves

`pixel_history` at (640,60) — sky region — on the scene target `ResourceId::214`
returns **exactly one modification for the whole frame**: event 10, a **Clear**,
postMod `(1.0, 0.0, 1.0, 1.0)`.

**There is no skybox draw at all.** Not a mis-sampled cubemap, not a broken
shader, not a bad SRV binding — nothing is drawn there, and what shows through is
the clear colour. Every theory in the "Dead theories" section above was aimed at
the wrong thing, and so was the analysis plan's step 4 (look for a cubemap at the
sky draw): that draw does not exist.

Also established from the same capture, so nobody re-checks:

* The frame is structurally sane: clear (10, 11), scene draws (48..340), one
  3-index fullscreen composite (354) into backbuffer `ResourceId::840`, Present.
* **The composite is innocent.** It faithfully copies 214 -> 840. Its shader
  output at the sky pixel is already magenta because its input is.
* **Non-sky pixels are fine.** (640,400) = `0.63, 0.53, 0.47` (tan),
  (200,650) = `0.43, 0.47, 0.28` (green). Geometry and texturing work.
* Draw bindings are ordinary mesh shaders (`samplerDiffuse0` / `samplerNormal0`);
  the 6-index draws at 271..340 are the particle quads (single sampler `s0`).

### Where the magenta comes from — exact source

`GroundScene.cpp:2344,2371` clears to `terrainObject->getClearColor()`, which is
`ClientProceduralTerrainAppearance::getClearColor` ->
`GroundEnvironment::getClearColor` -> `m_clearColor`, interpolated
(`GroundEnvironment.cpp:1096`) from the environment block's clear-colour ramp.

`EnvironmentBlock::loadColorRamps` (`EnvironmentBlock.cpp:715`) begins

```cpp
Image* const image = fileName ? ImageFormatList::loadImage (fileName) : 0;
if (image && isValid (image))
    ... load the real ramps ...
else
    ... default ramps, including:
    m_clearColorRamp [i] = PackedRgb (255, 0, 255);   // line 811 — MAGENTA
```

`PackedRgb(255,0,255)` is `(1.0, 0.0, 1.0)` — **bit-for-bit the captured pixel**.
It is a deliberate "these ramps did not load" sentinel.

### Why nothing was ever logged — and why the log hunt kept failing

The only diagnostic on that path is

```cpp
DEBUG_WARNING (fileName && *fileName, ("...not in the appropriate format (256w x 8h x 32b tga)"));
```

Two independent reasons it is silent here:

1. `DEBUG_WARNING` **compiles out in release** (`Fatal.h:50` — the same trap the
   NpcEditor `strlen(NULL)` fix hit; use `WARNING` for anything release-visible).
2. The `fileName && *fileName` guard suppresses it **entirely** when the name is
   empty — which is exactly the default-environment-block case.

So the engine takes a documented failure path and says nothing at all. That is
why sessions of log archaeology produced wrong answers: the evidence was never in
the log to begin with.

### Ruled OUT this session, with evidence — do not re-run these

* **TGA loader not installed.** It is. `GameWidget.cpp:271-273` calls
  `SetupSharedImage::setupDefaultData` then `install`, and
  `setupDefaultData` sets `m_supportTarga = true` (`SetupSharedImage.cpp:67`),
  which registers `TargaFormat`. Same in NpcEditor / TerrainEditor /
  ShipComponentEditor.
* **Ramp files missing from the mounted TREs.** They are present:
  `trelist.py "D:/Code/SWGSource Client v3.0" colorramp` finds them in
  `data_other_00.tre`, `patch_00.tre`, `patch_01.tre`, `patch_06.tre`
  (`terrain/colorramp/*.tga` plus loose `terrain/*_colorramp_*.tga`).
* **Ramp files invalid.** Extracted `terrain/colorramp/tatooine_global0.tga`
  and parsed its header: **256w x 8h x 32bpp, uncompressed (imgtype 2)** — 8236
  bytes = 18 header + 8192 pixels + 26 TGA-2.0 footer. That satisfies
  `isValid()` (`EnvironmentBlock.cpp:61`: width 256, height 8 or 10, 32-bit
  format). The data is good.

### What is NOT yet established

Which of the **two** entry conditions into that else-branch actually fires:

* **(a) `fileName` is null/empty** — the block is
  `EnvironmentBlockManager::m_defaultEnvironmentBlock`, which has no
  `colorRampFileName`. This is the likelier one: it also explains the silence
  (the guard suppresses the warning) and it means the serverless tools simply
  never resolve a real environment family, because no planet/terrain environment
  is loaded. Under this reading it is a **scene-setup/content gap in the tools,
  not a DX11 port defect**, and the DX11 renderer is exonerated.
* **(b) the image genuinely fails to load** at runtime despite being valid on
  disk — a TreeFile/streaming problem specific to the tools' mount.

These are cheap to separate and the next session should do exactly that before
anything else.

### Next step — one decisive test, ~15 minutes

Temporarily promote the diagnostic and rebuild ParticleEditor:

```cpp
// EnvironmentBlock.cpp, else-branch of loadColorRamps
WARNING (true, ("EnvironmentBlock::loadColorRamps FALLBACK - fileName=[%s] image=%p",
                fileName ? fileName : "(null)", image));
```

`WARNING` (not `DEBUG_WARNING`) survives release. One run then says which case it
is, and names the file if there is one. Branch (a) -> fix where the tools pick
their environment family; branch (b) -> chase the TreeFile mount.

Worth confirming in the same run: **does the god client show a correct sky?** If
yes, the D3D11 sky path is provably fine and the fault is entirely in how the
serverless tools set up their scene. That single observation splits the problem
in half and costs one launch.

### This also likely explains symptom 2 (terrain looks wrong) — same root cause

The magenta clear is only the most visible of the defaults. The **same**
else-branch replaces every lighting ramp at once
(`EnvironmentBlock.cpp:798-818`): ambient -> `solidGray`, main diffuse and
specular -> `solidWhite` at scale 1, fill and bounce -> `solidBlack`, fog ->
`solidGray`, shadow -> `solidGray`, back/tangent -> `solidBlack`.

That is precisely a flat, wrongly-lit, unfogged world. **Symptoms 1 and 2 are one
bug, not two** — which fits the observation that both appear together in exactly
the serverless-start tools. Fixing the ramp load should be expected to fix both;
if it fixes the sky but not the terrain, then and only then treat terrain as
separate.

### Regression check once fixed

The capture makes this mechanical — `assert-pixel` on the sky region:
`renderdoc-cli <capture.rdc> assert-pixel 354 640 60 --expect <r> <g> <b> 1`.
Any future regression to `1 0 1 1` is caught without a human eyeballing a
screenshot.

## 2026-08-24 (later): the WARNING test ran — answer is EMPTY_NAME, and the cause is `terrain/simple.trn`

The test proposed above was carried out. Result: **case (a)**, and it leads to a
one-line config cause with no DX11 involvement at all.

### What was done

`EnvironmentBlock.cpp`, else-branch of `loadColorRamps`, gained a release-visible
`WARNING` splitting the three possible entry conditions (EMPTY_NAME /
LOAD_FAILED / BAD_FORMAT). Rebuilt `clientTerrain.vcxproj` then
`ParticleEditor.vcxproj`:

```
MSBuild: D:\Program Files\Microsoft Visual Studio\18\Community\MSBuild\Current\Bin\MSBuild.exe
  -p:Configuration=Release -p:Platform=x64 -m
```

Both succeeded (clientTerrain 92 warnings / 0 errors, ParticleEditor 3 / 0).

### Result — unambiguous

```
WARNING b160e5df: EnvironmentBlock::loadColorRamps FALLBACK case=EMPTY_NAME
(default environment block; no colour ramp configured) -> magenta clear
```

Counts over the whole run: **EMPTY_NAME 1, LOAD_FAILED 0, BAD_FORMAT 0.**

So the ramp files were never even *asked* for. Nothing failed to load and
nothing was malformed — which retroactively confirms the three "ruled out"
findings above were correct, and rules the TreeFile/streaming branch (b) out
entirely.

The same log shows terrain shaders compiling and running normally
(`dot3_terrain_imp1`, `terrain_dot3_vs20_blend0`), so terrain *geometry* was
always fine; only its lighting environment was defaulted.

### The actual cause — ParticleEditor loads a bare test terrain

`Game.cpp:859-874`: for `A_particleEditor` / `A_animationEditor`, the scene comes
from `ConfigClientGame::getParticleEditorGroundScene()`, and
`ConfigClientGame.cpp:1088` defines it as

```cpp
ms_particleEditorGroundScene = ConfigFile::getKeyString("ParticleEditor", "groundScene", "terrain/simple.trn");
```

Our `ParticleEditor.cfg` has **no `[ParticleEditor]` section at all**, so the
compiled default applies: **`terrain/simple.trn`** — a bare test terrain with no
environment family. No environment family means no environment block, so
`EnvironmentBlockManager` hands back `m_defaultEnvironmentBlock`, which has an
empty `colorRampFileName`, which takes the fallback, which paints the sky
magenta. Every step is now accounted for.

`terrain/simple.trn` is real and present (`data_other_00.tre`); so is
`terrain/tatooine.trn` (`patch_01.tre`).

### Confirming test — pointing it at a real planet

Appended to `src\build\win32\x64\Release\ParticleEditor.cfg` (backup:
`_ParticleEditor.cfg.pre-groundscene.bak`):

```
[ParticleEditor]
	groundScene=terrain/tatooine.trn
```

The run changes character completely: **912 -> 1991 log lines**, and it now
compiles **`vertex_program/stars.vsh` + `pixel_program/stars.psh`** and the
`water_pass2_ps20` pair — celestial and water programs that the `simple.trn` run
never touched. The sky/celestial machinery only engages when a terrain actually
carries an environment.

**Do not misread the remaining EMPTY_NAME line in that run.** It still appears,
and that is correct and harmless: `EnvironmentBlockManager` *always* constructs a
default block with no ramp, independently of how many real blocks load. The
warning proves the default block exists; it does not prove real ones are absent.
The `stars.*` compiles are the evidence that real ones loaded.

### THIS IS PROBABLY NOT A PORT DEFECT — and probably not a defect at all

SOE's own `ParticleEditor.cfg` (reference tree, `exe/win32/`) sets no
`groundScene` either — it is 25 lines and only sets `windowed`, `uiRootName`,
`loadHud=false`, `preloadWorldSnapshot=0`, and includes `tools.cfg` (which also
sets none). So **SOE's ParticleEditor also ran on `terrain/simple.trn` and would
also have shown the magenta clear.** The magenta sky looks like original
behaviour for a bare tool scene, not a DX11 regression.

Which means the DX11 port is **exonerated for symptom 1**, and "fixing" it is a
matter of choosing a nicer default scene for the tools rather than repairing any
rendering code.

### VISUALLY CONFIRMED by the user, 2026-08-24

> "The magenta is gone and I see the tatooine surface, sky box looks a bit
> oversaturated, but could be lighting issue."

That closes the investigation:

* **Symptom 1 (magenta skybox) — RESOLVED.** Cause was the default
  `groundScene=terrain/simple.trn`, a bare test terrain with no environment
  family. Not a DX11 port defect; almost certainly original SOE behaviour.
* **Symptom 2 (terrain looks wrong) — RESOLVED, same root cause**, as predicted.
  The tatooine surface renders. Both symptoms were one bug, and that bug was a
  missing config key rather than any rendering code.

The DX11 port is **exonerated for both**. Every renderer theory from the earlier
sessions (cubemap sampling, the phantom vertex element, the vacuous constant ABI
guard) was chasing a fault that did not exist.

### NEW, SMALL open item: the sky looks oversaturated

Reported in the same observation. This is a **fresh, much narrower** item — the
sky now draws, it just may not be graded right. Candidate causes, none yet
tested: gamma / sRGB handling in the DX11 port, time-of-day position in the
colour ramp (`GroundEnvironment.cpp:1096` interpolates by `m_currentColorIndex`),
or simply how tatooine's ramp looks at that hour.

**Do not theorise this one from source** — that is the mistake that cost this
investigation several sessions. Two cheap measurements first:

1. Re-capture with F12 and read the sky pixel numerically (`pick_pixel`), then
   compare against the corresponding entry in tatooine's colour-ramp TGA. If the
   drawn value matches the ramp, the renderer is right and it is content/hour.
2. Compare against the god client on the same planet — it goes through the same
   `GroundEnvironment` path but a different startup. A matching look there means
   nothing is tool-specific.

Note the tools still run without a compiled shader manifest, so this is also the
moment to check whether anything colour-related differs with a warm cache.

### Code left in place (deliberate, not scaffolding)

The diagnostic was **kept**, but reshaped so it does not become log noise:

* `LOAD_FAILED` and `BAD_FORMAT` -> release-visible `WARNING`. These indicate a
  genuine fault and were previously silent in release; that silence is exactly
  what cost this investigation several sessions.
* `EMPTY_NAME` -> `DEBUG_WARNING` only, because it fires once in every run of
  every tool and the client by design. Keeping it at `WARNING` would have made
  every release log dirty.

`clientTerrain` was rebuilt after the reshape. **ParticleEditor still needs a
relink** to pick it up — it was left running for a visual check and the exe was
locked.

### Loose ends for the next session

1. Relink ParticleEditor (`ParticleEditor.vcxproj`, Release|x64).
2. Decide whether `groundScene=terrain/tatooine.trn` should be kept. It is
   currently in the Release cfg as a TEST with a backup beside it. Note that cfg
   lives OUTSIDE the tracked tree — see the warning about that in the commit
   section above.
3. Confirm visually whether terrain now looks right; that closes or re-opens
   symptom 2.
4. `AnimationEditor` shares the identical code path (`A_particleEditor ||
   A_animationEditor`) and so has the same default and the same magenta sky. Any
   decision here should be applied to both.

## 2026-08-24 (final): groundScene made permanent for BOTH editors, both relinked

### The section name is a trap — it is `[ParticleEditor]` for both tools

There is **no** AnimationEditor equivalent of this key. `Game.cpp:859` handles
`A_particleEditor || A_animationEditor` in one branch and calls
`ConfigClientGame::getParticleEditorGroundScene()` for both, and
`ConfigClientGame.cpp:1088` reads it from section **`"ParticleEditor"`**.

So `AnimationEditor.cfg` needs a `[ParticleEditor]` section. An
`[AnimationEditor]` section would be **silently ignored** — no error, no warning,
the compiled default just keeps applying and the sky stays magenta. The same
holds for `avatarSelection` (`ConfigClientGame.cpp:1089`).

### What was written

The identical block was put in **both** `ParticleEditor.cfg` and
`AnimationEditor.cfg` in `src\build\win32\x64\Release\`, replacing the
provisional TEST block in the former:

```
[ParticleEditor]
	groundScene=terrain/tatooine.trn
```

(with a comment block recording why, the shared-section trap, and the
consequence of omitting it). Backup of the pre-change ParticleEditor cfg:
`_ParticleEditor.cfg.pre-groundscene.bak`.

Both files verified afterwards: sections intact
(`SharedFile / Station / ClientGraphics / SharedFoundation / SharedLog /
ParticleEditor`), and `diff` against the backup shows the appended block as the
only change.

### Rebuilt and verified

`clientTerrain.vcxproj` (for the reshaped diagnostic), then
`ParticleEditor.vcxproj` and `AnimationEditor.vcxproj` — Release|x64, 0 errors
each. Exes relinked 14:54:58 and 14:55:10.

Smoke run of both, 55 s each:

| | ParticleEditor | AnimationEditor |
|---|---|---|
| starts and stays up | yes | yes |
| log lines | 1990 | 2019 |
| `loadColorRamps` warnings | **0** | **0** |
| `stars.vsh` / `stars.psh` compiles | **3** | **3** |

Zero `loadColorRamps` warnings is the expected result, and it means two things
at once: no real ramp fault occurs (`LOAD_FAILED` / `BAD_FORMAT` would now be
release-visible), and the benign `EMPTY_NAME` case is correctly debug-only so it
no longer dirties the release log.

The `stars.*` compiles in **both** confirm the sky/celestial path now engages in
AnimationEditor too — i.e. the shared-section behaviour works as read.

### STILL OUTSTANDING: these cfgs are NOT in the repo

`.gitignore:118` ignores `**/build/win32/x64/`, so every tool cfg under
`src\build\win32\x64\Release\` is untracked — including both files just edited.
**A clean checkout loses all of them**, and with them this fix, the NpcEditor
config work, and the six ported SOE tool sections.

`git ls-files src/build/win32/` returns only 15 entries: the vcxproj/sln files
and the tracked `exe/win32/` payload. Nothing from `x64/Release/`.

This was flagged in the earlier commit section and is still open. It is a
decision, not an oversight — the options are to un-ignore the cfgs, to keep a
tracked snapshot directory, or to accept the loss and rely on this handoff. The
key itself is reproduced verbatim above so it is at least reconstructible.

## 2026-08-24 (final+1): the tool cfgs are now TRACKED — the clean-checkout hole is closed

The open item recorded above ("these cfgs are NOT in the repo") is resolved.
**21 config files** — 16 `.cfg` and 5 `.ini` under
`src\build\win32\x64\Release\` — are now tracked.

### Why the .gitignore change looks the way it does

Three rules covered that path and **all three excluded directories**:

```
src/build/win32/x64/
**/build/win32/x64/
**/x64/Release/
```

Git **never descends into an excluded directory**, so no `!` negation inside
them can ever work. Simply appending `!.../Release/*.cfg` would have done
nothing at all — silently. The rules therefore had to be rewritten to exclude
directory *contents* instead:

```
src/build/win32/x64/**
**/build/win32/x64/**
**/x64/Release/**

!src/build/win32/x64/
!src/build/win32/x64/Release/
!src/build/win32/x64/Release/*.cfg
!src/build/win32/x64/Release/*.ini
```

The two intermediate-directory negations are load-bearing: without them git
stops at `x64/` and never sees the files, no matter what the file patterns say.

**If anyone "tidies" these back into bare directory rules, the tool configs
silently stop being tracked again.** A comment in `.gitignore` says so.

### Verified, not assumed

* `git status --untracked-files=all` on that directory: **exactly 21 files**,
  all `.cfg` / `.ini`.
* Spot-checked `git check-ignore`: `ParticleEditor.cfg`, `AnimationEditor.cfg`,
  `SwgSpaceQuestEditor.ini` -> tracked; `ParticleEditor_r.exe`,
  `_cfg.sku-form.bak` -> still ignored.
* Build output still ignored: `.pdb`, `logs/warning.log`, `_smoke-results.csv`.
* Repo-wide untracked count afterwards: 22 = the 21 configs + `.gitignore`
  itself. Nothing else was loosened.

### What this preserves

Everything a clean checkout used to destroy: the legacy no-sku TreeFile keys
across all tool cfgs, the six ported SOE tool sections, the NpcEditor config
work, and the `[ParticleEditor] groundScene` key that keeps the sky from
rendering magenta.

### CAVEAT — these files contain machine-specific absolute paths

This is the real cost of tracking them, and it should be understood rather than
discovered later. The cfgs point at **this machine's** layout:

* `D:/Code/SWGSource Client v3.0/...` (the TRE set)
* `D:/SWG All Tools Working/swg/current/...` (the SOE reference tree)
* `D:/Code/Galaxies-Reborn/stage-B-override/ui/` (the NpcEditor `/AvView` page)

On any other machine these resolve to nothing, and the failure mode is mostly
**silent** — zero TREs mounted, or counts quietly reading 0 — not an error
dialog. So treat the tracked copies as *this machine's working set plus a
recoverable record of the structure*, not as portable configuration.

If these ever need to work on a second machine, the fix is to parameterise the
roots rather than to hand-edit 21 files; note also the quoting trap recorded
earlier in this document (`ConfigFile` splits unquoted values on whitespace, and
`D:\SWG All Tools Working` contains spaces).

`client.cfg` is among the tracked files. It is the CLIENT config and carries the
`_00_` sku key form. **Never copy it onto a tool cfg** — see the memory note
`tool-cfgs-need-legacy-no-sku-treefile-keys` and the landmine section above.

## 2026-08-24: the oversaturated sky is BLOOM, and the pink is a clamped overflow

Capture `D:\Code\Galaxies-Reborn\stage-B-x64\Capture251.rdc` (D3D11, 351 events,
**346 draws**, 1280x720) — the tatooine scene, taken with F12. Compare with
Capture250's 21 draws: the environment really is loading now.

### The frame's actual structure

| stage | events | target |
|---|---|---|
| scene | 10 (clear) .. ~4030 | `212` (B8G8R8A8_UNORM) |
| bloom downsample | 4033 | `223` (320x180) |
| bloom blur H/V | 4050, 4055 -> `228`; 4065, 4070 -> `230` | 320x180 |
| **bloom composite** | **4088** (reads `212` + `230`) | `214` |
| fog/copy | 4099 (reads `214`) | `48` |
| present blit | 4113 (reads `48`) | `960` swapchain |

### It is NOT a gamma/sRGB problem — that theory is dead

I floated `B8G8R8A8_UNORM` vs `_SRGB` last session as something the capture could
test. **It tested false.** The pale pink is not a colour-space conversion, it is
an arithmetic **overflow that clamps**:

At the sky pixel (640,50), the bloom composite at 4088 outputs
`(1.3608, 0.8078, 0.9353, alpha 2.0)` and the UNORM target clamps it to
`(1.0, 0.808, 0.933)`. Red went past 1.0 and got cut. A clamped red channel with
green and blue left high is exactly "washed-out pink". Nothing is being
mis-converted; something is being added twice.

### The mechanism, read off the shaders

The scene's **alpha channel is the bloom mask**. Two shader disassemblies prove
it:

*Downsample (4033):* accumulates `rgb += sample.rgb * sample.a` over 16 taps and
divides by 16. RGB is weighted **by alpha**, so a pixel only contributes bloom in
proportion to its alpha.

*Composite (4088):* `result.rgba = bloom.rgba * bloom.a + scene.rgba`.

Measured values confirm the mask is working as designed:

| pixel | bloom texture `230` | composite out at 4088 |
|---|---|---|
| sky (160,12) | `1.0, 0.612, 0.710, a=1.0` | `1.361, 0.808, 0.935, a=2.0` -> clamped |
| ground (160,150) | `0.0, 0.0, 0.0, a=1.0` | `0.396, 0.239, 0.224, a=1.0` unchanged |

Bloom **alpha** is 1.0 everywhere; it is bloom **RGB** that is zero over the
ground and bright over the sky. That is the downsample's alpha weighting doing
its job: ground pixels carry alpha ~0, sky pixels carry alpha 1.0.

So the sky's bloom is a blurred copy of a uniformly-alpha-1.0 sky, added back at
full weight — roughly **doubling** it. Hence the overflow. The ground is
untouched, which matches the report exactly: sky oversaturated, terrain fine.

### Sanity check against the authored data

`terrain/colorramp/tatooine_global0.tga` row 5 (the clear-colour ramp) holds
muted values — brightest `145,190,213`, most around `74,74,93`. The captured
scene target agrees: clear `74,55,70`, after the sky dome `111,60,71`. **Dark and
muted all the way through the scene pass.** Everything vivid appears after 4088.
The authored content is not the problem.

### A REAL port deviation found on the way — clear alpha is hardcoded

`Direct3d11_SwapChain::clearViewport` builds its clear colour as

```cpp
float const color[4] = {
    ((colorValue >> 16) & 0xff) / 255.0f,   // R
    ((colorValue >>  8) & 0xff) / 255.0f,   // G
    ((colorValue      ) & 0xff) / 255.0f,   // B
    1.0f };                                 // A  <-- hardcoded
```

The alpha byte `(colorValue >> 24) & 0xff` is **discarded**. Direct3d9 passed
`colorValue` straight to `ms_device->Clear(...)` as a D3DCOLOR, alpha byte
included — and `GroundScene.cpp:2371` clears with `backgroundColor.asUint32()`
where `PackedRgb::asUint32()` (PackedRgb.h:80) returns

```cpp
(r << 16) | (g << 8) | b        // alpha byte is ZERO
```

So retail cleared the scene alpha to **0** ("do not bloom"), and the port clears
it to **1.0** ("bloom at full strength"). Every pixel not overdrawn by geometry
is therefore marked for maximum bloom. This is a genuine, independently
verifiable D3D9->D3D11 behavioural deviation and it is a one-line fix.

### HONEST STATUS — do not treat the clear as proven to be the cause

The clear is **a** cause of sky alpha being 1.0. It is not yet proven to be
**the** cause at this pixel, because the sky dome draw itself (EID 33, 336
indices, single texture, into `212`) also outputs **alpha 1.0** — its
`shaderOut` is `(0.435, 0.234, 0.280, 1.0)`. It draws over the whole dome after
the clear, so at these pixels the clear's alpha may be irrelevant unless D3D9
masked alpha writes for that material.

Two possibilities remain and they need separating before anything is called
fixed:

* **(i)** the clear alpha alone, in which case the one-line fix is sufficient;
* **(ii)** the sky material's alpha write / colour-write mask is not being
  honoured in the port, in which case the clear fix changes nothing at the dome.

### Next step — cheap and decisive, in this order

1. Fix `clearViewport` to decode alpha from `colorValue` rather than forcing
   1.0. It is correct regardless of (i) vs (ii) — the port currently cannot
   express "clear alpha to 0" at all.
2. Rebuild, re-capture, and read the scene target's alpha at a sky pixel.
   Alpha 0 -> case (i), done. Alpha still 1.0 -> case (ii), and the search moves
   to the sky shader's alpha output and the D3D11 blend/write-mask handling.
3. Regression check once fixed: `assert-pixel` at 4088 asserting the composite
   output no longer exceeds 1.0 at a sky pixel.

Do not skip step 2. The measured fact that the dome writes alpha 1.0 itself is
exactly the sort of detail that made the earlier magenta theories wrong.

## 2026-08-24: clear-alpha FIXED and verified — case (i), the clear was the sole cause

### The fix

`Direct3d11_SwapChain::clearViewport` now decodes the alpha byte instead of
forcing 1.0:

```cpp
static_cast<float>((colorValue >> 24) & 0xff) / 255.0f   // was: 1.0f
```

Checked first that this was the only such site in the D3D11 port — the other
`{1.0f, 1.0f, 1.0f, 1.0f}` arrays are blend factors
(`Direct3d11_ShaderImplementationData.cpp:32`, `Direct3d11_StateCache.cpp:243`)
and an input-layout default, not clears.

Rebuilt `Direct3d11.vcxproj` (Release|x64, 0 errors) -> `gl11_r.dll` in the
Release dir. ParticleEditor smoke run afterwards: clean, 1990 log lines, no
FATAL/ERROR lines.

### It was case (i) — and the write-mask question is now ANSWERED

The previous entry left open whether the sky dome's own alpha-1.0 output would
defeat the clear fix. **It does not.** From the new capture at the sky pixel:

| event | before fix | after fix |
|---|---|---|
| 10 (clear) postMod alpha | 1.0 | **0.0** |
| 33 (sky dome) shaderOut alpha | 1.0 | 1.0 (unchanged) |
| 33 (sky dome) **postMod** alpha | 1.0 | **0.0** |

The dome still *outputs* alpha 1.0, but the render target's alpha is **not**
updated — so the colour-write mask **is** correctly masking alpha for that
material in the port. Nothing is wrong with the sky shader or the write-mask
handling. The clear was poisoning the bloom mask, and only the clear.

That is a satisfying result because it also retires the suspicion, raised
earlier, that the port might be mishandling write masks.

### End-to-end verification, all from the capture

| measurement | before | after |
|---|---|---|
| scene alpha at sky | 1.0 | **0.0** |
| bloom texture at sky | `1.0, 0.612, 0.710, a=1.0` | **`0, 0, 0, a=0`** |
| bloom composite shaderOut | `1.361, 0.808, 0.935, a=2.0` (**overflow, clamped**) | **`0.361, 0.196, 0.227, a=0.0`** (no overflow) |
| final backbuffer at sky | `1.0, 0.808, 0.937` = `255,206,239` pink | **`0.369, 0.196, 0.231` = `94,50,59`** muted |

The composite output now equals the scene value passed through untouched, which
is exactly right for a pixel that should not bloom.

### CAVEAT on the before/after colour numbers

The two captures are ~14 minutes apart and ParticleEditor runs a **time-of-day
cycle** (`ParticleEditorIoWin.cpp:365` only pauses it when `timeOfDayCycle` is
off), so the environment has moved between them. **Do not read the absolute RGB
before/after as a like-for-like comparison** — the ground pixel also changed
(`102,61,58` -> `64,46,43`) purely from the time shift.

What *is* time-independent, and is the actual proof: alpha 0 instead of 1.0,
bloom contribution 0 instead of full, and no overflow at the composite. Those
hold regardless of the hour.

### AUTOMATED CAPTURE NOW WORKS — the handoff's idea #2 is confirmed

This capture was taken by the **MCP's `capture_frame`, not by hand**, after
copying the baked shader cache into the Release directory:

```
D:\Code\Galaxies-Reborn\stage-B-x64\compiled_shader\  ->  ...\x64\Release\compiled_shader\
```

206 files / 231-line manifest. With the cache warm, `delayFrames: 900`
**completed** and produced a full 54.5 MB, 346-draw scene frame — where before
the fix every attempt above 120 frames timed out and 120 caught a useless
2-event mid-load frame.

So the capture problem that blocked several sessions is solved: **warm the
shader cache first, then `capture_frame` with a large `delayFrames`.** No human
F12 needed. The cache is safe to leave in place — blobs are keyed by a hash of
the exact compile input, so any mismatch simply recompiles rather than loading a
stale shader.

The `-o foo.rdc` -> `foo_frame<N>.rdc` quirk still applies and still reports a
false "file not found on disk". Here it wrote `alphafix_frame336.rdc`.

### Suggested regression check

`assert-pixel` at the bloom composite asserting the sky pixel's output stays
below 1.0. That turns "the sky is blown out" into a numeric check that does not
need a human to eyeball a screenshot, and it is immune to the time-of-day drift
that makes absolute colours unreliable.

### Remaining

Visual confirmation by eye is still worth doing — the numbers are conclusive
about the overflow, but only a human can say whether the sky now *looks* right.

## 2026-08-24: trelist.py now reads v0006 — and the 137-archive open item is CLOSED

### Do not reverse-engineer this format — there is a reference implementation

The user pointed at **SWG-Toolkit**, which has a full TRE reader set. The
authoritative sources on this machine:

* `D:/Code/swg-client-v2/tools/tre-lint/src/format.ts` — zero-dependency TS,
  every layout verified against real bytes and engine source.
* `D:/Code/SWG-Toolkit/.planning/handoff/2026-08-17-PROVIDER-NOTE-tre-lint-seed-and-v0006-verdict.md`

Check these FIRST for anything TRE-format-shaped. The v0006 record layout in
particular was *arbitrated on real bytes*, not guessed.

### The v0006 layout, and the model that was falsified

Header is the same 36 bytes as v0005 (`token@0 version@4 numberOfFiles@8
tocOffset@12 tocCompressor@16 sizeOfTOC@20 blockCompressor@24 sizeOfNameBlock@28
uncompSizeOfNameBlock@32`, all LE). Only the TOC record differs:

```
v0005 -- 24 B: crc@0 length@4 offset@8 compressor@12 compressedLength@16 fileNameOffset@20
v0006 -- 32 B: crc@0 length@4 offset@8 zero@12 zero@16 fileNameOffset@20 compressor@24 compressedLength@28
```

The v0006 form is the **REORDER** model. A competing **pad** model (compressor /
compressedLength at 12/16, padding at 24..31) is **FALSIFIED** — it scored 0.0%
on every populated archive while reorder won unanimously across all 46 populated
Restoration archives. Do not swap them back. Note the GR engine's own
`TreeVersion.h`/`TreBuilder` carry the pad assumption and are therefore wrong.

Compressor codes: `0` stored, `1` zlib (Restoration dialect), `2` zlib (stock).
Both 1 and 2 are plain zlib.

Tags are big-endian-composed uint32s written little-endian, so a hex dump shows
them mirrored: `TREE`->`EERT`, `0005`->`5000`, `0006`->`6000`. That mirroring is
NOT corruption and not a byte-order bug.

### The 137 v0006 archives contain NOTHING — item closed

```
scanned 209 tre(s) [v0005: 72, v0006: 137], 217533 entries, 137 empty, 0 unreadable
```

Zero unreadable, and the entry total is **unchanged** from the v0005-only count.
Audited every v0006 header directly: **all 137 have an entirely zero header body**
— `numberOfFiles`, `tocOffset`, every field. They declare nothing. This is not a
parse failure and not a limitation of the reader.

So the standing worry that "~two thirds of the corpus was never examined" is
**resolved: there was nothing in it to examine.** Any earlier census that covered
only v0005 archives was, for this corpus, already complete. (The populated v0006
archives the provider note describes belong to the *Restoration* corpus, which is
not installed here.)

Some v0006 files do carry payload — `hotfix_59_client_00.tre` is 1.38 MB of
concatenated zlib streams holding `PEFT` particle IFFs — but with no TOC
indexing them they are containers, not mountable archives, exactly as the
provider note's "container/Restoration; not searchTree-mountable stock" says.

### colorRampFileName, chased for kicks — and a loose end worth recording

`datatables/environment/tatooine.iff` is a `DTII` DataTable, 25 columns, 85 rows.
Column 9 is `Lighting Color Ramps (256x8 tga)` = `CD_colorRampFileName`. Parsed
it fully (row walk consumed exactly 34272 of 34272 bytes, which validates the
layout: `s` = inline NUL-terminated, `I`/`f` = 4 bytes LE).

Tatooine uses exactly **two** ramps across all 17 families:
`tatooine_global0.tga` (weather 0-1) and `tatooine_global1.tga` (weather 2-4).

**The four copies of `tatooine_global0.tga` all DIFFER** (data_other_00,
patch_00, patch_01, patch_06 — four distinct md5s). Any analysis must use the
highest-priority copy; here that is **patch_06**.

The TGA is bottom-origin, and the loader flips it, so image row `r` = file row
`7-r`. That mapping is self-consistent against the known ramp semantics: bounce
= `0,0,0`, fill = `2,1,1`, mainDiffuse = `164,88,47` (a warm orange — exactly
right for twin suns).

**The loose end:** the frame's measured clear colour was `74,55,70`. Under that
mapping the *clear* ramp at the matching time index is `96,88,106` (muted
blue-grey), while `74,55,70` matches the **fog** ramp at the same index to within
one bit of blue (`74,55,69`). Searching every row and all 256 time indices, the
fog row is the only near-exact match; the clear row never takes that value.

That is an observation, **not a diagnosis** — the obvious mechanism is absent:
`GroundScene.cpp:2371` clears to `terrainObject->getClearColor()`,
`ClientProceduralTerrainAppearance::getClearColor` returns
`GroundEnvironment::m_clearColor`, and `GroundEnvironment.cpp:1096` builds that
purely from the clear ramps with nothing modifying it afterwards. So there is no
code path visible that would substitute fog for clear.

Possible and untested: the flip assumption is wrong in some way the semantic
cross-check does not catch; or the environment block in play is not one of these
two files; or something reorders the ramp rows on load. **Cosmetically this does
not matter** — the user judged the result "close enough" and the sky renders
correctly — so this is logged as a curiosity for anyone who wants it, not as an
open defect.

### trelist.py

Rewritten. Reads v0005 and v0006, treats compressor 1 and 2 both as zlib,
reports empty-but-valid archives as empty rather than as errors, prints a
per-version census, and exposes `find()` / `extract()` for import. Usage
unchanged: `python scripts/trelist.py <dir> [substring] [--dump [outdir]]`.

# ===== SESSION END 2026-08-24 — POWER-LOSS SHUTDOWN — START HERE =====

Written under an imminent power cut. **Everything below the line is committed and
safe.** Working tree was clean at the last commit.

## What this session did (7 commits, all pushed to the branch)

| commit | what |
|---|---|
| `d80c55ae9` | magenta sky root-caused via RenderDoc — it is the CLEAR COLOUR; no skybox draw exists |
| `03c006ad0` | `EnvironmentBlock`: warn in release when a colour ramp fails to load |
| `2a368d829` | `groundScene` made permanent for ParticleEditor **and** AnimationEditor |
| `9d2a534ba` | tool cfgs TRACKED — 21 config files no longer lost on a clean checkout |
| `18d589c75` | oversaturated sky root-caused: bloom overflow, not gamma |
| `de6bf4161` | **Direct3d11: decode clear alpha instead of forcing it to 1.0** (the real port fix) |
| `81dc6b286` | `trelist.py` reads TRE v0006; the 137-archive question CLOSED |

**Both original renderer symptoms are closed.** Magenta sky + wrong terrain were
one bug — a missing `groundScene` config key, not a port defect. The
oversaturated sky WAS a genuine D3D11 port defect and is fixed and verified.

## IN FLIGHT AND LOST — re-run this first

A full 16-tool smoke run (`_smoke-auto.ps1 -WaitSeconds 30`) was running in the
background when the shutdown came. **Its results are lost — re-run it.**

It matters more than usual this time: today's `gl11_r.dll` (clear-alpha fix) and
`clientTerrain` (ramp diagnostic) rebuilds sit underneath **every** editor with a
3D viewport, and nothing has confirmed the other 15 tools still launch cleanly
since. Treat the 16/16 result as UNVERIFIED against today's binaries.

```
cd D:\Code\swg-qt-tools-worktree\src\build\win32\x64\Release
.\_smoke-auto.ps1 -WaitSeconds 30
```

Score by reading window TITLES, not window class — the CSV verdict column is
still wrong in both directions (see the trap noted earlier in this document).

## NEXT STEPS, in the order I would do them

### 1. Track `ui_root_npceditor.ui` — the last clean-checkout hole (2 minutes)

`NpcEditor.cfg` is now tracked and points at
`searchPath12="D:/Code/Galaxies-Reborn/stage-B-override"`, but the 11 KB file it
needs — `stage-B-override/ui/ui_root_npceditor.ui` — is **NOT tracked and lives
outside the repo**. A clean checkout therefore produces a tracked cfg pointing at
a missing file, and NpcEditor FATALs again on the absent `/AvView` page.

Precedent for tracking it already exists: `NpcEditor.tab` and
`QuestEditorConfig.xml` under `src/build/win32/exe/win32/` are tracked SOE
originals. Do the same for this file. Verified present this session:
11,349 bytes, dated 2026-08-23 19:37.

### 2. SoundEditor — the shipped fix is HALF-TESTED

`SoundEditor.cpp:449` was changed from `client.cfg` to `SoundEditor.cfg`, rebuilt
and committed (`d17043a48`) — but **the entire point of that fix was first-file
open**, and no sound file has ever been opened. Its known defect ("launches fine,
mounts zero TREs, fails the moment you open a sound file") is invisible to a
launch smoke by construction.

7,677 `.snd` files are available, e.g. `sound/music_combat_loop.snd`
(`ILM_music.tre`). Open one. This is the highest-value untested thing in the
tree.

### 3. AnimationEditor — newly changed, never exercised

It received the `[ParticleEditor] groundScene` key this session (it reads that
section, not an `[AnimationEditor]` one — see the trap recorded above) and shares
ParticleEditor's serverless path. Smoke-passed, but nothing loaded. 7,765 `.ans`
files available. Drive it the same way ParticleEditor was driven (Ctrl+O, type
the path, Enter, guarded on `GetForegroundWindow()`).

### 4. Functional testing generally — the big untested surface

**Only ParticleEditor has ever been driven past launch** (one `.prt` load).
Nothing else has opened or saved a file. Several tools display data parsed at
boot (SwgDraftSchematicEditor's 749 resourceTypes, SpaceQuest's 20 categories) —
that is startup parsing, not editing.

### 5. Do NOT "fix" these

* `SwgConversationEditor` / `SwgSpaceZoneEditor` scoring `c`: the
  `<branch>\exe\win32` check is structural and can never match unless run from
  `.../swg/<branch>/exe/win32`. Cosmetic, one click.
* QuestEditor's blank component icons: `data/internal/.../questeditor/image/`
  simply does not exist here. Documented, not fatal.

### 6. Still open from earlier sessions

Staging DLLs (08-22): staging has the newer `gl11_r.dll` beside the older exe and
`stage-x64/gl05,06,07_r.dll` show as modified. No ABI change, harmless,
unresolved. **Note today's rebuild produced a new `gl11_r.dll` in Release**, so
re-check this with fresh eyes rather than against the old notes.

## Two things that changed how to work here — do not miss these

**Automated frame capture now WORKS.** Copy the baked shader cache into the tool's
directory first:

```
D:\Code\Galaxies-Reborn\stage-B-x64\compiled_shader\  ->  <tool dir>\compiled_shader\
```

(already done for `x64\Release`). Then the RenderDoc MCP's `capture_frame` with
`delayFrames: 900` completes and yields a full scene frame. No human F12 needed.
`pixel_history` is the single highest-value call — it answers "what wrote this
pixel" directly and settled both bugs this session.

**SWG-Toolkit is the reference for anything TRE-format-shaped.** Do not
reverse-engineer:
* `D:/Code/swg-client-v2/tools/tre-lint/src/format.ts`
* `D:/Code/SWG-Toolkit/.planning/handoff/2026-08-17-PROVIDER-NOTE-tre-lint-seed-and-v0006-verdict.md`

## Machine state at shutdown

ParticleEditor may still be running (PID 3024) plus whatever the interrupted
smoke run left; kill any `*Editor_r.exe` / `SwgGodClient_r.exe` before trusting a
fresh run. `warning.log` in Release holds the last smoke tool's output, not
ParticleEditor's. Per-run logs saved this session:
`logs/warning.pre-envtest.log`, `logs/warning.envtest-simple.log`,
`logs/warning.envtest-tatooine.log`.

Captures worth keeping: `D:\Code\Galaxies-Reborn\stage-B-x64\Capture250.rdc`
(magenta, pre-fix) and `Capture251.rdc` (oversaturated, pre-alpha-fix). The
post-fix capture is in this session's scratchpad and will be orphaned — recapture
is now cheap, so no loss.

## LATE ADDENDUM — the interrupted smoke got through 9/16 before it was killed

Partial output survived. Amends the "UNVERIFIED" warning above: the first **9 of
16 tools are confirmed alive against TODAY'S binaries** (the clear-alpha
`gl11_r.dll` and the rebuilt `clientTerrain`).

| # | tool | verdict |
|---|------|---------|
| 1 | SwgGodClient_r | w |
| 2 | TerrainEditor_r | w |
| 3 | UIBuilder | `?` — known false negative, its `#32770` IS the main window |
| 4 | ParticleEditor_r | w |
| 5 | AnimationEditor_r | w |
| 6 | LightningEditor_r | w |
| 7 | SwooshEditor_r | w |
| 8 | NpcEditor_r | w — full title `Npc Editor (Aug 20 2026 - 18:51:54) : Default` |
| 9 | SoundEditor_r | w |

That covers the three that mattered most for regression risk: **both editors
changed this session** (ParticleEditor, AnimationEditor) and **NpcEditor**, the
most fragile tool in the set — all still reach a real main window. No regression
from the D3D11 clear-alpha fix is visible in the first 9.

**Still to confirm: tools 10-16** — ClientEffectEditor, QuestEditor,
ShipComponentEditor, SwgConversationEditor, SwgDraftSchematicEditor,
SwgSpaceQuestEditor, SwgSpaceZoneEditor. Re-run the smoke to close those out; it
is the first task next session either way.


# ===== SESSION 2026-08-24 (resume after power loss) =====

## TerrainEditor's "Tip of the Day" — the tips file was NEVER SHIPPED. Closed.

Asked whether the tips exist in the official editor config area. They do not,
anywhere. This is not a port defect and there is nothing to port.

The dialog wants a file called `terrainEditor.tip`, opened with a plain `fopen`
relative to the CWD (`TipDialog.cpp:39`) — **not** through TreeFile, so no
searchPath, TRE or cfg key can ever supply it. It has to sit literally beside
the exe.

Searched, all negative:

| Location | `*.tip` |
|---|---|
| `D:\SWG All Tools Working` — the whole SOE reference tree | none |
| `D:\SWG All Tools Working\swg\current\exe\win32` | ships only `TerrainEditor.exe` + `TerrainEditor.ini` |
| this repo + `D:\Code\Galaxies-Reborn` stage dirs | none |

So SOE's own build showed the same dialog we do. What is displayed is the
failure branch: string resource `CG_IDS_FILE_ABSENT` = *"Tips file does not
exist in the prescribed directory"* (`TerrainEditor.rc:2520`).

Two traps worth remembering:

* **`TerrainEditor.ini` is NOT the MFC profile.** It is the shader/family list
  data (`SF/dirt/dirt_bigcracks=...`, ~229 KB). Do not go looking for a `[Tip]`
  section in it.
* The real profile is the **registry**:
  `HKCU\Software\Sony Online Entertainment\TerrainEditor`, section `[Tip]`,
  keys `StartUp` / `FilePos` / `TimeStamp` (`TerrainEditor.cpp:331` sets the
  registry key). Checked this session: the `Tip` subkey **does not exist**, so
  `GetProfileInt(...,"StartUp",0)` returns 0, `m_bStartup` stays TRUE, and the
  dialog fires on every launch. Ticking off "Show tips on startup" once writes
  `StartUp=1` and it never comes back. That is the entire fix if it is wanted —
  no code change, no file to author.

Also note `ShowTipAtStartup()` only runs when `cmdInfo.m_bShowSplash` is set,
i.e. when the editor is launched with no file argument — which is exactly what
the smoke does.

## `ui_root_npceditor.ui` is now TRACKED — clean-checkout hole closed

Handoff next-step #1, done. Two changes:

1. The file is copied (byte-identical, 11,349 bytes) to
   `src/build/win32/exe/win32/ui/ui_root_npceditor.ui`, beside the other
   preserved SOE originals (`NpcEditor.tab`, `QuestEditorConfig.xml`). No
   `.gitignore` change was needed — verified with `git check-ignore`, that
   directory is not excluded.
2. `NpcEditor.cfg` gained `searchPath11="../../exe/win32"`, **relative**, which
   resolves from the Release dir back to that preservation store.

Why relative works, and it is worth knowing generally:
`TreeFile::SearchPath`'s constructor runs `Os::getAbsolutePath()` on whatever
the cfg gives it (`TreeFile_SearchNode.cpp:114`), resolving against the CWD —
the exe's own directory. So relative searchPaths are legal and are the way to
avoid the machine-specific-absolute-path problem flagged earlier in this doc.

**VERIFIED, not assumed** — by negative control, which is the only way this is
worth anything:

| run | out-of-repo copy | result |
|---|---|---|
| control | present | ALIVE at 45s, no FATAL |
| test, first attempt (`searchPath13`) | hidden | **EXITED 0x80000003**, `FATAL ExceptionHandler invoked` |
| test, after fix (`searchPath11`) | hidden | ALIVE at 45s, no FATAL |

**THREE searchPath traps, and the middle one cost real time:**

* A searchPath that does **not exist** is a hard `FATAL`, not a warning —
  `FATAL(!result, ("Could not convert to absolute path. Does it exist? %s"))`
  at `TreeFile_SearchNode.cpp:117`. That is why the missing-directory case bites
  so hard on a clean checkout.
* **`maxSearchPriority` CAPS WHICH KEYS ARE EVEN READ, and this cfg sets it to
  12** (`NpcEditor.cfg:5`). The registration loop is
  `for (priority = 0; priority <= maxPriority; ++priority)` (`TreeFile.cpp:133`),
  so `searchPath13` was **silently never read** — no warning, no error, the key
  simply does nothing. The library default is 20 (`TreeFile.cpp:117`), which is
  what misled me; the cfg overrides it. **If a searchPath appears to do nothing,
  check `maxSearchPriority` FIRST.** Priorities in use here: TOC 0-3, Tree
  0,2-8, Path 12. Free below the cap: 1, 9, 10, 11.
* Higher number = **higher** precedence: nodes are sorted with
  `a->getPriority() > b->getPriority()` (`TreeFile.cpp:336`), descending. So 11
  deliberately sits *below* stage-B-override's 12 — the override corpus keeps
  precedence and the in-repo copy is purely the safety net.

`stage-B-override` is deliberately LEFT IN PLACE at priority 12 — it is the
asm2hlsl corpus and carries `appearance/`, `datatables/`, `pixel_program/`,
`snapshot/`, `texture/`, `vertex_program/` besides this one `ui/` file.

## The 16-tool smoke is RE-RUN and GREEN against today's binaries

The run lost to the power cut is redone in full. `_smoke-auto.ps1 -WaitSeconds 30`,
results in `src/build/win32/x64/Release/_smoke-results.csv`.

**16/16 alive. No FATAL in any per-tool log, no crash artifacts.** This closes the
"UNVERIFIED against today's binaries" warning: the clear-alpha `gl11_r.dll` and the
rebuilt `clientTerrain` sit under every 3D-viewport editor and nothing regressed.

Tools 10-16, the ones the interrupted run never reached, all came up:

| # | tool | verdict | window title |
|---|------|---------|--------------|
| 10 | ClientEffectEditor_r | w | `ClientEffectEditor_r` |
| 11 | QuestEditor_r | w | `QuestEditor Version 2.11 (Built Aug 20 2026 - 18:17:05)` |
| 12 | ShipComponentEditor_r | w | `ShipComponentEditor_r` |
| 13 | SwgConversationEditor_r | w | `SwgConversationEditor` (MFC frame) |
| 14 | SwgDraftSchematicEditor | w | `SwgDraftSchematicEditor` (MFC frame) |
| 15 | SwgSpaceQuestEditor_r | w | `SwgSpaceQuestEditor - [naboo_imperial_4.tab]` |
| 16 | SwgSpaceZoneEditor_r | w | `SwgSpaceZoneEditor` (MFC frame) |

### Two deltas from the documented baseline — neither is a regression

* **SwgConversationEditor and SwgSpaceZoneEditor now score `w`, not `c`.** The
  `<branch>\exe\win32` complaint dialog did not appear in the 30s window this
  run. **Cause NOT established** — do not record this as fixed. Note those two
  (and QuestEditor, SwgDraftSchematicEditor, SwgSpaceQuestEditor, UIBuilder)
  wrote **no `warning.log` at all** this run, so there is no log evidence either
  way; only 11 of 16 tools produced one. Worth one look if it matters.
* **UIBuilder still scores `?`** — unchanged known false negative. Its `#32770`
  IS its main window (MFC dialog-based app). Ignore.

Per-tool logs kept in `src/build/win32/x64/Release/logs/_smoke/`. Note
`UIBuilder.warning.log` there is STALE (16:39, an earlier run) — the script only
copies a log if the tool wrote one, so a stale file is not evidence.

### CRLF fidelity checked too — no `.gitattributes` needed

The repo has no `.gitattributes` and `core.autocrlf=true`, so a clean checkout
writes this file with **CRLF**, not the LF bytes that were tested. Rather than
assume, the CRLF form was generated (11,349 -> 11,380 bytes) and run with the
out-of-repo copy hidden: **ALIVE at 45s**. The UI parser does not care, so the
file is left as an ordinary tracked text file, consistent with the other
preserved SOE originals. Both copies were restored and verified byte-identical.

## SoundEditor first-file open — TESTED AT LAST, and the fix HOLDS

Handoff next-step #2, the "highest-value untested thing in the tree". The
`SoundEditor.cpp:449` cfg fix (`d17043a48`) had never been exercised, because its
whole point is first-file open and no sound file had ever been opened.

**It works. The tool opens a sound template and resolves every sample out of the
TREs.**

### How it was driven

`fileOpen()` uses `QFileDialog::getOpenFileNames` (`SoundEditor.cpp:648`), so it
opens a **loose .snd from the filesystem** — not from a TRE. There are no loose
`.snd` files in this repo or the stage dirs, but the SOE tree has **7,220** of
them under `swg/current/data/sku.0/sys.client/compiled/game/{sound,player_music/sound,voice/sound}`.

Menu accel is **Ctrl+O** — `BaseSoundEditor.ui` stores it as the integer
`4194383`, which is `0x400000 | 0x4F` = CTRL + 'O'. The file dialog is a native
`#32770` "Open Sound", not a Qt widget, so it takes a typed absolute path fine.
Driver kept at `scratchpad/_drive-soundeditor.ps1`.

### The prediction was made BEFORE the run, which is what makes the result mean anything

Target: `sound/music_combat_loop.snd` — an `SD2D` (Sound2dTemplate) referencing
**28** `music/mus_*.mp3` samples. All 28 were confirmed present in TREs that
`SoundEditor.cfg` actually mounts (checked by intersecting the cfg's 70
`searchTree0` entries against `scripts/trelist.py`; e.g.
`music/mus_combat_f_lp.mp3` -> `patch_15_00.tre`). Note **ILM_music.tre is NOT
mounted** by SoundEditor.cfg, so the base patch archives are doing the work.

* PASS looks like: 28 samples listed with real sizes.
* FAIL looks like: 28 x `WARNING: Unable to find the sample in the tree file
  path and it will not be loaded` (`SoundTemplateWidget.cpp`, the `else` of
  `TreeFile::exists` at line 441).

### Result — PASS, on two independent readings

1. Title `Sound Template - D:/SWG All Tools Working/.../music_combat_loop.snd`,
   and **"Sample List (28 samples @ 27174 KB)"** — 28/28, with per-sample sizes
   (680 KB, 1062 KB, 901 KB, ...). Sizes come from `Audio::getSampleSize()`,
   which reads through TreeFile, so non-zero sizes already prove the mounts.
2. Better: the **Audio Debug** panel reports `Cache Miss Count 28` /
   `Cached Sample Count 28`. The audio subsystem actually pulled all 28 mp3
   payloads out of the archives. That is impossible with zero mounted TREs.

Template fields also populated correctly (Play Order "Random No Repeats",
Priority 2, Category "Background Music", play count 99/99).

`warning.log` stayed at its usual 6 lines of JUCE/WASAPI init, no FATAL. **Do not
read that as evidence either way** — `SoundEditorUtility::report()` writes ONLY to
the GUI output window (`SoundEditorUtility.cpp:110`), never to a file. Any future
SoundEditor check has to be visual.

Screenshots: `logs/_shots/SoundEditor_{a-before,b-dialog,c-after,e-output}.png`.

### Playback CONFIRMED BY THE USER, 2026-08-24

`Play` was pressed by Kenny on the loaded `music_combat_loop.snd`: **"It plays."**

So the whole chain is now proven end to end — cfg read -> 70 TREs mounted ->
template parsed -> 28 samples resolved through TreeFile -> mp3 payloads decoded
and cached -> audio out through the JUCE 8.0.14 / WASAPI backend. Nothing about
SoundEditor's first-file-open path is outstanding.

This also makes SoundEditor the **second** tool ever driven past launch, after
ParticleEditor.

## AnimationEditor driven past launch — works, and `groundScene` is confirmed visually

Handoff next-step #3. It is up and rendering. PID left running for the user.

### The handoff's own lead was WRONG — correct it

This doc said "7,765 `.ans` files available. Drive it the same way ParticleEditor
was driven." **AnimationEditor does not open `.ans` files.** Its document types
are `.ash` (animation state hierarchy) and `.lat` (logical animation table) —
`MainWindow.cpp:351`, filter `Editor Files (*.ash *.lat *.xml)`. The `.ans` files
are the compiled animations a LAT *points at*, exactly as `.mp3` samples are what
a `.snd` points at. There are **203** loose `.ash`/`.lat` in the SOE tree under
`.../compiled/game/appearance/{ash,lat}/`.

### The file dialog is a dead end here — do not waste time on it

`openFile()` refuses anything not already under a TreeFile **search path**:

    if (!TreeFile::stripTreeFileSearchPathFromFile(...)) {
        WARNING(true, ("User: the specified file [%s] is not mappable to your
                       TreeFile path.  Fix path before opening."));
        return;   // MainWindow.cpp:363
    }

and `stripTreeFileSearchPathFromFile` only matches `SearchPath` nodes — it
`dynamic_cast`s to `SearchPath` and ignores every TRE (`TreeFile.cpp:1027`).
AnimationEditor.cfg has exactly **one** searchPath, `stage-B-override` at 12. So
pointing the dialog at the SOE tree is rejected by design; the file would first
have to be copied under stage-B-override. The `Open Shared Creature Template`
path (`MainWindow.cpp:108`) has the same constraint plus two more: the path must
contain the substring `shared` and must contain `.iff`.

### The route that needs none of that

`File -> Open Target ASH(s)` / `Open target LAT(s)` act on
`AnimationEditorGameWorld::getFocusObject()`, which falls back to
`networkScene->getPlayer()` — no dialog, no path mapping. The File menu has **no
accelerators at all**, so drive it by arrows: Alt+F then Down xN, where
1=Open Shared Creature Template, 2=New Ash, 3=New Lat, 4=Open..., 5=Open Target
ASH(s), 6=Open target LAT(s), 7=Close, 8=Save. Driver kept at
`scripts/_drive-animationeditor.ps1`.

### Result

**It loads the player's animation data BY ITSELF at boot** — no menu action
needed. At ~35s three tabs are already open:

    ASH - all_b.ash  |  LAT - all_m.lat  |  LAT - hum_m_face.lat

with the Logical Animation Mapping tree populated from
`Template Name: appearance/ash/all_b.ash` — add_face_blink, add_pistol_fire_1,
coup_de_grace, default, emt_accept_affection, emt_afk, emt_applause_excited,
emt_beckon, emt_belly_laugh, emt_bow2..5, emt_celebrate, ... real data out of the
TREs.

**Be accurate about the menu picks: they appear to have been no-ops.** The tab set
is byte-for-byte identical across the boot shot and both post-menu shots, which is
expected — the targets were already open. What changed between the boot shot and
the next one is the **3D viewport**: at 35s it was bare ground, and a few seconds
later it renders the **human male player character standing on dirt terrain**.
That is the skeletal mesh finishing its build, not the menu.

So `groundScene` for AnimationEditor (`2a368d829`, written into the
`[ParticleEditor]` section — see the section-name trap above) is now **visually
confirmed**, not just assumed from a launch smoke.

No FATAL, no `Failed to get the player or a target object from the NetworkScene`,
no `Could not get the NetworkScene`, no `not mappable` — checked in
`logs/warning.animationeditor-drive.log`.

Screenshots: `logs/_shots/AnimationEditor_{a-boot,b-lat,c-ash}.png`.

### ANIMATION PLAYBACK CONFIRMED (user, 2026-08-24) — and here is exactly how

**Double-click an Action in the `ASH - all_b.ash` tab, under the Actions
sub-folder.** Kenny did it and the character animated.

That is precisely the code path:

    void ActionListItem::doDoubleClick()   // ashFormat/ActionListItem.cpp:122
    {
        // GOAL: tell the focus Object in the game to do the current action.
        ...
        appearance->getAnimationResolver().playAction(m_action.getName(), ...);
    }

`MovementActionListItem::doDoubleClick()` (MovementActionListItem.cpp:123) is
identical. Both are **ashFormat** types.

**The LAT tabs cannot play anything — do not try.** `LogicalAnimationTableWidget`
forwards a double-click to `ListItem::doDoubleClick()`, whose base implementation
is literally `// Default: do nothing.` (`core/ListItem.cpp:213`). Nothing in
latFormat overrides it except `AnimationPriorityListItem::PathListItem`, which is
a path edit, not playback. So the `Logical Animation Mapping` tree — the one that
is open by default and looks like the obvious place to click — is a dead end for
playback.

Layout for whoever comes next: tab `ASH - all_b.ash` -> sub-tabs
`State Hierarchy` | `Action Groups`. The Action items carry a blue **A** icon
(dance_lyrical, dive, door_knock, duck, face_blow_kiss, ...).

**Honest note on the automated attempt:** a scripted double-click was fired at a
blue-A row in the `State Hierarchy` sub-tab and frame differencing over the
viewport could NOT distinguish it from idle (0.02-0.15% changed pixels vs a
0.06-0.07% idle baseline — the idle breathing animation sets that floor). Either
the click missed a real Action item or it landed in the wrong list. The scripted
route is unproven; the human route above is confirmed. If anyone wants this
automated, target the **Actions sub-folder** specifically and expect the idle
animation to make naive frame-diffing weak — compare limb silhouettes, or pick a
large-amplitude action, rather than counting changed pixels.

### Still not exercised

Nothing has been edited or saved in AnimationEditor.

## 2026-08-24: FULL PASS over every tool -> docs/TOOLS-GUIDE.md

Drove every editor that had never been opened past its launch screen, then wrote
`docs/TOOLS-GUIDE.md` (commit `537e5e4ce`): required setup, config keys, basic
instructions, in-app points of interest, and an honest assessment per tool.

**13 of 16 are now driven past launch, up from 3.** Read the guide rather than
duplicating it here; only the things that change how you work are repeated below.

### Config fixes made, each verified by a before/after run

| file | change | symptom it fixed |
|---|---|---|
| `LightningEditor.cfg` | `[ParticleEditor] groundScene` | magenta sky |
| `ClientEffectEditor.cfg` | `[ParticleEditor] groundScene` | magenta sky |
| `ClientEffectEditor.cfg` | `searchPath11` = SOE client root | **could not open any file at all** |
| `QuestEditor.cfg` | `searchPath10` = SOE **server** root, `11` = client root | **FATAL on every quest open** |
| `uibuilder_searchpaths.cfg` | created | UIBuilder had no search paths |

### The four findings worth carrying forward

1. **All five Qt GameWidget tools call `Game::install(Game::A_particleEditor)`**
   (`GameWidget.cpp:384`). ParticleEditor, AnimationEditor, SwooshEditor,
   LightningEditor and ClientEffectEditor are all "the particle editor", all take
   the `setScene()` branch, and all read `[ParticleEditor] groundScene` from
   whatever cfg they loaded. The magenta sky was never particle-editor-specific.
   SwooshEditor was accidentally fine only because it loads `AnimationEditor.cfg`.

2. **QuestEditor needs SERVER data.** It FATALed on
   `datatables/item/master_item/master_item.iff`, which is in **none** of the 209
   client TREs. A client-only mount list can never satisfy it. This is the
   clearest example of why the launch smoke was worth so little: it booted
   perfectly every single time and died on the first file opened.

3. **`stripTreeFileSearchPathFromFile` ignores TREs** (`TreeFile.cpp:1027`) — it
   only matches `searchPath` entries. So AnimationEditor and ClientEffectEditor
   refuse files that are mounted and perfectly readable, and the only trace is one
   line in `warning.log`. In the UI the dialog just closes and nothing happens.

4. **The SOE loose data roots are the master key.**
   `.../data/sku.0/sys.{client,server}/compiled/game` are valid TreeFile roots,
   named exactly as the TREs name their entries. Mounting one makes everything
   under it both loadable and mappable. **Cost: startup goes from ~20s to 60s+.**

### TerrainEditor: two things that will waste your time

* Its MFC profile is at the **doubled-Software** registry path —
  `HKCU\Software\Software\Sony Online Entertainment\TerrainEditor	errainEditor\`
  — because `SetRegistryKey` was passed a full path where MFC wants a company name.
* **Tip of the Day is modal and blocks all scripted input.** Set
  `...	errainEditor\Tip\StartUp` (DWORD) `= 1` to stop it. Verified. Also note
  `Ctrl+O` proved unreliable to script; the `Alt+F`, `O` menu route works, and
  there is **no command-line file open** (`ProcessShellCommand` is commented out).

### Still unproven, and stated plainly

* **Nothing has been saved or edited by any tool.** Every result is a read path.
* **SwgConversationEditor has no data here at all** — its document type is `.cnv`
  and there is not one `.cnv` file on this machine. Only the compiled output
  (1,363 `.java` conversation scripts) shipped. Not a port defect.
* **SwgSpaceQuestEditor and SwgSpaceZoneEditor were not driven** past their
  startup warnings.
* **SwgGodClient stops at the client LOG IN screen** — it is a full game client
  and needs a running server. Its UI and renderer are intact, which is real
  evidence the port is sound, but no editing feature can be assessed here.

### The two startup dialogs on the MFC Swg* tools are STRUCTURAL - do not "fix"

1. "not running from `<branch>\exe\win32`" — checks the CWD for the substring
   `exewin32` after stripping slashes. From `x64/Release` it can never match.
2. "running out of the 'qt-tools-worktree' branch which does not match ..." —
   compares the branch extracted from the CWD against the branch in the cfg paths
   (`current`). Cosmetic. `SwgSpaceZoneEditor.cpp:127,133,140`.

This also settles the earlier `c` -> `w` scoring question: the dialogs are still
there. The smoke scores on window TITLES and the dialog's title is just
`SwgConversationEditor`, which its error regex does not match. **Scoring
artifact, not a behaviour change.**

## 2026-08-24: the three "broken" MFC tools ALL WORK - I was wrong

Kenny pushed back ("I think they work more than you realize") and he was right.
None of the three was broken. Each just needed the correct way in, and I had
guessed wrong on all three. `docs/TOOLS-GUIDE.md` is corrected; **15 of 16 tools
are now driven past launch.**

### SwgSpaceZoneEditor - open the `.tab` SOURCE, not the compiled `.iff`

I had it backwards. `OnOpenDocument` calls `loadFromSpreadsheet()` on a `.tab`
and swaps the extension to `.iff` itself when it wants the compiled form
(`SwgSpaceZoneEditorDoc.cpp:392,859`). The cfg's `spaceZoneDataTablePath` points
at the compiled `.iff` directory, which is what misled me.

The sources are the **31** files under
`dsrc/sku.0/sys.server/compiled/game/datatables/space_zones/buildout/`.

`space_tatooine.tab` opens fine: tree of **Nav Points / Spawners /
Miscellaneous**, and the zone view plots real objects on a ruled XZ grid.

### SwgSpaceQuestEditor - it is a TREE BROWSER, not a File>Open tool

File>Open produces no dialog, which is why my driver failed. It does not need
one: the whole `spacequest` tree is **already loaded at boot** (20 categories)
with the Configuration tab parsed.

**Expand a category, double-click a `.tab` leaf.** Title becomes
`SwgSpaceQuestEditor - [<name>.tab]` and a full property editor appears -
`PT_navPointList`, `PT_spaceMobileList`, `PT_spawnerList`, a StringId/Text grid
and Quest Log Data. Verified on `_debug.tab`. (That file contains
`PT_notImplemented = ERROR(2): see asommers` - SOE test content, not a defect.)

### SwgConversationEditor - the TOOL works; only the documents are missing

`File > New` (`Ctrl+N`) creates `swgcon1` and gives the whole authoring
environment: Conversation Editor tree seeded `Root` -> `Npc Branch` with Add
Branch / Add Response / Test Branch, and a Script Editor with Conditions,
Actions, %TO/%DI/%DF Tokens, **Libraries** (ai_lib, chat, conversation, utils),
Labels, Triggers, Condition/Action Wizards, plus Spell Check, Scan and Compile
Debug/Release on the main toolbar.

The `.cnv` finding stands and is not a defect: `.cnv` is an IFF with FORM tag
`CNV` (versions 0000/0001/0002, `Conversation.cpp:1431`) and there is **not one
`.cnv` anywhere** - not under `D:\SWG All Tools Working`, not under `D:\Code`,
not in any of the 209 TREs. Only the compiled output shipped (1,363 `.java`
conversation scripts). So: working authoring tool, nothing authored to open.

**Precision note:** the four Libraries come from the new conversation's own
default `LibrarySet` (`ScriptTreeView.cpp:464`), not from a directory scan. Those
four names DO correspond to real files under `dsrc/.../script/library/`, so it is
*consistent with* a correct `scriptPath` - but it does not by itself prove
`scriptPath` resolved. Do not overstate it.

### The lesson worth keeping

Three tools, three different entry conventions, none of them File>Open with the
path the cfg advertises:

| tool | way in |
|---|---|
| SwgSpaceZoneEditor | File>Open a `.tab` under **dsrc**, not the cfg's `.iff` path |
| SwgSpaceQuestEditor | **double-click a leaf** in the tree it loads at boot |
| SwgConversationEditor | **File>New** - there is no data to open |

"Booted but not driven" was the right label at the time, but I let it read as
closer to broken than it was. When a tool looks inert, the entry convention is
the first thing to question, not the tool.

Driver added: `scripts/_drive-mfc.ps1` - launches, dismisses the modal startup
warnings (they swallow keys sent before dismissal), then File>Open with polling.

## 2026-08-24: exhaustive `.cnv` hunt - still zero, with ONE archive left unread

Kenny thought he had loaded a `.cnv` last night, possibly from a TRE. My earlier
"zero .cnv" claim was scoped to **one directory** (`D:/Code/SWGSource Client v3.0`),
which was not good enough. Redone properly:

| scope | result |
|---|---|
| `*.cnv` on **C: and D:**, all fixed drives | only MS Office + ICU converters, nothing SWG |
| every `*.tre`/`*.sot` on both drives - 1,680 files, 407 unique | **1,110,194 entries, 0 `.cnv`** |
| the `.sot` archives (Misc/Server/Shared), which `trelist.py` had SKIPPED | 197,341 entries, 0 |
| `D:\SWG Beyond\Win64` - a whole separate client I had never searched, 207 archives | 179,994 entries, 0 |
| archive entries with "conversation" in the path (212 archives) | 5,981 - **all `.stf` strings** (5,951), plus a few `.ans`/`.snd`/`.inc`/`.wav`/`.cef`. No documents. |

**`trelist.py` globs `*.tre` only.** The three `.sot` files are full TRE archives
(`EERT5000`; Misc.sot alone has 120,601 entries) and were silently missed by every
earlier scan. Worth fixing in the script if TRE inventory matters again.

### The one place a `.cnv` could still hide

`D:\SWG Beyond\Win64eyond_patch_01.tre` - v0006, **9,122 files**, 192 MB - is
the only archive on either drive that will not open. Its header parses cleanly,
but the TOC and name blocks are **not zlib**: they start `cf98c515` and
`22c9ae60` rather than a `78 xx` zlib header, and every wbits variant (15, -15,
31, 47) fails. That looks like obfuscation/encryption in the Beyond distribution,
not a format variant. **I did not attempt to break it** - the standing rule is to
use SWG-Toolkit's tre-lint as the format reference rather than reverse-engineer,
and this is past what that reference covers.

### Also checked: the MRU says the tool has never opened anything

MFC put these under `HKCU\Software\Local AppWizard-Generated Applications\<app>\Recent File List`
(NOT the SOE key - another registry-path trap like TerrainEditor's doubled
`Software`). `SwgConversationEditor`'s list is **empty**. `SwgSpaceZoneEditor`'s
is empty too. `SwgSpaceQuestEditor` has entries, but both are from this session.

### Conclusion, stated carefully

There is no `.cnv` on this machine outside `beyond_patch_01.tre`, and
`SwgConversationEditor` has no record of ever opening one. It also cannot import
`.java`: that dialog is **"Add Script Library"** and only inserts a library NAME
into the LibrarySet (`ScriptTreeView.cpp:1107-1135`) - it does not read a
conversation. `Conversation::load` requires an IFF whose FORM tag is `CNV`
(`Conversation.cpp:1431`), extension irrelevant.

So either the file came from somewhere off these two drives, or what was loaded
was something else. Do not spend more time scanning - the search is exhaustive
except for that one protected archive.

## 2026-08-24: `.cnv` is EDITOR-ONLY - the client never reads it. Do not crack for it.

Before spending effort on `beyond_patch_01.tre`, checked whether the client reads
`.cnv` at all. **It does not**, and the pipeline is now proven end to end.

### Source evidence

* `TAG_CNV` appears in **exactly one file** in the whole tree:
  `SwgConversationEditor/src/win32/Conversation.cpp` - defined at :27, read at
  :1436/:1438, written at :1484. Nowhere else. Not clientGame, not sharedGame,
  not the server.
* **Zero** `.cnv` string references anywhere in the source.

### The real pipeline, confirmed against shipped data

```
.cnv  (authoring, SwgConversationEditor ONLY - stays in source control)
  |
  +-- Compile Debug / Compile Release
        |
        +--> <name>.java   runtime script  -> cfg [SwgConversationEditor] scriptPath
        +--> <name>.stf    localized text  -> cfg [SwgConversationEditor] stringPath
```

`writeStringTable()` (`SwgConversationEditorDoc.cpp:2942-2958`) writes a marker
entry into every generated table:

    key   = "do_not_edit"
    value = "The English version of this file (<name>.stf) is automatically
             generated by the SwgConversationEditor."

**Verified against real shipped content.** Extracted
`string/en/conversation/biogenic_crazyguy.stf` from `patch_04.tre` and the bytes
contain that sentence verbatim (UTF-16LE, at offset 173) plus the `do_not_edit`
key and the `s_<hash>` text keys. So the 5,951 conversation `.stf` files in the
TREs were generated by this very editor from `.cnv` sources we do not have.

### Consequences - both matter

1. **Cracking `beyond_patch_01.tre` to find a `.cnv` is almost certainly wasted
   effort.** It is a *client patch*. A `.cnv` has no runtime consumer, so it has
   no reason to be in a client archive. What such an archive ships is `.stf`.
2. **There is no round-trip.** The editor cannot import `.java` or `.stf` back
   into a conversation - the only import dialog is "Add Script Library", which
   merely inserts a library NAME (`ScriptTreeView.cpp:1107-1135`). So *editing an
   existing shipped conversation with this tool is not possible at all*,
   regardless of whether a `.cnv` is ever found. Authoring new ones works.

That reframes the tool honestly: SwgConversationEditor is a **create-new**
authoring environment here, not a way to modify SOE's existing conversations.

## 2026-08-24: SwgGodClient CONNECTED TO A LIVE SERVER - 16/16 driven

Kenny stood up the server; I configured and launched the client. It authenticated,
entered the world, and streamed cleanly. **All 16 tools are now driven past
launch.**

### The config trap - this is the reusable part

`SwgGodClient.cfg` had **no `[ClientGame]` section at all**, so it silently used
the `localhost` default and could never have reached the VM. Fixed by copying the
settings from the known-good client at `D:/Code/swg-client-v2/stage/client.cfg`:

```ini
[ClientGame]
	loginServerAddress0=192.168.1.200
	loginServerPort0=44453
```

**The index is mandatory and this is easy to get wrong.** `SwgCuiLoginScreen.cpp:284-303`
walks `loginServerAddress0`, `loginServerPort0`, `loginServerAddress1`, ... and
stops at the first missing address, accepting an entry only if its port is present
and non-zero. The unindexed `loginServerAddress` at `ConfigClientGame.cpp:991`
(default `localhost`, port 44453) is a **completely different key that the login
page never reads**. Setting only that one looks right and does nothing.

Confirmation lines to look for, and they only appear when you SUBMIT the login -
not at boot:

```
Login: assembled 1 address(es) from ClientGame/loginServerAddress<N>.
Login: connecting to 192.168.1.200:44453
Login: OUTCOME -- connection to the login server OPENED.
```

### What is actually proven

Authenticated as `swg`, reached character select, entered the world.
`WorldSnapshot` streamed while moving: `loaded` 68 -> 170, **`refused=0` on every
tick**, no FATAL, no assert, no disconnect. That exercises authentication, cluster
and character selection, world entry, proximity streaming and the DX11 renderer
against a real server - the entire client-side path, none of which could be
assessed before today.

Notable: `refused=0` throughout. The CONSULT-72 tombstone defect noted in
`swg-client-v2/stage/client.cfg` did not show in this session.

### What is NOT proven - Kenny's own words: "works as a basic client"

Everything that makes it a *god* client is untouched: object selection, the
Objects / ServerTemplates panels against live objects, the **ObjectTemplate** and
**Script** menus, Brushes / Palettes, the Bookmark tree, the `.tpf` / `poi*.lay` /
`.mif` / `.ilf` file dialogs, and creating/moving/editing/saving anything.

**Do not let "SwgGodClient works" drift into meaning more than "it connects and
plays".** Its editing surface is now the single largest untested area in the tree,
ahead of even the save paths.


# ===== SESSION 2026-08-27 - TerrainEditor driven to the end - START HERE =====

Resumed after a reboot. The previous session died mid-sentence right after
committing the Turf double-free fix (2a7d6ec68), so nothing was in flight.

**Six commits, tree clean.** Two real bugs fixed, two of my own earlier claims
corrected, and TerrainEditor taken from "launches and loads" to provably usable.

| commit | what |
|---|---|
| `cbb7f8c2a` | quote the Turf command line - in-app Bake Flora now lands its file |
| `28809f309` | Bake Terrain verified against SOE's shipped output |
| `7960572f0` | null-boundary paint guard |
| `13219df40` | all three bakes exercised; terrain bake proven deterministic |
| `7acb8a80a` | five `remove*()` paths corrupting their list count in release |
| `3f5bb2877` | editing round-trip verified |

Everything below is also in `docs/TOOLS-GUIDE.md` section 10, which is the durable
copy. This section is the narrative and the traps.

## Bug 1 - the unquoted command line (`cbb7f8c2a`)

Driving `Tools > Bake Flora` through the UI for the first time failed with
`Could not open sample file`. **Turf was innocent.** `_bakeFlora` built its command
line with raw `strcat`, and `ProcessSpawner` calls `CreateProcess` with
`lpApplicationName = 0` (`ProcessSpawner.cpp:138-140`), so the child CRT splits on
spaces. The data tree is `D:\SWG All Tools Working\...` - four arguments, not one.

Turf `push_front()`s each non-switch argument (`Turf.cpp:417`), so `front()` is the
LAST fragment. `_extractPlanetName` takes the basename, so the planet still resolved
to tatooine and **the bake ran perfectly** - 2048 rows, 207,114 flora, 75s - then
wrote to the relative `Working\swg\...\tatooine.tcf` under the editor's own
directory, where those folders do not exist. 75 seconds of correct work, discarded
silently.

**The giveaway is in the log** - the `D:\SWG All Tools ` prefix is simply missing:

```
*** Sampling terrain\tatooine.trn flora to Working\swg\current\...
```

## Bug 2 - five copies of the same release-only corruption (`7acb8a80a`)

`TerrainGenerator` has this in **five** functions - `removeBoundary`, `removeFilter`,
`removeAffector`, `Layer::removeLayer`, `TerrainGenerator::removeLayer`:

```cpp
for (i = 0; i < list.getNumberOfElements (); i++)
    if (list [i] == item) { ...; break; }
DEBUG_FATAL (i == list.getNumberOfElements (), ("not found"));   // compiles out
list.removeIndexAndCompactList (i);                              // runs anyway
```

Item not in the list -> `i == count` -> the `DEBUG_FATAL` vanishes in release, and so
does the bounds check inside `removeIndexAndCompactList` (`ArrayList.h:334`). What
survives is `m_numberOfElements--`. On an empty list that reaches **-1**, and the
next `add()` does `m_data [m_numberOfElements++] = newElement` (`ArrayList.h:232`),
writing eight bytes BEFORE the allocation. `ArrayList::add` has no lower bound check.

All five are reachable from the layer tree UI (`LayerView.cpp:668`, `1974-1981`).
Fixed by bailing out instead of compacting an index never found, with a
release-visible `WARNING`.

## The recurring trap - now three instances

**`DEBUG_` diagnostics do not exist in the builds anyone runs.** The NpcEditor
`strlen(NULL)` (hidden by `DEBUG_WARNING`), today's null-boundary crash, and all
five `remove*()` paths were invisible for exactly this reason. When you add a
diagnostic in this tree use `WARNING` (`Fatal.h:50`), never `DEBUG_WARNING` or
`DEBUG_FATAL`, unless you genuinely only want it in a debug build.

## The headline result - the port computes SOE's own answers

The shipped `tatooine.trn` **already contains SOE's baked terrain**, so their
reference output for exactly this computation is sitting in the file to diff
against. Bake Terrain, then `File > Save As`, then compare `WMAP`/`SMAP`:

| chunk | SOE shipped | regenerated | verdict |
|---|---|---|---|
| `WMAP` (water) | 440 bits of 4,194,304 | 440 | **bit-for-bit identical** |
| `SMAP` (slope >4m) | 2,171,057 (51.76%) | 2,171,035 | 1,066 differ - **99.9746%** |

The 1,066 bits are floating-point jitter at the `chunkHeight > 4.f` threshold, not a
port defect: the drift is **bidirectional and near-symmetric** (544 one way, 522 the
other - a logic error drifts hard in one direction), it clusters in 12 contiguous
runs over 124 of 2048 rows, and the water map, which uses a boolean test rather than
a float threshold, is exactly right.

**It is also deterministic.** A second bake in a separate process produced
bit-identical maps and the same 1,066-bit delta. That is what a compiler/FP-model
difference looks like; uninitialised state would have varied.

Before today every result in this tree was "it launches and does not crash". This is
the first evidence the ported code produces the same *numbers*.

## Editing round-trips (`3f5bb2877`)

First real editing by any of the 16 tools. Boundary deleted, circles added, boundary
dragged between layers, Properties value changed -> Save As -> **File > Open on the
saved file**. IFF-tag census, pre-edit vs after:

```
                layers  boundaries  filters  affectors  BCIR         size
  pre-edit         274         394       98        409   267    3,687,203
  after editing    274         396      103        423   269    3,689,387
```

On reload the deleted boundary was still gone, the added ones present, the changed
value intact. `BCIR` net +2 with one confirmed deletion = one removed, three added.

The reload direction mattered on its own: the editor had been shown to WRITE a file
but never to read back what it wrote.

## Two of my own claims, corrected - do not re-inherit them

1. **"The double-free made TerrainEditor report good bakes as failed."** Wrong.
   `_bakeFlora` **never reads the child exit code**. `getExitCode` exists
   (`ProcessSpawner.cpp:189`) but is never called; the loop uses `isFinished(200)`,
   a bare `WaitForSingleObject`, so a crashed child is indistinguishable from a
   clean one. Success is decided solely by `_importFloraSampleFile` reading the
   `.tcf` back. The double-free was real; its user-visible impact was overstated.
2. **"Budget several minutes to half an hour for Bake Terrain."** Wrong by ~40x.
   2048 x 2048 = 4,194,304 chunks takes **50 seconds** - the generator bails cheaply
   on chunks no affector covers.

## Traps worth the ink

* **Bake Terrain has no completion dialog in release.** The `MessageBox` is inside
  `#ifdef _DEBUG` (`EditorTerrain.cpp:1883-1888`). Success = the progress bar simply
  vanishing. It also writes **no file**; the data only reaches disk on save.
* **`Debug > View Baked Terrain` is a trap, not a verification.**
  `addConsoleMessage` (`TerrainEditorDoc.cpp:1522-1529`) appends to a `CString` then
  `SetWindowText`s the ENTIRE buffer, and the dump makes 1024 such calls. O(n^2),
  ~270 MB of text copying for a 525 KB result. It will look like a hang. Diff the
  saved `.trn` instead.
* **The UI bake passes no `/R`** - it always bakes the whole planet.
* **Rebuilding TerrainEditor needs the running instance closed** or the link fails
  with `LNK1104: cannot open file ... TerrainEditor_r.exe`.
* Building TerrainEditor incidentally relinks `stage-x64/gl05_r.dll`, `gl06_r.dll`,
  `gl07_r.dll`. Same size, no source change - `git restore` them, keep them out of
  commits.

## OPEN - the null-boundary crash after Bake Rivers/Roads

**One occurrence in four runs. Mechanism characterised, trigger unidentified.**

```
MapView::drawBoundary+0x4:  cmp byte ptr [r9+0Ch],0   ds:000000000000000c=??
r9 = 0000000000000000
```

`r9` carries the `boundary` argument, so `layer->getBoundary(i)` returned **NULL**
and `boundary->isActive()` dereferenced it. Stack: `drawBoundary <- drawLayer <-
drawLayer <- drawBoundaries <- MapView::OnDraw <- CView::OnPaint` - the repaint
`updateRiversAndRoads` triggers via `setZoom(oldZoom)` (`MapView.cpp:2559`).

**Ruled out, with evidence - do not re-run these:**

* **SOE's `preallocate(4096) // causes corruption`** (`MapView.cpp:2468`). The bug it
  warns about is real (`ArrayList::resizeUp` memcpy's then `delete[]`s, so growing an
  array of `MetaData` bitwise-copies each inner `ArrayList<Plane>` pointer and frees
  the buffers out from under the copies), but tatooine has **12** boundary-poly
  affectors - `AROA` 12, `ARIV` 0, `ARIB` 0, counted by IFF tag. The list never grows.
* **Heap corruption.** `r9` was a clean NULL, not a freed or garbage pointer.
* **Me killing the process.** WER logged a real `APPCRASH` (Application Error 1000,
  exception `0xc000041d`, pid `0x6B78` = 27512) with a 36 MB minidump, and the app
  ran its own `MyUnhandledExceptionFilter`. `TerminateProcess` produces neither.

**Not reproduced in three subsequent attempts**: rivers/roads alone on a fresh load,
after all three bakes, and after `File > Save As` - the exact original sequence.
Each ran ~2s and clean.

Guarded, not fixed: `MapView::drawLayer` now skips a null boundary and reports it
once per session with `WARNING`, naming the layer and index. If it recurs, that line
names the culprit.

**Dump preserved**: `<scratchpad>/crash/TerrainEditor_r.exe.27512.dmp` plus
`warning.at-crash.log`. Analyse with the Windows Kits `cdb.exe`; `.ecxr` lands on
`InternalFatal`, so use `.frame /r 9` to get the real faulting frame.

## Where TerrainEditor stands

All three bake paths, the full edit/save/reload cycle, and the save path exercised on
a real 3.7 MB planet, with output verified against reference data. **Still untouched:
the 3D View.** That is the last surface on this tool.

## State at handoff

* Branch `qt-tools-verify`, clean, **41 ahead of `origin/x64-dx11-qt-tools`** - still
  unpushed.
* TerrainEditor running, PID 30236, with `C:\bake-test\tatooine3.trn` loaded.
* `C:\bake-test\` holds three saves: `tatooine.trn` (post-bake), `tatooine2.trn`
  (second bake, determinism check), `tatooine3.trn` (edited).
* Original `tatooine.trn` in the SOE tree **untouched** (mtime 08/22). Backup at
  `<scratchpad>/backup/tatooine.trn`.
* Scratchpad:
  `C:\Users\kenne\AppData\Local\Temp\claude\D--Code-swg-qt-tools-worktree\02b05a29-04a5-48a3-b42d-c2fdea431f16\scratchpad`

## Next, in the order I would do it

1. **The 3D View** - the last untouched surface on TerrainEditor.
2. **Save and edit on the other 15.** Still completely untested there; TerrainEditor
   is the only tool that has ever written a file.
3. **SwgGodClient's editing surface** - still the single largest untested area in the
   tree, per the earlier session's note. Nothing today changed that.
4. Push the branch. 41 commits is a lot to be holding locally.


# ===== SESSION 2026-08-27 (evening) + 08-28 - the 3D View, and the edit loop =====

Continuation of the same working day. Durable detail is in docs/TOOLS-GUIDE.md
section 10 and in the commit messages; this is the index.

## Commits (all pushed)

| commit | what |
|---|---|
| `02e7543ca` | 3D View: SetupClientTerrain + reference camera + SetupSharedCollision |
| `41ba57276` | 3D View: ClientTerrainSorter draw/clear hooks + restored lights - RENDERS |
| `b31a1335d` | guide: the four missing pieces of clientGame scene glue |
| `b66086156` | guide: edit->preview loop verified; layers-tree scroll defect |

## The one-line summary

The 3D View went from a grey rectangle to fully textured, lit terrain, and the
edit -> Refresh -> preview loop is verified (boundary circle + AffectorHeightConstant
150 -> visible cliff). TerrainEditor is done: every major surface driven.

## The reusable part - client terrain rendering in ANY tool needs four things

1. `SetupClientTerrain::install()` after SetupClientGraphics (else the MPTA/PTAT
   tags bind to the SERVER appearance - collision only, no renderable chunks)
2. `ClientProceduralTerrainAppearance::setReferenceCamera(camera)` every frame
   (else calculateLod() silently returns; only clientGame ever sets it)
3. `SetupSharedCollision::install()` (else the first flora addToWorld faults in
   MemoryBlockManager::allocate) - copy Turf.cpp:194-205
4. World-cell render hooks + lights: `addPreDrawRenderHookFunction(&ClientTerrainSorter::draw)`
   + `addExitRenderHookFunction(&ClientTerrainSorter::clear)` (else chunks queue
   primitives nobody flushes - ClientWorld.cpp:634 is the only game caller), and
   ambient+parallel Lights via RenderWorld::addWorldEnvironmentLight (else black -
   GroundEnvironment creates the game's lights BLACK and env data drives them)

Every assert guarding all four compiles out in release. That trap is now at SIX
instances across this effort.

## OPEN defects

* **Construction Layers tree cannot scroll** - control-level: WM_VSCROLL, wheel,
  End, TVM_ENSUREVISIBLE all no-ops sent directly to the HWND; no scrollbar drawn
  despite WS_VSCROLL + range 0..31 + overflowing content. Queries and selection
  work. Workarounds (fully usable): maximise the panel, Insert > Collapse All.
  Suspect: TVS_CHECKBOXES set post-creation (LayerView.cpp:1301)? Undiagnosed.
* Null-boundary crash after Bake Rivers/Roads - one occurrence, guarded, see the
  earlier section.

## RenderDoc on MFC tools - what worked (also in the renderdoc memory)

CLI `-d N` counting is useless here: ~150 presents burn during startup and the
internal timeout kills 400+. Working recipe: launch under `renderdoc-cli capture`,
drive the UI with WM_COMMAND posts (MRU open 0xE111, ID_3D_VIEW 1258, ID_REFRESH
1384), let the CLI time out - the editor STAYS injected - then F12 writes a full
capture to the CLI's -o path. `drive3d.ps1` in the session scratchpad does the
posting.

## Next steps (in order)

1. **File > New** - planet from scratch. Started 08-28; see the section below if
   one was added, else it is the open task. Facts already established from code:
   new doc = mapWidth 4096 (not 16384), chunkWidth 8, 4 tiles/chunk, empty
   generator; Options > Map Parameters dialog exists (DialogMapParameters);
   new-shader-family flow is ShaderTreeView::OnNewshaderfamily which auto-creates
   a placeholder CHILD whose shaderTemplateName is a made-up unique name - a real
   shader template must be assigned or first fetch will presumably fail.
   TRAP for later: Bake Flora on a new planet CANNOT work via Turf until the .trn
   is reachable as terrain/<name>.trn through TreeFile - Turf loads from the
   mounted TREs/search paths, not the file on disk.
2. **Server evening**: walk on an edited .trn in SwgGodClient (closes
   edit->save->PLAY), then drive the god tools - still the largest untested area.
3. Save-path sweep across the other 15 tools - only TerrainEditor has ever saved.

# ===== SESSION 2026-08-28 - SAVE-PATH SWEEP across the other 15 tools =====

Kenny is standing the server up in parallel; the god-client walk on an edited
.trn happens when he is ready. Meanwhile: the save sweep. Only TerrainEditor had
ever written a file before today.

## Save-path map (agent-built, full detail in the agent output; keep these traps)

* **SwgConversationEditor**: OnSaveDocument REJECTS paths with spaces; a failed
  save can still return TRUE and clear the modified flag (catch block falls
  through) - verify bytes on disk, never trust the title alone.
* **ParticleEditor**: fileSaveAs has NO accelerator - drive via Alt+F, 'a'
  (menuText "Save &As..."). Extension force-appended .prt.
* **SoundEditor**: no save accel either (menu built in code); refuses to save an
  empty sample list.
* **AnimationEditor**: the ONLY tool that resolves save paths through TreeFile
  (TreeFile::getPathName, dsrc->data rewrite); no Save As at all - dialog only
  when m_pathName is empty. Boot-loaded all_b.ash would save to the raw relative
  path under the CWD (Release dir) since TREs are not searchPaths.
* **ClientEffectEditor**: save is a no-op unless m_effectTemplateModified; typed
  extension .cef REQUIRED (not appended).
* **DANGER GROUP - save writes to config-derived paths pointing into the SOE
  reference tree, NOT the path you pick**: ShipComponentEditor (Save All, no
  dialog at all), SwgSpaceQuestEditor (path run through extractRootName, real
  dests from Configuration::getMissionTemplate), QuestEditor (exportDataTables +
  .stf after the .qst), SwgDraftSchematicEditor (derived shared .tpf beside the
  picked server .tpf). Do NOT drive their saves without first sandboxing or
  auditing the destination paths.
* SwgSpaceZoneEditor: writes the .tab you pick PLUS a compiled .iff derived via
  Replace("dsrc","data") - a path with no "dsrc" gets the .iff beside the .tab.

## Automation lessons (paid for in near-misses)

* **The native file dialog's filename field must be VERIFIED after WM_SETTEXT.**
  First attempt put the path in the wrong Edit (the search box); the dialog kept
  its default name pointing at the ORIGINAL SOE file and the OK click raised an
  overwrite prompt for it. Answered No; original verified untouched (mtime).
  scripts/_drive-save.ps1 now sets every candidate edit, reads back, refuses to
  click without an exact match, and treats any 'Confirm Save As' as failure
  (targets are pre-deleted, so a confirm ALWAYS means wrong file) - answers NO.
* **BM_CLICK via SendMessage deadlocks** when the click raises a modal dialog -
  use PostMessage(dlg, WM_COMMAND, IDOK, btn) instead.
* MFC tools are drivable with zero foreground: WM_COMMAND 0xE100/0xE101/0xE104
  (New/Open/SaveAs), WM_CLOSE dismisses the startup boxes. Qt tools still need
  guarded SendKeys for menu accels, and the guard DID trip while Kenny used the
  machine - the guard aborts rather than spraying keys into his windows.

## Results so far

| tool | result |
|---|---|
| SwgConversationEditor | **SAVE + RELOAD PASS.** File>New -> Save As -> 2,164-byte FORM/CNV /0002 IFF (the FIRST .cnv on this machine) -> File>Open on it, title takes the name, no crash. C:\save-test\swgcon-new.cnv |
| ParticleEditor | open PASS (campfire tree: fire/trailing embers/trailing smoke). Save As pending - foreground guard tripped (Kenny active). Retry. |
| SwgSpaceZoneEditor | in flight |

## Also fixed: SwgConversationEditor's three startup dialogs -> one

Kenny reported three boxes. Identified all three (enum + Static text):
1. structural exe\win32 check - stays;
2. missing mochaCommand key (SwgConversationEditor.cpp:216-218 requires
   scriptPath+stringPath+mochaCommand KEYS to exist);
3. missing dictionary keys.
Fix: appended mochaCommand (rebased; the mocha script does NOT exist locally -
no utils/ dir in the reference tree - so Compile will fail if ever invoked) and
both SOE .dct dictionary paths to SwgConversationEditor.cfg. Verified: one
dialog remains. Spell checker now has SOE's 894KB medium dictionary.

## SwgSpaceZoneEditor - SAVE + RELOAD + DETERMINISM PASS (2026-08-28)

Open SOE's `space_tatooine.tab` (dsrc buildout) -> Save As `C:\save-test\space_tatooine.tab`
-> writes BOTH the .tab (184,697 B) and the compiled .iff (155,461 B; census
IDENTICAL to SOE's shipped compile: FORM DTII/0001 + COLS/TYPE/ROWS, per
`scripts/iffcensus.py`) -> File>Open the saved .tab (title takes it, no crash)
-> Save As gen2 -> **gen1 == gen2 byte-identical for BOTH files.**

Content fidelity vs the SOE original: 7 diff lines total - one row repositioned
(writer reorders on load), float text normalized (`4300.0` -> `4300.00`), and a
trailing field tab appended per line. Writer normalization, no data loss.

The .iff landed beside the .tab because the path had no "dsrc" for the
Replace("dsrc","data") rewrite to hit - as predicted from the source.

## SwgDraftSchematicEditor - SAVE + RELOAD PASS (2026-08-28)

Open SOE dsrc `armor_appearance_assault_trooper_bicep_l.tpf` -> Save As into
`C:\save-test\schematic\server\` -> BOTH tpfs written: the server one at the
picked path and the derived `shared_*.tpf`, which landed in `schematic\shared\`
(the `server/`->`shared/` rewrite worked on the dialog path). Reload the saved
tpf -> gen2 save -> identical modulo the filename banner. Diff vs the SOE
original: only regeneration artifacts (editor banner replaces the armor-exporter
one, `optional=false` -> `optional = false`, key reordering). No data loss.

## SwgSpaceQuestEditor - SAVE PASS in a full sandbox (2026-08-28)

Its save ignores the picked path and writes to config-derived destinations, so
the run used a COPY sandbox: spacequest datatables (dsrc+data) and
string/en/spacequest copied to C:\save-test\sq\, cfg keys
serverMissionDataTablePath / sharedStringFilePath temporarily redirected
(RESTORED afterwards - the .pre-savesweep.bak flow).

Open `spacequest/patrol/corellia_imperial_1.tab` -> ID_FILE_SAVE (0xE103, no
dialog) -> **all SEVEN artifacts written**: mission .tab+.iff, questlist
.tab+.iff, questtask .tab+.iff (those directory trees created by the tool
itself), and the .stf. SOE tree verified untouched (find -newer: 0 files).

NOTE: the save UPGRADES old-schema tabs - the current build's patrol template
has a `navRadius i[150]` column SOE's shipped .tab predates; the rewrite adds
it (rows preserved, enum quoting normalized). Anyone diffing saved output
against shipped data should expect that column to appear.

## Driver hardening while getting here (scripts/_drive-save.ps1)

* Filename edit = dlg item 0x480 ONLY (or the cmb13 combo's Edit), found with a
  retry loop; the Vista dialog materializes the legacy ids lazily. NEVER write
  to other Edits - the search box triggers navigation, the address bar fools
  the readback verify.
* EM_SETSEL + EM_REPLACESEL (typing-like) with WM_SETTEXT fallback, then a
  readback gate before clicking OK.
* OK via PostMessage WM_COMMAND(IDOK) - BM_CLICK over SendMessage deadlocks
  when the save pops a modal.
* Any 'Confirm Save As' after OK = the fill went to the WRONG file (targets are
  pre-deleted) -> answer IDNO, abort. This guard caught two real near-misses
  aimed at the SOE originals.
* -NoSaveDialog for tools whose save writes straight to config paths
  (SpaceQuest); -NoDismiss for UIBuilder whose MAIN window is a #32770 (the
  dismiss loop would WM_CLOSE the app).

## UIBuilder - SAVE + RELOAD + IDEMPOTENCY PASS (2026-08-28)

Open a sandbox COPY of SOE's loose `ui_root_npceditor.ui` -> post ID_FILE_SAVE
(0xE103) -> in-place rewrite, 11,349 -> 6,543 bytes. The shrink is UISaver
dropping default-valued attributes, NOT data loss: every load-bearing node
survives (/AvView, viewerWidget, sampleWearableBox, wearableVolumePage,
currentVolumePage, pageWearables, hiddenAvatarList x2, CodeData). Reload of the
normalized file -> second save leaves mtime UNTOUCHED, which is by design:
`MainFrm.cpp:903-905` compares regenerated content against disk and skips
unmodified files - i.e. the regeneration was byte-identical. Strongest possible
idempotency result.

Driving notes: UIBuilder's MAIN window is a #32770 (use -NoDismiss or the
dismiss loop closes the app); opening a workspace spawns a SECOND #32770
titled '[<file>]', so the save-dialog finder must look for NEW #32770s only.
UNEXPLAINED: ID_FILE_SAVEAS (32774, custom id) posted via WM_COMMAND produced
no dialog on two attempts - in-place ID_FILE_SAVE was used instead. If Save As
matters later, investigate whether CFileDialog there needs an active window.

## ParticleEditor - SAVE + RELOAD PASS (2026-08-28, human-driven)

Kenny drove it; automation only verified. Open `pt_campfire_s01.prt` -> Save As
`C:\save-test\campfire-resave.prt` (8,040 B vs 6,899 B original) -> File>Open
the saved file -> tree repopulates AND the fire renders. Census: all semantic
structure 1:1 (PEFT/EMGP/3x EMTR/3x PTQD + ramps/textures/timing); differences
are FORMAT-VERSION UPGRADES - emitters 0012 -> 0014, version chunks 0001 ->
0002, WVFM 63 -> 72 (later-SOE emitter parameters serialized with defaults).
Third instance of the pattern: these tools UPGRADE old data to their current
schema on save (SpaceQuest navRadius column, UIBuilder attribute
normalization, ParticleEditor emitter version).

Incidental findings while driving:
* "Campfire not visible" = the effect TRANSLATION was non-zero (off-camera).
  Reset + the Snap-to-player button brought it back. Not a render bug.
* The UI stopped accepting clicks once after menu use; process Responding=TRUE,
  no dialog present; Esc / Alt+Esc released it. Looks like a stuck Qt menu/
  mouse grab, one occurrence, not reproduced.
* File > New works but takes ~20s to visibly reset - not a hang, don't kill it.

## SwooshEditor + LightningEditor - SAVE PASS (2026-08-28, human-driven)

**SwooshEditor**: `pt_electric_sword.swh` -> save -> census 1:1, SWSH form
version upgraded 0000 -> 0001 (+12 bytes of new-field defaults). Same
upgrade-on-save pattern as ParticleEditor/SpaceQuest.

**LightningEditor**: `force_lightning.ltn` -> save -> **BYTE-IDENTICAL to the
SOE original**. Strongest fidelity result in the sweep - its .ltn version
matches the original, so the round trip is exact.

**The .swh probe bug has a visible symptom**: LightningEditor's Save As
writability probe uses ".swh" (copy-paste from SwooshEditor,
MainWindow.cpp:255) and the probe CREATES the file - every Save As leaves a
0-byte `<name>.swh` beside the real .ltn. Confirmed live: saving
`force_lightening-resave.ltn` produced `force_lightening-resave.swh` (0 B).

**Release-build fact that will confuse anyone using these two tools**: the
ENTIRE property panel is disabled BY DESIGN in release - MainWindow.cpp:513-519
(#ifdef _DEBUG gates editing; the #else disables m_mainToolsFrame outright).
SOE only allowed swoosh/lightning EDITING in debug builds; release builds are
viewers with working File I/O. The ironically-named 'Debug' UI group (demo
controls) stays enabled. Seventh instance of the _DEBUG-only behavior trap.

**OPEN observation (not chased)**: SwooshEditor's animation demo is inert -
the attacker/defender never play the combat action (alter() re-fires
handleCombatAction every ~2s; combat_manager.iff + 52 playback .pst ARE in
the mounted TREs; no warnings logged - whatever fails is silent in release).
Both podracer_energy_binders*.swh files in the SOE tree are 0 bytes -
placeholders, not valid opens.

## SoundEditor - SAVE PASS (2026-08-28, human-driven)

`music_combat_loop.snd` -> Save As -> 933 bytes, census identical, same 28
samples - in EXACTLY REVERSED order (writer iterates its list back-to-front;
cosmetic for a Random-No-Repeats playlist). First attempt saved a 163-byte
1-sample template because the open hadn't landed - ALWAYS confirm "Sample List
(28 samples)" before saving; the tool happily saves whatever it holds.

## ShipComponentEditor - SAVE ALL PASS in sandbox (2026-08-28) - 10/15

cfg sharedPathDsrc/Data temporarily -> C:\save-test\shipcomp (restored after).
Ctrl+S (Save All, no dialog) wrote **1,288 files**: master ship_chassis and
ship_components .tab+.iff plus per-chassis attachment .tab+.iff for the whole
fleet. Spot checks: ship_chassis_xwing.iff BYTE-IDENTICAL to the SOE copy;
master .iffs census-identical DTII. Master .tab rows differ from the SOE loose
tree - DATA VINTAGE, not corruption: the tool writes what it loaded from the
mounted TREs (SWGSource 3.0), a different snapshot than the loose tree.

## AnimationEditor - TRE-resident files CANNOT be saved (loud, honest failure)

Ctrl+S on the boot-loaded ASH tab -> error dialog: "failed to write IFF-based
ASH file to path [patch_57_client_00.tre[appearance/ash/all_b.ash]]". So
TreeFile::getPathName on a TRE-resident file returns the tre[...] bracket
notation, the writer fopens that string, and fails - RELEASE-VISIBLE dialog,
unlike most failures in this tree. The earlier prediction (fallback writes to
a relative path under CWD) was WRONG - the fallback never engages.
Save is only usable for files under a real searchPath. Test rerun with a
sandbox searchPath11=C:/save-test/anim holding loose all_b.ash + both LATs
(AnimationEditor.cfg backed up as .pre-savesweep.bak; maxSearchPriority=12 so
11 is read; 11 beats the TREs at 0-8).

## AnimationEditor - SAVE PASS via sandbox searchPath (2026-08-28) - 11/15

With searchPath11=C:/save-test/anim (loose all_b.ash + both LATs), Ctrl+S on
each tab rewrote all three files BYTE-IDENTICAL (hash unchanged, mtime moved) -
perfect round trip through both writers. Each save also emits an XML sibling
(all_b.ash.xml ~1MB etc.) - the writers produce IFF + XML export together.
Success is SILENT (no dialog) - by design. cfg restored after the test.
Incidental: with the loose SOE-tree copies loaded instead of the TRE vintage,
the avatar WALKED OFF SCREEN at boot - the loose tree's default logical
animation apparently carries root motion. Cosmetic, but expect it if anyone
mounts the loose tree for this tool.

## ClientEffectEditor - EDIT + SAVE PASS (2026-08-28, human-driven) - 12/15

avatar_explosion_01.cef + added Camera Shake -> Save As -> census: CAMS 1->2,
everything else 1:1 (CPAP/PSND/CLEF). A true edit round-trip.
TRAPS confirmed live, in order encountered:
1. Save is a SILENT no-op unless m_effectTemplateModified - no dialog, no
   write, no feedback. The first attempt "did nothing" because the edit
   preceded the file open (open resets the flag). Edit AFTER opening.
2. Tree Value-column edits REVERT on commit (Kenny observed) - only the
   context-menu add paths set the modified flag (MainWindow.cpp:596-599); the
   value-edit path was not exercised further. Worth its own look if
   value-editing matters.
3. Both false alarms checked: the SOE original was never overwritten (mtime
   intact, 0 files newer in the clienteffect dir).

## NpcEditor - CLIENT-DATA WRITER PASS; template writers blocked by missing sources (2026-08-28) - 13/15 (partial)

Kenny dressed the boot avatar (3 wearables + customization sliders) -> Ctrl+A
-> three C:\save-test outputs.

* **npc-client.mif: PASS with real content** - 742 B of generated MIF source
  holding exactly the UI state: UseMeshGenerator for shoes_s01_m / pants_s13_m
  (color 41) / shirt_s32_m (colors 215/202) + CustomizationSetInt blend_fat 95,
  index_color_skin 15. The dress->save loop works end to end.
* **npc-server.tpf / npc-shared.tpf: 46-byte stubs** - only the cross-reference
  lines, each CORRECTLY rewritten (sharedTemplate -> npc-shared.iff via the
  .tpf->.iff map; clientDataFile -> npc-client.cdf via .mif->.cdf). The base
  template content is missing because the patch SOURCE cannot be read:
  - fresh mode needs text/templates/base_humanoid.txt +
    shared_base_humanoid.txt (the NpcEditor.tab ServerFile/SharedFile columns)
    - **absent everywhere**: 0 hits in all 209 TREs, nothing loose, nothing in
    the SOE tree. Never shipped.
  - open-existing mode reads the originals recorded at open; those resolved to
    dsrc/sku.0/sys.client/.../object/creature/player/*.tpf which DOES NOT
    EXIST (the real sources are under sys.server and sys.shared).
  Errors are QMessageBoxes only - NOTHING reaches warning.log, and warning.log
  is truncated by every tool launch, so post-hoc log forensics is useless here.

Same category as QuestEditor's icons and the .cnv sources: SOE-internal dev
data that never shipped. Code path exercised; content gap documented.

## QuestEditor - SAVE PASS (2026-08-28, human-driven) - SWEEP COMPLETE

Open u16_nym_meet_townspeople.qst -> File>Save As C:\save-test\resave.qst
(cfg export dirs sandboxed, RESTORED after):
* .qst BYTE-IDENTICAL to the SOE original (12,865 B, 0 diff) - third exact
  round trip of the sweep.
* Full fan-out landed: questlist + questtask .tab (real content, string ids
  renamed to the new basename), resave.stf (1,531 B). The basename regexp
  works despite looking wrong (greedy .* with empty capture concern - in
  practice Qt3 QRegExp yields the right basename).
* Both compiled .iff outputs are 0 BYTES - compile() shells out to an external
  ToolProcess (compileDataTable) and the tools/ directory never shipped
  (documented 08-23: toolPath absent). NOT a save defect; the editor's own
  writers are all correct. SOE's DataTableTool.exe in the reference exe/win32
  can compile .tab->.iff manually if ever needed.
* TRAP: after opening a file, plain Ctrl+S saves back to the OPENED PATH -
  in-place into the SOE tree. Use File>Save As only.

# ===== SAVE SWEEP FINAL TALLY (2026-08-28) =====

**14 of 15 tools driven through their save path** (SwgGodClient deferred to the
server session by design). 13 full PASS + NpcEditor partial (client-data
writer PASS; template writers blocked by unshipped text/templates sources).

Byte-identical round trips: LightningEditor (.ltn), AnimationEditor (all
three files), QuestEditor (.qst), ShipComponentEditor (xwing attachment .iff),
SwgSpaceZoneEditor (gen1==gen2 across .tab AND .iff).

The recurring pattern worth knowing: these tools UPGRADE old data to their
current schema on save (ParticleEditor emitters 0012->0014, SwooshEditor SWSH
0000->0001, SpaceQuest navRadius column, UIBuilder attribute normalization).
Byte-fidelity happens exactly when the on-disk format version matches the
build's.

All originals audited untouched; every near-miss was caught by the driver's
overwrite guard or turned out to be a false alarm.

## 2026-08-28 (evening): QuestEditor's ENTIRE save pipeline now works - three fixes

Kenny asked for the compile step to work. Three separate defects stood in the way:

1. **QuestChecker needed perl (absent).** Ported the 543-line QuestChecker.pl to
   PowerShell - `src/build/win32/exe/win32/QuestChecker.ps1`, original .pl
   preserved beside it. Rule-for-rule faithful including quirks (isTrue("") is
   TRUE; perl numification; exit 0 even with findings). Verified: clean quest ->
   0/0 SUCCESS; adversarial quest -> 19 errors + 1 warning across every rule
   category. ToolProcess::checkQuest now invokes powershell -File
   ../../exe/win32/QuestChecker.ps1 (also fixing the original's single-`..`
   path which resolved to x64\exe\win32 - nowhere).

2. **DataTableTool did not exist for x64** (SOE's 2016 exe rejects args - see 3).
   Built from in-tree source. Two vcxproj-chain fixes: build with
   -p:SolutionDir=<src\build\win32\> (the archive dependency's includes hang
   off $(SolutionDir), undefined for direct vcxproj builds), and the
   Release|x64 link needed libxml2.lib from deps\x64\lib + zlib.lib from the
   solution output (the project referenced 32-bit prebuilts). Output lands as
   Release\DataTableTool.exe - exactly the bare name QuestEditor spawns.

3. **THE ROOT CAUSE of 'Invalid command line specified' - a 20-year-old parser
   bug.** CommandLine.cpp gobbleString() terminated unquoted arguments at ANY
   '-', so any dashed path (c:/save-test/...) split mid-argument and failed the
   parse - in OUR build AND SOE's own 2016 binary identically. Fixed: '-' only
   terminates at stringLength 0 (token start, where it introduces an option).
   No grammar rule relied on mid-argument splitting (glued short options were
   never lexed). NOTE: this is sharedFoundation - every tool and the client
   pick up the (strictly more permissive) behavior on their next rebuild.

END-TO-END VERIFIED: QuestEditor open resave.qst -> Ctrl+S -> .qst + both
.tabs + BOTH COMPILED .IFFs (2,417 / 1,974 B real DTII; were 0-byte failures)
+ .stf, all in the sandbox. DataTableTool standalone: "SUCCESS creating data
table". QuestEditor.cfg sandbox redirect still ACTIVE pending Kenny's checker
confirmation - restore from .pre-savesweep.bak when done.

## SOE-tree write audit (Kenny's request) - TWO files were hit; both reconstructed

Full-tree scan for files modified 2026-08-28: exactly TWO, both dsrc NpcEditor
default-save targets, clobbered at 17:00 during the failed NpcEditor save
attempts (each failed attempt APPENDED another stub cross-reference line):
  dsrc/sku.0/sys.server/.../object/mobile/beginner_brawler_client_1.tpf
  dsrc/sku.0/sys.shared/.../object/mobile/shared_beginner_brawler_client_1.tpf

RECONSTRUCTED exactly from two untouched sources: the sibling _client_2/_3
templates (identical modulo index + appearance) and the COMPILED data-side
.iffs, which preserved _client_1's truth (appearance/bith_m.sat - the Bith
Kenny was dressing; he had opened this NPC). Server rebuilt at the siblings'
exact 283 B; shared at 407 B with bith_m. The checker output and QuestEditor
pipeline work is in the previous section; the .qst checker ran CLEAN in-app
(Kenny confirmed the banner + 0/0 summary). QuestEditor.cfg restored - NO
sandbox redirects remain in any cfg.

WARNING, sharper than before now that saves SUCCEED: NpcEditor's SaveDialog
Browse defaults and QuestEditor's plain Ctrl+S both point at / write back to
the reference tree. The failures that used to protect it are fixed. Save As
to a scratch path first, always.

## NEXT PHASE ROADMAP -> .planning/TODO-tools-productization.md (2026-08-28)

Kenny's direction, captured in the TODO file: (1) port
buildQuestCrcStringTables (the .pl exists NOWHERE on this machine - find in
SWGSource history or reimplement from the output format); (2) strip Perforce
from every tool (several P4 buttons AUTO-SAVE first - dangerous); (3) a
usability pass per editor - "usable, not perfection" - seeded with the save
sweep's trap list; (4) packaging: inventory what loose data is NOT in the
SWGSource TREs (lmg/ui/ash/lat/dsrc/...), installer carries it and
parameterizes the cfg roots; (5) survey the CLI layer (templatecompiler,
miff, TreeFileBuilder/Extractor, mochac - DataTableTool already done) to
restore the end-to-end toolkit; (6) endgame: migrate that CLI layer to
SWG-Toolkit.

# ===== SESSION END 2026-08-28 - SAVE SWEEP DONE, PIPELINE FIXED - START HERE =====

Everything below is committed and PUSHED (origin/x64-dx11-qt-tools, in sync at
e10d37fb5). Working tree clean. No editors left running. Kenny confirmed every
human-driven result in-session.

## What this day delivered, shortest form

1. **Save-path sweep COMPLETE: 14 of 15 tools driven through save** (SwgGodClient
   deferred - needs the server). 13 full PASS + NpcEditor partial (client-data
   .mif writer works with real content; .tpf writers blocked by never-shipped
   text/templates sources). Five byte-identical round trips. Per-tool verdicts
   + the confirmed trap list: docs/TOOLS-GUIDE.md Part 2.5. The tools UPGRADE
   old data to their current schema on save - expect version deltas vs 2004
   data; they are correct behavior.
2. **QuestEditor's save pipeline fully works now** - three fixes: QuestChecker
   ported perl->PowerShell (tracked at src/build/win32/exe/win32/, adversarially
   tested, ran clean in-app); DataTableTool built for x64 from in-tree source
   (needs -p:SolutionDir=src\build\win32\ - the archive dep's includes hang off
   it; x64 link uses deps\x64\lib libxml2 + solution zlib); and THE ROOT CAUSE -
   **CommandLine.cpp gobbleString terminated unquoted args at any '-'**, so
   every dashed path failed "Invalid command line" in every engine CLI tool
   since 2004. Fixed in sharedFoundation; all tools + client inherit on rebuild.
3. **SwgConversationEditor startup dialogs 3 -> 1** (mochaCommand + dictionary
   keys added; remaining dialog is the structural exe\win32 check).
4. **SOE-tree write audit (Kenny asked): 2 dsrc templates were clobbered by
   failed NpcEditor saves; both reconstructed EXACTLY** from untouched siblings
   + the compiled .iffs (which preserved the truth, incl. the bith_m.sat). The
   memory note now carries the audit one-liner - run it after any save session.
5. **Roadmap captured: .planning/TODO-tools-productization.md** - 6 workstreams
   (CRC port, P4 removal everywhere, per-tool usability pass, installer +
   not-in-TREs inventory, CLI-layer survey, SWG-Toolkit endgame). The CRC port
   collapsed to ONE script (buildCrcStringTable.pl, found in
   D:\Code\Galaxies-Reborn\swg-main\tools\ along with the whole SOE pipeline;
   the community's p4-free wrapper is swg-main\utils\
   build_quest_crc_string_tables.py). mochac.pl remains UNFOUND anywhere.

## Machine state

* C:\save-test\ = the sweep's artifacts (resaves, sandboxes, broken.qst test
  file, build logs). Disposable, but the sandboxes are handy for re-tests.
* All tool cfgs restored - NO sandbox redirects remain (verified: zero
  .pre-savesweep.bak files).
* Release dir gained: DataTableTool.exe (x64, working), compiled_shader cache
  (from 08-24), appearance/ash+lat dirs (AnimationEditor test, empty now).
* SOE reference tree: fully intact after reconstruction; audit `find "D:/SWG
  All Tools Working" -type f -newermt <date>` after future save sessions.

## Next session, in order

1. **The god-client server evening** (standing item, Kenny was bringing the
   server up): walk on an edited .trn in SwgGodClient (closes
   edit->save->PLAY), then drive the god tools - the largest untested area.
   Login cfg facts are in the 08-24 section (loginServerAddress0 indexed keys).
2. Then the productization TODO, roughly in its own order - item 1 (CRC port)
   is small and unblocks the last QuestEditor button.

## Traps refreshed this session (beyond the standing list)

* QuestEditor Ctrl+S writes back to the OPENED path - and now SUCCEEDS. Save
  As first, always. NpcEditor's SaveDialog defaults also point into the
  reference tree.
* warning.log is truncated by every tool launch and QMessageBox errors never
  reach it - post-hoc log forensics on UI errors is useless; capture dialogs
  live.
* Native file dialogs: fill ONLY dlg item 0x480 (or cmb13's edit), verify by
  readback, click via posted WM_COMMAND - and treat any 'Confirm Save As' as
  a wrong-target signal (scripts/_drive-save.ps1 embodies all of it).

# ===== SESSION 2026-08-29 - CRC PORT DONE - QuestEditor 100% =====

Productization TODO item 1 is DONE and verified end to end. Everything
committed. QuestEditor now has no broken buttons left except the deliberate
p4 ones (item 2's business).

## What was done

* **`src/build/win32/exe/win32/BuildQuestCrcStringTables.ps1`** - one
  PowerShell script replacing the perl pair (buildQuestCrcStringTables.pl p4
  wrapper + buildCrcStringTable.pl) AND Miff: it walks
  `<root>/data/sku.0/sys.shared/compiled/game/datatables/questlist`, CRCs the
  names (SOE's table, transcribed mechanically from the perl), and writes the
  binary CSTB IFF directly plus the CRLF .tab. Root is derived from
  `defaultListDirectory` in QuestEditor.cfg (text before `/dsrc/`), so it
  tracks the tool's own config; `-Root`, `-OutputIff`, `-OutputTab` override.
  Generic mode `-InputFile names.txt -OutputIff out.iff` reproduces the inner
  buildCrcStringTable.pl for OTHER crc tables (object templates etc, TODO
  item 5).
* **ToolProcess.cpp** buildQuestCrcStringTables() now spawns powershell with
  `-Branch <branch>` - same shape as the QuestChecker port. Rebuilt
  QuestEditor_r (vcxproj + `-p:SolutionDir=src\build\win32\`), links clean.

## Verification (all three layers)

1. Generic mode fed the 2736 names extracted from the SOE tree's shipped
   `quest_crc_string_table.iff` -> regenerated it BYTE-IDENTICAL (125160
   bytes, 0 differing).
2. Walk mode from the Release dir (root out of QuestEditor.cfg) -> also
   byte-identical. The SOE questlist dir holds exactly 2736 .iffs and the
   walked names equal the shipped table's names exactly.
3. In-app: drove Tool > BuildQuestCrcTables via Alt+T,T (guarded foreground,
   PrintWindow evidence). Console printed both paths, "2736 entries written",
   DONE. On-disk iff hash unchanged (0C7339C5FDCBC8FF...), .tab went from
   the stale 2654-line SOE copy to a fresh 2736-line one.

## Facts worth keeping

* The shipped SOE `.iff` (2736 entries) and its sibling `.tab` (2654 lines)
  were from DIFFERENT bakes - never byte-compare a regenerated tab against
  the SOE tab. The iff is the truth; its STNG chunk carries the exact input
  name list.
* IFF numbers: chunk/form sizes big-endian, chunk payloads little-endian,
  cstrings NUL-terminated; entries sorted by unsigned CRC ascending (perl
  sorted "0x%08x" strings - same order). Tab lines are `0x%08x<TAB>name`
  CRLF.
* PS 5.1 parses 8-hex-digit literals as WRAPPED Int32 (0xFFFFFFFF is -1);
  the table uses the `L` suffix. Do the CRC math in [long] with 0xFFFFFFFFL
  masks.
* The in-app run WRITES INTO the SOE reference tree (that is its job - those
  are the pipeline's output slots). SOE originals of both files are backed
  up with hashes at `C:\save-test\soe-crc-backup\`.
* QuestEditor's title still says "Built Aug 28" after a relink - the banner
  __DATE__ lives in a TU that only recompiles when ITS file changes. Check
  the exe mtime, not the title, when verifying you run a fresh build.

## Next session

The handoff order stands: the god-client server evening when Kenny brings
the server up (walk an edited .trn, drive the god tools), else continue the
productization TODO - item 2 (strip Perforce; the auto-save-before-p4
buttons are the dangerous ones) or item 3 (usability paper cuts, seed list
in the TODO).

# ===== SESSION 2026-08-29 (later): PERFORCE STRIPPED FROM ALL EDITORS =====

TODO item 2 done for the shipped editors. Every p4 button/menu/spawn removed,
9 projects rebuilt clean, all 8 changed tools launch-smoked with PrintWindow
screenshots confirming windows + toolbars.

## What was removed, per tool

* QuestEditor: AddToPerforce action (menu+toolbar+Ctrl+P accel in .ui),
  MainWindow/QuestEditor::addToPerforce, ToolProcess::addToPerforce;
  "sync from Perforce" error texts reworded.
* NpcEditor: Perforce action (Tools menu + toolbar), MainWindow::AddToPerforce
  + slot (p4 edit/add of all 6 file infos).
* SwgDraftSchematicEditor: ID_BUTTON_P4EDIT (toolbar+handler+resource id) -
  this was the auto-save-then-p4 one; DialogConsole "p4 info" probe; the
  Compile no-path message no longer says "conversation"/"Perforce".
* SwgSpaceQuestEditor: ID_BUTTON_P4EDIT + Doc::edit() (the whole p4 routine),
  the disabled Tools>Open/Edit All menu item + editAll()/openItem editDocument
  plumbing, DialogConsole "p4 info", string-table prompt, resource ids.
* SwgSpaceZoneEditor: ID_BUTTON_P4 (last toolbar button) +
  SpaceZoneTreeView::perforceEdit + ChildFrame handler + string + id.
* SwgConversationEditor: ID_BUTTON_P4EDIT + OnButtonP4edit + H_shellP4edit
  hint + the ScriptShellView p4 edit/add case (p4Command cfg key now unread).
* ShipComponentEditor: "P4 Edit Files" File-menu item (Ctrl+P) + slot,
  "Jump to P4"/"Jump to P4 Shared Template" context items (spawned p4win),
  p4 add spawns in ChassisNewDialog and TemplateNewDialog.
* UIBuilder: checkout button (IDC_CHECKOUT) in the object inspector +
  CheckOutSelectedFile + IDI_CHECKOUT icon; p4.bmp/p4.ico deleted.
* SwgClient.vcxproj: inert libclient/libsupp/librpc removed from the
  Release|x64 link; client relinks clean (35MB exe, 09:39).

## The MFC toolbar bitmap trap (worth remembering)

MFC TOOLBAR resources map BUTTON entries to bitmap-strip tiles in order -
deleting a BUTTON line shifts every later button's icon. The four Toolbar.bmp
strips (4bpp uncompressed, 32x32 tiles) had their p4 tile cut with a python
tile-cutter (scratchpad); tile indexes were DraftSchematic 7, SpaceQuest 7,
Conversation 11, SpaceZone 13. Screenshots confirm no icon shift anywhere.

## What was intentionally left

* SwgGodClient - the x64 port already ships SWG_DISABLE_PERFORCE:
  GodClientPerforceUser::runCommand stubs out and fails cleanly, active x64
  links carry no p4 libs. Its p4 UI is entangled with untested god-tool
  workflows; revisit after the server evening.
* TemplateCompiler / TemplateDefinitionCompiler (real p4 API users, not yet
  built - item 5's job), MayaExporter / TemplateEditor / SwgContentSync
  (not shipped tools), the perforce library source itself, and the dead
  Win32-config lib lists.

## Machine state

All 8 changed editors relinked 09:33-09:39 and smoked; screenshots in the
session scratchpad (p4strip-shots/). No editors left running. SwgClient
relinked but not re-run (link-only change, exit 0).

# ===== SESSION 2026-08-29 (evening): EDIT->SAVE->PLAY CLOSED - god client walk on edited terrain =====

Kenny stood the server up. **The edited .trn walk happened and PASSED.**

## The result

tatooine3.trn (the 08-27 TerrainEditor edit: height change + circle boundary
at (-3616,-832) r=224) staged as terrain/tatooine.trn in
D:/Code/Galaxies-Reborn/stage-B-override (priority 12). God client logged in
(all three Login: lines clean), god mode granted by the server automatically
(GameWidget.cpp:1578 sends setGodMode on world entry), /teleport to the site,
and Kenny walked the edited terrain: carved depression rendered, textures/
flora/lighting correct, and the server-placed rocks FLOATING at the old
ground height - the exact predicted client/server terrain mismatch artifact,
i.e. positive proof the client renders the EDITED file. Screenshot:
logs/_shots/godclient-edited-terrain-walk.jpg (GOD MODE indicator visible).

To revert the override: delete stage-B-override/terrain/tatooine.trn.
To make the edit real server-side: copy it into the VM's server data (not done).

## Two walls hit on the way, both solved - REUSABLE KNOWLEDGE

1. **The god client has NO typed command console in this build.** The
   backtick/Ctrl+F8 console toggle is a null-guarded no-op (the CUI Console
   page is missing from the NGE-retail UI bundle - guarded by an earlier
   session, comment at ActionsGame.cpp:211). The Qt ConsoleWindow is
   OUTPUT-ONLY (ConsoleWindow.cpp - QTextView, no input line). The in-game
   chat line is the only place to type. Also: /warpme and the whole
   scene/remote/mount parser set are compiled out of release
   (SwgCuiChatWindow.cpp:437 '#if PRODUCTION == 0'; Production.h derives
   PRODUCTION from DEBUG_LEVEL=0).
2. **Admin slash commands are hidden behind SOE's obfuscated cfg key.**
   CuiCommandTableParser::resetCommands skips every command in the 'csr'
   display group (teleport included) unless ConfigClientGame::getCSR() -
   which is KEY_BOOL(0fd345d9) (ConfigClientGame.cpp:1169,886; deliberately
   gibberish-named). Fix: [ClientGame] 0fd345d9=true - now set in
   SwgGodClient.cfg with a comment. The working client always had it
   (swg-client-v2/stage/client.cfg:80). Client-side visibility only; the
   server still validates god mode per command. Symptom without it:
   "No such command, mood, chat type: teleport" (CuiChatParser.cpp:348).

## Focus-model facts for driving the god client

Title bar shows input owner: [Game Focus] = game grabbed mouse+keyboard,
[God Client Focus] = Qt panels have input. Toggle: Ctrl+F8 (or numpad Enter,
or the Game button on the game window). Clicking in the viewport always
grabs focus back to the game (GameWidget mousePressEvent). Entering god
mode DISABLES the HUD (GameWidget.cpp:1573); Ctrl+H toggles it back.

## Still open tonight: the god-tool surface (phase 3)

Selection, Objects/ServerTemplates panels, spawn/move/delete, bookmarks,
ObjectTemplate/Script menus. In progress as this block is written.

## 2026-08-29 evening (later): GOD-TOOL EDITING SURFACE PROVEN

Phase-3 results, all Kenny-driven against the live server:

* **Spawn -> move -> Apply Transform -> PERSISTED: PASS.** Camp cot spawned
  from the ServerTemplates panel (drag-drop into viewport, or right-click ->
  create-from-selected-template), moved, committed with Apply Transform
  (Space / Ctrl+T / Edit menu). Server accepted and the object stayed.
* **Selection works** on server-replicated objects (bantha selected/rotated).
  A CREATURE's Apply Transform gets stomped by its AI controller - the ghost
  clears and the object re-replicates at the AI's transform. Expected, not a
  defect. Test transforms on static objects.
* **World-snapshot/baked static scenery (the floating rocks) is not
  selectable** - no live server object behind it. Also expected.
* **ServerTemplates panel populated** only after adding the [GodClient]
  section to SwgGodClient.cfg - the cfg had NONE, so every panel walked the
  compiled-in default c:/work/swg/... The section is SOE's own (reference
  tree exe/win32/SwgGodClient.cfg) rebased onto D:/SWG All Tools Working;
  sharedTerrainDirectory omitted (no local sys.shared terrain dir); editors
  set to notepad.exe. VALUES QUOTED - the space-in-path trap.
  SOE's godclient_favorites.xml copied to Release (cwd-relative load,
  FavoritesWindow.cpp:23).
* Ghost model, for the record: cyan cube = pending ghost, red cube = server
  position. Apply Transform (ActionsEdit) syncs ghosts -> server via
  ServerCommander::setObjectTransform; ESC cancels ghosts. If Apply BEEPS
  and does nothing, ServerObjectData had no god-info for that object
  (ServerCommander.cpp:356).

Still unexercised: bookmarks (in progress), object delete (in progress),
ObjectTemplate/Script menus, Brushes/Palettes, buildout areas, theater
creation. The essential surface (connect, walk edited terrain, spawn,
manipulate, persist) is all PROVEN.

# ===== SESSION END 2026-08-29 - GOD CLIENT EVENING COMPLETE - START HERE =====

The standing item is CLOSED. Everything below verified by Kenny in-session
against the live server (192.168.1.200), all committed and pushed.

## Final scorecard for the god-client evening

| check | result |
|---|---|
| login -> world entry | PASS (all three Login: lines) |
| god mode | PASS (auto-requested on entry, server granted) |
| admin slash commands | PASS after [ClientGame] 0fd345d9=true |
| walk on edited .trn | PASS - **edit->save->PLAY closed**; floating rocks = server has stock terrain (expected); screenshot logs/_shots/godclient-edited-terrain-walk.jpg |
| select server object | PASS (bantha) |
| spawn from template | PASS (camp cot, after [GodClient] cfg section) |
| move + Apply Transform + persist | PASS |
| delete object | PASS |
| bookmarks | PASS (double-click = CAMERA jump, not avatar - by design) |
| creature transform | AI stomps it (ghost clears, object re-replicates) - expected, use static objects |
| baked scenery selection | correctly unselectable (no live server object) |

## Close-out state

* God client shut down. Terrain override REVERTED (stage-B-override/terrain/
  deleted) - stock tatooine again; the edited file remains at
  C:\bake-test\tatooine3.trn if ever wanted (server-side deploy would be the
  next step for a real terrain change).
* SOE-tree write audit run at close (find -newermt session start).
* SwgGodClient.cfg permanently gained: [ClientGame] 0fd345d9=true and the
  full [GodClient] path section (SOE's, rebased). godclient_favorites.xml
  (SOE's) now beside the exe.
* Not exercised, lower priority now: ObjectTemplate/Script menus, Brushes/
  Palettes, buildout areas, theaters. The essential god surface is proven.

## Next session

Back to the productization TODO: item 3 (usability paper cuts - seed list
in the TODO: LightningEditor .swh probe, ClientEffectEditor value-revert,
ConversationEditor dishonest save-failure, NpcEditor SaveDialog defaults,
QuestEditor Ctrl+S no-prompt, TerrainEditor tree scroll, SwooshEditor demo)
or item 4 (not-in-TREs inventory + installer). Item 5's CLI survey now has
one more datum: the god client needed no CLI tools tonight.

# ===== SESSION 2026-08-29 (night): CLI TOOLKIT BUILD-OUT - 8 new tools - START HERE =====

TODO item 5 executed across all three tiers, Kenny-authorized ("work on all
3 tiers"). Everything committed and pushed. Full status, recipes, and the
deferred list live in .planning/TODO-tools-productization.md item 5 - read
that first; this block is the summary.

**10 CLI tools now live in Release**: TemplateCompiler, Miff, TreeFileBuilder,
TreeFileExtractor, TemplateDefinitionCompiler, UpdateLocalizedStrings,
LabelHashTool, ViewIff (new tonight) + DataTableTool, Turf (earlier).

Verification highlights (each tool proven, not just built):
* Miff reproduced the shipped quest_crc_string_table.iff BYTE-IDENTICAL from
  perl-format MIF text - which also re-validates the CRC PS port a third way.
* TreeFileBuilder/Extractor: build->list->extract round trip byte-identical,
  and the built archive parses as v0005 in the independent trelist.py.
* TemplateCompiler compiles SOE dsrc against SOE tdfs -> v0010 iffs, the
  exact schema the in-tree engine expects (shipped data is v0009 - the known
  upgrade-on-recompile delta, NOT a defect).
* LabelHashTool agrees with the shipped CRC table.
* TDC regenerates template C++ matching in-tree generated code modulo the
  TFD custom-code sections (which preserve hand-written methods by design).

Machine facts future sessions need:
* Miff requires a C preprocessor: cpp.exe beside the exe, or MIFF_CPP env
  var. MIFF_CPP is setx'd to VS clang on this machine. No GNU cpp exists
  anywhere locally; SOE flex/bison DO exist at swg-main/tools (used for the
  Miff grammar build; BISON_SIMPLE must point at Miff's bison.simple).
* templateCompiler.cfg now sits in Release (TreeFile searchPath for @base
  resolution). tdfs resolve by walking UP directories from the .tpf; base
  .tpfs resolve the same way - sandboxes need the base chain (see
  C:\save-test\tpl-sandbox for a working example).
* TDC writes generated C++ into ../../../..-style paths from the tdf's own
  sharedpath/compilerpath directives - NEVER run it inside the SOE tree
  unless you intend to regenerate; sandbox layout at C:\save-test\tdf-sandbox.
* Deferred with reasons (StringFileTool, ShaderBuilder, TextureBuilder,
  CreateShaderTemplate, ClientCacheFileBuilder, exporter tools) - item 5 in
  the TODO has the exact error shapes and the reusable build recipes.

## Next session
Item 3 (usability paper cuts) or item 4 (not-in-TREs inventory / installer).
The DraftSchematicEditor Compile button can now actually work end to end
(templatecompiler exists) - worth a quick in-app verification when next in
that editor.

# ===== SESSION 2026-08-29/30 - USABILITY PASS: Lightning + Swoosh DONE =====

Item-3 pass running interactively with Kenny (he drives the UI, fixes land
live). Two editors completed and verified in his hands; all committed+pushed.

## LightningEditor - 4 fixes, all verified
* Save As .swh probe litter -> probes the real .ltn (SOE's own tree carries
  a 0-byte podracer_energy_binders.swh from this bug, ~20 years old).
* INVISIBLE BOLTS solved via RenderDoc (automated launch-capture + driving
  Ctrl+O during the frame-delay window works; captures land as _frameN.rdc):
  the endpoint demo pinned bolts at the WORLD ORIGIN - fine on simple.trn,
  invisible after the 08-24 move to tatooine (avatar spawns far away; clip
  y ~ -725). All demo modes now anchor to the player. Save round trip and
  color edits verified.
* Caption only refreshed in paintEvent (which never fires) - update() forced
  on open/save.

## SwooshEditor - property panel enabled + combat demo fully revived
* Panel was force-disabled in release (viewer-only since SOE). Enabled; only
  the debug-only 'final game swooshes' toggle stays greyed.
* The 'animation demo inert' mystery ran FIVE silent layers deep (every
  failure DEBUG-only): demo fires -> selector FOUND -> script accepted ->
  PSAA initialize -> LAT lookup fails because the avatar never enters the
  weapon 'ready' combat states. Root: requestSetCombatTarget was removed
  upstream (SOE TODO comment in the tool). Fix: CreatureController::
  overrideAnimationTarget re-applied per alter.
* Weapon switching: unequip-to-inventory fails on the inventory-less avatar
  and the deleted weapon left the hand slot occupied - first equip worked,
  all later ones failed silently. Fix: transferItemToWorld before delete.
* Polearm trails: tab rows pointed at lower_posture_* entries (no
  StartTrailsAction in their scripts); repointed at knockdown_polearm_*.
  Trail hardpoints (tr1s/tr1e) verified present on the weapon meshes.
* Kenny-verified: punch/kick/sword/lightsaber/polearm/beams/flamethrower all
  swing with trails; switching works. Defender + reference-swoosh orbit also
  player-anchored (same origin disease as the bolts).

## Reusable diagnosis knowledge
* The combat/animation pipeline has ~6 consecutive silent failure points
  (CCPM no-selector fallthrough, PSAA actor/variable/empty-name skips,
  SHAC lookup miss) - ALL debug-only. Instrument with temporary WARNINGs,
  then git-restore the library files (keep tool-side fixes only).
* Trail system: weapon trails need tr1s/tr1e hardpoints on the WEAPON mesh
  and a StartTrailsAction in the combat entry's playback script; body trails
  ride lankle/rankle/hold_l/hold_r with thin camera-facing ribbons.
* dlt20a Rifle row still references fire_5 which doesn't exist in all_b.ash
  root.combat - datatable nit, untouched.

## Remaining item-3 seeds
ClientEffectEditor (tree value edits revert; silent no-op save),
SwgConversationEditor (failed save returns TRUE + clears modified flag),
NpcEditor (SaveDialog defaults point into the reference tree; silent
template-writer stubs), QuestEditor (Ctrl+S writes opened path, no prompt),
TerrainEditor (Construction Layers scroll; 3D View untested).

# ===== SESSION END 2026-08-30 - CONTEXT CLEAR - START HERE =====

Everything committed and PUSHED (origin/x64-dx11-qt-tools in sync at
716b19091). Working tree clean. No editors running. This block is the
complete resume point; the two session blocks above it (CLI toolkit
build-out, usability pass) carry the deep detail.

## What this mega-session delivered, in order

1. **CRC port (TODO item 1) DONE** - BuildQuestCrcStringTables.ps1 in the
   tracked exe/win32 store, byte-identical vs shipped, wired into
   QuestEditor, run clean in-app. QuestEditor has NO broken buttons left.
2. **Perforce stripped (TODO item 2) DONE for all shipped editors** - every
   p4 button/menu/spawn removed from 8 tools + UIBuilder; toolbar bitmap
   tiles cut so icons don't shift; SwgClient's inert p4 libs dropped. God
   client intentionally untouched (already stubbed via SWG_DISABLE_PERFORCE).
3. **God client evening COMPLETE** - edit->save->PLAY closed (walked the
   edited .trn against the live server; screenshot in logs/_shots/), god
   editing surface proven (spawn/move/apply-transform/delete/bookmarks).
   Two permanent cfg gains: [ClientGame] 0fd345d9=true (unhides CSR slash
   commands) and the full [GodClient] path section. Login recipe and focus
   model (Ctrl+F8, backtick console is a no-op in this build) documented in
   the evening blocks.
4. **CLI toolkit (TODO item 5) BUILT** - 10 CLI tools live in Release:
   TemplateCompiler, Miff (needs MIFF_CPP env var -> set to VS clang,
   persisted via setx), TreeFileBuilder/Extractor, TemplateDefinitionCompiler,
   UpdateLocalizedStrings, LabelHashTool, ViewIff + DataTableTool, Turf.
   Each verified (byte-identical where a reference existed). Deferred list
   + reusable build recipes in TODO item 5.
5. **Usability pass (TODO item 3) IN PROGRESS** - 2 of ~7 editors done:
   * LightningEditor: 4 fixes (probe litter, world-origin invisible bolts
     found via RenderDoc, caption refresh) - all Kenny-verified.
   * SwooshEditor: panel enabled in release + combat demo revived through
     THREE root causes (missing combat stance via overrideAnimationTarget,
     hand-slot leak killing weapon switching, polearm rows pointing at
     trail-less combat entries) - Kenny-verified across all weapon types.

## The interactive workflow being used for item 3 (KEEP USING IT)

Kenny drives the UI and reports; the session fixes live and relaunches.
Loop: pre-fix known paper cuts -> rebuild -> launch for Kenny -> he pokes,
asks what controls do, runs save scenarios -> instrument silent failures
with temporary WARNINGs when something is dead -> fix -> strip probes
(git-restore library files that only carried probes; keep tool-side fixes)
-> commit batch when Kenny confirms. Rebuilds need his editor CLOSED
(LNK1104 otherwise). Save-safe workspace: C:\save-test\papercut-pass\.

## NEXT: ClientEffectEditor (agreed with Kenny before the clear)

Known seeds: tree value edits REVERT (the editing-hostile one) and save
silently no-ops on unmodified docs. Pre-read the value-edit path in
src/engine/client/application/ClientEffectEditor before launching. Loose
.cef samples exist in the SOE tree appearance dir if needed.
Then remaining: SwgConversationEditor (failed save returns TRUE + clears
modified flag - Doc.cpp ~1118-1138), NpcEditor (SaveDialog defaults point
INTO the SOE reference tree + silent template-writer stubs), QuestEditor
(Ctrl+S writes opened path, no prompt), TerrainEditor (Construction Layers
tree cannot scroll; 3D View still never exercised).

## Machine state

* Release dir: all 16 editors + 10 CLI tools, everything current.
* C:\save-test\: papercut-pass\ (samples + Kenny's force-lightening-resave),
  tpl-sandbox\ + tdf-sandbox\ + tre-sandbox\ + lat-check\ (CLI verification
  sandboxes, disposable but handy), soe-crc-backup\ (SOE originals + hashes).
* MIFF_CPP user env var -> VS clang (miff's preprocessor).
* SOE reference tree pristine (write audit clean; my one warning.log litter
  deleted). Terrain override REVERTED - stock tatooine.
* Server VM (192.168.1.200) was up for the god evening; state now unknown.

## Traps refreshed this session (beyond the standing list)

* The combat/animation pipeline hides ~6 consecutive DEBUG-only failure
  points - instrument, don't theorize (details in the Swoosh block above).
* RenderDoc launch-capture works automated: renderdoc-cli capture -d 1500 +
  drive the file-open during the delay + hold foreground; output lands as
  <name>_frameN.rdc despite a 'timed out' message.
* SwooshEditor reads AnimationEditor.cfg ([ParticleEditor] section feeds
  ParticleEditor AND AnimationEditor - and Swoosh via its GameWidget quirk).
* Serverless avatar has NO inventory container - CuiInventoryManager
  unequip paths fail; anything doing container transfers on the tool
  avatar needs a serverless fallback.
* PS 5.1: 8-hex-digit literals wrap to negative Int32 (use L suffix);
  [Text.Encoding]::Latin1 doesn't exist.

# ===== SESSION 2026-08-29 (cont.): ClientEffectEditor usability pass DONE =====

Item-3 pass, third editor complete. All fixes Kenny-verified in-app ("this is
actually a really useful editor and it's super simple to use"). Committed.

## Fixes (all in ClientEffectEditor/src/shared/core/MainWindow.cpp)

* **Tree value edits reverted** - THE editing-hostile bug. Root cause is Qt
  itself: Qt3 QListView defaults defaultRenameAction to Reject
  (qlistview.cpp:2670), so ANY focus loss short of pressing Enter cancels the
  inline edit. No tool ever overrode it. Fix: setDefaultRenameAction(Accept)
  in the MainWindow ctor. NOTE for the remaining editors: any other Qt tool
  with setRenameEnabled columns has this same landmine.
* **Save was a silent no-op on unmodified docs** (gated on the modified flag,
  did nothing - no dialog, no message). Save now always opens the dialog;
  a filename typed without extension gets .cef appended (used to fail with
  only a warning.log line); wrong extension gets a message box; a successful
  save updates ms_currentFile + caption.
* **Two data-loss holes**: "save before closing? -> Yes" then CANCELLING the
  save dialog discarded the work anyway, in both the New and Close/exit
  paths. A cancelled/failed save now aborts the discard/close.
* **Caption shows `*` when modified**, refreshed on edit/add/delete/save.
* **Open refused files outside the searchPaths silently** - the reload-my-
  saved-file killer. If stripTreeFileSearchPathFromFile cannot map the path,
  the editor now falls back to the absolute path (TreeFile's default
  SearchAbsolute node opens it directly - verified present, cfg does not
  override it). All three open-failure branches (unopenable / no extension /
  wrong extension) now show message boxes instead of warning.log-only.

## THE WALKING AVATAR - root cause, and a TreeFile trap worth remembering

Kenny reported the viewport avatar WALKED instead of idling. Differential
test: ParticleEditor (08-24 exe) stood, CEE walked, same tatooine scene ->
suspected today's libs; but incremental rebuild recompiled NOTHING (objs
newer than pristine restored sources - the 15:55 libs ARE pristine) and no
shared-lib commit since 08-24 touches anything relevant. The real delta was
the CFG: ClientEffectEditor.cfg (08-24 18:55) mounted the ENTIRE SOE loose
tree (.../compiled/game) at searchPath11 so the Open dialog could map .cef
files. That root also holds appearance/animation (8,586 files), 194 .lat,
9 .ash, datatables/, combat/, playback/ - all shadowing the v3.0 TREs, and
the 2016 dev data resolves the avatar idle to a walk.

**The trap: you cannot fix this by demoting the priority.** TreeFile
registers searchPaths ahead of searchTrees at each priority and same-
priority earlier-added wins (TreeFile.cpp:345 + install loop order), so a
loose root shadows the TREs even at priority 0.

Fix: SCOPED mount. New root D:\Code\Galaxies-Reborn\stage-cee-loose\
containing ONLY a junction clienteffect -> SOE tree's clienteffect (948
.cef). searchPath11 repointed there; cfg comment documents the whole story.
Adding .prt/.snd/.ffe needs no searchPath at all (those flows use
TreeFile::getShortestExistingPath, suffix-matched against the TREs).

**Workflow note:** to open SOE loose .cef files, browse via
D:\Code\Galaxies-Reborn\stage-cee-loose\clienteffect\ (the original SOE path
no longer maps; with the absolute-path fallback it opens anyway, just
without the tree-relative name). Scratch saves (C:\save-test\...) reload
fine via the fallback - Kenny verified the full round trip.

**The junction is OUTSIDE the repo** - like stage-B-override, it is lost on
a machine wipe. One line recreates it:
  New-Item -ItemType Junction -Path D:\Code\Galaxies-Reborn\stage-cee-loose\clienteffect -Target "D:\SWG All Tools Working\swg\current\data\sku.0\sys.client\compiled\game\clienteffect"

## Remaining item-3 seeds

SwgConversationEditor (failed save returns TRUE + clears modified flag -
Doc.cpp ~1118-1138), NpcEditor (SaveDialog defaults point INTO the SOE
reference tree + silent template-writer stubs), QuestEditor (Ctrl+S writes
opened path, no prompt), TerrainEditor (Construction Layers tree cannot
scroll; 3D View now works but the scroll cut remains).

# ===== SESSION 2026-08-29 (cont. 2): SwgConversationEditor pass DONE + exewin32 dialogs killed =====

Fourth item-3 editor complete. Kenny verified load -> edit -> resave ->
reload round trip in-app. Committed.

## SwgConversationEditor fixes (SwgConversationEditorDoc.cpp)

* **The dishonest save (the seed).** OnSaveDocument's catch fell through to
  SetModifiedFlag(false) + return TRUE - a failed save told MFC it
  succeeded: no dirty *, no prompt on close, work silently discarded. Both
  failure branches now return FALSE and keep the flag.
* **Both catch blocks were DEAD CODE since 2004.** OnOpenDocument AND
  OnSaveDocument set FatalSetThrowExceptions(false) BEFORE their try blocks
  (should be true; the trailing reset to false exists in both). A FATAL
  during load/save never threw - it crashed the app; the "Error loading"/
  "Error saving" boxes could never fire. Fixed: true before, false after,
  including on every early return.
* **save() returning false (read-only file, bad path) was silent** -
  Conversation::save ends in iff.write(), and the FALSE return produced no
  message at all. Now: "Could not write the file. Is it read-only?" box.
* **A failed load presented as a good document** - the open catch fell
  through to onOpenDefaultViews + return TRUE on a partially-loaded doc.
  Now aborts the open.
* **Pre-compile auto-save was fire-and-forget** - a failed save let the
  compile run against stale on-disk state. Now aborts the compile.

## exewin32 startup dialog REMOVED from all three MFC tools

The "X is not running from <branch>\exe\win32. You may be running an older
version." box was one copy-pasted block (strip slashes from cwd, look for
substring "exewin32") in SwgConversationEditor, SwgSpaceQuestEditor and
SwgSpaceZoneEditor. Our x64\Release cwd can never contain it -> guaranteed
useless click every launch. Removed from all three; all three rebuilt and
ConversationEditor now starts with ZERO dialogs.

CAREFUL if this is ever revisited: in the two space editors the removed
block DECLARED the `char buffer[1024]` cwd that the SECOND dialog (the
branch-mismatch check right below it) still reads - the declaration was
re-added inside that check's scope. That second "running out of the
'qt-tools-worktree' branch" box still fires in both space editors; it is
the structural cfg-path comparison documented 08-23. Kenny has been offered
its removal too - not done yet.

Test artifact: C:\save-test\swgcon-new.cnv (the 08-28 sweep's round-trip
file) is the handy .cnv for future ConversationEditor testing - the SOE
.cnv sources never shipped.

## Remaining item-3 seeds

NpcEditor (SaveDialog defaults point INTO the SOE reference tree + silent
template-writer stubs), QuestEditor (Ctrl+S writes opened path, no prompt),
TerrainEditor (Construction Layers tree cannot scroll).

# ===== SESSION 2026-08-29 (cont. 3): QuestEditor pass DONE =====

Fifth item-3 editor complete. Kenny verified all three scenarios in-app,
plus re-confirmed the CRC button (BuildQuestCrcStringTables.ps1) works on
the fresh build.

## QuestEditor fixes (QuestEditor.cpp/.h)

* **Ctrl+S in-place overwrite now confirms - ONCE per file.** The seed:
  plain Save wrote straight back to the opened path (usually inside the SOE
  reference tree) AND fanned out exportDataTables/compile/check beside it.
  First plain Save of an opened file now shows Save In Place / Save As... /
  Cancel with SAVE AS as the Enter default, so habitual Ctrl+S+Enter routes
  to a dialog instead of clobbering shared data. Confirming (or using Save
  As) sets m_confirmedSaveToOpenedPath and later saves are silent. saveAs()
  sets the flag BEFORE calling save() - do not remove that line or Save As
  re-prompts.
* **Close prompt can now save.** Was "Are you sure you want to close?"
  Yes/No - discarding was the only affirmative. Now Save / Discard / Cancel
  (default Save); a cancelled/failed save aborts the close (m_dirty
  re-checked after save() - save() only clears it on a successful write).

Checked and intentionally left: saveQuest failure already shows a critical
box; Save As already appends .qst + confirms overwrite; writability
pre-check already present; Export/Compile/Check gate on "save first"
rather than auto-saving (so they never hit the new prompt).

Reminder trap (still true): the title-bar build date is a stale __DATE__
banner - check the exe mtime, not the title.

## Remaining item-3 seeds

NpcEditor (SaveDialog defaults point INTO the SOE reference tree + silent
template-writer stubs), TerrainEditor (Construction Layers tree cannot
scroll).

# ===== SESSION 2026-08-29 (cont. 4): NpcEditor pass DONE - x64 npos bug was the REAL clobber mechanism =====

Sixth item-3 editor complete. Kenny-verified: in-place confirm fires, Save As
redirects cleanly, and the saved .tpf files are faithful (one rewritten
cross-reference line, everything else preserved).

## THE BIG FIND - copyUpdatedFile's x64 npos truncation

MainWindow.cpp copyUpdatedFile compared
  i->find(key) != static_cast<unsigned>(std::string::npos)
Fine on win32. On x64, find() returns 64-bit npos but the cast truncates the
right side to 0xFFFFFFFF - never equal - so EVERY line "matched" and every
save through this path replaced the ENTIRE file with N copies of the
cross-reference line (N = source line count). Kenny's saves produced 12/19,
12/21-line repeat files from PRISTINE dsrc sources (dressed_mugger verified
clean, dated 08-22).

**This retro-corrects the 08-28 diagnosis**: the beginner_brawler dsrc
clobber was blamed on "appended stub cross-reference lines" from unreadable
patch sources. The real mechanism was this npos bug mangling every
copyUpdatedFile save. The 08-28 reconstruction of the two files remains
correct; the explanation in that section is superseded.

Found by instrumentation, not theory (three wrong theories preceded it:
corrupted sources, ObjectTemplateWriter, QFileInfo staleness). Temporary
PROBE WARNINGs in the save path named the branch + source; the source being
pristine while output repeated pinned it inside copyUpdatedFile in one
glance. Probes stripped after. Swept every tool source for one-sided npos
truncation compares - this was the only instance. (Two-sided casts like
static_cast<int>(pos) == static_cast<int>(npos) truncate consistently and
are safe.)

## Other NpcEditor fixes (same commit)

* One-time in-place-overwrite confirm on plain Save (lists all three target
  files; Save In Place / Save As... / Cancel, Enter = Save As) - the
  QuestEditor pattern; m_confirmedSaveToOpenedPath, set by Save As too.
* All three savers return bool; m_dirty only clears when ALL succeed (both
  save paths used to clear it unconditionally, even on total failure).
* Every silent failure branch now shows a message box: missing template
  source (the never-shipped text/templates/base_humanoid.txt),
  ObjectTemplateWriter failures (was IGNORE_RETURN + DEBUG_WARNING printing
  the FILE* instead of the name - now WARNING with the right args),
  copyUpdatedFile failures.
* copyUpdatedFile preserves the replaced line's leading whitespace and
  trailing newline (it used to emit the bare line, gluing it to the next).

## Environment trap that bit this session: setx vs running terminals

MIFF_CPP is setx'd (registry has it) but this terminal session PREDATES the
setx, so every process launched from it - including editors, and Miff
spawned by NpcEditor's Compile - lacked it. Symptom: Compile button ->
Console window "ERROR: Possible problems running the GNU C Preprocessor /
'cpp' is not recognized". Fix per launch: read it from
HKCU\Environment and set $env:MIFF_CPP before Start-Process. A fresh
terminal (post-reboot or newly opened) inherits it globally.

## Machine state

C:\save-test\papercut-pass\ cleaned of the corrupt test outputs; the good
verification set (client/shared/server-save-3.*) kept. SOE tree took ZERO
writes from all NpcEditor testing (audited) - the confirm+redirect flow
works. QuestEditor litter from earlier testing still in the SOE tree
(quest-resave2.* - 5 files incl. two 0-byte compiled iffs; the 0-byte iffs
suggest the in-app DataTableTool compile failed silently in that run -
UNINVESTIGATED, worth a look when next in QuestEditor).

## Remaining item-3 seeds

TerrainEditor only: Construction Layers tree cannot scroll (3D View works
since 08-27).

# ===== SESSION 2026-08-29 (cont. 5): TerrainEditor scroll FIXED - USABILITY PASS COMPLETE (7/7) =====

The last seeded editor. Kenny-verified: Construction Layers tree scrolls
(wheel/drag/keyboard), checkbox states correct.

## The Construction Layers scroll defect - actual cause

NOT input routing, NOT clipping, NOT TVS_CHECKBOXES timing (all tested and
eliminated - the checkbox style moved to PreCreateWindow anyway, which made
the scrollbar DRAW but not work). Live probing of the running control found:

* Geometry perfect: tree 438x372 client, 1195 items @ 18px, WS_VSCROLL set,
  scrollbar present.
* Scroll state STALE: GetScrollInfo range 0..30 (= the ~33 collapsed roots
  BEFORE expandAll; the "0..31 range" in the 08-28 notes was this) with
  page=20 - comctl never recalculated after the bulk populate + expandAll.
* WM_SETREDRAW(TRUE) sent to the live control instantly revived everything -
  comctl's handler forces a full scrollbar recalculation.
* A message-map probe proved NO WM_SETREDRAW(FALSE) is ever sent - nothing
  freezes the control; its scroll state just never updates after bulk
  expansion on the x64 build.

Fix: LayerView::forceScrollRecalculation() (WM_SETREDRAW TRUE + Invalidate)
called after both bulk paths - OnInitialUpdate's populate+expandAll and
OnInsertExpandall. TVS_CHECKBOXES stays in PreCreateWindow (the docs' timing
warning about initial check states does not apply - every item's state is
explicitly SetCheck'd after populate; Kenny confirmed states correct).

Diagnosis method worth reusing: probe the LIVE control with SendMessage from
PowerShell (TVM_GETNEXTITEM/TVGN_FIRSTVISIBLE before/after WM_VSCROLL) -
three theories died in minutes without a single rebuild.

# ===== USABILITY PASS (TODO ITEM 3) COMPLETE - ALL 7 EDITORS =====

LightningEditor, SwooshEditor, ClientEffectEditor, SwgConversationEditor,
QuestEditor, NpcEditor, TerrainEditor - every seeded paper cut fixed and
Kenny-verified in-app. TODO item 3 marked DONE.

Next in the productization TODO: item 4 (not-in-TREs inventory + installer)
or item 6 (SWG-Toolkit endgame). Item 5's deferred CLI tools list also
remains. Loose end parked: QuestEditor's in-app compile produced two 0-byte
iffs in one run (17:11 on 08-29, litter since removed) - DataTableTool step
failed silently once; uninvestigated.

# ===== SESSION 2026-08-30: NOT-IN-TREs INVENTORY DONE (TODO item 4, step 1) =====

Recovered clean from the power cut (previous session had committed+pushed
everything; nothing was lost). This session built the census.

## Deliverables

* scripts/not_in_tres_inventory.py - indexes all 209 v3.0 TREs (trelist.py
  now reads BOTH v0005 and v0006 - the census is exhaustive, unlike every
  pre-guard sweep) and walks the six SOE data mount roots + dsrc. ~1 min.
* .planning/inventory/PAYLOAD-MANIFEST.md - THE analysis doc. Read it first.
* .planning/inventory/summary.txt (committed) + data-manifest.csv /
  dsrc-manifest.csv (26+8 MB, gitignored - regenerate by running the script).

## Headline findings

* 121,024 data files (2,617 MB) are in NO TRE; dsrc adds 85,431 (258 MB).
* Payload has TWO classes: (A) not-in-TRE files, (B) cfg-referenced dirs the
  tools open via the FILESYSTEM (browse defaults, write targets, dsrc) which
  must ship loose even where TRE-duplicated. Class B table with per-tool cfg
  keys is in the manifest doc.
* .lmg correction: only 1,819 of the 4,882 wearable .lmg are not-in-TRE, but
  all 4,882 ship anyway (1.1 MB) - NpcEditor enumerates the dir on disk.
  Validated: census's appearance/mesh .lmg count == 4,882 exactly.
* Quest content is 100% loose - zero .qst in any TRE (1,300 files).
* SHADOW TRAP quantified: 12,106 loose files share a TRE name with NO
  size-matching TRE copy (2016 dev data vs v3.0). Mounting broad loose roots
  shadows the TREs at ANY priority (TreeFile.cpp:345 - searchPaths beat
  searchTrees per priority) = the walking-avatar bug generalized. Installer
  rule: Class B dirs are for filesystem access + SCOPED mounts only.
  QuestEditor.cfg searchPath10/11 currently mount whole compiled/game roots -
  works today, flagged for scoping during cfg parameterization.
* Trimming: sample/video/music/voice ~650 MB likely droppable; texture/
  1,042 MB not-in-TRE is the open question (needs a reference-closure walk
  of .apt/.sat/.msh/.sht chains to split live from dead dev data).

## Next for item 4

1. Decide ship-everything (~3 GB) vs closure-trimmed payload (needs the
   reference-closure pass over appearance chains).
2. Cfg parameterization: three roots (TRE dir / loose root / output root),
   documented at the end of PAYLOAD-MANIFEST.md. Keep legacy no-sku keys.
3. Installer skeleton: payload + exes + exe/win32 store + the out-of-repo
   pieces (stage-B-override ui file, stage-cee-loose junction - recreate
   lines in the manifest doc).

## 2026-08-30 (cont.): dsrc IS SWG-Source/dsrc.git - payload shrinks, reconstruction validated

Kenny asked whether swg-main ships the dsrc set. It does, and better:

* Galaxies-Reborn/swg-main AND upstream SWG-Source/swg-main both carry dsrc
  as a submodule of https://github.com/SWG-Source/dsrc.git pinned at the
  SAME sha c7294da3e (2020-09-18). Local swg-main never ran submodule init
  (dsrc/ dir is empty).
* The SOE tree's dsrc/ IS a clone of that repo at a05279872 (2020-06-10),
  21 commits behind the pin, 0 ahead. Installer: clone instead of shipping
  258 MB. Choice pending: stay at a05279872 (validated state) vs take the
  21 commits + re-smoke.
* git status of that clone = the definitive dsrc write audit. Currently
  dirty: exactly our 3 known writes (2 reconstructed .tpf + regenerated
  quest_crc_string_table.tab). Nothing unexpected.
* THE 08-28 RECONSTRUCTION IS VALIDATED: git diff shows the two
  beginner_brawler .tpf files content-identical to the repo; only delta is
  a trailing newline we added that the originals lacked. Ground truth, not
  sibling inference.
* Lead for more payload cuts: SWG-Source/serverdata submodule (~1 GB,
  active 2026) ships compiled server data (datatables/quest/misc/...).
  Unverified whether it maps onto our sys.server/compiled/game Class B dirs.

Details in .planning/inventory/PAYLOAD-MANIFEST.md (new dsrc section).

## 2026-08-30 (cont. 2): serverdata comparison RUN - it is the loose CLIENT data set

SWG-Source/serverdata (~1 GB repo) is misnamed: 125,417 of its 125,515
files are sys.client/compiled/game names, 99.9% size-identical vs the SOE
tree. Listing pulled via GitHub tree API (blobless clone route FAILED -
promisor lazy-fetch pathology, 10-min timeout; per-directory tree API calls
work, appearance/ needs one more level of descent past the truncation).
PS 5.1 trap: embedded double quotes in gh --jq args get mangled - fetch raw
JSON and parse in python instead.

Coverage of the client not-in-TRE payload: appearance 23,983/23,984
(685 MB, incl. ALL wearable .lmg), quest 1,300/1,300, client datatables
4,079/4,079, shader/string/terrain/palette/footprint ~all. NOT covered:
texture (1,042 MB - closure question stands), media dirs (651 MB), client
object/ui/clientdata/clienteffect/sound (~26 MB), nearly all of
sys.server/compiled/game (123 MB - build artifacts of dsrc) and most
sys.shared leftovers. 41 size mismatches among covered files, untriaged.
Version note: compared vs master 3ee03ed3; swg-main pins df41a07ed.

NET: installer payload = 2 git clones (dsrc, serverdata) + ~1.9 GB worst
case shipped, ~200 MB if texture/media resolve droppable. Details + table
in PAYLOAD-MANIFEST.md. serverdata full listing in session scratchpad
(serverdata-tree.txt) - regenerable from the API.

## 2026-08-30 (cont. 3): texture facts + rebuild-at-install decision

* Textures: 20,961 of the loose 29,845 ARE in the v3.0 TREs; the 8,884
  loose-only (1,042 MB; 8,512 NGE item/vehicle .dds at texture/ root + 275
  loading + 97 font) are NOT derivable - .dds is the compiled form and the
  source art tree was never distributed (dsrc: 32 palette .tga only;
  serverdata: no texture dir). Ship or closure-trim; wrong trims degrade
  SILENTLY to default textures.
* Kenny decided: REBUILD the compiled server/shared data at install from
  the dsrc clone (TemplateCompiler for 63k .tpf, DataTableTool for 16k
  .tab, CRC scripts for misc/, javac for script/ - optional, GodClient
  only). Drops ~150 MB more AND fixes the latent 2016-bakes-vs-2020-dsrc
  inconsistency in the SOE tree. Expect v0009->v0010 schema deltas on
  recompile (fine); acceptance = smoke the editors against a rebuilt set.
  Object-template CRC table generation still TODO (generic mode exists).
Details in PAYLOAD-MANIFEST.md (two new sections).

## 2026-08-30 (cont. 4): INSTALLER ARCHITECTURE SET - single SOE-shaped root

Kenny set the direction: installer pulls from git repos (dsrc, serverdata,
a NEW missing-bits repo), one top-level directory holding apps + configs +
data (loose or TRE per what makes sense), tools work against that tree.
Full design captured in .planning/inventory/INSTALLER-DESIGN.md.

Key insight recorded there: make the root SOE-SHAPED (swg/current/
{data,dsrc,exe}, apps in exe/win32). Then the hardcoded ../../exe/win32
config reads resolve to the exe dir itself, the space editors' branch-
mismatch check passes by construction, and every cfg path can be RELATIVE
-> final cfgs are machine-independent and tracked; the installer templates
NOTHING. stage-B-override and the stage-cee-loose junction disappear into
the tree. Texture payload (if shipped) packs into a tools_texture.tre via
TreeFileBuilder; dsrc + Class B dirs + rebuilt compiled data stay loose.
Open: base-TRE acquisition, texture trim, media drop, repo pins, trial
compile timing.

## 2026-08-30 (cont. 5): media verdict - audio ships, video droppable

Kenny suspected .snd files reference sample/player_music/voice - CONFIRMED
by parsing all 1,354 loose-only .snd: 1,293 of 1,497 unique refs point at
LOOSE-ONLY media (1,207 sample / 46 voice / 40 music). Loose-only sound +
loose-only audio are one unit -> the missing-bits repo ships 490 MB of
audio (sample+music+player_music+voice). TREs carry their own large media
set (4,246 sample etc.) which TreeFile already serves - extract loose only
if a browse dir turns out needed (check SoundEditor defaults). video/
(162 MB) referenced by nothing - still a drop candidate. 6 refs are dead
c:/swg dev paths. Details in PAYLOAD-MANIFEST.md media section. This also
validates the string-scan closure method - same approach will settle the
1 GB texture question.

## 2026-08-30 (cont. 6): texture closure walk RUN - ship all 1,042 MB

scripts/texture_closure.py scanned the 255k shippable loose files for .dds
refs: 88% of the 8,884 loose-only textures are provably referenced (6,458
full-path + 1,394 basename + 89 font). The 943 "unreferenced" (122 MB) are
loading screens / ui_ / companion-map suffixes - exactly what a loose-only
corpus cannot see (TRE-resident UI+datatables refs, code-composed names).
DECISION: ship all. Dead-dev-data theory disproven. texture-closure.csv
committed. Payload picture is now COMPLETE - see PAYLOAD-MANIFEST.md:
missing-bits repo = 1,042 MB texture + 490 MB audio + ~26 MB leftovers +
small extras; video dropped; dsrc+serverdata cloned; server/shared
compiled REBUILT at install. Next: trial full-tree compile (timing), then
cfg rework against a prototype SOE-shaped root (INSTALLER-DESIGN.md).

## 2026-08-31: missing-bits repo decision - separate repo, submodule pin

Kenny proposed storing the payload in client-tools itself for corpus
tracking. Settled on: separate payload repo + git submodule in
client-tools (the swg-main pattern). Tracking is better (payload history =
pure data changelog, pin bumps visible here), code clones stay light,
installer clones --depth 1 at the pinned sha. Recorded in
INSTALLER-DESIGN.md open question 5 (now DECIDED).

## 2026-08-31 (cont.): install UX + launcher proposal recorded

Kenny asked what drives installation (download, run, coffee, done) and
proposed an editor home-page app. Proposal recorded in INSTALLER-DESIGN.md:
two-stage install - Inno Setup bootstrap (apps + CLI + launcher + MinGit)
then the LAUNCHER ITSELF runs the first-run wizard (locate TREs, pinned
clones, payload layout, rebuild, shader warm, smoke scorecard finish).
Idempotent steps + state file = power-cut-resumable; same wizard re-runs
as Repair/Update (update channel = git pull + rebuild). Launcher = C#/.NET
8 single-exe tile grid launching editors with correct cwd/env, per-editor
sample-flow guides rendered from repo markdown (seeds: TOOLS-GUIDE Part
2.5, handoff per-editor knowledge, logs/_shots, known sample files).

## 2026-08-31 (cont. 2): TRE acquisition options + stack answer + hash manifest

Kenny raised: TRE duplication option, direct-from-SWGSource download
(his preference), and why C# vs Node/React. Recorded in INSTALLER-DESIGN:
* Wizard offers copy (default - version stability vs launcher patches) /
  point (junction, zero disk) / download from SWGSource (OPEN: need their
  distribution channel + community coordination, ~8 GB/install). Note:
  tools have NO write path into TREs (TreeFile mounts read-only; all
  editor writes are loose files) - duplication is about stability, not
  clobber.
* ALL acquisition paths verify against tre-hash-manifest.csv - NEW,
  committed: name/size/sha256 of all 209 v3.0 TREs (7.8 GB, generated
  from the known-good local set).
* Stack: C# shell stays (OS-integration-heavy job, self-contained single
  exe, zero runtime install); if React UI wanted, host it in WebView2 via
  a C# bridge rather than shipping Electron. Non-admin runtime inventory
  in the doc (MinGit bundled, PS 5.1 in-box, WebView2 per-user, no .NET
  install, javac off by default).

## 2026-08-31 (cont. 3): TRE download research DONE - GitHub Releases hosts it

The SWGSource client is distributed via GitHub Releases
(SWG-Source/releases, tag swgsourceclientv3.0, 4x split 7z ~7.3 GB,
GitHub CDN = no community bandwidth concern) + incremental updates via
the SWG-Source/client-assets git repo (UpdateSwgClient.bat applies it).
Contacts for the courtesy heads-up: SWG Source Discord
(discord.com/invite/Va8e6n8), org members AconiteX (docs author),
BubbaJoeX, HeronAlexandria; client-assets committers Heron, Russ
Andrews, Talisa Knight. CAVEAT: regenerate tre-hash-manifest.csv against
a canonical fresh download (local install may carry post-3.0 updates -
_cfg_backup_pre_p19_control exists). Bonus finds: full server VM release,
"Godclient v1.0 by Erusman" package (win32 prior art), and SWG-Source has
its OWN client-tools repo (2026-05, uninspected). Stack: C# confirmed by
Kenny. All in INSTALLER-DESIGN.md option (c).

## 2026-08-31 (cont. 4): hash-at-install, update checker, LINEAGE confirmed

* Hash strategy revised per Kenny: baseline generated AT INSTALL from the
  acquired set (updates from SWGSource never break installs); tracked
  manifest demoted to advisory version identification. Updater compares
  local baseline to detect TRE drift.
* Check-for-updates UI spec'd: per-component local-vs-available list
  (client TREs / dsrc / serverdata / missing-bits / the tools themselves),
  user selects, wizard steps re-run, baseline refreshed.
* LINEAGE: Galaxies-Reborn/client-tools IS a fork of
  SWG-Source/client-tools; upstream PR #21 (swgsais, 2026-08-19) is the
  x64/DX11+SDL3 port this work builds on - upstream is ACTIVE, our fixes
  and the installer have an upstream path. PR #10 (TyroneSWG 2021) = god
  client additions, prior art.
* Erusman Godclient v1.0 package (4.15 GB) downloading in background for
  inspection - docs/knowledge mining for our launcher guides.

## 2026-08-31 (cont. 5): Erusman Godclient v1.0 package MINED

Downloaded (4.15 GB, 3-part 7z wrapping a 2018 rar), listed all 366,674
files, extracted the interesting 15. Findings:

* IT IS OUR DESIGN, 2018 EDITION: an SOE-shaped swg/{data,dsrc,exe} tree,
  god client in exe/win32, cfgs using RELATIVE ../../data searchPaths -
  independent validation of the single-root relative-cfg architecture.
  All-loose (284k files, 7.4 GB, publish 54 vintage, NO TREs) - proves
  all-loose works; our TRE+scoped-loose is better on size.
* His client.cfg carries 0fd345d9=true - independent confirmation of the
  obfuscated CSR key find (08-29).
* World-builder cfg keys worth adopting into SwgGodClient.cfg:
  skipIntro/skipSplash, disableWorldSnapshot=false (world building),
  autoConnectToLoginServer + loginClientID + launcherAvatarName
  (auto-login), allowTargetAnything=1, drawNetworkIds=1, debugExamine=1,
  noDataTimeout=900000, freeChaseCameraMaximumZoom=8, commented
  groundScene planet list.
* His [GodClient] section is BROKEN - C++ getKeyString call syntax pasted
  as cfg lines, plus keys (connectToPerforce, loadServerObjects) that do
  not exist in the engine source (grepped). Nothing to copy; our SOE-cfg
  section is the correct one.
* NO documentation in the package. But 10 screenshots of real god-tool
  workflows (selection/spawn/ObjVars/script lists) - usable as launcher
  guide references.
* Data vintage older than ours (2018 pub54 vs our 2016+2020 tree) - not a
  data source.

Kept: 3 cfgs at .planning/inventory/erusman-godclient/. The rar stays in
the session scratchpad (orphaned on session end - re-download from
SWG-Source/releases tag Godclientv1.0byErusman if ever needed again).

## 2026-08-31 (cont. 6): upstream compared; Erusman useful parts ADOPTED

* UPSTREAM: SWG-Source/client-tools master tip (PR #18 merge, 2026-05) IS
  our fork point - 0 commits upstream we lack, we are 256 ahead (+7,849
  files: deps/ x64 tree, src/external; 898 modified). Nothing to pull.
  Their open PR #20 (droid-commands toolbar fix, bcalabro) = cherry-pick
  candidate for later.
* CORRECTION to cont. 5: connectToPerforce and loadServerObjects ARE real
  keys - ConfigGodClient.cpp:87-88 (KEY_BOOL, both default TRUE) - my
  "nonexistent" claim came from grepping src\engine only; god client keys
  live in src\game. Only Erusman's comma-syntax path lines were broken.
  debugClipboardExamine remains slash-command-only (not a cfg key).
* ADOPTED into Release\SwgGodClient.cfg (tracked; every key verified in
  source first): skipIntro/skipSplash, freeChaseCameraMaximumZoom=8
  (stock 1.0!), new [ClientUserInterface] allowTargetAnything=1 +
  debugExamine=1 (+commented drawNetworkIds), new [SharedNetwork]
  noDataTimeout=900000 (stock 46 s - idle god sessions can trip it),
  commented disableWorldSnapshot=false (world building) + auto-login trio,
  explicit [GodClient] connectToPerforce=false. NOT yet live-tested (needs
  the server up) - smoke on the next god-client evening.
* Erusman's 10 god-tool workflow screenshots copied to
  .planning/inventory/erusman-godclient/screenshots/ (12.7 MB) as launcher
  guide reference material.

## 2026-08-31 (cont. 7): Erusman-vs-SOE-tree compare + missing-bits generator

* COMPARE (Kenny asked): 283,980 of Erusman's 284,010 data files match our
  SOE tree by exact name - near-identical sibling trees. 39,109 size
  mismatches = 2018-vs-2016 vintage drift (mostly object templates); ours
  stays canonical. He has THIRTY files we lack, 26 of which are the
  complete sys.shared/terrain space-zone sources (space_*.mif +
  makedata.btm) - THE dir our tree is missing (why sharedTerrainDirectory
  was omitted from SwgGodClient.cfg on 08-29) - plus 2 halloween buildout
  datatables, stella_admin.iff, one .lod. All 30 extracted from the rar to
  .planning/inventory/erusman-extras/ (110 KB, committed). None are in any
  TRE. Once the payload ships them, sharedTerrainDirectory can be wired.
* GENERATOR: scripts/generate_missing_bits.py builds the payload repo at
  D:/Code/Galaxies-Reborn/tools-payload (data/sku.0 layout + exe/win32
  extras + payload-manifest.csv + README, git init + commit). Rules in the
  docstring; serverdata coverage requires name AND size match (the 41
  name-only shadows ship). serverdata-tree.txt now committed to
  .planning/inventory/ for reproducibility. Server script/ (javac off by
  default) and misc/ (object-CRC generation unproven) SHIP; server+shared
  object/ + datatables/ + shared misc/ are rebuild-at-install.

## 2026-08-31 (cont. 8): PAYLOAD REPO BUILT - 29,681 files / 1,615 MB

D:/Code/Galaxies-Reborn/tools-payload generated, git-committed locally
(main, d54c64e2; pack 1.01 GiB - well under GitHub push limits). Split:
client 23,970/1,564 MB, server script 5,658/50 MB, erusman 30, shared
residue 18, exe extras 3. NOT pushed - needs the org repo created
(Kenny). Refinement from the run: server misc/ selected zero files (all
14 are TRE-resident; Class B only for filesystem reads) -> new rule: any
Class B file that exists in a TRE is MATERIALIZED from TREs at install
(TreeFileExtractor), never shipped. Recorded in PAYLOAD-MANIFEST.md.

## 2026-08-31 (cont. 9): sharedTerrainDirectory wired - with a correction

Source dig first: the key's SOLE consumer is ActionsEdit.cpp:1285, the
browse default for the "Select terrain layer" QFileDialog (poi*.lay,
theater/POI creation). Compiled default ../../data/sku.0/sys.shared/built/
game/terrain. CORRECTION: the Erusman space_*.mif recoveries are NOT what
this key wants (they are SpaceZoneEditor space terrain sources - still
good payload, different consumer). The wanted poi*.lay files (3: poi_
large/medium/small among 46 .lay) live in the CLIENT compiled terrain dir
(usual built->compiled remap), present in TREs AND loose. Wired to
"D:/SWG All Tools Working/.../sys.client/compiled/game/terrain" (browse-
only dialog - no SOE-tree write risk). NOT live-tested (needs server);
verify on the next god evening via Edit menu -> the terrain-layer picker
opening in a dir showing poi_*.lay.

# ===== SESSION 2026-09-01: payload repo README + push to GitHub =====

* Org repo created by Kenny: https://github.com/Galaxies-Reborn/legacy-tools-payload
  (note the name: legacy-tools-payload, local dir is still tools-payload).
* README.md in the payload repo expanded (provenance, layout, contents
  table, the two selection rules) and committed (91864c3c). The generator
  used to clobber README on every run - generate_missing_bits.py now seeds
  it only when absent (worktree commit d23e086d3, NOT yet pushed).
* First push rejected: GitHub seeded the repo with a 2-line stub README
  (f5309e23). Merged with --allow-unrelated-histories -X ours (cf53acca),
  local README kept. Push of the ~1 GB pack running in background at time
  of writing - VERIFY it completed (git -C D:/Code/Galaxies-Reborn/tools-payload
  status -sb should show main...origin/main with no ahead marker).

## 2026-09-01 (cont.): submodule wired, authoring clone retired

* legacy-tools-payload added as client-tools submodule at tools-payload/
  (pin cf53acca, commit d33a14abe). Seeded from the local clone to skip
  the 1 GB re-download; .gitmodules carries the GitHub URL.
* The authoring clone D:/Code/Galaxies-Reborn/tools-payload is DELETED
  (verified clean, no stashes, nothing unpushed, tip == origin/main ==
  submodule tip). The submodule copy is the only local checkout now.
  Payload edits happen IN the submodule: commit+push there, then commit
  the pin bump in client-tools.
* generate_missing_bits.py default OUT repointed from the deleted path to
  <repo-root>/tools-payload. Earlier path mentions in this file are
  historical.

# ===== SESSION 2026-09-01 (cont.): PROTOTYPE SOE-SHAPED ROOT BUILT ON C: =====

C:\swg\current\ built by hand following INSTALLER-DESIGN.md — this is the
"prototype SOE-shaped root" milestone AND a rehearsal of the install flow.

## What was laid, in order

1. Skeleton: C:\swg\current\{data,dsrc,exe\win32,tre} + C:\swg\repos\.
2. tre\: 209 TREs (7.8 GB, 8 s NVMe copy) + the 4 sku*_client.toc.
3. Clones FROM GITHUB (honest install test, all three worked):
   dsrc -> C:\swg\current\dsrc @ a05279872 (validated pin, NOT the swg-main
   +21 pin — one variable at a time). NOTE: clean clone lacks our 3 local
   dsrc writes; repo content already matches the 2 reconstructed .tpf, only
   the regenerated quest_crc_string_table.tab differs. serverdata + 
   legacy-tools-payload (--depth 1) -> C:\swg\repos\.
4. data\override\ = stage-B-override copy (422 files/29 MB — the asm2hlsl
   override corpus; NOT in any repo yet, FLAGGED below).
   data\override-cee\clienteffect = junction -> ..\data\sku.0\...\clienteffect
   (replaces the stage-cee-loose junction).
5. Payload laid: repo data\ -> current\data (29,676 files), repo exe\ ->
   current\exe. THEN serverdata -> data\sku.0\sys.client\compiled\game with
   robocopy /XC /XN /XO (no overwrite => payload wins conflicts): 125,474
   copied, 43 skipped = payload-priority files, as designed.
6. exe\win32\: Release *.exe *.dll *.cfg *.ini *.xml *.ps1 (72 files,
   381 MB — no pdb/lib) + the exe\win32 store (10 files). The 2 .ini
   collisions are identical files; SwgDraftSchematicEditor.cfg MERGED (see
   below).

## Cfg relativization (scratchpad relativize_cfgs.py; rules here)

All 18 cfg/ini/xml rewritten, relative to cwd=exe\win32:
  D:/Code/SWGSource Client v3.0/           -> ../../tre/
  D:/Code/Galaxies-Reborn/stage-B-override -> ../../data/override
  D:/Code/Galaxies-Reborn/stage-cee-loose  -> ../../data/override-cee
  D:/SWG All Tools Working/swg/current/    -> ../../
Survivors are comments only. QuestEditorConfig.xml has no paths at all.

## SwgDraftSchematicEditor.cfg — the two copies become ONE file, and that WORKS

In the SOE shape, cwd cfg and ../../exe/win32 cfg are the same path. Merged
file = the Release engine copy (TreeFile keys + [SwgDraftSchematicEditor]
section) with the tool keys UNQUOTED: Configuration::loadCfg reads values
verbatim (quotes would corrupt the path) but skips sections/unknown keys, so
one file serves both parsers. Relative paths have no spaces => ConfigFile no
longer needs the quotes either. The quoting trap from 08-23 dissolves.

## First smoke from the C: root

ParticleEditor: verdict `w` FIRST TRY. warning.log matches the D: baseline
(DEPRECATED_SKILLS, nebula table) + 2 missing normal-map textures
(xwing_main_n_sm.dds, dewback_saddle_n.dds) + 1 snd — triage later, likely
Class-B materialization gaps. Full 16-editor smoke running at time of writing;
results -> C:\swg\current\exe\win32\_smoke-results.csv.

## FLAGGED: stage-B-override has no repo home

422 files / 29 MB of port-generated overrides (shader programs, skeletons,
datatables, ui incl. ui_root_npceditor.ui, textures) live ONLY at
D:\Code\Galaxies-Reborn\stage-B-override + this C: copy. Not in client-tools,
not in the payload repo. It must land in one of them (payload repo fits:
it is data, and the installer already lays that repo) — decide + commit.

## Deferred (known, deliberate)

Rebuild-at-install of server/shared compiled data (trial-compile milestone),
Class B TRE-materialization, QuestEditor searchPath10/11 scoping (broad
mounts still mounted, same risk profile as the D: setup), shader warm.

## C: ROOT FINAL SMOKE (2026-09-01): 15 w + 1 known-? — best scorecard ever

Full run, uniform cfgs, rebuilt space editors: every tool `w` except
UIBuilder's structural `?` (its main window legitimately IS a #32770 —
confirmed working on D: by screenshot; unchanged behavior). ZERO dialogs
anywhere — better than the D: baseline, which still had the cosmetic branch
boxes on ConvEditor/SpaceQuest/SpaceZone and SpaceQuest's frame blocked
behind them.

What it took beyond the initial lay (all committed, 9abd0241a):

1. Server misc/ + server/shared compiled data copied from the SOE tree
   (78 MB new files after skips) — stand-in for the deferred
   rebuild-at-install; ShipComponentEditor and SpaceQuest were the
   consumers that proved the need.
2. TREEFILE FINDING: TreeFile::fixUpFileName STRIPS leading ../ segments
   from any name opened through TreeFile, so ../../data-style cfg values
   silently became data/... and matched nothing (absolute paths never hit
   this — why D: worked). Fix: searchPath1="../.." in every tool cfg (the
   root itself; TRE names never start with data/ dsrc/ exe/ tre/, so no
   shadow risk). DO NOT mount broader roots: SearchPath manifest-walks its
   dir recursively — a ../../../.. (= drive root) mount hung startup
   enumerating all of C:\.
3. CODE FIX (SpaceQuest + SpaceZone): the branch-mismatch check now runs
   only for absolute cfg paths — relative paths carry no swg/<branch>/
   segment and resolve under the exe's own root, so extractBranch compared
   garbage. Rebuilt + deployed both. SpaceQuest scores a clean `w` for the
   FIRST TIME EVER (no dialog stack at all).
4. A 4-up cfg form (../../../../swg/current/...) was tried to satisfy
   extractBranch and REVERTED — it forces the drive-root mount from (2).
   Don't retry it.

relativize_cfgs.py (in scripts/) now encodes the full transform: path
rules + root mount insert + tool-parser key unquoting. Idempotent.

## Install-recipe deltas discovered by this rehearsal (feed INSTALLER-DESIGN)

* The materialize-from-TREs step is REQUIRED, not optional (server misc/).
* Until rebuild-at-install exists, server+shared compiled/game must be
  copied from a baked source (SOE tree today).
* The stage-B-override corpus (422 files/29 MB) needs a repo home — only
  copies are D: loose + C:\swg\current\data\override.
* Small triage list from ParticleEditor's C: log: texture/xwing_main_n_sm.dds,
  texture/dewback_saddle_n.dds, sound/cr_angler_vocalize.snd unresolved
  (absent on D: baseline? unverified) — check payload coverage.

# ===== SESSION 2026-09-01 (cont. 2): TRIAL DSRC FULL-TREE COMPILE — DONE =====

The rebuild-at-install milestone. All driven by scripts/rebuild_compiled_data.py
(+ build_object_crc_tables.py); everything below committed (d1a1b1ffc+).

## TIMING ANSWER (the number the installer design wanted)

~10 minutes wall on this machine, 8 workers: 63,427 .tpf in 6.1 min
(TemplateCompiler, 200-file batches) + 15,787 .tab in 3.2 min (DataTableTool,
per-file). CRC tables add seconds.

## FINAL SCORE

* Templates: 63,424/63,428 compiled. The 4 failures are dsrc sources with
  HYPHENS in their names (rare_heavy_crusader_m-xx, rare_pistol_ur-g8,
  lair_*_kai-tok x2) — validator rejects them; upstream data quirk. All 4
  names covered by existing bakes (kai-tok bakes live at lair/structure/*,
  dsrc sources at lair/mawgax/ — relocated dev copies).
* Datatables: 15,788/15,788 real sources compiled (the 16th "failure" was
  dsrc's quest_crc_string_table.tab — CRC OUTPUT, not a source; now excluded).
* CRC tables regenerated from the rebuilt tree: object client 30,239 names /
  server 60,511 (swg-main recipe; server table copied to both compiled/misc
  spots, matching SOE's shipped layout where those two are byte-identical);
  quest table 2,736 entries (the known-good count).

## THE BIG FIX: File::open sharing mode (sharedTemplateDefinition)

_fsopen(..., _SH_DENYRW) on EVERY open incl. reads meant any two concurrent
TemplateCompiler instances failed each other on the shared base .tdf/.tpf
chain ("ERROR file <> line 0: Permission denied" + cascading base-template
failures; 315/318 batches died). Fixed: reads use _SH_DENYWR, writes keep
exclusive. That took the tpf phase from unusable to 6 min at 8 workers.

## DataTableTool include resolution

DataTableTool loads NO cfg (SOE commented tools.cfg out). .tab include refs
(datatables/include/*.iff) resolve via CWD — the driver now runs it with
cwd = the source's own side's DATA compiled/game dir. The 3 movement tables
that failed with "Type with unknown basic type" (a downstream symptom of the
unresolved include) compile clean this way.

## Build-recipe traps (CLI tools, vcxproj-direct)

* Pass -p:SolutionDir=D:\...\src\build\win32\ (trailing slash) — the
  vcxprojs' AdditionalLibraryDirectories use $(SolutionDir)x64\Release;
  without it LNK1181 zlib.lib.
* A FAILED link DELETES the canonical exe in src\build\...\Release.
* archive.vcxproj is broken standalone (missing sharedFoundationTypes
  include) — build with -p:BuildProjectReferences=false against existing
  libs when the full chain trips on it.
* MSB8012 TargetPath-vs-OutputFile warnings are cosmetic; outputs land in
  the canonical Release dir.

## State

C:\swg\current data\sku.0 sys.server+sys.shared compiled/game is now the
DSRC REBUILD (v0010 schema) not the 2016 SOE bakes; pre-rebuild copies at
C:\swg\_baseline\. Acceptance smoke vs rebuilt data running at end of
session — check _smoke-results.csv.

## ACCEPTANCE SMOKE vs REBUILT DATA: PASSED (2026-09-01)

Identical scorecard to the pre-rebuild run — 15 w + UIBuilder's structural ?.
Logs: zero FATALs; the only could-not-open-table lines are the benign
baseline set (space/nebula/tatooine, minigame/mahjong — missing in every
dataset). The editors run on the v0010 dsrc rebuild with no regressions.

REBUILD-AT-INSTALL IS PROVEN END TO END: clone dsrc -> ~10 min compile ->
CRC tables -> working editors. Remaining SOE-tree dependencies in the C:
root: the 4 hyphen-named bakes, the not-yet-materialized TRE Class B
content, server misc/ (materialize-from-TREs step still unimplemented),
and whatever sys.server/sys.shared files are neither dsrc-compiled nor in
the payload (the _baseline diff can enumerate this when wanted).

# ===== SESSION 2026-09-01 (cont. 3): install.ps1 CLEAN-ROOM TEST PASSED =====

C:\swg was DELETED and reinstalled from empty by scripts/install.ps1 (the
manual rehearsal turned into orchestration; state-file resumable). Two
passes: pass 1 ran skeleton->rebuild and failed at quest-CRC; driver fixed;
pass 2 resumed (all earlier steps [skip]) and finished: rebuild residue +
CRC + SMOKE = 15 w + UIBuilder's structural ?. "Install complete."

## Timings (fresh machine estimate)

TREs copy 0.8 min; dsrc clone 0.9; serverdata 2.3; PAYLOAD CLONE 29 MIN
(1 GB pack, cold GitHub CDN - budget for it, or note first-download cost);
lays ~3; rebuild 8-10; smoke ~10. Total ~55 min, dominated by the payload
download.

## Clean-room-only defects found (all fixed in rebuild_compiled_data.py,
commit 3eda3537b) - yesterday's SOE-copy-prepopulated tree masked ALL three:

1. NEITHER compiler creates missing output directories. DataTableTool prints
   "ERROR: The output file is not available for writing" and EXITS 0;
   TemplateCompiler silently skips too. Result: 0/6199 shared datatables,
   half the server ones. Fix: driver pre-creates the full dsrc->data dir
   mirror (293 dirs on pass 2) + treats ERROR-in-stdout as failure.
2. datatables/include/* race their referers under parallel compile (other
   .tab sources READ them at compile time). Fix: include tabs compile
   serially before the pool.
3. install.ps1 quest-CRC step ran before questlist existed (consequence of
   1). Fixed by 1; step order is fine.

## Clean-room final counts

63,424/63,428 tpf (the 4 hyphen sources, unchanged); all real tabs; CRC
object tables client 29,902 / server 60,073 names; quest table 2,654 =
exactly the dsrc questlist set (internally consistent).

## The SOE-tree residue, now QUANTIFIED by absence

vs yesterday's SOE-augmented tree: ~437 object names and 82 questlist
entries fewer. These are 2016 bakes whose dsrc sources were later
renamed/removed (kai-tok pattern). The clean-room tree is dsrc-CONSISTENT
(matches what swg-main servers build) - arguably more correct than the SOE
mix. Nothing in the smoke needs the residue.

## Still outside the script (flagged)

stage-B-override still copies from D:\Code\Galaxies-Reborn\stage-B-override
(no repo home); apps/TREs come from local -AppSource/-TreSource params (the
real installer ships/downloads these); the 4 hyphen bakes are absent from a
clean install (fix belongs upstream in dsrc: rename the sources).

# ===== SESSION END 2026-09-01/03 - CONTEXT CLEAR - START HERE =====

Everything committed and PUSHED (origin/x64-dx11-qt-tools at 5fa69bf72).
Working tree clean. This block is the resume point; the five 2026-09-01
sections above carry the detail.

## What this session delivered, in order

1. legacy-tools-payload pushed to the org + wired as the tools-payload/
   submodule; authoring clone retired (payload edits happen IN the
   submodule now: commit+push there, then pin-bump here).
2. PROTOTYPE SOE-SHAPED ROOT on C: - cfgs relativized, 16/16 smoke,
   TreeFile ../-stripping finding, space-editor branch-check code fix.
3. TRIAL DSRC COMPILE - ~10 min full tree, File::open sharing-mode fix
   (parallel TemplateCompiler), CRC tables generated, acceptance passed.
4. install.ps1 - the whole lay as one state-file-resumable script;
   CLEAN-ROOM TESTED against a deleted C:\swg (3 masked defects found+
   fixed: no output-dir creation, DataTableTool exit-0 ERRORs,
   include-tab race).
5. CLONE-DRIVEN install - smoke ps1s tracked in the exe/win32 store, cfgs
   deploy from the clone's tracked Release copies, repo-relative paths;
   docs/INSTALL.md starts at git clone; wiring validated via a throwaway
   C: clone (deleted after).

## IN FLIGHT: Kenny's user-driven install test

Kenny is about to run the install HIMSELF from docs/INSTALL.md alone
(clone to C:\Code\client-tools, wipe C:\swg, run install.ps1). PURPOSE:
find where the doc/script fail a human driver. When he reports back:
fix the DOC or SCRIPT, not the symptom, and re-verify. Success bar =
15 w + UIBuilder ? and "Install complete." Known first-run cost: the
payload clone hit 29 min cold (may be faster now).

## Open items after that

* stage-B-override repo home (422 files/29 MB, port-generated; only
  copies: D:\Code\Galaxies-Reborn\stage-B-override + C:\swg tree.
  Payload repo is the suggested home; installer step then re-points).
* -AppSource still the D: dev Release (no shipped binaries yet) and
  -TreSource the local client dir (download path = INSTALLER-DESIGN
  option c). These are the next installer milestones.
* 4 hyphen-named dsrc sources fail compile (upstream data fix: rename).
* Functional (beyond-launch) testing of the C: tools; god-client evening
  items from 08-31 still untested (needs server).
* Upstream PR #20 cherry-pick candidate; dsrc pin bump (+21) re-smoke.
