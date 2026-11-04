class_name SafeFile
extends RefCounted
## Protected JSON writes: temp file -> read back + validate -> keep previous
## file as .bak -> replace. An interrupted or invalid write never removes the
## last good file.


## validator: Callable(Dictionary) -> String (empty string = valid).
static func write_json(path: String, data: Dictionary, validator: Callable = Callable()) -> String:
	var tmp := path + ".tmp"
	var bak := path + ".bak"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return "cannot open temp file (%s)" % error_string(FileAccess.get_open_error())
	f.store_string(JSON.stringify(data, "\t"))
	f.flush()
	var write_err := f.get_error()
	f.close()
	if write_err != OK:
		return "write failed (%s)" % error_string(write_err)
	var parsed = read_json(tmp)
	if parsed is String:
		DirAccess.remove_absolute(tmp)
		return "verification failed: " + str(parsed)
	if validator.is_valid():
		var problem: String = validator.call(parsed)
		if problem != "":
			DirAccess.remove_absolute(tmp)
			return "verification failed: " + problem
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(bak):
			DirAccess.remove_absolute(bak)
		var err := DirAccess.rename_absolute(path, bak)
		if err != OK:
			DirAccess.remove_absolute(tmp)
			return "could not keep backup (%s)" % error_string(err)
	var err2 := DirAccess.rename_absolute(tmp, path)
	if err2 != OK:
		if FileAccess.file_exists(bak):
			DirAccess.rename_absolute(bak, path)
		return "could not replace file (%s)" % error_string(err2)
	return ""


## Returns a Dictionary, or a String describing the problem.
static func read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return "file not found"
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		return "file is empty or unreadable"
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		return "invalid JSON at line %d: %s" % [json.get_error_line(), json.get_error_message()]
	if not (json.data is Dictionary):
		return "top level is not an object"
	return json.data
