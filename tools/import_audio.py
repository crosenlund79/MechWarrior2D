#!/usr/bin/env python3
"""Imports selected creator audio from `assets/audio inbox` into assets/templates/audio/
(per tools/audio_map.json). Originals are never modified. Needs ffmpeg + numpy.
  python3 tools/import_audio.py"""
import json, os, subprocess, sys
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INBOX = os.path.join(ROOT, "assets", "audio inbox")
MAN = json.load(open(os.path.join(ROOT, "assets/manifest/assets.json")))["sounds"]
MAP = json.load(open(os.path.join(ROOT, "tools/audio_map.json")))
SR = 44100


def decode(path, channels):
    raw = subprocess.run(["ffmpeg", "-v", "quiet", "-i", path, "-ac", str(channels), "-ar", str(SR), "-f", "f32le", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32).reshape(-1, channels).copy()


def encode(x, path, codec):
    args = ["ffmpeg", "-v", "quiet", "-y", "-f", "f32le", "-ar", str(SR), "-ac", str(x.shape[1]), "-i", "-"]
    args += ["-c:a", "libvorbis", "-q:a", "5"] if codec == "ogg" else ["-c:a", "pcm_s16le"]
    subprocess.run(args + [path], input=x.astype(np.float32).tobytes(), check=True)


def template_base(id_):
    d, n = os.path.split(MAN[id_]["path"])
    folder = os.path.join(ROOT, "assets/templates", d)
    os.makedirs(folder, exist_ok=True)
    return os.path.join(folder, "template_" + n)


for id_, e in MAP.items():
    if id_.startswith("_"):
        continue
    src = os.path.join(INBOX, e["src"])
    base = template_base(id_)
    for ext in (".wav", ".ogg", ".mp3"):   # one source file per id
        for suffix in ("", ".import"):
            if os.path.exists(base + ext + suffix):
                os.remove(base + ext + suffix)
    if e["mode"] == "copy":
        with open(src, "rb") as f, open(base + ".mp3", "wb") as o:
            o.write(f.read())
        print(f"{id_:18s} copy  {e['src']}")
        continue
    if e["mode"] == "loop":
        x = decode(src, 2)
        if "max_seconds" in e:
            x = x[: int(SR * e["max_seconds"])]
        f = int(SR * 2.0)          # crossfade the tail into the head → seamless loop point
        head = x[:f].copy()
        x = x[f:]
        ramp = np.linspace(0, 1, f)[:, None]
        x[-f:] = x[-f:] * (1 - ramp) + head * ramp
        encode(x, base + ".ogg", "ogg")
        print(f"{id_:18s} loop  {e['src']} ({len(x)/SR:.1f}s)")
        continue
    x = decode(src, 1)
    if "max_seconds" in e:
        x = x[: int(SR * e["max_seconds"])]
    env = np.abs(x[:, 0])
    above = np.where(env > 10 ** (-50 / 20))[0]   # trim leading/trailing silence (-50 dBFS)
    if len(above):
        x = x[max(0, above[0] - 200): above[-1] + 2000]
    fade = min(len(x), int(SR * 0.06))
    x[-fade:] *= np.linspace(1, 0, fade)[:, None]
    pk = np.max(np.abs(x))
    if pk > 0.98:
        x *= 0.98 / pk
    encode(x, base + ".wav", "wav")
    print(f"{id_:18s} shot  {e['src']} ({len(x)/SR:.2f}s)")
