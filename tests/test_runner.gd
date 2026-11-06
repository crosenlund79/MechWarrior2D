extends Node
## Baseline unit/regression suite. Run:
##   godot --headless --path . res://tests/run_tests.tscn
## Exit code 0 = all passed. Uses its own user folder (--instance=unit_tests is
## implied: tests write only under user://instances/unit_tests/).

var _fails := 0
var _passes := 0
var _current := ""


func _ready() -> void:
	await get_tree().process_frame
	for m in get_method_list():
		var n: String = m["name"]
		if n.begins_with("test_"):
			_current = n
			await call(n)
	print("\n%d passed, %d failed" % [_passes, _fails])
	get_tree().quit(1 if _fails > 0 else 0)


func check(cond: bool, what: String) -> void:
	if cond:
		_passes += 1
	else:
		_fails += 1
		print("FAIL [%s] %s" % [_current, what])


func approx(a: float, b: float, eps: float, what: String) -> void:
	check(absf(a - b) <= eps, "%s: %.4f vs %.4f" % [what, a, b])


func _mech(radiator: float, open := true, heat := 60.0) -> Dictionary:
	return {"heat": heat, "radiator": radiator, "shutters_open": open, "engine": "running"}


# ---------------------------------------------------------------- content

func test_content_loads() -> void:
	Content.reload()
	check(Content.problems.is_empty(), "content problems: %s" % str(Content.problems))
	var loc := Content.location()
	check(loc.get("id") == "desert_basin_01", "location id")
	check(loc.get("salvage", []).size() >= 1, "salvage defined")
	for s in loc["salvage"]:
		check(Content.is_item(s["item"]), "salvage item known: %s" % s["item"])
	for p in loc["props"]:
		check(AssetCatalog.has(p["asset"]), "prop asset in manifest: %s" % p["asset"])


func test_manifest_files_exist() -> void:
	AssetCatalog.reload()
	check(AssetCatalog.problems.is_empty(), "manifest problems")
	for id in AssetCatalog.ids():
		var found := false
		for p in AssetCatalog.template_paths(id):
			if ResourceLoader.exists(p) or FileAccess.file_exists(p):
				found = true
		check(found, "template exists for %s" % id)


func test_zones() -> void:
	var loc := Content.location()
	check(Content.zone_at(loc, Vector2(760, 1240))["type"] == "shade", "shelter is shade")
	check(Content.zone_at(loc, Vector2(1700, 500))["type"] == "dunes", "north dunes")
	check(Content.zone_at(loc, Vector2(1700, 1140))["type"] == "open", "track gap is open sand")
	check(Content.zone_at(loc, Vector2(2700, 2000))["type"] == "salt", "salt pan")


# ---------------------------------------------------------------- thermal

func test_thermal_equilibrium_matches_simulation() -> void:
	var tun: Dictionary = Content.tuning["thermal"]
	var zone := {"ambient": 58.0, "solar": 1.0, "abrasion": 0.0}
	var m := _mech(1.0)
	var eq := Thermal.equilibrium(m, true, 1.0, zone, tun)
	for i in 6000:
		Thermal.step(m, zone, tun, 0.05, 1.0, true)
	approx(float(m["heat"]), eq, 0.5, "simulated heat converges to equilibrium")
	check(eq < float(tun["warn_temp"]), "repaired mech at full speed stays below warning (eq %.1f)" % eq)


func test_damaged_radiator_overheats_and_shuts_down() -> void:
	var tun: Dictionary = Content.tuning["thermal"]
	var zone := {"ambient": 58.0, "solar": 1.0, "abrasion": 0.0}
	var m := _mech(float(tun["start_radiator"]), true, float(tun["start_heat"]))
	var t := 0.0
	var shut := false
	while t < 120.0 and not shut:
		shut = Thermal.step(m, zone, tun, 0.05, 1.0, true).has("shutdown")
		t += 0.05
	check(shut, "damaged radiator overheats at full speed")
	check(t > 15.0 and t < 60.0, "overheat takes a playable time (%.1f s)" % t)
	check(m["engine"] == "shutdown", "engine state shutdown")
	var restarted := false
	t = 0.0
	while t < 180.0 and not restarted:
		restarted = Thermal.step(m, zone, tun, 0.05, 0.0, false).has("restart")
		t += 0.05
	check(restarted, "engine-off cooling allows restart (%.1f s)" % t)


func test_cooling_depends_on_condition_and_shutters() -> void:
	var tun: Dictionary = Content.tuning["thermal"]
	var zone := {"ambient": 58.0}
	var bad := Thermal.cooling_rate(_mech(0.2, true, 100.0), zone, tun)
	var good := Thermal.cooling_rate(_mech(1.0, true, 100.0), zone, tun)
	var closed := Thermal.cooling_rate(_mech(1.0, false, 100.0), zone, tun)
	check(good > bad * 1.8, "repaired radiator cools much better")
	check(closed < good * 0.6, "closed shutters restrict cooling")


func test_abrasion_only_with_open_shutters() -> void:
	var tun: Dictionary = Content.tuning["thermal"]
	var dunes := {"ambient": 60.0, "solar": 1.0, "abrasion": 22.0}
	var open_m := _mech(1.0, true)
	var shut_m := _mech(1.0, false)
	for i in 200:
		Thermal.step(open_m, dunes, tun, 0.05, 1.0, true)
		Thermal.step(shut_m, dunes, tun, 0.05, 1.0, true)
	check(float(open_m["radiator"]) < 0.9, "open shutters wear in dunes (%.3f)" % open_m["radiator"])
	approx(float(shut_m["radiator"]), 1.0, 0.0001, "closed shutters protect")


# ---------------------------------------------------------------- session loop

func test_session_loop_in_memory() -> void:
	Content.reload()
	Session.loc = Content.location()
	Session.slot = 3
	Session.state = GameState.create(Session.loc, 3)
	Session.running = true
	Session.spot_is_free = Callable()
	var s := Session.state
	# Exit while parked
	check(Session.exit_mech(), "exit when stopped")
	check(Session.mode() == "foot", "on foot")
	check(s["mech"]["engine"] == "off", "engine off when parked")
	# Suit drains outside
	var suit0 := float(s["pilot"]["suit"])
	Session.tick(5.0)
	check(float(s["pilot"]["suit"]) < suit0, "suit drains on foot")
	# Salvage
	var node: Dictionary = Session.loc["salvage"][0]
	s["pilot"]["pos"] = node["pos"].duplicate()
	check(Session.request("interact"), "start salvage")
	for i in 40:
		Session.tick(0.1)
	check(GameState.count(s["pilot"]["pack"], "radiator_core") == 1, "core in pack")
	check(s["world"]["taken"].has(node["id"]), "salvage node marked taken")
	# Return and repair
	s["pilot"]["pos"] = [float(s["mech"]["pos"][0]) + 100.0, float(s["mech"]["pos"][1])]
	var before := float(s["mech"]["radiator"])
	check(Session.request("service"), "start repair")
	for i in 40:
		Session.tick(0.1)
	check(float(s["mech"]["radiator"]) > before + 0.5, "radiator repaired")
	check(GameState.count(s["pilot"]["pack"], "radiator_core") == 0, "core consumed")
	check(Session.enter_mech(), "re-enter")
	var suit1 := float(s["pilot"]["suit"])
	Session.tick(2.0)
	check(float(s["pilot"]["suit"]) > suit1, "suit recovers in mech")
	Session.running = false
	Saves.delete_slot(3)


func test_suit_failure_collapse_drops_pack() -> void:
	Session.loc = Content.location()
	Session.slot = 3
	Session.state = GameState.create(Session.loc, 3)
	Session.running = true
	Session.exit_mech()
	var s := Session.state
	GameState.add(s["pilot"]["pack"], "radiator_core", 1)
	s["pilot"]["suit"] = 0.5
	for i in 200:
		Session.tick(0.1)
	check(Session.mode() == "mech", "recovered into mech after collapse")
	check(int(s["stats"]["collapses"]) == 1, "collapse counted")
	check(s["world"]["drops"].size() == 1, "pack dropped in the world")
	check(GameState.total(s["pilot"]["pack"]) == 0, "pack emptied")
	Session.running = false
	Saves.delete_slot(3)


# ---------------------------------------------------------------- saves

func test_save_roundtrip_and_backup_recovery() -> void:
	var loc := Content.location()
	var st := GameState.create(loc, 2)
	st["mech"]["radiator"] = 0.77
	st["world"]["taken"]["salvage_pump_rig"] = true
	check(Saves.save_slot(2, st) == "", "first save")
	st["mech"]["radiator"] = 0.81
	check(Saves.save_slot(2, st) == "", "second save (creates .bak)")
	var r := Saves.load_slot(2)
	check(r["ok"], "load ok")
	approx(float(r["state"]["mech"]["radiator"]), 0.81, 0.0001, "radiator persisted")
	check(r["state"]["world"]["taken"].has("salvage_pump_rig"), "taken persisted")
	# Corrupt the main file → backup is used.
	var f := FileAccess.open(Saves.slot_path(2), FileAccess.WRITE)
	f.store_string("{ broken json")
	f.close()
	var r2 := Saves.load_slot(2)
	check(r2["ok"] and r2["recovered"], "recovered from .bak")
	approx(float(r2["state"]["mech"]["radiator"]), 0.77, 0.0001, "backup holds the previous good save")
	Saves.delete_slot(2)
	check(not Saves.has_save(2), "slot deleted")


func test_validation_and_migration() -> void:
	var loc := Content.location()
	var env := SaveCodec.encode(GameState.create(loc, 1))
	check(SaveCodec.validate(env) == "", "fresh envelope valid")
	var bad := env.duplicate(true)
	bad["state"]["mech"]["pos"] = ["x", 2]
	check(SaveCodec.validate(bad) != "", "rejects bad position")
	var v0 := env.duplicate(true)
	v0["version"] = 0
	v0["state"]["mech"].erase("radiator")
	v0["state"]["mech"]["cooling"] = 40.0
	var up = SaveCodec.migrate(v0)
	check(up is Dictionary and int(up["version"]) == SaveCodec.VERSION, "migrated to current version")
	approx(float(up["state"]["mech"]["radiator"]), 0.4, 0.0001, "migration converted cooling")
	var future := env.duplicate(true)
	future["version"] = 99
	check(SaveCodec.migrate(future) is String, "refuses newer versions")
	var dirty: Dictionary = env["state"].duplicate(true)
	dirty["mech"]["radiator"] = 7.0
	dirty["pilot"]["pack"] = {"unknown_thing": 3, "radiator_core": 2}
	var clean := GameState.sanitize(dirty, loc)
	approx(float(clean["mech"]["radiator"]), 1.0, 0.0001, "sanitize clamps")
	check(not clean["pilot"]["pack"].has("unknown_thing"), "sanitize drops unknown items")


# ---------------------------------------------------------------- assets

func test_asset_override_priority_and_fallback() -> void:
	var id := "item.radiator_core"
	var root := Paths.external_override_roots()[-1]
	var rel: String = AssetCatalog.entry(id)["path"]
	var path := root + rel + ".png"
	Paths.ensure_dir(path.get_base_dir())
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	Assets.reload()
	Assets.texture(id)
	check(Assets.source_of(id) == "template", "template used without override (got %s)" % Assets.source_of(id))
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 1, 0))
	img.save_png(path)
	Assets.reload()
	var t := Assets.texture(id)
	check(Assets.source_of(id) == "external", "external override wins")
	check(t.get_width() == 32, "override texture loaded")
	var s := Sprite2D.new()
	Assets.apply_to_sprite(s, id)
	approx(t.get_width() * s.scale.x, Assets.display_size(id).x, 0.01, "override fitted to display box")
	s.free()
	# Invalid override (not an image) falls back to template.
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("not a png")
	f.close()
	Assets.reload()
	Assets.texture(id)
	check(Assets.source_of(id) == "template", "invalid override falls back to template")
	DirAccess.remove_absolute(path)
	Assets.reload()
	Assets.texture("does.not.exist")
	check(Assets.source_of("does.not.exist") == "fallback", "unknown id → diagnostic fallback")
	Assets.reload()


func test_audio_resolves() -> void:
	Assets.reload()
	for id in ["sfx.warning", "amb.wind", "music.theme", "music.theme_alt", "sfx.generator_hum", "sfx.gun_fire", "ui.click"]:
		check(Assets.audio_stream(id) != null, "sound resolves: %s" % id)


func test_settings_roundtrip() -> void:
	var old := float(Settings.get_value("volume_Music"))
	Settings.set_value("volume_Music", 0.33)
	Settings.rebind("interact", KEY_F)
	Settings.values["volume_Music"] = 0.9
	Settings.bindings.clear()
	Settings.load_settings()
	approx(float(Settings.get_value("volume_Music")), 0.33, 0.001, "volume persisted")
	check(Settings.key_for("interact") == KEY_F, "binding persisted")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_F
	check(InputMap.event_is_action(ev, "interact"), "rebinding applied to InputMap")
	Settings.reset_bindings()
	Settings.set_value("volume_Music", old)
	check(not FileAccess.get_file_as_string(Paths.settings_file()).contains("radiator"), "settings file holds no game state")


# ---------------------------------------------------------------- first hostile encounter

func _fresh_session(slot := 3) -> Dictionary:
	Content.reload()
	Session.loc = Content.location()
	Session.slot = slot
	Session.state = GameState.create(Session.loc, slot)
	Session.projectiles.clear()
	Session.brains.clear()
	Session.enemy_intents.clear()
	Session.running = true
	Session.spot_is_free = Callable()
	Session.shot_blocked = Callable()
	return Session.state


func _enemy_id() -> String:
	return str(Session.loc["enemies"][0]["id"])


func test_enemy_created_with_stable_id() -> void:
	var s := _fresh_session()
	var id := _enemy_id()
	check(s["enemies"].has(id), "enemy state keyed by stable id")
	check(s["enemies"][id]["ai"] == "patrol", "enemy starts patrolling")
	var start := Content.v2(Session.loc["mech_start"]["pos"])
	check(Content.v2(s["enemies"][id]["pos"]).distance_to(start) > 1500.0, "enemy placed away from the start")
	Session.running = false


func test_combat_hit_areas() -> void:
	var eh: Dictionary = Content.tuning["combat"]["enemy_hit"]
	var w: Dictionary = Content.tuning["combat"]["player_weapon"]
	var rng := RandomNumberGenerator.new()
	var pos := Vector2(1000, 1000)
	var heading := 0.0
	var cp := Combat.cooling_point(pos, heading, eh)
	check(cp.y > pos.y, "cooling area sits at the rear (facing up)")
	var shot := Combat.make_shot("player", cp + Vector2(0, 60), Vector2(0, -1), {"speed": 100, "spread_deg": 0, "radius": 4, "damage": 7, "cooling_damage": 0.1}, rng)
	shot["prev"] = cp + Vector2(0, 60)
	shot["pos"] = cp
	check(Combat.hit_test(shot, pos, heading, eh) == "cooling", "shot into the radiator hits cooling")
	shot["prev"] = pos + Vector2(-200, -40)
	shot["pos"] = pos + Vector2(0, -40)
	check(Combat.hit_test(shot, pos, heading, eh) == "structure", "shot into the front hits structure")
	shot["prev"] = pos + Vector2(-300, -300)
	shot["pos"] = pos + Vector2(-250, -300)
	check(Combat.hit_test(shot, pos, heading, eh) == "", "far shot misses")
	var m := {"integrity": 50.0, "radiator": 0.8}
	Combat.apply_hit(m, shot, "cooling")
	check(float(m["radiator"]) < 0.8 and float(m["integrity"]) < 50.0, "cooling hit damages radiator (and a little structure)")
	var m2 := {"integrity": 50.0, "radiator": 0.8}
	Combat.apply_hit(m2, shot, "structure")
	approx(float(m2["integrity"]), 43.0, 0.01, "structural hit damage")


func test_heat_impairs_movement() -> void:
	var th: Dictionary = Content.tuning["thermal"]
	approx(Drive.impairment(80.0, th, 0.5), 1.0, 0.001, "no impairment when cool")
	check(Drive.impairment(float(th["warn_temp"]) + 8.0, th, 0.5) < 0.85, "hot mech is slowed")
	approx(Drive.impairment(float(th["critical_temp"]), th, 0.5), 0.5, 0.001, "max impairment at critical")


func test_enemy_ai_patrol_detect_engage_disengage() -> void:
	var s := _fresh_session()
	var id := _enemy_id()
	var e: Dictionary = s["enemies"][id]
	var defn: Dictionary = Session.loc["enemies"][0]
	var te: Dictionary = Content.tuning["enemy"]
	var w: Dictionary = Content.tuning["combat"]["enemy_weapon"]
	var brain := {"wp": 0, "t_state": 0.0, "windup": 0.0, "cooldown": 0.0}
	var far := {"valid": true, "pos": Content.v2(e["pos"]) + Vector2(2000, 0), "heat": 70.0}
	var r := EnemyAI.think(e, brain, far, defn, te, Content.tuning["thermal"], w, 0.1)
	check(e["ai"] == "patrol" and absf(float(r["throttle"])) > 0.0, "patrols when nobody is near")
	var near := {"valid": true, "pos": Content.v2(e["pos"]) + Vector2(0, -300), "heat": 80.0}
	EnemyAI.think(e, brain, near, defn, te, Content.tuning["thermal"], w, 0.1)
	check(e["ai"] == "alert", "detects a nearby mech")
	for i in 20:
		EnemyAI.think(e, brain, near, defn, te, Content.tuning["thermal"], w, 0.1)
	check(e["ai"] == "engage", "engages after its (slow) reaction time")
	var fired := false
	var saw_windup := false
	for i in 80:
		var rr := EnemyAI.think(e, brain, near, defn, te, Content.tuning["thermal"], w, 0.1)
		e["heading"] = 0.0   # already facing the target (up)
		saw_windup = saw_windup or float(rr["windup"]) > 0.0
		if rr["fire"]:
			fired = true
			break
	check(saw_windup and fired, "fires only after a visible wind-up")
	var gone := {"valid": true, "pos": Content.v2(e["pos"]) + Vector2(3000, 0), "heat": 80.0}
	EnemyAI.think(e, brain, gone, defn, te, Content.tuning["thermal"], w, 0.1)
	check(e["ai"] == "return", "disengages when the target escapes")
	var cold := {"valid": true, "pos": Content.v2(e["pos"]) + Vector2(0, -500), "heat": 60.0}
	check(EnemyAI.detect_radius(60.0, te) < EnemyAI.detect_radius(110.0, te), "hot mechs are seen from farther away")
	Session.running = false


func test_enemy_overheats_and_is_disabled() -> void:
	var s := _fresh_session()
	var id := _enemy_id()
	var e: Dictionary = s["enemies"][id]
	e["radiator"] = 0.0
	e["heat"] = 100.0
	Session.mech()["pos"] = [100.0, 100.0]  # far away
	for i in 400:
		Session.tick(0.1)
		if e["ai"] == "wreck":
			break
	check(e["ai"] == "wreck", "cooked enemy (no cooling, critical heat) is disabled")
	check(float(e["speed"]) == 0.0, "wreck is stationary")
	var s2 := _fresh_session()
	var e2: Dictionary = s2["enemies"][id]
	e2["integrity"] = 1.0
	var sh := {"owner": "player", "pos": Content.v2(e2["pos"]) + Vector2(-40, -10), "prev": Content.v2(e2["pos"]) + Vector2(-140, -10),
		"vel": Vector2(500, 0), "travelled": 0.0, "range": 600.0, "damage": 7.0, "cooling_damage": 0.1, "structural_cooling_damage": 0.0, "radius": 5.0}
	Session.projectiles = [sh]
	sh["pos"] = sh["prev"]
	Session.tick(0.25)
	check(e2["ai"] == "wreck", "structural destruction disables the enemy")
	Session.running = false
	Saves.delete_slot(3)


func test_wreck_salvage_single_use_and_persistent() -> void:
	var s := _fresh_session(2)
	var id := _enemy_id()
	var e: Dictionary = s["enemies"][id]
	e["ai"] = "wreck"
	e["integrity"] = 0.0
	Session.mech()["pos"] = [Content.v2(e["pos"]).x - 400.0, Content.v2(e["pos"]).y]
	Session.mech()["speed"] = 0.0
	check(Session.exit_mech(), "exit near the wreck")
	s["pilot"]["pos"] = [Content.v2(e["pos"]).x - 80.0, Content.v2(e["pos"]).y]
	var suit0 := float(s["pilot"]["suit"])
	check(Session.request("interact"), "start stripping the wreck")
	for i in 50:
		Session.tick(0.1)
	check(bool(e["salvaged"]), "wreck marked salvaged")
	check(GameState.count(s["pilot"]["pack"], "scrap") == int(Content.tuning["wreck_salvage"]["scrap"]), "scrap recovered")
	check(GameState.count(s["pilot"]["pack"], "radiator_core") == 1, "cooling component recovered")
	check(float(s["pilot"]["suit"]) < suit0 - 4.0, "salvaging costs suit exposure")
	approx(float(s["mech"]["radiator"]), Content.t("thermal", "start_radiator", 0.3), 0.001, "salvage does not repair the mech by itself")
	var again := false
	for it in Session.interactions():
		if it["kind"] == "wreck":
			again = true
	check(not again, "the same wreck cannot be stripped twice")
	check(Session.save_now("test"), "save")
	var r := Saves.load_slot(2)
	var loaded := GameState.sanitize(r["state"], Session.loc)
	check(loaded["enemies"][id]["ai"] == "wreck" and bool(loaded["enemies"][id]["salvaged"]), "defeat + salvage state persisted")
	Session.running = false
	Saves.delete_slot(2)


func test_hull_repair_and_emergency_patch() -> void:
	var s := _fresh_session()
	s["mech"]["integrity"] = 0.0
	s["mech"]["radiator"] = 1.0
	check(not Session.can_drive(), "crippled mech cannot drive")
	check(not Session.can_fire(), "crippled mech cannot fire")
	Session.exit_mech()
	s["pilot"]["pos"] = [float(s["mech"]["pos"][0]) + 140.0, float(s["mech"]["pos"][1])]
	check(Session.request("service"), "emergency patch available without scrap")
	for i in 70:
		Session.tick(0.1)
	approx(float(s["mech"]["integrity"]), 25.0, 0.01, "emergency patch restores minimum integrity")
	GameState.add(s["pilot"]["pack"], "scrap", 2)
	check(Session.request("service"), "scrap hull repair")
	for i in 40:
		Session.tick(0.1)
	approx(float(s["mech"]["integrity"]), 60.0, 0.01, "scrap repair adds integrity")
	check(Session.scrap_available() == 0, "scrap consumed")
	Session.running = false
	Saves.delete_slot(3)


func test_shade_reduces_heat_gain_and_suit_drain() -> void:
	var loc := Content.location()
	var shade := Content.zone_at(loc, Vector2(2220, 1640))
	check(shade["type"] == "shade", "awning shade zone near the encounter")
	var sun := Content.zone_at(loc, Vector2(2220, 1300))
	var th: Dictionary = Content.tuning["thermal"]
	var m := {"heat": 100.0, "radiator": 0.6, "shutters_open": true, "engine": "off"}
	check(Thermal.equilibrium(m, false, 0.0, shade, th) < Thermal.equilibrium(m, false, 0.0, sun, th) - 10.0, "parking in shade lowers the equilibrium")
	var m2 := m.duplicate()
	Thermal.step(m2, shade, th, 1.0, 0.0, false)
	check(float(m2["heat"]) > 90.0, "shade does not instantly remove accumulated heat")
	var s := _fresh_session()
	Session.exit_mech()
	s["pilot"]["pos"] = [2220.0, 1640.0]
	var a := float(s["pilot"]["suit"])
	Session.tick(1.0)
	var shade_drain := a - float(s["pilot"]["suit"])
	s["pilot"]["pos"] = [2220.0, 1300.0]
	a = float(s["pilot"]["suit"])
	Session.tick(1.0)
	var sun_drain := a - float(s["pilot"]["suit"])
	check(shade_drain > 0.0 and shade_drain < sun_drain * 0.6, "shade slows (but does not stop) suit drain")
	Session.running = false
	Saves.delete_slot(3)


func test_migration_v1_to_v2() -> void:
	var loc := Content.location()
	var env := SaveCodec.encode(GameState.create(loc, 1))
	env["version"] = 1
	env["state"]["mech"].erase("integrity")
	env["state"].erase("enemies")
	var up = SaveCodec.migrate(env)
	check(up is Dictionary and int(up["version"]) == SaveCodec.VERSION, "v1 migrates to current")
	check(SaveCodec.validate(up) == "", "migrated save validates")
	var st := GameState.sanitize(up["state"], loc)
	approx(float(st["mech"]["integrity"]), 100.0, 0.01, "integrity added")
	check(st["enemies"].size() == loc["enemies"].size(), "enemies created on load")



# ---------------------------------------------------------------- canyon refuge iteration

func _enc_id() -> String:
	return "enemy_scrapper_02"


func test_housing_rotates_independently() -> void:
	var s := _fresh_session()
	var h0 := float(s["mech"]["heading"])
	Session.housing_angle = h0
	Session.aim_point = Session.mech_pos() + Vector2(-500, 0)   # due west
	for i in 30:
		Session.tick(0.05)
	approx(float(s["mech"]["heading"]), h0, 0.0001, "aiming does not turn the chassis")
	approx(wrapf(Session.housing_angle - (-PI / 2.0), -PI, PI), 0.0, 0.05, "housing turns to face the aim point")
	Session.aim_point = Session.mech_pos() + Vector2(0, 500)
	Session.tick(0.05)
	var moved := absf(wrapf(Session.housing_angle - (-PI / 2.0), -PI, PI))
	check(moved > 0.05 and moved < 0.6, "housing rotation is smooth (rate-limited), not instant")
	Session.running = false


func test_twin_guns_fire_from_both_muzzles_at_target() -> void:
	var s := _fresh_session()
	s["mech"]["engine"] = "running"
	Session.housing_angle = 0.0
	var target := Session.mech_pos() + Vector2(40, -260)   # close, slightly right
	Session.aim_point = target
	for i in 20:
		Session.tick(0.05)
	Session.projectiles.clear()
	Session.fire_held = true
	var origins := []
	for i in 30:
		Session.tick(0.05)
		for sh in Session.projectiles:
			pass
	Session.fire_held = false
	check(Session.projectiles.size() > 0, "guns fire")
	var left := Session.muzzle_pos(0)
	var right := Session.muzzle_pos(1)
	check(left.distance_to(right) > 150.0, "muzzles are on opposite sides of the housing")
	var hit_l := false
	var hit_r := false
	for sh in Session.projectiles:
		var d: Vector2 = (sh["vel"] as Vector2).normalized()
		var o: Vector2 = (sh["pos"] as Vector2) - d * float(sh["travelled"])
		var miss := Combat.seg_dist(o, o + d * 2000.0, target)
		if o.distance_to(left) < 30.0 and miss < 25.0:
			hit_l = true
		if o.distance_to(right) < 30.0 and miss < 25.0:
			hit_r = true
	check(hit_l and hit_r, "both barrels fire from their own muzzle toward the actual target (close range)")
	Session.running = false


func test_parked_encounter_sequence() -> void:
	var s := _fresh_session()
	var id := _enc_id()
	var e: Dictionary = s["enemies"][id]
	check(e["ai"] == "unpiloted" and e["pilot"]["state"] == "outside", "starts unpiloted with the pilot outside")
	var p0 := Content.v2(e["pos"])
	for i in 40:
		Session.tick(0.1)
	check(e["ai"] == "unpiloted" and Content.v2(e["pos"]).distance_to(p0) < 0.5, "parked mech does nothing while unaware")
	# Bring the player close.
	s["mech"]["pos"] = [p0.x + 320.0, p0.y + 120.0]
	var seen := ["unpiloted"]
	var pilot_path := 0.0
	var last := Content.v2(e["pilot"]["pos"])
	for i in 200:
		Session.tick(0.05)
		if seen.is_empty() or seen[-1] != e["ai"]:
			seen.append(e["ai"])
		pilot_path += Content.v2(e["pilot"]["pos"]).distance_to(last)
		last = Content.v2(e["pilot"]["pos"])
		check(e["ai"] != "engage" or e["pilot"]["state"] == "aboard", "never active without a pilot aboard")
	check(seen.slice(0, 5) == ["unpiloted", "alerted", "boarding", "starting", "engage"], "sequence UNPILOTED→ALERTED→BOARDING→STARTING→ACTIVE (%s)" % str(seen))
	check(pilot_path > 60.0, "the pilot really travels to the cockpit (%.0f px)" % pilot_path)
	check(e["pilot"]["state"] == "aboard", "pilot aboard")
	Session.running = false


func test_mech_cannot_move_or_fire_before_startup() -> void:
	var s := _fresh_session()
	var id := _enc_id()
	var e: Dictionary = s["enemies"][id]
	e["ai"] = "starting"
	e["pilot"]["state"] = "aboard"
	Session.brains[id] = {"wp": 0, "t_state": 0.0, "windup": 0.0, "cooldown": 0.0}
	Session.enemy_intents[id] = {"throttle": 1.0, "turn": 1.0}
	var v := Session.enemy_velocity(id, 0.1)
	approx(v.length(), 0.0, 0.001, "no movement during startup")
	Session.projectiles.clear()
	s["mech"]["pos"] = [Content.v2(e["pos"]).x, Content.v2(e["pos"]).y - 300.0]
	for i in 20:
		Session.tick(0.05)
	var enemy_shots := 0
	for sh in Session.projectiles:
		if sh["owner"] == id:
			enemy_shots += 1
	check(enemy_shots == 0, "no firing during startup")
	Session.running = false


func test_encounter_interrupted_and_load_resolution() -> void:
	var s := _fresh_session()
	var id := _enc_id()
	var e: Dictionary = s["enemies"][id]
	e["ai"] = "boarding"
	e["integrity"] = 0.0
	Session.brains[id] = {"wp": 0, "t_state": 0.0, "windup": 0.0, "cooldown": 0.0}
	Session.tick(0.1)
	check(e["ai"] == "wreck", "destroyed while boarding → wreck")
	check(e["pilot"]["state"] == "fled", "pilot outside flees instead of vanishing or boarding")
	for i in 120:
		Session.tick(0.1)
	check(e["pilot"]["state"] == "gone", "fled pilot leaves the scene for good")
	var loc := Content.location()
	for st in ["alerted", "boarding", "starting"]:
		var e2 := GameState.new_enemy(loc["enemies"][1])
		e2["ai"] = st
		var dummy := GameState.create(loc, 1)
		dummy["enemies"][id] = e2
		var clean := GameState.sanitize(dummy, loc)
		var r: Dictionary = clean["enemies"][id]
		check(r["ai"] == "return" and r["pilot"]["state"] == "aboard" and r["engine"] == "running", "loading during '%s' resolves forward, no replay/duplicate" % st)
	var e3 := GameState.new_enemy(loc["enemies"][1])
	e3["ai"] = "wreck"
	var d3 := GameState.create(loc, 1)
	d3["enemies"][id] = e3
	check(GameState.sanitize(d3, loc)["enemies"][id]["pilot"]["state"] == "gone", "a wreck never respawns its pilot")
	Session.running = false
	Saves.delete_slot(3)


func test_refuge_terrain_and_thermal() -> void:
	var loc := Content.location()
	var masses := Content.terrain(loc, "masses")
	check(masses.size() >= 1 and masses[0]["shape"].size() > loc["terrain"]["masses"][0]["polygon"].size(), "rock mass outline is roughened (organic)")
	check(Content.terrain(loc, "masses")[0]["shape"] == masses[0]["shape"], "roughening is deterministic (visual = collision)")
	var road := PackedVector2Array()
	for pt in loc["patches"]:
		if pt["id"] == "track_refuge":
			road = Content.poly(pt["path"])
	for p in road:
		check(not Geometry2D.is_point_in_polygon(p, masses[0]["shape"]), "refuge road stays out of the rock at %s" % str(p))
	var refuge := Content.zone_at(loc, Vector2(-1500, 800))
	var canyon := Content.zone_at(loc, Vector2(-700, 1550))
	var open := Content.zone_at(loc, Vector2(300, 2000))
	check(refuge["type"] == "refuge" and canyon["type"] == "canyon" and open["type"] == "open", "open → canyon → refuge zones")
	var th: Dictionary = Content.tuning["thermal"]
	var m := {"heat": 100.0, "radiator": 0.6, "shutters_open": true, "engine": "off"}
	var eq_r := Thermal.equilibrium(m, false, 0.0, refuge, th)
	var eq_c := Thermal.equilibrium(m, false, 0.0, canyon, th)
	var eq_o := Thermal.equilibrium(m, false, 0.0, open, th)
	check(eq_r < eq_c and eq_c < eq_o, "heat pressure falls gradually toward the refuge (%.0f/%.0f/%.0f)" % [eq_o, eq_c, eq_r])
	check(Thermal.cooling_rate(m, refuge, th) > Thermal.cooling_rate(m, open, th) * 1.3, "mech cools more effectively in the refuge")
	check(float(refuge["suit"]) <= 0.2, "suit exposure low enough for on-foot work")
	var m2 := {"heat": 100.0, "radiator": 0.3, "shutters_open": true, "engine": "off", "integrity": 40.0}
	Thermal.step(m2, refuge, th, 5.0, 0.0, false)
	approx(float(m2["radiator"]), 0.3, 0.0001, "refuge does not repair components")


func test_migration_v2_to_v3_adds_pilots() -> void:
	var loc := Content.location()
	var env := SaveCodec.encode(GameState.create(loc, 1))
	env["version"] = 2
	for id in env["state"]["enemies"]:
		env["state"]["enemies"][id].erase("pilot")
	env["state"]["enemies"].erase(_enc_id())
	var up = SaveCodec.migrate(env)
	check(up is Dictionary and int(up["version"]) == SaveCodec.VERSION, "v2 → current")
	var st := GameState.sanitize(up["state"], loc)
	check(st["enemies"]["enemy_scrapper_01"]["pilot"]["state"] == "aboard", "existing enemy gets an aboard pilot")
	check(st["enemies"][_enc_id()]["ai"] == "unpiloted", "new parked encounter appears in old saves")



# ---------------------------------------------------------------- Southern Junkers iteration

func test_weather_cycle_is_gradual() -> void:
	var tw: Dictionary = Content.tuning["weather"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var w := Weather.create(tw)
	w["next"] = 1.0
	var evs := []
	var prev := 0.0
	var max_jump := 0.0
	for i in 4000:
		var e := Weather.step(w, tw, 0.1, true, rng)
		if e != "":
			evs.append(e)
		max_jump = maxf(max_jump, absf(float(w["intensity"]) - prev))
		prev = float(w["intensity"])
		if e == "storm_over":
			break
	check(evs == ["storm_coming", "storm_peak", "storm_fading", "storm_over"], "clear → building → storm → fading → clear (%s)" % str(evs))
	check(max_jump < 0.01, "intensity changes gradually (max step %.4f)" % max_jump)
	var w2 := Weather.create(tw)
	w2["next"] = 0.5
	for i in 200:
		Weather.step(w2, tw, 0.1, false, rng)
	check(w2["state"] == "clear", "dynamic weather off → stays clear")


func test_storm_effects_and_shelter() -> void:
	var loc := Content.location()
	var tw: Dictionary = Content.tuning["weather"]
	var th: Dictionary = Content.tuning["thermal"]
	var w := {"state": "storm", "intensity": 1.0}
	var open := Content.zone_at(loc, Vector2(300, 2100))
	var refuge := Content.zone_at(loc, Vector2(-1500, 800))
	var so := Weather.apply(open, w, tw)
	var sr := Weather.apply(refuge, w, tw)
	var m := {"heat": 100.0, "radiator": 0.8, "shutters_open": true, "engine": "running"}
	check(Thermal.cooling_rate(m, so, th) < Thermal.cooling_rate(m, open, th) * 0.75, "storm impairs cooling outside")
	check(Thermal.equilibrium(m, true, 1.0, so, th) > Thermal.equilibrium(m, true, 1.0, open, th) + 8.0, "overheating becomes a bigger concern")
	check(float(so["suit"]) > float(open["suit"]) * 1.5, "suit exposure is more dangerous outside")
	check(float(sr["suit"]) < float(open["suit"]) * 0.3 and Weather.felt(w, refuge) < 0.15, "the refuge shelters from the storm")
	check(Weather.visibility(w, open, tw) < 0.7, "storm reduces visibility (detection)")
	var te: Dictionary = Content.tuning["enemy"]
	var e := GameState.new_enemy(loc["enemies"][0])
	e["ai"] = "patrol"
	var brain := {"wp": 0, "t_state": 0.0}
	var near := {"valid": true, "pos": Content.v2(e["pos"]) + Vector2(0, -300), "heat": 70.0, "visibility": 0.55}
	EnemyAI.think(e, brain, near, loc["enemies"][0], te, th, Content.tuning["combat"]["enemy_weapon"], 0.1)
	check(e["ai"] == "patrol", "a mech hidden by the storm at 300 px is not detected")


func test_turret_detect_aim_fire_limit_destroy() -> void:
	var s := _fresh_session()
	var loc: Dictionary = Session.loc
	check(loc["turrets"].size() >= 4, "several perimeter turrets")
	var d: Dictionary = loc["turrets"][0]
	var t: Dictionary = s["turrets"][d["id"]]
	var tt: Dictionary = Content.tuning["turret"]
	var brain := {"windup": 0.0, "cooldown": 0.0}
	var far := {"valid": true, "pos": Content.v2(d["pos"]) + Vector2(0, -900), "visibility": 1.0}
	var r := Turret.step(d, t, brain, far, tt, 0.1, true, true)
	check(not r["engaged"], "out of range → idle")
	var tgt := {"valid": true, "pos": Content.v2(d["pos"]) + Vector2(300, -250), "visibility": 1.0}
	var a0 := float(t["angle"])
	Turret.step(d, t, brain, tgt, tt, 0.1, true, true)
	check(absf(float(t["angle"]) - a0) <= float(tt["turn_rate"]) * 0.1 + 0.001, "turret rotation is rate-limited")
	var fired := false
	var wind := false
	for i in 120:
		var rr := Turret.step(d, t, brain, tgt, tt, 0.1, true, true)
		wind = wind or float(rr["windup"]) > 0.0
		if rr["fire"]:
			fired = true
			break
	check(wind and fired, "turret telegraphs, then fires")
	var brain2 := {"windup": 0.0, "cooldown": 0.0}
	var blocked := false
	for i in 80:
		blocked = blocked or Turret.step(d, t, brain2, tgt, tt, 0.1, false, true)["fire"]
	check(not blocked, "no line of sight → no fire")
	# engagement limiter: put the player among all turrets
	var cx := 0.0
	var cy := 0.0
	for td in loc["turrets"]:
		cx += Content.v2(td["pos"]).x
		cy += Content.v2(td["pos"]).y
	s["mech"]["pos"] = [cx / loc["turrets"].size(), cy / loc["turrets"].size()]
	var max_wind := 0
	for i in 200:
		Session.tick(0.05)
		var n := 0
		for id in Session.turret_view:
			if float(Session.turret_view[id]["windup"]) > 0.0:
				n += 1
		max_wind = maxi(max_wind, n)
	check(max_wind <= int(tt["max_engaged"]), "at most %d turrets wind up at once (saw %d)" % [int(tt["max_engaged"]), max_wind])
	# destroy + persistence
	var sh := {"owner": "player", "pos": Content.v2(d["pos"]), "prev": Content.v2(d["pos"]) + Vector2(-80, 0), "vel": Vector2(500, 0),
		"travelled": 0.0, "range": 600.0, "damage": 100.0, "cooling_damage": 0.0, "structural_cooling_damage": 0.0, "radius": 5.0}
	Session.projectiles = [sh]
	sh["pos"] = sh["prev"]
	Session.tick(0.2)
	check(bool(s["turrets"][d["id"]]["destroyed"]), "turret destroyed by fire")
	var clean := GameState.sanitize(Saves.load_slot(3)["state"], loc)
	check(bool(clean["turrets"][d["id"]]["destroyed"]), "destroyed turret persists")
	Session.running = false
	Saves.delete_slot(3)


func test_junker_type_and_defenders() -> void:
	var loc := Content.location()
	var junkers := 0
	var parked := 0
	for e in loc["enemies"]:
		if e.get("type", "") == "junker":
			junkers += 1
			if e.get("parked", false):
				parked += 1
	check(junkers >= 2 and junkers <= 4, "a few Junker defenders (%d)" % junkers)
	check(parked == 1, "one parked Junker mech reuses the boarding encounter")
	var s := _fresh_session()
	var j: Dictionary = s["enemies"]["junker_yard_guard"]
	approx(float(j["integrity"]), float(Content.tuning["enemy_types"]["junker"]["integrity"]), 0.01, "Junker uses its type stats")
	check(float(j["integrity"]) < 80.0, "modest health")
	Session.running = false


func test_dev_cheats_never_saved() -> void:
	var s := _fresh_session(2)
	Session.mech_spot_free = Callable()
	Session.dev["invulnerable"] = true
	Session.dev["aggression"] = false
	var made := Session.dev_spawn("junker", 2)
	check(made == 2, "spawned 2 dev Junkers")
	var any_dev := false
	for id in s["enemies"]:
		any_dev = any_dev or bool(s["enemies"][id].get("dev", false))
	check(any_dev, "spawned enemies are flagged as dev")
	for id in s["enemies"]:
		if bool(s["enemies"][id].get("dev", false)):
			check(Content.v2(s["enemies"][id]["pos"]).distance_to(Session.mech_pos()) > 300.0, "spawn not on top of the player")
	check(Session.save_now("test"), "save")
	var raw = SafeFile.read_json(Saves.slot_path(2))
	var leaked := false
	for id in raw["state"]["enemies"]:
		leaked = leaked or bool(raw["state"]["enemies"][id].get("dev", false))
	check(not leaked, "dev-spawned mechs are not written to the save")
	check(not FileAccess.get_file_as_string(Saves.slot_path(2)).contains("invulnerable"), "cheat toggles are not in the save")
	s["mech"]["integrity"] = 50.0
	var sh := {"owner": "x", "pos": Session.mech_pos(), "prev": Session.mech_pos() + Vector2(-200, 0), "vel": Vector2(500, 0),
		"travelled": 0.0, "range": 600.0, "damage": 20.0, "cooling_damage": 0.2, "structural_cooling_damage": 0.0, "radius": 5.0}
	Session.projectiles = [sh]
	Session.tick(0.05)
	approx(float(s["mech"]["integrity"]), 50.0, 0.001, "invulnerable blocks damage")
	Session.dev_clear_spawned()
	var left := 0
	for id in s["enemies"]:
		if bool(s["enemies"][id].get("dev", false)):
			left += 1
	check(left == 0, "clear spawned removes dev mechs only")
	Session.start_new(2)
	check(not bool(Session.dev["invulnerable"]) and bool(Session.dev["aggression"]), "cheats reset when a game starts")
	Session.running = false
	Saves.delete_slot(2)


func test_teleports_and_areas() -> void:
	var loc := Content.location()
	for k in ["refuge", "junker_base", "cooling_station", "scrap_field"]:
		check(loc["teleports"].has(k), "teleport target %s" % k)
	var s := _fresh_session()
	check(Session.dev_teleport("junker_base"), "teleport to the Junker base")
	check(Session.area_at(Session.mech_pos()) == "area_junkers", "arrives in Junker territory")
	check(Session.dev_teleport("refuge") and Session.mech_zone["type"] == "refuge", "teleport home to the refuge")
	Session.running = false


func test_migration_v3_to_v4() -> void:
	var loc := Content.location()
	var env := SaveCodec.encode(GameState.create(loc, 1))
	env["version"] = 3
	env["state"].erase("turrets")
	env["state"].erase("weather")
	var up = SaveCodec.migrate(env)
	check(up is Dictionary and int(up["version"]) == 4, "v3 → v4")
	var st := GameState.sanitize(up["state"], loc)
	check(st["turrets"].size() == loc["turrets"].size() and st["weather"]["state"] == "clear", "turrets + clear weather added to old saves")
	check(st["enemies"].has("junker_yard_guard"), "new defenders appear in old saves")
