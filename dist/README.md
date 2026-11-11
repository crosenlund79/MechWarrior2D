# Thawborn — Windows build

- `Thawborn-0.2.0-setup.exe` is the per-user installer (no admin rights). It installs to
  `%LOCALAPPDATA%\Programs\Thawborn` and adds Start-menu and desktop shortcuts and an uninstaller.
  SHA-256: `b5d2b987f9eddbf3e22abfb0faeb072464993bb81ba8085378850dc67f491ba8`
- Built from branch `iteration/thawborn-conversion` with `python3 tools/build_windows.py`. The same
  command also writes a portable zip to `export/`.
- Verified: the Godot export completes, and the exported `.pck` runs in Godot 4.7.2 (new game, driving,
  save) with all Thawborn assets resolving.
- **Not verified:** the installer and the `.exe` have not been run on Windows yet. The build machine
  had no Windows or Wine.
