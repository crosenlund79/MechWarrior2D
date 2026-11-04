class_name WorldView
extends Node2D
## Builds the visible location from data (ground, props, salvage markers, drops,
## actors, camera) and keeps markers in sync with Session.state. Rebuildable:
## destroying this node never loses game state.
##
## Top-down layering (z_index):
##   -10 ground tiles · -5 floor decals · -3 prop cast shadows · 0 low props
##   5 mech · 6 pilot · 8 roof cast shadow · 20 overhead (roofs, fade when under)
##   25 airborne particles. Grade on CanvasLayer 5, UI on CanvasLayer 10.

const Z := {"ground": -10, "floor": -5, "low": 0, "mech": 5, "pilot": 6, "overhead": 20, "air": 25}

var ground: Node2D
var floor_layer: Node2D
var low: Node2D
var overhead: Node2D
var markers: Node2D
var mech_view: MechView
var pilot_view: PilotView
var camera: CameraRig
var atmosphere: Node
var props: Array[PropView] = []
var _salvage_nodes := {}   # id -> Node2D
var _drop_nodes := {}      # id -> Node2D
var _t := 0.0


func _ready() -> void:
	name = "World"
	var loc := Session.loc
	ground = _layer("Ground", Z["ground"])
	floor_layer = _layer("Floor", Z["floor"])
	low = _layer("Low", Z["low"])
	markers = _layer("Markers", 2)
	overhead = _layer("Overhead", Z["overhead"])
	GroundBuilder.build(ground, loc)
	_build_bounds(loc)
	for d in loc.get("props", []):
		var pv := PropView.new()
		var layer := str(d.get("layer", "low"))
		var parent: Node2D = floor_layer if layer == "floor" else (overhead if layer == "overhead" else low)
		parent.add_child(pv)
		pv.setup(d)
		props.append(pv)
	Scatter.build(low, loc)
	mech_view = MechView.new()
	mech_view.name = "Mech"
	mech_view.z_index = Z["mech"]
	add_child(mech_view)
	pilot_view = PilotView.new()
	pilot_view.name = "Pilot"
	pilot_view.z_index = Z["pilot"]
	add_child(pilot_view)
	camera = CameraRig.new()
	add_child(camera)
	camera.make_current()
	Session.spot_is_free = _spot_is_free
	Session.mode_changed.connect(_on_mode_changed)
	_sync_markers()


func _layer(n: String, z: int) -> Node2D:
	var l := Node2D.new()
	l.name = n
	l.z_index = z
	add_child(l)
	return l


func _build_bounds(loc: Dictionary) -> void:
	var b: Array = loc.get("bounds", [0, 0, 3600, 2600])
	var r := Rect2(b[0], b[1], b[2], b[3])
	var body := StaticBody2D.new()
	body.name = "Bounds"
	for seg in [[r.position, Vector2(r.end.x, r.position.y)], [Vector2(r.end.x, r.position.y), r.end],
			[r.end, Vector2(r.position.x, r.end.y)], [Vector2(r.position.x, r.end.y), r.position]]:
		var cs := CollisionShape2D.new()
		var s := SegmentShape2D.new()
		s.a = seg[0]
		s.b = seg[1]
		cs.shape = s
		body.add_child(cs)
	add_child(body)


func _spot_is_free(p: Vector2) -> bool:
	var b: Array = Session.loc.get("bounds", [0, 0, 3600, 2600])
	if not Rect2(b[0] + 30, b[1] + 30, b[2] - 60, b[3] - 60).has_point(p):
		return false
	var q := PhysicsShapeQueryParameters2D.new()
	var c := CircleShape2D.new()
	c.radius = 18.0
	q.shape = c
	q.transform = Transform2D(0.0, p)
	q.collision_mask = 1
	q.exclude = [mech_view.get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(q, 1).is_empty()


func _on_mode_changed(m: String) -> void:
	if m == "foot" or m == "mech":
		pilot_view.sync_from_state()


func _process(delta: float) -> void:
	if not Session.running:
		return
	_t += delta
	var pts := [Session.mech_pos()]
	if Session.mode() != "mech":
		pts.append(Session.pilot_pos())
	for pv in props:
		pv.update_occlusion(pts, delta)
	_sync_markers()
	for id in _salvage_nodes:
		var n: Node2D = _salvage_nodes[id]
		n.get_child(0).position.y = sin(_t * 2.2 + n.position.x * 0.01) * 2.0
		n.get_child(1).energy = 0.35 + 0.25 * sin(_t * 3.0 + n.position.y * 0.02)


func any_roof_overhead() -> bool:
	for pv in props:
		if pv.occlude and pv.is_faded():
			return true
	return false


func _sync_markers() -> void:
	var taken: Dictionary = Session.state["world"]["taken"]
	for s in Session.loc.get("salvage", []):
		var id: String = s["id"]
		var want := not taken.has(id)
		if want and not _salvage_nodes.has(id):
			_salvage_nodes[id] = _marker(Content.v2(s["pos"]), Content.items.get(s["item"], {}).get("asset", "item.radiator_core"), Color(1.0, 0.85, 0.5))
		elif not want and _salvage_nodes.has(id):
			_salvage_nodes[id].queue_free()
			_salvage_nodes.erase(id)
	var live := {}
	for dr in Session.state["world"]["drops"]:
		live[dr["id"]] = true
		if not _drop_nodes.has(dr["id"]):
			_drop_nodes[dr["id"]] = _marker(Content.v2(dr["pos"]), "item.dropped_pack", Color(1.0, 0.6, 0.4))
	for id in _drop_nodes.keys():
		if not live.has(id):
			_drop_nodes[id].queue_free()
			_drop_nodes.erase(id)


func _marker(p: Vector2, asset: String, glow_color: Color) -> Node2D:
	var n := Node2D.new()
	n.position = p
	var holder := Node2D.new()
	n.add_child(holder)
	var s := Sprite2D.new()
	holder.add_child(s)
	Assets.apply_to_sprite(s, asset)
	var g := LightKit.glow(glow_color, 0.8, 0.4)
	n.add_child(g)
	markers.add_child(n)
	return n
