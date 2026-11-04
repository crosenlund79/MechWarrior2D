class_name Combat
extends RefCounted
## Basic ranged combat as plain data. Projectiles are runtime-only dictionaries
## {owner, pos, vel, travelled, range, damage, cooling_damage, radius}.
## Two damage categories: structural integrity and the cooling system. A hit
## inside the target's cooling hit area (a circle at a local offset, matching
## the illustrated radiator) damages the radiator; elsewhere it damages
## structure (plus a tiny cooling knock-on).


static func make_shot(owner: String, origin: Vector2, dir: Vector2, w: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var spread := deg_to_rad(float(w.get("spread_deg", 0.0)))
	var d := dir.normalized().rotated(rng.randf_range(-spread, spread))
	return {"owner": owner, "pos": origin, "prev": origin, "vel": d * float(w.get("speed", 400.0)), "travelled": 0.0,
		"range": float(w.get("range", 600.0)), "damage": float(w.get("damage", 5.0)),
		"cooling_damage": float(w.get("cooling_damage", 0.05)),
		"structural_cooling_damage": float(w.get("structural_cooling_damage", 0.0)),
		"radius": float(w.get("radius", 5.0))}


## World-space centre of a mech's cooling hit area.
static func cooling_point(pos: Vector2, heading: float, hit: Dictionary) -> Vector2:
	return pos + Content.v2(hit.get("cooling_offset", [0, 0])).rotated(heading)


## Closest distance from point c to the segment a→b.
static func seg_dist(a: Vector2, b: Vector2, c: Vector2) -> float:
	var ab := b - a
	var t := 0.0 if ab.length_squared() < 0.0001 else clampf((c - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return (a + ab * t).distance_to(c)


## Tests one moved projectile against a target. Returns "" (miss), "cooling" or "structure".
static func hit_test(shot: Dictionary, pos: Vector2, heading: float, hit: Dictionary) -> String:
	var a: Vector2 = shot["prev"]
	var b: Vector2 = shot["pos"]
	var r := float(shot["radius"])
	var cp := cooling_point(pos, heading, hit)
	if seg_dist(a, b, cp) <= float(hit.get("cooling_radius", 30.0)) + r:
		return "cooling"
	if seg_dist(a, b, pos) <= float(hit.get("body_radius", 80.0)) + r:
		return "structure"
	return ""


## Applies a hit to a mech dictionary (needs integrity + radiator). Returns the damage kind.
static func apply_hit(m: Dictionary, shot: Dictionary, kind: String) -> void:
	if kind == "cooling":
		m["radiator"] = maxf(0.0, float(m["radiator"]) - float(shot["cooling_damage"]))
		m["integrity"] = maxf(0.0, float(m["integrity"]) - float(shot["damage"]) * 0.5)
	else:
		m["integrity"] = maxf(0.0, float(m["integrity"]) - float(shot["damage"]))
		m["radiator"] = maxf(0.0, float(m["radiator"]) - float(shot["structural_cooling_damage"]))
