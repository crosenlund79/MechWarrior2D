class_name HuntMarks
extends Node2D
## Ground-level hunting signs and loot, synced from Session.state:
##   · creature tracks (state.tracks) as decals that fade with age — fresh ones
##     are dark and crisp, old ones faint; blood-marked ones carry red drops;
##   · physical ground loot (state.world.loot): the item icon on the sand with a
##     rarity glow (bone common · straw uncommon · bronze rare · temper-violet
##     legendary with a turning star), bobbing gently;
##   · tyre skid marks (runtime only, fade out).
## Purely visual; rebuildable at any time.

const RARITY_COLOR := {
	"common": Color(0.89, 0.84, 0.75),
	"uncommon": Color(0.86, 0.72, 0.42),
	"rare": Color(0.78, 0.5, 0.26),
	"legendary": Color(0.62, 0.48, 0.95),
}
const TRACK_ASSET := {"skirr": "decal.track_skirr", "rimeback": "decal.track_rime", "grindback": "decal.furrow"}

var floor_layer: Node2D   # tracks + skids (below props)
var loot_layer: Node2D    # loot markers
var _tracks := {}         # key -> Node2D
var _loot := {}           # id -> Node2D
var _skids: Array[Node2D] = []
var _sync_t := 0.0
var _t := 0.0


func setup(floor_parent: Node2D, loot_parent: Node2D) -> void:
	floor_layer = Node2D.new()
	floor_layer.name = "Tracks"
	floor_parent.add_child(floor_layer)
	loot_layer = Node2D.new()
	loot_layer.name = "Loot"
	loot_layer.z_index = 3   # above creatures and carcasses (loot must never hide under a body)
	loot_parent.add_child(loot_layer)
	_sync_tracks()
	_sync_loot()


func _process(delta: float) -> void:
	if not Session.running:
		return
	_t += delta
	_sync_t -= delta
	if _sync_t <= 0.0:
		_sync_t = 0.5
		_sync_tracks()
	_sync_loot()
	for id in _loot:
		var n: Node2D = _loot[id]
		n.get_child(0).position.y = sin(_t * 2.4 + n.position.x * 0.01) * 2.5
		var star: Node2D = n.get_node_or_null("Star")
		if star:
			star.rotation += delta * 1.2
			star.scale = Vector2.ONE * (1.0 + 0.12 * sin(_t * 4.0))
		var g: PointLight2D = n.get_child(1)
		g.energy = float(n.get_meta("glow")) * (0.75 + 0.25 * sin(_t * 3.0 + n.position.y * 0.02))
	for s in _skids.duplicate():
		s.modulate.a -= delta / 9.0
		if s.modulate.a <= 0.0:
			_skids.erase(s)
			s.queue_free()


func _key(t: Dictionary) -> String:
	return "%s_%d_%d_%d" % [t["s"], int(float(t["p"][0])), int(float(t["p"][1])), int(float(t["t"]) * 10.0)]


func _sync_tracks() -> void:
	var life := float(Session.tun("creatures").get("track_life", 420.0))
	var now := float(Session.state.get("playtime", 0.0))
	var live := {}
	for t in Session.state.get("tracks", []):
		var k := _key(t)
		live[k] = true
		var n: Node2D = _tracks.get(k)
		if n == null:
			n = Node2D.new()
			n.position = Content.v2(t["p"])
			n.rotation = float(t["h"])
			var s := Sprite2D.new()
			Assets.apply_to_sprite(s, TRACK_ASSET.get(str(t["s"]), "decal.track_skirr"))
			n.add_child(s)
			if bool(t.get("b", false)):
				var b := Sprite2D.new()
				Assets.apply_to_sprite(b, "decal.blood")
				n.add_child(b)
			floor_layer.add_child(n)
			_tracks[k] = n
		var fresh := clampf(1.0 - (now - float(t["t"])) / life, 0.0, 1.0)
		n.modulate = Color(1, 1, 1, 0.12 + 0.78 * fresh)
	for k in _tracks.keys():
		if not live.has(k):
			_tracks[k].queue_free()
			_tracks.erase(k)


func _sync_loot() -> void:
	var live := {}
	for l in Session.state.get("world", {}).get("loot", []):
		var id := str(l["id"])
		live[id] = true
		if not _loot.has(id):
			_loot[id] = _marker(l)
	for id in _loot.keys():
		if not live.has(id):
			_loot[id].queue_free()
			_loot.erase(id)


func _marker(l: Dictionary) -> Node2D:
	var item := str(l["item"])
	var rar := Loot.rarity(item)
	var col: Color = RARITY_COLOR.get(rar, RARITY_COLOR["common"])
	var n := Node2D.new()
	n.position = Content.v2(l["pos"])
	var holder := Node2D.new()
	n.add_child(holder)
	var s := Sprite2D.new()
	holder.add_child(s)
	Assets.apply_to_sprite(s, str(Content.items.get(item, {}).get("asset", "item.scrap")))
	var glow_e := {"common": 0.35, "uncommon": 0.5, "rare": 0.7, "legendary": 1.1}.get(rar, 0.35) as float
	var g := LightKit.glow(col, 0.7 if rar != "legendary" else 1.2, glow_e)
	n.add_child(g)
	n.set_meta("glow", glow_e)
	# rarity ring on the sand
	var ring := Line2D.new()
	ring.width = 2.5 if rar != "legendary" else 4.0
	ring.default_color = Color(col.r, col.g, col.b, 0.75)
	ring.closed = true
	var pts := PackedVector2Array()
	for k in 20:
		var a := TAU * k / 20.0
		pts.append(Vector2(cos(a), sin(a) * 0.8) * 30.0)
	ring.points = pts
	ring.z_index = -1
	n.add_child(ring)
	if rar == "legendary":
		var star := Polygon2D.new()
		star.name = "Star"
		var sp := PackedVector2Array()
		for k in 10:
			var a := TAU * k / 10.0
			sp.append(Vector2(cos(a), sin(a)) * (46.0 if k % 2 == 0 else 16.0))
		star.polygon = sp
		star.color = Color(col.r, col.g, col.b, 0.35)
		star.z_index = -1
		n.add_child(star)
	if int(l.get("n", 1)) > 1:
		var lab := Label.new()
		lab.text = "×%d" % int(l["n"])
		lab.position = Vector2(14, 4)
		lab.add_theme_font_size_override("font_size", 14)
		lab.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
		lab.add_theme_constant_override("outline_size", 5)
		lab.add_theme_color_override("font_outline_color", Color(0.1, 0.07, 0.05, 0.9))
		n.add_child(lab)
	loot_layer.add_child(n)
	return n


func add_skid(at: Vector2, rot: float, strength: float) -> void:
	var n := Node2D.new()
	n.position = at
	n.rotation = rot
	var s := Sprite2D.new()
	Assets.apply_to_sprite(s, "decal.skid")
	n.add_child(s)
	n.modulate = Color(1, 1, 1, 0.35 + 0.45 * strength)
	floor_layer.add_child(n)
	_skids.append(n)
	while _skids.size() > 360:
		_skids.pop_front().queue_free()
