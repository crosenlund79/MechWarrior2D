#!/usr/bin/env python3
"""Screenshots for the Southern Junkers iteration (needs a display):
recoil frames (GIF), sandstorm (build-up / full / refuge), expanded map
locations, the Junkers compound, turrets, defenders, and the F10 menu.
  xvfb-run -a -s "-screen 0 2600x1200x24" python3 tools/shots_junkers.py docs/screenshots/junkers"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hs_driver import Instance
OUT = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else "docs/screenshots/junkers")
os.makedirs(OUT, exist_ok=True)
g = Instance("shots_jk", headless=False, extra_args=["--rendering-driver", "opengl3"])
g.wipe(); g.start()
def shot(name):
    r = g.cmd(f"screenshot {OUT}/{name}.png"); print(name, r["ok"], r["error"])
frames = []
try:
    g.cmd("window 1600 900"); g.cmd("new 1"); g.cmd("dev toggle aggression"); g.cmd("wait 1")
    # --- recoil burst at an angle, frame sequence
    g.cmd("set_mech 1500 1150 60"); g.cmd("setting zoom 1.7"); g.cmd("aim 1850 950"); g.cmd("ui hud off"); g.cmd("wait 1.2")
    shot("j01_twin_guns_at_rest")
    for k in range(12):
        n = f"rec_{k:02d}"; g.cmd(f"fire_capture {OUT}/{n}.png {k % 3}"); frames.append(n)
    g.cmd(f"fire_capture {OUT}/j01c_muzzle_flash_recoil.png 0")
    g.cmd("aim 1300 1500"); g.cmd("wait 0.9"); g.cmd(f"fire_capture {OUT}/j02_recoil_firing_backward.png 0")
    g.cmd("setting zoom 1.0"); g.cmd("ui hud on")
    # --- impacts: sand and rock / metal
    g.cmd("set_mech 1050 1060 0"); g.cmd("aim 1250 820"); g.cmd("wait 0.8"); g.cmd("fire_for 0.8"); g.cmd(f"fire_capture {OUT}/j03_rock_impacts_dust.png 1")
    # --- sandstorm
    g.cmd("set_mech 300 2000 90"); g.cmd("dev weather start 1.0"); g.cmd("wait 3"); shot("j10_storm_building")
    g.cmd("wait 7"); shot("j11_sandstorm_full")
    g.cmd("aim 600 1900"); g.cmd("wait 0.6"); g.cmd(f"fire_capture {OUT}/j12_sandstorm_firing.png 0")
    g.cmd("dev teleport refuge"); g.cmd("wait 2.5"); shot("j13_storm_seen_from_refuge")
    g.cmd("dev weather clear"); g.cmd("wait 1")
    # --- locations
    for name, cmd in [("j20_cooling_station", "set_mech 4400 1350 60"), ("j21_scrap_field", "set_mech 1900 3700 160"),
                      ("j22_roadside_rest_stop", "set_mech 620 3240 120"), ("j23_rocky_ravine", "set_mech 3560 3010 135")]:
        g.cmd(cmd); g.cmd("setting zoom 0.62"); g.cmd("wait 1.5"); shot(name)
    # --- Junkers
    g.cmd("set_mech 5180 3800 180"); g.cmd("setting zoom 0.55"); g.cmd("wait 1.5"); shot("j30_junker_base_approach")
    g.cmd("ui hud off"); g.cmd("set_mech 5180 4650 180"); g.cmd("setting zoom 0.42"); g.cmd("wait 1.5"); shot("j31_junker_compound_overview")
    g.cmd("ui hud on"); g.cmd("setting zoom 0.95")
    g.cmd("dev toggle aggression"); g.cmd("set_mech 5180 4150 180"); g.cmd("aim 5180 4500")
    for k in range(20):
        st = g.cmd("wait 0.2")["state"]
        if any(v["windup"] > 0.3 for v in st["turret_view"].values()):
            break
    shot("j32_turret_telegraph")
    g.cmd("wait 1.0"); shot("j33_turret_fire_and_guard")
    g.cmd("aim 4870 4380"); g.cmd("wait 0.6")
    for k in range(10):
        if g.state()["game"]["turrets"]["jk_turret_gate_w"]["destroyed"]:
            break
        g.cmd("aim 4870 4380"); g.cmd("fire_for 0.8")
    g.cmd("wait 0.8"); shot("j34_turret_destroyed")
    g.cmd("dev toggle aggression")
    g.cmd("set_mech 5640 4380 200"); g.cmd("setting zoom 1.2"); g.cmd("wait 1.0"); shot("j35_junker_mech_and_pilot")
    g.cmd("setting zoom 1.0"); g.cmd("devmenu on"); g.cmd("wait 0.4"); shot("j40_dev_menu_f10"); g.cmd("devmenu off")
finally:
    g.quit()
from PIL import Image
imgs = []
for n in frames:
    im = Image.open(os.path.join(OUT, n + ".png")).convert("RGB")
    w, h = im.size
    imgs.append(im.crop((int(w * 0.25), int(h * 0.15), int(w * 0.75), int(h * 0.85))).resize((640, 504), Image.LANCZOS))
    os.remove(os.path.join(OUT, n + ".png"))
if imgs:
    imgs[0].save(os.path.join(OUT, "j01b_recoil_sequence.gif"), save_all=True, append_images=imgs[1:], duration=90, loop=0)
print("done")
