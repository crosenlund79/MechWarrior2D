#!/usr/bin/env python3
"""Thawborn templates in the "Dirty Ink Wasteland" pipeline: the player's car,
rival cars, the three prototype creatures, tracks and hunt materials.

  python3 tools/art/gen_thawborn.py          register manifest entries + draw all
  python3 tools/art/gen_thawborn.py car      only generators whose name contains a word

Writes ONLY assets/templates/** (template_<name>.png) and adds/updates the
matching entries in assets/manifest/assets.json. Never touches overrides.
Straight top-down, nose/head facing UP, light from the upper left, no cast
shadow (the game casts it at runtime from the sprite alpha)."""
import json, math, os, sys
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MANP = os.path.join(ROOT, "assets/manifest/assets.json")

# ---- manifest entries (display = in-game px, source = 2x drawing size) -------------------
def S(path, w, h, pivot=(0.5, 0.5), note="", rot=True):
    e = {"path": path, "display": [w, h], "source": [w * 2, h * 2], "pivot": list(pivot)}
    if rot:
        e["facing"] = "up"; e["rotates"] = True
    if note:
        e["note"] = note
    return e

ENTRIES = {
    "car.body": S("vehicles/player/body", 132, 240, note="the player's car (nose up). Wheels are separate (car.wheel) so the front pair can steer; the roof gun ring sits at the centre"),
    "car.wheel": S("vehicles/player/wheel", 28, 48, note="one tyre seen from above; the game places four and steers the front pair"),
    "car.gun_ring": S("vehicles/player/gun_ring", 76, 76, note="rotating roof mount; turns toward the mouse"),
    "car.twin_gun": S("vehicles/player/twin_gun", 24, 70, pivot=(0.5, 0.7), note="one of the two roof guns (left; the right is mirrored). Pivot = bracket"),
    "rival.body": S("vehicles/scrapper/body", 118, 214, note="hostile scrapper car: oxide red, welded plates, exposed front radiator"),
    "rival.junker_body": S("vehicles/junker/body", 124, 220, note="Southern Junker car: oxide orange, tar hazard bands, bone cog insignia, ram bar"),
    "rival.wreck": S("vehicles/scrapper/wreck", 130, 226, note="burnt-out scrapper car"),
    "rival.junker_wreck": S("vehicles/junker/wreck", 134, 230, note="burnt-out Junker car"),
    "rival.gun": S("vehicles/rival/gun", 34, 78, pivot=(0.5, 0.68), note="crude roof gun on a pivot, swings toward its target"),
    "creature.skirr": S("creatures/skirr/body", 62, 92, note="small pack hunter (head up)"),
    "creature.skirr_dead": S("creatures/skirr/dead", 70, 96),
    "creature.grindback": S("creatures/grindback/body", 156, 196, note="armoured burrower: front shovel plate (top), rear vent (bottom)"),
    "creature.grindback_dead": S("creatures/grindback/dead", 170, 200),
    "creature.mound": S("creatures/grindback/mound", 150, 118, note="sand mound pushed up by a burrowing grindback (the tremor tell)"),
    "creature.rimeback": S("creatures/rimeback/body", 300, 400, note="large quarry body (head and tail are separate parts)"),
    "creature.rimeback_head": S("creatures/rimeback/head", 170, 170, pivot=(0.5, 0.75), note="horned head; pivot = neck"),
    "creature.rimeback_tail": S("creatures/rimeback/tail", 110, 270, pivot=(0.5, 0.08), note="heavy tail; pivot = root"),
    "creature.rime_gland": S("creatures/rimeback/gland", 66, 66, note="frost gland (breakable part, glows before the spit)"),
    "creature.rimeback_dead": S("creatures/rimeback/dead", 360, 620, note="carcass to harvest"),
    "decal.track_skirr": S("decals/track_skirr", 44, 44, rot=True),
    "decal.track_rime": S("decals/track_rime", 96, 84, rot=True),
    "decal.furrow": S("decals/furrow", 70, 88, rot=True),
    "decal.blood": S("decals/blood", 48, 48, rot=False),
    "decal.skid": S("decals/skid", 24, 40, rot=True),
}
ITEMS = ["skirr_hide", "skirr_fang", "grind_plate", "rime_hide", "rime_spine", "rime_horn", "rime_gland", "thawheart"]
for it in ITEMS:
    ENTRIES["item." + it] = S("items/" + it, 44, 44, rot=False)


def register():
    man = json.load(open(MANP))
    for k, v in ENTRIES.items():
        man["sprites"][k] = v
    json.dump(man, open(MANP, "w"), indent="\t", ensure_ascii=False)


register()
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_art as G  # noqa: E402  (reads the updated manifest)
from gen_art import plate, bolts_along, canvas_for, out  # noqa: E402
from inkkit import blob, rrect  # noqa: E402

# creature palette: pale, cold hides that lived under ice (not machinery colours)
HIDE = (196, 190, 176)
HIDE_D = (132, 132, 128)
SLATE = (104, 110, 116)
SLATE_D = (70, 74, 80)
BRUISE = (112, 92, 124)     # temper blue-violet (also the legendary colour)
FROST = (214, 226, 228)
GUT = (120, 52, 44)
OXIDE_O = (188, 96, 42)
TAR = (44, 38, 33)


# ======================================================================= PLAYER CAR
def gen_car_body():
    c = canvas_for("car.body", 901)
    W, H = 264, 480
    cx = W / 2
    # chassis tub
    hull = [(cx - 92, 70), (cx + 92, 70), (cx + 112, 120), (cx + 116, 410), (cx + 100, 462), (cx - 100, 462), (cx - 116, 410), (cx - 112, 120)]
    m = c.fill(hull, G.CHAR, tex=0.35, cell=12)
    c.shade(m, 1, .6, 4.0, 85, cross=True)
    c.ink_poly(hull, 3.0)
    # bonnet (front, faded industrial yellow) with the engine bulge
    bonnet = [(cx - 86, 40), (cx + 86, 40), (cx + 98, 150), (cx - 98, 150)]
    plate(c, bonnet, G.PAINT_Y, line=2.8, grime=0.5, hatch_alpha=70)
    bulge = [(cx - 34, 52), (cx + 34, 52), (cx + 38, 140), (cx - 38, 140)]
    plate(c, bulge, (186, 148, 66), line=2.0, grime=0.3, hatch_alpha=60)
    for y in range(64, 136, 12):   # bonnet louvres
        c.ink([(cx - 26, y), (cx - 6, y)], 2.0, wobble=0.3); c.ink([(cx + 6, y), (cx + 26, y)], 2.0, wobble=0.3)
    # radiator grille + bull bar at the nose (the cooling hit area)
    grille = [(cx - 70, 18), (cx + 70, 18), (cx + 76, 44), (cx - 76, 44)]
    plate(c, grille, G.STEEL_D, hatch=False, line=2.2, grime=0.2)
    for x in range(int(cx - 62), int(cx + 64), 9):
        c.ink([(x, 22), (x + 1, 40)], 1.4, wobble=0.1, color=G.HOLE)
    c.ink([(cx - 98, 10), (cx + 98, 10)], 7.0, wobble=0.3, color=G.STEEL, alpha=255)
    c.ink([(cx - 98, 10), (cx + 98, 10)], 2.0, wobble=0.3)
    for sx in (-1, 1):
        c.ink([(cx + sx * 60, 10), (cx + sx * 60, 30)], 5.0, wobble=0.2, color=G.STEEL_D, alpha=255)
        c.fill_ellipse((cx + sx * 80 - 9, 22, cx + sx * 80 + 9, 38), G.AMBER, tex=0.1)   # headlights
        c.ink_ellipse((cx + sx * 80 - 9, 22, cx + sx * 80 + 9, 38), 1.4)
    # cab + roof (faded utility green), gun ring bearing at the centre
    cab = [(cx - 88, 156), (cx + 88, 156), (cx + 92, 300), (cx - 92, 300)]
    plate(c, cab, G.PAINT_G, line=2.8, grime=0.45, hatch_alpha=75)
    wind = [(cx - 76, 156), (cx + 76, 156), (cx + 70, 178), (cx - 70, 178)]
    c.fill(wind, (64, 70, 72), tex=0.2)
    c.ink([(cx - 50, 162), (cx - 10, 160)], 2.0, alpha=150, color=(230, 226, 210))
    c.ink_poly(wind, 1.8)
    c.fill_ellipse((cx - 44, 196, cx + 44, 284), G.STEEL, tex=0.3)
    c.ink_ellipse((cx - 44, 196, cx + 44, 284), 2.6)
    c.rivets([(cx + math.cos(a) * 40, 240 + math.sin(a) * 40) for a in np.linspace(0, math.tau, 12, endpoint=False)], 1.6)
    # roll cage bars
    for sx in (-1, 1):
        c.ink([(cx + sx * 84, 182), (cx + sx * 84, 296)], 4.0, wobble=0.3, color=G.STEEL_D, alpha=255)
    # flatbed with strapped cargo
    bed = [(cx - 98, 306), (cx + 98, 306), (cx + 100, 454), (cx - 100, 454)]
    plate(c, bed, G.RUST, line=2.6, grime=0.6, hatch_alpha=70)
    for y in range(322, 452, 18):
        c.ink([(cx - 92, y), (cx + 92, y)], 1.4, wobble=0.3, alpha=140)
    crate = [(cx - 72, 330), (cx - 6, 330), (cx - 6, 396), (cx - 72, 396)]
    plate(c, crate, G.OCHRE, line=2.0, grime=0.4)
    tarp = blob(cx + 46, 400, 40, 34, 14, 0.15, 4)
    plate(c, tarp, G.CANVAS_T, line=2.0, grime=0.3)
    c.ink([(cx + 10, 380), (cx + 84, 420)], 2.4, wobble=0.5, color=(150, 70, 40))
    for x in (cx - 50, cx + 50):   # coolant jerrycans (teal = cooling hardware)
        c.fill([(x - 12, 418), (x + 12, 418), (x + 12, 446), (x - 12, 446)], G.COOLANT, tex=0.2)
        c.ink_poly([(x - 12, 418), (x + 12, 418), (x + 12, 446), (x - 12, 446)], 1.6)
    # side exhaust stacks + hazard stripe on the tailgate
    for sx in (-1, 1):
        c.fill_ellipse((cx + sx * 108 - 8, 300, cx + sx * 108 + 8, 316), G.HOLE, tex=0.1)
        c.ink_ellipse((cx + sx * 108 - 8, 300, cx + sx * 108 + 8, 316), 1.6)
    for i in range(7):
        x = cx - 96 + i * 28
        c.fill([(x, 456), (x + 14, 456), (x + 10, 466), (x - 4, 466)], (40, 36, 30) if i % 2 else G.PAINT_Y, tex=0.1)
    bolts_along(c, [(cx - 98, 306), (cx + 98, 306), (cx + 100, 454), (cx - 100, 454)], 26, 6)
    c.desertize(dust=0.5, abrasion=0.45, bleach=0.35, seams=0.6, heat=[(cx, 40, 50, 0.4), (cx - 108, 308, 24, 0.7), (cx + 108, 308, 24, 0.7)])
    c.save(out("car.body"))


def gen_car_wheel():
    c = canvas_for("car.wheel", 902)
    W, H = 56, 96
    t = rrect(6, 4, W - 6, H - 4, 10, 0.4, 2)
    m = c.fill(t, (40, 36, 32), tex=0.3)
    c.shade(m, 1, .6, 3.5, 80)
    c.ink_poly(t, 2.4)
    for y in range(10, H - 8, 9):   # tread blocks
        c.ink([(10, y), (W / 2 - 3, y + 4)], 2.6, wobble=0.2, color=(18, 15, 12))
        c.ink([(W / 2 + 3, y + 4), (W - 10, y)], 2.6, wobble=0.2, color=(18, 15, 12))
    c.desertize(dust=0.8, abrasion=0.3, bleach=0.3, seams=0.3)
    c.save(out("car.wheel"))


def gen_car_gun_ring():
    c = canvas_for("car.gun_ring", 903)
    W = 152
    cx = cy = W / 2
    c.fill_ellipse((cx - 64, cy - 64, cx + 64, cy + 64), G.STEEL_D, tex=0.3)
    c.ink_ellipse((cx - 64, cy - 64, cx + 64, cy + 64), 2.8)
    shield = [(cx - 58, cy - 40), (cx + 58, cy - 40), (cx + 50, cy - 70), (cx - 50, cy - 70)]
    plate(c, shield, G.PAINT_Y, line=2.4, grime=0.4)
    c.ink([(cx - 14, cy - 60), (cx + 14, cy - 60)], 3.0, color=G.HOLE)   # vision slit
    seat = rrect(cx - 26, cy - 20, cx + 26, cy + 40, 8, 0.4, 3)
    plate(c, seat, G.CHAR, line=2.0, grime=0.3, hatch=False)
    c.fill_ellipse((cx - 16, cy - 10, cx + 16, cy + 22), (80, 70, 58), tex=0.2)   # gunner helmet
    c.ink_ellipse((cx - 16, cy - 10, cx + 16, cy + 22), 1.8)
    c.fill([(cx - 10, cy - 8), (cx + 10, cy - 8), (cx + 8, cy - 2), (cx - 8, cy - 2)], G.AMBER, tex=0.1)   # visor
    c.rivets([(cx + math.cos(a) * 56, cy + math.sin(a) * 56) for a in np.linspace(0, math.tau, 14, endpoint=False)], 1.6)
    c.desertize(dust=0.4, abrasion=0.5, bleach=0.3, seams=0.6)
    c.save(out("car.gun_ring"))


def gen_car_twin_gun():
    c = canvas_for("car.twin_gun", 904)
    W, H = 48, 140
    cx, my = W / 2, 98
    box = rrect(cx - 18, my - 12, cx + 18, my + 38, 5, 0.4, 2)
    plate(c, box, G.RUST, line=2.2, grime=0.5)
    barrel = [(cx - 7, my - 12), (cx + 7, my - 12), (cx + 6, 12), (cx - 6, 12)]
    plate(c, barrel, G.STEEL, line=2.0, grime=0.3, hatch_alpha=70)
    for y in range(20, int(my - 16), 10):
        c.ink([(cx - 9, y), (cx + 9, y)], 2.2, wobble=0.2)
    c.fill([(cx - 9, 2), (cx + 9, 2), (cx + 9, 14), (cx - 9, 14)], G.CHAR, tex=0.1)
    c.ink_poly([(cx - 9, 2), (cx + 9, 2), (cx + 9, 14), (cx - 9, 14)], 1.6)
    c.desertize(dust=0.4, abrasion=0.5, bleach=0.3, seams=0.6, heat=[(cx, 20, 20, 0.7)])
    c.save(out("car.twin_gun"))


# ======================================================================= RIVAL CARS
def _rival(id_, seed, junker=False, wrecked=False):
    c = canvas_for(id_, seed)
    W, H = ENTRIES[id_]["source"]
    cx = W / 2
    top, bot = 26, H - 18
    L = bot - top
    hull = [(cx - 78, top + 30), (cx + 70, top + 18), (cx + 98, top + 70), (cx + 100, bot - 40), (cx + 84, bot), (cx - 90, bot - 6), (cx - 104, bot - 50), (cx - 100, top + 80)]
    if wrecked:
        hull = [(x + (12 if i % 2 else -10), y + (8 if i % 3 == 0 else -6)) for i, (x, y) in enumerate(hull)]
    body_col = OXIDE_O if junker else G.PAINT_R
    m = c.fill(hull, G.CHAR, tex=0.35, cell=12)
    c.shade(m, 1, .6, 4.0, 90, cross=True)
    c.ink_poly(hull, 3.0)
    # mismatched welded plates
    plates = [
        [(cx - 70, top + 40), (cx + 62, top + 30), (cx + 80, top + 0.32 * L), (cx - 76, top + 0.34 * L)],
        [(cx - 84, top + 0.36 * L), (cx + 8, top + 0.36 * L), (cx + 4, top + 0.62 * L), (cx - 88, top + 0.6 * L)],
        [(cx + 12, top + 0.38 * L), (cx + 88, top + 0.36 * L), (cx + 90, top + 0.66 * L), (cx + 14, top + 0.64 * L)],
        [(cx - 88, top + 0.66 * L), (cx + 88, top + 0.68 * L), (cx + 82, bot - 12), (cx - 84, bot - 16)],
    ]
    cols = [body_col, G.RUST, body_col, G.RUST_D] if not junker else [body_col, TAR, body_col, G.RUST]
    for p, col in zip(plates, cols):
        plate(c, p, col, line=2.4, grime=0.7, hatch_alpha=80)
        bolts_along(c, p, 22, 5)
    # exposed front radiator (cooling hit area) — coolant hoses
    rad = [(cx - 48, top + 6), (cx + 44, top + 2), (cx + 46, top + 30), (cx - 50, top + 34)]
    plate(c, rad, G.STEEL_D, hatch=False, line=2.2, grime=0.2)
    for x in range(int(cx - 42), int(cx + 42), 8):
        c.ink([(x, top + 8), (x, top + 30)], 1.3, wobble=0.1, color=G.HOLE)
    for sx in (-1, 1):
        c.ink([(cx + sx * 40, top + 30), (cx + sx * 56, top + 60)], 4.0, wobble=0.6, color=(48, 92, 88), alpha=255)
    # cab offset to the left, gun pivot plate on the roof
    cab = rrect(cx - 70, top + 0.38 * L, cx - 6, top + 0.58 * L, 6, 0.6, 3)
    plate(c, cab, (70, 64, 56), line=2.2, grime=0.3, hatch=False)
    c.fill([(cx - 62, top + 0.4 * L), (cx - 14, top + 0.4 * L), (cx - 16, top + 0.44 * L), (cx - 60, top + 0.44 * L)], (56, 62, 64), tex=0.2)
    c.fill_ellipse((cx + 20, top + 0.42 * L, cx + 76, top + 0.62 * L), G.STEEL_D, tex=0.3)
    c.ink_ellipse((cx + 20, top + 0.42 * L, cx + 76, top + 0.62 * L), 2.2)
    if junker:
        # ram bar with spikes, tar hazard bands, bone cog insignia
        c.ink([(cx - 104, top - 4), (cx + 100, top - 10)], 8.0, wobble=0.4, color=G.STEEL, alpha=255)
        for x in range(int(cx - 96), int(cx + 100), 26):
            c.ink([(x, top - 8), (x + 2, top - 22)], 4.0, wobble=0.2, color=G.STEEL_L, alpha=255)
        for i in range(6):
            y = top + 0.7 * L + i * 14
            c.ink([(cx - 84, y), (cx - 60, y + 10)], 6.0, wobble=0.2, color=TAR if i % 2 else (210, 160, 60), alpha=230)
        G.insignia(c, cx + 46, top + 0.8 * L, 18, G.BONE)
    else:
        c.ink([(cx - 96, top + 2), (cx + 92, top - 4)], 5.0, wobble=0.6, color=G.RUST_D, alpha=255)
    if wrecked:
        for _ in range(9):   # soot blooms
            x = cx + c.rng.uniform(-80, 80); y = top + c.rng.uniform(0.1, 0.9) * L
            c.fill_ellipse((x - 26, y - 20, x + 26, y + 20), (34, 30, 26), tex=0.4)
        c.ink([(cx - 60, top + 0.3 * L), (cx + 10, top + 0.5 * L), (cx - 20, top + 0.8 * L)], 3.0, wobble=1.4, color=G.HOLE)
        c.desertize(dust=0.8, abrasion=0.5, bleach=0.3, seams=0.8, heat=[(cx, top + 0.5 * L, 90, 0.9)])
    else:
        c.desertize(dust=0.55, abrasion=0.5, bleach=0.3, seams=0.7, heat=[(cx + 80, bot - 50, 26, 0.7)])
    c.save(out(id_))


def gen_rivals():
    _rival("rival.body", 911)
    _rival("rival.junker_body", 912, junker=True)
    _rival("rival.wreck", 913, wrecked=True)
    _rival("rival.junker_wreck", 914, junker=True, wrecked=True)
    c = canvas_for("rival.gun", 915)
    W, H = 68, 156
    cx, my = W / 2, 106
    c.fill_ellipse((cx - 26, my - 22, cx + 26, my + 30), G.STEEL_D, tex=0.3)
    c.ink_ellipse((cx - 26, my - 22, cx + 26, my + 30), 2.2)
    pipe = [(cx - 9, my - 14), (cx + 9, my - 14), (cx + 8, 10), (cx - 8, 10)]
    plate(c, pipe, G.RUST, line=2.2, grime=0.6)
    for y in (30, 60, 88):   # crude weld collars
        c.ink([(cx - 13, y), (cx + 13, y + 2)], 4.0, wobble=0.6, color=G.RUST_D, alpha=255)
    c.fill([(cx - 12, 0), (cx + 12, 0), (cx + 12, 12), (cx - 12, 12)], G.CHAR, tex=0.1)
    c.desertize(dust=0.5, abrasion=0.5, bleach=0.3, seams=0.7, heat=[(cx, 16, 22, 0.8)])
    c.save(out("rival.gun"))


# ======================================================================= CREATURES
def _legs(c, cx, cy, n, span, length, col, width=7.0, seed=0):
    rng = np.random.default_rng(seed)
    for i in range(n):
        t = (i + 0.5) / n
        y = cy - span / 2 + t * span
        for sx in (-1, 1):
            a = (t - 0.5) * 1.2 * sx
            kx = cx + sx * length * 0.55
            ky = y + rng.uniform(-6, 6)
            fx = cx + sx * length
            fy = y + math.sin(a) * length * 0.5 + (t - 0.5) * 30
            c.ink([(cx + sx * 12, y), (kx, ky - 10), (fx, fy)], width, wobble=0.6, color=col, alpha=255)
            c.ink([(cx + sx * 12, y), (kx, ky - 10), (fx, fy)], 1.6, wobble=0.6)


def gen_skirr():
    for id_, dead in (("creature.skirr", False), ("creature.skirr_dead", True)):
        c = canvas_for(id_, 921 + dead)
        W, H = ENTRIES[id_]["source"]
        cx = W / 2
        _legs(c, cx, H * 0.52, 3, H * 0.34, W * 0.44 if not dead else W * 0.4, SLATE_D, 6.0, 3)
        body = blob(cx, H * 0.52, W * 0.2, H * 0.3, 18, 0.08, 4)
        if dead:
            body = [(x + (y - H / 2) * 0.18, y) for x, y in body]
        m = c.fill(body, HIDE, tex=0.35, cell=8)
        c.shade(m, 1, .6, 3.5, 80)
        c.ink_poly(body, 2.4)
        for i in range(5):   # dark ink bands along the back (pack marking)
            y = H * 0.32 + i * H * 0.08
            c.ink([(cx - W * 0.14, y), (cx, y + 6), (cx + W * 0.14, y)], 3.0, wobble=0.5, color=BRUISE, alpha=200)
        head = blob(cx, H * 0.2, W * 0.14, H * 0.13, 14, 0.1, 5)
        plate(c, head, HIDE_D, line=2.2, grime=0.0, hatch_alpha=70)
        c.ink([(cx - 8, H * 0.08), (cx, H * 0.02), (cx + 8, H * 0.08)], 2.2, wobble=0.3)   # snout hook
        for sx in (-1, 1):   # eyes (glint during the crouch tell comes from the game)
            c.fill_ellipse((cx + sx * 9 - 4, H * 0.16 - 4, cx + sx * 9 + 4, H * 0.16 + 4), (24, 18, 16) if not dead else (90, 84, 80), tex=0.1)
            c.ink([(cx + sx * 10, H * 0.2), (cx + sx * 26, H * 0.12)], 2.4, wobble=0.5, color=FROST)   # frill spines
        c.ink([(cx, H * 0.82), (cx + 6, H * 0.94), (cx - 2, H * 0.99)], 4.0, wobble=0.6, color=HIDE_D, alpha=255)   # tail
        if dead:
            c.fill_ellipse((cx - 14, H * 0.44, cx + 18, H * 0.62), GUT, tex=0.3)
        c.desertize(dust=0.35, abrasion=0.2, bleach=0.2, seams=0.5)
        c.save(out(id_))


def gen_grindback():
    for id_, dead in (("creature.grindback", False), ("creature.grindback_dead", True)):
        c = canvas_for(id_, 931 + dead)
        W, H = ENTRIES[id_]["source"]
        cx = W / 2
        _legs(c, cx, H * 0.55, 2, H * 0.3, W * 0.46, SLATE_D, 12.0, 5)
        body = blob(cx, H * 0.55, W * 0.34, H * 0.34, 22, 0.06, 6)
        m = c.fill(body, SLATE, tex=0.45, cell=12)
        c.shade(m, 1, .6, 4.0, 90, cross=True)
        c.ink_poly(body, 3.0)
        # overlapping carapace plates
        for i in range(5):
            y = H * 0.32 + i * H * 0.1
            seg = [(cx - W * 0.3 + i * 3, y), (cx + W * 0.3 - i * 3, y), (cx + W * 0.26 - i * 4, y + H * 0.11), (cx - W * 0.26 + i * 4, y + H * 0.11)]
            plate(c, seg, (128, 118, 98) if i % 2 else (116, 108, 92), line=2.2, grime=0.4, hatch_alpha=70)
        # front shovel plate (armour)
        shovel = [(cx - W * 0.36, H * 0.24), (cx + W * 0.36, H * 0.24), (cx + W * 0.26, H * 0.04), (cx - W * 0.26, H * 0.04)]
        if dead:
            shovel = [(x + 14, y + 10) for x, y in shovel]
        plate(c, shovel, G.OCHRE, line=3.0, grime=0.5, hatch_alpha=90)
        for x in np.linspace(cx - W * 0.22, cx + W * 0.22, 5):
            c.ink([(x, H * 0.06), (x, H * 0.2)], 2.0, wobble=0.4, alpha=150)
        # rear vent (weak spot), warm glow
        c.fill_ellipse((cx - 22, H * 0.8, cx + 22, H * 0.92), (150, 70, 48) if not dead else (60, 40, 34), tex=0.3)
        c.ink_ellipse((cx - 22, H * 0.8, cx + 22, H * 0.92), 2.2)
        for x in (cx - 10, cx, cx + 10):
            c.ink([(x, H * 0.82), (x, H * 0.9)], 1.6, color=G.HOLE)
        if dead:
            c.fill_ellipse((cx - 30, H * 0.5, cx + 26, H * 0.66), GUT, tex=0.3)
        c.desertize(dust=0.7, abrasion=0.6, bleach=0.25, seams=0.7)
        c.save(out(id_))
    c = canvas_for("creature.mound", 935)
    W, H = ENTRIES["creature.mound"]["source"]
    md = blob(W / 2, H / 2, W * 0.42, H * 0.38, 20, 0.12, 7)
    m = c.fill(md, (196, 160, 106), tex=0.5, cell=10)
    c.shade(m, 1, .6, 4.0, 70)
    for i in range(6):
        a = i / 6 * math.tau
        c.ink([(W / 2 + math.cos(a) * W * 0.12, H / 2 + math.sin(a) * H * 0.12), (W / 2 + math.cos(a) * W * 0.36, H / 2 + math.sin(a) * H * 0.32)], 1.8, wobble=1.2, alpha=170)
    c.save(out("creature.mound"), outline=1.2, burn=0.1)


def gen_rimeback():
    c = canvas_for("creature.rimeback", 941)
    W, H = ENTRIES["creature.rimeback"]["source"]
    cx = W / 2
    _legs(c, cx, H * 0.5, 3, H * 0.62, W * 0.47, SLATE_D, 22.0, 9)
    body = blob(cx, H * 0.5, W * 0.34, H * 0.44, 26, 0.05, 8)
    m = c.fill(body, HIDE, tex=0.4, cell=16)
    c.shade(m, 1, .6, 4.5, 85, cross=True)
    c.ink_poly(body, 3.4)
    # spine ridge with frost-crusted plates
    for i in range(9):
        y = H * 0.12 + i * H * 0.085
        r = W * (0.06 + 0.04 * math.sin(i / 8 * math.pi))
        p = [(cx - r, y + 14), (cx, y - 10), (cx + r, y + 14), (cx, y + 26)]
        plate(c, p, FROST if i % 2 else (190, 200, 204), line=2.2, grime=0.0, hatch_alpha=60)
    # bruise-violet mottling (temper colours) along the flanks
    for k in range(18):
        x = cx + c.rng.uniform(-W * 0.28, W * 0.28); y = H * c.rng.uniform(0.15, 0.85)
        if abs(x - cx) > W * 0.08:
            c.fill_ellipse((x - 9, y - 6, x + 9, y + 6), BRUISE, tex=0.2)
    for i in range(7):   # shoulder skin folds
        y = H * 0.24 + i * H * 0.08
        for sx in (-1, 1):
            c.ink([(cx + sx * W * 0.12, y), (cx + sx * W * 0.3, y + 10)], 1.8, wobble=0.8, alpha=150)
    c.desertize(dust=0.4, abrasion=0.2, bleach=0.2, seams=0.6)
    c.save(out("creature.rimeback"))
    # head (pivot at neck = 75 % down)
    c = canvas_for("creature.rimeback_head", 942)
    W, H = ENTRIES["creature.rimeback_head"]["source"]
    cx = W / 2
    head = blob(cx, H * 0.55, W * 0.3, H * 0.34, 20, 0.07, 10)
    m = c.fill(head, HIDE_D, tex=0.4, cell=10)
    c.shade(m, 1, .6, 4.0, 85)
    c.ink_poly(head, 3.0)
    for sx in (-1, 1):   # swept horns
        horn = [(cx + sx * W * 0.12, H * 0.32), (cx + sx * W * 0.46, H * 0.06), (cx + sx * W * 0.38, H * 0.02), (cx + sx * W * 0.06, H * 0.26)]
        plate(c, horn, (214, 204, 182), line=2.4, grime=0.0, hatch_alpha=70)
        c.fill_ellipse((cx + sx * W * 0.16 - 8, H * 0.42 - 6, cx + sx * W * 0.16 + 8, H * 0.42 + 6), (26, 22, 22), tex=0.1)
    plate(c, [(cx - W * 0.12, H * 0.2), (cx + W * 0.12, H * 0.2), (cx + W * 0.08, H * 0.36), (cx - W * 0.08, H * 0.36)], FROST, line=2.0, grime=0.0)
    c.desertize(dust=0.3, abrasion=0.2, bleach=0.2, seams=0.5)
    c.save(out("creature.rimeback_head"))
    # tail (pivot at root = top)
    c = canvas_for("creature.rimeback_tail", 943)
    W, H = ENTRIES["creature.rimeback_tail"]["source"]
    cx = W / 2
    tail = [(cx - W * 0.32, H * 0.02), (cx + W * 0.32, H * 0.02), (cx + W * 0.12, H * 0.8), (cx, H * 0.98), (cx - W * 0.12, H * 0.8)]
    m = c.fill(tail, HIDE, tex=0.4, cell=10)
    c.shade(m, 1, .6, 4.0, 80)
    c.ink_poly(tail, 3.0)
    for i in range(8):
        y = H * 0.08 + i * H * 0.1
        w = W * 0.28 * (1 - i / 10)
        c.ink([(cx - w, y), (cx, y + 10), (cx + w, y)], 2.4, wobble=0.4, color=BRUISE if i % 2 else HIDE_D, alpha=220)
    for i in range(4):   # bony club spines
        y = H * 0.72 + i * 16
        for sx in (-1, 1):
            c.ink([(cx, y), (cx + sx * 26, y - 10)], 3.0, wobble=0.3, color=FROST, alpha=255)
    c.desertize(dust=0.3, abrasion=0.2, bleach=0.2, seams=0.5)
    c.save(out("creature.rimeback_tail"))
    c = canvas_for("creature.rime_gland", 944)
    W, H = ENTRIES["creature.rime_gland"]["source"]
    g = blob(W / 2, H / 2, W * 0.38, H * 0.38, 16, 0.08, 11)
    m = c.fill(g, (176, 196, 204), tex=0.3, cell=6)
    c.ink_poly(g, 2.4)
    for i in range(5):
        a = i / 5 * math.tau
        c.ink([(W / 2, H / 2), (W / 2 + math.cos(a) * W * 0.3, H / 2 + math.sin(a) * H * 0.3)], 1.6, wobble=0.6, color=BRUISE)
    c.fill_ellipse((W / 2 - 10, H / 2 - 10, W / 2 + 10, H / 2 + 10), FROST, tex=0.1)
    c.save(out("creature.rime_gland"))
    # carcass
    c = canvas_for("creature.rimeback_dead", 945)
    W, H = ENTRIES["creature.rimeback_dead"]["source"]
    cx = W / 2
    _legs(c, cx - 10, H * 0.45, 3, H * 0.4, W * 0.46, SLATE_D, 20.0, 12)
    body = blob(cx, H * 0.45, W * 0.3, H * 0.28, 24, 0.07, 13)
    m = c.fill(body, (176, 168, 152), tex=0.45, cell=16)
    c.shade(m, 1, .6, 4.0, 95, cross=True)
    c.ink_poly(body, 3.2)
    head = blob(cx + 30, H * 0.12, W * 0.16, H * 0.08, 16, 0.08, 14)
    plate(c, head, HIDE_D, line=2.6, grime=0.3)
    tail = [(cx - 20, H * 0.7), (cx + 24, H * 0.7), (cx + 60, H * 0.96), (cx + 40, H * 0.98)]
    plate(c, tail, HIDE, line=2.4, grime=0.3)
    c.fill_ellipse((cx - 50, H * 0.4, cx + 40, H * 0.55), GUT, tex=0.4)
    c.ink([(cx - 60, H * 0.36), (cx + 50, H * 0.6)], 2.4, wobble=1.2)
    c.desertize(dust=0.6, abrasion=0.3, bleach=0.3, seams=0.7)
    c.save(out("creature.rimeback_dead"))


# ======================================================================= DECALS
def gen_decals():
    c = canvas_for("decal.track_skirr", 951)
    W, H = ENTRIES["decal.track_skirr"]["source"]
    for sx, dy in ((-1, 10), (1, -10)):
        x, y = W / 2 + sx * 18, H / 2 + dy
        for a in (-0.5, 0, 0.5):
            c.ink([(x, y + 8), (x + math.sin(a) * 14, y - 10)], 3.2, wobble=0.3, color=(110, 82, 54), alpha=210)
    c.save(out("decal.track_skirr"), finish=False)
    c = canvas_for("decal.track_rime", 952)
    W, H = ENTRIES["decal.track_rime"]["source"]
    for sx in (-1, 1):
        x = W / 2 + sx * 52
        c.fill_ellipse((x - 26, H / 2 - 34, x + 26, H / 2 + 34), (120, 90, 58), tex=0.4, cell=6)
        c.fill_ellipse((x - 16, H / 2 - 22, x + 16, H / 2 + 24), (92, 68, 44), tex=0.3, cell=6)
        for k in (-1, 0, 1):
            c.fill_ellipse((x + k * 15 - 6, H / 2 - 46, x + k * 15 + 6, H / 2 - 32), (100, 76, 50), tex=0.2)
    c.save(out("decal.track_rime"), finish=False)
    c = canvas_for("decal.furrow", 953)
    W, H = ENTRIES["decal.furrow"]["source"]
    for sx in (-1, 1):
        c.ink([(W / 2 + sx * 30, 4), (W / 2 + sx * 34, H - 4)], 9.0, wobble=1.0, color=(150, 116, 76), alpha=170)
    c.ink([(W / 2, 4), (W / 2 + 2, H - 4)], 16.0, wobble=1.2, color=(190, 154, 104), alpha=150)
    c.save(out("decal.furrow"), finish=False)
    c = canvas_for("decal.blood", 954)
    W, H = ENTRIES["decal.blood"]["source"]
    for k in range(6):
        x = W / 2 + c.rng.uniform(-26, 26); y = H / 2 + c.rng.uniform(-26, 26); r = c.rng.uniform(5, 13)
        c.fill_ellipse((x - r, y - r * 0.8, x + r, y + r * 0.8), (98, 34, 30), tex=0.3)
    c.save(out("decal.blood"), finish=False)
    c = canvas_for("decal.skid", 955)
    W, H = ENTRIES["decal.skid"]["source"]
    c.ink([(W / 2, 2), (W / 2, H - 2)], 18.0, wobble=0.6, color=(48, 40, 32), alpha=150)
    c.save(out("decal.skid"), finish=False)


# ======================================================================= MATERIALS (loot icons)
def gen_materials():
    def icon(it, seed, draw):
        c = canvas_for("item." + it, seed)
        draw(c, *ENTRIES["item." + it]["source"])
        c.desertize(dust=0.25, abrasion=0.15, bleach=0.15, seams=0.4)
        c.save(out("item." + it))
    icon("skirr_hide", 961, lambda c, W, H: (plate(c, blob(W / 2, H / 2, W * 0.36, H * 0.3, 14, 0.2, 1), HIDE, line=2.2, grime=0.2),
                                             [c.ink([(W * 0.3, H * (0.35 + k * 0.12)), (W * 0.7, H * (0.38 + k * 0.12))], 2.4, color=BRUISE) for k in range(3)]))
    icon("skirr_fang", 962, lambda c, W, H: [plate(c, [(W * (0.3 + k * 0.22), H * 0.2), (W * (0.38 + k * 0.22), H * 0.24), (W * (0.32 + k * 0.22), H * 0.82)], (230, 222, 200), line=2.0, grime=0.0) for k in range(3)])
    icon("grind_plate", 963, lambda c, W, H: (plate(c, [(W * 0.14, H * 0.3), (W * 0.86, H * 0.24), (W * 0.8, H * 0.76), (W * 0.2, H * 0.8)], G.OCHRE, line=2.4, grime=0.4),
                                              [c.ink([(W * 0.2, H * (0.42 + k * 0.14)), (W * 0.8, H * (0.38 + k * 0.14))], 2.0, alpha=160) for k in range(3)]))
    icon("rime_hide", 964, lambda c, W, H: (plate(c, blob(W / 2, H / 2, W * 0.4, H * 0.34, 16, 0.18, 2), (200, 194, 180), line=2.4, grime=0.2),
                                            [c.fill_ellipse((W * x - 5, H * y - 4, W * x + 5, H * y + 4), BRUISE, tex=0.1) for x, y in ((0.35, 0.4), (0.6, 0.55), (0.45, 0.65))]))
    icon("rime_spine", 965, lambda c, W, H: (c.ink([(W * 0.2, H * 0.8), (W * 0.8, H * 0.2)], 8.0, color=FROST, alpha=255),
                                             c.ink([(W * 0.2, H * 0.8), (W * 0.8, H * 0.2)], 2.0),
                                             [c.ink([(W * (0.3 + k * 0.15), H * (0.7 - k * 0.15)), (W * (0.38 + k * 0.15), H * (0.82 - k * 0.15))], 3.0, color=HIDE_D) for k in range(4)]))
    icon("rime_horn", 966, lambda c, W, H: plate(c, [(W * 0.2, H * 0.84), (W * 0.42, H * 0.84), (W * 0.84, H * 0.12), (W * 0.72, H * 0.1)], (220, 210, 186), line=2.6, grime=0.0))
    icon("rime_gland", 967, lambda c, W, H: (plate(c, blob(W / 2, H / 2, W * 0.34, H * 0.34, 14, 0.1, 3), (170, 192, 202), line=2.4, grime=0.0),
                                             c.fill_ellipse((W * 0.42, H * 0.38, W * 0.58, H * 0.54), FROST, tex=0.1)))
    def heart(c, W, H):
        p = blob(W / 2, H * 0.54, W * 0.36, H * 0.34, 18, 0.1, 4)
        plate(c, p, BRUISE, line=2.8, grime=0.0, hatch_alpha=70)
        for k in range(5):
            a = k / 5 * math.tau
            c.ink([(W / 2, H * 0.54), (W / 2 + math.cos(a) * W * 0.28, H * 0.54 + math.sin(a) * H * 0.26)], 1.8, color=FROST, alpha=220)
        c.fill_ellipse((W * 0.44, H * 0.46, W * 0.56, H * 0.6), (236, 228, 250), tex=0.05)
    icon("thawheart", 968, heart)


GENS = [gen_car_body, gen_car_wheel, gen_car_gun_ring, gen_car_twin_gun, gen_rivals, gen_skirr, gen_grindback, gen_rimeback, gen_decals, gen_materials]

if __name__ == "__main__":
    filt = sys.argv[1:]
    for g in GENS:
        if not filt or any(f in g.__name__ for f in filt):
            g()
            print("done", g.__name__)
