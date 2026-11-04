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
const VERSION := 1

## from_version -> Callable(Dictionary envelope) -> Dictionary envelope (version+1)
static var MIGRATIONS := {
	0: _migrate_0_to_1,
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
	return ""


static func _finite(v) -> bool:
	return (v is float or v is int) and is_finite(float(v))
