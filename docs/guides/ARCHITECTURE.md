# Architecture

Small, plain Godot. State is data; scenes are views.

## Autoloads (one owner each)
| Autoload | Script | Owns |
|---|---|---|
| `Log` | `src/core/session_log.gd` | `user://logs/session.log` (+ previous run) |
| `Assets` | `src/core/asset_resolver.gd` | logical asset ID → texture/stream, override priority, cache |
| `Audio` | `src/core/audio_service.gd` | buses Master/Music/Ambience/SFX/UI, one-shots, loops |
| `Settings` | `src/core/settings_service.gd` | `settings.cfg`: volumes, window mode, UI scale, zoom, language, key bindings |
| `Saves` | `src/persistence/save_service.gd` | slot files, `.bak` recovery, summaries |
| `Session` | `src/sim/game_session.gd` | the running game: `state`, tick, mode changes, interactions, autosave |

## Data flow
```
data/tuning.json, data/items.json, data/locations/*.json ──► Content (read-only)
                                                             │
Input (PlayerInput / AutotestDriver) ── intents ──► Session.state ◄── Thermal (pure functions)
                                                             │  ▲
          WorldView ─ MechView / PilotView (physics: move_and_slide → commit_*)
          Hud / DevOverlay (read only)            Saves ◄─ SaveCodec (envelope, validate, migrate)
```
- **Session.state** is a single JSON-safe Dictionary: `mode`, `mech` (pos, heading, speed, heat,
  radiator, shutters_open, engine, storage), `pilot` (pos, facing, suit, strain, pack), `world`
  (taken salvage IDs, dropped packs), `stats`.
- **Movement**: the view asks `Session.mech_velocity(dt)` (drive dynamics in the sim), moves with
  `move_and_slide`, and reports back with `Session.commit_mech(pos, real_velocity)`. Collision shapes
  come from location data, never from art.
- **Thermal model** (`src/sim/thermal.gd`): `dT/dt = heat_in − k·eff·airflow·(T − ambient)`.
  The equilibrium `T_eq = ambient + heat_in/(k·eff·airflow)` is shown on the HUD ("settling at").
  Cooling efficiency follows radiator condition; shutters trade airflow (0.45 closed) against sand
  abrasion (wear only when open and moving, ×22 in dunes). Above `critical_temp` the engine shuts down
  and the radiator takes heat damage until it cools below `restart_temp`.
- **Suit**: drains on foot (× zone factor), recovers in a mech that is below `cabin_safe_temp`. At 0
  strain builds; at full strain the pilot collapses, the pack is dropped where they fell (persistent
  world drop), and they wake in the cockpit with 25 % protection.
- **Zones**: polygons in the location file (shade, dunes, salt) set ambient, solar, abrasion, drag and
  suit factors.

## Saves
`<user>/saves/slot_<1..3>.json`, envelope `{format, version, saved_unix, game_version, summary, state}`.
Write: temp → read back → validate → previous file to `.bak` → replace. Load: main → validate/migrate →
else `.bak` (reported as "recovered"). Migrations: `SaveCodec.MIGRATIONS[from_version]`. Stable IDs:
salvage nodes and props are named in location data; drops get `drop_<n>`. Autosave: new game, enter
mech, salvage, repair, collapse, every 60 s, quit and window close.

## Scene composition
`scenes/main.tscn` → `main.gd` swaps `MainMenu` ↔ `GameScreen`. Everything else is built in code.
`GameScreen` = `WorldView` (+ `Atmosphere` from Phase B) + HUD (CanvasLayer 10) + dev overlay (12) +
pause (14); settings (15) are owned by main. The colour grade sits on CanvasLayer 5, so UI is never graded.

Top-down z-order: ground −10 · floor decals −5 · prop cast shadows −3 · props 0 · markers 2 · mech 5 ·
pilot 6 · roof shadow 8 · overhead roofs 20 (fade to 0.42 while an actor is under) · air particles 25.

## User folders
`user://` = `%APPDATA%\HeatSignature\` on Windows (custom user dir). `--instance=<name>` (after `--`)
isolates saves, settings, logs and overrides under `instances/<name>/` (used by all automated tests).

## Diagnostics
F3 dev overlay: fps, scene, slot, thermal in/out/equilibrium, radiator, zone, suit, positions, save status,
asset override/fallback counts. Debug keys (only while visible): F4 reload art, F6 +15 °C, F7 damage
radiator, F8 give core, F9 refill suit, F10 suit → 5, F11 time ×4.
