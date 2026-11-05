class_name TerrainView
extends Node2D
## Reusable terrain + covered-space presentation, built from location "terrain":
##  - masses: impassable rock. Textured fill, inked rim, cast shadow on the floor
##    and collision — all from the SAME roughened polygon (Content.terrain).
##  - covers: overhead rock (or any roof). While the mech or pilot is under it, the
##    fill fades smoothly to transparent and only an inked outline + faint rim stay,
##    so nothing underneath is ever hidden. Reuse for caves, tunnels, hangars.
##  - walls: thin built walls (textured strip + matching collision).
##  - cables: sagging power cables lying on the floor.

const FADE_START := 70.0   # px outside the cover where fading begins
const FADE_FULL := 90.0    # px inside where the fill is fully transparent

var covers: Array = []     # [{fill: Polygon2D, rim: Line2D, edge: Line2D, shape: PackedVector2Array, f: float}]


func build(loc: Dictionary, masses_parent: Node2D, covers_parent: Node2D, floor_parent: Node2D) -> void:
	for m in Content.terrain(loc, "masses"):
		var shape: PackedVector2Array = m["shape"]
		var sh := Polygon2D.new()
		sh.polygon = _offset(shape, Vector2(0.45, 0.55) * float(m.get("height", 60.0)))
		sh.color = Color(0.09, 0.06, 0.04, 0.34)
		sh.z_index = -4
		sh.z_as_relative = false
		floor_parent.add_child(sh)
		masses_parent.add_child(_fill(shape, str(m["tile"])))
		masses_parent.add_child(_rim(shape))
		masses_parent.add_child(_edge(shape, 3.2, Color(0.13, 0.105, 0.08, 0.95)))
		var body := StaticBody2D.new()
		body.name = "Rock_" + str(m["id"])
		body.collision_layer = 1
		var cp := CollisionPolygon2D.new()
		cp.polygon = shape
		cp.build_mode = CollisionPolygon2D.BUILD_SOLIDS
		body.add_child(cp)
		masses_parent.add_child(body)
	for c in Content.terrain(loc, "covers"):
		var shape2: PackedVector2Array = c["shape"]
		var entry := {"shape": shape2, "f": 0.0}
		entry["fill"] = _fill(shape2, str(c["tile"]))
		entry["rim"] = _rim(shape2)
		entry["edge"] = _edge(shape2, 3.0, Color(0.13, 0.105, 0.08, 0.95))
		covers_parent.add_child(entry["fill"])
		covers_parent.add_child(entry["rim"])
		covers_parent.add_child(entry["edge"])
		covers.append(entry)
	for w in loc.get("terrain", {}).get("walls", []):
		var tex := Assets.texture(str(w.get("tile", "refuge.wall_strip")))
		var body2 := StaticBody2D.new()
		body2.name = "Walls_" + str(w["id"])
		masses_parent.add_child(body2)
		for seg in w["segments"]:
			var a := Content.v2(seg[0])
			var b := Content.v2(seg[1])
			var l := Line2D.new()
			l.points = PackedVector2Array([a, b])
			l.width = float(w.get("width", 24.0))
			l.texture = tex
			l.texture_mode = Line2D.LINE_TEXTURE_TILE
			l.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			l.begin_cap_mode = Line2D.LINE_CAP_BOX
			l.end_cap_mode = Line2D.LINE_CAP_BOX
			masses_parent.add_child(l)
			var cs := CollisionShape2D.new()
			var r := RectangleShape2D.new()
			r.size = Vector2(a.distance_to(b) + float(w.get("width", 24.0)), float(w.get("width", 24.0)))
			cs.shape = r
			cs.position = (a + b) * 0.5
			cs.rotation = (b - a).angle()
			body2.add_child(cs)
	for cb in loc.get("terrain", {}).get("cables", []):
		var a2 := Content.v2(cb["from"])
		var b2 := Content.v2(cb["to"])
		var mid := (a2 + b2) * 0.5 + Content.v2(cb.get("sag", [0, 0]))
		var pts := PackedVector2Array()
		for i in 17:
			var t := i / 16.0
			pts.append(a2.lerp(mid, t).lerp(mid.lerp(b2, t), t))
		var dark := Line2D.new()
		dark.points = pts
		dark.width = 5.0
		dark.default_color = Color(0.11, 0.09, 0.07, 0.95)
		dark.joint_mode = Line2D.LINE_JOINT_ROUND
		floor_parent.add_child(dark)
		var hi := Line2D.new()
		hi.points = _offset(pts, Vector2(-0.8, -0.8))
		hi.width = 1.4
		hi.default_color = Color(0.55, 0.5, 0.42, 0.55)
		floor_parent.add_child(hi)


func _offset(pts: PackedVector2Array, o: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + o)
	return out


func _fill(shape: PackedVector2Array, tile: String) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.polygon = shape
	var tex := Assets.texture(tile)
	poly.texture = tex
	poly.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var disp := Assets.display_size(tile)
	poly.texture_scale = Vector2(tex.get_width() / disp.x, tex.get_height() / disp.y)
	return poly


func _closed(shape: PackedVector2Array) -> PackedVector2Array:
	var pts := shape.duplicate()
	pts.append(shape[0])
	return pts


func _rim(shape: PackedVector2Array) -> Line2D:
	var l := Line2D.new()
	l.points = _closed(shape)
	l.width = 34.0
	l.texture = Assets.texture("terrain.cliff_rim")
	l.texture_mode = Line2D.LINE_TEXTURE_TILE
	l.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	return l


func _edge(shape: PackedVector2Array, w: float, col: Color) -> Line2D:
	var l := Line2D.new()
	l.points = _closed(shape)
	l.width = w
	l.default_color = col
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	var curve := Curve.new()   # brush-like width variation along the stroke
	for i in 9:
		curve.add_point(Vector2(i / 8.0, 0.65 + 0.35 * absf(sin(i * 1.7))))
	l.width_curve = curve
	return l


## Signed depth of p inside the polygon (positive inside, negative outside), px.
static func depth(shape: PackedVector2Array, p: Vector2) -> float:
	var best := INF
	for i in shape.size():
		var a := shape[i]
		var b := shape[(i + 1) % shape.size()]
		best = minf(best, Combat.seg_dist(a, b, p))
	return best if Geometry2D.is_point_in_polygon(p, shape) else -best


## 0 = nothing under any cover, 1 = fully under a cover (for atmosphere/audio).
func coverage(points: Array) -> float:
	var f := 0.0
	for c in covers:
		for p in points:
			f = maxf(f, clampf((depth(c["shape"], p) + FADE_START) / (FADE_START + FADE_FULL), 0.0, 1.0))
	return f


func update(points: Array, delta: float) -> void:
	for c in covers:
		var target := 0.0
		for p in points:
			target = maxf(target, clampf((depth(c["shape"], p) + FADE_START) / (FADE_START + FADE_FULL), 0.0, 1.0))
		c["f"] = move_toward(float(c["f"]), target, delta * 2.5)
		var f := smoothstep(0.0, 1.0, float(c["f"]))
		(c["fill"] as Polygon2D).modulate.a = 1.0 - f
		(c["rim"] as Line2D).modulate.a = 1.0 - f * 0.75
		(c["edge"] as Line2D).modulate.a = 1.0 - f * 0.25
