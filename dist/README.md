# Thawborn — Windows build (0.2.1: playtest fixes 001–006)

- `Thawborn-0.2.1-setup.exe` is the per-user installer (no admin rights). It installs to
  `%LOCALAPPDATA%\Programs\Thawborn` and adds Start-menu and desktop shortcuts and an uninstaller.
  SHA-256: `ea4580eb5b0f15436b574e8b950336c011b35b737edb4e8585771e7ec7d979ad`
- Built from branch `iteration/thawborn-conversion` with `python3 tools/build_windows.py`. The same
  command also writes a portable zip to `export/`.
- Verified: the Godot export completes, and the exported `.pck` runs in Godot 4.7.2 (new game, driving,
  save) with all Thawborn assets resolving.
- **Not verified:** the installer and the `.exe` have not been run on Windows yet. The build machine
  had no Windows or Wine.
