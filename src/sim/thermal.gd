class_name Thermal
extends RefCounted
## Mech thermal model — pure functions over plain data (testable, scene-free).
##
##   heat_in  = engine_heat (idle + move·speed) + solar·zone.solar
##   heat_out = cooling_coeff · efficiency · airflow · (T − zone.ambient)
##   dT/dt    = (heat_in − heat_out) / heat_capacity
## efficiency = lerp(min_efficiency, 1, radiator condition)
## airflow    = 1 with shutters open, shutters_closed_airflow when closed.
## Equilibrium: T_eq = ambient + heat_in / (coeff · efficiency · airflow).
##
## Wear: open shutters let sand abrade the radiator while moving
## (abrasion_wear · speed_frac · zone.abrasion). Above critical_temp the engine
## shuts down and the radiator takes heat damage until it cools below restart_temp.


static func efficiency(condition: float, tun: Dictionary) -> float:
	var mn := float(tun.get("min_efficiency", 0.18))
	return lerpf(mn, 1.0, clampf(condition, 0.0, 1.0))


static func airflow(shutters_open: bool, tun: Dictionary) -> float:
	return 1.0 if shutters_open else float(tun.get("shutters_closed_airflow", 0.45))


static func heat_in(engine_on: bool, speed_frac: float, zone: Dictionary, tun: Dictionary) -> float:
	var q := float(tun.get("solar_heat", 0.8)) * float(zone.get("solar", 1.0))
	if engine_on:
		q += float(tun.get("idle_heat", 0.9)) + float(tun.get("move_heat", 2.0)) * clampf(absf(speed_frac), 0.0, 1.0)
	return q


static func cooling_rate(m: Dictionary, zone: Dictionary, tun: Dictionary) -> float:
	var k := float(tun.get("cooling_coeff", 0.12)) * float(zone.get("cooling", 1.0))
	var dt_amb := float(m["heat"]) - float(zone.get("ambient", 58.0))
	return k * efficiency(float(m["radiator"]), tun) * airflow(bool(m["shutters_open"]), tun) * dt_amb


static func equilibrium(m: Dictionary, engine_on: bool, speed_frac: float, zone: Dictionary, tun: Dictionary) -> float:
	var k := float(tun.get("cooling_coeff", 0.12)) * float(zone.get("cooling", 1.0)) * efficiency(float(m["radiator"]), tun) * airflow(bool(m["shutters_open"]), tun)
	return float(zone.get("ambient", 58.0)) + heat_in(engine_on, speed_frac, zone, tun) / maxf(k, 0.0001)


## Advances one mech dictionary by dt. Returns a list of event names:
## "warn", "shutdown", "restart", "abrasion", "heat_damage".
static func step(m: Dictionary, zone: Dictionary, tun: Dictionary, dt: float, speed_frac: float, engine_on: bool) -> Array[String]:
	var events: Array[String] = []
	var cap := maxf(float(tun.get("heat_capacity", 1.0)), 0.01)
	var before := float(m["heat"])
	var d := (heat_in(engine_on, speed_frac, zone, tun) - cooling_rate(m, zone, tun)) / cap
	m["heat"] = clampf(before + d * dt, 0.0, float(tun.get("max_temp", 135.0)))
	var warn := float(tun.get("warn_temp", 98.0))
	var crit := float(tun.get("critical_temp", 115.0))
	if before < warn and m["heat"] >= warn:
		events.append("warn")
	if m["engine"] != "shutdown" and m["heat"] >= crit:
		m["engine"] = "shutdown"
		events.append("shutdown")
	elif m["engine"] == "shutdown" and m["heat"] <= float(tun.get("restart_temp", 90.0)):
		m["engine"] = "off"
		events.append("restart")
	if m["heat"] > crit:
		m["radiator"] = maxf(0.0, float(m["radiator"]) - float(tun.get("overheat_damage", 0.004)) * dt)
		events.append("heat_damage")
	if bool(m["shutters_open"]) and absf(speed_frac) > 0.05:
		var wear := float(tun.get("abrasion_wear", 0.0008)) * absf(speed_frac) * float(zone.get("abrasion", 1.0)) * dt
		if wear > 0.0:
			m["radiator"] = maxf(0.0, float(m["radiator"]) - wear)
			if float(zone.get("abrasion", 1.0)) > 4.0:
				events.append("abrasion")
	return events


## Heat state for UI: "normal" | "warm" | "warning" | "critical".
static func band(heat: float, tun: Dictionary) -> String:
	if heat >= float(tun.get("critical_temp", 115.0)):
		return "critical"
	if heat >= float(tun.get("warn_temp", 98.0)):
		return "warning"
	if heat >= float(tun.get("warn_temp", 98.0)) - 12.0:
		return "warm"
	return "normal"
