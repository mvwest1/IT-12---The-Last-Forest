"""THE LAST FOREST - static project checks (no Godot needed).
Run from the project root:  python tests/static_check.py
Checks:
  1. every res:// path in scenes/resources/scripts exists with EXACT letter case
     (Windows exports are case-sensitive inside the .pck even though Windows is not)
  2. every translation key has non-empty English AND Filipino text
  3. every key used in code/scenes (SIGN_, PROMPT_, TIP_, ...) exists in a CSV
  4. each stage has enough seeds (starting + on the ground) for its planting zones
"""
import csv, glob, os, re, sys

ROOT = os.getcwd()
problems = []


def rel(p):
    return os.path.relpath(p, ROOT).replace(os.sep, "/")


def exists_exact(path):
    parts = path.split("/")
    cur = ROOT
    for part in parts:
        try:
            names = os.listdir(cur)
        except (NotADirectoryError, FileNotFoundError):
            return False
        if part not in names:
            return False
        cur = os.path.join(cur, part)
    return True


# 1. res:// paths --------------------------------------------------------------
text_files = []
for ext in ("tscn", "tres", "gd", "cfg", "godot"):
    text_files += glob.glob(os.path.join(ROOT, "**", "*." + ext), recursive=True)
text_files = [f for f in text_files if "/.godot/" not in f and "/addons/ziva_agent/" not in f]
path_re = re.compile(r'res://([^"\'\s\)\]]+)')
checked = 0
for f in text_files:
    for m in path_re.finditer(open(f, encoding="utf-8", errors="replace").read()):
        p = m.group(1).split("::")[0]
        if "%" in p or "{" in p or p.endswith("/") or "*" in p:
            continue  # format strings / folders / patterns
        checked += 1
        if not exists_exact(p):
            problems.append("missing or wrong-case path res://%s  (in %s)" % (p, rel(f)))

# 2. translations complete -------------------------------------------------------
keys = {}
for f in glob.glob(os.path.join(ROOT, "the_last_forest/data/translations/*.csv")):
    with open(f, encoding="utf-8") as fh:
        rows = list(csv.reader(fh))
    header = rows[0]
    for row in rows[1:]:
        if not row or not row[0].strip():
            continue
        key = row[0].strip()
        if key in keys:
            problems.append("translation key %s defined twice (%s and %s)" % (key, keys[key], rel(f)))
        keys[key] = rel(f)
        for i, lang in enumerate(header[1:], start=1):
            if i >= len(row) or not row[i].strip():
                problems.append("translation %s has no %s text (%s)" % (key, lang, rel(f)))

# 3. keys used in code exist -----------------------------------------------------
key_re = re.compile(r'"((?:SIGN|PROMPT|TIP|OBJ|STAGE|GATE|QUIZ|HUD|JOURNAL|UI|LOGIN|MENU|TEACHER|CLEAR|FACT|PAUSE)_[A-Z0-9_]+)"')
used = set()
for f in text_files:
    if not f.endswith((".gd", ".tscn", ".tres")):
        continue
    for m in key_re.finditer(open(f, encoding="utf-8", errors="replace").read()):
        k = m.group(1)
        if k.endswith("_"):
            continue  # prefix used to build a key, e.g. "STAGE_%d_TITLE"
        used.add((k, rel(f)))
for k, where in sorted(used):
    if k not in keys:
        problems.append("key %s used in %s but not in any translation CSV" % (k, where))

# 4. seeds per stage -------------------------------------------------------------
for i in range(1, 5):
    scene = open(os.path.join(ROOT, "the_last_forest/scenes/stage_%d.tscn" % i)).read()
    data_path = re.search(r'path="res://(the_last_forest/stage/stages/[^"]+)" id="data"', scene).group(1)
    data = open(os.path.join(ROOT, data_path)).read()
    start = int(re.search(r"starting_seeds = (\d+)", data).group(1))
    zones = len(re.findall(r'parent="PlantingZones"', scene))
    seeds = len(re.findall(r'parent="Seeds"', scene))
    if start + seeds < zones:
        problems.append("stage %d: %d zones but only %d seeds available" % (i, zones, start + seeds))
    print("stage %d: %d planting zones, %d seeds (%d at start + %d to find)" % (i, zones, start + seeds, start, seeds))

print("checked %d res:// references, %d translation keys, %d key uses" % (checked, len(keys), len(used)))
if problems:
    print("\nPROBLEMS (%d):" % len(problems))
    for p in problems:
        print("  - " + p)
    sys.exit(1)
print("STATIC CHECK OK")
