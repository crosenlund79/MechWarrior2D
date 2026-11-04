extends Node
## Autoload `Session`: owns the running game — state, simulation tick, mode
## changes, interactions, autosave. Views read `state` and call the request
## methods below; nothing authoritative lives in scene nodes.

signal started
signal ended(reason: String)
signal notice(key: String, args: Array)
signal mode_changed(mode: String)
signal mech_event(event: String)
signal saved(ok: bool, message: String)

var running := false
var state: Dictionary = {}
var slot := 0
var loc: Dictionary = {}

## Input intents, written by views (or the autotest driver) every frame.
var drive_throttle := 0.0
var drive_turn := 0.0
var walk_dir := Vector2.ZERO

## Runtime-only (not saved).
var task: Dictionary = {}          # {"type": "repair"|"salvage", "target": id, "t": s, "duration": s}
var mech_zone: Dictionary = {}
var pilot_zone: Dictionary = {}
var collapse_t := 0.0
var time_scale := 1.0
var save_status := "—"
var last_save_unix := 0
var _autosave_t := 0.0
var _suit_warned := 100.0
var recovered_from_backup := false
## Physics query supplied by the world view: Callable(Vector2) -> bool (spot is free).
var spot_is_free: Callable = Callable()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().set_auto_accept_quit(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if running:
			save_now("quit")
		get_tree().quit()


func tun(section: String) -> Dictionary:
	Content.ensure()
	return Content.tuning.get(section, {})


# ---------------------------------------------------------------- lifecycle

func start_new(slot_index: int) -> void:
	Content.ensure()
	loc = Content.location()
	slot = slot_index
	state = GameState.create(loc, slot)
	recovered_from_backup = false
	_begin()
	Log.info("session", "new_game", {"slot": slot, "id": state["id"]})
	save_now("new_game")


func continue_slot(slot_index: int) -> String:
	Content.ensure()
	var res := Saves.load_slot(slot_index)
	if not res["ok"]:
		Log.warn("session", "continue_failed", {"slot": slot_index, "error": res["error"]})
		return str(res["error"])
	loc = Content.location(str(res["state"].get("location", Content.DEFAULT_LOCATION)))
	slot = slot_index
	state = GameState.sanitize(res["state"], loc)
	recovered_from_backup = bool(res.get("recovered", false))
	_begin()
	Log.info("session", "continued", {"slot": slot, "recovered": recovered_from_backup})
	if recovered_from_backup:
		notice.emit("NOTICE_SAVE_RECOVERED", [])
	return ""


func _begin() -> void:
	task = {}
	collapse_t = 0.0
	_autosave_t = 0.0
	drive_throttle = 0.0
	drive_turn = 0.0
	walk_dir = Vector2.ZERO
	_suit_warned = float(state["pilot"]["suit"])
	running = true
	_refresh_zones()
	started.emit()


func end_session(reason: String = "menu") -> void:
	if not running:
		return
	save_now(reason)
	running = false
	state = {}
	ended.emit(reason)


func save_now(reason: String = "manual") -> bool:
	if state.is_empty():
		return false
	var err := Saves.save_slot(slot, state)
	if err == "":
		last_save_unix = int(Time.get_unix_time_from_system())
		save_status = "saved (%s) %s" % [reason, Time.get_time_string_from_system()]
		saved.emit(true, reason)
		return true
	save_status = "SAVE FAILED: " + err
	Log.error("session", "save_failed", {"reason": reason, "error": err})
	saved.emit(false, err)
	return false


# ---------------------------------------------------------------- helpers

func mode() -> String:
	return str(state.get("mode", ""))


func mech() -> Dictionary:
	return state["mech"]


func pilot() -> Dictionary:
	return state["pilot"]


func mech_pos() -> Vector2:
	return Content.v2(state["mech"]["pos"])


func pilot_pos() -> Vector2:
	return Content.v2(state["pilot"]["pos"])


func actor_pos() -> Vector2:
	return mech_pos() if mode() != "foot" else pilot_pos()


func repair_item() -> String:
	return str(tun("repair").get("item", "radiator_core"))


func parts_available() -> int:
	return GameState.count(pilot()["pack"], repair_item()) + GameState.count(mech()["storage"], repair_item())


func _refresh_zones() -> void:
	mech_zone = Content.zone_at(loc, mech_pos())
	pilot_zone = Content.zone_at(loc, pilot_pos()) if mode() == "foot" else mech_zone


func engine_on() -> bool:
	return str(mech()["engine"]) == "running"


# ---------------------------------------------------------------- tick

func _physics_process(delta: float) -> void:
	if not running:
		return
	tick(delta * time_scale)


func tick(dt: float) -> void:
	state["playtime"] = float(state["playtime"]) + dt
	_refresh_zones()
	var m := mech()
	var max_speed := float(tun("mech").get("max_speed", 150.0))
	var speed_frac := float(m["speed"]) / max_speed
	var was_band := Thermal.band(float(m["heat"]), tun("thermal"))
	for ev in Thermal.step(m, mech_zone, tun("thermal"), dt, speed_frac, engine_on()):
		match ev:
			"warn":
				notice.emit("NOTICE_HEAT_WARNING", [])
				mech_event.emit("warn")
			"shutdown":
				state["stats"]["overheats"] = int(state["stats"]["overheats"]) + 1
				notice.emit("NOTICE_SHUTDOWN", [])
				mech_event.emit("shutdown")
				Log.info("sim", "overheat_shutdown", {"heat": snappedf(m["heat"], 0.1), "radiator": snappedf(m["radiator"], 0.01)})
			"restart":
				if mode() == "mech":
					m["engine"] = "running"
				notice.emit("NOTICE_RESTART", [])
				mech_event.emit("restart")
			"abrasion":
				mech_event.emit("abrasion")
	if was_band != Thermal.band(float(m["heat"]), tun("thermal")):
		mech_event.emit("band")
	_tick_suit(dt)
	_tick_task(dt)
	if mode() == "collapsed":
		collapse_t += dt
		if collapse_t >= float(tun("suit").get("collapse_fade", 2.5)):
			_recover_from_collapse()
	_autosave_t += dt
	if _autosave_t >= float(Content.tuning.get("autosave_interval", 60.0)):
		_autosave_t = 0.0
		save_now("autosave")


func _tick_suit(dt: float) -> void:
	var p := pilot()
	var ts := tun("suit")
	var mx := float(ts.get("max", 100.0))
	match mode():
		"foot":
			p["suit"] = maxf(0.0, float(p["suit"]) - float(ts.get("drain", 1.4)) * float(pilot_zone.get("suit", 1.0)) * dt)
			if float(p["suit"]) <= 0.0:
				p["strain"] = float(p["strain"]) + dt / maxf(float(ts.get("strain_time", 10.0)), 0.1)
				if float(p["strain"]) >= 1.0:
					_collapse()
		"mech":
			if float(mech()["heat"]) < float(tun("thermal").get("cabin_safe_temp", 105.0)):
				p["suit"] = minf(mx, float(p["suit"]) + float(ts.get("recover_in_mech", 9.0)) * dt)
			else:
				p["suit"] = maxf(0.0, float(p["suit"]) - float(ts.get("hot_cabin_drain", 0.5)) * dt)
			p["strain"] = maxf(0.0, float(p["strain"]) - float(ts.get("strain_recover", 0.25)) * dt)
	var s := float(p["suit"])
	for level in [50.0, 25.0, 10.0, 0.0]:
		if _suit_warned > level and s <= level and mode() == "foot":
			notice.emit("NOTICE_SUIT_%d" % int(level), [])
			mech_event.emit("suit_warning")
	_suit_warned = s


func _tick_task(dt: float) -> void:
	if task.is_empty():
		return
	if mode() != "foot" or walk_dir.length() > 0.1:
		notice.emit("NOTICE_TASK_CANCELLED", [])
		task = {}
		return
	task["t"] = float(task["t"]) + dt
	if float(task["t"]) >= float(task["duration"]):
		var done := task.duplicate()
		task = {}
		match str(done["type"]):
			"salvage":
				_finish_salvage(str(done["target"]))
			"repair":
				_finish_repair()


# ---------------------------------------------------------------- driving / walking

## Called by the mech view each physics frame. Returns the desired velocity.
func mech_velocity(dt: float) -> Vector2:
	var m := mech()
	var tm := tun("mech")
	var drag := float(mech_zone.get("drag", 1.0))
	var max_s := float(tm.get("max_speed", 150.0)) * drag
	var rev_s := float(tm.get("reverse_speed", 65.0)) * drag
	var speed := float(m["speed"])
	var throttle := drive_throttle if (mode() == "mech" and engine_on()) else 0.0
	var turn := drive_turn if (mode() == "mech" and engine_on()) else 0.0
	var target := max_s * throttle if throttle >= 0.0 else rev_s * throttle
	var rate := float(tm.get("accel", 95.0))
	if absf(throttle) < 0.05:
		rate = float(tm.get("coast_drag", 60.0)) if engine_on() else float(tm.get("brake", 240.0))
	elif signf(target) != signf(speed) and absf(speed) > 1.0:
		rate = float(tm.get("brake", 240.0))
	if absf(speed) > max_s + 1.0:
		rate = maxf(rate, float(tm.get("brake", 240.0)) * 0.5)  # sand drag bleeds speed
	speed = move_toward(speed, target, rate * dt)
	var tr := lerpf(float(tm.get("turn_rate", 1.5)), float(tm.get("turn_rate_full_speed", 0.95)),
		clampf(absf(speed) / float(tm.get("max_speed", 150.0)), 0.0, 1.0))
	m["heading"] = wrapf(float(m["heading"]) + turn * tr * dt, -PI, PI)
	m["speed"] = speed
	var h := float(m["heading"])
	return Vector2(sin(h), -cos(h)) * speed


## Called by the mech view after move_and_slide with the real result.
func commit_mech(pos: Vector2, real_velocity: Vector2) -> void:
	var m := mech()
	var old := Content.v2(m["pos"])
	m["pos"] = [pos.x, pos.y]
	state["stats"]["distance"] = float(state["stats"]["distance"]) + old.distance_to(pos)
	var h := float(m["heading"])
	var fwd := Vector2(sin(h), -cos(h))
	# Collisions bleed speed: keep only what actually moved along the heading.
	var along := real_velocity.dot(fwd)
	if absf(along) < absf(float(m["speed"])):
		m["speed"] = along
	if mode() != "foot":
		pilot()["pos"] = [pos.x, pos.y]


func pilot_velocity() -> Vector2:
	if mode() != "foot":
		return Vector2.ZERO
	var dir := walk_dir.limit_length(1.0)
	return dir * float(tun("pilot").get("speed", 100.0))


func commit_pilot(pos: Vector2, facing: float) -> void:
	pilot()["pos"] = [pos.x, pos.y]
	pilot()["facing"] = facing


# ---------------------------------------------------------------- mode changes

func exit_mech() -> bool:
	if mode() != "mech":
		return false
	var m := mech()
	if absf(float(m["speed"])) > float(tun("mech").get("exit_max_speed", 15.0)):
		notice.emit("NOTICE_TOO_FAST_TO_EXIT", [])
		return false
	var h := float(m["heading"])
	var spot := Vector2.INF
	for off in [Vector2(0, 150), Vector2(-140, 20), Vector2(140, 20), Vector2(0, -150), Vector2(-120, 120), Vector2(120, 120)]:
		var p: Vector2 = mech_pos() + off.rotated(h)
		if not spot_is_free.is_valid() or spot_is_free.call(p):
			spot = p
			break
	if spot == Vector2.INF:
		notice.emit("NOTICE_NO_ROOM_TO_EXIT", [])
		return false
	if engine_on():
		m["engine"] = "off"
	m["speed"] = 0.0
	pilot()["pos"] = [spot.x, spot.y]
	state["mode"] = "foot"
	_suit_warned = float(pilot()["suit"])
	_refresh_zones()
	mode_changed.emit("foot")
	mech_event.emit("hatch")
	Log.info("session", "exit_mech", {"heat": snappedf(m["heat"], 0.1)})
	return true


func enter_mech() -> bool:
	if mode() != "foot":
		return false
	if pilot_pos().distance_to(mech_pos()) > float(tun("mech").get("enter_radius", 125.0)):
		return false
	task = {}
	var m := mech()
	var pack: Dictionary = pilot()["pack"]
	for item in pack.keys():
		GameState.add(m["storage"], item, int(pack[item]))
	pack.clear()
	if str(m["engine"]) != "shutdown":
		m["engine"] = "running"
	state["mode"] = "mech"
	pilot()["pos"] = m["pos"].duplicate()
	_refresh_zones()
	mode_changed.emit("mech")
	mech_event.emit("hatch")
	Log.info("session", "enter_mech", {"suit": snappedf(pilot()["suit"], 0.1)})
	save_now("enter_mech")
	return true


func toggle_shutters() -> void:
	if mode() != "mech":
		return
	mech()["shutters_open"] = not bool(mech()["shutters_open"])
	notice.emit("NOTICE_SHUTTERS_OPEN" if mech()["shutters_open"] else "NOTICE_SHUTTERS_CLOSED", [])
	mech_event.emit("shutters")


func _collapse() -> void:
	state["mode"] = "collapsed"
	collapse_t = 0.0
	task = {}
	notice.emit("NOTICE_COLLAPSE", [])
	mode_changed.emit("collapsed")
	Log.info("session", "collapse", {"pos": state["pilot"]["pos"]})


func _recover_from_collapse() -> void:
	var p := pilot()
	var w: Dictionary = state["world"]
	if GameState.total(p["pack"]) > 0:
		var id := "drop_%d" % int(w["next_drop"])
		w["next_drop"] = int(w["next_drop"]) + 1
		w["drops"].append({"id": id, "pos": p["pos"].duplicate(), "items": p["pack"].duplicate()})
		p["pack"] = {}
	p["suit"] = float(tun("suit").get("after_collapse_protection", 25.0))
	p["strain"] = 0.0
	state["stats"]["collapses"] = int(state["stats"]["collapses"]) + 1
	state["mode"] = "mech"
	p["pos"] = mech()["pos"].duplicate()
	if str(mech()["engine"]) != "shutdown":
		mech()["engine"] = "running"
	_refresh_zones()
	mode_changed.emit("mech")
	notice.emit("NOTICE_RECOVERED", [])
	save_now("collapse")


# ---------------------------------------------------------------- interactions

## What the player can do right now. Each entry: {action, kind, target, label, enabled}.
func interactions() -> Array:
	var out: Array = []
	if not running:
		return out
	match mode():
		"mech":
			out.append({"action": "interact", "kind": "exit", "target": "mech", "label": "ACT_EXIT_MECH",
				"enabled": absf(float(mech()["speed"])) <= float(tun("mech").get("exit_max_speed", 15.0))})
			out.append({"action": "service", "kind": "shutters", "target": "mech",
				"label": "ACT_CLOSE_SHUTTERS" if mech()["shutters_open"] else "ACT_OPEN_SHUTTERS", "enabled": true})
		"foot":
			var pp := pilot_pos()
			var r := float(tun("pilot").get("interact_radius", 85.0))
			var near := _nearest_pickup(pp, r)
			if not near.is_empty():
				out.append(near)
			if pp.distance_to(mech_pos()) <= float(tun("mech").get("enter_radius", 125.0)):
				out.append({"action": "interact", "kind": "enter", "target": "mech", "label": "ACT_ENTER_MECH", "enabled": true})
			if pp.distance_to(mech_pos()) <= float(tun("mech").get("service_radius", 150.0)) and float(mech()["radiator"]) < 0.995:
				out.append({"action": "service", "kind": "repair", "target": "mech",
					"label": "ACT_REPAIR" if parts_available() > 0 else "ACT_REPAIR_NEED_PART",
					"enabled": parts_available() > 0})
	return out


func _nearest_pickup(pp: Vector2, r: float) -> Dictionary:
	var best := {}
	var best_d := r
	var taken: Dictionary = state["world"]["taken"]
	for s in loc.get("salvage", []):
		if taken.has(s["id"]):
			continue
		var d := pp.distance_to(Content.v2(s["pos"]))
		if d <= best_d:
			best_d = d
			best = {"action": "interact", "kind": "salvage", "target": s["id"], "label": "ACT_SALVAGE", "enabled": true}
	for dr in state["world"]["drops"]:
		var d2 := pp.distance_to(Content.v2(dr["pos"]))
		if d2 <= best_d:
			best_d = d2
			best = {"action": "interact", "kind": "drop", "target": dr["id"], "label": "ACT_PICK_UP_PACK", "enabled": true}
	if not best.is_empty() and GameState.total(pilot()["pack"]) >= int(tun("pilot").get("pack_capacity", 2)) and best["kind"] == "salvage":
		best["enabled"] = false
		best["label"] = "ACT_PACK_FULL"
	return best


## Performs the first enabled interaction bound to `action` ("interact" or "service").
func request(action: String) -> bool:
	if not running or mode() == "collapsed":
		return false
	for it in interactions():
		if it["action"] != action:
			continue
		if not it["enabled"]:
			if it["kind"] == "exit":
				notice.emit("NOTICE_TOO_FAST_TO_EXIT", [])
			elif it["kind"] == "repair":
				notice.emit("NOTICE_NEED_PART", [])
			elif it["kind"] == "salvage":
				notice.emit("NOTICE_PACK_FULL", [])
			continue
		match str(it["kind"]):
			"exit":
				return exit_mech()
			"enter":
				return enter_mech()
			"shutters":
				toggle_shutters()
				return true
			"salvage":
				return _start_task("salvage", str(it["target"]), float(tun("salvage").get("duration", 1.6)))
			"drop":
				return _pick_up_drop(str(it["target"]))
			"repair":
				return _start_task("repair", "mech", float(tun("repair").get("duration", 3.0)))
	return false


func _start_task(kind: String, target: String, duration: float) -> bool:
	if not task.is_empty():
		return false
	task = {"type": kind, "target": target, "t": 0.0, "duration": duration}
	mech_event.emit("task_" + kind)
	return true


func task_progress() -> float:
	if task.is_empty():
		return -1.0
	return clampf(float(task["t"]) / maxf(float(task["duration"]), 0.01), 0.0, 1.0)


func _finish_salvage(id: String) -> void:
	for s in loc.get("salvage", []):
		if s["id"] == id and not state["world"]["taken"].has(id):
			state["world"]["taken"][id] = true
			GameState.add(pilot()["pack"], str(s["item"]), int(s.get("count", 1)))
			state["stats"]["salvaged"] = int(state["stats"]["salvaged"]) + 1
			notice.emit("NOTICE_SALVAGED", [str(s["item"])])
			mech_event.emit("pickup")
			Log.info("session", "salvaged", {"id": id, "item": s["item"]})
			save_now("salvage")
			return


func _pick_up_drop(id: String) -> bool:
	var drops: Array = state["world"]["drops"]
	for i in drops.size():
		if drops[i]["id"] == id:
			for item in drops[i]["items"]:
				GameState.add(pilot()["pack"], item, int(drops[i]["items"][item]))
			drops.remove_at(i)
			notice.emit("NOTICE_PACK_RECOVERED", [])
			mech_event.emit("pickup")
			save_now("pickup")
			return true
	return false


func _finish_repair() -> void:
	var item := repair_item()
	if GameState.count(pilot()["pack"], item) > 0:
		GameState.add(pilot()["pack"], item, -1)
	elif GameState.count(mech()["storage"], item) > 0:
		GameState.add(mech()["storage"], item, -1)
	else:
		notice.emit("NOTICE_NEED_PART", [])
		return
	var m := mech()
	var before := float(m["radiator"])
	m["radiator"] = minf(1.0, before + float(tun("repair").get("restore", 0.55)))
	state["stats"]["repairs"] = int(state["stats"]["repairs"]) + 1
	notice.emit("NOTICE_REPAIRED", [int(round(float(m["radiator"]) * 100.0))])
	mech_event.emit("repaired")
	Log.info("session", "repaired", {"before": snappedf(before, 0.01), "after": snappedf(m["radiator"], 0.01)})
	save_now("repair")


# ---------------------------------------------------------------- guidance

## One short contextual objective line (translation key).
func hint() -> String:
	if not running:
		return ""
	var m := mech()
	var md := mode()
	if md == "collapsed":
		return "HINT_COLLAPSED"
	if str(m["engine"]) == "shutdown":
		return "HINT_SHUTDOWN_FOOT" if md == "foot" else "HINT_SHUTDOWN"
	if md == "foot" and float(pilot()["suit"]) < 30.0:
		return "HINT_RETURN_NOW"
	var has_part := parts_available() > 0
	if float(m["radiator"]) < 0.6:
		if has_part:
			return "HINT_REPAIR" if md == "foot" else "HINT_EXIT_TO_REPAIR"
		if not state["world"]["drops"].is_empty():
			return "HINT_RECOVER_PACK"
		if md == "foot":
			return "HINT_SCAVENGE"
		return "HINT_FIND_CORE"
	if md == "foot":
		return "HINT_RETURN"
	return "HINT_CONTINUE"


func nearest_objective() -> Vector2:
	if not running:
		return Vector2.INF
	var from := actor_pos()
	if parts_available() > 0 and float(mech()["radiator"]) < 0.6:
		return mech_pos() if mode() == "foot" else Vector2.INF
	var best := Vector2.INF
	for dr in state["world"]["drops"]:
		var p := Content.v2(dr["pos"])
		if best == Vector2.INF or from.distance_to(p) < from.distance_to(best):
			best = p
	if best != Vector2.INF:
		return best
	for s in loc.get("salvage", []):
		if state["world"]["taken"].has(s["id"]):
			continue
		var p2 := Content.v2(s["pos"])
		if best == Vector2.INF or from.distance_to(p2) < from.distance_to(best):
			best = p2
	if best == Vector2.INF and mode() == "foot":
		return mech_pos()
	return best


# ---------------------------------------------------------------- debug actions (dev overlay / autotest)

func debug(action: String, value: float = 0.0) -> void:
	if not running:
		return
	match action:
		"heat":
			mech()["heat"] = clampf(float(mech()["heat"]) + value, 0.0, Content.t("thermal", "max_temp", 135.0))
		"damage":
			mech()["radiator"] = clampf(float(mech()["radiator"]) - value, 0.0, 1.0)
		"give_part":
			GameState.add(pilot()["pack"] if mode() == "foot" else mech()["storage"], repair_item(), 1)
		"suit":
			pilot()["suit"] = clampf(value, 0.0, Content.t("suit", "max", 100.0))
			_suit_warned = float(pilot()["suit"])
		"timescale":
			time_scale = clampf(value, 0.1, 20.0)
	Log.info("debug", action, {"value": value})
