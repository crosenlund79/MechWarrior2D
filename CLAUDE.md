# CLAUDE.md — Thawborn (formerly Heat Signature)

Permanent project rules. Keep this file short; details live in `docs/`.

## Identity
- **Thawborn** (formerly Heat Signature; provisional title). Repo `github.com/crosenlund79/MechWarrior2D`,
  `project.godot` name `Thawborn`, user dir `Thawborn` (legacy `HeatSignature` saves are copied on first
  start). Godot **4.7.2**, GDScript, Compatibility renderer, Windows desktop target. Do not upgrade the
  engine silently. Vehicular hunting/survival: the player's vehicle is a CAR; internal legacy identifiers
  (`state.mech`, mode `"mech"`, tuning `mech`) mean the car.
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
- `python3 tools/regression_refuge.py` (roof guns, canyon + overhang, workshop, music, parked-car encounter)
- `python3 tools/regression_junkers.py` (recoil, sandstorm, F10 dev menu, exploration, Junker base, turrets, defenders)
- `python3 tools/regression_balance.py` (speed/responsiveness, progressive heat pressure)
- `python3 tools/regression_hunt.py` (full Thawborn loop: drive, track, hunt, harvest, loot, garage, save/reload; rival car, skirrs, grindback, storm)
- `xvfb-run -a -s "-screen 0 2600x1200x24" python3 tools/regression_playtest.py` (playtest 001–006: reverse steering, starter heat, garage cursor, cargo storage, bullet speed)
- Heat tuning changes: run `python3 tools/heat_balance.py` — ordinary travel must never warn.
- Map layout changes: edit `tools/build_world_south.py` (south/east content, creatures, garage) and run it — it validates roads, creatures and the rimeback route vs rock/props.
- Thawborn art: `python3 tools/art/gen_thawborn.py` (cars, creatures, tracks, materials; never touches overrides).
- `python3 tools/check_script_guides.py` — update EN + DA script guides for new/removed scripts

## Architecture rules
- State is plain data in `Session.state`; scenes display it and call Session request methods.
- One owner per responsibility: Session (game), Saves, Settings, Assets, Audio, Log. No new autoloads
  without need. Balance values live in `data/tuning.json`, layout in `data/locations/*.json`.
- Saves: versioned envelope, stable IDs, validate → migrate, safe write with `.bak` recovery.
  Settings never go in saves.
- Art/audio: `assets/templates/<dir>/template_<name>` overridden by `assets/overrides/<dir>/<name>`,
  `<exe>/overrides/...` or `user://overrides/...`. Art never drives collision or gameplay.
- Developer cheats (F10) live in `Session.dev` only; dev-spawned cars and creatures carry `"dev": true` and are stripped
  from saves. Never persist cheat state.
- Multiplayer is NOT approved. Any future multiplayer must be host-authoritative.
- No speculative systems. Scope limits: see `docs/DESIGN_REGISTER.md` (DEFERRED).

## Visual direction
`docs/VISUAL_DIRECTION.md`. Straight top-down (not Red Thaw's 3/4). Provisional until the creator reviews.
Creatures are prototypes (not fixed lore); attacks must always be telegraphed in-world. Deferred scope
(mining, smelting, schematics, minimap, ore cart, cities…): `docs/DESIGN_REGISTER.md` TB-30+.

## Workflow
Creator tests: GitHub → branch → Download ZIP → extract → open `project.godot` → run. No hidden build steps.
Reports distinguish: implemented / auto-tested / runtime-verified / Windows-export-verified / creator-accepted.
