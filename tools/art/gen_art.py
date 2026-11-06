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
    """Lower chassis: frame, hip joints, turret ring, rear radiator rails, exhausts, strapped cargo."""
    c = canvas_for("mech.hull", 101)
    W, H = 400, 440
    cx = W / 2
    for sx in (-1, 1):
        x = cx + sx * 150
        c.fill_ellipse((x - 34, 186, x + 34, 254), STEEL_D, tex=0.3)
        c.ink_ellipse((x - 34, 186, x + 34, 254), 2.2)
        c.fill_ellipse((x - 16, 204, x + 16, 236), STEEL_L, tex=0.2)
        c.ink_ellipse((x - 16, 204, x + 16, 236), 1.4)
        # hip actuators reaching from the frame to the joints
        c.ink([(cx + sx * 100, 200), (cx + sx * 130, 210)], 9.0, wobble=0.3, color=STEEL_D, alpha=255)
        c.ink([(cx + sx * 100, 236), (cx + sx * 130, 228)], 9.0, wobble=0.3, color=STEEL_D, alpha=255)
    frame = [(cx - 120, 70), (cx + 120, 70), (cx + 150, 130), (cx + 150, 330), (cx + 118, 420), (cx - 118, 420), (cx - 150, 330), (cx - 150, 130)]
    m = c.fill(frame, CHAR, tex=0.35, cell=12)
    c.shade(m, 1, .6, 4.0, 90, cross=True)
    c.ink_poly(frame, 3.0)
    # cross members and floor plates visible around the housing
    for y in (96, 360):
        plate(c, [(cx - 110, y - 10), (cx + 110, y - 10), (cx + 110, y + 12), (cx - 110, y + 12)], STEEL_D, hatch=False, line=1.6, grime=0.3)
    for sx in (-1, 1):
        side = [(cx + sx * 104, 120), (cx + sx * 144, 140), (cx + sx * 144, 320), (cx + sx * 104, 336)]
        plate(c, side, RUST, line=2.0, grime=0.6, hatch_alpha=70)
        bolts_along(c, side, 24, 6)
    # turret ring (the housing sits on this bearing)
    c.fill_ellipse((cx - 98, 122, cx + 98, 318), STEEL, tex=0.3)
    c.ink_ellipse((cx - 98, 122, cx + 98, 318), 3.0)
    c.ink_ellipse((cx - 86, 134, cx + 86, 306), 1.4, alpha=170)
    c.rivets([(cx + math.cos(a) * 92, 220 + math.sin(a) * 92) for a in np.linspace(0, math.tau, 18, endpoint=False)], 1.8)
    for sx in (-1, 1):
        rail = [(cx + sx * 70 - 9, 330), (cx + sx * 70 + 9, 330), (cx + sx * 70 + 9, 438), (cx + sx * 70 - 9, 438)]
        plate(c, rail, STEEL_D, hatch=False, line=1.6, grime=0)
    for ex in (-62, 62):
        c.fill_ellipse((cx + ex - 15, 334, cx + ex + 15, 364), RUST, tex=0.4)
        c.fill_ellipse((cx + ex - 9, 340, cx + ex + 9, 358), HOLE, tex=0.1)
        c.ink_ellipse((cx + ex - 15, 334, cx + ex + 15, 364), 1.8)
    for sx in (-1, 1):
        pts = [(cx + sx * 40, 318), (cx + sx * 30, 380), (cx + sx * 44, 420)]
        c.ink(pts, 6.0, wobble=0.5, alpha=255, color=(48, 92, 88))
        c.ink(pts, 3.2, wobble=0.4, alpha=255, color=(78, 140, 130))
    can = [(cx - 132, 344), (cx - 104, 348), (cx - 106, 390), (cx - 134, 386)]
    plate(c, can, PAINT_R, line=1.8, grime=0.3)
    roll = [(cx + 98, 350), (cx + 136, 344), (cx + 140, 374), (cx + 102, 382)]
    plate(c, roll, CANVAS_T, line=1.8, grime=0.2)
    c.desertize(dust=0.5, abrasion=0.45, bleach=0.3, seams=0.6, heat=[(cx - 62, 349, 34, 0.7), (cx + 62, 349, 34, 0.7)])
    c.save(out("mech.hull"))


def gen_mech_housing():
    """Rotating upper housing: heavy armoured block with cockpit, vents and gun cheeks."""
    c = canvas_for("mech.housing", 107)
    W, H = 352, 368
    cx, cy = W / 2, H / 2
    body = [(cx - 96, 40), (cx + 96, 40), (cx + 140, 96), (cx + 146, 250), (cx + 110, 322), (cx - 110, 322), (cx - 146, 250), (cx - 140, 96)]
    m = plate(c, body, PAINT_Y, line=3.2, grime=0.55, hatch_alpha=95)
    bolts_along(c, body, 26, 9)
    # gun cheeks (heavy brackets, the guns attach outside at ±120)
    for sx in (-1, 1):
        ch = [(cx + sx * 118, 150), (cx + sx * 170, 158), (cx + sx * 170, 236), (cx + sx * 118, 244)]
        plate(c, ch, STEEL_D, line=2.6, grime=0.4, hatch_alpha=80)
        c.rivets([(cx + sx * 132, 168), (cx + sx * 156, 168), (cx + sx * 132, 226), (cx + sx * 156, 226)], 2.2)
    # central deck plate + vents
    deck = [(cx - 80, 150), (cx + 80, 150), (cx + 86, 300), (cx - 86, 300)]
    plate(c, deck, STEEL, line=2.4, grime=0.5, hatch_alpha=70)
    for vx in (-42, 42):
        g = [(cx + vx - 26, 196), (cx + vx + 26, 196), (cx + vx + 26, 276), (cx + vx - 26, 276)]
        c.fill(g, HOLE, tex=0.2)
        c.slots(cx + vx - 22, 200, cx + vx + 22, 272, 8, vertical=False, width=2.0, alpha=230)
        c.ink_poly(g, 1.8)
    # hazard chevrons on the front armour
    for k in range(4):
        x0 = cx - 120 + k * 22
        c.fill([(x0, 108), (x0 + 12, 108), (x0 + 24, 136), (x0 + 12, 136)], CHAR, tex=0.4)
    for k in range(4):
        x0 = cx + 54 + k * 22
        c.fill([(x0, 108), (x0 + 12, 108), (x0 + 24, 136), (x0 + 12, 136)], CHAR, tex=0.4)
    # cockpit at the front: armoured shell with canopy and visor slit
    pod = blob(cx, 92, 62, 52, 24, 0.04, 7)
    plate(c, pod, PAINT_G, line=3.0, grime=0.4, hatch_alpha=90)
    canopy = blob(cx, 84, 40, 30, 20, 0.03, 8)
    c.fill(canopy, (52, 66, 66), tex=0.5, cell=8, light=(-1, -1, 0.5))
    c.ink([(cx - 26, 72), (cx - 12, 64)], 3.0, wobble=0.3, alpha=150, color=(214, 226, 210))
    c.ink_poly(canopy, 2.4)
    c.ink([(cx - 30, 46), (cx + 30, 46)], 5.0, wobble=0.4, alpha=245, color=HOLE)
    # welded patch, beacon, antenna, cable bundle
    plate(c, [(cx + 92, 262), (cx + 128, 258), (cx + 130, 300), (cx + 96, 306)], STEEL_L, line=1.6, grime=0.2)
    c.fill_ellipse((cx + 64, 40, cx + 82, 58), AMBER, tex=0.2)
    c.ink_ellipse((cx + 64, 40, cx + 82, 58), 1.4)
    c.ink([(cx - 70, 60), (cx - 104, 18)], 1.6, wobble=0.6)
    c.ink([(cx - 60, 300), (cx - 100, 286), (cx - 124, 236)], 4.0, wobble=0.8, color=CHAR)
    c.desertize(dust=0.45, abrasion=0.5, bleach=0.35, seams=0.65)
    c.save(out("mech.housing"))


def gen_twin_gun():
    """Heavy side gun (left; mirrored for the right). Mount bracket at 62 % height."""
    c = canvas_for("mech.twin_gun", 108)
    W, H = 112, 300
    cx, my = W / 2, 186
    c.soft_shadow((cx - 40, my - 30, cx + 44, my + 100), 90, 6)
    box = rrect(cx - 40, my - 20, cx + 40, my + 100, 8, 0.6, 2)   # receiver / ammo box
    plate(c, box, RUST, line=2.8, grime=0.6, hatch_alpha=90)
    c.rivets([(cx - 30, my - 8), (cx + 30, my - 8), (cx - 30, my + 88), (cx + 30, my + 88)], 2.2)
    c.ink([(cx - 30, my + 40), (cx + 30, my + 40)], 2.0, wobble=0.4)
    feed = [(cx + 20, my + 60), (cx + 54, my + 64), (cx + 54, my + 96), (cx + 20, my + 96)]
    plate(c, feed, PAINT_G, line=2.0, grime=0.4)
    barrel = [(cx - 15, my - 20), (cx + 15, my - 20), (cx + 12, 22), (cx - 12, 22)]
    plate(c, barrel, STEEL, line=2.6, grime=0.4, hatch_alpha=80)
    for y in range(40, int(my - 30), 16):   # cooling jacket
        c.ink([(cx - 19, y), (cx + 19, y)], 3.0, wobble=0.25)
    c.ink([(cx - 4, 30), (cx - 4, my - 26)], 1.4, alpha=120, color=(220, 210, 190))
    brake = [(cx - 19, 4), (cx + 19, 4), (cx + 19, 26), (cx - 19, 26)]
    plate(c, brake, CHAR, line=2.2, grime=0.2, hatch=False)
    for x in (cx - 12, cx, cx + 12):
        c.ink([(x, 8), (x, 22)], 1.6, color=HOLE)
    c.desertize(dust=0.4, abrasion=0.5, bleach=0.3, seams=0.6, heat=[(cx, 40, 40, 0.65)])
    c.save(out("mech.twin_gun"))


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


# ======================================================================= ENEMY SCRAPPER
ENEMY_RED = (142, 62, 42)
OXIDE = (118, 70, 50)


def draw_scrapper(c, cx, cy, wrecked=False, seed=0, junker=False):
    """Top-down hostile scrapper centred at (cx, cy), facing up (source px)."""
    r = random.Random(seed)
    j = (lambda v: v + r.uniform(-6, 6)) if wrecked else (lambda v: v)
    # chassis spine
    spine = [(cx - 52, cy - 120), (cx + 50, cy - 118), (cx + 70, cy + 70), (cx + 60, cy + 150), (cx - 60, cy + 150), (cx - 72, cy + 70)]
    m = plate(c, [(j(x), j(y)) for x, y in spine], CHAR, line=3.0, grime=0.5, hatch_alpha=90)
    # crude cannon: a pipe welded on, protruding forward
    bx = cx + 6
    barrel = [(bx - 11, cy - 70), (bx + 11, cy - 70), (bx + 10, cy - 168), (bx - 10, cy - 168)]
    if wrecked:
        barrel = [(bx - 11, cy - 70), (bx + 11, cy - 70), (bx + 34, cy - 140), (bx + 16, cy - 146)]
    plate(c, barrel, RUST_D, line=2.4, grime=0.4, hatch_alpha=70)
    for k in range(3):
        y = cy - 90 - k * 22
        c.ink([(bx - 14, y), (bx + 14, y)], 3.0, wobble=0.6, color=STEEL_D)
    end = barrel[2]
    c.fill_ellipse((end[0] - 14, end[1] - 6, end[0] + 4, end[1] + 10), HOLE, tex=0.1)
    # armour: mismatched welded plates (oxide red, bare steel, rust) with raider stripes
    pc = (JK_ORANGE, JK_BLACK, STEEL) if junker else (ENEMY_RED, OXIDE, STEEL)
    plates = [([(cx - 70, cy - 70), (cx - 10, cy - 84), (cx - 6, cy + 20), (cx - 76, cy + 30)], pc[0]),
              ([(cx + 2, cy - 66), (cx + 66, cy - 60), (cx + 74, cy + 34), (cx + 6, cy + 24)], pc[1]),
              ([(cx - 40, cy + 22), (cx + 44, cy + 26), (cx + 40, cy + 70), (cx - 44, cy + 68)], pc[2])]
    for poly, col in plates:
        poly = [(j(x), j(y)) for x, y in poly]
        plate(c, poly, col, line=2.4, grime=0.6, hatch_alpha=80)
        bolts_along(c, poly, 20, 6)
    for k in range(3):
        y = cy - 50 + k * 22
        c.ink([(cx - 64, y), (cx - 22, y - 10)], 5.0, wobble=0.8, alpha=200, color=(BONE if junker else HOLE))
    if junker:
        insignia(c, cx + 38, cy - 18, 24, BONE, 220)
        for k in range(4):   # welded ram bars across the front
            x = cx - 54 + k * 34
            c.ink([(x, cy - 124), (x + 10, cy - 146)], 4.0, wobble=0.4, color=STEEL_D)
    # cockpit: small boxy cab offset left with a viewing slit
    cab = [(cx - 54, cy - 116), (cx - 14, cy - 118), (cx - 12, cy - 74), (cx - 56, cy - 72)]
    plate(c, [(j(x), j(y)) for x, y in cab], STEEL_L, line=2.4, grime=0.4)
    c.ink([(cx - 48, cy - 106), (cx - 20, cy - 108)], 4.0, wobble=0.3, color=HOLE)
    # scrap spikes / bars on the shoulders
    for sx in (-1, 1):
        for k in range(3):
            y = cy - 30 + k * 26
            c.ink([(cx + sx * 74, y), (cx + sx * 92, y - 8)], 3.0, wobble=0.4, color=STEEL_D)
    # EXPOSED RADIATOR on the back (the cooling hit area): frame, fins, fan, coolant hoses
    ry = cy + 116
    rad = [(cx - 52, ry - 34), (cx + 52, ry - 34), (cx + 54, ry + 32), (cx - 54, ry + 32)]
    plate(c, rad, STEEL_D, line=2.8, grime=0.3, hatch=False)
    c.fill([(cx - 46, ry - 28), (cx + 46, ry - 28), (cx + 46, ry + 26), (cx - 46, ry + 26)], (60, 58, 52), tex=0.2)
    for i in range(22):
        x = cx - 44 + i * 4.2
        c.ink([(x, ry - 26), (x, ry + 24)], 1.0, wobble=0.15, alpha=210)
    if not wrecked:
        c.fill_ellipse((cx - 22, ry - 22, cx + 22, ry + 22), (40, 36, 32), tex=0.2)
        for k in range(5):
            a = k / 5 * math.tau
            c.fill([(cx, ry), (cx + math.cos(a) * 20, ry + math.sin(a) * 20), (cx + math.cos(a + .55) * 18, ry + math.sin(a + .55) * 18)], STEEL_L, tex=0.1)
        c.ink_ellipse((cx - 22, ry - 22, cx + 22, ry + 22), 2.0)
    else:
        for k in range(5):
            x = cx + r.uniform(-40, 40)
            c.ink([(x, ry - 26), (x + r.uniform(-10, 10), ry + 24)], 2.2, wobble=1.4)
    for sx in (-1, 1):
        c.ink([(cx + sx * 30, cy + 40), (cx + sx * 50, cy + 80), (cx + sx * 50, ry - 30)], 5.0, wobble=0.5, color=(48, 92, 88), alpha=255)
        c.ink([(cx + sx * 30, cy + 40), (cx + sx * 50, cy + 80), (cx + sx * 50, ry - 30)], 2.6, wobble=0.4, color=COOLANT, alpha=255)
    c.ink_poly(rad, 2.8)


JK_ORANGE = (188, 96, 42)
JK_BLACK = (44, 38, 33)
JK_RUST = (120, 60, 34)


def insignia(c, cx, cy, r, col, alpha=230):
    """Southern Junkers mark: a stencilled cog with a south-pointing chevron."""
    teeth = 10
    pts = []
    for k in range(teeth * 2):
        a = k / (teeth * 2) * math.tau
        rr = r if k % 2 == 0 else r * 0.8
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    layer_poly = pts
    c.fill(layer_poly, col, tex=0.15, cell=4)
    c.fill_ellipse((cx - r * 0.55, cy - r * 0.55, cx + r * 0.55, cy + r * 0.55), JK_BLACK, tex=0.2)
    c.fill([(cx - r * 0.4, cy - r * 0.2), (cx, cy + r * 0.38), (cx + r * 0.4, cy - r * 0.2), (cx + r * 0.22, cy - r * 0.3), (cx, cy), (cx - r * 0.22, cy - r * 0.3)], col, tex=0.15)
    c.ink_poly(layer_poly, 1.2, alpha=150)


def gen_enemy():
    c = canvas_for("enemy.hull", 901)
    draw_scrapper(c, 150, 166)
    c.desertize(dust=0.5, abrasion=0.5, bleach=0.3, seams=0.7, heat=[(156, 60, 40, 0.5)])
    c.save(out("enemy.hull"))
    c = canvas_for("enemy.leg", 902)
    W, H = 92, 208
    cx = W / 2
    for dx in (-18, 18):
        toe = [(cx + dx - 9, 26), (cx + dx + 9, 26), (cx + dx + 12, 4), (cx + dx - 12, 4)]
        plate(c, toe, STEEL_D, line=1.8, grime=0.2, hatch_alpha=60)
    pad = blob(cx, 40, 34, 20, 16, 0.08, 3)
    plate(c, pad, RUST, line=2.2, grime=0.5)
    plate(c, [(cx - 9, 56), (cx + 9, 56), (cx + 8, 130), (cx - 8, 130)], CHAR, line=1.8, grime=0.2)
    c.fill_ellipse((cx - 18, 118, cx + 18, 154), STEEL, tex=0.3)
    c.ink_ellipse((cx - 18, 118, cx + 18, 154), 2.0)
    thigh = [(cx - 24, 146), (cx + 24, 146), (cx + 26, 196), (cx - 26, 196)]
    plate(c, thigh, ENEMY_RED, line=2.2, grime=0.6)
    c.desertize(dust=0.6, abrasion=0.5, bleach=0.3, seams=0.6)
    c.save(out("enemy.leg"))
    # wreck: collapsed body, splayed legs, scorched, half drifted over with sand
    c = canvas_for("enemy.wreck", 903)
    W, H = 380, 380
    c.soft_shadow((40, 50, 350, 350), 120, 14)
    for sx, ang in ((-1, -0.6), (1, 0.9)):
        lx, ly = 190 + sx * 96, 210
        leg = [(lx - 18, ly - 60), (lx + 18, ly - 60), (lx + 22, ly + 60), (lx - 22, ly + 60)]
        rot = [(lx + (x - lx) * math.cos(ang) - (y - ly) * math.sin(ang), ly + (x - lx) * math.sin(ang) + (y - ly) * math.cos(ang)) for x, y in leg]
        plate(c, rot, RUST_D, line=2.2, grime=0.6)
    draw_scrapper(c, 190, 196, wrecked=True, seed=4)
    # scorch and soot blooms, a torn plate on the ground
    for k in range(5):
        b = blob(190 + random.Random(k).uniform(-70, 70), 196 + random.Random(k + 9).uniform(-90, 90), 34, 24, 14, 0.4, k)
        c.fill(b, (34, 28, 24), tex=0.6, cell=6)
    plate(c, [(40, 300), (96, 290), (104, 330), (44, 344)], OXIDE, line=2.0, grime=0.5)
    d = blob(300, 330, 60, 30, 18, 0.25, 7)
    c.fill(d, SAND_L, tex=0.3)
    c.desertize(dust=0.8, abrasion=0.5, bleach=0.4, seams=0.7, heat=[(190, 300, 60, 0.3), (190, 120, 50, 0.35)])
    c.save(out("enemy.wreck"))


def gen_enemy_pilot():
    c = canvas_for("enemy.pilot", 410)
    W, H = 92, 108
    cx = W / 2
    SUIT = (96, 74, 62)
    pack = rrect(cx - 22, 62, cx + 22, 98, 6, 0.4, 5)
    plate(c, pack, RUST_D, line=2.2, grime=0.4, hatch_alpha=70)
    for sx in (-1, 1):
        arm = [(cx + sx * 26, 40), (cx + sx * 36, 44), (cx + sx * 34, 22), (cx + sx * 26, 16)]
        plate(c, arm, SUIT, line=2.0, grime=0.3, hatch_alpha=60)
        c.fill_ellipse((cx + sx * 30 - 6, 8, cx + sx * 30 + 6, 20), CHAR, tex=0.2)
        c.ink_ellipse((cx + sx * 30 - 6, 8, cx + sx * 30 + 6, 20), 1.4)
    torso = blob(cx, 52, 30, 20, 20, 0.07, 6)
    plate(c, torso, SUIT, line=2.6, grime=0.4, hatch_alpha=80)
    c.ink([(cx - 26, 50), (cx + 26, 54)], 3.0, wobble=0.6, color=ENEMY_RED)   # sash / strap
    c.fill_ellipse((cx - 18, 22, cx + 18, 58), (120, 112, 100), tex=0.3, light=(-1, -1, 0.45))
    c.shade(c.ellipse_mask((cx - 18, 22, cx + 18, 58)), 1, .6, 3.5, 80)
    visor = [(cx - 14, 32), (cx - 6, 24), (cx + 6, 24), (cx + 14, 32), (cx + 10, 36), (cx - 10, 36)]
    c.fill(visor, (176, 52, 36), tex=0.3, light=(-1, -1, 0.6))
    c.ink_poly(visor, 1.6)
    c.ink_ellipse((cx - 18, 22, cx + 18, 58), 2.4)
    c.desertize(dust=0.5, abrasion=0.2, bleach=0.2, seams=0.4)
    c.save(out("enemy.pilot"))


def gen_refuge():
    # parking bay decal on rock floor (no finish; soft edge)
    c = canvas_for("refuge.parking", 1001)
    W, H = 640, 560
    r = random.Random(1)
    for k in range(7):
        st = blob(r.uniform(200, 440), r.uniform(180, 380), r.uniform(30, 70), r.uniform(20, 46), 16, 0.4, k)
        c.fill(st, (60, 52, 44), tex=0.5, cell=10)
    for x0 in (60, 580):
        c.ink([(x0, 60), (x0 + r.uniform(-4, 4), 500)], 9.0, wobble=1.2, alpha=150, color=(214, 178, 90))
    c.ink([(60, 500), (580, 500)], 9.0, wobble=1.2, alpha=150, color=(214, 178, 90))
    for k in range(5):
        x = 120 + k * 100
        c.ink([(x, 470), (x + 40, 500)], 6.0, wobble=0.8, alpha=130, color=(214, 178, 90))
    for k in range(4):
        x = 230 + k * 50
        c.ink([(x, 80), (x + r.uniform(-20, 20), 470)], 4.0, wobble=2.0, alpha=60, color=(40, 32, 26))
    a = c.img.split()[3].filter(ImageFilter.GaussianBlur(2 * SS)); c.img.putalpha(a)
    c.save(out("refuge.parking"), finish=False)
    # workshop floor: plank floor + rug
    c = canvas_for("refuge.workshop_floor", 1002)
    W, H = 568, 448
    m = c.fill([(10, 10), (W - 10, 10), (W - 10, H - 10), (10, H - 10)], (128, 98, 70), tex=0.3, cell=20)
    for y in range(30, H - 10, 32):
        c.ink([(14, y), (W - 14, y + r.uniform(-2, 2))], 1.2, wobble=0.6, alpha=150)
    rug = rrect(200, 170, 380, 300, 8, 1.0, 3)
    c.fill(rug, (140, 70, 50), tex=0.4)
    c.ink_poly(rug, 1.8)
    for y in (190, 280):
        c.ink([(214, y), (366, y)], 3.0, wobble=0.6, alpha=170, color=(196, 160, 90))
    c.grime(m, 0.5, streaks=6)
    c.desertize(dust=0.4, abrasion=0.0, bleach=0.1, seams=0.4)
    c.save(out("refuge.workshop_floor"), finish=False)
    # workshop roof
    c = canvas_for("refuge.workshop_roof", 1003)
    W, H = 600, 480
    x = 14; k = 0
    cols = [(140, 118, 96), (124, 82, 56), (150, 132, 110)]
    while x < W - 30:
        x1 = min(W - 14, x + r.uniform(110, 150))
        poly = [(x, 20 + r.uniform(-3, 3)), (x1, 20 + r.uniform(-3, 3)), (x1, H - 20 + r.uniform(-3, 3)), (x, H - 20 + r.uniform(-3, 3))]
        mm = c.corrugate(poly, cols[k % 3], spacing=10, vertical=False, alpha=100)
        c.shade(mm, 1, .6, 5.0, 55, reach=0.4)
        c.ink_poly(poly, 2.4)
        x = x1 - 8; k += 1
    c.fill_ellipse((440, 90, 492, 142), STEEL_D, tex=0.2)   # stove pipe
    c.fill_ellipse((452, 102, 480, 130), HOLE, tex=0.1)
    c.ink_ellipse((440, 90, 492, 142), 2.2)
    c.desertize(dust=0.6, abrasion=0.3, bleach=0.4, seams=0.6)
    c.save(out("refuge.workshop_roof"))
    # sliding door
    c = canvas_for("refuge.door", 1004)
    plate(c, [(4, 4), (36, 4), (36, 160), (4, 160)], PAINT_G, line=2.2, grime=0.4)
    c.ink([(20, 10), (20, 154)], 1.4, wobble=0.4, alpha=140)
    c.desertize(dust=0.3, abrasion=0.3, bleach=0.3, seams=0.4)
    c.save(out("refuge.door"))
    # wall strip (tiles along the wall)
    c = Canvas(256, 48, 1005)
    c.corrugate([(0, 4), (256, 4), (256, 44), (0, 44)], (124, 100, 78), spacing=12, vertical=True, alpha=110)
    c.ink([(0, 4), (256, 4)], 2.4, wobble=0.6)
    c.ink([(0, 44), (256, 44)], 2.4, wobble=0.6)
    for x in (2, 128):
        c.fill([(x, 2), (x + 14, 2), (x + 14, 46), (x, 46)], STEEL_D, tex=0.2)
    c.img.resize((256, 48), Image.LANCZOS).save(out("refuge.wall_strip"))
    # industrial generator
    c = canvas_for("refuge.generator", 1006)
    W, H = 300, 208
    c.soft_shadow((10, 14, 292, 200), 120, 8)
    skid = [(10, 20), (290, 16), (292, 192), (12, 196)]
    plate(c, skid, STEEL_D, line=3.0, grime=0.6, hatch_alpha=60)
    eng = rrect(30, 34, 190, 176, 10, 0.6, 3)
    plate(c, eng, PAINT_Y, line=2.8, grime=0.7, hatch_alpha=90)
    bolts_along(c, eng, 24, 8)
    c.slots(44, 52, 176, 100, 9, vertical=True, width=2.0)
    grill = [(196, 34), (276, 34), (276, 120), (196, 120)]
    c.fill(grill, HOLE, tex=0.2)
    for y in range(40, 118, 8):
        c.ink([(198, y), (274, y)], 1.4, wobble=0.2, color=(110, 104, 92))
    c.ink_poly(grill, 2.2)
    c.fill_ellipse((210, 136, 250, 176), RUST, tex=0.3)   # exhaust stack
    c.fill_ellipse((220, 146, 240, 166), HOLE, tex=0.1)
    c.ink_ellipse((210, 136, 250, 176), 2.2)
    panel = [(54, 116), (130, 116), (130, 168), (54, 168)]
    plate(c, panel, STEEL_L, line=1.8, grime=0.3, hatch=False)
    for gx in (72, 110):
        c.fill_ellipse((gx - 11, 130, gx + 11, 152), BONE, tex=0.1)
        c.ink_ellipse((gx - 11, 130, gx + 11, 152), 1.4)
        c.ink([(gx, 141), (gx + 6, 134)], 1.4)
    c.fill_ellipse((140, 150, 152, 162), (90, 200, 120), tex=0.1)   # running lamp
    term = [(256, 140), (286, 140), (286, 186), (256, 186)]
    plate(c, term, CHAR, line=1.8, grime=0.2, hatch=False)
    c.desertize(dust=0.4, abrasion=0.2, bleach=0.3, seams=0.7, heat=[(230, 156, 40, 0.7)])
    c.save(out("refuge.generator"))
    # light post head (top view)
    c = canvas_for("refuge.light_post", 1007)
    c.fill_ellipse((6, 6, 54, 54), STEEL_D, tex=0.3, light=(-1, -1, 0.5))
    c.fill_ellipse((16, 16, 44, 44), (250, 220, 150), tex=0.1)
    c.ink_ellipse((6, 6, 54, 54), 2.2)
    c.ink([(30, 6), (30, 0)], 2.0)
    c.save(out("refuge.light_post"))
    # crates
    c = canvas_for("refuge.crates", 1008)
    for k, (x0, y0, w, h, col) in enumerate(((10, 30, 100, 90, (150, 112, 70)), (100, 14, 90, 80, (132, 96, 60)), (60, 100, 110, 72, STEEL))):
        pl = [(x0, y0), (x0 + w, y0 + 3), (x0 + w - 2, y0 + h), (x0 + 2, y0 + h - 2)]
        plate(c, pl, col, line=2.4, grime=0.5, hatch_alpha=80)
        c.ink([(x0 + 6, y0 + 6), (x0 + w - 6, y0 + h - 6)], 1.6, wobble=0.6, alpha=170)
        c.ink([(x0 + w - 6, y0 + 6), (x0 + 6, y0 + h - 6)], 1.6, wobble=0.6, alpha=170)
    c.desertize(dust=0.5, abrasion=0.2, bleach=0.3, seams=0.5)
    c.save(out("refuge.crates"))
    # coolant canisters
    c = canvas_for("refuge.coolant_cans", 1009)
    for (x, y) in ((40, 44), (92, 40), (62, 92), (106, 96)):
        can = rrect(x - 20, y - 24, x + 20, y + 24, 5, 0.4, int(x))
        plate(c, can, COOLANT, line=2.2, grime=0.3, hatch_alpha=70)
        c.fill([(x - 6, y - 30), (x + 6, y - 30), (x + 6, y - 22), (x - 6, y - 22)], CHAR, tex=0.1)
        c.ink([(x - 12, y - 10), (x + 12, y + 10)], 1.4, wobble=0.4, alpha=160)
    c.desertize(dust=0.5, abrasion=0.3, bleach=0.45, seams=0.4)
    c.save(out("refuge.coolant_cans"))


def gen_rock_tiles():
    S = 512
    SSz = S * SS
    t = Tile(S, 51)
    t.base((150, 112, 80), (178, 136, 96), (204, 164, 120), cell=150, octaves=5)
    yy, xx = np.mgrid[0:SSz, 0:SSz].astype(np.float32)
    warp = value_noise(SSz, SSz, 120 * SS, 7, 3, wrap=True)
    strata = np.sin((yy / SSz + xx / SSz * 0.25 + warp * 0.35) * 2 * math.pi * 7)
    arr = np.asarray(t.c.img, np.float32)
    arr[..., :3] *= (1 + strata[..., None] * 0.05)
    varnish = np.clip((value_noise(SSz, SSz, 60 * SS, 8, 3, wrap=True) - 0.6) * 2.5, 0, 1) * 0.35
    arr[..., :3] = arr[..., :3] * (1 - varnish[..., None]) + np.array((86, 58, 44)) * varnish[..., None]
    t.c.img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")
    rr = random.Random(51); marks = [(rr.uniform(0, S), rr.uniform(0, S), rr.uniform(20, 60)) for _ in range(26)]
    def draw(ox, oy):
        for x, y, L in marks:
            x += ox; y += oy
            if -80 < x < S + 80 and -80 < y < S + 80:
                t.c.ink([(x, y), (x + L * .4, y + L * .25), (x + L, y + L * .1)], 1.0, wobble=1.0, alpha=110)
    t.wrap_draw(draw)
    t.save(out("ground.rock_top"))
    t = Tile(S, 52)
    t.base((118, 100, 84), (140, 120, 98), (160, 140, 114), cell=100, octaves=5)
    rr = random.Random(52); pebbles = [(rr.uniform(0, S), rr.uniform(0, S), rr.uniform(1.5, 4)) for _ in range(110)]
    def draw2(ox, oy):
        for x, y, r0 in pebbles:
            x += ox; y += oy
            if -20 < x < S + 20 and -20 < y < S + 20:
                t.c.fill_ellipse((x - r0, y - r0 * .8, x + r0, y + r0 * .8), (104, 90, 76), tex=0.2, cell=3)
                t.c.ink([(x - r0 * .3, y + r0 * .8), (x + r0, y + r0 * .2)], 0.8, wobble=0.1, alpha=140)
    t.wrap_draw(draw2)
    t.save(out("ground.canyon_floor"))
    # cliff rim strip: rock edge (top) → hatched face → soft shadow on the floor (bottom)
    W, H = 256, 64
    c = Canvas(W, H, 53)
    yy = np.mgrid[0:H * SS, 0:W * SS][0] / (H * SS)
    n = value_noise(W * SS, H * SS, 10 * SS, 53, 3, wrap=True)
    rgb = np.zeros((H * SS, W * SS, 3), np.float32) + np.array((96, 72, 54))
    rgb *= (0.85 + n[..., None] * 0.3)
    alpha = np.clip(1.0 - np.clip((yy - 0.45) / 0.55, 0, 1) ** 0.8, 0, 1) * 0.85
    c.img = Image.fromarray(np.dstack([np.clip(rgb, 0, 255), alpha * 255]).astype(np.uint8), "RGBA")
    for k in range(0, W + 8, 6):
        for ox in (-W, 0, W):
            c.ink([(k + ox, 4), (k + ox + 10, 28)], 1.0, wobble=0.3, alpha=120)
    c.ink([(0, 3), (W, 3)], 2.6, wobble=0.8)
    c.img.resize((W, H), Image.LANCZOS).save(out("terrain.cliff_rim"))


def gen_junker():
    # Junker scrapper variant + wreck
    c = canvas_for("enemy.junker_hull", 1101)
    draw_scrapper(c, 150, 166, junker=True, seed=11)
    c.desertize(dust=0.5, abrasion=0.55, bleach=0.3, seams=0.75, heat=[(156, 60, 40, 0.5)])
    c.save(out("enemy.junker_hull"))
    c = canvas_for("enemy.junker_wreck", 1102)
    c.soft_shadow((40, 50, 350, 350), 120, 14)
    for sx, ang in ((-1, -0.7), (1, 0.6)):
        lx, ly = 190 + sx * 96, 210
        leg = [(lx - 18, ly - 60), (lx + 18, ly - 60), (lx + 22, ly + 60), (lx - 22, ly + 60)]
        rot = [(lx + (x - lx) * math.cos(ang) - (y - ly) * math.sin(ang), ly + (x - lx) * math.sin(ang) + (y - ly) * math.cos(ang)) for x, y in leg]
        plate(c, rot, JK_RUST, line=2.2, grime=0.6)
    draw_scrapper(c, 190, 196, wrecked=True, seed=14, junker=True)
    for k in range(5):
        b = blob(190 + random.Random(k + 3).uniform(-70, 70), 196 + random.Random(k + 19).uniform(-90, 90), 32, 22, 14, 0.4, k)
        c.fill(b, (34, 28, 24), tex=0.6, cell=6)
    c.desertize(dust=0.8, abrasion=0.5, bleach=0.4, seams=0.7, heat=[(190, 300, 60, 0.3)])
    c.save(out("enemy.junker_wreck"))
    # turret: reinforced scrap mount + rotating gun housing + wreck
    c = canvas_for("junker.turret_base", 1103)
    W = 208; cx = W / 2
    c.soft_shadow((14, 18, 196, 198), 120, 8)
    octo = [(cx + math.cos(a) * 92, cx + math.sin(a) * 92) for a in np.linspace(0, math.tau, 8, endpoint=False) + math.pi / 8]
    plate(c, octo, JK_BLACK, line=3.0, grime=0.6, hatch_alpha=90)
    for a in np.linspace(0, math.tau, 8, endpoint=False) + math.pi / 8:   # sandbag/plate buttresses
        x, y = cx + math.cos(a) * 80, cx + math.sin(a) * 80
        pl = blob(x, y, 20, 14, 10, 0.2, int(a * 10), rot=a)
        plate(c, pl, JK_ORANGE if int(a * 3) % 2 else STEEL, line=1.8, grime=0.5, hatch_alpha=60)
    c.fill_ellipse((cx - 56, cx - 56, cx + 56, cx + 56), STEEL_D, tex=0.3)
    c.ink_ellipse((cx - 56, cx - 56, cx + 56, cx + 56), 2.6)
    c.rivets([(cx + math.cos(a) * 50, cx + math.sin(a) * 50) for a in np.linspace(0, math.tau, 12, endpoint=False)], 1.8)
    c.desertize(dust=0.6, abrasion=0.5, bleach=0.3, seams=0.7)
    c.save(out("junker.turret_base"))
    c = canvas_for("junker.turret_gun", 1104)
    W, H = 144, 256; cx, my = W / 2, 159
    hous = rrect(cx - 50, my - 44, cx + 50, my + 70, 14, 0.8, 4)
    plate(c, hous, JK_ORANGE, line=3.0, grime=0.6, hatch_alpha=95)
    for k in range(3):
        c.fill([(cx - 46, my - 6 + k * 22), (cx + 46, my - 6 + k * 22), (cx + 46, my + 6 + k * 22), (cx - 46, my + 6 + k * 22)], JK_BLACK, tex=0.3)
    insignia(c, cx, my + 46, 15, BONE, 210)
    barrel = [(cx - 12, my - 40), (cx + 12, my - 40), (cx + 10, 18), (cx - 10, 18)]
    plate(c, barrel, STEEL, line=2.6, grime=0.4, hatch_alpha=80)
    for y in range(36, int(my - 46), 16):
        c.ink([(cx - 16, y), (cx + 16, y)], 2.6, wobble=0.3)
    plate(c, [(cx - 18, 4), (cx + 18, 4), (cx + 18, 22), (cx - 18, 22)], CHAR, line=2.0, grime=0.2, hatch=False)
    ammo = [(cx + 34, my - 30), (cx + 64, my - 26), (cx + 62, my + 24), (cx + 34, my + 20)]
    plate(c, ammo, PAINT_G, line=2.0, grime=0.4)
    c.ink([(cx + 40, my - 20), (cx + 56, my + 14)], 1.4, wobble=0.3)
    c.desertize(dust=0.45, abrasion=0.55, bleach=0.3, seams=0.7, heat=[(cx, 36, 30, 0.6)])
    c.save(out("junker.turret_gun"))
    c = canvas_for("junker.turret_wreck", 1105)
    W = 224; cx = W / 2
    c.soft_shadow((14, 18, 210, 214), 130, 10)
    octo = [(cx + math.cos(a) * 96, cx + math.sin(a) * 96) for a in np.linspace(0, math.tau, 8, endpoint=False) + math.pi / 8]
    plate(c, octo, JK_BLACK, line=3.0, grime=0.7)
    for k in range(6):
        b = blob(cx + random.Random(k).uniform(-60, 60), cx + random.Random(k + 5).uniform(-60, 60), 26, 18, 12, 0.4, k, rot=k)
        plate(c, b, random.Random(k).choice([JK_ORANGE, STEEL, JK_RUST]), line=1.8, grime=0.5, hatch_alpha=70)
    c.ink([(cx, cx), (cx + 70, cx - 80)], 9.0, wobble=1.0, color=STEEL_D)   # toppled barrel
    for k in range(4):
        b = blob(cx + random.Random(k + 9).uniform(-50, 50), cx + random.Random(k + 13).uniform(-50, 50), 30, 20, 12, 0.4, k)
        c.fill(b, (30, 26, 22), tex=0.6, cell=6)
    c.desertize(dust=0.7, abrasion=0.4, bleach=0.3, seams=0.6, heat=[(cx, cx, 70, 0.5)])
    c.save(out("junker.turret_wreck"))
    # buildings
    def roof(id_, seed, cols, mark=False, chimney=True):
        c = canvas_for(id_, seed)
        W, H = ALL[id_]["source"]
        r = random.Random(seed)
        c.soft_shadow((6, 8, W - 4, H - 2), 110, 8)
        x = 12; k = 0
        while x < W - 30:
            x1 = min(W - 12, x + r.uniform(W * 0.12, W * 0.2))
            poly = [(x, 14 + r.uniform(-4, 4)), (x1, 14 + r.uniform(-4, 4)), (x1, H - 14 + r.uniform(-4, 4)), (x, H - 14 + r.uniform(-4, 4))]
            mm = c.corrugate(poly, cols[k % len(cols)], spacing=11, vertical=False, alpha=110)
            c.shade(mm, 1, .6, 5.0, 60, reach=0.4)
            c.ink_poly(poly, 2.6)
            x = x1 - r.uniform(6, 14); k += 1
        for y in (H * 0.3, H * 0.7):
            c.rivets([(xx, y + r.uniform(-2, 2)) for xx in range(28, int(W) - 20, 36)], 2.2)
        for j in range(4):   # welded patch plates
            px, py = r.uniform(40, W - 120), r.uniform(40, H - 110)
            pl = [(px, py), (px + r.uniform(60, 110), py + r.uniform(-6, 6)), (px + r.uniform(60, 110), py + r.uniform(50, 80)), (px, py + r.uniform(50, 80))]
            plate(c, pl, r.choice([STEEL, JK_RUST, STEEL_L]), line=1.8, grime=0.5, hatch_alpha=50)
        if mark:
            insignia(c, W * 0.5, H * 0.5, min(W, H) * 0.2, BONE, 200)
        if chimney:
            c.fill_ellipse((W * 0.8, H * 0.18, W * 0.8 + 46, H * 0.18 + 46), STEEL_D, tex=0.2)
            c.fill_ellipse((W * 0.8 + 11, H * 0.18 + 11, W * 0.8 + 35, H * 0.18 + 35), HOLE, tex=0.1)
            c.ink_ellipse((W * 0.8, H * 0.18, W * 0.8 + 46, H * 0.18 + 46), 2.2)
        for k2 in range(3):   # hazard stripes along one eave
            x0 = 30 + k2 * 70
            c.fill([(x0, H - 28), (x0 + 34, H - 28), (x0 + 50, H - 14), (x0 + 16, H - 14)], JK_BLACK, tex=0.3)
        c.desertize(dust=0.6, abrasion=0.4, bleach=0.4, seams=0.7)
        c.save(out(id_))
    roof("junker.workshop", 1110, [JK_ORANGE, JK_RUST, (140, 120, 98), JK_ORANGE, STEEL], mark=True)
    roof("junker.shed", 1111, [JK_RUST, (140, 120, 98)], chimney=False)
    roof("junker.shed_b", 1112, [JK_ORANGE, STEEL], chimney=True)
    # scrap stack
    c = canvas_for("junker.scrap_stack", 1113)
    W, H = 320, 260
    r = random.Random(13)
    c.soft_shadow((10, 14, W - 6, H - 4), 120, 10)
    for k in range(16):
        x, y = r.uniform(50, W - 50), r.uniform(40, H - 40)
        w, h = r.uniform(40, 110), r.uniform(20, 60)
        a = r.uniform(0, math.pi)
        pts = [(x + math.cos(a) * dx - math.sin(a) * dy, y + math.sin(a) * dx + math.cos(a) * dy) for dx, dy in ((-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2))]
        plate(c, pts, r.choice([RUST, STEEL, JK_ORANGE, JK_RUST, STEEL_D, PAINT_G]), line=1.8, grime=0.4, hatch_alpha=60)
    for k in range(3):
        gx, gy = r.uniform(80, W - 80), r.uniform(70, H - 70)
        c.fill_ellipse((gx - 26, gy - 26, gx + 26, gy + 26), STEEL_L, tex=0.2)
        c.ink_ellipse((gx - 26, gy - 26, gx + 26, gy + 26), 2.0)
        c.fill_ellipse((gx - 8, gy - 8, gx + 8, gy + 8), HOLE, tex=0.1)
    c.desertize(dust=0.6, abrasion=0.4, bleach=0.4, seams=0.7)
    c.save(out("junker.scrap_stack"))
    # cooler: radiator banks with big fans (their own machinery)
    c = canvas_for("junker.cooler", 1114)
    W, H = 340, 260
    plate(c, rrect(8, 8, W - 8, H - 8, 10, 0.8, 1), JK_BLACK, line=3.0, grime=0.6)
    for fx_, fy in ((92, 92), (248, 92), (92, 186), (248, 186)):
        c.fill_ellipse((fx_ - 58, fy - 40, fx_ + 58, fy + 40), (60, 58, 52), tex=0.2)
        for k in range(6):
            a = k / 6 * math.tau
            c.fill([(fx_, fy), (fx_ + math.cos(a) * 52, fy + math.sin(a) * 36), (fx_ + math.cos(a + .5) * 46, fy + math.sin(a + .5) * 32)], STEEL_L, tex=0.1)
        c.ink_ellipse((fx_ - 58, fy - 40, fx_ + 58, fy + 40), 2.2)
    c.ink([(20, 140), (W - 20, 140)], 6.0, wobble=0.8, color=(48, 92, 88))
    c.ink([(20, 140), (W - 20, 140)], 3.0, wobble=0.6, color=COOLANT)
    c.desertize(dust=0.5, abrasion=0.4, bleach=0.3, seams=0.7, heat=[(170, 130, 120, 0.3)])
    c.save(out("junker.cooler"))
    # generator rig
    c = canvas_for("junker.generator", 1115)
    W, H = 320, 220
    c.soft_shadow((10, 14, W - 6, H - 6), 120, 8)
    plate(c, [(10, 20), (W - 10, 14), (W - 8, H - 18), (12, H - 12)], JK_BLACK, line=3.0, grime=0.7)
    eng = rrect(28, 36, 200, 180, 10, 0.8, 3)
    plate(c, eng, JK_ORANGE, line=2.8, grime=0.8, hatch_alpha=90)
    c.slots(44, 56, 184, 110, 9, vertical=True, width=2.0)
    for k in range(2):
        ex, ey = 236 + k * 40, 60
        c.fill_ellipse((ex - 16, ey - 16, ex + 16, ey + 16), RUST, tex=0.3)
        c.fill_ellipse((ex - 8, ey - 8, ex + 8, ey + 8), HOLE, tex=0.1)
        c.ink_ellipse((ex - 16, ey - 16, ex + 16, ey + 16), 2.0)
    plate(c, [(222, 110), (300, 110), (300, 190), (222, 190)], STEEL, line=2.0, grime=0.4)
    insignia(c, 114, 148, 22, BONE, 200)
    c.desertize(dust=0.5, abrasion=0.3, bleach=0.3, seams=0.8, heat=[(256, 60, 50, 0.7)])
    c.save(out("junker.generator"))
    # shade tarp (patched, faction colours)
    c = canvas_for("junker.tarp", 1116)
    W, H = 640, 480
    sail = [(30, 30), (W / 2, 56), (W - 30, 30), (W - 56, H / 2), (W - 30, H - 30), (W / 2, H - 56), (30, H - 30), (56, H / 2)]
    m = c.fill(sail, (170, 110, 66), tex=0.4, cell=22)
    for k in range(4):
        x0 = 40 + k * (W - 80) / 4
        pnl = [(x0, 30), (x0 + (W - 80) / 4, 30), (x0 + (W - 80) / 4, H - 30), (x0, H - 30)]
        pm = Image.fromarray(np.minimum(np.asarray(m), np.asarray(c.mask(pnl))))
        c.fill(None, [JK_ORANGE, (150, 120, 90), JK_RUST, (176, 150, 110)][k], tex=0.35, cell=20, m=pm)
    c.shade(m, 1, .6, 6.0, 55, reach=0.45)
    insignia(c, W / 2, H / 2, 70, JK_BLACK, 200)
    c.desertize(dust=0.6, abrasion=0.2, bleach=0.6, seams=0.4)
    c.ink_poly(sail, 2.6)
    c.save(out("junker.tarp"))
    # burn barrel, insignia decal, lamp
    c = canvas_for("junker.burn_barrel", 1117)
    c.fill_ellipse((6, 6, 82, 82), RUST, tex=0.4)
    c.fill_ellipse((16, 16, 72, 72), (30, 22, 16), tex=0.3)
    for k in range(5):
        x, y = random.Random(k).uniform(26, 62), random.Random(k + 3).uniform(26, 62)
        c.fill_ellipse((x - 6, y - 6, x + 6, y + 6), (230, 120, 40), tex=0.1)
    c.ink_ellipse((6, 6, 82, 82), 2.4)
    c.save(out("junker.burn_barrel"))
    c = canvas_for("junker.insignia", 1118)
    insignia(c, 180, 180, 150, (210, 196, 170), 200)
    for k in range(5):   # spray-paint drips / sand eating the paint
        x = random.Random(k).uniform(100, 260)
        c.ink([(x, 250), (x + 2, 300)], 4.0, wobble=0.6, alpha=120, color=(210, 196, 170))
    arr = np.asarray(c.img, np.float32)
    n = value_noise(c.img.size[0], c.img.size[1], 18 * SS, 77, 3)
    arr[..., 3] *= np.clip(0.4 + n * 0.8, 0, 1) * 0.8
    c.img = Image.fromarray(arr.astype(np.uint8), "RGBA")
    c.save(out("junker.insignia"), finish=False)
    c = canvas_for("junker.lamp", 1119)
    c.fill_ellipse((6, 6, 54, 54), JK_BLACK, tex=0.3)
    c.fill_ellipse((16, 16, 44, 44), (255, 190, 110), tex=0.1)
    c.ink_ellipse((6, 6, 54, 54), 2.2)
    c.save(out("junker.lamp"))
    # wall strip: welded plates, rust, spikes on top
    c = Canvas(256, 60, 1120)
    r = random.Random(20)
    x = 0
    while x < 256:
        w = r.uniform(40, 70)
        plate(c, [(x, 8), (x + w, 6 + r.uniform(-2, 2)), (x + w, 52), (x, 54)], r.choice([JK_RUST, STEEL, JK_ORANGE, STEEL_D]), line=1.8, grime=0.6, hatch_alpha=60)
        x += w - 2
    for k in range(0, 256, 32):
        c.ink([(k + 8, 8), (k + 14, 0)], 2.4, wobble=0.3, color=STEEL_D)
    c.img.resize((256, 60), Image.LANCZOS).save(out("junker.wall_strip"))


def gen_cooling_station():
    c = canvas_for("cs.cooling_tower", 1201)
    W = 660; cx = W / 2
    c.soft_shadow((40, 50, 640, 650), 120, 18)
    c.fill_ellipse((20, 20, 640, 640), (156, 146, 128), tex=0.35, cell=30, light=(-1, -1, 0.5))
    c.shade(c.ellipse_mask((20, 20, 640, 640)), 1, .6, 6, 70, cross=True, reach=0.45)
    for rr in (290, 250):
        c.ink_ellipse((cx - rr, cx - rr, cx + rr, cx + rr), 1.6, alpha=150)
    c.fill_ellipse((cx - 220, cx - 220, cx + 220, cx + 220), (40, 34, 30), tex=0.4)   # open throat
    c.fill_ellipse((cx - 150, cx - 160, cx + 170, cx + 150), (70, 62, 54), tex=0.5)
    for k in range(8):   # broken fan blades / debris in the throat
        a = k / 8 * math.tau
        c.ink([(cx, cx), (cx + math.cos(a) * 180, cx + math.sin(a) * 180)], 8.0, wobble=1.2, color=STEEL_D)
    c.fill_ellipse((cx - 30, cx - 30, cx + 30, cx + 30), RUST, tex=0.2)
    hole = blob(cx + 200, cx - 150, 70, 46, 16, 0.4, 3)   # collapsed rim section
    c.fill(hole, (52, 46, 40), tex=0.4)
    c.ink_poly(hole, 2.0)
    c.ink_ellipse((20, 20, 640, 640), 3.4)
    c.ink_ellipse((cx - 220, cx - 220, cx + 220, cx + 220), 2.6)
    c.desertize(dust=0.7, abrasion=0.5, bleach=0.5, seams=0.6)
    c.save(out("cs.cooling_tower"))
    c = canvas_for("cs.tank", 1202)
    c.soft_shadow((14, 18, 290, 296), 120, 10)
    c.fill_ellipse((14, 14, 286, 286), (128, 132, 124), tex=0.35, cell=22, light=(-1, -1, 0.55))
    c.shade(c.ellipse_mask((14, 14, 286, 286)), 1, .6, 5, 80, reach=0.45)
    for rr in (110, 80):
        c.ink_ellipse((150 - rr, 150 - rr, 150 + rr, 150 + rr), 1.2, alpha=150)
    c.fill_ellipse((126, 126, 174, 174), STEEL_D, tex=0.2)
    c.ink_ellipse((126, 126, 174, 174), 2.0)
    c.ink([(60, 110), (240, 110)], 12.0, wobble=0.8, alpha=140, color=COOLANT)   # faded coolant band
    c.ink_ellipse((14, 14, 286, 286), 3.0)
    c.desertize(dust=0.6, abrasion=0.5, bleach=0.6, seams=0.5)
    c.save(out("cs.tank"))
    c = canvas_for("cs.radiator_bank", 1203)
    W, H = 560, 240
    c.soft_shadow((10, 14, W - 6, H - 4), 110, 8)
    plate(c, rrect(8, 8, W - 8, H - 8, 10, 0.8, 2), STEEL_D, line=3.0, grime=0.5)
    c.fill([(26, 26), (W - 26, 26), (W - 26, H - 26), (26, H - 26)], (64, 62, 56), tex=0.3)
    for i in range(80):
        x = 28 + i * (W - 56) / 79
        c.ink([(x, 28), (x + random.Random(i).uniform(-6, 6) * (i % 7 == 0), H - 28)], 1.1, wobble=0.2, alpha=210)
    for k in range(4):
        b = blob(random.Random(k).uniform(80, W - 80), random.Random(k + 4).uniform(60, H - 60), 40, 22, 14, 0.4, k)
        c.fill(b, SAND_M, tex=0.4)
    c.desertize(dust=0.6, abrasion=0.5, bleach=0.4, seams=0.6)
    c.save(out("cs.radiator_bank"))
    c = canvas_for("cs.pipe_rack", 1204)
    W, H = 600, 140
    for y, col in ((40, RUST), (70, STEEL), (100, (48, 92, 88))):
        c.ink([(10, y), (W - 10, y + 4)], 18.0, wobble=0.6, color=col)
        c.ink([(10, y - 7), (W - 10, y - 3)], 2.0, wobble=0.4, alpha=120, color=(230, 210, 180))
        c.ink([(10, y + 9), (W - 10, y + 13)], 1.6, wobble=0.4)
    for x in range(30, W, 120):
        plate(c, [(x, 14), (x + 16, 14), (x + 16, 128), (x, 128)], STEEL_D, line=1.8, grime=0.4, hatch=False)
    c.desertize(dust=0.5, abrasion=0.5, bleach=0.4, seams=0.5)
    c.save(out("cs.pipe_rack"))
    c = canvas_for("cs.control_shed", 1205)
    W, H = 440, 340
    c.soft_shadow((6, 8, W - 4, H - 2), 110, 8)
    plate(c, rrect(10, 10, W - 10, H - 10, 8, 1.0, 5), (150, 146, 132), line=3.0, grime=0.6, hatch_alpha=80)
    for k in range(3):
        c.fill([(40 + k * 130, 40), (140 + k * 130, 40), (140 + k * 130, 90), (40 + k * 130, 90)], (60, 70, 76), tex=0.3)   # skylights
        c.ink_poly([(40 + k * 130, 40), (140 + k * 130, 40), (140 + k * 130, 90), (40 + k * 130, 90)], 1.6)
    c.ink([(30, 200), (W - 30, 180)], 3.0, wobble=2.0)   # crack across the roof
    c.ink([(60, 260), (380, 250)], 10.0, wobble=1.0, alpha=110, color=COOLANT)
    c.desertize(dust=0.7, abrasion=0.4, bleach=0.6, seams=0.6)
    c.save(out("cs.control_shed"))


def gen_roadside():
    c = canvas_for("road.lot", 1301)
    W, H = 960, 680
    m = c.fill(rrect(20, 20, W - 20, H - 20, 30, 3.0, 2), (82, 78, 72), tex=0.3, cell=30)
    r = random.Random(4)
    for k in range(5):
        x = 120 + k * 160
        c.ink([(x, 80), (x + 10, 300)], 6.0, wobble=1.0, alpha=120, color=(220, 210, 180))
    for k in range(18):
        x, y = r.uniform(60, W - 60), r.uniform(60, H - 60)
        pts = [(x, y)]
        for j in range(4):
            x += r.uniform(-40, 40); y += r.uniform(-40, 40); pts.append((x, y))
        c.ink(pts, 1.4, wobble=1.0, alpha=150)
    yy, xx = np.mgrid[0:H * SS, 0:W * SS]
    n = value_noise(W * SS, H * SS, 40 * SS, 9, 4)
    drift = np.clip((n - 0.45) * 2.2 + (xx / (W * SS)) * 0.4 - 0.2, 0, 1)
    arr = np.asarray(c.img, np.float32)
    arr[..., :3] = arr[..., :3] * (1 - drift[..., None] * 0.8) + np.array(SAND_M) * drift[..., None] * 0.8
    c.img = Image.fromarray(arr.astype(np.uint8), "RGBA")
    c.img.putalpha(c.img.split()[3].filter(ImageFilter.GaussianBlur(5 * SS)))
    c.save(out("road.lot"), finish=False)
    c = canvas_for("road.kiosk", 1302)
    W, H = 500, 340
    c.soft_shadow((6, 8, W - 4, H - 2), 110, 8)
    plate(c, rrect(10, 10, W - 10, H - 10, 6, 1.0, 1), (176, 168, 150), line=3.0, grime=0.6, hatch_alpha=70)
    plate(c, [(10, 10), (W - 10, 10), (W - 10, 70), (10, 70)], (150, 60, 44), line=2.4, grime=0.5)   # faded brand fascia
    for k in range(4):
        c.ink([(60 + k * 100, 30), (100 + k * 100, 50)], 6.0, wobble=0.6, alpha=160, color=BONE)
    c.fill([(320, 140), (440, 140), (440, 260), (320, 260)], HOLE, tex=0.2)   # caved-in roof section
    c.ink_poly([(320, 140), (440, 140), (440, 260), (320, 260)], 2.2)
    c.desertize(dust=0.8, abrasion=0.5, bleach=0.7, seams=0.6)
    c.save(out("road.kiosk"))
    c = canvas_for("road.pump", 1303)
    plate(c, rrect(8, 8, 64, 96, 6, 0.4, 1), (180, 70, 50), line=2.2, grime=0.5)
    c.fill([(18, 20), (54, 20), (54, 44), (18, 44)], (50, 60, 64), tex=0.2)
    c.ink([(60, 60), (70, 90), (60, 100)], 2.4, wobble=0.6)
    c.desertize(dust=0.6, abrasion=0.4, bleach=0.7, seams=0.4)
    c.save(out("road.pump"))
    c = canvas_for("road.canopy", 1304)
    W, H = 880, 600
    roofp = [(14, 14), (W - 14, 14), (W - 14, H - 14), (14, H - 14)]
    m = plate(c, roofp, (190, 184, 168), line=3.0, grime=0.6, hatch_alpha=60)
    for x in range(14, W, 90):
        c.ink([(x, 20), (x + 4, H - 20)], 1.2, wobble=0.8, alpha=130)
    for k in range(4):
        c.ink([(60 + k * 200, 50), (140 + k * 200, 50)], 14.0, wobble=0.8, alpha=150, color=(150, 60, 44))
    for k in range(6):   # missing / solar panels
        x0, y0 = 80 + (k % 3) * 260, 160 + (k // 3) * 200
        cell = [(x0, y0), (x0 + 200, y0), (x0 + 200, y0 + 140), (x0, y0 + 140)]
        if k in (1, 4):
            continue
        c.fill(cell, (52, 62, 78), tex=0.3, light=(-1, -1, 0.5))
        c.ink_poly(cell, 1.4)
        c.ink([(x0 + 20, y0 + 20), (x0 + 120, y0 + 100)], 1.0, wobble=1.2, alpha=180, color=(200, 210, 220))
    c.desertize(dust=0.8, abrasion=0.4, bleach=0.6, seams=0.5)
    hm = Image.new("L", c.img.size, 255)
    for k in (1, 4):
        x0, y0 = 80 + (k % 3) * 260, 160 + (k // 3) * 200
        ImageDraw.Draw(hm).rectangle([x0 * SS, y0 * SS, (x0 + 200) * SS, (y0 + 140) * SS], fill=0)
    c.img.putalpha(Image.fromarray(np.minimum(np.asarray(c.img.split()[3]), np.asarray(hm))))
    c.save(out("road.canopy"))
    c = canvas_for("road.car", 1305)
    W, H = 360, 192
    c.soft_shadow((10, 14, W - 6, H - 4), 120, 8)
    body = rrect(20, 24, W - 20, H - 24, 40, 1.0, 3)
    plate(c, body, (90, 110, 120), line=3.0, grime=0.7, hatch_alpha=80)
    c.fill([(110, 40), (230, 40), (240, H - 40), (100, H - 40)], (46, 54, 58), tex=0.3)   # cabin glass
    c.ink_poly([(110, 40), (230, 40), (240, H - 40), (100, H - 40)], 2.0)
    for (x, y) in ((70, 20), (290, 20), (70, H - 20), (290, H - 20)):
        c.fill_ellipse((x - 26, y - 12, x + 26, y + 12), HOLE, tex=0.1)
    c.fill(blob(300, 140, 80, 40, 14, 0.3, 2), SAND_L, tex=0.3)
    c.desertize(dust=0.8, abrasion=0.6, bleach=0.8, seams=0.6)
    c.save(out("road.car"))
    c = canvas_for("road.billboard", 1306)
    W, H = 600, 128
    plate(c, [(10, 20), (W - 10, 14), (W - 12, H - 16), (12, H - 10)], (196, 186, 164), line=3.0, grime=0.6)
    for k in range(5):
        c.ink([(60 + k * 110, 50), (110 + k * 110, 50)], 16.0, wobble=1.0, alpha=140, color=[(70, 120, 150), (190, 80, 50)][k % 2])
    c.ink([(40, 90), (W - 120, 96)], 6.0, wobble=1.0, alpha=120, color=(60, 60, 60))
    c.desertize(dust=0.8, abrasion=0.6, bleach=0.8, seams=0.5)
    c.save(out("road.billboard"))
    c = canvas_for("road.sign", 1307)
    c.fill_ellipse((10, 10, 78, 78), (60, 110, 80), tex=0.3)
    c.fill([(22, 44), (54, 44), (54, 32), (70, 48), (54, 64), (54, 52), (22, 52)], BONE, tex=0.1)   # evacuation arrow
    c.ink_ellipse((10, 10, 78, 78), 2.4)
    c.desertize(dust=0.5, abrasion=0.5, bleach=0.7, seams=0.3)
    c.save(out("road.sign"))
    # debris props
    c = canvas_for("prop.engine_block", 1308)
    plate(c, rrect(16, 20, 164, 140, 12, 1.0, 2), STEEL_D, line=2.8, grime=0.7, hatch_alpha=90)
    for k in range(3):
        c.fill_ellipse((34 + k * 44, 50, 64 + k * 44, 80), HOLE, tex=0.1)
        c.ink_ellipse((34 + k * 44, 50, 64 + k * 44, 80), 1.8)
    c.ink([(30, 110), (150, 110)], 6.0, wobble=0.6, color=RUST)
    c.desertize(dust=0.6, abrasion=0.4, bleach=0.3, seams=0.7)
    c.save(out("prop.engine_block"))
    c = canvas_for("prop.tire_stack", 1309)
    for k, (x, y) in enumerate(((60, 62), (84, 80), (72, 96))):
        c.fill_ellipse((x - 46, y - 46, x + 46, y + 46), CHAR, tex=0.3)
        c.fill_ellipse((x - 20, y - 20, x + 20, y + 20), SAND_D, tex=0.2)
        c.ink_ellipse((x - 46, y - 46, x + 46, y + 46), 2.4)
    c.desertize(dust=0.6, abrasion=0.3, bleach=0.4, seams=0.4)
    c.save(out("prop.tire_stack"))


def gen_south_tiles():
    S = 512
    t = Tile(S, 61)   # junker yard: oil-stained packed dirt
    t.base((120, 90, 62), (148, 112, 76), (172, 136, 96), cell=110, octaves=5)
    SSz = S * SS
    stain = np.clip((value_noise(SSz, SSz, 50 * SS, 62, 3, wrap=True) - 0.58) * 3, 0, 1) * 0.55
    arr = np.asarray(t.c.img, np.float32)
    arr[..., :3] = arr[..., :3] * (1 - stain[..., None]) + np.array((44, 36, 30)) * stain[..., None]
    t.c.img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")
    rr = random.Random(61); bits = [(rr.uniform(0, S), rr.uniform(0, S), rr.uniform(4, 10), rr.uniform(0, 3)) for _ in range(60)]
    def draw(ox, oy):
        for x, y, L, a in bits:
            x += ox; y += oy
            if -30 < x < S + 30 and -30 < y < S + 30:
                t.c.ink([(x, y), (x + math.cos(a) * L, y + math.sin(a) * L)], 1.6, wobble=0.2, alpha=170, color=(70, 62, 56))
    t.wrap_draw(draw)
    t.save(out("ground.junker_dirt"))
    W, H = 256, 128   # asphalt strip
    c = Canvas(W, H, 63)
    n = value_noise(W * SS, H * SS, 30 * SS, 63, 4, wrap=True)
    from inkkit import ramp3
    rgb = ramp3(n, (62, 60, 56), (84, 80, 74), (104, 98, 88))
    yy = np.mgrid[0:H * SS, 0:W * SS][0] / (H * SS)
    xx = np.mgrid[0:H * SS, 0:W * SS][1] / (W * SS)
    dash = ((xx * 4) % 1.0 < 0.5) & (np.abs(yy - 0.5) < 0.025)
    rgb = np.where(dash[..., None], np.array((200, 186, 140)) * 0.85, rgb)
    sand = np.clip((value_noise(W * SS, H * SS, 18 * SS, 64, 3, wrap=True) - 0.55) * 2.5 + np.abs(yy - 0.5) * 1.2 - 0.25, 0, 1)
    rgb = rgb * (1 - sand[..., None] * 0.85) + np.array(SAND_M) * sand[..., None] * 0.85
    alpha = np.clip(np.minimum(yy, 1 - yy) / 0.14, 0, 1)
    c.img = Image.fromarray(np.dstack([np.clip(rgb, 0, 255), alpha * 245]).astype(np.uint8), "RGBA")
    rr2 = random.Random(5)
    for k in range(10):
        x = rr2.uniform(0, W); y = rr2.uniform(20, H - 20)
        for ox in (-W, 0, W):
            c.ink([(x + ox, y), (x + ox + 14, y + rr2.uniform(-10, 10)), (x + ox + 30, y + rr2.uniform(-10, 10))], 1.0, wobble=0.6, alpha=150)
    c.img.resize((W, H), Image.LANCZOS).save(out("ground.asphalt"))


def gen_fx_muzzle():
    fx = os.path.join(ROOT, "assets/fx")
    S = 96
    img = Image.new("RGBA", (S * 2, S * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = S
    r = random.Random(3)
    for k in range(9):   # star flash, longer along the barrel (−y)
        a = -math.pi / 2 + r.uniform(-0.55, 0.55) if k < 5 else r.uniform(0, math.tau)
        L = r.uniform(60, 90) if k < 5 else r.uniform(24, 40)
        tip = (cx + math.cos(a) * L * 2, cx + math.sin(a) * L * 2)
        n = (math.cos(a + math.pi / 2) * 14, math.sin(a + math.pi / 2) * 14)
        d.polygon([(cx + n[0], cx + n[1]), tip, (cx - n[0], cx - n[1])], fill=(255, 200, 110, 210))
    img = img.filter(ImageFilter.GaussianBlur(3))
    d2 = ImageDraw.Draw(img)
    d2.ellipse((cx - 34, cx - 34, cx + 34, cx + 34), fill=(255, 244, 210, 255))
    img = img.filter(ImageFilter.GaussianBlur(2)).resize((S, S), Image.LANCZOS)
    img.save(os.path.join(fx, "muzzle_flash.png"))


def gen_scrap_item():
    c = canvas_for("item.scrap", 503)
    for k, (x, y, col) in enumerate(((26, 30, RUST), (48, 26, STEEL), (40, 46, OXIDE))):
        pl = blob(x, y, 18, 12, 8, 0.25, k, rot=k * 0.7)
        plate(c, pl, col, line=1.8, grime=0.3, hatch_alpha=60)
    c.rivets([(30, 30), (46, 44)], 1.6)
    c.desertize(dust=0.4, abrasion=0.4, bleach=0.3, seams=0.4)
    c.save(out("item.scrap"))


def gen_awning():
    """Salt-works shade sail: stitched tarp panels stretched to four posts, sagging edges."""
    c = canvas_for("shelter.awning", 611)
    W, H = 780, 620
    corners = [(30, 30), (W - 30, 30), (W - 30, H - 30), (30, H - 30)]
    sail = [(40, 40), (W / 2, 70), (W - 40, 40), (W - 70, H / 2), (W - 40, H - 40), (W / 2, H - 72), (40, H - 40), (68, H / 2)]
    m = c.fill(sail, (186, 140, 90), tex=0.4, cell=22, light=(-1, -1, 0.35))
    cols = [(176, 112, 70), (196, 160, 104), (160, 98, 62)]
    for k in range(5):  # stitched panels
        x0 = 40 + k * (W - 80) / 5
        pnl = [(x0, 40), (x0 + (W - 80) / 5, 40), (x0 + (W - 80) / 5, H - 40), (x0, H - 40)]
        pm = Image.fromarray(np.minimum(np.asarray(m), np.asarray(c.mask(pnl))))
        c.fill(None, cols[k % 3], tex=0.35, cell=20, m=pm)
        if k:
            c.ink([(x0, 60), (x0 + 3, H / 2), (x0, H - 60)], 1.2, wobble=0.8, alpha=150)
            for y in range(70, H - 60, 16):
                c.ink([(x0 - 3, y), (x0 + 3, y + 4)], 0.8, wobble=0.1, alpha=120)
    c.shade(m, 1, .6, 6.0, 55, reach=0.45)
    for k in range(4):  # sag folds
        c.ink([(120 + k * 160, 90), (150 + k * 160, H / 2), (120 + k * 160, H - 90)], 1.0, wobble=2.0, alpha=90)
    patch = [(470, 380), (560, 372), (566, 450), (474, 458)]
    plate(c, patch, (120, 120, 104), line=1.6, grime=0.2, hatch=False)
    c.desertize(dust=0.6, abrasion=0.2, bleach=0.6, seams=0.4)
    hole = blob(250, 420, 18, 12, 12, 0.4, 3)
    hm = Image.new("L", c.img.size, 255)
    ImageDraw.Draw(hm).polygon([(px * SS, py * SS) for px, py in hole], fill=0)
    c.img.putalpha(Image.fromarray(np.minimum(np.asarray(c.img.split()[3]), np.asarray(hm))))
    c.ink_poly(hole, 1.6)
    c.ink_poly(sail, 2.6)
    for (a, b) in zip(corners, [sail[0], sail[2], sail[4], sail[6]]):   # ropes to the posts
        c.ink([a, b], 1.6, wobble=0.4, color=(90, 70, 50))
    c.save(out("shelter.awning"))


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


GENS = [gen_junker, gen_cooling_station, gen_roadside, gen_south_tiles, gen_fx_muzzle, gen_mech_housing, gen_twin_gun, gen_enemy_pilot, gen_refuge, gen_rock_tiles, gen_enemy, gen_scrap_item, gen_awning, gen_flag, gen_items, gen_shelter_floor, gen_shelter_roof, gen_shelter_bits, gen_pump_rig, gen_hauler, gen_debris, gen_tiles, gen_fx, gen_mech_hull, gen_mech_leg, gen_mech_radiator, gen_mech_radiator_damage, gen_mech_shutters, gen_pilot, gen_rocks, gen_minerals]

if __name__ == "__main__":
    filt = sys.argv[1:]
    for g in GENS:
        if not filt or any(f in g.__name__ for f in filt):
            g()
            print("done", g.__name__)
