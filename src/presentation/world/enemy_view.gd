class_name EnemyView
extends CharacterBody2D
## Hostile RIVAL CAR (scrapper / Southern Junker). Reads Session.state.enemies[id];
## movement through Session.enemy_velocity (same car dynamics as the player).
## Visual states: active (wheels, roof gun swinging to its target, red telegraph
## line + muzzle glow during wind-up, steam when hot, smoke/leak when damaged),
## parked (driver outside; runs to the door, gets in, engine coughs to life) and
## wreck (burnt-out sprite, slow smoke, sparks, salvage glint until stripped).

const SHADOW_OFFSET := Vector2(12, 15)

var id := ""
var body: Node2D
var hull: Sprite2D
var leg_l: Sprite2D      # front wheels (legacy names)
var leg_r: Sprite2D
var wheels: Array[Sprite2D] = []
var gun: Sprite2D
var gun_holder: Node2D
var wreck: Sprite2D
var shadow: Node2D
var telegraph: Line2D
var muzzle_glow: PointLight2D
var steam: CPUParticles2D
var smoke: CPUParticles2D
var leak: CPUParticles2D
var glint: PointLight2D
var _stride := 0.0
var _flash := 0.0
var _spark_t := 1.0
var _was_wreck := false
var pilot_node: Node2D
var pilot_sprite: Sprite2D
var pilot_shadow: Node2D
var alert_mark: Label
var cockpit_light: PointLight2D
var _pose := 1.0
var _hit_off := Vector2.ZERO     # flinch from heavy hits (damped spring, visual only)
var _hit_vel := Vector2.ZERO
var _hit_rot := 0.0
var _hit_rot_vel := 0.0     # 0 = parked (lowered, legs tucked), 1 = standing / active
var _pilot_t := 0.0
var _cs: CollisionShape2D


func setup(enemy_id: String) -> void:
	id = enemy_id
	name = "Enemy_" + id


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 4 | 8 | 16
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_cs = CollisionShape2D.new()
	var c := CapsuleShape2D.new()
	c.radius = float(Session.tun("enemy").get("collision_radius", 44.0))
	c.height = float(Session.tun("enemy").get("collision_length", 200.0))
	_cs.shape = c
	add_child(_cs)
	shadow = Node2D.new()
	shadow.top_level = true
	shadow.z_index = -2
	shadow.modulate = Color(1, 1, 1, 0.36)
	add_child(shadow)
	body = Node2D.new()
	add_child(body)
	body.material = LightKit.rotating_light_material()
	var etype := str(Session.enemy(id).get("type", "scrapper"))
	var junk := etype == "junker"
	for wp in [Vector2(-52, -68), Vector2(52, -68), Vector2(-54, 72), Vector2(54, 72)]:
		wheels.append(_part("car.wheel", wp))
	leg_l = wheels[0]
	leg_r = wheels[1]
	hull = _part("rival.junker_body" if junk else "rival.body", Vector2.ZERO)
	wreck = _part("rival.junker_wreck" if junk else "rival.wreck", Vector2.ZERO)
	for s in [hull, wreck] + wheels:
		s.use_parent_material = true
	gun_holder = Node2D.new()
	gun_holder.top_level = true
	gun_holder.z_index = z_index + 1
	add_child(gun_holder)
	gun_holder.material = LightKit.rotating_light_material()
	gun = Sprite2D.new()
	gun.set_meta("asset", "rival.gun")
	gun.use_parent_material = true
	gun_holder.add_child(gun)
	Assets.apply_to_sprite(gun, "rival.gun")
	_build_shadow()
	telegraph = Line2D.new()
	telegraph.width = 3.0
	telegraph.default_color = Color(1.0, 0.3, 0.15, 0.0)
	telegraph.top_level = true
	telegraph.z_index = 22
	add_child(telegraph)
	muzzle_glow = LightKit.glow(Color(1.0, 0.45, 0.15), 0.6, 0.0)
	muzzle_glow.position = Vector2(0, -54)
	gun_holder.add_child(muzzle_glow)
	steam = FxKit.steam()
	steam.position = Vector2(0, -80)
	steam.emission_rect_extents = Vector2(30, 8)
	body.add_child(steam)
	leak = FxKit.coolant_leak()
	leak.position = Vector2(0, -96)
	body.add_child(leak)
	smoke = FxKit.damage_smoke()
	add_child(smoke)
	glint = LightKit.glow(Color(1.0, 0.85, 0.5), 0.9, 0.0)
	add_child(glint)
	cockpit_light = LightKit.glow(Color(1.0, 0.55, 0.2), 0.35, 0.0)
	cockpit_light.position = Vector2(-26, -10)
	body.add_child(cockpit_light)
	_build_pilot()
	Session.combat_event.connect(_on_combat)
	var e0 := Session.enemy(id)
	if not e0.is_empty() and str(e0["ai"]) in ["unpiloted", "alerted", "boarding", "starting"]:
		_pose = 0.0
	Assets.reloaded.connect(_rebuild_art)
	sync_from_state()


func _build_pilot() -> void:
	pilot_node = Node2D.new()
	pilot_node.top_level = true
	pilot_node.z_index = 2
	add_child(pilot_node)
	pilot_shadow = Node2D.new()
	pilot_shadow.top_level = true
	pilot_shadow.z_index = -1
	pilot_shadow.modulate = Color(1, 1, 1, 0.3)
	add_child(pilot_shadow)
	pilot_sprite = Sprite2D.new()
	pilot_sprite.set_meta("asset", "enemy.pilot")
	pilot_node.add_child(pilot_sprite)
	Assets.apply_to_sprite(pilot_sprite, "enemy.pilot")
	var ss := Sprite2D.new()
	ss.texture = pilot_sprite.texture
	ss.centered = false
	ss.scale = pilot_sprite.scale
	ss.position = pilot_sprite.position
	ss.material = LightKit.shadow_material()
	pilot_shadow.add_child(ss)
	pilot_node.material = LightKit.rotating_light_material()
	pilot_sprite.use_parent_material = true
	alert_mark = Label.new()
	alert_mark.text = "!"
	alert_mark.top_level = true
	alert_mark.z_index = 30
	alert_mark.add_theme_font_size_override("font_size", 34)
	alert_mark.add_theme_color_override("font_color", Color(1.0, 0.82, 0.3))
	alert_mark.add_theme_constant_override("outline_size", 8)
	alert_mark.add_theme_color_override("font_outline_color", Color(0.1, 0.07, 0.05, 0.95))
	alert_mark.visible = false
	add_child(alert_mark)


func _update_pilot(e: Dictionary, delta: float) -> void:
	var p: Dictionary = e.get("pilot", {})
	var st := str(p.get("state", "aboard"))
	var outside := st in ["outside", "climbing", "fled"]
	pilot_node.visible = outside
	pilot_shadow.visible = outside and st != "climbing"
	if not outside:
		alert_mark.visible = false
		return
	var pos := Content.v2(p["pos"])
	var moving := str(e["ai"]) == "boarding" or st == "fled"
	if moving:
		_pilot_t += delta * 14.0
	else:
		_pilot_t += delta * 1.5
	pilot_node.global_position = pos
	var sway := sin(_pilot_t) * (0.09 if moving else 0.03)
	pilot_node.rotation = float(p.get("facing", 0.0)) + sway
	var k := 1.0
	if st == "climbing":
		var b: Dictionary = Session.brains.get(id, {})
		var t := clampf(float(b.get("climb", 0.0)) / float(Session.tun("encounter").get("climb_time", 0.9)), 0.0, 1.0)
		k = lerpf(1.0, 0.72, t)
		pilot_node.z_index = 8   # climbing onto the hull
	else:
		pilot_node.z_index = 2
	pilot_node.scale = Vector2(k, k) * (1.0 + (absf(sin(_pilot_t)) * 0.04 if moving else 0.0))
	if st == "fled":
		var d := pos.distance_to(Content.v2(e["pos"]))
		pilot_node.modulate.a = clampf(1.0 - (d - 400.0) / 300.0, 0.0, 1.0)
	else:
		pilot_node.modulate.a = 1.0
	pilot_shadow.global_position = pos + Vector2(6, 8)
	pilot_shadow.rotation = pilot_node.rotation
	alert_mark.visible = str(e["ai"]) == "alerted" or (str(e["ai"]) == "boarding" and st == "outside")
	alert_mark.global_position = pos + Vector2(-8, -64 - absf(sin(Time.get_ticks_msec() * 0.012)) * 6.0)


func _part(asset: String, at: Vector2) -> Sprite2D:
	var h := Node2D.new()
	h.position = at
	body.add_child(h)
	var s := Sprite2D.new()
	s.set_meta("asset", asset)
	h.add_child(s)
	Assets.apply_to_sprite(s, asset)
	return s


func _build_shadow() -> void:
	for ch in shadow.get_children():
		ch.queue_free()
	var holder := Node2D.new()
	shadow.add_child(holder)
	for src in wheels + [hull, wreck]:
		var s := Sprite2D.new()
		s.texture = src.texture
		s.centered = false
		s.scale = src.scale
		s.position = src.position
		s.material = LightKit.shadow_material()
		var h := Node2D.new()
		h.position = src.get_parent().position
		h.scale = src.get_parent().scale
		h.add_child(s)
		h.set_meta("src", src)
		holder.add_child(h)


func _rebuild_art() -> void:
	for s in wheels + [hull, wreck, gun]:
		Assets.apply_to_sprite(s, str(s.get_meta("asset")))
	_build_shadow()


func sync_from_state() -> void:
	var e := Session.enemy(id)
	if e.is_empty():
		return
	global_position = Content.v2(e["pos"])
	body.rotation = float(e["heading"])
	if _cs:
		_cs.rotation = body.rotation


func _physics_process(delta: float) -> void:
	if not Session.running:
		return
	var e := Session.enemy(id)
	if e.is_empty() or str(e["ai"]) == "wreck":
		return
	velocity = Session.enemy_velocity(id, delta)
	_cs.rotation = float(e["heading"])
	move_and_slide()
	Session.commit_enemy(id, global_position, get_real_velocity())


func _process(delta: float) -> void:
	if not Session.running:
		return
	var e := Session.enemy(id)
	if e.is_empty():
		return
	var is_wreck := str(e["ai"]) == "wreck"
	body.rotation = float(e["heading"])
	hull.get_parent().visible = not is_wreck
	for wh in wheels:
		wh.get_parent().visible = not is_wreck
	wreck.get_parent().visible = is_wreck
	gun_holder.visible = not is_wreck
	var it: Dictionary = Session.enemy_intents.get(id, {})
	for i in 2:
		wheels[i].get_parent().rotation = lerpf(wheels[i].get_parent().rotation, float(it.get("turn", 0.0)) * 0.45, 1.0 - exp(-8.0 * delta))
	# Parked: engine cold, body settled. Startup: the engine coughs and the body
	# shakes. Active: running.
	var ai := str(e["ai"])
	var target_pose := 1.0
	var shudder := 0.0
	if ai in ["unpiloted", "alerted", "boarding"]:
		target_pose = 0.0
	elif ai == "starting":
		var b: Dictionary = Session.brains.get(id, {})
		var t := clampf(float(b.get("t_state", 0.0)) / float(Session.tun("encounter").get("startup_time", 3.2)), 0.0, 1.0)
		target_pose = smoothstep(0.15, 0.95, t)
		shudder = (1.0 - t) * 0.6 + 0.4 * sin(t * PI)
	if is_wreck:
		target_pose = 1.0
	_pose = move_toward(_pose, target_pose, delta * 1.2)
	var lift := lerpf(0.97, 1.0, _pose)
	hull.get_parent().scale = Vector2(lift, lift)
	_hit_vel += (-180.0 * _hit_off - 16.0 * _hit_vel) * delta
	_hit_off += _hit_vel * delta
	_hit_rot_vel += (-200.0 * _hit_rot - 14.0 * _hit_rot_vel) * delta
	_hit_rot += _hit_rot_vel * delta
	body.position = _hit_off.limit_length(14.0)
	body.rotation = float(e["heading"]) + clampf(_hit_rot, -0.12, 0.12)
	hull.get_parent().position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 2.5 * shudder
	cockpit_light.energy = 0.0 if ai in ["unpiloted", "alerted", "boarding"] or is_wreck else (0.5 + 0.4 * sin(Time.get_ticks_msec() * 0.02) if ai == "starting" else 0.35)
	_update_pilot(e, delta)
	var tt := Session.enemy_thermal()
	var heat := float(e["heat"])
	steam.emitting = not is_wreck and (heat >= float(tt.get("warn_temp", 98.0)) or str(e["engine"]) == "shutdown")
	leak.emitting = not is_wreck and float(e["radiator"]) < 0.35
	var integ := float(e["integrity"]) / float(Session.enemy_tun(e).get("integrity", 55.0))
	smoke.emitting = is_wreck or integ < 0.5
	smoke.global_position = global_position + Vector2(10, -10)
	# Telegraph: red aim line + growing muzzle glow while the weapon winds up.
	var w := float(it.get("windup", 0.0))
	var gang := float(it.get("gun", e["heading"]))
	gun_holder.global_position = global_position + body.position + Vector2(18, -6).rotated(body.rotation)
	gun_holder.rotation = gang
	var fwd := Drive.forward(gang)
	var muzzle := gun_holder.global_position + fwd * 54.0
	if w > 0.0 and not is_wreck:
		var pulse := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.03)
		telegraph.points = PackedVector2Array([muzzle, muzzle + fwd * float(Session.tun("combat")["enemy_weapon"]["range"]) * 0.9])
		telegraph.default_color = Color(1.0, 0.3, 0.15, (0.25 + 0.5 * w) * pulse)
		telegraph.width = 2.0 + 3.0 * w
		muzzle_glow.energy = 0.3 + 1.2 * w
	else:
		telegraph.default_color.a = move_toward(telegraph.default_color.a, 0.0, delta * 4.0)
		muzzle_glow.energy = move_toward(muzzle_glow.energy, 0.0, delta * 4.0)
	_flash = move_toward(_flash, 0.0, delta * 3.0)
	body.modulate = Color(1, 1, 1).lerp(Color(1.9, 0.6, 0.5), _flash)
	if is_wreck:
		body.modulate = body.modulate * Color(0.82, 0.78, 0.74)
		glint.energy = 0.0 if bool(e.get("salvaged", false)) else 0.35 + 0.2 * sin(Time.get_ticks_msec() * 0.003)
		_spark_t -= delta
		if _spark_t <= 0.0 and not bool(e.get("salvaged", false)):
			_spark_t = randf_range(1.5, 4.0)
			var sp := FxKit.sparks()
			sp.amount = 5
			get_parent().add_child(sp)
			sp.global_position = global_position + Vector2(randf_range(-40, 40), randf_range(-40, 40))
			sp.emitting = true
			sp.finished.connect(sp.queue_free)
	else:
		glint.energy = 0.0
	if is_wreck and not _was_wreck:
		var boom := FxKit.puff(Color(0.25, 0.2, 0.16, 0.7), 24)
		get_parent().add_child(boom)
		boom.global_position = global_position
		boom.scale_amount_max = 4.0
		boom.emitting = true
		boom.finished.connect(boom.queue_free)
	_was_wreck = is_wreck
	var hgt := 0.0
	var wv = get_parent()
	if wv and wv.get("relief"):
		hgt = wv.relief.height_at(global_position)
	# visual-only elevation scale (never scale the physics body itself)
	body.scale = body.scale.lerp(Vector2.ONE * (1.0 + hgt * Relief.SCALE_K), 1.0 - exp(-8.0 * delta))
	gun_holder.scale = body.scale
	shadow.global_position = global_position + SHADOW_OFFSET * lerpf(0.45, 1.0, _pose) * (1.0 + hgt * Relief.SHADOW_K)
	var sb: Node2D = shadow.get_child(0) if shadow.get_child_count() > 0 else null
	if sb:
		sb.rotation = body.rotation
		for h in sb.get_children():
			var src: Sprite2D = h.get_meta("src")
			h.visible = src.get_parent().visible
			h.position = src.get_parent().position
			h.rotation = src.get_parent().rotation


func _on_combat(kind: String, data: Dictionary) -> void:
	if str(data.get("id", "")) == id and (kind == "startup" or kind == "active"):
		var puff := FxKit.puff(Color(0.9, 0.88, 0.84, 0.55), 18 if kind == "startup" else 10)
		get_parent().add_child(puff)
		puff.global_position = global_position + Drive.forward(body.rotation) * -50.0
		puff.emitting = true
		puff.finished.connect(puff.queue_free)
	if str(data.get("target", "")) == id and (kind == "impact" or kind == "cooling_hit"):
		_flash = 0.7
		var d: Vector2 = data.get("dir", Vector2.ZERO)
		_hit_vel += d * 260.0
		_hit_rot_vel += randf_range(-1.0, 1.0) * 2.2
