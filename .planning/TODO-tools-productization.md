# TODO — tools productization (Kenny, 2026-08-28)

Started as QuestEditor notes; the scope is all 16 editors. Goal per Kenny:
"basic cleanup and make them usable, not perfection" — then package.

## 1. Port buildQuestCrcStringTables (QuestEditor) — DONE 2026-08-29

Shipped as `src/build/win32/exe/win32/BuildQuestCrcStringTables.ps1` (one
script, folds the walk + buildCrcStringTable.pl together, writes the binary
IFF directly — no perl, no p4, no Miff). ToolProcess.cpp now spawns it the
QuestChecker way. Verified byte-identical against the SOE tree's shipped
quest_crc_string_table.iff (2736 entries) in both generic-input and
directory-walk modes, then run in-app via the Tool menu: clean console, DONE,
iff hash unchanged, stale 2654-line .tab refreshed to 2736 (SOE originals
backed up at C:\save-test\soe-crc-backup\). The tree root is derived from
defaultListDirectory in QuestEditor.cfg, so the installer's later cfg
parameterization carries over for free. The script's `-InputFile` generic
mode is reusable for the object-template/planet CRC tables in item 5.

## 1 (original notes). Port buildQuestCrcStringTables (QuestEditor)

The `Build Quest CRC Tables` button shells `perl buildQuestCrcStringTables.pl
--local <branch>` (ToolProcess.cpp:148-160), same missing-perl problem the
QuestChecker had. **FOUND (2026-08-28, after searching the TREs and both
drives)**: three identical copies, in the SWGSource repos' tools/ dirs —
`D:\Code\Galaxies-Reborn\swg-main\tools\`, `D:\Code\swg-main\tools\`,
`D:\Code\swg-client\tools\`. (NOT in the SOE tree — its tools/ dir is the
documented absence — and NOT in any archive: client TREs have zero .pl
entries, Beyond TREs likewise.)

What the script actually is (read in full, 120 lines): a PERFORCE WRAPPER —
`p4 where`/`p4 files`/`p4 opened` enumerate the questlist datatable names,
then it pipes the list into **`buildCrcStringTable.pl`** (168 lines, same
tools/ dirs, generic — `buildObjectTemplateCrcStringTables.pl` uses it too),
which holds the CRC-32 table inline and writes the output.

**Even better: the community already replaced the p4 wrapper.**
`swg-main/utils/build_quest_crc_string_tables.py` (44 lines) is exactly the
directory-walk version — walk questlist, sort, pipe — but it STILL pipes into
buildCrcStringTable.pl. So the whole port reduces to ONE script:
- port `buildCrcStringTable.pl` -> PowerShell (CRC-32 table is inline data,
  logic ~40 lines past the table); fold the 44-line walk logic in so the
  editor needs a single spawn;
- verify against the shipped `misc/quest_crc_string_table.iff` in the patch
  TREs (byte comparison, the terrain-bake method).
Verification target exists: `misc/quest_crc_string_table.iff` ships in the
patch TREs (reference outputs), and the reader is
`sharedFoundation/CrcStringTable.cpp` + `QuestManager.cpp:36`.
Wire-up is the proven pattern: ToolProcess.cpp + a .ps1 in the tracked
`src/build/win32/exe/win32/` store.

## 2. Remove Perforce from all tools — DONE 2026-08-29 (editors)

Stripped from all shipped editors: QuestEditor and NpcEditor (Qt actions +
spawn queues), SwgDraftSchematicEditor / SwgSpaceQuestEditor /
SwgSpaceZoneEditor / SwgConversationEditor (toolbar buttons, handlers,
`p4 info` console probes; toolbar bitmap tiles cut so no icon shift),
ShipComponentEditor (P4 Edit Files menu, Jump-to-P4 context items, p4 add
on chassis/template create), UIBuilder (checkout button + p4.bmp/ico).
The dangerous auto-save-before-p4 paths are gone with their buttons.
All 9 projects rebuilt clean and launch-smoked with screenshots.

Libraries: the x64 port had already dropped the p4 client libs from every
active Release|x64 link (no x64 p4 libs even exist); SwgClient still listed
libclient/librpc/libsupp inertly — removed, client relinks clean. The
Win32-config lib lists and src/external/3rd/library/perforce were left
as-is (dead configs / reference source).

NOT stripped, deliberately:
- **SwgGodClient**: the port already defines SWG_DISABLE_PERFORCE — its
  GodClientPerforceUser::runCommand is a stub that fails cleanly with
  "Perforce integration is unavailable in the x64 God client." Its p4 menu
  items are woven into content workflows and the god tools are still
  untested (server evening pending) — revisit after that, using the stub.
- **TemplateCompiler / TemplateDefinitionCompiler**: genuinely use the p4
  C++ API (auto-checkout of outputs); they are not yet built for x64 and
  belong to workstream 5 — do their p4-ectomy when bringing them up.
- MayaExporter / TemplateEditor / SwgContentSync: not part of the 16
  shipped tools; untouched.

## 3. Usability pass over every editor — DONE 2026-08-29 (all 7 seeded editors)

Completed across three sessions; every seed below fixed and Kenny-verified.
Highlights beyond the seeds: the x64 npos truncation in NpcEditor that
corrupted every template save (the REAL beginner_brawler clobber mechanism),
the Qt3 defaultRenameAction=Reject landmine (ClientEffectEditor; check any
future Qt tool with setRenameEnabled), the exewin32 startup dialog removed
from all three MFC tools, and TerrainEditor's stale treeview scroll state
after bulk expansion (forceScrollRecalculation). Per-session detail in the
handoff (2026-08-29 cont. blocks 1-5).

Original seed list from the save sweep (docs/TOOLS-GUIDE.md Part 2.5 has the
full trap table):
- LightningEditor: the .swh writability-probe bug (0-byte litter + wrong-file
  probe) — MainWindow.cpp:255 one-liner.
- ClientEffectEditor: value edits in the tree revert; save silently no-ops on
  unmodified docs (add feedback).
- SwgConversationEditor: failed save returns TRUE and clears the modified
  flag (Doc.cpp:1118-1138) — make failure honest.
- NpcEditor: SaveDialog defaults point INTO the reference tree (clobbered two
  files once already); template-writer failures are silent stubs — surface
  them. Consider shipping replacement text/templates sources.
- QuestEditor: plain Ctrl+S writes back to the opened path with no prompt.
- TerrainEditor: Construction Layers tree cannot scroll (undiagnosed);
  null-boundary crash guard in place but cause unfound.
- SwooshEditor: animation demo inert (combat playback never engages).
- Everywhere: DEBUG_-only diagnostics that hide real failures in release
  (seven instances found so far) — promote the load-bearing ones.

## 4. Packaging / installer

Most SWG data ships in the SWGSource TREs — the tools additionally need the
LOOSE data that is NOT in any TRE. Plan:
- **Build the "not in TREs" inventory — DONE 2026-08-30.**
  `scripts/not_in_tres_inventory.py` (exhaustive: trelist.py reads v0005 AND
  v0006 now); analysis in `.planning/inventory/PAYLOAD-MANIFEST.md`.
  Headlines: 121,024 files / 2.6 GB in no TRE + dsrc 258 MB; TWO payload
  classes (not-in-TRE files vs cfg-referenced dirs tools open via the
  filesystem); 12,106 shadow files ⇒ scoped mounts only; quest content 100%
  loose; trimming question = texture/ (1 GB, needs reference-closure walk).
- Known-required loose payload so far: 4,882 .lmg wearable meshes
  (appearance/mesh), the loose ui/ tree (170 files incl. ui_root_npceditor.ui
  — /AvView exists in NO TRE), ash/lat sources (203), .qst quests, the dsrc
  server+shared sources (QuestEditor/DraftSchematic/SpaceZone/SpaceQuest all
  need them), QuestEditorConfig.xml, NpcEditor.tab/SwooshEditor.tab, the
  spell-check .dct files, loose .prt/.snd/.swh/.ltn/.cef samples for content
  work.
- **Installer**: package that payload + the tool exes + the ported .ps1
  scripts + DataTableTool.exe; installer writes the install root into the
  tool cfgs (the cfgs are tracked and machine-specific today — parameterize
  the three roots: TRE dir, loose-data dir, output dir). The relative
  searchPath trick (TreeFile_SearchNode resolves against CWD) is the
  portable alternative to absolute paths where layout allows.
- Ship legacy no-sku TreeFile keys in tool cfgs (never client.cfg's _00_
  form) — see the memory note; this stays the #1 config landmine.

## 5. CLI tools — BUILD-OUT DONE 2026-08-29 (8 new tools built + verified)

**Built x64 and verified this session** (all in src/build/win32/x64/Release):
- TemplateCompiler (compiles SOE tpf+tdf sources; output = tdf schema v0010,
  what the in-tree engine loads; p4 -edit/-submit stripped)
- Miff (byte-identical vs shipped quest CRC iff; needs a preprocessor:
  cpp.exe beside exe, or MIFF_CPP env var -> set to VS clang on this machine)
- TreeFileBuilder + TreeFileExtractor (3-file TRE round trip byte-identical,
  archive validates as v0005 in trelist.py; extractor reads real SOE TREs)
- TemplateDefinitionCompiler (regenerated SharedTangibleObjectTemplate
  matches in-tree generated code modulo TFD custom-code sections)
- UpdateLocalizedStrings (stf v0->v1 CRC upgrade tool)
- LabelHashTool (quest name -> 0x00707d5e, matches shipped CRC table)
- ViewIff (MFC GUI IFF inspector - opens iffs, title bar confirms)
Plus DataTableTool + Turf from earlier sessions: **10 CLI tools live**.

**Deferred, with reasons**:
- StringFileTool: MFC GUI stf diff/merge; 57 char16/MBCS errors after the
  atlmfc-header fix; needs a real Unicode pass.
- ShaderBuilder: MFC message-map casts + pre-C++11 idioms; ALSO investigate
  whether its D3D9-era output matches the DX11 port's compiled_shader
  manifest before spending time.
- TextureBuilder: TextureFormat fwd-decl vs modern type_traits; real port.
- CreateShaderTemplate / ClientCacheFileBuilder: sources only, no project
  files at all (VC6 leftovers) - would need vcxprojs authored from scratch.
- Armor/CoreWeapon/WeaponExporterTool: need serverGame headers - the server
  library is not in this repo; build from swg-main if ever wanted.
- mochac.pl: STILL UNFOUND.

**Recipes that made this go** (reuse for any future CLI bring-up):
- x64 groups keep win32-era lib lists: point AdditionalLibraryDirectories at
  ..\..\..\..\..\..\..\deps\x64\lib + $(SolutionDir)x64\Release; replace
  libpcre.a -> pcre.lib; add zlib.lib; drop libclient/librpc/libsupp.
- pcre is a DLL: PCRE_STATIC sharedRegex objs want pcre_malloc/pcre_free
  DATA symbols an import lib can't give - drop SetupSharedRegex::install
  from CLI tools (allocator hook only).
- Tools with empty x64 dep lists (rsp-era): add the engine lib set by hand.
- Old atlmfc bundle: remove external/3rd/library/atlmfc include+lib, use
  VS's MFC/ATL. 'byte' ambiguity: _HAS_STD_BYTE=0 (SwgConversationEditor
  precedent).
- Miff needs flex/bison: SOE's own exes at swg-main/tools work (BISON_SIMPLE
  env var -> its bison.simple); custom-build output paths had to be pinned
  to src/compile/win32/Miff (x64 IntDir broke $(IntDir)..\).

## 5 (survey notes). Survey of exe/win32 — 2026-08-29

Full survey of D:\SWG All Tools Working\swg\current\exe\win32 (50+ exes)
cross-referenced against in-tree sources. Verdicts:
- **Tier 1 (editors shell to these)**: TemplateCompiler (source ✓, needs
  p4-ectomy), miff (source ✓ engine/client/application/Miff);
  DataTableTool + Turf already built; QuestChecker/CRC already ported.
- **Tier 2 (pipeline essentials)**: TreeFileBuilder + TreeFileExtractor
  (source ✓), TemplateDefinitionCompiler (source ✓), StringFileTool +
  UpdateLocalizedStrings (source ✓), LabelHashTool (source ✓).
- **Tier 3 (bundle later)**: ViewIff (source ✓), ShaderBuilder (source ✓ —
  INVESTIGATE: does its output match the DX11 port's compiled_shader
  manifest format?), TextureBuilder/CreateShaderTemplate (source ✓),
  NormalMapGen/DxTex (SOE exes as-is), ClientCacheFileBuilder (source ✓),
  Armor/CoreWeapon/WeaponExporterTool (source ✓, combat-balance only).
- **Skip**: p4 plumbing (SwgContentSync/Builder, *RspBuilder), server-ops
  kit (ServerConsole, PlanetWatcher, DatabaseObjectViewer, ServerBins),
  one-offs (BugTool, CrashReporter, SwgCsTool, VoiceService, SkillImport,
  WordCountTool, fedit, SetBrightnessContrastGamma).
- mochac.pl: STILL UNFOUND — conversation Compile remains blocked.

## 5 (original notes). Survey the command-line tools — restore the end-to-end toolkit

The editors shell out to a whole CLI layer; inventory which ones the pipeline
actually needs and bring each up the way DataTableTool was (in-tree source,
x64 build, parser fix already inherited via sharedFoundation). Known so far:
- **DataTableTool** — DONE (built x64, works, .tab -> .iff).
- **templatecompiler** — SwgDraftSchematicEditor's Compile shells
  `templatecompiler -compileeditor` for both .tpfs (Doc.cpp:223-229); the
  server also needs it for all object templates. In-tree source? Check.
- **miff** — .mif -> .cdf/.iff compiler (NpcEditor writes .mif sources; the
  client reads compiled .cdf). SOE exe exists; in-tree source likely
  (sharedFile tools).
- **TreeFileBuilder / TreeFileExtractor** — TRE pack/unpack; needed for
  shipping content back into TREs. SOE exes exist in the reference tree.
- **ViewIff** — diagnostic, nice-to-have.
- The mocha conversation compiler (mochac.pl) — perl again, script ABSENT
  locally; SwgConversationEditor's Compile depends on it. Same
  find-or-reimplement decision as buildQuestCrcStringTables.
Audit method: grep the editors for ProcessSpawner/QProcess/CONSOLE_EXECUTE
spawns to get the complete list of external commands, then triage.

**Resource maps found 2026-08-28** (searched while hunting the CRC script):
- `D:\Code\Galaxies-Reborn\swg-main\tools\` — 189 files: the SOE build
  pipeline (TreeFileBuilder/Extractor/RspBuilder exes, the CRC .pl trio,
  BuildLivePatchTree, DataLint, patcher scripts...). Also mirrored in
  `D:\Code\swg-main\tools\` and `D:\Code\swg-client\tools\`.
- `D:\Code\Galaxies-Reborn\swg-main\utils\` — the COMMUNITY's modernized
  pipeline: build_miff.sh / build_tab.sh / build_tpf.sh / build_java.sh +
  python CRC builders (quest/object_template/planet). This is the working
  map of what the end-to-end content pipeline actually invokes.
- mochac.pl: STILL UNFOUND (not in swg-main tools/ or utils/, not in the SOE
  tree, not in any archive). SwgConversationEditor's Compile stays broken
  until found or the conversation .java/.stf generation is reimplemented.

## 6. Endgame: replace the CLI layer with SWG-Toolkit

Long-term direction: the legacy CLI tools are stopgaps; the durable home for
format tooling is **SWG-Toolkit** (D:/Code/SWG-Toolkit — already the format
REFERENCE for TRE per the standing rule; tre-lint at
D:/Code/swg-client-v2/tools/tre-lint has the verified v0005/v0006 layouts).
Per-format migration: TRE pack/unpack, datatable tab<->iff, IFF inspect
(iffcensus.py is a seed), template compile, string tables. Editors would then
shell the toolkit's CLIs instead of the 2004 exes — the ToolProcess/
CONSOLE_EXECUTE seams found in item 5 are exactly where they swap in.
