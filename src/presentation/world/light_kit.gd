class_name LightKit
extends RefCounted
## Shared light/shadow resources (one instance each, reused everywhere).
##  - glow(): PointLight2D with the shared radial gradient (Red Thaw recipe).
##  - rotating_light_material(): top-down adaptation — rotating sprites cannot
##    bake "light from the upper left", so this shader brightens the world
##    upper-left half of each part and darkens the lower-right half at runtime.
##  - shadow_material(): flat soft silhouette for runtime cast shadows; the
##    owner offsets it toward the lower right in WORLD space.

static var _glow_tex: GradientTexture2D
static var _rot_mat: ShaderMaterial
static var _shadow_mat: ShaderMaterial

const ROTATING_LIGHT_SHADER := """
shader_type canvas_item;
uniform vec2 light_dir = vec2(-0.6, -0.8);
uniform float strength = 0.12;
varying vec2 local_light;
void vertex() {
	vec2 ax = normalize(MODEL_MATRIX[0].xy);
	vec2 ay = normalize(MODEL_MATRIX[1].xy);
	local_light = vec2(dot(light_dir, ax), dot(light_dir, ay));
}
void fragment() {
	vec2 l = normalize(local_light + vec2(0.0001));
	float f = dot((vec2(0.5) - UV) * 2.0, -l);
	COLOR.rgb *= 1.0 - clamp(f, -1.0, 1.0) * strength;
}
"""

const SHADOW_SHADER := """
shader_type canvas_item;
uniform float softness = 2.5;
uniform vec4 tint : source_color = vec4(0.09, 0.06, 0.04, 1.0);
void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * softness;
	float a = texture(TEXTURE, UV).a * 0.36;
	a += texture(TEXTURE, UV + vec2(px.x, 0.0)).a * 0.16;
	a += texture(TEXTURE, UV - vec2(px.x, 0.0)).a * 0.16;
	a += texture(TEXTURE, UV + vec2(0.0, px.y)).a * 0.16;
	a += texture(TEXTURE, UV - vec2(0.0, px.y)).a * 0.16;
	COLOR = vec4(tint.rgb, a * COLOR.a);
}
"""


static func glow_texture() -> GradientTexture2D:
	if _glow_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.55))
		_glow_tex = GradientTexture2D.new()
		_glow_tex.gradient = g
		_glow_tex.fill = GradientTexture2D.FILL_RADIAL
		_glow_tex.fill_from = Vector2(0.5, 0.5)
		_glow_tex.fill_to = Vector2(0.5, 0.0)
		_glow_tex.width = 256
		_glow_tex.height = 256
	return _glow_tex


static func glow(color: Color, scale: float, energy: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = glow_texture()
	l.color = color
	l.texture_scale = scale
	l.energy = energy
	l.blend_mode = Light2D.BLEND_MODE_ADD
	return l


static func rotating_light_material() -> ShaderMaterial:
	if _rot_mat == null:
		var sh := Shader.new()
		sh.code = ROTATING_LIGHT_SHADER
		_rot_mat = ShaderMaterial.new()
		_rot_mat.shader = sh
	return _rot_mat


static func shadow_material() -> ShaderMaterial:
	if _shadow_mat == null:
		var sh := Shader.new()
		sh.code = SHADOW_SHADER
		_shadow_mat = ShaderMaterial.new()
		_shadow_mat.shader = sh
	return _shadow_mat
