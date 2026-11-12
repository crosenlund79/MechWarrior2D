#!/usr/bin/env python3
"""Runtime regression for playtest fixes 001–006 (real game process, WINDOWED so
the mouse cursor can be checked — run under a display or xvfb-run):
  001/003 reverse steering gentle + controllable at low and high speed
  002     starter-area driving stays comfortable; escalation still exists
  004     the cursor is visible in the garage (and pause menu), purchases + close work
  005     unload cargo into persistent garage storage; no duplication; save/load
  006     player bullets ~2x faster, still hit; enemy slugs unchanged
  xvfb-run -a -s "-screen 0 2600x1200x24" python3 tools/regression_playtest.py     exit 0 = pass"""
import os, sys, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hs_driver import Instance

fails = []


def check(cond, what):
    print(("  ok   " if cond else "  FAIL ") + what)
    if not cond:
        fails.append(what)


def ang(a, b):
    return abs((b - a + math.pi) % (2 * math.pi) - math.pi)


g = Instance("playtest", headless=False, extra_args=["--rendering-driver", "opengl3"])
g.wipe(); g.start()
try:
    g.cmd("window 1600 900"); g.cmd("setting show_tutorial false")
    g.cmd("new 1 taubecken"); g.cmd("dev toggle aggression")

    print("1. reverse steering (001/003)")
    g.cmd("set_mech 300 2100 90"); g.cmd("wait 0.3")
    h0 = g.state()["game"]["mech"]["heading"]
    st = g.cmd("drive 0.5 1 1.0")["state"]
    fwd_turn = ang(h0, st["game"]["mech"]["heading"])
    g.cmd("stop"); g.cmd("set_mech 300 2100 90"); g.cmd("wait 0.3")
    g.cmd("drive -1 0 0.8")                       # back up to speed first
    st = g.state(); h1 = st["game"]["mech"]["heading"]; v1 = st["game"]["mech"]["speed"]
    st = g.cmd("drive -1 1 1.0")["state"]          # full lock while reversing fast
    rev_turn = ang(h1, st["game"]["mech"]["heading"])
    check(v1 < -100, f"the car reverses at speed ({v1:.0f} px/s)")
    check(rev_turn < fwd_turn * 0.6, f"reversing turns much less than driving forward ({math.degrees(rev_turn):.0f}° vs {math.degrees(fwd_turn):.0f}° in 1 s)")
    check(math.degrees(rev_turn) < 75, f"no abrupt spin when reversing fast at full lock ({math.degrees(rev_turn):.0f}°/s)")
    check(st["game"]["mech"]["slip"] < 200, f"no slide-out while reversing ({st['game']['mech']['slip']:.0f})")
    g.cmd("stop"); g.cmd("set_mech 300 2100 90"); g.cmd("wait 0.3")
    st = g.cmd("drive -0.4 1 1.5")["state"]
    check(0.15 < ang(h0, st["game"]["mech"]["heading"]) < 1.6, "slow reversing still steers for parking")
    g.cmd("stop"); g.cmd("set_mech 300 2100 90"); g.cmd("wait 0.3")
    g.cmd("drive 1 0 1.4"); g.cmd("handbrake 1"); st = g.cmd("drive 1 1 0.6")["state"]; g.cmd("handbrake 0")
    check(st["game"]["mech"]["slip"] > 120, f"forward handbrake drift unchanged (slip {st['game']['mech']['slip']:.0f})")

    print("2. starter-area heat (002)")
    g.cmd("dev teleport refuge"); g.cmd("debug heat 0"); g.cmd("wait 0.3")
    peak = 0.0
    for x, y in [(-1400, 1250), (-900, 1480), (-200, 1520), (560, 1480), (700, 2200), (300, 2400), (700, 2200), (560, 1480), (-200, 1520), (-900, 1480), (-1400, 1250)]:
        st = g.cmd(f"drive_to {x} {y} 35")["state"]
        peak = max(peak, st["game"]["mech"]["heat"])
    check(peak < 83, f"a round trip from the refuge stays out of the warm band ({peak:.0f} °C)")
    check(st["game"]["stats"]["overheats"] == 0, "no overheat near the refuge")
    g.cmd("set_mech 300 2100 90"); g.cmd("dev weather start 1.0"); g.cmd("wait 9")
    m = g.state()["game"]["mech"]
    g.cmd(f"debug damage {m['radiator'] - 0.25:.4f}"); g.cmd(f"debug heat {70 - m['heat']:.1f}"); g.cmd("aim 300 1600")
    hot = 0.0
    for k in range(12):
        hot = max(hot, g.cmd("fire_for 2")["state"]["game"]["mech"]["heat"])
    check(hot >= 95, f"storm + damaged cooling + sustained fire still reaches the warning ({hot:.0f} °C)")
    g.cmd("dev weather clear"); g.cmd("dev repair")

    print("3. projectiles (006)")
    g.cmd("set_mech 300 2100 0"); g.cmd("aim 300 1500"); g.cmd("wait 0.4")
    st = g.cmd("fire_for 0.35")["state"]
    sp = st["player_projectile_speeds"]
    check(bool(sp) and min(sp) >= 1150, f"player rounds fly ~2x faster ({[round(v) for v in sp]} px/s, was 620)")
    g.cmd("spawn_creature skirr 1"); g.cmd("wait 0.1")
    st = g.state(); cid = [k for k in st["game"]["creatures"] if k.startswith("dev_skirr")][0]
    g.cmd(f"set_creature 300 1650 roam cid={cid}"); hp0 = g.state()["game"]["creatures"][cid]["hp"]
    g.cmd(f"fire_at_creature 1.5 body cid={cid}")
    c = g.state()["game"]["creatures"][cid]
    check(c["hp"] < hp0 or c["ai"] == "dead", f"fast rounds still hit a small target ({hp0:.0f} → {c['hp']:.0f}, {c['ai']})")
    g.cmd("dev clear")

    print("4. garage cursor (004) and 5. storage (005)")
    g.cmd("travel ersthafen force"); g.cmd("devx money 2000"); g.cmd("give_materials")
    gp = g.state()["game"]["mech"]["pos"]
    g.cmd("dev teleport garage"); g.cmd("wait 0.5")
    st = g.state()
    check(not st["mouse_visible"], "while driving the system cursor is hidden (reticle)")
    g.cmd("ui garage on"); g.cmd("wait 0.4")
    st = g.state()
    check(st["garage_open"] and st["paused"], "the garage opens and pauses the game")
    check(st["mouse_visible"], "the mouse cursor is visible in the garage")
    carried = dict(st["game"]["mech"]["storage"])
    g.cmd("click_garage Tab_storage"); g.cmd("wait 0.2")
    r = g.cmd("click_garage Unload"); g.cmd("wait 0.2")
    st = g.state()
    check(r["ok"] and not st["game"]["mech"]["storage"], "Unload cargo empties the car")
    check(all(st["garage_storage"].get(k, 0) >= v for k, v in carried.items()), "everything arrived in the garage store")
    store1 = dict(st["garage_storage"])
    r2 = g.cmd("click_garage Unload")
    check(not r2["ok"], "the Unload button is disabled once the car is empty (no repeat)")
    m0 = g.state()["money"]
    g.cmd("click_garage Tab_upgrades"); g.cmd("wait 0.2")
    r = g.cmd("click_garage Fit_armor"); g.cmd("wait 0.2")
    st = g.state()
    check(r["ok"] and st["game"]["mech"]["upgrades"].get("armor") == 1, "buying an upgrade with the mouse works")
    check(st["money"] < m0, f"it was paid in Mark ({m0} → {st['money']})")
    g.cmd("click_garage Tab_market"); g.cmd("wait 0.2")
    r = g.cmd("click_garage SellAll_rime_hide"); g.cmd("wait 0.2")
    st = g.state()
    check(r["ok"] and st["garage_storage"].get("rime_hide", 0) == 0 and st["money"] > m0 - 300, "stored loot sells from the market tab")
    r = g.cmd("click_garage Close"); g.cmd("wait 0.4")
    st = g.state()
    check(not st["garage_open"] and not st["paused"], "closing the panel resumes the game")
    check(not st["mouse_visible"], "the reticle takes over again after closing")
    g.cmd("ui pause on"); g.cmd("wait 0.3")
    check(g.state()["mouse_visible"], "the pause menu also shows the cursor")
    g.cmd("ui pause off"); g.cmd("wait 0.3")
    store2 = dict(g.state()["garage_storage"])
    g.cmd("save")
    g.quit(); g.start()
    st = g.cmd("continue 1")["state"]
    check(st["garage_storage"] == store2, "the garage store survives save + restart")
    check(st["game"]["mech"]["upgrades"].get("armor") == 1, "the bought module persisted")
    g.cmd("set_mech 300 300 90")
    check(not g.cmd("unload")["ok"], "no unloading out in the field")
finally:
    g.quit()
print("\nRESULT:", "PASS" if not fails else f"FAIL ({len(fails)})")
sys.exit(1 if fails else 0)
