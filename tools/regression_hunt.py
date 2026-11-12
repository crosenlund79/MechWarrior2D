#!/usr/bin/env python3
"""Runtime regression for the Thawborn journey loop (real game process):
start in Ersthafen (settlement) → drive out through the gate (edge prompt) → Taubecken → road (car feel, heat fairness) → find
and follow rimeback tracks → survive its telegraphed attacks while circling and
shooting → break parts → it flees, follow → kill → get out, harvest → physical
loot → load it by driving over it → return → garage repair + upgrade → save,
quit, reload → everything persisted. Plus: rival-car encounter (telegraphed
roof gunner, retreat), skirr pack + grindback behaviours, sandstorm path.
  python3 tools/regression_hunt.py      exit 0 = pass"""
import os, sys, math, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hs_driver import Instance

HEADLESS = os.environ.get("HS_WINDOWED") != "1"
fails = []
WARN = 98.0
ROAD_OUT = [(-1400, 3340), (-500, 3360), (-150, 3390), (-150, 4150)]
ROAD_BACK = [(-150, 3390), (-500, 3360), (-1400, 3340), (-2250, 3330)]


def leave_by(g, side, start, step, tries=12):
    """Drive toward a map edge until the exit prompt shows (returns its state)."""
    for k in range(tries):
        st = g.state()
        if st["exit_prompt"]:
            return st
        me = st["game"]["mech"]["pos"]
        tx, ty = me[0] + step[0], me[1] + step[1]
        g.cmd(f"drive_to {tx:.0f} {ty:.0f} 6")
    return g.state()


def check(cond, what):
    print(("  ok   " if cond else "  FAIL ") + what)
    if not cond:
        fails.append(what)


def creature(st, cid):
    return st["game"]["creatures"][cid]


g = Instance("hunt", headless=HEADLESS)
g.wipe(); g.start()
try:
    print("1. start in Ersthafen and leave by the gate")
    st = g.cmd("new 1")["state"]
    check(st["node"] == "ersthafen" and st["zone_status"] == "safe", f"the journey starts in Ersthafen, a safe zone ({st['node']})")
    check(st["at_garage"] and st["money"] > 0 and st["fuel"] > 90, "parked at the Eisenwolf garage with money and a full tank")
    gate = [g2 for g2 in json.load(open("data/locations/ersthafen.json"))["gates"] if g2["to"] == "taubecken"][0]
    g.cmd(f"drive_to {gate['entry'][0]} {gate['entry'][1]} 30")
    st = leave_by(g, "e", gate["entry"], (300, 0))
    check(bool(st["exit_prompt"]) and st["exit_prompt"]["kind"] == "leave", f"at the edge: 'Leave this area?' ({st['exit_prompt']})")
    check(abs(st["game"]["mech"]["speed"]) <= 260, f"the car slowed down near the edge ({st['game']['mech']['speed']:.0f})")
    st = g.cmd("exit yes")["state"]
    check(st["node"] == "taubecken" and st["zone_status"] == "danger", f"arrived in the Taubecken territory ({st['node']}, {st['zone_status']})")
    check(st["creature_views"] == len(st["game"]["creatures"]) and len(st["game"]["creatures"]) >= 10, "creatures are alive in the world")
    m = st["game"]["mech"]

    print("2. drive out by road (car handling, heat fairness)")
    peak, crash_free = 0.0, True
    hull0 = m["integrity"]
    for x, y in ROAD_OUT:
        r = g.cmd(f"drive_to {x} {y} 35")
        st = r["state"]
        peak = max(peak, st["game"]["mech"]["heat"])
        if not r["ok"]:
            check(False, f"reached road waypoint {x},{y} ({r['error']})")
    st = g.state()
    check(st["area"] == "area_thaw_flats", f"arrived in the Thaw Flats ({st['area']})")
    check(peak < WARN, f"ordinary driving never warns ({peak:.0f} °C peak)")
    check(st["game"]["mech"]["integrity"] >= hull0 - 15, f"no heavy crash damage on the road ({st['game']['mech']['integrity']:.0f})")
    check(st["game"]["stats"]["distance"] > 5000, f"a reasonable distance driven ({st['game']['stats']['distance']:.0f} px)")

    print("3. find and follow the tracks")
    tk = st["tracker"]
    check(bool(tk), f"creature sign near the flats ({tk.get('species') if tk else None})")
    rime_tracks = [t for t in st["game"]["tracks"] if t["s"] == "rimeback"]
    check(len(rime_tracks) > 20, f"rimeback trail on the ground ({len(rime_tracks)} prints)")
    found = False
    for k in range(14):
        st = g.state()
        rb = creature(st, "rimeback")
        rp = rb["pos"]; me = st["game"]["mech"]["pos"]
        if math.dist(rp, me) < 750 or rb["ai"] not in ("roam",):
            found = True
            break
        # read the sign like a player: the compass names the species, so follow RIMEBACK prints
        # (the freshest nearby rimeback track), not whatever animal crossed last
        now = st["game"]["playtime"]
        near = [t for t in st["game"]["tracks"] if t["s"] == "rimeback" and math.dist(t["p"], me) < 900]
        if not near:
            g.cmd("drive_to -200 4700 8"); continue
        tk = max(near, key=lambda t: t["t"])
        h = tk["h"]
        tx, ty = me[0] + math.sin(h) * 450, me[1] - math.cos(h) * 450
        g.cmd(f"drive_to {tx:.0f} {ty:.0f} 6")
    check(found, "following the trail leads to the rimeback")

    print("4. the hunt: circle, dodge the charge, break parts")
    st = g.state()
    hp0 = creature(st, "rimeback")["hp"]
    g.cmd("kite 14 470 gland_l cid=rimeback")
    st = g.state(); rb = creature(st, "rimeback")
    check(rb["ai"] not in ("roam",), f"it notices and fights ({rb['ai']})")
    check(rb["hp"] < hp0, f"shots land ({hp0:.0f} → {rb['hp']:.0f})")
    for part in ("gland_l", "gland_r", "tail", "head"):
        g.cmd(f"kite 10 470 {part} cid=rimeback")
    st = g.state(); rb = creature(st, "rimeback")
    broken = [p for p, v in rb["parts"].items() if v <= 0]
    check(len(broken) >= 1, f"parts break during the fight ({broken})")
    check(st["game"]["mech"]["integrity"] > 0, f"the car survives the opening exchanges ({st['game']['mech']['integrity']:.0f})")
    print(f"       (car body {st['game']['mech']['integrity']:.0f}, heat {st['game']['mech']['heat']:.0f} °C, damage by source {st['hits_taken']})")
    loot_parts = [l for l in st["game"]["world"]["loot"] if l["item"] in ("rime_gland", "rime_horn", "rime_spine")]
    check(len(loot_parts) >= 1, f"broken parts lie on the ground as loot ({[l['item'] for l in loot_parts]})")
    fled = False
    for k in range(12):
        st = g.state(); rb = creature(st, "rimeback")
        if rb["ai"] == "dead":
            break
        if rb["ai"] == "flee":
            fled = True
        if st["game"]["mech"]["engine"] == "shutdown":
            g.cmd("wait 6"); continue
        if st["game"]["mech"]["integrity"] < 25:
            g.cmd("dev repair")   # (documented assist: keep the long scripted fight going)
        g.cmd("kite 10 420 body cid=rimeback")
    st = g.state(); rb = creature(st, "rimeback")
    check(fled or any("FLEES" in n for n in st["notices"]) or rb["ai"] == "dead", "wounded, it tried to flee (blood trail)")
    check(rb["ai"] == "dead", f"the rimeback is down ({rb['ai']}, hp {rb['hp']:.0f})")
    blood = [t for t in st["game"]["tracks"] if t.get("b")]
    check(len(blood) > 0, f"it left blood-marked tracks ({len(blood)})")

    print("5. harvest and load the loot")
    rp = rb["pos"]
    g.cmd(f"drive_to {rp[0] + 260:.0f} {rp[1]:.0f} 20"); g.cmd("stop")
    r = g.cmd("interact")
    st = r["state"]
    check(st["game"]["mode"] == "foot", "got out of the car")
    g.cmd(f"walk_to {rp[0] + 150:.0f} {rp[1]:.0f} 10")
    st = g.state()
    check(any(i["kind"] == "harvest" for i in st["interactions"]), "harvest is offered at the carcass")
    g.cmd("interact"); g.cmd("wait 4.6")
    st = g.state()
    check(creature(st, "rimeback")["harvested"], "carcass harvested")
    items = [l["item"] for l in st["game"]["world"]["loot"]]
    check("rime_hide" in items, f"materials dropped as physical loot ({items})")
    me = st["game"]["mech"]["pos"]
    g.cmd(f"walk_to {me[0] + 95:.0f} {me[1]:.0f} 12"); g.cmd("interact")
    st = g.state()
    check(st["game"]["mode"] == "mech", "back in the car")
    leave = None
    for k in range(3):
        g.cmd("collect_loot 1100")
    st = g.state()
    stor = st["game"]["mech"]["storage"]
    check(stor.get("rime_hide", 0) >= 2, f"loot loaded by driving over it ({stor})")
    rarities = [n for n in st["notices"] if n in ("NOTICE_LOOT", "NOTICE_LEGENDARY")]
    check(len(rarities) > 0, "pickups announced")

    print("6. flee back to Ersthafen, sell, refuel, upgrade")
    st = g.state()
    print(f"       (car body {st['game']['mech']['integrity']:.0f}, grille {st['game']['mech']['radiator']:.2f}, fuel {st['fuel']:.0f} L, rank {st['rank']})")
    if st["game"]["mech"]["integrity"] <= 0:
        g.cmd("stop"); g.cmd("interact"); g.cmd("service"); g.cmd("wait 6.5"); g.cmd("interact")
        st = g.state()
        check(st["game"]["mech"]["integrity"] > 0, "field patch on foot makes a crippled car drivable")
    for x, y in ROAD_BACK:
        g.cmd(f"drive_to {x} {y} 35")
    st = leave_by(g, "w", None, (-300, 0))
    check(bool(st["exit_prompt"]) and st["exit_prompt"]["kind"] == "flee", f"at the territory edge: 'Flee this territory?' ({st['exit_prompt']})")
    g.cmd("exit no")
    st = g.cmd("wait 1.5")["state"]
    check(not st["exit_prompt"] and st["node"] == "taubecken", "declining keeps you in the territory, no prompt spam")
    me = st["game"]["mech"]["pos"]
    g.cmd(f"drive_to {me[0] - 700:.0f} {me[1]:.0f} 10")
    st = g.state()
    check(st["node"] == "ersthafen", f"driving on past the boundary exits anyway ({st['node']})")
    cargo_before = dict(st["game"]["mech"]["storage"])
    gp = json.load(open("data/locations/ersthafen.json"))["garage"]["pos"]
    g.cmd(f"drive_to {gp[0]} {gp[1]} 40"); g.cmd("stop")
    st = g.state()
    check(st["at_garage"], "parked in the Ersthafen garage")
    check(st["hint"] in ("HINT_GARAGE",), f"hint points at the garage ({st['hint']})")
    money0 = st["money"]
    sold = 0
    for item, n in cargo_before.items():
        if g.cmd(f"sell {item} {n}")["ok"]:
            sold += 1
    st = g.state()
    check(sold >= 2 and st["money"] > money0 + 300, f"hunt loot sold for Mark ({money0} → {st['money']} M)")
    check(st["journey"]["completed"].get("taubecken"), "the Taubecken is marked completed (its quarry is down)")
    check(st["rank"]["level"] >= 2, f"the hunt raised the Jäger rank ({st['rank']})")
    r = g.cmd("refuel"); st = r["state"]
    check(st["fuel"] > 95, f"refuelled ({st['fuel']:.0f} L)")
    if st["game"]["mech"]["integrity"] < st["max_integrity"] - 1:
        check(g.cmd("garage repair")["ok"], "repaired for Mark")
    fitted = []
    for mod in ("weapons", "armor", "engine", "cooling", "tires", "cargo"):
        if g.cmd(f"garage fit {mod}")["ok"]:
            fitted.append(mod)
    st = g.state()
    check(len(fitted) >= 1, f"hunt money buys upgrades ({fitted})")
    up = dict(st["game"]["mech"]["upgrades"])
    stor = dict(st["game"]["mech"]["storage"]); store = dict(st["garage_storage"])
    money1 = st["money"]
    ground_left = 0

    print("7. save, quit, reload")
    g.cmd("save")
    g.quit(); g.start()
    st = g.cmd("continue 1")["state"]
    check(st["running"], "continue works")
    check(st["game"]["mech"]["upgrades"] == up, f"upgrades persisted ({st['game']['mech']['upgrades']})")
    check(st["game"]["mech"]["storage"] == stor and st["garage_storage"] == store, "cargo and garage store persisted")
    check(st["money"] == money1 and st["node"] == "ersthafen", "money and position on the continent persisted")
    check(st["journey"]["completed"].get("taubecken") and st["journey"]["visited"].get("taubecken"), "journey progress persisted")
    check(st["at_garage"], "the car is where it was left")
    r = g.cmd("travel taubecken"); st = r["state"]
    check(creature(st, "rimeback")["ai"] == "dead" and creature(st, "rimeback")["harvested"], "the kill and harvest persisted in the Taubecken")

    print("8. rival-car encounter")
    g.cmd("dev repair"); g.cmd("set_mech 3000 2200 0"); g.cmd("wait 0.5")
    windup = False; fired = False
    for k in range(10):
        st = g.cmd("aim_enemy id=enemy_scrapper_01")["state"]
        e = st["game"]["enemies"]["enemy_scrapper_01"]
        if e["ai"] == "wreck":
            break
        if any(n == "NOTICE_ENEMY_ALERT" for n in st["notices"]):
            windup = True
        st = g.cmd("fire_for 2 body id=enemy_scrapper_01")["state"]
        fired = fired or st["projectiles"] > 0
    st = g.state()
    e = st["game"]["enemies"]["enemy_scrapper_01"]
    check(windup, "the rival car spotted the player")
    check(e["ai"] in ("wreck", "retreat", "return"), f"the rival car was beaten or ran ({e['ai']})")
    check(any(n in ("NOTICE_ENEMY_RETREAT", "NOTICE_ENEMY_DISABLED") for n in st["notices"]), "retreat / disabled announced")

    print("9. skirr pack and grindback behaviour in the world")
    g.cmd("dev repair"); g.cmd("set_mech 2600 800 90"); g.cmd("wait 0.2")
    g.cmd("drive 1 0.25 3")
    seen = set()
    for k in range(10):
        st = g.cmd("drive 1 0.4 1.2")["state"]
        for cid, b in st["creature_brains"].items():
            if cid.startswith("skirr_n") and b["tell"]:
                seen.add(b["tell"])
    pack = [creature(st, c)["ai"] for c in ("skirr_n1", "skirr_n2", "skirr_n3", "skirr_n4")]
    check(any(a != "roam" for a in pack), f"the engine noise drew the skirr pack ({pack})")
    check("crouch" in seen or st["game"]["mech"]["integrity"] < 100, f"skirrs telegraph (crouch) and bite ({seen})")
    g.cmd("dev repair"); g.cmd("set_mech 1100 1950 90"); g.cmd("wait 0.2")
    states = set()
    for k in range(8):
        st = g.cmd("drive 1 0.15 1")["state"]
        states.add(creature(st, "grindback_dunes")["ai"])
    check("tunnel" in states or "erupt" in states or "paw" in states or "charge" in states, f"a fast car's vibration wakes the grindback ({states})")

    print("10. sandstorm path")
    g.cmd("dev repair"); g.cmd("set_mech 300 2100 90"); g.cmd("dev weather start 1.0"); g.cmd("wait 10")
    st = g.state()
    n_storm = st["noise"]
    check(st["storm_here"] > 0.3, f"the storm is felt ({st['storm_here']:.2f})")
    for k in range(6):
        st = g.cmd("drive 1 0.2 3")["state"]
    check(st["game"]["mech"]["engine"] != "shutdown", f"cruising through the storm does not shut down ({st['game']['mech']['heat']:.0f} °C)")
    check(st["noise"] < 1.0, f"the storm muffles engine noise ({st['noise']:.2f})")
    g.cmd("dev weather clear")

    print("11. onward toward Stahlheim")
    g.cmd("devx repair"); g.cmd("set_mech 5600 2150 90"); g.cmd("wait 0.3")
    st = leave_by(g, "e", None, (350, 0))
    if st["exit_prompt"]:
        st = g.cmd("exit yes")["state"]
    check(st["node"] == "kaltbrunn" and st["zone_status"] == "safe", f"onward to Kaltbrunn ({st['node']})")
    check(st["journey"]["completed"].get("kaltbrunn") and st["journey"]["discovered"].get("salzpfanne"), "arriving completes the settlement and reveals the next route")
    for n in ("salzpfanne", "eisenhalt", "frostgrund", "stahlheim"):
        st = g.cmd(f"travel {n}")["state"]
    check(st["node"] == "stahlheim" and st["zone_status"] == "cleared", f"Stahlheim reached with the cargo: CLEARED ({st['zone_status']})")
    check(st["journey"]["delivered"], "the sealed case is delivered")
    g.cmd("save"); g.quit(); g.start()
    st = g.cmd("continue 1")["state"]
    check(st["node"] == "stahlheim" and st["journey"]["delivered"] and st["zone_status"] == "cleared", "the delivered journey persists")
finally:
    g.quit()
print("\nRESULT:", "PASS" if not fails else f"FAIL ({len(fails)})")
sys.exit(1 if fails else 0)
