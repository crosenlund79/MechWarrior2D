class_name Garage
extends RefCounted
## Eisenwolf Werke garage: car upgrades bought with MONEY (no crafting), gated by
## the Jäger hunting rank. Pure data. Lines, levels, prices, rank requirements
## and effects live in data/tuning.json "shop"; fitted levels in
## state.mech.upgrades {line: level}.
##
## Effects combine across lines: additive keys (integrity, cargo) are summed,
## multiplicative keys (*_mult) are multiplied.
##   chassis → +integrity, +cargo        engine  → ×speed, ×accel
##   turbo   → ×accel, ×speed, ×heat      armor   → +integrity
##   tires   → ×grip, ×accel              cooling → ×cooling
##   weapons → ×damage, ×cooldown, ×range, ×bullet speed
##   cargo   → +cargo, ×tracker range

const MODULES := ["chassis", "engine", "turbo", "armor", "tires", "cooling", "weapons", "cargo"]
## Fitted levels from before the economy rework map onto the new lines.
const LEGACY := {"weapon": "weapons", "rig": "cargo"}


static func defs(tg: Dictionary) -> Dictionary:
	return tg.get("modules", {})


static func level(upgrades: Dictionary, module: String) -> int:
	return int(upgrades.get(module, 0))


static func max_level(tg: Dictionary, module: String) -> int:
	return defs(tg).get(module, {}).get("levels", []).size()


## The level entry that WOULD be fitted next (or {} at max).
static func next_level(tg: Dictionary, upgrades: Dictionary, module: String) -> Dictionary:
	var lv: Array = defs(tg).get(module, {}).get("levels", [])
	var n := level(upgrades, module)
	return lv[n] if n < lv.size() else {}


static func current_level(tg: Dictionary, upgrades: Dictionary, module: String) -> Dictionary:
	var lv: Array = defs(tg).get(module, {}).get("levels", [])
	var n := mini(level(upgrades, module), lv.size())
	return lv[n - 1] if n > 0 else {}


## Effect value of ONE line at its fitted level.
static func effect(tg: Dictionary, upgrades: Dictionary, module: String, key: String, default_value: float) -> float:
	var cur := current_level(tg, upgrades, module)
	return float(cur.get(key, default_value)) if not cur.is_empty() else default_value


## Combined effect of all lines for one key.
static func total(tg: Dictionary, upgrades: Dictionary, key: String) -> float:
	var mult := key.ends_with("_mult")
	var v := 1.0 if mult else 0.0
	for m in MODULES:
		var cur := current_level(tg, upgrades, m)
		if cur.has(key):
			v = v * float(cur[key]) if mult else v + float(cur[key])
	return v


## "" if the next level can be bought, else a reason key.
static func check(tg: Dictionary, upgrades: Dictionary, module: String, money: int, rank: int) -> String:
	var nxt := next_level(tg, upgrades, module)
	if nxt.is_empty():
		return "GARAGE_MAXED"
	if rank < int(nxt.get("rank", 1)):
		return "GARAGE_RANK_LOCKED"
	if money < int(nxt.get("price", 0)):
		return "GARAGE_NO_MONEY"
	return ""


## Car tuning with the fitted lines applied.
static func car_tuning(base: Dictionary, tg: Dictionary, upgrades: Dictionary) -> Dictionary:
	var t := base.duplicate()
	t["integrity"] = float(base.get("integrity", 100.0)) + total(tg, upgrades, "integrity")
	t["grip"] = float(base.get("grip", 1300.0)) * total(tg, upgrades, "grip_mult")
	t["accel"] = float(base.get("accel", 300.0)) * total(tg, upgrades, "accel_mult")
	t["max_speed"] = float(base.get("max_speed", 460.0)) * total(tg, upgrades, "speed_mult")
	return t


static func thermal_tuning(base: Dictionary, tg: Dictionary, upgrades: Dictionary) -> Dictionary:
	var t := base.duplicate()
	t["cooling_coeff"] = float(base.get("cooling_coeff", 0.15)) * total(tg, upgrades, "cooling_mult")
	t["move_heat"] = float(base.get("move_heat", 1.0)) * total(tg, upgrades, "heat_mult")
	return t


static func weapon_tuning(base: Dictionary, tg: Dictionary, upgrades: Dictionary) -> Dictionary:
	var t := base.duplicate()
	t["damage"] = float(base.get("damage", 5.0)) * total(tg, upgrades, "damage_mult")
	t["cooldown"] = float(base.get("cooldown", 0.3)) * total(tg, upgrades, "cooldown_mult")
	t["range"] = float(base.get("range", 700.0)) * total(tg, upgrades, "range_mult")
	t["speed"] = float(base.get("speed", 1200.0)) * total(tg, upgrades, "bullet_mult")
	return t


static func cargo_capacity(base_capacity: int, tg: Dictionary, upgrades: Dictionary) -> int:
	return base_capacity + int(total(tg, upgrades, "cargo"))


static func tracker_range(base_range: float, tg: Dictionary, upgrades: Dictionary) -> float:
	return base_range * total(tg, upgrades, "tracker_mult")


## Readable effect lines for the next level vs now: [[key, now, next], ...].
static func preview(tg: Dictionary, upgrades: Dictionary, module: String) -> Array:
	var nxt := next_level(tg, upgrades, module)
	var out: Array = []
	for k in nxt:
		if k in ["price", "rank", "name"]:
			continue
		out.append([k, effect(tg, upgrades, module, k, 1.0 if str(k).ends_with("_mult") else 0.0), float(nxt[k])])
	return out


## Migrates fitted levels from the material-cost garage (armor, cooling, tires,
## weapon, rig) onto the money shop lines, clamped to each line's maximum.
static func migrate_upgrades(old: Dictionary, tg: Dictionary) -> Dictionary:
	var out := {}
	for k in old:
		var line: String = LEGACY.get(str(k), str(k))
		if line in MODULES:
			out[line] = clampi(int(old[k]), 0, max_level(tg, line))
	return out
