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
var _stride := 0.0
var _shutter_t := 1.0
var _shake := 0.0


func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
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
	_build_shadow()
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


func _rebuild_art() -> void:
	for s in [hull, leg_l, leg_r, radiator, radiator_damage, shutters]:
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
	hull.get_parent().rotation = sin(_stride * 2.0) * 0.018 * frac
	hull.get_parent().position = Vector2(sin(_stride) * 2.0 * frac, 0)
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
	dust.emitting = frac > 0.15
	dust.global_position = global_position + Vector2(-sin(body.rotation), cos(body.rotation)) * 60.0
	# Shadow follows the mech but keeps a fixed world-space offset (sun upper-left).
	shadow.global_position = global_position + SHADOW_OFFSET
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
