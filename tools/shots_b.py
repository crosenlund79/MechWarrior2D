#!/usr/bin/env python3
"""Phase B screenshots of the illustrated location + the menu backdrop capture.
  xvfb-run -a -s "-screen 0 2600x1200x24" python3 tools/shots_b.py docs/screenshots/phase_b [--backdrop]"""
import os, sys, shutil
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hs_driver import Instance, ROOT
OUT = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("--") else "docs/screenshots/phase_b")
os.makedirs(OUT, exist_ok=True)
g = Instance("shots_b", headless=False, extra_args=["--rendering-driver", "opengl3"])
g.wipe(); g.start()
def shot(name):
    r = g.cmd(f"screenshot {OUT}/{name}.png"); print(name, r["ok"], r["error"])
try:
    g.cmd("window 1600 900")
    g.cmd("new 1"); g.cmd("wait 1.5")
    if "--backdrop" in sys.argv:
        g.cmd("ui hud off"); g.cmd("setting zoom 0.8"); g.cmd("set_mech 1230 1270 75"); g.cmd("wait 2.0")
        dst = os.path.join(ROOT, "assets/templates/ui/template_menu_backdrop.png")
        g.cmd(f"screenshot {dst}"); print("backdrop", dst)
        g.cmd("ui hud on"); g.cmd("setting zoom 1.0")
        sys.exit(0)
    shot("b01_shelter_start")
    g.cmd("ui grade off"); g.cmd("ui hud off"); g.cmd("wait 0.3")
    shot("b02_shelter_no_grade_no_hud")
    g.cmd("ui grade on"); g.cmd("wait 0.3")
    shot("b03_shelter_graded_no_hud")
    g.cmd("ui hud on")
    g.cmd("drive_to 1500 1160 30"); g.cmd("drive 1 0 1.5")
    shot("b04_driving_track_dune_gap")
    g.cmd("drive_to 2520 1100 40")
    for _ in range(20):
        st = g.cmd("drive 1 1 3")["state"]
        if st["game"]["stats"]["overheats"] > 0:
            break
    g.cmd("wait 0.8")
    shot("b05_overheat_shutdown")
    g.cmd("stop"); r = g.cmd("interact")
    p = r["state"]["game"]["pilot"]["pos"]
    g.cmd(f"walk_to {p[0]} 1210 10"); g.cmd("walk_to 2760 1210 20"); g.cmd("walk_to 2760 1100 20")
    shot("b06_on_foot_at_pump_rig")
    g.cmd("interact"); g.cmd("wait_task")
    mp = g.state()["game"]["mech"]["pos"]
    g.cmd("walk_to 2760 1210 20"); g.cmd(f"walk_to {mp[0]} {mp[1] + 140} 20")
    g.cmd("service"); g.cmd("wait 1.5")
    shot("b07_repairing")
    g.cmd("wait_task")
    g.cmd("ui hud off"); g.cmd("setting zoom 1.9"); g.cmd("wait 1.5")
    shot("b08_closeup_pilot_and_mech")
    g.cmd("setting zoom 1.0"); g.cmd("ui hud on"); g.cmd("interact")
    g.cmd("set_mech 2560 1700 200"); g.cmd("wait 1.5")
    shot("b09_salt_pan")
    g.cmd("set_mech 1700 600 90"); g.cmd("service"); g.cmd("wait 1.0")
    shot("b10_dunes_shutters_closed")
    g.cmd("set_mech 1180 1240 270"); g.cmd("drive 1 0 2.5"); g.cmd("stop"); g.cmd("interact"); g.cmd("wait 0.5")
    st = g.state(); p = st["game"]["pilot"]["pos"]
    g.cmd("walk_to 760 1240 20"); g.cmd("wait 1.0")
    shot("b11_on_foot_under_roof_fade")
    g.cmd("ui dev on"); shot("b12_dev_overlay"); g.cmd("ui dev off")
    g.cmd("window 2560 1080"); g.cmd("walk_to 900 1500 20"); g.cmd("wait 1.0")
    shot("b13_ultrawide")
    g.cmd("window 1600 900"); g.cmd("menu"); g.cmd("wait 1.0")
    shot("b14_main_menu")
finally:
    g.quit()
