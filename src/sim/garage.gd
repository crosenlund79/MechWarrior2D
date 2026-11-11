class_name Garage
extends RefCounted
## Refuge garage: car modifications bought with salvage and hunt materials.
## Pure data. Module definitions and costs live in data/tuning.json "garage";
## the fitted levels live in state.mech.upgrades {module: level}.
##
## Effects (all multiplicative on the base tuning, so balance stays in one file):
##   armor   → +integrity            cooling → × cooling_coeff
##   tires   → × grip, × accel       weapon  → × damage, × cooldown
##   rig     → + cargo bulk, × tracker range


const MODULES := ["armor", "cooling", "tires", "weapon", "rig"]


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


## Effect value of a module at its fitted level (key = effect name).
static func effect(tg: Dictionary, upgrades: Dictionary, module: String, key: String, default_value: float) -> float:
	var n := level(upgrades, module)
	if n <= 0:
		return default_value
	var lv: Array = defs(tg).get(module, {}).get("levels", [])
	return float(lv[mini(n, lv.size()) - 1].get(key, default_value))


static func can_afford(cost: Dictionary, have: Callable) -> bool:
	for item in cost:
		if int(have.call(str(item))) < int(cost[item]):
			return false
	return true


## Car tuning with the fitted modules applied.
static func car_tuning(base: Dictionary, tg: Dictionary, upgrades: Dictionary) -> Dictionary:
	var t := base.duplicate()
	t["integrity"] = float(base.get("integrity", 100.0)) + effect(tg, upgrades, "armor", "integrity", 0.0)
	t["grip"] = float(base.get("grip", 1300.0)) * effect(tg, upgrades, "tires", "grip_mult", 1.0)
	t["accel"] = float(base.get("accel", 300.0)) * effect(tg, upgrades, "tires", "accel_mult", 1.0)
	t["max_speed"] = float(base.get("max_speed", 420.0)) * effect(tg, upgrades, "tires", "speed_mult", 1.0)
	return t


static func thermal_tuning(base: Dictionary, tg: Dictionary, upgrades: Dictionary) -> Dictionary:
	var t := base.duplicate()
	t["cooling_coeff"] = float(base.get("cooling_coeff", 0.15)) * effect(tg, upgrades, "cooling", "cooling_mult", 1.0)
	return t


static func weapon_tuning(base: Dictionary, tg: Dictionary, upgrades: Dictionary) -> Dictionary:
	var t := base.duplicate()
	t["damage"] = float(base.get("damage", 5.0)) * effect(tg, upgrades, "weapon", "damage_mult", 1.0)
	t["cooldown"] = float(base.get("cooldown", 0.3)) * effect(tg, upgrades, "weapon", "cooldown_mult", 1.0)
	return t


static func cargo_capacity(base_capacity: int, tg: Dictionary, upgrades: Dictionary) -> int:
	return base_capacity + int(effect(tg, upgrades, "rig", "cargo", 0.0))


static func tracker_range(base_range: float, tg: Dictionary, upgrades: Dictionary) -> float:
	return base_range * effect(tg, upgrades, "rig", "tracker_mult", 1.0)


## Human-readable effect lines for the next level vs now: [[key, now, next], ...].
static func preview(tg: Dictionary, upgrades: Dictionary, module: String) -> Array:
	var nxt := next_level(tg, upgrades, module)
	var out: Array = []
	for k in nxt:
		if k == "cost":
			continue
		out.append([k, effect(tg, upgrades, module, k, 0.0 if not k.ends_with("_mult") else 1.0), float(nxt[k])])
	return out
