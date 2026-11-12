#!/usr/bin/env python3
"""Builds the continental journey locations (data/locations/*.json) from data/journey.json:

  settlements (safe zones): Ersthafen, Kaltbrunn, Eisenhalt, Stahlheim (hub)
  territories (danger):     Salzpfanne, Rostfeld, Weißgrat, Frostgrund
  + patches the existing Taubecken map (desert_basin_01) with gates, tier, relief and POIs.

Everything is generated deterministically (fixed seeds) from the existing illustrated prop kit, then
validated: roads, gates, creatures, routes and POIs must be clear of rock and colliding props.
Run: python3 tools/build_continent.py   (idempotent; exit 1 on geometry errors)"""
import json, math, os, random, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
J = json.load(open(os.path.join(ROOT, "data/journey.json")))
BASIN_P = os.path.join(ROOT, "data/locations/desert_basin_01.json")
BASIN = json.load(open(BASIN_P))
NODES = J["nodes"]
NEIGH = {n: [] for n in NODES}
for a, b, _f in J["edges"]:
    NEIGH[a].append(b); NEIGH[b].append(a)
errs = []

ZT = json.loads(json.dumps(BASIN["zone_types"]))
ZT["settlement"] = {"ambient": 46.0, "solar": 0.55, "abrasion": 0.2, "drag": 1.0, "grip": 1.05, "suit": 0.35, "cooling": 1.25,
                    "label": "ZONE_SETTLEMENT", "storm_exposure": 0.35, "safe": True}
ZT["frost"] = {"ambient": 49.0, "solar": 1.15, "abrasion": 0.5, "drag": 0.95, "grip": 0.8, "suit": 1.2, "label": "ZONE_FROST", "storm_exposure": 1.0}
ZT["scorch"] = {"ambient": 66.0, "solar": 1.35, "abrasion": 1.0, "drag": 1.0, "grip": 0.95, "suit": 1.4, "label": "ZONE_SCORCH", "storm_exposure": 1.0}


# ----------------------------------------------------------------------------- geometry helpers
def dist_seg(p, a, b):
    ax, ay = a; bx, by = b; px, py = p
    dx, dy = bx - ax, by - ay
    t = max(0, min(1, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy + 1e-9)))
    return math.hypot(ax + dx * t - px, ay + dy * t - py)


def inside(pt, poly):
    x, y = pt; c = False
    for i in range(len(poly)):
        x1, y1 = poly[i]; x2, y2 = poly[(i + 1) % len(poly)]
        if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1 + 1e-9) + x1:
            c = not c
    return c


def near_poly(pt, poly, margin):
    return inside(pt, poly) or min(dist_seg(pt, poly[i], poly[(i + 1) % len(poly)]) for i in range(len(poly))) < margin


def near_roads(pt, roads, margin):
    for r in roads:
        for i in range(len(r) - 1):
            if dist_seg(pt, r[i], r[i + 1]) < margin:
                return True
    return False


def gate_pos(side, t, W, H):
    return {"n": [W * t, 0], "s": [W * t, H], "w": [0, H * t], "e": [W, H * t]}[side]


def inward(side):
    return {"n": (0, 1, 180), "s": (0, -1, 0), "w": (1, 0, 90), "e": (-1, 0, 270)}[side]


def meander(a, b, rng, amp=220, n=6):
    pts = [a]
    for k in range(1, n):
        t = k / n
        x = a[0] + (b[0] - a[0]) * t; y = a[1] + (b[1] - a[1]) * t
        dx, dy = b[0] - a[0], b[1] - a[1]; L = math.hypot(dx, dy) + 1e-9
        off = math.sin(t * math.pi) * rng.uniform(-amp, amp)
        pts.append([round(x - dy / L * off), round(y + dx / L * off)])
    pts.append(b)
    return pts


def make_gates(node, W, H, sides):
    """One gate per neighbour, on the side of the map facing that neighbour on the continental map."""
    gates = []
    used = {}
    p0 = NODES[node]["pos"]
    for nb in NEIGH[node]:
        p1 = NODES[nb]["pos"]
        ang = math.atan2(p1[1] - p0[1], p1[0] - p0[0])
        side = sides.get(nb) or ("e" if -0.79 <= ang < 0.79 else "s" if 0.79 <= ang < 2.36 else "n" if -2.36 <= ang < -0.79 else "w")
        k = used.get(side, 0); used[side] = k + 1
        t = [0.5, 0.25, 0.75][k % 3]
        pos = gate_pos(side, t, W, H)
        ix, iy, hd = inward(side)
        gates.append({"id": f"gate_{nb}", "to": nb, "side": side, "pos": [round(pos[0]), round(pos[1])],
                      "entry": [round(pos[0] + ix * 420), round(pos[1] + iy * 420)], "heading_deg": hd})
    return gates


def ridge(cx, cy, length, width, ang, rng, seed):
    """A rock ridge: elongated rough polygon along a line."""
    pts = []
    n = 9
    for k in range(n + 1):
        t = k / n - 0.5
        w = width * (0.35 + 0.65 * math.sin((t + 0.5) * math.pi)) * rng.uniform(0.85, 1.15)
        x = cx + math.cos(ang) * t * length; y = cy + math.sin(ang) * t * length
        pts.append((x - math.sin(ang) * w, y + math.cos(ang) * w))
    back = []
    for k in range(n, -1, -1):
        t = k / n - 0.5
        w = width * (0.35 + 0.65 * math.sin((t + 0.5) * math.pi)) * rng.uniform(0.85, 1.15)
        x = cx + math.cos(ang) * t * length; y = cy + math.sin(ang) * t * length
        back.append((x + math.sin(ang) * w, y - math.cos(ang) * w))
    poly = [[round(x), round(y)] for x, y in pts + back]
    return {"id": f"ridge_{seed}", "tile": "ground.rock_top", "height": rng.randint(40, 75), "rough": 22, "seed": seed, "polygon": poly}


def prop(props, pid, asset, pos, layer="low", rot=0, collision=None, **kw):
    d = {"id": pid, "asset": asset, "pos": [round(pos[0]), round(pos[1])], "layer": layer}
    if rot:
        d["rot"] = rot
    if collision:
        d["collision"] = collision
    d.update(kw)
    props.append(d)
    return d


def base_loc(node, W, H):
    n = NODES[node]
    return {"id": n["location"], "name": n["name"], "node": node, "kind": n["kind"], "tier": n["tier"], "bounds": [0, 0, W, H],
            "default_zone": {"ambient": 58.0 + 1.5 * n["tier"], "solar": 1.0 + 0.04 * n["tier"], "abrasion": 1.0, "drag": 1.0, "suit": 1.0,
                             "label": "ZONE_OPEN_SAND", "storm_exposure": 1.0, "grip": 0.92},
            "zone_types": ZT, "patches": [], "zones": [], "props": [], "scatter": [], "scatter_avoid": [], "enemies": [], "salvage": [],
            "terrain": {"masses": [], "covers": [], "walls": [], "cables": []}, "turrets": [], "areas": [], "teleports": {},
            "creatures": [], "pois": [], "relief": {"seed": hash(node) % 9973, "amp": 1.0, "scale": 900.0},
            "weather_mult": 1.0 + 0.25 * n["tier"]}


# ----------------------------------------------------------------------------- settlements
SIGN = {"ersthafen": "sign.ersthafen", "kaltbrunn": "sign.kaltbrunn", "eisenhalt": "sign.eisenhalt", "stahlheim": "sign.stahlheim"}


def settlement(node, big=False, sides=None):
    W, H = (4400, 3400) if big else (3600, 2800)
    L = base_loc(node, W, H)
    rng = random.Random(node)
    cx, cy = W / 2, H / 2
    gates = make_gates(node, W, H, sides or {})
    L["gates"] = gates
    L["relief"]["amp"] = 0.5
    props = L["props"]
    # compound: walls around a central yard with a gap at every road
    hw, hh = (1500, 1100) if big else (1150, 850)
    x0, y0, x1, y1 = cx - hw, cy - hh, cx + hw, cy + hh
    roads = []
    for g in gates:
        side = g["side"]
        door = {"n": [g["pos"][0], y0], "s": [g["pos"][0], y1], "w": [x0, g["pos"][1]], "e": [x1, g["pos"][1]]}[side]
        roads.append(meander(g["pos"], door, rng, 120, 4) + [[round(cx), round(cy)]])
    for i, r in enumerate(roads):
        L["patches"].append({"id": f"road_{i}", "tile": "ground.asphalt" if big else "ground.track", "width": 150, "path": r})
    L["patches"].insert(0, {"id": "yard", "tile": "ground.junker_dirt", "polygon": [[x0 + 30, y0 + 30], [x1 - 30, y0 + 30], [x1 - 30, y1 - 30], [x0 + 30, y1 - 30]]})
    # walls with gate gaps (gaps are 360 wide around each road crossing)
    gaps = {"n": [], "s": [], "w": [], "e": []}
    for g in gates:
        gaps[g["side"]].append(g["pos"][0] if g["side"] in "ns" else g["pos"][1])
    segs = []
    def wall_line(a, b, axis_gaps, horizontal):
        lo, hi = (a[0], b[0]) if horizontal else (a[1], b[1])
        cuts = sorted(axis_gaps)
        cur = lo
        for c in cuts:
            if c - 180 > cur:
                segs.append([[cur, a[1]], [c - 180, a[1]]] if horizontal else [[a[0], cur], [a[0], c - 180]])
            cur = c + 180
        if cur < hi:
            segs.append([[cur, a[1]], [hi, a[1]]] if horizontal else [[a[0], cur], [a[0], hi]])
    wall_line([x0, y0], [x1, y0], gaps["n"], True)
    wall_line([x0, y1], [x1, y1], gaps["s"], True)
    wall_line([x0, y0], [x0, y1], gaps["w"], False)
    wall_line([x1, y0], [x1, y1], gaps["e"], False)
    L["terrain"]["walls"].append({"id": "compound_wall", "tile": "junker.wall_strip", "width": 30, "segments": [[[round(p[0]), round(p[1])] for p in s] for s in segs]})
    # Eisenwolf Werke garage (drive-in bay) north of the yard centre
    gx, gy = cx - 260, cy - 320
    prop(props, "werkstatt_floor", "refuge.workshop_floor", (gx, gy), "floor")
    prop(props, "werkstatt_roof", "refuge.workshop_roof", (gx, gy), "overhead", occlude=True)
    prop(props, "werkstatt_sign", "sign.eisenwolf", (gx, gy - 170), "low", collision={"rect": [250, 30]})
    prop(props, "werkstatt_lamp_a", "junker.lamp", (gx - 175, gy + 110), "low", collision={"circle": 12}, light=True, light_color=[1.0, 0.7, 0.35], light_energy=0.45, light_scale=1.8)
    prop(props, "werkstatt_lamp_b", "junker.lamp", (gx + 175, gy + 110), "low", collision={"circle": 12}, light=True, light_color=[1.0, 0.7, 0.35], light_energy=0.45, light_scale=1.8)
    L["garage"] = {"pos": [round(gx), round(gy)], "radius": 260.0, "services": ["repair", "fuel", "sell", "upgrade", "storage"], "name": "GARAGE_EISENWOLF"}
    L["mech_start"] = {"pos": [round(gx), round(gy)], "heading_deg": 180}
    # Tankstelle: canopy over two pumps east of the garage
    tx, ty = cx + 420, cy - 300
    prop(props, "tank_canopy", "road.canopy", (tx, ty), "overhead", occlude=True)
    prop(props, "tank_pump_a", "road.pump", (tx - 80, ty), "low", collision={"circle": 16})
    prop(props, "tank_pump_b", "road.pump", (tx + 80, ty), "low", collision={"circle": 16})
    prop(props, "tank_sign", "sign.tankstelle", (tx, ty - 190), "low", collision={"rect": [210, 28]})
    # Handelsposten (trading post) + parked cars, tents, crates
    prop(props, "handel_kiosk", "road.kiosk", (cx - 380, cy + 360), "low", collision={"rect": [230, 150]})
    prop(props, "handel_sign", "sign.handelsposten", (cx - 380, cy + 230), "low", collision={"rect": [230, 28]})
    prop(props, "town_sign", SIGN[node], (cx + 120, cy + 120), "low", collision={"rect": [250, 30]})
    for i, (dx, dy, r) in enumerate([(380, 380, 10), (620, 420, -8), (-760, 300, 92)]):
        prop(props, f"parked_{i}", "road.car", (cx + dx, cy + dy), "low", rot=r, collision={"rect": [170, 86]})
    for i, (dx, dy) in enumerate([(-hw + 260, -hh + 250), (hw - 300, hh - 260), (-hw + 280, hh - 280)]):
        prop(props, f"tent_{i}", "shelter.awning", (cx + dx, cy + dy), "overhead", occlude=True)
        prop(props, f"crates_{i}", "refuge.crates", (cx + dx + 130, cy + dy + 60), "low", collision={"rect": [90, 80]})
    prop(props, "flag", "shelter.flag", (cx + 40, cy - 40), "low")
    prop(props, "generator", "junker.generator", (cx + hw - 220, cy - hh + 160), "low", collision={"rect": [150, 100]})
    prop(props, "barrels", "shelter.barrels", (cx - hw + 170, cy - hh + 170), "low", collision={"circle": 44})
    if big:
        prop(props, "hub_tower_a", "cs.cooling_tower", (cx + hw - 380, cy + hh - 360), "low", collision={"circle": 150})
        prop(props, "hub_tank_a", "cs.tank", (cx - hw + 380, cy - hh + 360), "low", collision={"circle": 70})
        prop(props, "hub_works", "junker.workshop", (cx + 700, cy + 520), "low", collision={"rect": [520, 350]})
        prop(props, "hub_billboard", "road.billboard", (cx - 760, cy + 700), "low", collision={"rect": [290, 40]})
    L["zones"].append({"id": "compound", "type": "settlement", "polygon": [[x0, y0], [x1, y0], [x1, y1], [x0, y1]]})
    L["areas"].append({"id": "area_" + node, "name": NODES[node]["name"], "polygon": [[x0, y0], [x1, y0], [x1, y1], [x0, y1]]})
    L["scatter"].append({"seed": rng.randint(1, 999), "count": 70, "area": [0, 0, W, H], "spacing": 90, "assets": ["prop.rock_small_a", "prop.stones", "prop.rock_small_b"]})
    L["scatter_avoid"].append([x0 - 100, y0 - 100, 2 * hw + 200, 2 * hh + 200])
    for r in roads:
        for i in range(len(r) - 1):
            a, b = r[i], r[i + 1]
            L["scatter_avoid"].append([min(a[0], b[0]) - 120, min(a[1], b[1]) - 120, abs(a[0] - b[0]) + 240, abs(a[1] - b[1]) + 240])
    # a few rocks in the surroundings
    for k in range(10):
        p = (rng.uniform(200, W - 200), rng.uniform(200, H - 200))
        if x0 - 250 < p[0] < x1 + 250 and y0 - 250 < p[1] < y1 + 250 or near_roads(p, roads, 260):
            continue
        prop(props, f"rock_{k}", "prop.rock_large_a" if k % 2 else "prop.rock_large_b", p, "low", rot=rng.randint(0, 359), collision={"circle": 50})
    L["teleports"]["garage"] = {"pos": L["garage"]["pos"], "heading_deg": 180}
    L["_roads"] = roads
    return L


# ----------------------------------------------------------------------------- territories
THEMES = {
    "salzpfanne": {"patch": ("ground.saltpan", "salt"), "patches": 5, "ridges": 6, "packs": 2, "grind": 3, "eis": 1, "rivals": 0, "zone": "scorch"},
    "rostfeld": {"patch": ("ground.junker_dirt", None), "patches": 4, "ridges": 7, "packs": 2, "grind": 2, "eis": 1, "rivals": 3, "zone": None},
    "weissgrat": {"patch": ("ground.dunes", "dunes"), "patches": 4, "ridges": 11, "packs": 3, "grind": 2, "eis": 2, "rivals": 0, "zone": None},
    "frostgrund": {"patch": ("ground.saltpan", "frost"), "patches": 6, "ridges": 8, "packs": 3, "grind": 3, "eis": 2, "rivals": 2, "zone": "frost"},
}


def territory(node, sides=None):
    th = THEMES[node]
    W, H = 6600, 4800
    L = base_loc(node, W, H)
    tier = NODES[node]["tier"]
    rng = random.Random(node + "_terr")
    gates = make_gates(node, W, H, sides or {})
    L["gates"] = gates
    hub = [round(W * rng.uniform(0.42, 0.58)), round(H * rng.uniform(0.42, 0.58))]
    roads = [meander(g["pos"], hub, rng, 380, 7) for g in gates]
    for i, r in enumerate(roads):
        L["patches"].append({"id": f"track_{i}", "tile": "ground.track", "width": 110, "path": r})
    props = L["props"]
    # theme patches (large soft polygons)
    for k in range(th["patches"]):
        for _ in range(30):
            c = (rng.uniform(600, W - 600), rng.uniform(600, H - 600))
            r = rng.uniform(420, 820)
            poly = [[round(c[0] + math.cos(a) * r * rng.uniform(0.7, 1.2)), round(c[1] + math.sin(a) * r * rng.uniform(0.6, 1.1))] for a in [i / 10 * math.tau for i in range(10)]]
            break
        p = {"id": f"patch_{k}", "tile": th["patch"][0], "polygon": poly}
        if th["patch"][1]:
            p["zone"] = th["patch"][1]
        L["patches"].append(p)
    if th["zone"]:
        L["default_zone"].update(ZT[th["zone"]]); L["default_zone"]["label"] = ZT[th["zone"]]["label"]
    # ridges and outcrops (relief), never on the roads or the gate approaches
    ridges = []
    tries = 0
    while len(ridges) < th["ridges"] and tries < 400:
        tries += 1
        c = (rng.uniform(500, W - 500), rng.uniform(500, H - 500))
        rd = ridge(c[0], c[1], rng.uniform(700, 1500), rng.uniform(90, 170), rng.uniform(0, math.pi), rng, len(ridges) + 1)
        if any(near_roads(q, roads, 280) for q in rd["polygon"]) or near_roads(c, roads, 420):
            continue
        if any(math.dist(c, g["pos"]) < 900 for g in gates):
            continue
        if any(math.dist(c, r2["_c"]) < 900 for r2 in ridges):
            continue
        rd["_c"] = c
        ridges.append(rd)
    for rd in ridges:
        rd.pop("_c")
    L["terrain"]["masses"] = ridges
    # shade pockets under ridges (cooler), named areas
    L["areas"].append({"id": f"area_{node}", "name": NODES[node]["name"], "polygon": [[0, 0], [W, 0], [W, H], [0, H]]})
    # rocks
    for k in range(26):
        p = (rng.uniform(300, W - 300), rng.uniform(300, H - 300))
        if near_roads(p, roads, 240) or any(near_poly(p, m["polygon"], 160) for m in ridges) or any(math.dist(p, g["pos"]) < 600 for g in gates):
            continue
        prop(props, f"rock_{k}", "prop.rock_large_a" if k % 2 else "prop.rock_large_b", p, "low", rot=rng.randint(0, 359), collision={"circle": 50})
    L["scatter"].append({"seed": rng.randint(1, 999), "count": 160, "area": [0, 0, W, H], "spacing": 90, "assets": ["prop.rock_small_a", "prop.rock_small_b", "prop.stones", "prop.stones"]})
    for r in roads:
        for i in range(len(r) - 1):
            a, b = r[i], r[i + 1]
            L["scatter_avoid"].append([min(a[0], b[0]) - 90, min(a[1], b[1]) - 90, abs(a[0] - b[0]) + 180, abs(a[1] - b[1]) + 180])

    def free_spot(margin=300, avoid_road=320):
        for _ in range(200):
            p = (rng.uniform(500, W - 500), rng.uniform(500, H - 500))
            if near_roads(p, roads, avoid_road) or any(near_poly(p, m["polygon"], margin) for m in ridges):
                continue
            if any(math.dist(p, g["pos"]) < 1100 for g in gates):
                continue
            if any("collision" in q and math.dist(p, q["pos"]) < 260 for q in props):
                continue
            return [round(p[0]), round(p[1])]
        return None
    # creatures (scale with tier through the location tier, see Session)
    cr = L["creatures"]
    for k in range(th["packs"]):
        c = free_spot()
        if c:
            for i in range(3 + (1 if tier >= 3 else 0)):
                cr.append({"id": f"skirr_{k}_{i}", "species": "skirr", "pack": f"{node}_{k}", "spawn": [c[0] + i * 70 - 100, c[1] + (i % 2) * 60]})
    for k in range(th["grind"]):
        c = free_spot()
        if c:
            cr.append({"id": f"grindback_{k}", "species": "grindback", "spawn": c})
    quarry = None
    for k in range(th["eis"]):
        route = []
        for _ in range(7):
            p = free_spot(330, 200)
            if p:
                route.append(p)
        if len(route) >= 4:
            # order the route around its centroid so the animal walks a loop
            mx = sum(p[0] for p in route) / len(route); my = sum(p[1] for p in route) / len(route)
            route.sort(key=lambda p: math.atan2(p[1] - my, p[0] - mx))
            lair = free_spot(320, 400) or route[0]
            cid = f"eisback_{k}"
            cr.append({"id": cid, "species": "rimeback", "spawn": route[0], "route": route, "lair": lair, "heading_deg": 90})
            quarry = quarry or cid
    L["quarry"] = quarry
    # rival cars (Rostfeld scavengers, Frostgrund raiders)
    for k in range(th["rivals"]):
        c = free_spot(260, 0)
        if c:
            ring = [[c[0], c[1]], [c[0] + 400, c[1]], [c[0] + 400, c[1] + 400], [c[0], c[1] + 400]]
            if all(not any(near_poly(q, m["polygon"], 160) for m in ridges) for q in ring):
                L["enemies"].append({"id": f"rival_{k}", "type": "junker" if k % 2 else "scrapper", "spawn": c, "heading_deg": 90, "patrol": ring})
    # points of interest: abandoned expeditions + landmarks (hidden as anomalies until found)
    loot_tables = [{"salvaged_parts": 2, "logbook": 1}, {"instrument": 1}, {}, {"scrap": 6, "radiator_core": 1}, {"salvaged_parts": 1}]
    names = ["POI_EXPEDITION", "POI_EXPEDITION", "POI_EXPEDITION"]
    for k in range(3 + (1 if tier >= 3 else 0)):
        p = free_spot(260, 180)
        if p:
            L["pois"].append({"id": f"exp_{k}", "kind": "expedition", "pos": p, "name": names[k % len(names)], "burning": k % 2 == 0,
                              "wreck": "rival.wreck" if k % 2 else "road.car", "loot": loot_tables[(k + tier) % len(loot_tables)]})
    lm = free_spot(260, 150)
    if lm:
        L["pois"].append({"id": "landmark_0", "kind": "landmark", "pos": lm, "name": f"POI_LANDMARK_{node.upper()}",
                          "asset": {"salzpfanne": "wreck.pump_rig", "rostfeld": "wreck.hauler", "weissgrat": "prop.pylon", "frostgrund": "prop.solar_wreck"}[node], "loot": {}})
    L["teleports"]["hub"] = {"pos": hub, "heading_deg": 90}
    for g in gates:
        L["teleports"][g["id"]] = {"pos": g["entry"], "heading_deg": g["heading_deg"]}
    L["_roads"] = roads
    return L


# ----------------------------------------------------------------------------- Taubecken (existing basin)
def patch_basin():
    d = BASIN
    d["node"] = "taubecken"; d["kind"] = "territory"; d["tier"] = 1; d["name"] = "NODE_TAUBECKEN"
    b = d["bounds"]  # [-2600, 0, 9400, 6200]
    d["gates"] = [
        {"id": "gate_ersthafen", "to": "ersthafen", "side": "w", "pos": [b[0], 3330], "entry": [b[0] + 420, 3330], "heading_deg": 90},
        {"id": "gate_kaltbrunn", "to": "kaltbrunn", "side": "e", "pos": [b[0] + b[2], 2150], "entry": [b[0] + b[2] - 420, 2150], "heading_deg": 270},
        {"id": "gate_rostfeld", "to": "rostfeld", "side": "e", "pos": [b[0] + b[2], 2700], "entry": [b[0] + b[2] - 420, 2700], "heading_deg": 270},
    ]
    d["quarry"] = "rimeback"
    d["relief"] = {"seed": 4242, "amp": 1.0, "scale": 950.0}
    d["weather_mult"] = 1.0
    d["zone_types"].update({k: ZT[k] for k in ("settlement", "frost", "scorch")})
    d["pois"] = [
        {"id": "exp_basin_0", "kind": "expedition", "pos": [1700, 5600], "name": "POI_EXPEDITION", "burning": True, "wreck": "road.car", "loot": {"salvaged_parts": 1, "logbook": 1}},
        {"id": "exp_basin_1", "kind": "expedition", "pos": [2300, 5300], "name": "POI_EXPEDITION", "burning": False, "wreck": "rival.wreck", "loot": {}},
        {"id": "landmark_refuge", "kind": "landmark", "pos": [-1440, 930], "name": "POI_LANDMARK_REFUGE", "asset": "", "loot": {}},
        {"id": "landmark_station", "kind": "landmark", "pos": [4400, 1260], "name": "POI_LANDMARK_STATION", "asset": "", "loot": {}},
    ]
    d["garage"]["services"] = ["repair", "storage"]
    d["garage"]["name"] = "GARAGE_REFUGE"
    roads = [p["path"] for p in d["patches"] if "path" in p]
    d["_roads"] = roads
    return d


# ----------------------------------------------------------------------------- validation + write
def validate(L):
    masses = L["terrain"]["masses"]
    props = [p for p in L["props"] if "collision" in p]
    def blocked(pt, m_margin, p_margin):
        for m in masses:
            if near_poly(pt, m["polygon"], m_margin):
                return "rock " + m["id"]
        for p in props:
            r = p["collision"].get("circle") or max(p["collision"].get("rect", [0, 0])) / 2
            if math.dist(pt, p["pos"]) < r + p_margin:
                return "prop " + p["id"]
        return ""
    for g in L.get("gates", []):
        for q in (g["entry"],):
            w = blocked(q, 200, 140)
            if w:
                errs.append(f"{L['id']}: gate {g['id']} entry blocked by {w}")
    for c in L.get("creatures", []):
        w = blocked(c["spawn"], 120, 80 if c["species"] != "skirr" else 0)
        if w:
            errs.append(f"{L['id']}: creature {c['id']} in {w}")
        for q in c.get("route", []):
            w = blocked(q, 170, 150)
            if w:
                errs.append(f"{L['id']}: route of {c['id']} at {q} in {w}")
    for p in L.get("pois", []):
        w = blocked(p["pos"], 120, 60) if p["kind"] != "landmark" else ""
        if w:
            errs.append(f"{L['id']}: poi {p['id']} in {w}")
    if L.get("kind") != "territory" or L["id"] != "desert_basin_01":
        for r in L.get("_roads", []):
            for i in range(len(r) - 1):
                for k in range(11):
                    t = k / 10
                    pt = (r[i][0] + (r[i + 1][0] - r[i][0]) * t, r[i][1] + (r[i + 1][1] - r[i][1]) * t)
                    w = blocked(pt, 90, 60)
                    if w and not w.startswith("prop werkstatt") and not w.startswith("prop town_sign"):
                        errs.append(f"{L['id']}: road blocked at {tuple(round(v) for v in pt)} by {w}")
                        break


def write(L, path):
    L.pop("_roads", None)
    json.dump(L, open(path, "w"), indent="\t", ensure_ascii=False)


SIDES = {
    "ersthafen": {"taubecken": "e"},
    "kaltbrunn": {"taubecken": "w", "salzpfanne": "e"},
    "eisenhalt": {"salzpfanne": "n", "rostfeld": "w", "frostgrund": "e"},
    "stahlheim": {"frostgrund": "s"},
    "salzpfanne": {"kaltbrunn": "w", "eisenhalt": "s"},
    "rostfeld": {"taubecken": "w", "eisenhalt": "n", "weissgrat": "e"},
    "weissgrat": {"rostfeld": "w", "frostgrund": "n"},
    "frostgrund": {"eisenhalt": "w", "weissgrat": "s", "stahlheim": "n"},
}
out = {}
for node, n in NODES.items():
    if n["location"] == "desert_basin_01":
        continue
    L = settlement(node, big=n["kind"] == "hub", sides=SIDES.get(node)) if n["kind"] in ("settlement", "hub") else territory(node, SIDES.get(node))
    validate(L)
    out[n["location"]] = L
basin = patch_basin()
validate(basin)
for pid, L in out.items():
    write(L, os.path.join(ROOT, f"data/locations/{pid}.json"))
write(basin, BASIN_P)
print("\n".join(errs) if errs else f"continent OK ({len(out) + 1} locations)")
sys.exit(1 if errs else 0)
