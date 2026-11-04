#!/usr/bin/env python3
"""Generates the bundled placeholder sounds (16-bit mono WAV, 44.1 kHz) into
assets/templates/audio/... Synthesised with numpy so no external samples or
licences are involved. Replace any of them via the override folders.
Usage: python3 tools/gen_audio.py
"""
import os, wave
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SR = 44100
rng = np.random.default_rng(42)


def save(rel, x):
    d, n = os.path.split(rel)
    p = os.path.join(ROOT, "assets/templates", d, "template_" + n + ".wav")
    os.makedirs(os.path.dirname(p), exist_ok=True)
    x = np.clip(x, -1, 1)
    with wave.open(p, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32000).astype(np.int16).tobytes())


def t(sec):
    return np.arange(int(SR * sec)) / SR


def noise(sec):
    return rng.standard_normal(int(SR * sec))


def lowpass(x, a):  # one-pole
    y = np.empty_like(x); acc = 0.0
    for i, v in enumerate(x):
        acc += a * (v - acc); y[i] = acc
    return y


def env(n, attack=0.01, release=0.2):
    e = np.ones(n); a = int(attack * SR); r = int(release * SR)
    if a: e[:a] = np.linspace(0, 1, a)
    if r: e[-r:] *= np.linspace(1, 0, r)
    return e


def loopify(x, fade=0.25):
    f = int(fade * SR)
    x = x.copy(); head = x[:f].copy()
    x = x[f:]
    x[-f:] = x[-f:] * np.linspace(1, 0, f) + head * np.linspace(0, 1, f)
    return x


tt = t(4.0)
engine = 0.35 * np.sin(2 * np.pi * 42 * tt) + 0.2 * np.sin(2 * np.pi * 84 * tt + 0.3) + 0.12 * np.sign(np.sin(2 * np.pi * 21 * tt))
engine *= 0.8 + 0.2 * np.sin(2 * np.pi * 3.5 * tt)
engine += 0.18 * lowpass(noise(4.0), 0.05)
save("audio/sfx/mech_engine", loopify(engine * 0.6))
fan = lowpass(noise(3.0), 0.25) * 0.35 + 0.08 * np.sin(2 * np.pi * 180 * t(3.0))
fan *= 0.85 + 0.15 * np.sin(2 * np.pi * 9 * t(3.0))
save("audio/sfx/cooling_fan", loopify(fan * 0.7))
st = t(0.45)
step = (np.sin(2 * np.pi * (55 - 30 * st) * st) * np.exp(-st * 9) + lowpass(noise(0.45), 0.08) * np.exp(-st * 14) * 0.8)
step += 0.25 * np.sin(2 * np.pi * 320 * st) * np.exp(-st * 30)
save("audio/sfx/mech_step", step * 0.8)
ft = t(0.16)
save("audio/sfx/footstep", lowpass(noise(0.16), 0.3) * np.exp(-ft * 30) * 0.6)
wt = t(0.22)
save("audio/sfx/warning", (np.sign(np.sin(2 * np.pi * 880 * wt)) * 0.25 + np.sin(2 * np.pi * 1760 * wt) * 0.1) * env(len(wt), 0.005, 0.05))
at = t(1.4)
save("audio/sfx/alarm", np.sign(np.sin(2 * np.pi * (520 + 200 * np.sign(np.sin(2 * np.pi * 3 * at))) * at)) * 0.22 * env(len(at), 0.01, 0.3))
sm = t(1.6)
save("audio/sfx/steam", (noise(1.6) - lowpass(noise(1.6), 0.2)) * 0.45 * env(len(sm), 0.05, 1.0))
ht = t(0.6)
hatch = np.sin(2 * np.pi * 70 * ht) * np.exp(-ht * 6) * 0.6 + lowpass(noise(0.6), 0.4) * np.exp(-ht * 20) * 0.5
hatch[int(0.3 * SR):] += 0.5 * np.sin(2 * np.pi * 140 * ht[: len(ht) - int(0.3 * SR)]) * np.exp(-ht[: len(ht) - int(0.3 * SR)] * 25)
save("audio/sfx/hatch", hatch)
pt = t(0.5)
save("audio/sfx/pickup", (np.sin(2 * np.pi * 440 * pt) * (pt < 0.12) + np.sin(2 * np.pi * 660 * pt) * (pt >= 0.12)) * 0.3 * env(len(pt), 0.005, 0.2))
rt = t(1.2)
rep = np.zeros(len(rt))
for k, start in enumerate([0.0, 0.25, 0.5, 0.8]):
    i = int(start * SR); seg = rt[: len(rt) - i]
    rep[i:] += np.sin(2 * np.pi * (900 + 150 * k) * seg) * np.exp(-seg * 22) * 0.4
save("audio/sfx/repair", rep)
tl = t(0.35)
save("audio/sfx/tool", (np.sin(2 * np.pi * 1200 * tl) * np.exp(-tl * 18) * 0.3 + lowpass(noise(0.35), 0.5) * np.exp(-tl * 25) * 0.3))
sh = t(0.7)
save("audio/sfx/shutters", lowpass(noise(0.7), 0.15) * 0.5 * env(len(sh), 0.02, 0.2) + np.sin(2 * np.pi * 95 * sh) * np.exp(-((sh - 0.6) * 30) ** 2) * 0.5)
su = t(0.6)
save("audio/sfx/suit_alarm", np.sin(2 * np.pi * 1300 * su) * ((su % 0.2) < 0.1) * 0.25 * env(len(su), 0.002, 0.05))
gr = t(0.5)
save("audio/sfx/grit", (noise(0.5) - lowpass(noise(0.5), 0.5)) * (rng.random(len(gr)) > 0.7) * 0.5 * env(len(gr), 0.05, 0.3))
wd = t(10.0)
wind = lowpass(noise(10.0), 0.02) * 3.0
wind *= 0.6 + 0.4 * np.sin(2 * np.pi * 0.11 * wd) * np.sin(2 * np.pi * 0.047 * wd + 1)
wind += (noise(10.0) - lowpass(noise(10.0), 0.3)) * 0.03 * (0.5 + 0.5 * np.sin(2 * np.pi * 0.2 * wd))
save("audio/ambience/wind", loopify(wind * 0.45, 1.0))
dt_ = t(16.0)
drone = sum(a * np.sin(2 * np.pi * f * dt_ + p) for a, f, p in [(0.25, 55, 0), (0.18, 82.4, 1), (0.1, 110.3, 2), (0.06, 164.6, 0.5)])
drone *= 0.7 + 0.3 * np.sin(2 * np.pi * dt_ / 16.0)
drone += lowpass(noise(16.0), 0.01) * 0.6
save("audio/music/drone", loopify(drone * 0.35, 2.0))
ct = t(0.06)
save("audio/ui/click", np.sin(2 * np.pi * 1500 * ct) * np.exp(-ct * 80) * 0.3)
print("audio written")
