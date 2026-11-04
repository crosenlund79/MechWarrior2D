#!/usr/bin/env python3
"""Phase A diagnostic placeholders for every sprite/tile in the manifest.

Flat shapes at display size with the logical ID and a facing arrow, so
scale, pivots, rotation and layering can be checked before real art exists.
Usage: python3 tools/gen_placeholders.py [--force]   (only writes missing files unless --force)
"""
import json, os, sys
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAN = json.load(open(os.path.join(ROOT, "assets/manifest/assets.json")))
FORCE = "--force" in sys.argv
COLORS = {"mech": (150, 120, 90), "pilot": (90, 160, 170), "item": (230, 190, 60), "shelter": (120, 110, 100),
          "wreck": (140, 80, 60), "prop": (130, 115, 95)}


def out_path(rel):
    d, n = os.path.split(rel)
    p = os.path.join(ROOT, "assets/templates", d, "template_" + n + ".png")
    os.makedirs(os.path.dirname(p), exist_ok=True)
    return p


def sprite(id_, e):
    w, h = e["display"]
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    col = COLORS.get(id_.split(".")[0], (128, 128, 128))
    round_ = id_.startswith(("prop.rock", "prop.stones", "prop.mineral", "item", "shelter.barrels", "shelter.cistern", "shelter.post"))
    box = [1, 1, w - 2, h - 2]
    if round_:
        d.ellipse(box, fill=col + (230,), outline=(20, 20, 20, 255), width=2)
    else:
        d.rectangle(box, fill=col + (200 if id_ != "shelter.roof" else 170,), outline=(20, 20, 20, 255), width=2)
    if e.get("rotates"):
        cx = w // 2
        d.polygon([(cx, 4), (cx - min(14, w // 4), 4 + min(20, h // 3)), (cx + min(14, w // 4), 4 + min(20, h // 3))], fill=(240, 60, 40, 255))
    if id_ == "mech.radiator_damage":
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        for i in range(6):
            d.line([(10 + i * 24, 6), (20 + i * 24, h - 6)], fill=(200, 30, 30, 220), width=3)
    if w >= 60 and h >= 24:
        d.text((6, h // 2 - 6), id_, fill=(255, 255, 255, 255))
    img.save(out_path(e["path"]))


def tile(id_, e):
    w, h = e["display"]
    base = {"ground.sand": (196, 160, 112), "ground.dunes": (214, 176, 120), "ground.saltpan": (210, 200, 180), "ground.track": (150, 120, 90)}[id_]
    img = Image.new("RGBA", (w, h), base + (255,))
    d = ImageDraw.Draw(img)
    for x in range(0, w, 64):
        d.line([(x, 0), (x, h)], fill=tuple(int(c * 0.9) for c in base) + (255,))
    for y in range(0, h, 64):
        d.line([(0, y), (w, y)], fill=tuple(int(c * 0.9) for c in base) + (255,))
    if id_ == "ground.track":
        a = img.split()[3]
        ad = ImageDraw.Draw(a)
        for y in range(h):
            edge = min(y, h - 1 - y) / (h * 0.25)
            ad.line([(0, y), (w, y)], fill=int(255 * min(1.0, edge)))
        img.putalpha(a)
    d.text((8, 8), id_, fill=(40, 30, 20, 255))
    img.save(out_path(e["path"]))


n = 0
for group, fn in (("sprites", sprite), ("tiles", tile)):
    for id_, e in MAN[group].items():
        p = out_path(e["path"])
        if FORCE or not os.path.exists(p):
            fn(id_, e)
            n += 1
print(f"placeholders written: {n}")
