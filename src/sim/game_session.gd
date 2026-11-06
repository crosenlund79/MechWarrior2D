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
## Combat/presentation events: kind ∈ muzzle, impact, cooling_hit, enemy_windup,
## enemy_alert, enemy_disabled, player_hit. data carries pos/ids.
signal combat_event(kind: String, data: Dictionary)

var running := false
var state: Dictionary = {}
var slot := 0
var loc: Dictionary = {}

## Input intents, written by views (or the autotest driver) every frame.
var drive_throttle := 0.0
var drive_turn := 0.0
var walk_dir := Vector2.ZERO
var aim_point := Vector2.INF     # world point the player's turret aims at
var fire_held := false

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
## Raycast supplied by the world view: Callable(Vector2 from, Vector2 to) -> bool (static obstacle in between).
var shot_blocked: Callable = Callable()
## Combat runtime (not saved): live projectiles, per-enemy AI brains and intents.
var projectiles: Array = []
var brains := {}         # enemy id -> {wp, t_state, windup, cooldown}
var enemy_intents := {}  # enemy id -> {throttle, turn, windup}
var enemy_zones := {}
var gun_angle := 0.0          # = housing_angle (kept for tools/tests)
var housing_angle := 0.0      # world angle of the rotating upper housing (runtime)
var housing_speed := 0.0      # rad/s actually turned last tick (audio)
var _muzzle_i := 0
var _fire_cd := 0.0
var _zone_type := ""
## Developer cheats (F10). Runtime only — never saved, reset on every start/end.
const DEV_DEFAULTS := {"dynamic_weather": true, "invulnerable": false, "aggression": true, "time_scale": 1.0}
var dev := DEV_DEFAULTS.duplicate()
var turret_brains := {}
var turret_view := {}    # id -> {windup, engaged} for views
var storm_here := 0.0    # storm intensity felt by the active actor (0..1)
var _area := ""


## Named discovery areas (location "areas"): the most specific (last) match wins.
func area_at(p: Vector2) -> String:
	var found := ""
	for a in loc.get("areas", []):
		if Geometry2D.is_point_in_polygon(p, Content.poly(a["polygon"])):
			found = str(a["id"])
	return found


func area_name(id: String) -> String:
	for a in loc.get("areas", []):
		if a["id"] == id:
			return str(a["name"])
	return ""
var _rng := RandomNumberGenerator.new()
var _in_shade := false


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
	dev = DEV_DEFAULTS.duplicate()
	time_scale = 1.0
	turret_brains.clear()
	turret_view.clear()
	task = {}
	collapse_t = 0.0
	_autosave_t = 0.0
	drive_throttle = 0.0
	drive_turn = 0.0
	walk_dir = Vector2.ZERO
	_suit_warned = float(state["pilot"]["suit"])
	projectiles.clear()
	brains.clear()
	enemy_intents.clear()
	aim_point = Vector2.INF
	fire_held = false
	_fire_cd = 0.0
	housing_angle = float(state["mech"]["heading"])
	gun_angle = housing_angle
	_rng.seed = hash(str(state.get("id", "")))
	running = true
	_refresh_zones()
	_in_shade = _actor_zone_type() == "shade"
	_zone_type = _actor_zone_type()
	_area = area_at(actor_pos())
	started.emit()


func end_session(reason: String = "menu") -> void:
	if not running:
		return
	save_now(reason)
	running = false
	dev = DEV_DEFAULTS.duplicate()
	time_scale = 1.0
	state = {}
	ended.emit(reason)


func save_now(reason: String = "manual") -> bool:
	if state.is_empty():
		return false
	var err := Saves.save_slot(slot, savable_state())
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


## The state as it goes to disk: developer-spawned entities are left out.
func savable_state() -> Dictionary:
	var s := state.duplicate(true)
	var en: Dictionary = s.get("enemies", {})
	for id in en.keys():
		if bool(en[id].get("dev", false)):
			en.erase(id)
	return s


func weather() -> Dictionary:
	if not state.has("weather"):
		state["weather"] = Weather.create(tun("weather"))
	return state["weather"]


## Zone at a position with the current storm folded in (same rules for every mech).
func zone_with_weather(pos: Vector2) -> Dictionary:
	return Weather.apply(Content.zone_at(loc, pos), weather(), tun("weather"))


func _refresh_zones() -> void:
	mech_zone = zone_with_weather(mech_pos())
	pilot_zone = zone_with_weather(pilot_pos()) if mode() == "foot" else mech_zone
	storm_here = float(pilot_zone.get("storm", 0.0))


func engine_on() -> bool:
	return str(mech()["engine"]) == "running"


func can_drive() -> bool:
	return mode() == "mech" and engine_on() and float(mech()["integrity"]) > 0.0


func enemy_defs() -> Array:
	return loc.get("enemies", [])


func enemy(id: String) -> Dictionary:
	return state.get("enemies", {}).get(id, {})


func enemy_def(id: String) -> Dictionary:
	for d in enemy_defs():
		if d["id"] == id:
			return d
	return enemy(id).get("def", {})


## Thermal tuning for enemies: the player's model with the enemy's overrides.
func enemy_thermal() -> Dictionary:
	var t: Dictionary = tun("thermal").duplicate()
	for k in tun("enemy").get("thermal", {}):
		t[k] = tun("enemy")["thermal"][k]
	return t


## Enemy tuning for one enemy: base `enemy` + its type's overrides.
func enemy_tun(e: Dictionary) -> Dictionary:
	var t: Dictionary = tun("enemy").duplicate()
	var ov: Dictionary = tun("enemy_types").get(str(e.get("type", "scrapper")), {})
	for k in ov:
		t[k] = ov[k]
	return t


func _actor_zone_type() -> String:
	return str((pilot_zone if mode() == "foot" else mech_zone).get("type", ""))


# ---------------------------------------------------------------- tick

func _physics_process(delta: float) -> void:
	if not running:
		return
	tick(delta * time_scale)


func tick(dt: float) -> void:
	state["playtime"] = float(state["playtime"]) + dt
	_tick_weather(dt)
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
	_tick_player_weapon(dt)
	_tick_enemies(dt)
	_tick_turrets(dt)
	_tick_projectiles(dt)
	var zt := _actor_zone_type()
	if zt != _zone_type:
		var was := _zone_type
		_zone_type = zt
		if zt == "refuge":
			notice.emit("NOTICE_ENTER_REFUGE", [])
		elif was == "refuge":
			notice.emit("NOTICE_LEAVE_REFUGE", [])
		elif zt == "shade":
			notice.emit("NOTICE_ENTER_SHADE", [])
		elif was == "shade":
			notice.emit("NOTICE_LEAVE_SHADE", [])
		mech_event.emit("zone_" + zt)
	_in_shade = zt == "shade" or zt == "refuge"
	var ar := area_at(actor_pos())
	if ar != _area:
		_area = ar
		if ar != "":
			notice.emit("NOTICE_AREA", [area_name(ar)])
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
			if not bool(dev["invulnerable"]):
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
			"wreck":
				_finish_wreck_salvage(str(done["target"]))
			"turret":
				_finish_turret_salvage(str(done["target"]))
			"hull":
				_finish_hull_repair(false)
			"patch":
				_finish_hull_repair(true)


# ---------------------------------------------------------------- driving / walking

## Called by the mech view each physics frame. Returns the desired velocity.
func mech_velocity(dt: float) -> Vector2:
	return Drive.step(mech(), drive_throttle, drive_turn, can_drive(), tun("mech"), tun("thermal"), mech_zone, dt)


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
			var near_mech := pp.distance_to(mech_pos()) <= float(tun("mech").get("service_radius", 150.0))
			if near_mech and float(mech()["radiator"]) < 0.995:
				out.append({"action": "service", "kind": "repair", "target": "mech",
					"label": "ACT_REPAIR" if parts_available() > 0 else "ACT_REPAIR_NEED_PART",
					"enabled": parts_available() > 0})
			if near_mech and float(mech()["integrity"]) < float(tun("mech").get("integrity", 100.0)) - 0.5:
				var th := tun("hull_repair")
				if scrap_available() >= int(th.get("scrap_cost", 2)):
					out.append({"action": "service", "kind": "hull", "target": "mech", "label": "ACT_HULL_REPAIR", "enabled": true})
				elif float(mech()["integrity"]) < float(th.get("emergency_below", 25.0)):
					out.append({"action": "service", "kind": "patch", "target": "mech", "label": "ACT_HULL_PATCH", "enabled": true})
				else:
					out.append({"action": "service", "kind": "hull", "target": "mech", "label": "ACT_HULL_NEED_SCRAP", "enabled": false})
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
	for id in state.get("enemies", {}):
		var e: Dictionary = state["enemies"][id]
		if str(e["ai"]) != "wreck" or bool(e.get("salvaged", false)):
			continue
		var d3 := pp.distance_to(Content.v2(e["pos"]))
		if d3 <= best_d + 60.0:
			best_d = d3 - 60.0
			best = {"action": "interact", "kind": "wreck", "target": id, "label": "ACT_SALVAGE_WRECK", "enabled": true}
	for tid in state.get("turrets", {}):
		var tu: Dictionary = state["turrets"][tid]
		if not bool(tu["destroyed"]) or bool(tu.get("salvaged", false)):
			continue
		var d4 := pp.distance_to(Content.v2(turret_def(tid).get("pos", [0, 0])))
		if d4 <= best_d + 30.0:
			best_d = d4 - 30.0
			best = {"action": "interact", "kind": "turret", "target": tid, "label": "ACT_SALVAGE_TURRET", "enabled": true}
	if not best.is_empty() and best["kind"] in ["salvage", "wreck"] and not pack_has_room(1):
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
			elif it["kind"] == "salvage" or it["kind"] == "wreck":
				notice.emit("NOTICE_PACK_FULL", [])
			elif it["kind"] == "hull":
				notice.emit("NOTICE_NEED_SCRAP", [])
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
			"wreck":
				return _start_task("wreck", str(it["target"]), float(tun("wreck_salvage").get("duration", 3.5)))
			"turret":
				return _start_task("turret", str(it["target"]), float(tun("turret").get("salvage_duration", 2.5)))
			"hull":
				return _start_task("hull", "mech", float(tun("hull_repair").get("duration", 3.0)))
			"patch":
				return _start_task("patch", "mech", float(tun("hull_repair").get("emergency_duration", 6.0)))
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
	if float(m["integrity"]) <= 0.0:
		return "HINT_CRIPPLED_FOOT" if md == "foot" else "HINT_CRIPPLED"
	if str(m["engine"]) == "shutdown":
		return "HINT_SHUTDOWN_FOOT" if md == "foot" else "HINT_SHUTDOWN"
	if md == "foot" and float(pilot()["suit"]) < 30.0:
		return "HINT_RETURN_NOW"
	for id in state.get("enemies", {}):
		if str(state["enemies"][id]["ai"]) in ["alert", "engage"]:
			return "HINT_COMBAT_HOT" if float(m["heat"]) >= float(tun("thermal").get("warn_temp", 98.0)) - 6.0 else "HINT_COMBAT"
	var has_part := parts_available() > 0
	var open_wreck := false
	for id in state.get("enemies", {}):
		if str(state["enemies"][id]["ai"]) == "wreck" and not bool(state["enemies"][id].get("salvaged", false)):
			open_wreck = true
	if open_wreck and not has_part:
		return "HINT_SALVAGE_WRECK" if md == "mech" else "HINT_SALVAGE_WRECK_FOOT"
	if float(m["radiator"]) < 0.6:
		if has_part:
			return "HINT_REPAIR" if md == "foot" else "HINT_EXIT_TO_REPAIR"
		if not state["world"]["drops"].is_empty():
			return "HINT_RECOVER_PACK"
		if md == "foot":
			return "HINT_SCAVENGE"
		return "HINT_FIND_CORE"
	for id in state.get("enemies", {}):
		var e: Dictionary = state["enemies"][id]
		if str(e["ai"]) == "wreck" and not bool(e.get("salvaged", false)):
			return "HINT_SALVAGE_WRECK" if md == "mech" else "HINT_SALVAGE_WRECK_FOOT"
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
	for id in state.get("enemies", {}):
		var e: Dictionary = state["enemies"][id]
		if str(e["ai"]) == "wreck" and not bool(e.get("salvaged", false)):
			return Content.v2(e["pos"])
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
		"integrity":
			mech()["integrity"] = clampf(value, 0.0, float(tun("mech").get("integrity", 100.0)))
		"give_scrap":
			GameState.add(pilot()["pack"] if mode() == "foot" else mech()["storage"], "scrap", int(maxf(1.0, value)))
		"enemy_heat":
			for id in state["enemies"]:
				state["enemies"][id]["heat"] = clampf(float(state["enemies"][id]["heat"]) + value, 0.0, 135.0)
		"enemy_cooling":
			for id in state["enemies"]:
				state["enemies"][id]["radiator"] = clampf(float(state["enemies"][id]["radiator"]) - value, 0.0, 1.0)
		"enemy_integrity":
			for id in state["enemies"]:
				state["enemies"][id]["integrity"] = clampf(value, 0.0, 999.0)
	Log.info("debug", action, {"value": value})


# ---------------------------------------------------------------- inventory helpers

func scrap_available() -> int:
	return GameState.count(pilot()["pack"], "scrap") + GameState.count(mech()["storage"], "scrap")


func pack_bulk() -> int:
	var b := 0
	for k in pilot()["pack"]:
		b += int(pilot()["pack"][k]) * int(Content.items.get(k, {}).get("bulk", 1))
	return b


func pack_has_room(bulk: int) -> bool:
	return pack_bulk() + bulk <= int(tun("pilot").get("pack_capacity", 2))


func _consume(item: String, n: int) -> bool:
	var have := GameState.count(pilot()["pack"], item) + GameState.count(mech()["storage"], item)
	if have < n:
		return false
	var from_pack := mini(n, GameState.count(pilot()["pack"], item))
	GameState.add(pilot()["pack"], item, -from_pack)
	GameState.add(mech()["storage"], item, -(n - from_pack))
	return true


# ---------------------------------------------------------------- combat: player weapon

func gun_mount() -> Vector2:
	return mech_pos()


## World position of muzzle i of the twin guns (they rotate with the housing).
func muzzle_pos(i: int) -> Vector2:
	var ms: Array = tun("combat")["player_weapon"].get("muzzles", [[0, -90]])
	return mech_pos() + Content.v2(ms[i % ms.size()]).rotated(housing_angle)


func in_combat() -> bool:
	for id in state.get("enemies", {}):
		if str(state["enemies"][id]["ai"]) in ["alert", "engage", "alerted", "boarding", "starting"]:
			return true
	return false


func can_fire() -> bool:
	return can_drive()


func _tick_player_weapon(dt: float) -> void:
	_fire_cd = maxf(0.0, _fire_cd - dt)
	var w: Dictionary = tun("combat")["player_weapon"]
	var before := housing_angle
	var want := housing_angle
	if aim_point != Vector2.INF and mode() == "mech" and float(mech()["integrity"]) > 0.0:
		var to := aim_point - mech_pos()
		if to.length() > 4.0:
			want = atan2(to.x, -to.y)
		# Heavy but responsive: eases in over the last ~0.3 rad, capped turn rate.
		var err := wrapf(want - housing_angle, -PI, PI)
		var rate := float(tun("mech").get("housing_turn_rate", 5.5))
		var stepv := clampf(err * 10.0 * dt, -rate * dt, rate * dt)
		housing_angle = wrapf(housing_angle + stepv, -PI, PI)
	housing_speed = absf(wrapf(housing_angle - before, -PI, PI)) / maxf(dt, 0.0001)
	gun_angle = housing_angle
	if not fire_held or _fire_cd > 0.0 or not can_fire():
		return
	if absf(wrapf(want - housing_angle, -PI, PI)) > deg_to_rad(float(w.get("fire_cone_deg", 25.0))):
		return   # housing still swinging toward the target
	_fire_cd = float(w["cooldown"])
	var i := _muzzle_i
	_muzzle_i = (_muzzle_i + 1) % 2
	var origin := muzzle_pos(i)
	var fwd := Drive.forward(housing_angle)
	var dir := fwd
	if aim_point != Vector2.INF:
		var to2 := aim_point - origin
		# Converge on the real target point, also at close range; never shoot backwards.
		if to2.length() >= float(w.get("min_aim_distance", 50.0)) and to2.normalized().dot(fwd) > 0.2:
			dir = to2.normalized()
	projectiles.append(Combat.make_shot("player", origin, dir, w, _rng))
	mech()["heat"] = minf(float(mech()["heat"]) + float(w["heat_per_shot"]), Content.t("thermal", "max_temp", 135.0))
	combat_event.emit("muzzle", {"owner": "player", "pos": origin, "angle": atan2(dir.x, -dir.y), "barrel": i})


# ---------------------------------------------------------------- combat: enemies

func _tick_enemies(dt: float) -> void:
	var thermal := enemy_thermal()
	var w: Dictionary = tun("combat")["enemy_weapon"]
	var aggro := bool(dev["aggression"])
	var vis := Weather.visibility(weather(), Content.zone_at(loc, mech_pos()), tun("weather"))
	var target := {"valid": aggro and float(mech()["integrity"]) > 0.0, "pos": mech_pos(), "heat": float(mech()["heat"]), "visibility": vis}
	var tenc := tun("encounter")
	var player := {"mech_valid": aggro and float(mech()["integrity"]) > 0.0, "mech_pos": mech_pos(), "mech_heat": float(mech()["heat"]) * vis,
		"foot": aggro and mode() == "foot", "foot_pos": pilot_pos()}
	for id in state.get("enemies", {}):
		var e: Dictionary = state["enemies"][id]
		if not brains.has(id):
			brains[id] = {"wp": 0, "t_state": 0.0, "windup": 0.0, "cooldown": 1.0}
		var te := enemy_tun(e)
		if str(e["ai"]) == "wreck":
			enemy_intents[id] = {"throttle": 0.0, "turn": 0.0, "windup": 0.0}
			Encounter.tick_flee(e, tenc, dt)
			continue
		var zone := zone_with_weather(Content.v2(e["pos"]))
		enemy_zones[id] = zone
		var sf := float(e["speed"]) / float(te["max_speed"])
		for ev in Thermal.step(e, zone, thermal, dt, sf, str(e["engine"]) == "running"):
			if ev == "restart":
				e["engine"] = "running"
			elif ev == "shutdown":
				combat_event.emit("enemy_shutdown", {"id": id, "pos": Content.v2(e["pos"])})
		var intent := {"throttle": 0.0, "turn": 0.0, "windup": 0.0}
		if Encounter.is_encounter_state(str(e["ai"])):
			var ev2 := Encounter.step(e, brains[id], player, tenc, te, dt)
			if ev2 != "":
				combat_event.emit(ev2, {"id": id, "pos": Content.v2(e["pos"]), "pilot": Content.v2(e["pilot"]["pos"])})
				match ev2:
					"pilot_alert":
						notice.emit("NOTICE_PILOT_ALERT", [])
					"startup":
						notice.emit("NOTICE_MECH_STARTUP", [])
					"active":
						notice.emit("NOTICE_ENEMY_ALERT", [])
				Log.info("encounter", ev2, {"id": id})
		elif str(e["engine"]) == "running":
			var defn := enemy_def(id)
			var r := EnemyAI.think(e, brains[id], target, defn, te, thermal, w, dt)
			intent = r
			match str(r["event"]):
				"alert":
					notice.emit("NOTICE_ENEMY_ALERT", [])
					combat_event.emit("enemy_alert", {"id": id, "pos": Content.v2(e["pos"])})
				"windup":
					combat_event.emit("enemy_windup", {"id": id, "pos": Content.v2(e["pos"])})
				"disengage":
					notice.emit("NOTICE_ENEMY_LOST", [])
			if r["fire"]:
				var dir := Drive.forward(float(e["heading"]))
				var origin := Content.v2(e["pos"]) + dir * 82.0
				var ew := w
				if te.has("damage_mult"):
					ew = w.duplicate()
					ew["damage"] = float(w["damage"]) * float(te["damage_mult"])
					ew["cooling_damage"] = float(w["cooling_damage"]) * float(te["damage_mult"])
				projectiles.append(Combat.make_shot(id, origin, dir, ew, _rng))
				e["heat"] = minf(float(e["heat"]) + float(w["heat_per_shot"]), float(thermal.get("max_temp", 135.0)))
				combat_event.emit("muzzle", {"owner": id, "pos": origin, "angle": float(e["heading"])})
		else:
			brains[id]["windup"] = 0.0
		enemy_intents[id] = intent
		_check_enemy_disabled(id, e, thermal)


func _check_enemy_disabled(id: String, e: Dictionary, thermal: Dictionary) -> void:
	var cooked := float(e["radiator"]) <= float(enemy_tun(e).get("disable_radiator", 0.04)) and float(e["heat"]) >= float(thermal.get("critical_temp", 115.0))
	if float(e["integrity"]) > 0.0 and not cooked:
		return
	e["ai"] = "wreck"
	Encounter.flee(e)
	e["engine"] = "off"
	e["speed"] = 0.0
	e["salvaged"] = false
	brains[id]["windup"] = 0.0
	notice.emit("NOTICE_ENEMY_DISABLED", [])
	combat_event.emit("enemy_disabled", {"id": id, "pos": Content.v2(e["pos"]), "cooked": cooked})
	Log.info("combat", "enemy_disabled", {"id": id, "integrity": snappedf(e["integrity"], 0.1), "radiator": snappedf(e["radiator"], 0.01), "heat": snappedf(e["heat"], 0.1)})
	save_now("enemy_disabled")


## Enemy views call this each physics frame (same drive rules as the player).
func enemy_velocity(id: String, dt: float) -> Vector2:
	var e := enemy(id)
	if e.is_empty():
		return Vector2.ZERO
	var it: Dictionary = enemy_intents.get(id, {})
	var ok := str(e["engine"]) == "running" and str(e["ai"]) != "wreck" and not Encounter.is_encounter_state(str(e["ai"]))
	return Drive.step(e, float(it.get("throttle", 0.0)), float(it.get("turn", 0.0)), ok, enemy_tun(e), enemy_thermal(),
		enemy_zones.get(id, {}), dt)


func commit_enemy(id: String, pos: Vector2, real_velocity: Vector2) -> void:
	var e := enemy(id)
	if e.is_empty():
		return
	e["pos"] = [pos.x, pos.y]
	var along := real_velocity.dot(Drive.forward(float(e["heading"])))
	if absf(along) < absf(float(e["speed"])):
		e["speed"] = along


# ---------------------------------------------------------------- combat: projectiles

func _tick_projectiles(dt: float) -> void:
	var keep: Array = []
	var ph: Dictionary = tun("combat")["player_hit"]
	var eh: Dictionary = tun("combat")["enemy_hit"]
	for sh in projectiles:
		sh["prev"] = sh["pos"]
		var step: Vector2 = sh["vel"] * dt
		sh["pos"] = sh["prev"] + step
		sh["travelled"] = float(sh["travelled"]) + step.length()
		var hit := false
		if str(sh["owner"]) == "player":
			for id in state.get("enemies", {}):
				var e: Dictionary = state["enemies"][id]
				var kind := Combat.hit_test(sh, Content.v2(e["pos"]), float(e["heading"]), eh)
				if kind == "":
					continue
				hit = true
				if str(e["ai"]) != "wreck":
					Combat.apply_hit(e, sh, kind)
					if str(e["ai"]) == "patrol" or str(e["ai"]) == "return":
						e["ai"] = "alert"   # being shot always gets its attention
						brains[id]["t_state"] = 0.0
					elif str(e["ai"]) == "unpiloted":
						e["ai"] = "alerted"
						brains[id]["t_state"] = 0.0
						notice.emit("NOTICE_PILOT_ALERT", [])
						combat_event.emit("pilot_alert", {"id": id, "pos": Content.v2(e["pos"]), "pilot": Content.v2(e["pilot"]["pos"])})
					_check_enemy_disabled(id, e, enemy_thermal())
				combat_event.emit("cooling_hit" if kind == "cooling" else "impact", {"pos": sh["pos"], "target": id, "dir": (sh["vel"] as Vector2).normalized()})
				break
			if not hit:
				hit = _shot_vs_turrets(sh)
		else:
			var kind2 := Combat.hit_test(sh, mech_pos(), float(mech()["heading"]), ph)
			if kind2 != "":
				hit = true
				var before := float(mech()["integrity"])
				if not bool(dev["invulnerable"]):
					Combat.apply_hit(mech(), sh, kind2)
				combat_event.emit("cooling_hit" if kind2 == "cooling" else "impact", {"pos": sh["pos"], "target": "player"})
				combat_event.emit("player_hit", {"kind": kind2})
				if kind2 == "cooling":
					notice.emit("NOTICE_COOLING_HIT", [])
				if before > 0.0 and float(mech()["integrity"]) <= 0.0:
					notice.emit("NOTICE_HULL_CRITICAL", [])
					save_now("crippled")
		if not hit and shot_blocked.is_valid() and shot_blocked.call(sh["prev"], sh["pos"]):
			hit = true
			combat_event.emit("impact", {"pos": sh["pos"], "target": "world"})
		if not hit and float(sh["travelled"]) < float(sh["range"]):
			keep.append(sh)
		elif not hit:
			combat_event.emit("impact", {"pos": sh["pos"], "target": "ground", "owner": str(sh["owner"])})
	projectiles = keep


# ---------------------------------------------------------------- wreck salvage and hull repair

func _finish_wreck_salvage(id: String) -> void:
	var e := enemy(id)
	if e.is_empty() or str(e["ai"]) != "wreck" or bool(e.get("salvaged", false)):
		return
	var tw := tun("wreck_salvage")
	e["salvaged"] = true
	GameState.add(pilot()["pack"], "scrap", int(tw.get("scrap", 4)))
	var item := str(tw.get("item", ""))
	if item != "" and int(tw.get("item_count", 0)) > 0:
		GameState.add(pilot()["pack"], item, int(tw["item_count"]))
	state["stats"]["salvaged"] = int(state["stats"]["salvaged"]) + 1
	notice.emit("NOTICE_WRECK_SALVAGED", [int(tw.get("scrap", 4))])
	mech_event.emit("pickup")
	Log.info("session", "wreck_salvaged", {"id": id})
	save_now("wreck_salvage")


func _finish_hull_repair(emergency: bool) -> void:
	var th := tun("hull_repair")
	var m := mech()
	var mx := float(tun("mech").get("integrity", 100.0))
	if emergency:
		m["integrity"] = maxf(float(m["integrity"]), float(th.get("emergency_to", 25.0)))
		notice.emit("NOTICE_HULL_PATCHED", [int(m["integrity"])])
	else:
		if not _consume("scrap", int(th.get("scrap_cost", 2))):
			notice.emit("NOTICE_NEED_SCRAP", [])
			return
		m["integrity"] = minf(mx, float(m["integrity"]) + float(th.get("restore", 35.0)))
		notice.emit("NOTICE_HULL_REPAIRED", [int(m["integrity"])])
	state["stats"]["repairs"] = int(state["stats"]["repairs"]) + 1
	mech_event.emit("repaired")
	save_now("hull_repair")



# ---------------------------------------------------------------- weather

func _tick_weather(dt: float) -> void:
	var ev := Weather.step(weather(), tun("weather"), dt, bool(dev["dynamic_weather"]), _rng)
	match ev:
		"storm_coming":
			notice.emit("NOTICE_STORM_COMING", [])
		"storm_fading":
			notice.emit("NOTICE_STORM_FADING", [])
		"storm_over":
			notice.emit("NOTICE_STORM_OVER", [])
	if ev != "":
		mech_event.emit(ev)
		Log.info("weather", ev, {"intensity": snappedf(float(weather()["intensity"]), 0.01)})


# ---------------------------------------------------------------- turrets (Southern Junkers)

func turret_defs() -> Array:
	return loc.get("turrets", [])


func turret_def(id: String) -> Dictionary:
	for d in turret_defs():
		if d["id"] == id:
			return d
	return {}


func _tick_turrets(dt: float) -> void:
	var tt := tun("turret")
	var aggro := bool(dev["aggression"])
	var vis := Weather.visibility(weather(), Content.zone_at(loc, mech_pos()), tun("weather"))
	var target := {"valid": aggro and float(mech()["integrity"]) > 0.0, "pos": mech_pos(), "visibility": vis}
	# Engagement limiter: only the closest few engaged turrets may wind up / fire.
	var cands: Array = []
	for d in turret_defs():
		var t: Dictionary = state.get("turrets", {}).get(d["id"], {})
		if t.is_empty() or bool(t["destroyed"]):
			continue
		var dist := Content.v2(d["pos"]).distance_to(mech_pos())
		if dist <= float(tt.get("range", 480.0)) * vis:
			cands.append([dist, d["id"]])
	cands.sort()
	var allowed := {}
	for i in mini(cands.size(), int(tt.get("max_engaged", 2))):
		allowed[cands[i][1]] = true
	for d in turret_defs():
		var id: String = d["id"]
		var t: Dictionary = state.get("turrets", {}).get(id, {})
		if t.is_empty():
			continue
		if not turret_brains.has(id):
			turret_brains[id] = {"windup": 0.0, "cooldown": _rng.randf_range(0.5, 2.5)}
		var los := true
		if shot_blocked.is_valid() and target["valid"]:
			los = not shot_blocked.call(Turret.muzzle(d, t, tt), mech_pos())
		var r := Turret.step(d, t, turret_brains[id], target, tt, dt, los, allowed.has(id))
		turret_view[id] = {"windup": r["windup"], "engaged": r["engaged"]}
		match str(r["event"]):
			"turret_alert":
				combat_event.emit("turret_alert", {"id": id, "pos": Content.v2(d["pos"])})
			"turret_windup":
				combat_event.emit("turret_windup", {"id": id, "pos": Content.v2(d["pos"])})
		if r["fire"]:
			var origin := Turret.muzzle(d, t, tt)
			var dir := Drive.forward(float(t["angle"]))
			projectiles.append(Combat.make_shot("turret:" + id, origin, dir, tt["weapon"], _rng))
			combat_event.emit("muzzle", {"owner": "turret", "id": id, "pos": origin, "angle": float(t["angle"])})


func _shot_vs_turrets(sh: Dictionary) -> bool:
	var tt := tun("turret")
	for d in turret_defs():
		var id: String = d["id"]
		var t: Dictionary = state.get("turrets", {}).get(id, {})
		if t.is_empty():
			continue
		if Combat.seg_dist(sh["prev"], sh["pos"], Content.v2(d["pos"])) > float(tt.get("hit_radius", 40.0)) + float(sh["radius"]):
			continue
		if not bool(t["destroyed"]):
			t["hp"] = maxf(0.0, float(t["hp"]) - float(sh["damage"]))
			combat_event.emit("impact", {"pos": sh["pos"], "target": "turret:" + id, "dir": (sh["vel"] as Vector2).normalized()})
			if float(t["hp"]) <= 0.0:
				t["destroyed"] = true
				turret_brains.erase(id)
				notice.emit("NOTICE_TURRET_DESTROYED", [])
				combat_event.emit("turret_destroyed", {"id": id, "pos": Content.v2(d["pos"])})
				Log.info("combat", "turret_destroyed", {"id": id})
				save_now("turret_destroyed")
		else:
			combat_event.emit("impact", {"pos": sh["pos"], "target": "world"})
		return true
	return false


func _finish_turret_salvage(id: String) -> void:
	var t: Dictionary = state.get("turrets", {}).get(id, {})
	if t.is_empty() or not bool(t["destroyed"]) or bool(t.get("salvaged", false)):
		return
	t["salvaged"] = true
	var n := int(tun("turret").get("salvage_scrap", 2))
	GameState.add(pilot()["pack"], "scrap", n)
	notice.emit("NOTICE_TURRET_SALVAGED", [n])
	mech_event.emit("pickup")
	save_now("turret_salvage")


# ---------------------------------------------------------------- developer menu actions (F10)

const DEV_SPAWN_TYPES := ["scrapper", "junker"]
var _dev_n := 0


## Finds a free spot for a mech near `around` (ring search; never inside rock,
## buildings, the player or other mechs).
func find_spawn_spot(around: Vector2, min_r: float = 420.0, max_r: float = 800.0) -> Vector2:
	for ring in 6:
		var r := lerpf(min_r, max_r, ring / 5.0)
		for k in 16:
			var a := _rng.randf() * TAU
			var p := around + Vector2(cos(a), sin(a)) * r
			if mech_spot_free.is_valid() and not mech_spot_free.call(p):
				continue
			var ok := true
			for id in state.get("enemies", {}):
				if Content.v2(state["enemies"][id]["pos"]).distance_to(p) < 220.0:
					ok = false
			if ok and p.distance_to(mech_pos()) > 300.0:
				return p
	return Vector2.INF


## Physics query for a mech-sized spot, supplied by the world view.
var mech_spot_free: Callable = Callable()
signal dev_spawned(id: String)


func dev_spawn(type: String, count: int = 1) -> int:
	var made := 0
	for i in count:
		var p := find_spawn_spot(actor_pos())
		if p == Vector2.INF:
			break
		_dev_n += 1
		var id := "dev_%s_%d" % [type, _dev_n]
		var defn := {"id": id, "type": type, "spawn": [p.x, p.y], "heading_deg": rad_to_deg((actor_pos() - p).angle()) + 90.0,
			"patrol": [[p.x, p.y], [p.x + 200.0, p.y], [p.x + 200.0, p.y + 200.0], [p.x, p.y + 200.0]]}
		var e := GameState.new_enemy(defn)
		e["integrity"] = float(enemy_tun(e).get("integrity", e["integrity"]))
		e["dev"] = true
		e["def"] = defn
		state["enemies"][id] = e
		dev_spawned.emit(id)
		made += 1
	Log.info("dev", "spawn", {"type": type, "count": made})
	return made


func dev_clear_spawned() -> void:
	for id in state.get("enemies", {}).keys():
		if bool(state["enemies"][id].get("dev", false)):
			state["enemies"].erase(id)
			brains.erase(id)
			enemy_intents.erase(id)
			dev_spawned.emit(id)
	projectiles = projectiles.filter(func(sh): return not str(sh["owner"]).begins_with("dev_"))


func dev_repair_all() -> void:
	var m := mech()
	m["radiator"] = 1.0
	m["integrity"] = float(tun("mech").get("integrity", 100.0))
	if str(m["engine"]) == "shutdown":
		m["engine"] = "running" if mode() == "mech" else "off"
	m["heat"] = minf(float(m["heat"]), 70.0)


func dev_restore_cooling() -> void:
	var m := mech()
	m["radiator"] = 1.0
	m["heat"] = float(mech_zone.get("ambient", 58.0)) + 6.0
	if str(m["engine"]) == "shutdown":
		m["engine"] = "running" if mode() == "mech" else "off"


## Teleport the mech (and pilot, if aboard) to a named place from the location.
signal dev_teleported
func dev_teleport(place: String) -> bool:
	var tp: Dictionary = loc.get("teleports", {})
	if not tp.has(place):
		return false
	var p := Content.v2(tp[place]["pos"])
	mech()["pos"] = [p.x, p.y]
	mech()["heading"] = deg_to_rad(float(tp[place].get("heading_deg", 0.0)))
	mech()["speed"] = 0.0
	if mode() != "mech":
		state["mode"] = "mech"
		task = {}
		mode_changed.emit("mech")
	pilot()["pos"] = [p.x, p.y]
	housing_angle = float(mech()["heading"])
	_refresh_zones()
	dev_teleported.emit()
	return true


func dev_weather(cmd: String, value: float = -1.0) -> void:
	var w := weather()
	var tw := tun("weather")
	match cmd:
		"start":
			w.erase("forced_peak")
			if value > 0.0:
				w["forced_peak"] = value
			Weather.start(w, tw, _rng, 8.0)
			w.erase("forced_peak")
			notice.emit("NOTICE_STORM_COMING", [])
		"stop":
			Weather.stop(w, tw, 8.0)
		"clear":
			Weather.clear(w, tw, _rng)
		"intensity":
			w["peak"] = clampf(value, 0.05, 1.0)
			if str(w["state"]) == "storm":
				w["intensity"] = w["peak"]


func dev_reset() -> void:
	dev = DEV_DEFAULTS.duplicate()
	time_scale = 1.0
