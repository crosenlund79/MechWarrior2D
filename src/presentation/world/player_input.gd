class_name PlayerInput
extends Node
## Reads the (remappable) input actions and writes intents to Session.
## Disabled while the autotest driver controls the game.

static var driver_control := false

var screen: GameScreen


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	if driver_control or not Session.running or get_tree().paused:
		return
	var x := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var y := Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	if Session.mode() == "mech":
		Session.drive_throttle = -y
		Session.drive_turn = x
		Session.drive_handbrake = Input.is_action_pressed("handbrake")
		Session.walk_dir = Vector2.ZERO
		if screen and screen.world:
			Session.aim_point = screen.world.get_global_mouse_position()
		Session.fire_held = Input.is_action_pressed("fire") and not DevMenu.is_open
	else:
		Session.drive_throttle = 0.0
		Session.drive_turn = 0.0
		Session.drive_handbrake = false
		Session.walk_dir = Vector2(x, y)
		Session.fire_held = false


func _unhandled_input(event: InputEvent) -> void:
	if not Session.running:
		return
	if screen and screen.hud and screen.hud.garage != null:
		return   # the garage menu handles its own keys
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if screen.main.settings_layer.get_child_count() == 0:
			screen.toggle_pause()
		return
	if get_tree().paused or driver_control:
		return
	if event.is_action_pressed("interact"):
		Session.request("interact")
	elif event.is_action_pressed("service"):
		Session.request("service")
	elif event.is_action_pressed("garage"):
		Session.request("garage")
	elif event.is_action_pressed("help"):
		if screen and screen.hud:
			screen.hud.toggle_help()
	elif event.is_action_pressed("quick_save"):
		Session.save_now("quicksave")
		Session.notice.emit("NOTICE_SAVED", [])
