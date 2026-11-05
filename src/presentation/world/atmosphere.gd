class_name Atmosphere
extends Node
## Desert atmosphere (Phase B): global light colour, the single full-screen colour
## grade (CanvasLayer 5; UI on 10 is never graded), world-anchored dust haze,
## restrained heat shimmer, drifting dust, ground-hugging sand streams and
## screen-space wind streaks (CanvasLayer 4).
##
## Grade = Red Thaw shader structure (saturation → contrast → split tone → fog →
## tinted vignette → grain) starting from the documented neutral-warm preset,
## adjusted for harsh desert sun. Shimmer and haze are NEW (sampled in world
## space through the canvas transform so they never slide with the camera).

const DAY_LIGHT := Color(1.0, 0.97, 0.9)
const CAVE_LIGHT := Color(0.74, 0.76, 0.84)   # under rock: cooler and darker; lamps carry the warmth

## Presets: "sun" (open desert) and "shade" (pilot/mech under the shelter roof).
const PRESETS := {
	"sun": {"saturation": 0.84, "contrast": 1.10, "shadow_tone": Vector3(0.90, 0.93, 0.98),
		"highlight_tone": Vector3(1.07, 1.0, 0.88), "vignette_tone": Vector3(0.56, 0.43, 0.31),
		"vignette_strength": 0.30, "grain_strength": 0.07, "fog_strength": 0.10, "shimmer": 0.7},
	"shade": {"saturation": 0.86, "contrast": 1.08, "shadow_tone": Vector3(0.88, 0.92, 0.97),
		"highlight_tone": Vector3(1.03, 1.0, 0.92), "vignette_tone": Vector3(0.50, 0.42, 0.34),
		"vignette_strength": 0.40, "grain_strength": 0.08, "fog_strength": 0.04, "shimmer": 0.25},
	"cave": {"saturation": 0.82, "contrast": 1.07, "shadow_tone": Vector3(0.86, 0.90, 0.98),
		"highlight_tone": Vector3(1.0, 0.98, 0.96), "vignette_tone": Vector3(0.40, 0.40, 0.46),
		"vignette_strength": 0.44, "grain_strength": 0.08, "fog_strength": 0.0, "shimmer": 0.08},
}

const GRADE_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform sampler2D grain : repeat_enable, filter_linear;
uniform sampler2D fog : repeat_enable, filter_linear;
uniform sampler2D shimmer_tex : repeat_enable, filter_linear;
uniform float grain_strength = 0.07;
uniform float vignette_strength = 0.3;
uniform float contrast = 1.1;
uniform float saturation = 0.84;
uniform float fog_strength = 0.1;
uniform float shimmer = 0.7;
uniform vec3 fog_color = vec3(0.90, 0.79, 0.62);
uniform vec3 shadow_tone = vec3(0.90, 0.93, 0.98);
uniform vec3 highlight_tone = vec3(1.07, 1.0, 0.88);
uniform vec3 vignette_tone = vec3(0.56, 0.43, 0.31);
uniform vec2 screen_size = vec2(1280.0, 720.0);
uniform vec2 world_origin = vec2(0.0);
uniform float world_scale = 1.0;
void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 wp = (uv * screen_size - world_origin) / world_scale;
	// heat shimmer: tiny, world-anchored, mostly horizontal wobble (px amplitude)
	vec2 s = texture(shimmer_tex, wp / 640.0 + vec2(TIME * 0.035, TIME * 0.11)).rg - 0.5;
	uv += vec2(s.x, s.y * 0.35) * shimmer * 2.0 / screen_size;
	vec3 c = texture(screen_tex, uv).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	c = clamp((c - 0.5) * contrast + 0.5, 0.0, 1.0);
	c *= mix(shadow_tone, highlight_tone, smoothstep(0.12, 0.8, l));
	if (fog_strength > 0.0) {
		float f1 = texture(fog, wp / 900.0 + vec2(TIME * 0.012, TIME * 0.003)).a;
		float f2 = texture(fog, wp / 1500.0 + vec2(TIME * 0.008, -TIME * 0.002)).a;
		float f = clamp(f1 * 0.6 + f2 * 0.6, 0.0, 1.0) * fog_strength;
		c = mix(c, fog_color * (0.6 + 0.4 * smoothstep(0.0, 0.6, l + 0.3)), f);
	}
	float g = texture(grain, SCREEN_UV * screen_size / 256.0).r;
	vec2 d = SCREEN_UV - 0.5;
	float v = smoothstep(0.32, 0.85, length(d * vec2(1.0, 0.8)));
	c = mix(c, c * vignette_tone, clamp(v * vignette_strength * 1.8, 0.0, 1.0));
	c *= 1.0 + (g - 0.5) * grain_strength * 2.0;
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
"""

var world: WorldView
var light: CanvasModulate
var grade_rect: ColorRect
var mat: ShaderMaterial
var streaks: WindStreaks
var enabled := true
var _blend := 0.0   # 0 = sun, 1 = shade
var _cave := 0.0    # 0 = open sky, 1 = under rock cover


func _ready() -> void:
	name = "Atmosphere"
	light = CanvasModulate.new()
	light.color = DAY_LIGHT
	world.add_child(light)
	var sl := CanvasLayer.new()
	sl.layer = 4
	add_child(sl)
	streaks = WindStreaks.new()
	sl.add_child(streaks)
	var gl := CanvasLayer.new()
	gl.layer = 5
	add_child(gl)
	grade_rect = ColorRect.new()
	grade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sh := Shader.new()
	sh.code = GRADE_SHADER
	mat = ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("grain", _fx("grain.png"))
	mat.set_shader_parameter("fog", _fx("haze.png"))
	mat.set_shader_parameter("shimmer_tex", _fx("shimmer.png"))
	grade_rect.material = mat
	gl.add_child(grade_rect)
	_build_dust()
	_apply(1.0)


func _fx(file: String) -> Texture2D:
	var p := "res://assets/fx/" + file
	return load(p) if ResourceLoader.exists(p) else null


func _build_dust() -> void:
	var b: Array = Session.loc.get("bounds", [0, 0, 3600, 2600])
	var mote := _fx("dust_mote.png")
	# Airborne fine dust over the whole location (Red Thaw drift recipe, desert wind).
	var p := CPUParticles2D.new()
	p.name = "DriftDust"
	p.texture = mote if mote else FxKit.dot()
	p.amount = 170
	p.lifetime = 14.0
	p.preprocess = 14.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.position = Vector2(b[0] + b[2] * 0.5, b[1] + b[3] * 0.5)
	p.emission_rect_extents = Vector2(b[2] * 0.55, b[3] * 0.55)
	p.direction = Vector2(1, 0.25)
	p.spread = 15.0
	p.gravity = Vector2(8, 2)
	p.initial_velocity_min = 18.0
	p.initial_velocity_max = 40.0
	p.scale_amount_min = 0.3
	p.scale_amount_max = 0.7
	p.color = Color(0.93, 0.84, 0.68, 0.55)
	p.z_index = 25
	world.add_child(p)
	# Sand streaming low over each dune field.
	for patch in Session.loc.get("patches", []):
		if patch.get("zone", "") != "dunes":
			continue
		var poly := Content.poly(patch["polygon"])
		var r := Rect2(poly[0], Vector2.ZERO)
		for v in poly:
			r = r.expand(v)
		var s := CPUParticles2D.new()
		s.name = "SandStream_" + str(patch["id"])
		s.texture = mote if mote else FxKit.dot()
		s.amount = 90
		s.lifetime = 3.5
		s.preprocess = 4.0
		s.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		s.position = r.get_center()
		s.emission_rect_extents = r.size * 0.45
		s.direction = Vector2(1, 0.22)
		s.spread = 6.0
		s.initial_velocity_min = 60.0
		s.initial_velocity_max = 110.0
		s.scale_amount_min = 0.4
		s.scale_amount_max = 1.2
		s.color_ramp = FxKit.ramp([0.0, 0.25, 0.8, 1.0], [Color(0.95, 0.84, 0.64, 0.0), Color(0.95, 0.84, 0.64, 0.35),
			Color(0.95, 0.84, 0.64, 0.25), Color(0.95, 0.84, 0.64, 0.0)])
		s.z_index = -6
		world.add_child(s)


func set_enabled(on: bool) -> void:
	enabled = on
	grade_rect.visible = on


func _process(delta: float) -> void:
	if not Session.running:
		return
	var in_shade := str((Session.pilot_zone if Session.mode() == "foot" else Session.mech_zone).get("type", "")) == "shade"
	_blend = move_toward(_blend, 1.0 if in_shade else 0.0, delta * 1.2)
	var cover := world.cover_amount() if world else 0.0
	var zt := str((Session.pilot_zone if Session.mode() == "foot" else Session.mech_zone).get("type", ""))
	var cave_t := maxf(cover, 0.35 if zt == "canyon" else 0.0)
	_cave = move_toward(_cave, cave_t, delta * 0.8)
	light.color = DAY_LIGHT.lerp(CAVE_LIGHT, smoothstep(0.0, 1.0, _cave))
	_apply(delta)
	var vp := get_viewport()
	mat.set_shader_parameter("screen_size", vp.get_visible_rect().size)
	var ct := vp.get_canvas_transform()
	mat.set_shader_parameter("world_origin", ct.origin)
	mat.set_shader_parameter("world_scale", ct.x.x)


func _apply(_delta: float) -> void:
	var a: Dictionary = PRESETS["sun"]
	var b: Dictionary = PRESETS["shade"]
	var c: Dictionary = PRESETS["cave"]
	var kc := smoothstep(0.0, 1.0, _cave)
	for k in a:
		var v = a[k]
		if v is Vector3:
			mat.set_shader_parameter(k, (v as Vector3).lerp(b[k], _blend).lerp(c[k], kc))
		else:
			mat.set_shader_parameter(k, lerpf(lerpf(float(v), float(b[k]), _blend), float(c[k]), kc))
	# A hot mech makes the air above the scene wobble a little more.
	if Session.running:
		var heat := float(Session.mech()["heat"])
		var extra := clampf((heat - 95.0) / 25.0, 0.0, 1.0) * 0.6
		mat.set_shader_parameter("shimmer", lerpf(lerpf(float(a["shimmer"]), float(b["shimmer"]), _blend), float(c["shimmer"]), kc) + extra * (1.0 - kc))
