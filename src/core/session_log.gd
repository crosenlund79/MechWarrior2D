extends Node
## Autoload `Log`: one small rotating log file per run (user://logs/session.log,
## previous run kept as session.prev.log). Warnings and errors also go to the
## console. Keep logging sparse: state changes, not per-frame values.

const MAX_LINES := 4000

var _file: FileAccess
var _lines := 0
var recent: Array[String] = []


func _ready() -> void:
	var dir := Paths.logs_dir()
	var path := dir + "session.log"
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(dir + "session.prev.log"):
			DirAccess.remove_absolute(dir + "session.prev.log")
		DirAccess.rename_absolute(path, dir + "session.prev.log")
	_file = FileAccess.open(path, FileAccess.WRITE)
	info("app", "start", {"version": ProjectSettings.get_setting("application/config/version"),
		"godot": Engine.get_version_info().string, "instance": Paths.instance_name()})


func info(area: String, event: String, data: Dictionary = {}) -> void:
	_write("INFO", area, event, data)


func warn(area: String, event: String, data: Dictionary = {}) -> void:
	_write("WARN", area, event, data)
	push_warning("%s/%s %s" % [area, event, JSON.stringify(data)])


func error(area: String, event: String, data: Dictionary = {}) -> void:
	_write("ERROR", area, event, data)
	push_error("%s/%s %s" % [area, event, JSON.stringify(data)])


func _write(level: String, area: String, event: String, data: Dictionary) -> void:
	var line := "%s %s %s/%s %s" % [Time.get_time_string_from_system(), level, area, event,
		JSON.stringify(data) if not data.is_empty() else ""]
	recent.append(line)
	if recent.size() > 12:
		recent.pop_front()
	if _file and _lines < MAX_LINES:
		_file.store_line(line)
		_file.flush()
		_lines += 1
