# THAWBORN

A gritty, top-down **vehicular hunting adventure** for Godot 4.7.2, set in a transformed Antarctic
desert. A lone **Jäger** drives a battered Eisenwolf hunting car across a dangerous continent, hunts
enormous creatures, sells what they recover, upgrades the car — and carries a mysterious piece of
technology, **Kern-7**, to the distant industrial city of **Stahlheim**.

## The campaign — the Kern-7 crossing
- **Act I — The Hunter.** Ersthafen, on the old arrival coast. Greta the mechanic gets you started;
  take contracts, hunt in the Taubecken and on the Wrackküste, sell your drops. Then a burning car
  rolls up to the east gate, and its dying driver hands you an Eisenwolf case: *KERN-7 — NUR FÜR
  STAHLHEIM. Don't activate it.* Mika Voss, a veteran Jäger, wants to see you bring down the Alter
  Eisback first.
- **Act II — The Crossing.** The Rostmark (Grauwacht, where the trader Oskar knows who is asking
  about your case), the Southern Junkers' Schrottgrund, the Dornpass canyons, Eisenfurt's engineers,
  and the research station in the Glaswüste where you learn what Kern-7 really is.
- **Act III — The Last Road.** The Stahlheim approach: Frostgrund and the collapsed Hochstraße, where
  the creature migration is coming down the highway.
- **The finale.** Deliver Kern-7, drive back out, restart the three transmitter masts under the
  migration, and bring down **Kaltvater**, the apex leading it. Then the ending, the credits, and the
  open world: keep hunting, finish contracts, chase the apexes.

## The loop
**PREPARE → TRAVEL → TRACK → HUNT → RECOVER → RETURN → IMPROVE.** In a settlement's Eisenwolf
garage (**G**): repair, refuel, restock ammunition, sell drops (Markt), take contracts (Aufträge),
buy upgrades (13 lines), weapons and chassis (Waffen & Wagen), store cargo (Lager). Out there: follow
tracks (compass, bottom left), investigate blinking anomalies on the minimap, fight or flee. A
breakdown is never the end: **Esc → Call recovery truck** tows you to the last settlement for a fee
and part of your cargo — never Kern-7.

- **Continent:** 16 locations in 5 regions (Ersthafener Küste, Rostmark, Dornpass, Glaswüste,
  Stahlheim-Anflug); 5 settlements, 10 hunting territories, Stahlheim. **M** opens the route map.
- **Creatures:** Skirr, Aschenläufer, Wühler (grindback), Dornmaul, Eisback, Glutkriecher; apexes
  Alter Eisback, Dornkönig, Glutmutter and Kaltvater. Every attack is telegraphed in the world.
- **Weapons:** Hagel twin MG, Streuer flak, Hammer 30 autocannon, Weitblick precision cannon,
  Sprengwerfer launcher (keys 1–5, Q cycles). **Chassis:** Eisenwolf Marder, Krähe Falke, Eisenwolf Bär.
- **Difficulty:** Wanderer / Jäger / Veteran, chosen at new game.
- **Day and night:** one day is 40 minutes; nights are cold and dark (headlights), and skirr packs hunt
  better in the dark. Fitted upgrades show on the car and change its engine note. **H** shows the field
  guide with your hunting record.

## Play it on Windows
- **Installer / ZIP:** see [`dist/README.md`](dist/README.md); every push to an iteration branch also
  builds both on GitHub Actions (*Windows build* workflow → artifacts).
- **From source:** GitHub → branch → Code → Download ZIP → extract → open `project.godot` in
  **Godot 4.7.2** (standard) → F5. Details: [`docs/guides/TESTING_AND_LAUNCH.md`](docs/guides/TESTING_AND_LAUNCH.md).

## Controls (remappable in Settings) — **H** shows the field guide
| In the car | On foot |
|---|---|
| W/S throttle · A/D steer (only while rolling) · Shift handbrake drift | WASD walk (the heat suit drains) |
| Mouse aims the roof weapon, left click/Space fires · 1–5 / Q weapons | E get in · harvest · pick up · search |
| E get out (when stopped) · restart a mast · confirm a leave prompt | R repair radiator / patch the body |
| G garage · M continental map · R grille shutters · Esc pause (recovery, save) | |
| F5 quick save · F3 overlay · F10 developer menu | |

## Docs
- [Complete-game plan & status](docs/COMPLETE_GAME_PLAN.md) · [Design register](docs/DESIGN_REGISTER.md)
- [Architecture](docs/guides/ARCHITECTURE.md) · [Script guide EN](docs/guides/SCRIPT_GUIDE_EN.md) · [DA](docs/guides/SCRIPT_GUIDE_DA.md)
- [Art & audio replacement](docs/guides/ASSET_REPLACEMENT.md) · [Testing & launch](docs/guides/TESTING_AND_LAUNCH.md)
- [Visual direction](docs/VISUAL_DIRECTION.md) · [Audio](docs/AUDIO.md) · [Engineering lessons](docs/ENGINEERING_LESSONS.md)

*`index.html` and `style.css` belong to an earlier, unrelated "Iron Siege" web prototype that was already
in this repository. Godot ignores them, and they have been left untouched.*
