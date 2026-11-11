# THAWBORN *(formerly "Heat Signature"; title provisional)*

A straight top-down, open-world **vehicular hunting/survival** game for Godot 4.7.2 — cars × monster
hunting in the scorched, thawed Antarctic wasteland. The retreating ice exposed living species nobody
knew existed. Your car is your transport, weapon, protection, storage and identity.

**The loop:** prepare in the canyon refuge → drive out → find and follow tracks → survive a mobile hunt →
break parts, bring it down → get out and harvest → load the loot → return → repair and upgrade the car.

**First hunt:** leave the canyon refuge by the dirt road, go south past the old highway into the
**Thaw Flats**. A **rimeback** grazes there on a long circuit, leaving deep tracks. The tracking compass
(bottom left) points along the freshest sign. It telegraphs every attack. When it lowers its horned
head, a charge lane appears, so steer out of it. A swinging tail warns of a sweep, and glowing glands
warn of spit. Break its frost glands, horn and tail for rare materials. Badly hurt, it limps to its
lair, bleeding. Bring it down, get out, harvest it, drive slowly over the materials to load them, and
take them to the **refuge garage (G)**.

**Also out there:** **skirr** packs (they hear engines; they crouch before they lunge),
**grindbacks** (buried, they feel vibration; a racing sand mound means one is coming up under you;
shoot the rear vent while it is dazed), hostile **rival cars** (scrappers and the Southern Junkers'
fortified scrapyard with perimeter turrets), and **sandstorms**. **F10** opens the developer menu.

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
| E get out (when stopped) · **G garage** (in the refuge bay) | E get in / harvest a carcass / pick up loot / strip a wreck |
| R open/close the grille shutters | R repair radiator (core) / patch the body (scrap, or a slow free emergency patch) |
| Mouse wheel or +/− zoom · F5 quick save · Esc pause · F3 dev overlay · H field guide | |

## Docs
- [Architecture](docs/guides/ARCHITECTURE.md) · [Script guide EN](docs/guides/SCRIPT_GUIDE_EN.md) · [Script guide DA](docs/guides/SCRIPT_GUIDE_DA.md)
- [Art & audio replacement](docs/guides/ASSET_REPLACEMENT.md) · [Testing & launch](docs/guides/TESTING_AND_LAUNCH.md)
- [Visual direction](docs/VISUAL_DIRECTION.md) · [Design register](docs/DESIGN_REGISTER.md)
- [Engineering lessons](docs/ENGINEERING_LESSONS.md) · [Regression checklist](docs/REGRESSION_CHECKLIST.md)

*`index.html` and `style.css` belong to an earlier, unrelated "Iron Siege" web prototype that was already in
this repository. Godot ignores them, and they have been left untouched.*
