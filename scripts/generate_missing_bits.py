"""Generate the missing-bits payload repo (INSTALLER-DESIGN.md).

Selects every loose file the installer cannot obtain from another source and
copies it into a git-ready payload tree:

  include: sys.client  in_tre==0, not serverdata-covered*, not video/
           sys.shared  in_tre==0, not serverdata-covered*, minus rebuildable
                       (object/, datatables/, misc/ compile from dsrc)
           sys.server  in_tre==0, script/ + misc/ only (object/ and
                       datatables/ rebuild from dsrc with proven tools;
                       script/ needs javac [off by default] and misc/ CRC
                       generation is not yet proven -> ship both)
           extras:     .planning/inventory/erusman-extras/data/** (30 files
                       absent from the SOE tree, incl. the sys.shared space
                       terrain sources) and the SOE exe/win32 dictionaries +
                       godclient_favorites.xml
  * covered = same relname in SWG-Source/serverdata WITH the same size
    (name-only matches ship - serverdata's copy differs from the validated
    SOE tree copy).

Inputs: .planning/inventory/data-manifest.csv (regenerate with
not_in_tres_inventory.py), .planning/inventory/serverdata-tree.txt (GitHub
tree listing, 'path|size' per line), the SOE loose tree.

Output: <out>/data/sku.0/... + <out>/exe/win32/... + payload-manifest.csv +
README.md, git init + initial commit.

Usage: python generate_missing_bits.py [out_dir]   (default: the
tools-payload/ submodule next to this repo's root)
"""
import os, sys, csv, io, shutil, subprocess, collections

HERE = os.path.dirname(os.path.abspath(__file__))
INV = os.path.join(os.path.dirname(HERE), ".planning", "inventory")
SOE = r"D:\SWG All Tools Working\swg\current"
SOE_DATA = os.path.join(SOE, "data")
SOE_EXE = os.path.join(SOE, "exe", "win32")
EXTRAS = os.path.join(INV, "erusman-extras", "data")
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(HERE), "tools-payload")

EXE_EXTRAS = ["SwgConversationEditor_medium.dct", "SwgConversationEditor_user.dct",
              "godclient_favorites.xml"]

def load_serverdata():
    sd = {}
    for line in io.open(os.path.join(INV, "serverdata-tree.txt"), encoding="utf-8"):
        line = line.strip()
        if not line:
            continue
        p, s = line.rsplit("|", 1)
        sd[p.lower()] = int(s)
    return sd

def main():
    sd = load_serverdata()
    rows = list(csv.DictReader(open(os.path.join(INV, "data-manifest.csv"), encoding="utf-8")))
    selected = []   # (root, relname, size, reason)
    for r in rows:
        if r["in_tre"] != "0":
            continue
        root, rel, size = r["root"], r["relname"], int(r["size"])
        sysdir = root.split("/")[1]
        top = rel.split("/", 1)[0]
        covered = sd.get(rel) == size
        if sysdir == "sys.client":
            if covered or top == "video":
                continue
            selected.append((root, rel, size, "client"))
        elif sysdir == "sys.shared":
            if covered or top in ("object", "datatables", "misc"):
                continue
            selected.append((root, rel, size, "shared-residue"))
        elif sysdir == "sys.server":
            if top in ("script", "misc"):
                selected.append((root, rel, size, "server-" + top))

    os.makedirs(OUT, exist_ok=True)
    stats = collections.Counter()
    stats_sz = collections.Counter()
    manifest = []
    for root, rel, size, reason in selected:
        src = os.path.join(SOE_DATA, root.replace("/", os.sep), rel.replace("/", os.sep))
        dst = os.path.join(OUT, "data", root.replace("/", os.sep), rel.replace("/", os.sep))
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(src, dst)
        stats[reason] += 1
        stats_sz[reason] += size
        manifest.append(("data/%s/%s" % (root, rel), size, reason))

    # extras: erusman files (already in data/sku.0 layout under EXTRAS)
    for dirpath, _dirs, files in os.walk(EXTRAS):
        for f in files:
            src = os.path.join(dirpath, f)
            rel = os.path.relpath(src, EXTRAS)
            dst = os.path.join(OUT, "data", rel)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copy2(src, dst)
            stats["erusman-extra"] += 1
            stats_sz["erusman-extra"] += os.path.getsize(src)
            manifest.append(("data/" + rel.replace(os.sep, "/"), os.path.getsize(src), "erusman-extra"))
    # extras: exe/win32
    for f in EXE_EXTRAS:
        src = os.path.join(SOE_EXE, f)
        dst = os.path.join(OUT, "exe", "win32", f)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(src, dst)
        stats["exe-extra"] += 1
        stats_sz["exe-extra"] += os.path.getsize(src)
        manifest.append(("exe/win32/" + f, os.path.getsize(src), "exe-extra"))

    with open(os.path.join(OUT, "payload-manifest.csv"), "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(["path", "size", "reason"])
        for row in sorted(manifest):
            w.writerow(row)

    # Seed a stub README only on first generation; the repo's real README is
    # hand-maintained and must survive a regen.
    readme = os.path.join(OUT, "README.md")
    if not os.path.exists(readme):
        lines = ["# SWG tools payload — the \"missing bits\"", "",
                 "Loose data the SWG tools need that exists in no TRE, no other",
                 "git repo (SWG-Source/dsrc, SWG-Source/serverdata), and cannot be",
                 "rebuilt from sources. Generated by client-tools",
                 "scripts/generate_missing_bits.py; selection rationale in",
                 "client-tools .planning/inventory/PAYLOAD-MANIFEST.md.", "",
                 "Layout mirrors the SOE tree: data/sku.0/sys.*/{built,compiled}/game/...", ""]
        for k, c in stats.most_common():
            lines.append("- %-16s %6d files  %8.1f MB" % (k, c, stats_sz[k] / 1048576.0))
        lines.append("")
        lines.append("Total: %d files, %.1f MB" % (sum(stats.values()), sum(stats_sz.values()) / 1048576.0))
        io.open(readme, "w", encoding="utf-8").write("\n".join(lines) + "\n")

    for k, c in stats.most_common():
        print("%-16s %6d files  %8.1f MB" % (k, c, stats_sz[k] / 1048576.0))
    print("TOTAL %d files, %.1f MB -> %s" % (sum(stats.values()), sum(stats_sz.values()) / 1048576.0, OUT))

    if not os.path.isdir(os.path.join(OUT, ".git")):
        subprocess.run(["git", "init", "-b", "main"], cwd=OUT, check=True)
    subprocess.run(["git", "add", "-A"], cwd=OUT, check=True)
    subprocess.run(["git", "commit", "-m", "Initial payload from generate_missing_bits.py"],
                   cwd=OUT, check=False)

if __name__ == "__main__":
    main()
