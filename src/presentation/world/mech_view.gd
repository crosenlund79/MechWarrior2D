class_name MechView
extends CharacterBody2D
## Draws and moves the player's mech. Movement intent → Session.mech_velocity(),
## physics → move_and_slide(), result → Session.commit_mech(). All state lives in
## Session.state.mech; this node can be rebuilt at any time.
##
## Top-down construction (facing "up" at rotation 0): hull in the centre, a leg
## on each side that strides forward/back, radiator bank at the rear with armour
## shutters that slide over it, and a runtime cast shadow offset toward the
## lower right (sun from the upper left) that does NOT rotate with the mech.

const SHADOW_OFFSET := Vector2(16, 20)

var body: Node2D          # rotates with heading
var hull: Sprite2D
var leg_l: Sprite2D
var leg_r: Sprite2D
var radiator: Sprite2D
var radiator_damage: Sprite2D
var shutters: Sprite2D
var shadow: Node2D        # world-aligned shadow (does not rotate the offset)
var heat_glow: PointLight2D
var steam: CPUParticles2D
var dust: CPUParticles2D
var housing_holder: Node2D   # rotates with Session.housing_angle (independent of the legs)
var housing: Sprite2D
var guns: Array[Sprite2D] = []
var gun_holders: Array[Node2D] = []
var housing_shadow: Node2D
## Recoil (visual only): each gun is a damped spring along its barrel axis; the
## whole housing gets a backward jolt + a rocking twist that settle with inertia.
## Springs integrate continuously, so rapid fire stacks instead of snapping.
var _gun_off := [0.0, 0.0]
var _gun_vel := [0.0, 0.0]
var _bolt_off := [0.0, 0.0]
var _bolt_vel := [0.0, 0.0]
var _h_off := 0.0
var _h_vel := 0.0
var _h_rot := 0.0
var _h_rot_vel := 0.0
var bolts: Array[Polygon2D] = []
var flash_lights: Array[PointLight2D] = []
var flashes: Array[Sprite2D] = []
var world_ref: Node
const GUN_MOUNTS := [Vector2(-92, -10), Vector2(92, -10)]
var leak: CPUParticles2D
var smoke: CPUParticles2D
var _flash := 0.0
var _stride := 0.0
var _last_speed := 0.0
var _accel_s := 0.0     # smoothed acceleration (px/s²) for squat/dip
var _lean := 0.0
var _shutter_t := 1.0
var _shake := 0.0


func _ready() -> void:
	collision_layer = 4   # mechs
	collision_mask = 1 | 4
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = float(Session.tun("mech").get("collision_radius", 74.0))
	cs.shape = circle
	add_child(cs)
	shadow = Node2D.new()
	shadow.name = "Shadow"
	shadow.top_level = true
	shadow.z_index = -2
	add_child(shadow)
	body = Node2D.new()
	body.name = "Body"
	add_child(body)
	leg_l = _part("mech.leg", Vector2(-98, 0), body)
	leg_r = _part("mech.leg", Vector2(98, 0), body)
	leg_r.get_parent().scale.x = -1
	hull = _part("mech.hull", Vector2.ZERO, body)
	radiator = _part("mech.radiator", Vector2(0, 92), body)
	radiator_damage = _part("mech.radiator_damage", Vector2(0, 92), body)
	shutters = _part("mech.shutters", Vector2(0, 92), body)
	housing_holder = Node2D.new()
	housing_holder.name = "Housing"
	add_child(housing_holder)
	housing_holder.material = LightKit.rotating_light_material()
	var hh := Node2D.new()
	housing_holder.add_child(hh)
	housing = Sprite2D.new()
	housing.set_meta("asset", "mech.housing")
	housing.use_parent_material = true
	hh.add_child(housing)
	Assets.apply_to_sprite(housing, "mech.housing")
	for i in 2:
		var gh := Node2D.new()
		gh.position = GUN_MOUNTS[i]
		if i == 1:
			gh.scale.x = -1
		housing_holder.add_child(gh)
		var g := Sprite2D.new()
		g.set_meta("asset", "mech.twin_gun")
		g.use_parent_material = true
		gh.add_child(g)
		Assets.apply_to_sprite(g, "mech.twin_gun")
		guns.append(g)
		gun_holders.append(gh)
		# breech bolt that slams back on every shot
		var bolt := Polygon2D.new()
		bolt.polygon = PackedVector2Array([Vector2(-7, 18), Vector2(7, 18), Vector2(7, 40), Vector2(-7, 40)])
		bolt.color = Color(0.2, 0.17, 0.14)
		gh.add_child(bolt)
		var hl := Line2D.new()
		hl.points = PackedVector2Array([Vector2(-5, 21), Vector2(-5, 37)])
		hl.width = 2.0
		hl.default_color = Color(0.75, 0.68, 0.55, 0.7)
		bolt.add_child(hl)
		bolts.append(bolt)
		# muzzle flash (sprite + light), hidden until a shot
		var fl := Sprite2D.new()
		var ft := "res://assets/fx/muzzle_flash.png"
		fl.texture = load(ft) if ResourceLoader.exists(ft) else FxKit.dot()
		fl.position = Vector2(0, -112)
		fl.visible = false
		fl.z_index = 3
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		fl.material = add
		gh.add_child(fl)
		flashes.append(fl)
		var lt := LightKit.glow(Color(1.0, 0.72, 0.35), 1.25, 0.0)
		lt.position = Vector2(0, -110)
		gh.add_child(lt)
		flash_lights.append(lt)
	_build_shadow()
	leak = FxKit.coolant_leak()
	leak.position = Vector2(0, 110)
	body.add_child(leak)
	smoke = FxKit.damage_smoke()
	add_child(smoke)
	heat_glow = LightKit.glow(Color(1.0, 0.45, 0.2), 1.3, 0.0)
	heat_glow.position = Vector2(0, 96)
	body.add_child(heat_glow)
	steam = FxKit.steam()
	steam.position = Vector2(0, 100)
	body.add_child(steam)
	dust = FxKit.footfall_dust()
	add_child(dust)
	body.material = LightKit.rotating_light_material()
	for s in [hull, leg_l, leg_r, radiator, radiator_damage, shutters]:
		s.use_parent_material = true
	Session.mech_event.connect(_on_mech_event)
	Session.combat_event.connect(on_combat)
	Assets.reloaded.connect(_rebuild_art)
	sync_from_state()


## Each art part sits in its own holder so the fitted sprite offset (pivot) and
## the placement on the mech stay independent.
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
	for src in [leg_l, leg_r, hull, radiator]:
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
	holder.modulate = Color(1, 1, 1, 0.36)
	# The housing (and its guns) casts its own shadow, rotating with the housing.
	housing_shadow = Node2D.new()
	housing_shadow.name = "HousingShadow"
	housing_shadow.modulate = Color(1, 1, 1, 0.36)
	shadow.add_child(housing_shadow)
	for src in [housing] + guns:
		var s2 := Sprite2D.new()
		s2.texture = src.texture
		s2.centered = false
		s2.scale = src.scale
		s2.position = src.position
		s2.material = LightKit.shadow_material()
		var h2 := Node2D.new()
		h2.position = src.get_parent().position
		h2.scale = src.get_parent().scale
		h2.add_child(s2)
		housing_shadow.add_child(h2)


func _rebuild_art() -> void:
	for s in [hull, leg_l, leg_r, radiator, radiator_damage, shutters, housing] + guns:
		Assets.apply_to_sprite(s, str(s.get_meta("asset")))
	_build_shadow()


func sync_from_state() -> void:
	var m := Session.mech()
	global_position = Content.v2(m["pos"])
	body.rotation = float(m["heading"])
	_shutter_t = 0.0 if m["shutters_open"] else 1.0


func _physics_process(delta: float) -> void:
	if not Session.running:
		return
	var v := Session.mech_velocity(delta)
	velocity = v
	move_and_slide()
	Session.commit_mech(global_position, get_real_velocity())


func _process(delta: float) -> void:
	if not Session.running:
		return
	var m := Session.mech()
	var tth := Session.tun("thermal")
	body.rotation = float(m["heading"])
	var speed := float(m["speed"])
	var max_s := float(Session.tun("mech").get("max_speed", 150.0))
	var frac := clampf(absf(speed) / max_s, 0.0, 1.0)
	# Stride: legs swing forward/back in opposite phase; the hull sways slightly.
	_stride += delta * (2.0 + 5.5 * frac) * signf(speed if absf(speed) > 1.0 else 0.0)
	var swing := sin(_stride) * 22.0 * minf(1.0, frac * 3.0)
	leg_l.get_parent().position = Vector2(-98, -swing)
	leg_r.get_parent().position = Vector2(98, swing)
	# Mass: the hull squats back when accelerating, dips forward when braking and
	# leans into turns (visual only; the chassis physics are unchanged).
	var tmf := Session.tun("mech")
	var acc := (speed - _last_speed) / maxf(delta, 0.0001)
	_last_speed = speed
	_accel_s = lerpf(_accel_s, acc, 1.0 - exp(-8.0 * delta))
	var squat := clampf(_accel_s * float(tmf.get("feel_squat", 0.035)), -9.0, 9.0)
	var turning := Session.drive_turn if Session.mode() == "mech" and Session.engine_on() else 0.0
	_lean = lerpf(_lean, turning * frac * float(tmf.get("feel_lean", 0.06)), 1.0 - exp(-5.0 * delta))
	hull.get_parent().rotation = sin(_stride * 2.0) * 0.018 * frac + _lean
	hull.get_parent().position = Vector2(sin(_stride) * 2.0 * frac, squat)
	var engine := str(m["engine"])
	if engine == "running" and absf(speed) < 2.0:
		hull.get_parent().position += Vector2(sin(Time.get_ticks_msec() * 0.045) * 0.5, 0)  # idle shudder
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 2.0)
		hull.get_parent().position += Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 4.0 * _shake
	# Shutters slide over the radiator.
	_shutter_t = move_toward(_shutter_t, 0.0 if m["shutters_open"] else 1.0, delta * 3.0)
	shutters.get_parent().scale = Vector2(1.0, lerpf(0.12, 1.0, _shutter_t))
	shutters.get_parent().position = Vector2(0, lerpf(124, 92, _shutter_t))
	shutters.modulate.a = lerpf(0.0, 1.0, minf(1.0, _shutter_t * 4.0))
	radiator_damage.modulate.a = clampf(1.0 - float(m["radiator"]) * 1.15, 0.0, 1.0)
	# Heat glow and steam by heat band.
	var heat := float(m["heat"])
	var warn := float(tth.get("warn_temp", 98.0))
	var crit := float(tth.get("critical_temp", 115.0))
	var glow_f := clampf((heat - (warn - 20.0)) / (crit - warn + 20.0), 0.0, 1.0)
	heat_glow.energy = glow_f * (0.55 + 0.15 * sin(Time.get_ticks_msec() * 0.008))
	radiator.modulate = Color(1, 1, 1).lerp(Color(1.35, 0.8, 0.62), glow_f * 0.6)
	steam.emitting = heat >= warn or engine == "shutdown"
	# Turret: rotates toward the aim point around its mount on the deck.
	# Upper housing: rotates independently toward the aim; recoil springs settle.
	_step_recoil(delta)
	housing_holder.rotation = Session.housing_angle + _h_rot
	housing_holder.position = hull.get_parent().position.rotated(body.rotation) + Vector2(0, _h_off).rotated(Session.housing_angle)
	for i in 2:
		gun_holders[i].position = GUN_MOUNTS[i] + Vector2(0, _gun_off[i])
		bolts[i].position = Vector2(0, _bolt_off[i])
		flash_lights[i].energy = move_toward(flash_lights[i].energy, 0.0, delta * 11.0)
		if flashes[i].visible:
			flashes[i].modulate.a -= delta * 7.0
			if flashes[i].modulate.a <= 0.0:
				flashes[i].visible = false
	# Damage feedback: coolant leak (cooling < 35 %), smoke (integrity < 45 %), hit flash.
	leak.emitting = float(m["radiator"]) < 0.35
	var integ := float(m["integrity"]) / float(Session.tun("mech").get("integrity", 100.0))
	smoke.emitting = integ < 0.45
	smoke.global_position = global_position + Vector2(-20, -30).rotated(body.rotation)
	_flash = move_toward(_flash, 0.0, delta * 3.0)
	body.modulate = Color(1, 1, 1).lerp(Color(1.9, 0.55, 0.5), _flash)
	dust.emitting = frac > 0.15
	dust.global_position = global_position + Vector2(-sin(body.rotation), cos(body.rotation)) * 60.0
	# Shadow follows the mech but keeps a fixed world-space offset (sun upper-left).
	shadow.global_position = global_position + SHADOW_OFFSET
	if housing_shadow:
		housing_shadow.rotation = housing_holder.rotation
	var sb: Node2D = shadow.get_child(0) if shadow.get_child_count() > 0 else null
	if sb:
		sb.rotation = body.rotation
		for h in sb.get_children():
			var src: Sprite2D = h.get_meta("src")
			h.position = src.get_parent().position
			h.rotation = src.get_parent().rotation


func _on_mech_event(ev: String) -> void:
	match ev:
		"shutdown":
			_shake = 1.0
		"repaired":
			_shake = 0.3


func _fire_kick(i: int) -> void:
	var rc: Dictionary = Session.tun("combat").get("recoil", {})
	_gun_vel[i] += float(rc.get("gun_kick", 22.0)) * 14.0
	_bolt_vel[i] += float(rc.get("gun_kick", 22.0)) * 22.0
	_h_vel += float(rc.get("housing_kick", 7.0)) * 14.0
	_h_rot_vel += (-1.0 if i == 0 else 1.0) * float(rc.get("housing_rock", 0.05)) * 14.0
	flashes[i].visible = true
	flashes[i].modulate.a = 1.0
	flashes[i].rotation = randf_range(-0.25, 0.25)
	var sc := randf_range(1.1, 1.45)
	flashes[i].scale = Vector2(sc, sc * randf_range(0.9, 1.3))
	flash_lights[i].energy = 1.15
	# receiver exhaust smoke + sand blown off the ground around the mech
	var parent := get_parent()
	var sm := FxKit.puff(Color(0.32, 0.28, 0.24, 0.55), 6)
	parent.add_child(sm)
	sm.global_position = gun_holders[i].global_position + Vector2(0, 30).rotated(housing_holder.rotation)
	sm.direction = Drive.forward(housing_holder.rotation) * -1.0
	sm.emitting = true
	sm.finished.connect(sm.queue_free)
	var dust := FxKit.ground_blast()
	parent.add_child(dust)
	dust.global_position = gun_holders[i].global_position + Drive.forward(housing_holder.rotation) * 120.0
	dust.direction = Drive.forward(housing_holder.rotation)
	dust.emitting = true
	dust.finished.connect(dust.queue_free)


func _step_recoil(delta: float) -> void:
	var rc: Dictionary = Session.tun("combat").get("recoil", {})
	var k := float(rc.get("spring", 160.0))
	var c := float(rc.get("damping", 15.0))
	var steps := 3
	var h := delta / steps
	for _s in steps:
		for i in 2:
			_gun_vel[i] += (-k * _gun_off[i] - c * _gun_vel[i]) * h
			_gun_off[i] = clampf(_gun_off[i] + _gun_vel[i] * h, -6.0, 30.0)
			_bolt_vel[i] += (-k * 0.7 * _bolt_off[i] - c * 0.9 * _bolt_vel[i]) * h
			_bolt_off[i] = clampf(_bolt_off[i] + _bolt_vel[i] * h, -3.0, 22.0)
		# the housing is heavier: softer spring, slower settle, small overshoot
		_h_vel += (-k * 0.45 * _h_off - c * 0.55 * _h_vel) * h
		_h_off = clampf(_h_off + _h_vel * h, -4.0, 14.0)
		_h_rot_vel += (-k * 0.5 * _h_rot - c * 0.5 * _h_rot_vel) * h
		_h_rot = clampf(_h_rot + _h_rot_vel * h, -0.12, 0.12)


func recoil_state() -> Dictionary:
	return {"gun": _gun_off.duplicate(), "housing": _h_off, "rock": _h_rot}


func on_combat(kind: String, data: Dictionary) -> void:
	match kind:
		"player_hit":
			_flash = 0.8
			_shake = maxf(_shake, 0.35)
		"muzzle":
			if str(data.get("owner", "")) == "player":
				_fire_kick(int(data.get("barrel", 0)) % 2)
				if world_ref and world_ref.camera:
					var rc: Dictionary = Session.tun("combat").get("recoil", {})
					world_ref.camera.add_shake(float(rc.get("shake", 0.16)), float(rc.get("shake_max", 0.45)))
