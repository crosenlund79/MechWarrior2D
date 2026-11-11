class_name Loot
extends RefCounted
## Physical ground loot: creature materials and salvage lie in the world as
## visible items until picked up (state.world.loot = [{id, item, n, pos}]).
## Rarity comes from data/items.json (common, uncommon, rare, legendary).
## The car scoops loot up when it rolls slowly over it (cargo permitting); on
## foot the pilot picks it up with Interact.

const RARITIES := ["common", "uncommon", "rare", "legendary"]


static func rarity(item: String) -> String:
	return str(Content.items.get(item, {}).get("rarity", "common"))


static func bulk(item: String) -> int:
	return int(Content.items.get(item, {}).get("bulk", 1))


## Adds loot items scattered around `at` (deterministic offsets from rng).
static func spawn(world: Dictionary, at: Vector2, drops: Dictionary, rng: RandomNumberGenerator, spread: float = 90.0) -> Array:
	if not world.has("loot") or not (world["loot"] is Array):
		world["loot"] = []
	if not world.has("next_loot"):
		world["next_loot"] = 1
	var made: Array = []
	var k := 0
	for item in drops:
		var n := int(drops[item])
		if n <= 0 or not Content.is_item(str(item)):
			continue
		var a := rng.randf() * TAU + k * 2.1
		var p := at + Vector2.from_angle(a) * rng.randf_range(spread * 0.4, spread)
		var id := "loot_%d" % int(world["next_loot"])
		world["next_loot"] = int(world["next_loot"]) + 1
		var entry := {"id": id, "item": str(item), "n": n, "pos": [p.x, p.y]}
		world["loot"].append(entry)
		made.append(entry)
		k += 1
	return made


static func find(world: Dictionary, id: String) -> int:
	var arr: Array = world.get("loot", [])
	for i in arr.size():
		if str(arr[i]["id"]) == id:
			return i
	return -1


## Rolls a drop table: {item: [min, max, chance]} → {item: n}.
static func roll(table: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var out := {}
	for item in table:
		var r: Array = table[item]
		if rng.randf() <= float(r[2] if r.size() > 2 else 1.0):
			var n := rng.randi_range(int(r[0]), int(r[1]))
			if n > 0:
				out[item] = n
	return out
