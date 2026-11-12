#!/usr/bin/env python3
"""Runtime regression for movement + heat balance (real game process).
Fast, responsive mech; ordinary travel sustainable; heat pressure builds through
combat, hot regions, storms and damage, always with a warning first; shade/refuge
recovery; early Junker skirmish without constant overheating.
  python3 tools/regression_balance.py      exit 0 = pass"""
import os, sys, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hs_driver import Instance

HEADLESS = os.environ.get("HS_WINDOWED") != "1"
fails = []
WARN, CRIT = 95.0, 115.0


def check(cond, what):
    print(("  ok   " if cond else "  FAIL ") + what)
    if not cond:
        fails.append(what)


def heat(g):
    return g.state()["game"]["mech"]["heat"]


g = Instance("balance", headless=HEADLESS)
g.wipe(); g.start()
try:
    g.cmd("new 1 taubecken"); g.cmd("dev toggle aggression")
    print("1. speed and responsiveness")
    g.cmd("set_mech 300 2100 90"); g.cmd("wait 0.3")
    top, t90 = 0.0, None
    for k in range(20):
        st = g.cmd("drive 1 0 0.1")["state"]
        v = st["game"]["mech"]["speed"]; top = max(top, v)
        if t90 is None and v >= 0.9 * 460: t90 = (k + 1) * 0.1
    st = g.cmd("drive 1 0 1.0")["state"]; top = max(top, st["game"]["mech"]["speed"])
    check(top >= 420, f"car top speed ({top:.0f} px/s; the mech did 245)")
    check(t90 is not None and t90 <= 1.3, f"reaches 90 % speed quickly ({t90} s)")
    h0 = st["game"]["mech"]["heading"]
    st = g.cmd("drive 0.3 1 1.3")["state"]
    turned = abs((st["game"]["mech"]["heading"] - h0 + math.pi) % (2 * math.pi) - math.pi)
    check(turned > 2.0, f"turns briskly ({math.degrees(turned):.0f}° in 1.3 s)")
    g.cmd("stop")
    stopped = g.state()["game"]["mech"]["speed"]
    check(abs(stopped) < 3, "brakes to a stop promptly")

    print("2. ordinary travel is sustainable (starting radiator)")
    g.cmd("new 1 taubecken"); g.cmd("dev toggle aggression")
    route = [(-1400, 1250), (-900, 1480), (-200, 1520), (560, 1480), (700, 1500), (830, 2000), (770, 2600), (660, 3100), (1000, 3430), (1600, 3420), (2400, 3330), (2900, 3520), (2400, 3330), (1600, 3420), (1000, 3430), (620, 3290)]   # around the abandoned highway cars
    peak = 0.0
    for x, y in route:
        st = g.cmd(f"drive_to {x} {y} 40")["state"]
        peak = max(peak, st["game"]["mech"]["heat"])
    st = g.state()
    check(peak < WARN, f"a long drive never reaches the warning (peak {peak:.0f} °C)")
    check(st["game"]["stats"]["overheats"] == 0, "no overheat during exploration")
    check(st["game"]["mech"]["radiator"] > 0.45, f"the radiator survives ordinary travel ({st['game']['mech']['radiator']:.2f})")
    check(st["game"]["mech"]["integrity"] > 80, f"road driving without crash damage ({st['game']['mech']['integrity']:.0f})")
    g.cmd("dev repair")

    print("3. sustained combat builds heat progressively")
    g.cmd("set_mech 300 2100 90"); g.cmd(f"debug heat {64.0 - heat(g):.2f}"); g.cmd("wait 0.3")
    g.cmd("aim 300 1600")
    samples = []
    for k in range(10):
        st = g.cmd("fire_for 3")["state"]; samples.append(st["game"]["mech"]["heat"])
    t_warn = next((i * 3 for i, h in enumerate(samples) if h >= WARN), None)
    check(samples[-1] > samples[0] + 15, f"firing builds heat ({samples[0]:.0f} → {samples[-1]:.0f} °C)")
    check(t_warn is None or t_warn >= 15, f"no early warning from firing (first warning ≈ {t_warn} s)")
    check(g.state()["game"]["stats"]["overheats"] == 0, "30 s of sustained fire with the starting radiator does not shut down")
    print("4. shade and refuge recovery")
    hot = heat(g)
    g.cmd("dev teleport refuge"); g.cmd("wait 6")
    cooled = heat(g)
    check(cooled < hot - 8, f"the refuge pulls heat down ({hot:.0f} → {cooled:.0f} °C in 6 s)")

    print("5. stacked pressure: damaged cooling + sandstorm + combat")
    # Deterministic start (earlier scenarios leave varying heat and wear): radiator 25 %, 60 °C.
    g.cmd("set_mech 300 2100 90"); g.cmd("dev weather start 1.0"); g.cmd("wait 9")
    m = g.state()["game"]["mech"]
    g.cmd(f"debug damage {float(m['radiator']) - 0.25:.4f}")
    g.cmd(f"debug heat {60.0 - float(m['heat']):.2f}"); g.cmd("wait 0.3"); g.cmd("aim 300 1600")
    warned_at, crit_at, t = None, None, 0.0
    for k in range(30):
        st = g.cmd("fire_for 2")["state"]; t += 2
        h = st["game"]["mech"]["heat"]
        if warned_at is None and (h >= WARN or "NOTICE_HEAT_WARNING" in st["notices"]):
            warned_at = t
        if st["game"]["mech"]["engine"] == "shutdown" or st["game"]["stats"]["overheats"] > 0:
            crit_at = t
            break
    check(crit_at is not None, f"heavy combined pressure does overheat (after ≈{crit_at} s)")
    check(warned_at is not None and crit_at is not None and crit_at - warned_at >= 8, f"with clear warning first (warn ≈{warned_at} s, critical ≈{crit_at} s)")
    g.cmd("dev weather clear"); g.cmd("dev teleport refuge"); g.cmd("debug timescale 4"); g.cmd("wait 8"); g.cmd("debug timescale 1")
    st = g.state()
    check(st["game"]["mech"]["engine"] == "running", "recovers and restarts in shelter")
    # The warning is actionable: same stacked setup, but cease fire on the first warning.
    g.cmd("set_mech 300 2100 90"); g.cmd("dev weather start 1.0"); g.cmd("wait 9")
    m = g.state()["game"]["mech"]
    g.cmd(f"debug damage {float(m['radiator']) - 0.25:.4f}")
    g.cmd(f"debug heat {60.0 - float(m['heat']):.2f}"); g.cmd("wait 0.3"); g.cmd("aim 300 1600")
    over0 = g.state()["game"]["stats"]["overheats"]
    for k in range(30):
        st = g.cmd("fire_for 1")["state"]
        if st["game"]["mech"]["heat"] >= WARN or "NOTICE_HEAT_WARNING" in st["notices"]:
            break
    g.cmd("wait 15")
    st = g.state()
    check(st["game"]["stats"]["overheats"] == over0 and st["game"]["mech"]["engine"] == "running",
          f"ceasing fire at the warning avoids shutdown, even in a storm with 25 % cooling ({st['game']['mech']['heat']:.0f} °C)")
    g.cmd("dev weather clear")

    print("6. damaged cooling while cruising: slow build, recoverable by easing off")
    g.cmd("dev repair"); g.cmd("debug damage 0.75"); g.cmd("set_mech 1500 2100 90"); g.cmd(f"debug heat {24.0 - heat(g):.2f}"); g.cmd("wait 0.3")
    over0 = g.state()["game"]["stats"]["overheats"]
    samples = []
    for k in range(10):
        st = g.cmd("drive 1 0.35 6")["state"]; samples.append(st["game"]["mech"]["heat"])
    check(st["game"]["stats"]["overheats"] == over0, f"a minute of cruising on a 25 % radiator does not shut down ({[round(x) for x in samples[::3]]} °C)")
    check(samples[-1] > samples[0], "but it does run warmer — damaged cooling matters")
    g.cmd("stop"); h2 = heat(g)
    check(h2 < CRIT - 15, f"a damaged radiator alone stays well short of critical ({h2:.0f} °C)")
    g.cmd("interact"); g.cmd("wait 12"); h3 = heat(g); g.cmd("interact")
    check(h3 < h2 - 1.5, f"parking with the engine off cools it down ({h2:.0f} → {h3:.0f} °C)")

    print("7. early Southern Junkers skirmish (healthy mech)")
    g.cmd("dev repair"); g.cmd("dev toggle aggression"); g.cmd("set_mech 5180 3950 180"); g.cmd("debug heat -40")
    for k in range(12):
        g.cmd("aim_enemy id=junker_gate_guard"); st = g.cmd("fire_for 2.5 body id=junker_gate_guard")["state"]
    st = g.state()
    check(st["game"]["mech"]["engine"] != "shutdown" and st["game"]["stats"]["overheats"] <= 1, f"30 s of fighting at the gate without overheating (heat {st['game']['mech']['heat']:.0f} °C)")
    check(st["game"]["mech"]["integrity"] > 35, f"and survivable ({st['game']['mech']['integrity']:.0f} hull)")
finally:
    g.quit()
print("\nRESULT:", "PASS" if not fails else f"FAIL ({len(fails)})")
sys.exit(1 if fails else 0)
