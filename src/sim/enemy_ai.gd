class_name EnemyAI
extends RefCounted
## Rival-car behaviour (scrappers and Southern Junkers). Pure decision function:
## reads the car dictionary, its runtime brain and the target, returns intents.
## The simulation (car dynamics, thermal, weapons) applies the same rules as for
## the player.
##
## Each rival car has a DRIVER (throttle/steer) and a roof GUNNER (a rotating
## gun, brain.gun = world angle). States:
##   patrol → alert (reaction delay) → engage → retreat → return → patrol
##   engage: chase when far, circle-strafe at preferred range when close; the
##           gunner swings onto the target, telegraphs (red aim line) and fires.
##   retreat: badly damaged (integrity < retreat_frac) → floor it away from the
##            player; once out of reach it "escapes" home and patches up slowly.
## Detection radius grows with the target's heat AND engine noise (speed):
## a hot, loud car is easy to find. Storms reduce it. "wreck" is final.


static func detect_radius(target_heat: float, te: Dictionary, noise: float = 0.0) -> float:
	var r := float(te["detect_base"]) + maxf(0.0, target_heat - 60.0) * float(te["detect_per_degree"])
	r += noise * float(te.get("detect_per_noise", 160.0))
	return clampf(r, float(te["detect_base"]), float(te["detect_max"]))


## brain: runtime dict {wp, t_state, windup, cooldown, gun, orbit}. target: {valid, pos, heat, noise, visibility}.
## Returns {throttle, turn, fire, fire_dir, windup (0..1), event}.
static func think(e: Dictionary, brain: Dictionary, target: Dictionary, defn: Dictionary, te: Dictionary,
		_thermal: Dictionary, weapon: Dictionary, dt: float) -> Dictionary:
	var out := {"throttle": 0.0, "turn": 0.0, "fire": false, "event": "", "windup": 0.0}
	var st := str(e["ai"])
	if st == "wreck":
		return out
	var pos := Content.v2(e["pos"])
	if not brain.has("gun"):
		brain["gun"] = float(e["heading"])
	var home := _patrol_centre(defn)
	var tpos: Vector2 = target.get("pos", Vector2.INF)
	var valid: bool = target.get("valid", false)
	var dist := pos.distance_to(tpos) if valid else INF
	var radius := detect_radius(float(target.get("heat", 0.0)), te, float(target.get("noise", 0.0))) * float(target.get("visibility", 1.0))
	var sees: bool = valid and dist <= radius
	var lost: bool = not valid or dist > float(te["lose_radius"]) or pos.distance_to(home) > float(te["leash_radius"])
	brain["t_state"] = float(brain.get("t_state", 0.0)) + dt
	brain["cooldown"] = maxf(0.0, float(brain.get("cooldown", 0.0)) - dt)
	var max_i := float(te.get("integrity", 55.0))
	var hurt := float(e["integrity"]) < max_i * float(te.get("retreat_frac", 0.3))
	var gun_target := Vector2.INF
	match st:
		"patrol":
			_steer_to(out, e, _waypoint(defn, brain, pos), float(te["patrol_throttle"]))
			if sees:
				_set_state(e, brain, "alert")
				out["event"] = "alert"
		"alert":
			gun_target = tpos
			_steer_to(out, e, tpos, 0.35)
			if lost:
				_set_state(e, brain, "return")
			elif float(brain["t_state"]) >= float(te["reaction_time"]):
				_set_state(e, brain, "engage")
				brain["cooldown"] = 0.8
				brain["orbit"] = 1.0 if (int(hash(str(defn.get("id", "")))) & 1) == 0 else -1.0
		"engage":
			if lost:
				_set_state(e, brain, "return")
				brain["windup"] = 0.0
				out["event"] = "disengage"
				return out
			if hurt:
				_set_state(e, brain, "retreat")
				brain["windup"] = 0.0
				out["event"] = "retreat"
				return out
			gun_target = tpos
			var pref := float(te["preferred_range"])
			if dist > pref * 1.6:
				_steer_to(out, e, tpos, 1.0)                         # chase
			else:
				# circle-strafe: aim for a point on the ring around the target
				var away := (pos - tpos).normalized()
				var orbit := float(brain.get("orbit", 1.0))
				var ring := tpos + away.rotated(orbit * 0.75) * pref
				_steer_to(out, e, ring, float(te.get("orbit_throttle", 0.7)))
				if dist < pref * 0.5:
					out["throttle"] = 1.0                            # too close: punch out of it
			var hot := float(e["heat"]) >= float(te["cool_off_temp"])
			if hot:
				out["throttle"] = minf(out["throttle"], 0.35)        # ease off to cool
			_gunner(out, e, brain, tpos, dist, te, weapon, dt, hot)
		"retreat":
			var flee := pos + (pos - tpos).normalized() * 600.0 if valid else home
			_steer_to(out, e, flee, 1.0)
			if not valid or dist > float(te.get("escape_distance", 1200.0)):
				_set_state(e, brain, "return")
				out["event"] = "escaped"
		"return":
			_steer_to(out, e, home, float(te["patrol_throttle"]) * 1.3)
			# patch up slowly once safely away from the fight
			e["integrity"] = minf(max_i, float(e["integrity"]) + float(te.get("field_repair", 0.6)) * dt)
			if sees and not hurt and pos.distance_to(home) < float(te["leash_radius"]) * 0.8:
				_set_state(e, brain, "alert")
				out["event"] = "alert"
			elif pos.distance_to(home) < 240.0:   # cars circle rather than stop on a spot
				_set_state(e, brain, "patrol")
	# Unstick: a car pinned against an obstacle (wants to drive, not moving) backs
	# up with opposite lock for a moment — cars cannot turn on the spot.
	if float(brain.get("reverse_t", 0.0)) > 0.0:
		brain["reverse_t"] = float(brain["reverse_t"]) - dt
		out["throttle"] = -0.8
		out["turn"] = -float(brain.get("reverse_turn", 1.0))
	elif absf(float(out["throttle"])) > 0.2 and absf(float(e.get("speed", 0.0))) < 15.0:
		brain["stuck_t"] = float(brain.get("stuck_t", 0.0)) + dt
		if float(brain["stuck_t"]) > 0.9:
			brain["stuck_t"] = 0.0
			brain["reverse_t"] = 1.1
			brain["reverse_turn"] = signf(float(out["turn"])) if absf(float(out["turn"])) > 0.1 else 1.0
	else:
		brain["stuck_t"] = 0.0
	# The gunner turret slews toward its target (or back to the bonnet).
	var want := float(e["heading"])
	if gun_target != Vector2.INF:
		var to := gun_target - pos
		want = atan2(to.x, -to.y)
	var gerr := wrapf(want - float(brain["gun"]), -PI, PI)
	var gr := float(te.get("gun_turn_rate", 2.2))
	brain["gun"] = wrapf(float(brain["gun"]) + clampf(gerr, -gr * dt, gr * dt), -PI, PI)
	out["fire_dir"] = Drive.forward(float(brain["gun"]))
	out["windup"] = clampf(float(brain.get("windup", 0.0)) / maxf(float(weapon["telegraph"]), 0.01), 0.0, 1.0)
	return out


static func _gunner(out: Dictionary, _e: Dictionary, brain: Dictionary, tpos: Vector2, dist: float, te: Dictionary,
		weapon: Dictionary, dt: float, hot: bool) -> void:
	var to := tpos - Content.v2(_e["pos"])
	var aim_err := wrapf(atan2(to.x, -to.y) - float(brain["gun"]), -PI, PI)
	var cone := deg_to_rad(float(te["fire_cone_deg"]))
	if float(brain.get("windup", 0.0)) > 0.0:
		brain["windup"] = float(brain["windup"]) + dt
		if float(brain["windup"]) >= float(weapon["telegraph"]):
			brain["windup"] = 0.0
			brain["cooldown"] = float(weapon["cooldown"])
			out["fire"] = true
	elif not hot and float(brain["cooldown"]) <= 0.0 and absf(aim_err) < cone and dist <= float(weapon["range"]) * 0.95:
		brain["windup"] = 0.0001
		out["event"] = "windup"


static func _set_state(e: Dictionary, brain: Dictionary, st: String) -> void:
	e["ai"] = st
	brain["t_state"] = 0.0


static func _patrol_centre(defn: Dictionary) -> Vector2:
	var pts: Array = defn.get("patrol", [])
	if pts.is_empty():
		return Content.v2(defn.get("spawn", [0, 0]))
	var c := Vector2.ZERO
	for p in pts:
		c += Content.v2(p)
	return c / pts.size()


static func _waypoint(defn: Dictionary, brain: Dictionary, pos: Vector2) -> Vector2:
	var pts: Array = defn.get("patrol", [])
	if pts.is_empty():
		return pos
	var i := int(brain.get("wp", 0)) % pts.size()
	var wp := Content.v2(pts[i])
	if pos.distance_to(wp) < 110.0:
		brain["wp"] = (i + 1) % pts.size()
		wp = Content.v2(pts[int(brain["wp"])])
	return wp


## Steers a car toward a point; returns the remaining heading error (radians).
## Cars turn only while rolling, so a big error keeps some throttle on.
static func _face(out: Dictionary, e: Dictionary, p: Vector2) -> float:
	var to := p - Content.v2(e["pos"])
	var want := atan2(to.x, -to.y)
	var err := wrapf(want - float(e["heading"]), -PI, PI)
	out["turn"] = clampf(err * 2.0, -1.0, 1.0)
	return err


static func _steer_to(out: Dictionary, e: Dictionary, p: Vector2, throttle: float) -> void:
	var err := _face(out, e, p)
	if Content.v2(e["pos"]).distance_to(p) < 60.0:
		out["throttle"] = 0.0
		return
	out["throttle"] = throttle if absf(err) < 1.2 else maxf(0.35, throttle * 0.5)
