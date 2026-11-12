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
## enemy_alert, enemy_disabled, player_hit, collision, creature_alert,
## creature_tell, creature_attack, creature_hit, creature_dead, part_broken,
## loot_spawned, loot_picked, garage. data carries pos/ids.
signal combat_event(kind: String, data: Dictionary)

var running := false
var state: Dictionary = {}
var slot := 0
var loc: Dictionary = {}

## Input intents, written by views (or the autotest driver) every frame.
var drive_throttle := 0.0
var drive_turn := 0.0
var drive_handbrake := false
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
## Hunting runtime (not saved): creature brains and desired moves, noise memory.
var creature_brains := {}
var creature_moves := {}
var world_moves_creatures := false   # true while a WorldView moves creature bodies
var world_owner: Object = null
var _fire_recent := 0.0
var _impact_cd := 0.0
var _last_desired := Vector2.ZERO
var _track_prune_t := 0.0
## Damage taken this session by source (runtime diagnostics for tests/balance).
var hits_taken := {}


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
	loc = Content.location(str(Journey.node(str(Journey.data().get("start", "ersthafen"))).get("location", Content.DEFAULT_LOCATION)))
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
	creature_brains.clear()
	creature_moves.clear()
	drive_handbrake = false
	_fire_recent = 0.0
	_impact_cd = 0.0
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
	var cr: Dictionary = s.get("creatures", {})
	for id in cr.keys():
		if bool(cr[id].get("dev", false)):
			cr.erase(id)
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
	var k2 := maxf(0.0, float(int(loc.get("tier", 1)) - 1))
	if k2 > 0.0:
		var ec := tun("economy")
		t["integrity"] = float(t.get("integrity", 55.0)) * (1.0 + float(ec.get("tier_hp", 0.3)) * k2)
		t["damage_mult"] = float(t.get("damage_mult", 1.0)) * (1.0 + float(ec.get("tier_damage", 0.18)) * k2)
	return t


## The player's car tuning with fitted garage modules applied.
func car_tun() -> Dictionary:
	var t := Garage.car_tuning(tun("mech"), tun("shop"), upgrades())
	if not state.is_empty() and limp_mode():
		# out of fuel: the engine runs on fumes and reserve — slow, but never stranded
		t["max_speed"] = float(t["max_speed"]) * float(tun("economy").get("limp_speed_mult", 0.32))
		t["accel"] = float(t["accel"]) * float(tun("economy").get("limp_accel_mult", 0.5))
	return t


func car_thermal() -> Dictionary:
	return Garage.thermal_tuning(tun("thermal"), tun("shop"), upgrades())


func player_weapon() -> Dictionary:
	return Garage.weapon_tuning(tun("combat")["player_weapon"], tun("shop"), upgrades())


func upgrades() -> Dictionary:
	if state.is_empty():
		return {}
	if not (mech().get("upgrades") is Dictionary):
		mech()["upgrades"] = {}
	return mech()["upgrades"]


func max_integrity() -> float:
	return float(car_tun().get("integrity", 100.0))


func cargo_capacity() -> int:
	return Garage.cargo_capacity(int(tun("mech").get("cargo_bulk", 14)), tun("shop"), upgrades())


func cargo_bulk() -> int:
	var b := 0
	for k in mech()["storage"]:
		b += int(mech()["storage"][k]) * Loot.bulk(str(k))
	return b


## Items usable right now: pack + car, plus the refuge garage store while at the garage.
func have_item(item: String) -> int:
	var n := GameState.count(pilot()["pack"], item) + GameState.count(mech()["storage"], item)
	if at_garage():
		n += GameState.count(garage_storage(), item)
	return n


## Persistent refuge storage (state.garage.storage).
func garage_storage() -> Dictionary:
	if not (state.get("garage") is Dictionary):
		state["garage"] = {"storage": {}, "unloads": 0}
	return state["garage"]["storage"]


## Engine noise the world can hear (0..~1.2): speed, a running engine, recent
## gunfire. Sandstorms muffle it. On foot the pilot is nearly silent.
func noise() -> float:
	var n := 0.0
	if mode() == "mech":
		n = clampf(absf(float(mech()["speed"])) / maxf(float(car_tun().get("max_speed", 460.0)), 1.0), 0.0, 1.0) * 0.75
		if engine_on():
			n += 0.15
		n += _fire_recent * 0.5
	elif mode() == "foot":
		n = 0.08 if walk_dir.length() > 0.1 else 0.02
	return n * (1.0 - 0.4 * storm_here)


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
	var max_speed := float(car_tun().get("max_speed", 460.0))
	var speed_frac := float(m["speed"]) / max_speed
	var was_band := Thermal.band(float(m["heat"]), tun("thermal"))
	_fire_recent = maxf(0.0, _fire_recent - dt * 0.5)
	_impact_cd = maxf(0.0, _impact_cd - dt)
	for ev in Thermal.step(m, mech_zone, car_thermal(), dt, speed_frac, engine_on()):
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
	_tick_creatures(dt)
	_tick_projectiles(dt)
	_tick_loot_pickup()
	_tick_pois()
	if engine_on() and mode() == "mech":
		_burn_fuel(float(tun("economy").get("fuel_idle_per_s", 0.008)) * dt)
	var here_loc := str(state.get("location", ""))
	_tick_exits(dt)
	if not running or str(state.get("location", "")) != here_loc:
		return   # travelled to another node this tick
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
			"harvest":
				_finish_harvest(str(done["target"]))
			"search":
				_finish_search(str(done["target"]))
			"hull":
				_finish_hull_repair(false)
			"patch":
				_finish_hull_repair(true)


# ---------------------------------------------------------------- driving / walking

## Called by the mech view each physics frame. Returns the desired velocity.
func mech_velocity(dt: float) -> Vector2:
	var ct := car_tun()
	var ef := edge_speed_factor()
	if ef < 1.0:
		ct["max_speed"] = float(ct["max_speed"]) * ef
	_last_desired = Drive.step(mech(), drive_throttle, drive_turn, can_drive(), ct, car_thermal(), mech_zone, dt, drive_handbrake and can_drive())
	return _last_desired


## Called by the car view after move_and_slide with the real result. Walls and
## rocks take the velocity they absorbed; a hard hit damages the car.
func commit_mech(pos: Vector2, real_velocity: Vector2) -> void:
	var m := mech()
	var old := Content.v2(m["pos"])
	m["pos"] = [pos.x, pos.y]
	state["stats"]["distance"] = float(state["stats"]["distance"]) + old.distance_to(pos)
	if mode() == "mech":
		_burn_fuel(old.distance_to(pos) * float(tun("economy").get("fuel_per_px", 0.0035)))
	var lost := (_last_desired - real_velocity).length()
	m["vel"] = [real_velocity.x, real_velocity.y]
	m["speed"] = real_velocity.dot(Drive.forward(float(m["heading"])))
	var tm := tun("mech")
	if lost > float(tm.get("impact_threshold", 170.0)) and _impact_cd <= 0.0:
		_impact_cd = 0.35
		var dmg := minf((lost - float(tm.get("impact_threshold", 170.0))) * float(tm.get("impact_damage", 0.045)), float(tm.get("impact_max", 14.0)))
		if not bool(dev["invulnerable"]):
			m["integrity"] = maxf(0.0, float(m["integrity"]) - dmg)
		combat_event.emit("collision", {"pos": pos, "strength": clampf(lost / 600.0, 0.0, 1.0), "damage": dmg})
	_last_desired = real_velocity
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
	for off in [Vector2(-95, 0), Vector2(95, 0), Vector2(-95, 70), Vector2(95, 70), Vector2(0, 165), Vector2(0, -170)]:
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
	m["vel"] = [0.0, 0.0]
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
			if at_garage():
				out.append({"action": "garage", "kind": "garage", "target": "mech", "label": "ACT_GARAGE",
					"enabled": absf(float(mech()["speed"])) <= 40.0})
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
			if near_mech and float(mech()["integrity"]) < max_integrity() - 0.5:
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
	var hr := float(tun("creatures").get("harvest_reach", 70.0))
	for cid in state.get("creatures", {}):
		var c: Dictionary = state["creatures"][cid]
		if not Creatures.is_dead(c) or bool(c.get("harvested", false)) or not bool(tun("creatures").get(str(c["species"]), {}).get("harvest", false)):
			continue
		var reach := float(tun("creatures").get(str(c["species"]), {}).get("collision", 60.0)) + hr
		var dc := pp.distance_to(Content.v2(c["pos"]))
		if dc <= best_d + reach:
			best_d = dc - reach
			best = {"action": "interact", "kind": "harvest", "target": cid, "label": "ACT_HARVEST", "enabled": true}
	for p in loc.get("pois", []):
		if str(p.get("kind", "")) != "expedition" or bool(poi_state(str(p["id"]))["searched"]):
			continue
		var dp := pp.distance_to(Content.v2(p["pos"]))
		if dp <= best_d + 60.0:
			best_d = dp - 60.0
			best = {"action": "interact", "kind": "search", "target": str(p["id"]), "label": "ACT_SEARCH", "enabled": true}
	for l in state["world"].get("loot", []):
		var dl := pp.distance_to(Content.v2(l["pos"]))
		if dl <= best_d:
			best_d = dl
			best = {"action": "interact", "kind": "loot", "target": str(l["id"]), "label": "ACT_PICK_UP", "enabled": true, "item": str(l["item"])}
	for tid in state.get("turrets", {}):
		var tu: Dictionary = state["turrets"][tid]
		if not bool(tu["destroyed"]) or bool(tu.get("salvaged", false)):
			continue
		var d4 := pp.distance_to(Content.v2(turret_def(tid).get("pos", [0, 0])))
		if d4 <= best_d + 30.0:
			best_d = d4 - 30.0
			best = {"action": "interact", "kind": "turret", "target": tid, "label": "ACT_SALVAGE_TURRET", "enabled": true}
	if not best.is_empty() and best["kind"] == "loot" and not pack_has_room(Loot.bulk(str(best["item"]))):
		best["enabled"] = false
		best["label"] = "ACT_PACK_FULL"
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
			elif it["kind"] in ["salvage", "wreck", "loot"]:
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
			"search":
				return _start_task("search", str(it["target"]), 2.5)
			"harvest":
				return _start_task("harvest", str(it["target"]), float(tun("creatures").get("harvest_duration", 4.0)))
			"loot":
				return pick_up_loot(str(it["target"]), false)
			"garage":
				mech_event.emit("garage")
				return true
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
	var hunt_id := hunting()
	if hunt_id != "":
		var hc := creature(hunt_id)
		return "HINT_HUNT_" + str(hc["species"]).to_upper() + ("_FOOT" if md == "foot" else "")
	for cid in state.get("creatures", {}):
		var dc: Dictionary = state["creatures"][cid]
		if Creatures.is_dead(dc) and not bool(dc.get("harvested", false)) and Content.v2(dc["pos"]).distance_to(actor_pos()) < 1400.0:
			return "HINT_HARVEST_FOOT" if md == "foot" else "HINT_HARVEST"
	if not state["world"].get("loot", []).is_empty() and _nearest_loot(actor_pos()).distance_to(actor_pos()) < 900.0:
		return "HINT_LOOT_FOOT" if md == "foot" else "HINT_LOOT"
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
	if not exit_prompt.is_empty():
		return "HINT_EXIT_LEAVE" if is_safe_zone() else "HINT_EXIT_FLEE"
	if bool(journey().get("delivered", false)) and is_safe_zone():
		return "HINT_DELIVERED"
	if limp_mode():
		return "HINT_NO_FUEL"
	if is_safe_zone():
		if at_garage():
			return "HINT_GARAGE"
		if _carrying_materials() or float(mech()["integrity"]) < max_integrity() * 0.7:
			return "HINT_SETTLEMENT_GARAGE"
		if fuel() < fuel_capacity() * 0.5:
			return "HINT_REFUEL"
		return "HINT_SETTLEMENT_DEPART"
	if fuel() < float(tun("economy").get("low_fuel_warn", 15.0)):
		return "HINT_FUEL_LOW"
	if cargo_bulk() >= int(cargo_capacity() * 0.85):
		return "HINT_CARGO_FULL_RETURN"
	var tk := tracker()
	if not tk.is_empty():
		return "HINT_TRACKS_BLOOD" if bool(tk["blood"]) else "HINT_TRACKS"
	if bool(journey()["completed"].get(current_node(), false)):
		return "HINT_TERRITORY_DONE"
	return "HINT_HUNT"


## Position of the gate on this map that starts the route toward a node.
func _gate_toward(node_id: String) -> Vector2:
	var hop := Journey.next_hop(current_node(), node_id)
	var g := gate_to(hop)
	if g.is_empty():
		return Vector2.INF
	return Content.v2(g["pos"])


func _nearest_loot(from: Vector2) -> Vector2:
	var best := Vector2.INF
	for l in state["world"].get("loot", []):
		var p := Content.v2(l["pos"])
		if best == Vector2.INF or from.distance_to(p) < from.distance_to(best):
			best = p
	return best


func _carrying_materials() -> bool:
	for inv in [mech()["storage"], pilot()["pack"]]:
		for k in inv:
			if str(k) != "scrap" and str(k) != "radiator_core":
				return true
	return false


func nearest_objective() -> Vector2:
	if not running:
		return Vector2.INF
	var from := actor_pos()
	# hunting loop: carcass → loot → garage → hunting grounds
	for cid in state.get("creatures", {}):
		var dc: Dictionary = state["creatures"][cid]
		if Creatures.is_dead(dc) and not bool(dc.get("harvested", false)) and Content.v2(dc["pos"]).distance_to(from) < 1400.0:
			return Content.v2(dc["pos"])
	var lp := _nearest_loot(from)
	if lp != Vector2.INF and lp.distance_to(from) < 900.0:
		return lp
	if hunting() == "" and mode() == "mech":
		if is_safe_zone():
			if (_carrying_materials() or float(mech()["integrity"]) < max_integrity() * 0.7 or fuel() < fuel_capacity() * 0.5) and not at_garage() and loc.has("garage"):
				return Content.v2(loc["garage"]["pos"])
			return _gate_toward(course())
		if cargo_bulk() >= int(cargo_capacity() * 0.85) or fuel() < float(tun("economy").get("low_fuel_warn", 15.0)) or bool(journey()["completed"].get(current_node(), false)):
			var safe := Journey.nearest_safe(current_node())
			return _gate_toward(course() if bool(journey()["completed"].get(current_node(), false)) and not _carrying_materials() else safe)
		if tracker().is_empty():
			var q := creature(str(loc.get("quarry", "")))
			if not q.is_empty() and not Creatures.is_dead(q):
				return Content.v2(q.get("home", q["pos"]))
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
			mech()["integrity"] = clampf(value, 0.0, max_integrity())
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
		"give_materials":
			dev_give_materials()
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


## Takes n items: from the garage store first (when at the garage), then the
## pack, then the car. All-or-nothing.
func _consume(item: String, n: int) -> bool:
	if have_item(item) < n:
		return false
	var left := n
	var sources: Array = [pilot()["pack"], mech()["storage"]]
	if at_garage():
		sources.push_front(garage_storage())
	for inv in sources:
		var take := mini(left, GameState.count(inv, item))
		if take > 0:
			GameState.add(inv, item, -take)
			left -= take
	return left == 0


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
	return hunting() != ""


## Id of a creature currently fighting the player (or "").
func hunting() -> String:
	var at := actor_pos()
	for id in state.get("creatures", {}):
		var c: Dictionary = state["creatures"][id]
		var a := str(c["ai"])
		var d := Content.v2(c["pos"]).distance_to(at)
		if a in ["roam", "buried", "dead"] or d > 1400.0:
			continue
		if a in ["flee", "stalk"] and d > 700.0:
			continue
		return id
	return ""


func can_fire() -> bool:
	return can_drive()


func _tick_player_weapon(dt: float) -> void:
	_fire_cd = maxf(0.0, _fire_cd - dt)
	var w: Dictionary = player_weapon()
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
	_fire_recent = minf(1.0, _fire_recent + 0.25)
	mech()["heat"] = minf(float(mech()["heat"]) + float(w["heat_per_shot"]), Content.t("thermal", "max_temp", 135.0))
	combat_event.emit("muzzle", {"owner": "player", "pos": origin, "angle": atan2(dir.x, -dir.y), "barrel": i})


# ---------------------------------------------------------------- combat: enemies

func _tick_enemies(dt: float) -> void:
	var thermal := enemy_thermal()
	var w: Dictionary = tun("combat")["enemy_weapon"]
	var aggro := bool(dev["aggression"])
	var vis := Weather.visibility(weather(), Content.zone_at(loc, mech_pos()), tun("weather"))
	var target := {"valid": aggro and float(mech()["integrity"]) > 0.0, "pos": mech_pos(), "heat": float(mech()["heat"]), "visibility": vis,
		"noise": noise() if mode() == "mech" else 0.0}
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
				"retreat":
					notice.emit("NOTICE_ENEMY_RETREAT", [])
					combat_event.emit("enemy_retreat", {"id": id, "pos": Content.v2(e["pos"])})
				"escaped":
					notice.emit("NOTICE_ENEMY_ESCAPED", [])
			intent["gun"] = float(brains[id].get("gun", e["heading"]))
			if r["fire"]:
				var dir: Vector2 = r.get("fire_dir", Drive.forward(float(e["heading"])))
				var origin := Content.v2(e["pos"]) + dir * 64.0
				var ew := w
				if te.has("damage_mult"):
					ew = w.duplicate()
					ew["damage"] = float(w["damage"]) * float(te["damage_mult"])
					ew["cooling_damage"] = float(w["cooling_damage"]) * float(te["damage_mult"])
				projectiles.append(Combat.make_shot(id, origin, dir, ew, _rng))
				e["heat"] = minf(float(e["heat"]) + float(w["heat_per_shot"]), float(thermal.get("max_temp", 135.0)))
				combat_event.emit("muzzle", {"owner": id, "pos": origin, "angle": atan2(dir.x, -dir.y)})
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
	e["vel"] = [0.0, 0.0]
	e["salvaged"] = false
	brains[id]["windup"] = 0.0
	notice.emit("NOTICE_ENEMY_DISABLED", [])
	if not bool(e.get("dev", false)):
		add_xp(xp_for("rival"), "rival")
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
	e["vel"] = [real_velocity.x, real_velocity.y]
	e["speed"] = real_velocity.dot(Drive.forward(float(e["heading"])))


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
				hit = _shot_vs_creatures(sh)
			if not hit:
				hit = _shot_vs_turrets(sh)
		else:
			var kind2 := Combat.hit_test(sh, mech_pos(), float(mech()["heading"]), ph)
			if kind2 != "":
				hit = true
				var before := float(mech()["integrity"])
				if not bool(dev["invulnerable"]):
					Combat.apply_hit(mech(), sh, kind2)
					var hk := "shot:" + str(sh["owner"]).get_slice(":", 0)
					hits_taken[hk] = float(hits_taken.get(hk, 0.0)) + (before - float(mech()["integrity"]))
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
	var mx := max_integrity()
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
	for id in state.get("creatures", {}).keys():
		if bool(state["creatures"][id].get("dev", false)):
			state["creatures"].erase(id)
			creature_brains.erase(id)
			creature_moves.erase(id)
			dev_spawned.emit(id)
	projectiles = projectiles.filter(func(sh): return not str(sh["owner"]).begins_with("dev_") and not str(sh["owner"]).begins_with("creature:dev_"))


func dev_repair_all() -> void:
	var m := mech()
	m["radiator"] = 1.0
	m["integrity"] = max_integrity()
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
	mech()["vel"] = [0.0, 0.0]
	_last_desired = Vector2.ZERO
	_impact_cd = 0.5
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


# ---------------------------------------------------------------- hunting: creatures

func creature(id: String) -> Dictionary:
	return state.get("creatures", {}).get(id, {})


func creature_tuning() -> Dictionary:
	return Creatures.scaled(tun("creatures"), int(loc.get("tier", 1)), tun("economy"))


func creature_tun(c: Dictionary) -> Dictionary:
	return creature_tuning().get(str(c.get("species", "skirr")), {})


func creature_def(id: String) -> Dictionary:
	for d in loc.get("creatures", []):
		if d["id"] == id:
			return d
	return creature(id).get("def", {})


## What creatures sense of the player this tick (car or pilot on foot).
func _creature_target() -> Dictionary:
	var aggro := bool(dev["aggression"])
	var foot := mode() == "foot"
	var p := pilot_pos() if foot else mech_pos()
	var vis := Weather.visibility(weather(), Content.zone_at(loc, p), tun("weather"))
	var v := Vector2.ZERO if foot else Drive.velocity(mech())
	return {"valid": aggro and mode() != "collapsed" and (foot or float(mech()["integrity"]) > 0.0), "pos": p, "vel": v,
		"noise": noise(), "heat": 60.0 if foot else float(mech()["heat"]), "vis": vis, "foot": foot}


func _tick_creatures(dt: float) -> void:
	var tc := creature_tuning()
	var target := _creature_target()
	var playtime := float(state["playtime"])
	for id in state.get("creatures", {}):
		var c: Dictionary = state["creatures"][id]
		if not creature_brains.has(id):
			creature_brains[id] = {"t": 0.0, "cd": 1.0, "trk": 0.0}
		var brain: Dictionary = creature_brains[id]
		if Creatures.is_dead(c):
			creature_moves[id] = Vector2.ZERO
			_maybe_respawn(id, c, playtime)
			continue
		var res := Creatures.step(c, brain, target, tc, dt, _rng)
		creature_moves[id] = res["move"]
		if not world_moves_creatures:
			var np := Content.v2(c["pos"]) + (res["move"] as Vector2) * dt
			c["pos"] = [np.x, np.y]
		for ev in res["events"]:
			_creature_event(id, c, brain, ev)
		_lay_tracks(id, c, brain, dt)
	_track_prune_t += dt
	if _track_prune_t > 3.0:
		_track_prune_t = 0.0
		var life := float(tc.get("track_life", 420.0))
		state["tracks"] = state["tracks"].filter(func(t): return playtime - float(t["t"]) < life)


func _creature_event(id: String, c: Dictionary, brain: Dictionary, ev: Dictionary) -> void:
	var pos := Content.v2(c["pos"])
	match str(ev["kind"]):
		"alert":
			combat_event.emit("creature_alert", {"id": id, "species": c["species"], "pos": pos})
			if str(c["species"]) == "rimeback":
				notice.emit("NOTICE_RIMEBACK_ALERT", [])
			elif str(c["species"]) == "grindback":
				notice.emit("NOTICE_TREMOR", [])
			else:
				notice.emit("NOTICE_SKIRR_ALERT", [])
			# pack hunters call the rest of the pack
			if str(c["pack"]) != "":
				for oid in state["creatures"]:
					var o: Dictionary = state["creatures"][oid]
					if oid != id and str(o["pack"]) == str(c["pack"]) and str(o["ai"]) == "roam" and Content.v2(o["pos"]).distance_to(pos) < 900.0:
						o["ai"] = "stalk"
						creature_brains.get(oid, {})["t"] = 0.0
		"tell":
			combat_event.emit("creature_tell", {"id": id, "species": c["species"], "tell": ev.get("tell", ""), "pos": pos})
		"attack":
			_resolve_creature_attack(id, c, ev)
		"spit":
			var g: Dictionary = creature_tun(c).get("glob", {})
			for d in ev["dirs"]:
				projectiles.append(Combat.make_shot("creature:" + id, ev["from"], d, g, _rng))
			combat_event.emit("creature_spit", {"id": id, "pos": ev["from"]})
		"enrage":
			notice.emit("NOTICE_RIMEBACK_ENRAGED", [])
			combat_event.emit("creature_tell", {"id": id, "species": c["species"], "tell": "enrage", "pos": pos})
		"flee":
			if str(c["species"]) == "rimeback":
				notice.emit("NOTICE_RIMEBACK_FLEES", [])
			combat_event.emit("creature_flee", {"id": id, "pos": pos})
		"cornered":
			notice.emit("NOTICE_RIMEBACK_CORNERED", [])
		"surface", "burrow":
			combat_event.emit("creature_" + str(ev["kind"]), {"id": id, "pos": pos})


## Applies a creature attack (radius around ev.pos) to the car or the pilot.
func _resolve_creature_attack(id: String, c: Dictionary, ev: Dictionary) -> void:
	var at: Vector2 = ev["pos"]
	var foot := mode() == "foot"
	var victim := pilot_pos() if foot else mech_pos()
	var reach := float(ev["radius"]) + (20.0 if foot else 60.0)
	combat_event.emit("creature_attack", {"id": id, "attack": ev.get("attack", ""), "pos": at, "radius": float(ev["radius"])})
	if at.distance_to(victim) > reach or bool(dev["invulnerable"]):
		return
	var dmg := float(ev["damage"])
	if foot:
		pilot()["suit"] = maxf(0.0, float(pilot()["suit"]) - dmg * 2.5)
		notice.emit("NOTICE_PILOT_HIT", [])
		combat_event.emit("player_hit", {"kind": "creature", "attack": ev.get("attack", "")})
		return
	var m := mech()
	var before := float(m["integrity"])
	m["integrity"] = maxf(0.0, before - dmg)
	var key := "%s:%s" % [c["species"], ev.get("attack", "")]
	hits_taken[key] = float(hits_taken.get(key, 0.0)) + dmg
	# head-on hits smash the radiator grille at the nose
	var to_attacker := (Content.v2(c["pos"]) - victim).normalized()
	var front := to_attacker.dot(Drive.forward(float(m["heading"]))) > 0.5
	m["radiator"] = maxf(0.0, float(m["radiator"]) - float(ev.get("cooling", 0.0)) * (2.0 if front else 0.5))
	var push_dir: Vector2 = ev.get("dir", (victim - Content.v2(c["pos"])).normalized())
	var v := Drive.velocity(m) + push_dir.normalized() * float(ev.get("push", 0.0))
	m["vel"] = [v.x, v.y]
	combat_event.emit("player_hit", {"kind": "cooling" if front else "creature", "attack": ev.get("attack", ""), "dir": push_dir})
	if front and float(ev.get("cooling", 0.0)) > 0.0:
		notice.emit("NOTICE_GRILLE_HIT", [])
	if before > 0.0 and float(m["integrity"]) <= 0.0:
		notice.emit("NOTICE_HULL_CRITICAL", [])
		save_now("crippled")


func _lay_tracks(_id: String, c: Dictionary, brain: Dictionary, dt: float) -> void:
	var ts := creature_tun(c)
	var sp := str(c["species"])
	if sp == "grindback" and not (str(c["ai"]) in ["buried", "tunnel"]):
		return
	brain["trk"] = float(brain.get("trk", 0.0)) + absf(float(c["speed"])) * dt
	if float(brain["trk"]) < float(ts.get("track_every", 120.0)):
		return
	brain["trk"] = 0.0
	var tr: Array = state["tracks"]
	tr.append({"s": sp, "p": [float(c["pos"][0]), float(c["pos"][1])], "h": float(c["heading"]), "t": float(state["playtime"]),
		"b": bool(brain.get("bleeding", false)) or Creatures.max_hp(c, tun("creatures")) * 0.4 > float(c["hp"])})
	var cap := int(tun("creatures").get("track_cap", 520))
	if tr.size() > cap:
		tr.remove_at(0)


## The freshest readable track near the active actor, or {}:
## {species, pos, heading, freshness 0..1, blood, dist}.
func tracker() -> Dictionary:
	if not running:
		return {}
	var at := actor_pos()
	var rng := Garage.tracker_range(float(tun("mech").get("tracker_range", 380.0)), tun("shop"), upgrades())
	if mode() == "foot":
		rng *= 0.6
	var life := float(tun("creatures").get("track_life", 420.0))
	var now := float(state["playtime"])
	var best := {}
	var best_score := -INF
	for t in state.get("tracks", []):
		var p := Content.v2(t["p"])
		var d := p.distance_to(at)
		if d > rng:
			continue
		var fresh := clampf(1.0 - (now - float(t["t"])) / life, 0.0, 1.0)
		var score := fresh - d / rng * 0.35
		if score > best_score:
			best_score = score
			best = {"species": str(t["s"]), "pos": p, "heading": float(t["h"]), "freshness": fresh, "blood": bool(t.get("b", false)), "dist": d}
	return best


## Player projectile vs creatures. Returns true if it hit one.
func _shot_vs_creatures(sh: Dictionary) -> bool:
	for id in state.get("creatures", {}):
		var c: Dictionary = state["creatures"][id]
		if not Creatures.targetable(c):
			continue
		var ts := creature_tun(c)
		var part := Creatures.hit_part(c, sh["prev"], sh["pos"], float(sh["radius"]), ts)
		if part == "":
			continue
		var brain: Dictionary = creature_brains.get(id, {})
		var dazed := str(c["ai"]) == "dazed"
		var r := Creatures.damage(c, part, float(sh["damage"]), ts, dazed)
		var mult := float(ts.get("parts", {}).get(part, {}).get("mult", 1.0))
		combat_event.emit("creature_hit", {"id": id, "part": part, "pos": sh["pos"], "dir": (sh["vel"] as Vector2).normalized(),
			"armoured": mult < 0.4 and not dazed})
		if str(c["ai"]) == "roam":
			if str(c["species"]) == "rimeback":
				brain["provoked"] = true
			elif str(c["species"]) == "skirr":
				c["ai"] = "stalk"
				brain["t"] = 0.0
		if bool(r["broken"]):
			_break_part(id, c, part)
		if float(c["hp"]) <= 0.0:
			_creature_dies(id, c)
		return true
	return false


func _break_part(id: String, c: Dictionary, part: String) -> void:
	var pd: Dictionary = creature_tun(c).get("parts", {}).get(part, {})
	var at := Content.v2(c["pos"]) + Content.v2(pd.get("offset", [0, 0])).rotated(float(c["heading"]))
	var drops: Dictionary = pd.get("drop", {})
	var made := Loot.spawn(state["world"], at, drops, _rng, 60.0)
	notice.emit("NOTICE_PART_BROKEN", ["PART_" + part.to_upper()])
	combat_event.emit("part_broken", {"id": id, "part": part, "pos": at})
	for l in made:
		combat_event.emit("loot_spawned", {"id": l["id"], "item": l["item"], "pos": Content.v2(l["pos"])})
	Log.info("hunt", "part_broken", {"id": id, "part": part})


func _creature_dies(id: String, c: Dictionary) -> void:
	var ts := creature_tun(c)
	c["ai"] = "dead"
	c["speed"] = 0.0
	c["dead_at"] = float(state["playtime"])
	c["harvested"] = false
	creature_moves[id] = Vector2.ZERO
	state["stats"]["kills"] = int(state["stats"].get("kills", 0)) + 1
	add_xp(xp_for(str(c["species"])), "kill")
	if id == str(loc.get("quarry", "")) and not bool(c.get("dev", false)):
		complete_node(current_node())
	combat_event.emit("creature_dead", {"id": id, "species": c["species"], "pos": Content.v2(c["pos"])})
	notice.emit("NOTICE_%s_DOWN" % str(c["species"]).to_upper(), [])
	if not bool(ts.get("harvest", false)):
		# small game drops its materials straight away
		c["harvested"] = true
		for l in Loot.spawn(state["world"], Content.v2(c["pos"]), Loot.roll(ts.get("loot", {}), _rng), _rng, 50.0):
			combat_event.emit("loot_spawned", {"id": l["id"], "item": l["item"], "pos": Content.v2(l["pos"])})
	# the rest of a pack loses its nerve when half of it is down
	if str(c["pack"]) != "":
		var alive := 0
		var total := 0
		for oid in state["creatures"]:
			var o: Dictionary = state["creatures"][oid]
			if str(o["pack"]) == str(c["pack"]):
				total += 1
				if not Creatures.is_dead(o):
					alive += 1
		if alive * 2 <= total:
			for oid in state["creatures"]:
				if str(state["creatures"][oid]["pack"]) == str(c["pack"]) and creature_brains.has(oid):
					creature_brains[oid]["morale_broken"] = true
	Log.info("hunt", "creature_down", {"id": id, "species": c["species"]})
	save_now("creature_down")


func _finish_harvest(id: String) -> void:
	var c := creature(id)
	if c.is_empty() or not Creatures.is_dead(c) or bool(c.get("harvested", false)):
		return
	var ts := creature_tun(c)
	c["harvested"] = true
	var drops := Loot.roll(ts.get("loot", {}), _rng)
	var bonus: Dictionary = ts.get("bonus", {})
	if not bonus.is_empty():
		var ok := true
		for p in bonus.get("requires_broken", []):
			if float(c["parts"].get(p, 1.0)) > 0.0:
				ok = false
		if ok:
			drops[str(bonus["item"])] = int(drops.get(str(bonus["item"]), 0)) + 1
	var made := Loot.spawn(state["world"], Content.v2(c["pos"]), drops, _rng, float(ts.get("collision", 60.0)) + 50.0)
	state["stats"]["harvests"] = int(state["stats"].get("harvests", 0)) + 1
	for l in made:
		combat_event.emit("loot_spawned", {"id": l["id"], "item": l["item"], "pos": Content.v2(l["pos"])})
	notice.emit("NOTICE_HARVESTED", [made.size()])
	mech_event.emit("pickup")
	Log.info("hunt", "harvested", {"id": id, "drops": drops})
	save_now("harvest")


func _maybe_respawn(id: String, c: Dictionary, playtime: float) -> void:
	var ts := creature_tun(c)
	var wait := float(ts.get("respawn_time", 600.0))
	if float(c["dead_at"]) < 0.0 or playtime - float(c["dead_at"]) < wait:
		return
	var d := creature_def(id)
	if d.is_empty() or Content.v2(d["spawn"]).distance_to(actor_pos()) < 2600.0 or bool(c.get("dev", false)):
		return
	state["creatures"][id] = Creatures.create(d, tun("creatures"))
	creature_brains.erase(id)
	Log.info("hunt", "respawn", {"id": id})


## Called by creature views (when the world moves them) with the physics result.
func commit_creature(id: String, pos: Vector2, real_velocity: Vector2) -> void:
	var c := creature(id)
	if c.is_empty():
		return
	c["pos"] = [pos.x, pos.y]
	var want: Vector2 = creature_moves.get(id, Vector2.ZERO)
	if want.length() > 200.0 and real_velocity.length() < want.length() * 0.35:
		creature_brains.get(id, {})["blocked"] = true   # a charge ran into rock


# ---------------------------------------------------------------- loot

## The car scoops loot it rolls slowly over; legendary finds announce themselves.
func _tick_loot_pickup() -> void:
	if mode() != "mech":
		return
	var tm := tun("mech")
	if absf(float(mech()["speed"])) > float(tm.get("loot_pickup_speed", 280.0)):
		return
	var r := float(tm.get("loot_pickup_radius", 110.0))
	var at := mech_pos()
	for l in state["world"].get("loot", []).duplicate():
		if Content.v2(l["pos"]).distance_to(at) <= r:
			pick_up_loot(str(l["id"]), true)


## Moves one ground loot item into the car (by_car) or the pilot's pack.
func pick_up_loot(id: String, by_car: bool) -> bool:
	var i := Loot.find(state["world"], id)
	if i < 0:
		return false
	var l: Dictionary = state["world"]["loot"][i]
	var item := str(l["item"])
	var n := int(l["n"])
	if by_car:
		if cargo_bulk() + Loot.bulk(item) * n > cargo_capacity():
			if not _cargo_warned:
				_cargo_warned = true
				notice.emit("NOTICE_CARGO_FULL", [])
			return false
		GameState.add(mech()["storage"], item, n)
	else:
		if not pack_has_room(Loot.bulk(item) * n):
			notice.emit("NOTICE_PACK_FULL", [])
			return false
		GameState.add(pilot()["pack"], item, n)
	_cargo_warned = false
	state["world"]["loot"].remove_at(i)
	state["stats"]["salvaged"] = int(state["stats"]["salvaged"]) + 1
	var rar := Loot.rarity(item)
	notice.emit("NOTICE_LEGENDARY" if rar == "legendary" else "NOTICE_LOOT", [Content.items.get(item, {}).get("name", item), n])
	combat_event.emit("loot_picked", {"id": id, "item": item, "rarity": rar, "pos": Content.v2(l["pos"])})
	mech_event.emit("pickup")
	Log.info("loot", "picked", {"item": item, "n": n, "by_car": by_car})
	return true

var _cargo_warned := false


# ---------------------------------------------------------------- garage

func at_garage() -> bool:
	if not running or mode() != "mech":
		return false
	var g: Dictionary = loc.get("garage", {})
	if g.is_empty():
		return false
	return mech_pos().distance_to(Content.v2(g["pos"])) <= float(g.get("radius", 300.0))


## Services offered by the garage here (settlements: everything; the canyon
## refuge field garage: repair + storage).
func garage_services() -> Array:
	return loc.get("garage", {}).get("services", ["repair", "fuel", "sell", "upgrade", "storage"])


func has_service(s: String) -> bool:
	return at_garage() and s in garage_services()


func money() -> int:
	return int(state.get("money", 0))


func rank_level() -> int:
	return int(state.get("rank", {}).get("level", 1))


func add_money(n: int) -> void:
	state["money"] = maxi(0, money() + n)


## Jäger XP: kills, discoveries, completed nodes, sales. Rank-ups unlock shop levels.
func add_xp(n: int, why: String = "") -> void:
	if n <= 0 or state.is_empty():
		return
	var r: Dictionary = state["rank"]
	var before := int(r["level"])
	r["xp"] = int(r["xp"]) + n
	r["level"] = GameState.rank_for_xp(int(r["xp"]))
	if int(r["level"]) > before:
		notice.emit("NOTICE_RANK_UP", ["RANK_%d" % int(r["level"]), int(r["level"])])
		mech_event.emit("rank_up")
		Log.info("economy", "rank_up", {"level": r["level"], "why": why})


func xp_for(key: String) -> int:
	return int(tun("economy").get("xp", {}).get(key, 0))


## "" if the next level of a line can be bought here, else a reason key.
func garage_check(module: String) -> String:
	if not has_service("upgrade"):
		return "GARAGE_NO_SHOP"
	return Garage.check(tun("shop"), upgrades(), module, money(), rank_level())


func garage_fit(module: String) -> bool:
	if garage_check(module) != "":
		return false
	var nxt := Garage.next_level(tun("shop"), upgrades(), module)
	add_money(-int(nxt.get("price", 0)))
	var before_max := max_integrity()
	upgrades()[module] = Garage.level(upgrades(), module) + 1
	mech()["integrity"] = minf(max_integrity(), float(mech()["integrity"]) + maxf(0.0, max_integrity() - before_max))
	state["stats"]["upgrades"] = int(state["stats"].get("upgrades", 0)) + 1
	notice.emit("NOTICE_FITTED", [str(nxt.get("name", "MOD_" + module.to_upper())), Garage.level(upgrades(), module)])
	combat_event.emit("garage", {"module": module})
	mech_event.emit("repaired")
	Log.info("garage", "fitted", {"module": module, "level": upgrades()[module], "price": nxt.get("price", 0)})
	save_now("garage")
	return true


## Moves everything carried (car cargo + pilot pack) into the persistent garage
## store. A move, never a copy. Returns the number of items moved.
func unload_cargo() -> int:
	if not has_service("storage"):
		return 0
	var moved := 0
	for inv in [mech()["storage"], pilot()["pack"]]:
		for item in inv.keys():
			var n := int(inv[item])
			if n > 0:
				GameState.add(garage_storage(), str(item), n)
				moved += n
			inv.erase(item)
	if moved > 0:
		state["garage"]["unloads"] = int(state["garage"].get("unloads", 0)) + 1
		_cargo_warned = false
		notice.emit("NOTICE_UNLOADED", [moved])
		mech_event.emit("pickup")
		Log.info("garage", "unloaded", {"items": moved})
		save_now("unload")
	return moved


## Price in Mark for a full repair of body + radiator here.
func garage_repair_cost() -> int:
	var tsh := tun("shop")
	var body := (max_integrity() - float(mech()["integrity"])) * float(tsh.get("repair_price_per_point", 1.2))
	var rad := (1.0 - float(mech()["radiator"])) * 100.0 * float(tsh.get("radiator_price_per_pct", 3.0))
	return int(ceil(maxf(0.0, body + rad)))


## Repairs as much as the money allows (all of it when affordable).
func garage_repair() -> bool:
	if not has_service("repair"):
		return false
	var cost := garage_repair_cost()
	if cost <= 0:
		return false
	var pay := mini(cost, money())
	if pay <= 0:
		notice.emit("NOTICE_NO_MONEY", [])
		return false
	add_money(-pay)
	var frac := float(pay) / float(cost)
	var m := mech()
	m["integrity"] = minf(max_integrity(), float(m["integrity"]) + (max_integrity() - float(m["integrity"])) * frac)
	m["radiator"] = minf(1.0, float(m["radiator"]) + (1.0 - float(m["radiator"])) * frac)
	if str(m["engine"]) == "shutdown":
		m["engine"] = "running"
	state["stats"]["repairs"] = int(state["stats"]["repairs"]) + 1
	notice.emit("NOTICE_GARAGE_REPAIRED", [int(round(float(m["integrity"]))), int(round(float(m["radiator"]) * 100.0))])
	mech_event.emit("repaired")
	save_now("garage_repair")
	return true


# ---------------------------------------------------------------- fuel

func fuel() -> float:
	return float(mech().get("fuel", 0.0))


func fuel_capacity() -> float:
	return float(tun("economy").get("fuel_capacity", 100.0))


## Fills the tank as far as the money allows. Returns litres bought.
func refuel() -> float:
	if not has_service("fuel"):
		return 0.0
	var price := float(tun("shop").get("fuel_price", 2.0))
	var want := fuel_capacity() - fuel()
	if want < 0.5:
		return 0.0
	var litres := minf(want, floorf(float(money()) / maxf(price, 0.01)))
	if litres <= 0.0:
		if want > 0.0:
			notice.emit("NOTICE_NO_MONEY", [])
		return 0.0
	add_money(-int(ceil(litres * price)))
	mech()["fuel"] = fuel() + litres
	notice.emit("NOTICE_REFUELLED", [int(round(litres))])
	combat_event.emit("refuel", {})
	save_now("refuel")
	return litres


func refuel_cost() -> int:
	var missing := fuel_capacity() - fuel()
	if missing < 0.5:
		return 0
	return int(ceil(missing * float(tun("shop").get("fuel_price", 2.0))))


func _burn_fuel(litres: float) -> void:
	if litres <= 0.0 or bool(dev.get("infinite_fuel", false)):
		return
	var m := mech()
	var before := float(m.get("fuel", 0.0))
	m["fuel"] = maxf(0.0, before - litres)
	var warn := float(tun("economy").get("low_fuel_warn", 15.0))
	if before > warn and float(m["fuel"]) <= warn:
		notice.emit("NOTICE_FUEL_LOW", [])
	if before > 0.0 and float(m["fuel"]) <= 0.0:
		notice.emit("NOTICE_FUEL_EMPTY", [])


func limp_mode() -> bool:
	return fuel() <= 0.0


# ---------------------------------------------------------------- market

func item_value(item: String) -> int:
	return int(round(float(Content.items.get(item, {}).get("value", 0)) * float(tun("shop").get("sell_rate", 1.0))))


## Sells n of an item from the car, the pack, then the garage store.
func sell_item(item: String, n: int = 1) -> int:
	if not has_service("sell") or n <= 0 or item_value(item) <= 0:
		return 0
	var have := GameState.count(mech()["storage"], item) + GameState.count(pilot()["pack"], item) + GameState.count(garage_storage(), item)
	n = mini(n, have)
	if n <= 0:
		return 0
	var left := n
	for inv in [mech()["storage"], pilot()["pack"], garage_storage()]:
		var take := mini(left, GameState.count(inv, item))
		if take > 0:
			GameState.add(inv, item, -take)
			left -= take
	var earned := item_value(item) * n
	add_money(earned)
	state["stats"]["sold"] = int(state["stats"].get("sold", 0)) + earned
	add_xp(int(float(earned) / 100.0 * float(xp_for("sold_per_100"))), "sell")
	notice.emit("NOTICE_SOLD", [Content.items.get(item, {}).get("name", item), n, earned])
	combat_event.emit("sold", {"item": item, "n": n, "earned": earned})
	save_now("sell")
	return earned


## Everything sellable here: {item: count} over car + pack + store.
func sellable() -> Dictionary:
	var out := {}
	for inv in [mech()["storage"], pilot()["pack"], garage_storage()]:
		for k in inv:
			if item_value(str(k)) > 0:
				out[k] = int(out.get(k, 0)) + int(inv[k])
	return out


# ---------------------------------------------------------------- journey

func journey() -> Dictionary:
	return state.get("journey", {})


func current_node() -> String:
	return str(journey().get("node", ""))


func is_safe_zone() -> bool:
	return str(loc.get("kind", "territory")) != "territory"


## "danger" | "safe" | "cleared" for the hazard ribbon.
func zone_status() -> String:
	if str(loc.get("kind", "")) == "hub" and bool(journey().get("delivered", false)):
		return "cleared"
	return "safe" if is_safe_zone() else "danger"


func tier() -> int:
	return int(loc.get("tier", 1))


## Gate of this map that leads to a node (or {}).
func gate_to(node_id: String) -> Dictionary:
	for g in loc.get("gates", []):
		if str(g["to"]) == node_id:
			return g
	return {}


## Moves the whole party (car, pilot, cargo, money) to a neighbouring node: the
## current map's site state is stashed, the destination's restored (or created),
## the car arrives at the destination's gate from here. Returns "" or an error.
signal travelled(from_node: String, to_node: String)


func travel_to(node_id: String, force: bool = false) -> String:
	if not running:
		return "not running"
	var here := current_node()
	if not force and not (node_id in Journey.neighbors(here)):
		return "not connected"
	var nd := Journey.node(node_id)
	if nd.is_empty():
		return "unknown node"
	var dest := Content.location(str(nd["location"]))
	if dest.is_empty():
		return "missing location"
	if mode() != "mech":
		state["mode"] = "mech"
	# stash the map we leave
	var site := {}
	for k in Journey.SITE_KEYS:
		site[k] = state.get(k)
	state["sites"][str(state["location"])] = site
	_burn_fuel(Journey.edge_fuel(here, node_id))
	# restore / create the destination
	loc = dest
	state["location"] = str(dest["id"])
	var stored: Dictionary = state["sites"].get(str(dest["id"]), {})
	if stored.is_empty():
		stored = GameState.create_site(dest)
	for k in Journey.SITE_KEYS:
		state[k] = stored.get(k, GameState.create_site(dest)[k])
	state["sites"].erase(str(dest["id"]))
	# arrive at the gate that faces where we came from
	var g := gate_to(here)
	var p := Content.v2(dest.get("mech_start", {}).get("pos", [0, 0]))
	var hd := float(dest.get("mech_start", {}).get("heading_deg", 0.0))
	if not g.is_empty():
		p = Content.v2(g["entry"])
		hd = float(g["heading_deg"])
	var m := mech()
	m["pos"] = [p.x, p.y]
	m["heading"] = deg_to_rad(hd)
	m["speed"] = 0.0
	m["vel"] = [0.0, 0.0]
	if str(m["engine"]) != "shutdown":
		m["engine"] = "running"
	pilot()["pos"] = [p.x, p.y]
	state = GameState.sanitize(state, loc)
	var evs := Journey.arrive(journey(), node_id)
	for ev in evs:
		if str(ev) == "first_visit" and Journey.is_safe(node_id):
			add_xp(xp_for("settlement"), "settlement")
		elif str(ev).begins_with("discovered:"):
			pass
		elif str(ev) == "delivered":
			notice.emit("NOTICE_DELIVERED", [])
	exit_prompt = {}
	_exit_cd = 3.0
	Log.info("journey", "travel", {"from": here, "to": node_id, "fuel": snappedf(fuel(), 0.1)})
	_begin()
	notice.emit("NOTICE_ARRIVED", [str(nd.get("name", node_id))])
	travelled.emit(here, node_id)
	save_now("travel")
	return ""


## The node the player has plotted on the continental map ("" = straight for Stahlheim).
func set_course(node_id: String) -> void:
	journey()["course"] = node_id
	notice.emit("NOTICE_COURSE_SET", [str(Journey.node(node_id).get("name", node_id))])


func course() -> String:
	var c := str(journey().get("course", ""))
	if c == current_node() or c == "":
		return str(Journey.data().get("goal", ""))
	return c


## Marks the current territory completed (its quarry is down) — XP + notice.
func complete_node(node_id: String) -> void:
	var j := journey()
	if bool(j["completed"].get(node_id, false)):
		return
	j["completed"][node_id] = true
	add_xp(xp_for("complete"), "complete")
	notice.emit("NOTICE_TERRITORY_CLEARED", [str(Journey.node(node_id).get("name", node_id))])
	Log.info("journey", "completed", {"node": node_id})


# ---------------------------------------------------------------- territory exits

## {gate, to, kind ("leave"|"flee")} while the car is at the edge and the prompt
## is up; {} otherwise. Read by the HUD.
var exit_prompt := {}
var _exit_cd := 0.0
var _exit_declined_at := Vector2.INF


func _edge_distance(p: Vector2) -> float:
	var b: Array = loc.get("bounds", [0, 0, 3600, 2600])
	return minf(minf(p.x - float(b[0]), float(b[0]) + float(b[2]) - p.x), minf(p.y - float(b[1]), float(b[1]) + float(b[3]) - p.y))


func _nearest_gate(p: Vector2) -> Dictionary:
	var best := {}
	var bd := INF
	for g in loc.get("gates", []):
		var d := p.distance_to(Content.v2(g["pos"]))
		if d < bd:
			bd = d
			best = g
	return best


## Edge handling: near a map edge the car slows, the prompt appears (once; a
## cooldown after "stay"), and driving on past the boundary leaves anyway.
func _tick_exits(dt: float) -> void:
	_exit_cd = maxf(0.0, _exit_cd - dt)
	if mode() != "mech" or loc.get("gates", []).is_empty():
		exit_prompt = {}
		return
	var p := mech_pos()
	var d := _edge_distance(p)
	var margin := float(tun("mech").get("exit_margin", 380.0))
	if d < -40.0:
		var g := _nearest_gate(p)
		if not g.is_empty():
			travel_to(str(g["to"]))
		return
	if d > margin:
		exit_prompt = {}
		if _exit_declined_at != Vector2.INF and p.distance_to(_exit_declined_at) > margin * 1.5:
			_exit_declined_at = Vector2.INF
		return
	if exit_prompt.is_empty() and _exit_cd <= 0.0 and _exit_declined_at == Vector2.INF:
		var g2 := _nearest_gate(p)
		if not g2.is_empty():
			exit_prompt = {"gate": str(g2["id"]), "to": str(g2["to"]), "kind": "leave" if is_safe_zone() else "flee"}
			notice.emit("NOTICE_EDGE", [])


## Speed cap near the edge (gradual deceleration toward the boundary).
func edge_speed_factor() -> float:
	if mode() != "mech" or loc.get("gates", []).is_empty() or exit_prompt.is_empty():
		return 1.0
	var margin := float(tun("mech").get("exit_margin", 380.0))
	var d := clampf(_edge_distance(mech_pos()) / margin, 0.0, 1.0)
	return lerpf(float(tun("mech").get("exit_slow_speed", 170.0)) / maxf(float(car_tun().get("max_speed", 560.0)), 1.0), 1.0, d)


func confirm_exit() -> bool:
	if exit_prompt.is_empty():
		return false
	var to := str(exit_prompt["to"])
	exit_prompt = {}
	return travel_to(to) == ""


func decline_exit() -> void:
	if exit_prompt.is_empty():
		return
	exit_prompt = {}
	_exit_cd = float(tun("mech").get("exit_prompt_cooldown", 6.0))
	_exit_declined_at = mech_pos()


# ---------------------------------------------------------------- points of interest (anomalies)

func poi_state(id: String) -> Dictionary:
	var pois: Dictionary = state["world"].get("pois", {})
	if not pois.has(id):
		pois[id] = {"discovered": false, "searched": false}
		state["world"]["pois"] = pois
	return pois[id]


func _tick_pois() -> void:
	var at := actor_pos()
	for p in loc.get("pois", []):
		var ps := poi_state(str(p["id"]))
		if bool(ps["discovered"]):
			continue
		if at.distance_to(Content.v2(p["pos"])) < float(tun("economy").get("discover_radius", 420.0)):
			ps["discovered"] = true
			add_xp(xp_for("discovery"), "discovery")
			notice.emit("NOTICE_DISCOVERED", [str(p.get("name", "POI_EXPEDITION"))])
			combat_event.emit("discovered", {"id": p["id"], "pos": Content.v2(p["pos"])})
			Log.info("poi", "discovered", {"id": p["id"]})
			save_now("discovery")


func poi_def(id: String) -> Dictionary:
	for p in loc.get("pois", []):
		if str(p["id"]) == id:
			return p
	return {}


func _finish_search(id: String) -> void:
	var p := poi_def(id)
	var ps := poi_state(id)
	if p.is_empty() or bool(ps["searched"]):
		return
	ps["searched"] = true
	ps["discovered"] = true
	var drops: Dictionary = p.get("loot", {})
	if drops.is_empty():
		notice.emit("NOTICE_SEARCH_EMPTY", [])
	else:
		var made := Loot.spawn(state["world"], Content.v2(p["pos"]) + Vector2(60, 40), drops, _rng, 70.0)
		for l in made:
			combat_event.emit("loot_spawned", {"id": l["id"], "item": l["item"], "pos": Content.v2(l["pos"])})
		notice.emit("NOTICE_SEARCH_FOUND", [made.size()])
	mech_event.emit("pickup")
	save_now("search")


# ---------------------------------------------------------------- developer: creatures and materials

const DEV_CREATURES := ["skirr", "grindback", "rimeback"]


func dev_spawn_creature(species: String, count: int = 1) -> int:
	var made := 0
	for i in count:
		var p := find_spawn_spot(actor_pos(), 520.0, 900.0)
		if p == Vector2.INF:
			break
		_dev_n += 1
		var id := "dev_%s_%d" % [species, _dev_n]
		var defn := {"id": id, "species": species, "spawn": [p.x, p.y], "pack": "dev_pack" if species == "skirr" else ""}
		var c := Creatures.create(defn, tun("creatures"))
		c["dev"] = true
		c["def"] = defn
		if species == "rimeback":
			c["ai"] = "roam"
		state["creatures"][id] = c
		dev_spawned.emit(id)
		made += 1
	Log.info("dev", "spawn_creature", {"species": species, "count": made})
	return made


func dev_give_materials() -> void:
	var inv: Dictionary = mech()["storage"] if mode() == "mech" else pilot()["pack"]
	for item in ["scrap", "skirr_hide", "skirr_fang", "grind_plate", "rime_hide", "rime_spine", "rime_horn", "rime_gland", "thawheart", "radiator_core"]:
		GameState.add(inv, item, 6 if item == "scrap" else 2)
	notice.emit("NOTICE_DEV_MATERIALS", [])


# ---------------------------------------------------------------- developer: journey, fuel, upgrades (F10)

func _dev_mark() -> void:
	state["stats"]["dev_actions"] = int(state["stats"].get("dev_actions", 0)) + 1


func dev_refuel() -> void:
	mech()["fuel"] = fuel_capacity()
	_dev_mark()
	notice.emit("NOTICE_DEV", ["DEV_FUEL_FULL"])


func dev_grant_upgrade(line: String) -> bool:
	if not (line in Garage.MODULES) or Garage.level(upgrades(), line) >= Garage.max_level(tun("shop"), line):
		return false
	var before_max := max_integrity()
	upgrades()[line] = Garage.level(upgrades(), line) + 1
	mech()["integrity"] = minf(max_integrity(), float(mech()["integrity"]) + maxf(0.0, max_integrity() - before_max))
	_dev_mark()
	notice.emit("NOTICE_DEV", ["DEV_UPGRADE_GRANTED"])
	return true


func dev_complete_node(node_id: String) -> bool:
	if Journey.node(node_id).is_empty():
		return false
	journey()["discovered"][node_id] = true
	for n in Journey.neighbors(node_id):
		journey()["discovered"][n] = true
	journey()["completed"][node_id] = true
	if node_id == str(Journey.data().get("goal", "")) and current_node() == node_id:
		journey()["delivered"] = true
	_dev_mark()
	notice.emit("NOTICE_DEV", ["DEV_NODE_COMPLETED"])
	return true


## Removes every living creature of the current map (no loot, no XP).
func dev_clear_creatures() -> int:
	var n := 0
	for id in state.get("creatures", {}):
		var c: Dictionary = state["creatures"][id]
		if not Creatures.is_dead(c):
			c["ai"] = "dead"
			c["dead_at"] = float(state["playtime"])
			c["harvested"] = true
			creature_moves[id] = Vector2.ZERO
			n += 1
	_dev_mark()
	notice.emit("NOTICE_DEV", ["DEV_CREATURES_CLEARED"])
	return n


func dev_money(amount: int) -> void:
	add_money(amount)
	_dev_mark()
	notice.emit("NOTICE_DEV", ["DEV_MONEY"])
