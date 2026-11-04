class_name ProjectilesView
extends Node2D
## Draws live projectiles from Session.projectiles (sim-owned, not saved) and
## spawns short-lived impact / muzzle effects from Session.combat_event.
## Player shots: thin amber tracers. Enemy shots: slow, fat glowing slugs with a
## smoky trail so they are easy to read and dodge.


func _ready() -> void:
	z_index = 22
	Session.combat_event.connect(_on_combat)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	for sh in Session.projectiles:
		var p: Vector2 = sh["pos"]
		var v: Vector2 = sh["vel"]
		var d := v.normalized()
		if str(sh["owner"]) == "player":
			draw_line(p - d * 26.0, p, Color(1.0, 0.82, 0.45, 0.35), 4.0, true)
			draw_line(p - d * 18.0, p, Color(1.0, 0.95, 0.75, 0.95), 2.0, true)
		else:
			for k in 5:
				var t := float(k) / 5.0
				draw_circle(p - d * (10.0 + 14.0 * k), 7.0 - k, Color(0.25, 0.2, 0.16, 0.30 * (1.0 - t)))
			draw_circle(p, 11.0, Color(1.0, 0.45, 0.15, 0.30))
			draw_circle(p, 6.5, Color(1.0, 0.62, 0.25, 0.95))
			draw_circle(p, 3.0, Color(1.0, 0.95, 0.8, 1.0))
			draw_arc(p, 7.0, 0, TAU, 14, Color(0.13, 0.1, 0.08, 0.9), 1.5, true)


func _fx(node: CPUParticles2D, pos: Vector2) -> void:
	add_child(node)
	node.global_position = pos
	node.emitting = true
	node.finished.connect(node.queue_free)


func _on_combat(kind: String, data: Dictionary) -> void:
	var pos: Vector2 = data.get("pos", Vector2.ZERO)
	match kind:
		"impact":
			_fx(FxKit.sparks(), pos)
			_fx(FxKit.puff(Color(0.82, 0.7, 0.52, 0.55), 8), pos)
		"cooling_hit":
			_fx(FxKit.sparks(), pos)
			_fx(FxKit.puff(Color(0.4, 0.8, 0.75, 0.75), 14), pos)
			_fx(FxKit.puff(Color(0.95, 0.94, 0.9, 0.5), 10), pos)
		"muzzle":
			var p := FxKit.puff(Color(1.0, 0.75, 0.4, 0.8), 6)
			p.lifetime = 0.25
			_fx(p, pos)
