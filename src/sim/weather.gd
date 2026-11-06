class_name Weather
extends RefCounted
## One weather system with two states: CLEAR and SANDSTORM (stored as plain data
## in state.weather and saved). A storm never appears instantly:
##   clear → building (intensity ramps up) → storm (hold) → fading → clear
## Effects scale with intensity × the location's storm exposure (zone
## "storm_exposure": refuge ≈ 0.08, canyon/ravine ≈ 0.45, open sand = 1):
##   cooling efficiency drops (dust ingestion, clogged airflow), sand abrasion
##   rises with open shutters, suit exposure grows, hot wind adds ambient heat,
##   and visibility shrinks enemy/turret detection ranges.

const STATES := ["clear", "building", "storm", "fading"]


static func create(tw: Dictionary) -> Dictionary:
	return {"state": "clear", "intensity": 0.0, "t": 0.0, "peak": 0.85, "hold": 120.0,
		"next": float(tw.get("first_storm_after", 420.0)), "ramp": float(tw.get("build_time", 45.0))}


static func is_storm(w: Dictionary) -> bool:
	return str(w.get("state", "clear")) != "clear"


## Advances the weather. Returns an event: "" | "storm_coming" | "storm_peak" | "storm_fading" | "storm_over".
static func step(w: Dictionary, tw: Dictionary, dt: float, dynamic: bool, rng: RandomNumberGenerator) -> String:
	w["t"] = float(w["t"]) + dt
	match str(w["state"]):
		"clear":
			w["intensity"] = 0.0
			if dynamic and float(w["t"]) >= float(w["next"]):
				start(w, tw, rng, float(tw.get("build_time", 45.0)))
				return "storm_coming"
		"building":
			var ramp := maxf(float(w.get("ramp", tw.get("build_time", 45.0))), 0.5)
			w["intensity"] = move_toward(float(w["intensity"]), float(w["peak"]), float(w["peak"]) * dt / ramp)
			if float(w["intensity"]) >= float(w["peak"]) - 0.001:
				w["state"] = "storm"
				w["t"] = 0.0
				return "storm_peak"
		"storm":
			w["intensity"] = move_toward(float(w["intensity"]), float(w["peak"]), dt * 0.2)
			if float(w["t"]) >= float(w["hold"]) and (dynamic or bool(w.get("auto_end", true))):
				stop(w, tw, float(tw.get("fade_time", 40.0)))
				return "storm_fading"
		"fading":
			var ramp2 := maxf(float(w.get("ramp", tw.get("fade_time", 40.0))), 0.5)
			w["intensity"] = move_toward(float(w["intensity"]), 0.0, float(w["peak"]) * dt / ramp2)
			if float(w["intensity"]) <= 0.001:
				clear(w, tw, rng)
				return "storm_over"
	return ""


static func start(w: Dictionary, tw: Dictionary, rng: RandomNumberGenerator, ramp: float) -> void:
	w["state"] = "building"
	w["t"] = 0.0
	w["ramp"] = ramp
	var pk: Array = tw.get("peak_range", [0.7, 1.0])
	w["peak"] = rng.randf_range(float(pk[0]), float(pk[1])) if float(w.get("forced_peak", -1.0)) < 0.0 else float(w["forced_peak"])
	var hr: Array = tw.get("hold_range", [90.0, 150.0])
	w["hold"] = rng.randf_range(float(hr[0]), float(hr[1]))


static func stop(w: Dictionary, tw: Dictionary, ramp: float) -> void:
	if str(w["state"]) == "clear":
		return
	w["state"] = "fading"
	w["t"] = 0.0
	w["ramp"] = ramp


static func clear(w: Dictionary, tw: Dictionary, rng: RandomNumberGenerator) -> void:
	w["state"] = "clear"
	w["intensity"] = 0.0
	w["t"] = 0.0
	var cr: Array = tw.get("clear_range", [300.0, 540.0])
	w["next"] = rng.randf_range(float(cr[0]), float(cr[1]))


## Storm intensity felt at a zone (0..1).
static func felt(w: Dictionary, zone: Dictionary) -> float:
	return clampf(float(w.get("intensity", 0.0)) * float(zone.get("storm_exposure", 1.0)), 0.0, 1.0)


## Returns a copy of the zone with storm effects folded in (thermal + suit).
static func apply(zone: Dictionary, w: Dictionary, tw: Dictionary) -> Dictionary:
	var i := felt(w, zone)
	if i <= 0.0:
		return zone
	var z := zone.duplicate()
	z["cooling"] = float(z.get("cooling", 1.0)) * (1.0 - float(tw.get("cooling_penalty", 0.4)) * i)
	z["abrasion"] = float(z.get("abrasion", 1.0)) + float(tw.get("abrasion_add", 8.0)) * i
	z["suit"] = float(z.get("suit", 1.0)) * (1.0 + float(tw.get("suit_penalty", 0.9)) * i)
	z["ambient"] = float(z.get("ambient", 58.0)) + float(tw.get("ambient_add", 3.0)) * i
	z["storm"] = i
	return z


## Detection/visibility multiplier for something standing in `zone`.
static func visibility(w: Dictionary, zone: Dictionary, tw: Dictionary) -> float:
	return 1.0 - float(tw.get("visibility_penalty", 0.45)) * felt(w, zone)
