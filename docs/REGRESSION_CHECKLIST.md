# Regression checklist (short)

Automated (run before every push):
- [ ] `godot --headless --path . --import` — no script errors
- [ ] `godot --headless --path . res://tests/run_tests.tscn -- --instance=unit_tests` — 0 failed
- [ ] `python3 tools/regression.py` — PASS
- [ ] `python3 tools/check_script_guides.py` — OK

Manual (Windows, ~5 min):
- [ ] Clean start from a fresh ZIP; main menu appears; no errors in the Output panel
- [ ] New game → drive; walls/rocks block the mech; camera follows; wheel zoom works
- [ ] Temperature rises when driving, falls when parked; shutdown at ~115 °C with steam + alarm
- [ ] Exit only when stopped; suit timer counts down; HUD warns at 50/25/10 %
- [ ] Salvage at the pump rig; repair at the mech with R; cooling bar jumps
- [ ] Shutters: R in mech; HUD shows closed; temperature settles higher
- [ ] Walk under the shelter roof: roof fades; HUD shows Shade
- [ ] Let the suit run out: collapse → wake in cockpit; pack marker where you fell; pick it up
- [ ] Quit → restart Godot → Continue: position, salvage, repair, drops intact
- [ ] Settings persist (volume, window mode, UI scale, a rebound key) after restart
- [ ] Drop a PNG into `%APPDATA%\HeatSignature\overrides\mechs\starter\hull.png` → Reload art → visible;
      delete it → Reload → template returns
- [ ] 21:9 window: HUD anchored, nothing stretched
