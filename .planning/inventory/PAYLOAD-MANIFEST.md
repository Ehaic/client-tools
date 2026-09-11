# Not-in-TREs inventory — installer payload manifest (TODO item 4)

Generated 2026-08-30 by `scripts/not_in_tres_inventory.py`. Regenerate any time
(~1 min):

```
python scripts/not_in_tres_inventory.py
```

Inputs: the 209 SWGSource v3.0 TREs (`D:\Code\SWGSource Client v3.0`, 217,533
entries, 150,575 unique names — trelist.py now reads BOTH v0005 and v0006, so
this census is exhaustive, unlike the pre-guard sweeps) vs the SOE loose tree
(`D:\SWG All Tools Working\swg\current`). Full per-file results:
`data-manifest.csv` (295k rows) + `dsrc-manifest.csv` (85k rows) in this
directory — NOT committed (26 MB + 8 MB, regenerable); `summary.txt` is.

## Headline numbers

| payload class | files | size |
|---|---|---|
| A. data files in NO TRE | 121,024 | 2,617 MB |
| A. dsrc sources (never in TREs) | 85,431 | 258 MB |
| B. cfg-referenced loose dirs (overlaps A) | see below | — |
| exe/win32 config payload | ~60 small files | < 5 MB |

Per data root (files / total MB / **not-in-TRE** files / not-in MB / shadow):

```
sku.0/sys.client/compiled/game   209,139  7,421 MB   60,469  2,470 MB   7,330
sku.0/sys.server/compiled/game    48,656    143 MB   48,627    123 MB      17
sku.0/sys.shared/compiled/game    36,894     72 MB   11,928     25 MB   4,756
(the three .../built/game roots hold 1 file each, all TRE-covered)
```

Not-in-TRE data by top-level dir, largest first: texture 1,042 MB (8,884 .dds),
appearance 685 MB (23,984), sample 302 MB, video 162 MB, music 90 MB,
player_music 69 MB, object 62 MB (47k tiny .iff), datatables 59 MB, script
50 MB (5,658 .class — the whole server script tree), voice 29 MB, quest 27 MB
(1,300 .qst — quest content is 100% loose, zero .qst in any TRE), terrain
22 MB, then a long tail (ui 4.4 MB incl. ui_root_npceditor.ui, clienteffect
176 files, etc.).

## Two payload classes — the distinction that matters

**Class A — files in no TRE.** TreeFile can never serve them; without a loose
copy the data does not exist. The `in_tre == 0` rows of data-manifest.csv.

**Class B — directories the tools open with the FILESYSTEM, not TreeFile.**
The cfg keys point editors straight at loose dirs (browse defaults, source
dirs, WRITE targets). These must exist loose **even where every file is also
in a TRE**. From the cfg cross-reference (all `SWG All Tools Working`
references in the Release + exe/win32 cfgs):

| loose dir (under the matching root) | files | MB | cfg keys / tools |
|---|---|---|---|
| client `appearance/mesh` — *.lmg only | 4,882 | 1.1 | NpcEditor wearableDirectory |
| client `quest/` | 1,671 | 32 | QuestEditor defaultQuestDirectory |
| client `string/en/` | 5,494 | 46 | SpaceQuest sharedStringFilePath, ConvEditor stringPath (WRITE target) — 0 not-in-TRE, ships for browse/write |
| client `ui/` | 203 | 16 | UIBuilder searchpaths; ui_root_npceditor.ui (NpcEditor /AvView) |
| client `clienteffect/` | 1,048 | 0.1 | CEE scoped mount (stage-cee-loose junction) |
| server `object/` | 30,086 | 37 | NpcEditor weapons, QuestEditor serverObjectTemplateDirectory, GodClient |
| server `datatables/` | 9,557 | 35 | SpaceQuest/SpaceZone/GodClient |
| server `script/` | 5,658 | 50 | GodClient scriptClassPath |
| server `misc/` | 14 | 23 | object_template_crc_string_table.iff (ShipComponent, GodClient) |
| shared `object/` | 30,006 | 48 | GodClient template paths |
| shared `datatables/` | 6,530 | 24 | QuestEditor questlist (CRC script walks it) |
| `dsrc/` (all three sys.*) | 85,429 | 258 | NpcEditor/QuestEditor/DraftSchematic/ConvEditor/SpaceQuest/GodClient sources — READ AND WRITE |

Note the .lmg correction: the TODO said "4,882 .lmg wearable meshes" as if
not-in-TRE; actually only 1,819 are absent from TREs. Irrelevant for packaging
— NpcEditor enumerates the directory, so all 4,882 ship (1.1 MB, trivial).

## THE SHADOW TRAP — why the installer must use scoped mounts

**12,106 loose files share a TRE name but match no TRE copy's size** (object
4,608, datatables 2,528, appearance 2,160, string 855, ...). The SOE tree is
2016 dev data; the TREs are v3.0. Mounting a broad loose root over the TREs
makes these shadow files WIN and changes engine behavior — this is exactly the
walking-avatar bug (08-29): a whole-tree searchPath11 mount made the CEE
avatar walk. And priority does NOT fix it: TreeFile registers searchPaths
ahead of searchTrees at each priority (TreeFile.cpp:345), so a loose root
shadows TREs even at priority 0.

Rule for the installer: **loose dirs are for filesystem access (Class B) and
for scoped TreeFile mounts only** (junction/subdir per data type, like
stage-cee-loose). Never mount a whole `compiled/game` root as a searchPath.
(QuestEditor.cfg's searchPath10/11 currently DO mount whole roots — works,
but carries the shadow risk; candidate for scoping during cfg
parameterization.)

## exe/win32 payload (beside the tool exes)

Tracked already in `src/build/win32/exe/win32/`: QuestEditorConfig.xml,
SwgDraftSchematicEditor.cfg/.ini, SwgConversationEditor.ini, NpcEditor.tab,
SwooshEditor.tab, QuestChecker + BuildQuestCrcStringTables .ps1. From the SOE
exe/win32 still referenced by cfgs and NOT tracked: the two spell-check
dictionaries `SwgConversationEditor_medium.dct` / `_user.dct` (ConvEditor
dictionary keys), `godclient_favorites.xml` (copied to Release). mochac.pl
(mochaCommand key) exists NOWHERE — key is now unread after the p4 strip,
dialog was fixed 08-28.

Out-of-repo pieces the installer must also carry (lost on wipe today):
- `D:\Code\Galaxies-Reborn\stage-B-override\ui\ui_root_npceditor.ui`
  (searchPath12 override; NpcEditor dies without it)
- `D:\Code\Galaxies-Reborn\stage-cee-loose\clienteffect` junction (recreate:
  `New-Item -ItemType Junction -Path ...\stage-cee-loose\clienteffect -Target
  "D:\SWG All Tools Working\swg\current\data\sku.0\sys.client\compiled\game\clienteffect"`)
- compiled_shader cache in Release (regenerable, avoids first-run stalls)

## PAYLOAD REPO GENERATED (2026-08-31) — D:\Code\Galaxies-Reborn\tools-payload

> **2026-09-01:** pushed to
> https://github.com/Galaxies-Reborn/legacy-tools-payload and wired into
> client-tools as the `tools-payload/` submodule. The authoring clone at
> the path above is RETIRED (deleted after verifying fully pushed) — the
> submodule copy is now the only local checkout, and
> `generate_missing_bits.py` defaults its output there.

`scripts/generate_missing_bits.py` built and committed it (local `main`,
d54c64e2, ready to push to the org): **29,681 files / 1,615 MB**
(git pack 1.01 GiB) = client 23,970 / 1,564 MB + server script 5,658 /
50 MB + Erusman extras 30 + shared residue 18 + exe extras 3.

Refinement discovered by the run: server `misc/` selected ZERO files —
all 14 (object_template_crc_string_table.iff included) are IN TREs; they
were only Class B because tools read them via filesystem paths. So they
are neither payload nor rebuild: the installer MATERIALIZES them from the
TREs (TreeFileExtractor, byte-exact). General rule adopted: any Class B
file that exists in a TRE is extracted at install, never shipped.

## dsrc DROPS OUT OF THE PAYLOAD — it is a public git repo (found 2026-08-30)

The SOE tree's `dsrc/` is not loose data at all: it is a clone of
**https://github.com/SWG-Source/dsrc.git** at `a05279872` (2020-06-10), a
strict ancestor of the commit both swg-main repos pin (`c7294da3e`,
2020-09-18 — Galaxies-Reborn/swg-main and upstream SWG-Source/swg-main pin
the SAME sha; local delta is 21 commits behind, 0 ahead). The installer can
`git clone` (or `git submodule update --init dsrc` in swg-main) instead of
shipping 258 MB. Open choice: stay at a05279872 (what every tool was
validated against) or take the 21 upstream commits and re-smoke the
dsrc-dependent editors.

Bonus uses of that clone being a git repo:
- `git -C <soe>/dsrc status` is the definitive dsrc WRITE AUDIT (supersedes
  find -newermt for that subtree). As of 2026-08-30 it shows exactly our 3
  known writes and nothing else: the two 08-28 reconstructed .tpf files and
  the CRC-regenerated quest_crc_string_table.tab.
- `git diff` VALIDATED the 08-28 beginner_brawler reconstruction against
  ground truth: content byte-identical; sole delta is a trailing newline the
  originals lacked. (Left in place — harmless.)

## serverdata IS THE LOOSE CLIENT DATA SET — 745 MB more drops out (verified 2026-08-30)

swg-main's `serverdata` submodule (SWG-Source/serverdata) is misnamed:
125,417 of its 125,515 files match our **sys.client**/compiled/game names,
99.9% size-identical (full listing pulled via the GitHub tree API — master
@ `3ee03ed3`; note swg-main pins `df41a07ed`, and the repo is active,
pushed 2026-05). Only 99 files in it are unknown to the SOE tree.

Coverage of our client not-in-TRE payload (files covered/total):

| category | covered | MB | verdict |
|---|---|---|---|
| appearance | 23,983/23,984 | 685/685 | **clone serverdata instead of shipping** (includes all 4,882 wearable .lmg) |
| quest | 1,300/1,300 | 26.5 | covered |
| datatables (client) | 4,079/4,079 | 12.8 | covered |
| shader / string / terrain / pixel_program / palette / footprint | ~all | ~21 | covered |
| **texture** | 0/8,884 | 0/1,042 | NOT covered — still the closure question |
| sample/video/music/player_music/voice | 0 | 0/651 | not covered — trim candidates anyway |
| client object/, ui/, clientdata/, clienteffect/, sound/, interiorlayout/ | 0 | ~26 | small, ship loose |

**Total: 36,527 files / 745 MB of the 2,470 MB client not-in payload comes
from a `git clone` instead of shipped files.** Only 41 size mismatches among
the covered set (un-triaged). serverdata covers essentially NOTHING of
sys.server/compiled/game (object/script/datatables/misc, 123 MB) — those are
build artifacts of dsrc via swg-main's pipeline; ship them or build them.
sys.shared not-in coverage is partial (3,393 of 11,928).

Revised payload-to-ship estimate: texture 1,042 MB (pending closure walk) +
media 651 MB (likely droppable) + server compiled 123 MB + shared leftovers
~25 MB + small client leftovers ~26 MB ≈ **1.9 GB worst case, ~200 MB if
texture+media resolve as droppable/clonable** — plus two git clones (dsrc,
serverdata).

## Texture facts (checked 2026-08-30) — not derivable, ship-or-trim only

Loose `texture/` is 29,845 files; 20,961 ARE in the v3.0 TREs (which carry
25,118 texture entries), 8,884 are loose-only (1,042 MB): 8,512 at texture/
root (NGE-era item/vehicle .dds — a1_deluxe_floater etc.), 275 loading
screens (38 MB), 97 fonts (23 MB). **They cannot be rebuilt**: .dds IS the
compiled form (TextureBuilder compiles source art), and the source art tree
was never distributed — dsrc holds just 32 palette .tga, serverdata has no
texture dir at all. So the choice is ship (1 GB) vs closure-trim; anything
trimmed wrongly degrades silently to a default texture (TextureList::fetch
createTexture=true). Interplay to remember: serverdata's appearance/shader
set is the same 2016 vintage as these textures — dev appearances may
reference loose-only textures.

## Rebuild-at-install for the compiled server/shared data (decided 2026-08-30)

All of it compiles from the dsrc clone with tools we already ship:

| artifact | source | tool | status |
|---|---|---|---|
| server+shared+client object/*.iff | 63,428 .tpf | TemplateCompiler | proven 08-29 |
| server+shared datatables/*.iff | 15,789 .tab | DataTableTool | proven 08-29 |
| misc/ CRC string tables | template name walk | BuildQuestCrcStringTables.ps1 generic mode + LabelHashTool | quest table byte-identical; object table TODO |
| script/*.class | 5,623 .java | javac (JDK dep) | swg-main's own pipeline; only GodClient uses these — make optional |

Impact: shipped payload drops another ~150 MB (server 123 + shared
leftovers) and — the bigger win — the installed env becomes SOURCE-CONSISTENT:
the SOE tree today mixes 2016 compiled bakes with a 2020 dsrc clone, so its
compiled data may not even match its own sources; rebuilding from the cloned
dsrc removes that latent mismatch and proves the editor→compile pipeline on
every install. Costs: an install-time compile step (est. tens of minutes for
~80k files — measure once), a JDK only if scripts are wanted, and the known
schema-upgrade delta (recompiles emit v0010 vs shipped v0009 — engine reads
both; expect byte-diffs vs SOE bakes, compare functionally not byte-wise,
except CRC tables which ARE byte-reproducible). Editors read the rebuilt
files — one smoke pass against a rebuilt set is the acceptance test.

## Media verdict (checked 2026-08-30): the audio SHIPS — Kenny's hunch confirmed

Parsed all 1,354 loose-only .snd templates and extracted their media
references (string scan for .wav/.mp3): 1,497 unique refs — **1,293 point at
loose-only media** (1,207 sample, 46 voice, 40 music), 198 at TRE-resident
media, 6 at dead absolute SOE dev paths (c:/swg/... litter, ignore). The
loose-only sound set and the loose-only audio are one unit; dropping the
media breaks 95% of the loose-only sounds.

TRE holdings for context: the TREs DO carry a large media set (sample 4,246,
player_music 1,454, voice 795, music 217, sound 4,056 entries) — that part
needs NOTHING: TreeFile serves it to the engine from the mounts. Extraction
into the flat tree (TreeFileExtractor/trelist, trivial) is only warranted if
a tool needs a loose BROWSE dir (check SoundEditor's open-dialog defaults
when next in it). The loose-only media cannot come from TREs — it is not in
them.

Revised media plan: ship the loose-only audio in the missing-bits repo —
sample 302 MB + music 90 MB + player_music 69 MB + voice 29 MB = **490 MB**
(player_music is the musician-profession songs, referenced via datatables
not .snd). `video/` (13 files, 162 MB) is referenced by no .snd and is
identified: Bink cutscene/UI content — npe_intro/station/falcon (NGE
tutorial cutscenes, 88 MB), mustafar_main (Trials of Obi-Wan intro), and 9
profession_*.bik (NGE character-creation preview videos). Played only by
the game client's creation/tutorial flows, never by any tool, and the v3.0
client install ships NO video dir at all — **dropped from the tools
payload** (if GR ever wants them it is a game-client distribution item). Residue: 103 of the loose-only samples are
unreferenced by loose-only .snd (may be referenced by TRE-resident .snd or
dead) — kept, not worth the risk for ~MBs.

## Texture closure walk RUN (2026-08-30): SHIP ALL — the textures are live

`scripts/texture_closure.py` string-scanned all 255,189 shippable loose
files (2.6 GB; media/texture payload excluded from the corpus) for .dds
references and classified the 8,884 loose-only textures
(`texture-closure.csv`, committed):

| verdict | files | MB |
|---|---|---|
| referenced by full path | 6,458 | 774 |
| referenced by basename | 1,394 | 123 |
| font (composed by font system) | 89 | 22 |
| unreferenced by the loose corpus | 943 | 122 |

**88% provably live from the shipped-loose corpus alone** — the "1 GB of
dead dev textures" theory is dead. And the 943 "unreferenced" are dominated
by categories the corpus cannot see: `large_*` loading screens (253 —
selected via TRE datatables/code), `ui_*` (145 — referenced from
TRE-resident UI files, which were not scanned), and companion-map suffix
families (_cn/_sm/_emis/_spec/_n — plausibly code-composed from base names).
Trimming them would save 122 MB (12%) against silent-degradation risk
(missing texture ⇒ default texture, no error). **Decision: ship all
1,042 MB.** Optionally pack into `tools_texture.tre` per the installer
design. (A TRE-content scan could reclassify most of the 943 as live, but
it cannot change the decision — either way everything ships.)

## Trimming opportunities (superseded for texture/media — see verdicts above)

The 2.6 GB Class A is the *superset*. Big chunks are plausibly not needed by
any tool: `sample/` 302 MB (audio samples — SoundEditor might browse them),
`video/` 162 MB, `music/` + `player_music/` 159 MB, `voice/` 29 MB. texture/
1,042 MB not-in-TRE is the big question mark — how much is referenced by
not-in-TRE appearances vs dead dev data is unknown. A reference-closure pass
(walk .apt/.sat/.msh/.sht chains) would answer it; not done. Decision for
later: ship-everything (~3 GB) vs closure-trimmed.

## Suggested cfg parameterization (three roots)

Every machine-specific path in the cfgs is built from three roots:
1. TRE dir (`D:\Code\SWGSource Client v3.0`)
2. loose-data root (`D:\SWG All Tools Working\swg\current`) — data/ + dsrc/
3. output/scratch root (C:\save-test today)

The installer writes these into the cfgs (or a shared include cfg). Keep the
legacy no-sku TreeFile keys — never client.cfg's `_00_` form (standing #1
landmine).
