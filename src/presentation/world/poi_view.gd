class_name PoiView
extends Node2D
## One point of interest in the world. Abandoned expedition: a wrecked vehicle
## (sometimes still burning), the dead driver beside it and scattered papers,
## with a faint glint while it has not been searched. Landmark: its prop.
## Collision comes from the wreck footprint (art never drives gameplay: the
## footprint is a fixed rect). Purely visual otherwise; reads Session state.

var def: Dictionary = {}
var fire: CPUParticles2D
var smoke: CPUParticles2D
var glint: PointLight2D
var _t := 0.0


func setup(d: Dictionary) -> void:
	def = d
	name = "Poi_" + str(d["id"])
	position = Content.v2(d["pos"])


func _ready() -> void:
	var kind := str(def.get("kind", "expedition"))
	var seed := hash(str(def["id"]))
	if kind == "expedition":
		var wreck := _sprite(str(def.get("wreck", "rival.wreck")), Vector2(0, 0), float(seed % 360))
		wreck.modulate = Color(0.62, 0.56, 0.5)
		_sprite("poi.corpse", Vector2(95, 55), float((seed / 7) % 360))
		_sprite("poi.papers", Vector2(-70, 80), float((seed / 13) % 360))
		var body := StaticBody2D.new()
		body.collision_layer = 1
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(150, 80)
		cs.shape = r
		cs.rotation = deg_to_rad(float(seed % 360))
		body.add_child(cs)
		add_child(body)
		if bool(def.get("burning", false)):
			fire = FxKit.fire()
			fire.position = Vector2(10, -10)
			add_child(fire)
			smoke = FxKit.damage_smoke()
			smoke.position = Vector2(0, -20)
			add_child(smoke)
			var fl := LightKit.glow(Color(1.0, 0.55, 0.2), 1.4, 0.7)
			add_child(fl)
			fl.set_meta("flicker", true)
		glint = LightKit.glow(Color(1.0, 0.85, 0.5), 0.8, 0.0)
		glint.position = Vector2(95, 55)
		add_child(glint)
	elif str(def.get("asset", "")) != "":
		_sprite(str(def["asset"]), Vector2.ZERO, float(seed % 360))


func _sprite(asset: String, at: Vector2, rot_deg: float) -> Sprite2D:
	var h := Node2D.new()
	h.position = at
	h.rotation = deg_to_rad(rot_deg)
	add_child(h)
	var s := Sprite2D.new()
	h.add_child(s)
	Assets.apply_to_sprite(s, asset)
	return s


func _process(delta: float) -> void:
	if not Session.running:
		return
	_t += delta
	var ps := Session.poi_state(str(def["id"]))
	if glint:
		glint.energy = 0.0 if bool(ps.get("searched", false)) else 0.3 + 0.2 * sin(_t * 2.5)
	for c in get_children():
		if c is PointLight2D and c.has_meta("flicker"):
			c.energy = 0.55 + 0.25 * sin(_t * 13.0) * sin(_t * 7.3)
