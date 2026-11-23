# Thawborn — Windows build (1.0.0-rc1: the complete game, release candidate)

- `Thawborn-1.0.0-rc1-setup.exe` is the per-user installer (no admin rights). It installs to
  `%LOCALAPPDATA%\Programs\Thawborn` and adds Start-menu and desktop shortcuts and an uninstaller.
  SHA-256: `87c464e640e560579d36ea8f59d724eecf47a6934f6c1f770efbe41481948488`
- The portable ZIP (unzip, run `Thawborn/Thawborn.exe`) is built by GitHub Actions on every push to the
  branch: Actions → *Windows build* → the run's artifacts **Thawborn-windows-zip** and
  **Thawborn-windows-installer**. Local build of this commit: ZIP SHA-256 `f8767b6a0cfecf7ae09e671fd816f7ed374958f04f513a88241b4c8401b9562e`.
- Built from branch `iteration/complete-game` with `python3 tools/build_windows.py` (Godot 4.7.2).
- Verified: the export completes locally and on GitHub Actions; the exported `.pck` runs in Godot 4.7.2
  on Linux (new game in Ersthafen, story card, driving, travel, save) with the creator's menu prints and
  logo resolving.
- **Not verified:** the installer and the `.exe` have not been launched on Windows; no Windows or Wine
  was available in the build environment.
