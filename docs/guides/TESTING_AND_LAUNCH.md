# Testing and launch (Thawborn)

## Creator workflow (Windows, no build steps)
1. GitHub → select the branch → **Code → Download ZIP** → extract anywhere.
2. Open **Godot 4.7.2** (standard edition) → **Import** → select `project.godot` → *Import & Edit*.
   The first import takes a few seconds; the `.godot/` cache is created locally and never committed.
3. Press **F5** to run. Windowed 1600×900 by default; Settings switches to fullscreen.
4. Saves, settings and logs live in `%APPDATA%\HeatSignature\` (open it from Godot: *Project → Open
   User Data Folder*).

## Playing the first loop (about 3 minutes)
1. You start parked in the shade shelter. The radiator is worn (55 %). Drive east along the track (W/A/D).
   The mech is fast now, and ordinary driving stays below the warning.
2. Watch **MECH CORE**: "settling at" shows where the temperature is heading. Heat builds with
   sustained fire, the hot salt pan, sandstorms and damaged cooling. Combine them and you can still
   overheat (engine shutdown, steam, alarm), always after a warning.
3. Stop, press **E** to exit. The suit drains (~70 s in open sun; slower in shade, faster on salt).
4. Walk to the wrecked pump rig (the pointer shows the way), press **E** to salvage the radiator core.
5. Walk back to the mech and press **R** to repair (3 s; standing still). Cooling jumps to ~85 %.
6. **E** to re-enter; the suit recharges. Drive on. Close the shutters (**R** in the mech) when
   crossing the dunes: the sand there shreds an open radiator.
7. Quit, restart Godot, **Continue**: the salvage stays taken and the repair stays done.

## The hostile encounter (about 4 minutes)
1. Follow the south track toward the salt pan. A rusty-red **scrapper** patrols around the dead hauler.
   It sees a hot mech from farther away.
2. When it engages, it turns to face you. A red aim line and a glowing muzzle warn about 1.2 s before
   each slow, fat shot. Step sideways to dodge.
3. Aim with the mouse and hold left click. Body hits wear down its hull. Hits on its **exposed rear
   radiator** (teal hoses) wreck its cooling, so it overheats, slows, and stops shooting to cool.
   Firing heats your mech too.
4. Running hot? Back off into the shade of the **salt-works awning** (north-west of the salt pan). It
   lowers heat gain and slows suit drain, but it doesn't erase heat.
5. Once it is a wreck (smoke, sparks, glinting ring), park, step out and strip it (E, 3.5 s, costs suit
   time). You get 4 scrap and a radiator core. Each wreck can be stripped once.
6. Back at your mech: R repairs the radiator with the core, and R again patches the hull with 2 scrap.
   If your hull hits 0, the mech is crippled. Step out and R gives a slow, free emergency patch to 25 %.

## The first hunt (about 6–10 minutes)
1. New game: the car is parked in the canyon refuge garage bay. **H** shows the field guide.
2. Drive out by the dirt road east, then south down the track to the old highway, then south into the
   **Thaw Flats**. Ordinary driving never reaches the heat warning.
3. Big hoof prints appear on the sand. The **tracking compass** (bottom left) names the species, shows how
   fresh the sign is, and points the way the animal went. Follow fresher prints.
4. The **rimeback** roars when it notices you (noise, heat, sight). Keep circling at 400–500 px. When it
   lowers its head an amber **charge lane** appears, so steer out sideways. Close in, the tail coils
   (red arc). At range, the frost glands glow before it spits.
5. Shoot the glands, horn and tail. Broken parts drop materials on the sand. Below about 30 % it limps
   toward its lair in the far south-west, leaving blood prints. Follow and finish it.
6. Stop by the carcass, get out (**E**), walk up and **harvest** (E, 4 s). Get back in and roll slowly over
   the materials to load them. A legendary **Thawheart** drops only if both glands were broken.
7. Drive back to the refuge bay and press **G**: repair for scrap and fit a module (for example
   cooling L1 = frost gland + 2 scrap).
8. Save (F5), quit, continue: upgrades, cargo, the carcass and any loot left lying are all kept.

Other things to try: drive fast through the central dune sea (a **grindback** tunnels at you; shoot its
rear vent while it is dazed). Visit skirr country north-east of the salt pan (a pack circles and lunges).
Meet the scrapper car by the salt pan or the Junker scrapyard. Start a storm from F10.

## Developer menu (F10)
F10 opens it during play, without pausing. It has controls for:
- **Weather:** dynamic weather on/off, clear now, start or stop a storm, storm intensity.
- **Enemies:** spawn scrappers or Junkers near you, clear spawned enemies, aggression on/off.
- **Player and mech:** repair all, refill suit, restore cooling, invulnerability, simulation speed.
- **Teleport:** to the refuge, the Junker base, the cooling station or the scrap field.
- **Reset:** restore default settings.

None of it is saved, and it resets on new game, continue and return to menu. A "DEV:" badge in the
lower-right corner shows active cheats.

## Automated checks (any OS with Godot 4.7.2 on PATH as `godot`)
```bash
godot --headless --path . --import
godot --headless --path . res://tests/run_tests.tscn -- --instance=unit_tests
python3 tools/regression.py
python3 tools/regression_encounter.py
python3 tools/regression_refuge.py
python3 tools/regression_junkers.py
python3 tools/check_script_guides.py
```
- `run_tests.tscn`: unit and regression suite covering content, manifest, zones, thermal maths,
  the in-memory loop, collapse, saves/backup/migration, overrides/fallback, audio and settings.
- `regression.py`: starts the **real game** twice (via `--autotest`). It plays drive → overheat → stop →
  exit → salvage → return → repair → continue, then restarts Godot and verifies persistence, settings
  persistence, external override → removal → template fallback, and the suit-collapse consequence.
- Screenshots (needs a display): `xvfb-run -a -s "-screen 0 2600x1200x24" python3 tools/shots.py docs/screenshots/<dir> <prefix>`
  (Phase A flow) or `python3 tools/shots_b.py docs/screenshots/phase_b` (illustrated location).
- Regenerate art: `python3 tools/art/gen_art.py` (needs Python 3 + Pillow + numpy; ~1 min). Not needed to run the game.

## Windows build and installer
`python3 tools/build_windows.py` exports with the *Windows Desktop* preset (needs the Godot 4.7.2 export
templates installed) and writes three things to `export/`:
- `Thawborn.exe` + `Thawborn.pck`;
- a portable `Thawborn-<version>-windows.zip`;
- if NSIS (`makensis`) is available, `Thawborn-<version>-setup.exe`.

The installer installs per user (no admin rights) to `%LOCALAPPDATA%\Programs\Thawborn`. It adds a
Start-menu shortcut, a desktop shortcut and an uninstaller. Saves (`%APPDATA%\Thawborn`) and your
`overrides` folder are never removed. Put your own art into `overrides\` next to the .exe, using the same
folder layout as `assets/templates`.

What was verified in the build environment (Linux): the export completes, and the exported `.pck` runs in
Godot (new game, driving, save) with every Thawborn asset resolving. The `.exe` itself has not been
launched on Windows from here: no Windows or Wine was available.
