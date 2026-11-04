class_name ObjectivePointer
extends Control
## Small chevron at the screen edge pointing at the current objective when it is
## off-screen, or a ring around it when visible. Pure UI (not graded).

var world: WorldView


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if world == null or not Session.running:
		return
	var target := Session.nearest_objective()
	if target == Vector2.INF:
		return
	var ct := get_viewport().get_canvas_transform()
	var s := get_global_transform().get_scale().x
	var screen := (ct * target) / s
	var rect := Rect2(Vector2.ZERO, size).grow(-48)
	var col := Color(UiTheme.STRAW, 0.85)
	if rect.has_point(screen):
		var r := 26.0 + 3.0 * sin(Time.get_ticks_msec() * 0.005)
		draw_arc(screen, r, 0, TAU, 32, Color(col, 0.55), 2.0, true)
		return
	var c := size * 0.5
	var dir := (screen - c).normalized()
	var t := INF
	for axis in 2:
		if absf(dir[axis]) > 0.0001:
			var lim := (rect.size[axis] * 0.5) / absf(dir[axis])
			t = minf(t, lim)
	var p := c + dir * t
	var n := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([p + dir * 14, p - dir * 8 + n * 10, p - dir * 3, p - dir * 8 - n * 10]), col)
	var dist := int(Session.actor_pos().distance_to(target) / 42.0)
	draw_string(get_theme_default_font(), p - dir * 34 - Vector2(16, -5), "%d m" % dist, HORIZONTAL_ALIGNMENT_CENTER, 48, 13, col)
