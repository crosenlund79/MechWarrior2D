#!/usr/bin/env python3
"""Runtime regression for the first hostile encounter (real game processes).

Patrol → detection → pursuit → disengage; aiming, shooting, projectile hits
(structure and cooling); enemy overheating / impairment / defeat; player damage,
crippling and recovery; shade for mech and suit; wreck salvage (single use,
suit cost); repairs with salvage; save/load across a Godot restart.
  python3 tools/regression_encounter.py      exit 0 = pass
"""
import os, sys, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hs_driver import Instance

HEADLESS = os.environ.get("HS_WINDOWED") != "1"
EID = "enemy_scrapper_01"
fails = []


def check(cond, what):
    print(("  ok   " if cond else "  FAIL ") + what)
    if not cond:
        fails.append(what)


def en(st):
    return st["game"]["enemies"][EID]


g = Instance("encounter", headless=HEADLESS)
g.wipe(); g.start()
try:
    print("1. patrol")
    st = g.cmd("new 1")["state"]
    e0 = en(st)
    check(e0["ai"] == "patrol", "enemy starts on patrol")
    g.cmd("wait 4")
    e1 = en(g.state())
    moved = math.dist(e0["pos"], e1["pos"])
    check(moved > 60, f"enemy walks its patrol route ({moved:.0f} px)")
    check(e1["ai"] == "patrol", "start area is out of detection range")

    print("2. detect + pursue")
    ep = e1["pos"]
    g.cmd(f"set_mech {ep[0] - 420} {ep[1]} 90")
    g.cmd("debug heat 25")       # a hot mech is visible from farther away
    g.cmd("wait 3")
    st = g.state()
    check(en(st)["ai"] in ("alert", "engage"), f"enemy detects the hot mech ({en(st)['ai']})")
    check("NOTICE_ENEMY_ALERT" in st["notices"], "detection is announced")
    d0 = math.dist(en(st)["pos"], st["game"]["mech"]["pos"])
    g.cmd("wait 3")
    st = g.state()
    d1 = math.dist(en(st)["pos"], st["game"]["mech"]["pos"])
    check(en(st)["ai"] == "engage", "enemy engages")
    check(d1 < d0 - 10 or d1 < 420, f"enemy closes to its preferred range ({d0:.0f} → {d1:.0f})")

    print("3. telegraphed enemy fire damages the player")
    g.cmd("debug heat -40")
    integ0 = st["game"]["mech"]["integrity"]
    g.cmd("wait 9")
    st = g.state()
    check(st["game"]["mech"]["integrity"] < integ0, f"enemy shots land ({integ0:.0f} → {st['game']['mech']['integrity']:.0f})")
    check(st["game"]["mech"]["integrity"] > 60, "damage is low (very easy enemy)")

    print("4. disengage")
    g.cmd("set_mech 600 600 0")
    g.cmd("wait 2")
    st = g.state()
    check(en(st)["ai"] in ("return", "patrol"), f"enemy disengages when the player escapes ({en(st)['ai']})")
    check("NOTICE_ENEMY_LOST" in st["notices"], "disengage is announced")
    g.cmd("debug timescale 6"); g.cmd("wait 6"); g.cmd("debug timescale 1")
    check(en(g.state())["ai"] == "patrol", "enemy returns to patrol")

    print("5. player aiming + shooting: structure and cooling")
    st = g.state()
    ep = en(st)["pos"]
    g.cmd(f"set_enemy {ep[0]} {ep[1]} 0 engage")
    g.cmd(f"set_mech {ep[0]} {ep[1] - 380} 180")   # clear line of fire (the hauler wreck is cover)
    g.cmd("aim_enemy"); g.cmd("wait 0.3")
    a = g.state()
    check(a["gun_angle"] is not None, "turret aims at the mouse point")
    e_before = en(a)
    heat_before = a["game"]["mech"]["heat"]
    g.cmd("fire_for 2.5 body")
    st = g.state()
    check(en(st)["integrity"] < e_before["integrity"], f"shots hit structure ({e_before['integrity']:.0f} → {en(st)['integrity']:.0f})")
    check(st["game"]["mech"]["heat"] > heat_before, "firing heats the player's mech")
    rad_before = en(st)["radiator"]
    # flank so the rear radiator is exposed, then target it
    for _ in range(3):   # short flanking bursts: an engaged enemy turns to hide its radiator
        g.cmd(f"set_enemy {ep[0]} {ep[1]} 270 engage")      # enemy faces west
        g.cmd(f"set_mech {ep[0] + 360} {ep[1] + 60} 270")   # player behind it (east)
        g.cmd("fire_for 1.2 cooling")
    st = g.state()
    check(en(st)["radiator"] < rad_before - 0.1, f"targeted shots damage the cooling ({rad_before:.2f} → {en(st)['radiator']:.2f})")

    print("6. enemy overheats / impaired / disabled")
    g.cmd("fire_for 8 cooling")
    st = g.state()
    e = en(st)
    check(e["heat"] > 90 or e["ai"] == "wreck", f"damaged cooling makes the enemy run hot ({e['heat']:.0f} °C)")
    for _ in range(8):
        if en(g.state())["ai"] == "wreck":
            break
        g.cmd("fire_for 3 body")
    st = g.state()
    check(en(st)["ai"] == "wreck", "enemy disabled → wreck")
    check("NOTICE_ENEMY_DISABLED" in st["notices"], "defeat announced")
    wp = en(st)["pos"]
    g.cmd("wait 2")
    check(math.dist(en(g.state())["pos"], wp) < 1, "wreck no longer moves")
    n_proj = g.state()["projectiles"]
    g.cmd("wait 4")
    check(g.state()["projectiles"] == 0 or n_proj == 0, "wreck stops firing")

    print("7. shade for the mech")
    g.cmd("debug heat -60"); g.cmd("wait 0.5"); g.cmd("set_mech 2220 1300 180")
    st = g.state(); h_sun = st["game"]["mech"]["heat"]
    g.cmd("drive_to 2220 1640 20"); g.cmd("stop")
    st = g.state()
    check(st["zone"] == "awning_shade", f"mech parked under the awning ({st['zone']})")
    check("NOTICE_ENTER_SHADE" in st["notices"], "entering shade is signalled")
    check(st["roof_faded"], "the awning fades while underneath")

    print("8. exit, salvage the wreck on foot, return, repair")
    r = g.cmd("interact")
    check(r["state"]["game"]["mode"] == "foot", "exit in the suit")
    suit_shade = r["state"]["game"]["pilot"]["suit"]
    g.cmd("wait 2")
    drain_shade = suit_shade - g.state()["game"]["pilot"]["suit"]
    wp = en(g.state())["pos"]
    g.cmd(f"walk_to {wp[0] - 90} {wp[1]} 40")
    st = g.state()
    suit0 = st["game"]["pilot"]["suit"]
    hit = [i for i in st["interactions"] if i["kind"] == "wreck"]
    check(len(hit) == 1, "wreck salvage offered on foot")
    g.cmd("interact"); g.cmd("wait_task")
    st = g.state()
    pack = st["game"]["pilot"]["pack"]
    check(pack.get("scrap", 0) >= 4 and pack.get("radiator_core", 0) >= 1, f"scrap + cooling part recovered {pack}")
    check(suit0 - st["game"]["pilot"]["suit"] > 4, "salvaging burns suit time")
    check(en(st)["salvaged"] is True, "wreck marked salvaged")
    check(not [i for i in st["interactions"] if i["kind"] == "wreck"], "no repeat collection")
    g.cmd("debug timescale 3"); g.cmd("wait 1")
    drain_sun = (st["game"]["pilot"]["suit"] - g.state()["game"]["pilot"]["suit"]) / 3.0
    g.cmd("debug timescale 1")
    check(drain_shade / 2.0 < drain_sun, f"suit drains slower in shade ({drain_shade/2:.2f}/s vs {drain_sun:.2f}/s)")
    mp = st["game"]["mech"]["pos"]
    g.cmd(f"walk_to {mp[0]} {mp[1] + 140} 40")
    rad0 = g.state()["game"]["mech"]["radiator"]
    g.cmd("service"); g.cmd("wait_task")
    st = g.state()
    check(st["game"]["mech"]["radiator"] > rad0 + 0.4, "salvaged core repairs the radiator")
    i0 = st["game"]["mech"]["integrity"]
    if i0 < 100:
        g.cmd("service"); g.cmd("wait_task")
        st = g.state()
        check(st["game"]["mech"]["integrity"] > i0, f"scrap patches the hull ({i0:.0f} → {st['game']['mech']['integrity']:.0f})")
    r = g.cmd("interact")
    check(r["state"]["game"]["mode"] == "mech", "back in the mech")
    saved = g.cmd("save")["state"]["game"]
finally:
    g.quit()

print("9. restart Godot → continue")
g2 = Instance("encounter", headless=HEADLESS)
g2.start()
try:
    st = g2.cmd("continue 1")["state"]
    e = en(st)
    check(e["ai"] == "wreck" and e["salvaged"] is True, "defeat + salvage persisted across restart")
    check(abs(st["game"]["mech"]["integrity"] - saved["mech"]["integrity"]) < 0.5, "player integrity persisted")
    check(not [i for i in st["interactions"] if i["kind"] == "wreck"], "still no repeat salvage after reload")
    print("10. losing a fight is recoverable")
    g2.cmd("debug integrity 0"); g2.cmd("wait 0.3")
    p0 = g2.state()["game"]["mech"]["pos"]
    g2.cmd("drive 1 0 2")
    st = g2.state()
    check(math.dist(p0, st["game"]["mech"]["pos"]) < 5, "crippled mech cannot drive")
    check(st["hint"] == "HINT_CRIPPLED", "player is told how to recover")
    g2.cmd("interact")
    mp = st["game"]["mech"]["pos"]
    g2.cmd(f"walk_to {mp[0]} {mp[1] + 140} 20")
    g2.cmd("service"); g2.cmd("wait_task")
    st = g2.state()
    check(st["game"]["mech"]["integrity"] >= 25, f"emergency patch restores a usable hull ({st['game']['mech']['integrity']:.0f})")
    g2.cmd("interact"); g2.cmd("drive 1 0 1.5")
    check(math.dist(mp, g2.state()["game"]["mech"]["pos"]) > 20, "mech drives again after the patch")
finally:
    g2.quit()

print("\nRESULT:", "PASS" if not fails else f"FAIL ({len(fails)})")
sys.exit(1 if fails else 0)
