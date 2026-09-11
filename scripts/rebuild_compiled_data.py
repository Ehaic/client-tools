"""Rebuild the compiled server/shared data from the dsrc clone.

Prototype of the installer's rebuild-at-install step (INSTALLER-DESIGN.md,
PAYLOAD-MANIFEST.md rebuild section). Compiles every dsrc .tpf via
TemplateCompiler (batched: it accepts many files per invocation) and every
.tab via DataTableTool (one -i per invocation), both writing to the
dsrc->data mirrored path.

Run order is shared then server, alphabetical within each. NOTE for a fresh
tree (no pre-existing bakes): @base references resolve through the
templateCompiler.cfg TreeFile mount OR by walking up to the base .tpf
source, so ordering has not been proven load-bearing — this trial ran over
an already-populated tree. If a fresh-tree run shows @base failures,
compile base_*.tpf first or run two passes.

Usage: python rebuild_compiled_data.py [root]   (default C:/swg/current)
Writes _rebuild-report.txt + _rebuild-failures.csv into root/exe/win32.
"""
import csv, io, os, subprocess, sys, time
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else r"C:\swg\current")
EXE = os.path.join(ROOT, "exe", "win32")
DSRC = os.path.join(ROOT, "dsrc")
TEMPLATE_COMPILER = os.path.join(EXE, "TemplateCompiler.exe")
DATATABLE_TOOL = os.path.join(EXE, "DataTableTool.exe")
TPF_BATCH = 200
WORKERS = 8

def output_of(src):
    return src.replace(os.sep + "dsrc" + os.sep, os.sep + "data" + os.sep).rsplit(".", 1)[0] + ".iff"

def gather(ext):
    out, skipped = [], 0
    for base, _dirs, files in os.walk(DSRC):
        for f in files:
            if f.lower().endswith(ext):
                src = os.path.join(base, f)
                # idempotent/resumable: skip sources already compiled this run
                try:
                    if os.path.getmtime(output_of(src)) >= os.path.getmtime(src):
                        skipped += 1
                        continue
                except OSError:
                    pass
                out.append(src)
    if skipped:
        print("%s: skipping %d already-current outputs" % (ext, skipped))
    # shared before server, alphabetical within each
    out.sort(key=lambda p: ("sys.server" in p, p.lower()))
    return out

failures = []

def run(cmd, key, cwd=EXE):
    r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    # DataTableTool exits 0 even on "ERROR: The output file is not available
    # for writing" — treat any ERROR line as failure, not just the exit code
    bad = r.returncode != 0 or "ERROR" in r.stdout or "ERROR" in r.stderr
    if bad:
        failures.append((key, r.returncode, (r.stdout + r.stderr)[-400:].replace("\n", " | ")))
    return 0 if not bad else (r.returncode or 1)

def mirror_output_dirs():
    # Neither compiler creates missing output directories (both fail silently
    # when one is absent — DataTableTool even exits 0). Pre-create the whole
    # dsrc->data mirror so writes always land.
    made = 0
    for base, _dirs, files in os.walk(DSRC):
        if not any(f.lower().endswith((".tpf", ".tab")) for f in files):
            continue
        out = base.replace(os.sep + "dsrc" + os.sep, os.sep + "data" + os.sep)
        if not os.path.isdir(out):
            os.makedirs(out)
            made += 1
    print("output dirs: %d created" % made)

def tab_cwd(tab):
    # DataTableTool loads no cfg; .tab include references (datatables/include/
    # *.iff) resolve relative to the CWD, so run it from the source's own
    # side's compiled/game dir on the DATA side.
    data = tab.replace(os.sep + "dsrc" + os.sep, os.sep + "data" + os.sep)
    return data.split(os.sep + "game" + os.sep)[0] + os.sep + "game"

def compile_tpf_batch(batch):
    # a bad source aborts the whole invocation, so on batch failure retry the
    # files individually (recording only the per-file failures, not the batch)
    r = subprocess.run([TEMPLATE_COMPILER, "-compile"] + batch, cwd=EXE, capture_output=True, text=True)
    if r.returncode != 0:
        for f in batch:
            run([TEMPLATE_COMPILER, "-compile", f], f)

def main():
    mirror_output_dirs()
    tabs = [t for t in gather(".tab") if not t.endswith("crc_string_table.tab")]
    # datatables/include/* are referenced by other .tab sources at compile
    # time; build them before the parallel pool or the referers race them
    include_tabs = [t for t in tabs if os.sep + "include" + os.sep in t]
    for t in include_tabs:
        run([DATATABLE_TOOL, "-i", t], t, cwd=tab_cwd(t))
    report = []
    for label, files, runner in (
        ("tpf/TemplateCompiler", gather(".tpf"),
         lambda batch: compile_tpf_batch(batch)),
        ("tab/DataTableTool", [t for t in tabs if t not in include_tabs],
         lambda one: run([DATATABLE_TOOL, "-i", one[0]], one[0], cwd=tab_cwd(one[0]))),
    ):
        size = TPF_BATCH if "tpf" in label else 1
        batches = [files[i:i + size] for i in range(0, len(files), size)]
        t0 = time.time()
        with ThreadPoolExecutor(max_workers=WORKERS) as pool:
            list(pool.map(runner, batches))
        dt = time.time() - t0
        line = "%s: %d files in %d invocations, %.1f min (%d failures so far)" % (
            label, len(files), len(batches), dt / 60.0, len(failures))
        print(line)
        report.append(line)

    with io.open(os.path.join(EXE, "_rebuild-failures.csv"), "w", encoding="utf-8", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["key", "exit", "tail"])
        for row in failures:
            w.writerow(row)
    report.append("total failures: %d (see _rebuild-failures.csv)" % len(failures))
    io.open(os.path.join(EXE, "_rebuild-report.txt"), "w", encoding="utf-8").write("\n".join(report) + "\n")
    print(report[-1])

if __name__ == "__main__":
    main()
