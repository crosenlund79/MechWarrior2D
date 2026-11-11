class_name TrackerWidget
extends Control
## Tracking compass (HUD, bottom-left). When the car (or the pilot) is near
## readable creature sign, shows which species left it, how fresh it is and an
## arrow along the trail (the way the animal went). Blood-marked trails glow red.
## Fresher sign further along the arrow leads to the animal.

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if not Session.running:
		return
	var tk := Session.tracker()
	var c := Vector2(54, 54)
	var base := Color(UiTheme.CHARCOAL, 0.82)
	draw_circle(c, 50.0, base)
	draw_arc(c, 50.0, 0, TAU, 40, Color(UiTheme.STRAW, 0.35), 2.0, true)
	var font := get_theme_default_font()
	if tk.is_empty():
		draw_string(font, Vector2(112, 46), tr("TRACK_NONE"), HORIZONTAL_ALIGNMENT_LEFT, 260, 15, UiTheme.DIM)
		draw_string(font, Vector2(112, 68), tr("TRACK_NONE_SUB"), HORIZONTAL_ALIGNMENT_LEFT, 300, 12, UiTheme.DIM)
		return
	var fresh := float(tk["freshness"])
	var col := UiTheme.DANGER if bool(tk["blood"]) else UiTheme.STRAW.lerp(UiTheme.PAPER, fresh)
	var dir := Drive.forward(float(tk["heading"]))
	var tip := c + dir * 40.0
	var side := Vector2(-dir.y, dir.x)
	var pulse := 0.8 + 0.2 * sin(_t * (2.0 + fresh * 6.0))
	draw_colored_polygon(PackedVector2Array([tip, c - dir * 14.0 + side * 16.0, c - dir * 4.0, c - dir * 14.0 - side * 16.0]), Color(col, pulse))
	draw_string(font, Vector2(112, 40), tr("TRACK_SPECIES") % tr("SPECIES_" + str(tk["species"]).to_upper()), HORIZONTAL_ALIGNMENT_LEFT, 300, 16, col)
	var age_key := "TRACK_FRESH" if fresh > 0.7 else ("TRACK_RECENT" if fresh > 0.35 else "TRACK_OLD")
	draw_string(font, Vector2(112, 62), tr(age_key) + ("  ·  " + tr("TRACK_BLOOD") if bool(tk["blood"]) else ""), HORIZONTAL_ALIGNMENT_LEFT, 320, 13, UiTheme.PAPER)
	draw_rect(Rect2(112, 72, 160, 6), Color(UiTheme.SOOT, 0.9))
	draw_rect(Rect2(112, 72, 160 * fresh, 6), col)
