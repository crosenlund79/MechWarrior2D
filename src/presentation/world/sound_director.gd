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
	for k in ["wind", "distant", "engine", "fan", "servo", "storm"]:
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
		Audio.loop("engine", "sfx.car_engine")
		Audio.set_loop_params("engine", -11.0 + _rev * 7.0, 0.62 + _rev * 0.85)
	else:
		Audio.stop_loop("engine")
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
		match str(c["species"]):
			"grindback":
				if str(c["ai"]) == "tunnel" and d < 1100.0:
					tremor = maxf(tremor, 1.0 - d / 1100.0)
			"rimeback":
				if str(c["ai"]) != "dead" and absf(float(c["speed"])) > 20.0 and d < 1500.0 and _rime_t <= 0.0:
					_rime_t = clampf(90.0 / maxf(absf(float(c["speed"])), 1.0), 0.18, 0.9)
					Audio.play_at("sfx.rime_step", p, world, -4.0, randf_range(0.8, 0.95))
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
				_heavy_shot(int(data.get("barrel", 0)))
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
			var sp := str(data.get("species", ""))
			var tell := str(data.get("tell", ""))
			if sp == "rimeback":
				if kind == "creature_alert" or tell == "enrage" or tell == "charge":
					Audio.play_at("sfx.rime_roar", pos, world, 2.0, randf_range(0.85, 1.0), 600)
				else:
					Audio.play_at("sfx.creature_growl", pos, world, -2.0, 0.7)
			elif sp == "skirr":
				Audio.play_at("sfx.skirr_hiss", pos, world, -4.0, randf_range(1.0, 1.25), 120)
			elif sp == "grindback":
				Audio.play_at("sfx.creature_growl", pos, world, -2.0, 0.55)
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
			Audio.play_at("sfx.creature_down", pos, world, 0.0, 0.6 if str(data.get("species", "")) != "skirr" else 1.1)
			if str(data.get("species", "")) == "rimeback":
				Audio.play_at("sfx.rime_roar", pos, world, -2.0, 0.6)
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
func _heavy_shot(barrel: int) -> void:
	Audio.play("sfx.gun_fire" if barrel == 0 else "sfx.gun_fire_b", -2.0, _rng.randf_range(0.7, 0.78), 25)
	Audio.play("sfx.gun_ring", -15.0, _rng.randf_range(0.42, 0.5), 25)
	get_tree().create_timer(0.085).timeout.connect(func() -> void:
		Audio.play("sfx.gun_cycle", -11.0, _rng.randf_range(0.72, 0.85), 25))
	_report_alt = not _report_alt
	if _report_alt:
		get_tree().create_timer(0.05).timeout.connect(func() -> void:
			Audio.play("sfx.gun_report", -12.0 - storm * 6.0, _rng.randf_range(0.62, 0.7), 60))
