#!/usr/bin/env python3
"""Genere src/sine.i (table sinus 256 entrees) et src/sprite.i (boule 16x16).

Les fichiers generes sont commites : la compilation ne depend donc pas de
Python. Relancer uniquement pour changer les donnees :
    python3 tools/gen_data.py
"""
import math
import os

HEADER = (";----------------------------------------------------------------------\n"
          "; {name} - GENERE PAR tools/gen_data.py - ne pas editer a la main\n"
          ";----------------------------------------------------------------------\n\n")


def sine_table():
    return [int(round(127.5 + 127.4 * math.sin(2 * math.pi * i / 256)))
            for i in range(256)]


def ball():
    """Boule 16x16 ombree : index 0 = transparent, 1..3 = couleurs 17..19."""
    rows = []
    r = 7.5
    for y in range(16):
        idx = []
        for x in range(16):
            dx, dy = x - r, y - r
            d = math.hypot(dx, dy)
            if d > 7.6:
                idx.append(0)
                continue
            light = (-dx - dy) / 11.0 + (1.0 - d / 8.0) * 0.55   # lumiere haut-gauche
            idx.append(1 if light > 0.55 else 2 if light > 0.12 else 3)
        rows.append(idx)
    return rows


def write_sine(path):
    with open(path, "w") as f:
        f.write(HEADER.format(name=os.path.basename(path)))
        f.write("; sin(x) mis a l'echelle 0..255 (128 = zero), 256 entrees\n")
        f.write("SinTab:\n")
        vals = sine_table()
        for i in range(0, 256, 16):
            row = ",".join(f"${v:02x}" for v in vals[i:i + 16])
            f.write(f"\tdc.b\t{row}\n")


def write_sprite(path):
    with open(path, "w") as f:
        f.write(HEADER.format(name=os.path.basename(path)))
        f.write("; Donnees pixels : 16 lignes de (plan0, plan1), puis mot de fin.\n")
        f.write("; A placer immediatement apres les mots SPRxPOS / SPRxCTL.\n")
        for idx in ball():
            p0 = p1 = 0
            for x, c in enumerate(idx):
                bit = 15 - x
                p0 |= (c & 1) << bit
                p1 |= ((c >> 1) & 1) << bit
            f.write(f"\tdc.w\t${p0:04x},${p1:04x}\n")
        f.write("\tdc.w\t$0000,$0000\t\t; fin du sprite\n")


here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
write_sine(os.path.join(here, "src", "sine.i"))
write_sprite(os.path.join(here, "src", "sprite.i"))
print("src/sine.i et src/sprite.i generes")
