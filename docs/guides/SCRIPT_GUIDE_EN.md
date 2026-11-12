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
| `src/sim/drive.gd` | Shared top-down car dynamics: throttle/brake/reverse, speed-dependent steering, tyre grip and slip, handbrake drift, heat impairment (player and rival cars). |
| `src/sim/combat.gd` | Projectiles as data, cooling vs structure hit areas, damage. |
| `src/sim/enemy_ai.gd` | Rival-car AI: patrol, detect (heat + engine noise), chase and circle-strafe, roof gunner with telegraphed shots, retreat/escape. |
| `src/sim/encounter.gd` | Parked-car encounter: the driver reacts, runs to the car, gets in, engine startup; flee; load resolution. |
| `src/sim/weather.gd` | CLEAR/SANDSTORM weather: gradual build-up, zone storm exposure, cooling/suit/visibility effects. |
| `src/sim/turret.gd` | Junker perimeter turret: rate-limited aim, line of sight, telegraphed slow fire. |
| `src/persistence/save_codec.gd` | Save envelope, validation, migrations. |
| `src/persistence/save_service.gd` | Autoload `Saves`: slot files, backup recovery, summaries. |
| `src/presentation/app/main.gd` | Root: switches menu ↔ game, starts the autotest driver. |
| `src/presentation/app/game_screen.gd` | In-game composition: world, atmosphere, HUD, overlays, pause. |
| `src/presentation/app/menu_backdrop.gd` | Background behind the main menu. |
| `src/presentation/world/world_view.gd` | Builds the location view; markers, occlusion, spot checks. |
| `src/presentation/world/ground_builder.gd` | Ground tiles, patches and track strips. |
| `src/presentation/world/scatter.gd` | Seeded decorative stones and mineral crusts. |
| `src/presentation/world/prop_view.gd` | One static prop: sprite, footprint collision, cast shadow, roof fade. |
| `src/presentation/world/car_view.gd` | The player's car: body, steering front wheels, roof gun ring with twin guns and recoil, body roll/squat, skid marks, heat glow, damage FX, crash feedback. |
| `src/presentation/world/pilot_view.gd` | Suited pilot on foot: movement, facing, procedural walk. |
| `src/presentation/world/camera_rig.gd` | Follow camera with look-ahead, zoom and bounds. |
| `src/presentation/world/player_input.gd` | Input actions → Session intents and requests. |
| `src/presentation/world/sound_director.gd` | Maps state/events to loops and one-shots. |
| `src/presentation/world/enemy_view.gd` | Rival car: wheels, swinging roof gun, telegraph line, driver on foot, damage FX, wreck state. |
| `src/presentation/world/projectiles_view.gd` | Draws projectiles; impact, cooling-hit and muzzle effects. |
| `src/presentation/world/terrain_view.gd` | Rock masses, fading overhead covers, built walls and power cables. |
| `src/presentation/world/turret_view.gd` | Turret visuals: rotating housing, laser telegraph, recoil, damage, wreck. |
| `src/presentation/world/light_kit.gd` | Shared glow texture, rotating-light and shadow shaders. |
| `src/presentation/world/fx_kit.gd` | Particle presets (steam, dust). |
| `src/presentation/world/atmosphere.gd` | Phase B atmosphere: day light, colour grade, dust haze, heat shimmer, dust particles. |
| `src/presentation/world/wind_streaks.gd` | Faint screen-space wind streaks under the grade. |
| `src/presentation/ui/ui_theme.gd` | Flat UI theme and small widget helpers. |
| `src/presentation/ui/ui_root.gd` | UI root that applies the UI scale setting. |
| `src/presentation/ui/hud.gd` | HUD: mech, suit, objective, prompts, cargo, notices, danger edge. |
| `src/presentation/ui/objective_pointer.gd` | Edge chevron / ring toward the current objective. |
| `src/presentation/ui/reticle.gd` | Mouse reticle while piloting. |
| `src/presentation/ui/dev_menu.gd` | F10 developer/cheat menu (runtime only, never saved). |
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
| `tools/regression_junkers.py` | Runtime regression: recoil, sandstorm, dev menu, exploration, Junker base, turrets, defenders. |
| `tools/shots_junkers.py` | Screenshots + recoil GIF for the Southern Junkers iteration. |
| `tools/build_world_south.py` | Writes and validates the expanded map / Junker base in the location file. |
| `tools/heat_balance.py` | Prints the heat balance table (settle temperature, time to warning/critical) from tuning.json. |
| `tools/regression_balance.py` | Runtime regression: speed/responsiveness and progressive heat pressure. |
| `tools/shots_balance.py` | Screenshots for the movement/heat rebalance. |
| `tools/shots.py` | Captures screenshots of the running game. |
| `tools/shots_b.py` | Phase B screenshots; `--backdrop` captures the menu backdrop template. |
| `tools/art/inkkit.py` | Ink pipeline (Red Thaw kit + desertize, top-down finish, seamless tiles). |
| `tools/art/gen_art.py` | Generates all illustrated templates and FX textures. |
| `tools/gen_placeholders.py` | Phase A diagnostic placeholder sprites. |
| `tools/gen_audio.py` | Synthesises the bundled placeholder sounds. |
| `tools/locale_src.py` | Source of all UI text (EN/DA) → locale/strings.csv. |
| `tools/guide_rows.py` | Descriptions used to write the script guides. |
| `tools/check_script_guides.py` | Checks/rewrites EN + DA script guides. |
| `src/sim/creatures.gd` | The thawed-out ecosystem: skirr pack, grindback burrower and rimeback quarry — senses, telegraphed attacks, breakable parts, flee/burrow (pure data). |
| `src/sim/garage.gd` | Settlement workshop upgrade lines (chassis, engine, turbo, armour, tyres, cooling, weapons, cargo): prices, rank unlocks, effects on car/heat/gun tuning, legacy upgrade migration. |
| `src/sim/journey.gd` | Continental route network (data/journey.json): nodes, edges, fuel costs, arrival bookkeeping, shortest route and nearest safe zone. |
| `src/presentation/ui/hazard_ribbon.gd` | Diagonal hazard tape in the top-right corner: DANGER / SAFE-ZONE / CLEARED. |
| `src/presentation/ui/minimap.gd` | Minimap: roads, rock, settlement, gates, blinking anomalies, discovered sites, player arrow. |
| `src/presentation/ui/journey_map.gd` | Continental map screen (M): node states, routes with fuel cost, node info, set course. |
| `src/presentation/world/poi_view.gd` | Abandoned expedition sites (wreck, dead driver, papers, fire) and landmarks. |
| `src/presentation/world/relief.gd` | Visual-only elevation: heightfield, hillshade texture, altitude scale for objects. |
| `tools/build_continent.py` | Generates and validates the settlement and territory maps of the continental journey (run after build_world_south.py). |
| `src/sim/loot.gd` | Physical ground loot with rarities: spawn, drop tables, lookup. |
| `src/presentation/world/creature_view.gd` | One creature: body parts, gait, in-world telegraphs (lanes, crack rings, arcs, glowing glands), hit/part-break FX, carcass. |
| `src/presentation/world/hunt_marks.gd` | Tracks fading with age (blood marked), ground loot with rarity glow and legendary star, tyre skid marks. |
| `src/presentation/ui/garage_menu.gd` | Garage screen: condition, cargo, full repair, modules with have/need costs and effect preview. |
| `src/presentation/ui/help_overlay.gd` | In-game field guide (H): driving, shooting, heat, tracking, hunting, harvesting, garage, on foot. |
| `src/presentation/ui/tracker_widget.gd` | Tracking compass: species, freshness, blood, arrow along the trail. |
| `tools/art/gen_thawborn.py` | Ink-pipeline templates for cars, rival cars, creatures, tracks and hunt materials; registers manifest entries. |
| `tools/regression_hunt.py` | Runtime regression of the full Thawborn loop: refuge → drive → track → hunt → harvest → loot → garage → save/reload; rival car, skirrs, grindback, sandstorm. |
| `tools/build_windows.py` | Windows build: Godot export, portable zip and NSIS installer (export/). |
| `tools/shots_thawborn.py` | Screenshots of the Thawborn conversion and the menu backdrop capture. |
| `tools/regression_playtest.py` | Runtime regression for playtest fixes 001–006 (windowed): reverse steering, starter heat, garage cursor, cargo unloading + storage, fast bullets. |
