# THAWBORN *(formerly "Heat Signature"; title provisional)*

A straight top-down, open-world **vehicular hunting/survival** game for Godot 4.7.2 — cars × monster
hunting in the scorched, thawed Antarctic wasteland. The retreating ice exposed living species nobody
knew existed. Your car is your transport, weapon, protection, storage and identity.

**The journey:** you land at **Ersthafen** carrying a sealed case that must reach **Stahlheim**, the
main hub of the frontier. The case is never sellable. Between the two lies a branching continent of
**danger territories** and walled **safe-zone settlements** (Kaltbrunn, Eisenhalt). The further you go,
the harder it gets. Press **M** for the continental map: it shows the routes, their fuel cost and what
you have discovered. Set a course, and the objective pointer leads to the right exit gate.

**The loop:** PREPARE in a settlement → HUNT in a territory → RETURN, then sell, refuel, repair and
upgrade at the **Eisenwolf Werke** workshop (**G** in the garage bay):
- **Money** comes from selling hunted drops (bone, hide, glands, salvage) at the Handelsposten.
- **Fuel** burns while driving. Refuel at the Tankstelle. An empty tank never strands you, because the
  car limps on slowly.
- **Upgrades:** eight priced lines (chassis, engine, turbo, armour, tyres, cooling, roof guns, cargo
  bed). Higher levels unlock with your **Jäger rank**, which grows with kills, harvests and discoveries.

**Territories:** the **minimap** (bottom right) shows roads, gates and blinking **anomalies**. Drive up to
one to identify it. Some are abandoned expeditions: a dead driver, a wreck that is sometimes still
burning, and sometimes loot (search once, on foot). Near a map edge the car slows. You are asked
"Leave this area?" in a settlement or "Flee this territory?" in a danger zone. Drive on past the
boundary and you leave anyway. The tape in the top right says **DANGER**, **SAFE-ZONE** or, at
Stahlheim after the delivery, **CLEARED**.

**The quarry:** the **Eisback** (rimeback) grazes the Taubecken basin on a long circuit, leaving deep
tracks. The tracking compass (bottom left) points along the freshest sign. Every attack is telegraphed:
- **Charge:** when it lowers its horned head, a charge lane appears, so steer out of it.
- **Sweep:** a swinging tail warns of a sweep.
- **Spit:** glowing glands warn of spit.

Break its frost glands, horn and tail for rare drops, bring it down, get out and harvest it, then drive
slowly over the drops to load them.

**Also out there:** **skirr** packs (they hear engines; they crouch before they lunge), **Wühler**
grindbacks (buried; a racing sand mound means one is coming up under you), hostile **rival cars**, the
Southern Junkers' fortified scrapyard, and **sandstorms**. **F10** opens the developer menu.

## Run it (Windows)
1. On GitHub, open the branch you want and choose **Code → Download ZIP**. Extract it.
2. Start **Godot 4.7.2** (standard, not .NET), choose **Import**, and pick `project.godot`.
3. Press **F5** (Run Project). The first open imports assets, which takes a few seconds.

More detail: [`docs/guides/TESTING_AND_LAUNCH.md`](docs/guides/TESTING_AND_LAUNCH.md).
Old Heat Signature saves are copied over automatically on first start (the originals are kept).

## Controls (remappable in Settings) — press **H** in game for the field guide
| In the car | On foot |
|---|---|
| W accelerate · S brake/reverse · A/D steer (only while rolling) · **Shift handbrake (drift)** | WASD walk (the heat suit drains) |
| Mouse turns the **roof guns**; **left click** (or Space) fires | |
| E get out (when stopped) · **G garage** (settlement bay) · **M continental map** · E confirms a leave prompt | E get in / harvest a carcass / pick up loot / strip a wreck |
| R open/close the grille shutters | R repair radiator (core) / patch the body (scrap, or a slow free emergency patch) |
| Mouse wheel or +/− zoom · F5 quick save · Esc pause · F3 dev overlay · H field guide | |

## Docs
- [Architecture](docs/guides/ARCHITECTURE.md) · [Script guide EN](docs/guides/SCRIPT_GUIDE_EN.md) · [Script guide DA](docs/guides/SCRIPT_GUIDE_DA.md)
- [Art & audio replacement](docs/guides/ASSET_REPLACEMENT.md) · [Testing & launch](docs/guides/TESTING_AND_LAUNCH.md)
- [Visual direction](docs/VISUAL_DIRECTION.md) · [Design register](docs/DESIGN_REGISTER.md)
- [Engineering lessons](docs/ENGINEERING_LESSONS.md) · [Regression checklist](docs/REGRESSION_CHECKLIST.md)

*`index.html` and `style.css` belong to an earlier, unrelated "Iron Siege" web prototype that was already in
this repository. Godot ignores them, and they have been left untouched.*
