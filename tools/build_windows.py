#!/usr/bin/env python3
"""Builds the Windows package: export/Thawborn.exe + .pck (Godot export, needs the
4.7.2 export templates), a portable zip and an NSIS installer (needs makensis).
  python3 tools/build_windows.py      → export/Thawborn-<ver>-windows.zip, export/Thawborn-<ver>-setup.exe"""
import os, re, subprocess, sys, zipfile
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXP = os.path.join(ROOT, "export")
ver = re.search(r'config/version="([^"]+)"', open(os.path.join(ROOT, "project.godot")).read()).group(1)
os.makedirs(EXP, exist_ok=True)
r = subprocess.run(["godot", "--headless", "--path", ROOT, "--export-release", "Windows Desktop", os.path.join(EXP, "Thawborn.exe")],
                   capture_output=True, text=True)
for f in ("Thawborn.exe", "Thawborn.pck"):
    if not os.path.exists(os.path.join(EXP, f)):
        sys.exit("export failed:\n" + r.stdout[-2000:] + r.stderr[-2000:])
open(os.path.join(EXP, "README.txt"), "w", newline="\r\n").write(
    f"THAWBORN {ver} (prototype)\n\nRun Thawborn.exe. Press H in game for the field guide, F10 for the developer menu.\n"
    "Saves and settings: %APPDATA%\\Thawborn (old Heat Signature saves are copied on first start).\n"
    "Your own art/sound: put files into the 'overrides' folder next to Thawborn.exe, mirroring\n"
    "assets/templates (see docs/guides/ASSET_REPLACEMENT.md in the source).\n")
zp = os.path.join(EXP, f"Thawborn-{ver}-windows.zip")
with zipfile.ZipFile(zp, "w", zipfile.ZIP_DEFLATED) as z:
    for f in ("Thawborn.exe", "Thawborn.pck", "README.txt"):
        z.write(os.path.join(EXP, f), f"Thawborn/{f}")
    z.writestr("Thawborn/overrides/PUT_YOUR_ART_HERE.txt", "Same folder layout as assets/templates; same file name without 'template_'.\r\n")
print("zip", zp, os.path.getsize(zp))
if subprocess.run(["which", "makensis"], capture_output=True).returncode == 0:
    r = subprocess.run(["makensis", f"-DVERSION={ver}", os.path.join(ROOT, "tools/installer/thawborn.nsi")], capture_output=True, text=True)
    out = os.path.join(EXP, f"Thawborn-{ver}-setup.exe")
    print("installer", out if r.returncode == 0 else "FAILED:\n" + r.stdout[-1500:])
else:
    print("makensis not found: installer skipped (zip is complete)")
