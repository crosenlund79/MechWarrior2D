"""Heat Signature ink kit — the "dirty ink" sprite pipeline.

The core (value_noise, Canvas.fill/ink/shade/soft_shadow/finish) follows Red Thaw's documented
reference kit (ZombieSurvival2D @ iteration/010-red-thaw, docs/visual_direction/export/
GODOT_REPRODUCTION_GUIDE.md §5.1) with its exact values: INK (33,27,21), SS=2, fill warm/cool
drift, brush-pen jitter/taper/dry-brush ghost, −55° shadow-side hatching, finish(outline 2.6,
burn 0.32, grain 0.05).

Heat Signature additions (marked NEW):
  * value_noise(wrap=True) and wrap_draw() for seamless ground tiles
  * grime() — stains + WIND streaks (top-down replacement for Red Thaw's gravity drips)
  * desertize() — the setting pass (replaces Red Thaw's winterize): dust deposits, sand abrasion,
    sun bleaching / faded paint, seam grime, heat discoloration
  * finish(top_down=True) — no vertical base darkening (that cue only makes sense in 3/4 view);
    instead a gentle upper-left → lower-right light falloff
  * helpers: blob(), rrect(), rivets(), slots(), corrugate()
"""
import math, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageChops

SS = 2
INK = (33, 27, 21)
WARM = (214, 176, 112)
COOL = (46, 52, 50)
DUST = (206, 172, 124)
GRIME = tuple(int(INK[i] * 0.6 + (80, 62, 40)[i] * 0.4) for i in range(3))


def value_noise(w, h, cell, seed, octaves=3, wrap=False):
    rng = np.random.default_rng(seed)
    out = np.zeros((h, w), np.float32)
    amp, tot = 1.0, 0.0
    for _ in range(octaves):
        gw, gh = max(2, math.ceil(w / cell)), max(2, math.ceil(h / cell))
        grid = (rng.random((gh, gw)) * 255).astype(np.uint8)
        if wrap:  # tile 3x3, resize, crop the centre → continuous across edges
            big = Image.fromarray(np.tile(grid, (3, 3))).resize((w * 3, h * 3), Image.BICUBIC)
            layer = np.asarray(big, np.float32)[h:2 * h, w:2 * w]
        else:
            layer = np.asarray(Image.fromarray(grid).resize((w, h), Image.BICUBIC), np.float32)
        out += layer / 255 * amp
        tot += amp
        amp *= 0.5
        cell = max(2, cell // 2)
    return out / tot


def blob(cx, cy, rx, ry, n=18, jitter=0.18, seed=0, rot=0.0):
    r = random.Random(seed)
    pts = []
    for i in range(n):
        a = i / n * math.tau
        k = 1 + r.uniform(-jitter, jitter)
        x, y = math.cos(a) * rx * k, math.sin(a) * ry * k
        pts.append((cx + x * math.cos(rot) - y * math.sin(rot), cy + x * math.sin(rot) + y * math.cos(rot)))
    return pts


def rrect(x0, y0, x1, y1, r=6, wob=0.0, seed=0):
    """Rounded rectangle polygon with optional hand wobble."""
    rr = random.Random(seed)
    pts = []
    for cx, cy, a0 in ((x1 - r, y0 + r, -90), (x1 - r, y1 - r, 0), (x0 + r, y1 - r, 90), (x0 + r, y0 + r, 180)):
        for k in range(5):
            a = math.radians(a0 + k * 22.5)
            pts.append((cx + math.cos(a) * r + rr.uniform(-wob, wob), cy + math.sin(a) * r + rr.uniform(-wob, wob)))
    return pts


class Canvas:
    def __init__(s, w, h, seed=1):
        s.w, s.h, s.seed, s.rng = w, h, seed, random.Random(seed)
        s.img = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))

    # ---------------- Red Thaw reference kit ----------------
    def mask(s, poly):
        m = Image.new("L", s.img.size, 0)
        ImageDraw.Draw(m).polygon([(x * SS, y * SS) for x, y in poly], fill=255)
        return m

    def ellipse_mask(s, box):
        m = Image.new("L", s.img.size, 0)
        ImageDraw.Draw(m).ellipse([v * SS for v in box], fill=255)
        return m

    def fill(s, poly, col, tex=0.25, cell=10, grain=0.06, light=(-1, -1, 0.3), m=None):
        m = m if m is not None else s.mask(poly)
        bb = m.getbbox()
        if not bb:
            return m
        x0, y0, x1, y1 = bb
        w, h = x1 - x0, y1 - y0
        sd = s.rng.randint(0, 1 << 30)
        n = value_noise(w, h, cell * SS, sd)
        n2 = value_noise(w, h, max(4, cell * SS * 3), sd + 7, 2)
        g = np.random.default_rng(sd + 3).random((h, w))
        fib = value_noise(w, h, 3, sd + 11, 1)
        shade = 1 + (n - .5) * 1.3 * tex + (g - .5) * 1.6 * grain + (fib - .5) * .07
        yy, xx = np.mgrid[0:h, 0:w]
        dx, dy, st = light
        lit = st * (-(xx / max(1, w) - .5) * dx - (yy / max(1, h) - .5) * dy)
        shade *= 1 + lit
        wm = np.clip((n2 - .5) * .9 + lit, -1, 1)
        wp, wn = np.clip(wm, 0, 1)[..., None], np.clip(-wm, 0, 1)[..., None]
        b = np.array(col[:3], np.float32)
        warm = b * .82 + np.array(WARM) * .18
        cool = b * .8 + np.array(COOL) * .2
        rgb = np.clip((b * (1 - .45 * wp - .55 * wn) + warm * .45 * wp + cool * .55 * wn) * shade[..., None], 0, 255)
        layer = Image.new("RGBA", s.img.size)
        tile = np.dstack([rgb, np.full((h, w), 255)]).astype(np.uint8)
        layer.paste(Image.fromarray(tile, "RGBA"), (x0, y0), m.crop((x0, y0, x1, y1)))
        s.img = Image.alpha_composite(s.img, layer)
        return m

    def fill_ellipse(s, box, col, **kw):
        return s.fill(None, col, m=s.ellipse_mask(box), **kw)

    def ink(s, pts, width=2.0, wobble=0.9, alpha=235, seg=6, color=INK):
        if len(pts) < 2:
            return
        path = []
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            L = math.hypot(bx - ax, by - ay)
            n = max(1, int(L / seg))
            path += [(ax + (bx - ax) * i / n, ay + (by - ay) * i / n, (bx - ax) / max(L, 1e-6), (by - ay) / max(L, 1e-6)) for i in range(n)]
        path.append((*pts[-1], 0, 0))
        ph = s.rng.uniform(0, 100)
        P = []
        for i, (x, y, tx, ty) in enumerate(path):
            off = (math.sin(ph + i * .7) * .5 + s.rng.uniform(-.5, .5)) * wobble
            w = width * (.7 + .55 * (math.sin(ph * 1.7 + i * .35) * .5 + .5)) * s.rng.uniform(.85, 1.12)
            t = i / max(1, len(path) - 1)
            w *= .45 + .55 * min(1, min(t, 1 - t) * 5) if len(path) > 6 else 1
            P.append(((x - ty * off) * SS, (y + tx * off) * SS, w * SS))
        layer = Image.new("RGBA", s.img.size)
        d = ImageDraw.Draw(layer)
        c = tuple(color) + (alpha,)
        prev = None
        for x, y, w in P:
            if prev:
                d.line([prev, (x, y)], fill=c, width=max(1, int(w)))
            d.ellipse((x - w / 2, y - w / 2, x + w / 2, y + w / 2), fill=c)
            prev = (x, y)
        if width >= 1.6 and alpha >= 150 and len(P) > 3:  # dry-brush ghost
            k0 = s.rng.randint(0, len(P) // 3)
            k1 = min(len(P), k0 + s.rng.randint(len(P) // 3, len(P)))
            gp = None
            for x, y, w in P[k0:k1]:
                q = (x + .9 * SS, y + .7 * SS)
                if gp and s.rng.random() > .12:
                    d.line([gp, q], fill=tuple(color) + (int(alpha * .38),), width=max(1, int(w * .45)))
                gp = q
        s.img = Image.alpha_composite(s.img, layer)

    def ink_poly(s, poly, width=2.2, **kw):
        s.ink(list(poly) + [poly[0]], width, **kw)

    def ink_ellipse(s, box, width=2.0, n=28, **kw):
        cx, cy = (box[0] + box[2]) / 2, (box[1] + box[3]) / 2
        rx, ry = (box[2] - box[0]) / 2, (box[3] - box[1]) / 2
        s.ink_poly([(cx + math.cos(a) * rx, cy + math.sin(a) * ry) for a in np.linspace(0, math.tau, n, endpoint=False)], width, **kw)

    def shade(s, m, dx=1.0, dy=0.6, spacing=4.5, alpha=95, angle=-55, reach=0.55, cross=False):
        bb = m.getbbox()
        if not bb:
            return
        x0, y0, x1, y1 = bb
        W, H = s.img.size
        yy, xx = np.mgrid[0:H, 0:W]
        u = ((xx - x0) / max(1, x1 - x0) - .5) * dx + ((yy - y0) / max(1, y1 - y0) - .5) * dy
        side = np.clip((u + .5 - (1 - reach)) / max(.05, reach), 0, 1)
        sm = Image.fromarray((np.asarray(m, np.float32) * side).astype(np.uint8), "L")
        for ang, sp, al, smask in ((angle, spacing, alpha, sm),) + (((angle + 85, spacing * 1.1, int(alpha * .8),
                Image.fromarray((np.asarray(m, np.float32) * np.clip(side * 2 - 1, 0, 1)).astype(np.uint8), "L")),) if cross else ()):
            layer = Image.new("RGBA", (W, H))
            d = ImageDraw.Draw(layer)
            a = math.radians(ang)
            ddx, ddy = math.cos(a), math.sin(a)
            L = W + H
            k = -L
            while k < L:
                o = k + s.rng.uniform(-.6, .6) * SS
                cx, cy = W / 2 - ddy * o, H / 2 + ddx * o
                d.line([(cx - ddx * L, cy - ddy * L), (cx + ddx * L, cy + ddy * L)], fill=INK + (al,), width=SS)
                k += sp * SS
            clip = Image.new("RGBA", (W, H))
            clip.paste(layer, (0, 0), ImageChops.multiply(smask, layer.split()[3]))
            s.img = Image.alpha_composite(s.img, clip)

    def soft_shadow(s, box, alpha=120, blur=8, poly=None):
        m = Image.new("L", s.img.size, 0)
        if poly:
            ImageDraw.Draw(m).polygon([(x * SS, y * SS) for x, y in poly], fill=alpha)
        else:
            ImageDraw.Draw(m).ellipse([v * SS for v in box], fill=alpha)
        layer = Image.new("RGBA", s.img.size, (20, 18, 12, 0))
        layer.putalpha(m.filter(ImageFilter.GaussianBlur(blur * SS)))
        s.img = Image.alpha_composite(s.img, layer)

    def finish(s, outline=2.6, burn=0.32, grain=0.05, top_down=True):
        a = s.img.split()[3]
        A = np.asarray(a, np.float32) / 255
        H, W = A.shape
        thin = np.asarray(a.filter(ImageFilter.MaxFilter(max(3, int(outline * SS * .7) | 1))), np.float32) / 255
        thick = np.asarray(a.filter(ImageFilter.MaxFilter(max(3, int(outline * SS * 1.5) | 1))), np.float32) / 255
        n = value_noise(W, H, 9 * SS, s.seed + 991)
        ring = np.clip(np.where(n > .5, thick, thin) - A, 0, 1) * (.7 + .3 * (np.random.default_rng(s.seed).random((H, W)) > .08))
        blur = np.asarray(a.filter(ImageFilter.GaussianBlur(5 * SS)), np.float32) / 255
        edge = np.clip((A - blur) * 2.2, 0, 1)
        if top_down:  # NEW: light falloff upper-left → lower-right instead of 3/4 base darkening
            yy, xx = np.mgrid[0:H, 0:W]
            topd = (1.05 - 0.13 * ((xx / W) * 0.45 + (yy / H) * 0.55))[..., None]
        else:
            topd = np.linspace(.9, 1.06, H)[::-1][:, None][..., None]
        rgb = np.asarray(s.img, np.float32)[..., :3] * (1 - edge[..., None] * burn) * topd * (1 + (n - .5) * 2 * grain)[..., None]
        tot = np.clip(A + ring, 0, 1)
        out = (rgb * A[..., None] + np.array(INK) * ring[..., None]) / np.maximum(tot, 1e-6)[..., None]
        s.img = Image.fromarray(np.dstack([np.clip(out, 0, 255), tot * 255]).astype(np.uint8), "RGBA")

    def save(s, path, finish=True, **fkw):
        if finish:
            s.finish(**fkw)
        s.img.resize((s.w, s.h), Image.LANCZOS).save(path)

    # ---------------- NEW helpers ----------------
    def grime(s, m, amount=0.4, streaks=6, wind=(1.0, 0.25)):
        """Noise-thresholded stains + streaks dragged downwind (top-down: no gravity drips)."""
        W, H = s.img.size
        n = value_noise(W, H, 14 * SS, s.rng.randint(0, 1 << 30), 3)
        M = np.asarray(m, np.float32) / 255
        st = np.clip((n - (0.62 - amount * 0.25)) * 3.0, 0, 1) * 0.55 * M
        layer = np.zeros((H, W, 4), np.float32)
        layer[..., :3] = GRIME
        layer[..., 3] = st * 255
        img = Image.fromarray(layer.astype(np.uint8), "RGBA")
        d = ImageDraw.Draw(img)
        bb = m.getbbox()
        if bb:
            for _ in range(streaks):
                x = s.rng.uniform(bb[0], bb[2]); y = s.rng.uniform(bb[1], bb[3])
                if m.getpixel((int(min(W - 1, x)), int(min(H - 1, y)))) < 128:
                    continue
                L = s.rng.uniform(10, 40) * SS
                for k in range(12):
                    t = k / 12
                    d.line([(x + wind[0] * L * t, y + wind[1] * L * t), (x + wind[0] * L * (t + .09), y + wind[1] * L * (t + .09))],
                           fill=GRIME + (int(120 * (1 - t) * amount),), width=max(1, int(SS * (2.2 - t * 1.6))))
        clip = Image.new("RGBA", (W, H))
        clip.paste(img, (0, 0), ImageChops.multiply(m, img.split()[3]))
        s.img = Image.alpha_composite(s.img, clip)

    def rivets(s, pts, r=1.6):
        for x, y in pts:
            s.fill_ellipse((x - r, y - r, x + r, y + r), (120, 108, 92), tex=0.1)
            s.ink([(x - r * .6, y + r * .8), (x + r * .9, y + r * .2)], 0.8, wobble=0.1, alpha=200)

    def slots(s, x0, y0, x1, y1, n, vertical=True, width=1.2, alpha=210):
        for i in range(n):
            t = (i + .5) / n
            if vertical:
                x = x0 + (x1 - x0) * t
                s.ink([(x, y0), (x, y1)], width, wobble=0.25, alpha=alpha)
            else:
                y = y0 + (y1 - y0) * t
                s.ink([(x0, y), (x1, y)], width, wobble=0.25, alpha=alpha)

    def corrugate(s, poly, col, spacing=7, vertical=True, alpha=120):
        """Corrugated sheet: base fill + alternating light/dark ridges + ink grooves."""
        m = s.fill(poly, col, tex=0.3, cell=14)
        bb = m.getbbox()
        x0, y0, x1, y1 = [v / SS for v in bb]
        layer = Image.new("RGBA", s.img.size)
        d = ImageDraw.Draw(layer)
        k = 0
        rng = (x0, x1) if vertical else (y0, y1)
        v = rng[0]
        while v < rng[1]:
            light = k % 2 == 0
            c = (255, 240, 210, 36) if light else (20, 16, 10, 46)
            if vertical:
                d.rectangle([v * SS, y0 * SS, (v + spacing / 2) * SS, y1 * SS], fill=c)
            else:
                d.rectangle([x0 * SS, v * SS, x1 * SS, (v + spacing / 2) * SS], fill=c)
            v += spacing / 2
            k += 1
        clip = Image.new("RGBA", s.img.size)
        clip.paste(layer, (0, 0), ImageChops.multiply(m, layer.split()[3]))
        s.img = Image.alpha_composite(s.img, clip)
        v = rng[0] + spacing
        while v < rng[1] - 1:
            if vertical:
                s.ink([(v, y0 + 1), (v, y1 - 1)], 0.9, wobble=0.35, alpha=alpha)
            else:
                s.ink([(x0 + 1, v), (x1 - 1, v)], 0.9, wobble=0.35, alpha=alpha)
            v += spacing
        return m

    def desertize(s, dust=0.5, abrasion=0.5, bleach=0.4, seams=0.5, heat=(), wind=(1.0, 0.25), m=None):
        """NEW setting pass (replaces Red Thaw's winterize). Material-aware via parameters:
        metal: abrasion+bleach+seams; rock: dust+abrasion; cloth: bleach; heat=[(cx,cy,r,strength)] temper tint."""
        arr = np.asarray(s.img, np.float32)
        rgb, A = arr[..., :3], arr[..., 3] / 255
        H, W = A.shape
        if m is not None:
            A = A * (np.asarray(m, np.float32) / 255)
        sd = s.rng.randint(0, 1 << 30)
        lum = rgb @ np.array([.299, .587, .114], np.float32)
        # 1. sun bleaching / faded paint: saturated pixels lose chroma most, brights lift toward bone white
        if bleach > 0:
            sat = (rgb.max(-1) - rgb.min(-1)) / 255
            k = np.clip(bleach * (0.35 + sat * 0.9), 0, 0.8)[..., None]
            rgb = rgb * (1 - k) + lum[..., None] * k
            lift = np.clip((lum / 255 - 0.45) * 1.6, 0, 1)[..., None] * bleach * 0.35
            rgb = rgb * (1 - lift) + np.array((238, 226, 200), np.float32) * lift
        # 2. seam grime: cavities (darker than surroundings) get darker and browner
        if seams > 0:
            blur = np.asarray(Image.fromarray(lum.astype(np.uint8)).filter(ImageFilter.GaussianBlur(3 * SS)), np.float32)
            cav = np.clip((blur - lum) / 40.0, 0, 1)[..., None] * seams
            rgb = rgb * (1 - cav * 0.45) + np.array(GRIME, np.float32) * cav * 0.25
        # 3. sand abrasion: windward edges (facing the upper-left wind source) scoured lighter
        if abrasion > 0:
            a_img = Image.fromarray((A * 255).astype(np.uint8))
            shift = ImageChops.offset(a_img, int(-wind[0] * 3 * SS), int(-wind[1] * 3 * SS))
            edge = np.clip(A - np.asarray(shift, np.float32) / 255, 0, 1)
            edge = np.asarray(Image.fromarray((edge * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.5 * SS)), np.float32) / 255
            n = value_noise(W, H, 4 * SS, sd + 5, 2)
            sc = (edge * 1.6 + np.clip((n - 0.72) * 2.0, 0, 1) * 0.5)[..., None] * abrasion
            rgb = rgb * (1 - np.clip(sc, 0, .7)) + np.array((214, 196, 166), np.float32) * np.clip(sc, 0, .7)
        # 4. heat discoloration: straw → bronze → blue-violet temper rings
        for cx, cy, r, st in heat:
            yy, xx = np.mgrid[0:H, 0:W]
            dd = np.sqrt((xx - cx * SS) ** 2 + (yy - cy * SS) ** 2) / (r * SS)
            w = np.clip(1 - dd, 0, 1) * st
            tint = np.where((dd < .45)[..., None], np.array((70, 72, 110), np.float32),
                            np.where((dd < .75)[..., None], np.array((150, 96, 60), np.float32), np.array((196, 162, 96), np.float32)))
            rgb = rgb * (1 - w[..., None] * .5) + tint * w[..., None] * .5
        # 5. fine dust deposits: speckled film, heavier in the wind shadow (lower-right) of shapes
        if dust > 0:
            a_img = Image.fromarray((arr[..., 3]).astype(np.uint8))
            lee = ImageChops.offset(a_img, int(wind[0] * 5 * SS), int(wind[1] * 5 * SS))
            lee_edge = np.clip(arr[..., 3] / 255 - np.asarray(lee, np.float32) / 255, 0, 1)
            lee_edge = np.asarray(Image.fromarray((lee_edge * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(4 * SS)), np.float32) / 255
            n = value_noise(W, H, 10 * SS, sd + 9, 3)
            sp = np.random.default_rng(sd).random((H, W))
            film = np.clip((n - .45) * 1.5, 0, 1) * .35 + (sp > .985) * .5 + lee_edge * .9
            film = np.clip(film * dust, 0, .75)[..., None]
            rgb = rgb * (1 - film) + np.array(DUST, np.float32) * film
        out = arr.copy()
        Am = A[..., None]
        out[..., :3] = arr[..., :3] * (1 - Am) + np.clip(rgb, 0, 255) * Am
        s.img = Image.fromarray(out.astype(np.uint8), "RGBA")


# ---------------- ground tiles (NEW helpers for seamless top-down ground) ----------------
def ramp3(n, dark, mid, light):
    n = np.clip(n, 0, 1)[..., None]
    a, b, c = (np.array(x, np.float32) for x in (dark, mid, light))
    return np.where(n < .5, a + (b - a) * (n / .5), b + (c - b) * ((n - .5) / .5))


class Tile:
    """Seamless tile: noise ramp + small inked marks drawn at 9 wrap offsets. No finish()."""
    def __init__(s, size, seed):
        s.size, s.seed, s.rng = size, seed, random.Random(seed)
        s.c = Canvas(size, size, seed)
        s.c.img = Image.new("RGBA", (size * SS, size * SS), (0, 0, 0, 255))

    def base(s, dark, mid, light, cell=96, octaves=5, white=0.06):
        S = s.size * SS
        n = value_noise(S, S, cell * SS, s.seed, octaves, wrap=True)
        n = (n - n.min()) / max(1e-6, n.max() - n.min())
        rgb = ramp3(n, dark, mid, light)
        rgb *= (1 + (np.random.default_rng(s.seed).random((S, S)) - .5) * 2 * white)[..., None]
        s.c.img = Image.fromarray(np.dstack([np.clip(rgb, 0, 255), np.full((S, S), 255)]).astype(np.uint8), "RGBA")
        return n

    def wrap_draw(s, fn):
        for ox in (-s.size, 0, s.size):
            for oy in (-s.size, 0, s.size):
                fn(ox, oy)

    def overlay(s, arr_rgba):
        s.c.img = Image.alpha_composite(s.c.img, Image.fromarray(arr_rgba.astype(np.uint8), "RGBA"))

    def save(s, path, alpha=None):
        img = s.c.img.resize((s.size, s.size), Image.LANCZOS)
        img.save(path)
