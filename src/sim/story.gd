class_name Story
extends RefCounted
## The Kern-7 campaign (data/story.json): beats that fire once when a game event
## matches. Pure functions over state.story = {flags, seen, act, objective,
## activated}; Session applies the returned actions (cards, flags, objective,
## money, act, contract, ending) and owns all side effects.


static func data() -> Dictionary:
	return Content.data("story")


static func beats() -> Array:
	return data().get("beats", [])


static func create() -> Dictionary:
	return {"flags": {}, "seen": {}, "act": 1, "objective": {}, "activated": 0}


static func sanitize(s) -> Dictionary:
	var d := create()
	if not (s is Dictionary):
		return d
	for k in d:
		if not s.has(k) or typeof(s[k]) != typeof(d[k]):
			if s.has(k) and typeof(s[k]) in [TYPE_INT, TYPE_FLOAT] and typeof(d[k]) in [TYPE_INT, TYPE_FLOAT]:
				continue
			s[k] = d[k]
	s["act"] = clampi(int(s["act"]), 1, 4)
	s["activated"] = maxi(0, int(s["activated"]))
	return s


static func flag(s: Dictionary, f: String) -> bool:
	return bool(s.get("flags", {}).get(f, false))


## Every condition of a beat against an event: {event, node, poi, creature, flag, count}.
static func matches(b: Dictionary, s: Dictionary, ev: Dictionary) -> bool:
	var w: Dictionary = b.get("when", {})
	if str(w.get("event", "")) != str(ev.get("event", "")):
		return false
	for key in ["node", "poi", "creature", "flag"]:
		if w.has(key) and str(w[key]) != str(ev.get(key, "")):
			return false
	if b.has("count") and int(b["count"]) != int(ev.get("count", -1)):
		return false
	if b.has("region") and Journey.region(str(ev.get("node", ""))) != str(b["region"]):
		return false
	if bool(b.get("territory", false)) and Journey.is_safe(str(ev.get("node", ""))):
		return false
	for f in b.get("requires", []):
		if not flag(s, str(f)):
			return false
	for f in b.get("unless", []):
		if flag(s, str(f)):
			return false
	return true


## Beats that fire for this event (marked seen). Returns their action lists, in order.
static func on_event(s: Dictionary, ev: Dictionary) -> Array:
	var out: Array = []
	for b in beats():
		var id := str(b.get("id", ""))
		if bool(s["seen"].get(id, false)):
			continue
		if matches(b, s, ev):
			s["seen"][id] = true
			out.append({"beat": id, "do": b.get("do", [])})
	return out


static func cast(id: String) -> Dictionary:
	return data().get("cast", {}).get(id, {"name": id})


## Does a location item (poi / creature def) exist yet? ("requires": [flags])
static func available(s: Dictionary, item: Dictionary) -> bool:
	for f in item.get("requires", []):
		if not flag(s, str(f)):
			return false
	return true


## Developer: mark every beat up to (and including) `beat` as seen and apply its
## flags (no cards, no money). Returns the flags set.
static func advance_to(s: Dictionary, beat: String) -> Array:
	var set_flags: Array = []
	for b in beats():
		s["seen"][str(b["id"])] = true
		for a in b.get("do", []):
			if a.has("flag"):
				s["flags"][str(a["flag"])] = true
				set_flags.append(str(a["flag"]))
			if a.has("act"):
				s["act"] = int(a["act"])
			if a.has("objective"):
				s["objective"] = a["objective"].duplicate()
		if str(b["id"]) == beat:
			break
	return set_flags
