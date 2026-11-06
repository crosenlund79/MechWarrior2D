extends Node
## Autoload `Assets`: resolves logical asset IDs to textures / audio streams.
##
## Priority (first valid wins):
##   1. external  <exe>/overrides/<dir>/<name>.png, then user://overrides/<dir>/<name>.png
##   2. bundled   res://assets/overrides/<dir>/<name>.png
##   3. template  res://assets/templates/<dir>/template_<name>.png
##   4. fallback  generated magenta checker / silence (logged once)
## Results are cached until reload() (Settings → "Reload art & sound", or F4 in the dev overlay).

signal reloaded

const MAX_FILE_BYTES := 16 * 1024 * 1024
const MAX_DIMENSION := 4096
const MIN_DIMENSION := 4

var _textures := {}
var _streams := {}
var source := {}  # id -> "external" | "bundled" | "template" | "fallback"
var _fallback_tex: Texture2D


func _ready() -> void:
	AssetCatalog.reload()
	for p in AssetCatalog.problems:
		Log.error("assets", "manifest_problem", {"detail": p})
	Log.info("assets", "catalog_loaded", {"count": AssetCatalog.ids().size(),
		"external_roots": Array(Paths.external_override_roots()).map(func(r): return ProjectSettings.globalize_path(r))})


func reload() -> void:
	_textures.clear()
	_streams.clear()
	source.clear()
	AssetCatalog.reload()
	Log.info("assets", "reloaded")
	reloaded.emit()


func display_size(id: String) -> Vector2:
	return AssetCatalog.display_size(id)


func pivot(id: String) -> Vector2:
	return AssetCatalog.pivot(id)


func source_of(id: String) -> String:
	return str(source.get(id, "unresolved"))


func override_count() -> int:
	var n := 0
	for id in source:
		if source[id] == "external" or source[id] == "bundled":
			n += 1
	return n


func fallback_count() -> int:
	var n := 0
	for id in source:
		if source[id] == "fallback":
			n += 1
	return n


# ---------------- textures ----------------

func texture(id: String) -> Texture2D:
	if not _textures.has(id):
		_textures[id] = _resolve_texture(id)
	return _textures[id]


func _resolve_texture(id: String) -> Texture2D:
	if not AssetCatalog.has(id):
		Log.error("assets", "unknown_asset_id", {"id": id})
		source[id] = "fallback"
		return _fallback()
	for path in AssetCatalog.external_candidates(id):
		if FileAccess.file_exists(path):
			var t := _load_image_file(id, path)
			if t != null:
				source[id] = "external"
				Log.info("assets", "override_used", {"id": id, "path": ProjectSettings.globalize_path(path)})
				return t
	for path in AssetCatalog.bundled_candidates(id):
		var t := _load_project_texture(id, path, true)
		if t != null:
			source[id] = "bundled"
			Log.info("assets", "override_used", {"id": id, "path": path})
			return t
	for path in AssetCatalog.template_paths(id):
		var t := _load_project_texture(id, path, false)
		if t != null:
			source[id] = "template"
			return t
	Log.warn("assets", "missing_art_using_fallback", {"id": id})
	source[id] = "fallback"
	return _fallback()


func _load_project_texture(id: String, path: String, is_override: bool) -> Texture2D:
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D and _dimensions_ok(id, res.get_size(), path):
			return res
		if is_override:
			Log.warn("assets", "override_rejected", {"id": id, "path": path})
		return null
	# Dropped in while the editor was closed (not imported yet): read the file directly.
	if FileAccess.file_exists(path):
		return _load_image_file(id, path)
	return null


func _load_image_file(id: String, path: String) -> Texture2D:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var size := f.get_length()
	f.close()
	if size > MAX_FILE_BYTES:
		Log.warn("assets", "override_rejected", {"id": id, "path": path, "reason": "file larger than 16 MB"})
		return null
	var img := Image.new()
	var err := img.load(ProjectSettings.globalize_path(path))
	if err != OK or img.is_empty():
		Log.warn("assets", "override_rejected", {"id": id, "path": path, "reason": "unreadable image (%s)" % error_string(err)})
		return null
	if not _dimensions_ok(id, Vector2(img.get_width(), img.get_height()), path):
		return null
	return ImageTexture.create_from_image(img)


func _dimensions_ok(id: String, size: Vector2, path: String) -> bool:
	if size.x < MIN_DIMENSION or size.y < MIN_DIMENSION or size.x > MAX_DIMENSION or size.y > MAX_DIMENSION:
		Log.warn("assets", "override_rejected", {"id": id, "path": path,
			"reason": "size %dx%d outside %d..%d px" % [size.x, size.y, MIN_DIMENSION, MAX_DIMENSION]})
		return false
	return true


func _fallback() -> Texture2D:
	if _fallback_tex == null:
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		for y in 16:
			for x in 16:
				img.set_pixel(x, y, Color(1, 0, 1) if ((x / 4) + (y / 4)) % 2 == 0 else Color(0.1, 0.1, 0.1))
		_fallback_tex = ImageTexture.create_from_image(img)
	return _fallback_tex


## Fits the texture into the asset's display box (aspect kept, centred) and puts
## the manifest pivot at the node origin. Top-down: pivots are usually the centre
## (rotating actors) or the footprint centre (static structures).
func apply_to_sprite(sprite: Sprite2D, id: String) -> void:
	var tex := texture(id)
	sprite.texture = tex
	sprite.centered = false
	var box := display_size(id)
	var tsize := tex.get_size()
	var s := minf(box.x / tsize.x, box.y / tsize.y)
	sprite.scale = Vector2(s, s)
	var drawn := tsize * s
	var piv := pivot(id)
	sprite.position = -Vector2(box.x * piv.x, box.y * piv.y) + (box - drawn) * 0.5


# ---------------- audio ----------------

func audio_stream(id: String) -> AudioStream:
	if not _streams.has(id):
		_streams[id] = _resolve_audio(id)
	return _streams[id]


func _resolve_audio(id: String) -> AudioStream:
	if not AssetCatalog.has(id):
		Log.error("assets", "unknown_sound_id", {"id": id})
		source[id] = "fallback"
		return null
	for path in AssetCatalog.external_candidates(id):
		if FileAccess.file_exists(path):
			var s := _load_audio_file(path)
			if s != null:
				source[id] = "external"
				Log.info("assets", "override_used", {"id": id, "path": ProjectSettings.globalize_path(path)})
				return s
	for path in AssetCatalog.bundled_candidates(id):
		var s := _load_project_audio(path)
		if s != null:
			source[id] = "bundled"
			return s
	for path in AssetCatalog.template_paths(id):
		var s := _load_project_audio(path)
		if s != null:
			source[id] = "template"
			return s
	Log.warn("assets", "missing_sound_silent", {"id": id})
	source[id] = "fallback"
	return null


func _load_project_audio(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		var res = load(path)
		return res if res is AudioStream else null
	if FileAccess.file_exists(path):
		return _load_audio_file(path)
	return null


func _load_audio_file(path: String) -> AudioStream:
	var g := ProjectSettings.globalize_path(path)
	if path.get_extension().to_lower() == "ogg":
		return AudioStreamOggVorbis.load_from_file(g)
	if path.get_extension().to_lower() == "mp3":
		return AudioStreamMP3.load_from_file(g)
	return AudioStreamWAV.load_from_file(g)
