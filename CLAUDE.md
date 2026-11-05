# CLAUDE.md — Heat Signature

Permanent project rules. Keep this file short; details live in `docs/`.

## Identity
- **Heat Signature** (provisional working title). Repo `github.com/crosenlund79/MechWarrior2D`,
  `project.godot` name `Heat Signature`, user dir `HeatSignature`. Godot **4.7.2**, GDScript,
  Compatibility renderer, Windows desktop target. Do not upgrade the engine silently.
- `index.html` / `style.css` at the root are an unrelated, pre-existing "Iron Siege" web shell.
  Leave them untouched until the creator decides.
- `assets/audio inbox/` holds the creator's original audio (Godot-ignored, never edit). Implemented
  clips are imported via `tools/audio_map.json` + `tools/import_audio.py`; see `docs/AUDIO.md`.
  Never generate music: the theme "Where the Ice Once Lay" is the musical identity.
- Red Thaw (`crosenlund79/ZombieSurvival2D`, branch `iteration/010-red-thaw`) is a **read-only**
  visual reference. Never modify it.

## Before modifying anything
Verify repo remote, branch, `project.godot` name and git status. If anything is ambiguous, STOP and ask.
Never modify another project. Never alter `backup/*` branches.

## Checks before pushing
- `godot --headless --path . --import`
- `godot --headless --path . res://tests/run_tests.tscn -- --instance=unit_tests` (exit 0)
- `python3 tools/regression.py` (real game process: loop, restart persistence, overrides, settings)
- `python3 tools/regression_encounter.py` (enemy AI, combat, wreck salvage, shade, restart persistence)
- `python3 tools/regression_refuge.py` (housing/twin guns, canyon + overhang, workshop, music, parked-mech encounter)
- `python3 tools/check_script_guides.py` — update EN + DA script guides for new/removed scripts

## Architecture rules
- State is plain data in `Session.state`; scenes display it and call Session request methods.
- One owner per responsibility: Session (game), Saves, Settings, Assets, Audio, Log. No new autoloads
  without need. Balance values live in `data/tuning.json`, layout in `data/locations/*.json`.
- Saves: versioned envelope, stable IDs, validate → migrate, safe write with `.bak` recovery.
  Settings never go in saves.
- Art/audio: `assets/templates/<dir>/template_<name>` overridden by `assets/overrides/<dir>/<name>`,
  `<exe>/overrides/...` or `user://overrides/...`. Art never drives collision or gameplay.
- Multiplayer is NOT approved. Any future multiplayer must be host-authoritative.
- No speculative systems. Scope limits: see `docs/DESIGN_REGISTER.md` (DEFERRED).

## Visual direction
`docs/VISUAL_DIRECTION.md`. Straight top-down (not Red Thaw's 3/4). Provisional until the creator reviews.

## Workflow
Creator tests: GitHub → branch → Download ZIP → extract → open `project.godot` → run. No hidden build steps.
Reports distinguish: implemented / auto-tested / runtime-verified / Windows-export-verified / creator-accepted.
