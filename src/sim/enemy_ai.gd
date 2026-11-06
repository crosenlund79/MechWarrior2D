class_name EnemyAI
extends RefCounted
## Scrapper behaviour. Pure decision function: reads the enemy dictionary, its
## runtime brain and the target, returns intents. The simulation (drive,
## thermal, weapons) then applies the same rules as for the player.
##
## States: patrol → alert (reaction delay) → engage (approach to preferred
## range, aim, telegraphed wind-up, fire) → return (target lost or leash
## exceeded) → patrol. A hot enemy stops firing to cool off. "wreck" is final.
## Detection radius grows with the target mech's heat: a hot mech is easy to see.


static func detect_radius(target_heat: float, te: Dictionary) -> float:
	return clampf(float(te["detect_base"]) + maxf(0.0, target_heat - 60.0) * float(te["detect_per_degree"]),
		float(te["detect_base"]), float(te["detect_max"]))


## brain: runtime dict {wp, t_state, windup, cooldown}. target: {valid, pos, heat}.
## Returns {throttle, turn, fire, windup (0..1 for telegraph), state_changed}.
static func think(e: Dictionary, brain: Dictionary, target: Dictionary, defn: Dictionary, te: Dictionary,
		thermal: Dictionary, weapon: Dictionary, dt: float) -> Dictionary:
	var out := {"throttle": 0.0, "turn": 0.0, "fire": false, "event": ""}
	var st := str(e["ai"])
	if st == "wreck":
		return out
	var pos := Content.v2(e["pos"])
	var home := _patrol_centre(defn)
	var tpos: Vector2 = target.get("pos", Vector2.INF)
	var dist := pos.distance_to(tpos) if target.get("valid", false) else INF
	var sees: bool = target.get("valid", false) and dist <= detect_radius(float(target.get("heat", 0.0)), te) * float(target.get("visibility", 1.0))
	var lost: bool = not target.get("valid", false) or dist > float(te["lose_radius"]) or pos.distance_to(home) > float(te["leash_radius"])
	brain["t_state"] = float(brain.get("t_state", 0.0)) + dt
	brain["cooldown"] = maxf(0.0, float(brain.get("cooldown", 0.0)) - dt)
	match st:
		"patrol":
			_steer_to(out, e, _waypoint(defn, brain, pos), float(te["patrol_throttle"]))
			if sees:
				_set_state(e, brain, "alert")
				out["event"] = "alert"
		"alert":
			_face(out, e, tpos)
			if lost:
				_set_state(e, brain, "return")
			elif float(brain["t_state"]) >= float(te["reaction_time"]):
				_set_state(e, brain, "engage")
				brain["cooldown"] = 0.6
		"engage":
			if lost:
				_set_state(e, brain, "return")
				brain["windup"] = 0.0
				out["event"] = "disengage"
				return out
			var pref := float(te["preferred_range"])
			var aim_err := _face(out, e, tpos)
			if dist > pref + 60.0:
				out["throttle"] = 0.8 if absf(aim_err) < 0.7 else 0.2
			elif dist < pref - 90.0:
				out["throttle"] = -0.6
			var hot := float(e["heat"]) >= float(te["cool_off_temp"])
			var cone := deg_to_rad(float(te["fire_cone_deg"]))
			if float(brain.get("windup", 0.0)) > 0.0:
				brain["windup"] = float(brain["windup"]) + dt
				out["throttle"] = 0.0
				if float(brain["windup"]) >= float(weapon["telegraph"]):
					brain["windup"] = 0.0
					brain["cooldown"] = float(weapon["cooldown"])
					out["fire"] = true
			elif not hot and float(brain["cooldown"]) <= 0.0 and absf(aim_err) < cone and dist <= float(weapon["range"]) * 0.95:
				brain["windup"] = 0.0001
				out["event"] = "windup"
			if hot and float(brain.get("windup", 0.0)) <= 0.0:
				out["throttle"] = minf(out["throttle"], 0.0)  # hold position and cool down
		"return":
			_steer_to(out, e, home, float(te["patrol_throttle"]) * 1.2)
			if sees and pos.distance_to(home) < float(te["leash_radius"]) * 0.8:
				_set_state(e, brain, "alert")
				out["event"] = "alert"
			elif pos.distance_to(home) < 140.0:
				_set_state(e, brain, "patrol")
	out["windup"] = clampf(float(brain.get("windup", 0.0)) / maxf(float(weapon["telegraph"]), 0.01), 0.0, 1.0)
	return out


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
	if pos.distance_to(wp) < 70.0:
		brain["wp"] = (i + 1) % pts.size()
		wp = Content.v2(pts[int(brain["wp"])])
	return wp


## Turns toward a point; returns the remaining heading error (radians).
static func _face(out: Dictionary, e: Dictionary, p: Vector2) -> float:
	var to := p - Content.v2(e["pos"])
	var want := atan2(to.x, -to.y)
	var err := wrapf(want - float(e["heading"]), -PI, PI)
	out["turn"] = clampf(err * 1.6, -1.0, 1.0)
	return err


static func _steer_to(out: Dictionary, e: Dictionary, p: Vector2, throttle: float) -> void:
	var err := _face(out, e, p)
	out["throttle"] = throttle if absf(err) < 0.8 else throttle * 0.25
