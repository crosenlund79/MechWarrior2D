class_name Paths
extends RefCounted
## Command-line arguments and user folders.
## `--instance=<name>` (after `--`) gives a copy of the game its own user folder,
## so automated tests never touch the creator's saves or settings.

static var _args: Dictionary = {}
static var _parsed := false


static func args() -> Dictionary:
	if not _parsed:
		_parsed = true
		for raw in OS.get_cmdline_user_args():
			var a: String = raw
			if not a.begins_with("--"):
				continue
			a = a.substr(2)
			var eq := a.find("=")
			if eq == -1:
				_args[a] = "true"
			else:
				_args[a.substr(0, eq)] = a.substr(eq + 1)
	return _args


static func arg(key: String, default_value: String = "") -> String:
	return str(args().get(key, default_value))


static func has_arg(key: String) -> bool:
	return args().has(key)


static func instance_name() -> String:
	var clean := ""
	for c in arg("instance", "").to_lower():
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == "_" or c == "-":
			clean += c
	return clean.substr(0, 32)


static func user_root() -> String:
	var inst := instance_name()
	if inst == "":
		return "user://"
	return ensure_dir("user://instances/%s/" % inst)


static func saves_dir() -> String:
	return ensure_dir(user_root() + "saves/")


static func logs_dir() -> String:
	return ensure_dir(user_root() + "logs/")


static func settings_file() -> String:
	ensure_dir(user_root())
	return user_root() + "settings.cfg"


static func screenshots_dir() -> String:
	return ensure_dir(user_root() + "screenshots/")


## External override folders, highest priority first.
## 1. `overrides/` next to the exported .exe (portable builds, easy for the creator)
## 2. `user://overrides/` (also works when running from the editor). Test instances
##    (`--instance=...`) use their own `instances/<name>/overrides/` so automated
##    tests can never touch the creator's real override files.
static func external_override_roots() -> PackedStringArray:
	var roots := PackedStringArray()
	if not OS.has_feature("editor"):
		roots.append(OS.get_executable_path().get_base_dir().path_join("overrides") + "/")
	var test_root := arg("override-root", "")
	if test_root != "":
		roots.append(test_root.trim_suffix("/") + "/")
	roots.append(ensure_dir(user_root() + "overrides/"))
	return roots


static func ensure_dir(path: String) -> String:
	if not DirAccess.dir_exists_absolute(path):
		DirAccess.make_dir_recursive_absolute(path)
	return path


## The project was called Heat Signature before the Thawborn conversion; its
## user folder was "HeatSignature". On first start, saves and settings found
## there are COPIED (never moved or deleted) into the Thawborn folder, only into
## empty slots, only for the real player profile (not test instances). The
## normal versioned migration (v4 → v5) converts each save when it is loaded.
## Returns the number of files copied.
const LEGACY_USER_DIR := "HeatSignature"


static func import_legacy(legacy_root: String = "", dest_root: String = "") -> int:
	if instance_name() != "" and legacy_root == "":
		return 0
	if legacy_root == "":
		legacy_root = OS.get_user_data_dir().get_base_dir().path_join(LEGACY_USER_DIR)
	if dest_root == "":
		dest_root = ProjectSettings.globalize_path(user_root())
	if not DirAccess.dir_exists_absolute(legacy_root) or legacy_root.simplify_path() == dest_root.simplify_path():
		return 0
	DirAccess.make_dir_recursive_absolute(dest_root.path_join("saves"))
	var copied := 0
	for slot in range(1, 4):
		var src := legacy_root.path_join("saves/slot_%d.json" % slot)
		var dst := dest_root.path_join("saves/slot_%d.json" % slot)
		if FileAccess.file_exists(dst) or FileAccess.file_exists(dst + ".bak") or not FileAccess.file_exists(src):
			continue
		for ext in ["", ".bak"]:
			if FileAccess.file_exists(src + ext) and DirAccess.copy_absolute(src + ext, dst + ext) == OK:
				copied += 1
	var sset := legacy_root.path_join("settings.cfg")
	var dset := dest_root.path_join("settings.cfg")
	if FileAccess.file_exists(sset) and not FileAccess.file_exists(dset):
		if DirAccess.copy_absolute(sset, dset) == OK:
			copied += 1
	return copied
