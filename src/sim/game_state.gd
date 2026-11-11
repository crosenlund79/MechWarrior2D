class_name GameState
extends RefCounted
## Plain-data game state (one Dictionary, JSON-safe). Created here, owned by
## Session, serialised by SaveCodec. Scenes read it; they never own it.

const MODES := ["mech", "foot", "collapsed"]
const ENGINE := ["running", "off", "shutdown"]


static func create(loc: Dictionary, slot: int) -> Dictionary:
	Content.ensure()
	var start: Dictionary = loc.get("mech_start", {})
	var p := Content.v2(start.get("pos", [800, 1250]))
	return {
		"id": "run_%d_%d" % [int(Time.get_unix_time_from_system()), randi() % 100000],
		"slot": slot,
		"created_unix": int(Time.get_unix_time_from_system()),
		"playtime": 0.0,
		"location": str(loc.get("id", Content.DEFAULT_LOCATION)),
		"mode": "mech",
		"mech": {
			"id": "mech_starter",
			"pos": [p.x, p.y],
			"heading": deg_to_rad(float(start.get("heading_deg", 0.0))),
			"speed": 0.0,
			"heat": Content.t("thermal", "start_heat", 72.0),
			"radiator": Content.t("thermal", "start_radiator", 0.3),
			"shutters_open": true,
			"engine": "running",
			"integrity": Content.t("mech", "integrity", 100.0),
			"storage": {"scrap": 6},
			"vel": [0.0, 0.0],
			"slip": 0.0,
			"upgrades": {},
		},
		"pilot": {
			"pos": [p.x, p.y],
			"facing": 0.0,
			"suit": Content.t("suit", "max", 100.0),
			"strain": 0.0,
			"pack": {},
		},
		"world": {"taken": {}, "drops": [], "next_drop": 1, "loot": [], "next_loot": 1},
		"garage": {"storage": {}, "unloads": 0},
		"enemies": create_enemies(loc),
		"creatures": create_creatures(loc),
		"tracks": seed_tracks(loc),
		"turrets": create_turrets(loc),
		"weather": Weather.create(Content.tuning.get("weather", {})),
		"stats": {"repairs": 0, "overheats": 0, "salvaged": 0, "collapses": 0, "distance": 0.0, "kills": 0, "harvests": 0, "upgrades": 0},
	}


## Creatures from the location, keyed by stable IDs.
static func create_creatures(loc: Dictionary) -> Dictionary:
	var out := {}
	var tc: Dictionary = Content.tuning.get("creatures", {})
	for d in loc.get("creatures", []):
		out[str(d["id"])] = Creatures.create(d, tc)
	return out


## Old rimeback tracks along its grazing route (so a new run has sign to find):
## walked backwards from the spawn, older the further back.
static func seed_tracks(loc: Dictionary) -> Array:
	var route: Array = loc.get("rimeback_route", [])
	var out: Array = []
	if route.size() < 2:
		return out
	var tr: Dictionary = Content.tuning.get("creatures", {}).get("rimeback", {})
	var every := float(tr.get("track_every", 90.0))
	var speed := maxf(float(tr.get("roam_speed", 80.0)), 1.0)
	var life := float(Content.tuning.get("creatures", {}).get("track_life", 420.0))
	var age := 2.0
	var i := 0
	var n := route.size()
	while age < life * 0.85 and i < n:
		var a := Content.v2(route[(n - i) % n])
		var b := Content.v2(route[(n - i - 1) % n])
		var seg := a.distance_to(b)
		var k := 0.0
		while k < seg:
			var p := a.lerp(b, k / seg)
			var h := atan2((a - b).x, -(a - b).y)   # the animal walked b → a
			out.append({"s": "rimeback", "p": [p.x, p.y], "h": h, "t": -age, "b": false})
			k += every
			age += every / speed
		age += float(tr.get("graze_time", 4.0))
		i += 1
	out.reverse()
	return out


static func create_turrets(loc: Dictionary) -> Dictionary:
	var out := {}
	for d in loc.get("turrets", []):
		out[str(d["id"])] = Turret.create(d, Content.tuning.get("turret", {}))
	return out


## Enemy mechs from the location definition, keyed by their stable IDs.
static func create_enemies(loc: Dictionary) -> Dictionary:
	var out := {}
	for d in loc.get("enemies", []):
		out[str(d["id"])] = new_enemy(d)
	return out


static func _etype(d: Dictionary, key: String) -> float:
	var ov: Dictionary = Content.tuning.get("enemy_types", {}).get(str(d.get("type", "scrapper")), {})
	return float(ov.get(key, Content.t("enemy", key, 0.0)))


static func new_enemy(d: Dictionary) -> Dictionary:
	var p := Content.v2(d.get("spawn", [0, 0]))
	var parked := bool(d.get("parked", false))
	var pp := Content.v2(d.get("pilot_spawn", d.get("spawn", [0, 0])))
	return {"type": str(d.get("type", "scrapper")), "pos": [p.x, p.y], "heading": deg_to_rad(float(d.get("heading_deg", 0.0))),
		"speed": 0.0, "heat": Content.t("enemy", "start_heat", 66.0) - (8.0 if parked else 0.0), "radiator": _etype(d, "start_radiator"),
		"shutters_open": true, "engine": "off" if parked else "running", "integrity": _etype(d, "integrity"),
		"ai": "unpiloted" if parked else "patrol", "salvaged": false,
		"pilot": {"state": "outside" if parked else "aboard", "pos": [pp.x, pp.y], "facing": 0.0}}


## Fills missing keys with defaults and clamps ranges. Used after loading.
static func sanitize(s: Dictionary, loc: Dictionary) -> Dictionary:
	var d := create(loc, int(s.get("slot", 1)))
	for key in d:
		if not s.has(key) or typeof(s[key]) != typeof(d[key]):
			s[key] = d[key]
	for sub in ["mech", "pilot", "world", "stats"]:
		for key in d[sub]:
			if not s[sub].has(key) or typeof(s[sub][key]) != typeof(d[sub][key]):
				# JSON loads every number as float; accept int/float interchangeably.
				if s[sub].has(key) and (typeof(s[sub][key]) in [TYPE_INT, TYPE_FLOAT]) and (typeof(d[sub][key]) in [TYPE_INT, TYPE_FLOAT]):
					continue
				s[sub][key] = d[sub][key]
	if not MODES.has(s["mode"]):
		s["mode"] = "mech"
	if s["mode"] == "collapsed":
		s["mode"] = "mech"
	var m: Dictionary = s["mech"]
	if not ENGINE.has(m["engine"]):
		m["engine"] = "off"
	m["heat"] = clampf(float(m["heat"]), 0.0, Content.t("thermal", "max_temp", 135.0))
	m["radiator"] = clampf(float(m["radiator"]), 0.0, 1.0)
	m["speed"] = 0.0
	if s["mode"] == "mech" and m["engine"] == "off":
		m["engine"] = "running"
	var pl: Dictionary = s["pilot"]
	pl["suit"] = clampf(float(pl["suit"]), 0.0, Content.t("suit", "max", 100.0))
	pl["strain"] = clampf(float(pl["strain"]), 0.0, 0.99)
	m["storage"] = clean_inventory(m["storage"])
	pl["pack"] = clean_inventory(pl["pack"])
	var drops: Array = []
	for dr in s["world"]["drops"]:
		if dr is Dictionary and dr.has("id") and dr.has("pos"):
			dr["items"] = clean_inventory(dr.get("items", {}))
			drops.append(dr)
	s["world"]["drops"] = drops
	m["integrity"] = clampf(float(m["integrity"]), 0.0, Content.t("mech", "integrity", 100.0) + 200.0)
	# Enemies: keep known IDs, add missing ones, drop ones no longer in the location.
	var en := {}
	var have: Dictionary = s.get("enemies", {}) if s.get("enemies") is Dictionary else {}
	for ed in loc.get("enemies", []):
		var id := str(ed["id"])
		var fresh := new_enemy(ed)
		var e: Dictionary = have.get(id, fresh) if have.get(id) is Dictionary else fresh
		for k in fresh:
			if not e.has(k):
				e[k] = fresh[k]
		if not (str(e["ai"]) in ["patrol", "alert", "engage", "retreat", "return", "wreck"] or Encounter.is_encounter_state(str(e["ai"]))):
			e["ai"] = "patrol"
		if not (e["pilot"] is Dictionary) or not e["pilot"].has("state"):
			e["pilot"] = fresh["pilot"]
		if str(e["ai"]) in ["alert", "engage", "retreat"]:
			e["ai"] = "return"   # resume calmly after loading
		Encounter.resolve_on_load(e)
		e["speed"] = 0.0
		e["salvaged"] = bool(e["salvaged"])
		e["radiator"] = clampf(float(e["radiator"]), 0.0, 1.0)
		e["integrity"] = maxf(0.0, float(e["integrity"]))
		en[id] = e
	s["enemies"] = en
	# Turrets: keep destroyed/salvaged state for known IDs, create missing ones.
	var tu := {}
	var had: Dictionary = s.get("turrets", {}) if s.get("turrets") is Dictionary else {}
	for td in loc.get("turrets", []):
		var tid := str(td["id"])
		var ft := Turret.create(td, Content.tuning.get("turret", {}))
		var t: Dictionary = had.get(tid, ft) if had.get(tid) is Dictionary else ft
		for k in ft:
			if not t.has(k):
				t[k] = ft[k]
		t["destroyed"] = bool(t["destroyed"])
		t["salvaged"] = bool(t["salvaged"])
		if bool(t["destroyed"]):
			t["hp"] = 0.0
		tu[tid] = t
	s["turrets"] = tu
	# Creatures: keep known IDs (alive/dead/harvested), add missing ones, resume calmly.
	var cr := {}
	var hadc: Dictionary = s.get("creatures", {}) if s.get("creatures") is Dictionary else {}
	var tc: Dictionary = Content.tuning.get("creatures", {})
	for cd in loc.get("creatures", []):
		var cid := str(cd["id"])
		var fc := Creatures.create(cd, tc)
		var c: Dictionary = hadc.get(cid, fc) if hadc.get(cid) is Dictionary else fc
		for k in fc:
			if not c.has(k) or typeof(c[k]) != typeof(fc[k]):
				if c.has(k) and (typeof(c[k]) in [TYPE_INT, TYPE_FLOAT]) and (typeof(fc[k]) in [TYPE_INT, TYPE_FLOAT]):
					continue
				c[k] = fc[k]
		c["species"] = fc["species"]
		if str(c["ai"]) != "dead":
			c["ai"] = fc["ai"]   # calm state after loading (rimeback roams, grindback buried)
		c["speed"] = 0.0
		c["hp"] = clampf(float(c["hp"]), 0.0, Creatures.max_hp(fc, tc))
		cr[cid] = c
	s["creatures"] = cr
	var tracks: Array = []
	for t in (s.get("tracks", []) if s.get("tracks") is Array else []):
		if t is Dictionary and t.has("p") and t.has("t") and t["p"] is Array:
			tracks.append(t)
	s["tracks"] = tracks
	var loot: Array = []
	for l in (s["world"].get("loot", []) if s["world"].get("loot") is Array else []):
		if l is Dictionary and l.has("id") and l.has("pos") and Content.is_item(str(l.get("item", ""))):
			l["n"] = maxi(1, int(l.get("n", 1)))
			loot.append(l)
	s["world"]["loot"] = loot
	if not s["world"].has("next_loot"):
		s["world"]["next_loot"] = 1
	var up := {}
	if m.get("upgrades") is Dictionary:
		for k in m["upgrades"]:
			if str(k) in Garage.MODULES:
				up[str(k)] = clampi(int(m["upgrades"][k]), 0, Garage.max_level(Content.tuning.get("garage", {}), str(k)))
	m["upgrades"] = up
	m["vel"] = [0.0, 0.0]
	m["slip"] = 0.0
	if not (s.get("garage") is Dictionary):
		s["garage"] = {"storage": {}, "unloads": 0}
	s["garage"]["storage"] = clean_inventory(s["garage"].get("storage", {}))
	s["garage"]["unloads"] = int(s["garage"].get("unloads", 0))
	var wd := Weather.create(Content.tuning.get("weather", {}))
	if not (s.get("weather") is Dictionary) or not (str(s["weather"].get("state", "")) in Weather.STATES):
		s["weather"] = wd
	for k in wd:
		if not s["weather"].has(k):
			s["weather"][k] = wd[k]
	s["weather"]["intensity"] = clampf(float(s["weather"]["intensity"]), 0.0, 1.0)
	var b: Array = loc.get("bounds", [0, 0, 3600, 2600])
	for arr in [m["pos"], pl["pos"]]:
		arr[0] = clampf(float(arr[0]), float(b[0]) + 40.0, float(b[0]) + float(b[2]) - 40.0)
		arr[1] = clampf(float(arr[1]), float(b[1]) + 40.0, float(b[1]) + float(b[3]) - 40.0)
	return s


static func clean_inventory(inv) -> Dictionary:
	var out := {}
	if not (inv is Dictionary):
		return out
	for k in inv:
		var n := int(inv[k])
		if Content.is_item(str(k)) and n > 0:
			out[str(k)] = n
	return out


static func count(inv: Dictionary, item: String) -> int:
	return int(inv.get(item, 0))


static func add(inv: Dictionary, item: String, n: int) -> void:
	inv[item] = count(inv, item) + n
	if int(inv[item]) <= 0:
		inv.erase(item)


static func total(inv: Dictionary) -> int:
	var t := 0
	for k in inv:
		t += int(inv[k])
	return t
