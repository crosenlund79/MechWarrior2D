class_name CarView
extends CharacterBody2D
## Draws and moves the player's CAR. Movement intent → Session.mech_velocity()
## (car dynamics), physics → move_and_slide(), result → Session.commit_mech().
## All state lives in Session.state.mech (legacy key = the car); this node can
## be rebuilt at any time.
##
## Top-down construction (nose "up" at rotation 0): body, four wheels (the front
## pair steers with the input), a rotating roof gun ring with twin guns, and a
## runtime cast shadow offset toward the lower right (sun upper-left) that does
## NOT rotate with the car. Weight comes from body roll in turns, squat/dive on
## throttle and brakes, skid marks, tyre dust and impact shake.

const SHADOW_OFFSET := Vector2(12, 16)
const WHEELS := [Vector2(-58, -76), Vector2(58, -76), Vector2(-60, 80), Vector2(60, 80)]
const GUN_MOUNTS := [Vector2(-17, -24), Vector2(17, -24)]
const RING_POS := Vector2(0, 0)

var body: Node2D          # rotates with heading
var chassis: Node2D       # rolls / squats inside body
var hull: Sprite2D
var wheels: Array[Sprite2D] = []
var shadow: Node2D
var heat_glow: PointLight2D
var steam: CPUParticles2D
var dust: CPUParticles2D
var housing_holder: Node2D
var housing: Sprite2D
var guns: Array[Sprite2D] = []
var gun_holders: Array[Node2D] = []
var housing_shadow: Node2D
var headlights: Array[PointLight2D] = []
var _gun_off := [0.0, 0.0]
var _gun_vel := [0.0, 0.0]
var _h_off := 0.0
var _h_vel := 0.0
var _h_rot := 0.0
var _h_rot_vel := 0.0
var flash_lights: Array[PointLight2D] = []
var flashes: Array[Sprite2D] = []
var world_ref: Node
var leak: CPUParticles2D
var smoke: CPUParticles2D
var _flash := 0.0
var _last_speed := 0.0
var _accel_s := 0.0
var _lean := 0.0
var _shake := 0.0
var _steer := 0.0
var _skid_t := 0.0
var _roll := 0.0
var _cs: CollisionShape2D


func _ready() -> void:
	collision_layer = 4   # vehicles
	collision_mask = 1 | 4 | 8
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	wall_min_slide_angle = 0.0
	_cs = CollisionShape2D.new()
	var cap := CapsuleShape2D.new()
	var tm := Session.tun("mech")
	cap.radius = float(tm.get("collision_radius", 50.0))
	cap.height = float(tm.get("collision_length", 228.0))
	_cs.shape = cap
	add_child(_cs)
	shadow = Node2D.new()
	shadow.name = "Shadow"
	shadow.top_level = true
	shadow.z_index = -2
	add_child(shadow)
	body = Node2D.new()
	body.name = "Body"
	add_child(body)
	chassis = Node2D.new()
	body.add_child(chassis)
	for i in 4:
		wheels.append(_part("car.wheel", WHEELS[i], chassis))
	hull = _part("car.body", Vector2.ZERO, chassis)
	for sx in [-1.0, 1.0]:
		var hl := LightKit.glow(Color(1.0, 0.82, 0.5), 0.9, 0.0)
		hl.position = Vector2(sx * 40.0, -150.0)
		chassis.add_child(hl)
		headlights.append(hl)
	housing_holder = Node2D.new()
	housing_holder.name = "GunRing"
	add_child(housing_holder)
	housing_holder.material = LightKit.rotating_light_material()
	housing = Sprite2D.new()
	housing.set_meta("asset", "car.gun_ring")
	housing.use_parent_material = true
	housing_holder.add_child(housing)
	Assets.apply_to_sprite(housing, "car.gun_ring")
	for i in 2:
		var gh := Node2D.new()
		gh.position = GUN_MOUNTS[i]
		if i == 1:
			gh.scale.x = -1
		housing_holder.add_child(gh)
		var g := Sprite2D.new()
		g.set_meta("asset", "car.twin_gun")
		g.use_parent_material = true
		gh.add_child(g)
		Assets.apply_to_sprite(g, "car.twin_gun")
		guns.append(g)
		gun_holders.append(gh)
		var fl := Sprite2D.new()
		var ft := "res://assets/fx/muzzle_flash.png"
		fl.texture = load(ft) if ResourceLoader.exists(ft) else FxKit.dot()
		fl.position = Vector2(0, -52)
		fl.scale = Vector2(0.6, 0.6)
		fl.visible = false
		fl.z_index = 3
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		fl.material = add
		gh.add_child(fl)
		flashes.append(fl)
		var lt := LightKit.glow(Color(1.0, 0.72, 0.35), 1.0, 0.0)
		lt.position = Vector2(0, -52)
		gh.add_child(lt)
		flash_lights.append(lt)
	_build_shadow()
	leak = FxKit.coolant_leak()
	leak.position = Vector2(0, -108)
	chassis.add_child(leak)
	smoke = FxKit.damage_smoke()
	add_child(smoke)
	heat_glow = LightKit.glow(Color(1.0, 0.45, 0.2), 1.0, 0.0)
	heat_glow.position = Vector2(0, -96)
	chassis.add_child(heat_glow)
	steam = FxKit.steam()
	steam.position = Vector2(0, -100)
	chassis.add_child(steam)
	dust = FxKit.footfall_dust()
	add_child(dust)
	body.material = LightKit.rotating_light_material()
	for s in [hull] + wheels:
		s.use_parent_material = true
	Session.mech_event.connect(_on_mech_event)
	Session.combat_event.connect(on_combat)
	Assets.reloaded.connect(_rebuild_art)
	sync_from_state()


func _part(id: String, at: Vector2, parent: Node2D) -> Sprite2D:
	var holder := Node2D.new()
	holder.position = at
	parent.add_child(holder)
	var s := Sprite2D.new()
	s.set_meta("asset", id)
	holder.add_child(s)
	Assets.apply_to_sprite(s, id)
	return s


func _build_shadow() -> void:
	for c in shadow.get_children():
		c.queue_free()
	var holder := Node2D.new()
	holder.name = "ShadowBody"
	shadow.add_child(holder)
	for src in [hull] + wheels:
		var s := Sprite2D.new()
		s.texture = src.texture
		s.centered = false
		s.scale = src.scale
		s.position = src.position
		s.material = LightKit.shadow_material()
		var h := Node2D.new()
		h.position = src.get_parent().position
		h.add_child(s)
		h.set_meta("src", src)
		holder.add_child(h)
	holder.modulate = Color(1, 1, 1, 0.38)
	housing_shadow = Node2D.new()
	housing_shadow.name = "RingShadow"
	housing_shadow.modulate = Color(1, 1, 1, 0.3)
	shadow.add_child(housing_shadow)
	for src in [housing] + guns:
		var s2 := Sprite2D.new()
		s2.texture = src.texture
		s2.centered = false
		s2.scale = src.scale
		s2.position = src.position
		s2.material = LightKit.shadow_material()
		var h2 := Node2D.new()
		h2.position = src.get_parent().position if src != housing else Vector2.ZERO
		h2.scale = src.get_parent().scale if src != housing else Vector2.ONE
		h2.add_child(s2)
		housing_shadow.add_child(h2)


func _rebuild_art() -> void:
	for s in [hull, housing] + wheels + guns:
		Assets.apply_to_sprite(s, str(s.get_meta("asset")))
	_build_shadow()


func sync_from_state() -> void:
	var m := Session.mech()
	global_position = Content.v2(m["pos"])
	body.rotation = float(m["heading"])
	if _cs:
		_cs.rotation = body.rotation


func _physics_process(delta: float) -> void:
	if not Session.running:
		return
	var v := Session.mech_velocity(delta)
	_cs.rotation = float(Session.mech()["heading"])
	velocity = v
	move_and_slide()
	Session.commit_mech(global_position, get_real_velocity())


func _process(delta: float) -> void:
	if not Session.running:
		return
	var m := Session.mech()
	var tth := Session.tun("thermal")
	var tmf := Session.tun("mech")
	body.rotation = float(m["heading"])
	var speed := float(m["speed"])
	var max_s := float(tmf.get("max_speed", 460.0))
	var frac := clampf(absf(speed) / max_s, 0.0, 1.0)
	var driving := Session.mode() == "mech" and Session.engine_on()
	# Front wheels steer with the input; all wheels roll (tread scroll via offset).
	_steer = lerpf(_steer, (Session.drive_turn if driving else 0.0) * 0.5, 1.0 - exp(-10.0 * delta))
	for i in 2:
		wheels[i].get_parent().rotation = _steer
	# Mass: squat on throttle, dive under braking, roll in corners (visual only).
	var acc := (speed - _last_speed) / maxf(delta, 0.0001)
	_last_speed = speed
	_accel_s = lerpf(_accel_s, acc, 1.0 - exp(-8.0 * delta))
	var squat := clampf(_accel_s * float(tmf.get("feel_squat", 0.02)), -7.0, 7.0)
	var lat := float(m.get("slip", 0.0))
	_lean = lerpf(_lean, (Session.drive_turn if driving else 0.0) * frac * float(tmf.get("feel_lean", 0.05)), 1.0 - exp(-5.0 * delta))
	_roll = lerpf(_roll, _lean * 60.0, 1.0 - exp(-6.0 * delta))
	chassis.position = Vector2(-_roll, squat)
	hull.get_parent().scale = Vector2(1.0 - absf(_lean) * 0.4, 1.0)
	var engine := str(m["engine"])
	if engine == "running" and absf(speed) < 4.0:
		chassis.position += Vector2(sin(Time.get_ticks_msec() * 0.06) * 0.6, 0)   # idle shake
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 2.4)
		chassis.position += Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 5.0 * _shake
	# Skid marks + tyre dust when the tyres slide or spin up.
	_skid_t -= delta
	var skid := lat > float(tmf.get("skid_slip", 120.0)) or (absf(_accel_s) > 520.0 and frac > 0.05)
	if skid and _skid_t <= 0.0 and world_ref:
		_skid_t = 0.045
		for i in [2, 3]:
			world_ref.add_skid(wheels[i].get_parent().global_position, body.rotation, clampf(lat / 400.0, 0.3, 1.0))
	dust.emitting = frac > 0.12 or skid
	dust.global_position = global_position + Vector2(-sin(body.rotation), cos(body.rotation)) * 90.0
	dust.amount = 18 if skid else 10
	# Heat glow and steam at the bonnet by heat band; headlights in shade/storm.
	var heat := float(m["heat"])
	var warn := float(tth.get("warn_temp", 98.0))
	var crit := float(tth.get("critical_temp", 115.0))
	var glow_f := clampf((heat - (warn - 20.0)) / (crit - warn + 20.0), 0.0, 1.0)
	heat_glow.energy = glow_f * (0.55 + 0.15 * sin(Time.get_ticks_msec() * 0.008))
	steam.emitting = heat >= warn or engine == "shutdown"
	var dim := clampf(Session.storm_here * 1.2 + (0.6 if world_ref and world_ref.cover_amount() > 0.5 else 0.0), 0.0, 1.0)
	for hl in headlights:
		hl.energy = move_toward(hl.energy, (0.65 * dim) if engine == "running" else 0.0, delta * 2.0)
	# Gun ring: rotates toward the aim; recoil springs settle.
	_step_recoil(delta)
	housing_holder.rotation = Session.housing_angle + _h_rot
	housing_holder.position = (RING_POS + chassis.position).rotated(body.rotation) + Vector2(0, _h_off).rotated(Session.housing_angle)
	for i in 2:
		gun_holders[i].position = GUN_MOUNTS[i] + Vector2(0, _gun_off[i])
		flash_lights[i].energy = move_toward(flash_lights[i].energy, 0.0, delta * 11.0)
		if flashes[i].visible:
			flashes[i].modulate.a -= delta * 7.0
			if flashes[i].modulate.a <= 0.0:
				flashes[i].visible = false
	# Damage feedback: coolant leak (grille < 35 %), smoke (body < 45 %), hit flash.
	leak.emitting = float(m["radiator"]) < 0.35
	var integ := float(m["integrity"]) / maxf(Session.max_integrity(), 1.0)
	smoke.emitting = integ < 0.45
	smoke.global_position = global_position + Vector2(0, -90).rotated(body.rotation)
	_flash = move_toward(_flash, 0.0, delta * 3.0)
	body.modulate = Color(1, 1, 1).lerp(Color(1.9, 0.55, 0.5), _flash)
	shadow.global_position = global_position + SHADOW_OFFSET
	if housing_shadow:
		housing_shadow.rotation = housing_holder.rotation
		housing_shadow.position = housing_holder.position
	var sb: Node2D = shadow.get_child(0) if shadow.get_child_count() > 0 else null
	if sb:
		sb.rotation = body.rotation
		for h in sb.get_children():
			var src: Sprite2D = h.get_meta("src")
			h.position = src.get_parent().position + chassis.position
			h.rotation = src.get_parent().rotation


func _on_mech_event(ev: String) -> void:
	match ev:
		"shutdown":
			_shake = 1.0
		"repaired":
			_shake = 0.3


func _fire_kick(i: int) -> void:
	var rc: Dictionary = Session.tun("combat").get("recoil", {})
	_gun_vel[i] += float(rc.get("gun_kick", 22.0)) * 10.0
	_h_vel += float(rc.get("housing_kick", 7.0)) * 10.0
	_h_rot_vel += (-1.0 if i == 0 else 1.0) * float(rc.get("housing_rock", 0.05)) * 14.0
	flashes[i].visible = true
	flashes[i].modulate.a = 1.0
	flashes[i].rotation = randf_range(-0.25, 0.25)
	var sc := randf_range(0.55, 0.8)
	flashes[i].scale = Vector2(sc, sc * randf_range(0.9, 1.3))
	flash_lights[i].energy = 1.1
	var parent := get_parent()
	var sm := FxKit.puff(Color(0.32, 0.28, 0.24, 0.5), 5)
	parent.add_child(sm)
	sm.global_position = gun_holders[i].global_position
	sm.direction = Drive.forward(housing_holder.rotation) * -1.0
	sm.emitting = true
	sm.finished.connect(sm.queue_free)
	var blast := FxKit.ground_blast()
	parent.add_child(blast)
	blast.global_position = gun_holders[i].global_position + Drive.forward(housing_holder.rotation) * 90.0
	blast.direction = Drive.forward(housing_holder.rotation)
	blast.emitting = true
	blast.finished.connect(blast.queue_free)


func _step_recoil(delta: float) -> void:
	var rc: Dictionary = Session.tun("combat").get("recoil", {})
	var k := float(rc.get("spring", 160.0))
	var c := float(rc.get("damping", 15.0))
	var steps := 3
	var h := delta / steps
	for _s in steps:
		for i in 2:
			_gun_vel[i] += (-k * _gun_off[i] - c * _gun_vel[i]) * h
			_gun_off[i] = clampf(_gun_off[i] + _gun_vel[i] * h, -4.0, 18.0)
		_h_vel += (-k * 0.45 * _h_off - c * 0.55 * _h_vel) * h
		_h_off = clampf(_h_off + _h_vel * h, -3.0, 9.0)
		_h_rot_vel += (-k * 0.5 * _h_rot - c * 0.5 * _h_rot_vel) * h
		_h_rot = clampf(_h_rot + _h_rot_vel * h, -0.12, 0.12)


func recoil_state() -> Dictionary:
	return {"gun": _gun_off.duplicate(), "housing": _h_off, "rock": _h_rot}


func on_combat(kind: String, data: Dictionary) -> void:
	match kind:
		"player_hit":
			_flash = 0.8
			_shake = maxf(_shake, 0.5 if str(data.get("kind", "")) != "structure" else 0.35)
			if world_ref and world_ref.camera:
				world_ref.camera.add_shake(0.35, 0.6)
		"collision":
			var st := float(data.get("strength", 0.0))
			_shake = maxf(_shake, 0.3 + st)
			if world_ref and world_ref.camera:
				world_ref.camera.add_shake(0.2 + st * 0.6, 0.7)
			var sp := FxKit.sparks()
			get_parent().add_child(sp)
			sp.global_position = global_position + Drive.forward(body.rotation) * 110.0
			sp.emitting = true
			sp.finished.connect(sp.queue_free)
		"muzzle":
			if str(data.get("owner", "")) == "player":
				_fire_kick(int(data.get("barrel", 0)) % 2)
				if world_ref and world_ref.camera:
					var rc: Dictionary = Session.tun("combat").get("recoil", {})
					world_ref.camera.add_shake(float(rc.get("shake", 0.16)) * 0.8, float(rc.get("shake_max", 0.45)))
