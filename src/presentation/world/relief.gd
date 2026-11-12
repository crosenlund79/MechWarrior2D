class_name Relief
extends RefCounted
## Lightweight 2D elevation illusion (visual only — collision, aiming and
## navigation are untouched). Each map gets a smooth heightfield h ∈ [-1, 1]:
##   low-frequency noise (rolling ground, depressions)
## + raised flanks around rock masses (ridges)       — blurred, so slopes are gentle
## − flattened bands along roads and settlement yards.
## Uses: a baked hillshade texture (light from the upper left) laid over the
## ground, and a small smooth scale/shadow change for objects standing higher or
## lower (SCALE_K). Built once per map and cached.

const CELL := 48.0
const SCALE_K := 0.07        # ±7 % size at the extremes
const SHADOW_K := 0.6        # shadows lengthen with height

static var _cache := {}

var origin := Vector2.ZERO
var w := 0
var h := 0
var data := PackedFloat32Array()


static func for_location(loc: Dictionary) -> Relief:
	var id := str(loc.get("id", ""))
	if not _cache.has(id):
		var r := Relief.new()
		r._build(loc)
		_cache[id] = r
	return _cache[id]


func _build(loc: Dictionary) -> void:
	var b: Array = loc.get("bounds", [0, 0, 3600, 2600])
	var rel: Dictionary = loc.get("relief", {})
	var amp := float(rel.get("amp", 1.0))
	origin = Vector2(float(b[0]) - 400.0, float(b[1]) - 400.0)
	w = int((float(b[2]) + 800.0) / CELL) + 2
	h = int((float(b[3]) + 800.0) / CELL) + 2
	data.resize(w * h)
	var n := FastNoiseLite.new()
	n.seed = int(rel.get("seed", 1))
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 1.0 / maxf(float(rel.get("scale", 900.0)), 100.0)
	n.fractal_octaves = 3
	# rock masses raise the ground around them (rasterised, then blurred)
	var mass := PackedFloat32Array()
	mass.resize(w * h)
	for m in loc.get("terrain", {}).get("masses", []):
		var poly := PackedVector2Array()
		for q in m["polygon"]:
			poly.append(Content.v2(q))
		var bb := Rect2(poly[0], Vector2.ZERO)
		for q in poly:
			bb = bb.expand(q)
		var x0 := maxi(0, int((bb.position.x - origin.x) / CELL))
		var x1 := mini(w - 1, int((bb.end.x - origin.x) / CELL) + 1)
		var y0 := maxi(0, int((bb.position.y - origin.y) / CELL))
		var y1 := mini(h - 1, int((bb.end.y - origin.y) / CELL) + 1)
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				if Geometry2D.is_point_in_polygon(origin + Vector2(x, y) * CELL, poly):
					mass[y * w + x] = 1.0
	mass = _blur(_blur(_blur(mass)))
	# roads and yards are graded flat
	var flat := PackedFloat32Array()
	flat.resize(w * h)
	for p in loc.get("patches", []):
		if p.has("path"):
			var pts: Array = p["path"]
			for i in pts.size() - 1:
				var a := Content.v2(pts[i])
				var c := Content.v2(pts[i + 1])
				var steps := int(a.distance_to(c) / (CELL * 0.5)) + 1
				for k in steps + 1:
					var q := a.lerp(c, float(k) / steps)
					var cx := int((q.x - origin.x) / CELL)
					var cy := int((q.y - origin.y) / CELL)
					for dy in range(-2, 3):
						for dx in range(-2, 3):
							var xx := cx + dx
							var yy := cy + dy
							if xx >= 0 and yy >= 0 and xx < w and yy < h:
								flat[yy * w + xx] = 1.0
	for z in loc.get("zones", []):
		if str(z.get("type", "")) == "settlement":
			var zp := PackedVector2Array()
			for q in z["polygon"]:
				zp.append(Content.v2(q))
			for y in h:
				for x in w:
					if Geometry2D.is_point_in_polygon(origin + Vector2(x, y) * CELL, zp):
						flat[y * w + x] = 1.0
	flat = _blur(_blur(flat))
	for y in h:
		for x in w:
			var wp := origin + Vector2(x, y) * CELL
			var v := n.get_noise_2d(wp.x, wp.y) * 0.75 + float(mass[y * w + x]) * 0.9
			v *= 1.0 - 0.75 * clampf(float(flat[y * w + x]), 0.0, 1.0)
			data[y * w + x] = clampf(v * amp, -1.0, 1.0)


func _blur(a: PackedFloat32Array) -> PackedFloat32Array:
	var o := PackedFloat32Array()
	o.resize(a.size())
	for y in h:
		for x in w:
			var s := 0.0
			var c := 0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var xx := x + dx
					var yy := y + dy
					if xx >= 0 and yy >= 0 and xx < w and yy < h:
						s += a[yy * w + xx]
						c += 1
			o[y * w + x] = s / c
	return o


## Smooth (bilinear) height at a world position, −1..1.
func height_at(p: Vector2) -> float:
	var fx := (p.x - origin.x) / CELL
	var fy := (p.y - origin.y) / CELL
	var x := clampi(int(fx), 0, w - 2)
	var y := clampi(int(fy), 0, h - 2)
	var tx := clampf(fx - x, 0.0, 1.0)
	var ty := clampf(fy - y, 0.0, 1.0)
	var a := lerpf(data[y * w + x], data[y * w + x + 1], tx)
	var b := lerpf(data[(y + 1) * w + x], data[(y + 1) * w + x + 1], tx)
	return lerpf(a, b, ty)


## Visual scale factor for something standing at p.
func scale_at(p: Vector2) -> float:
	return 1.0 + height_at(p) * SCALE_K


## Hillshade texture: one pixel per cell, lit slopes warm, shaded slopes dark;
## faint contour lines every elevation step. Drawn over the ground tiles.
func hillshade() -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var light := Vector3(-1.0, -1.0, 1.4).normalized()
	for y in h:
		for x in w:
			var hx := data[y * w + mini(x + 1, w - 1)] - data[y * w + maxi(x - 1, 0)]
			var hy := data[mini(y + 1, h - 1) * w + x] - data[maxi(y - 1, 0) * w + x]
			var nrm := Vector3(-hx * 2.6, -hy * 2.6, 1.0).normalized()
			var lit := nrm.dot(light) - light.z
			var v := data[y * w + x]
			var c: Color
			if lit >= 0.0:
				c = Color(1.0, 0.93, 0.78, clampf(lit * 1.4, 0.0, 0.2))
			else:
				c = Color(0.16, 0.11, 0.07, clampf(-lit * 1.6, 0.0, 0.26))
			# low ground slightly darker (depressions hold shade), high ground lighter
			c = c.blend(Color(0.2, 0.14, 0.09, clampf(-v * 0.1, 0.0, 0.1)))
			c = c.blend(Color(1.0, 0.95, 0.85, clampf(v * 0.08, 0.0, 0.08)))
			# contour hint
			var band := fposmod(v * 6.0, 1.0)
			if band < 0.06 and absf(v) > 0.15:
				c = c.blend(Color(0.25, 0.17, 0.1, 0.12))
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)
