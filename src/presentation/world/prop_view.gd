class_name PropView
extends Node2D
## One static world object from the location data: sprite (fitted from the
## manifest), optional collision footprint (from location data, never from art),
## optional runtime cast shadow and, for overhead structures, occlusion fade.

const FADE_ALPHA := 0.42

var def: Dictionary
var sprite: Sprite2D
var shadow: Node2D
var occlude := false
var _box := Rect2()
var anim := ""
var _t := 0.0
var _door_open := Vector2.ZERO
var _door_f := 0.0
var lamp: PointLight2D
var _hum: AudioStreamPlayer2D


func setup(d: Dictionary) -> void:
	def = d
	name = str(d.get("id", "prop"))
	position = Content.v2(d["pos"])
	var rot := deg_to_rad(float(d.get("rot", 0.0)))
	occlude = bool(d.get("occlude", false))
	var asset := str(d["asset"])
	var height := float(AssetCatalog.entry(asset).get("height", 0.0))
	if height > 0.0:
		shadow = Node2D.new()
		shadow.name = "CastShadow"
		shadow.z_as_relative = false
		shadow.z_index = -3 if d.get("layer", "low") != "overhead" else 8
		shadow.position = Vector2(0.45, 0.55) * height
		shadow.rotation = rot
		shadow.modulate = Color(1, 1, 1, 0.34 if d.get("layer", "low") != "overhead" else 0.40)
		add_child(shadow)
		var ss := Sprite2D.new()
		ss.set_meta("asset", asset)
		shadow.add_child(ss)
		Assets.apply_to_sprite(ss, asset)
		ss.material = LightKit.shadow_material()
	var holder := Node2D.new()
	holder.rotation = rot
	add_child(holder)
	sprite = Sprite2D.new()
	sprite.set_meta("asset", asset)
	holder.add_child(sprite)
	Assets.apply_to_sprite(sprite, asset)
	if str(AssetCatalog.entry(asset).get("anim", "")) == "flutter":
		sprite.material = flutter_material()
	var disp := Assets.display_size(asset)
	_box = Rect2(-disp * Assets.pivot(asset), disp)
	if d.has("collision"):
		_add_collision(d["collision"], rot)
	anim = str(d.get("anim", ""))
	_t = position.x * 0.013 + position.y * 0.007
	_door_open = Content.v2(d.get("door_open", [0, 0]))
	if anim == "generator":
		var smoke := FxKit.damage_smoke()
		smoke.emitting = true
		smoke.amount = 10
		smoke.position = Vector2(30, 22)
		add_child(smoke)
		var g := LightKit.glow(Color(0.6, 1.0, 0.65), 0.25, 0.4)
		g.position = Vector2(-77, 26)
		add_child(g)
		_hum = Audio.positional_loop(self, "sfx.generator_hum", -2.0, 1500.0, 1.6)
	if bool(d.get("light", false)):
		lamp = LightKit.glow(Color(1.0, 0.8, 0.5), 2.6, 0.85)
		add_child(lamp)
		_hum = Audio.positional_loop(self, "sfx.electric_hum", -14.0, 260.0, 2.0)
	Assets.reloaded.connect(_on_reload)


const FLUTTER_SHADER := """
shader_type canvas_item;
// Top-down cloth flutter: the free end (UV.x → 1) waves across the wind direction.
uniform float strength = 3.0;
void vertex() {
	vec2 world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xy;
	float phase = world.x * 0.013 + world.y * 0.007;
	VERTEX.y += sin(TIME * 5.0 + UV.x * 7.0 + phase) * strength * UV.x * UV.x * 2.0;
}
"""
static var _flutter: ShaderMaterial


static func flutter_material() -> ShaderMaterial:
	if _flutter == null:
		var sh := Shader.new()
		sh.code = FLUTTER_SHADER
		_flutter = ShaderMaterial.new()
		_flutter.shader = sh
	return _flutter


func _add_collision(c: Dictionary, rot: float) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.rotation = rot
	var cs := CollisionShape2D.new()
	if c.has("circle"):
		var sh := CircleShape2D.new()
		sh.radius = float(c["circle"])
		cs.shape = sh
	else:
		var r := RectangleShape2D.new()
		r.size = Content.v2(c["rect"])
		cs.shape = r
	if c.has("offset"):
		cs.position = Content.v2(c["offset"])
	body.add_child(cs)
	add_child(body)


func _on_reload() -> void:
	Assets.apply_to_sprite(sprite, str(sprite.get_meta("asset")))
	if shadow:
		var ss: Sprite2D = shadow.get_child(0)
		Assets.apply_to_sprite(ss, str(ss.get_meta("asset")))


## Small looping animations: generator shake, lamp flicker, sliding door.
func animate(delta: float) -> void:
	_t += delta
	match anim:
		"generator":
			sprite.get_parent().position = Vector2(sin(_t * 61.0), cos(_t * 47.0)) * 0.9
		"door":
			var near := Session.mode() == "foot" and Session.pilot_pos().distance_to(position) < 95.0
			_door_f = move_toward(_door_f, 1.0 if near else 0.0, delta * 2.5)
			sprite.get_parent().position = _door_open * smoothstep(0.0, 1.0, _door_f)
	if lamp:
		lamp.energy = 0.8 + 0.06 * sin(_t * 9.0) + (0.12 * sin(_t * 31.0) if fmod(_t, 7.3) < 0.25 else 0.0)


## Overhead structures fade while an actor is underneath.
func update_occlusion(points: Array, delta: float) -> void:
	if not occlude:
		return
	var under := false
	var inner := _box.grow(-18.0)
	for p in points:
		if inner.has_point(to_local(p)):
			under = true
	sprite.modulate.a = move_toward(sprite.modulate.a, FADE_ALPHA if under else 1.0, delta * 3.0)


func is_faded() -> bool:
	return sprite.modulate.a < 0.9
