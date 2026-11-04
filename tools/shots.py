#!/usr/bin/env python3
"""Rendered screenshots of the running game (needs a display: xvfb-run -s '-screen 0 1920x1080x24').
  python3 tools/shots.py <out_dir> [prefix]"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hs_driver import Instance
OUT = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else "docs/screenshots")
P = sys.argv[2] if len(sys.argv) > 2 else "s"
os.makedirs(OUT, exist_ok=True)
g = Instance("shots", headless=False, extra_args=["--rendering-driver", "opengl3"])
g.wipe(); g.start()
def shot(name):
    r = g.cmd(f"screenshot {OUT}/{P}_{name}.png"); print(name, r["ok"], r["error"])
try:
    g.cmd("window 1600 900")
    shot("01_main_menu")
    g.cmd("new 1"); g.cmd("wait 1.0")
    shot("02_start_in_shelter")
    g.cmd("drive_to 1500 1160 30"); g.cmd("drive 1 0 1.2")
    shot("03_driving_track")
    g.cmd("drive_to 2520 1100 40")
    for _ in range(20):
        st = g.cmd("drive 1 1 3")["state"]
        if st["game"]["stats"]["overheats"] > 0:
            break
    g.cmd("wait 0.6")
    shot("04_overheat_shutdown")
    g.cmd("stop"); r = g.cmd("interact")
    p = r["state"]["game"]["pilot"]["pos"]
    g.cmd(f"walk_to {p[0]} 1210 10"); g.cmd("walk_to 2760 1210 20"); g.cmd("walk_to 2760 1100 20")
    shot("05_on_foot_at_salvage")
    g.cmd("interact"); g.cmd("wait 0.8")
    shot("06_salvaging")
    g.cmd("wait_task")
    mp = g.state()["game"]["mech"]["pos"]
    g.cmd("walk_to 2760 1210 20"); g.cmd(f"walk_to {mp[0]} {mp[1] + 140} 20")
    g.cmd("service"); g.cmd("wait 1.5")
    shot("07_repairing")
    g.cmd("wait_task"); g.cmd("ui dev on")
    shot("08_repaired_dev_overlay")
    g.cmd("ui dev off"); g.cmd("interact")
    g.cmd("setting zoom 0.6"); g.cmd("wait 1.5")
    shot("09_zoomed_out")
    g.cmd("setting zoom 1.0")
    g.cmd("ui pause on"); shot("10_pause"); g.cmd("ui pause off")
    g.cmd("ui settings on"); shot("11_settings"); g.cmd("ui settings off")
    g.cmd("window 2560 1080"); g.cmd("wait 1.0")
    shot("12_ultrawide")
finally:
    g.quit()
