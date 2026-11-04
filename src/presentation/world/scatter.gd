class_name Scatter
extends RefCounted
## Seeded decorative dressing (stones, mineral crusts). Purely visual: no
## collision, generated identically every run from the location data.


static func build(parent: Node2D, loc: Dictionary) -> void:
	var avoid: Array[Rect2] = []
	for a in loc.get("scatter_avoid", []):
		avoid.append(Rect2(a[0], a[1], a[2], a[3]))
	var avoid_points: Array[Vector2] = []
	for d in loc.get("props", []):
		avoid_points.append(Content.v2(d["pos"]))
	for s in loc.get("salvage", []):
		avoid_points.append(Content.v2(s["pos"]))
	var patches := {}
	for p in loc.get("patches", []):
		patches[p["id"]] = p
	for group in loc.get("scatter", []):
		var rng := RandomNumberGenerator.new()
		rng.seed = int(group.get("seed", 1))
		var area: Array = group["area"]
		var spacing := float(group.get("spacing", 60.0))
		var placed: Array[Vector2] = []
		var inside_poly := PackedVector2Array()
		if group.has("inside") and patches.has(group["inside"]):
			inside_poly = Content.poly(patches[group["inside"]]["polygon"])
		var assets: Array = group["assets"]
		var tries := 0
		while placed.size() < int(group["count"]) and tries < int(group["count"]) * 30:
			tries += 1
			var p := Vector2(rng.randf_range(area[0], area[0] + area[2]), rng.randf_range(area[1], area[1] + area[3]))
			if not inside_poly.is_empty() and not Geometry2D.is_point_in_polygon(p, inside_poly):
				continue
			var ok := true
			for r in avoid:
				if r.has_point(p):
					ok = false
					break
			if ok:
				for q in avoid_points:
					if q.distance_to(p) < 110.0:
						ok = false
						break
			if ok:
				for q in placed:
					if q.distance_to(p) < spacing:
						ok = false
						break
			if not ok:
				continue
			placed.append(p)
			var pv := PropView.new()
			parent.add_child(pv)
			pv.setup({"id": "scatter_%d_%d" % [int(group.get("seed", 1)), placed.size()],
				"asset": assets[rng.randi() % assets.size()], "pos": [p.x, p.y], "rot": rng.randf_range(0, 360)})
