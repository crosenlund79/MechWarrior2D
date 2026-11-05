extends Node
## Autoload `Audio`: creates the bus layout (Master → Music, Ambience, SFX, UI),
## plays named sounds from the asset manifest (one-shots and loops) and lets
## volumes come from Settings. Sounds resolve through `Assets`, so creator
## overrides work the same way as for sprites.

var _loops := {}       # key -> AudioStreamPlayer
var _pool: Array[AudioStreamPlayer] = []
var _last_play := {}   # id -> msec, prevents machine-gun repeats

## Music: two players crossfade, so a track repeats without a gap and cues can
## replace each other smoothly. Volume follows the Music bus (settings).
const MUSIC_XFADE := 5.0
var _music: Array[AudioStreamPlayer] = []
var _music_cur := 0
var music_id := ""
var music_target_db := 0.0
var _music_fade := {}  # player index -> {from, to, t, dur, stop}
var music_repeat := true


func _init() -> void:
	_ensure_buses()


func _ensure_buses() -> void:
	for bus_name in ["Music", "Ambience", "SFX", "UI"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus_name)
			AudioServer.set_bus_send(i, "Master")
	# Wind sub-bus (→ Ambience) with a low-pass that closes as you get sheltered.
	if AudioServer.get_bus_index("Wind") == -1:
		AudioServer.add_bus()
		var w := AudioServer.bus_count - 1
		AudioServer.set_bus_name(w, "Wind")
		AudioServer.set_bus_send(w, "Ambience")
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 18000.0
		AudioServer.add_bus_effect(w, lp)


## 0 = fully exposed, 1 = deep shelter: quieter, duller wind.
func set_shelter(amount: float) -> void:
	var w := AudioServer.get_bus_index("Wind")
	if w < 0:
		return
	var lp := AudioServer.get_bus_effect(w, 0) as AudioEffectLowPassFilter
	if lp:
		lp.cutoff_hz = lerpf(18000.0, 700.0, clampf(amount, 0.0, 1.0) ** 0.7)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	Assets.reloaded.connect(_on_assets_reloaded)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.name = "Music%d" % i
		m.bus = "Music"
		m.volume_db = -80.0
		add_child(m)
		_music.append(m)


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
	_make_looping(stream)
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


static func _make_looping(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = true
	elif stream is AudioStreamWAV and stream.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		pass   # WAV loops restart on `finished` (works for any import settings)


# ---------------- music ----------------

## Starts (or keeps) a music track. fade = seconds. repeat = crossfade into a
## fresh copy before the end, so it can play indefinitely without a gap.
func music_play(id: String, fade: float = 3.0, volume_db: float = 0.0, repeat: bool = true) -> void:
	music_repeat = repeat
	music_target_db = volume_db + float(AssetCatalog.entry(id).get("volume_db", 0.0))
	if music_id == id and _music[_music_cur].playing:
		_fade_to(_music_cur, music_target_db, fade, false)
		return
	var stream := Assets.audio_stream(id)
	if stream == null:
		return
	if stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:
		stream.loop = false   # we crossfade ourselves
	var old := _music_cur
	_music_cur = 1 - _music_cur
	var p := _music[_music_cur]
	p.stream = stream
	p.volume_db = -60.0
	p.play()
	music_id = id
	_fade_to(_music_cur, music_target_db, fade, false)
	if _music[old].playing:
		_fade_to(old, -60.0, fade, true)


func music_stop(fade: float = 3.0) -> void:
	music_id = ""
	for i in 2:
		if _music[i].playing:
			_fade_to(i, -60.0, fade, true)


func music_playing() -> bool:
	return music_id != "" and _music[_music_cur].playing


func music_position() -> float:
	return _music[_music_cur].get_playback_position() if _music[_music_cur].playing else -1.0


func _fade_to(i: int, to_db: float, dur: float, stop: bool) -> void:
	_music_fade[i] = {"from": _music[i].volume_db, "to": to_db, "t": 0.0, "dur": maxf(dur, 0.01), "stop": stop}


func _process(delta: float) -> void:
	for i in _music_fade.keys():
		var f: Dictionary = _music_fade[i]
		f["t"] = float(f["t"]) + delta
		var k := clampf(float(f["t"]) / float(f["dur"]), 0.0, 1.0)
		# fade in linear power, not linear dB (sounds even)
		var a := db_to_linear(float(f["from"]))
		var b := db_to_linear(float(f["to"]))
		_music[i].volume_db = linear_to_db(maxf(lerpf(a, b, k), 0.00001))
		if k >= 1.0:
			_music_fade.erase(i)
			if bool(f["stop"]):
				_music[i].stop()
	if music_id != "" and music_repeat:
		var p := _music[_music_cur]
		if p.playing and p.stream and p.stream.get_length() > MUSIC_XFADE * 3.0:
			if p.get_playback_position() >= p.stream.get_length() - MUSIC_XFADE:
				var id := music_id
				music_id = ""    # force a fresh copy on the other player
				music_play(id, MUSIC_XFADE, music_target_db - float(AssetCatalog.entry(id).get("volume_db", 0.0)), true)


## A positional loop owned by a world node (generator hum, lamp buzz). Stops
## with its owner. Volume falls off with distance from the camera/listener.
func positional_loop(owner: Node2D, id: String, volume_db: float, max_distance: float, attenuation: float = 1.0) -> AudioStreamPlayer2D:
	var p := AudioStreamPlayer2D.new()
	p.stream = Assets.audio_stream(id)
	_make_looping(p.stream)
	p.bus = _bus_for(id)
	p.volume_db = volume_db + float(AssetCatalog.entry(id).get("volume_db", 0.0))
	p.max_distance = max_distance
	p.attenuation = attenuation
	p.autoplay = true
	p.finished.connect(func() -> void: p.play())
	owner.add_child(p)
	return p


## One-shot at a world position (enemy startup, pilot shout, impacts).
func play_at(id: String, pos: Vector2, parent: Node, volume_db: float = 0.0, pitch: float = 1.0, max_distance: float = 1800.0) -> void:
	var stream := Assets.audio_stream(id)
	if stream == null or parent == null:
		return
	var p := AudioStreamPlayer2D.new()
	p.stream = stream
	p.bus = _bus_for(id)
	p.volume_db = volume_db + float(AssetCatalog.entry(id).get("volume_db", 0.0))
	p.pitch_scale = pitch
	p.max_distance = max_distance
	parent.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()


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
