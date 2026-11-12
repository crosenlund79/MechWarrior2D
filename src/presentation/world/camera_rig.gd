class_name CameraRig
extends Camera2D
## Follows the active actor (mech or pilot) with exponential smoothing
## (1 − exp(−6·dt), Red Thaw recipe), a small look-ahead while driving, and the
## player's zoom setting (× 1.1 per step, 0.5–2.0) times a mode factor
## (on foot the camera moves closer). Clamped to the location bounds.

const ZOOM_MIN := 0.5
const ZOOM_MAX := 2.0
const FOOT_FACTOR := 1.3
## In the car the camera sits farther out, and pulls back further with speed so
## fast driving shows what is coming (zoom < 1 = wider view).
const CAR_FACTOR := 0.74
const CAR_SPEED_PULLBACK := 0.16

var _look := Vector2.ZERO
var _trauma := 0.0
var _shake_t := 0.0


## Short, decaying screen shake (trauma² drives the offset).
func add_shake(amount: float, cap: float = 0.45) -> void:
	_trauma = minf(cap, _trauma + amount)
var _zoom := 1.0


func _ready() -> void:
	top_level = true
	_zoom = _target_zoom()
	zoom = Vector2(_zoom, _zoom)
	var b: Array = Session.loc.get("bounds", [0, 0, 3600, 2600])
	limit_left = int(b[0])
	limit_top = int(b[1])
	limit_right = int(b[0] + b[2])
	limit_bottom = int(b[1] + b[3])
	snap()


func snap() -> void:
	global_position = Session.actor_pos()
	reset_smoothing()


func _target_zoom() -> float:
	var z := float(Settings.get_value("zoom", 1.0))
	if Session.mode() == "foot":
		return z * FOOT_FACTOR
	var frac := 0.0
	if Session.running and not Session.state.is_empty():
		frac = clampf(absf(float(Session.mech()["speed"])) / maxf(float(Session.car_tun().get("max_speed", 560.0)), 1.0), 0.0, 1.0)
	return z * CAR_FACTOR * (1.0 - CAR_SPEED_PULLBACK * frac)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("zoom_in"):
		Settings.set_value("zoom", clampf(float(Settings.get_value("zoom", 1.0)) * 1.1, ZOOM_MIN, ZOOM_MAX))
	elif event.is_action_pressed("zoom_out"):
		Settings.set_value("zoom", clampf(float(Settings.get_value("zoom", 1.0)) / 1.1, ZOOM_MIN, ZOOM_MAX))


func _process(delta: float) -> void:
	if not Session.running:
		return
	var target := Session.actor_pos()
	if Session.mode() == "mech":
		var h := float(Session.mech()["heading"])
		var ahead := Vector2(sin(h), -cos(h)) * float(Session.mech()["speed"]) * 0.9
		_look = _look.lerp(ahead, 1.0 - exp(-2.0 * delta))
	else:
		_look = _look.lerp(Vector2.ZERO, 1.0 - exp(-3.0 * delta))
	global_position = global_position.lerp(target + _look, 1.0 - exp(-6.0 * delta))
	_zoom = lerpf(_zoom, _target_zoom(), 1.0 - exp(-2.5 * delta))
	zoom = Vector2(_zoom, _zoom)
	_trauma = maxf(0.0, _trauma - delta * 1.2)
	_shake_t += delta * 38.0
	var s := _trauma * _trauma * 26.0
	offset = Vector2(sin(_shake_t * 1.13) + sin(_shake_t * 2.7) * 0.5, cos(_shake_t * 0.97) + sin(_shake_t * 2.1) * 0.5) * s
	rotation = 0.0
