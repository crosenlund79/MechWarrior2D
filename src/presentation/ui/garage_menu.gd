class_name GarageMenu
extends UiRoot
## Refuge garage (pauses the game). Shows the car's condition and cargo, a full
## repair paid in scrap, and every module with its level, the next level's
## materials (have / need) and what it changes. Calls Session.garage_fit /
## Session.garage_repair; never edits state itself.

signal closed

var _list: VBoxContainer
var _status: Label
var _cond: Label
var _cargo: Label

const EFFECT_KEYS := {
	"integrity": "GARAGE_FX_INTEGRITY", "cooling_mult": "GARAGE_FX_COOLING", "grip_mult": "GARAGE_FX_GRIP",
	"accel_mult": "GARAGE_FX_ACCEL", "speed_mult": "GARAGE_FX_SPEED", "damage_mult": "GARAGE_FX_DAMAGE",
	"cooldown_mult": "GARAGE_FX_RATE", "cargo": "GARAGE_FX_CARGO", "tracker_mult": "GARAGE_FX_TRACKER",
}


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
	panel.add_theme_stylebox_override("panel", UiTheme.panel(0.96))
	panel.custom_minimum_size = Vector2(860, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	v.add_child(UiTheme.label(tr("GARAGE_TITLE"), 26, UiTheme.STRAW))
	v.add_child(UiTheme.label(tr("GARAGE_SUB"), 14, UiTheme.DIM))
	_cond = UiTheme.label("", 15)
	v.add_child(_cond)
	_cargo = UiTheme.label("", 13, UiTheme.DIM)
	_cargo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cargo.custom_minimum_size = Vector2(820, 0)
	v.add_child(_cargo)
	v.add_child(HSeparator.new())
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	v.add_child(_list)
	v.add_child(HSeparator.new())
	var row := HBoxContainer.new()
	v.add_child(row)
	_status = UiTheme.label("", 14, UiTheme.WARNING)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_status)
	var close := UiTheme.btn(tr("GARAGE_CLOSE"), func() -> void: close_menu())
	row.add_child(close)
	_refresh()
	close.call_deferred("grab_focus")


func close_menu() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("garage"):
		get_viewport().set_input_as_handled()
		close_menu()


func _refresh() -> void:
	var m := Session.mech()
	_cond.text = tr("GARAGE_CONDITION") % [int(round(float(m["integrity"]))), int(round(Session.max_integrity())),
		int(round(float(m["radiator"]) * 100.0)), Session.cargo_bulk(), Session.cargo_capacity()]
	var inv := {}
	for src in [m["storage"], Session.pilot()["pack"]]:
		for k in src:
			inv[k] = int(inv.get(k, 0)) + int(src[k])
	var parts: PackedStringArray = []
	for k in inv:
		parts.append("%s ×%d" % [tr(str(Content.items.get(k, {}).get("name", k))), int(inv[k])])
	_cargo.text = tr("GARAGE_CARGO") % (", ".join(parts) if parts.size() > 0 else tr("GARAGE_EMPTY"))
	for c in _list.get_children():
		c.queue_free()
	# full repair
	var rc := Session.garage_repair_cost()
	var rrow := HBoxContainer.new()
	_list.add_child(rrow)
	var rl := UiTheme.label(tr("GARAGE_REPAIR") % [rc, Session.have_item("scrap")] if rc > 0 else tr("GARAGE_REPAIR_NONE"), 16)
	rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rrow.add_child(rl)
	var rb := UiTheme.btn(tr("GARAGE_REPAIR_BTN"), func() -> void:
		if not Session.garage_repair():
			_status.text = tr("NOTICE_NEED_SCRAP")
		_refresh())
	rb.disabled = rc <= 0 or Session.have_item("scrap") <= 0
	rrow.add_child(rb)
	var tg: Dictionary = Session.tun("garage")
	for module in Garage.MODULES:
		var lv := Garage.level(Session.upgrades(), module)
		var mx := Garage.max_level(tg, module)
		var box := HBoxContainer.new()
		_list.add_child(box)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 1)
		box.add_child(col)
		var pips := "●".repeat(lv) + "○".repeat(mx - lv)
		col.add_child(UiTheme.label("%s  %s" % [tr("MOD_" + module.to_upper()), pips], 17, UiTheme.STRAW))
		col.add_child(UiTheme.label(tr("MOD_" + module.to_upper() + "_DESC"), 12, UiTheme.DIM))
		var nxt := Garage.next_level(tg, Session.upgrades(), module)
		if nxt.is_empty():
			col.add_child(UiTheme.label(tr("GARAGE_MAXED"), 13, UiTheme.COOLANT))
			continue
		var cost: PackedStringArray = []
		var ok := true
		for item in nxt.get("cost", {}):
			var have := Session.have_item(str(item))
			var need := int(nxt["cost"][item])
			ok = ok and have >= need
			cost.append("%s %d/%d" % [tr(str(Content.items.get(item, {}).get("name", item))), have, need])
		var cl := UiTheme.label(tr("GARAGE_NEEDS") % ", ".join(cost), 13, UiTheme.PAPER if ok else UiTheme.WARNING)
		col.add_child(cl)
		var fx: PackedStringArray = []
		for e in Garage.preview(tg, Session.upgrades(), module):
			fx.append(_fx_text(str(e[0]), float(e[1]), float(e[2])))
		col.add_child(UiTheme.label(" · ".join(fx), 13, UiTheme.COOLANT))
		var b := UiTheme.btn(tr("GARAGE_FIT") % (lv + 1), func() -> void:
			if Session.garage_fit(module):
				_status.text = tr("NOTICE_FITTED") % [tr("MOD_" + module.to_upper()), Garage.level(Session.upgrades(), module)]
			else:
				_status.text = tr("GARAGE_MISSING")
			_refresh())
		b.disabled = not ok
		box.add_child(b)


func _fx_text(key: String, now: float, nxt: float) -> String:
	var label := tr(str(EFFECT_KEYS.get(key, key)))
	if key.ends_with("_mult"):
		return "%s %+d%% → %+d%%" % [label, int(round((now - 1.0) * 100.0)), int(round((nxt - 1.0) * 100.0))]
	return "%s +%d → +%d" % [label, int(now), int(nxt)]
