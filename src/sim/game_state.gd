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
			"storage": {},
		},
		"pilot": {
			"pos": [p.x, p.y],
			"facing": 0.0,
			"suit": Content.t("suit", "max", 100.0),
			"strain": 0.0,
			"pack": {},
		},
		"world": {"taken": {}, "drops": [], "next_drop": 1},
		"stats": {"repairs": 0, "overheats": 0, "salvaged": 0, "collapses": 0, "distance": 0.0},
	}


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
