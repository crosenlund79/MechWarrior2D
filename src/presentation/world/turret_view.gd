class_name TurretView
extends Node2D
## Southern Junkers perimeter turret: static reinforced mount + rotating gun
## housing (Session.state.turrets[id].angle), red laser telegraph during wind-up,
## recoil on firing, damage flash, and a smoking, sparking wreck when destroyed.
## Collision footprint comes from tuning (hit_radius), never from art.

var id := ""
var def: Dictionary
var base: Sprite2D
var gun_holder: Node2D
var gun: Sprite2D
var wreck: Sprite2D
var laser: Line2D
var smoke: CPUParticles2D
var glow: PointLight2D
var _kick := 0.0
var _kick_v := 0.0
var _flash := 0.0
var _spark_t := 1.0


func setup(d: Dictionary) -> void:
	def = d
	id = str(d["id"])
	name = "Turret_" + id
	position = Content.v2(d["pos"])


func _ready() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = float(Session.tun("turret").get("hit_radius", 40.0)) - 4.0
	cs.shape = c
	body.add_child(cs)
	add_child(body)
	var sh := Node2D.new()
	sh.position = Vector2(10, 13)
	sh.modulate = Color(1, 1, 1, 0.34)
	sh.z_index = -3
	sh.z_as_relative = false
	add_child(sh)
	base = _sprite("junker.turret_base", self)
	var ss := Sprite2D.new()
	ss.texture = base.texture
	ss.centered = false
	ss.scale = base.scale
	ss.position = base.position
	ss.material = LightKit.shadow_material()
	sh.add_child(ss)
	wreck = _sprite("junker.turret_wreck", self)
	gun_holder = Node2D.new()
	gun_holder.material = LightKit.rotating_light_material()
	add_child(gun_holder)
	var gh := Node2D.new()
	gun_holder.add_child(gh)
	gun = _sprite("junker.turret_gun", gh)
	gun.use_parent_material = true
	laser = Line2D.new()
	laser.width = 2.0
	laser.default_color = Color(1.0, 0.25, 0.12, 0.0)
	laser.top_level = true
	laser.z_index = 22
	add_child(laser)
	smoke = FxKit.damage_smoke()
	add_child(smoke)
	glow = LightKit.glow(Color(1.0, 0.35, 0.15), 0.5, 0.0)
	glow.position = Vector2(0, -50)
	gh.add_child(glow)
	Session.combat_event.connect(_on_combat)


func _sprite(asset: String, parent: Node) -> Sprite2D:
	var h := Node2D.new()
	parent.add_child(h)
	var s := Sprite2D.new()
	h.add_child(s)
	Assets.apply_to_sprite(s, asset)
	return s


func _process(delta: float) -> void:
	if not Session.running:
		return
	var t: Dictionary = Session.state.get("turrets", {}).get(id, {})
	if t.is_empty():
		return
	var dead := bool(t["destroyed"])
	wreck.get_parent().visible = dead
	base.get_parent().visible = not dead
	gun_holder.visible = not dead
	smoke.emitting = dead and not bool(t.get("salvaged", false)) or (not dead and float(t["hp"]) < float(Session.tun("turret").get("hp", 38.0)) * 0.4)
	smoke.global_position = global_position + Vector2(6, -8)
	_kick_v += (-150.0 * _kick - 13.0 * _kick_v) * delta
	_kick += _kick_v * delta
	gun_holder.rotation = float(t["angle"])
	gun.get_parent().position = Vector2(0, clampf(_kick, -3.0, 16.0))
	_flash = move_toward(_flash, 0.0, delta * 3.0)
	gun_holder.modulate = Color(1, 1, 1).lerp(Color(1.9, 0.6, 0.5), _flash)
	var v: Dictionary = Session.turret_view.get(id, {})
	var w := float(v.get("windup", 0.0))
	if w > 0.0 and not dead:
		var tt := Session.tun("turret")
		var m := Turret.muzzle(def, t, tt)
		var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.035)
		laser.points = PackedVector2Array([m, m + Drive.forward(float(t["angle"])) * float(tt["weapon"]["range"]) * 0.85])
		laser.default_color = Color(1.0, 0.25, 0.12, (0.2 + 0.55 * w) * pulse)
		laser.width = 1.5 + 2.5 * w
		glow.energy = 0.3 + 1.0 * w
	else:
		laser.default_color.a = move_toward(laser.default_color.a, 0.0, delta * 4.0)
		glow.energy = move_toward(glow.energy, 0.0, delta * 4.0)
	if dead and not bool(t.get("salvaged", false)):
		_spark_t -= delta
		if _spark_t <= 0.0:
			_spark_t = randf_range(1.2, 3.5)
			var sp := FxKit.sparks()
			sp.amount = 6
			get_parent().add_child(sp)
			sp.global_position = global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
			sp.emitting = true
			sp.finished.connect(sp.queue_free)


func _on_combat(kind: String, data: Dictionary) -> void:
	if kind == "muzzle" and str(data.get("owner", "")) == "turret" and str(data.get("id", "")) == id:
		_kick_v += 260.0
		var p := FxKit.puff(Color(1.0, 0.75, 0.4, 0.8), 6)
		p.lifetime = 0.25
		get_parent().add_child(p)
		p.global_position = data["pos"]
		p.emitting = true
		p.finished.connect(p.queue_free)
	elif kind == "impact" and str(data.get("target", "")) == "turret:" + id:
		_flash = 0.8
		_kick_v -= 120.0
	elif kind == "turret_destroyed" and str(data.get("id", "")) == id:
		var boom := FxKit.puff(Color(0.25, 0.2, 0.16, 0.75), 22)
		boom.scale_amount_max = 4.0
		get_parent().add_child(boom)
		boom.global_position = global_position
		boom.emitting = true
		boom.finished.connect(boom.queue_free)
