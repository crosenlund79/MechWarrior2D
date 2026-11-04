class_name Reticle
extends Control
## Mouse reticle while piloting (UI layer, ungraded). Dims while the weapon
## cannot fire (shutdown, crippled).


func _process(_delta: float) -> void:
	var want := Session.running and Session.mode() == "mech"
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if want and not get_tree().paused else Input.MOUSE_MODE_VISIBLE
	queue_redraw()


func _draw() -> void:
	if not Session.running or Session.mode() != "mech" or get_tree().paused:
		return
	var s := get_global_transform().get_scale().x
	var p := get_viewport().get_mouse_position() / s
	var col := Color(UiTheme.PAPER, 0.9) if Session.can_fire() else Color(UiTheme.DIM, 0.45)
	draw_arc(p, 11.0, 0, TAU, 24, col, 1.6, true)
	for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		draw_line(p + d * 6.0, p + d * 16.0, col, 1.6, true)
	draw_circle(p, 1.6, col)


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
