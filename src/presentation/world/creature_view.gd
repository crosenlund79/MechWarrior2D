class_name CreatureView
extends CharacterBody2D
## One living creature (skirr / grindback / rimeback). Reads
## Session.state.creatures[id] and the runtime brain (for telegraphs); moves by
## Session.creature_moves[id] through physics (rocks block it) and reports back
## with Session.commit_creature(). Purely presentational otherwise.
##
## Telegraphs are drawn in the world so danger is readable without UI:
##   skirr crouch → body squashes, eyes glint, short red lunge line
##   grindback tremor → racing sand mound + cracking ring where it will erupt;
##             paw → charge lane; dazed → rear vent glows (shoot it)
##   rimeback roar → pulse ring; charge → amber lane; sweep → tail coils + arc;
##             spit → frost glands swell and glow

const SHADOW_OFFSET := Vector2(10, 14)

var id := ""
var species := ""
var body: Node2D
var main: Sprite2D
var dead_sprite: Sprite2D
var head: Sprite2D
var tail: Sprite2D
var glands := {}
var mound: Sprite2D
var shadow: Sprite2D
var shadow_h: Node2D
var mound_h: Node2D
var lane: Polygon2D
var ring: Line2D
var arc: Polygon2D
var eye: PointLight2D
var vent: PointLight2D
var dust: CPUParticles2D
var _cs: CollisionShape2D
var _t := 0.0
var _flash := 0.0
var _hit := Vector2.ZERO
var _hit_v := Vector2.ZERO
var _tail_ang := 0.0
var _was_dead := false
var _parts_seen := {}


func setup(creature_id: String) -> void:
	id = creature_id
	name = "Creature_" + id


func _ready() -> void:
	var c := Session.creature(id)
	species = str(c.get("species", "skirr"))
	var ts := Session.creature_tun(c)
	collision_layer = 8
	collision_mask = 1 | 16
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_cs = CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = float(ts.get("collision", 40.0))
	_cs.shape = circle
	add_child(_cs)
	shadow_h = Node2D.new()
	shadow_h.top_level = true
	shadow_h.z_index = -2
	shadow_h.modulate = Color(1, 1, 1, 0.34)
	add_child(shadow_h)
	shadow = Sprite2D.new()
	shadow.material = LightKit.shadow_material()
	shadow_h.add_child(shadow)
	body = Node2D.new()
	add_child(body)
	body.material = LightKit.rotating_light_material()
	match species:
		"skirr":
			main = _sprite("creature.skirr", body)
			dead_sprite = _sprite("creature.skirr_dead", body)
		"grindback":
			main = _sprite("creature.grindback", body)
			dead_sprite = _sprite("creature.grindback_dead", body)
			mound_h = Node2D.new()
			mound_h.top_level = true
			mound_h.z_index = -4
			add_child(mound_h)
			mound = Sprite2D.new()
			mound.set_meta("asset", "creature.mound")
			mound_h.add_child(mound)
			Assets.apply_to_sprite(mound, "creature.mound")
			vent = LightKit.glow(Color(1.0, 0.5, 0.2), 0.7, 0.0)
			vent.position = Vector2(0, 66)
			body.add_child(vent)
		"rimeback":
			var th := Node2D.new()
			th.position = Vector2(0, 170)
			body.add_child(th)
			tail = _sprite("creature.rimeback_tail", th)
			main = _sprite("creature.rimeback", body)
			var hh := Node2D.new()
			hh.position = Vector2(0, -150)
			body.add_child(hh)
			head = _sprite("creature.rimeback_head", hh)
			for g in ["gland_l", "gland_r"]:
				var gh := Node2D.new()
				gh.position = Vector2(-86 if g == "gland_l" else 86, -40)
				body.add_child(gh)
				var gs := _sprite("creature.rime_gland", gh)
				glands[g] = gs
				var gl := LightKit.glow(Color(0.75, 0.9, 1.0), 0.8, 0.0)
				gh.add_child(gl)
				gs.set_meta("light", gl)
			dead_sprite = _sprite("creature.rimeback_dead", body)
	eye = LightKit.glow(Color(1.0, 0.35, 0.2), 0.45, 0.0)
	eye.position = Vector2(0, -30 if species == "skirr" else -60)
	body.add_child(eye)
	_sync_shadow(main)
	lane = Polygon2D.new()
	lane.top_level = true
	lane.z_index = -3
	lane.color = Color(0.95, 0.55, 0.2, 0.0)
	add_child(lane)
	ring = Line2D.new()
	ring.top_level = true
	ring.z_index = -3
	ring.width = 5.0
	ring.default_color = Color(0.4, 0.27, 0.15, 0.0)
	ring.closed = true
	add_child(ring)
	arc = Polygon2D.new()
	arc.top_level = true
	arc.z_index = -3
	arc.color = Color(0.95, 0.4, 0.2, 0.0)
	add_child(arc)
	dust = FxKit.footfall_dust()
	add_child(dust)
	for k in c.get("parts", {}):
		_parts_seen[k] = float(c["parts"][k]) > 0.0
	Session.combat_event.connect(_on_combat)
	Assets.reloaded.connect(_rebuild_art)
	global_position = Content.v2(c["pos"])
	_was_dead = Creatures.is_dead(c)


## Each sprite sits in its own holder: the fitted sprite keeps its pivot offset
## and scale; animation (squash, swell, sway) is applied to the holder.
func _sprite(asset: String, parent: Node2D) -> Sprite2D:
	var h := Node2D.new()
	h.use_parent_material = true
	parent.add_child(h)
	var s := Sprite2D.new()
	s.set_meta("asset", asset)
	s.use_parent_material = true
	h.add_child(s)
	Assets.apply_to_sprite(s, asset)
	return s


func _sync_shadow(src: Sprite2D) -> void:
	shadow.texture = src.texture
	shadow.centered = false
	shadow.position = src.position
	shadow.scale = src.scale


func _rebuild_art() -> void:
	for s in [main, dead_sprite, head, tail, mound] + glands.values():
		if s:
			Assets.apply_to_sprite(s, str(s.get_meta("asset", "")))
	_sync_shadow(main)


func _physics_process(_delta: float) -> void:
	if not Session.running:
		return
	var c := Session.creature(id)
	if c.is_empty():
		return
	collision_layer = 8 if Creatures.solid(c) else 0
	if Creatures.is_dead(c):
		global_position = Content.v2(c["pos"])
		return
	velocity = Session.creature_moves.get(id, Vector2.ZERO)
	move_and_slide()
	Session.commit_creature(id, global_position, get_real_velocity())


func _process(delta: float) -> void:
	if not Session.running:
		return
	var c := Session.creature(id)
	if c.is_empty():
		return
	_t += delta
	var ai := str(c["ai"])
	var dead := ai == "dead"
	var brain: Dictionary = Session.creature_brains.get(id, {})
	var tl := Creatures.tell(brain)
	var tell_v := float(tl["v"])
	var tell_k := str(tl["kind"])
	body.rotation = float(c["heading"])
	var spd := absf(float(c["speed"]))
	# hit flinch spring
	_hit_v += (-160.0 * _hit - 14.0 * _hit_v) * delta
	_hit += _hit_v * delta
	body.position = _hit.limit_length(16.0)
	_flash = move_toward(_flash, 0.0, delta * 3.0)
	var tint := Color(1, 1, 1).lerp(Color(1.9, 0.6, 0.5), _flash)
	main.visible = not dead
	dead_sprite.visible = dead
	var mh := main.get_parent() as Node2D
	if head:
		head.get_parent().get_parent().visible = not dead
		tail.get_parent().get_parent().visible = not dead
	var buried := ai in ["buried", "tunnel"]
	if species == "grindback":
		main.visible = not dead and not buried and ai != "burrow"
		mound_h.visible = buried or ai in ["burrow", "erupt"]
		mound_h.global_position = global_position
		mound_h.rotation = float(c["heading"])
		var sink := 1.0
		if ai == "burrow":
			sink = 1.0 - clampf(float(brain.get("t", 0.0)) / 1.1, 0.0, 1.0)
			main.visible = true
		mh.scale = Vector2.ONE * lerpf(0.7, 1.0, sink)
		mound_h.modulate.a = 0.55 + 0.35 * (1.0 if ai == "tunnel" else 0.3)
		mound_h.scale = Vector2.ONE * (1.25 if ai == "tunnel" else 0.9) * (1.0 + sin(_t * 9.0) * (0.05 if ai == "tunnel" else 0.01))
		vent.energy = (0.9 + 0.4 * sin(_t * 10.0)) if ai == "dazed" else (0.25 if main.visible and not dead else 0.0)
		dust.emitting = ai == "tunnel" or ai == "charge" or ai == "paw"
	else:
		dust.emitting = spd > 120.0
	dust.global_position = global_position
	# body motion: gait bob / squash in the skirr crouch
	var gait := sin(_t * (6.0 + spd * 0.04)) * minf(1.0, spd / 120.0)
	if species == "skirr" and not dead:
		var sq := 1.0 - 0.22 * tell_v
		mh.scale = Vector2(1.0 + 0.12 * tell_v, sq)
		mh.rotation = gait * 0.08
	elif species == "rimeback" and not dead:
		mh.rotation = gait * 0.02
		var head_drop := 0.0
		if tell_k == "charge":
			head_drop = tell_v
		elif ai == "charge":
			head_drop = 1.0
		var hh := head.get_parent().get_parent() as Node2D
		hh.position = Vector2(0, -150 + head_drop * 22.0)
		hh.scale = Vector2.ONE * (1.0 - 0.06 * head_drop)
		hh.rotation = sin(_t * 1.3) * 0.08 * (1.0 - head_drop) + (sin(_t * 30.0) * 0.06 * tell_v if tell_k == "roar" else 0.0)
		var want_tail := sin(_t * 1.6) * 0.18 + gait * 0.1
		if tell_k == "sweep":
			want_tail = -1.1 * tell_v * float(brain.get("side", 1))
		elif ai == "sweep":
			want_tail = 1.6 * float(brain.get("side", 1))
		_tail_ang = lerpf(_tail_ang, want_tail, 1.0 - exp(-(22.0 if ai == "sweep" else 5.0) * delta))
		var tlh := tail.get_parent().get_parent() as Node2D
		tlh.rotation = _tail_ang
		tlh.visible = float(c["parts"].get("tail", 1.0)) > 0.0
		for g in glands:
			var gs: Sprite2D = glands[g]
			var alive := float(c["parts"].get(g, 0.0)) > 0.0
			gs.get_parent().get_parent().visible = alive
			var swell := tell_v if tell_k == "spit" else 0.0
			(gs.get_parent() as Node2D).scale = Vector2.ONE * (1.0 + swell * 0.35 + sin(_t * 2.0) * 0.03)
			(gs.get_meta("light") as PointLight2D).energy = 0.15 + swell * 1.4 if alive else 0.0
		head.visible = true
		head.modulate = Color(1, 1, 1) if float(c["parts"].get("head", 1.0)) > 0.0 else Color(0.75, 0.65, 0.62)
	body.modulate = tint if not dead else Color(0.82, 0.78, 0.74)
	eye.energy = (0.4 + 1.2 * tell_v) if tell_k in ["crouch", "charge", "roar"] else 0.0
	# --- telegraphs drawn on the ground
	var pos := global_position
	var fwd := Drive.forward(float(c["heading"]))
	lane.color.a = move_toward(lane.color.a, 0.0, delta * 3.0)
	ring.default_color.a = move_toward(ring.default_color.a, 0.0, delta * 2.0)
	arc.color.a = move_toward(arc.color.a, 0.0, delta * 3.0)
	var ts := Session.creature_tun(c)
	if tell_k == "charge" or ai == "charge":
		var length := float(ts.get("charge_speed", 500.0)) * float(ts.get("charge_time", 1.3))
		var half := float(ts.get("ram_radius", 150.0)) * 0.7
		var d: Vector2 = brain.get("dir", fwd) if ai == "charge" else fwd
		var r := Vector2(-d.y, d.x) * half
		var start := pos + d * float(ts.get("collision", 60.0)) * 0.6
		lane.polygon = PackedVector2Array([start - r, start + r, start + d * length + r * 0.7, start + d * length - r * 0.7])
		lane.color = Color(0.95, 0.5, 0.18, (0.12 + 0.28 * tell_v) if ai != "charge" else 0.22)
	if tell_k == "crouch":
		lane.polygon = PackedVector2Array([pos - Vector2(-fwd.y, fwd.x) * 10.0, pos + Vector2(-fwd.y, fwd.x) * 10.0,
			pos + fwd * 300.0 + Vector2(-fwd.y, fwd.x) * 4.0, pos + fwd * 300.0 - Vector2(-fwd.y, fwd.x) * 4.0])
		lane.color = Color(0.9, 0.25, 0.15, 0.15 + 0.35 * tell_v)
	if tell_k == "tremor":
		var lock: Vector2 = brain.get("lock", pos)
		var rad := float(ts.get("erupt_radius", 135.0))
		ring.points = _circle(lock, rad * (0.4 + 0.6 * tell_v), 28, 7.0 * tell_v)
		ring.default_color = Color(0.35, 0.22, 0.12, 0.3 + 0.5 * tell_v)
		ring.width = 3.0 + 5.0 * tell_v
		if world_ref() and world_ref().camera and Session.actor_pos().distance_to(pos) < 700.0:
			world_ref().camera.add_shake(0.05 * tell_v, 0.25)
	if tell_k == "roar":
		ring.points = _circle(pos, 160.0 + 260.0 * tell_v, 40, 0.0)
		ring.default_color = Color(0.95, 0.85, 0.7, 0.35 * (1.0 - tell_v))
		ring.width = 4.0
	if tell_k == "sweep":
		var rad2 := float(ts.get("sweep_range", 300.0))
		var pts := PackedVector2Array([pos])
		var back := float(c["heading"]) + PI
		for k in 17:
			var a := back + lerpf(-1.9, 1.9, k / 16.0)
			pts.append(pos + Drive.forward(a) * rad2)
		arc.polygon = pts
		arc.color = Color(0.95, 0.42, 0.2, 0.1 + 0.25 * tell_v)
	# --- shadow (world-aligned offset)
	shadow_h.visible = main.visible or dead
	_sync_shadow(dead_sprite if dead else main)
	var hgt := 0.0
	var wv = get_parent()
	if wv and wv.get("relief"):
		hgt = wv.relief.height_at(pos)
	body.scale = body.scale.lerp(Vector2.ONE * (1.0 + hgt * Relief.SCALE_K), 1.0 - exp(-8.0 * delta))
	shadow_h.global_position = pos + SHADOW_OFFSET * (1.4 if species == "rimeback" else 1.0) * (1.0 + hgt * Relief.SHADOW_K)
	shadow_h.rotation = body.rotation
	if dead and not _was_dead:
		var puff := FxKit.puff(Color(0.45, 0.36, 0.28, 0.6), 20)
		get_parent().add_child(puff)
		puff.global_position = pos
		puff.emitting = true
		puff.finished.connect(puff.queue_free)
	_was_dead = dead


func _circle(at: Vector2, r: float, n: int, jitter: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in n:
		var a := TAU * k / n
		out.append(at + Vector2(cos(a), sin(a)) * (r + sin(a * 5.0 + _t * 20.0) * jitter))
	return out


func world_ref() -> Node:
	return get_parent()


func _on_combat(kind: String, data: Dictionary) -> void:
	if str(data.get("id", "")) != id:
		return
	match kind:
		"creature_hit":
			_flash = 0.35 if bool(data.get("armoured", false)) else 0.75
			var d: Vector2 = data.get("dir", Vector2.ZERO)
			_hit_v += d * (90.0 if species == "rimeback" else 220.0)
			var fx := FxKit.sparks() if bool(data.get("armoured", false)) else FxKit.puff(Color(0.5, 0.18, 0.16, 0.7), 6)
			get_parent().add_child(fx)
			fx.global_position = data.get("pos", global_position)
			fx.emitting = true
			fx.finished.connect(fx.queue_free)
		"part_broken":
			var deb := FxKit.debris(Color(0.85, 0.82, 0.76))
			get_parent().add_child(deb)
			deb.global_position = data.get("pos", global_position)
			deb.emitting = true
			deb.finished.connect(deb.queue_free)
			_flash = 1.0
		"creature_surface":
			var burst := FxKit.ground_blast()
			get_parent().add_child(burst)
			burst.global_position = global_position
			burst.emitting = true
			burst.finished.connect(burst.queue_free)
			var p2 := FxKit.puff(Color(0.8, 0.66, 0.46, 0.7), 26)
			get_parent().add_child(p2)
			p2.global_position = global_position
			p2.emitting = true
			p2.finished.connect(p2.queue_free)
			if get_parent().get("camera"):
				get_parent().camera.add_shake(0.5, 0.8)
