class_name SoundDirector
extends Node
## Maps simulation state and events to sound. Owns the gameplay soundscape:
##  - exposure: open desert wind (+ faint distant machinery) → canyon (quieter,
##    filtered) → refuge (muffled, generator and lamp hum take over; positional)
##  - mech: engine, cooling fan, housing servo, twin guns, damage, overheating
##  - enemy encounter: pilot shout, climb, cockpit close, startup (positional)
##  - music: the creator's theme plays now and then during calm exploration,
##    never during combat or in the refuge, and fades on transitions.

const CALM_BEFORE_CUE := Vector2(80.0, 140.0)   # seconds of calm exploration before a cue
const CUE_LENGTH := 105.0
const CUE_COOLDOWN := Vector2(240.0, 420.0)

var world: WorldView
var exposure := 1.0
var _beep_t := 0.0
var _step_t := 0.0
var _foot_t := 0.0
var _calm := 0.0
var _next_cue := 0.0
var _cue_t := -1.0
var _rng := RandomNumberGenerator.new()
var storm := 0.0
var _gust_t := 4.0
var _sand_t := 1.0
var _report_alt := false


func _ready() -> void:
	_rng.randomize()
	_next_cue = _rng.randf_range(CALM_BEFORE_CUE.x, CALM_BEFORE_CUE.y)
	Audio.music_stop(4.0)   # gameplay starts in silence + ambience
	Audio.loop("wind", "amb.wind", -6.0)
	Audio.loop("distant", "amb.distant", -30.0)
	Audio.loop("storm", "amb.storm", -60.0)
	Session.mech_event.connect(_on_event)
	Session.combat_event.connect(_on_combat)


func _exit_tree() -> void:
	for k in ["wind", "distant", "engine", "engine_low", "turbo", "fan", "servo", "storm"]:
		Audio.stop_loop(k)
	Audio.set_shelter(0.0)
	Audio.set_storm(0.0)


## 1 open desert, ~0.5 canyon, ~0.1 under the overhang.
func target_exposure() -> float:
	var zt := str((Session.pilot_zone if Session.mode() == "foot" else Session.mech_zone).get("type", ""))
	var cover := world.cover_amount() if world else 0.0
	var e := 1.0
	if zt == "canyon":
		e = 0.5
	elif zt == "refuge":
		e = 0.12
	elif zt == "shade":
		e = 0.8
	return minf(e, 1.0 - cover * 0.88)


var _boost := 0.0
var _rev := 0.0
var _rime_t := 0.0


func _process(delta: float) -> void:
	if not Session.running or get_tree().paused:
		return
	exposure = move_toward(exposure, target_exposure(), delta * 0.45)
	Audio.set_shelter(1.0 - exposure)
	# Sandstorm: louder wind bed + storm layer, gusts, sand ticking on the hull;
	# distant sounds lose clarity (Audio.set_storm), the mech sounds enclosed.
	storm = move_toward(storm, Session.storm_here, delta * 0.3)
	Audio.set_storm(storm)
	Audio.set_loop_params("wind", lerpf(-24.0, -5.0, exposure) + storm * 4.0)
	Audio.set_loop_params("storm", lerpf(-60.0, -2.0, clampf(storm * 1.3, 0.0, 1.0) ** 0.6))
	Audio.set_loop_params("distant", lerpf(-60.0, -27.0, clampf((exposure - 0.6) / 0.4, 0.0, 1.0)) - storm * 30.0)
	if storm > 0.08:
		_gust_t -= delta * (0.4 + storm * 1.4)
		if _gust_t <= 0.0:
			_gust_t = _rng.randf_range(3.0, 7.0)
			Audio.play("sfx.gust" if _rng.randf() < 0.5 else "sfx.gust_b", -14.0 + storm * 9.0, _rng.randf_range(0.6, 0.85), 1500)
		_sand_t -= delta * storm * 6.0
		if _sand_t <= 0.0:
			_sand_t = _rng.randf_range(0.4, 1.2)
			Audio.play("sfx.sand_hit", -24.0 + storm * 8.0, _rng.randf_range(0.8, 1.4), 80)
	_music(delta)
	var m := Session.mech()
	var tt := Session.tun("thermal")
	var frac := absf(float(m["speed"])) / float(Session.car_tun().get("max_speed", 460.0))
	if Session.engine_on():
		# revs follow speed and throttle (a car, not a walker): idle burble → howl
		var thr := absf(Session.drive_throttle) if Session.mode() == "mech" else 0.0
		_rev = lerpf(_rev, clampf(frac * 0.8 + thr * 0.35, 0.0, 1.2), 1.0 - exp(-4.0 * delta))
		# the installed equipment is audible: chassis sets the voice, engine level adds a
		# heavier rumble layer, a turbo whines under load and blows off on lift
		var ch := Session.chassis_id()
		var voice := {"falke": 1.16, "baer": 0.82}.get(ch, 1.0) as float
		var eng := Garage.level(Session.upgrades(), "engine")
		var tur := Garage.level(Session.upgrades(), "turbo")
		Audio.loop("engine", "sfx.car_engine")
		Audio.set_loop_params("engine", -11.0 + _rev * 7.0 + eng * 0.8, (0.62 + _rev * 0.85) * voice * (1.0 - eng * 0.03))
		if eng > 0 or ch == "baer":
			Audio.loop("engine_low", "sfx.mech_engine")
			Audio.set_loop_params("engine_low", -26.0 + eng * 3.0 + (4.0 if ch == "baer" else 0.0) + _rev * 4.0, (0.45 + _rev * 0.4) * voice)
		else:
			Audio.stop_loop("engine_low")
		if tur > 0:
			var load := clampf(thr * _rev, 0.0, 1.0)
			Audio.loop("turbo", "sfx.servo")
			Audio.set_loop_params("turbo", -40.0 + load * (16.0 + tur * 3.0), 2.1 + _rev * 0.9 + tur * 0.15)
			if _boost > 0.6 and thr < 0.15:
				Audio.play("sfx.steam", -16.0 + tur * 2.0, 1.7, 400)   # blow-off valve
			_boost = lerpf(_boost, load, 1.0 - exp(-3.0 * delta))
		else:
			Audio.stop_loop("turbo")
	else:
		Audio.stop_loop("engine")
		Audio.stop_loop("engine_low")
		Audio.stop_loop("turbo")
	var slip := float(m.get("slip", 0.0))
	if Session.mode() == "mech" and slip > float(Session.tun("mech").get("skid_slip", 120.0)) * 0.8:
		Audio.loop("skid", "sfx.tyre_skid")
		Audio.set_loop_params("skid", lerpf(-22.0, -6.0, clampf(slip / 420.0, 0.0, 1.0)), 0.85 + frac * 0.3)
	else:
		Audio.stop_loop("skid")
	_creature_ambience(delta)
	var hs := clampf(Session.housing_speed / 4.0, 0.0, 1.0)
	if hs > 0.04 and Session.mode() == "mech":
		Audio.loop("servo", "sfx.servo")
		Audio.set_loop_params("servo", lerpf(-30.0, -11.0, hs), 0.8 + hs * 0.35)
	else:
		Audio.stop_loop("servo")
	var heat := float(m["heat"])
	if heat > 70.0 and str(m["engine"]) != "off":
		Audio.loop("fan", "sfx.cooling_fan")
		Audio.set_loop_params("fan", -20.0 + clampf((heat - 70.0) / 45.0, 0.0, 1.0) * 12.0 + (0.0 if m["shutters_open"] else -5.0),
			0.85 + float(m["radiator"]) * 0.3)
	else:
		Audio.stop_loop("fan")
	var band := Thermal.band(heat, tt)
	_beep_t -= delta
	if (band == "warning" or band == "critical") and _beep_t <= 0.0:
		Audio.play("sfx.warning", 0.0 if band == "critical" else -4.0)
		_beep_t = 0.7 if band == "critical" else 1.6
	if Session.mode() == "foot" and Session.walk_dir.length() > 0.1:
		_foot_t -= delta
		if _foot_t <= 0.0:
			_foot_t = 0.36
			Audio.play("sfx.footstep", -8.0, randf_range(0.9, 1.1))


## Creatures you can hear before you see: rimeback footfalls (positional
## thuds that shake the camera when close) and the grindback's tremor rumble.
func _creature_ambience(delta: float) -> void:
	var at := Session.actor_pos()
	var tremor := 0.0
	_rime_t -= delta
	for id in Session.state.get("creatures", {}):
		var c: Dictionary = Session.state["creatures"][id]
		var p := Content.v2(c["pos"])
		var d := p.distance_to(at)
		match Creatures.brain(c):
			"grindback":
				if str(c["ai"]) == "tunnel" and d < 1100.0:
					tremor = maxf(tremor, 1.0 - d / 1100.0)
			"rimeback":
				if str(c["ai"]) != "dead" and absf(float(c["speed"])) > 20.0 and d < 1500.0 and _rime_t <= 0.0:
					_rime_t = clampf(90.0 / maxf(absf(float(c["speed"])), 1.0), 0.18, 0.9)
					var vk := _voice(str(c["species"]))
					Audio.play_at("sfx.rime_step", p, world, -4.0 + float(vk[1]), randf_range(0.8, 0.95) * float(vk[0]))
					if world and world.camera and d < 700.0:
						world.camera.add_shake(0.08 * (1.0 - d / 700.0), 0.2)
	if tremor > 0.0:
		Audio.loop("tremor", "sfx.tremor")
		Audio.set_loop_params("tremor", lerpf(-30.0, -2.0, tremor), 0.8)
	else:
		Audio.stop_loop("tremor")


## Music policy: silence is the default during play.
func _music(delta: float) -> void:
	var zt := str((Session.pilot_zone if Session.mode() == "foot" else Session.mech_zone).get("type", ""))
	var calm := not Session.in_combat() and zt != "refuge" and exposure > 0.6
	if _cue_t >= 0.0:
		_cue_t += delta
		if not calm:
			Audio.music_stop(2.5 if Session.in_combat() else 6.0)
			_end_cue()
		elif _cue_t >= CUE_LENGTH:
			Audio.music_stop(10.0)
			_end_cue()
		return
	if calm:
		_calm += delta
		if _calm >= _next_cue:
			start_cue()
	else:
		_calm = maxf(0.0, _calm - delta * 2.0)


func start_cue() -> void:
	_cue_t = 0.0
	Audio.music_play("music.theme_alt", 8.0, 0.0, false)


func _end_cue() -> void:
	_cue_t = -1.0
	_calm = 0.0
	_next_cue = _rng.randf_range(CUE_COOLDOWN.x, CUE_COOLDOWN.y)


func cue_active() -> bool:
	return _cue_t >= 0.0


func _on_event(ev: String) -> void:
	match ev:
		"shutdown":
			Audio.play("sfx.alarm", 0.0, 1.0, 500)
			Audio.play("sfx.steam", -2.0)
		"restart":
			Audio.play("sfx.hatch", -6.0, 0.8)
		"hatch":
			Audio.play("sfx.hatch")
		"pickup":
			Audio.play("sfx.pickup")
		"repaired":
			Audio.play("sfx.repair")
			Audio.play("sfx.steam", -10.0, 1.3)
		"task_repair", "task_salvage", "task_wreck", "task_hull", "task_patch":
			Audio.play("sfx.tool", -4.0)
		"shutters":
			Audio.play("sfx.shutters")
		"suit_warning":
			Audio.play("sfx.suit_alarm", 0.0, 1.0, 400)
		"abrasion":
			Audio.play("sfx.grit", -10.0, randf_range(0.9, 1.1), 900)


func _on_combat(kind: String, data: Dictionary) -> void:
	var pos: Vector2 = data.get("pos", Session.actor_pos())
	match kind:
		"muzzle":
			var owner := str(data.get("owner", ""))
			if owner == "player":
				_weapon_shot(str(data.get("weapon", "mg")), int(data.get("barrel", 0)))
			elif owner == "turret":
				Audio.play_at("sfx.turret_fire", pos, world, -2.0, randf_range(0.7, 0.78))
			else:
				Audio.play_at("sfx.enemy_fire", pos, world, 0.0, 0.62)
		"impact":
			if str(data.get("target", "")) == "world":
				Audio.play_at("sfx.impact", pos, world, -6.0, randf_range(0.9, 1.1))
			else:
				Audio.play_at("sfx.impact_metal", pos, world, -5.0, randf_range(0.85, 1.1))
		"player_hit":
			if str(data.get("kind", "")) == "structure":
				Audio.play("sfx.armor_break", -4.0, randf_range(0.9, 1.05), 150)
		"explosion":
			Audio.play_at("sfx.wreck", pos, world, 3.0, _rng.randf_range(0.62, 0.7))
			Audio.play_at("sfx.impact", pos, world, 0.0, _rng.randf_range(0.45, 0.5))
		"dry_fire":
			Audio.play("sfx.gun_cycle", -8.0, 1.3, 300)
		"weapon_swap":
			Audio.play("sfx.gun_cycle", -6.0, 0.8, 200)
		"cooling_hit":
			Audio.play_at("sfx.cooling_hit", pos, world, -3.0)
		"enemy_windup":
			Audio.play_at("sfx.enemy_charge", pos, world, -4.0)
		"enemy_alert":
			Audio.play("sfx.enemy_alert", -2.0, 1.0, 1500)
		"enemy_disabled":
			Audio.play_at("sfx.wreck", pos, world, 0.0)
			Audio.play_at("sfx.steam", pos, world, -4.0, 0.8)
		"pilot_alert":
			Audio.play_at("sfx.pilot_shout", data.get("pilot", pos), world, 0.0, 0.95)
		"cockpit_closed":
			Audio.play_at("sfx.climb", pos, world, -4.0)
			Audio.play_at("sfx.hatch_close", pos, world, -2.0, 0.8)
		"startup":
			Audio.play_at("sfx.mech_startup", pos, world, 0.0)
			Audio.play_at("sfx.power_up", pos, world, -6.0, 0.7)
		"active":
			Audio.play_at("sfx.hatch", pos, world, -6.0, 0.7)
		"turret_windup":
			Audio.play_at("sfx.enemy_charge", pos, world, -6.0, 1.35)
		"turret_alert":
			Audio.play_at("sfx.servo", pos, world, -8.0, 0.6)
		"turret_destroyed":
			Audio.play_at("sfx.turret_destroyed", pos, world, 0.0)
			Audio.play_at("sfx.steam", pos, world, -6.0, 0.8)
		"collision":
			Audio.play_at("sfx.crash", pos, world, lerpf(-12.0, 0.0, float(data.get("strength", 0.3))), randf_range(0.8, 1.0), 120)
		"creature_alert", "creature_tell":
			var sp0 := str(data.get("species", ""))
			var sp := Creatures.brain({"species": sp0})
			var vk2 := _voice(sp0)
			var pk := float(vk2[0])
			var vol := float(vk2[1])
			var tell := str(data.get("tell", ""))
			if sp == "rimeback":
				if kind == "creature_alert" or tell in ["enrage", "charge", "quake"]:
					# a distant roar carries far — the bigger the animal, the deeper
					Audio.play_at("sfx.rime_roar", pos, world, 2.0 + vol, randf_range(0.85, 1.0) * pk, 600)
				else:
					Audio.play_at("sfx.creature_growl", pos, world, -2.0 + vol, 0.7 * pk)
			elif sp == "skirr":
				Audio.play_at("sfx.skirr_hiss", pos, world, -4.0 + vol, randf_range(1.0, 1.25) * pk, 120)
			elif sp == "grindback":
				Audio.play_at("sfx.creature_growl", pos, world, -2.0 + vol, 0.55 * pk)
		"creature_attack":
			match str(data.get("attack", "")):
				"bite":
					Audio.play_at("sfx.skirr_bite", pos, world, -2.0, randf_range(0.9, 1.1))
				"erupt":
					Audio.play_at("sfx.crash", pos, world, 0.0, 0.55)
				_:
					Audio.play_at("sfx.crash", pos, world, -2.0, 0.7)
		"creature_hit":
			if bool(data.get("armoured", false)):
				Audio.play_at("sfx.impact_metal", pos, world, -6.0, randf_range(1.1, 1.3), 40)
			else:
				Audio.play_at("sfx.flesh_hit", pos, world, -6.0, randf_range(1.2, 1.5), 40)
		"part_broken":
			Audio.play_at("sfx.part_break", pos, world, 0.0, 0.8)
		"creature_dead":
			var dsp := Creatures.brain({"species": str(data.get("species", ""))})
			var vk3 := _voice(str(data.get("species", "")))
			Audio.play_at("sfx.creature_down", pos, world, 0.0 + float(vk3[1]), (0.6 if dsp != "skirr" else 1.1) * float(vk3[0]))
			if dsp == "rimeback":
				Audio.play_at("sfx.rime_roar", pos, world, -2.0 + float(vk3[1]), 0.6 * float(vk3[0]))
		"creature_spit":
			Audio.play_at("sfx.creature_spit", pos, world, -2.0)
		"creature_surface":
			Audio.play_at("sfx.crash", pos, world, 2.0, 0.5)
		"loot_picked":
			if str(data.get("rarity", "")) == "legendary":
				Audio.play("sfx.legendary", 0.0)
				Audio.play("sfx.power_up", -4.0, 0.9)
			else:
				Audio.play("sfx.loot", -6.0, {"common": 1.0, "uncommon": 1.08, "rare": 1.16}.get(str(data.get("rarity", "")), 1.0) as float, 60)
		"garage":
			Audio.play("sfx.garage_fit", -2.0)


## One heavy twin-gun round = four layers on the Weapons bus (compressed and
## limited, so alternating barrels never pile up into distortion):
##   blast (pitched-down shot) → bolt cycling (delayed clack) → metallic ring of
##   the housing → a low, distant report on every other shot.
## Each roof-weapon family has its own voice, layered from the gun clips.
func _weapon_shot(weapon: String, barrel: int) -> void:
	match weapon:
		"flak":
			Audio.play("sfx.gun_fire", 1.0, _rng.randf_range(0.48, 0.54), 25)
			Audio.play("sfx.gun_report", -4.0, _rng.randf_range(0.45, 0.5), 25)
			Audio.play("sfx.impact", -10.0, _rng.randf_range(0.6, 0.7), 25)
		"autocannon":
			Audio.play("sfx.gun_fire_b", 2.0, _rng.randf_range(0.42, 0.46), 25)
			Audio.play("sfx.gun_ring", -8.0, _rng.randf_range(0.3, 0.34), 25)
			get_tree().create_timer(0.12).timeout.connect(func() -> void:
				Audio.play("sfx.gun_cycle", -6.0, _rng.randf_range(0.5, 0.56), 25))
		"rifle":
			Audio.play("sfx.gun_report", 2.0, _rng.randf_range(0.95, 1.02), 25)
			Audio.play("sfx.gun_ring", -6.0, _rng.randf_range(0.62, 0.68), 25)
			Audio.play("sfx.gun_fire", -6.0, _rng.randf_range(0.36, 0.4), 25)
		"launcher":
			Audio.play("sfx.steam", -2.0, _rng.randf_range(0.6, 0.66), 25)
			Audio.play("sfx.gun_fire_b", -6.0, _rng.randf_range(0.34, 0.38), 25)
		_:
			_heavy_shot(barrel)


func _heavy_shot(barrel: int) -> void:
	Audio.play("sfx.gun_fire" if barrel == 0 else "sfx.gun_fire_b", -2.0, _rng.randf_range(0.7, 0.78), 25)
	Audio.play("sfx.gun_ring", -15.0, _rng.randf_range(0.42, 0.5), 25)
	get_tree().create_timer(0.085).timeout.connect(func() -> void:
		Audio.play("sfx.gun_cycle", -11.0, _rng.randf_range(0.72, 0.85), 25))
	_report_alt = not _report_alt
	if _report_alt:
		get_tree().create_timer(0.05).timeout.connect(func() -> void:
			Audio.play("sfx.gun_report", -12.0 - storm * 6.0, _rng.randf_range(0.62, 0.7), 60))


## [pitch multiplier, volume offset dB] for a species: apexes are deeper and louder,
## the Aschenläufer shriller, the Glutkriecher hoarse and low.
func _voice(species: String) -> Array:
	var ts: Dictionary = Session.creature_tuning().get(species, {})
	var sc := float(ts.get("scale", 1.0))
	var p := 1.0 / sqrt(maxf(sc, 0.3))
	match species:
		"aschenlaeufer":
			p *= 1.18
		"glutkriecher", "glutmutter":
			p *= 0.82
		"dornmaul", "dornkoenig":
			p *= 0.9
	return [p, 3.0 if bool(ts.get("apex", false)) else 0.0]
