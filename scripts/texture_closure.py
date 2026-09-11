"""Texture reference-closure walk (TODO item 4): which loose-only textures are live?

Corpus = every loose sys.client/sys.shared/sys.server file we would ship
(not-in-TRE or serverdata-covered - in practice ALL loose files, since
serverdata mirrors the loose tree), excluding media/texture payload itself.
String-scan for .dds references; classify the loose-only textures:

  referenced   - full path 'texture/x.dds' (or x.dds basename-with-ext) seen
  ui-basename  - basename sans extension seen (UI files reference source
                 images without path/extension)
  pattern      - lives under a directory a %s-composed reference points into
  font         - texture/font/* (composed by the font system; live wholesale)
  UNREFERENCED - nothing names it

Outputs .planning/inventory/texture-closure.csv + prints a summary.
"""
import os, re, csv, sys, collections

SOE = r"D:\SWG All Tools Working\swg\current\data\sku.0"
MANIFEST = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                        ".planning", "inventory", "data-manifest.csv")
OUT = os.path.join(os.path.dirname(MANIFEST), "texture-closure.csv")

SKIP_DIRS = ("texture/", "sample/", "music/", "player_music/", "voice/", "video/")
SKIP_EXT = (".dds", ".wav", ".mp3", ".bik", ".tga", ".psd", ".mdmp")

rows = list(csv.DictReader(open(MANIFEST, encoding="utf-8")))
loose_only = {}   # relname -> size, the 8,884 targets
for r in rows:
    if "sys.client" in r["root"] and r["in_tre"] == "0" and r["relname"].startswith("texture/"):
        loose_only[r["relname"]] = int(r["size"])
print("targets: %d loose-only textures" % len(loose_only))

# lookup sets
full_names = set(loose_only)                                  # texture/foo.dds
base_ext = {}                                                 # foo.dds -> relname(s)
base_noext = {}                                               # foo -> relname(s)
for n in loose_only:
    b = n.rsplit("/", 1)[-1]
    base_ext.setdefault(b, []).append(n)
    base_noext.setdefault(b[:-4], []).append(n)

hit_full = set()
hit_base = set()
hit_noext = set()
pattern_dirs = set()
pat_string = re.compile(rb"[ -~]{4,}")

scanned = files_scanned = 0
for sysdir in ("sys.client", "sys.server", "sys.shared"):
    for kind in ("built", "compiled"):
        base = os.path.join(SOE, sysdir, kind, "game")
        if not os.path.isdir(base):
            continue
        for dirpath, dirs, files in os.walk(base):
            rel_dir = os.path.relpath(dirpath, base).replace("\\", "/").lower()
            if any((rel_dir + "/").startswith(s) for s in SKIP_DIRS):
                dirs[:] = []
                continue
            for f in files:
                if f.lower().endswith(SKIP_EXT):
                    continue
                p = os.path.join(dirpath, f)
                try:
                    data = open(p, "rb").read()
                except OSError:
                    continue
                files_scanned += 1
                scanned += len(data)
                for m in pat_string.findall(data):
                    s = m.decode("latin-1").lower().replace("\\", "/")
                    if ".dds" in s:
                        if "%" in s:
                            # composed name: mark the directory it points into
                            d = s.rsplit("/", 1)[0] if "/" in s else ""
                            if d.startswith("texture"):
                                pattern_dirs.add(d.split("%", 1)[0].rstrip("/"))
                            continue
                        # trim to the path tail ending in .dds
                        i = s.find(".dds")
                        cand = s[: i + 4]
                        # strip any leading garbage before a plausible path char
                        cand = re.split(r"[^a-z0-9_/\.\-]", cand)[-1]
                        if cand in full_names:
                            hit_full.add(cand)
                        else:
                            b = cand.rsplit("/", 1)[-1]
                            for t in base_ext.get(b, ()):
                                hit_base.add(t)
                    else:
                        for t in base_noext.get(s, ()):
                            hit_noext.add(t)

print("scanned %d files / %.1f MB" % (files_scanned, scanned / 1048576.0))

def classify(n):
    if n in hit_full:
        return "referenced-full"
    if n in hit_base:
        return "referenced-basename"
    if n in hit_noext:
        return "referenced-ui-noext"
    if n.startswith("texture/font/"):
        return "font-live"
    d = n.rsplit("/", 1)[0]
    for pd in pattern_dirs:
        if d == pd or d.startswith(pd + "/") or n.startswith(pd):
            return "pattern-dir"
    return "UNREFERENCED"

stats = collections.Counter()
size_stats = collections.Counter()
with open(OUT, "w", newline="", encoding="utf-8") as fh:
    w = csv.writer(fh)
    w.writerow(["relname", "size", "verdict"])
    for n in sorted(loose_only):
        v = classify(n)
        stats[v] += 1
        size_stats[v] += loose_only[n]
        w.writerow([n, loose_only[n], v])

print("pattern dirs seen:", sorted(pattern_dirs))
for v, c in stats.most_common():
    print("%-22s %6d files %9.1f MB" % (v, c, size_stats[v] / 1048576.0))
