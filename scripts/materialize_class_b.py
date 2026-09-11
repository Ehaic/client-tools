"""Materialize Class B files from the mounted TREs into the loose tree.

Installer rule (PAYLOAD-MANIFEST, 2026-08-31): any file a tool reads via the
FILESYSTEM that also exists in a TRE is never shipped in the payload repo —
it is extracted from the TREs at install time. This implements that step.

Current list: the server misc/ files (ShipComponentEditor et al. read
sys.server/compiled/game/misc from disk). The two CRC string tables are NOT
here — build_object_crc_tables.py and BuildQuestCrcStringTables.ps1 generate
those from the rebuilt tree.

Where a name exists in several TREs, the copy from the last TRE in sorted
order wins (newest patch approximation).

Usage: python materialize_class_b.py [root]   (default C:/swg/current;
TREs are read from <root>/tre)
"""
import glob, io, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import trelist

ROOT = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else r"C:\swg\current")
TRE_DIR = os.path.join(ROOT, "tre")

# (TRE entry name, dest path relative to root)
SERVER_MISC = "data/sku.0/sys.server/compiled/game/misc"
WANTED = [("misc/" + n, SERVER_MISC + "/" + n) for n in (
    "asynchronous_loader_data_0.iff", "asynchronous_loader_data_1.iff",
    "asynchronous_loader_data_2.iff", "cache_large.iff", "cache_medium.iff",
    "cache_small.iff", "cell_lights.iff", "client_event_source_dest_map.iff",
    "space_preload.iff", "override.cfg",
)]

best = {}  # entry name -> (tre path, entry)
for t in sorted(glob.glob(os.path.join(TRE_DIR, "*.tre"))):
    try:
        ents = trelist.read_tre(t)
    except Exception:
        continue
    if not ents:
        continue
    index = {e[0].lower().replace("\\", "/"): e for e in ents}
    for name, _dest in WANTED:
        if name in index:
            best[name] = (t, index[name])

missing = 0
for name, dest in WANTED:
    if name not in best:
        print("NOT IN TREs: %s" % name)
        missing += 1
        continue
    t, entry = best[name]
    data = trelist.extract(t, entry)
    out = os.path.join(ROOT, dest.replace("/", os.sep))
    d = os.path.dirname(out)
    if not os.path.isdir(d):
        os.makedirs(d)
    io.open(out, "wb").write(data)
    print("%-52s %8d bytes  <- %s" % (dest, len(data), os.path.basename(t)))

if missing:
    sys.exit("%d wanted entries not found in any TRE" % missing)
