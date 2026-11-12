class_name MainMenu
extends UiRoot
## Start screen: a weathered workbench in an Ersthafen garage under a hanging
## lamp (ui.menu_table), with the creator's two photographs laid on it as worn
## prints — slightly rotated, overlapping, taped down, with contact shadows —
## and the menu typed on an Eisenwolf job card. Continue / New game (slot
## picker) / Settings / Quit. Responsive: the layout is relative to the screen.
##
## The prints are ui.photo_combat / ui.photo_garage: the creator's files in
## assets/Illustrations/ are used first (manifest "creator" path), generated
## template_ prints are only a fallback; overrides work without code changes.

signal open_settings

var _main: VBoxContainer
var _slots: VBoxContainer
var _status: Label
var _table: TextureRect
var _prints: Array[Control] = []
var _card: PanelContainer
var _t := 0.0
var _lamp: ColorRect

const INK := Color("#2a2119")
const PAPER := Color("#e6dcc4")


func _ready() -> void:
	super._ready()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_table = TextureRect.new()
	_table.texture = Assets.texture("ui.menu_table")
	_table.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_table.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_table.set_anchors_preset(Control.PRESET_FULL_RECT)
	_table.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_table)
	for pid in ["ui.photo_combat", "ui.photo_garage"]:
		_prints.append(_make_print(pid))
	_lamp = ColorRect.new()   # very subtle lamp sway over the table
	_lamp.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lamp.color = Color(1.0, 0.8, 0.5, 0.0)
	add_child(_lamp)
	_card = PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = PAPER
	st.border_color = Color(0.55, 0.45, 0.32)
	st.set_border_width_all(2)
	st.set_corner_radius_all(2)
	st.set_content_margin_all(18)
	st.shadow_color = Color(0, 0, 0, 0.45)
	st.shadow_size = 14
	st.shadow_offset = Vector2(6, 9)
	_card.add_theme_stylebox_override("panel", st)
	add_child(_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_card.add_child(v)
	var hdr := _ink(tr("MENU_CARD_HEADER"), 11)
	v.add_child(hdr)
	var title := _ink(tr("GAME_TITLE"), 44)
	v.add_child(title)
	var sub := _ink(tr("GAME_SUBTITLE"), 14)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(360, 0)
	v.add_child(sub)
	v.add_child(HSeparator.new())
	_main = VBoxContainer.new()
	v.add_child(_main)
	_slots = VBoxContainer.new()
	_slots.visible = false
	v.add_child(_slots)
	_status = _ink("", 13)
	_status.add_theme_color_override("font_color", Color("#9c2a18"))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_status)
	var ver := _ink("v%s · Eisenwolf Werke · Ersthafen" % ProjectSettings.get_setting("application/config/version"), 10)
	v.add_child(ver)
	refresh()
	resized.connect(_layout)
	_layout()


func _ink(text: String, size_px: int) -> Label:
	var l := UiTheme.label(text, size_px, INK)
	return l


## One photographic print: paper-edged texture on a soft contact shadow, taped down.
func _make_print(pid: String) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	var shadow := Panel.new()
	var ss := StyleBoxFlat.new()
	ss.bg_color = Color(0, 0, 0, 0.0)
	ss.shadow_color = Color(0.03, 0.02, 0.01, 0.55)
	ss.shadow_size = 22
	ss.shadow_offset = Vector2(10, 16)
	shadow.add_theme_stylebox_override("panel", ss)
	shadow.set_anchors_preset(Control.PRESET_FULL_RECT)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(shadow)
	var tex := TextureRect.new()
	tex.name = "Photo"
	tex.texture = Assets.texture(pid)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.set_meta("asset", pid)
	holder.add_child(tex)
	# a warm, uneven sheen (old gloss under the lamp) — restrained, artwork stays clear
	var sheen := ColorRect.new()
	sheen.color = Color(1.0, 0.9, 0.7, 0.05)
	sheen.set_anchors_preset(Control.PRESET_FULL_RECT)
	sheen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(sheen)
	for k in 2:   # two strips of yellowed tape at the corners
		var tape := ColorRect.new()
		tape.color = Color(0.86, 0.8, 0.62, 0.62)
		tape.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tape.size = Vector2(90, 26)
		tape.set_meta("corner", k)
		holder.add_child(tape)
	return holder


func _layout() -> void:
	var s := size
	if s.x < 10:
		return
	# prints: combat upper-left, garage overlapping to the right and lower
	var w := s.x * 0.47
	var h := w * 470.0 / 836.0
	var spec := [[Vector2(s.x * 0.04, s.y * 0.07), -3.6], [Vector2(s.x * 0.44, s.y * 0.2), 2.8]]
	for i in _prints.size():
		var p := _prints[i]
		p.size = Vector2(w, h)
		p.position = spec[i][0]
		p.pivot_offset = p.size * 0.5
		p.rotation = deg_to_rad(spec[i][1])
		for c in p.get_children():
			if c.has_meta("corner"):
				var k := int(c.get_meta("corner"))
				c.position = Vector2(-20, -10) if k == 0 else Vector2(w - 70, h - 16)
				c.rotation = deg_to_rad(-35.0 if k == 0 else -35.0)
	# the job card: lower left, over the survey map, clear of the prints' centres
	_card.custom_minimum_size = Vector2(minf(420.0, s.x * 0.34), 0)
	_card.reset_size()
	_card.position = Vector2(s.x * 0.05, s.y - _card.size.y - s.y * 0.05)
	_card.pivot_offset = _card.size * 0.5
	_card.rotation = deg_to_rad(-1.2)


func _process(delta: float) -> void:
	_t += delta
	_lamp.color.a = 0.025 + 0.015 * sin(_t * 0.9) * sin(_t * 0.37)
	if _card.size.y > 0 and abs(_card.position.y - (size.y - _card.size.y - size.y * 0.05)) > 1.0:
		_layout()


func refresh() -> void:
	for c in _main.get_children():
		c.queue_free()
	_main.visible = true
	_slots.visible = false
	var recent := Saves.most_recent_slot()
	if recent > 0:
		var b := _menu_btn(tr("MENU_CONTINUE"), func() -> void: _continue(recent))
		b.name = "Continue"
		_main.add_child(b)
		b.call_deferred("grab_focus")
	var nb := _menu_btn(tr("MENU_NEW_GAME"), _show_slots)
	nb.name = "NewGame"
	_main.add_child(nb)
	if recent == 0:
		nb.call_deferred("grab_focus")
	_main.add_child(_menu_btn(tr("MENU_SETTINGS"), func() -> void: open_settings.emit()))
	_main.add_child(_menu_btn(tr("MENU_QUIT"), func() -> void: get_tree().quit()))


## Menu entries typed on the card: dark ink, underline on hover/focus.
func _menu_btn(text: String, cb: Callable) -> Button:
	var b := UiTheme.btn("›  " + text, cb)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 20)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.16, 0.12, 0.08, 0.0 if state == "normal" else (0.12 if state != "pressed" else 0.22))
		sb.border_color = Color(0.6, 0.18, 0.1, 0.9)
		sb.border_width_bottom = 2 if state in ["hover", "focus"] else 0
		sb.content_margin_left = 8
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		b.add_theme_stylebox_override(state, sb)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, INK)
	b.add_theme_color_override("font_disabled_color", Color(INK, 0.4))
	return b


func _show_slots() -> void:
	for c in _slots.get_children():
		c.queue_free()
	_main.visible = false
	_slots.visible = true
	_slots.add_child(_ink(tr("MENU_PICK_SLOT"), 15))
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
		var b := _menu_btn(text, func() -> void: _new_in(idx))
		b.name = "Slot%d" % i
		b.add_theme_font_size_override("font_size", 15)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
		if not s.is_empty() and not s.get("broken", false):
			var lb := _menu_btn(tr("SLOT_LOAD"), func() -> void: _continue(idx))
			lb.add_theme_font_size_override("font_size", 15)
			row.add_child(lb)
	_slots.add_child(_ink(tr("SLOT_OVERWRITE_NOTE"), 12))
	_slots.add_child(_menu_btn(tr("MENU_BACK"), refresh))
	_layout()


func _new_in(slot: int) -> void:
	if Saves.has_save(slot):
		Saves.delete_slot(slot)
	Session.start_new(slot)


func _continue(slot: int) -> void:
	var err := Session.continue_slot(slot)
	if err != "":
		_status.text = tr("MENU_LOAD_FAILED") % err


## Asset sources in use for the prints (tests / diagnostics).
func print_sources() -> Array:
	var out: Array = []
	for p in _prints:
		var t: TextureRect = p.get_node("Photo")
		out.append(Assets.source.get(str(t.get_meta("asset")), ""))
	return out
