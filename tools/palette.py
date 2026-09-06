#!/usr/bin/env python3
"""La palette 256 couleurs AGA du jeu, et les gammes qui la composent.

L'A1200 sait afficher huit bitplanes, soit 256 couleurs choisies parmi
seize millions. Le jeu se contentait de seize teintes de pierre : d'ou
des visages gris et des murs plats. On decrit ici des matieres --
pierre, bois, fer, peau, mousse, or -- chacune sous forme d'une gamme
continue, et on les range dans les 256 cases.

Source unique : ce module ecrit src/dgnpal.i (les couleurs, en 24 bits
sur deux mots comme l'exige LOCT) et src/dgncol.i (les noms, pour
l'assembleur), et sert directement au generateur de decors.

    python3 tools/palette.py
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def gradient(points, n):
    """n teintes reparties le long d'une suite de points de controle."""
    out = []
    for i in range(n):
        t = i / (n - 1) if n > 1 else 0.0
        seg = t * (len(points) - 1)
        k = min(len(points) - 2, int(seg))
        out.append(lerp(points[k], points[k + 1], seg - k))
    return out


# --- les matieres, du plus sombre au plus clair ----------------------
# Une crypte eclairee a la torche : les pierres tirent vers le chaud du
# cote de la lumiere, vers le bleu dans l'ombre.
MATERIALS = [
    ("STONE", 20, [(0x14, 0x15, 0x1a), (0x33, 0x33, 0x38),
                    (0x5e, 0x5b, 0x58), (0x8e, 0x88, 0x7c),
                    (0xbc, 0xb4, 0xa2), (0xe6, 0xdd, 0xc6)]),
    ("MORTAR",  6, [(0x0d, 0x0d, 0x10), (0x2a, 0x27, 0x24),
                    (0x50, 0x49, 0x3e), (0x7a, 0x70, 0x5e)]),
    ("EARTH", 14, [(0x16, 0x11, 0x0c), (0x36, 0x28, 0x1b),
                    (0x60, 0x48, 0x30), (0x92, 0x71, 0x4c),
                    (0xc0, 0x9c, 0x6e)]),
    ("WOOD", 12, [(0x18, 0x0e, 0x07), (0x3a, 0x22, 0x11),
                    (0x63, 0x3d, 0x1e), (0x8e, 0x5c, 0x30),
                    (0xba, 0x84, 0x50)]),
    ("IRON", 10, [(0x0c, 0x0d, 0x10), (0x24, 0x27, 0x2e),
                    (0x43, 0x48, 0x53), (0x68, 0x6f, 0x7c),
                    (0x96, 0x9e, 0xac)]),
    ("STEEL", 12, [(0x14, 0x16, 0x1c), (0x35, 0x3a, 0x44),
                    (0x62, 0x69, 0x76), (0x98, 0xa1, 0xae),
                    (0xd2, 0xd9, 0xe4), (0xff, 0xff, 0xff)]),
    ("SKIN", 14, [(0x20, 0x12, 0x0c), (0x4a, 0x2c, 0x1e),
                    (0x7c, 0x4e, 0x36), (0xac, 0x76, 0x54),
                    (0xd8, 0xa4, 0x7c), (0xf2, 0xd2, 0xb0)]),
    ("MOSS", 10, [(0x0a, 0x14, 0x0a), (0x1c, 0x33, 0x1a),
                    (0x35, 0x5c, 0x2c), (0x56, 0x8a, 0x40),
                    (0x86, 0xb8, 0x60)]),
    ("GOLD", 10, [(0x2a, 0x1c, 0x06), (0x66, 0x46, 0x10),
                    (0xa8, 0x7c, 0x20), (0xe0, 0xb8, 0x40),
                    (0xff, 0xe8, 0x9a)]),
    ("BLOOD",  8, [(0x1c, 0x06, 0x06), (0x4c, 0x0e, 0x0e),
                    (0x86, 0x1c, 0x18), (0xbe, 0x36, 0x28),
                    (0xe8, 0x70, 0x58)]),
    ("FIRE", 10, [(0x40, 0x10, 0x02), (0x8c, 0x2c, 0x04),
                    (0xd0, 0x60, 0x0c), (0xf4, 0xa4, 0x28),
                    (0xff, 0xe4, 0x9c)]),
    ("BONE",  8, [(0x2a, 0x26, 0x1e), (0x5c, 0x55, 0x44),
                    (0x96, 0x8d, 0x74), (0xd4, 0xcc, 0xb2),
                    (0xf6, 0xf2, 0xe2)]),
    ("HIDE",  8, [(0x14, 0x0e, 0x0a), (0x33, 0x24, 0x18),
                    (0x5c, 0x42, 0x2a), (0x8a, 0x66, 0x42),
                    (0xb4, 0x90, 0x66)]),
    ("SCALE", 10, [(0x08, 0x14, 0x10), (0x18, 0x36, 0x2c),
                    (0x2c, 0x5c, 0x46), (0x4a, 0x88, 0x66),
                    (0x7c, 0xb6, 0x92)]),
    ("ROT",  8, [(0x12, 0x14, 0x0c), (0x2e, 0x33, 0x1e),
                    (0x52, 0x58, 0x34), (0x7c, 0x82, 0x54),
                    (0xa8, 0xac, 0x80)]),
    ("CLOTHR",  6, [(0x1c, 0x08, 0x0a), (0x48, 0x14, 0x18),
                    (0x7e, 0x26, 0x2a), (0xb4, 0x44, 0x44)]),
    ("CLOTHB",  6, [(0x08, 0x0c, 0x20), (0x18, 0x24, 0x4e),
                    (0x2c, 0x42, 0x82), (0x50, 0x6e, 0xb6)]),
    ("CLOTHG",  6, [(0x08, 0x16, 0x0c), (0x16, 0x36, 0x1e),
                    (0x26, 0x5c, 0x34), (0x42, 0x88, 0x52)]),
    ("CLOTHP",  6, [(0x16, 0x0a, 0x1e), (0x36, 0x1c, 0x48),
                    (0x5c, 0x32, 0x7c), (0x8a, 0x58, 0xb0)]),
    ("HAIRD",  8, [(0x0c, 0x0a, 0x08), (0x24, 0x1c, 0x14),
                    (0x44, 0x34, 0x24), (0x6c, 0x54, 0x3c)]),
    ("HAIRL",  8, [(0x3a, 0x34, 0x28), (0x70, 0x68, 0x54),
                    (0xac, 0xa2, 0x86), (0xe8, 0xe2, 0xcc)]),
    ("HAIRR",  8, [(0x24, 0x0c, 0x06), (0x58, 0x1e, 0x0c),
                    (0x94, 0x3a, 0x16), (0xc8, 0x66, 0x2e)]),
    ("MAGIC",  8, [(0x08, 0x0a, 0x24), (0x1c, 0x24, 0x66),
                    (0x38, 0x54, 0xb4), (0x74, 0xa4, 0xf0),
                    (0xd8, 0xee, 0xff)]),
]
MATERIALS_BY_NAME = [(n, pts) for n, _, pts in MATERIALS]

# Quelques teintes isolees pour l'interface, nommees une a une.
SINGLES = [
    ("BLACK",   (0x00, 0x00, 0x00)),
    ("WHITE",   (0xff, 0xff, 0xff)),
    ("INK",     (0x1a, 0x14, 0x0e)),
    ("PARCH",   (0xe4, 0xd2, 0xa8)),
    ("PARCHD",  (0xb0, 0x99, 0x70)),
    ("TEXT",    (0xdc, 0xd2, 0xbc)),
    ("TEXTDIM", (0x86, 0x7e, 0x6e)),
    ("TEXTLOW", (0x50, 0x4c, 0x44)),
    ("HILITE",  (0xff, 0xe0, 0x80)),
    ("ALERT",   (0xe0, 0x4c, 0x38)),
    ("HEALTH",  (0x58, 0xc0, 0x50)),
    ("MANA",    (0x60, 0x9c, 0xf0)),
    ("SHADOW",  (0x0a, 0x0a, 0x0c)),
    ("FRAME",   (0x6e, 0x52, 0x22)),     # bronze patine du cadre
    ("FRAMELIT", (0xc6, 0xa0, 0x50)),    # son arete eclairee
    ("FRAMEDK", (0x2e, 0x22, 0x0e)),     # son ombre portee
    ("PANEL",   (0x1a, 0x17, 0x14)),     # fond des panneaux
    ("TORCH",   (0xff, 0xc8, 0x50)),     # flamme
    ("TORCHDK", (0x9c, 0x40, 0x08)),
]


# Les sprites AGA prennent leurs couleurs dans un bloc de seize aligne
# sur seize, choisi par ESPRM/OSPRM dans BPLCON4. On leur reserve le
# dernier bloc, $f0-$ff, que rien d'autre n'occupe : le pointeur de
# souris ne coute alors pas une seule teinte au decor.
# Le sol et la voute ne prennent pas leur teinte dans la palette fixe :
# le copper reecrit ces douze cases a chaque paire de lignes, si bien
# que la profondeur se lit en degrade continu et non en marches. Elles
# tombent dans le bloc des sprites, dont ceux-ci n'utilisent que les
# quatre premieres : le materiel lit les memes registres, chacun n'y
# regarde que ce qui le concerne.
SURFBASE = 0xf4
NSURF_STONE = 8                          # variation locale du dallage
NSURF_EARTH = 2                          # joints de terre
NSURF_MOSS = 2                           # touffes de mousse
NSURF = NSURF_STONE + NSURF_EARTH + NSURF_MOSS

SPRBASE = 0xf0
SPRITE = [
    (0x00, 0x00, 0x00),                  # 0 : transparent, jamais lu
    (0xff, 0xe8, 0xb4),                  # 1 : corps du pointeur
    (0x20, 0x18, 0x10),                  # 2 : son cerne
    (0xc6, 0x8a, 0x30),                  # 3 : son ombre, ton bronze
]


def build():
    """-> (liste de 256 RGB, {nom: (debut, longueur)})."""
    palette = [(0, 0, 0)]
    index = {}
    for name, n, points in MATERIALS:
        index[name] = (len(palette), n)
        palette += gradient(points, n)
    for name, rgb in SINGLES:
        index[name] = (len(palette), 1)
        palette.append(rgb)
    assert len(palette) <= SPRBASE, \
        f"{len(palette)} couleurs, le bloc des sprites commence a {SPRBASE}"
    palette += [(0, 0, 0)] * (SPRBASE - len(palette))
    index["SPRITE"] = (SPRBASE, len(SPRITE))
    palette += SPRITE
    palette += [(0, 0, 0)] * (SURFBASE - len(palette))
    # Valeurs de repli : ce que le copper ecrirait a mi-profondeur. Sans
    # elles, un ecran sans copper -- l'accueil, une capture -- montrerait
    # du noir a la place du sol.
    index["SURF"] = (SURFBASE, NSURF)
    stone = gradient(dict(MATERIALS_BY_NAME)["STONE"], 64)
    earth = gradient(dict(MATERIALS_BY_NAME)["EARTH"], 64)
    moss = gradient(dict(MATERIALS_BY_NAME)["MOSS"], 64)
    for k in range(NSURF_STONE):
        palette.append(stone[max(0, 63 - int((0.55 + k * 0.05) * 63))])
    for k in range(NSURF_EARTH):
        palette.append(earth[max(0, 63 - int(min(1.0, 0.91 + k * 0.11) * 63))])
    for k in range(NSURF_MOSS):
        palette.append(moss[max(0, 63 - int(min(1.0, 0.77 + k * 0.11) * 63))])
    palette += [(0, 0, 0)] * (256 - len(palette))
    assert len(palette) == 256
    return palette, index


PALETTE, INDEX = build()


def ramp(name):
    """La gamme d'une matiere, du plus sombre au plus clair."""
    start, n = INDEX[name]
    return list(range(start, start + n))


def shade(name, t):
    """t de 0 (le plus sombre) a 1 (le plus clair) -> index de palette."""
    start, n = INDEX[name]
    return start + max(0, min(n - 1, int(t * (n - 1) + 0.5)))


def lit(name, t):
    """t de 0 (le plus clair) a 1 (le plus sombre) : sens des routines
    de dessin, qui raisonnent en profondeur d'ombre."""
    return shade(name, 1.0 - t)


def one(name):
    return INDEX[name][0]


def rgb(name, t):
    """La couleur continue d'une matiere, t de 0 (sombre) a 1 (clair).

    shade() rend un index, donc une des N teintes retenues ; celle-ci
    rend la couleur exacte, entre deux points de controle. C'est ce que
    le copper ecrit : lui n'est pas tenu par la palette."""
    pts = dict(MATERIALS_BY_NAME)[name]
    t = max(0.0, min(1.0, t))
    seg = t * (len(pts) - 1)
    k = min(len(pts) - 2, int(seg))
    return lerp(pts[k], pts[k + 1], seg - k)


def dark(name, t):
    """t de 0 (clair) a 1 (sombre) : le sens des routines de dessin."""
    return rgb(name, 1.0 - t)


def write_palette(path):
    with open(path, "w") as f:
        f.write(";---------------------------------------------------------\n")
        f.write("; dgnpal.i - GENERE PAR tools/palette.py\n")
        f.write(";---------------------------------------------------------\n\n")
        f.write("; 256 couleurs AGA, deux mots chacune : quartets hauts puis\n")
        f.write("; bas (BPLCON3 LOCT). Huit banques de trente-deux.\n")
        f.write("DgnPalette:\n")
        for i, (r, g, b) in enumerate(PALETTE):
            hi = ((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4)
            lo = ((r & 15) << 8) | ((g & 15) << 4) | (b & 15)
            f.write(f"\tdc.w\t${hi:04x},${lo:04x}\t\t; {i}\n")


def write_names(path):
    with open(path, "w") as f:
        f.write(";---------------------------------------------------------\n")
        f.write("; dgncol.i - GENERE PAR tools/palette.py\n")
        f.write("; Debut et longueur de chaque gamme, puis les teintes\n")
        f.write("; nommees de l'interface.\n")
        f.write(";---------------------------------------------------------\n\n")
        for name, n, _ in MATERIALS:
            start = INDEX[name][0]
            f.write(f"C_{name}\t\t= {start}\n")
            f.write(f"N_{name}\t\t= {n}\n")
        f.write("\n")
        for name, _ in SINGLES:
            f.write(f"C_{name}\t\t= {INDEX[name][0]}\n")
        f.write(f"\nC_SPRITE\t\t= {SPRBASE}\n")
        f.write(f"C_SURF\t\t= {SURFBASE}\n")
        f.write(f"N_SURF\t\t= {NSURF}\n")
        f.write(f"C_SURF_EARTH\t= {SURFBASE + NSURF_STONE}\n")
        f.write(f"C_SURF_MOSS\t= {SURFBASE + NSURF_STONE + NSURF_EARTH}\n")


if __name__ == "__main__":
    used = sum(n for _, n, _ in MATERIALS) + len(SINGLES) + 1 + len(SPRITE) + NSURF
    write_palette(os.path.join(ROOT, "src", "dgnpal.i"))
    write_names(os.path.join(ROOT, "src", "dgncol.i"))
    print(f"src/dgnpal.i, src/dgncol.i : {used} couleurs sur 256, "
          f"{len(MATERIALS)} matieres")
