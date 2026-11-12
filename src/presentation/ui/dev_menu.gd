class_name DevMenu
extends UiRoot
## Developer / cheat menu (F10). Works during gameplay without pausing.
## Everything here is runtime-only: Session.dev is reset on every start/end and is
## never written to saves; developer-spawned cars and creatures are flagged "dev" and are
## stripped from saves. No console framework — just buttons with live states.

static var is_open := false

var _panel: PanelContainer
var _list: VBoxContainer
var _labels := {}
var _status: Label
var _intensity: HSlider


func _ready() -> void:
	super._ready()
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiTheme.panel(0.92))
	_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_panel.offset_left = -330
	_panel.offset_top = 120
	_panel.offset_bottom = -20
	_panel.offset_right = -16
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 5)
	scroll.add_child(_list)
	_build()
	visible = false


func _build() -> void:
	_list.add_child(UiTheme.label("DEVELOPER MENU (F10)", 16, UiTheme.WARNING))
	_status = UiTheme.label("", 12, UiTheme.DIM)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.add_child(_status)
	_head("Weather")
	_toggle("dyn", "Dynamic weather", func() -> void: Session.dev["dynamic_weather"] = not Session.dev["dynamic_weather"])
	_row([["Clear now", func() -> void: Session.dev_weather("clear")], ["Start storm", func() -> void: Session.dev_weather("start", _intensity.value)],
		["Stop storm", func() -> void: Session.dev_weather("stop")]])
	_intensity = HSlider.new()
	_intensity.min_value = 0.2
	_intensity.max_value = 1.0
	_intensity.step = 0.05
	_intensity.value = 0.85
	_intensity.value_changed.connect(func(v: float) -> void: Session.dev_weather("intensity", v))
	var h := HBoxContainer.new()
	h.add_child(UiTheme.label("Storm intensity", 13))
	_intensity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(_intensity)
	_list.add_child(h)
	_head("Rival cars")
	_row([["Spawn scrapper", func() -> void: _spawn("scrapper", 1)], ["Spawn 3", func() -> void: _spawn("scrapper", 3)]])
	_row([["Spawn Junker", func() -> void: _spawn("junker", 1)], ["Clear spawned", func() -> void: Session.dev_clear_spawned()]])
	_toggle("aggro", "Enemy aggression", func() -> void: Session.dev["aggression"] = not Session.dev["aggression"])
	_head("Creatures")
	_row([["Skirr pack (3)", func() -> void: _spawn_c("skirr", 3)], ["Wühler", func() -> void: _spawn_c("grindback", 1)],
		["Eisback", func() -> void: _spawn_c("rimeback", 1)]])
	_head("Player / car")
	_row([["Repair car completely", func() -> void: Session.dev_repair_all()], ["Refill fuel", func() -> void: Session.dev_refuel()],
		["Refill suit", func() -> void: Session.debug("suit", 100.0)]])
	_row([["+1000 M", func() -> void: Session.dev_money(1000)], ["Give test materials", func() -> void: Session.dev_give_materials()]])
	_upgrade_pick = OptionButton.new()
	for m in Garage.MODULES:
		_upgrade_pick.add_item(m)
	_pick_row(_upgrade_pick, "Grant upgrade level", func() -> void:
		if not Session.dev_grant_upgrade(Garage.MODULES[_upgrade_pick.selected]):
			Session.notice.emit("NOTICE_DEV", ["GARAGE_MAXED"]))
	_head("Journey")
	_node_pick = OptionButton.new()
	for id in Journey.nodes():
		_node_pick.add_item(id)
	_pick_row(_node_pick, "Complete node", func() -> void: Session.dev_complete_node(_node_pick.get_item_text(_node_pick.selected)))
	_row([["Travel to selected node", func() -> void: Session.travel_to(_node_pick.get_item_text(_node_pick.selected), true)],
		["Clear territory creatures", func() -> void: Session.dev_clear_creatures()]])
	_row([["Restore cooling", func() -> void: Session.dev_restore_cooling()]])
	_toggle("invuln", "Invulnerable", func() -> void: Session.dev["invulnerable"] = not Session.dev["invulnerable"])
	_head("Simulation speed")
	var sp := []
	for v in [0.5, 1.0, 2.0, 4.0]:
		var vv: float = v
		sp.append(["x%s" % str(v), func() -> void:
			Session.dev["time_scale"] = vv
			Session.time_scale = vv])
	_row(sp)
	_head("Teleport (this map)")
	_tp_pick = OptionButton.new()
	for k in Session.loc.get("teleports", {}):
		_tp_pick.add_item(str(k))
	_pick_row(_tp_pick, "Teleport", func() -> void:
		if _tp_pick.item_count > 0:
			Session.dev_teleport(_tp_pick.get_item_text(_tp_pick.selected)))
	_head("")
	_row([["Restore default settings", func() -> void:
		Session.dev_reset()
		_intensity.value = 0.85]])


var _upgrade_pick: OptionButton
var _node_pick: OptionButton
var _tp_pick: OptionButton


func _pick_row(pick: OptionButton, label: String, cb: Callable) -> void:
	var h := HBoxContainer.new()
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(pick)
	var b := UiTheme.btn(label, cb)
	h.add_child(b)
	_list.add_child(h)


func _spawn_c(species: String, n: int) -> void:
	var made := Session.dev_spawn_creature(species, n)
	if made < n:
		Session.notice.emit("NOTICE_DEV_NO_ROOM", [])


func _spawn(type: String, n: int) -> void:
	var made := Session.dev_spawn(type, n)
	if made < n:
		Session.notice.emit("NOTICE_DEV_NO_ROOM", [])


func _head(t: String) -> void:
	if t != "":
		_list.add_child(UiTheme.label(t, 14, UiTheme.STRAW))
	else:
		_list.add_child(HSeparator.new())


func _row(items: Array) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	for it in items:
		var b := UiTheme.btn(str(it[0]), it[1])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 13)
		h.add_child(b)
	_list.add_child(h)


func _toggle(key: String, label: String, cb: Callable) -> void:
	var b := UiTheme.btn(label, cb)
	b.add_theme_font_size_override("font_size", 13)
	_labels[key] = [b, label]
	_list.add_child(b)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("dev_menu"):
		visible = not visible
		is_open = visible
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	is_open = false


func _process(_delta: float) -> void:
	if not visible or not Session.running:
		return
	var d: Dictionary = Session.dev
	var on := func(b: bool) -> String: return "ON" if b else "OFF"
	(_labels["dyn"][0] as Button).text = "%s: %s" % [_labels["dyn"][1], on.call(d["dynamic_weather"])]
	(_labels["aggro"][0] as Button).text = "%s: %s" % [_labels["aggro"][1], on.call(d["aggression"])]
	(_labels["invuln"][0] as Button).text = "%s: %s" % [_labels["invuln"][1], on.call(d["invulnerable"])]
	var w := Session.weather()
	var n_dev := 0
	for id in Session.state.get("enemies", {}):
		if bool(Session.state["enemies"][id].get("dev", false)):
			n_dev += 1
	_status.text = "Weather: %s %d%%  (felt here %d%%)\nSim speed x%s · dev-spawned mechs: %d\nCheats are not saved and reset on new game / menu." % [
		str(w["state"]).to_upper(), int(float(w["intensity"]) * 100.0), int(Session.storm_here * 100.0), str(Session.time_scale), n_dev]
