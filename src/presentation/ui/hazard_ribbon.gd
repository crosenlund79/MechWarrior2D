class_name HazardRibbon
extends Control
## Weathered hazard tape across the upper-right corner of the screen:
##   DANGER DANGER DANGER          red with black chevrons   — hunting territories
##   SAFE-ZONE SAFE-ZONE …         warning yellow            — settlements
##   CLEARED CLEARED …             faded green-grey          — Stahlheim once the cargo is delivered
## Drawn diagonally in the corner only (mouse-transparent), clear of the HUD panels.

const SIZE := 230.0
var _scroll := 0.0
var _status := ""
var _noise: Texture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = -SIZE
	offset_right = 0.0
	offset_top = 0.0
	offset_bottom = SIZE
	var n := FastNoiseLite.new()
	n.frequency = 0.08
	var img := n.get_image(128, 32)
	_noise = ImageTexture.create_from_image(img)


func _process(delta: float) -> void:
	if not Session.running:
		return
	var st := Session.zone_status()
	if st != _status:
		_status = st
	_scroll = fmod(_scroll + delta * 18.0, 2000.0)
	queue_redraw()


func _draw() -> void:
	if not Session.running:
		return
	var cols := {"danger": [Color("#b0281c"), Color("#1c1612"), Color("#f2e6d0")],
		"safe": [Color("#d9a92a"), Color("#1c1612"), Color("#1c1612")],
		"cleared": [Color("#7d8f78"), Color("#2a2e28"), Color("#f2efe6")]}
	var c: Array = cols.get(_status, cols["danger"])
	var word := {"danger": tr("RIBBON_DANGER"), "safe": tr("RIBBON_SAFE"), "cleared": tr("RIBBON_CLEARED")}.get(_status, "DANGER") as String
	# band along the corner diagonal (from the top edge to the right edge)
	draw_set_transform(Vector2(SIZE * 0.5 + 12, SIZE * 0.5 - 12), PI * 0.25, Vector2.ONE)
	var L := SIZE * 1.6
	var h := 34.0
	var r := Rect2(-L * 0.5, -h * 0.5, L, h)
	draw_rect(Rect2(r.position + Vector2(3, 5), r.size), Color(0, 0, 0, 0.35))   # contact shadow
	draw_rect(r, c[0])
	# stripes on the edges (hazard tape)
	for k in range(-20, 20):
		var x := k * 22.0 + fmod(_scroll, 22.0)
		draw_colored_polygon(PackedVector2Array([Vector2(x, -h * 0.5), Vector2(x + 8, -h * 0.5), Vector2(x + 2, -h * 0.5 + 6), Vector2(x - 6, -h * 0.5 + 6)]), c[1])
		draw_colored_polygon(PackedVector2Array([Vector2(x, h * 0.5 - 6), Vector2(x + 8, h * 0.5 - 6), Vector2(x + 2, h * 0.5), Vector2(x - 6, h * 0.5)]), c[1])
	var font := get_theme_default_font()
	var txt := "  ".join([word, word, word, word])
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	draw_string(font, Vector2(-tw * 0.5, 6), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, c[2])
	# wear: scuffs and dust on the tape
	draw_texture_rect(_noise, r, false, Color(0.25, 0.2, 0.15, 0.22))
	for k in 7:
		var x2 := -L * 0.4 + k * L * 0.13
		draw_line(Vector2(x2, -h * 0.5 + 3), Vector2(x2 + 14, h * 0.5 - 4), Color(0.95, 0.9, 0.8, 0.12), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
