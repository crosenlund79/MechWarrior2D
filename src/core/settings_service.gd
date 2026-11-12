extends Node
## Autoload `Settings`: personal preferences in settings.cfg — never inside saves.
## Audio volumes, window mode, UI scale, camera zoom, language and key bindings.

signal changed(key: String)

const BUSES := ["Master", "Music", "Ambience", "SFX", "UI"]
const WINDOW_MODES := ["windowed", "fullscreen", "borderless"]

## Remappable actions: action -> default keys. Labels are translation keys.
const ACTIONS := {
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"interact": [KEY_E],
	"service": [KEY_R],
	"zoom_in": [KEY_EQUAL, KEY_KP_ADD],
	"zoom_out": [KEY_MINUS, KEY_KP_SUBTRACT],
	"quick_save": [KEY_F5],
	"dev_overlay": [KEY_F3],
	"pause": [KEY_ESCAPE],
	"fire": [KEY_SPACE],
	"handbrake": [KEY_SHIFT],
	"garage": [KEY_G],
	"help": [KEY_H],
	"journey_map": [KEY_M],
	"dev_menu": [KEY_F10],
}
const REMAPPABLE := ["move_up", "move_down", "move_left", "move_right", "handbrake", "interact", "service", "garage", "fire", "help", "journey_map", "zoom_in", "zoom_out"]

var values := {
	"volume_Master": 0.8, "volume_Music": 0.55, "volume_Ambience": 0.8, "volume_SFX": 0.85, "volume_UI": 0.7,
	"window_mode": "windowed", "ui_scale": 1.0, "zoom": 1.0, "language": "en",
	"show_tutorial": true,
}
var bindings := {}  # action -> keycode (primary, remappable)
var _path := ""


func _ready() -> void:
	var imported := Paths.import_legacy()
	if imported > 0:
		print("Thawborn: imported %d file(s) from the Heat Signature user folder" % imported)
	_path = Paths.settings_file()
	_setup_actions()
	load_settings()
	apply_all()


func _setup_actions() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
	_rebuild_input()


func _rebuild_input() -> void:
	for action in ACTIONS:
		InputMap.action_erase_events(action)
		var keys: Array = ACTIONS[action].duplicate()
		if bindings.has(action):
			keys[0] = int(bindings[action])
		for k in keys:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	# Left mouse fires (in addition to the remappable key); wheel zooms.
	var lmb := InputEventMouseButton.new()
	lmb.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("fire", lmb)
	# Mouse wheel zoom is always available in addition to the keys.
	for pair in [["zoom_in", MOUSE_BUTTON_WHEEL_UP], ["zoom_out", MOUSE_BUTTON_WHEEL_DOWN]]:
		var mb := InputEventMouseButton.new()
		mb.button_index = pair[1]
		InputMap.action_add_event(pair[0], mb)


func key_for(action: String) -> int:
	if bindings.has(action):
		return int(bindings[action])
	return int(ACTIONS[action][0])


func key_label(action: String) -> String:
	return OS.get_keycode_string(key_for(action))


func rebind(action: String, keycode: int) -> void:
	if not ACTIONS.has(action):
		return
	bindings[action] = keycode
	_rebuild_input()
	save_settings()
	changed.emit("binding_" + action)


func reset_bindings() -> void:
	bindings.clear()
	_rebuild_input()
	save_settings()
	changed.emit("bindings")


func get_value(key: String, default_value = null):
	return values.get(key, default_value)


func set_value(key: String, v) -> void:
	values[key] = v
	apply_key(key)
	save_settings()
	changed.emit(key)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_path) != OK:
		return
	for key in values.keys():
		values[key] = cfg.get_value("settings", key, values[key])
	values["ui_scale"] = clampf(float(values["ui_scale"]), 0.75, 1.75)
	values["zoom"] = clampf(float(values["zoom"]), 0.5, 2.0)
	if not WINDOW_MODES.has(values["window_mode"]):
		values["window_mode"] = "windowed"
	for action in REMAPPABLE:
		if cfg.has_section_key("bindings", action):
			bindings[action] = int(cfg.get_value("bindings", action))
	_rebuild_input()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in values:
		cfg.set_value("settings", key, values[key])
	for action in bindings:
		cfg.set_value("bindings", action, bindings[action])
	var err := cfg.save(_path)
	if err != OK:
		Log.error("settings", "save_failed", {"error": error_string(err)})


func apply_all() -> void:
	for key in values:
		apply_key(key)


func apply_key(key: String) -> void:
	if key.begins_with("volume_"):
		var bus := AudioServer.get_bus_index(key.substr(7))
		if bus >= 0:
			var v := clampf(float(values[key]), 0.0, 1.0)
			AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(v, 0.0001)))
			AudioServer.set_bus_mute(bus, v <= 0.001)
	elif key == "window_mode":
		if DisplayServer.get_name() == "headless":
			return
		match str(values[key]):
			"fullscreen":
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
			"borderless":
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			_:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	elif key == "language":
		TranslationServer.set_locale(str(values[key]))
