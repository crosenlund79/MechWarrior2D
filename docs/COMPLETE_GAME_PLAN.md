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
