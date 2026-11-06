class_name SaveCodec
extends RefCounted
## Save file format: a versioned envelope around the plain game state.
##
##   {"format": "heat_signature_save", "version": N, "saved_unix": ..., "game_version": ...,
##    "summary": {...}, "state": {...}}
##
## To change the format: bump VERSION and add a function to MIGRATIONS that
## upgrades version N-1 to N. Old saves are migrated step by step on load.

const FORMAT := "heat_signature_save"
const VERSION := 4

## from_version -> Callable(Dictionary envelope) -> Dictionary envelope (version+1)
static var MIGRATIONS := {
	0: _migrate_0_to_1,
	1: _migrate_1_to_2,
	2: _migrate_2_to_3,
	3: _migrate_3_to_4,
}


static func encode(state: Dictionary) -> Dictionary:
	return {
		"format": FORMAT,
		"version": VERSION,
		"saved_unix": int(Time.get_unix_time_from_system()),
		"game_version": str(ProjectSettings.get_setting("application/config/version", "0")),
		"summary": summarize(state),
		"state": state.duplicate(true),
	}


static func summarize(state: Dictionary) -> Dictionary:
	return {
		"location": state.get("location", ""),
		"playtime": float(state.get("playtime", 0.0)),
		"mode": state.get("mode", ""),
		"radiator": float(state.get("mech", {}).get("radiator", 0.0)),
		"repairs": int(state.get("stats", {}).get("repairs", 0)),
	}


## Brings an envelope up to VERSION. Returns the upgraded envelope or a String error.
static func migrate(env: Dictionary) -> Variant:
	var v := int(env.get("version", -1))
	if v > VERSION:
		return "save is from a newer game version (%d > %d)" % [v, VERSION]
	while v < VERSION:
		if not MIGRATIONS.has(v):
			return "no migration from version %d" % v
		env = MIGRATIONS[v].call(env)
		v = int(env.get("version", -1))
	return env


## Example / extension point: version 0 was the pre-release draft format that
## stored the radiator as "cooling" (0-100) and had no world drops.
static func _migrate_0_to_1(env: Dictionary) -> Dictionary:
	var s: Dictionary = env.get("state", {})
	var m: Dictionary = s.get("mech", {})
	if m.has("cooling") and not m.has("radiator"):
		m["radiator"] = float(m["cooling"]) / 100.0
		m.erase("cooling")
	if s.has("world") and not s["world"].has("drops"):
		s["world"]["drops"] = []
	env["version"] = 1
	return env


## Version 2 (first hostile encounter): mech structural integrity and enemy
## state. Old saves get a full-integrity mech; enemies are created fresh from the
## location on load (GameState.sanitize).
static func _migrate_1_to_2(env: Dictionary) -> Dictionary:
	var s: Dictionary = env.get("state", {})
	if s.get("mech") is Dictionary and not s["mech"].has("integrity"):
		s["mech"]["integrity"] = 100.0
	if not s.has("enemies"):
		s["enemies"] = {}
	env["version"] = 2
	return env


## Version 3 (canyon refuge): enemies carry their pilot. Existing enemies were
## already crewed, so they get an aboard pilot; new encounters come from the
## location on load.
static func _migrate_2_to_3(env: Dictionary) -> Dictionary:
	var s: Dictionary = env.get("state", {})
	for id in s.get("enemies", {}):
		var e = s["enemies"][id]
		if e is Dictionary and not e.has("pilot"):
			e["pilot"] = {"state": "aboard", "pos": e.get("pos", [0, 0]), "facing": 0.0}
	env["version"] = 3
	return env


## Version 4 (Southern Junkers): weather state and turret state. Old saves get
## clear weather; turrets (and the new Junker defenders) appear from the location.
static func _migrate_3_to_4(env: Dictionary) -> Dictionary:
	var s: Dictionary = env.get("state", {})
	if not s.has("turrets"):
		s["turrets"] = {}
	env["version"] = 4
	return env


## Structural validation of a CURRENT-version envelope. Returns "" when valid.
## Ranges are clamped later (GameState.sanitize); this rejects corruption.
static func validate(env: Dictionary) -> String:
	if str(env.get("format", "")) != FORMAT:
		return "not a Heat Signature save"
	if int(env.get("version", -1)) != VERSION:
		return "unexpected version %s" % str(env.get("version"))
	var s = env.get("state")
	if not (s is Dictionary):
		return "missing state"
	for key in ["mech", "pilot", "world"]:
		if not (s.get(key) is Dictionary):
			return "state.%s missing" % key
	for pair in [["mech", "pos"], ["pilot", "pos"]]:
		var p = s[pair[0]].get(pair[1])
		if not (p is Array) or p.size() != 2 or not _finite(p[0]) or not _finite(p[1]):
			return "state.%s.%s invalid" % pair
	for pair2 in [["mech", "heat"], ["mech", "radiator"], ["pilot", "suit"]]:
		if not _finite(s[pair2[0]].get(pair2[1])):
			return "state.%s.%s invalid" % pair2
	if not (str(s.get("mode", "")) in GameState.MODES):
		return "state.mode invalid"
	if not (s["world"].get("taken", {}) is Dictionary):
		return "state.world.taken invalid"
	if not _finite(s["mech"].get("integrity")):
		return "state.mech.integrity invalid"
	if not (s.get("enemies", {}) is Dictionary):
		return "state.enemies invalid"
	for id in s.get("enemies", {}):
		var e = s["enemies"][id]
		if not (e is Dictionary) or not (e.get("pos") is Array) or e["pos"].size() != 2 or not _finite(e["pos"][0]) or not _finite(e["pos"][1]):
			return "state.enemies.%s invalid" % id
	return ""


static func _finite(v) -> bool:
	return (v is float or v is int) and is_finite(float(v))
