"""List / extract entries from SWG .tre archives (TREE versions 0005 and 0006).

Format ground truth is NOT guessed here -- it comes from the SWG-Toolkit provider's
tre-lint, which arbitrated the v0006 record layout against real bytes across every
populated archive on this machine:

    D:/Code/swg-client-v2/tools/tre-lint/src/format.ts
    D:/Code/SWG-Toolkit/.planning/handoff/2026-08-17-PROVIDER-NOTE-tre-lint-seed-and-v0006-verdict.md

Header (36 bytes, little-endian, identical for 0005 and 0006):
    token@0 version@4 numberOfFiles@8 tocOffset@12 tocCompressor@16
    sizeOfTOC@20 blockCompressor@24 sizeOfNameBlock@28 uncompSizeOfNameBlock@32

Tags are big-endian-composed uint32s serialised little-endian, so a hex dump shows
them mirrored: 'TREE' -> "EERT", '0005' -> "5000", '0006' -> "6000".

TOC records:
    v0005 -- 24 bytes: crc@0 length@4 offset@8 compressor@12 compressedLength@16
             fileNameOffset@20
    v0006 -- 32 bytes: crc@0 length@4 offset@8 zero@12 zero@16 fileNameOffset@20
             compressor@24 compressedLength@28

The v0006 layout is the "REORDER" model. A competing "pad" model (compressor and
compressedLength at 12/16, zero padding at 24..31) was FALSIFIED -- it scored 0.0%
on every populated archive while reorder won unanimously. Do not swap them back.

Compressor codes: 0 = stored, 1 = zlib (Restoration dialect), 2 = zlib (stock).
Both 1 and 2 are plain zlib streams.

Many v0006 archives are legitimately UNPOPULATED: a valid 36-byte header whose
numberOfFiles is 0. Those are empty containers, not corrupt files, and are reported
as empty rather than as errors.
"""
import os, sys, zlib, struct, glob

VERSION_0005 = 0x30303035
VERSION_0006 = 0x30303036
TOKEN_TREE = 0x54524545

RECORD_SIZE = {VERSION_0005: 24, VERSION_0006: 32}


def _inflate(blob, compressor, expected_size, what):
    """Decompress a TOC / name block. compressor 0 = stored, 1 and 2 = zlib."""
    if compressor == 0:
        return blob
    if compressor in (1, 2):
        return zlib.decompress(blob)
    raise ValueError("unknown %s compressor %d" % (what, compressor))


def read_tre(path):
    """Return a list of (name, offset, compressor, compressedLength, length).

    Returns None if the file is not a TRE at all. Raises ValueError on a TRE whose
    header parses but whose contents do not.
    """
    with open(path, "rb") as f:
        head = f.read(36)
        if len(head) < 36 or head[0:4] not in (b"TREE", b"EERT"):
            return None

        (token, version, count, toc_off, toc_comp, toc_size,
         name_comp, name_size, name_usize) = struct.unpack("<9I", head)

        if version not in RECORD_SIZE:
            raise ValueError("unsupported TRE version %r (0005 and 0006 implemented)"
                             % head[4:8])

        # A valid header declaring nothing. Real and common among v0006 containers.
        if count == 0:
            return []

        rec_size = RECORD_SIZE[version]

        f.seek(toc_off)
        toc_raw = f.read(toc_size if toc_comp else count * rec_size)
        toc_raw = _inflate(toc_raw, toc_comp, count * rec_size, "TOC")

        name_raw = f.read(name_size if name_comp else name_usize)
        name_raw = _inflate(name_raw, name_comp, name_usize, "name block")

    if len(toc_raw) < count * rec_size:
        raise ValueError("TOC short: %d bytes for %d x %d-byte records"
                         % (len(toc_raw), count, rec_size))

    entries = []
    for i in range(count):
        o = i * rec_size
        crc, length, offset = struct.unpack("<Iii", toc_raw[o:o + 12])
        if version == VERSION_0005:
            compressor, clen, noff = struct.unpack("<iii", toc_raw[o + 12:o + 24])
        else:
            noff = struct.unpack("<i", toc_raw[o + 20:o + 24])[0]
            compressor, clen = struct.unpack("<ii", toc_raw[o + 24:o + 32])

        if noff < 0 or noff >= len(name_raw):
            raise ValueError("entry %d name offset %d outside %d-byte name block"
                             % (i, noff, len(name_raw)))
        end = name_raw.index(b"\0", noff)
        name = name_raw[noff:end].decode("latin-1")
        entries.append((name, offset, compressor, clen, length))
    return entries


def extract(path, entry):
    name, off, comp, csize, usize = entry
    with open(path, "rb") as f:
        f.seek(off)
        blob = f.read(csize if comp else usize)
    return _inflate(blob, comp, usize, "member '%s'" % name)


def find(root, pattern):
    """Yield (tre_path, entry) for every entry whose name contains pattern."""
    pattern = pattern.lower()
    for t in sorted(glob.glob(os.path.join(root, "*.tre"))):
        try:
            ents = read_tre(t)
        except Exception:
            continue
        for e in ents or []:
            if pattern in e[0].lower():
                yield t, e


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit("usage: trelist.py <dir-of-tres> [name-substring] [--dump [outdir]]")

    root = sys.argv[1]
    pattern = sys.argv[2].lower() if len(sys.argv) > 2 and not sys.argv[2].startswith("--") else ""
    dump = "--dump" in sys.argv
    outdir = None
    if dump:
        i = sys.argv.index("--dump")
        if len(sys.argv) > i + 1:
            outdir = sys.argv[i + 1]

    tres = sorted(glob.glob(os.path.join(root, "*.tre")))
    total = 0
    empty = 0
    bad = 0
    by_version = {}
    hits = []

    for t in tres:
        try:
            with open(t, "rb") as f:
                ver = f.read(8)[4:8]
            ents = read_tre(t)
        except Exception as e:
            print("  !! %s: %s" % (os.path.basename(t), e))
            bad += 1
            continue
        if ents is None:
            bad += 1
            continue
        key = ver[::-1].decode("latin-1", "replace")
        by_version[key] = by_version.get(key, 0) + 1
        if not ents:
            empty += 1
        total += len(ents)
        for e in ents:
            if pattern in e[0].lower():
                hits.append((os.path.basename(t), t, e))

    vers = ", ".join("v%s: %d" % (k, v) for k, v in sorted(by_version.items()))
    print("scanned %d tre(s) [%s], %d entries, %d empty, %d unreadable"
          % (len(tres), vers, total, empty, bad))
    print("matches for %r: %d" % (pattern, len(hits)))
    for base, full, e in hits[:200]:
        print("  %-28s %s" % (base, e[0]))
    if len(hits) > 200:
        print("  ... %d more not shown" % (len(hits) - 200))

    if dump and hits:
        base, full, e = hits[0]
        data = extract(full, e)
        target_dir = outdir or os.path.dirname(os.path.abspath(__file__))
        out = os.path.join(target_dir, os.path.basename(e[0]))
        with open(out, "wb") as f:
            f.write(data)
        print("dumped %s (%d bytes) -> %s" % (e[0], len(data), out))
