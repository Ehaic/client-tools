"""Generate object_template_crc_string_table for a rebuilt SOE-shaped root.

Recipe from swg-main/utils/build_object_template_crc_string_tables.py:
walk the COMPILED object trees for .iff names (relative, object/...):
  client table = shared object/ + server object/creature/player
  server table = server object/ + client-table set, deduped
CRC encoding via BuildQuestCrcStringTables.ps1 generic mode (byte-faithful
port of SOE's buildCrcStringTable.pl, proven on the quest table).

Placement (matches the SOE reference tree): the split tables land in
sys.{client,server}/built/game/misc; the SERVER table also lands in BOTH
sys.client and sys.server compiled/game/misc — in the SOE tree those two
compiled copies are byte-identical to each other (one merged table) and
that is what the editors read (e.g. ShipComponentEditor's
serverTemplateCrcStringTable key).

Run AFTER the template compile (the walk enumerates compiled .iff output).

Usage: python build_object_crc_tables.py [root]   (default C:/swg/current)
"""
import io, os, shutil, subprocess, sys, tempfile

ROOT = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else r"C:\swg\current")
EXE = os.path.join(ROOT, "exe", "win32")
PS1 = os.path.join(EXE, "BuildQuestCrcStringTables.ps1")
DATA = os.path.join(ROOT, "data", "sku.0")

def read_objects(objectdir):
    names = []
    base = os.path.dirname(objectdir)  # .../compiled/game
    for dirname, _dirs, files in os.walk(objectdir):
        for f in files:
            if f.lower().endswith(".iff"):
                rel = os.path.relpath(os.path.join(dirname, f), base)
                names.append(rel.replace(os.sep, "/"))
    return names

def build(names, out_iff, out_tab):
    for p in (out_iff, out_tab):
        d = os.path.dirname(p)
        if not os.path.isdir(d):
            os.makedirs(d)
    fd, tmp = tempfile.mkstemp(suffix=".txt")
    with io.open(fd, "w", encoding="ascii") as fh:
        fh.write("\n".join(sorted(set(names))) + "\n")
    try:
        r = subprocess.run(
            ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", PS1,
             "-InputFile", tmp, "-OutputIff", out_iff, "-OutputTab", out_tab],
            cwd=EXE, capture_output=True, text=True)
        if r.returncode != 0:
            sys.exit("CRC build failed for %s:\n%s%s" % (out_iff, r.stdout, r.stderr))
        print("%s: %d names" % (os.path.relpath(out_iff, ROOT), len(set(names))))
    finally:
        os.remove(tmp)

server_objs = read_objects(os.path.join(DATA, "sys.server", "compiled", "game", "object"))
shared_objs = read_objects(os.path.join(DATA, "sys.shared", "compiled", "game", "object"))
player_objs = [n for n in server_objs if n.startswith("object/creature/player/")]

client_set = shared_objs + player_objs
server_set = server_objs + client_set

def under(side, kind):
    return os.path.join(DATA, side, kind, "game", "misc", "object_template_crc_string_table")

build(client_set, under("sys.client", "built") + ".iff", under("sys.client", "built") + ".tab")
build(server_set, under("sys.server", "built") + ".iff", under("sys.server", "built") + ".tab")
# the editors read the compiled copies; SOE ships the merged (server) table there
shutil.copyfile(under("sys.server", "built") + ".iff", under("sys.server", "compiled") + ".iff")
shutil.copyfile(under("sys.server", "built") + ".iff", under("sys.client", "compiled") + ".iff")
print("compiled/misc copies updated (server table, both sides)")
