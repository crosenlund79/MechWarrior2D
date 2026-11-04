#!/usr/bin/env python3
"""Generates every illustrated template for Heat Signature ("Dirty Ink Wasteland").

  python3 tools/art/gen_art.py            all assets
  python3 tools/art/gen_art.py mech rock  only generators whose name contains a filter word

Writes ONLY assets/templates/** (template_<name>.png) and assets/fx/*. Never touches overrides.
Sizes come from the manifest "source" field (≈2× display). Straight top-down, light from the upper
left; rotating parts face up and carry no cast shadow (the game casts it at runtime).
"""
import json, math, os, random, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from inkkit import Canvas, Tile, value_noise, blob, rrect, INK, SS, DUST

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MAN = json.load(open(os.path.join(ROOT, "assets/manifest/assets.json")))
ALL = {**MAN["sprites"], **MAN["tiles"]}

# ---- palette (Dirty Ink Wasteland) ----
SAND_L, SAND_M, SAND_D = (226, 196, 146), (204, 166, 112), (166, 128, 84)
OCHRE = (196, 146, 72)
SIENNA = (152, 86, 52)
RUST = (128, 72, 44)
RUST_D = (92, 52, 34)
STEEL = (108, 102, 92)
STEEL_D = (72, 68, 62)
STEEL_L = (146, 138, 124)
CHAR = (54, 47, 40)
HOLE = (30, 24, 20)
PAINT_Y = (200, 160, 70)     # faded industrial yellow
PAINT_G = (112, 126, 104)    # faded utility green
PAINT_R = (156, 72, 50)
BONE = (226, 214, 190)
COOLANT = (62, 160, 150)
AMBER = (232, 150, 40)
CANVAS_T = (176, 120, 72)    # sun-faded tarp


def canvas_for(id_, seed=None):
    w, h = ALL[id_]["source"]
    return Canvas(w, h, seed if seed is not None else (abs(hash(id_)) % 100000))


def out(id_):
    d, n = os.path.split(ALL[id_]["path"])
    p = os.path.join(ROOT, "assets/templates", d, "template_" + n + ".png")
    os.makedirs(os.path.dirname(p), exist_ok=True)
    return p


def plate(c, poly, col, hatch=True, line=2.2, tex=0.3, cell=10, grime=0.3, hatch_alpha=80):
    m = c.fill(poly, col, tex=tex, cell=cell)
    if hatch:
        c.shade(m, 1, 0.6, 4.5, hatch_alpha)
    if grime:
        c.grime(m, grime, streaks=3)
    c.ink_poly(poly, line)
    return m


def bolts_along(c, pts, every=18, inset=5):
    out_pts = []
    for (ax, ay), (bx, by) in zip(pts, pts[1:] + pts[:1]):
        L = math.hypot(bx - ax, by - ay)
        n = int(L // every)
        for i in range(1, n):
            t = i / n
            cx = (ax + (bx - ax) * t)
            cy = (ay + (by - ay) * t)
            out_pts.append((cx, cy))
    mx = sum(p[0] for p in pts) / len(pts); my = sum(p[1] for p in pts) / len(pts)
    out_pts = [(x + (mx - x) * inset / max(1, math.hypot(mx - x, my - y)), y + (my - y) * inset / max(1, math.hypot(mx - x, my - y))) for x, y in out_pts]
    c.rivets(out_pts, 1.7)


# ======================================================================= MECH
def gen_mech_hull():
    c = canvas_for("mech.hull", 101)
    W, H = 400, 440
    cx = W / 2
    # hip joints (sit under the side armour, where the legs attach at ±176 px)
    for sx in (-1, 1):
        x = cx + sx * 150
        c.fill_ellipse((x - 34, 186, x + 34, 254), STEEL_D, tex=0.3)
        c.ink_ellipse((x - 34, 186, x + 34, 254), 2.2)
        c.fill_ellipse((x - 16, 204, x + 16, 236), STEEL_L, tex=0.2)
        c.ink_ellipse((x - 16, 204, x + 16, 236), 1.4)
    # chassis frame (dark, underneath everything)
    frame = [(cx - 120, 70), (cx + 120, 70), (cx + 150, 130), (cx + 150, 330), (cx + 118, 420), (cx - 118, 420), (cx - 150, 330), (cx - 150, 130)]
    m = c.fill(frame, CHAR, tex=0.35, cell=12)
    c.shade(m, 1, .6, 4.0, 90, cross=True)
    c.ink_poly(frame, 3.0)
    # rear mounting rails for the radiator
    for sx in (-1, 1):
        rail = [(cx + sx * 70 - 9, 330), (cx + sx * 70 + 9, 330), (cx + sx * 70 + 9, 438), (cx + sx * 70 - 9, 438)]
        plate(c, rail, STEEL_D, hatch=False, line=1.6, grime=0)
    # side armour plates (faded yellow, mismatched patch on the right)
    for sx, col, seed in ((-1, PAINT_Y, 3), (1, PAINT_Y, 4)):
        p = [(cx + sx * 96, 96), (cx + sx * 140, 128), (cx + sx * 142, 318), (cx + sx * 112, 350), (cx + sx * 92, 340)]
        if sx > 0:
            p = [(x, y) for x, y in p]
        m = plate(c, p, col, line=2.6, grime=0.45)
        bolts_along(c, p, 22, 7)
        # worn hazard chevrons near the front
        for k in range(3):
            y0 = 140 + k * 22
            st = [(cx + sx * 100, y0), (cx + sx * 138, y0 + 12), (cx + sx * 138, y0 + 22), (cx + sx * 100, y0 + 10)]
            c.fill(st, CHAR, tex=0.4)
    # patch panel (different metal, welded)
    patch = [(cx + 104, 250), (cx + 140, 246), (cx + 141, 300), (cx + 108, 306)]
    plate(c, patch, STEEL_L, line=1.6, grime=0.2)
    c.ink([(cx + 104, 250), (cx + 108, 306)], 1.0, wobble=1.4, alpha=160)
    # central spine / engine deck (oxidised steel)
    deck = [(cx - 88, 176), (cx + 88, 176), (cx + 92, 330), (cx + 70, 360), (cx - 70, 360), (cx - 92, 330)]
    m = plate(c, deck, STEEL, line=2.4, grime=0.5, hatch_alpha=70)
    # engine vent grilles
    for vx in (-46, 46):
        g = [(cx + vx - 26, 226), (cx + vx + 26, 226), (cx + vx + 26, 300), (cx + vx - 26, 300)]
        c.fill(g, HOLE, tex=0.2)
        c.slots(cx + vx - 22, 230, cx + vx + 22, 296, 7, vertical=False, width=2.0, alpha=230)
        for k in range(7):
            yy = 233 + k * 9.4
            c.ink([(cx + vx - 22, yy), (cx + vx + 22, yy)], 0.8, wobble=0.2, alpha=90, color=(170, 160, 140))
        c.ink_poly(g, 1.8)
    # exhaust stacks (round openings seen from above)
    for ex in (-62, 62):
        c.fill_ellipse((cx + ex - 15, 318, cx + ex + 15, 348), RUST, tex=0.4)
        c.fill_ellipse((cx + ex - 9, 324, cx + ex + 9, 342), HOLE, tex=0.1)
        c.ink_ellipse((cx + ex - 15, 318, cx + ex + 15, 348), 1.8)
    # coolant lines from cockpit to the radiator (faded coolant teal)
    for sx in (-1, 1):
        pts = [(cx + sx * 30, 182), (cx + sx * 34, 230), (cx + sx * 20, 300), (cx + sx * 26, 360), (cx + sx * 44, 420)]
        c.ink(pts, 6.0, wobble=0.5, alpha=255, color=(48, 92, 88))
        c.ink(pts, 3.2, wobble=0.4, alpha=255, color=(78, 140, 130))
        c.ink([(x - 1.5, y - 1) for x, y in pts], 1.0, wobble=0.3, alpha=120, color=(170, 210, 196))
    # cockpit pod (front centre): armoured shell + canopy with dark glass
    pod = blob(cx, 132, 74, 70, 26, 0.04, 7)
    m = plate(c, pod, PAINT_G, line=3.0, grime=0.4, hatch_alpha=90)
    canopy = blob(cx, 118, 46, 40, 22, 0.03, 8)
    c.fill(canopy, (52, 66, 66), tex=0.5, cell=8, light=(-1, -1, 0.5))
    c.shade(c.mask(canopy), 1, .6, 3.5, 70)
    c.ink([(cx - 30, 100), (cx - 14, 88)], 3.0, wobble=0.3, alpha=150, color=(214, 226, 210))  # glare
    c.ink([(cx - 20, 108), (cx - 10, 101)], 1.6, wobble=0.2, alpha=110, color=(214, 226, 210))
    c.ink_poly(canopy, 2.4)
    # visor slit + grille bars at the very front
    c.ink([(cx - 30, 80), (cx + 30, 80)], 5.0, wobble=0.4, alpha=245, color=HOLE)
    for gx in range(-24, 30, 12):
        c.ink([(cx + gx, 72), (cx + gx, 90)], 1.4, wobble=0.2)
    # hatch ring on the pod rear
    c.ink_ellipse((cx - 22, 160, cx + 22, 190), 1.6)
    c.rivets([(cx - 18, 175), (cx + 18, 175), (cx, 162), (cx, 188)], 1.4)
    # strapped cargo: water jerrycan (left) and a rolled tarp (right)
    can = [(cx - 132, 330), (cx - 104, 334), (cx - 106, 376), (cx - 134, 372)]
    plate(c, can, PAINT_R, line=1.8, grime=0.3)
    c.ink([(cx - 126, 340), (cx - 110, 368)], 1.2, wobble=0.3)
    roll = [(cx + 98, 336), (cx + 136, 330), (cx + 140, 360), (cx + 102, 368)]
    plate(c, roll, CANVAS_T, line=1.8, grime=0.2)
    for k in range(3):
        c.ink([(cx + 106 + k * 11, 334), (cx + 108 + k * 11, 365)], 1.0, wobble=0.6, alpha=150)
    # amber warning beacon + antenna
    c.fill_ellipse((cx + 56, 86, cx + 72, 102), AMBER, tex=0.2)
    c.ink_ellipse((cx + 56, 86, cx + 72, 102), 1.4)
    c.ink([(cx - 62, 92), (cx - 96, 52)], 1.4, wobble=0.6)
    c.desertize(dust=0.45, abrasion=0.45, bleach=0.35, seams=0.6, heat=[(cx - 62, 333, 34, 0.7), (cx + 62, 333, 34, 0.7)])
    c.save(out("mech.hull"))


def gen_mech_leg():
    c = canvas_for("mech.leg", 202)
    W, H = 128, 300
    cx = W / 2
    # foot pad with three splayed toes (bottom = rear when facing up? the foot sits forward)
    for dx, ang in ((-30, -0.35), (0, 0), (30, 0.35)):
        toe = [(cx + dx - 11, 30), (cx + dx + 11, 30), (cx + dx + 14 + ang * 20, 4), (cx + dx - 14 + ang * 20, 4)]
        plate(c, toe, STEEL_D, line=2.0, grime=0.2, hatch_alpha=60)
    pad = blob(cx, 52, 50, 30, 18, 0.05, 2)
    plate(c, pad, STEEL, line=2.6, grime=0.4)
    # lower strut + piston
    strut = [(cx - 14, 70), (cx + 14, 70), (cx + 12, 168), (cx - 12, 168)]
    plate(c, strut, CHAR, line=2.0, grime=0.2)
    c.fill([(cx + 18, 80), (cx + 26, 80), (cx + 26, 160), (cx + 18, 160)], STEEL_L, tex=0.2)
    c.ink([(cx + 22, 80), (cx + 22, 160)], 1.0, alpha=140, color=(230, 220, 200))
    c.ink_poly([(cx + 18, 80), (cx + 26, 80), (cx + 26, 160), (cx + 18, 160)], 1.4)
    # knee joint
    c.fill_ellipse((cx - 26, 152, cx + 26, 204), RUST, tex=0.35)
    c.shade(c.ellipse_mask((cx - 26, 152, cx + 26, 204)), 1, .6, 4, 80)
    c.ink_ellipse((cx - 26, 152, cx + 26, 204), 2.4)
    c.fill_ellipse((cx - 9, 169, cx + 9, 187), STEEL_D, tex=0.1)
    # thigh armour plate (faded yellow) up to the hip
    thigh = [(cx - 34, 196), (cx + 34, 196), (cx + 40, 270), (cx + 22, 296), (cx - 22, 296), (cx - 40, 270)]
    plate(c, thigh, PAINT_Y, line=2.6, grime=0.5)
    bolts_along(c, thigh, 20, 6)
    c.fill([(cx - 30, 214), (cx + 30, 214), (cx + 30, 224), (cx - 30, 224)], CHAR, tex=0.3)
    c.desertize(dust=0.6, abrasion=0.5, bleach=0.35, seams=0.6)
    c.save(out("mech.leg"))


def gen_mech_radiator():
    c = canvas_for("mech.radiator", 303)
    W, H = 300, 128
    frame = rrect(4, 6, W - 4, H - 6, 10, 0.6, 1)
    m = plate(c, frame, STEEL_D, line=3.0, grime=0.3, hatch_alpha=70)
    core = [(20, 20), (W - 20, 20), (W - 20, H - 20), (20, H - 20)]
    c.fill(core, (64, 62, 56), tex=0.3, cell=6)
    # fins: dense vertical lines (the cooling surface)
    for i in range(52):
        x = 22 + i * (W - 44) / 51
        c.ink([(x, 22), (x, H - 22)], 1.1, wobble=0.15, alpha=220)
        c.ink([(x + 1.6, 22), (x + 1.6, H - 22)], 0.7, wobble=0.1, alpha=90, color=(196, 186, 166))
    # two fans
    for fx in (W * 0.3, W * 0.7):
        r = 38
        c.fill_ellipse((fx - r, H / 2 - r, fx + r, H / 2 + r), (40, 36, 32), tex=0.2)
        for k in range(6):
            a = k / 6 * math.tau
            blade = [(fx, H / 2), (fx + math.cos(a) * r * .95, H / 2 + math.sin(a) * r * .95), (fx + math.cos(a + .5) * r * .85, H / 2 + math.sin(a + .5) * r * .85)]
            c.fill(blade, STEEL_L, tex=0.2)
            c.ink_poly(blade, 1.0, alpha=200)
        c.fill_ellipse((fx - 8, H / 2 - 8, fx + 8, H / 2 + 8), RUST, tex=0.1)
        c.ink_ellipse((fx - r, H / 2 - r, fx + r, H / 2 + r), 2.2)
        c.ink([(fx - r, H / 2), (fx + r, H / 2)], 1.6)  # guard bar
        c.ink([(fx, H / 2 - r), (fx, H / 2 + r)], 1.6)
    # coolant inlet/outlet fittings (bright accent)
    for x in (10, W - 10):
        c.fill_ellipse((x - 8, 14, x + 8, 30), COOLANT, tex=0.2)
        c.ink_ellipse((x - 8, 14, x + 8, 30), 1.4)
    c.rivets([(12, 60), (12, 100), (W - 12, 60), (W - 12, 100)], 1.8)
    c.desertize(dust=0.3, abrasion=0.4, bleach=0.25, seams=0.5, heat=[(W * .5, H * .5, 110, 0.45)])
    c.save(out("mech.radiator"))


def gen_mech_radiator_damage():
    """Overlay only: bent fins, sand clog, cracks, coolant stains (opacity = damage)."""
    c = canvas_for("mech.radiator_damage", 304)
    W, H = 300, 128
    r = random.Random(5)
    # sand clogging the fins
    for k in range(7):
        bx, by = r.uniform(30, W - 30), r.uniform(28, H - 28)
        pb = blob(bx, by, r.uniform(14, 30), r.uniform(8, 16), 14, 0.35, k)
        c.fill(pb, (184, 150, 104), tex=0.6, cell=4)
        c.ink_poly(pb, 0.8, alpha=90)
    # coolant leak stain
    st = blob(W * .62, H * .7, 30, 14, 16, 0.4, 9)
    c.fill(st, (78, 120, 108), tex=0.5)
    c.ink_poly(st, 0.8, alpha=90)
    # bent fins + cracks
    for k in range(6):
        x = r.uniform(30, W - 30)
        c.ink([(x, 24), (x + r.uniform(-8, 8), H / 2), (x + r.uniform(-12, 12), H - 24)], 2.0, wobble=1.2, alpha=230)
    for k in range(3):
        x, y = r.uniform(40, W - 40), r.uniform(30, H - 30)
        c.ink([(x, y), (x + 14, y + 6), (x + 22, y + 2), (x + 34, y + 12)], 1.4, wobble=0.8)
    # soot on the fan hubs
    for fx in (W * .3, W * .7):
        c.soft_shadow((fx - 26, H / 2 - 20, fx + 26, H / 2 + 20), 120, 4)
    c.save(out("mech.radiator_damage"), finish=False)


def gen_mech_shutters():
    c = canvas_for("mech.shutters", 305)
    W, H = 320, 144
    frame = rrect(4, 4, W - 4, H - 4, 8, 0.5, 2)
    plate(c, frame, STEEL_D, line=3.0, grime=0.3)
    n = 6
    for i in range(n):
        y0 = 12 + i * (H - 24) / n
        y1 = y0 + (H - 24) / n + 4
        slat = [(14, y0), (W - 14, y0 + 1), (W - 14, y1), (14, y1 - 1)]
        m = plate(c, slat, PAINT_Y if i % 3 else PAINT_G, line=1.8, grime=0.35, hatch_alpha=60)
        c.ink([(16, y1 - 2), (W - 16, y1 - 1)], 2.4, alpha=200)   # overlap shadow edge
        c.rivets([(24, (y0 + y1) / 2), (W - 24, (y0 + y1) / 2)], 1.8)
    for x in (W * 0.33, W * 0.66):
        c.fill([(x - 6, 6), (x + 6, 6), (x + 6, H - 6), (x - 6, H - 6)], STEEL, tex=0.2)
        c.ink_poly([(x - 6, 6), (x + 6, 6), (x + 6, H - 6), (x - 6, H - 6)], 1.4)
    # a stencil mark (worn)
    c.ink([(W * .45, 50), (W * .5, 70), (W * .55, 50)], 3.0, wobble=0.6, alpha=120, color=HOLE)
    c.desertize(dust=0.5, abrasion=0.7, bleach=0.5, seams=0.6)
    c.save(out("mech.shutters"))


# ======================================================================= PILOT
def gen_pilot():
    c = canvas_for("pilot.suit", 401)
    W, H = 92, 108
    cx = W / 2
    SUIT = (214, 200, 172)
    # backpack cooler (rear = bottom)
    pack = rrect(cx - 24, 62, cx + 24, 100, 6, 0.4, 3)
    plate(c, pack, STEEL, line=2.2, grime=0.3, hatch_alpha=70)
    c.slots(cx - 16, 70, cx + 16, 92, 5, vertical=True, width=1.4)
    c.fill_ellipse((cx - 22, 86, cx - 12, 96), COOLANT, tex=0.1)
    c.ink([(cx - 17, 86), (cx - 28, 70), (cx - 30, 54)], 2.4, wobble=0.3, color=(56, 110, 104), alpha=250)
    # arms
    for sx in (-1, 1):
        arm = [(cx + sx * 26, 40), (cx + sx * 36, 44), (cx + sx * 34, 22), (cx + sx * 26, 16)]
        plate(c, arm, SUIT, line=2.0, grime=0.2, hatch_alpha=60)
        c.fill_ellipse((cx + sx * 30 - 6, 8, cx + sx * 30 + 6, 20), CHAR, tex=0.2)  # gloves
        c.ink_ellipse((cx + sx * 30 - 6, 8, cx + sx * 30 + 6, 20), 1.4)
    # shoulders / torso
    torso = blob(cx, 52, 30, 20, 20, 0.05, 4)
    plate(c, torso, SUIT, line=2.6, grime=0.3, hatch_alpha=70)
    for sx in (-1, 1):
        c.ink([(cx + sx * 26, 46), (cx + sx * 18, 64)], 3.4, wobble=0.3, alpha=240, color=(196, 92, 44))  # orange hi-vis stripes
    # helmet with amber visor facing up
    c.fill_ellipse((cx - 18, 22, cx + 18, 58), BONE, tex=0.2, light=(-1, -1, 0.45))
    c.shade(c.ellipse_mask((cx - 18, 22, cx + 18, 58)), 1, .6, 3.5, 70)
    visor = [(cx - 14, 32), (cx - 6, 24), (cx + 6, 24), (cx + 14, 32), (cx + 10, 36), (cx - 10, 36)]
    c.fill(visor, (196, 130, 40), tex=0.3, light=(-1, -1, 0.6))
    c.ink([(cx - 8, 28), (cx - 2, 26)], 1.6, wobble=0.1, alpha=180, color=(255, 236, 190))
    c.ink_poly(visor, 1.6)
    c.ink_ellipse((cx - 18, 22, cx + 18, 58), 2.4)
    c.desertize(dust=0.4, abrasion=0.2, bleach=0.2, seams=0.4)
    c.save(out("pilot.suit"))


# ======================================================================= ROCKS / MINERALS
def rock(id_, seed, rx, ry, col=(176, 138, 98), strata=True):
    c = canvas_for(id_, seed)
    W, H = ALL[id_]["source"]
    cx, cy = W / 2, H / 2
    c.soft_shadow((cx - rx * .95, cy - ry * .85, cx + rx * 1.0, cy + ry * 1.0), 120, 6)  # contact darkening (non-directional)
    body = blob(cx, cy, rx * .9, ry * .86, 22, 0.16, seed)
    m = c.fill(body, col, tex=0.38, cell=16, light=(-1, -1, 0.45))
    # top face (lighter, flatter plateau toward the light)
    top = blob(cx - rx * .12, cy - ry * .14, rx * .55, ry * .5, 16, 0.2, seed + 1)
    c.fill(top, tuple(min(255, int(v * 1.12)) for v in col), tex=0.3, cell=12, light=(-1, -1, 0.3))
    c.shade(m, 1, .6, 4.5, 95, cross=True, reach=0.5)
    r = random.Random(seed)
    if strata:
        for k in range(4):
            y = cy - ry * .5 + k * ry * .32
            c.ink([(cx - rx * .7 + r.uniform(-6, 6), y + r.uniform(-4, 4)), (cx, y + r.uniform(-6, 6)), (cx + rx * .7, y + r.uniform(-4, 4))], 1.0, wobble=1.5, alpha=130)
    for k in range(3):
        x, y = cx + r.uniform(-rx * .5, rx * .5), cy + r.uniform(-ry * .5, ry * .5)
        c.ink([(x, y), (x + r.uniform(6, 16), y + r.uniform(4, 12)), (x + r.uniform(14, 26), y + r.uniform(0, 18))], 1.2, wobble=0.8, alpha=180)
    c.ink_poly(top, 1.4, alpha=150)
    c.ink_poly(body, 2.8)
    c.desertize(dust=0.6, abrasion=0.5, bleach=0.15, seams=0.4, m=m)
    c.save(out(id_))


def gen_rocks():
    rock("prop.rock_large_a", 11, 140, 118)
    rock("prop.rock_large_b", 12, 112, 100, col=(160, 112, 80))
    rock("prop.rock_small_a", 13, 44, 38, strata=False)
    rock("prop.rock_small_b", 14, 34, 30, col=(150, 110, 82), strata=False)
    c = canvas_for("prop.stones", 15)
    r = random.Random(15)
    for k in range(9):
        x, y = r.uniform(18, 126), r.uniform(16, 88)
        rr = r.uniform(5, 12)
        b = blob(x, y, rr, rr * .8, 12, 0.2, k)
        m = c.fill(b, r.choice([(170, 134, 96), (140, 108, 80), (190, 160, 120)]), tex=0.3, cell=5, light=(-1, -1, 0.5))
        c.shade(m, 1, .6, 3.0, 80)
        c.ink_poly(b, 1.4)
    c.desertize(dust=0.5, abrasion=0.3, bleach=0.1, seams=0.2)
    c.save(out("prop.stones"))


def gen_minerals():
    # salt crust ridge ring with copper-salt (teal) flecks
    c = canvas_for("prop.mineral_a", 21)
    W, H = 168, 124
    r = random.Random(21)
    for k in range(14):
        a = k / 14 * math.tau
        x, y = W / 2 + math.cos(a) * 52 + r.uniform(-8, 8), H / 2 + math.sin(a) * 36 + r.uniform(-6, 6)
        cr = [(x, y - 10), (x + 8, y - 2), (x + 4, y + 8), (x - 6, y + 6), (x - 8, y - 4)]
        m = c.fill(cr, (232, 226, 210), tex=0.2, cell=4, light=(-1, -1, 0.6))
        c.shade(m, 1, .6, 3, 70)
        c.ink_poly(cr, 1.2, alpha=200)
    for k in range(10):
        x, y = W / 2 + r.uniform(-50, 50), H / 2 + r.uniform(-32, 32)
        c.fill_ellipse((x - 3, y - 3, x + 3, y + 3), (90, 170, 160), tex=0.1)
    c.save(out("prop.mineral_a"))
    # iron-oxide crust
    c = canvas_for("prop.mineral_b", 22)
    W, H = 124, 100
    b = blob(W / 2, H / 2, 50, 38, 20, 0.3, 22)
    m = c.fill(b, (170, 92, 56), tex=0.5, cell=6)
    for k in range(18):
        x, y = W / 2 + r.uniform(-40, 40), H / 2 + r.uniform(-28, 28)
        c.ink([(x, y), (x + r.uniform(-8, 8), y + r.uniform(-8, 8))], 1.0, wobble=0.6, alpha=160)
    c.shade(m, 1, .6, 4, 70)
    c.ink_poly(b, 1.6, alpha=200)
    c.desertize(dust=0.5, abrasion=0.1, bleach=0.2, seams=0.3)
    c.save(out("prop.mineral_b"))


# ======================================================================= ITEMS
def gen_items():
    c = canvas_for("item.radiator_core", 501)
    W = 84
    core = rrect(10, 16, 74, 68, 6, 0.4, 1)
    plate(c, core, STEEL, line=2.4, grime=0.2, hatch_alpha=70)
    c.fill([(16, 22), (68, 22), (68, 62), (16, 62)], (60, 58, 52), tex=0.2)
    for i in range(12):
        x = 18 + i * 4.3
        c.ink([(x, 23), (x, 61)], 1.0, wobble=0.1, alpha=220)
    for x in (12, 72):
        c.fill_ellipse((x - 7, 8, x + 7, 22), COOLANT, tex=0.1)
        c.ink_ellipse((x - 7, 8, x + 7, 22), 1.4)
    c.ink([(20, 26), (34, 24)], 2.0, alpha=170, color=(255, 246, 220))  # glint
    c.desertize(dust=0.3, abrasion=0.3, bleach=0.2, seams=0.4)
    c.save(out("item.radiator_core"))
    c = canvas_for("item.dropped_pack", 502)
    pk = blob(40, 38, 30, 24, 16, 0.12, 3)
    plate(c, pk, CANVAS_T, line=2.4, grime=0.4)
    c.ink([(18, 30), (62, 34)], 3.0, wobble=0.5, color=(196, 92, 44))
    c.fill_ellipse((46, 40, 58, 52), COOLANT, tex=0.1)
    c.ink([(22, 50), (38, 60), (52, 58)], 1.6, wobble=0.8)
    c.desertize(dust=0.6, abrasion=0.2, bleach=0.4, seams=0.3)
    c.save(out("item.dropped_pack"))


# ======================================================================= SHELTER
def gen_shelter_floor():
    """Concrete pad decal (low detail, no outline pass, sand creeping in at the edges)."""
    c = canvas_for("shelter.floor", 601)
    W, H = 1080, 840
    pad = rrect(30, 30, W - 30, H - 30, 22, 2.0, 4)
    m = c.fill(pad, (150, 138, 120), tex=0.25, cell=40, light=(-1, -1, 0.15))
    r = random.Random(4)
    # slab joints and cracks
    for x in (W / 3, 2 * W / 3):
        c.ink([(x, 40), (x + r.uniform(-4, 4), H / 2), (x, H - 40)], 1.4, wobble=0.6, alpha=120)
    c.ink([(40, H / 2), (W / 2, H / 2 + 4), (W - 40, H / 2)], 1.4, wobble=0.6, alpha=120)
    for k in range(10):
        x, y = r.uniform(80, W - 80), r.uniform(80, H - 80)
        pts = [(x, y)]
        for j in range(4):
            x += r.uniform(-30, 30); y += r.uniform(-30, 30)
            pts.append((x, y))
        c.ink(pts, 1.0, wobble=1.2, alpha=110)
    # oil and coolant stains, faded bay markings
    for k in range(6):
        st = blob(r.uniform(300, 800), r.uniform(250, 600), r.uniform(30, 80), r.uniform(20, 55), 16, 0.4, k)
        c.fill(st, (70, 62, 52), tex=0.5, cell=10)
    for x0 in (330, 760):
        c.ink([(x0, 120), (x0, H - 120)], 7.0, wobble=1.0, alpha=110, color=(206, 170, 80))
    c.ink([(330, 120), (760, 120)], 7.0, wobble=1.0, alpha=110, color=(206, 170, 80))
    # drain grate
    c.fill([(500, 380), (580, 380), (580, 460), (500, 460)], HOLE, tex=0.2)
    c.slots(502, 382, 578, 458, 8, vertical=True, width=1.6)
    c.ink_poly([(500, 380), (580, 380), (580, 460), (500, 460)], 2.0)
    # sand drifting in from the open (south and east) sides
    yy, xx = np.mgrid[0:H * SS, 0:W * SS]
    n = value_noise(W * SS, H * SS, 30 * SS, 9, 4)
    drift = np.clip(((yy / (H * SS)) * 0.7 + (xx / (W * SS)) * 0.5 - 0.62) * 2.2 + (n - 0.5) * 0.9, 0, 1)
    arr = np.asarray(c.img, np.float32)
    A = arr[..., 3:] / 255
    arr[..., :3] = arr[..., :3] * (1 - drift[..., None] * 0.85) + np.array(SAND_M) * drift[..., None] * 0.85
    c.img = Image.fromarray(arr.astype(np.uint8), "RGBA")
    c.grime(m, 0.3, streaks=10)
    c.desertize(dust=0.4, abrasion=0, bleach=0.1, seams=0.3)
    # soften the slab edge into the sand (decal)
    a = c.img.split()[3].filter(ImageFilter.GaussianBlur(6 * SS))
    c.img.putalpha(a)
    c.save(out("shelter.floor"), finish=False)


def gen_shelter_roof():
    """Patched corrugated roof + faded shade tarp; seen from above; holes let light through."""
    c = canvas_for("shelter.roof", 602)
    W, H = 1024, 806
    r = random.Random(6)
    # main beams under the sheets (visible at the eaves)
    for y in (24, H - 24):
        plate(c, [(6, y - 10), (W - 6, y - 10), (W - 6, y + 10), (6, y + 10)], RUST_D, hatch=False, line=2.0, grime=0.2)
    sheets = []
    cols = [(150, 128, 104), (128, 84, 56), (140, 120, 100), (118, 92, 70), (156, 136, 112), (122, 74, 48)]
    x = 14
    k = 0
    while x < W - 30:
        w = r.uniform(120, 170)
        x1 = min(W - 14, x + w)
        y0, y1 = r.uniform(30, 44), H - r.uniform(30, 44)
        poly = [(x + r.uniform(-3, 3), y0 + r.uniform(-4, 4)), (x1 + r.uniform(-3, 3), y0 + r.uniform(-4, 4)),
                (x1 + r.uniform(-3, 3), y1 + r.uniform(-4, 4)), (x + r.uniform(-3, 3), y1 + r.uniform(-4, 4))]
        if k == 3:  # the shade tarp section, faded sienna canvas
            m = c.fill(poly, CANVAS_T, tex=0.35, cell=20)
            for j in range(9):
                yy = y0 + (j + 1) * (y1 - y0) / 10
                c.ink([(x + 6, yy), ((x + x1) / 2, yy + r.uniform(4, 10)), (x1 - 6, yy)], 1.0, wobble=1.2, alpha=110)
            c.ink_poly(poly, 2.0)
        else:
            m = c.corrugate(poly, cols[k % len(cols)], spacing=10, vertical=False, alpha=100)
            c.ink_poly(poly, 2.4)
        c.shade(m, 1, .6, 5.0, 60, reach=0.4)
        sheets.append(poly)
        x = x1 - r.uniform(6, 14)   # overlap
        k += 1
    # bolt lines along purlins
    for y in (60, H / 2, H - 60):
        c.rivets([(xx, y + r.uniform(-2, 2)) for xx in range(30, W - 20, 34)], 2.2)
    # roof turbine vent + a solar trickle panel
    c.fill_ellipse((780, 140, 860, 220), STEEL_L, tex=0.2)
    for j in range(10):
        a = j / 10 * math.tau
        c.ink([(820, 180), (820 + math.cos(a) * 38, 180 + math.sin(a) * 38)], 1.4, wobble=0.2)
    c.ink_ellipse((780, 140, 860, 220), 2.4)
    pv = [(150, 520), (300, 512), (306, 620), (156, 630)]
    plate(c, pv, (54, 62, 72), line=2.2, grime=0.3)
    for j in range(1, 4):
        c.ink([(150 + j * 38, 516), (156 + j * 38, 626)], 1.0, alpha=160, color=(150, 160, 170))
    # holes / missing sheet corners (transparent)
    holes = [blob(r.uniform(150, 900), r.uniform(150, 650), r.uniform(10, 22), r.uniform(8, 16), 12, 0.3, j) for j in range(5)]
    c.desertize(dust=0.7, abrasion=0.35, bleach=0.55, seams=0.6)
    hm = Image.new("L", c.img.size, 255)
    for h in holes:
        ImageDraw.Draw(hm).polygon([(px * SS, py * SS) for px, py in h], fill=0)
    a = Image.fromarray(np.minimum(np.asarray(c.img.split()[3]), np.asarray(hm)).astype(np.uint8))
    c.img.putalpha(a)
    for h in holes:
        c.ink_poly(h, 1.8)
    c.save(out("shelter.roof"))


def gen_flag():
    c = canvas_for("shelter.flag", 610)
    W, H = 220, 80
    c.fill_ellipse((4, 28, 28, 52), STEEL_D, tex=0.2)
    c.ink_ellipse((4, 28, 28, 52), 2.0)
    cloth = [(18, 30), (120, 24), (200, 30), (214, 36), (196, 44), (206, 52), (120, 56), (18, 50)]
    m = c.fill(cloth, (190, 78, 44), tex=0.4, cell=8)
    c.shade(m, 0, 1, 4, 70)
    for x in (60, 110, 160):
        c.ink([(x, 28), (x + 4, 52)], 0.9, wobble=0.8, alpha=120)
    c.ink_poly(cloth, 1.8)
    c.desertize(dust=0.3, abrasion=0.2, bleach=0.55, seams=0.2)
    c.save(out("shelter.flag"))


def gen_shelter_bits():
    c = canvas_for("shelter.post", 603)
    c.soft_shadow((10, 10, 60, 60), 110, 4)
    c.fill_ellipse((14, 14, 54, 54), RUST, tex=0.3)
    c.fill_ellipse((22, 22, 46, 46), HOLE, tex=0.1)
    c.ink_ellipse((14, 14, 54, 54), 2.4)
    c.desertize(dust=0.4, abrasion=0.4, bleach=0.2, seams=0.3)
    c.save(out("shelter.post"))
    for id_, vertical in (("shelter.wall_h", False), ("shelter.wall_v", True)):
        c = canvas_for(id_, 604 + vertical)
        W, H = ALL[id_]["source"]
        poly = [(8, 18), (W - 8, 18), (W - 8, H - 18), (8, H - 18)] if not vertical else [(18, 8), (W - 18, 8), (W - 18, H - 8), (18, H - 8)]
        c.corrugate(poly, (132, 104, 80), spacing=12, vertical=not vertical, alpha=110)
        c.ink_poly(poly, 2.6)
        L = W if not vertical else H
        for k in range(0, int(L), 120):
            if vertical:
                c.fill([(10, k + 8), (W - 10, k + 8), (W - 10, k + 26), (10, k + 26)], STEEL_D, tex=0.2)
                c.ink_poly([(10, k + 8), (W - 10, k + 8), (W - 10, k + 26), (10, k + 26)], 1.6)
            else:
                c.fill([(k + 8, 10), (k + 26, 10), (k + 26, H - 10), (k + 8, H - 10)], STEEL_D, tex=0.2)
                c.ink_poly([(k + 8, 10), (k + 26, 10), (k + 26, H - 10), (k + 8, H - 10)], 1.6)
        c.desertize(dust=0.7, abrasion=0.5, bleach=0.4, seams=0.5)
        c.save(out(id_))
    # workbench
    c = canvas_for("shelter.workbench", 606)
    top = rrect(8, 10, 260, 122, 6, 0.6, 2)
    plate(c, top, (122, 94, 66), line=2.6, grime=0.5)
    for y in (40, 70, 100):
        c.ink([(14, y), (254, y + 2)], 1.0, wobble=0.6, alpha=120)
    plate(c, [(20, 30), (60, 30), (60, 70), (20, 70)], STEEL, line=1.8, grime=0.2)  # vise
    c.ink([(90, 50), (150, 40)], 4.0, wobble=0.2, color=STEEL_D)  # wrench
    c.ink_ellipse((146, 32, 162, 48), 2.2, color=STEEL_D)
    for k in range(6):  # bolts / parts
        x, y = 180 + (k % 3) * 18, 34 + (k // 3) * 20
        c.fill_ellipse((x - 5, y - 5, x + 5, y + 5), STEEL_L, tex=0.1)
        c.ink_ellipse((x - 5, y - 5, x + 5, y + 5), 1.0)
    plate(c, blob(110, 92, 28, 14, 12, 0.3, 3), (176, 70, 50), line=1.4, grime=0.1, hatch=False)  # rag
    c.desertize(dust=0.5, abrasion=0.2, bleach=0.3, seams=0.5)
    c.save(out("shelter.workbench"))
    # tool rack along the wall
    c = canvas_for("shelter.toolrack", 607)
    plate(c, [(8, 6), (72, 6), (72, 294), (8, 294)], (110, 86, 62), line=2.2, grime=0.4)
    for k, col in enumerate([PAINT_R, STEEL_L, PAINT_Y, STEEL, COOLANT]):
        y = 20 + k * 54
        plate(c, rrect(16, y, 64, y + 40, 4, 0.4, k), col, line=1.6, grime=0.3, hatch_alpha=50)
    c.desertize(dust=0.5, abrasion=0.2, bleach=0.4, seams=0.4)
    c.save(out("shelter.toolrack"))
    # barrels (one coolant drum = precious accent)
    c = canvas_for("shelter.barrels", 608)
    for (x, y, col) in ((62, 62, RUST), (132, 70, (60, 120, 112)), (88, 136, PAINT_R), (150, 140, STEEL)):
        c.soft_shadow((x - 34, y - 32, x + 38, y + 40), 110, 4)
        c.fill_ellipse((x - 32, y - 32, x + 32, y + 32), col, tex=0.35, light=(-1, -1, 0.45))
        c.shade(c.ellipse_mask((x - 32, y - 32, x + 32, y + 32)), 1, .6, 4, 80)
        c.ink_ellipse((x - 25, y - 25, x + 25, y + 25), 1.2, alpha=170)
        c.fill_ellipse((x + 6, y - 18, x + 16, y - 8), CHAR, tex=0.1)
        c.ink_ellipse((x - 32, y - 32, x + 32, y + 32), 2.6)
    c.desertize(dust=0.6, abrasion=0.4, bleach=0.45, seams=0.4)
    c.save(out("shelter.barrels"))
    # water cistern
    c = canvas_for("shelter.cistern", 609)
    c.soft_shadow((14, 18, 246, 250), 120, 8)
    c.fill_ellipse((16, 16, 240, 240), (150, 150, 136), tex=0.35, cell=20, light=(-1, -1, 0.5))
    m = c.ellipse_mask((16, 16, 240, 240))
    c.shade(m, 1, .6, 5, 80, cross=True, reach=0.45)
    for rr in (96, 70):
        c.ink_ellipse((128 - rr, 128 - rr, 128 + rr, 128 + rr), 1.2, alpha=150)
    c.fill_ellipse((104, 104, 152, 152), STEEL_D, tex=0.2)
    c.ink_ellipse((104, 104, 152, 152), 2.0)
    c.ink([(128, 30), (128, 100)], 2.0, alpha=160)
    c.ink([(40, 150), (12, 200), (2, 250)], 5.0, wobble=0.4, color=(48, 92, 88))  # outlet pipe
    c.ink([(70, 60), (180, 60)], 9.0, wobble=0.8, alpha=150, color=(196, 92, 44))  # faded stencil band
    c.ink_ellipse((16, 16, 240, 240), 3.0)
    c.desertize(dust=0.5, abrasion=0.5, bleach=0.5, seams=0.5)
    c.save(out("shelter.cistern"))


# ======================================================================= WRECKS / DEBRIS
def truss(c, x0, y0, x1, y1, w, col=RUST, n=8, seed=0):
    """Lattice girder from (x0,y0) to (x1,y1), width w (top-down)."""
    dx, dy = x1 - x0, y1 - y0
    L = math.hypot(dx, dy)
    nx, ny = -dy / L * w / 2, dx / L * w / 2
    for sgn in (-1, 1):
        a = (x0 + nx * sgn, y0 + ny * sgn); b = (x1 + nx * sgn, y1 + ny * sgn)
        c.ink([a, b], 5.0, wobble=0.4, color=col, alpha=255)
        c.ink([a, b], 1.6, wobble=0.4)
    for i in range(n + 1):
        t = i / n
        p = (x0 + dx * t, y0 + dy * t)
        c.ink([(p[0] - nx, p[1] - ny), (p[0] + nx, p[1] + ny)], 2.0, wobble=0.3, color=col)
        if i < n:
            q = (x0 + dx * (t + 1 / n), y0 + dy * (t + 1 / n))
            s_ = 1 if i % 2 else -1
            c.ink([(p[0] + nx * s_, p[1] + ny * s_), (q[0] - nx * s_, q[1] - ny * s_)], 1.8, wobble=0.4, color=col)


def gen_pump_rig():
    c = canvas_for("wreck.pump_rig", 701)
    W, H = 720, 580
    r = random.Random(7)
    c.soft_shadow((60, 60, 680, 540), 90, 18)
    # skid base
    base = [(70, 120), (640, 96), (660, 470), (90, 500)]
    m = plate(c, base, STEEL_D, line=3.0, grime=0.5, hatch_alpha=60)
    c.corrugate([(90, 140), (300, 132), (308, 300), (98, 310)], (108, 96, 84), spacing=12, vertical=True)
    c.ink_poly([(90, 140), (300, 132), (308, 300), (98, 310)], 2.2)
    # big pump housing (cylinder lying on its side)
    hous = [(330, 150), (600, 140), (610, 300), (340, 314)]
    m = plate(c, hous, PAINT_G, line=3.0, grime=0.6)
    for x in (380, 450, 520, 580):
        c.ink([(x, 146), (x + 4, 308)], 2.6, wobble=0.6)
    bolts_along(c, hous, 26, 8)
    # flywheel
    c.fill_ellipse((200, 330, 330, 460), RUST, tex=0.4)
    c.shade(c.ellipse_mask((200, 330, 330, 460)), 1, .6, 4.5, 90)
    for j in range(6):
        a = j / 6 * math.tau + 0.3
        c.ink([(265, 395), (265 + math.cos(a) * 58, 395 + math.sin(a) * 58)], 3.0, wobble=0.4)
    c.ink_ellipse((200, 330, 330, 460), 3.0)
    c.fill_ellipse((250, 380, 280, 410), STEEL_D, tex=0.1)
    # collapsed derrick truss across the site
    truss(c, 120, 520, 610, 40, 46, n=11)
    truss(c, 420, 560, 700, 330, 30, col=RUST_D, n=6)
    # broken pipes
    for (a, b) in (((610, 220), (708, 250)), ((340, 240), (250, 200)), ((560, 300), (520, 410))):
        c.ink([a, b], 14, wobble=0.6, color=RUST_D)
        c.ink([a, b], 2.2, wobble=0.6)
        c.fill_ellipse((b[0] - 9, b[1] - 9, b[0] + 9, b[1] + 9), HOLE, tex=0.1)
    # open radiator bay (south-west, where the core is salvaged) with coolant stain
    bay = [(110, 380), (200, 372), (206, 470), (116, 478)]
    c.fill(bay, HOLE, tex=0.2)
    c.slots(118, 384, 198, 468, 9, vertical=True, width=1.4, alpha=200)
    c.ink_poly(bay, 2.4)
    c.fill(blob(150, 500, 50, 22, 14, 0.4, 3), (70, 110, 100), tex=0.4)
    c.ink([(110, 380), (60, 340), (40, 360)], 3.0, wobble=1.0, color=STEEL)  # torn-off panel hinge
    plate(c, [(20, 300), (80, 290), (96, 350), (30, 366)], PAINT_Y, line=2.2, grime=0.4)
    # sand drift over the windward corner
    drift = blob(640, 470, 120, 70, 20, 0.25, 9)
    c.fill(drift, SAND_M, tex=0.3, cell=14)
    for j in range(4):
        c.ink([(560 + j * 16, 440 + j * 12), (700, 430 + j * 18)], 1.0, wobble=1.0, alpha=100)
    c.desertize(dust=0.7, abrasion=0.6, bleach=0.5, seams=0.7, heat=[(470, 220, 90, 0.35)])
    c.save(out("wreck.pump_rig"))


def gen_hauler():
    c = canvas_for("wreck.hauler", 702)
    W, H = 640, 420
    c.soft_shadow((40, 50, 600, 390), 100, 16)
    # chassis rails
    for y in (130, 290):
        plate(c, [(60, y - 12), (600, y - 12), (600, y + 12), (60, y + 12)], STEEL_D, hatch=False, line=2.0, grime=0.4)
    # cargo bed ribs (tarp long gone)
    bed = [(200, 80), (600, 74), (606, 346), (204, 340)]
    plate(c, bed, RUST, line=3.0, grime=0.7, hatch_alpha=70)
    for k in range(7):
        x = 230 + k * 52
        c.ink([(x, 82), (x + 2, 340)], 5.0, wobble=0.6, color=RUST_D)
        c.ink([(x, 82), (x + 2, 340)], 1.4, wobble=0.6)
    for k in range(3):
        y = 120 + k * 80
        c.ink([(206, y), (600, y - 3)], 1.2, wobble=1.0, alpha=140)
    # cab (faded red), roof caved in
    cab = [(40, 96), (190, 90), (196, 330), (46, 336)]
    m = plate(c, cab, PAINT_R, line=3.0, grime=0.6)
    win = [(60, 120), (110, 116), (114, 310), (64, 314)]
    c.fill(win, (40, 46, 46), tex=0.4)
    c.ink_poly(win, 2.0)
    c.ink([(130, 110), (150, 200), (128, 300)], 2.0, wobble=1.6)  # crumple
    # missing wheels: dark hub sockets
    for x in (100, 330, 520):
        for y in (60, 360):
            c.fill_ellipse((x - 22, y - 16, x + 22, y + 16), HOLE, tex=0.1)
            c.ink_ellipse((x - 22, y - 16, x + 22, y + 16), 2.0)
    # dune burying the rear corner
    for j, (bx, by, rx, ry) in enumerate(((560, 330, 140, 100), (470, 380, 120, 50))):
        d = blob(bx, by, rx, ry, 22, 0.2, j + 4)
        c.fill(d, SAND_L, tex=0.3, cell=18)
        c.shade(c.mask(d), 1, .6, 6, 50, reach=0.35)
        for k in range(4):
            c.ink([(bx - rx * .6, by - ry * .4 + k * 14), (bx + rx * .5, by - ry * .5 + k * 16)], 0.9, wobble=1.2, alpha=100)
    c.desertize(dust=0.8, abrasion=0.7, bleach=0.6, seams=0.6)
    c.save(out("wreck.hauler"))


def gen_debris():
    c = canvas_for("prop.pylon", 801)
    W, H = 420, 168
    c.soft_shadow((20, 40, 400, 150), 90, 8)
    truss(c, 20, 84, 400, 84, 70, n=9, col=(120, 84, 60))
    plate(c, [(360, 30), (410, 40), (404, 130), (356, 136)], STEEL, line=2.0, grime=0.4)  # insulator crossarm
    for y in (50, 84, 118):
        c.fill_ellipse((396, y - 7, 410, y + 7), BONE, tex=0.1)
        c.ink_ellipse((396, y - 7, 410, y + 7), 1.2)
    c.desertize(dust=0.5, abrasion=0.6, bleach=0.4, seams=0.5)
    c.save(out("prop.pylon"))
    c = canvas_for("prop.pipe", 802)
    W, H = 452, 124
    c.soft_shadow((20, 20, 436, 114), 110, 8)
    body = [(20, 22), (430, 18), (434, 100), (24, 106)]
    m = c.fill(body, RUST, tex=0.4, cell=14, light=(-1, -1, 0.5))
    c.shade(m, 0, 1, 4.5, 90, reach=0.45)
    c.ink([(24, 34), (428, 30)], 3.0, wobble=0.6, alpha=110, color=(230, 190, 150))  # highlight
    for x in (24, 160, 300, 428):
        c.fill([(x - 8, 12), (x + 8, 12), (x + 8, 112), (x - 8, 112)], RUST_D, tex=0.2)
        c.ink_poly([(x - 8, 12), (x + 8, 12), (x + 8, 112), (x - 8, 112)], 1.8)
    c.fill_ellipse((418, 26, 446, 98), HOLE, tex=0.1)
    c.ink_poly(body, 2.8)
    d = blob(220, 100, 150, 30, 18, 0.25, 3)
    c.fill(d, SAND_L, tex=0.3)
    c.desertize(dust=0.6, abrasion=0.5, bleach=0.3, seams=0.4)
    c.save(out("prop.pipe"))
    c = canvas_for("prop.scrap_pile", 803)
    r = random.Random(8)
    c.soft_shadow((20, 20, 216, 176), 100, 8)
    for k in range(9):
        x, y = r.uniform(50, 180), r.uniform(50, 140)
        w, h = r.uniform(30, 70), r.uniform(16, 40)
        a = r.uniform(0, math.pi)
        pts = [(x + math.cos(a) * dx - math.sin(a) * dy, y + math.sin(a) * dx + math.cos(a) * dy) for dx, dy in ((-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2))]
        plate(c, pts, r.choice([RUST, STEEL, PAINT_Y, PAINT_G, RUST_D]), line=1.8, grime=0.3, hatch_alpha=60)
    c.fill_ellipse((140, 100, 200, 160), CHAR, tex=0.3)  # old tyre
    c.fill_ellipse((156, 116, 184, 144), SAND_D, tex=0.2)
    c.ink_ellipse((140, 100, 200, 160), 2.4)
    c.desertize(dust=0.6, abrasion=0.4, bleach=0.5, seams=0.6)
    c.save(out("prop.scrap_pile"))
    c = canvas_for("prop.solar_wreck", 804)
    W, H = 336, 224
    c.soft_shadow((20, 20, 320, 210), 90, 8)
    frame = [(24, 30), (310, 22), (318, 196), (30, 204)]
    plate(c, frame, STEEL_L, line=2.6, grime=0.3)
    for i in range(4):
        for j in range(3):
            x0, y0 = 36 + i * 69, 36 + j * 54
            cell = [(x0, y0), (x0 + 64, y0 - 2), (x0 + 65, y0 + 48), (x0 + 1, y0 + 50)]
            c.fill(cell, (52, 62, 78), tex=0.3, light=(-1, -1, 0.5))
            c.ink_poly(cell, 1.2)
            if (i + j) % 3 == 0:
                c.ink([(x0 + 10, y0 + 6), (x0 + 30, y0 + 26), (x0 + 50, y0 + 20)], 1.0, wobble=1.0, alpha=200, color=(200, 210, 220))
    d = blob(260, 180, 110, 50, 18, 0.25, 6)
    c.fill(d, SAND_L, tex=0.3)
    c.desertize(dust=0.7, abrasion=0.4, bleach=0.4, seams=0.4)
    c.save(out("prop.solar_wreck"))


# ======================================================================= GROUND TILES (seamless, no finish)
def mark_layer(size):
    return Image.new("RGBA", (size * SS, size * SS), (0, 0, 0, 0))


def gen_tiles():
    S = 512
    # --- sand: three-step ochre ramp, wind ripples, pebbles, faint cracks
    t = Tile(S, 31)
    n = t.base((172, 134, 88), (202, 164, 112), (222, 190, 140), cell=110, octaves=5)
    r = t.rng
    marks = []
    for _ in range(90):
        x, y = r.uniform(0, S), r.uniform(0, S)
        L = r.uniform(12, 34)
        marks.append(("ripple", x, y, L))
    for _ in range(70):
        marks.append(("pebble", r.uniform(0, S), r.uniform(0, S), r.uniform(1.4, 3.6)))
    for _ in range(6):
        marks.append(("crack", r.uniform(0, S), r.uniform(0, S), r.uniform(18, 40)))
    c = t.c
    def draw(ox, oy):
        for kind, x, y, L in marks:
            x += ox; y += oy
            if not (-60 < x < S + 60 and -60 < y < S + 60):
                continue
            if kind == "ripple":
                c.ink([(x, y), (x + L * .5, y - 2), (x + L, y)], 0.8, wobble=0.5, alpha=60, seg=5)
                c.ink([(x + 1, y + 2), (x + L * .5 + 1, y), (x + L + 1, y + 2)], 0.8, wobble=0.4, alpha=50, color=(236, 212, 168), seg=5)
            elif kind == "pebble":
                c.fill_ellipse((x - L, y - L * .8, x + L, y + L * .8), (150, 118, 84), tex=0.2, cell=3)
                c.ink([(x - L * .3, y + L * .8), (x + L, y + L * .2)], 0.8, wobble=0.1, alpha=150)
            else:
                c.ink([(x, y), (x + L * .4, y + L * .3), (x + L, y + L * .2)], 0.8, wobble=0.8, alpha=70)
    t.wrap_draw(draw)
    t.save(out("ground.sand"))
    # --- dunes: strong ripple field (lighter crests, shadowed troughs), lower ink
    t = Tile(S, 32)
    t.base((182, 140, 92), (210, 172, 118), (230, 200, 150), cell=160, octaves=4)
    SSz = S * SS
    yy, xx = np.mgrid[0:SSz, 0:SSz].astype(np.float32)
    warp = value_noise(SSz, SSz, 90 * SS, 5, 3, wrap=True)
    phase = (yy / SSz * 2 * math.pi * 22 + xx / SSz * 2 * math.pi * 4 + warp * 9)
    rip = np.sin(phase)
    arr = np.asarray(t.c.img, np.float32)
    crest = np.clip(rip, 0, 1) ** 3
    trough = np.clip(-rip, 0, 1) ** 2
    arr[..., :3] = arr[..., :3] * (1 + crest[..., None] * 0.10 - trough[..., None] * 0.12)
    ink_line = (np.abs(np.cos(phase)) < 0.06) & (rip > 0)
    arr[..., :3] = np.where(ink_line[..., None], arr[..., :3] * 0.82 + np.array(INK) * 0.18, arr[..., :3])
    t.c.img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")
    t.save(out("ground.dunes"))
    # --- salt pan: pale crust, polygonal crack network (seamless Voronoi), mineral stains
    t = Tile(S, 33)
    t.base((196, 186, 166), (222, 214, 196), (238, 232, 218), cell=130, octaves=4, white=0.04)
    rr = np.random.default_rng(33)
    pts = rr.random((46, 2)) * S
    allp = np.concatenate([pts + [dx, dy] for dx in (-S, 0, S) for dy in (-S, 0, S)])
    yy, xx = np.mgrid[0:SSz, 0:SSz].astype(np.float32) / SS
    wx = (value_noise(SSz, SSz, 40 * SS, 61, 3, wrap=True) - .5) * 26   # domain warp → organic cracks
    wy = (value_noise(SSz, SSz, 40 * SS, 62, 3, wrap=True) - .5) * 26
    gx, gy = xx + wx, yy + wy
    best = np.full((SSz, SSz), np.inf, np.float32); lab = np.zeros((SSz, SSz), np.int32)
    for i, (px, py) in enumerate(allp):
        d = (gx - px) ** 2 + (gy - py) ** 2
        upd = d < best
        best = np.where(upd, d, best); lab = np.where(upd, i % len(pts), lab)
    edge = np.zeros((SSz, SSz), np.float32)
    for ax in (0, 1):
        edge = np.maximum(edge, (lab != np.roll(lab, 1, ax)).astype(np.float32))
    edge = np.asarray(Image.fromarray((edge * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2)), np.float32) / 255
    rim = np.asarray(Image.fromarray((edge * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(5)), np.float32) / 255
    arr = np.asarray(t.c.img, np.float32)
    arr[..., :3] = arr[..., :3] * (1 + rim[..., None] * 0.10) * (1 - np.clip(edge * 1.4, 0, 1)[..., None] * 0.32)
    stain = np.clip((value_noise(SSz, SSz, 70 * SS, 8, 3, wrap=True) - 0.62) * 3, 0, 1) * 0.35
    arr[..., :3] = arr[..., :3] * (1 - stain[..., None]) + np.array((176, 120, 84)) * stain[..., None]
    t.c.img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")
    t.save(out("ground.saltpan"))
    # --- track strip 256×128: compacted, rutted, soft transparent edges (tiles along x)
    W, H = 256, 128
    c = Canvas(W, H, 34)
    n = value_noise(W * SS, H * SS, 30 * SS, 34, 4, wrap=True)
    from inkkit import ramp3
    rgb = ramp3(n, (150, 114, 76), (176, 138, 94), (196, 160, 112))
    yy = np.mgrid[0:H * SS, 0:W * SS][0] / (H * SS)
    for ry in (0.32, 0.68):  # ruts
        rgb *= (1 - np.exp(-((yy - ry) / 0.05) ** 2) * 0.16)[..., None]
    alpha = np.clip(np.minimum(yy, 1 - yy) / 0.22, 0, 1) ** 1.5
    alpha *= np.clip(0.75 + (value_noise(W * SS, H * SS, 12 * SS, 35, 2, wrap=True) - 0.5) * 1.2, 0, 1)
    c.img = Image.fromarray(np.dstack([np.clip(rgb, 0, 255), alpha * 235]).astype(np.uint8), "RGBA")
    rr2 = random.Random(3)
    for k in range(40):  # tread marks across the ruts
        x = rr2.uniform(0, W); y0 = rr2.choice((0.32, 0.68)) * H
        for ox in (-W, 0, W):
            c.ink([(x + ox - 3, y0 - 7), (x + ox + 3, y0 + 7)], 1.0, wobble=0.2, alpha=70)
    c.img.resize((W, H), Image.LANCZOS).save(out("ground.track"))


# ======================================================================= FX textures (not creator-replaceable)
def gen_fx():
    fx = os.path.join(ROOT, "assets/fx")
    os.makedirs(fx, exist_ok=True)
    n = value_noise(256, 256, 8, 41, 3, wrap=True)
    wn = np.random.default_rng(41).random((256, 256))
    v = np.clip(128 + (n - .5) * 70 + (wn - .5) * 60, 0, 255).astype(np.uint8)
    Image.fromarray(v, "L").convert("RGB").save(os.path.join(fx, "grain.png"))
    n1 = value_noise(512, 512, 180, 42, 4, wrap=True); n2 = value_noise(512, 512, 60, 43, 3, wrap=True)
    a = np.clip((n1 * .8 + n2 * .4 - .45) * 2.2, 0, 1) * 200
    Image.fromarray(np.dstack([np.full((512, 512, 3), 235), a]).astype(np.uint8), "RGBA").save(os.path.join(fx, "haze.png"))
    sh = value_noise(256, 256, 32, 44, 3, wrap=True); sh2 = value_noise(256, 256, 16, 45, 2, wrap=True)
    Image.fromarray(np.dstack([sh * 255, sh2 * 255, np.full((256, 256), 128)]).astype(np.uint8), "RGB").save(os.path.join(fx, "shimmer.png"))
    yy, xx = np.mgrid[0:24, 0:24]
    d = np.sqrt((xx - 11.5) ** 2 + (yy - 11.5) ** 2) / 11.5
    Image.fromarray(np.dstack([np.full((24, 24, 3), 255), np.clip(1 - d, 0, 1) ** 1.5 * 255]).astype(np.uint8), "RGBA").save(os.path.join(fx, "soft_dot.png"))
    # dust mote: small elongated grain
    d2 = np.sqrt(((xx - 11.5) / 11.5) ** 2 + ((yy - 11.5) / 4.0) ** 2)
    Image.fromarray(np.dstack([np.full((24, 24, 3), 255), np.clip(1 - d2, 0, 1) * 255]).astype(np.uint8), "RGBA").save(os.path.join(fx, "dust_mote.png"))


GENS = [gen_flag, gen_items, gen_shelter_floor, gen_shelter_roof, gen_shelter_bits, gen_pump_rig, gen_hauler, gen_debris, gen_tiles, gen_fx, gen_mech_hull, gen_mech_leg, gen_mech_radiator, gen_mech_radiator_damage, gen_mech_shutters, gen_pilot, gen_rocks, gen_minerals]

if __name__ == "__main__":
    filt = sys.argv[1:]
    for g in GENS:
        if not filt or any(f in g.__name__ for f in filt):
            g()
            print("done", g.__name__)
