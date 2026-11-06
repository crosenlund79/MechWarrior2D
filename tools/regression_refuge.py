#!/usr/bin/env python3
"""Runtime regression for the canyon refuge iteration (real game processes).

Rotating housing + twin guns; canyon traversal; overhang fade; workshop entry/exit;
refuge thermal protection; soundscape exposure; theme music (menu, cues, volume,
crossfaded repeat); the parked-mech encounter (unpiloted → … → active), its
difficulty, interruption and save/load resolution across a Godot restart.
  python3 tools/regression_refuge.py      exit 0 = pass
"""
import os, sys, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hs_driver import Instance

HEADLESS = os.environ.get("HS_WINDOWED") != "1"
E2 = "enemy_scrapper_02"
fails = []


def check(cond, what):
    print(("  ok   " if cond else "  FAIL ") + what)
    if not cond:
        fails.append(what)


def ang(a, b):
    return abs((a - b + math.pi) % (2 * math.pi) - math.pi)


g = Instance("refuge", headless=HEADLESS)
g.wipe(); g.start()
try:
    print("1. theme music on the main menu")
    st = g.state()
    check(st["music_id"] == "music.theme", f"menu plays the creator's theme ({st['music_id']})")
    p0 = st["music_pos"]; g.cmd("wait 1.5"); p1 = g.state()["music_pos"]
    check(p1 > p0 + 1.0, f"theme is actually playing ({p0:.1f} → {p1:.1f} s)")
    g.cmd("setting volume_Music 0.2"); db_low = g.state()["music_bus_db"]
    g.cmd("setting volume_Music 0.8"); db_hi = g.state()["music_bus_db"]
    check(db_low < db_hi - 6, f"music follows the volume setting ({db_low:.1f} dB vs {db_hi:.1f} dB)")
    g.cmd("music_seek 3")
    g.cmd("wait 5")
    st = g.state()
    check(st["music_id"] == "music.theme" and 0 < st["music_pos"] < 12, f"theme repeats via crossfade (pos {st['music_pos']:.1f} s)")

    print("2. rotating housing, twin guns, independent chassis")
    st = g.cmd("new 1")["state"]
    g.cmd("wait 4")
    check(g.state()["music_id"] in ("", None) or not g.state()["music_cue"], "gameplay starts without constant music")
    m = st["game"]["mech"]
    g.cmd(f"aim {m['pos'][0] - 600} {m['pos'][1]}")
    g.cmd("wait 1.0")
    st = g.state()
    check(ang(st["housing_angle"], -math.pi / 2) < 0.08, f"housing turns to the mouse (→ {st['housing_angle']:.2f})")
    check(ang(st["game"]["mech"]["heading"], m["heading"]) < 0.01, "aiming leaves the chassis heading alone")
    aim = (m['pos'][0] + 200, m['pos'][1] + 900)
    g.cmd(f"aim {aim[0]} {aim[1]}")
    g.cmd("drive 1 0 1.5")
    st = g.state()
    mp = st["game"]["mech"]["pos"]
    want = math.atan2(aim[0] - mp[0], -(aim[1] - mp[1]))
    check(ang(st["game"]["mech"]["heading"], m["heading"]) < 0.01, "chassis drives straight while the housing swings")
    check(ang(st["housing_angle"], want) < 0.1, f"housing tracked the aim while moving ({st['housing_angle']:.2f} vs {want:.2f})")

    print("3. canyon approach → refuge (no invisible barriers)")
    route = [(700, 1500), (300, 1540), (-150, 1545), (-500, 1575), (-850, 1545), (-1120, 1420), (-1300, 1230), (-1430, 980)]
    covers, zones, exps = [], [], []
    for x, y in route:
        r = g.cmd(f"drive_to {x} {y} 30")
        check(r["ok"], f"reached road point ({x}, {y})")
        s2 = r["state"]; covers.append(s2["cover"]); zones.append(s2["zone"]); exps.append(s2["exposure"])
    g.cmd("stop"); g.cmd("wait 3")
    st = g.state()
    check("canyon_approach" in zones, "the road passes through the canyon zone")
    check(st["zone"] == "refuge_cavern", f"parked inside the refuge ({st['zone']})")
    check(covers[0] < 0.05 and st["cover"] > 0.9, f"overhang fades in smoothly under it ({covers[0]:.2f} → {st['cover']:.2f})")
    check(st["roof_faded"], "overhead rock is see-through under the overhang")
    check("NOTICE_ENTER_REFUGE" in st["notices"], "sheltered conditions are announced")
    check(max(exps[:3]) > 0.9 and st["exposure"] < 0.35, f"wind/exposure falls toward the refuge ({max(exps[:3]):.2f} → {st['exposure']:.2f})")

    print("4. refuge thermal protection")
    g.cmd("debug heat 30"); h0 = g.state()["game"]["mech"]["heat"]
    g.cmd("debug timescale 6"); g.cmd("wait 5"); g.cmd("debug timescale 1")
    h1 = g.state()["game"]["mech"]["heat"]
    check(h1 < h0 - 25, f"parked mech cools effectively in the refuge ({h0:.0f} → {h1:.0f} °C)")
    check(h1 > 40, "but not instantly to ambient")

    print("5. on foot: workshop entry / exit, suit exposure")
    r = g.cmd("interact")
    check(r["state"]["game"]["mode"] == "foot", "exit the mech in the refuge")
    s0 = g.state()["game"]["pilot"]["suit"]
    g.cmd("wait 5")
    rate = (s0 - g.state()["game"]["pilot"]["suit"]) / 5.0
    check(rate < 0.3, f"suit exposure is low in the refuge ({rate:.2f}/s; open sun ≈ 1.4/s)")
    p = g.state()["game"]["pilot"]["pos"]
    g.cmd(f"walk_to {p[0] + 120} {p[1] - 40} 8"); g.cmd("walk_to -1260 800 12")
    r = g.cmd("walk_to -1600 610 25"); check(r["ok"], "walk to the workshop door")
    r = g.cmd("walk_to -1760 605 15"); check(r["ok"], "walk through the door into the workshop")
    st = g.state()
    check(st["roof_faded"], "workshop roof fades while inside")
    r = g.cmd("walk_to -1780 420 6")
    print("      pilot after wall test:", [round(v) for v in r["state"]["game"]["pilot"]["pos"]], r["state"]["pilot_zone"])
    check(not r["ok"] and r["state"]["game"]["pilot"]["pos"][1] > 505, "workshop walls block the pilot (no walking through the wall)")
    g.cmd("walk_to -1760 605 8")
    r = g.cmd("walk_to -1600 610 15"); check(r["ok"], "walk back out of the workshop")
    mp = g.state()["game"]["mech"]["pos"]
    g.cmd("walk_to -1260 800 15")
    g.cmd(f"walk_to {mp[0] + 150} {mp[1]} 25")
    r = g.cmd("interact")
    check(r["state"]["game"]["mode"] == "mech", "back into the mech")

    print("6. music cue in the desert, faded in the refuge")
    g.cmd("set_mech 1500 1150 90"); g.cmd("wait 2"); g.cmd("music_cue"); g.cmd("wait 1")
    st = g.state()
    check(st["music_id"] == "music.theme_alt" and st["music_cue"], "occasional exploration cue plays the alternate theme")
    g.cmd("set_mech -1440 930 0"); g.cmd("wait 4")
    st = g.state()
    check(not st["music_cue"], "entering the refuge fades the music out")
    g.cmd("save")
finally:
    g.quit()

print("7. parked enemy mech encounter")
g = Instance("refuge", headless=HEADLESS)
g.start()
try:
    st = g.cmd("new 2")["state"]
    e = st["game"]["enemies"][E2]
    check(e["ai"] == "unpiloted" and e["pilot"]["state"] == "outside", "pilot stands outside the inactive mech")
    ep, pp = e["pos"], e["pilot"]["pos"]
    g.cmd(f"set_mech {pp[0] - 900} {pp[1] + 500} 45"); g.cmd("debug heat -20"); g.cmd("wait 3")
    e = g.state()["game"]["enemies"][E2]
    check(e["ai"] == "unpiloted" and math.dist(e["pos"], ep) < 1, "unaware while the player is far; parked mech stays put")
    g.cmd(f"set_mech {pp[0] - 230} {pp[1] + 170} 60")
    seq, pilot_moves, mech_still = [], 0.0, True
    last = pp
    for _ in range(60):
        st = g.cmd("wait 0.15")["state"]; e = st["game"]["enemies"][E2]
        if not seq or seq[-1] != e["ai"]:
            seq.append(e["ai"])
        pilot_moves += math.dist(last, e["pilot"]["pos"]); last = e["pilot"]["pos"]
        if e["ai"] in ("alerted", "boarding", "starting") and math.dist(e["pos"], ep) > 1:
            mech_still = False
        if e["ai"] == "engage":
            break
    print("      sequence:", seq)
    check(seq[:4] == ["alerted", "boarding", "starting", "engage"], "ALERTED → BOARDING → STARTING → ACTIVE")
    check(pilot_moves > 60, f"pilot physically runs to the cockpit ({pilot_moves:.0f} px)")
    check(mech_still, "mech does not move before startup completes")
    check(e["pilot"]["state"] == "aboard", "pilot is aboard")
    check("NOTICE_PILOT_ALERT" in st["notices"] and "NOTICE_MECH_STARTUP" in st["notices"], "reaction and startup are signalled")
    i0 = st["game"]["mech"]["integrity"]
    g.cmd("wait 10")
    st = g.state(); e = st["game"]["enemies"][E2]
    check(math.dist(e["pos"], ep) > 20 or e["ai"] == "engage", "active enemy moves / engages")
    check(st["game"]["mech"]["integrity"] > i0 - 25, f"introductory difficulty ({i0:.0f} → {st['game']['mech']['integrity']:.0f} hull in 10 s)")
    g.cmd(f"set_enemy {e['pos'][0]} {e['pos'][1]} 0 engage id={E2}")
    for _ in range(10):
        if g.state()["game"]["enemies"][E2]["ai"] == "wreck":
            break
        g.cmd(f"aim_enemy id={E2}"); g.cmd(f"fire_for 2 body id={E2}")
    check(g.state()["game"]["enemies"][E2]["ai"] == "wreck", "the boarded mech can be defeated as before")

    print("8. interrupted encounter + save/load")
    st = g.cmd("new 3")["state"]
    e = st["game"]["enemies"][E2]; pp = e["pilot"]["pos"]
    g.cmd(f"set_mech {pp[0] - 230} {pp[1] + 170} 60")
    for _ in range(40):
        st = g.cmd("wait 0.1")["state"]
        if st["game"]["enemies"][E2]["ai"] == "boarding":
            break
    check(st["game"]["enemies"][E2]["ai"] == "boarding", "caught mid-boarding")
    g.cmd("save")
finally:
    g.quit()
g = Instance("refuge", headless=HEADLESS)
g.start()
try:
    st = g.cmd("continue 3")["state"]
    e = st["game"]["enemies"][E2]
    check(e["ai"] in ("return", "patrol", "alert", "engage") and e["pilot"]["state"] == "aboard",
          f"loading mid-boarding resolves forward ({e['ai']}, pilot {e['pilot']['state']}) — no replay")
    check(sum(1 for k in st["game"]["enemies"] if k == E2) == 1, "no duplicated encounter")
    g.cmd("new 2")
    e = g.state()["game"]["enemies"][E2]
    g.cmd(f"set_mech {e['pos'][0] - 340} {e['pos'][1] + 120} 70")
    g.cmd("debug enemy_integrity 0"); g.cmd("wait 2")
    e = g.state()["game"]["enemies"][E2]
    check(e["ai"] == "wreck" and e["pilot"]["state"] in ("fled", "gone"), "destroyed before boarding: wreck + pilot flees")
    g.cmd("debug timescale 8"); g.cmd("wait 3"); g.cmd("debug timescale 1"); g.cmd("save")
finally:
    g.quit()
g = Instance("refuge", headless=HEADLESS)
g.start()
try:
    st = g.cmd("continue 2")["state"]
    e = st["game"]["enemies"][E2]
    check(e["ai"] == "wreck" and e["pilot"]["state"] == "gone", "destroyed mech stays destroyed, pilot never returns")
finally:
    g.quit()

print("\nRESULT:", "PASS" if not fails else f"FAIL ({len(fails)})")
sys.exit(1 if fails else 0)
