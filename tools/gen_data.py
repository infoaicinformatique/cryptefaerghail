#!/usr/bin/env python3
"""Genere les donnees incluses par les sources assembleur :

    src/sine.i     table sinus 256 entrees
    src/sprite.i   boule 16x16, 2 plans
    src/palette.i  palette AGA de 256 couleurs 24 bits

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


def palette():
    """256 couleurs 24 bits : arc-en-ciel cyclique sur 0..239, entrees
    240..255 reservees (dont 241..243 pour le sprite)."""
    cols = []
    for i in range(240):
        a = 2 * math.pi * i / 240
        cols.append(tuple(
            int(round(127.5 + 127.0 * math.sin(a + phase)))
            for phase in (0.0, 2 * math.pi / 3, 4 * math.pi / 3)))
    cols += [(0, 0, 0)] * 16
    cols[241] = (0xff, 0xff, 0xff)              # sprite : haute lumiere
    cols[242] = (0x70, 0xa0, 0xff)              # sprite : bleu clair
    cols[243] = (0x10, 0x20, 0x60)              # sprite : bleu sombre
    return cols


def write_palette(path):
    with open(path, "w") as f:
        f.write(HEADER.format(name=os.path.basename(path)))
        f.write("; Une entree = deux mots : quartets hauts, puis quartets bas.\n")
        f.write("; Les deux sont ecrits dans le meme registre COLORxx, le second\n")
        f.write("; avec BPLCON3 LOCT = 1 : c'est ainsi qu'on obtient 24 bits sur AGA.\n")
        f.write("PaletteTab:\n")
        for i, (r, g, b) in enumerate(palette()):
            hi = ((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4)
            lo = ((r & 15) << 8) | ((g & 15) << 4) | (b & 15)
            f.write(f"\tdc.w\t${hi:04x},${lo:04x}\t\t; couleur {i}\n")


here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
write_sine(os.path.join(here, "src", "sine.i"))
write_sprite(os.path.join(here, "src", "sprite.i"))
write_palette(os.path.join(here, "src", "palette.i"))
print("src/sine.i, src/sprite.i et src/palette.i generes")
