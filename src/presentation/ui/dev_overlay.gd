class_name DevOverlay
extends UiRoot
## Developer overlay (F3). Live thermal/suit/save diagnostics and debug keys.
## Debug keys work only while the overlay is visible.

var _label: Label
var world: WorldView


func _ready() -> void:
	super._ready()
	process_mode = Node.PROCESS_MODE_ALWAYS
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.panel(0.86))
	p.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	p.position = Vector2(16, -16)
	add_child(p)
	_label = UiTheme.label("", 12)
	_label.add_theme_font_override("font", _mono())
	p.add_child(_label)
	visible = false


func _mono() -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Consolas", "DejaVu Sans Mono", "Menlo", "monospace"])
	return f


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("dev_overlay"):
		visible = not visible
		get_viewport().set_input_as_handled()
		return
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_F4:
			Assets.reload()
		KEY_F6:
			Session.debug("heat", 15.0)
		KEY_F7:
			Session.debug("damage", 0.2)
		KEY_F8:
			Session.debug("give_part")
		KEY_F9:
			Session.debug("suit", 100.0)
		KEY_F12:
			Session.debug("suit", 5.0)
		KEY_F11:
			Session.debug("timescale", 1.0 if Session.time_scale > 1.0 else 4.0)
		_:
			return
	get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not visible or not Session.running:
		return
	var m := Session.mech()
	var p := Session.pilot()
	var tt := Session.tun("thermal")
	var sf := absf(float(m["speed"])) / float(Session.tun("mech").get("max_speed", 150.0))
	var lines := [
		"HEAT SIGNATURE dev  fps %d  scene=%s  slot=%d  x%.1f" % [Engine.get_frames_per_second(), Session.state["location"], Session.slot, Session.time_scale],
		"mode=%s  engine=%s  speed=%.0f px/s  heading=%.0f°" % [Session.mode(), m["engine"], m["speed"], rad_to_deg(float(m["heading"]))],
		"heat=%.1f°C  eq=%.1f°C  in=%.2f  out=%.2f /s" % [m["heat"], Thermal.equilibrium(m, Session.engine_on(), sf, Session.mech_zone, tt),
			Thermal.heat_in(Session.engine_on(), sf, Session.mech_zone, tt), Thermal.cooling_rate(m, Session.mech_zone, tt)],
		"radiator=%.3f  eff=%.2f  airflow=%.2f  shutters=%s" % [m["radiator"], Thermal.efficiency(float(m["radiator"]), tt),
			Thermal.airflow(bool(m["shutters_open"]), tt), "open" if m["shutters_open"] else "closed"],
		"zone(mech)=%s amb=%.0f solar=%.2f abr=%.1f drag=%.2f" % [Session.mech_zone.get("id"), Session.mech_zone.get("ambient", 0),
			Session.mech_zone.get("solar", 0), Session.mech_zone.get("abrasion", 0), Session.mech_zone.get("drag", 1)],
		"suit=%.1f  strain=%.2f  zone(pilot)=%s  pack=%s  storage=%s" % [p["suit"], p["strain"], Session.pilot_zone.get("id"), p["pack"], m["storage"]],
		"pos mech=(%.0f,%.0f) pilot=(%.0f,%.0f)  task=%s" % [m["pos"][0], m["pos"][1], p["pos"][0], p["pos"][1], Session.task.get("type", "-")],
		"save: %s%s" % [Session.save_status, "  (recovered from backup)" if Session.recovered_from_backup else ""],
		"assets: overrides=%d fallbacks=%d  stats=%s" % [Assets.override_count(), Assets.fallback_count(), Session.state["stats"]],
		"F4 reload art  F6 +15°C  F7 damage radiator  F8 give core  F9 refill suit  F12 suit→5  F11 time x4",
	]
	_label.text = "\n".join(lines)
