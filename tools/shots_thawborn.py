#!/usr/bin/env python3
"""Screenshots of the Thawborn conversion (needs a display) + the menu backdrop.
  xvfb-run -a -s "-screen 0 2600x1200x24" python3 tools/shots_thawborn.py docs/screenshots/thawborn [--backdrop]"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hs_driver import Instance, ROOT
OUT = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("--") else "docs/screenshots/thawborn")
os.makedirs(OUT, exist_ok=True)
g = Instance("shots_tb", headless=False, extra_args=["--rendering-driver", "opengl3"])
g.wipe(); g.start()


def shot(name):
    r = g.cmd(f"screenshot {OUT}/{name}.png"); print(name, r["ok"], r["error"])


def wait_for_tell(cid, kinds, tries=60, step=0.1):
    for _ in range(tries):
        st = g.cmd(f"wait {step}")["state"]
        if st["creature_brains"].get(cid, {}).get("tell") in kinds:
            return True
    return False


try:
    g.cmd("window 1600 900")
    g.cmd("setting show_tutorial false")
    g.cmd("new 1 taubecken"); g.cmd("wait 1.5")
    if "--backdrop" in sys.argv:
        g.cmd("ui hud off"); g.cmd("setting zoom 0.75"); g.cmd("set_mech -320 4500 120")
        g.cmd("set_creature 120 4280 roam cid=rimeback"); g.cmd("dev toggle aggression"); g.cmd("wait 2.5")
        dst = os.path.join(ROOT, "assets/templates/ui/template_menu_backdrop.png")
        g.cmd(f"screenshot {dst}"); print("backdrop", dst)
        sys.exit(0)
    shot("t01_refuge_garage_bay")
    g.cmd("garage")
    # driving feel: handbrake drift on open ground (skid marks)
    g.cmd("set_mech 300 2100 90"); g.cmd("drive 1 0 1.6"); g.cmd("handbrake 1"); g.cmd("drive 1 1 0.7"); g.cmd("handbrake 0")
    shot("t02_handbrake_drift_skid_marks")
    # tracks and the compass in the flats
    g.cmd("set_mech -200 4150 180"); g.cmd("set_creature 600 5420 roam cid=rimeback"); g.cmd("wait 1")
    shot("t03_rimeback_tracks_compass")
    # the rimeback: roar → charge lane
    g.cmd("set_creature -200 4700 roam cid=rimeback"); g.cmd("set_mech -200 4200 180"); g.cmd("wait 0.2")
    g.cmd("fire_at_creature 1.0 body cid=rimeback")
    if wait_for_tell("rimeback", ("charge",), 120):
        g.cmd("wait 0.7")
    shot("t04_rimeback_charge_lane")
    g.cmd("kite 6 470 gland_l cid=rimeback")
    if wait_for_tell("rimeback", ("spit", "sweep"), 160):
        g.cmd("wait 0.5")
    shot("t05_rimeback_tell_glands_or_tail")
    g.cmd("break_part gland_r cid=rimeback"); g.cmd("break_part gland_l cid=rimeback"); g.cmd("creature_hp 1 cid=rimeback")
    g.cmd("fire_at_creature 3 body cid=rimeback"); g.cmd("wait 1")
    st = g.state(); rp = st["game"]["creatures"]["rimeback"]["pos"]
    g.cmd(f"set_mech {rp[0] + 330:.0f} {rp[1]:.0f} 0"); g.cmd("wait 0.3"); g.cmd("interact")
    g.cmd(f"walk_to {rp[0] + 150:.0f} {rp[1]:.0f} 10"); g.cmd("interact"); g.cmd("wait 4.6")
    shot("t06_harvest_loot_rarities")
    me = g.state()["game"]["mech"]["pos"]
    g.cmd(f"walk_to {me[0] + 95:.0f} {me[1]:.0f} 12"); g.cmd("interact")
    # grindback: tremor ring, then surfaced
    g.cmd("dev repair"); g.cmd("set_mech 1100 1950 90"); g.cmd("set_creature 1500 1950 buried cid=grindback_dunes")
    g.cmd("drive 1 0 0.8")
    wait_for_tell("grindback_dunes", ("tremor",), 40)
    g.cmd("drive 0 0 0.5")
    shot("t07_grindback_tremor_ring")
    wait_for_tell("grindback_dunes", ("charge",), 80)
    g.cmd("wait 0.5")
    shot("t08_grindback_paw_charge_lane")
    # skirr pack
    g.cmd("dev repair"); g.cmd("set_mech 2700 800 90"); g.cmd("drive 1 0.3 2.5")
    wait_for_tell("skirr_n1", ("crouch",), 80)
    shot("t09_skirr_pack_crouch")
    # rival car with its roof gunner telegraphing
    g.cmd("dev repair"); g.cmd("set_mech 3000 2250 0"); g.cmd("wait 2.5")
    for _ in range(40):
        st = g.cmd("wait 0.1")["state"]
        if any(n == "NOTICE_ENEMY_ALERT" for n in st["notices"]):
            break
    g.cmd("wait 2.0")
    shot("t10_rival_car_gunner_telegraph")
    # garage menu with materials
    g.cmd("dev teleport refuge"); g.cmd("give_materials"); g.cmd("wait 0.5"); g.cmd("garage fit cooling")
    g.cmd("ui garage on"); g.cmd("wait 0.3")
    shot("t11_garage")
    g.cmd("ui garage off")
    # sandstorm on the road
    g.cmd("set_mech 300 2100 90"); g.cmd("dev weather start 1.0"); g.cmd("wait 10"); g.cmd("drive 1 0.2 2")
    shot("t12_sandstorm_driving")
finally:
    g.quit()
