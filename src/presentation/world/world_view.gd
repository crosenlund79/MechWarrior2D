class_name WorldView
extends Node2D
## Builds the visible location from data (ground, props, salvage markers, drops,
## actors, camera) and keeps markers in sync with Session.state. Rebuildable:
## destroying this node never loses game state.
##
## Top-down layering (z_index):
##   -10 ground tiles · -5 floor decals · -3 prop cast shadows · 0 low props
##   4 creatures · 5 cars · 6 pilot · 8 roof cast shadow · 20 overhead (roofs, fade when under)
##   25 airborne particles. Grade on CanvasLayer 5, UI on CanvasLayer 10.

const Z := {"ground": -10, "floor": -5, "low": 0, "mech": 5, "pilot": 6, "overhead": 20, "air": 25}

var ground: Node2D
var floor_layer: Node2D
var low: Node2D
var overhead: Node2D
var markers: Node2D
var mech_view: CarView     # the player's car (legacy name kept for tools)
var creature_views := {}
var marks: HuntMarks
var pilot_view: PilotView
var camera: CameraRig
var enemy_views := {}
var turret_views := {}
var projectiles_view: ProjectilesView
var terrain: TerrainView
var rock: Node2D
var cover_layer: Node2D
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
	rock = _layer("Rock", 3)
	cover_layer = _layer("Covers", 21)
	terrain = TerrainView.new()
	add_child(terrain)
	terrain.build(loc, rock, cover_layer, floor_layer)
	_build_bounds(loc)
	for d in loc.get("props", []):
		var pv := PropView.new()
		var layer := str(d.get("layer", "low"))
		var parent: Node2D = floor_layer if layer == "floor" else (overhead if layer == "overhead" else low)
		parent.add_child(pv)
		pv.setup(d)
		props.append(pv)
	Scatter.build(low, loc)
	marks = HuntMarks.new()
	add_child(marks)
	marks.setup(floor_layer, markers)
	for cid in Session.state.get("creatures", {}):
		_add_creature_view(str(cid))
	Session.world_moves_creatures = true
	mech_view = CarView.new()
	mech_view.name = "Car"
	mech_view.z_index = Z["mech"]
	add_child(mech_view)
	pilot_view = PilotView.new()
	pilot_view.name = "Pilot"
	pilot_view.z_index = Z["pilot"]
	add_child(pilot_view)
	for id in Session.state.get("enemies", {}):
		_add_enemy_view(str(id))
	for td in loc.get("turrets", []):
		var tv := TurretView.new()
		tv.setup(td)
		tv.z_index = Z["mech"] - 1
		add_child(tv)
		turret_views[str(td["id"])] = tv
	projectiles_view = ProjectilesView.new()
	add_child(projectiles_view)
	camera = CameraRig.new()
	add_child(camera)
	camera.make_current()
	Session.spot_is_free = _spot_is_free
	Session.mech_spot_free = _mech_spot_free
	Session.dev_spawned.connect(_on_dev_spawned)
	Session.dev_teleported.connect(_on_teleported)
	mech_view.world_ref = self
	Session.shot_blocked = _shot_blocked
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


func _add_enemy_view(id: String) -> void:
	var ev := EnemyView.new()
	ev.setup(id)
	ev.z_index = Z["mech"]
	add_child(ev)
	enemy_views[id] = ev


func _add_creature_view(id: String) -> void:
	var cv := CreatureView.new()
	cv.setup(id)
	cv.z_index = Z["mech"] - 1
	add_child(cv)
	creature_views[id] = cv


func add_skid(at: Vector2, rot: float, strength: float) -> void:
	marks.add_skid(at, rot, strength)


func _exit_tree() -> void:
	Session.world_moves_creatures = false


func _on_dev_spawned(id: String) -> void:
	if Session.state.get("creatures", {}).has(id) and not creature_views.has(id):
		_add_creature_view(id)
		return
	if not Session.state.get("creatures", {}).has(id) and creature_views.has(id):
		creature_views[id].queue_free()
		creature_views.erase(id)
		return
	if Session.state.get("enemies", {}).has(id) and not enemy_views.has(id):
		_add_enemy_view(id)
	elif not Session.state.get("enemies", {}).has(id) and enemy_views.has(id):
		enemy_views[id].queue_free()
		enemy_views.erase(id)


func _on_teleported() -> void:
	mech_view.sync_from_state()
	for cid in Session.state.get("creatures", {}):
		if not creature_views.has(cid):
			_add_creature_view(str(cid))
	pilot_view.sync_from_state()
	camera.snap()


## A spot big enough for a mech (radius 120): no rock, walls, props or mechs.
func _mech_spot_free(p: Vector2) -> bool:
	var b: Array = Session.loc.get("bounds", [0, 0, 3600, 2600])
	if not Rect2(b[0] + 150, b[1] + 150, b[2] - 300, b[3] - 300).has_point(p):
		return false
	var q := PhysicsShapeQueryParameters2D.new()
	var c := CircleShape2D.new()
	c.radius = 120.0
	q.shape = c
	q.transform = Transform2D(0.0, p)
	q.collision_mask = 1 | 4 | 8
	return get_world_2d().direct_space_state.intersect_shape(q, 1).is_empty()


func _spot_is_free(p: Vector2) -> bool:
	var b: Array = Session.loc.get("bounds", [0, 0, 3600, 2600])
	if not Rect2(b[0] + 30, b[1] + 30, b[2] - 60, b[3] - 60).has_point(p):
		return false
	var q := PhysicsShapeQueryParameters2D.new()
	var c := CircleShape2D.new()
	c.radius = 18.0
	q.shape = c
	q.transform = Transform2D(0.0, p)
	q.collision_mask = 1 | 4
	q.exclude = [mech_view.get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(q, 1).is_empty()


## Projectiles stop at static obstacles (layer 1: props, walls, bounds). Mechs
## are on layer 4 and are hit-tested by the simulation instead.
func _shot_blocked(a: Vector2, b: Vector2) -> bool:
	var q := PhysicsRayQueryParameters2D.create(a, b, 1)
	return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()


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
		pv.animate(delta)
	terrain.update(pts, delta)
	_sync_markers()
	for id in _salvage_nodes:
		var n: Node2D = _salvage_nodes[id]
		n.get_child(0).position.y = sin(_t * 2.2 + n.position.x * 0.01) * 2.0
		n.get_child(1).energy = 0.35 + 0.25 * sin(_t * 3.0 + n.position.y * 0.02)


func any_roof_overhead() -> bool:
	for pv in props:
		if pv.occlude and pv.is_faded():
			return true
	return terrain.coverage([Session.actor_pos()]) > 0.5


## 0..1: how far the active actor is under rock cover (atmosphere / audio).
func cover_amount() -> float:
	return terrain.coverage([Session.actor_pos()])


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
