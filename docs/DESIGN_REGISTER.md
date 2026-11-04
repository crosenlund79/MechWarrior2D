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
| HS-12 | Tank-style mech controls (W/S throttle, A/D turn); 8-way walking on foot | EXPLORING | |
| HS-13 | Dirty Ink Wasteland visual direction (Red Thaw DNA, desert palette, `desertize()`) | EXPLORING | creator review pending |
| HS-14 | Working title "Heat Signature" | EXPLORING | provisional, not final |
| HS-15 | Multiplayer | DEFERRED | not approved; must be host-authoritative if ever added |
| HS-16 | Antarctic research station on the world map | DEFERRED | do not build yet |
| HS-17 | Western-style towns, trade economy, factions, NPCs | DEFERRED | |
| HS-18 | Enemy combat, other scrap-mech operators | DEFERRED | |
| HS-19 | Procedural world generation, large maps | DEFERRED | |
| HS-20 | Extensive crafting, mech construction, multiple mechs, progression | DEFERRED | |
