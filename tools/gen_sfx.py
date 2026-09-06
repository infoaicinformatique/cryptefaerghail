#!/usr/bin/env python3
"""Genere data/sfx.bin : les bruitages du jeu, synthetises.

Format, tout en gros-boutiste :
    mot        nombre d'effets
    par effet  long offset, mot longueur en mots, mot periode,
               mot volume, mot duree en tics de 50 Hz  (12 octets)
    puis       les echantillons 8 bits signes, bout a bout

Le canal 3 de Paula est emprunte a la musique le temps de l'effet ; la
duree en tics dit au replayer combien de temps le laisser tranquille.

    python3 tools/gen_sfx.py
"""
import math
import os
import random
import struct

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "data", "sfx.bin")
PAL_CLOCK = 3546895


def clamp8(v):
    return max(-128, min(127, int(round(v))))


def swing(n, f0, f1, bright, seed):
    """Sifflement d'une arme fendant l'air : bruit filtre qui monte."""
    rnd = random.Random(seed)
    out, prev = [], 0.0
    for i in range(n):
        t = i / n
        env = math.sin(math.pi * t) ** 1.5
        cut = f0 + (f1 - f0) * t
        prev += (rnd.uniform(-1, 1) - prev) * cut
        out.append(clamp8(120 * env * (prev * bright)))
    return out


def impact(n, freq, seed, noisy=0.6):
    rnd = random.Random(seed)
    out = []
    for i in range(n):
        t = i / n
        env = math.exp(-7 * t)
        tone = math.sin(2 * math.pi * freq * i / 8000 * (1 - 0.5 * t))
        out.append(clamp8(125 * env * (noisy * rnd.uniform(-1, 1)
                                       + (1 - noisy) * tone)))
    return out


def tone_seq(steps, dur, seed=0, wave="square"):
    """Suite de notes courtes : pieces, montee de niveau, sort."""
    out = []
    for f in steps:
        for i in range(dur):
            t = i / dur
            env = math.exp(-3.5 * t)
            ph = (f * i / 8000.0) % 1.0
            v = (1.0 if ph < 0.5 else -1.0) if wave == "square" \
                else math.sin(2 * math.pi * ph)
            out.append(clamp8(110 * env * v))
    return out


def creak(n, seed):
    """Grincement : frottement lent, hauteur qui traine."""
    rnd = random.Random(seed)
    out, prev = [], 0.0
    for i in range(n):
        t = i / n
        env = min(1.0, 4 * t) * math.exp(-2.2 * t)
        f = 70 + 40 * math.sin(2 * math.pi * 3 * t)
        prev += (rnd.uniform(-1, 1) - prev) * 0.08
        grain = 1.0 if (i // max(1, int(8000 / f))) % 2 else -0.7
        out.append(clamp8(105 * env * (0.6 * grain + 0.4 * prev)))
    return out


def growl(n, seed):
    rnd = random.Random(seed)
    out, prev = [], 0.0
    for i in range(n):
        t = i / n
        env = math.sin(math.pi * t) ** 0.7
        prev += (rnd.uniform(-1, 1) - prev) * 0.05
        tone = math.sin(2 * math.pi * (60 + 15 * math.sin(2 * math.pi * 6 * t))
                        * i / 8000)
        out.append(clamp8(120 * env * (0.55 * tone + 0.6 * prev)))
    return out


def sparkle(n, seed):
    out = []
    for i in range(n):
        t = i / n
        env = math.sin(math.pi * t) ** 0.8
        f = 300 + 1400 * t + 300 * math.sin(2 * math.pi * 9 * t)
        out.append(clamp8(105 * env * math.sin(2 * math.pi * f * i / 8000)))
    return out


def descend(n, f0, f1):
    out = []
    for i in range(n):
        t = i / n
        env = math.exp(-2.0 * t)
        f = f0 + (f1 - f0) * t
        out.append(clamp8(115 * env * math.sin(2 * math.pi * f * i / 8000)))
    return out


def snap(n, seed):
    """Detente d'un piege : un claquement sec, puis le sifflement des
    darts. Bruit blanc pique d'une resonance qui descend vite."""
    rnd = random.Random(seed)
    out, prev = [], 0.0
    for i in range(n):
        t = i / n
        env = math.exp(-9.0 * t) + 0.35 * math.exp(-2.5 * t)
        prev += (rnd.uniform(-1, 1) - prev) * (0.9 - 0.6 * t)
        ring = math.sin(2 * math.pi * (2600 - 1900 * t) * i / 8000)
        out.append(clamp8(120 * env * (0.6 * prev + 0.4 * ring)))
    return out


def coins(n, seed):
    """Des pieces qu'on pose sur un comptoir : quelques tintements
    metalliques serres, chacun un peu plus bas que le precedent."""
    rnd = random.Random(seed)
    out = []
    hits = [(int(n * f), 900 + rnd.randrange(700)) for f in
            (0.0, 0.16, 0.28, 0.46, 0.62)]
    for i in range(n):
        v = 0.0
        for start, freq in hits:
            if i < start:
                continue
            t = (i - start) / n
            v += math.exp(-13.0 * t) * math.sin(2 * math.pi * freq * (i - start) / 8000)
            v += 0.4 * math.exp(-16.0 * t) * math.sin(
                2 * math.pi * freq * 2.7 * (i - start) / 8000)
        out.append(clamp8(58 * v))
    return out


# nom, echantillon, periode
SFX = [
    ("epee",     swing(1300, 0.05, 0.35, 1.6, 1), 320),
    ("hache",    swing(1700, 0.02, 0.20, 1.9, 2), 400),
    ("arc",      swing(700, 0.12, 0.50, 1.4, 3), 250),
    ("impact",   impact(1100, 160, 4), 340),
    ("esquive",  swing(600, 0.20, 0.45, 1.0, 5), 300),
    ("porte",    creak(2600, 6), 430),
    ("coffre",   tone_seq([880, 1170, 1480, 1760], 260, wave="sine"), 300),
    ("potion",   tone_seq([440, 590, 780], 300, wave="sine"), 320),
    ("sort",     sparkle(1800, 7), 300),
    ("monstre",  growl(2200, 8), 420),
    ("niveau",   tone_seq([523, 659, 784, 1047], 320, wave="square"), 300),
    ("pas",      impact(500, 90, 9, noisy=0.35), 460),
    ("mort",     descend(2000, 400, 70), 360),
    ("piege",    snap(1500, 11), 340),
    ("pieces",   coins(2400, 13), 300),
]


def build():
    blobs, descs = [], []
    offset = 2 + len(SFX) * 12
    for name, data, period in SFX:
        data = list(data)
        if len(data) % 2:
            data.append(0)
        data[0] = data[1] = 0                        # depart silencieux
        rate = PAL_CLOCK / period                    # octets par seconde
        ticks = int(len(data) * 50 / rate) + 2       # duree en images
        descs.append(struct.pack(">IHHHH", offset, len(data) // 2,
                                 period, 64, ticks))
        blobs.append(bytes((v & 0xff) for v in data))
        offset += len(data)
    return (struct.pack(">H", len(SFX)) + b"".join(descs) + b"".join(blobs))


if __name__ == "__main__":
    raw = build()
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    open(OUT, "wb").write(raw)
    total = sum(len(d) for _, d, _ in SFX)
    print(f"{OUT} : {len(SFX)} effets, {len(raw)} octets")
    for i, (name, data, period) in enumerate(SFX):
        rate = PAL_CLOCK / period
        print(f"  {i:2d} {name:9s} {len(data):5d} octets  {rate/1000:.1f} kHz  "
              f"{len(data)/rate*1000:.0f} ms")
