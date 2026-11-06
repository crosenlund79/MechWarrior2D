class_name Drive
extends RefCounted
## Shared walker-mech drive dynamics (player and enemy obey the same rules).
## Throttle/turn intents → speed and heading; zone drag and heat impairment cap
## the top speed; a shut-down or wrecked mech coasts to a stop.


## Heat impairment: full speed below warn_temp, falling linearly to
## (1 − impair_max) at critical_temp (where the engine shuts down anyway).
static func impairment(heat: float, thermal: Dictionary, impair_max: float) -> float:
	var warn := float(thermal.get("warn_temp", 98.0))
	var crit := float(thermal.get("critical_temp", 115.0))
	return 1.0 - impair_max * clampf((heat - warn) / maxf(crit - warn, 0.1), 0.0, 1.0)


## Updates m.speed / m.heading in place and returns the desired velocity.
static func step(m: Dictionary, throttle: float, turn: float, can_drive: bool, tm: Dictionary,
		thermal: Dictionary, zone: Dictionary, dt: float) -> Vector2:
	var drag := float(zone.get("drag", 1.0)) * impairment(float(m["heat"]), thermal, float(tm.get("impair_max", 0.5)))
	var max_s := float(tm.get("max_speed", 150.0)) * drag
	var rev_s := float(tm.get("reverse_speed", 65.0)) * drag
	var speed := float(m["speed"])
	if not can_drive:
		throttle = 0.0
		turn = 0.0
	var target := max_s * throttle if throttle >= 0.0 else rev_s * throttle
	var rate := float(tm.get("accel", 95.0))
	if absf(throttle) < 0.05:
		rate = float(tm.get("coast_drag", 60.0)) if can_drive else float(tm.get("brake", 240.0))
	elif signf(target) != signf(speed) and absf(speed) > 1.0:
		rate = float(tm.get("brake", 240.0))
	if absf(speed) > max_s + 1.0:
		rate = maxf(rate, float(tm.get("brake", 240.0)) * 0.5)
	speed = move_toward(speed, target, rate * dt)
	var tr := lerpf(float(tm.get("turn_rate", 1.5)), float(tm.get("turn_rate_full_speed", 0.95)),
		clampf(absf(speed) / maxf(float(tm.get("max_speed", 150.0)), 1.0), 0.0, 1.0))
	m["heading"] = wrapf(float(m["heading"]) + turn * tr * dt, -PI, PI)
	m["speed"] = speed
	return forward(float(m["heading"])) * speed


static func forward(heading: float) -> Vector2:
	return Vector2(sin(heading), -cos(heading))
