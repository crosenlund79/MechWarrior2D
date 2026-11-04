#!/usr/bin/env python3
"""Checks that every .gd/.py script is listed in both script guides.
  python3 tools/check_script_guides.py          check (exit 1 on mismatch)
  python3 tools/check_script_guides.py --write  regenerate both guides from tools/guide_rows.py"""
import os, sys, glob
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib, guide_rows
importlib.reload(guide_rows)
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EN = os.path.join(ROOT, "docs/guides/SCRIPT_GUIDE_EN.md")
DA = os.path.join(ROOT, "docs/guides/SCRIPT_GUIDE_DA.md")
scripts = sorted(os.path.relpath(p, ROOT) for pat in ("src/**/*.gd", "tests/*.gd", "tools/**/*.py") for p in glob.glob(os.path.join(ROOT, pat), recursive=True))
listed = {r[0] for r in guide_rows.ROWS}
if "--write" in sys.argv:
    for path, title, intro, col in ((EN, "Script guide (English)", "What each script does. Keep in sync with `tools/guide_rows.py`, then run `python3 tools/check_script_guides.py --write`.", 1),
                                     (DA, "Scriptguide (dansk)", "Hvad hvert script gør. Hold den i trit med `tools/guide_rows.py`, og kør `python3 tools/check_script_guides.py --write`.", 2)):
        lines = [f"# {title}", "", intro, "", "| Script | " + ("Purpose" if col == 1 else "Formål") + " |", "|---|---|"]
        lines += [f"| `{r[0]}` | {r[col]} |" for r in guide_rows.ROWS]
        open(path, "w").write("\n".join(lines) + "\n")
missing = [s for s in scripts if s not in listed]
stale = [s for s in listed if s not in scripts]
for path in (EN, DA):
    text = open(path).read() if os.path.exists(path) else ""
    missing += [f"{os.path.basename(path)}: {s}" for s in scripts if f"`{s}`" not in text]
if missing or stale:
    print("missing:", missing, "\nstale:", stale); sys.exit(1)
print(f"script guides OK ({len(scripts)} scripts)")
