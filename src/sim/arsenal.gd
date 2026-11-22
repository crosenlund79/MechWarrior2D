class_name Arsenal
extends RefCounted
## Roof-mount weapon families and their ammunition (data/weapons.json).
## Car state: mech.weapon (mounted id), mech.owned_weapons {id: true},
## mech.ammo {id: rounds}. The upgrade lines still apply: "weapons" (barrels:
## damage/rate/range/velocity for every family), "mounts" (turret slew, swap
## time, recoil) and "ammo" (capacity). Pure functions over plain data.


static func data() -> Dictionary:
	return Content.data("weapons")


static func defs() -> Dictionary:
	return data().get("weapons", {})


static func order() -> Array:
	return data().get("order", defs().keys())


static func def(id: String) -> Dictionary:
	return defs().get(id, {})


static func start_id() -> String:
	return str(data().get("start", "mg"))


## Makes sure a car has a mounted, owned weapon and an ammo table (new games,
## migrated saves). Never takes anything away.
static func ensure(m: Dictionary, tg: Dictionary, upgrades: Dictionary) -> void:
	var s := start_id()
	if not (m.get("owned_weapons") is Dictionary):
		m["owned_weapons"] = {}
	m["owned_weapons"][s] = true
	if not (m.get("ammo") is Dictionary):
		m["ammo"] = {}
	for id in m["owned_weapons"].keys():
		if not defs().has(str(id)):
			m["owned_weapons"].erase(id)
		elif not m["ammo"].has(id):
			m["ammo"][id] = capacity(str(id), tg, upgrades)
	if not defs().has(str(m.get("weapon", ""))) or not m["owned_weapons"].has(str(m.get("weapon", ""))):
		m["weapon"] = s


static func capacity(id: String, tg: Dictionary, upgrades: Dictionary) -> int:
	return int(round(float(def(id).get("ammo", 0)) * Garage.total(tg, upgrades, "ammo_mult")))


## Shot/firing tuning for a family with the fitted lines applied.
static func tuning(id: String, tg: Dictionary, upgrades: Dictionary, base: Dictionary = {}) -> Dictionary:
	var t := base.duplicate()
	for k in def(id):
		t[k] = def(id)[k]
	t["id"] = id
	t["damage"] = float(t.get("damage", 5.0)) * Garage.total(tg, upgrades, "damage_mult")
	t["cooldown"] = float(t.get("cooldown", 0.3)) * Garage.total(tg, upgrades, "cooldown_mult")
	t["range"] = float(t.get("range", 700.0)) * Garage.total(tg, upgrades, "range_mult")
	t["speed"] = float(t.get("speed", 1200.0)) * Garage.total(tg, upgrades, "bullet_mult")
	t["recoil"] = float(t.get("recoil", 1.0)) * Garage.total(tg, upgrades, "recoil_mult")
	return t


static func swap_time(tg: Dictionary, upgrades: Dictionary) -> float:
	return 0.9 * Garage.total(tg, upgrades, "swap_mult")


## Price to fill every owned family to capacity.
static func restock_cost(m: Dictionary, tg: Dictionary, upgrades: Dictionary, price_mult: float = 1.0) -> int:
	var c := 0.0
	for id in m.get("owned_weapons", {}):
		var missing := capacity(str(id), tg, upgrades) - int(m["ammo"].get(id, 0))
		if missing > 0:
			c += missing * float(def(str(id)).get("ammo_price", 1.0))
	return int(ceil(c * price_mult))


## Families sold at a node (by id) that the car does not own yet.
static func for_sale(node: String, m: Dictionary) -> Array:
	var out: Array = []
	for id in order():
		var d := def(str(id))
		if node in d.get("sold", []) and not m.get("owned_weapons", {}).has(id):
			out.append(id)
	return out
