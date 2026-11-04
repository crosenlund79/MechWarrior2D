class_name AutotestDriver
extends Node
## Test-only remote control, active only with `-- --autotest`. Reads one command
## per line from <user_root>/autotest_inbox.txt and writes the result plus a
## state report to <user_root>/autotest_outbox.json (see tools/hs_driver.py).
## Commands use the same Session request paths as the player.

var main: Node
var _inbox := ""
var _outbox := ""
var _done := 0
var _busy := false
var _notices: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_inbox = Paths.user_root() + "autotest_inbox.txt"
	_outbox = Paths.user_root() + "autotest_outbox.json"
	if FileAccess.file_exists(_inbox):
		DirAccess.remove_absolute(_inbox)
	Session.notice.connect(func(k: String, _a: Array) -> void:
		_notices.append(k)
		if _notices.size() > 30:
			_notices.pop_front())
	_write({"seq": 0, "cmd": "ready", "ok": true, "error": "", "state": _state()})


func _process(_delta: float) -> void:
	if _busy or not FileAccess.file_exists(_inbox):
		return
	var lines := FileAccess.get_file_as_string(_inbox).split("\n", false)
	if lines.size() <= _done:
		return
	var line := lines[_done].strip_edges()
	_done += 1
	_busy = true
	await _run(line)
	_busy = false


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, true).timeout


func _run(line: String) -> void:
	var parts := line.split(" ", false)
	var cmd := parts[0] if parts.size() > 0 else ""
	var a := parts.slice(1)
	var ok := true
	var err := ""
	match cmd:
		"new":
			PlayerInput.driver_control = true
			Session.start_new(int(a[0]) if a.size() > 0 else 1)
			await _wait(0.3)
		"continue":
			PlayerInput.driver_control = true
			err = Session.continue_slot(int(a[0]) if a.size() > 0 else Saves.most_recent_slot())
			ok = err == ""
			await _wait(0.3)
		"drive":  # drive <throttle> <turn> <seconds>
			Session.drive_throttle = float(a[0])
			Session.drive_turn = float(a[1])
			await _wait(float(a[2]))
			Session.drive_throttle = 0.0
			Session.drive_turn = 0.0
		"drive_to":  # drive_to <x> <y> [timeout]: steer the mech toward a point
			var target := Vector2(float(a[0]), float(a[1]))
			var limit := float(a[2]) if a.size() > 2 else 30.0
			var t := 0.0
			while t < limit and Session.running and Session.mech_pos().distance_to(target) > 60.0:
				var to := target - Session.mech_pos()
				var want := atan2(to.x, -to.y)
				var diff := wrapf(want - float(Session.mech()["heading"]), -PI, PI)
				Session.drive_turn = clampf(diff * 2.0, -1.0, 1.0)
				Session.drive_throttle = 1.0 if absf(diff) < 0.6 else 0.25
				if Session.mech_pos().distance_to(target) < 220.0:
					Session.drive_throttle = minf(Session.drive_throttle, 0.4)
				await get_tree().physics_frame
				t += get_physics_process_delta_time()
			Session.drive_throttle = 0.0
			Session.drive_turn = 0.0
			ok = Session.mech_pos().distance_to(target) <= 60.0
			if not ok:
				err = "did not reach target"
		"stop":  # brake until (almost) stationary
			Session.drive_throttle = 0.0
			Session.drive_turn = 0.0
			var t2 := 0.0
			while absf(float(Session.mech()["speed"])) > 2.0 and t2 < 10.0:
				await get_tree().physics_frame
				t2 += get_physics_process_delta_time()
		"walk_to":  # walk_to <x> <y> [timeout]
			var target2 := Vector2(float(a[0]), float(a[1]))
			var limit2 := float(a[2]) if a.size() > 2 else 30.0
			var t3 := 0.0
			while t3 < limit2 and Session.running and Session.mode() == "foot" and Session.pilot_pos().distance_to(target2) > 12.0:
				Session.walk_dir = (target2 - Session.pilot_pos()).normalized()
				await get_tree().physics_frame
				t3 += get_physics_process_delta_time()
			Session.walk_dir = Vector2.ZERO
			ok = Session.pilot_pos().distance_to(target2) <= 12.0
			if not ok:
				err = "did not reach target"
		"interact":
			ok = Session.request("interact")
		"service":
			ok = Session.request("service")
		"wait":
			await _wait(float(a[0]))
		"wait_task":
			var t4 := 0.0
			while not Session.task.is_empty() and t4 < 20.0:
				await get_tree().physics_frame
				t4 += get_physics_process_delta_time()
		"debug":  # debug <action> [value]
			Session.debug(a[0], float(a[1]) if a.size() > 1 else 0.0)
		"set_mech":  # set_mech <x> <y> <heading_deg>
			Session.mech()["pos"] = [float(a[0]), float(a[1])]
			Session.mech()["heading"] = deg_to_rad(float(a[2]) if a.size() > 2 else 0.0)
			Session.mech()["speed"] = 0.0
			if main.game:
				main.game.world.mech_view.sync_from_state()
				main.game.world.camera.snap()
			await _wait(0.1)
		"save":
			ok = Session.save_now("autotest")
		"menu":
			Session.end_session("menu")
			await _wait(0.3)
		"setting":  # setting <key> <value>
			var v: Variant = a[1]
			if a[1].is_valid_float():
				v = float(a[1])
			Settings.set_value(a[0], v)
		"rebind":
			Settings.rebind(a[0], OS.find_keycode_from_string(a[1]))
		"reload_assets":
			Assets.reload()
			await _wait(0.2)
		"ui":  # ui dev|pause|settings on|off
			var on := a.size() < 2 or a[1] == "on"
			match a[0]:
				"dev":
					if main.game:
						main.game.dev.visible = on
				"hud":
					if main.game:
						main.game.hud.visible = on
				"grade":
					if main.game:
						main.game.world.atmosphere.set_enabled(on)
				"pause":
					if main.game and on != get_tree().paused:
						main.game.toggle_pause()
				"settings":
					if on:
						main.open_settings()
					else:
						for c in main.settings_layer.get_children():
							c.queue_free()
			await _wait(0.2)
		"window":
			get_window().size = Vector2i(int(a[0]), int(a[1]))
			await _wait(0.4)
		"screenshot":
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			err = error_string(img.save_png(a[0])) if img else "no image"
			ok = img != null
			if ok:
				err = ""
		"quit":
			_write({"seq": _done, "cmd": cmd, "ok": true, "error": "", "state": _state()})
			if Session.running:
				Session.save_now("quit")
			get_tree().quit()
			return
		_:
			ok = false
			err = "unknown command: " + cmd
	_write({"seq": _done, "cmd": line, "ok": ok, "error": err, "state": _state()})


func _state() -> Dictionary:
	var st := {"running": Session.running, "notices": _notices.duplicate(), "save_status": Session.save_status,
		"recovered": Session.recovered_from_backup, "paused": get_tree().paused,
		"settings": Settings.values.duplicate(), "bindings": Settings.bindings.duplicate(),
		"asset_sources": Assets.source.duplicate(), "recent_slot": Saves.most_recent_slot()}
	if Session.running:
		st["game"] = Session.state.duplicate(true)
		st["interactions"] = Session.interactions()
		st["hint"] = Session.hint()
		st["zone"] = Session.mech_zone.get("id", "")
		st["pilot_zone"] = Session.pilot_zone.get("id", "")
		if main and main.game:
			st["roof_faded"] = main.game.world.any_roof_overhead()
	return st


func _write(d: Dictionary) -> void:
	var f := FileAccess.open(_outbox + ".tmp", FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(d))
	f.close()
	DirAccess.rename_absolute(_outbox + ".tmp", _outbox)
