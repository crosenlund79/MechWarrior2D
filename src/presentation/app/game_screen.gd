class_name GameScreen
extends Node
## In-game composition: World (graded) + HUD/overlays (ungraded) + pause.
## CanvasLayers: 5 = colour grade (Phase B), 10 = HUD, 12 = dev overlay,
## 14 = pause, 15 = settings (owned by main).

var main: Node
var world: WorldView
var hud: Hud
var dev: DevOverlay
var pause_layer: CanvasLayer
var input: PlayerInput
var sound: SoundDirector


func _ready() -> void:
	name = "Game"
	world = WorldView.new()
	add_child(world)
	var atmo := Atmosphere.new()
	atmo.world = world
	add_child(atmo)
	world.atmosphere = atmo
	var hl := CanvasLayer.new()
	hl.layer = 10
	add_child(hl)
	hud = Hud.new()
	hud.world = world
	hl.add_child(hud)
	var dl := CanvasLayer.new()
	dl.layer = 12
	add_child(dl)
	dev = DevOverlay.new()
	dev.world = world
	dl.add_child(dev)
	pause_layer = CanvasLayer.new()
	pause_layer.layer = 14
	pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pause_layer)
	input = PlayerInput.new()
	input.screen = self
	add_child(input)
	sound = SoundDirector.new()
	add_child(sound)


func toggle_pause() -> void:
	if get_tree().paused:
		_resume()
		return
	get_tree().paused = true
	var p := PauseMenu.new()
	pause_layer.add_child(p)
	p.resume.connect(_resume)
	p.open_settings.connect(func() -> void: main.open_settings())
	p.to_menu.connect(func() -> void:
		get_tree().paused = false
		Session.end_session("menu"))


func _resume() -> void:
	for c in pause_layer.get_children():
		c.queue_free()
	get_tree().paused = false


func _exit_tree() -> void:
	get_tree().paused = false
