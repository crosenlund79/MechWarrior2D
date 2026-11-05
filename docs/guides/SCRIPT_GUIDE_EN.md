# Script guide (English)

What each script does. Keep in sync with `tools/guide_rows.py`, then run `python3 tools/check_script_guides.py --write`.

| Script | Purpose |
|---|---|
| `src/core/paths.gd` | Command-line args, user folders, per-instance isolation, external override folders. |
| `src/core/safe_file.gd` | Protected JSON write (temp → verify → .bak → replace) and safe read. |
| `src/core/session_log.gd` | Autoload `Log`: small per-run log file, warnings to the console. |
| `src/core/settings_service.gd` | Autoload `Settings`: settings.cfg, input actions and remapping, applies volumes/window/language. |
| `src/core/asset_catalog.gd` | Reads the asset manifest; template/bundled/external candidate paths. |
| `src/core/asset_resolver.gd` | Autoload `Assets`: resolves IDs with override priority, fits sprites to display boxes. |
| `src/core/audio_service.gd` | Autoload `Audio`: bus layout, named one-shots and loops. |
| `src/sim/content.gd` | Read-only data: tuning, items, location; zone lookup. |
| `src/sim/thermal.gd` | Pure thermal model: heat in/out, equilibrium, shutdown, wear. |
| `src/sim/game_state.gd` | Creates and sanitises the plain-data game state; inventory helpers. |
| `src/sim/game_session.gd` | Autoload `Session`: owns the running game, tick, modes, interactions, autosave. |
| `src/sim/drive.gd` | Shared walker drive dynamics + heat impairment (player and enemy). |
| `src/sim/combat.gd` | Projectiles as data, cooling vs structure hit areas, damage. |
| `src/sim/enemy_ai.gd` | Scrapper AI: patrol, detect (heat-based), engage with telegraph, disengage. |
| `src/sim/encounter.gd` | Parked-mech encounter: pilot reaction, boarding, startup, flee, load resolution. |
| `src/persistence/save_codec.gd` | Save envelope, validation, migrations. |
| `src/persistence/save_service.gd` | Autoload `Saves`: slot files, backup recovery, summaries. |
| `src/presentation/app/main.gd` | Root: switches menu ↔ game, starts the autotest driver. |
| `src/presentation/app/game_screen.gd` | In-game composition: world, atmosphere, HUD, overlays, pause. |
| `src/presentation/app/menu_backdrop.gd` | Background behind the main menu. |
| `src/presentation/world/world_view.gd` | Builds the location view; markers, occlusion, spot checks. |
| `src/presentation/world/ground_builder.gd` | Ground tiles, patches and track strips. |
| `src/presentation/world/scatter.gd` | Seeded decorative stones and mineral crusts. |
| `src/presentation/world/prop_view.gd` | One static prop: sprite, footprint collision, cast shadow, roof fade. |
| `src/presentation/world/mech_view.gd` | Mech body, legs, radiator, shutters, heat glow, steam, movement. |
| `src/presentation/world/pilot_view.gd` | Suited pilot on foot: movement, facing, procedural walk. |
| `src/presentation/world/camera_rig.gd` | Follow camera with look-ahead, zoom and bounds. |
| `src/presentation/world/player_input.gd` | Input actions → Session intents and requests. |
| `src/presentation/world/sound_director.gd` | Maps state/events to loops and one-shots. |
| `src/presentation/world/enemy_view.gd` | Enemy mech: movement, telegraph line, damage FX, wreck state. |
| `src/presentation/world/projectiles_view.gd` | Draws projectiles; impact, cooling-hit and muzzle effects. |
| `src/presentation/world/terrain_view.gd` | Rock masses, fading overhead covers, built walls and power cables. |
| `src/presentation/world/light_kit.gd` | Shared glow texture, rotating-light and shadow shaders. |
| `src/presentation/world/fx_kit.gd` | Particle presets (steam, dust). |
| `src/presentation/world/atmosphere.gd` | Phase B atmosphere: day light, colour grade, dust haze, heat shimmer, dust particles. |
| `src/presentation/world/wind_streaks.gd` | Faint screen-space wind streaks under the grade. |
| `src/presentation/ui/ui_theme.gd` | Flat UI theme and small widget helpers. |
| `src/presentation/ui/ui_root.gd` | UI root that applies the UI scale setting. |
| `src/presentation/ui/hud.gd` | HUD: mech, suit, objective, prompts, cargo, notices, danger edge. |
| `src/presentation/ui/objective_pointer.gd` | Edge chevron / ring toward the current objective. |
| `src/presentation/ui/reticle.gd` | Mouse reticle while piloting. |
| `src/presentation/ui/main_menu.gd` | Continue / new game with slot picker / settings / quit. |
| `src/presentation/ui/settings_menu.gd` | Audio, display, UI scale, zoom, language, key remapping, asset reload. |
| `src/presentation/ui/pause_menu.gd` | Resume / save / settings / quit. |
| `src/presentation/ui/dev_overlay.gd` | F3 diagnostics and debug keys. |
| `src/dev/autotest_driver.gd` | Test-only remote control (`--autotest`) for real game processes. |
| `tests/test_runner.gd` | Unit/regression suite (headless). |
| `tools/hs_driver.py` | Python helper that drives game processes. |
| `tools/regression.py` | Runtime regression: loop, restart persistence, overrides, settings. |
| `tools/regression_encounter.py` | Runtime regression for the hostile encounter (combat, AI, wreck, shade, restart). |
| `tools/shots_encounter.py` | Screenshots of the hostile encounter. |
| `tools/regression_refuge.py` | Runtime regression: housing/twin guns, canyon, overhang, workshop, refuge heat, music, parked-mech encounter. |
| `tools/shots_refuge.py` | Refuge screenshots + boarding sequence sheet/GIF. |
| `tools/import_audio.py` | Imports selected creator audio from the inbox into templates. |
| `tools/shots.py` | Captures screenshots of the running game. |
| `tools/shots_b.py` | Phase B screenshots; `--backdrop` captures the menu backdrop template. |
| `tools/art/inkkit.py` | Ink pipeline (Red Thaw kit + desertize, top-down finish, seamless tiles). |
| `tools/art/gen_art.py` | Generates all illustrated templates and FX textures. |
| `tools/gen_placeholders.py` | Phase A diagnostic placeholder sprites. |
| `tools/gen_audio.py` | Synthesises the bundled placeholder sounds. |
| `tools/locale_src.py` | Source of all UI text (EN/DA) → locale/strings.csv. |
| `tools/guide_rows.py` | Descriptions used to write the script guides. |
| `tools/check_script_guides.py` | Checks/rewrites EN + DA script guides. |
