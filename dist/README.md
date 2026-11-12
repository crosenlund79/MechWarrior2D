# Thawborn — Windows build (0.3.0: the Continental Journey)

- `Thawborn-0.3.0-setup.exe` is the per-user installer (no admin rights). It installs to
  `%LOCALAPPDATA%\Programs\Thawborn` and adds Start-menu and desktop shortcuts and an uninstaller.
  SHA-256: `2618aa387afc96f41d9865db6c4253887de51f499d760db41e6735238c70d643`
- Built from branch `iteration/continental-journey` with `python3 tools/build_windows.py`. The same
  command also writes a portable zip to `export/`.
- Verified: the Godot export completes, and the exported `.pck` runs in Godot 4.7.2 on Linux (new game in
  Ersthafen, driving, travel to Taubecken, save), with the creator's menu prints and logo resolving.
- **Not verified:** the installer and the `.exe` have not been run on Windows yet. The build machine
  had no Windows or Wine.
