# Heat Signature *(provisional working title)*

A straight top-down, post-apocalyptic mech survival game for Godot 4.7.2. Former Antarctica is now a
desert hotter than Death Valley ever was. Your battered scrap mech is your shelter, your storage and your
life support, and its greatest enemy is heat.

**First playable loop:** drive → overheat → stop → exit → scavenge → return → repair → continue.

**Canyon Refuge:** follow the worn road west from the start shelter, down the canyon and around the
bend, until you pass under the overhang. The cavern base has a parking bay, a walk-in workshop, a running
generator and powered lamps. It's cool enough to work on foot. North of the pump-rig area, a
survivor stands beside a parked scrapper. Get close and they run for it, climb in and power up.

**First hostile encounter:** a weak scrapper mech patrols the salt pan in the south-east. Shoot its exposed
rear radiator to cook it, retreat to the awning's shade when you run hot, then strip its wreck on foot.

## Run it (Windows)
1. On GitHub, open the branch you want and choose **Code → Download ZIP**. Extract it.
2. Start **Godot 4.7.2** (standard, not .NET), choose **Import**, and pick `project.godot`.
3. Press **F5** (Run Project). The first open imports assets, which takes a few seconds.

More detail: [`docs/guides/TESTING_AND_LAUNCH.md`](docs/guides/TESTING_AND_LAUNCH.md).

## Controls (remappable in Settings)
| In the mech | On foot |
|---|---|
| W/S throttle, A/D turn | WASD walk |
| Mouse turns the **upper housing**; **left click** (or Space) fires the twin guns | |
| E exit (when stopped) | E salvage / enter mech / pick up |
| R open/close radiator shutters | R repair radiator (core) / patch hull (2 scrap, or a slow free emergency patch) |
| Mouse wheel or +/− zoom · F5 quick save · Esc pause · F3 dev overlay | |

## Docs
- [Architecture](docs/guides/ARCHITECTURE.md) · [Script guide EN](docs/guides/SCRIPT_GUIDE_EN.md) · [Script guide DA](docs/guides/SCRIPT_GUIDE_DA.md)
- [Art & audio replacement](docs/guides/ASSET_REPLACEMENT.md) · [Testing & launch](docs/guides/TESTING_AND_LAUNCH.md)
- [Visual direction](docs/VISUAL_DIRECTION.md) · [Design register](docs/DESIGN_REGISTER.md)
- [Engineering lessons](docs/ENGINEERING_LESSONS.md) · [Regression checklist](docs/REGRESSION_CHECKLIST.md)

*`index.html` and `style.css` belong to an earlier, unrelated "Iron Siege" web prototype that was already in
this repository. Godot ignores them, and they have been left untouched.*
