class_name EnemyView
extends CharacterBody2D
## Hostile scrapper mech. Reads Session.state.enemies[id]; movement through
## Session.enemy_velocity (same drive rules as the player). Visual states:
## active (legs stride, red telegraph line + muzzle glow during wind-up, steam
## when hot, smoke/leak when damaged) and wreck (collapsed sprite, slow smoke,
## occasional sparks, salvage glint until salvaged).

const SHADOW_OFFSET := Vector2(12, 15)

var id := ""
var body: Node2D
var hull: Sprite2D
var leg_l: Sprite2D
var leg_r: Sprite2D
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


func setup(enemy_id: String) -> void:
	id = enemy_id
	name = "Enemy_" + id


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 4
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = float(Session.tun("enemy").get("collision_radius", 66.0))
	cs.shape = c
	add_child(cs)
	shadow = Node2D.new()
	shadow.top_level = true
	shadow.z_index = -2
	shadow.modulate = Color(1, 1, 1, 0.36)
	add_child(shadow)
	body = Node2D.new()
	add_child(body)
	body.material = LightKit.rotating_light_material()
	leg_l = _part("enemy.leg", Vector2(-62, 0))
	leg_r = _part("enemy.leg", Vector2(62, 0))
	leg_r.get_parent().scale.x = -1
	hull = _part("enemy.hull", Vector2.ZERO)
	wreck = _part("enemy.wreck", Vector2.ZERO)
	for s in [leg_l, leg_r, hull, wreck]:
		s.use_parent_material = true
	_build_shadow()
	telegraph = Line2D.new()
	telegraph.width = 3.0
	telegraph.default_color = Color(1.0, 0.3, 0.15, 0.0)
	telegraph.top_level = true
	telegraph.z_index = 22
	add_child(telegraph)
	muzzle_glow = LightKit.glow(Color(1.0, 0.45, 0.15), 0.6, 0.0)
	muzzle_glow.position = Vector2(0, -84)
	body.add_child(muzzle_glow)
	steam = FxKit.steam()
	steam.position = Vector2(0, 60)
	steam.emission_rect_extents = Vector2(30, 8)
	body.add_child(steam)
	leak = FxKit.coolant_leak()
	leak.position = Vector2(0, 70)
	body.add_child(leak)
	smoke = FxKit.damage_smoke()
	add_child(smoke)
	glint = LightKit.glow(Color(1.0, 0.85, 0.5), 0.9, 0.0)
	add_child(glint)
	Session.combat_event.connect(_on_combat)
	Assets.reloaded.connect(_rebuild_art)
	sync_from_state()


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
	for src in [leg_l, leg_r, hull, wreck]:
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
	for s in [leg_l, leg_r, hull, wreck]:
		Assets.apply_to_sprite(s, str(s.get_meta("asset")))
	_build_shadow()


func sync_from_state() -> void:
	var e := Session.enemy(id)
	if e.is_empty():
		return
	global_position = Content.v2(e["pos"])
	body.rotation = float(e["heading"])


func _physics_process(delta: float) -> void:
	if not Session.running:
		return
	var e := Session.enemy(id)
	if e.is_empty() or str(e["ai"]) == "wreck":
		return
	velocity = Session.enemy_velocity(id, delta)
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
	leg_l.get_parent().visible = not is_wreck
	leg_r.get_parent().visible = not is_wreck
	wreck.get_parent().visible = is_wreck
	var frac := clampf(absf(float(e["speed"])) / float(Session.tun("enemy").get("max_speed", 78.0)), 0.0, 1.0)
	_stride += delta * (2.0 + 6.0 * frac) * (1.0 if absf(float(e["speed"])) > 1.0 else 0.0)
	var swing := sin(_stride) * 16.0 * minf(1.0, frac * 3.0)
	leg_l.get_parent().position = Vector2(-62, -swing)
	leg_r.get_parent().position = Vector2(62, swing)
	var tt := Session.enemy_thermal()
	var heat := float(e["heat"])
	steam.emitting = not is_wreck and (heat >= float(tt.get("warn_temp", 98.0)) or str(e["engine"]) == "shutdown")
	leak.emitting = not is_wreck and float(e["radiator"]) < 0.35
	var integ := float(e["integrity"]) / float(Session.tun("enemy").get("integrity", 55.0))
	smoke.emitting = is_wreck or integ < 0.5
	smoke.global_position = global_position + Vector2(10, -10)
	# Telegraph: red aim line + growing muzzle glow while the weapon winds up.
	var w := float(Session.enemy_intents.get(id, {}).get("windup", 0.0))
	var fwd := Drive.forward(float(e["heading"]))
	var muzzle := global_position + fwd * 82.0
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
	shadow.global_position = global_position + SHADOW_OFFSET
	var sb: Node2D = shadow.get_child(0) if shadow.get_child_count() > 0 else null
	if sb:
		sb.rotation = body.rotation
		for h in sb.get_children():
			var src: Sprite2D = h.get_meta("src")
			h.visible = src.get_parent().visible
			h.position = src.get_parent().position


func _on_combat(kind: String, data: Dictionary) -> void:
	if str(data.get("target", "")) == id and (kind == "impact" or kind == "cooling_hit"):
		_flash = 0.7
