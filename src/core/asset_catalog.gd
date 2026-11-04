class_name AssetCatalog
extends RefCounted
## Reads assets/manifest/assets.json: every replaceable sprite and sound with its
## logical ID, mirrored path, display size, source size, pivot and facing.
## Gameplay never reads image sizes; views fit art into `display`.

const MANIFEST := "res://assets/manifest/assets.json"
const TEMPLATE_ROOT := "res://assets/templates/"
const BUNDLED_ROOT := "res://assets/overrides/"
const IMAGE_EXTS := ["png", "webp", "jpg"]
const AUDIO_EXTS := ["wav", "ogg"]

static var _entries: Dictionary = {}
static var problems: Array[String] = []
static var _loaded := false


static func reload() -> void:
	_entries.clear()
	problems.clear()
	_loaded = true
	var data = SafeFile.read_json(MANIFEST)
	if data is String:
		problems.append("manifest: " + str(data))
		return
	for group in ["sprites", "tiles", "sounds"]:
		var g: Dictionary = data.get(group, {})
		for id in g:
			var e: Dictionary = g[id].duplicate()
			e["kind"] = group
			if not e.has("path"):
				problems.append("%s: missing path" % id)
				continue
			_entries[id] = e


static func _ensure() -> void:
	if not _loaded:
		reload()


static func has(id: String) -> bool:
	_ensure()
	return _entries.has(id)


static func ids() -> Array:
	_ensure()
	return _entries.keys()


static func entry(id: String) -> Dictionary:
	_ensure()
	return _entries.get(id, {})


static func kind(id: String) -> String:
	return str(entry(id).get("kind", ""))


static func display_size(id: String) -> Vector2:
	var d: Array = entry(id).get("display", [64, 64])
	return Vector2(d[0], d[1])


static func pivot(id: String) -> Vector2:
	var p: Array = entry(id).get("pivot", [0.5, 0.5])
	return Vector2(p[0], p[1])


static func _split(id: String) -> PackedStringArray:
	var rel: String = entry(id).get("path", "")
	return PackedStringArray([rel.get_base_dir(), rel.get_file()])


static func _exts(id: String) -> Array:
	return AUDIO_EXTS if kind(id) == "sounds" else IMAGE_EXTS


## Template file: res://assets/templates/<dir>/template_<name>.<ext>
static func template_paths(id: String) -> PackedStringArray:
	var s := _split(id)
	var out := PackedStringArray()
	for ext in _exts(id):
		out.append(TEMPLATE_ROOT + s[0] + "/template_" + s[1] + "." + ext)
	return out


## Bundled override: res://assets/overrides/<dir>/<name>.<ext>
static func bundled_candidates(id: String) -> PackedStringArray:
	var s := _split(id)
	var out := PackedStringArray()
	for ext in _exts(id):
		out.append(BUNDLED_ROOT + s[0] + "/" + s[1] + "." + ext)
	return out


## External overrides: <root>/<dir>/<name>.<ext> for every external root.
static func external_candidates(id: String) -> PackedStringArray:
	var s := _split(id)
	var out := PackedStringArray()
	for root in Paths.external_override_roots():
		for ext in _exts(id):
			out.append(root + s[0] + "/" + s[1] + "." + ext)
	return out
