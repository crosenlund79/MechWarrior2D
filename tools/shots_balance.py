#!/usr/bin/env python3
"""Screenshots for the movement + heat rebalance (needs a display).
  xvfb-run -a -s "-screen 0 2600x1200x24" python3 tools/shots_balance.py docs/screenshots/balance"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hs_driver import Instance
OUT = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else "docs/screenshots/balance")
os.makedirs(OUT, exist_ok=True)
g = Instance("shots_bal", headless=False, extra_args=["--rendering-driver", "opengl3"])
g.wipe(); g.start()
def shot(n):
    r = g.cmd(f"screenshot {OUT}/{n}.png"); print(n, r["ok"])
try:
    g.cmd("window 1600 900"); g.cmd("new 1"); g.cmd("dev toggle aggression"); g.cmd("wait 1")
    g.cmd("drive_to 830 2000 30"); g.cmd("drive_to 770 2600 30"); g.cmd("drive 1 0.6 0.8"); shot("b01_full_speed_turning_after_long_drive")
    g.cmd("set_mech 300 2100 90"); g.cmd("aim 300 1600"); g.cmd("wait 0.6")
    for k in range(7):
        g.cmd("fire_for 3")
    shot("b02_after_20s_sustained_fire_warning")
    g.cmd("dev weather start 1.0"); g.cmd("wait 9"); g.cmd("drive 1 0.2 4"); shot("b03_sandstorm_cruising")
finally:
    g.quit()
