# Design register

**APPROVED** = decided by the creator brief · **EXPLORING** = implemented provisionally, needs creator
review · **DEFERRED** = explicitly out of scope for now.

| ID | Item | Status | Notes |
|---|---|---|---|
| HS-01 | Setting: former Antarctica as a lethal desert; ~98 % of Earth uninhabitable | APPROVED | |
| HS-02 | Straight top-down 2D (not 3/4 oblique) | APPROVED | |
| HS-03 | The mech is shelter, storage and life support; heat is the main enemy | APPROVED | |
| HS-04 | First loop: drive → overheat → stop → exit → scavenge → return → repair → continue | APPROVED | implemented |
| HS-05 | Thermal model: engine + solar heat vs. Newtonian cooling × radiator condition × airflow | EXPLORING | values in `data/tuning.json` |
| HS-06 | Shielding trade-off as radiator **shutters**: open = full airflow but sand abrasion while moving; closed = protected but 45 % airflow | EXPLORING | dunes ×22 abrasion |
| HS-07 | Overheat consequence: engine shutdown until < 90 °C + radiator heat damage above 115 °C | EXPLORING | |
| HS-08 | Suit: ~70 s in open sun, slower in shade; recovers in a mech below 105 °C | EXPLORING | |
| HS-09 | Suit failure: strain → collapse → wake in the cockpit at 25 %, pack dropped where you fell (persistent) | EXPLORING | no permadeath yet |
| HS-10 | One repair resource: radiator core (+55 % condition, 3 s on foot) | EXPLORING | two in the first location |
| HS-11 | Zones: shade (shelter), dunes (abrasive, slow), salt pan (reflective, hotter) | EXPLORING | |
| HS-12 | Tank-style mech controls (W/S throttle, A/D turn); 8-way walking on foot | SUPERSEDED | car controls (TB-03); walking unchanged |
| HS-13 | Dirty Ink Wasteland visual direction (Red Thaw DNA, desert palette, `desertize()`) | EXPLORING | creator review pending |
| HS-14 | Working title "Heat Signature" | SUPERSEDED | renamed to Thawborn (TB-01) |
| HS-21 | First hostile: one weak "scrapper" mech, patrol → detect → engage → disengage, telegraphed slow shots | EXPLORING | values in `tuning.json` `enemy`, `combat` |
| HS-22 | Detection grows with the target mech's heat ("heat signature") | EXPLORING | enemy ignores pilots on foot |
| HS-23 | Two damage categories: structural integrity + cooling system (hit area = the illustrated radiator) | EXPLORING | no limbs, no armour penetration |
| HS-24 | Heat impairs movement (−50 % at critical) for every mech; firing adds heat | EXPLORING | |
| HS-25 | Enemy disabled at 0 integrity, or with destroyed cooling at critical heat → persistent wreck | EXPLORING | |
| HS-26 | Wreck salvage on foot: 3.5 s, once per wreck, 4 scrap + 1 radiator core | EXPLORING | |
| HS-27 | Scrap patches the hull (2 → +35); free slow emergency patch to 25 % when crippled | EXPLORING | loss is always recoverable |
| HS-28 | Shade zones aligned with each roof's cast shadow; second shade (salt-works awning) near the encounter | EXPLORING | |
| HS-29 | Mouse aim + left click / Space fire; turret rotates independently of the legs | EXPLORING | |
| HS-30 | Rotating upper housing (follows the mouse, rate-limited 5.5 rad/s) with twin side guns, alternating barrels | EXPLORING | chassis movement independent |
| HS-31 | Canyon Refuge: road down a rock canyon, around a bend, under an overhang into a cavern base | EXPLORING | first player base, no upgrades yet |
| HS-32 | Overhead covers fade to outline-only while the player is under them (reusable caves/tunnels/roofs) | EXPLORING | |
| HS-33 | Refuge thermal: ambient 34 °C, no sun, ×1.3 cooling, suit ×0.12; canyon is intermediate | EXPLORING | no auto-repair |
| HS-34 | Workshop (walkable, sliding door), generator + cables + 5 powered lamps | EXPLORING | no interior gameplay |
| HS-35 | Theme "Where the Ice Once Lay" on the menu; occasional exploration cue; silence by default | APPROVED | creator-provided |
| HS-36 | Parked-mech encounter: UNPILOTED → ALERTED → BOARDING → STARTING → ACTIVE → DISABLED | EXPLORING | loads resolve forward |
| HS-37 | Heavy-weapon feel: spring-damped gun + housing recoil (visual only), big muzzle flash, smoke, ground blast, camera shake, layered shot audio | EXPLORING | damage unchanged in spirit |
| HS-38 | Weather: CLEAR / SANDSTORM; gradual build-up; cooling −40 %, suit ×1.9, visibility −45 % at full storm; shelters cut exposure | EXPLORING | dev-controllable |
| HS-39 | F10 developer menu (weather, spawns, aggression, repair, invulnerability, speed, teleports, reset) — never saved | APPROVED | |
| HS-40 | Expanded desert: cooling station, scrap field, rocky ravine, highway rest stop, Junker territory | EXPLORING | handcrafted, one location file |
| HS-41 | Southern Junkers faction identity: oxide orange + tar black, bone stencilled cog-and-south-chevron insignia, welded scrap | EXPLORING | no reputation/dialogue |
| HS-42 | Junker main base: walls with gate + two breaches, workshop, sheds, stacks, wrecks, cooler, generator, tarps, burn barrels, lamps | EXPLORING | no interiors / trading |
| HS-43 | 5 perimeter turrets (easy), max 2 engage at once, LOS, telegraph, destructible + salvageable, persistent | EXPLORING | |
| HS-44 | 3 Junker defenders (yard patrol, gate guard, parked mech with pilot boarding); type stats + 0.7 damage | EXPLORING | no endless spawns |
| HS-45 | Named area discovery notices | EXPLORING | |
| HS-46 | Movement & heat rebalance: 245 px/s, fast accel/turning; weight via hull squat/lean, footfall thump, recoil. Start radiator 55 %; ordinary travel never warns; pressure stacks from combat, hot regions, storms, damage (≥8 s warning before critical) | EXPLORING | `tools/heat_balance.py` |
| **TB-01** | **Thawborn conversion**: Heat Signature becomes THAWBORN — open-world vehicular hunting/survival (cars × monster hunting): prepare → drive out → track → survive a mobile hunt → harvest → return → upgrade the car | EXPLORING | branch `iteration/thawborn-conversion`; title provisional until creator review |
| TB-02 | Revelation: the retreating ice exposed living species with their own ecosystem and habits | EXPLORING | creature designs are prototypes, not lore |
| TB-03 | The player's mech is replaced by a car (transport, weapon, protection, storage, identity). Top-down car physics: grip/slip, speed-dependent steering, reverse steers inverted, handbrake drift, crash damage | EXPLORING | `tuning.json` `mech` (legacy key = the car) |
| TB-04 | Roof gun ring with twin guns (mouse aim, recoil, layered sound) kept from the mech | EXPLORING | |
| TB-05 | Enemy mechs become human-operated rival cars (scrappers, Southern Junkers): chase, circle-strafe, roof gunner with telegraphed shots, retreat/escape, salvageable wreck | EXPLORING | same IDs as before |
| TB-06 | Parked-mech boarding → a driver runs to their parked car, gets in, engine starts | EXPLORING | |
| TB-07 | Skirr — small pack hunter: hears engines, circles, crouch tell → lunge → bite; breaks off when hurt / half the pack is down | EXPLORING | |
| TB-08 | Grindback — armoured burrower: senses vibration (speed), tunnels at you (racing sand mound = tell), erupts, paws (tell) → straight charge → dazed with the rear vent exposed; armoured front plate (breakable) | EXPLORING | |
| TB-09 | Rimeback — large quarry: grazes a long route leaving deep tracks; roar → charge lane / tail sweep arc / brine spit (glowing glands); breakable horn, two glands, tail; enrages at 55 %, limps to its lair at 30 % (blood trail), turns to fight when cornered | EXPLORING | respawns after 15 min |
| TB-10 | Detection by sight + engine noise (speed, gunfire) + heat; storms muffle sound and cut visibility | EXPLORING | |
| TB-11 | Tracks: every species leaves prints (furrows for the grindback), fading with age; blood-marked when wounded; tracking compass reads the freshest nearby sign | EXPLORING | persisted in the save |
| TB-12 | Physical ground loot with rarities (bone common · straw uncommon · bronze rare · temper-violet legendary + star + sound); the car scoops loot rolling slowly over it; cargo limit | EXPLORING | |
| TB-13 | Harvest a large carcass on foot (heat suit) → materials drop on the sand; Thawheart (legendary) only if both frost glands were broken | EXPLORING | |
| TB-14 | Refuge garage: full repair for scrap; modules armour, cooling, tyres & traction, roof guns, cargo rig & tracker (3 levels each) | EXPLORING | costs in `tuning.json` `garage` |
| TB-15 | Save v5 (Thawborn): old Heat Signature saves migrate; legacy user folder copied (never moved) on first start | APPROVED | |
| TB-16 | Heat stays forgiving near the refuge; pressure escalates with distance (hot ground), damage, combat and storms | EXPLORING | `tools/heat_balance.py` |
| TB-17 | In-game field guide (H) + hunt panel (condition, broken parts — no health bars) | EXPLORING | |
| TB-30 | Mining, coal/iron/rare Antarctic ore, smelting/alloys, schematics, modular equipment | DEFERRED | **never implemented in this repository** (audit found no code, data or docs). Integration points: `data/items.json` (rarity, bulk), `Loot.spawn` for ore nodes, `Garage` modules for schematic-gated levels |
| TB-31 | Autonomous ore cart | DEFERRED | roadmap only; would be a rival-car-style vehicle (`Drive` + an AI brain) following the player |
| TB-32 | Minimap / full map with POIs | DEFERRED | not implemented before the conversion; areas + teleports in the location file are the data a map would read. The objective pointer and tracking compass cover navigation for now |
| TB-33 | Further species, cities, quests, networking, full mining economy | DEFERRED | scope guard |
| HS-15 | Multiplayer | DEFERRED | not approved; must be host-authoritative if ever added |
| HS-16 | Antarctic research station on the world map | DEFERRED | do not build yet |
| HS-17 | Western-style towns, trade economy, factions, NPCs | DEFERRED | |
| HS-18 | Enemy combat, other scrap-mech operators | DEFERRED | |
| HS-19 | Procedural world generation, large maps | DEFERRED | |
| HS-20 | Extensive crafting, mech construction, multiple mechs, progression | DEFERRED | |
