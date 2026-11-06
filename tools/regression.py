#!/usr/bin/env python3
"""Baseline runtime regression: plays the first loop in a REAL game process,
restarts Godot to verify persistence, and checks art/sound override + fallback
and settings persistence. Headless by default (set HS_WINDOWED=1 to watch).

  python3 tools/regression.py          exit code 0 = pass
"""
import os, sys, json, struct, zlib
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hs_driver import Instance, USER_DIR

HEADLESS = os.environ.get("HS_WINDOWED") != "1"
fails = []


def check(cond, what):
    print(("  ok   " if cond else "  FAIL ") + what)
    if not cond:
        fails.append(what)


def tiny_png(path, rgb=(0, 255, 0), size=24):
    raw = b"".join(b"\x00" + bytes(rgb) * size for _ in range(size))
    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    data = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b"")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "wb").write(data)


g = Instance("regression", headless=HEADLESS)
g.wipe()
g.start()
try:
    print("1. new game, drive, overheat")
    s = g.cmd("new 1")["state"]
    check(s["running"] and s["game"]["mode"] == "mech", "new game starts in the mech")
    m0 = s["game"]["mech"]
    r = g.cmd("drive_to 1500 1160 30")
    check(r["ok"], "mech drives along the track (collision-free route)")
    pos = r["state"]["game"]["mech"]["pos"]
    check(abs(pos[0] - m0["pos"][0]) > 300, "mech moved")
    heat_after_drive = r["state"]["game"]["mech"]["heat"]
    check(heat_after_drive > m0["heat"], f"driving heats the core ({m0['heat']:.1f} → {heat_after_drive:.1f})")
    r = g.cmd("drive_to 2520 1100 40")
    check(r["ok"], "mech reaches the wreck site")
    # Keep the engine working hard (tight circles) until the damaged radiator gives out.
    for k in range(20):
        if k >= 6:   # heat impairment slows a hot mech; firing the guns pushes it over the edge
            m = g.state()["game"]["mech"]["pos"]
            g.cmd(f"aim {m[0]} {m[1] - 400}")
            st = g.cmd("fire_for 2")["state"]
        st = g.cmd("drive 1 1 3")["state"]
        if st["game"]["stats"]["overheats"] > 0:
            break
    check(st["game"]["stats"]["overheats"] > 0 and st["game"]["mech"]["engine"] == "shutdown",
          f"damaged radiator overheats → engine shutdown (heat {st['game']['mech']['heat']:.1f})")
    st = g.cmd("drive 1 0 2")["state"]
    check(abs(st["game"]["mech"]["speed"]) < 3, "shut-down mech cannot drive")
    print("2. stop, exit, scavenge")
    g.cmd("stop")
    r = g.cmd("interact")
    check(r["ok"] and r["state"]["game"]["mode"] == "foot", "exit the parked mech")
    check(r["state"]["game"]["mech"]["engine"] in ("off", "shutdown"), "parked engine is off")
    suit0 = r["state"]["game"]["pilot"]["suit"]
    p = r["state"]["game"]["pilot"]["pos"]
    r = g.cmd(f"walk_to {p[0]} 1210 10")
    r = g.cmd("walk_to 2760 1210 20")
    r = g.cmd("walk_to 2760 1092 20")
    check(r["ok"], "walk to salvage")
    r = g.cmd("interact"); g.cmd("wait_task")
    st = g.state()
    check(st["game"]["pilot"]["pack"].get("radiator_core", 0) == 1, "radiator core in pack")
    check(st["game"]["pilot"]["suit"] < suit0, f"suit protection drains outside ({suit0:.1f} → {st['game']['pilot']['suit']:.1f})")
    print("3. return, repair, continue")
    mp = st["game"]["mech"]["pos"]
    g.cmd("walk_to 2760 1210 20")
    g.cmd(f"walk_to {mp[0]} {mp[1] + 140} 20")
    rad0 = g.state()["game"]["mech"]["radiator"]
    r = g.cmd("service"); g.cmd("wait_task")
    st = g.state()
    check(st["game"]["mech"]["radiator"] > rad0 + 0.5, f"radiator repaired ({rad0:.2f} → {st['game']['mech']['radiator']:.2f})")
    check(st["game"]["stats"]["repairs"] == 1, "repair counted")
    r = g.cmd("interact")
    check(r["state"]["game"]["mode"] == "mech", "re-enter the mech")
    g.cmd("debug timescale 8"); g.cmd("wait 6"); g.cmd("debug timescale 1")
    st = g.state()
    check(st["game"]["mech"]["engine"] == "running", "engine restarts after cooling")
    check(st["game"]["pilot"]["suit"] > 90, "suit recovered inside the mech")
    heat_before = st["game"]["mech"]["heat"]
    g.cmd("drive_to 2300 1100 25")
    st = g.state()
    check(st["game"]["mech"]["heat"] < 100, f"repaired cooling holds while driving ({heat_before:.1f} → {st['game']['mech']['heat']:.1f})")
    print("4. settings + key rebinding")
    g.cmd("setting volume_SFX 0.42")
    g.cmd("rebind interact G")
    g.cmd("setting ui_scale 1.25")
    g.cmd("stop")
    saved_state = g.cmd("save")["state"]["game"]
finally:
    g.quit()

print("5. restart Godot → continue: persistence")
ov_root = os.path.join(USER_DIR, "instances", "regression", "overrides")
tiny_png(os.path.join(ov_root, "mechs/starter/hull.png"))
open(os.path.join(ov_root, "items/radiator_core.png") if os.path.isdir(os.path.join(ov_root, "items")) else os.path.join(ov_root, "bad.png"), "w").write("garbage")
g2 = Instance("regression", headless=HEADLESS)
g2.start()
try:
    st = g2.state()
    check(st["settings"]["volume_SFX"] == 0.42 and st["settings"]["ui_scale"] == 1.25, "settings persisted across restart")
    check(st["bindings"].get("interact") is not None, "key binding persisted across restart")
    check(st["recent_slot"] == 1, "slot 1 offered for Continue")
    st = g2.cmd("continue 1")["state"]
    gm = st["game"]
    check(gm["world"]["taken"].get("salvage_pump_rig") is True, "collected salvage persisted")
    check(abs(gm["mech"]["radiator"] - saved_state["mech"]["radiator"]) < 0.01 and gm["stats"]["repairs"] == 1, "repair persisted")
    check(abs(gm["mech"]["pos"][0] - saved_state["mech"]["pos"][0]) < 2, "mech position persisted")
    print("6. art override / fallback")
    check(st["asset_sources"].get("mech.hull") == "external", "external hull override used")
    os.remove(os.path.join(ov_root, "mechs/starter/hull.png"))
    st = g2.cmd("reload_assets")["state"]
    g2.cmd("wait 0.2")
    st = g2.state()
    check(st["asset_sources"].get("mech.hull") == "template", "removing the override falls back to the template")
    print("7. on-foot suit failure consequence")
    g2.cmd("stop")
    r = g2.cmd("interact")
    check(r["state"]["game"]["mode"] == "foot", "exit after continuing")
    g2.cmd("debug give_part")
    g2.cmd("debug suit 1")
    g2.cmd("debug timescale 6"); g2.cmd("wait 5"); g2.cmd("debug timescale 1")
    st = g2.state()
    print("     ", st["game"]["mode"], st["game"]["stats"], st["notices"][-4:])
    check(st["game"]["stats"]["collapses"] == 1 and st["game"]["mode"] == "mech", "suit failure → collapse → wake in mech")
    check(len(st["game"]["world"]["drops"]) == 1, "carried salvage dropped at the collapse site")
finally:
    g2.quit()

print("\nRESULT:", "PASS" if not fails else f"FAIL ({len(fails)})")
sys.exit(1 if fails else 0)
