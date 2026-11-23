# Thawborn — complete-game plan and status

Master brief: "THAWBORN — THE COMPLETE GAME, Version 1.0 Draft". Branch `iteration/complete-game`,
recovery reference `backup/pre-complete-game` (= `3885f3f`, Thawborn 0.3.0 Continental Journey).

## Baseline audit (start of the iteration, `3885f3f`)

| Area | Baseline | Gap against the brief |
|---|---|---|
| Driving | fast car (560 px/s), smoothstep steering onset, gentle reverse, handbrake drift, crash damage, camera pull-back | keep; per-chassis handling |
| Guns | one twin MG (1900 px/s, 0.17 s, 1000 px), segment hits, recoil, audio | 5 weapon families, ammunition |
| Loop | money, fuel (limp mode), selling, garage storage, 8 upgrade lines, Jäger rank | contracts, ammo, chassis, recovery on failure, difficulty |
| Continent | 9 nodes (3 settlements, 5 territories, hub), exits/prompts/auto-exit, minimap, anomalies, expedition sites | 5 regions, ~16 nodes, distinct Stahlheim |
| Story | sealed case objective only | Kern-7, 3 acts, recurring characters, finale, ending, credits |
| Creatures | skirr, grindback (Wühler), rimeback (Eisback) | Dornmaul, Glutkriecher, Aschenläufer, apexes |
| World | relief/hillshade, sandstorms, Junker base, refuge | day/night, regional hazards |
| Menu | creator prints + creator logo on the workshop table | keep (locked) |
| Tests | 1049 unit tests, 7 runtime regressions | campaign regression |
| Delivery | local NSIS installer in `dist/` | GitHub Actions Windows build |

## Stages
A audit · B expedition loop · C continent · D campaign · E creatures · F/G polish, CI, verification.
Status of each stage is recorded at the end of this file when it lands.

## Audit: implementation vs the master brief (release candidate)

Legend — **V** implemented and verified (automated tests and a rendered game process) · **I** implemented,
not fully verified (reason given) · **D** incomplete or deferred (reason given).

| Brief § | Item | Status | Evidence / notes |
|---|---|---|---|
| 1 | Preflight, backup, working branch | V | `backup/pre-complete-game` = `3885f3f`; branch `iteration/complete-game` |
| 2–3 | Setting, names (Ersthafen, Stahlheim, Jäger, Eisenwolf Werke, Eisback), German-industrial frontier | V | names throughout UI/world; no WWII imagery |
| 4–5 | Kern-7 premise, three acts, ending, post-game | V | `regression_campaign.py`, `shots_campaign.py` (rendered cards, finale, ending, credits) |
| 6 | 15–20 nodes, 5 regions, branching routes, physical locations | V | 16 nodes / 5 regions; unit + runtime tests; rendered tour |
| 6 | Travel rules (slow-down, prompts, auto-exit, cooldown, no walls) | V | unit + `regression_hunt.py` |
| 6 | 10–15 h first playthrough | D | estimated 6–10 h from economy numbers; the creator asked not to pad. Not measured |
| 7 | Settlement services (sell, fuel, repair, ammo, upgrades, storage, contracts, map) | V | garage tabs rendered; unit + runtime |
| 8 | Driving (speed, steering onset, reverse, drift, zoom) | V | earlier playtest regressions still pass |
| 8 | Suspension/body motion, engine audio, tyre dust/tracks | I | visual/audio present; engine audio per equipment implemented, not audibly verified here (no speakers) |
| 9 | Weapons ×5, ammo, recoil, tracers, impacts, no tunnelling | V | unit (pellets, blast, ammo) + rendered MG/flak; autocannon/rifle/launcher fired in unit tests only |
| 10 | Chassis ×3, upgrade lines, visible upgrades | V / I | chassis + 13 lines unit-tested; kits rendered on the car; chassis/kit art is template |
| 10 | Cosmetic choices | D | not implemented (no paint/decal system); out of scope for this pass |
| 11 | Creature roster (Skirr, Wühler, Eisback, Dornmaul, Glutkriecher, Aschenläufer) | V | unit + rendered |
| 11 | Apexes (Alter Eisback, Dornkönig, Glutmutter, Kaltvater) | V | rendered Dornkönig/Glutmutter/Alter Eisback/Kaltvater; Kaltvater quake + summons unit-tested |
| 11 | Young/mature, rare variants, mutations, storm/night behaviour | I / D | night hunters (skirr family) implemented; young/rare/mutated variants not implemented |
| 12 | Tracking (tracks, blood, compass), weather complicates tracking | V | existing systems; storms muffle; night shortens sight |
| 13 | Contracts: authored story + generated repeatable, sensible constraints | V | unit test proves generated contracts are achievable |
| 14 | Money economy, no crafting, storage, never stranded | V | recovery truck, limp mode; unit + runtime |
| 15 | Physical settlements with distinct atmosphere, Stahlheim city | V / I | five styles rendered; layouts are generated, not hand-authored |
| 15 | Recurring cast (7) with portraits and dialogue | V / I | cards rendered; portraits are templates |
| 16 | Southern Junkers role | I | existing Junker base and rivals; Oskar's Junker contract; no non-hostile Junkers |
| 17 | Anomalies, abandoned expeditions, persistent discovery | V | unit + rendered |
| 18 | Terrain relief, canyons, highway | V | relief, Dornpass canyon theme, Hochstraße asphalt |
| 19 | Weather + day/night | V | storms (existing) + day/night (unit + rendered night/dusk) |
| 20 | Sound design | I | creature voices per species/size, weapon voices, engine layers; no new recorded audio; music unchanged |
| 21 | Main menu with creator prints + `Thawborn Logo.png` | V | rendered, hashes unchanged; logo also heads the credits |
| 21 | HUD, map, minimap, garage, contracts, guide, pause, endgame | V | rendered |
| 22 | Difficulty presets, failure recovery, saves (autosave, migration) | V | unit + runtime; save v8 migration tested |
| 23 | Polish (transitions, feedback, credits, ending) | I | ending/credits rendered; general polish needs a human playtest |
| 24 | Post-campaign play, records | V | open world after credits; field-guide hunting record |
| 24 | New Game+ | D | optional in the brief; not implemented |
| 25 | F10 tools (fuel, repair, money, upgrades, weapons, chassis, clear, complete/travel node, spawn incl. apexes, story advance, time of day) | V | dev menu + driver |
| 25 | Unlock a route | I | routes open by discovery; "travel to node" covers testing; no separate unlock button |
| 27 | Data-driven, modular | V | weapons/vehicles/contracts/story/creatures/locations in data; new modules |
| 28 | Verification list | V / I | see the report; Windows launch itself not verified (no Windows here) |
| 29 | Windows build (CI artifacts + installer) | V / I | CI green with ZIP + installer artifacts; not launched on Windows |

## Campaign length
Critical path: about 12 map transits, 3 story hunts and the finale. From the economy (a territory
hunt-and-return takes roughly 10–25 minutes; late-region gear costs 5–15 k Mark), a first playthrough is
estimated at **6–10 hours**, below the brief's 10–15 h target. The creator asked not to pad the campaign;
the gap is left for the playtest to judge. This is an estimate, not a measured playthrough.

## Deferred / incomplete (after the release candidate)
1. Cosmetic choices for the car (paint, decals).
2. Young / rare / mutated creature variants (night hunters exist; storms already muffle senses).
3. Non-hostile Junkers and deeper faction interaction (kept simple on purpose).
4. Hand-authored settlement and territory layouts (currently generated from the prop kit).
5. Creator art passes: portraits, new species, Stahlheim buildings, chassis and kits (all template art,
   overridable without code).
6. New recorded audio (engine/turbo layers and creature voices reuse the existing clips).
7. New Game+ (optional in the brief).
8. Windows launch verification and balance from a human playtest.
