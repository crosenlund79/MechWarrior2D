extends Node
## Root scene: switches between the main menu and the game screen in response
## to Session.started / Session.ended. Optional test hooks: `--autotest`.

var menu_layer: CanvasLayer
var menu: MainMenu
var settings_layer: CanvasLayer
var game: GameScreen


func _ready() -> void:
	menu_layer = CanvasLayer.new()
	menu_layer.layer = 10
	add_child(menu_layer)
	settings_layer = CanvasLayer.new()
	settings_layer.layer = 15
	settings_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(settings_layer)
	Session.started.connect(_on_started)
	Session.ended.connect(_on_ended)
	_show_menu()
	Audio.loop("music", "music.drone")
	if Paths.has_arg("autotest"):
		var d := AutotestDriver.new()
		d.main = self
		add_child(d)


func _show_menu() -> void:
	if menu:
		menu.queue_free()
	menu = MainMenu.new()
	menu.open_settings.connect(open_settings)
	menu_layer.add_child(menu)
	MenuBackdrop.show_on(self)


func open_settings() -> void:
	if settings_layer.get_child_count() > 0:
		return
	var s := SettingsMenu.new()
	settings_layer.add_child(s)
	s.closed.connect(func() -> void:
		s.queue_free()
		if menu and is_instance_valid(menu):
			menu.refresh())


func _on_started() -> void:
	if menu:
		menu.queue_free()
		menu = null
	MenuBackdrop.hide_from(self)
	if game:
		game.queue_free()
	game = GameScreen.new()
	game.main = self
	add_child(game)


func _on_ended(_reason: String) -> void:
	get_tree().paused = false
	if game:
		game.queue_free()
		game = null
	Audio.stop_all_loops()
	Audio.loop("music", "music.drone")
	_show_menu()
