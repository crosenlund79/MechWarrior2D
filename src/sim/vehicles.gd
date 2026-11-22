class_name Vehicles
extends RefCounted
## Chassis catalogue (data/vehicles.json): Eisenwolf Marder (start), Krähe Falke
## (light, fast), Eisenwolf Bär (heavy). Car state: mech.chassis (driven id),
## mech.owned_chassis {id: true}. Fitted upgrade lines stay with the driver and
## apply to whichever chassis is driven, so no chassis becomes obsolete.


static func data() -> Dictionary:
	return Content.data("vehicles")


static func defs() -> Dictionary:
	return data().get("chassis", {})


static func order() -> Array:
	return data().get("order", defs().keys())


static func def(id: String) -> Dictionary:
	return defs().get(id, defs().get(start_id(), {}))


static func start_id() -> String:
	return str(data().get("start", "marder"))


static func ensure(m: Dictionary) -> void:
	if not (m.get("owned_chassis") is Dictionary):
		m["owned_chassis"] = {}
	m["owned_chassis"][start_id()] = true
	if not defs().has(str(m.get("chassis", ""))) or not m["owned_chassis"].has(str(m.get("chassis", ""))):
		m["chassis"] = start_id()


## Car tuning with the chassis' character applied on top of the upgrades.
static func apply(t: Dictionary, chassis: String) -> Dictionary:
	var d := def(chassis)
	t["max_speed"] = float(t.get("max_speed", 560.0)) * float(d.get("speed", 1.0))
	t["accel"] = float(t.get("accel", 400.0)) * float(d.get("accel", 1.0))
	t["grip"] = float(t.get("grip", 1450.0)) * float(d.get("grip", 1.0))
	t["integrity"] = float(t.get("integrity", 100.0)) * float(d.get("integrity", 1.0))
	for k in ["turn_rate", "turn_rate_full_speed", "reverse_turn_rate", "reverse_turn_rate_full_speed"]:
		if t.has(k):
			t[k] = float(t[k]) * float(d.get("turn", 1.0))
	t["damage_taken"] = float(d.get("armor", 1.0))
	t["chassis"] = chassis
	return t


static func body_asset(chassis: String) -> String:
	return str(def(chassis).get("body", "car.body"))


static func for_sale(node: String, m: Dictionary) -> Array:
	var out: Array = []
	for id in order():
		if node in def(str(id)).get("sold", []) and not m.get("owned_chassis", {}).has(id):
			out.append(id)
	return out
