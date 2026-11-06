#!/usr/bin/env python3
"""Screenshots for the canyon-refuge iteration + a frame sequence of the pilot
boarding / mech startup (also assembled into a contact sheet and an animated GIF).
  xvfb-run -a -s "-screen 0 2600x1200x24" python3 tools/shots_refuge.py docs/screenshots/refuge"""
import os, sys, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hs_driver import Instance
OUT = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else "docs/screenshots/refuge")
os.makedirs(OUT, exist_ok=True)
E2 = "enemy_scrapper_02"
g = Instance("shots_refuge", headless=False, extra_args=["--rendering-driver", "opengl3"])
g.wipe(); g.start()
def shot(name):
    r = g.cmd(f"screenshot {OUT}/{name}.png"); print(name, r["ok"], r["error"])
try:
    g.cmd("window 1600 900"); shot("r00_main_menu_theme")
    g.cmd("new 1"); g.cmd("wait 1")
    m = g.state()["game"]["mech"]["pos"]
    g.cmd("set_mech 1300 1150 90"); g.cmd("setting zoom 1.6"); g.cmd(f"aim 1300 900"); g.cmd("ui hud off"); g.cmd("wait 1.2")
    shot("r01_mech_housing_forward")
    g.cmd("aim 1650 1250"); g.cmd("wait 0.6"); g.cmd("fire_for 0.35"); shot("r02_mech_housing_rotated_firing")
    g.cmd("aim 1100 1400"); g.cmd("wait 0.8"); shot("r03_mech_housing_aims_behind")
    g.cmd("ui hud on"); g.cmd("setting zoom 0.8")
    g.cmd("set_mech 300 1540 270"); g.cmd("aim -200 1540"); g.cmd("drive_to -150 1545 20"); g.cmd("wait 0.3")
    shot("r04_canyon_mouth")
    g.cmd("drive_to -850 1545 20"); shot("r05_canyon_descent")
    g.cmd("drive_to -1120 1420 20"); g.cmd("drive_to -1250 1300 10"); shot("r06_rounding_the_bend")
    g.cmd("drive_to -1330 1200 10"); g.cmd("wait 0.2"); shot("r07_overhang_transition")
    g.cmd("drive_to -1430 980 15"); g.cmd("stop"); g.cmd("wait 2.5"); shot("r08_cavern_refuge_parked")
    g.cmd("setting zoom 0.62"); g.cmd("ui hud off"); g.cmd("wait 1.2"); shot("r09_cavern_overview")
    g.cmd("ui hud on"); g.cmd("setting zoom 1.0")
    g.cmd("interact"); p = g.state()["game"]["pilot"]["pos"]
    g.cmd(f"walk_to {p[0] + 120} {p[1] - 40} 8"); g.cmd("walk_to -1260 800 12"); g.cmd("wait 0.2")
    shot("r10_on_foot_under_overhang")
    g.cmd("walk_to -1600 610 25"); g.cmd("wait 0.4"); shot("r11_workshop_door")
    g.cmd("walk_to -1760 605 15"); g.cmd("wait 1.0"); shot("r12_inside_workshop")
    # ---- encounter
    g.cmd("new 2"); g.cmd("wait 1")
    e = g.state()["game"]["enemies"][E2]; pp = e["pilot"]["pos"]
    g.cmd(f"set_mech {pp[0] - 520} {pp[1] + 300} 60"); g.cmd("debug heat -20"); g.cmd(f"aim {pp[0]} {pp[1]}")
    g.cmd("setting zoom 1.15"); g.cmd("wait 1.5")
    shot("r20_pilot_beside_parked_mech")
    g.cmd(f"set_mech {pp[0] - 260} {pp[1] + 190} 60"); g.cmd(f"aim {pp[0]} {pp[1]}")
    seq = []
    for k in range(26):
        st = g.cmd("wait 0.22")["state"]
        name = f"seq_{k:02d}_{st['game']['enemies'][E2]['ai']}"
        shot(name); seq.append(name)
        if st["game"]["enemies"][E2]["ai"] == "engage" and k > 3:
            g.cmd("wait 0.8"); shot(f"seq_{k+1:02d}_active"); seq.append(f"seq_{k+1:02d}_active")
            break
    open(os.path.join(OUT, "sequence.txt"), "w").write("\n".join(seq))
finally:
    g.quit()
# contact sheet + gif
from PIL import Image
frames = [Image.open(os.path.join(OUT, n + ".png")).convert("RGB") for n in seq]
crop = []
for f in frames:
    w, h = f.size
    crop.append(f.crop((w * 0.18, h * 0.12, w * 0.82, h * 0.88)).resize((512, 306), Image.LANCZOS))
cols = 4
rows = math.ceil(len(crop) / cols)
sheet = Image.new("RGB", (cols * 512, rows * 306), (20, 16, 12))
for i, c in enumerate(crop):
    sheet.paste(c, ((i % cols) * 512, (i // cols) * 306))
sheet.save(os.path.join(OUT, "r21_boarding_sequence_sheet.png"))
crop[0].save(os.path.join(OUT, "r22_boarding_sequence.gif"), save_all=True, append_images=crop[1:], duration=220, loop=0)
for n in seq:
    os.remove(os.path.join(OUT, n + ".png"))
print("sequence frames:", len(seq))
