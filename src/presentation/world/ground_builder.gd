class_name GroundBuilder
extends RefCounted
## Ground layer: a base tile over the whole location, then polygon patches
## (dunes, salt flats) and textured path strips (tracks). Tiles are seamless and
## repeat in world space, so the ground never slides or stretches.


static func build(parent: Node2D, loc: Dictionary) -> void:
	var b: Array = loc.get("bounds", [0, 0, 3600, 2600])
	var pad := 400.0
	var base := PackedVector2Array([Vector2(b[0] - pad, b[1] - pad), Vector2(b[0] + b[2] + pad, b[1] - pad),
		Vector2(b[0] + b[2] + pad, b[1] + b[3] + pad), Vector2(b[0] - pad, b[1] + b[3] + pad)])
	parent.add_child(_poly("BaseSand", base, str(loc.get("base_tile", "ground.sand"))))
	for p in loc.get("patches", []):
		if p.has("polygon"):
			parent.add_child(_poly(str(p["id"]), Content.poly(p["polygon"]), str(p["tile"])))
		elif p.has("path"):
			parent.add_child(_path(p))


static func _poly(n: String, pts: PackedVector2Array, tile: String) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.name = n
	poly.polygon = pts
	var tex := Assets.texture(tile)
	poly.texture = tex
	poly.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var disp := Assets.display_size(tile)
	poly.texture_scale = Vector2(tex.get_width() / disp.x, tex.get_height() / disp.y)
	poly.set_meta("asset", tile)
	return poly


static func _path(p: Dictionary) -> Line2D:
	var l := Line2D.new()
	l.name = str(p["id"])
	l.points = Content.poly(p["path"])
	l.width = float(p.get("width", 90.0))
	var tile := str(p["tile"])
	l.texture = Assets.texture(tile)
	l.texture_mode = Line2D.LINE_TEXTURE_TILE
	l.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	l.set_meta("asset", tile)
	return l
