class_name Hud
extends UiRoot
## In-game HUD. Reads Session.state every frame; never writes it.
## Mech panel (temperature, cooling, shutters, engine), suit panel, objective,
## interaction prompts with task progress, cargo, notices, objective pointer,
## heat-danger edge and collapse fade.

var hull_bar: ProgressBar
var hull_label: Label
var reticle: Control
var heat_bar: ProgressBar
var heat_label: Label
var trend_label: Label
var cool_bar: ProgressBar
var cool_label: Label
var status_label: Label
var suit_panel: PanelContainer
var suit_bar: ProgressBar
var suit_label: Label
var strain_bar: ProgressBar
var hint_label: Label
var prompt_label: Label
var task_bar: ProgressBar
var cargo_label: Label
var zone_label: Label
var storm_label: Label
var dev_badge: Label
var notices: VBoxContainer
var pointer: Control
var danger: ColorRect
var fade: ColorRect
var world: WorldView
var _heat_fill := {}
var _last_band := ""

const DANGER_SHADER := """
shader_type canvas_item;
uniform float amount = 0.0;
uniform vec4 tint : source_color = vec4(0.85, 0.25, 0.12, 1.0);
void fragment() {
	vec2 d = UV - 0.5;
	float v = smoothstep(0.25, 0.75, length(d * vec2(1.0, 0.75)));
	COLOR = vec4(tint.rgb, v * amount);
}
"""


func _ready() -> void:
	super._ready()
	_build()
	Session.notice.connect(_on_notice)


func _build() -> void:
	danger = ColorRect.new()
	danger.set_anchors_preset(Control.PRESET_FULL_RECT)
	danger.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = DANGER_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	danger.material = mat
	add_child(danger)
	# --- mech panel (top-left)
	var mp := PanelContainer.new()
	mp.add_theme_stylebox_override("panel", UiTheme.panel(0.82))
	mp.position = Vector2(16, 16)
	mp.custom_minimum_size = Vector2(300, 0)
	add_child(mp)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	mp.add_child(v)
	v.add_child(UiTheme.label(tr("HUD_MECH"), 13, UiTheme.STRAW))
	var hrow := HBoxContainer.new()
	v.add_child(hrow)
	heat_label = UiTheme.label("", 22)
	heat_label.custom_minimum_size = Vector2(96, 0)
	hrow.add_child(heat_label)
	trend_label = UiTheme.label("", 14, UiTheme.DIM)
	trend_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hrow.add_child(trend_label)
	heat_bar = _bar(v, UiTheme.WARNING)
	hull_label = UiTheme.label("", 12, UiTheme.DIM)
	v.add_child(hull_label)
	hull_bar = _bar(v, UiTheme.STRAW)
	v.add_child(UiTheme.label(tr("HUD_COOLING"), 12, UiTheme.DIM))
	cool_bar = _bar(v, UiTheme.COOLANT)
	cool_label = UiTheme.label("", 13, UiTheme.PAPER)
	v.add_child(cool_label)
	status_label = UiTheme.label("", 13, UiTheme.PAPER)
	v.add_child(status_label)
	# --- suit panel (below)
	suit_panel = PanelContainer.new()
	suit_panel.add_theme_stylebox_override("panel", UiTheme.panel(0.82))
	suit_panel.position = Vector2(16, 246)
	suit_panel.custom_minimum_size = Vector2(300, 0)
	add_child(suit_panel)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 4)
	suit_panel.add_child(sv)
	suit_label = UiTheme.label("", 15)
	sv.add_child(suit_label)
	suit_bar = _bar(sv, UiTheme.COOLANT)
	strain_bar = _bar(sv, UiTheme.DANGER)
	# --- objective (top centre)
	hint_label = UiTheme.label("", 18, UiTheme.PAPER)
	hint_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hint_label.offset_left = 340
	hint_label.offset_right = -340
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_constant_override("outline_size", 6)
	hint_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	hint_label.offset_top = 18
	add_child(hint_label)
	notices = VBoxContainer.new()
	notices.set_anchors_preset(Control.PRESET_TOP_WIDE)
	notices.offset_left = 340
	notices.offset_right = -340
	notices.offset_top = 92
	notices.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(notices)
	# --- cargo / zone (top-right)
	var cp := PanelContainer.new()
	cp.add_theme_stylebox_override("panel", UiTheme.panel(0.82))
	cp.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	cp.position = Vector2(-16, 16)
	cp.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(cp)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 4)
	cp.add_child(cv)
	cargo_label = UiTheme.label("", 14)
	cv.add_child(cargo_label)
	zone_label = UiTheme.label("", 13, UiTheme.DIM)
	cv.add_child(zone_label)
	storm_label = UiTheme.label("", 14, UiTheme.WARNING)
	cv.add_child(storm_label)
	dev_badge = UiTheme.label("", 12, UiTheme.WARNING)
	dev_badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	dev_badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	dev_badge.grow_vertical = Control.GROW_DIRECTION_BEGIN
	dev_badge.position = Vector2(-16, -16)
	dev_badge.add_theme_constant_override("outline_size", 5)
	dev_badge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	add_child(dev_badge)
	# --- prompts (bottom centre)
	var pb := VBoxContainer.new()
	pb.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	pb.offset_top = -110
	pb.offset_bottom = -30
	pb.alignment = BoxContainer.ALIGNMENT_END
	add_child(pb)
	task_bar = ProgressBar.new()
	task_bar.show_percentage = false
	task_bar.custom_minimum_size = Vector2(260, 10)
	task_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	task_bar.add_theme_stylebox_override("fill", UiTheme.bar_fill(UiTheme.STRAW))
	pb.add_child(task_bar)
	prompt_label = UiTheme.label("", 20)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_constant_override("outline_size", 7)
	prompt_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	pb.add_child(prompt_label)
	reticle = Reticle.new()
	reticle.set_anchors_preset(Control.PRESET_FULL_RECT)
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(reticle)
	pointer = ObjectivePointer.new()
	pointer.set_anchors_preset(Control.PRESET_FULL_RECT)
	pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pointer)
	fade = ColorRect.new()
	fade.color = Color(0.05, 0.03, 0.02, 0.0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)


func _bar(parent: Control, color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, 12)
	b.max_value = 1.0
	b.step = 0.0
	b.add_theme_stylebox_override("fill", UiTheme.bar_fill(color))
	parent.add_child(b)
	return b


func _process(delta: float) -> void:
	if not Session.running:
		return
	var m := Session.mech()
	var p := Session.pilot()
	var tt := Session.tun("thermal")
	var heat := float(m["heat"])
	var band := Thermal.band(heat, tt)
	var maxt := float(tt.get("max_temp", 135.0))
	heat_bar.value = clampf((heat - 40.0) / (maxt - 40.0), 0.0, 1.0)
	var col: Color = {"normal": UiTheme.COOLANT, "warm": UiTheme.WARNING, "warning": Color("#e07a2c"), "critical": UiTheme.DANGER}[band]
	if band != _last_band:
		heat_bar.add_theme_stylebox_override("fill", UiTheme.bar_fill(col))
		_last_band = band
	heat_label.text = "%d °C" % int(round(heat))
	heat_label.add_theme_color_override("font_color", col if band != "normal" else UiTheme.PAPER)
	var speed_frac := absf(float(m["speed"])) / float(Session.tun("mech").get("max_speed", 150.0))
	var eq := Thermal.equilibrium(m, Session.engine_on(), speed_frac, Session.mech_zone, tt)
	var arrow := "▲" if eq > heat + 1.5 else ("▼" if eq < heat - 1.5 else "■")
	trend_label.text = tr("HUD_TREND") % [arrow, int(round(eq))]
	var integ := float(m["integrity"]) / float(Session.tun("mech").get("integrity", 100.0))
	hull_bar.value = integ
	hull_label.text = tr("HUD_HULL") % int(round(integ * 100.0))
	hull_label.add_theme_color_override("font_color", UiTheme.DANGER if integ < 0.25 else UiTheme.DIM)
	cool_bar.value = Thermal.efficiency(float(m["radiator"]), tt) * Thermal.airflow(bool(m["shutters_open"]), tt)
	cool_label.text = tr("HUD_RADIATOR") % [int(round(float(m["radiator"]) * 100.0)),
		tr("HUD_SHUTTERS_OPEN") if m["shutters_open"] else tr("HUD_SHUTTERS_CLOSED")]
	status_label.text = tr("HUD_ENGINE_" + str(m["engine"]).to_upper())
	status_label.add_theme_color_override("font_color", UiTheme.DANGER if m["engine"] == "shutdown" else UiTheme.PAPER)
	# Suit
	var md := Session.mode()
	var suit := float(p["suit"])
	var smax := float(Session.tun("suit").get("max", 100.0))
	suit_panel.visible = md != "mech" or suit < smax - 0.5
	suit_bar.value = suit / smax
	suit_bar.add_theme_stylebox_override("fill", UiTheme.bar_fill(UiTheme.COOLANT if suit > 30.0 else (UiTheme.WARNING if suit > 10.0 else UiTheme.DANGER)))
	var secs := suit / maxf(float(Session.tun("suit").get("drain", 1.4)) * float(Session.pilot_zone.get("suit", 1.0)), 0.01)
	suit_label.text = tr("HUD_SUIT_FOOT") % [int(round(suit)), int(secs)] if md == "foot" else tr("HUD_SUIT_MECH") % int(round(suit))
	strain_bar.visible = float(p["strain"]) > 0.0
	strain_bar.value = float(p["strain"])
	# Objective, prompts, cargo
	hint_label.text = tr(Session.hint())
	var lines: PackedStringArray = []
	for it in Session.interactions():
		if it["kind"] == "exit" and not it["enabled"]:
			continue
		var key := Settings.key_label(str(it["action"]))
		lines.append(("[%s] " % key if it["enabled"] else "") + tr(str(it["label"])))
	prompt_label.text = "     ".join(lines)
	var tp := Session.task_progress()
	task_bar.visible = tp >= 0.0
	task_bar.max_value = 1.0
	task_bar.value = maxf(tp, 0.0)
	var item := Session.repair_item()
	cargo_label.text = tr("HUD_CARGO") % [GameState.count(p["pack"], item), GameState.count(m["storage"], item), Session.scrap_available()]
	zone_label.text = tr("HUD_ZONE") % [tr(str(Session.pilot_zone.get("label", "ZONE_OPEN_SAND"))), int(Session.pilot_zone.get("ambient", 58))]
	var sheltered := bool(Session.pilot_zone.get("sheltered", false))
	if sheltered:
		zone_label.text += "  ·  " + tr("HUD_SHELTERED")
	zone_label.add_theme_color_override("font_color", UiTheme.COOLANT if sheltered else UiTheme.DIM)
	var w := Session.weather()
	storm_label.visible = float(w["intensity"]) > 0.03
	if storm_label.visible:
		storm_label.text = tr("HUD_STORM") % [int(float(w["intensity"]) * 100.0), int(Session.storm_here * 100.0)]
	var dv: PackedStringArray = []
	if bool(Session.dev["invulnerable"]):
		dv.append("invulnerable")
	if not bool(Session.dev["aggression"]):
		dv.append("enemies passive")
	if not bool(Session.dev["dynamic_weather"]):
		dv.append("weather static")
	if absf(Session.time_scale - 1.0) > 0.01:
		dv.append("speed x%s" % str(Session.time_scale))
	dev_badge.text = ("DEV: " + ", ".join(dv)) if dv.size() > 0 else ""
	# Danger edge: suit strain on foot, or a critical mech.
	var dmg := 0.0
	if md == "foot" and suit < 25.0:
		dmg = (1.0 - suit / 25.0) * 0.35 + float(p["strain"]) * 0.5
	if band == "critical":
		dmg = maxf(dmg, 0.3)
	elif band == "warning":
		dmg = maxf(dmg, 0.12)
	var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.006)
	(danger.material as ShaderMaterial).set_shader_parameter("amount", dmg * pulse)
	var fade_target := 0.0
	if md == "collapsed":
		fade_target = clampf(Session.collapse_t / float(Session.tun("suit").get("collapse_fade", 2.5)) * 1.3, 0.0, 0.96)
	fade.color.a = move_toward(fade.color.a, fade_target, delta * (2.0 if fade_target > fade.color.a else 0.8))
	(pointer as ObjectivePointer).world = world


func _on_notice(key: String, args: Array) -> void:
	var text := tr(key)
	if args.size() > 0:
		var targs: Array = []
		for a in args:
			targs.append(tr(Content.items.get(a, {}).get("name", str(a))) if a is String else a)
		if text.contains("%"):
			text = text % targs
	var l := UiTheme.label(text, 17, UiTheme.PAPER)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	notices.add_child(l)
	while notices.get_child_count() > 4:
		notices.get_child(0).free()
	var tw := l.create_tween()
	tw.tween_interval(3.2)
	tw.tween_property(l, "modulate:a", 0.0, 0.8)
	tw.tween_callback(l.queue_free)
