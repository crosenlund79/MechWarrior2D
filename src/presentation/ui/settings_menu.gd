class_name SettingsMenu
extends UiRoot
## Functional settings only: audio buses, window mode, UI scale, zoom, language,
## key remapping, art/sound reload. Everything persists in settings.cfg.

signal closed

var _list: VBoxContainer
var _waiting_action := ""
var _waiting_button: Button


func _ready() -> void:
	super._ready()
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.5)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 560)
	center.add_child(panel)
	var outer := VBoxContainer.new()
	panel.add_child(outer)
	outer.add_child(UiTheme.label(tr("MENU_SETTINGS"), 24, UiTheme.STRAW))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(520, 440)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	var back := UiTheme.btn(tr("MENU_BACK"), func() -> void: closed.emit())
	outer.add_child(back)
	back.call_deferred("grab_focus")
	_fill()


func _fill() -> void:
	for c in _list.get_children():
		c.queue_free()
	_section("SET_AUDIO")
	for bus in Settings.BUSES:
		_slider("BUS_" + bus.to_upper(), "volume_" + bus, 0.0, 1.0, 0.05)
	_section("SET_DISPLAY")
	var wm := OptionButton.new()
	for m in Settings.WINDOW_MODES:
		wm.add_item(tr("WINDOW_" + m.to_upper()))
	wm.selected = Settings.WINDOW_MODES.find(Settings.get_value("window_mode"))
	wm.item_selected.connect(func(i: int) -> void: Settings.set_value("window_mode", Settings.WINDOW_MODES[i]))
	_row("SET_WINDOW", wm)
	_slider("SET_UI_SCALE", "ui_scale", 0.75, 1.75, 0.05)
	_slider("SET_ZOOM", "zoom", 0.5, 2.0, 0.05)
	var lang := OptionButton.new()
	var langs := ["en", "da"]
	for l in langs:
		lang.add_item(tr("LANG_" + l.to_upper()))
	lang.selected = maxi(0, langs.find(Settings.get_value("language")))
	lang.item_selected.connect(func(i: int) -> void:
		Settings.set_value("language", langs[i])
		_fill.call_deferred())
	_row("SET_LANGUAGE", lang)
	_section("SET_CONTROLS")
	for action in Settings.REMAPPABLE:
		var b := Button.new()
		b.text = Settings.key_label(action)
		b.custom_minimum_size = Vector2(140, 0)
		var a: String = action
		b.pressed.connect(func() -> void:
			_waiting_action = a
			_waiting_button = b
			b.text = tr("SET_PRESS_KEY"))
		_row("ACTION_" + action.to_upper(), b)
	_list.add_child(UiTheme.btn(tr("SET_RESET_KEYS"), func() -> void:
		Settings.reset_bindings()
		_fill()))
	_section("SET_CREATOR")
	_list.add_child(UiTheme.btn(tr("SET_RELOAD_ASSETS"), func() -> void: Assets.reload()))
	var note := UiTheme.label(tr("SET_OVERRIDE_PATH") % ProjectSettings.globalize_path(Paths.external_override_roots()[-1]), 12, UiTheme.DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.add_child(note)


func _section(key: String) -> void:
	var l := UiTheme.label(tr(key), 16, UiTheme.STRAW)
	_list.add_child(l)


func _row(key: String, control: Control) -> void:
	var h := HBoxContainer.new()
	var l := UiTheme.label(tr(key), 15)
	l.custom_minimum_size = Vector2(220, 0)
	h.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(control)
	_list.add_child(h)


func _slider(key: String, setting: String, mn: float, mx: float, step: float) -> void:
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = step
	s.value = float(Settings.get_value(setting, mn))
	s.custom_minimum_size = Vector2(200, 24)
	var val := UiTheme.label("", 13, UiTheme.DIM)
	val.custom_minimum_size = Vector2(48, 0)
	var upd := func(x: float) -> void: val.text = ("%.2f" % x) if setting in ["ui_scale", "zoom"] else "%d%%" % int(round(x * 100.0))
	upd.call(s.value)
	s.value_changed.connect(func(x: float) -> void:
		upd.call(x)
		Settings.set_value(setting, x))
	var h := HBoxContainer.new()
	var l := UiTheme.label(tr(key), 15)
	l.custom_minimum_size = Vector2(220, 0)
	h.add_child(l)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(s)
	h.add_child(val)
	_list.add_child(h)


func _input(event: InputEvent) -> void:
	if _waiting_action == "":
		if event.is_action_pressed("pause"):
			get_viewport().set_input_as_handled()
			closed.emit()
		return
	if event is InputEventKey and event.pressed:
		get_viewport().set_input_as_handled()
		if event.physical_keycode != KEY_ESCAPE:
			Settings.rebind(_waiting_action, event.physical_keycode)
		_waiting_button.text = Settings.key_label(_waiting_action)
		_waiting_action = ""
