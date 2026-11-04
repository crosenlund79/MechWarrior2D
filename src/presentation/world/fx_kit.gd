class_name FxKit
extends RefCounted
## Small particle presets (CPUParticles2D: cheap, Compatibility-safe).

static var _dot: Texture2D


static func dot() -> Texture2D:
	if _dot == null:
		var path := "res://assets/fx/soft_dot.png"
		if ResourceLoader.exists(path):
			_dot = load(path)
		else:
			var g := Gradient.new()
			g.set_color(0, Color(1, 1, 1, 1))
			g.set_color(1, Color(1, 1, 1, 0))
			var t := GradientTexture2D.new()
			t.gradient = g
			t.fill = GradientTexture2D.FILL_RADIAL
			t.fill_from = Vector2(0.5, 0.5)
			t.fill_to = Vector2(0.5, 0.0)
			t.width = 24
			t.height = 24
			_dot = t
	return _dot


static func steam() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = dot()
	p.amount = 26
	p.lifetime = 1.6
	p.emitting = false
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(55, 10)
	p.direction = Vector2(0.4, -1)
	p.spread = 35.0
	p.gravity = Vector2(14, -10)
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 45.0
	p.scale_amount_min = 1.2
	p.scale_amount_max = 2.6
	p.color_ramp = ramp([0.0, 0.15, 1.0], [Color(0.95, 0.93, 0.88, 0.0), Color(0.95, 0.93, 0.88, 0.5), Color(0.9, 0.88, 0.84, 0.0)])
	p.z_index = 4
	return p


static func footfall_dust() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = dot()
	p.amount = 18
	p.lifetime = 1.4
	p.emitting = false
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 40.0
	p.direction = Vector2(1, 0.3)
	p.spread = 60.0
	p.gravity = Vector2(10, 4)
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 22.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.2
	p.color_ramp = ramp([0.0, 0.2, 1.0], [Color(0.78, 0.66, 0.5, 0.0), Color(0.78, 0.66, 0.5, 0.35), Color(0.78, 0.66, 0.5, 0.0)])
	p.z_index = -1
	return p


static func ramp(offsets: Array, colors: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	return g
