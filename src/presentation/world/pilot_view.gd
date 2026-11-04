class_name PilotView
extends CharacterBody2D
## The suited pilot on foot. Hidden while inside the mech. Faces its movement
## direction (top-down art faces "up"); walk motion is procedural: small
## shoulder sway and scale pulse, plus a world-aligned contact shadow.

var holder: Node2D
var sprite: Sprite2D
var shadow: Node2D
var shadow_sprite: Sprite2D
var _t := 0.0
var _facing := 0.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 13.0
	cs.shape = c
	add_child(cs)
	shadow = Node2D.new()
	shadow.top_level = true
	shadow.z_index = -2
	add_child(shadow)
	shadow_sprite = Sprite2D.new()
	shadow.add_child(shadow_sprite)
	holder = Node2D.new()
	add_child(holder)
	sprite = Sprite2D.new()
	holder.add_child(sprite)
	holder.material = LightKit.rotating_light_material()
	sprite.use_parent_material = true
	_apply_art()
	Assets.reloaded.connect(_apply_art)
	sync_from_state()


func _apply_art() -> void:
	Assets.apply_to_sprite(sprite, "pilot.suit")
	shadow_sprite.texture = sprite.texture
	shadow_sprite.centered = false
	shadow_sprite.scale = sprite.scale
	shadow_sprite.position = sprite.position
	shadow_sprite.material = LightKit.shadow_material()
	shadow.modulate = Color(1, 1, 1, 0.30)


func sync_from_state() -> void:
	global_position = Session.pilot_pos()
	_facing = float(Session.pilot()["facing"])
	visible = Session.mode() != "mech"


func _physics_process(_delta: float) -> void:
	if not Session.running or Session.mode() != "foot":
		return
	velocity = Session.pilot_velocity()
	move_and_slide()
	var v := get_real_velocity()
	if v.length() > 5.0:
		_facing = lerp_angle(_facing, atan2(v.x, -v.y), 0.25)
	Session.commit_pilot(global_position, _facing)


func _process(delta: float) -> void:
	if not Session.running:
		return
	var md := Session.mode()
	visible = md != "mech"
	if md == "mech":
		global_position = Session.mech_pos()
		return
	var moving := get_real_velocity().length() > 5.0 and md == "foot"
	if moving:
		_t += delta * 10.0
	holder.rotation = _facing + (sin(_t) * 0.07 if moving else 0.0)
	var pulse := 1.0 + (absf(sin(_t)) * 0.035 if moving else 0.0)
	holder.scale = Vector2(pulse, pulse)
	if md == "collapsed":
		holder.rotation = _facing + 1.3
		holder.modulate = Color(1.2, 0.75, 0.6)
	else:
		var strain := float(Session.pilot()["strain"])
		holder.modulate = Color(1, 1, 1).lerp(Color(1.4, 0.7, 0.55), strain * (0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.012)))
	shadow.global_position = global_position + Vector2(6, 8)
	shadow.rotation = holder.rotation
	shadow.scale = holder.scale
