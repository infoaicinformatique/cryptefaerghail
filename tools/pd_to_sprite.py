#!/usr/bin/env python3
"""Convertit les illustrations du domaine public en portraits 96x96
dans la palette 16 couleurs du jeu, et fabrique une planche de contact
pour juger de ce qui est utilisable.

    python3 tools/pd_to_sprite.py
"""
import os
import sys

from PIL import Image, ImageEnhance, ImageOps

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import gen_dungeon as G

SIZE = 96
SRC = os.path.join(ROOT, "art", "pd")


def palette_image():
    pal = Image.new("P", (1, 1))
    flat = []
    for r, g, b in G.PALETTE:
        flat += [r, g, b]
    flat += [0, 0, 0] * (256 - len(G.PALETTE))
    pal.putpalette(flat)
    return pal


PAL = palette_image()


def convert(path):
    im = Image.open(path).convert("RGB")
    w, h = im.size
    side = min(w, h)                                 # carre central
    im = im.crop(((w - side) // 2, (h - side) // 2,
                  (w + side) // 2, (h + side) // 2))
    im = im.resize((SIZE, SIZE), Image.LANCZOS)
    im = ImageOps.autocontrast(im, cutoff=2)
    im = ImageEnhance.Contrast(im).enhance(1.25)
    return im.quantize(palette=PAL, dither=Image.FLOYDSTEINBERG)


def contact_sheet(items, out):
    cols = 5
    rows = (len(items) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * (SIZE + 6), rows * (SIZE + 6)), (20, 20, 24))
    for i, (name, im) in enumerate(items):
        sheet.paste(im.convert("RGB"),
                    ((i % cols) * (SIZE + 6) + 3, (i // cols) * (SIZE + 6) + 3))
    sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(out)


if __name__ == "__main__":
    items = []
    for f in sorted(os.listdir(SRC)):
        if not f.endswith(".jpg"):
            continue
        key = f[:-4]
        im = convert(os.path.join(SRC, f))
        im.convert("RGB").save(os.path.join(SRC, key + "_96.png"))
        items.append((key, im))
        print(f"  {key:9s} converti")
    contact_sheet(items, "/tmp/planche.png")
    print(f"{len(items)} portraits, planche dans /tmp/planche.png")
