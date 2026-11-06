#!/usr/bin/env python3
"""Screenshots of the first hostile encounter (needs a display).
  xvfb-run -a -s "-screen 0 2600x1200x24" python3 tools/shots_encounter.py docs/screenshots/encounter"""
import os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hs_driver import Instance
OUT = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else "docs/screenshots/encounter")
os.makedirs(OUT, exist_ok=True)
EID = "enemy_scrapper_01"
g = Instance("shots_enc", headless=False, extra_args=["--rendering-driver", "opengl3"])
g.wipe(); g.start()
def shot(name):
    r = g.cmd(f"screenshot {OUT}/{name}.png"); print(name, r["ok"], r["error"])
def en():
    return g.state()["game"]["enemies"][EID]
try:
    g.cmd("window 1600 900"); g.cmd("new 1"); g.cmd("wait 1")
    ep = en()["pos"]
    g.cmd(f"set_mech {ep[0] - 700} {ep[1] - 80} 90"); g.cmd("setting zoom 0.85"); g.cmd("wait 1.5")
    shot("e01_enemy_on_patrol")
    g.cmd("debug heat 25"); g.cmd(f"set_mech {ep[0] - 430} {ep[1]} 90")
    for _ in range(40):   # wait for a visible wind-up
        st = g.state()
        if st["game"]["enemies"][EID]["ai"] == "engage" and any(True for _ in [0]):
            break
        g.cmd("wait 0.25")
    for _ in range(60):
        g.cmd("wait 0.1")
        if g.state()["notices"][-1:] and False:
            break
        # windup visible when telegraph active: sample screenshots periodically
    shot("e02_engaged_telegraph_or_shot")
    g.cmd("wait 1.1"); shot("e03_enemy_shot_in_flight")
    ep = en()["pos"]
    g.cmd(f"set_enemy {ep[0]} {ep[1]} 270 engage"); g.cmd(f"set_mech {ep[0] + 340} {ep[1] + 60} 270")
    g.cmd("aim_enemy 0 58"); g.cmd("fire_for 0.9 cooling")
    shot("e04_player_fire_cooling_hit")
    g.cmd("fire_for 2.5 cooling"); g.cmd("wait 0.4")
    shot("e05_enemy_damaged_hot")
    for _ in range(8):
        if en()["ai"] == "wreck":
            break
        g.cmd("fire_for 2 body")
    g.cmd("wait 1.5"); shot("e06_enemy_wreck")
    g.cmd("debug heat -60"); g.cmd("wait 0.5")
    g.cmd("set_mech 2220 1300 180"); g.cmd("drive_to 2220 1640 20"); g.cmd("stop"); g.cmd("wait 1.5")
    shot("e07_parked_in_awning_shade")
    g.cmd("interact"); g.cmd("wait 0.3")
    wp = en()["pos"]
    g.cmd(f"walk_to {wp[0] - 90} {wp[1]} 40"); g.cmd("setting zoom 1.2"); g.cmd("interact"); g.cmd("wait 1.8")
    shot("e08_stripping_the_wreck")
    g.cmd("wait_task"); g.cmd("wait 0.5"); shot("e09_wreck_salvaged")
    g.cmd("setting zoom 1.0")
finally:
    g.quit()
