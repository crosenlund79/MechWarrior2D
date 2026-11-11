extends Node
## Autoload `Saves`: slot files in <user>/saves/slot_<n>.json with a .bak copy
## of the previous good save. Writes are protected by SafeFile (temp → verify →
## backup → replace). Loading falls back to the .bak when the main file is
## missing, corrupt or fails validation. Settings are NOT stored here.

const SLOT_COUNT := 3
## Legacy Heat Signature saves are imported by Paths.import_legacy() (run by
## Settings at startup, before anything reads the user folder).


func slot_path(slot: int) -> String:
	return Paths.saves_dir() + "slot_%d.json" % slot


func save_slot(slot: int, state: Dictionary) -> String:
	if slot < 1 or slot > SLOT_COUNT:
		return "invalid slot %d" % slot
	var env := SaveCodec.encode(state)
	var err := SafeFile.write_json(slot_path(slot), env, SaveCodec.validate)
	if err == "":
		Log.info("saves", "saved", {"slot": slot})
	return err


## Returns {ok, state, recovered, error, envelope}.
func load_slot(slot: int) -> Dictionary:
	var main := _read(slot_path(slot))
	if main["ok"]:
		return main
	var bak := _read(slot_path(slot) + ".bak")
	if bak["ok"]:
		bak["recovered"] = true
		Log.warn("saves", "recovered_from_backup", {"slot": slot, "main_error": main["error"]})
		return bak
	return {"ok": false, "error": main["error"], "recovered": false, "state": {}}


func _read(path: String) -> Dictionary:
	var data = SafeFile.read_json(path)
	if data is String:
		return {"ok": false, "error": data, "recovered": false, "state": {}}
	var env = SaveCodec.migrate(data)
	if env is String:
		return {"ok": false, "error": env, "recovered": false, "state": {}}
	var problem := SaveCodec.validate(env)
	if problem != "":
		return {"ok": false, "error": problem, "recovered": false, "state": {}}
	return {"ok": true, "error": "", "recovered": false, "state": env["state"], "envelope": env}


func has_save(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot)) or FileAccess.file_exists(slot_path(slot) + ".bak")


## Light summary for the slot list (no full validation of state contents).
func summary(slot: int) -> Dictionary:
	if not has_save(slot):
		return {}
	var res := load_slot(slot)
	if not res["ok"]:
		return {"broken": true, "error": res["error"]}
	var env: Dictionary = res.get("envelope", {})
	var s: Dictionary = env.get("summary", {})
	s["saved_unix"] = int(env.get("saved_unix", 0))
	s["recovered"] = res["recovered"]
	return s


func delete_slot(slot: int) -> void:
	for suffix in ["", ".bak", ".tmp"]:
		var p: String = slot_path(slot) + suffix
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	Log.info("saves", "deleted", {"slot": slot})


func most_recent_slot() -> int:
	var best := 0
	var best_t := -1
	for i in range(1, SLOT_COUNT + 1):
		var s := summary(i)
		if not s.is_empty() and not s.get("broken", false) and int(s.get("saved_unix", 0)) > best_t:
			best_t = int(s["saved_unix"])
			best = i
	return best


func first_free_slot() -> int:
	for i in range(1, SLOT_COUNT + 1):
		if not has_save(i):
			return i
	return 0
