class_name Reticle
extends Control
## Mouse reticle while piloting (UI layer, ungraded). Dims while the weapon
## cannot fire (shutdown, crippled).


## Modal panels (garage, pause, settings, dev menu) need the real cursor. This
## node runs even while the tree is paused, so it can always restore it
## (playtest 004: the cursor stayed hidden inside the pausing garage menu).
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


static func modal_open(tree: SceneTree) -> bool:
	return tree.paused or DevMenu.is_open


func _process(_delta: float) -> void:
	var want := Session.running and Session.mode() == "mech" and not modal_open(get_tree())
	var mode := Input.MOUSE_MODE_HIDDEN if want else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != mode:
		Input.mouse_mode = mode
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
