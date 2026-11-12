#!/usr/bin/env python3
"""Screenshots of the Continental Journey (needs a display):
  xvfb-run -a -s "-screen 0 2600x1200x24" python3 tools/shots_journey.py docs/screenshots/journey"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hs_driver import Instance
OUT = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else "docs/screenshots/journey")
os.makedirs(OUT, exist_ok=True)
g = Instance("shots_cj", headless=False, extra_args=["--rendering-driver", "opengl3"])
g.wipe(); g.start()


def shot(name):
    r = g.cmd(f"screenshot {OUT}/{name}.png"); print(name, r["ok"], r["error"])


try:
    g.cmd("window 1600 900")
    g.cmd("setting show_tutorial false")
    g.cmd("wait 1.0")
    shot("j01_main_menu")
    g.cmd("new 1"); g.cmd("wait 1.5")
    shot("j02_ersthafen_settlement_safe_zone")
    g.cmd("devx money 2000"); g.cmd("ui garage on"); g.cmd("wait 0.3")
    g.cmd("click_garage Tab_upgrades"); g.cmd("wait 0.3")
    shot("j03_eisenwolf_workshop_upgrades")
    g.cmd("ui garage off")
    g.cmd("map on"); g.cmd("map select kaltbrunn"); g.cmd("wait 0.3")
    shot("j04_continental_map")
    g.cmd("map off")
    g.cmd("travel taubecken force"); g.cmd("wait 1.0")
    g.cmd("set_mech 1500 5300 120"); g.cmd("wait 1.5")
    shot("j05_taubecken_minimap_anomaly_danger")
    g.cmd("set_mech 2050 5520 60"); g.cmd("wait 1.2")
    shot("j06_abandoned_expedition_site")
    g.cmd("set_mech 300 2100 90"); g.cmd("drive 1 0.15 2.0")
    shot("j07_driving_hills_hillshade")
    g.cmd("travel rostfeld force"); g.cmd("wait 1.5")
    shot("j08_rostfeld_territory")
    g.cmd("travel stahlheim force"); g.cmd("wait 1.5")
    shot("j09_stahlheim_cleared")
finally:
    g.quit()
