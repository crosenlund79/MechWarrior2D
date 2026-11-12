# Thawborn (formerly Heat Signature) — visual direction: "Dirty Ink Wasteland"

**Status: EXPLORING (provisional until the creator reviews the rendered result).**
Source DNA: Red Thaw (`crosenlund79/ZombieSurvival2D`, branch `iteration/010-red-thaw`, export commit
`f15028a`, `docs/visual_direction/export/`: `VISUAL_DNA.md`, `GODOT_REPRODUCTION_GUIDE.md`,
`RED_THAW_SPECIFIC.md`, `PORTABLE_VISUAL_PROMPT.md`). Red Thaw was read only, never modified.

## 1. What was transferred unchanged (Red Thaw values)
| Technique | Where | Value |
|---|---|---|
| Hand-illustrated, non-pixel sprites; Linear filtering | `project.godot` | `default_texture_filter=1` |
| Warm near-black ink | `tools/art/inkkit.py` `INK` | `#211B15` (33, 27, 21) |
| Brush-pen line: jitter, width 0.7–1.25×, tapered ends, dry-brush ghost | `Canvas.ink` | wobble 0.9, seg 6, taper 20 %, ghost 38 % α / 45 % width |
| Line hierarchy | generators | contours 2.2–3.0, inner forms 1.4–2.0, texture 0.8–1.4 at α 90–200 |
| Mottled fill with warm/cool drift, upper-left light | `Canvas.fill` | tex 0.25–0.4, light (−1, −1, 0.3) |
| Shadow-side hatching | `Canvas.shade` | −55°, 4.5 px, α 60–95, optional cross-hatch +85° |
| Finish pass: rough broken silhouette, inner edge burn, grain | `Canvas.finish` | outline 2.6, burn 0.32, grain 0.05, 8 % broken ring |
| 2× source, 2× supersampling, Lanczos down | manifest `source`, `SS = 2` | |
| Seamless lower-detail ground tiles, no finish | `Tile` | 3-colour ramp, 4–5 octaves, marks at 9 wrap offsets |
| Baked contact shadows | `soft_shadow` | colour (20, 18, 12), α 90–140 |
| One full-screen grade, UI excluded | `atmosphere.gd` (CanvasLayer 5; UI on 10) | Red Thaw shader structure |
| World-anchored fog technique | grade shader | two-scale drift via canvas transform |
| Radial glow light | `LightKit.glow` | 256² gradient, 0.55 α at 0.45 |
| Drift particles, desynchronised motion | `atmosphere.gd`, views | 170 motes, phase from world position |
| Calm flat UI | `ui_theme.gd` | charcoal 94 %, straw border 35 %, radius 4–6, default font |

## 2. Top-down adaptations (Red Thaw is 3/4 oblique; these settings did NOT transfer)
| Red Thaw (3/4) | Heat Signature (straight top-down) |
|---|---|
| Pivot at ground-contact point, y-sort by feet | Pivot at the centre of the footprint; layering by **height class** (ground, floor, props, actors, roof) |
| Front-facing illustrations, one per facing | One **plan-view** illustration facing up; the game rotates it |
| Baked ellipse shadow under the feet | Soft **non-directional** contact darkening baked in; **cast shadow at runtime** from the sprite alpha, offset toward the lower right in **world** space (`height` in the manifest), so it stays correct when objects rotate |
| Baked upper-left shading on everything | Static props bake it. Rotating parts get a runtime **rotating-light shader** that brightens their world upper-left half (strength 0.12) |
| Vertical base darkening in `finish()` | `finish(top_down=True)`: a gentle upper-left → lower-right falloff |
| Grime drips (gravity) | Grime **streaks dragged downwind** (wind from the upper left) |
| Occlusion fade when behind a tall prop | **Overhead fade**: roofs fade to 0.42 while the mech or pilot is underneath |
| Walk bob (vertical offset) | Shoulder sway ±0.07 rad + 3.5 % scale pulse; mech legs stride ±22 px |
| Vegetation sway | Cloth **flutter** shader (shelter flag) and sand streams |

## 3. Heat Signature palette
- **Ground:** sun-bleached sand (166,128,84) → (204,166,112) → (226,196,146); dune ripples; pale
  salt crust (196,186,166) → (238,232,218) with polygonal cracks and iron-oxide stains.
- **Materials:** ochre (196,146,72), burnt sienna (152,86,52), rust (128,72,44)/(92,52,34), oxidised
  steel (108,102,92), faded industrial yellow (200,160,70), faded utility green (112,126,104), sun-faded
  tarp (176,120,72), charcoal (54,47,40), dark openings (30,24,20).
- **Reserved accents (meaning only):** coolant teal (62,160,150) for cooling hardware and water,
  amber (232,150,40) for warnings and the visor, hi-vis orange on the suit for readability,
  danger red (UI only).
- Rule from Red Thaw: one base hue per material; vary value and warm/cool, not hue.

## 4. `desertize()` — the setting pass (replaces Red Thaw's `winterize`)
`Canvas.desertize(dust, abrasion, bleach, seams, heat=[(x, y, r, strength)])`, applied before
`finish()` with material-specific values:
1. **Sun bleaching / faded paint:** saturated pixels lose the most chroma, and the brightest values
   lift toward bone white.
2. **Seam grime:** cavities (darker than a 3 px blur) get darker and browner.
3. **Sand abrasion:** windward edges (toward the upper left) are scoured lighter, plus sparse scratches.
4. **Heat discoloration:** temper rings (straw → bronze → blue-violet) around exhausts and hot cores.
5. **Fine dust deposits:** a speckled film plus build-up in the wind shadow (lower right) of shapes.

Typical values: painted metal 0.45/0.45/0.35/0.6; rock 0.6/0.5/0.15/0.4; tarp/cloth 0.3/0.2/0.55/0.2;
radiator 0.3/0.4/0.25/0.5 plus heat. It is never a global orange tint.

## 5. Screen grade (`src/presentation/world/atmosphere.gd`)
The grade starts from Red Thaw's **neutral-warm** preset (sat 0.88, contrast 1.10, shadow
(0.88, 0.94, 0.96), highlight (1.05, 1.0, 0.90), vignette (0.50, 0.45, 0.38) at 0.28, grain 0.07),
then adjusts for harsh desert sun:

| Preset | sat | contrast | shadow tone | highlight tone | vignette tone / str | grain | dust haze | shimmer |
|---|---|---|---|---|---|---|---|---|
| Sun (open desert) | 0.84 | 1.10 | (0.90, 0.93, 0.98) slightly cool shade | (1.07, 1.0, 0.88) hot highlights | (0.56, 0.43, 0.31) / 0.30 | 0.07 | 0.10 | 0.7 px |
| Shade (under the shelter) | 0.86 | 1.08 | (0.88, 0.92, 0.97) | (1.03, 1.0, 0.92) | (0.50, 0.42, 0.34) / 0.40 | 0.08 | 0.04 | 0.25 px |

Day light (`CanvasModulate`) (1.0, 0.97, 0.90). The scene blends between presets over ~1 s when the
active actor enters shade. NEW: **heat shimmer** is a world-anchored UV wobble of 0.7 px (it grows by
up to +0.6 px when the mech is past 95 °C). **Dust haze** is Red Thaw's fog technique in warm sand
colour (0.90, 0.79, 0.62). Both stay inside the guide's safe ranges (sat ≤ 0.9, contrast 1.05–1.12).

## 6. Scale (≈ 42 px per metre, display px)
Mech hull 200×220 with legs ±98 (≈ 6 m wide) · pilot 46×54 · radiator core 42 · shelter roof 560×440 ·
pump-rig wreck 360×290 · large rock 150×130 · ground tiles 512 px.

## 7. Environmental motion (all small, slow and desynchronised by world position)
Drifting dust motes; low sand streams over dune fields; screen-space wind streaks (46 lines,
α 0.03–0.10); flag flutter; mech stride, hull sway and idle shudder; footfall dust; steam when
hot or shut down; pulsing heat glow on the radiator; bobbing glint on salvage.

## 8. Readability rules
The UI is flat, never graded and never textured. The objective pointer is always visible.
Danger is signalled by an edge glow on the UI layer, not by grading the world. Pilot hi-vis stripes
and the amber visor keep the small figure readable on sand. Coolant teal appears only on cooling
hardware and water.

## 9. First hostile encounter (same pipeline)
- **Scrapper** (`enemy.hull`, `enemy.leg`, `enemy.wreck`): narrower and hunched, in oxide red and rust
  with welded mismatched plates, a cab offset to the left and a crude welded pipe cannon. Its **exposed
  rear radiator** with teal hoses marks the cooling hit area, so you can tell it from the player's
  yellow/green mech at a glance.
- **Wreck:** a separate sprite with collapsed splayed legs, a bent barrel, smashed fins, soot blooms
  and a sand drift. The body is dimmed, with slow smoke, occasional sparks and a salvage glint until
  stripped.
- **Telegraph:** a red aim line from the muzzle with a growing glow (UI-free, in-world).
  **Shots:** player = thin amber tracers; enemy = slow, fat glowing slug with a soot trail.
  **Hits:** small spark burst; cooling hits add a teal coolant puff and steam.
- **Damage states:** a coolant leak below 35 % cooling, smoke below 45–50 % integrity, steam when hot,
  a hit flash (Red Thaw recipe).
- **Turret** (`mech.gun`) rotates over the hull. The **awning** (`shelter.awning`) is a stitched tarp
  sail on four posts. Its shade zone equals its cast-shadow footprint and it fades when you are under it.

## 10. Southern Junkers and the expanded desert
- **Faction identity:** a consistent palette on every piece of equipment.
  - Colours: oxide orange (188, 96, 42), tar black (44, 38, 33) hazard bands, rust and bare steel.
  - Insignia: a **bone stencilled cog with a south-pointing chevron**. It appears on hulls, turret
    housings, the workshop roof, tarps and as worn floor decals.
  - Construction is visibly welded scrap plate, with ram bars and spikes on the wall tops. It is
    rougher and more aggressive than the player's yellow/green refuge machinery.
- **Turret:** an octagonal scrap mount with plate buttresses and a rotating orange housing with an
  ammo box. A red laser line telegraphs each shot. Destroyed turrets become a collapsed, smoking wreck.
- **Weapon feel:**
  - a star-shaped additive muzzle flash with a light burst
  - receiver smoke and sand blasted off the ground in the firing direction
  - long hot tracers
  - sand impacts throw dust plus grit; metal impacts throw a spark shower plus a hot flash
  - enemy mechs flinch along the direction of the shot
- **Sandstorm:** the Red Thaw fog technique, pushed further.
  - Haze increases with distance from the screen centre, so the player and nearby obstacles stay
    readable.
  - Fast world-anchored sand sheets, a dense camera-following dust layer, more and longer wind
    streaks, and a warm-tinted daylight.
- **New locations:** the same ink pipeline throughout. They are the cooling towers and tanks, a
  radiator bank, pipe rack and control shed, the rest-stop canopy (overhead fade), kiosk, pumps, cars,
  billboard, evacuation signs, a cracked asphalt highway, the scrap field, and the ravine rock.

## 11. Known limitations / open questions for the creator
- All art is **generated placeholder illustration** in the ink pipeline, not hand-drawn. It exists
  to evaluate the style and is fully replaceable (see `guides/ASSET_REPLACEMENT.md`).
- The menu backdrop (`ui.menu_backdrop`) is a capture of the running game
  (`tools/shots_b.py --backdrop`). Replace it with a painting if you like.
- No night or day cycle yet. No dynamic 2D shadows, by design.

## 12. Thawborn: cars and the thawed-out creatures (same pipeline, `tools/art/gen_thawborn.py`)
- **Player car.** A rugged flatbed 4×4 in the refuge colours: faded industrial yellow bonnet, faded utility
  green cab, rust flatbed with strapped crates and teal coolant cans. It has a bull bar, the radiator
  grille at the nose (the cooling hit area) and a roof gun ring with twin guns. The tyres are separate
  sprites; the front pair visibly steers. Weight is shown by body roll, squat and dive, skid marks,
  tyre dust and impact shake.
- **Rival cars.** Scrappers in oxide red with welded mismatched plates, the cab offset left, and an
  exposed front radiator with teal hoses. Junkers add oxide orange, tar hazard bands, the bone cog
  insignia and a spiked ram bar. A crude roof gun swings toward its target.
- **Creatures** must never read as machinery. Pale, cold hides that lived under ice: bone (196,190,176),
  slate (104,110,116), frost (214,226,228), with **temper blue-violet** (112,92,124) mottling and
  bands. That violet is also the legendary loot colour: the Thawheart is the rimeback's violet core.
  Coolant teal stays reserved for cooling hardware.
- **Telegraphs** are drawn in the world, never as UI:
  - Rimeback charge: an amber lane.
  - Rimeback tail sweep: a red arc behind it.
  - Spit: the frost glands swell and glow.
  - Grindback: a sand crack ring where it will erupt, and a racing sand mound before it.
  - Skirr crouch: the body squashes and the eyes glint.
- **Signs and loot.**
  - Tracks are ink-stamped decals (three-toed skirr prints, deep cloven rimeback prints, grindback
    furrows). They fade from dark to faint with age; blood drops mark a wounded animal.
  - Loot lies on the sand with a rarity ring and glow: bone (common), straw (uncommon), bronze (rare)
    and temper-violet plus a turning star (legendary).
- All of this is generated placeholder art meant to be replaced (see `guides/ASSET_REPLACEMENT.md`).

## Continental Journey additions
- **Frontier identity:** German-industrial frontier (Eisenwolf Werke badge, stencilled place signs,
  Tankstelle/Handelsposten), weathered and practical. Explicitly **not** WWII or Nazi imagery: no eagles,
  black-letter, uniforms or period insignia.
- **Elevation illusion:** a soft hillshade (light from the upper left), faint contour lines, darker
  depressions; objects grow up to 7 % on high ground and cast longer shadows. Roads and settlement
  yards are graded flat. Visual only.
- **Zone tape:** diagonal hazard tape in the top-right corner — red DANGER, yellow SAFE-ZONE, sage-grey
  CLEARED (Stahlheim after the delivery).
- **Main menu:** the creator's two prints (`assets/Illustrations/`) lie rotated on a weathered workshop
  table under a warm lamp, with tape, a map, tools and papers; the menu is a paper job card.
- **Minimap and continental map:** parchment and ink, like a field surveyor's chart; anomalies blink
  temper-violet until identified.
