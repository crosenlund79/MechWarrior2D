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
			parent.add_child(_soft_patch(p))
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


## Patch drawn over its padded bounding box; alpha comes from a low-res mask of
## the polygon (linear-filtered) broken up by world-space noise, so patch edges
## read as drifted sand rather than hard polygon cuts. Gameplay zones still use
## the exact polygon.
const PATCH_SHADER := """
shader_type canvas_item;
uniform sampler2D mask_tex : filter_linear;
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform vec2 mask_origin;
uniform vec2 mask_size;
varying vec2 wp;
void vertex() { wp = VERTEX; }
void fragment() {
	float m = texture(mask_tex, (wp - mask_origin) / mask_size).r;
	float n = texture(noise_tex, wp / 300.0).a + texture(noise_tex, wp / 90.0).a * 0.5;
	COLOR.a *= smoothstep(0.42, 0.58, m + (n - 0.62) * 0.9);
}
"""
const CELL := 16.0
static var _shader: Shader


static func _soft_patch(p: Dictionary) -> Polygon2D:
	var pts := Content.poly(p["polygon"])
	var r := Rect2(pts[0], Vector2.ZERO)
	for v in pts:
		r = r.expand(v)
	r = r.grow(160.0)
	var w := int(ceil(r.size.x / CELL))
	var h := int(ceil(r.size.y / CELL))
	var img := Image.create(w, h, false, Image.FORMAT_L8)
	for y in h:
		for x in w:
			var c := r.position + Vector2((x + 0.5) * CELL, (y + 0.5) * CELL)
			img.set_pixel(x, y, Color.WHITE if Geometry2D.is_point_in_polygon(c, pts) else Color.BLACK)
	# Blur the mask (down + up resample) so the noise can push the edge around.
	img.resize(maxi(2, w / 5), maxi(2, h / 5), Image.INTERPOLATE_LANCZOS)
	img.resize(w, h, Image.INTERPOLATE_CUBIC)
	var poly := _poly(str(p["id"]), PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), str(p["tile"]))
	if _shader == null:
		_shader = Shader.new()
		_shader.code = PATCH_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("mask_tex", ImageTexture.create_from_image(img))
	var noise_path := "res://assets/fx/haze.png"
	if ResourceLoader.exists(noise_path):
		mat.set_shader_parameter("noise_tex", load(noise_path))
	mat.set_shader_parameter("mask_origin", r.position)
	mat.set_shader_parameter("mask_size", Vector2(w, h) * CELL)
	poly.material = mat
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
