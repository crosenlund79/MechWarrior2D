class_name SoundDirector
extends Node
## Maps simulation state and events to sounds. Loops: desert wind (Ambience),
## mech engine + cooling fan (SFX, pitch/volume follow speed and heat).
## One-shots: warning beeps, shutdown alarm, steam, hatch, pickup, repair, suit alarm.

var _beep_t := 0.0
var _step_t := 0.0
var _foot_t := 0.0


func _ready() -> void:
	Audio.loop("wind", "amb.wind", -2.0)
	Session.mech_event.connect(_on_event)


func _exit_tree() -> void:
	for k in ["wind", "engine", "fan"]:
		Audio.stop_loop(k)


func _process(delta: float) -> void:
	if not Session.running or get_tree().paused:
		return
	var m := Session.mech()
	var tt := Session.tun("thermal")
	var frac := absf(float(m["speed"])) / float(Session.tun("mech").get("max_speed", 150.0))
	if Session.engine_on():
		Audio.loop("engine", "sfx.mech_engine")
		Audio.set_loop_params("engine", -10.0 + frac * 6.0, 0.8 + frac * 0.35)
	else:
		Audio.stop_loop("engine")
	var heat := float(m["heat"])
	var fan_on := heat > 70.0 and str(m["engine"]) != "off"
	if fan_on:
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
	if frac > 0.1 and Session.engine_on():
		_step_t -= delta * (0.9 + frac * 1.6)
		if _step_t <= 0.0:
			_step_t = 1.0
			Audio.play("sfx.mech_step", -6.0 + frac * 3.0, randf_range(0.9, 1.05))
	if Session.mode() == "foot" and Session.walk_dir.length() > 0.1:
		_foot_t -= delta
		if _foot_t <= 0.0:
			_foot_t = 0.36
			Audio.play("sfx.footstep", -8.0, randf_range(0.9, 1.1))


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
		"task_repair", "task_salvage":
			Audio.play("sfx.tool", -4.0)
		"shutters":
			Audio.play("sfx.shutters")
		"suit_warning":
			Audio.play("sfx.suit_alarm", 0.0, 1.0, 400)
		"abrasion":
			Audio.play("sfx.grit", -10.0, randf_range(0.9, 1.1), 900)
