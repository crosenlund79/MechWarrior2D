class_name Journey
extends RefCounted
## The continental journey (Ersthafen → Stahlheim). Pure data over
## data/journey.json (nodes, edges, start, goal, cargo) and the save's
## state.journey:
##   {node, from, visited{}, discovered{}, completed{}, delivered, cargo_intact}
## A node is a physical location (settlement, territory or the hub); edges are
## two-way routes with a fuel cost. The sealed cargo is a persistent objective,
## never an inventory item.

const SITE_KEYS := ["enemies", "creatures", "tracks", "turrets", "world"]

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var d = SafeFile.read_json("res://data/journey.json")
		_data = d if d is Dictionary else {"nodes": {}, "edges": [], "start": "", "goal": ""}
	return _data


static func node(id: String) -> Dictionary:
	return data().get("nodes", {}).get(id, {})


static func nodes() -> Dictionary:
	return data().get("nodes", {})


static func neighbors(id: String) -> Array:
	var out: Array = []
	for e in data().get("edges", []):
		if e[0] == id:
			out.append(str(e[1]))
		elif e[1] == id:
			out.append(str(e[0]))
	return out


static func edge_fuel(a: String, b: String) -> float:
	for e in data().get("edges", []):
		if (e[0] == a and e[1] == b) or (e[0] == b and e[1] == a):
			return float(e[2])
	return 0.0


## Node whose map is this location id ("" if none).
static func node_for_location(loc_id: String) -> String:
	for id in nodes():
		if str(nodes()[id].get("location", "")) == loc_id:
			return id
	return ""


static func is_safe(id: String) -> bool:
	return str(node(id).get("kind", "")) in ["settlement", "hub"]


static func create() -> Dictionary:
	var start := str(data().get("start", "ersthafen"))
	var j := {"node": start, "from": "", "visited": {start: true}, "discovered": {start: true}, "completed": {}, "delivered": false,
		"cargo_intact": true, "course": ""}
	for n in neighbors(start):
		j["discovered"][n] = true
	j["completed"][start] = true
	return j


## Marks arrival at a node: visited, its neighbours discovered, settlements count
## as completed on arrival, the hub completes the journey (cargo delivered).
static func arrive(j: Dictionary, id: String) -> Array:
	var events: Array = []
	if not bool(j["visited"].get(id, false)):
		events.append("first_visit")
	j["from"] = str(j.get("node", ""))
	j["node"] = id
	j["visited"][id] = true
	j["discovered"][id] = true
	for n in neighbors(id):
		if not bool(j["discovered"].get(n, false)):
			j["discovered"][n] = true
			events.append("discovered:" + n)
	if is_safe(id) and not bool(j["completed"].get(id, false)):
		j["completed"][id] = true
		events.append("completed")
	if id == str(data().get("goal", "")) and not bool(j.get("delivered", false)):
		j["delivered"] = true
		events.append("delivered")
	return events


static func sanitize(j) -> Dictionary:
	var fresh := create()
	if not (j is Dictionary):
		return fresh
	for k in fresh:
		if not j.has(k) or typeof(j[k]) != typeof(fresh[k]):
			j[k] = fresh[k]
	if not nodes().has(str(j["node"])):
		j["node"] = fresh["node"]
	for key in ["visited", "discovered", "completed"]:
		var clean := {}
		for n in j[key]:
			if nodes().has(str(n)) and bool(j[key][n]):
				clean[str(n)] = true
		j[key] = clean
	j["visited"][str(j["node"])] = true
	j["discovered"][str(j["node"])] = true
	return j


## First step on the shortest route a → b (by fuel), or "" if unreachable/same.
static func next_hop(a: String, b: String) -> String:
	if a == b:
		return ""
	var dist := {a: 0.0}
	var prev := {}
	var open: Array = [a]
	while not open.is_empty():
		open.sort_custom(func(x, y): return float(dist[x]) < float(dist[y]))
		var cur: String = open.pop_front()
		if cur == b:
			break
		for n in neighbors(cur):
			var nd := float(dist[cur]) + edge_fuel(cur, n)
			if not dist.has(n) or nd < float(dist[n]):
				dist[n] = nd
				prev[n] = cur
				open.append(n)
	if not prev.has(b):
		return ""
	var step := b
	while str(prev.get(step, "")) != a:
		step = str(prev[step])
	return step


## Nearest safe node (settlement/hub) from a node, by route fuel.
static func nearest_safe(a: String) -> String:
	var best := ""
	var bd := INF
	for id in nodes():
		if not is_safe(id) or id == a:
			continue
		var hop := next_hop(a, id)
		if hop == "":
			continue
		var d := 0.0
		var cur := a
		var guard := 0
		while cur != id and guard < 20:
			var nx := next_hop(cur, id)
			d += edge_fuel(cur, nx)
			cur = nx
			guard += 1
		if d < bd:
			bd = d
			best = id
	return best
