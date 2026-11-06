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


static func coolant_leak() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = dot()
	p.amount = 14
	p.lifetime = 1.2
	p.emitting = false
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(40, 4)
	p.direction = Vector2(0, 1)
	p.spread = 30.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 20.0
	p.scale_amount_min = 0.3
	p.scale_amount_max = 0.7
	p.color_ramp = ramp([0.0, 0.2, 1.0], [Color(0.3, 0.75, 0.7, 0.0), Color(0.3, 0.75, 0.7, 0.8), Color(0.25, 0.45, 0.4, 0.0)])
	p.z_index = 1
	return p


static func damage_smoke() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = dot()
	p.amount = 16
	p.lifetime = 2.4
	p.emitting = false
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 14.0
	p.direction = Vector2(1, 0.25)
	p.spread = 25.0
	p.gravity = Vector2(14, 3)
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 24.0
	p.scale_amount_min = 1.4
	p.scale_amount_max = 3.2
	p.color_ramp = ramp([0.0, 0.15, 1.0], [Color(0.18, 0.15, 0.12, 0.0), Color(0.18, 0.15, 0.12, 0.45), Color(0.3, 0.27, 0.22, 0.0)])
	p.z_index = 7
	return p


static func sparks() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = dot()
	p.amount = 10
	p.lifetime = 0.5
	p.one_shot = true
	p.explosiveness = 0.95
	p.local_coords = false
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 160.0
	p.damping_min = 120.0
	p.damping_max = 200.0
	p.scale_amount_min = 0.15
	p.scale_amount_max = 0.35
	p.color_ramp = ramp([0.0, 0.5, 1.0], [Color(1.0, 0.9, 0.55, 1.0), Color(1.0, 0.55, 0.2, 0.9), Color(0.6, 0.2, 0.1, 0.0)])
	p.z_index = 24
	return p


static func puff(color: Color, amount: int = 10) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = dot()
	p.amount = amount
	p.lifetime = 0.9
	p.one_shot = true
	p.explosiveness = 0.9
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 6.0
	p.spread = 180.0
	p.gravity = Vector2(10, 2)
	p.initial_velocity_min = 15.0
	p.initial_velocity_max = 45.0
	p.damping_min = 30.0
	p.damping_max = 50.0
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.8
	p.color_ramp = ramp([0.0, 0.2, 1.0], [Color(color, 0.0), Color(color, color.a), Color(color, 0.0)])
	p.z_index = 23
	return p


## Sand blasted off the ground by the muzzle blast (directional, settles quickly).
static func ground_blast() -> CPUParticles2D:
	var p := puff(Color(0.84, 0.72, 0.54, 0.5), 14)
	p.emission_sphere_radius = 26.0
	p.spread = 55.0
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 110.0
	p.damping_min = 90.0
	p.damping_max = 140.0
	p.scale_amount_min = 1.4
	p.scale_amount_max = 3.2
	p.lifetime = 1.1
	p.z_index = 4
	return p


## Debris chips thrown from an impact (sand/rock), plus a dust burst.
static func debris(color: Color) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = dot()
	p.amount = 12
	p.lifetime = 0.7
	p.one_shot = true
	p.explosiveness = 0.95
	p.local_coords = false
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 50.0
	p.initial_velocity_max = 150.0
	p.damping_min = 160.0
	p.damping_max = 240.0
	p.scale_amount_min = 0.12
	p.scale_amount_max = 0.3
	p.color = color
	p.z_index = 23
	return p


## Burning barrel flames (small, continuous).
static func fire() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = dot()
	p.amount = 18
	p.lifetime = 0.8
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 9.0
	p.direction = Vector2(0.3, -1)
	p.spread = 25.0
	p.gravity = Vector2(18, -20)
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 30.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	p.color_ramp = ramp([0.0, 0.3, 1.0], [Color(1.0, 0.85, 0.4, 0.9), Color(1.0, 0.45, 0.15, 0.7), Color(0.25, 0.2, 0.18, 0.0)])
	p.z_index = 6
	return p
