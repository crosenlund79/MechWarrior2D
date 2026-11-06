class_name Turret
extends RefCounted
## Southern Junkers perimeter turret: stationary, rotating gun housing.
## Saved state: {hp, angle, destroyed, salvaged}. Runtime brain: {windup, cooldown, engaged}.
## Rotates (rate-limited) toward a hostile mech inside its range and line of
## sight, telegraphs ~1 s (red laser line), then fires a slow projectile.
## Session limits how many turrets may wind up / fire at the same time.


static func create(d: Dictionary, tt: Dictionary) -> Dictionary:
	return {"hp": float(tt.get("hp", 40.0)), "angle": deg_to_rad(float(d.get("facing_deg", 0.0))), "destroyed": false, "salvaged": false}


## target: {valid, pos, visibility}. los: bool (clear line of sight). allowed: may wind up/fire this tick.
## Returns {fire, event, engaged, windup (0..1)}.
static func step(d: Dictionary, t: Dictionary, brain: Dictionary, target: Dictionary, tt: Dictionary, dt: float, los: bool, allowed: bool) -> Dictionary:
	var out := {"fire": false, "event": "", "engaged": false, "windup": 0.0}
	if bool(t["destroyed"]):
		brain["windup"] = 0.0
		return out
	var pos := Content.v2(d["pos"])
	brain["cooldown"] = maxf(0.0, float(brain.get("cooldown", 1.0)) - dt)
	var rng_ := float(tt.get("range", 480.0)) * float(target.get("visibility", 1.0))
	var tpos: Vector2 = target.get("pos", Vector2.INF)
	var engaged: bool = target.get("valid", false) and pos.distance_to(tpos) <= rng_ and los
	out["engaged"] = engaged
	var rate := float(tt.get("turn_rate", 0.9))
	if engaged:
		var to := tpos - pos
		var want := atan2(to.x, -to.y)
		var err := wrapf(want - float(t["angle"]), -PI, PI)
		t["angle"] = wrapf(float(t["angle"]) + clampf(err, -rate * dt, rate * dt), -PI, PI)
		if not brain.has("engaged") or not bool(brain["engaged"]):
			out["event"] = "turret_alert"
		brain["engaged"] = true
		var w := float(brain.get("windup", 0.0))
		if w > 0.0:
			if not allowed:
				brain["windup"] = 0.0
			else:
				brain["windup"] = w + dt
				if float(brain["windup"]) >= float(tt.get("telegraph", 1.1)):
					brain["windup"] = 0.0
					brain["cooldown"] = float(tt.get("cooldown", 3.8))
					out["fire"] = true
		elif allowed and float(brain["cooldown"]) <= 0.0 and absf(err) < deg_to_rad(float(tt.get("fire_cone_deg", 8.0))):
			brain["windup"] = 0.0001
			out["event"] = "turret_windup"
	else:
		brain["engaged"] = false
		brain["windup"] = 0.0
		# idle: slow scanning sweep around the mounting direction
		var base := deg_to_rad(float(d.get("facing_deg", 0.0)))
		brain["scan"] = float(brain.get("scan", 0.0)) + dt * 0.35
		var want2 := base + sin(float(brain["scan"]) + pos.x * 0.01) * 0.6
		var err2 := wrapf(want2 - float(t["angle"]), -PI, PI)
		t["angle"] = wrapf(float(t["angle"]) + clampf(err2, -rate * 0.4 * dt, rate * 0.4 * dt), -PI, PI)
	out["windup"] = clampf(float(brain.get("windup", 0.0)) / float(tt.get("telegraph", 1.1)), 0.0, 1.0)
	return out


static func muzzle(d: Dictionary, t: Dictionary, tt: Dictionary) -> Vector2:
	return Content.v2(d["pos"]) + Drive.forward(float(t["angle"])) * float(tt.get("muzzle", 50.0))
