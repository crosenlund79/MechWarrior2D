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

## Combat and the hostile encounter
- `src/sim/drive.gd`: one drive model for every mech, with heat impairment
  (`impairment = 1 − impair_max · clamp((T − warn)/(crit − warn))`).
- `src/sim/combat.gd`: projectiles are runtime dictionaries in `Session.projectiles` and are not
  saved. Hits are segment-vs-circle tests against each mech's **body** circle and its **cooling** circle
  (a local offset at the illustrated radiator). Static obstacles stop shots via a world-view raycast
  (`Session.shot_blocked`, physics layer 1). Mechs sit on layer 4 and the pilot on layer 2.
- `src/sim/enemy_ai.gd`: a pure decision function (patrol / alert / engage / return / wreck).
  `Session._tick_enemies` runs the same `Thermal.step` (enemy thermal overrides), weapon heat and zone
  rules as for the player. A mech is disabled at 0 integrity, or when its radiator is ≤ 4 % at critical heat.
- `state.enemies[<stable id>]` = `{type, pos, heading, speed, heat, radiator, shutters_open, engine,
  integrity, ai, salvaged}`. Brains (timers, waypoint) are runtime-only. Engaged enemies load as
  "return", so a reload never resumes mid-attack.
- Views: `EnemyView` (movement executor + telegraph and damage FX) and `ProjectilesView` (tracers and
  impacts). Both react to `Session.combat_event`.

## Canyon refuge iteration
- **Housing:** `Session.housing_angle` (runtime) turns toward `aim_point` at ≤ 5.5 rad/s with easing.
  Shots alternate between the two muzzles (`combat.player_weapon.muzzles`, housing-local). Each one
  aims from its own muzzle at the aim point (converging, also at close range) and fires only once the
  housing is within 25° of the target. The chassis heading comes only from drive input.
- **Terrain** (`location.terrain`):
  - `masses`: rock, roughened by `Content.organic`, which is deterministic, so the visual polygon is
    the collision polygon
  - `covers`: overhead rock. `TerrainView.coverage()` and fading use the signed distance to the outline.
  - `walls`: textured strips with matching rectangle colliders
  - `cables`: visual only
- **Zones** gain `cooling` (a multiplier on the cooling coefficient) and `sheltered` (the HUD tag).
  Zone types: canyon, refuge.
- **Encounter** (`src/sim/encounter.gd`): `enemy.pilot = {state, pos, facing}` with states outside →
  climbing → aboard (or fled → gone). The parked mech has no drive or weapon until it reaches the
  ACTIVE states. Loading in alerted, boarding or starting resolves to an active "return" state with
  the pilot aboard, and a wreck never respawns its pilot.

## Southern Junkers iteration
- **Weather** (`src/sim/weather.gd`): `state.weather = {state, intensity, t, peak, hold, next, ramp}` is
  saved. `Session.zone_with_weather(pos)` folds the storm into any zone, using intensity × the zone's
  `storm_exposure`. Every mech's thermal step, the suit and detection all use it, so the same rules
  apply everywhere.
- **Turrets** (`src/sim/turret.gd`): definitions live in location `turrets`; `state.turrets[id] = {hp, angle,
  destroyed, salvaged}` is saved. `Session._tick_turrets` gives only the `max_engaged` nearest turrets
  permission to wind up or fire. Line of sight uses the world raycast.
- **Enemy types:** `enemy_types.<type>` overrides the base `enemy` tuning (`Session.enemy_tun`).
- **Dev cheats:** `Session.dev` (runtime only) plus `dev_*` actions; `savable_state()` strips dev
  entities. Spawns use `Session.find_spawn_spot`, which runs a ring search with a 120 px physics query.
- **Recoil:** in `MechView` it is purely visual. Gun, bolt, housing kick and rock are each a damped
  spring in housing-local space, so it works at any turret angle and the chassis is never displaced.
  The camera shake is trauma-based in `CameraRig.add_shake`.
- **Audio:** Weapons bus (compressor + hard limiter) → SFX bus (storm low-pass) → Master.
  `Audio.set_storm` muffles SFX and distant one-shots.
- **Save v4:** adds weather and turrets.

## Movement & heat balance
- **Drive:** `tuning.mech` sets 245 px/s, accel 290, brake 520, turn 2.6 → 1.75 rad/s. The sense
  of weight is visual (`feel_squat`, `feel_lean`, `feel_step_shake`) plus sound and recoil.
- **Thermal:** heat capacity 2.2 gives slower swings and longer warnings. Cooling is 0.15, move heat
  1.2, shot heat 0.85, and the start radiator 55 %. Open-sand abrasion is 0.00025/s; dunes and storms
  multiply it.
- `python3 tools/heat_balance.py` prints the resulting situation table. Keep "ordinary travel: never
  warns" and "stacked pressure: overheats after a warning".

## Saves
`<user>/saves/slot_<1..3>.json`, envelope `{format, version, saved_unix, game_version, summary, state}`.
Format version **4** (v3 → v4 adds weather + turrets); earlier **3** (v2 → v3 adds `enemy.pilot`); previously version **2** (adds `mech.integrity` and `enemies`; v1 saves migrate automatically).
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
