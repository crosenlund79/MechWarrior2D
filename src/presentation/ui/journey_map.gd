class_name JourneyMap
extends UiRoot
## Continental route map (M; pauses the game). An Eisenwolf survey chart of the
## thawed continent with the route network Ersthafen → Stahlheim:
##   current node (pulsing), visited, discovered (route known), undiscovered (hidden),
##   completed territories (ticked), the hub (CLEARED once the cargo is delivered).
## Clicking a node shows its information; "Set course" points the objective arrow
## at the gate that starts the route there. Travel itself happens by driving out
## through that gate (physical traversal).

signal closed

var _map: Control
var _info: VBoxContainer
var _sel := ""
var _t := 0.0
var _bg: Texture2D


func _ready() -> void:
	super._ready()
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 30
	root.offset_right = -30
	root.offset_top = 30
	root.offset_bottom = -30
	root.add_theme_constant_override("separation", 18)
	add_child(root)
	_map = Control.new()
	_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map.draw.connect(_draw_map)
	_map.gui_input.connect(_on_map_input)
	root.add_child(_map)
	var side := PanelContainer.new()
	side.add_theme_stylebox_override("panel", UiTheme.panel(0.94))
	side.custom_minimum_size = Vector2(360, 0)
	root.add_child(side)
	_info = VBoxContainer.new()
	_info.add_theme_constant_override("separation", 8)
	side.add_child(_info)
	_bg = Assets.texture("ui.continent_map")
	_sel = Session.current_node()
	_refresh_info()


func close_map() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("journey_map"):
		get_viewport().set_input_as_handled()
		close_map()


func _process(delta: float) -> void:
	_t += delta
	_map.queue_redraw()


## Map space 1000×700 → the map control, letterboxed.
func _xf() -> Array:
	var s := minf(_map.size.x / 1000.0, _map.size.y / 700.0)
	var off := (_map.size - Vector2(1000, 700) * s) * 0.5
	return [s, off]


func _np(id: String) -> Vector2:
	var xf := _xf()
	return xf[1] + Content.v2(Journey.node(id).get("pos", [0, 0])) * float(xf[0])


func _state(id: String) -> String:
	var j := Session.journey()
	if id == Session.current_node():
		return "current"
	if bool(j["completed"].get(id, false)):
		return "completed"
	if bool(j["visited"].get(id, false)):
		return "visited"
	if bool(j["discovered"].get(id, false)):
		return "discovered"
	return "unknown"


func _draw_map() -> void:
	var xf := _xf()
	var s := float(xf[0])
	var off: Vector2 = xf[1]
	if _bg:
		_map.draw_texture_rect(_bg, Rect2(off, Vector2(1000, 700) * s), false)
	else:
		_map.draw_rect(Rect2(off, Vector2(1000, 700) * s), Color("#cdb68c"))
	var font := _map.get_theme_default_font()
	var j := Session.journey()
	for e in Journey.data().get("edges", []):
		var a := str(e[0])
		var b := str(e[1])
		var known := bool(j["discovered"].get(a, false)) and bool(j["discovered"].get(b, false))
		if not known:
			continue
		var travelled := bool(j["visited"].get(a, false)) and bool(j["visited"].get(b, false))
		var col := Color(0.25, 0.14, 0.08, 0.9) if travelled else Color(0.25, 0.14, 0.08, 0.55)
		_dashed(_np(a), _np(b), col, 3.0 if travelled else 2.0, 14.0 if travelled else 8.0)
		var mid := (_np(a) + _np(b)) * 0.5
		_map.draw_string(font, mid + Vector2(4, -4), "%d L" % int(e[2]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.25, 0.16, 0.1, 0.8))
	for id in Journey.nodes():
		var st := _state(id)
		if st == "unknown":
			continue
		var n := Journey.node(id)
		var p := _np(id)
		var kind := str(n.get("kind", ""))
		var ink := Color(0.16, 0.1, 0.07)
		var fill := {"settlement": Color("#d9a92a"), "hub": Color("#c9c3b4"), "territory": Color("#b0281c")}.get(kind, Color.WHITE) as Color
		if st == "discovered":
			fill = fill.darkened(0.35)
			fill.a = 0.75
		if kind == "territory":
			_map.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -13), p + Vector2(12, 9), p + Vector2(-12, 9)]), fill)
			_map.draw_polyline(PackedVector2Array([p + Vector2(0, -13), p + Vector2(12, 9), p + Vector2(-12, 9), p + Vector2(0, -13)]), ink, 2.0)
		elif kind == "hub":
			var star := PackedVector2Array()
			for k in 10:
				star.append(p + Vector2.from_angle(TAU * k / 10.0 - PI * 0.5) * (15.0 if k % 2 == 0 else 7.0))
			_map.draw_colored_polygon(star, fill)
			star.append(star[0])
			_map.draw_polyline(star, ink, 2.0)
		else:
			_map.draw_rect(Rect2(p - Vector2(10, 10), Vector2(20, 20)), fill)
			_map.draw_rect(Rect2(p - Vector2(10, 10), Vector2(20, 20)), ink, false, 2.0)
		if st == "completed" and kind == "territory":
			_map.draw_polyline(PackedVector2Array([p + Vector2(-6, 0), p + Vector2(-1, 6), p + Vector2(8, -6)]), Color(0.1, 0.35, 0.15), 3.0)
		if st == "current":
			var r := 22.0 + 4.0 * sin(_t * 3.0)
			_map.draw_arc(p, r, 0, TAU, 32, Color(0.95, 0.35, 0.15, 0.9), 2.5)
		if id == _sel:
			_map.draw_arc(p, 28.0, 0, TAU, 32, Color(0.1, 0.08, 0.06, 0.8), 1.5)
		var label := tr(str(n.get("name", id)))
		var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		_map.draw_string(font, p + Vector2(-tw * 0.5, 30), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ink)
	# undiscovered neighbours of discovered nodes are hinted by a question mark
	for id in Journey.nodes():
		if _state(id) == "unknown":
			var any := false
			for nb in Journey.neighbors(id):
				if bool(j["discovered"].get(nb, false)):
					any = true
			if any:
				_map.draw_string(font, _np(id) + Vector2(-6, 6), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.2, 0.12, 0.08, 0.6))


func _dashed(a: Vector2, b: Vector2, col: Color, w: float, dash: float) -> void:
	var L := a.distance_to(b)
	var d := (b - a) / maxf(L, 0.001)
	var x := 0.0
	while x < L:
		_map.draw_line(a + d * x, a + d * minf(x + dash, L), col, w, true)
		x += dash * 1.7


func _on_map_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var best := ""
		var bd := 34.0
		for id in Journey.nodes():
			if _state(id) == "unknown":
				continue
			var d := _np(id).distance_to(ev.position)
			if d < bd:
				bd = d
				best = id
		if best != "":
			_sel = best
			_refresh_info()


func select(id: String) -> void:
	_sel = id
	_refresh_info()


func _refresh_info() -> void:
	for c in _info.get_children():
		c.queue_free()
	var j := Session.journey()
	_info.add_child(UiTheme.label(tr("MAP_TITLE"), 22, UiTheme.STRAW))
	var cargo := UiTheme.label(tr("MAP_CARGO") % tr(str(Journey.data().get("cargo", {}).get("name", ""))), 13, UiTheme.PAPER)
	cargo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_child(cargo)
	if bool(j.get("delivered", false)):
		_info.add_child(UiTheme.label(tr("MAP_DELIVERED"), 14, UiTheme.COOLANT))
	_info.add_child(HSeparator.new())
	var n := Journey.node(_sel)
	if n.is_empty():
		return
	_info.add_child(UiTheme.label(tr(str(n.get("name", _sel))), 20, UiTheme.PAPER))
	var kind := str(n.get("kind", ""))
	_info.add_child(UiTheme.label(tr("KIND_" + kind.to_upper()) + "  ·  " + tr("MAP_TIER") % int(n.get("tier", 0)), 13,
		UiTheme.DANGER if kind == "territory" else UiTheme.WARNING))
	_info.add_child(UiTheme.label(tr("STATE_" + _state(_sel).to_upper()), 13, UiTheme.DIM))
	var desc := UiTheme.label(tr(str(n.get("desc", ""))), 13, UiTheme.PAPER)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(330, 0)
	_info.add_child(desc)
	var here := Session.current_node()
	if _sel != here:
		var hop := Journey.next_hop(here, _sel)
		if hop != "":
			var g := Session.gate_to(hop)
			var route := UiTheme.label(tr("MAP_ROUTE") % [tr(str(Journey.node(hop).get("name", hop))), tr("SIDE_" + str(g.get("side", "n")).to_upper()),
				int(Journey.edge_fuel(here, hop))], 13, UiTheme.STRAW)
			route.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			route.custom_minimum_size = Vector2(330, 0)
			_info.add_child(route)
			var b := UiTheme.btn(tr("MAP_SET_COURSE"), func() -> void:
				Session.set_course(_sel)
				close_map())
			b.name = "SetCourse"
			_info.add_child(b)
	var close := UiTheme.btn(tr("MAP_CLOSE"), close_map)
	close.name = "Close"
	_info.add_child(close)
