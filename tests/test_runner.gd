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
	for id in ["sfx.warning", "amb.wind", "music.drone", "ui.click"]:
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
