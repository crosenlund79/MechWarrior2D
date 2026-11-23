class_name Contracts
extends RefCounted
## Jäger contracts (settlement job boards). Plain data in state.contracts:
##   {active: [contract], offers: {node: [contract]}, done: {id: n}, next: int, paid: int}
## A contract: {id, kind, title, node (territory), species, count, progress,
##   poi, reward, xp, giver, status ("active" | "ready"), story (bool), repeat}
## Kinds: hunt (kill N of a species in a territory), cull (kill N creatures of
## any kind there), apex (a named creature), investigate (discover a POI),
## recover (search an expedition site). Authored story contracts come from
## data/contracts.json; repeatable ones are generated from the creatures and
## POIs that really exist in nearby territories (never impossible objectives).

const MAX_ACTIVE := 4
const KINDS := ["hunt", "cull", "apex", "investigate", "recover", "rivals"]


static func create() -> Dictionary:
	return {"active": [], "offers": {}, "done": {}, "next": 1, "paid": 0}


static func sanitize(c) -> Dictionary:
	var d := create()
	if not (c is Dictionary):
		return d
	for k in d:
		if not c.has(k) or typeof(c[k]) != typeof(d[k]):
			if c.has(k) and typeof(c[k]) in [TYPE_INT, TYPE_FLOAT] and typeof(d[k]) in [TYPE_INT, TYPE_FLOAT]:
				continue
			c[k] = d[k]
	var keep: Array = []
	for a in c["active"]:
		if a is Dictionary and str(a.get("kind", "")) in KINDS and a.has("id"):
			a["progress"] = int(a.get("progress", 0))
			a["count"] = maxi(1, int(a.get("count", 1)))
			keep.append(a)
	c["active"] = keep
	c["next"] = maxi(1, int(c["next"]))
	return c


static func authored() -> Dictionary:
	return Content.data("contracts").get("contracts", {})


## Board offers at a settlement: authored contracts whose story condition is met,
## plus up to three generated ones (cached until taken or the board refreshes).
static func board(cs: Dictionary, node: String, flags: Dictionary, rank: int, tier: int) -> Array:
	var out: Array = []
	for id in authored():
		var a: Dictionary = authored()[id]
		if not (node in a.get("boards", [node])) and not a.get("boards", []).is_empty():
			continue
		if cs["done"].has(id) and not bool(a.get("repeat", false)):
			continue
		if _is_active(cs, id):
			continue
		var need := str(a.get("requires", ""))
		if need != "" and not bool(flags.get(need, false)):
			continue
		var gone := str(a.get("until", ""))
		if gone != "" and bool(flags.get(gone, false)):
			continue
		if rank < int(a.get("rank", 1)):
			continue
		var c := a.duplicate(true)
		c["id"] = id
		c["story"] = bool(a.get("story", false))
		c["progress"] = 0
		c["giver"] = node
		out.append(c)
	if not cs["offers"].has(node) or cs["offers"][node].is_empty():
		cs["offers"][node] = generate(cs, node, tier)
	for g in cs["offers"][node]:
		out.append(g)
	return out


static func _is_active(cs: Dictionary, id: String) -> bool:
	for a in cs["active"]:
		if str(a["id"]) == id:
			return true
	return false


## Generated repeatable contracts for nearby territories (1–2 hops).
static func generate(cs: Dictionary, node: String, tier: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s_%d" % [node, int(cs["next"])])
	var near: Array = []
	for n in Journey.neighbors(node):
		if not Journey.is_safe(str(n)):
			near.append(str(n))
		for n2 in Journey.neighbors(str(n)):
			if not Journey.is_safe(str(n2)) and not (str(n2) in near) and str(n2) != node:
				near.append(str(n2))
	var out: Array = []
	var tries := 0
	while out.size() < 3 and tries < 12 and not near.is_empty():
		tries += 1
		var t := str(near[rng.randi() % near.size()])
		var loc := Content.location(str(Journey.node(t).get("location", "")))
		var species := {}
		for d in loc.get("creatures", []):
			var sp := str(d.get("species", ""))
			if sp != "" and not bool(d.get("apex", false)) and not bool(d.get("story", false)):
				species[sp] = int(species.get(sp, 0)) + 1
		var nt := int(Journey.node(t).get("tier", tier))
		var roll := rng.randi() % 3
		var c := {}
		if roll == 0 and not species.is_empty():
			var sp2 := str(species.keys()[rng.randi() % species.size()])
			var n := mini(int(species[sp2]), 3 if sp2 in ["skirr", "aschenlaeufer"] else 1)
			var val := float(Content.tuning.get("creatures", {}).get(sp2, {}).get("bounty", 60))
			c = {"kind": "hunt", "title": "CT_HUNT", "species": sp2, "count": n, "reward": int(round(val * n * (1.0 + 0.35 * nt) / 10.0)) * 10}
		elif roll == 1 and not species.is_empty():
			var total := 0
			for k in species:
				total += int(species[k])
			var n2 := clampi(int(total * 0.5), 2, 6)
			c = {"kind": "cull", "title": "CT_CULL", "species": "", "count": n2, "reward": int(round((90 + 45 * n2) * (1.0 + 0.3 * nt) / 10.0)) * 10}
		else:
			var pois: Array = []
			for p in loc.get("pois", []):
				if str(p.get("kind", "")) == "expedition":
					pois.append(p)
			if pois.is_empty():
				continue
			var p2: Dictionary = pois[rng.randi() % pois.size()]
			c = {"kind": "recover", "title": "CT_RECOVER", "poi": str(p2["id"]), "count": 1, "reward": int(round(120 * (1.0 + 0.4 * nt) / 10.0)) * 10}
		c["id"] = "gen_%s_%d_%d" % [node, int(cs["next"]), out.size()]
		c["node"] = t
		c["xp"] = int(c["reward"] / 6)
		c["progress"] = 0
		c["giver"] = node
		c["story"] = false
		var dup := false
		for o in out:
			if str(o["kind"]) == str(c["kind"]) and str(o["node"]) == t and str(o.get("species", "")) == str(c.get("species", "")):
				dup = true
		if not dup:
			out.append(c)
	return out


static func accept(cs: Dictionary, c: Dictionary, node: String) -> String:
	if cs["active"].size() >= MAX_ACTIVE:
		return "CT_FULL"
	if _is_active(cs, str(c["id"])):
		return "CT_TAKEN"
	var a := c.duplicate(true)
	a["status"] = "active"
	a["progress"] = 0
	cs["active"].append(a)
	if cs["offers"].has(node):
		var left: Array = []
		for o in cs["offers"][node]:
			if str(o["id"]) != str(c["id"]):
				left.append(o)
		cs["offers"][node] = left
	return ""


static func abandon(cs: Dictionary, id: String) -> bool:
	for i in cs["active"].size():
		if str(cs["active"][i]["id"]) == id and not bool(cs["active"][i].get("story", false)):
			cs["active"].remove_at(i)
			return true
	return false


## Game events → progress. ev: {type: "kill"|"discover"|"search"|"flag",
## node, species, creature, poi, flag}. Returns contracts that became ready.
static func on_event(cs: Dictionary, ev: Dictionary) -> Array:
	var ready: Array = []
	for a in cs["active"]:
		if str(a.get("status", "")) == "ready":
			continue
		var hit := false
		var at_node := str(a.get("node", "")) == "" or str(a.get("node", "")) == str(ev.get("node", ""))
		match str(a["kind"]):
			"hunt":
				hit = ev["type"] == "kill" and at_node and str(a.get("species", "")) == str(ev.get("species", ""))
			"cull":
				hit = ev["type"] == "kill" and at_node
			"apex":
				hit = ev["type"] == "kill" and str(a.get("creature", "")) == str(ev.get("creature", ""))
			"investigate":
				hit = ev["type"] in ["discover", "search"] and str(a.get("poi", "")) == str(ev.get("poi", ""))
			"recover":
				hit = ev["type"] == "search" and str(a.get("poi", "")) == str(ev.get("poi", ""))
			"rivals":
				hit = ev["type"] == "rival" and at_node
		if str(a.get("flag", "")) != "" and ev["type"] == "flag" and str(ev.get("flag", "")) == str(a["flag"]):
			hit = true
		if hit:
			a["progress"] = int(a["progress"]) + 1
			if int(a["progress"]) >= int(a["count"]):
				a["status"] = "ready"
				ready.append(a)
	return ready


## Pays every ready contract. Returns [{id, reward, xp, flag}].
static func turn_in(cs: Dictionary) -> Array:
	var paid: Array = []
	var keep: Array = []
	for a in cs["active"]:
		if str(a.get("status", "")) == "ready":
			paid.append({"id": a["id"], "reward": int(a.get("reward", 0)), "xp": int(a.get("xp", 0)), "flag": str(a.get("on_complete", "")),
				"title": a.get("title", ""), "story": bool(a.get("story", false))})
			cs["done"][a["id"]] = int(cs["done"].get(a["id"], 0)) + 1
			cs["paid"] = int(cs["paid"]) + 1
			if str(a["id"]).begins_with("gen_"):
				cs["next"] = int(cs["next"]) + 1
				cs["offers"].erase(str(a.get("giver", "")))
		else:
			keep.append(a)
	cs["active"] = keep
	return paid
