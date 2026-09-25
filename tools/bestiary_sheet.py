#!/usr/bin/env python3
"""Planche du bestiaire : les neuf familles, leurs trois poses, et les
creatures du SRD que chacune incarne.

    python3 tools/bestiary_sheet.py docs/bestiaire.png
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import monsters as M                             # noqa: E402
import palette as pal                            # noqa: E402
from gen_tables import MONSTERS                  # noqa: E402
from PIL import Image, ImageDraw, ImageFont      # noqa: E402

FAMILIES = ["LA BETE", "LE MORT-VIVANT", "LE PETIT HUMANOIDE",
            "LE GUERRIER", "LA BRUTE", "L'OMBRE", "LA MOMIE",
            "LA CREATURE AILEE", "L'HYDRE"]
POSES = ["repos", "souffle", "attaque"]
Z = 3                                            # agrandissement


def plain(name):
    """La police de la planche n'a pas les capitales accentuees."""
    import unicodedata
    return "".join(c for c in unicodedata.normalize("NFD", name)
                   if unicodedata.category(c) != "Mn")


def font(size):
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


def main(out):
    members = {k: [] for k in range(len(FAMILIES))}
    for m in MONSTERS:
        members[m[-1]].append(plain(m[0]))
    cw, ch = M.W * Z, M.H * Z
    pad, head = 16, 58
    card_w = cw * M.NPOSES + pad * 2
    card_h = ch + head + 34
    cols = 3
    rows = (len(FAMILIES) + cols - 1) // cols
    title_h = 70
    sheet = Image.new("RGB", (cols * card_w + pad, title_h + rows * card_h + pad),
                      (18, 16, 14))
    d = ImageDraw.Draw(sheet)
    gold = tuple(pal.PALETTE[pal.lit("GOLD", 0.1)])
    parch = tuple(pal.PALETTE[pal.one("PARCH")])
    dim = tuple(pal.PALETTE[pal.one("TEXTDIM")])
    d.text((pad, 16), "LE BESTIAIRE DE FAERGHAIL", fill=gold, font=font(30))
    d.text((pad, 50), "neuf familles, trois poses : repos, souffle, attaque",
           fill=dim, font=font(15))
    for k, name in enumerate(FAMILIES):
        x0 = pad + (k % cols) * card_w
        y0 = title_h + (k // cols) * card_h
        d.rectangle((x0, y0, x0 + card_w - pad, y0 + card_h - 10),
                    fill=(30, 27, 23), outline=tuple(pal.PALETTE[pal.one("FRAME")]),
                    width=2)
        d.text((x0 + 12, y0 + 8), name, fill=gold, font=font(20))
        d.text((x0 + 12, y0 + 34), ", ".join(members[k]).lower(),
               fill=parch, font=font(14))
        for p in range(M.NPOSES):
            g = M.draw(k, p)
            im = Image.new("RGBA", (M.W, M.H), (0, 0, 0, 0))
            for y in range(M.H):
                for x in range(M.W):
                    if g[y][x] is not None:
                        im.putpixel((x, y), tuple(pal.PALETTE[g[y][x]]) + (255,))
            im = im.resize((cw, ch), Image.NEAREST)
            px = x0 + 8 + p * cw
            sheet.paste(im, (px, y0 + head), im)
            d.text((px + cw // 2 - 24, y0 + head + ch + 2), POSES[p],
                   fill=dim, font=font(14))
    sheet.save(out)
    print(out)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "bestiaire.png")
