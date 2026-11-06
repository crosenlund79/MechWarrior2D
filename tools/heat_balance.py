#!/usr/bin/env python3
"""Heat balance table: runs the game's thermal model (src/sim/thermal.gd, mirrored)
over typical situations using data/tuning.json + the location's zone types.
Prints equilibrium temperature and time to WARNING / CRITICAL from a cool start.
  python3 tools/heat_balance.py          (edit data/tuning.json, re-run, compare)"""
import json, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
T = json.load(open(os.path.join(ROOT, "data/tuning.json")))
L = json.load(open(os.path.join(ROOT, "data/locations/desert_basin_01.json")))
th, w, tw, tm = T["thermal"], T["combat"]["player_weapon"], T["weather"], T["mech"]
Z = dict(L["zone_types"]); Z["open"] = L["default_zone"]


def storm(z, i):
    i *= z.get("storm_exposure", 1.0)
    z = dict(z)
    z["cooling"] = z.get("cooling", 1.0) * (1 - tw["cooling_penalty"] * i)
    z["ambient"] = z.get("ambient", 58) + tw["ambient_add"] * i
    return z


def run(rad, zone, speed_frac, firing, shutters=True, start=None, secs=600):
    eff = th["min_efficiency"] + (1 - th["min_efficiency"]) * rad
    air = 1.0 if shutters else th["shutters_closed_airflow"]
    k = th["cooling_coeff"] * zone.get("cooling", 1.0) * eff * air
    fire = (w["heat_per_shot"] / w["cooldown"]) if firing else 0.0
    T0 = th["start_heat"] if start is None else start
    t, h, tw_, tc = 0.0, T0, None, None
    while t < secs:
        imp = 1 - tm.get("impair_max", 0.5) * min(1, max(0, (h - th["warn_temp"]) / (th["critical_temp"] - th["warn_temp"])))
        q = th["idle_heat"] + th["move_heat"] * speed_frac * imp + th["solar_heat"] * zone.get("solar", 1.0) + fire
        h += (q - k * (h - zone.get("ambient", 58))) / th["heat_capacity"] * 0.1
        t += 0.1
        if tw_ is None and h >= th["warn_temp"]: tw_ = t
        if tc is None and h >= th["critical_temp"]: tc = t
    q0 = th["idle_heat"] + th["move_heat"] * speed_frac + th["solar_heat"] * zone.get("solar", 1.0) + fire
    eq = zone.get("ambient", 58) + q0 / k
    return eq, tw_, tc


def fmt(x):
    return "never" if x is None else f"{x:5.0f}s"


rows = [
    ("Start radiator, cruising open sand", th["start_radiator"], Z["open"], 1.0, False),
    ("Start radiator, parked in shelter shade", th["start_radiator"], Z["shade"], 0.0, False),
    ("Start radiator, canyon approach", th["start_radiator"], Z["canyon"], 1.0, False),
    ("Start radiator, salt pan (hot)", th["start_radiator"], Z["salt"], 1.0, False),
    ("Start radiator, sustained fire while moving", th["start_radiator"], Z["open"], 0.6, True),
    ("Good radiator (100%), cruising open sand", 1.0, Z["open"], 1.0, False),
    ("Good radiator, sustained fire while moving", 1.0, Z["open"], 0.6, True),
    ("Good radiator, full sandstorm cruising", 1.0, storm(Z["open"], 1.0), 1.0, False),
    ("Good radiator, sandstorm + combat", 1.0, storm(Z["open"], 1.0), 0.6, True),
    ("Start radiator, full sandstorm cruising", th["start_radiator"], storm(Z["open"], 1.0), 1.0, False),
    ("Damaged radiator (25%), cruising", 0.25, Z["open"], 1.0, False),
    ("Damaged radiator (25%), combat", 0.25, Z["open"], 0.6, True),
    ("Good radiator, shutters closed (dunes)", 1.0, Z["dunes"], 0.62, False),
    ("Start radiator, salt pan + combat", th["start_radiator"], Z["salt"], 0.6, True),
    ("Start radiator, sandstorm + combat", th["start_radiator"], storm(Z["open"], 1.0), 0.6, True),
    ("Start radiator, combat in refuge", th["start_radiator"], Z["refuge"], 0.6, True),
]
print(f"warn {th['warn_temp']} °C · critical {th['critical_temp']} °C · start {th['start_heat']} °C · start radiator {th['start_radiator']:.0%}\n")
print(f"{'situation':48s} {'settles at':>10s} {'→ warning':>10s} {'→ critical':>11s}")
for name, rad, z, sf, fire in rows:
    shut = "shutters closed" not in name
    eq, a, b = run(rad, z, sf, fire, shutters=shut)
    print(f"{name:48s} {eq:8.0f}°C {fmt(a):>10s} {fmt(b):>11s}")
