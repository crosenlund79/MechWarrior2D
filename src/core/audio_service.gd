extends Node
## Autoload `Audio`: creates the bus layout (Master → Music, Ambience, SFX, UI),
## plays named sounds from the asset manifest (one-shots and loops) and lets
## volumes come from Settings. Sounds resolve through `Assets`, so creator
## overrides work the same way as for sprites.

var _loops := {}       # key -> AudioStreamPlayer
var _pool: Array[AudioStreamPlayer] = []
var _last_play := {}   # id -> msec, prevents machine-gun repeats


func _init() -> void:
	_ensure_buses()


func _ensure_buses() -> void:
	for bus_name in ["Music", "Ambience", "SFX", "UI"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus_name)
			AudioServer.set_bus_send(i, "Master")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	Assets.reloaded.connect(_on_assets_reloaded)


func _bus_for(id: String) -> String:
	var e := AssetCatalog.entry(id)
	return str(e.get("bus", "SFX"))


## One-shot. `min_gap_ms` suppresses repeats of the same id.
func play(id: String, volume_db: float = 0.0, pitch: float = 1.0, min_gap_ms: int = 60) -> void:
	var now := Time.get_ticks_msec()
	if now - int(_last_play.get(id, -100000)) < min_gap_ms:
		return
	_last_play[id] = now
	var stream := Assets.audio_stream(id)
	if stream == null:
		return
	var p: AudioStreamPlayer = null
	for cand in _pool:
		if not cand.playing:
			p = cand
			break
	if p == null:
		p = _pool[0]
	p.stream = stream
	p.bus = _bus_for(id)
	p.volume_db = volume_db + float(AssetCatalog.entry(id).get("volume_db", 0.0))
	p.pitch_scale = pitch
	p.play()


## Starts (or keeps) a looping sound under `key`. Looping restarts on finish, so
## any WAV/OGG works without special import flags.
func loop(key: String, id: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var p: AudioStreamPlayer = _loops.get(key)
	if p == null:
		p = AudioStreamPlayer.new()
		p.name = "Loop_" + key
		add_child(p)
		p.finished.connect(func() -> void: if p.has_meta("looping"): p.play())
		_loops[key] = p
	var stream := Assets.audio_stream(id)
	p.set_meta("id", id)
	p.set_meta("base_db", volume_db)
	p.volume_db = volume_db + float(AssetCatalog.entry(id).get("volume_db", 0.0))
	p.pitch_scale = pitch
	p.bus = _bus_for(id)
	if p.stream != stream:
		p.stream = stream
		if stream != null:
			p.set_meta("looping", true)
			p.play()
	elif stream != null and not p.playing:
		p.set_meta("looping", true)
		p.play()


func set_loop_params(key: String, volume_db: float, pitch: float = 1.0) -> void:
	var p: AudioStreamPlayer = _loops.get(key)
	if p == null:
		return
	p.volume_db = volume_db + float(AssetCatalog.entry(str(p.get_meta("id", ""))).get("volume_db", 0.0))
	p.pitch_scale = pitch


func stop_loop(key: String) -> void:
	var p: AudioStreamPlayer = _loops.get(key)
	if p:
		p.remove_meta("looping")
		p.stop()


func stop_all_loops() -> void:
	for key in _loops:
		stop_loop(key)


func is_looping(key: String) -> bool:
	var p: AudioStreamPlayer = _loops.get(key)
	return p != null and p.playing


func _on_assets_reloaded() -> void:
	for key in _loops:
		var p: AudioStreamPlayer = _loops[key]
		if p.has_meta("looping"):
			p.stream = null
			loop(key, str(p.get_meta("id")), float(p.get_meta("base_db", 0.0)), p.pitch_scale)
