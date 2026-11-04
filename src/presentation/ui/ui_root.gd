class_name UiRoot
extends Control
## Full-screen UI root that applies the UI scale setting: its size is the
## viewport size divided by the scale, then scaled back up, so anchors keep
## working at every scale and on ultrawide screens.


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.get_theme()
	get_viewport().size_changed.connect(_fit)
	Settings.changed.connect(func(k: String) -> void: if k == "ui_scale": _fit())
	_fit()


func _fit() -> void:
	var s := clampf(float(Settings.get_value("ui_scale", 1.0)), 0.75, 1.75)
	var vp := get_viewport().get_visible_rect().size
	position = Vector2.ZERO
	scale = Vector2(s, s)
	size = vp / s
