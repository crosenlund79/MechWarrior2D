class_name MainMenu
extends UiRoot
## Start screen: Continue / New game (slot picker) / Settings / Quit.

signal open_settings

var _main: VBoxContainer
var _slots: VBoxContainer
var _status: Label


func _ready() -> void:
	super._ready()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.09, 0.07, 0.55)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var title := UiTheme.label(tr("GAME_TITLE"), 46, UiTheme.STRAW)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sub := UiTheme.label(tr("GAME_SUBTITLE"), 15, UiTheme.DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sub)
	v.add_child(HSeparator.new())
	_main = VBoxContainer.new()
	v.add_child(_main)
	_slots = VBoxContainer.new()
	_slots.visible = false
	v.add_child(_slots)
	_status = UiTheme.label("", 13, UiTheme.WARNING)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_status)
	var ver := UiTheme.label("v%s · %s" % [ProjectSettings.get_setting("application/config/version"), tr("PROVISIONAL_TITLE")], 11, UiTheme.DIM)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(ver)
	refresh()


func refresh() -> void:
	for c in _main.get_children():
		c.queue_free()
	_main.visible = true
	_slots.visible = false
	var recent := Saves.most_recent_slot()
	if recent > 0:
		var b := UiTheme.btn(tr("MENU_CONTINUE"), func() -> void: _continue(recent))
		_main.add_child(b)
		b.call_deferred("grab_focus")
	var nb := UiTheme.btn(tr("MENU_NEW_GAME"), _show_slots)
	_main.add_child(nb)
	if recent == 0:
		nb.call_deferred("grab_focus")
	_main.add_child(UiTheme.btn(tr("MENU_SETTINGS"), func() -> void: open_settings.emit()))
	_main.add_child(UiTheme.btn(tr("MENU_QUIT"), func() -> void: get_tree().quit()))


func _show_slots() -> void:
	for c in _slots.get_children():
		c.queue_free()
	_main.visible = false
	_slots.visible = true
	_slots.add_child(UiTheme.label(tr("MENU_PICK_SLOT"), 15, UiTheme.STRAW))
	for i in range(1, Saves.SLOT_COUNT + 1):
		var s := Saves.summary(i)
		var row := HBoxContainer.new()
		_slots.add_child(row)
		var text := tr("SLOT_EMPTY") % i
		if s.get("broken", false):
			text = tr("SLOT_BROKEN") % i
		elif not s.is_empty():
			text = tr("SLOT_USED") % [i, int(float(s.get("playtime", 0)) / 60.0), int(float(s.get("radiator", 0)) * 100.0)]
		var idx := i
		var b := UiTheme.btn(text, func() -> void: _new_in(idx))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
		if not s.is_empty() and not s.get("broken", false):
			row.add_child(UiTheme.btn(tr("SLOT_LOAD"), func() -> void: _continue(idx)))
	_slots.add_child(UiTheme.label(tr("SLOT_OVERWRITE_NOTE"), 12, UiTheme.DIM))
	_slots.add_child(UiTheme.btn(tr("MENU_BACK"), refresh))


func _new_in(slot: int) -> void:
	if Saves.has_save(slot):
		Saves.delete_slot(slot)
	Session.start_new(slot)


func _continue(slot: int) -> void:
	var err := Session.continue_slot(slot)
	if err != "":
		_status.text = tr("MENU_LOAD_FAILED") % err
