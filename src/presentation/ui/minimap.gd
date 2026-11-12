class_name Minimap
extends Control
## Active minimap (bottom-right): the whole current map scaled down — rock,
## roads, settlement compound, the garage, exit gates (with destination), the
## car's position + heading, discovered points of interest with their icon, and
## undiscovered ones as blinking dots marked "Anomaly Detected".

const W := 250.0
const H := 190.0
var _t := 0.0
var _static_loc := ""
var _scale := 1.0
var _origin := Vector2.ZERO
var _off := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(W, H + 22)
	size = Vector2(W, H + 22)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func to_map(p: Vector2) -> Vector2:
	return _off + (p - _origin) * _scale


func _fit() -> void:
	var b: Array = Session.loc.get("bounds", [0, 0, 3600, 2600])
	_scale = minf((W - 12) / float(b[2]), (H - 12) / float(b[3]))
	_origin = Vector2(b[0], b[1])
	_off = Vector2((W - float(b[2]) * _scale) * 0.5, (H - float(b[3]) * _scale) * 0.5)


func _draw() -> void:
	if not Session.running:
		return
	_fit()
	var font := get_theme_default_font()
	draw_rect(Rect2(0, 0, W, H), Color(0.09, 0.08, 0.07, 0.86))
	var b: Array = Session.loc.get("bounds", [0, 0, 3600, 2600])
	draw_rect(Rect2(to_map(Vector2(b[0], b[1])), Vector2(b[2], b[3]) * _scale), Color(0.62, 0.5, 0.34, 0.55))
	for p in Session.loc.get("patches", []):
		if p.has("path"):
			var pts := PackedVector2Array()
			for q in p["path"]:
				pts.append(to_map(Content.v2(q)))
			draw_polyline(pts, Color(0.86, 0.78, 0.6, 0.85), maxf(1.5, float(p.get("width", 90)) * _scale), true)
		elif p.has("polygon") and str(p.get("tile", "")) == "ground.saltpan":
			draw_colored_polygon(_poly(p["polygon"]), Color(0.9, 0.88, 0.8, 0.25))
	for m in Session.loc.get("terrain", {}).get("masses", []):
		var pp := _poly(m["polygon"])
		if pp.size() >= 3:
			draw_colored_polygon(pp, Color(0.28, 0.21, 0.16, 0.95))
	for z in Session.loc.get("zones", []):
		if str(z.get("type", "")) == "settlement":
			draw_polyline(_poly(z["polygon"]) + PackedVector2Array([to_map(Content.v2(z["polygon"][0]))]), Color(0.85, 0.66, 0.2, 0.9), 1.5)
	if Session.loc.has("garage"):
		var g := to_map(Content.v2(Session.loc["garage"]["pos"]))
		draw_rect(Rect2(g - Vector2(4, 4), Vector2(8, 8)), Color(0.35, 0.75, 0.72))
	for g2 in Session.loc.get("gates", []):
		var gp := to_map(Content.v2(g2["pos"]))
		gp = gp.clamp(Vector2(4, 4), Vector2(W - 4, H - 4))
		draw_circle(gp, 4.0, Color(0.9, 0.85, 0.7))
		var name := tr(str(Journey.node(str(g2["to"])).get("name", g2["to"])))
		var tw := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		var lp := (gp - Vector2(tw * 0.5, -14)).clamp(Vector2(2, 10), Vector2(W - tw - 2, H - 4))
		draw_string(font, lp, name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.95, 0.9, 0.78, 0.85))
	# points of interest
	var anomaly := false
	for p2 in Session.loc.get("pois", []):
		var ps := Session.poi_state(str(p2["id"]))
		var at := to_map(Content.v2(p2["pos"]))
		if bool(ps["discovered"]):
			var col := Color(0.55, 0.55, 0.5) if bool(ps.get("searched", false)) else Color(0.95, 0.6, 0.25)
			if str(p2.get("kind", "")) == "landmark":
				col = Color(0.8, 0.8, 0.7)
			draw_rect(Rect2(at - Vector2(3.5, 3.5), Vector2(7, 7)), col)
			draw_rect(Rect2(at - Vector2(3.5, 3.5), Vector2(7, 7)), Color(0.1, 0.08, 0.06), false, 1.0)
		else:
			anomaly = true
			var blink := 0.35 + 0.65 * absf(sin(_t * 3.2 + at.x))
			draw_circle(at, 3.5, Color(0.78, 0.6, 1.0, blink))
			draw_arc(at, 6.0 + 2.0 * sin(_t * 3.2), 0, TAU, 14, Color(0.78, 0.6, 1.0, 0.5 * blink), 1.0)
	# loot glints and the carcass the player is working
	for l in Session.state.get("world", {}).get("loot", []):
		draw_circle(to_map(Content.v2(l["pos"])), 1.6, Color(1.0, 0.85, 0.5, 0.9))
	# the car (or pilot): arrow with heading
	var me := to_map(Session.actor_pos())
	var h := float(Session.mech()["heading"]) if Session.mode() == "mech" else float(Session.pilot().get("facing", 0.0))
	var f := Drive.forward(h)
	var s := Vector2(-f.y, f.x)
	draw_colored_polygon(PackedVector2Array([me + f * 8.0, me - f * 5.0 + s * 5.0, me - f * 2.5, me - f * 5.0 - s * 5.0]), Color(1.0, 0.95, 0.85))
	draw_rect(Rect2(0, 0, W, H), Color(0.82, 0.72, 0.54, 0.45), false, 1.5)
	# footer: map name / anomaly line
	var footer := tr(str(Session.loc.get("name", "")))
	if anomaly:
		footer = tr("ANOMALY_DETECTED") if fmod(_t, 2.4) < 1.6 else footer
	draw_rect(Rect2(0, H, W, 22), Color(0.09, 0.08, 0.07, 0.86))
	draw_string(font, Vector2(6, H + 16), footer, HORIZONTAL_ALIGNMENT_LEFT, W - 12, 13,
		Color(0.85, 0.7, 1.0) if anomaly and fmod(_t, 2.4) < 1.6 else Color(0.92, 0.86, 0.72))


func _poly(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in pts:
		out.append(to_map(Content.v2(q)))
	return out
