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
