#!/usr/bin/env python3
"""Runtime regression for the Southern Junkers iteration (real game processes).

Heavy-weapon recoil at all housing angles; sandstorm build-up/effects/shelter;
F10 developer menu actions (spawn/clear/toggles/teleport/reset, never saved);
traversal of the expanded map; Junker base entry and wall collisions; turrets
(detect, telegraph, limiter, destroy, salvage, persistence); Junker defenders.
  python3 tools/regression_junkers.py      exit 0 = pass
"""
import os, sys, math, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hs_driver import Instance, USER_DIR

HEADLESS = os.environ.get("HS_WINDOWED") != "1"
fails = []


def check(cond, what):
    print(("  ok   " if cond else "  FAIL ") + what)
    if not cond:
        fails.append(what)


g = Instance("junkers", headless=HEADLESS)
g.wipe(); g.start()
try:
    st = g.cmd("new 1")["state"]
    print("1. heavy twin-gun recoil at every housing angle")
    g.cmd("set_mech 1500 1150 90"); g.cmd("dev toggle aggression")
    m0 = g.state()["game"]["mech"]["pos"]
    for ang_deg, (dx, dy) in [(0, (0, -500)), (90, (500, 0)), (180, (0, 500)), (270, (-500, 0)), (45, (350, -350))]:
        g.cmd(f"aim {m0[0] + dx} {m0[1] + dy}"); g.cmd("wait 1.2")
        st = g.cmd("fire_for 0.4")["state"]
        rc = st["recoil"]
        check(max(rc["gun"]) > 3.0 and rc["housing"] > 0.5, f"guns + housing recoil at {ang_deg}° (gun {max(rc['gun']):.1f}, housing {rc['housing']:.1f})")
    check(math.dist(m0, g.state()["game"]["mech"]["pos"]) < 2.0, "recoil is visual: the mech is not displaced")
    samples, shakes = [], []
    for _ in range(8):
        st = g.cmd("fire_for 0.12")["state"]
        samples.append(st["recoil"]["housing"]); shakes.append(st["shake"])
    check(max(shakes) > 0.1, f"camera shake while firing (peak {max(shakes):.2f})")
    check(min(samples) > 1.0, f"continuous fire keeps the heavy housing working, no snap back to rest: {[round(x,1) for x in samples]}")
    g.cmd("wait 1.5")
    rc = g.state()["recoil"]
    check(max(abs(v) for v in rc["gun"]) < 1.0 and abs(rc["housing"]) < 0.6, "recoil settles with damping")

    print("2. sandstorm: gradual approach, effects, shelter")
    g.cmd("dev weather start 1.0")
    i1 = g.cmd("wait 2")["state"]["game"]["weather"]["intensity"]
    st = g.cmd("wait 8")["state"]; w = st["game"]["weather"]
    check(0.05 < i1 < 0.6, f"storm builds up gradually (2 s: {i1:.2f})")
    check(w["state"] == "storm" and w["intensity"] > 0.9, f"storm reaches full strength ({w['state']} {w['intensity']:.2f})")
    check(st["storm_here"] > 0.8, "the open desert takes the full storm")
    g.cmd("debug heat -80"); g.cmd("wait 0.3"); g.cmd("stop")
    r = g.cmd("interact"); s0 = g.state()["game"]["pilot"]["suit"]; g.cmd("wait 3")
    storm_drain = (s0 - g.state()["game"]["pilot"]["suit"]) / 3
    g.cmd("interact")
    check(storm_drain > 2.0, f"suit exposure much more dangerous in the storm ({storm_drain:.2f}/s vs ≈1.4 clear)")
    g.cmd("dev teleport refuge"); g.cmd("wait 1")
    check(g.state()["storm_here"] < 0.15, f"the canyon refuge shelters from the storm ({g.state()['storm_here']:.2f})")
    g.cmd("save")
finally:
    g.quit()
g = Instance("junkers", headless=HEADLESS); g.start()
try:
    st = g.cmd("continue 1")["state"]
    check(st["game"]["weather"]["state"] in ("storm", "fading") and st["game"]["weather"]["intensity"] > 0.5, "storm state persists across a restart")
    check(st["dev"]["aggression"] is True, "cheat toggles were not saved (aggression back on)")
    g.cmd("dev weather stop"); i_a = g.cmd("wait 2")["state"]["game"]["weather"]["intensity"]
    g.cmd("wait 8"); st = g.state()
    check(0.1 < i_a < 0.95 and st["game"]["weather"]["state"] == "clear", f"storm fades out gradually ({i_a:.2f} → clear)")

    print("3. developer menu")
    g.cmd("devmenu on")
    g.cmd("set_mech 1500 1150 90")
    n0 = g.state()["enemy_views"]
    r = g.cmd("dev spawn scrapper 3"); st = r["state"]
    devs = {k: v for k, v in st["game"]["enemies"].items() if v.get("dev")}
    check(len(devs) == 3 and st["enemy_views"] == n0 + 3, "spawn 3 enemy mechs (with views)")
    mp = st["game"]["mech"]["pos"]
    check(all(math.dist(v["pos"], mp) > 300 for v in devs.values()), "spawned away from the player")
    check(all(math.dist(a["pos"], b["pos"]) > 200 for a in devs.values() for b in devs.values() if a is not b), "spawned apart from each other")
    r = g.cmd("dev spawn junker 1")
    check(any(v.get("type") == "junker" and v.get("dev") for v in r["state"]["game"]["enemies"].values()), "spawn a Southern Junkers mech")
    g.cmd("save")
    raw = json.load(open(os.path.join(USER_DIR, "instances", "junkers", "saves", "slot_1.json")))
    check(not any(v.get("dev") for v in raw["state"]["enemies"].values()), "dev-spawned mechs are not in the save file")
    g.cmd("dev clear")
    st = g.state()
    check(not any(v.get("dev") for v in st["game"]["enemies"].values()) and st["enemy_views"] == n0, "clear spawned removes them (and their views)")
    g.cmd("dev toggle invulnerable"); g.cmd("debug integrity 60")
    g.cmd("dev spawn scrapper 1"); g.cmd("dev speed 4"); g.cmd("wait 10"); g.cmd("dev speed 1")
    st = g.state()
    check(st["game"]["mech"]["integrity"] == 60, "invulnerability blocks damage")
    g.cmd("dev repair")
    st = g.state()
    check(st["game"]["mech"]["integrity"] == 100 and st["game"]["mech"]["radiator"] == 1.0, "repair all components")
    g.cmd("dev reset"); g.cmd("dev clear")
    st = g.state()
    check(st["dev"] == {"dynamic_weather": True, "invulnerable": False, "aggression": True, "time_scale": 1.0}, "restore default settings")
    g.cmd("devmenu off")

    print("4. exploring the expanded desert")
    g.cmd("dev toggle aggression"); g.cmd("engine_speed 3")
    routes = [
        ("shelter → old highway rest stop", (760, 1470, 180), [(830, 2000), (770, 2600), (660, 3100), (620, 3240)], "area_roadside"),
        ("highway → scrap field", (1500, 3260, 90), [(1600, 3270), (1750, 3600), (1880, 3880)], "area_scrapfield"),
        ("salt pan → rocky ravine → highway", (2620, 2300, 120), [(3150, 2600), (3420, 2880), (3650, 3120), (3880, 3340), (4020, 3580), (4110, 3860)], "area_ravine"),
        ("highway → Junker gate", (4300, 3990, 100), [(4700, 4060), (5050, 4280), (5180, 4380)], "area_junkers"),
        ("pump rig → cooling station", (2480, 1100, 135), [(2700, 1290), (3100, 1420), (3550, 1350), (4000, 1250), (4500, 1300)], "area_cooling"),
    ]
    areas_seen = set()
    for name, (sx, sy, sh), pts, area in routes:
        g.cmd(f"set_mech {sx} {sy} {sh}"); g.cmd("dev cooling")
        ok = True
        for x, y in pts:
            r = g.cmd(f"drive_to {x} {y} 30")
            ok = ok and r["ok"]
            areas_seen.add(r["state"].get("area"))
            if r["state"].get("zone") == "ravine_passage":
                areas_seen.add("ravine_zone")
        st = g.state()
        check(ok, f"route drivable: {name}")
        check(st["area"] == area or area in areas_seen, f"arrives in {area} ({st['area']})")
    check("area_ravine" in areas_seen and "ravine_zone" in areas_seen, "the ravine is traversed")

    print("5. Southern Junkers base: entry, walls, collisions")
    g.cmd("set_enemy 5750 5500 0 patrol id=junker_yard_guard")   # keep the patrolling guard out of the test lanes
    g.cmd("set_mech 5180 4200 180"); g.cmd("dev cooling")
    r = g.cmd("drive_to 5180 4700 25")
    check(r["ok"], "drive through the main gate into the yard")
    check(r["state"]["area"] == "area_junker_base", "inside the scrapyard")
    r = g.cmd("drive_to 5200 4960 6")
    check(not r["ok"] and r["state"]["game"]["mech"]["pos"][1] < 4930, "the main workshop is solid")
    g.cmd("drive_to 4900 4720 25"); g.cmd("drive_to 4800 5000 20"); g.cmd("drive_to 4580 5260 20"); r = g.cmd("drive_to 4180 5270 20")
    check(r["ok"], "leave through the west breach")
    g.cmd("set_mech 5700 5250 90"); g.cmd("drive_to 5800 5410 10"); r = g.cmd("drive_to 6150 5420 20")
    check(r["ok"], "the east breach is passable")
    g.cmd("set_mech 5500 4650 0"); r = g.cmd("drive_to 5560 4300 8")
    check(not r["ok"] and r["state"]["game"]["mech"]["pos"][1] > 4440, "walls block the mech (no driving through scrap walls)")
    g.cmd("engine_speed 1"); g.cmd("dev toggle aggression")
    g.cmd("save")
finally:
    g.quit()

print("6. turrets + defenders")
g = Instance("junkers", headless=HEADLESS); g.start()
try:
    st = g.cmd("new 2")["state"]
    g.cmd("set_mech 5180 3950 180")
    tw = st["game"]["turrets"]
    check(len(tw) >= 4 and all(not t["destroyed"] for t in tw.values()), "perimeter turrets armed")
    max_wind, engaged_seen, hull0 = 0, set(), 100.0
    g.cmd("dev toggle invulnerable")   # measure behaviour without dying; damage checked separately below
    g.cmd("set_mech 5180 4250 180")
    for _ in range(40):
        st = g.cmd("wait 0.25")["state"]
        tv = st["turret_view"]
        max_wind = max(max_wind, sum(1 for v in tv.values() if v["windup"] > 0))
        engaged_seen |= {k for k, v in tv.items() if v["engaged"]}
    check(len(engaged_seen) >= 1, f"turrets detect the approaching mech ({sorted(engaged_seen)})")
    check(max_wind <= 2, f"no more than two turrets wind up at once ({max_wind})")
    g.cmd("dev toggle invulnerable"); hull0 = g.state()["game"]["mech"]["integrity"]
    g.cmd("wait 10")
    st = g.state(); hull1 = st["game"]["mech"]["integrity"]
    check(hull1 < hull0, f"turret / defender fire damages the player ({hull0:.0f} → {hull1:.0f})")
    check(hull1 > hull0 - 40, "difficulty stays introductory over 10 s at the gate")
    tid = sorted(engaged_seen)[0]
    tpos = [t for t in json.load(open("data/locations/desert_basin_01.json"))["turrets"] if t["id"] == tid][0]["pos"]
    g.cmd("dev toggle invulnerable"); g.cmd(f"aim {tpos[0]} {tpos[1]}"); g.cmd("wait 1.0")
    for _ in range(12):
        if g.state()["game"]["turrets"][tid]["destroyed"]:
            break
        g.cmd(f"aim {tpos[0]} {tpos[1]}"); g.cmd("fire_for 1.0")
    st = g.state()
    check(st["game"]["turrets"][tid]["destroyed"], f"turret {tid} destroyed by the twin guns")
    check("NOTICE_TURRET_DESTROYED" in st["notices"], "destruction announced")
    # defenders: the gate guard is a Junker and engages
    gg = st["game"]["enemies"]["junker_gate_guard"]
    check(gg["ai"] in ("alert", "engage", "return"), f"Junker gate guard reacts ({gg['ai']})")
    for _ in range(14):
        if g.state()["game"]["enemies"]["junker_gate_guard"]["ai"] == "wreck":
            break
        g.cmd("aim_enemy id=junker_gate_guard"); g.cmd("fire_for 1.5 body id=junker_gate_guard")
    check(g.state()["game"]["enemies"]["junker_gate_guard"]["ai"] == "wreck", "a Junker defender can be defeated")
    g.cmd("dev toggle aggression")
    mp = g.state()["game"]["mech"]["pos"]
    g.cmd("stop"); g.cmd("interact")
    r = g.cmd(f"walk_to {tpos[0] - 40} {tpos[1] - 60} 25")
    st = g.state()
    kinds = [i["kind"] for i in st["interactions"]]
    check("turret" in kinds or "wreck" in kinds, f"destroyed turret / wreck can be stripped on foot ({kinds})")
    if "turret" in kinds or "wreck" in kinds:
        g.cmd("interact"); g.cmd("wait_task")
        check(g.state()["game"]["pilot"]["pack"].get("scrap", 0) >= 2, "salvage yields scrap")
    g.cmd("save")
finally:
    g.quit()
g = Instance("junkers", headless=HEADLESS); g.start()
try:
    st = g.cmd("continue 2")["state"]
    check(st["game"]["turrets"][tid]["destroyed"], "destroyed turret stays destroyed after restart")
    check(st["game"]["enemies"]["junker_gate_guard"]["ai"] == "wreck", "defeated defender stays defeated")
    mp = st["game"]["mech"]["pos"]
    check(mp[1] > 3500, f"player position in the expanded world restored ({mp[0]:.0f}, {mp[1]:.0f})")
finally:
    g.quit()

print("\nRESULT:", "PASS" if not fails else f"FAIL ({len(fails)})")
sys.exit(1 if fails else 0)
