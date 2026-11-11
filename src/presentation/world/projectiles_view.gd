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
			# heavy round: long hot tracer with a glow sheath
			var tl := minf(96.0, float(sh["travelled"]))   # fast rounds: longer streak
			draw_line(p - d * tl, p, Color(1.0, 0.62, 0.25, 0.22), 9.0, true)
			draw_line(p - d * tl * 0.8, p, Color(1.0, 0.82, 0.45, 0.55), 4.5, true)
			draw_line(p - d * tl * 0.55, p, Color(1.0, 0.97, 0.85, 1.0), 2.4, true)
			draw_circle(p, 3.2, Color(1.0, 0.98, 0.9, 1.0))
		elif str(sh["owner"]).begins_with("turret:"):
			draw_circle(p - d * 10.0, 6.0, Color(0.25, 0.2, 0.16, 0.3))
			draw_circle(p, 8.5, Color(1.0, 0.35, 0.15, 0.35))
			draw_circle(p, 5.0, Color(1.0, 0.55, 0.2, 0.95))
			draw_circle(p, 2.2, Color(1.0, 0.9, 0.7, 1.0))
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
			var tgt := str(data.get("target", ""))
			if tgt == "ground" or tgt == "world":
				# sand / rock: dust plume + thrown grit, a few dull sparks on rock
				var dp := FxKit.puff(Color(0.84, 0.72, 0.54, 0.7), 14)
				dp.scale_amount_max = 3.0
				_fx(dp, pos)
				_fx(FxKit.debris(Color(0.45, 0.36, 0.26)), pos)
				if tgt == "world":
					var sp := FxKit.sparks()
					sp.amount = 4
					_fx(sp, pos)
			else:
				# metal: bright spark shower, hot flash, chips of paint/rust
				var sp2 := FxKit.sparks()
				sp2.amount = 18
				sp2.initial_velocity_max = 220.0
				_fx(sp2, pos)
				_fx(FxKit.debris(Color(0.5, 0.3, 0.2)), pos)
				_fx(FxKit.puff(Color(0.3, 0.26, 0.22, 0.5), 6), pos)
				var fl := LightKit.glow(Color(1.0, 0.7, 0.35), 0.7, 1.2)
				add_child(fl)
				fl.global_position = pos
				var tw := fl.create_tween()
				tw.tween_property(fl, "energy", 0.0, 0.18)
				tw.tween_callback(fl.queue_free)
		"cooling_hit":
			_fx(FxKit.sparks(), pos)
			_fx(FxKit.puff(Color(0.4, 0.8, 0.75, 0.75), 14), pos)
			_fx(FxKit.puff(Color(0.95, 0.94, 0.9, 0.5), 10), pos)
		"muzzle":
			var p := FxKit.puff(Color(1.0, 0.75, 0.4, 0.8), 6)
			p.lifetime = 0.25
			_fx(p, pos)
