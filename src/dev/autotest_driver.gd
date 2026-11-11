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


## Enemy commands act on one enemy: `id=<enemy id>` anywhere in the line, else the first.
func _target_ids(a: PackedStringArray) -> Array:
	for t in a:
		if t.begins_with("id="):
			return [t.substr(3)]
	var ids: Array = Session.state.get("enemies", {}).keys()
	return ids.slice(0, 1)


func _run(line: String) -> void:
	var parts := line.split(" ", false)
	var cmd := parts[0] if parts.size() > 0 else ""
	var targets := _target_ids(parts)
	var a := PackedStringArray()
	var cid := ""
	for t in parts.slice(1):
		if t.begins_with("cid="):
			cid = t.substr(4)
		elif not t.begins_with("id="):
			a.append(t)
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
			var stuck := 0.0
			var backing := 0.0
			while t < limit and Session.running and Session.mech_pos().distance_to(target) > 60.0:
				var to := target - Session.mech_pos()
				var want := atan2(to.x, -to.y)
				var diff := wrapf(want - float(Session.mech()["heading"]), -PI, PI)
				var spd := float(Session.mech()["speed"])
				if backing > 0.0:
					# un-stick: reverse with opposite lock
					backing -= get_physics_process_delta_time()
					Session.drive_throttle = -1.0
					Session.drive_turn = -signf(diff)
				else:
					# a car: steer while rolling; slow down for tight turns and the stop
					var dist := to.length()
					var desired := clampf(dist * 1.3, 110.0, 520.0)
					if absf(diff) > 1.0:
						desired = minf(desired, 150.0)
					Session.drive_turn = clampf(diff * 2.2, -1.0, 1.0)
					Session.drive_throttle = clampf((desired - spd) / 110.0, -1.0, 1.0)
					stuck = stuck + get_physics_process_delta_time() if absf(spd) < 25.0 else 0.0
					if stuck > 1.2:
						stuck = 0.0
						backing = 0.9
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
		"handbrake":  # handbrake <0|1>
			Session.drive_handbrake = a.size() > 0 and a[0] == "1"
		"spawn_creature":  # spawn_creature <species> [n]
			var n := Session.dev_spawn_creature(a[0], int(a[1]) if a.size() > 1 else 1)
			ok = n > 0
		"set_creature":  # set_creature <x> <y> [ai] cid=..
			var c: Dictionary = Session.creature(cid)
			if c.is_empty():
				ok = false
				err = "no creature " + cid
			else:
				c["pos"] = [float(a[0]), float(a[1])]
				if a.size() > 2:
					c["ai"] = a[2]
					Session.creature_brains.get(cid, {})["t"] = 0.0
				c["speed"] = 0.0
				if main and main.game and main.game.world.creature_views.has(cid):
					main.game.world.creature_views[cid].global_position = Content.v2(c["pos"])
		"creature_hp":  # creature_hp <hp> cid=..
			Session.creature(cid)["hp"] = float(a[0])
		"break_part":  # break_part <part> cid=..
			var c2: Dictionary = Session.creature(cid)
			c2["parts"][a[0]] = 0.0
		"aim_creature":  # aim_creature [part] cid=..
			var c3: Dictionary = Session.creature(cid)
			var part := a[0] if a.size() > 0 else "body"
			var off := Content.v2(Session.creature_tun(c3).get("parts", {}).get(part, {}).get("offset", [0, 0]))
			Session.aim_point = Content.v2(c3["pos"]) + off.rotated(float(c3["heading"]))
		"fire_at_creature":  # fire_at_creature <seconds> [part] cid=..: hold fire, tracking the part
			var t7 := 0.0
			var part2 := a[1] if a.size() > 1 else "body"
			while t7 < float(a[0]) and not Creatures.is_dead(Session.creature(cid)):
				var c4: Dictionary = Session.creature(cid)
				var off2 := Content.v2(Session.creature_tun(c4).get("parts", {}).get(part2, {}).get("offset", [0, 0]))
				Session.aim_point = Content.v2(c4["pos"]) + off2.rotated(float(c4["heading"]))
				Session.fire_held = true
				await get_tree().physics_frame
				t7 += get_physics_process_delta_time()
			Session.fire_held = false
		"garage":  # garage fit <module> | garage repair
			if a.size() > 1 and a[0] == "fit":
				ok = Session.garage_fit(a[1])
			elif a.size() > 0 and a[0] == "repair":
				ok = Session.garage_repair()
			else:
				ok = Session.at_garage()
			if not ok:
				err = "garage action refused"
		"give_materials":
			Session.dev_give_materials()
		"aim":  # aim <x> <y> (world)
			Session.aim_point = Vector2(float(a[0]), float(a[1]))
		"aim_enemy":  # aim at an enemy, optional local offset: aim_enemy [ox oy] [id=..]
			for eid in targets:
				var e: Dictionary = Session.state["enemies"][eid]
				var off := Vector2(float(a[0]), float(a[1])) if a.size() >= 2 else Vector2.ZERO
				Session.aim_point = Content.v2(e["pos"]) + off.rotated(float(e["heading"]))
		"fire_for":  # fire_for <seconds> [track]: hold the trigger, optionally re-aiming at the enemy's cooling area
			var t5 := 0.0
			var track := a.size() > 1
			while t5 < float(a[0]):
				Session.fire_held = true
				if track:
					for eid in targets:
						var e2: Dictionary = Session.state["enemies"][eid]
						if str(e2["ai"]) != "wreck":
							Session.aim_point = Combat.cooling_point(Content.v2(e2["pos"]), float(e2["heading"]), Session.tun("combat")["enemy_hit"]) if a[1] == "cooling" else Content.v2(e2["pos"])
				await get_tree().physics_frame
				t5 += get_physics_process_delta_time()
			Session.fire_held = false
		"fire_shot":  # fire exactly when the guns are ready, return 2 frames later (for screenshots)
			var t6 := 0.0
			while t6 < 2.0:
				Session.fire_held = true
				await get_tree().physics_frame
				t6 += get_physics_process_delta_time()
				if Session._fire_cd > 0.2:
					break
			Session.fire_held = false
			await get_tree().process_frame
			await get_tree().process_frame
		"fire_capture":  # fire_capture <path> [frames_after]: one shot, then a screenshot N frames later
			var t7 := 0.0
			while t7 < 2.0:
				Session.fire_held = true
				await get_tree().physics_frame
				t7 += get_physics_process_delta_time()
				if Session._fire_cd > 0.2:
					break
			Session.fire_held = false
			for k in int(a[1]) if a.size() > 1 else 2:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var img2 := get_viewport().get_texture().get_image()
			ok = img2 != null and img2.save_png(a[0]) == OK
		"set_enemy":  # set_enemy <x> <y> <heading_deg> [ai] [id=..]
			for eid in targets:
				var e3: Dictionary = Session.state["enemies"][eid]
				e3["pos"] = [float(a[0]), float(a[1])]
				e3["heading"] = deg_to_rad(float(a[2]))
				e3["speed"] = 0.0
				if a.size() > 3:
					e3["ai"] = a[3]
				if main.game:
					main.game.world.enemy_views[eid].sync_from_state()
			await _wait(0.1)
		"music_seek":  # music_seek <seconds before the end of the current track>
			var pl: AudioStreamPlayer = Audio._music[Audio._music_cur]
			if pl.playing and pl.stream:
				pl.seek(maxf(0.0, pl.stream.get_length() - float(a[0])))
			await _wait(0.2)
		"menu_music":
			Audio.music_play("music.theme", 0.5)
			await _wait(0.6)
		"devmenu":  # devmenu on|off
			if main.game:
				main.game.devmenu.visible = a[0] == "on"
				DevMenu.is_open = main.game.devmenu.visible
			await _wait(0.2)
		"dev":  # dev <action> [arg]: spawn <type> <n> | clear | weather <start|stop|clear|intensity> [v] | teleport <place> | repair | cooling | toggle <key> | speed <x> | reset
			match a[0]:
				"spawn":
					ok = Session.dev_spawn(a[1], int(a[2]) if a.size() > 2 else 1) > 0
				"clear":
					Session.dev_clear_spawned()
				"weather":
					Session.dev_weather(a[1], float(a[2]) if a.size() > 2 else -1.0)
				"teleport":
					ok = Session.dev_teleport(a[1])
				"repair":
					Session.dev_repair_all()
				"cooling":
					Session.dev_restore_cooling()
				"toggle":
					Session.dev[a[1]] = not bool(Session.dev[a[1]])
				"speed":
					Session.dev["time_scale"] = float(a[1])
					Session.time_scale = float(a[1])
				"reset":
					Session.dev_reset()
			await _wait(0.15)
		"engine_speed":  # test-only: speeds up physics + sim for long traversals
			Engine.time_scale = float(a[0])
			await _wait(0.1)
		"music_cue":
			if main.game:
				main.game.sound.start_cue()
			await _wait(0.2)
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
		"asset_sources": Assets.source.duplicate(), "recent_slot": Saves.most_recent_slot(), "music_id": Audio.music_id, "music_pos": Audio.music_position(),
		"music_bus_db": AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))}
	if Session.running:
		st["game"] = Session.state.duplicate(true)
		st["interactions"] = Session.interactions()
		st["hint"] = Session.hint()
		st["zone"] = Session.mech_zone.get("id", "")
		st["projectiles"] = Session.projectiles.size()
		st["housing_angle"] = Session.housing_angle
		st["dev"] = Session.dev.duplicate()
		st["storm_here"] = Session.storm_here
		st["area"] = Session.area_at(Session.actor_pos())
		st["turret_view"] = Session.turret_view.duplicate(true)
		st["tracker"] = Session.tracker()
		st["hunting"] = Session.hunting()
		st["cargo"] = [Session.cargo_bulk(), Session.cargo_capacity()]
		st["max_integrity"] = Session.max_integrity()
		st["at_garage"] = Session.at_garage()
		st["noise"] = Session.noise()
		st["car"] = {"max_speed": Session.car_tun()["max_speed"], "grip": Session.car_tun()["grip"], "accel": Session.car_tun()["accel"],
			"cooling_coeff": Session.car_thermal()["cooling_coeff"], "damage": Session.player_weapon()["damage"], "cooldown": Session.player_weapon()["cooldown"]}
		var briefs := {}
		for k in Session.creature_brains:
			var b: Dictionary = Session.creature_brains[k]
			briefs[k] = {"tell": str(b.get("tell_kind", "")), "t": float(b.get("t", 0.0))}
		st["creature_brains"] = briefs
		if main and main.game:
			st["recoil"] = main.game.world.mech_view.recoil_state()
			st["shake"] = main.game.world.camera._trauma
			st["enemy_views"] = main.game.world.enemy_views.size()
			st["creature_views"] = main.game.world.creature_views.size()
			st["garage_open"] = main.game.hud.garage != null
		if main and main.game:
			st["cover"] = main.game.world.cover_amount()
			st["exposure"] = main.game.sound.exposure
			st["music_cue"] = main.game.sound.cue_active()
		st["gun_angle"] = Session.gun_angle
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
