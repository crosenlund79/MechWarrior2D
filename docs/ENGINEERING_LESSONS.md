# Engineering lessons carried over

Taken from the accessible prior-project handovers: Red Thaw / Aftergrowth
(`crosenlund79/ZombieSurvival2D`, `CLAUDE.md`, `docs/HANDOVER.md`), which itself inherited from Little
Captain's Hat (LCH). Only lessons that apply here are listed.

1. **State is data, scenes are views.** (LCH → RT.) One `Session.state` Dictionary; views rebuild from it.
2. **One owner per responsibility.** There are six autoloads in total, and none was added "just in case".
3. **Safe writes.** Use temp → read back → validate → keep `.bak` → replace. An interrupted save never
   destroys the last good one. Load falls back to `.bak` and says so.
4. **Versioned saves with migrations from day one.** It is cheaper than retrofitting. Validate
   structure, then clamp ranges.
5. **Template/override mirror for art.** The creator replaces art without touching code; art never
   decides collision (RT `apply_to_sprite`).
6. **Isolated test instances.** `--instance=<name>` keeps automated tests out of the creator's saves,
   settings and override folders. (New here: overrides are isolated too, after a test touched the
   shared folder in development.)
7. **Drive the real game.** Unit tests are not enough. The `--autotest` file channel lets Python play
   the actual loop and restart Godot to prove persistence.
8. **Refresh the class cache.** Run `godot --headless --import` after adding `class_name` scripts, or
   headless runs fail with unknown identifiers.
9. **Keep both script guides honest.** `check_script_guides.py` fails when a script is missing.
10. **Report status precisely.** Keep implemented, auto-tested, runtime-verified, Windows-verified and
    creator-accepted separate.
11. **Don't let decorative props block gameplay.** (RT nav issue.) Scatter is visual only, with no collision.
12. **Never transfer perspective-dependent settings blindly.** RT's y-sort, pivots and baked
    ellipse shadows assume 3/4. Here they became centre pivots, world-aligned runtime cast
    shadows and roof fading.
