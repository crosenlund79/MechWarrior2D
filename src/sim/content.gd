class_name Content
extends RefCounted
## Read-only game data: tuning (balance), items and the location definition.
## Loaded once; tests may call reload().

const TUNING := "res://data/tuning.json"
const ITEMS := "res://data/items.json"
const LOCATION_DIR := "res://data/locations/"
const DEFAULT_LOCATION := "desert_basin_01"

static var tuning: Dictionary = {}
static var items: Dictionary = {}
static var _locations: Dictionary = {}
static var problems: Array[String] = []


static func ensure() -> void:
	if tuning.is_empty():
		reload()


static func reload() -> void:
	problems.clear()
	_locations.clear()
	_terrain_cache.clear()
	var t = SafeFile.read_json(TUNING)
	tuning = t if t is Dictionary else {}
	if t is String:
		problems.append("tuning: " + t)
	var i = SafeFile.read_json(ITEMS)
	items = i if i is Dictionary else {}
	if i is String:
		problems.append("items: " + i)


static func t(section: String, key: String, default_value: float = 0.0) -> float:
	ensure()
	return float(tuning.get(section, {}).get(key, default_value))


static func location(id: String = DEFAULT_LOCATION) -> Dictionary:
	ensure()
	if not _locations.has(id):
		var d = SafeFile.read_json(LOCATION_DIR + id + ".json")
		if d is String:
			problems.append("location %s: %s" % [id, d])
			d = {}
		_locations[id] = d
	return _locations[id]


static func is_item(id: String) -> bool:
	ensure()
	return items.has(id)


## Roughens a polygon deterministically: edges are subdivided every `step` px and
## each new point is pushed along the edge normal by smooth hashed noise of
## amplitude `rough`. Used for rock masses so the SAME outline drives both the
## illustrated terrain and its collision.
static func organic(pts: PackedVector2Array, rough: float, seed: int, step: float = 46.0) -> PackedVector2Array:
	if rough <= 0.0:
		return pts
	var out := PackedVector2Array()
	var n := pts.size()
	var k := 0
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		var seg := b - a
		var count := maxi(1, int(seg.length() / step))
		var nrm := Vector2(-seg.y, seg.x).normalized()
		for j in count:
			var t := float(j) / count
			var p := a + seg * t
			if j > 0:
				var h := sin(float(k) * 1.7 + seed * 3.1) * 0.6 + sin(float(k) * 0.53 + seed) * 0.4
				p += nrm * h * rough
			out.append(p)
			k += 1
	return out


static var _terrain_cache := {}


## Terrain pieces with their roughened polygons ("masses", "covers").
static func terrain(loc: Dictionary, kind: String) -> Array:
	var key := str(loc.get("id", "")) + ":" + kind
	if _terrain_cache.has(key):
		return _terrain_cache[key]
	var out: Array = []
	for t in loc.get("terrain", {}).get(kind, []):
		var d: Dictionary = t.duplicate()
		d["shape"] = organic(poly(t["polygon"]), float(t.get("rough", 0.0)), int(t.get("seed", 1)))
		out.append(d)
	_terrain_cache[key] = out
	return out


static func v2(a) -> Vector2:
	if a is Array and a.size() >= 2:
		return Vector2(float(a[0]), float(a[1]))
	return Vector2.ZERO


static func poly(a: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in a:
		out.append(v2(p))
	return out


## Environmental conditions at a world position (first matching zone wins,
## explicit zones before ground-patch zones).
static func zone_at(loc: Dictionary, pos: Vector2) -> Dictionary:
	var types: Dictionary = loc.get("zone_types", {})
	for z in loc.get("zones", []):
		if Geometry2D.is_point_in_polygon(pos, poly(z["polygon"])):
			var d: Dictionary = types.get(z["type"], {}).duplicate()
			d["id"] = z["id"]
			d["type"] = z["type"]
			return d
	for p in loc.get("patches", []):
		if p.has("zone") and p.has("polygon") and Geometry2D.is_point_in_polygon(pos, poly(p["polygon"])):
			var d2: Dictionary = types.get(p["zone"], {}).duplicate()
			d2["id"] = p["id"]
			d2["type"] = p["zone"]
			return d2
	var d3: Dictionary = loc.get("default_zone", {"ambient": 58.0, "solar": 1.0, "abrasion": 1.0, "drag": 1.0, "suit": 1.0}).duplicate()
	d3["id"] = "open"
	d3["type"] = "open"
	return d3
