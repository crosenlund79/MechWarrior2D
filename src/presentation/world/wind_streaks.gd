class_name WindStreaks
extends Node2D
## Screen-space wind streaks (Red Thaw weather-overlay technique, re-themed):
## a few dozen faint thin lines in depth bands, moving with the wind. Restrained
## on purpose; drawn under the grade so they get graded too.

const COUNT := 46
const STORM_EXTRA := 150
var _s: Array = []
var storm := 0.0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in COUNT + STORM_EXTRA:
		var depth := rng.randf()
		_s.append({"p": Vector2(rng.randf() * 3000.0, rng.randf() * 1600.0), "d": depth,
			"len": lerpf(30.0, 140.0, depth), "a": lerpf(0.03, 0.10, depth), "v": lerpf(140.0, 420.0, depth)})


func _process(delta: float) -> void:
	var size := get_viewport().get_visible_rect().size
	for s in _s:
		s["p"] += Vector2(1, 0.22) * float(s["v"]) * delta * (1.0 + storm * 1.6)
		if s["p"].x > size.x + 200.0 or s["p"].y > size.y + 100.0:
			s["p"] = Vector2(randf_range(-300.0, size.x * 0.6), randf_range(-100.0, size.y))
	queue_redraw()


func _draw() -> void:
	var n := COUNT + int(STORM_EXTRA * storm)
	for i in n:
		var s: Dictionary = _s[i]
		var p: Vector2 = s["p"]
		var a := float(s["a"]) * (1.0 + storm * 2.5)
		draw_line(p, p + Vector2(1, 0.22) * float(s["len"]) * (1.0 + storm * 1.5), Color(0.93, 0.82, 0.62, minf(a, 0.35)), 1.0 + float(s["d"]) * (1.0 + storm), true)
