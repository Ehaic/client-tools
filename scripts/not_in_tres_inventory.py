"""Build the "not in TREs" inventory for the tools installer (TODO item 4).

Walks the SOE loose tree's six data mount roots
(data/sku.0/sys.{client,server,shared}/{built,compiled}/game) plus dsrc/,
computes each file's TreeFile-relative name, and checks membership across
every .tre in the client directory (trelist.py reads both v0005 and v0006).

Outputs, under .planning/inventory/:
    data-manifest.csv   relname,root,size,in_tre,size_match
                        in_tre = comma-free count of TREs holding that name
                        size_match = 1 if ANY holding TRE has the same
                        uncompressed length, else 0 (name-only shadow)
    dsrc-manifest.csv   relname,root,size   (sources; never in TREs)
    summary.txt         per-root and per-top-level-dir rollups

Usage: python not_in_tres_inventory.py [tre_dir] [soe_root] [out_dir]
Defaults match this machine's layout.
"""
import os, sys, csv, glob, collections

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import trelist

TRE_DIR = sys.argv[1] if len(sys.argv) > 1 else r"D:\Code\SWGSource Client v3.0"
SOE_ROOT = sys.argv[2] if len(sys.argv) > 2 else r"D:\SWG All Tools Working\swg\current"
OUT_DIR = sys.argv[3] if len(sys.argv) > 3 else os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))), ".planning", "inventory")


def norm(name):
    return name.replace("\\", "/").lower()


def index_tres(tre_dir):
    """name -> set of uncompressed lengths seen across all TREs; also per-name TRE count."""
    sizes = collections.defaultdict(set)
    count = collections.defaultdict(int)
    tres = sorted(glob.glob(os.path.join(tre_dir, "*.tre")))
    bad = []
    total = 0
    for t in tres:
        try:
            ents = trelist.read_tre(t)
        except Exception as e:
            bad.append("%s: %s" % (os.path.basename(t), e))
            continue
        if ents is None:
            bad.append("%s: not a TRE" % os.path.basename(t))
            continue
        total += len(ents)
        for name, _off, _comp, _clen, length in ents:
            n = norm(name)
            sizes[n].add(length)
            count[n] += 1
    return sizes, count, len(tres), total, bad


def walk_root(base, root_rel):
    """Yield (relname, size) for files under base, relname normalized. Skips VCS dirs."""
    for dirpath, dirs, files in os.walk(base):
        dirs[:] = [d for d in dirs if d not in (".git", ".svn")]
        for f in files:
            full = os.path.join(dirpath, f)
            rel = norm(os.path.relpath(full, base))
            try:
                size = os.path.getsize(full)
            except OSError:
                size = -1
            yield rel, size


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    print("indexing TREs in %s ..." % TRE_DIR)
    tre_sizes, tre_count, n_tres, n_entries, bad = index_tres(TRE_DIR)
    print("  %d TREs, %d entries, %d unique names, %d unreadable"
          % (n_tres, n_entries, len(tre_sizes), len(bad)))
    for b in bad:
        print("  !! %s" % b)

    data_roots = []
    for sysdir in ("sys.client", "sys.server", "sys.shared"):
        for kind in ("built", "compiled"):
            base = os.path.join(SOE_ROOT, "data", "sku.0", sysdir, kind, "game")
            if os.path.isdir(base):
                data_roots.append(("sku.0/%s/%s/game" % (sysdir, kind), base))

    stats = collections.OrderedDict()   # root -> [files, bytes, not_in, not_in_bytes, shadow]
    topdir = collections.defaultdict(lambda: [0, 0])  # top-level dir of NOT-IN files -> [n, bytes]

    data_csv = os.path.join(OUT_DIR, "data-manifest.csv")
    with open(data_csv, "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(["relname", "root", "size", "in_tre", "size_match"])
        for root_rel, base in data_roots:
            st = stats.setdefault(root_rel, [0, 0, 0, 0, 0])
            print("walking %s ..." % root_rel)
            for rel, size in walk_root(base, root_rel):
                in_n = tre_count.get(rel, 0)
                match = 1 if (in_n and size in tre_sizes[rel]) else 0
                w.writerow([rel, root_rel, size, in_n, match])
                st[0] += 1
                st[1] += size
                if in_n == 0:
                    st[2] += 1
                    st[3] += size
                    top = rel.split("/", 1)[0] if "/" in rel else "(root)"
                    topdir[top][0] += 1
                    topdir[top][1] += size
                elif not match:
                    st[4] += 1

    dsrc_csv = os.path.join(OUT_DIR, "dsrc-manifest.csv")
    dsrc_stats = collections.OrderedDict()
    dsrc_base = os.path.join(SOE_ROOT, "dsrc")
    with open(dsrc_csv, "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(["relname", "root", "size"])
        for sub in sorted(os.listdir(dsrc_base)):
            base = os.path.join(dsrc_base, sub)
            if not os.path.isdir(base) or sub in (".git", ".svn"):
                continue
            print("walking dsrc/%s ..." % sub)
            st = dsrc_stats.setdefault("dsrc/" + sub, [0, 0])
            for rel, size in walk_root(base, sub):
                w.writerow([rel, "dsrc/" + sub, size])
                st[0] += 1
                st[1] += size

    lines = []
    lines.append("not-in-TREs inventory  (TREs: %s | loose: %s)" % (TRE_DIR, SOE_ROOT))
    lines.append("%d TREs read, %d entries, %d unique names" % (n_tres, n_entries, len(tre_sizes)))
    lines.append("")
    lines.append("%-38s %9s %11s %9s %11s %8s" % ("data root", "files", "MB", "NOT in", "NOT-in MB", "shadow*"))
    for root_rel, (n, b, nn, nb, sh) in stats.items():
        lines.append("%-38s %9d %11.1f %9d %11.1f %8d"
                     % (root_rel, n, b / 1048576.0, nn, nb / 1048576.0, sh))
    lines.append("* shadow = name IS in a TRE but no TRE copy has the same size")
    lines.append("")
    lines.append("NOT-in-TRE files by top-level dir (all data roots combined):")
    for top, (n, b) in sorted(topdir.items(), key=lambda kv: -kv[1][1]):
        lines.append("  %-28s %9d %11.1f MB" % (top, n, b / 1048576.0))
    lines.append("")
    lines.append("dsrc (sources, never in TREs):")
    for root_rel, (n, b) in dsrc_stats.items():
        lines.append("  %-28s %9d %11.1f MB" % (root_rel, n, b / 1048576.0))

    summary = "\n".join(lines)
    with open(os.path.join(OUT_DIR, "summary.txt"), "w", encoding="utf-8") as fh:
        fh.write(summary + "\n")
    print()
    print(summary)


if __name__ == "__main__":
    main()
