class_name UiTheme
extends RefCounted
## Flat, calm UI theme (Red Thaw structure, desert accents). The UI is never
## graded or textured: illustration lives in the world, not the interface.

const PAPER := Color("#ece0c4")
const STRAW := Color("#d2b88a")
const CHARCOAL := Color("#1f1c19")
const SOOT := Color("#2c2823")
const RUST := Color("#a4492c")
const COOLANT := Color("#4fa3a0")
const WARNING := Color("#e0a030")
const DANGER := Color("#d4452c")
const FOCUS := Color("#59c0c2")
const DIM := Color("#a89a80")

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font_size = 16
	t.set_stylebox("panel", "PanelContainer", panel())
	t.set_stylebox("panel", "Panel", panel())
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		t.set_stylebox(state, "Button", button(state))
		t.set_stylebox(state, "OptionButton", button(state))
	t.set_color("font_color", "Button", PAPER)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(PAPER, 0.35))
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_color", "OptionButton", PAPER)
	t.set_color("font_color", "Label", PAPER)
	t.set_color("font_color", "CheckBox", PAPER)
	t.set_constant("separation", "VBoxContainer", 8)
	t.set_constant("separation", "HBoxContainer", 10)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.08, 0.07, 0.06, 0.9)
	bar_bg.set_corner_radius_all(3)
	var bar_fg := StyleBoxFlat.new()
	bar_fg.bg_color = COOLANT
	bar_fg.set_corner_radius_all(3)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fg)
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(STRAW, 0.35)
	grab.set_content_margin_all(3)
	grab.set_corner_radius_all(3)
	t.set_stylebox("slider", "HSlider", grab)
	_theme = t
	return t


static func panel(alpha: float = 0.94) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(CHARCOAL, alpha)
	s.border_color = Color(STRAW, 0.35)
	s.set_border_width_all(2)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(14)
	return s


static func button(state: String) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = {"normal": SOOT, "hover": Color("#3b362e"), "pressed": Color(RUST, 0.85),
		"disabled": Color(SOOT, 0.5), "focus": SOOT}.get(state, SOOT)
	s.border_color = Color(FOCUS, 0.9) if state == "focus" else Color(STRAW, 0.3)
	s.set_border_width_all(2 if state == "focus" else 1)
	s.set_corner_radius_all(4)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 7
	s.content_margin_bottom = 7
	if state == "focus":
		s.draw_center = false
	return s


static func bar_fill(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(3)
	return s


static func label(text: String, size: int = 16, color: Color = PAPER) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func() -> void:
		Audio.play("ui.click")
		cb.call())
	return b
