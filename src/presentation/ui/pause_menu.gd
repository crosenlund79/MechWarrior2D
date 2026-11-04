class_name PauseMenu
extends UiRoot
## Pause: Resume / Save / Settings / Quit to menu / Quit game.

signal resume
signal open_settings
signal to_menu

var _status: Label


func _ready() -> void:
	super._ready()
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.45)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	v.add_child(UiTheme.label(tr("PAUSE_TITLE"), 24, UiTheme.STRAW))
	var r := UiTheme.btn(tr("PAUSE_RESUME"), func() -> void: resume.emit())
	v.add_child(r)
	r.call_deferred("grab_focus")
	v.add_child(UiTheme.btn(tr("PAUSE_SAVE"), func() -> void:
		_status.text = tr("PAUSE_SAVED") if Session.save_now("manual") else Session.save_status))
	v.add_child(UiTheme.btn(tr("MENU_SETTINGS"), func() -> void: open_settings.emit()))
	v.add_child(UiTheme.btn(tr("PAUSE_TO_MENU"), func() -> void: to_menu.emit()))
	v.add_child(UiTheme.btn(tr("MENU_QUIT"), func() -> void:
		Session.save_now("quit")
		get_tree().quit()))
	_status = UiTheme.label("", 13, UiTheme.DIM)
	v.add_child(_status)
