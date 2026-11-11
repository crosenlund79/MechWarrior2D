class_name HelpOverlay
extends PanelContainer
## In-game field guide (H): driving, shooting, tracking, harvesting and the
## garage. Shown once at the start of a new game while "show tutorial" is on.


func _ready() -> void:
	add_theme_stylebox_override("panel", UiTheme.panel(0.93))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(560, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	v.add_child(UiTheme.label(tr("HELP_TITLE"), 22, UiTheme.STRAW))
	for k in ["HELP_DRIVE", "HELP_SHOOT", "HELP_HEAT", "HELP_TRACK", "HELP_HUNT", "HELP_HARVEST", "HELP_GARAGE", "HELP_FOOT"]:
		var l := UiTheme.label(_fmt(tr(k)), 14, UiTheme.PAPER)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(530, 0)
		v.add_child(l)
	v.add_child(UiTheme.label(_fmt(tr("HELP_CLOSE")), 13, UiTheme.DIM))


## Replaces {action} with the current key binding.
func _fmt(t: String) -> String:
	for a in Settings.ACTIONS:
		t = t.replace("{%s}" % a, Settings.key_label(a))
	return t
