class_name Drive
extends RefCounted
## Shared top-down CAR dynamics (player and rival cars obey the same rules).
##
## State on the vehicle dictionary: heading (rad, 0 = up), speed (forward speed,
## px/s, signed — read by heat, HUD, AI), vel ([x, y] world velocity) and slip
## (lateral sliding speed, for skid marks / tyre audio).
##
## Model (arcade but physical):
##   · the engine pushes the FORWARD component toward throttle × top speed
##     (accel / brake / coast rates; reverse is slower);
##   · steering turns the heading, scaled by forward speed (a parked car cannot
##     pivot; full lock is reached at `steer_full_speed`; turning gets gentler
##     toward top speed; reverse steers inverted like a real car, with its own
##     much lower `reverse_turn_rate*` so backing up stays controllable);
##   · the world velocity is carried over when the heading changes (momentum),
##     then the LATERAL component is bled off by tyre grip (px/s²). When the
##     required cornering force exceeds grip the car slides; the handbrake
##     cuts rear grip for a controllable drift.
## Zone `drag` caps top speed (soft sand), zone `grip` scales tyre grip and
## heat impairment caps speed when the engine runs hot.


## Heat impairment: full speed below warn_temp, falling linearly to
## (1 − impair_max) at critical_temp (where the engine shuts down anyway).
static func impairment(heat: float, thermal: Dictionary, impair_max: float) -> float:
	var warn := float(thermal.get("warn_temp", 98.0))
	var crit := float(thermal.get("critical_temp", 115.0))
	return 1.0 - impair_max * clampf((heat - warn) / maxf(crit - warn, 0.1), 0.0, 1.0)


static func forward(heading: float) -> Vector2:
	return Vector2(sin(heading), -cos(heading))


static func right(heading: float) -> Vector2:
	return Vector2(cos(heading), sin(heading))


static func velocity(m: Dictionary) -> Vector2:
	var v = m.get("vel", null)
	if v is Array and v.size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	return forward(float(m.get("heading", 0.0))) * float(m.get("speed", 0.0))


## Updates m.speed / m.heading / m.vel / m.slip in place and returns the desired
## world velocity. `handbrake` locks the rear wheels (drift).
static func step(m: Dictionary, throttle: float, turn: float, can_drive: bool, tm: Dictionary,
		thermal: Dictionary, zone: Dictionary, dt: float, handbrake: bool = false) -> Vector2:
	var drag := float(zone.get("drag", 1.0)) * impairment(float(m["heat"]), thermal, float(tm.get("impair_max", 0.5)))
	var max_s := float(tm.get("max_speed", 420.0)) * drag
	var rev_s := float(tm.get("reverse_speed", 160.0)) * drag
	if not can_drive:
		throttle = 0.0
		turn = 0.0
		handbrake = false
	var h := float(m["heading"])
	var v := velocity(m)
	var vf := v.dot(forward(h))
	# --- engine / brakes along the heading
	var target := max_s * throttle if throttle >= 0.0 else rev_s * throttle
	var rate := float(tm.get("accel", 300.0))
	if absf(throttle) < 0.05:
		rate = float(tm.get("coast_drag", 120.0)) if can_drive else float(tm.get("brake", 600.0)) * 0.5
	elif signf(target) != signf(vf) and absf(vf) > 1.0:
		rate = float(tm.get("brake", 600.0))
	if handbrake:
		target = 0.0
		rate = maxf(rate * 0.3, float(tm.get("handbrake_decel", 260.0)))
	if absf(vf) > max_s + 1.0:
		rate = maxf(rate, float(tm.get("brake", 600.0)) * 0.4)
	var new_vf := move_toward(vf, target, rate * dt)
	v += forward(h) * (new_vf - vf)
	# --- steering: scales with forward speed (no pivoting on the spot)
	var top := maxf(float(tm.get("max_speed", 420.0)), 1.0)
	var steer_frac := clampf(absf(new_vf) / maxf(float(tm.get("steer_full_speed", 70.0)), 1.0), 0.0, 1.0)
	var tr := lerpf(float(tm.get("turn_rate", 2.6)), float(tm.get("turn_rate_full_speed", 1.6)), clampf(absf(new_vf) / top, 0.0, 1.0))
	var dir := 1.0 if new_vf >= -1.0 else -1.0
	if dir < 0.0:
		# Reversing: much gentler steering, and gentler still the faster you back up,
		# so a reversing car never snaps round (playtest 001/003).
		var rtop := maxf(float(tm.get("reverse_speed", 170.0)), 1.0)
		tr = lerpf(float(tm.get("reverse_turn_rate", 1.1)), float(tm.get("reverse_turn_rate_full_speed", 0.6)), clampf(absf(new_vf) / rtop, 0.0, 1.0))
		steer_frac = clampf(absf(new_vf) / maxf(float(tm.get("reverse_steer_full_speed", 110.0)), 1.0), 0.0, 1.0)
	if handbrake:
		tr *= float(tm.get("handbrake_turn", 1.45))
	h = wrapf(h + turn * tr * steer_frac * dir * dt, -PI, PI)
	# --- tyres: bleed off sideways velocity (momentum survives the turn → slip)
	var grip := float(tm.get("grip", 1300.0)) * float(zone.get("grip", 1.0))
	if handbrake:
		grip *= float(tm.get("handbrake_grip", 0.22))
	var fwd := forward(h)
	var rgt := right(h)
	var vr := v.dot(rgt)
	var vf2 := v.dot(fwd)
	vr = move_toward(vr, 0.0, grip * dt)
	# rolling resistance on a sliding car turns some slide back into forward roll
	v = fwd * vf2 + rgt * vr
	m["heading"] = h
	m["speed"] = vf2
	m["slip"] = absf(vr)
	m["vel"] = [v.x, v.y]
	return v
