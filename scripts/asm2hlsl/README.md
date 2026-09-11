# asm2hlsl — Direct3D 9 shader assembly to HLSL

`D3DCompile` has no assembler, and Direct3D 9 shader assembly is not a Direct3D 11 shader
model. The shipped SWG shader corpus is roughly two thirds HLSL and one third assembly, so
the assembly half has to become HLSL before a D3D11 backend can render what DX9 renders.

This converts it, offline. The output is loose `.vsh` and `.psh` files in `client-assets`,
which override the TRE copies through the same search-path mechanism the project already
uses for its custom textures and shaders. After conversion the DX11 backend never sees an
assembly program, which is the point: no DX9 shader artefacts left in the running client.

## Pipeline

```
python shadercorpus.py     # resolve and extract the corpus from the TRE stack
python classify.py         # split programs by declared language
python reachable2.py       # which programs a live implementation can reach  (reporting only)
python envmap_stages.py    # which sampler stages are fed a cube map
python asm2hlsl_run.py     # convert ALL the assembly
python verifyconv.py       # compile every conversion with fxc
```

Two of those steps are load-bearing in ways that are easy to get wrong.

**`asm2hlsl_run.py` converts every assembly program, not the reachable subset.** It reads
`asm-programs.txt` (224 programs), not `asm-reachable.txt` (97). The closure in
`reachable2.py` walks the effects a live implementation loads, and five programs the client
demonstrably asks for are not reachable that way at all: `gradient_sky.vsh` / `.psh`,
`ui_radar.psh`, `texren_copy_c1a1.psh` and `bad_vertex_shader.psh`. The sky and the texture
renderer name their programs from engine code, and `bad_vertex_shader.psh` is what the backend
itself reaches for when a material will not draw. An unconverted vertex program means every
draw using it is dropped — the missing sky program alone was 12,665 dropped draws in a 6,300
frame run. `reachable-programs.txt` is still worth having as a census; it is not an input to
what gets built.

**`envmap_stages.py` recovers the one thing the assembly does not say.** D3D9 assembly before
`ps_2_0` declared no sampler dimension: `tex t1` sampled whatever kind of texture happened to
be bound. HLSL has to commit to `sampler` or `samplerCUBE`, and D3D11 rejects a read whose
declared type disagrees with the bound view — the draw does not render, and the debug layer
reports a slot number with no program attached. The dimension comes from the effects: each
pixel shader FORM carries a `PTXM` entry per stage holding the stage index and its texture
tag, and one tag is special. `ENVM` is not supplied by the material at all —
`ShaderPrimitiveSorter` pushes it as a global per cell and its default is a cube map — so an
`ENVM` stage is always a cube and everything else is 2D. Nine converted programs need it.
Regenerate `envmap-stages.tsv` whenever the corpus changes; `asm2hlsl_run.py` refuses to run
without it rather than silently declaring every environment stage 2D.

`shadercorpus.py` needs `E:\SWG\64bit-server\_client` (the deployed client: 209 `.tre`
archives, 4 `.toc` indexes, and the five `.cfg` files `client.cfg` includes). It writes the
corpus to `corpus/` and a provenance table to `corpus-manifest.tsv` (name, size, winning
node rank, node kind, containing archive). Everything downstream works from its output, and
`reachable2.py` imports `shadercorpus.search_order()` / `resolve()` rather than keeping its
own copy.

## Search precedence, which is easy to get backwards

`shadercorpus.search_order()` models the whole of `TreeFile::install`. Four things have to
be right at once:

**`searchTOC` counts, not just `searchTree`.** `live.cfg` carries four
`searchTOC_<sku>_<priority>` keys at priorities 0–3, naming 198 `.tre` archives between
them. **137 of the 209 `.tre` files in a deployed client are version `TREE0006` with a
completely zeroed header** — no internal directory at all — so a `SearchTree` over one finds
nothing and `tre.py` reports zero files for it. Those archives are reachable *only* through
a `.toc`, which supplies `(treeFileIndex, offset, length, compressor, compressedLength)`
externally; `SearchTOC::open` then reads the payload straight out of the `.tre`. A `.toc`
carries no payload of its own. Reading only the `searchTree` keys hid 89 files outright and
resolved 436 more from superseded copies.

**Priority, then insertion order.** `TreeFile::addSearchNode` keeps its list sorted by
priority descending and inserts with `std::lower_bound` against an
`a->priority > b->priority` comparator. `lower_bound` returns the first position whose
priority is *not greater*, so an equal-priority node is inserted **before** the ones already
there: **the last node added at a given priority is searched first.** The doc comment above
that function says the opposite. Within one sku, `install()` adds paths, then trees, then
TOCs, so at equal priority a `.toc` beats a `.tre` — an insertion-order artifact, not a type
precedence. Note also that the trees are *not* all at priority 0: 65 are, but `ILM_sound`,
`ILM_maps`, `ILM_music`, `ILM_visuals`, `ILM_animation`,
the snow override and legacy client update archives sit at 2–8, and five of those outrank every
TOC.

**`SearchAbsolute`.** `install()` always adds one at (highest configured priority + 1), so
loose files in the working directory beat every archive. 25 loose `.sht` files in the
deployment directory win that way.

**Zero-length entries mean two different things.** `SearchTree::localExists` sets
`deleted = true` for a matched entry whose `length == 0`, and `TreeFile::find` loops on
`!deleted`, so such an entry **aborts the whole search** and the file is reported absent even
though lower-priority nodes hold a copy. `SearchTOC` never sets `deleted`; its zero-length /
zero-offset entries are plain misses and the walk continues. Ignoring this wrote two
zero-byte files into the corpus that the client cannot open at all.

Resolving backwards picks a 12,318-byte `vertex_program/include/functions.inc` from
`patch_12_00.tre` instead of the 17,375-byte, 473-line copy in `patch_24_client_01.tre` (a
`TREE0006` archive, reachable only via `sku0_client.toc`) that the running client actually
compiles and that declares `HemisphericLightData`; a 601-byte `shared_program/functions.inc`
from a base tree instead of the 2,398-byte copy that defines `intensity()` and
`tex2DDxt5CompressedNormal()`; and an older `vertex_shader_constants.inc` whose `Dot3Light`
has its first two fields transposed relative to the C++ struct the engine uploads.

## What the conversion preserves

**Module structure.** A converted module is a block of HLSL statements that the converted
program `#include`s inside `main()`, exactly as the assembly had it. The shared lighting code
is translated once, the output diffs against the input, and the inherited `c_ambient.inc`
patch stays a runtime concern rather than being baked into 23 generated files.

**The constant ABI.** Constants resolve into a flat `float4 c[96] : register(c0)`. `fxc`
places that at `$Globals` offset 0 with size 1536, so element *i* sits at byte 16*i* —
byte-identical to the register file the engine already uploads. `registers.inc` becomes
`#define`s onto `c[N]`, so module bodies keep the symbolic names they were written with.

**The texture-coordinate indirection.** The engine rewrites the tag-to-set mapping per vertex
buffer, so converted programs keep the `#define` header the runtime parses, use the HLSL-form
`textureCoordinateSetTAG` spelling, and reach the sets through the input struct instance the
way the hand-written HLSL programs do.

**Whole-register constant reads.** Assembly reads a whole constant register:
`mul r1, r1, c[dot3LightSpecularColor]` multiplies all four channels. The engine-layout
`pixel_shader_constants.inc` defines those same names as partial swizzles of packed
registers, which is correct for the HLSL programs written against it and wrong here, so the
converted pixel programs get their own `asm_constants.inc` binding each name to a whole
register.

## Decisions worth knowing about

**`c95`.** `registers.inc` maps `c0_0`, `c0_5`, `c1_0` and `cLog2e` onto `c95.x/y/z/w`, which
a D3DX `#pragma def` preloaded. Only assembly ever read them, and the D3D11 path has no
equivalent directive, so they are emitted as literals rather than depending on an upload.

**`cExtLtData_parallelSpec_0_*`.** `ILM_visuals.tre` replaced
`vertex_program/modules/diffuse.inc` with a version referencing three constants that nothing
in any of the 209 TREs defines. DX9 hard-FATALs when assembly fails to compile, so sixteen
reachable vertex programs — fifteen of them base content from `patch_00.tre`, all cell and
interior shaders — cannot be created on DX9 as things stand. They are mapped here onto the
engine's `extendedLightData` block at `c60..c63`, whose `HemisphericLightData` fields are
`backColor`, `tangentColor`, `tangentMinusBackColor` and `tangentMinusDiffuseColor` in that
order, which is an exact name match for what the module wants. That is a deliberate choice to
make installed content work rather than to reproduce a crash.

**Vertex inputs are `float4`.** Assembly treats an input as a whole register and some
programs swizzle all four components of the normal. D3D11 fills components the input layout
does not supply with 0, and `w` with 1, which is what D3D9 did for an unwritten register
component.

**Co-issue markers are dropped.** A `+` pairs an alpha instruction with the preceding colour
one. The two write disjoint masks, so the pairing carries no semantics worth preserving.

## Verification

`verifyconv.py` overlays the conversion on the extracted corpus and compiles every converted
output with `fxc` at `vs_4_0` / `ps_4_0`. Converted programs carry their generated constant
and texture-coordinate declarations, so this sweep has no dependency on an untracked helper.
It uses `/Gec`, the same compatibility flag as `Direct3d11_ShaderCompiler`.

The full 242-file loose override was compiled on 2026-07-28: all 224 shader programs passed
(`94` vertex and `130` pixel), alongside 18 generated include/module files. The set contains
all 223 assembly programs recovered from the clean Publish 14 client plus
`a_specmap_bump_diffuse.psh` from the clean x64-DX11 base for compatibility with later effect
references.

The Pre-CU NGE content layer also reaches twenty-nine later retail shader sources that do not exist in
the Publish 14 TRE stack. They are native HLSL rather than assembly and are hash-pinned in
`precu-content-hlsl.tsv`. Run `import_precu_content_hlsl.py --source-client <clean-client>`
to import them into the tracked `converted` tree; `--stage-client` also writes the exact
payloads into a test client. The importer rejects a source-precedence change, a byte/hash
change, or any payload that is not HLSL. For the nine vertex programs it removes only the
D3D9-era `register(vN)` annotations from input-struct members and binds their two required
transform/fog helpers directly to the tracked flat DX11 constant ABI in `asm_constants.inc`.
This avoids inheriting a different `functions.inc` from the NGE or Publish 14 archive stack;
the DX11 output hashes are pinned separately. The normal x64 Pre-CU staging workflow then
deploys these programs with the rest of the tracked loose DX11 overrides.

Three program names that a live implementation references —
`pixel_program/lava_ps14.psh`, `vertex_program/lava_ps14.vsh` and
`vertex_program/lava_static.vsh` — exist in no archive, no `.toc` and no loose file, so they
cannot be compiled from anything. They are dangling references in the shipped effect data.

Compiling is not the same as being correct. The runtime gate is a live DX11 render with the
loose override staged above the TRE stack.

The complete Publish 14 set includes three legacy edge cases that the original conversion
missed: `water_pass2_20.psh` uses `texm3x3vspec`, `water_pass2_25.psh` uses the ps_1_4
`phase`/`texcrd` sequence, and `membrane.psh` places a descriptive comment before its
`ps.1.1` marker. The classifier and translator cover all three; generated output must contain
224 shader programs plus 18 shared include/module files.

The Publish 14 `procedural_clouds.vsh` source also uses the legacy singular
`cUserConstant` spelling even though `registers.inc` declares the user registers as
`cUserConstant0` through `cUserConstant7`. The generated constants include aliases that
singular spelling to slot zero, which is where the cloud opacity is uploaded.
