class_name Encounter
extends RefCounted
## Parked-mech encounter: a suited pilot stands beside an unoccupied scrapper.
## Explicit sequence (stored in enemy.ai):
##   unpiloted → alerted → boarding → starting → ACTIVE (EnemyAI states) → wreck
## The pilot is plain data (enemy.pilot = {state, pos, facing}); it genuinely
## walks to the boarding point, climbs to the hatch, then the mech powers up.
## Pilot states: "outside", "climbing", "aboard", "fled", "gone".

const STATES := ["unpiloted", "alerted", "boarding", "starting"]


static func is_encounter_state(ai: String) -> bool:
	return ai in STATES


static func board_point(e: Dictionary, te: Dictionary) -> Vector2:
	return Content.v2(e["pos"]) + Content.v2(te.get("board_offset", [-96, -30])).rotated(float(e["heading"]))


static func hatch_point(e: Dictionary, te: Dictionary) -> Vector2:
	return Content.v2(e["pos"]) + Content.v2(te.get("hatch_offset", [-18, -46])).rotated(float(e["heading"]))


## player: {mech_pos, mech_heat, mech_valid, foot, foot_pos}
## Returns an event name ("" | "pilot_alert" | "pilot_boarding" | "cockpit_closed" | "startup" | "active").
static func step(e: Dictionary, brain: Dictionary, player: Dictionary, tenc: Dictionary, te: Dictionary, dt: float) -> String:
	var ai := str(e["ai"])
	var p: Dictionary = e["pilot"]
	var ppos := Content.v2(p["pos"])
	brain["t_state"] = float(brain.get("t_state", 0.0)) + dt
	match ai:
		"unpiloted":
			# Idle maintenance: face the machine, shuffle slightly.
			var to_mech := Content.v2(e["pos"]) - ppos
			p["facing"] = lerp_angle(float(p["facing"]), atan2(to_mech.x, -to_mech.y), dt * 2.0)
			if detects(e, player, tenc, te):
				_set_state(e, brain, "alerted")
				return "pilot_alert"
		"alerted":
			var threat: Vector2 = player["foot_pos"] if player.get("foot", false) else player["mech_pos"]
			var to := threat - ppos
			p["facing"] = lerp_angle(float(p["facing"]), atan2(to.x, -to.y), dt * 8.0)
			if float(brain["t_state"]) >= float(tenc.get("reaction", 0.9)):
				_set_state(e, brain, "boarding")
				return "pilot_boarding"
		"boarding":
			if str(p["state"]) == "outside":
				var bp := board_point(e, tenc)
				var d := bp - ppos
				var stepv := float(tenc.get("pilot_speed", 150.0)) * dt
				if d.length() <= stepv:
					p["pos"] = [bp.x, bp.y]
					p["state"] = "climbing"
					brain["climb"] = 0.0
				else:
					var np := ppos + d.normalized() * stepv
					p["pos"] = [np.x, np.y]
					p["facing"] = atan2(d.x, -d.y)
			elif str(p["state"]) == "climbing":
				brain["climb"] = float(brain.get("climb", 0.0)) + dt
				var t := clampf(float(brain["climb"]) / float(tenc.get("climb_time", 0.9)), 0.0, 1.0)
				var np2 := board_point(e, tenc).lerp(hatch_point(e, tenc), t)
				p["pos"] = [np2.x, np2.y]
				if t >= 1.0:
					p["state"] = "aboard"
					_set_state(e, brain, "starting")
					return "cockpit_closed"
		"starting":
			if float(brain["t_state"]) < dt * 1.5:
				return "startup"
			if float(brain["t_state"]) >= float(tenc.get("startup_time", 3.2)):
				e["engine"] = "running"
				_set_state(e, brain, "engage")
				brain["cooldown"] = 1.0
				return "active"
	return ""


## Who notices the player: the pilot sees a hot mech (heat signature) or a suited
## figure close by. A shot fired at the mech also alerts (handled by Session).
static func detects(e: Dictionary, player: Dictionary, tenc: Dictionary, te: Dictionary) -> bool:
	var ppos := Content.v2(e["pilot"]["pos"])
	if player.get("mech_valid", false):
		var r := clampf(float(tenc.get("pilot_detect_base", 300.0)) + maxf(0.0, float(player["mech_heat"]) - 60.0) * float(te.get("detect_per_degree", 4.0)),
			0.0, float(te.get("detect_max", 620.0)))
		if ppos.distance_to(player["mech_pos"]) <= r:
			return true
	if player.get("foot", false) and ppos.distance_to(player["foot_pos"]) <= float(tenc.get("pilot_detect_foot", 230.0)):
		return true
	return false


## The mech was disabled while the pilot was still outside: they run away.
static func flee(e: Dictionary) -> void:
	var p: Dictionary = e.get("pilot", {})
	if p.is_empty():
		return
	if str(p["state"]) in ["outside", "climbing"]:
		p["state"] = "fled"


static func tick_flee(e: Dictionary, tenc: Dictionary, dt: float) -> void:
	var p: Dictionary = e.get("pilot", {})
	if p.is_empty() or str(p["state"]) != "fled":
		return
	var away := Content.v2(p["pos"]) - Content.v2(e["pos"])
	if away.length() < 1.0:
		away = Vector2(0, -1)
	var np := Content.v2(p["pos"]) + away.normalized() * float(tenc.get("pilot_speed", 150.0)) * dt
	p["pos"] = [np.x, np.y]
	p["facing"] = atan2(away.x, -away.y)
	if np.distance_to(Content.v2(e["pos"])) > float(tenc.get("flee_distance", 700.0)):
		p["state"] = "gone"


## Loading mid-sequence resolves forward to a stable state, never replays it.
static func resolve_on_load(e: Dictionary) -> void:
	var p: Dictionary = e.get("pilot", {})
	var ai := str(e["ai"])
	if ai == "wreck":
		if not p.is_empty() and str(p["state"]) in ["outside", "climbing", "fled"]:
			p["state"] = "gone"
		return
	if ai in ["alerted", "boarding", "starting"]:
		e["ai"] = "return"
		e["engine"] = "running"
		if not p.is_empty():
			p["state"] = "aboard"


static func _set_state(e: Dictionary, brain: Dictionary, st: String) -> void:
	e["ai"] = st
	brain["t_state"] = 0.0
