# Replacing art and sound (creator guide)

Every replaceable sprite, ground tile and sound has a **logical ID** in
`assets/manifest/assets.json`, with its folder path, display size, recommended source size, pivot and
facing. Replacing a file never needs a script change, and it never changes collision or saved state:
the game fits any image into the manifest's display box.

## Where files go (first valid file wins)
| Priority | Location | Use it for |
|---|---|---|
| 1 | `<folder of HeatSignature.exe>\overrides\<dir>\<name>.png` | exported Windows builds (portable) |
| 1 | `%APPDATA%\HeatSignature\overrides\<dir>\<name>.png` | any build, incl. running from the editor |
| 2 | `assets/overrides/<dir>/<name>.png` inside the project | art you want to commit and ship |
| 3 | `assets/templates/<dir>/template_<name>.png` | bundled template art (generated) |
| 4 | magenta checker / silence | diagnostic fallback, logged once |

Example for the mech hull (`mech.hull`, path `mechs/starter/hull`):
- template: `assets/templates/mechs/starter/template_hull.png`
- your version: `assets/overrides/mechs/starter/hull.png` (same folders, no `template_` prefix)

Sounds work the same way (`.wav` or `.ogg`), e.g. `assets/overrides/audio/sfx/warning.wav`.
Invalid files (unreadable, smaller than 4 px or larger than 4096 px, over 16 MB) are rejected and the
next source is used. Check the log (`%APPDATA%\HeatSignature\logs\session.log`) or the F3 overlay
(override and fallback counts).

**Reload without restarting:** Settings → *Reload art & sound*, or F4 while the F3 overlay is open.
Files dropped into `assets/overrides` while the editor is closed are read directly until Godot imports them.

## Drawing rules (HUION / any tablet app)
1. Open the template PNG at the manifest's **source** size (about 2× display). Keep the canvas size
   and aspect ratio; the art is centred in its box.
2. **Straight top-down.** Rotating parts (mech hull, legs, radiator, shutters, pilot) must face
   **up** (north). The game rotates them. Don't paint a cast shadow on rotating parts: the game adds
   a world-aligned shadow. Light still comes from the **upper left**.
3. Static props can include a soft contact darkening at their base, but no long cast shadow. The
   game casts one from the alpha toward the lower right (manifest `height` sets its length).
4. Transparent background (PNG with alpha). Ground tiles must be seamless and opaque. `ground.track`
   is a strip that repeats horizontally, with soft transparent top and bottom edges.
5. Export PNG, 8-bit RGBA, sRGB. Name it exactly like the template minus `template_`.
6. Recommended layer stack (matches the ink pipeline): flat colour → soft mottled texture → shadow-side
   hatching (−55°, about 4–6 px apart, ~35 % opacity) → brush-pen linework in warm near-black
   `#211B15` with varied width and tapered ends → grime/dust → a slightly broken outer contour.

## Thawborn IDs (cars, creatures, tracks, materials)
Same rules as above: drop `<name>.png` into `assets/overrides/<dir>/` (or `<exe>/overrides/…`,
`user://overrides/…`) and it replaces the template automatically. Everything rotating faces **up**
(nose/head up) and is centred unless noted.

| ID | Override path | Display box | Notes |
|---|---|---|---|
| `car.body` | `vehicles/player/body.png` | 132×240 | player car, nose up; radiator grille at the nose |
| `car.wheel` | `vehicles/player/wheel.png` | 28×48 | one tyre; four are placed, the front pair steers |
| `car.gun_ring` / `car.twin_gun` | `vehicles/player/gun_ring.png` / `twin_gun.png` | 76×76 / 24×70 | roof mount; gun pivot 70 % down |
| `rival.body` / `rival.junker_body` | `vehicles/scrapper/body.png` / `vehicles/junker/body.png` | 118×214 / 124×220 | rival cars |
| `rival.wreck` / `rival.junker_wreck` / `rival.gun` | `vehicles/…/wreck.png`, `vehicles/rival/gun.png` | | |
| `creature.skirr` (+`_dead`) | `creatures/skirr/body.png` / `dead.png` | 62×92 | |
| `creature.grindback` (+`_dead`), `creature.mound` | `creatures/grindback/…` | 156×196 | shovel plate top, vent bottom |
| `creature.rimeback`, `_head`, `_tail`, `creature.rime_gland`, `creature.rimeback_dead` | `creatures/rimeback/…` | 300×400 body | head pivot = neck (75 %), tail pivot = root (8 %) |
| `decal.track_skirr`, `decal.track_rime`, `decal.furrow`, `decal.blood`, `decal.skid` | `decals/…` | | ground decals (faded by age in game) |
| `item.skirr_hide` … `item.thawheart` | `items/<item>.png` | 44×44 | loot icons; rarity glow is drawn by the game |

## Regenerating the bundled templates
`python3 tools/art/gen_art.py` (illustrated, Phase B) or `python3 tools/gen_placeholders.py --force`
(diagnostic, Phase A). These only write `assets/templates/`; they never touch `assets/overrides/`.
