class_name Creatures
extends RefCounted
## The thawed-out ecosystem: living species exposed when the ice retreated.
## Pure data + decision functions (scene-free, testable). Session owns the state
## (state.creatures, state.tracks) and applies the returned events.
##
## Species (prototype designs — balance and lore are provisional):
##   skirr     — small pack hunter. Roams near its den, hears engines, circles
##               its prey and lunges (crouch tell → fast dash → bite). Breaks off
##               when hurt or when half the pack is down.
##   grindback — armoured burrower. Lies under the sand; feels VIBRATION (speed).
##               Tunnels at the source (a racing sand mound = the tell) and
##               erupts. Surfaced it paws (tell) and charges in a straight line,
##               then stands dazed with its rear vent open. Armoured front plate.
##   rimeback  — the large quarry. Grazes a long route through the flats leaving
##               deep tracks. Hunted, it roars and cycles telegraphed attacks:
##               charge (lane), tail sweep (arc), brine spit (glowing glands).
##               Breakable parts: horn, two frost glands, tail. Below 55 % it
##               enrages; below 30 % it limps to its lair, bleeding (tracks).
##
## Creature dict: {species, pos, heading, speed, hp, parts{name: hp}, ai, home,
##   pack, dead_at, harvested, respawn_at}. Brain (runtime): {t, cd, goal, lock,
##   dir, tell, roam_t, charges}. AI "dead" is final until respawn.

const SPECIES := ["skirr", "grindback", "rimeback"]
const ATTACK_STATES := ["lunge", "erupt", "charge", "sweep"]


static func create(defn: Dictionary, tun: Dictionary) -> Dictionary:
	var sp := str(defn.get("species", "skirr"))
	var ts: Dictionary = tun.get(sp, {})
	var p := Content.v2(defn.get("spawn", [0, 0]))
	var parts := {}
	var pd: Dictionary = ts.get("parts", {})
	for k in pd:
		if float(pd[k].get("hp", 0.0)) > 0.0:
			parts[k] = float(pd[k]["hp"])
	return {"species": sp, "pos": [p.x, p.y], "heading": deg_to_rad(float(defn.get("heading_deg", 0.0))), "speed": 0.0,
		"hp": float(ts.get("hp", 20.0)), "parts": parts, "ai": "buried" if sp == "grindback" else "roam",
		"home": [p.x, p.y], "pack": str(defn.get("pack", "")), "dead_at": -1.0, "harvested": false, "respawn_at": -1.0,
		"route": defn.get("route", []), "lair": defn.get("lair", [p.x, p.y])}


static func max_hp(c: Dictionary, tun: Dictionary) -> float:
	return float(tun.get(str(c["species"]), {}).get("hp", 20.0))


static func is_dead(c: Dictionary) -> bool:
	return str(c["ai"]) == "dead"


## Can bullets hit it right now? (a buried grindback is under the sand)
static func targetable(c: Dictionary) -> bool:
	return not (str(c["ai"]) in ["dead", "buried", "tunnel"])


## Does it physically block the car right now?
static func solid(c: Dictionary) -> bool:
	return str(c["species"]) != "skirr" and targetable(c)


## Telegraph strength 0..1 and kind, for views.
static func tell(brain: Dictionary) -> Dictionary:
	return {"kind": str(brain.get("tell_kind", "")), "v": float(brain.get("tell", 0.0))}


# --------------------------------------------------------------------------- tick

## Advances one creature. target: {valid, pos, vel, noise, heat, vis, foot}.
## Returns {move: Vector2 desired velocity, events: [ {kind, ...} ]}.
## Event kinds: alert, tell, attack {kind, pos, radius, damage, cooling, push},
## spit {from, dirs}, flee, enrage, burrow, surface, track.
static func step(c: Dictionary, brain: Dictionary, target: Dictionary, tun: Dictionary, dt: float,
		rng: RandomNumberGenerator) -> Dictionary:
	var res := {"move": Vector2.ZERO, "events": []}
	if is_dead(c):
		return res
	var ts: Dictionary = tun.get(str(c["species"]), {})
	brain["t"] = float(brain.get("t", 0.0)) + dt
	brain["cd"] = maxf(0.0, float(brain.get("cd", 0.0)) - dt)
	brain["tell"] = 0.0
	brain["tell_kind"] = ""
	match str(c["species"]):
		"skirr":
			_skirr(c, brain, target, ts, dt, rng, res)
		"grindback":
			_grindback(c, brain, target, ts, dt, rng, res)
		"rimeback":
			_rimeback(c, brain, target, ts, dt, rng, res)
	# Kinematic steering: heading turns toward the move direction (no pivoting
	# while charging), speed eases toward the wanted speed.
	var want: Vector2 = res["move"]
	var turn := float(ts.get("turn_rate", 3.0)) * (0.15 if str(c["ai"]) in ["charge", "lunge"] else 1.0)
	if want.length() > 1.0:
		var wa := atan2(want.x, -want.y)
		var err := wrapf(wa - float(c["heading"]), -PI, PI)
		c["heading"] = wrapf(float(c["heading"]) + clampf(err, -turn * dt, turn * dt), -PI, PI)
	var target_speed := want.length()
	c["speed"] = move_toward(float(c["speed"]), target_speed, float(ts.get("accel", 600.0)) * dt)
	res["move"] = Drive.forward(float(c["heading"])) * float(c["speed"]) if str(c["ai"]) != "lunge" else want
	return res


## How strongly does this creature notice the target? (0 = not at all)
static func _senses(c: Dictionary, target: Dictionary, ts: Dictionary) -> float:
	if not target.get("valid", false):
		return 0.0
	var d := Content.v2(c["pos"]).distance_to(target["pos"])
	var r := float(ts.get("sight", 260.0)) + float(target.get("noise", 0.0)) * float(ts.get("hearing", 600.0))
	r += maxf(0.0, float(target.get("heat", 60.0)) - 80.0) * float(ts.get("heat_sense", 0.0))
	r *= float(target.get("vis", 1.0))
	return clampf(1.0 - d / maxf(r, 1.0), 0.0, 1.0) if d < r else 0.0


static func _go(c: Dictionary, brain: Dictionary, st: String) -> void:
	c["ai"] = st
	brain["t"] = 0.0


static func _to(c: Dictionary, p: Vector2, speed: float) -> Vector2:
	var d := p - Content.v2(c["pos"])
	if d.length() < 12.0:
		return Vector2.ZERO
	return d.normalized() * speed


static func _roam_point(c: Dictionary, brain: Dictionary, radius: float, rng: RandomNumberGenerator) -> Vector2:
	if not brain.has("goal") or float(brain.get("roam_t", 0.0)) <= 0.0 or Content.v2(c["pos"]).distance_to(brain["goal"]) < 40.0:
		var home := Content.v2(c["home"])
		brain["goal"] = home + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(radius * 0.25, radius)
		brain["roam_t"] = rng.randf_range(3.0, 6.5)
	return brain["goal"]


static func _hp_frac(c: Dictionary, ts: Dictionary) -> float:
	return float(c["hp"]) / maxf(float(ts.get("hp", 1.0)), 1.0)


# --------------------------------------------------------------------------- skirr

static func _skirr(c: Dictionary, brain: Dictionary, target: Dictionary, ts: Dictionary, dt: float,
		rng: RandomNumberGenerator, res: Dictionary) -> void:
	var pos := Content.v2(c["pos"])
	var tpos: Vector2 = target.get("pos", pos)
	var dist := pos.distance_to(tpos)
	var home := Content.v2(c["home"])
	brain["roam_t"] = float(brain.get("roam_t", 0.0)) - dt
	var gave_up: bool = not target.get("valid", false) or dist > float(ts.get("give_up", 1100.0)) or pos.distance_to(home) > float(ts.get("leash", 1600.0))
	match str(c["ai"]):
		"roam":
			res["move"] = _to(c, _roam_point(c, brain, float(ts.get("roam_radius", 420.0)), rng), float(ts.get("roam_speed", 90.0)))
			if _senses(c, target, ts) > 0.0 and pos.distance_to(home) < float(ts.get("leash", 1600.0)) * 0.8:
				_go(c, brain, "stalk")
				brain["cd"] = rng.randf_range(0.8, 1.8)
				res["events"].append({"kind": "alert"})
		"stalk":
			if gave_up:
				_go(c, brain, "roam")
				return
			if _hp_frac(c, ts) < float(ts.get("flee_hp", 0.4)) or bool(brain.get("morale_broken", false)):
				_go(c, brain, "flee")
				res["events"].append({"kind": "flee"})
				return
			# circle the prey on a ring, each skirr at its own slot
			var slot := float(brain.get("slot", rng.randf() * TAU))
			brain["slot"] = slot + dt * 0.6
			var ring := tpos + Vector2.from_angle(float(brain["slot"])) * float(ts.get("circle_radius", 260.0))
			res["move"] = _to(c, ring, float(ts.get("run_speed", 330.0)))
			if float(brain["cd"]) <= 0.0 and dist < float(ts.get("lunge_range", 360.0)):
				_go(c, brain, "crouch")
		"crouch":
			# TELL: freezes low and faces the prey, hissing (view: squash + eye glint)
			var to := tpos - pos
			c["heading"] = atan2(to.x, -to.y)
			c["speed"] = 0.0
			brain["tell"] = float(brain["t"]) / float(ts.get("tell_time", 0.55))
			brain["tell_kind"] = "crouch"
			if float(brain["t"]) >= float(ts.get("tell_time", 0.55)):
				var aim: Vector2 = tpos + (target.get("vel", Vector2.ZERO) as Vector2) * 0.22
				brain["dir"] = (aim - pos).normalized()
				brain["hit"] = false
				_go(c, brain, "lunge")
				res["events"].append({"kind": "tell", "tell": "lunge"})
		"lunge":
			res["move"] = (brain.get("dir", Vector2.UP) as Vector2) * float(ts.get("lunge_speed", 700.0))
			c["heading"] = atan2((brain["dir"] as Vector2).x, -(brain["dir"] as Vector2).y)
			c["speed"] = float(ts.get("lunge_speed", 700.0))
			if not bool(brain.get("hit", false)) and dist < float(ts.get("bite_radius", 85.0)):
				brain["hit"] = true
				res["events"].append({"kind": "attack", "attack": "bite", "pos": pos, "radius": float(ts.get("bite_radius", 85.0)) + 30.0,
					"damage": float(ts.get("bite_damage", 4.0)), "cooling": float(ts.get("bite_cooling", 0.02)), "push": 60.0})
			if float(brain["t"]) >= float(ts.get("lunge_time", 0.4)):
				_go(c, brain, "recover")
		"recover":
			res["move"] = _to(c, pos + (pos - tpos).normalized() * 200.0, float(ts.get("roam_speed", 90.0)) * 1.5)
			if float(brain["t"]) >= float(ts.get("recover_time", 0.9)):
				brain["cd"] = rng.randf_range(float(ts.get("cooldown_min", 2.2)), float(ts.get("cooldown_max", 3.6)))
				_go(c, brain, "stalk")
		"flee":
			res["move"] = _to(c, home, float(ts.get("run_speed", 330.0)))
			if pos.distance_to(home) < 120.0:
				_go(c, brain, "roam")
				brain["morale_broken"] = false
	if str(c["ai"]) in ["roam", "flee"] and pos.distance_to(home) < 300.0:
		c["hp"] = minf(float(ts.get("hp", 14.0)), float(c["hp"]) + float(ts.get("heal", 0.5)) * dt)


# --------------------------------------------------------------------------- grindback

static func _grindback(c: Dictionary, brain: Dictionary, target: Dictionary, ts: Dictionary, dt: float,
		rng: RandomNumberGenerator, res: Dictionary) -> void:
	var pos := Content.v2(c["pos"])
	var tpos: Vector2 = target.get("pos", pos)
	var dist := pos.distance_to(tpos)
	var home := Content.v2(c["home"])
	brain["roam_t"] = float(brain.get("roam_t", 0.0)) - dt
	match str(c["ai"]):
		"buried":
			res["move"] = _to(c, _roam_point(c, brain, float(ts.get("roam_radius", 380.0)), rng), float(ts.get("buried_speed", 40.0)))
			# feels vibration: fast cars, running engines, footsteps at close range
			var vib := float(target.get("noise", 0.0))
			var reach := float(ts.get("vibration_base", 140.0)) + vib * float(ts.get("vibration_range", 640.0))
			if target.get("valid", false) and dist < reach and float(brain["cd"]) <= 0.0 and pos.distance_to(home) < float(ts.get("leash", 1400.0)):
				var lead: Vector2 = (target.get("vel", Vector2.ZERO) as Vector2) * float(ts.get("lead_time", 0.8))
				brain["lock"] = tpos + lead.limit_length(320.0)
				_go(c, brain, "tunnel")
				res["events"].append({"kind": "alert"})
		"tunnel":
			# TELL: a sand mound races toward the locked spot; a crack ring opens there
			var lock: Vector2 = brain["lock"]
			res["move"] = _to(c, lock, float(ts.get("tunnel_speed", 420.0)))
			brain["tell"] = clampf(float(brain["t"]) / float(ts.get("tell_time", 1.4)), 0.0, 1.0)
			brain["tell_kind"] = "tremor"
			if float(brain["t"]) >= float(ts.get("tell_time", 1.4)):
				c["pos"] = [lock.x, lock.y] if pos.distance_to(lock) < 140.0 else c["pos"]
				_go(c, brain, "erupt")
				res["events"].append({"kind": "surface"})
				res["events"].append({"kind": "attack", "attack": "erupt", "pos": Content.v2(c["pos"]), "radius": float(ts.get("erupt_radius", 135.0)),
					"damage": float(ts.get("erupt_damage", 14.0)), "cooling": 0.04, "push": 380.0})
				brain["charges"] = 0
		"erupt":
			if float(brain["t"]) >= 0.6:
				_go(c, brain, "paw")
		"paw":
			# TELL: faces the prey, digs in, throws sand back (view + aim lane)
			var to := tpos - pos
			res["move"] = Vector2.ZERO
			var wa := atan2(to.x, -to.y)
			c["heading"] = wrapf(float(c["heading"]) + clampf(wrapf(wa - float(c["heading"]), -PI, PI), -2.5 * dt, 2.5 * dt), -PI, PI)
			c["speed"] = 0.0
			brain["tell"] = clampf(float(brain["t"]) / float(ts.get("paw_time", 0.9)), 0.0, 1.0)
			brain["tell_kind"] = "charge"
			if _hp_frac(c, ts) < float(ts.get("flee_hp", 0.35)) or int(brain.get("charges", 0)) >= int(ts.get("max_charges", 3)) or dist > float(ts.get("give_up", 1000.0)):
				_go(c, brain, "burrow")
				res["events"].append({"kind": "burrow"})
				return
			if float(brain["t"]) >= float(ts.get("paw_time", 0.9)):
				brain["dir"] = Drive.forward(float(c["heading"]))
				brain["hit"] = false
				brain["charges"] = int(brain.get("charges", 0)) + 1
				_go(c, brain, "charge")
				res["events"].append({"kind": "tell", "tell": "charge"})
		"charge":
			var d: Vector2 = brain["dir"]
			res["move"] = d * float(ts.get("charge_speed", 470.0))
			c["speed"] = float(ts.get("charge_speed", 470.0))
			if not bool(brain.get("hit", false)) and dist < float(ts.get("ram_radius", 120.0)):
				brain["hit"] = true
				res["events"].append({"kind": "attack", "attack": "ram", "pos": pos, "radius": float(ts.get("ram_radius", 120.0)) + 40.0,
					"damage": float(ts.get("ram_damage", 11.0)), "cooling": 0.05, "push": 420.0, "dir": d})
			if float(brain["t"]) >= float(ts.get("charge_time", 1.5)) or bool(brain.get("blocked", false)):
				brain["blocked"] = false
				_go(c, brain, "dazed")
		"dazed":
			# vulnerable window: rear vent open (x vent multiplier)
			res["move"] = Vector2.ZERO
			c["speed"] = move_toward(float(c["speed"]), 0.0, 900.0 * dt)
			if float(brain["t"]) >= float(ts.get("daze_time", 2.2)):
				_go(c, brain, "paw")
		"burrow":
			res["move"] = Vector2.ZERO
			if float(brain["t"]) >= 1.1:
				_go(c, brain, "buried")
				brain["cd"] = float(ts.get("rest_after_burrow", 9.0))
				# tunnel away from the threat and lick its wounds
				brain["goal"] = home + (home - tpos).normalized() * 200.0
				brain["roam_t"] = 8.0
	if str(c["ai"]) == "buried":
		c["hp"] = minf(float(ts.get("hp", 90.0)), float(c["hp"]) + float(ts.get("heal", 0.8)) * dt)


# --------------------------------------------------------------------------- rimeback

static func _rimeback(c: Dictionary, brain: Dictionary, target: Dictionary, ts: Dictionary, dt: float,
		rng: RandomNumberGenerator, res: Dictionary) -> void:
	var pos := Content.v2(c["pos"])
	var tpos: Vector2 = target.get("pos", pos)
	var dist := pos.distance_to(tpos)
	var enraged := _hp_frac(c, ts) < float(ts.get("enrage_hp", 0.55))
	var cd_mult := float(ts.get("enrage_cooldown", 0.65)) if enraged else 1.0
	if enraged and not bool(brain.get("enraged", false)):
		brain["enraged"] = true
		res["events"].append({"kind": "enrage"})
	var lair: Vector2 = Content.v2(c.get("lair", ts.get("lair", c["home"])))
	match str(c["ai"]):
		"roam":
			# grazing circuit: walk the route, pause to graze at each waypoint
			var route: Array = c.get("route", ts.get("route", []))
			if route.is_empty():
				res["move"] = _to(c, _roam_point(c, brain, 500.0, rng), float(ts.get("roam_speed", 80.0)))
			else:
				var i := int(brain.get("wp", _nearest_wp(route, pos))) % route.size()
				brain["wp"] = i
				var wp := Content.v2(route[i])
				if pos.distance_to(wp) < 90.0:
					brain["graze"] = float(brain.get("graze", 0.0)) + dt
					if float(brain["graze"]) >= float(ts.get("graze_time", 4.0)):
						brain["graze"] = 0.0
						brain["wp"] = (i + 1) % route.size()
				else:
					res["move"] = _to(c, wp, float(ts.get("roam_speed", 80.0)))
			# heal slowly while calm (a hunt you abandon is not lost forever)
			var floor_hp := float(ts.get("hp", 300.0)) * 0.6
			if float(c["hp"]) < floor_hp:
				c["hp"] = minf(floor_hp, float(c["hp"]) + float(ts.get("heal", 0.6)) * dt)
			if _senses(c, target, ts) > 0.0 or bool(brain.get("provoked", false)):
				brain["provoked"] = false
				_go(c, brain, "roar")
				res["events"].append({"kind": "alert"})
		"roar":
			# TELL: rears and bellows, facing the threat
			_face_toward(c, tpos, 1.6, dt)
			brain["tell"] = clampf(float(brain["t"]) / 1.6, 0.0, 1.0)
			brain["tell_kind"] = "roar"
			if float(brain["t"]) >= float(ts.get("roar_time", 1.6)):
				_go(c, brain, "hunt")
				brain["cd"] = 0.8
		"hunt":
			if not target.get("valid", false) or dist > float(ts.get("give_up", 1600.0)):
				_go(c, brain, "roam")
				return
			if _hp_frac(c, ts) < float(ts.get("flee_hp", 0.3)) and not bool(brain.get("cornered", false)):
				_go(c, brain, "flee")
				res["events"].append({"kind": "flee"})
				return
			# keep a fighting distance and pick an attack that suits the range
			var pref := float(ts.get("preferred_range", 420.0))
			var side := (pos - tpos).normalized().rotated(0.9 if int(brain.get("side", 1)) > 0 else -0.9)
			res["move"] = _to(c, tpos + side * pref, float(ts.get("hunt_speed", 170.0)))
			if float(brain["cd"]) <= 0.0:
				var has_tail := float(c["parts"].get("tail", 0.0)) > 0.0
				var glands := int(float(c["parts"].get("gland_l", 0.0)) > 0.0) + int(float(c["parts"].get("gland_r", 0.0)) > 0.0)
				if dist < float(ts.get("sweep_range", 300.0)) and has_tail:
					_go(c, brain, "sweep_tell")
				elif dist > float(ts.get("spit_min", 380.0)) and dist < float(ts.get("spit_max", 820.0)) and glands > 0 and rng.randf() < 0.45:
					_go(c, brain, "spit_tell")
				elif dist < float(ts.get("charge_max", 950.0)):
					_go(c, brain, "charge_tell")
				brain["side"] = -int(brain.get("side", 1))
		"charge_tell":
			# TELL: lowers its horned head and stamps; a charge lane is drawn
			_face_toward(c, tpos, 1.4, dt)
			brain["tell"] = clampf(float(brain["t"]) / float(ts.get("charge_tell", 1.3)), 0.0, 1.0)
			brain["tell_kind"] = "charge"
			if float(brain["t"]) >= float(ts.get("charge_tell", 1.3)):
				brain["dir"] = Drive.forward(float(c["heading"]))
				brain["hit"] = false
				_go(c, brain, "charge")
				res["events"].append({"kind": "tell", "tell": "charge"})
		"charge":
			var d: Vector2 = brain["dir"]
			res["move"] = d * float(ts.get("charge_speed", 560.0))
			c["speed"] = float(ts.get("charge_speed", 560.0))
			if not bool(brain.get("hit", false)) and dist < float(ts.get("ram_radius", 200.0)):
				brain["hit"] = true
				var dmg := float(ts.get("charge_damage", 20.0)) * (1.0 if float(c["parts"].get("head", 0.0)) > 0.0 else float(ts.get("broken_horn_mult", 0.55)))
				res["events"].append({"kind": "attack", "attack": "charge", "pos": pos + d * 120.0, "radius": float(ts.get("ram_radius", 200.0)),
					"damage": dmg, "cooling": 0.06, "push": 520.0, "dir": d})
			if float(brain["t"]) >= float(ts.get("charge_time", 1.3)) or bool(brain.get("blocked", false)):
				brain["blocked"] = false
				_go(c, brain, "recover")
		"sweep_tell":
			# TELL: tail coils to one side (view: tail swings back, arc shown)
			_face_toward(c, tpos, 0.4, dt)
			brain["tell"] = clampf(float(brain["t"]) / float(ts.get("sweep_tell", 0.9)), 0.0, 1.0)
			brain["tell_kind"] = "sweep"
			if float(brain["t"]) >= float(ts.get("sweep_tell", 0.9)):
				_go(c, brain, "sweep")
				res["events"].append({"kind": "tell", "tell": "sweep"})
				res["events"].append({"kind": "attack", "attack": "sweep", "pos": pos, "radius": float(ts.get("sweep_range", 300.0)) + 40.0,
					"damage": float(ts.get("sweep_damage", 11.0)), "cooling": 0.02, "push": 460.0})
		"sweep":
			if float(brain["t"]) >= 0.35:
				_go(c, brain, "recover")
		"spit_tell":
			# TELL: the frost glands swell and glow
			_face_toward(c, tpos, 2.0, dt)
			brain["tell"] = clampf(float(brain["t"]) / float(ts.get("spit_tell", 1.0)), 0.0, 1.0)
			brain["tell_kind"] = "spit"
			if float(brain["t"]) >= float(ts.get("spit_tell", 1.0)):
				var glands := int(float(c["parts"].get("gland_l", 0.0)) > 0.0) + int(float(c["parts"].get("gland_r", 0.0)) > 0.0)
				var base := (tpos + (target.get("vel", Vector2.ZERO) as Vector2) * 0.5 - pos).normalized()
				var dirs: Array = []
				for k in (1 + glands):
					dirs.append(base.rotated((k - glands * 0.5) * 0.16))
				res["events"].append({"kind": "spit", "from": pos + Drive.forward(float(c["heading"])) * 170.0, "dirs": dirs})
				_go(c, brain, "recover")
		"recover":
			res["move"] = Vector2.ZERO
			if float(brain["t"]) >= float(ts.get("recover_time", 0.9)) * cd_mult:
				brain["cd"] = rng.randf_range(float(ts.get("cooldown_min", 1.6)), float(ts.get("cooldown_max", 3.0))) * cd_mult
				_go(c, brain, "hunt")
		"flee":
			# limps to its lair, bleeding (tracks marked as blood)
			res["move"] = _to(c, lair, float(ts.get("flee_speed", 230.0)))
			brain["bleeding"] = true
			if pos.distance_to(lair) < 160.0:
				brain["cornered"] = true
				_go(c, brain, "roar")
				res["events"].append({"kind": "cornered"})


static func _face_toward(c: Dictionary, p: Vector2, rate: float, dt: float) -> void:
	var to := p - Content.v2(c["pos"])
	var wa := atan2(to.x, -to.y)
	c["heading"] = wrapf(float(c["heading"]) + clampf(wrapf(wa - float(c["heading"]), -PI, PI), -rate * dt, rate * dt), -PI, PI)
	c["speed"] = 0.0


static func _nearest_wp(route: Array, pos: Vector2) -> int:
	var best := 0
	var bd := INF
	for i in route.size():
		var d := pos.distance_to(Content.v2(route[i]))
		if d < bd:
			bd = d
			best = i
	return best


# --------------------------------------------------------------------------- damage

## Which body part a shot segment a→b hits (or ""). Parts carry a local offset
## (rotates with the heading) and a radius; "body" is always present.
static func hit_part(c: Dictionary, a: Vector2, b: Vector2, shot_r: float, ts: Dictionary) -> String:
	var pos := Content.v2(c["pos"])
	var h := float(c["heading"])
	var best := ""
	var best_d := INF
	var pd: Dictionary = ts.get("parts", {})
	for k in pd:
		if k != "body" and float(c["parts"].get(k, 0.0)) <= 0.0 and not bool(pd[k].get("always", false)):
			continue
		var cp := pos + Content.v2(pd[k].get("offset", [0, 0])).rotated(h)
		var d := Combat.seg_dist(a, b, cp)
		if d <= float(pd[k].get("radius", 30.0)) + shot_r and d < best_d:
			best_d = d
			best = k
	return best


## Applies damage to a part. Returns {broken: bool, dealt: float}.
static func damage(c: Dictionary, part: String, amount: float, ts: Dictionary, dazed: bool) -> Dictionary:
	var pd: Dictionary = ts.get("parts", {}).get(part, {})
	var mult := float(pd.get("mult", 1.0))
	if dazed and pd.has("dazed_mult"):
		mult = float(pd["dazed_mult"])
	var dealt := amount * mult
	c["hp"] = maxf(0.0, float(c["hp"]) - dealt)
	var broken := false
	if c["parts"].has(part) and float(c["parts"][part]) > 0.0:
		c["parts"][part] = maxf(0.0, float(c["parts"][part]) - amount)
		broken = float(c["parts"][part]) <= 0.0
	return {"broken": broken, "dealt": dealt}


## Species tuning scaled for a journey tier (tougher, harder-hitting, keener
## animals toward Stahlheim). Tier 1 = the base values.
static var _scaled_cache := {}


static func scaled(tc: Dictionary, tier: int, econ: Dictionary) -> Dictionary:
	var key := "%d_%d" % [tier, tc.hash()]
	if _scaled_cache.has(key):
		return _scaled_cache[key]
	var out := tc.duplicate(true)
	var k := maxf(0.0, float(tier - 1))
	var hp_m := 1.0 + float(econ.get("tier_hp", 0.3)) * k
	var dmg_m := 1.0 + float(econ.get("tier_damage", 0.18)) * k
	var sense_m := 1.0 + float(econ.get("tier_sense", 0.06)) * k
	for sp in SPECIES:
		if not (out.get(sp) is Dictionary):
			continue
		var ts: Dictionary = out[sp]
		ts["hp"] = float(ts.get("hp", 20.0)) * hp_m
		for key2 in ts.keys():
			var ks := str(key2)
			if ks.ends_with("_damage") or ks == "damage":
				ts[ks] = float(ts[ks]) * dmg_m
			elif ks in ["sight", "hearing", "vibration_range"]:
				ts[ks] = float(ts[ks]) * sense_m
		var parts: Dictionary = ts.get("parts", {})
		for pk in parts:
			if float(parts[pk].get("hp", 0.0)) > 0.0:
				parts[pk]["hp"] = float(parts[pk]["hp"]) * hp_m
		if ts.get("glob") is Dictionary:
			ts["glob"]["damage"] = float(ts["glob"].get("damage", 5.0)) * dmg_m
	_scaled_cache[key] = out
	return out
