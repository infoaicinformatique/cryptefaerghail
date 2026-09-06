#!/usr/bin/env python3
"""Genere les donnees du dungeon crawler :

    data/dgnart.bin   decors en perspective, monstres, tous en 4 plans
    data/dgnmap.bin   les trois niveaux du donjon
    src/dgnpal.i      palette 16 couleurs, en 24 bits AGA
    src/font8.i       police 8x8 pour l'interface

Le fichier d'art est binaire (incbin cote assembleur) : le mettre en dc.w
gonflerait le depot pour rien.

    python3 tools/gen_dungeon.py
"""
import math
import os
import random
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))

# --- geometrie de la vue -----------------------------------------------
VIEW_X, VIEW_Y = 16, 16                  # coin de la vue dans l'ecran
VIEW_W, VIEW_H = 192, 136
CX, CY = VIEW_W // 2, VIEW_H // 2        # point de fuite
F = 64.0                                 # demi-taille d'un mur a distance 1
SCRBPL = 40                              # octets par ligne d'un plan d'ecran
DEPTHS = 8                               # AGA : huit bitplanes
NMONSTERART = 9                          # familles de silhouettes
NCLASSPORTRAIT = 8                       # un visage par classe

# --- palette : 256 couleurs AGA, decrites dans tools/palette.py ------
import palette as pal                     # noqa: E402

PALETTE = pal.PALETTE


def stone(t):
    """Pierre, t = profondeur d'ombre (0 en pleine lumiere)."""
    return pal.lit("STONE", t)


# Les creatures et les icones ont ete dessinees pour seize couleurs.
# Plutot que de les redessiner, on fait correspondre chaque ancien
# index a une teinte des nouvelles gammes : le trait reste, la matiere
# s'affine.
C = [
    pal.one("BLACK"),
    pal.lit("STONE", 0.05), pal.lit("STONE", 0.22), pal.lit("STONE", 0.38),
    pal.lit("STONE", 0.52), pal.lit("STONE", 0.68), pal.lit("STONE", 0.82),
    pal.lit("MORTAR", 0.90),
    pal.lit("WOOD", 0.30), pal.lit("WOOD", 0.62),
    pal.lit("EARTH", 0.42), pal.lit("EARTH", 0.72),
    pal.lit("MOSS", 0.40),
    pal.one("WHITE"),
    pal.lit("GOLD", 0.25),
    pal.lit("BLOOD", 0.40),
]


BRICK_W, BRICK_H = 0.25, 0.125           # taille d'un bloc, en cases


def torch(dist):
    """Profondeur d'ombre a cette distance.

    Une seule loi pour les murs, le sol et la voute : tant que chaque
    surface avait sa propre formule, elles ne s'accordaient pas et le
    couloir se lisait comme trois materiaux poses cote a cote."""
    return min(1.0, 0.08 + 0.185 * (dist - 1.0))


def wall_tone(dist, side):
    """Un mur lateral prend un cran d'ombre de plus qu'un mur de face :
    la lumiere du groupe le frappe en rasant."""
    return torch(dist) + (0.14 if side else 0.0)


def jitter(a, b):
    """Variation pseudo-aleatoire mais stable d'un bloc a l'autre."""
    h = (a * 73856093) ^ (b * 19349663)
    return ((h >> 7) & 3) - 1


def noise(a, b, seed=0):
    """Bruit stable, sans table : sert au grain et aux fissures."""
    h = (a * 374761393 + b * 668265263 + seed * 362437) & 0xffffffff
    h = (h ^ (h >> 13)) * 1274126177 & 0xffffffff
    return ((h >> 16) & 0xff) / 255.0


def brick(u, v, dist, side):
    """Blocs de pierre : joints en creux, rangees decalees, aretes
    eclairees, grain, fissures et mousse dans les angles humides."""
    row = int((v + 8.0) / BRICK_H)
    uu = u + (BRICK_W / 2 if row & 1 else 0.0)
    col = int((uu + 8.0) / BRICK_W)
    du = ((uu + 8.0) / BRICK_W) % 1.0
    dv = ((v + 8.0) / BRICK_H) % 1.0

    # joint, avec une epaisseur legerement irreguliere
    jx = 0.07 + 0.03 * noise(col, row, 3)
    jy = 0.12 + 0.04 * noise(col, row, 4)
    if du < jx or dv < jy:
        return pal.lit("MORTAR", min(1.0, 0.62 + 0.22 * (dist - 1.0)))

    t = wall_tone(dist, side) + 0.030 * jitter(col, row) \
        + 0.09 * min(1.0, abs(u) / 3.0)              # la torche s'eteint

    if dv < 0.28:                                    # arete eclairee du bloc
        t -= 0.055
    elif dv > 0.82 or du > 0.93:                     # arete a l'ombre
        t += 0.055

    n = noise(int((u + 8) * 90), int((v + 8) * 90), 1)   # grain de la pierre
    t += (n - 0.5) * 0.075

    # veinures claires : la pierre n'est pas unie
    if noise(col, row, 17) > 0.62:
        w = abs((du - 0.5) * 0.9 - (dv - 0.5) * 2.2)
        if w < 0.10:
            t -= 0.045

    # fissure : une diagonale par bloc, sur une partie des blocs seulement
    if noise(col, row, 7) > 0.72:
        crack = abs((du - 0.5) * 1.7 + (dv - 0.5))
        if crack < 0.06 + 0.05 * noise(int(dv * 60), col, 8):
            t += 0.16

    # mousse : bas des blocs, plutot pres du sol et sur les murs lateraux
    if v > 0.18 and noise(col, row, 11) > (0.55 if side else 0.72):
        if dv > 0.55 + 0.2 * noise(int(du * 40), row, 12):
            return pal.lit("MOSS", min(1.0, 0.20 + 0.22 * (dist - 1.0)
                                       + 0.25 * noise(col, row, 13)))
    # salpetre : trainees pales pres du sol
    if v > 0.30 and noise(col, row, 19) > 0.80 and dv > 0.4:
        t -= 0.10
    return stone(max(0.0, min(1.0, t)))


# --- construction des morceaux -----------------------------------------
class Piece:
    """Un morceau de decor : pixels indexes, plus un masque."""

    def __init__(self, x0, y0, w, h):
        self.x0, self.y0, self.w, self.h = x0, y0, w, h
        self.px = [[None] * w for _ in range(h)]     # None = transparent

    def set(self, x, y, idx):
        if 0 <= x - self.x0 < self.w and 0 <= y - self.y0 < self.h:
            self.px[y - self.y0][x - self.x0] = idx


def snap(x0, x1):
    """Cadre le morceau sur des multiples de 16 pixels (blit sans decalage)."""
    a = max(0, (int(x0) // 16) * 16)
    b = min(VIEW_W, -(-int(x1) // 16) * 16)
    return a, b


def gate_pixel(u, v, k):
    """Herse : barreaux de fer verticaux, deux traverses, et le vide
    entre les barreaux -- on laisse le pixel transparent pour que le
    couloir se voie au travers."""
    depth = 0.12 + 0.22 * (k - 1.0)
    if abs(u) > 0.19 or v < -0.27:                   # encadrement de pierre
        return stone(min(1.0, depth + 0.30))
    bar = (u + 8.0) / 0.048
    d = abs(bar % 1.0 - 0.5)
    cross = -0.16 < v < -0.125 or 0.02 < v < 0.055
    if d < 0.24 or cross:
        t = depth + 0.30 + 0.34 * d
        if d < 0.09 and not cross:                   # reflet sur le barreau
            t -= 0.26
        return pal.lit("IRON", max(0.0, min(1.0, t)))
    return None                                      # entre les barreaux


def make_front(k, door=False, offset=0, gate=False):
    """Face d'une case a la distance k, decalee lateralement de `offset`
    cases : offset 0 ferme le couloir, offset -1 ou +1 ferme le fond d'un
    passage lateral."""
    half = F / k
    xa = CX + 2 * half * (offset - 0.5)
    xb = CX + 2 * half * (offset + 0.5)
    x0, x1 = snap(xa, xb)
    y0, y1 = max(0, int(CY - half)), min(VIEW_H, int(round(CY + half)))
    if x1 <= x0 or y1 <= y0:
        return Piece(0, 0, 16, 1)                    # hors ecran
    p = Piece(x0, y0, x1 - x0, y1 - y0)
    for y in range(y0, y1):
        for x in range(x0, x1):
            if not (xa <= x < xb) or abs(y - CY) > half:
                continue
            u = (x - CX) * k / (2 * F)               # coordonnees monde
            v = (y - CY) * k / (2 * F)
            if gate and -0.22 < u < 0.22 and v > -0.30:
                c = gate_pixel(u, v, k)
                if c is not None:
                    p.set(x, y, c)
            elif door and -0.22 < u < 0.22 and v > -0.30:
                p.set(x, y, door_pixel(u, v, k))
            else:
                p.set(x, y, brick(u, v, k, False))
    return p


def door_pixel(u, v, k):
    """Porte de chene : planches verticales, ferrures, gros anneau."""
    depth = 0.10 + 0.20 * (k - 1.0)
    if abs(u) > 0.19 or v < -0.27:                   # encadrement de pierre
        return stone(min(1.0, depth + 0.30))
    plank = (u + 8.0) / 0.055
    edge = plank % 1.0
    t = depth + 0.10 + 0.16 * noise(int(plank), int((v + 8) * 40), 31)
    if edge < 0.10:                                  # creux entre planches
        t += 0.30
    elif edge > 0.86:
        t -= 0.08
    for band in (-0.17, 0.09):                       # ferrures horizontales
        if band < v < band + 0.055:
            rivet = abs((u + 8.0) / 0.05 % 1.0 - 0.5)
            return pal.lit("IRON", 0.30 if rivet < 0.18 else 0.62)
    if 0.10 < u < 0.16 and -0.03 < v < 0.05:         # anneau de tirage
        r = ((u - 0.13) / 0.030) ** 2 + ((v - 0.01) / 0.038) ** 2
        if 0.35 < r <= 1.0:
            return pal.lit("GOLD", 0.30 + 0.35 * depth)
    return pal.lit("WOOD", max(0.0, min(1.0, t)))


def make_side(i, lateral):
    """Mur vertical a la position laterale `lateral` (en demi-cases :
    -0.5 = mur gauche du couloir, -1.5 = mur du fond d'un passage a
    gauche), vu entre les distances i et i+1.

    Ces murs se projettent en droites passant par le point de fuite :
    a la colonne x, la distance vaut 2*F*lateral / (x - CX), ce qui donne
    un placage de texture exact, sans division par pixel a l'execution."""
    near, far = max(i, 0.42), i + 1
    xa = CX + 2 * F * lateral / near
    xb = CX + 2 * F * lateral / far
    x0, x1 = snap(min(xa, xb), max(xa, xb))
    if x1 <= x0:
        return Piece(0, 0, 16, 1)                    # entierement hors ecran
    p = Piece(x0, 0, x1 - x0, VIEW_H)
    drawn = False
    for x in range(x0, x1):
        if x == CX:
            continue
        dist = 2 * F * lateral / (x - CX)
        if not (near - 1e-6 <= dist <= far + 1e-6):
            continue
        halfw = F / dist
        for y in range(max(0, int(CY - halfw)), min(VIEW_H, int(round(CY + halfw)))):
            v = (y - CY) * dist / (2 * F)
            p.set(x, y, brick(dist, v, dist, True))
            drawn = True
    return p if drawn else Piece(0, 0, 16, 1)


def make_background():
    """Sol et voute, en perspective et dans la meme pierre que les murs.

    A la ligne y, la surface est a la distance F/|y-CY| et sa
    coordonnee laterale vaut (x-CX)/|y-CY| : les joints suivent donc
    exactement la fuite. Les deux surfaces empruntent la loi de lumiere
    des murs, plus un assombrissement lateral qui donne au couloir la
    lueur d'une torche portee par le groupe.
    """
    p = Piece(0, 0, VIEW_W, VIEW_H)
    slab = 0.5                                       # une dalle par demi-case
    for y in range(VIEW_H):
        dy = abs(y - CY)
        if dy < 2:                                   # la ligne de fuite
            for x in range(VIEW_W):
                p.set(x, y, stone(0.97))
            continue
        dist = F / dy
        floor = y > CY
        for x in range(VIEW_W):
            lat = (x - CX) / dy                      # position laterale
            gu = ((lat + 8.0) / slab) % 1.0
            gv = ((dist + 8.0) / slab) % 1.0
            edge = min(gu, gv, 1.0 - gu, 1.0 - gv)
            # Le fond du couloir s'eteint, mais jamais tout a fait : un
            # noir franc s'y lisait comme un trou rectangulaire.
            t = min(0.93, torch(dist)) + 0.11 * min(1.0, abs(lat) / 3.0)

            if floor:
                t += 0.05                            # le sol prend la lumiere
                if edge < 0.05:                      # joint garni de terre
                    p.set(x, y, pal.lit("EARTH", min(1.0, t + 0.36)))
                    continue
                if abs(lat) < 0.55:                  # le passage, use et poli
                    t -= 0.05
                t += 0.06 * (noise(int(lat * 42), int(dist * 42), 21) - 0.5)
                if abs(lat) > 0.7 and \
                        noise(int(lat * 16), int(dist * 16), 23) > 0.90:
                    p.set(x, y, pal.lit("MOSS", min(1.0, t + 0.22)))
                    continue
                p.set(x, y, stone(max(0.0, min(1.0, t))))
            else:                                    # la voute
                t += 0.24
                if edge < 0.06:                      # nervure, elle accroche
                    t -= 0.09                        # la lumiere
                t += 0.05 * (noise(int(lat * 38), int(dist * 38), 27) - 0.5)
                if noise(int(lat * 9), int(dist * 9), 29) > 0.90:
                    t += 0.13                        # suie des torches
                p.set(x, y, stone(max(0.0, min(1.0, t))))
    return p


# --- ecran-titre ------------------------------------------------------
TITLE_W, TITLE_H = 320, 176


def glyph_rows(ch):
    """Les huit lignes d'un caractere, en bits, depuis la police 8x8."""
    import gen_data
    rows = gen_data.GLYPHS.get(ch.upper())
    if rows is None:
        return [0] * 8
    out = []
    for row in rows:
        bits = 0
        for x, c in enumerate(row):
            if c == "#":
                bits |= 0x80 >> (x + 1)
        out.append(bits)
    return out + [0]


def carve_text(p, text, x0, y0, scale, face, lit, dark):
    """Un titre grave : le glyphe agrandi, une arete claire en haut a
    gauche et une ombre en bas a droite. La police du jeu suffit --
    doublee, elle prend l'allure d'une inscription."""
    for i, ch in enumerate(text):
        rows = glyph_rows(ch)
        bx = x0 + i * 8 * scale
        for ry, bits in enumerate(rows):
            for rx in range(8):
                if not (bits & (0x80 >> rx)):
                    continue
                for sy in range(scale):
                    for sx in range(scale):
                        x, y = bx + rx * scale + sx, y0 + ry * scale + sy
                        p.set(x, y, face)
                        p.set(x - 1, y - 1, lit)
                        p.set(x + scale, y + scale, dark)
    # deuxieme passe : le corps de la lettre repasse par-dessus le relief
    for i, ch in enumerate(text):
        rows = glyph_rows(ch)
        bx = x0 + i * 8 * scale
        for ry, bits in enumerate(rows):
            for rx in range(8):
                if bits & (0x80 >> rx):
                    for sy in range(scale):
                        for sx in range(scale):
                            p.set(bx + rx * scale + sx,
                                  y0 + ry * scale + sy, face)


def make_title():
    """L'entree de la crypte : une arche de pierre, sa porte bardee de
    fer, deux torches qui la rechauffent, et le titre grave au linteau."""
    p = Piece(0, 0, TITLE_W, TITLE_H)
    cx = TITLE_W // 2
    arch_w, arch_top, arch_bot = 54, 74, 168         # demi-largeur, hauteur
    torches = ((cx - 108, 86), (cx + 108, 86))

    for y in range(TITLE_H):
        for x in range(TITLE_W):
            # --- lumiere : deux torches plus un fond declinant
            glow = 0.0
            for tx, ty in torches:
                d2 = ((x - tx) / 86.0) ** 2 + ((y - ty) / 74.0) ** 2
                glow += max(0.0, 1.0 - d2) ** 2
            t = 0.70 - 0.56 * min(1.0, glow) + 0.24 * (y / TITLE_H)

            dx, dy = x - cx, y - arch_bot
            inside = abs(dx) < arch_w and arch_top < y < arch_bot
            if abs(dx) < arch_w:                     # le cintre de l'arche
                r = (dx / arch_w) ** 2 + ((y - arch_top) / 34.0) ** 2
                if y <= arch_top and r <= 1.0:
                    inside = True

            if inside:
                p.set(x, y, door_panel(dx, y, arch_w, arch_bot, t))
                continue

            ring = abs(dx) - arch_w                  # les voussoirs
            arc = (dx / (arch_w + 13.0)) ** 2 + \
                  ((y - arch_top) / 47.0) ** 2
            if (0 <= ring < 13 and arch_top < y < arch_bot) or \
                    (y <= arch_top and arc <= 1.0):
                wedge = int((math.atan2(arch_top - y, dx) + 4) * 6) % 2
                p.set(x, y, stone(max(0.0, min(1.0, t - 0.22 + 0.07 * wedge))))
                continue

            row = y // 22                            # l'appareil du mur
            off = 0.5 if row & 1 else 0.0
            col = (x / 44.0 + off) % 1.0
            if col < 0.045 or (y % 22) < 3:
                p.set(x, y, pal.lit("MORTAR", min(1.0, t + 0.22)))
                continue
            t += 0.06 * (noise(int(x * 0.7), int(y * 0.7), 41) - 0.5)
            p.set(x, y, stone(max(0.0, min(1.0, t))))

    for tx, ty in torches:                           # les torches elles-memes
        for y in range(ty, ty + 30):                 # le manche
            for x in range(tx - 2, tx + 3):
                p.set(x, y, pal.lit("WOOD", 0.30 + 0.16 * abs(x - tx)))
        for y in range(ty - 3, ty + 7):              # la corbeille de fer
            for x in range(tx - 7, tx + 8):
                if abs(x - tx) > 7 - (y - ty + 3) // 3:
                    continue
                if abs(x - tx) > 4 or y > ty + 3:
                    p.set(x, y, pal.lit("IRON", 0.40 + 0.03 * (y - ty)))
        for y in range(ty - 34, ty + 2):             # la flamme
            k = (y - (ty - 34)) / 36.0
            w = 1 + int(11 * k * (1.25 - k))
            for x in range(tx - w, tx + w + 1):
                r = abs(x - tx) / max(1.0, w)
                n = noise(x, y, 43)
                if r + 0.26 * n > 1.05:
                    continue
                p.set(x, y, pal.lit("FIRE", 0.04 + 0.70 * r + 0.16 * (1 - k)))

    for i, (top, w) in enumerate(((168, 78), (172, 96), (176, 118))):
        for y in range(top, min(TITLE_H, top + 5)):  # trois marches usees
            for x in range(cx - w, cx + w + 1):
                if not 0 <= x < TITLE_W:
                    continue
                lip = 0.16 if y == top else 0.44 + 0.02 * i
                p.set(x, y, stone(min(1.0, lip + 0.24 * abs(x - cx) / w)))

    carve_text(p, "LA CRYPTE", cx - 9 * 8 * 2 // 2, 12, 2,
               pal.lit("GOLD", 0.24), pal.lit("GOLD", 0.05),
               pal.lit("GOLD", 0.82))
    carve_text(p, "DE FAERGHAIL", cx - 12 * 8 * 2 // 2, 34, 2,
               pal.lit("GOLD", 0.30), pal.lit("GOLD", 0.08),
               pal.lit("GOLD", 0.86))
    return p


def door_panel(dx, y, half, bottom, t):
    """Le vantail de chene, dans l'ouverture de l'arche."""
    if y > bottom - 5:                               # le seuil
        return stone(min(1.0, t + 0.30))
    plank = (dx + 200.0) / 13.0
    edge = plank % 1.0
    # le chene reste sombre, mais pas noir : il ne prend qu'une part de
    # l'ombre du mur, sinon l'arche se lit comme un trou
    v = 0.28 + 0.44 * t + 0.12 * noise(int(plank), y // 3, 45)
    if edge < 0.10:
        v += 0.28
    elif edge > 0.88:
        v -= 0.06
    for band in (bottom - 92, bottom - 34):          # les ferrures
        if band < y < band + 9:
            rivet = abs((dx + 200.0) / 11.0 % 1.0 - 0.5)
            return pal.lit("IRON", 0.30 if rivet < 0.16 else 0.58 + 0.2 * t)
    if abs(dx - 30) < 9 and abs(y - (bottom - 60)) < 11:
        r = ((dx - 30) / 8.0) ** 2 + ((y - (bottom - 60)) / 10.0) ** 2
        if 0.34 < r <= 1.0:                          # l'anneau
            return pal.lit("GOLD", 0.26 + 0.34 * t)
    return pal.lit("WOOD", max(0.0, min(1.0, v)))


def make_lever(pulled):
    """Levier de fer sur une platine, vu de pres : leve ou abaisse."""
    x0, x1 = snap(CX - 20, CX + 20)
    y0, y1 = CY - 24, CY + 18
    p = Piece(x0, y0, x1 - x0, y1 - y0)
    px, py = CX, CY - 4                              # axe du levier
    for y in range(py - 14, py + 15):                # platine boulonnee
        for x in range(px - 9, px + 10):
            e = max(abs(x - px) / 9.0, abs(y - py) / 14.0)
            if e > 1.0:
                continue
            t = 0.30 + 0.34 * e + 0.16 * ((x - px) + (y - py)) / 20.0
            p.set(x, y, pal.lit("IRON", max(0.0, min(1.0, t))))
    for sx, sy in ((-6, -11), (6, -11), (-6, 11), (6, 11)):   # rivets
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                if abs(dx) + abs(dy) < 2:
                    p.set(px + sx + dx, py + sy + dy,
                          pal.lit("STEEL", 0.18 if dx + dy < 0 else 0.62))
    dx, dy = (7, 9) if pulled else (7, -11)          # manche de bois
    for i in range(22):
        t = i / 21.0
        x = int(px + dx * t)
        y = int(py + dy * t)
        for w in range(-2, 3):
            for h in range(-1, 2):
                shade = 0.26 + 0.30 * abs(w) / 2.0 + 0.18 * t
                p.set(x + w, y + h, pal.lit("WOOD", min(1.0, shade)))
    kx, ky = int(px + dx), int(py + dy)              # pommeau de laiton
    for y in range(ky - 3, ky + 4):
        for x in range(kx - 3, kx + 4):
            r = ((x - kx) / 3.2) ** 2 + ((y - ky) / 3.2) ** 2
            if r <= 1.0:
                p.set(x, y, pal.lit("GOLD", 0.16 + 0.5 * r))
    for y in range(py - 2, py + 3):                  # axe
        for x in range(px - 2, px + 3):
            if abs(x - px) + abs(y - py) <= 2:
                p.set(x, y, pal.lit("STEEL", 0.30))
    return p


def make_niche():
    """Niche creusee dans le mur d'en face, avec son offrande."""
    half = F                                          # distance 1
    x0, x1 = snap(CX - 28, CX + 28)
    y0, y1 = CY - 26, CY + 22
    p = Piece(x0, y0, x1 - x0, y1 - y0)
    for y in range(y0, y1):
        for x in range(x0, x1):
            dx, dy = x - CX, y - (CY - 2)
            if abs(dx) > 24 or abs(dy) > 20:
                continue
            edge = max(abs(dx) / 24.0, abs(dy) / 20.0)
            if edge > 0.86:
                p.set(x, y, 6)                        # encadrement
            elif edge > 0.78:
                p.set(x, y, 7)                        # ombre portee
            else:
                p.set(x, y, 0 if dy < 6 else 7)       # creux sombre
    for y in range(CY - 2, CY + 8):                   # un objet pose dedans
        for x in range(CX - 7, CX + 8):
            r = ((x - CX) / 7.0) ** 2 + ((y - CY - 3) / 5.0) ** 2
            if r <= 1.0:
                p.set(x, y, 14 if r < 0.35 else 8)
    return p


# Gamme de carnation, du plus clair au plus sombre. La palette de
# pierre n'avait aucune teinte de peau : les quatre bruns du bois et du
# sol ont ete choisis pour servir aussi de carnation.
SKIN = list(reversed(pal.ramp("SKIN")))
STEEL = list(reversed(pal.ramp("STEEL")))
HAIR_DARK = list(reversed(pal.ramp("HAIRD")))
HAIR_LIGHT = list(reversed(pal.ramp("HAIRL")))
HAIR_RED = list(reversed(pal.ramp("HAIRR")))
CLOAK_GREY = list(reversed(pal.ramp("IRON")))
CLOAK_GREEN = list(reversed(pal.ramp("CLOTHG")))
CLOAK_RED = list(reversed(pal.ramp("CLOTHR")))
LINEN = list(reversed(pal.ramp("BONE")))

# Un visage de trente-deux pixels ne supporte pas des traits calcules :
# le volume vient d'un eclairage d'ellipsoide, mais les yeux, le nez et
# la bouche sont poses pixel par pixel, sans quoi ils se noient.
FACE_CX, FACE_CY = 15, 14                          # centre de la tete
FACE_RX, FACE_RY = 8.4, 10.0
EYE_Y = 14                               # ligne des yeux
EYE_L, EYE_R = 11, 18                    # bord gauche de chaque oeil
NOSE_X = 15
MOUTH_Y = 20
LIGHT = (-0.52, -0.60, 0.61)             # haut, gauche, devant


def ramp(tones, t):
    """t de 0 (le plus clair) a 1 (le plus sombre) -> index de palette."""
    i = int(t * (len(tones) - 1) + 0.5)
    return tones[max(0, min(len(tones) - 1, i))]


def head_half(y, cy, rx, ry, jaw):
    """Demi-largeur de la tete a cette hauteur : crane rond, machoire
    qui se resserre jusqu'au menton."""
    dy = (y - cy) / ry
    if dy < -1.05 or dy > 1.12:
        return 0.0
    if dy <= 0.0:
        return rx * math.sqrt(max(0.0, 1.0 - dy * dy))
    taper = 1.0 - jaw * dy * dy
    return rx * max(0.0, taper) * math.sqrt(max(0.0, 1.0 - (dy / 1.10) ** 3))


def draw_face(p, tones, jaw=0.34, cy=FACE_CY, rx=FACE_RX, ry=FACE_RY, cx=FACE_CX):
    """Le volume de la tete, eclaire d'en haut a gauche."""
    lx, ly, lz = LIGHT
    for y in range(32):
        half = head_half(y, cy, rx, ry, jaw)
        if half < 0.6:
            continue
        for x in range(32):
            if abs(x - cx) > half:
                continue
            nx = (x - cx) / half
            ny = (y - cy) / ry
            nz = math.sqrt(max(0.04, 1.0 - min(1.0, 0.88 * nx * nx
                                               + 0.5 * ny * ny)))
            lum = 0.36 + 0.64 * max(0.0, nx * lx + ny * ly + nz * lz)
            if y < cy - ry * 0.42:                    # le front recule un peu
                lum -= 0.06
            if EYE_Y - 3 <= y <= EYE_Y - 1 and abs(x - cx) < rx * 0.80:
                lum -= 0.13                           # creux des orbites
            if EYE_Y + 2 <= y <= EYE_Y + 5 and rx * 0.34 < abs(x - cx) < rx * 0.92:
                lum += 0.10                           # pommettes
            lum -= 0.26 * max(0.0, abs(x - cx) / half - 0.74) / 0.26
            p.set(x, y, ramp(tones, 1.0 - max(0.0, min(1.0, lum))))


def draw_features(p, tones, iris=9, brow=9, cx=FACE_CX, narrow=0):
    """Yeux, nez, bouche, menton : poses au pixel."""
    light, mid, dark = tones[0], tones[2], tones[3]
    el, er = EYE_L + narrow, EYE_R - narrow
    # Un blanc de chaque cote de l'iris donnait un regard de poupee : on
    # n'en garde qu'un, du cote eclaire, comme sur un vrai reflet.
    for ox, out in ((el, 0), (er, 2)):
        for x in range(ox - 1, ox + 3):           # paupiere superieure
            p.set(x, EYE_Y - 1, pal.lit("SKIN", 0.94))
        p.set(ox, EYE_Y, dark)
        p.set(ox + 1, EYE_Y, dark)
        p.set(ox + 2, EYE_Y, dark)
        p.set(ox + out, EYE_Y, pal.one("WHITE"))  # reflet
        p.set(ox + (1 if out else 1), EYE_Y, iris)
        p.set(ox + 2 - out, EYE_Y, pal.one("INK"))   # pupille
        for x in range(ox, ox + 3):               # paupiere inferieure
            p.set(x, EYE_Y + 1, mid)
    for ox in (el - 1, er - 1):                   # sourcils
        for x in range(ox, ox + 4):
            p.set(x, EYE_Y - 3, brow)

    for y in range(EYE_Y + 1, MOUTH_Y - 2):       # arete du nez
        p.set(NOSE_X, y, light)
        p.set(NOSE_X + 1, y, dark)                # cote a l'ombre
    p.set(NOSE_X - 1, MOUTH_Y - 2, pal.lit("SKIN", 0.86))  # narines
    p.set(NOSE_X + 2, MOUTH_Y - 2, pal.lit("SKIN", 0.86))
    p.set(NOSE_X, MOUTH_Y - 2, light)
    p.set(NOSE_X + 1, MOUTH_Y - 2, dark)

    for x in range(cx - 3, cx + 4):               # bouche
        p.set(x, MOUTH_Y, pal.lit("BLOOD", 0.72))
    p.set(cx - 4, MOUTH_Y, dark)
    p.set(cx + 4, MOUTH_Y, dark)
    for x in range(cx - 2, cx + 3):               # levre inferieure eclairee
        p.set(x, MOUTH_Y + 1, light)
    for x in range(cx - 2, cx + 3):               # creux sous la levre
        p.set(x, MOUTH_Y + 2, mid)


def draw_neck(p, tones, cx=FACE_CX, cy=FACE_CY, ry=FACE_RY, wide=4, top=None):
    top = top if top is not None else int(cy + ry * 0.94)
    for y in range(top, 28):
        for x in range(cx - wide, cx + wide + 1):
            t = 0.58 + 0.24 * (1.0 - (x - cx + wide) / (2.0 * wide))
            p.set(x, y, ramp(tones, t))
    for x in range(cx - wide + 1, cx + wide):     # ombre portee du menton
        p.set(x, top, ramp(tones, 0.90))
        p.set(x, top + 1, ramp(tones, 0.80))


def draw_shoulders(p, cols, cx=FACE_CX):
    """Buste : deux tons, pour asseoir le portrait dans son cadre."""
    for y in range(27, 32):
        w = 7 + (y - 27) * 3
        for x in range(cx - w, cx + w + 1):
            if not 0 <= x < 32:
                continue
            t = (x - (cx - w)) / (2.0 * w)
            p.set(x, y, cols[0] if 0.20 < t < 0.60 else cols[1])


def draw_hair(p, tones, cx=FACE_CX, cy=FACE_CY, rx=FACE_RX, ry=FACE_RY, jaw=0.34,
              hairline=-0.32, drop=0.0, volume=1.12, base=0.24,
              spread=0.48, parted=False, sweep=0.0, vshade=0.20):
    """Masse de cheveux : une coque autour du crane, qui redescend le
    long du visage jusqu'a `drop`. Dessiner des meches isolees donnait
    des trainees ; une masse ombree se lit bien mieux en 32 pixels."""
    bottom = cy + ry * drop
    for y in range(32):
        outer = head_half(y, cy, rx * volume, ry * volume, 0.18)
        if outer < 0.6 or y > bottom + 0.5:
            continue
        face = head_half(y, cy, rx, ry, jaw)
        for x in range(32):
            d = abs(x - cx)
            if d > outer:
                continue
            limit = ry * (hairline + sweep * (x - cx) / rx)
            above = (y - cy) <= limit
            if not above and d <= face:
                continue                          # on ne couvre pas le visage
            if parted and above and d <= 1 and (y - cy) < -ry * 0.60:
                continue                          # la raie
            t = base + spread * d / outer \
                + vshade * max(0.0, (y - cy + ry) / ry)
            p.set(x, y, ramp(tones, min(1.0, t)))


def draw_beard(p, tones, cx=FACE_CX, cy=FACE_CY, rx=FACE_RX, ry=FACE_RY, length=4,
               moustache=True, top=None, base=0.28, spread=0.44):
    """Barbe : suit la machoire, deborde sous le menton, laisse la
    bouche visible si on ne veut pas de moustache."""
    top = top if top is not None else MOUTH_Y + 2
    chin = int(cy + ry * 0.94)
    for y in range(top, chin + length):
        if y <= chin:
            half = head_half(y, cy, rx * 1.02, ry, 0.34)
        else:                                     # la barbe pend, en pointe
            k = (y - chin) / max(1.0, length)
            half = head_half(chin, cy, rx * 1.02, ry, 0.34) * (1.0 - 0.72 * k)
        if half < 0.6:
            continue
        for x in range(32):
            if abs(x - cx) > half:
                continue
            if y <= MOUTH_Y + 1 and abs(x - cx) < rx * 0.42:
                continue                          # on degage la bouche
            t = base + spread * abs(x - cx) / half + 0.24 * (y - top) / \
                max(1.0, chin + length - top)
            p.set(x, y, ramp(tones, min(1.0, t)))
    if moustache:
        for x in range(cx - 4, cx + 5):
            t = base + spread * abs(x - cx) / 4.0
            p.set(x, MOUTH_Y - 1, ramp(tones, t))
            if length > 4:                        # les longues barbes la
                p.set(x, MOUTH_Y, ramp(tones, t + 0.14))


def draw_helmet(p, cx=FACE_CX, cy=FACE_CY, rx=FACE_RX, ry=FACE_RY, nasal=True, crest=None,
                brim=-0.34):
    """Casque : calotte d'acier, bord marque, protege-nez."""
    lx, ly, _ = LIGHT
    for y in range(32):
        half = head_half(y, cy, rx * 1.16, ry * 1.14, 0.30)
        if half < 0.6 or y - cy > ry * brim:
            continue
        for x in range(32):
            if abs(x - cx) > half:
                continue
            nx = (x - cx) / half
            ny = (y - cy) / ry
            nz = math.sqrt(max(0.05, 1.0 - min(1.0, nx * nx)))
            lum = 0.22 + 0.78 * max(0.0, nx * lx + ny * ly + nz * 0.62)
            if abs(nx) < 0.22:                    # arete centrale, en reflet
                lum += 0.22
            p.set(x, y, ramp(STEEL, 1.0 - max(0.0, min(1.0, lum))))
    band = int(cy + ry * brim)
    half = head_half(band, cy, rx * 1.16, ry * 1.14, 0.30)
    for x in range(int(cx - half), int(cx + half) + 1):
        p.set(x, band, pal.lit("STEEL", 0.85))
        p.set(x, band - 1, pal.lit("STEEL", 0.10))
    if nasal:
        for y in range(band, MOUTH_Y - 2):
            p.set(cx, y, pal.lit("STEEL", 0.28))
            p.set(cx + 1, y, pal.lit("STEEL", 0.58))
    if crest is not None:
        for y in range(int(cy - ry * 1.32), band - 1):
            p.set(cx - 1, y, crest)
            p.set(cx, y, crest)
            p.set(cx + 1, y, pal.lit("CLOTHR", 0.70))


def draw_hood(p, tones, cx=FACE_CX, cy=FACE_CY, rx=FACE_RX, ry=FACE_RY, shade=True,
              base=0.24, spread=0.50, low=1.14):
    """Capuche : couronne large, ouverture ovale sur le visage."""
    for y in range(32):
        outer = head_half(y, cy - 1, rx * 1.38, ry * 1.30, 0.10)
        if outer < 0.6 or y - cy > ry * low:
            continue
        inner = head_half(y, cy, rx * 1.02, ry * 1.02, 0.34)
        for x in range(32):
            d = abs(x - cx)
            if d > outer:
                continue
            if d <= inner and y - cy > -ry * 0.56:
                continue                          # l'ouverture du visage
            t = base + spread * d / outer \
                + 0.24 * max(0.0, (y - cy) / ry)
            p.set(x, y, ramp(tones, min(1.0, t)))
    if shade:                                     # ombre portee du capuchon
        for y in range(int(cy - ry * 0.56), EYE_Y - 3):
            half = head_half(y, cy, rx, ry, 0.34)
            for x in range(int(cx - half), int(cx + half) + 1):
                p.set(x, y, ramp(SKIN, 0.86))


PORTRAIT_TOP, PORTRAIT_H = 3, 26         # rognage : on garde la tete


def crop(p, top, height):
    """Rogne un morceau en hauteur, en gardant sa largeur."""
    out = Piece(p.x0, p.y0, p.w, height)
    for y in range(height):
        src = top + y
        if 0 <= src < p.h:
            out.px[y] = list(p.px[src])
    return out


def make_portrait(cls):
    """Portrait 32x32, un par classe : meme tete eclairee, coiffee,
    casquee ou encapuchonnee selon le metier."""
    p = Piece(0, 0, 32, 32)
    if cls == 0:                                      # guerrier
        draw_shoulders(p, (pal.lit("IRON", 0.45), pal.lit("IRON", 0.70)))
        draw_face(p, SKIN, jaw=0.26)
        draw_neck(p, SKIN, wide=5)
        draw_features(p, SKIN, iris=pal.lit("WOOD", 0.55),
                      brow=pal.lit("HAIRD", 0.75))
        draw_beard(p, HAIR_DARK, length=3, moustache=True)
        draw_helmet(p, nasal=True)
    elif cls == 1:                                    # barbare
        draw_shoulders(p, (pal.lit("HIDE", 0.45), pal.lit("HIDE", 0.72)))
        draw_hair(p, HAIR_RED, jaw=0.28, hairline=-0.28, drop=0.98,
                  volume=1.40, base=0.10, spread=0.62, vshade=0.24)
        draw_face(p, SKIN, jaw=0.28)
        draw_neck(p, SKIN, wide=6)
        draw_features(p, SKIN, iris=pal.lit("MOSS", 0.45),
                      brow=pal.lit("HAIRR", 0.70))
        draw_beard(p, HAIR_RED, length=6, moustache=True,
                   base=0.18, spread=0.56)
        for y in range(EYE_Y - 5, EYE_Y + 2):         # cicatrice
            p.set(FACE_CX - 6, y, pal.lit("BLOOD", 0.45))
    elif cls == 2:                                    # roublard
        draw_shoulders(p, (pal.lit("HAIRD", 0.55), pal.lit("HAIRD", 0.80)))
        draw_face(p, SKIN, jaw=0.40, rx=FACE_RX * 0.94)
        draw_neck(p, SKIN, wide=4)
        draw_features(p, SKIN, iris=pal.lit("EARTH", 0.70),
                      brow=pal.lit("HAIRD", 0.85), narrow=1)
        draw_hood(p, CLOAK_GREY + CLOAK_GREY[-2:], low=1.30, base=0.10)
    elif cls == 3:                                    # rodeur
        draw_shoulders(p, (pal.lit("CLOTHG", 0.40), pal.lit("CLOTHG", 0.70)))
        draw_hair(p, HAIR_DARK, jaw=0.32, hairline=-0.24, drop=0.40,
                  volume=1.08, base=0.22)
        draw_face(p, SKIN, jaw=0.32)
        draw_neck(p, SKIN, wide=4)
        draw_features(p, SKIN, iris=pal.lit("MOSS", 0.35),
                      brow=pal.lit("HAIRD", 0.75))
        draw_beard(p, HAIR_DARK, length=2, moustache=False)
        draw_hood(p, CLOAK_GREEN, shade=False, base=0.10, low=1.30)
    elif cls == 4:                                    # paladin
        draw_shoulders(p, (pal.lit("STEEL", 0.30), pal.lit("STEEL", 0.55)))
        draw_face(p, SKIN, jaw=0.28)
        draw_neck(p, SKIN, wide=5)
        draw_features(p, SKIN, iris=pal.lit("WOOD", 0.55),
                      brow=pal.lit("HAIRD", 0.75))
        draw_helmet(p, nasal=True, crest=pal.lit("CLOTHR", 0.35))
    elif cls == 5:                                    # clerc
        draw_shoulders(p, (pal.lit("BONE", 0.25), pal.lit("BONE", 0.45)))
        draw_face(p, SKIN, jaw=0.32)
        draw_neck(p, SKIN, wide=4)
        draw_features(p, SKIN, iris=pal.lit("WOOD", 0.50),
                      brow=pal.lit("HAIRL", 0.60))
        draw_hood(p, LINEN, shade=False, base=0.14, low=1.30)
        for y in range(3, 8):                         # symbole sur le capuchon
            p.set(FACE_CX, y, pal.lit("GOLD", 0.20))
        for x in range(FACE_CX - 2, FACE_CX + 3):
            p.set(x, 5, pal.lit("GOLD", 0.20))
    elif cls == 6:                                    # magicien
        draw_shoulders(p, (pal.lit("CLOTHB", 0.40), pal.lit("CLOTHB", 0.70)))
        draw_hair(p, HAIR_LIGHT, jaw=0.36, hairline=0.02, drop=0.80,
                  volume=1.34, base=0.16)
        draw_face(p, SKIN, jaw=0.36)
        draw_neck(p, SKIN, wide=4)
        draw_features(p, SKIN, iris=pal.lit("MAGIC", 0.40),
                      brow=pal.lit("HAIRL", 0.45))
        draw_beard(p, HAIR_LIGHT, length=7, moustache=True)
        for x in (FACE_CX - 4, FACE_CX + 4):                    # rides du front
            p.set(x, EYE_Y - 6, pal.lit("SKIN", 0.62))
            p.set(x, EYE_Y - 5, pal.lit("SKIN", 0.62))
    else:                                             # ensorceleur
        draw_shoulders(p, (pal.lit("CLOTHP", 0.40), pal.lit("CLOTHP", 0.70)))
        draw_hair(p, HAIR_DARK, jaw=0.42, hairline=-0.20, drop=0.66,
                  volume=1.26, base=0.14, sweep=-0.26)
        draw_face(p, SKIN, jaw=0.42, rx=FACE_RX * 0.96)
        draw_neck(p, SKIN, wide=4)
        draw_features(p, SKIN, iris=pal.lit("GOLD", 0.25),
                      brow=pal.lit("HAIRD", 0.85))
        for k in range(4):                            # une meche libre
            p.set(FACE_CX - 5 + k, EYE_Y - 4 + k, pal.lit("HAIRD", 0.55))
    return p


def make_icon(kind):
    """Icone 16x16 pour l'inventaire."""
    p = Piece(0, 0, 16, 16)
    if kind == 0:                                     # arme
        for y in range(2, 12):
            p.set(8, y, 2), p.set(7, y, 1)
        for x in range(5, 12):
            p.set(x, 12, 9)
        p.set(8, 14, 9), p.set(8, 13, 9)
    elif kind == 1:                                   # armure
        for y in range(3, 13):
            for x in range(4, 12):
                if abs(x - 8) < 4 - abs(y - 8) // 4:
                    p.set(x, y, 4)
        for y in range(4, 12):
            p.set(8, y, 2)
    elif kind == 2:                                   # potion
        ellipse(p, 8, 10, 4, 4, 15)
        for y in range(3, 7):
            p.set(7, y, 2), p.set(9, y, 2)
        p.set(8, 2, 8)
    elif kind == 3:                                   # parchemin
        for y in range(3, 13):
            for x in range(3, 13):
                p.set(x, y, 1)
        for y in (5, 7, 9):
            for x in range(5, 11):
                p.set(x, y, 6)
    else:                                             # cle
        ellipse(p, 6, 6, 3, 3, 14)
        p.set(6, 6, 0)
        for x in range(7, 13):
            p.set(x, 8, 14)
        p.set(11, 9, 14), p.set(12, 10, 14)
    return p


# --- monstres -----------------------------------------------------------
def ellipse(p, cx, cy, rx, ry, idx):
    for y in range(int(cy - ry), int(cy + ry) + 1):
        for x in range(int(cx - rx), int(cx + rx) + 1):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                p.set(x, y, idx)


def limb(p, x0, y0, x1, y1, thick, idx):
    """Trait epais : membres, cous, armes."""
    steps = max(abs(x1 - x0), abs(y1 - y0), 1)
    for i in range(steps + 1):
        x = x0 + (x1 - x0) * i / steps
        y = y0 + (y1 - y0) * i / steps
        for dx in range(-thick, thick + 1):
            for dy in range(-thick, thick + 1):
                if dx * dx + dy * dy <= thick * thick:
                    p.set(int(x) + dx, int(y) + dy, idx)


def eyes(p, cx, cy, spread, idx=15, size=2):
    for e in (-spread, spread):
        ellipse(p, cx + e, cy, size, size, idx)


def make_monster(kind, frame=0):
    """Neuf familles de creatures, deux poses chacune. Les couleurs
    restent dans la palette du donjon : gris de pierre, vert, rouge,
    ocre, blanc.  Chaque famille sert plusieurs entrees du bestiaire."""
    w, h = 96, 88                                    # largeur multiple de 16
    x0 = ((CX - w // 2) // 16) * 16
    p = Piece(x0, CY - h // 2 + 6, w, h)
    cx = x0 + w // 2
    cy = CY - h // 2 + 6 + h // 2
    f = 1 if frame else 0                            # deuxieme pose
    sway = 2 if frame else -2

    if kind == 0:                                    # --- bete a quatre pattes
        body, dark = C[4], C[6]
        ellipse(p, cx + 2, cy + 10, 26, 15, body)
        ellipse(p, cx + 2, cy + 6, 24, 11, C[3])        # dos eclaire
        for s, off in ((-1, -16), (-1, 8), (1, -12), (1, 12)):
            limb(p, cx + off, cy + 18, cx + off + s * 3, cy + 28 + f * 2, 3, dark)
        ellipse(p, cx - 26, cy + 2, 13, 11, body)    # tete
        ellipse(p, cx - 34, cy + 4, 6, 5, C[3])         # museau
        limb(p, cx - 31, cy - 8, cx - 27, cy - 2, 2, dark)   # oreilles
        limb(p, cx - 24, cy - 10, cx - 22, cy - 3, 2, dark)
        eyes(p, cx - 29, cy - 1, 0, C[15], 1)
        for t in range(26):                          # queue
            p.set(cx + 27 + t // 2, cy + 6 - t + (t * sway) // 14, dark)
        for t in range(-6, 7):                       # crocs
            if t % 3 == 0:
                p.set(cx - 36 + abs(t) // 2, cy + 8, 13)

    elif kind == 1:                                  # --- squelette
        bone, shade = C[13], C[2]
        ellipse(p, cx, cy - 24, 11, 13, bone)        # crane
        for e in (-4, 4):
            ellipse(p, cx + e, cy - 26, 3, 4, C[0])
        for t in range(-4, 5, 2):                    # machoire
            p.set(cx + t, cy - 14, C[0])
        limb(p, cx, cy - 12, cx, cy + 14, 3, bone)   # colonne
        for r in range(-8, 12, 5):                   # cotes
            for x in range(-12, 13):
                if abs(x) > 3:
                    p.set(cx + x, cy + r + abs(x) // 4, shade)
        limb(p, cx - 12, cy - 8, cx - 20 - f * 3, cy + 6 - f * 8, 2, bone)
        limb(p, cx + 12, cy - 8, cx + 20, cy + 10, 2, bone)
        limb(p, cx - 6, cy + 16, cx - 9, cy + 34, 3, bone)
        limb(p, cx + 6, cy + 16, cx + 9, cy + 34, 3, bone)
        limb(p, cx + 20, cy + 10, cx + 26, cy - 16, 2, C[4])     # arme
        for t in range(6):
            p.set(cx + 26 + t // 3, cy - 18 - t, C[2])

    elif kind == 2:                                  # --- petit humanoide
        skin, cloth = C[12], C[9]
        ellipse(p, cx, cy + 8, 13, 16, skin)         # corps
        ellipse(p, cx, cy - 12, 11, 11, skin)        # tete
        limb(p, cx - 9, cy - 18, cx - 14, cy - 24, 2, skin)   # oreilles
        limb(p, cx + 9, cy - 18, cx + 14, cy - 24, 2, skin)
        eyes(p, cx, cy - 13, 4, C[14], 2)
        for t in range(-4, 5, 2):
            p.set(cx + t, cy - 6, C[13])                # dents
        limb(p, cx - 12, cy + 4, cx - 18 - f * 2, cy + 16, 3, skin)
        limb(p, cx + 12, cy + 2, cx + 18, cy - 10 - f * 4, 3, skin)
        limb(p, cx + 18, cy - 26 - f * 4, cx + 18, cy + 14, 1, C[4])  # lance
        limb(p, cx - 6, cy + 22, cx - 8, cy + 34, 3, cloth)
        limb(p, cx + 6, cy + 22, cx + 8, cy + 34, 3, cloth)

    elif kind == 3:                                  # --- humanoide arme
        skin, dark = C[12], C[6]
        ellipse(p, cx, cy + 10, 20, 20, skin)
        ellipse(p, cx, cy + 6, 17, 15, C[3])            # torse eclaire
        ellipse(p, cx, cy - 16, 13, 13, skin)
        eyes(p, cx, cy - 18, 5, C[14], 2)
        for t in (-5, 5):                            # defenses
            p.set(cx + t, cy - 8, C[13]), p.set(cx + t, cy - 7, C[13])
        limb(p, cx - 18, cy + 4, cx - 26, cy + 18 - f * 4, 4, skin)
        limb(p, cx + 18, cy + 2, cx + 26, cy - 12 - f * 6, 4, skin)
        limb(p, cx + 26, cy - 14 - f * 6, cx + 34, cy - 30 - f * 6, 2, C[4])
        for t in range(10):                          # lame de la hache
            p.set(cx + 30 + t // 2, cy - 32 - f * 6 + t, C[2])
            p.set(cx + 36 - t // 3, cy - 30 - f * 6 + t, C[1])
        limb(p, cx - 8, cy + 28, cx - 11, cy + 40, 4, dark)
        limb(p, cx + 8, cy + 28, cx + 11, cy + 40, 4, dark)

    elif kind == 4:                                  # --- grand brutal
        skin, dark = C[3], C[5]
        ellipse(p, cx, cy + 14, 27, 26, skin)
        ellipse(p, cx, cy + 10, 23, 20, C[2])
        ellipse(p, cx, cy - 18, 16, 15, skin)
        limb(p, cx - 14, cy - 30, cx - 20, cy - 38, 3, C[13])    # cornes
        limb(p, cx + 14, cy - 30, cx + 20, cy - 38, 3, C[13])
        eyes(p, cx, cy - 20, 6, C[15], 2)
        for t in range(-6, 7, 3):
            p.set(cx + t, cy - 10, C[13])
        limb(p, cx - 24, cy + 6, cx - 34, cy + 22 - f * 4, 5, skin)
        limb(p, cx + 24, cy + 4, cx + 32, cy - 14 - f * 6, 5, skin)
        limb(p, cx + 32, cy - 16 - f * 6, cx + 38, cy - 36 - f * 8, 4, C[9])
        ellipse(p, cx + 38, cy - 38 - f * 8, 8, 8, C[9])         # masse
        limb(p, cx - 10, cy + 36, cx - 13, cy + 42, 6, dark)
        limb(p, cx + 10, cy + 36, cx + 13, cy + 42, 6, dark)

    elif kind == 5:                                  # --- spectre
        for r in range(30, 7, -3):                   # voile en degrade
            idx = 5 if r > 20 else (6 if r > 12 else 7)
            ellipse(p, cx, cy + 6 + f, max(2, r - 6), r, idx)
        for t in range(24):                          # lambeaux
            p.set(cx - 22 + t, cy + 34 + (t % 5) - f * 2, 6)
        ellipse(p, cx, cy - 16, 12, 13, C[7])           # capuche
        ellipse(p, cx, cy - 14, 9, 10, C[0])
        eyes(p, cx, cy - 16, 4, C[12], 2)
        limb(p, cx - 14, cy - 2, cx - 24 - f * 2, cy - 12, 2, C[6])
        limb(p, cx + 14, cy - 2, cx + 24, cy - 14 - f * 2, 2, C[6])

    elif kind == 6:                                  # --- momie
        wrap, shade = C[2], C[4]
        ellipse(p, cx, cy + 12, 18, 24, wrap)
        ellipse(p, cx, cy - 16, 12, 14, wrap)
        for r in range(-28, 36, 5):                  # bandelettes
            for x in range(-20, 21):
                if abs(x) < 19 - abs(r) // 6:
                    p.set(cx + x + (r // 4) % 3, cy + r, shade)
        ellipse(p, cx - 4, cy - 18, 3, 3, C[0])
        ellipse(p, cx + 4, cy - 18, 3, 3, C[0])
        limb(p, cx - 16, cy + 2, cx - 30, cy - 6 - f * 3, 4, wrap)
        limb(p, cx + 16, cy + 2, cx + 30, cy - 4 - f * 3, 4, wrap)
        for t in range(8):                           # bandelettes qui pendent
            p.set(cx - 30 + t % 3, cy + 2 + t, shade)
            p.set(cx + 30 - t % 3, cy + 4 + t, shade)

    elif kind == 7:                                  # --- creature ailee
        body, wing = C[6], C[5]
        for s in (-1, 1):                            # ailes
            for i in range(5):
                limb(p, cx + s * 10, cy - 4,
                     cx + s * (30 + i * 2), cy - 22 + i * 9 + f * 4, 2, wing)
            ellipse(p, cx + s * 24, cy - 4 + f * 2, 13, 20 - f * 3, wing)
        ellipse(p, cx, cy + 8, 14, 18, body)
        ellipse(p, cx, cy - 14, 11, 11, body)
        limb(p, cx - 10, cy - 22, cx - 14, cy - 30, 2, body)  # cornes
        limb(p, cx + 10, cy - 22, cx + 14, cy - 30, 2, body)
        eyes(p, cx, cy - 15, 4, C[14], 2)
        limb(p, cx - 6, cy + 24, cx - 10, cy + 34, 3, body)   # serres
        limb(p, cx + 6, cy + 24, cx + 10, cy + 34, 3, body)

    else:                                            # --- hydre
        ellipse(p, cx, cy + 22, 24, 14, C[12])          # corps
        ellipse(p, cx, cy + 18, 20, 10, C[3])
        necks = ((-30, -18), (-16, -30), (0, -36), (16, -30), (30, -16))
        for i, (hx, hy) in enumerate(necks):
            wob = f * (2 if i % 2 else -2)
            limb(p, cx, cy + 16, cx + hx, cy + hy + wob, 3, C[12])
            ellipse(p, cx + hx, cy + hy + wob, 8, 6, C[12])
            ellipse(p, cx + hx + (2 if hx > 0 else -2), cy + hy + wob + 2,
                    5, 3, 15)
            eyes(p, cx + hx, cy + hy + wob - 2, 3, C[14], 1)
        for t in range(20):                          # queue
            p.set(cx + 24 + t // 2, cy + 28 + t // 3, C[12])
    return p


# --- encodage planaire --------------------------------------------------
def encode(piece):
    """Masque puis quatre plans, mots de 16 pixels."""
    wwords = piece.w // 16
    assert piece.w % 16 == 0, piece.w
    out = bytearray()
    for plane in range(-1, DEPTHS):                  # -1 = masque
        for y in range(piece.h):
            for wx in range(wwords):
                acc = 0
                for b in range(16):
                    idx = piece.px[y][wx * 16 + b]
                    if plane < 0:
                        bit = 1 if idx is not None else 0
                    else:
                        bit = ((idx or 0) >> plane) & 1
                    acc = (acc << 1) | bit
                out += struct.pack(">H", acc)
    return bytes(out), wwords


ART_INDEX = {}                           # rempli par build_art


def build_art():
    pieces = [make_background()]
    ART_INDEX["ART_BG"] = 0
    ART_INDEX["ART_FRONT"] = len(pieces)
    pieces += [make_front(k) for k in (1, 2, 3, 4)]
    ART_INDEX["ART_LEFT"] = len(pieces)
    pieces += [make_side(i, -0.5) for i in range(DEPTHS)]
    ART_INDEX["ART_RIGHT"] = len(pieces)
    pieces += [make_side(i, 0.5) for i in range(DEPTHS)]
    ART_INDEX["ART_DOOR"] = len(pieces)
    pieces += [make_front(k, door=True) for k in (1, 2, 3)]
    ART_INDEX["ART_MONSTER"] = len(pieces)
    for k in range(NMONSTERART):                                 # deux poses
        pieces += [make_monster(k, 0), make_monster(k, 1)]
    # de quoi habiller les passages lateraux : la face du fond du passage
    # et son mur exterieur, sans quoi une ouverture n'est qu'un trou noir
    ART_INDEX["ART_FRONTL"] = len(pieces)
    pieces += [make_front(k, offset=-1) for k in (1, 2, 3, 4)]
    ART_INDEX["ART_FRONTR"] = len(pieces)
    pieces += [make_front(k, offset=1) for k in (1, 2, 3, 4)]
    ART_INDEX["ART_OUTERL"] = len(pieces)
    pieces += [make_side(i, -1.5) for i in (2, 3)]
    ART_INDEX["ART_OUTERR"] = len(pieces)
    pieces += [make_side(i, 1.5) for i in (2, 3)]
    ART_INDEX["ART_TITLE"] = len(pieces)
    pieces += [make_title()]
    ART_INDEX["ART_GATE"] = len(pieces)
    pieces += [make_front(k, gate=True) for k in (1, 2, 3)]
    ART_INDEX["ART_LEVER"] = len(pieces)
    pieces += [make_lever(s) for s in (0, 1)]
    ART_INDEX["ART_NICHE"] = len(pieces)
    pieces += [make_niche()]
    ART_INDEX["ART_PORTRAIT"] = len(pieces)
    # Le portrait est dessine sur un carre de trente-deux, puis rogne :
    # le nom du heros prend toute la largeur du panneau au-dessus de
    # lui, ce qui laisse la place d'ecrire les points sans abreger.
    pieces += [crop(make_portrait(c), PORTRAIT_TOP, PORTRAIT_H)
               for c in range(NCLASSPORTRAIT)]
    ART_INDEX["ART_ICON"] = len(pieces)
    pieces += [make_icon(k) for k in range(5)]

    blobs, descs = [], []
    offset = 2 + len(pieces) * 12
    for p in pieces:
        data, wwords = encode(p)
        dst = (VIEW_Y + p.y0) * SCRBPL + (VIEW_X + p.x0) // 8
        descs.append(struct.pack(">IHHHH", offset, wwords, p.h, dst, 0))
        blobs.append(data)
        offset += len(data)
    return (struct.pack(">H", len(pieces)) + b"".join(descs) + b"".join(blobs),
            pieces)


# --- donjon -------------------------------------------------------------
MAPW = MAPH = 24
FLOOR, WALL, DOOR, STAIRS, LOCKED, NICHE, RUNE = 0, 1, 2, 3, 4, 5, 6
LEVER, GATE = 7, 8                       # herse et son levier
CHEST, MONSTER, ITEM = 0x10, 0x20, 0x30              # quartet haut

# Rencontres par niveau : indices dans MonTypes (gen_tables.py)
ENCOUNTERS = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
    [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 16],
    [13, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24],
]

# Objets : doivent suivre exactement ItemTable dans src/crawl.s
ITEMS = {
    "DAGUE": 1, "EPEE COURTE": 2, "EPEE LONGUE": 3, "HACHE": 4,
    "HACHE DE GUERRE": 5, "MASSE": 6, "ARC COURT": 7, "BATON": 8,
    "EPEE LONGUE +1": 9, "HACHE RUNIQUE +2": 10, "DAGUE DE FEU +1": 11,
    "ROBE": 12, "ARMURE DE CUIR": 13, "COTTE DE MAILLES": 14,
    "HARNOIS": 15, "BOUCLIER": 16,
    "POTION DE SOIN": 17, "POTION MAJEURE": 18,
    "PARCHEMIN 1": 19, "PARCHEMIN 2": 20, "PARCHEMIN 3": 21,
    "PARCHEMIN 4": 22, "PARCHEMIN 5": 23, "PARCHEMIN 6": 24,
    "CLE DE FER": 25, "CLE D'ARGENT": 26,
    "GEMME": 27, "COURONNE": 28,
}

# butin par niveau, du plus modeste au plus rare
LOOT = [
    ["DAGUE", "EPEE COURTE", "BATON", "ARMURE DE CUIR", "POTION DE SOIN",
     "PARCHEMIN 1", "PARCHEMIN 2", "ARC COURT", "GEMME"],
    ["EPEE LONGUE", "HACHE", "MASSE", "COTTE DE MAILLES", "BOUCLIER",
     "POTION DE SOIN", "POTION MAJEURE", "PARCHEMIN 3", "PARCHEMIN 4", "GEMME"],
    ["HACHE DE GUERRE", "EPEE LONGUE +1", "HACHE RUNIQUE +2",
     "DAGUE DE FEU +1", "HARNOIS", "POTION MAJEURE", "PARCHEMIN 5",
     "PARCHEMIN 6", "COURONNE"],
]


def carve(level, seed):
    """Labyrinthe par backtracking, puis quelques passages en plus."""
    rnd = random.Random(seed)
    cells = (MAPW - 1) // 2, (MAPH - 1) // 2
    grid = [[WALL] * MAPW for _ in range(MAPH)]
    stack = [(0, 0)]
    seen = {(0, 0)}
    grid[1][1] = FLOOR
    while stack:
        cx, cy = stack[-1]
        nb = []
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = cx + dx, cy + dy
            if 0 <= nx < cells[0] and 0 <= ny < cells[1] and (nx, ny) not in seen:
                nb.append((nx, ny, dx, dy))
        if not nb:
            stack.pop()
            continue
        nx, ny, dx, dy = rnd.choice(nb)
        grid[1 + 2 * cy + dy][1 + 2 * cx + dx] = FLOOR
        grid[1 + 2 * ny][1 + 2 * nx] = FLOOR
        seen.add((nx, ny))
        stack.append((nx, ny))
    for _ in range(14 + 4 * level):                  # boucles : moins d'impasses
        x, y = rnd.randrange(2, MAPW - 2), rnd.randrange(2, MAPH - 2)
        if grid[y][x] == WALL and (grid[y][x - 1] == FLOOR) == (grid[y][x + 1] == FLOOR):
            grid[y][x] = FLOOR
    return grid, rnd


def floors(grid):
    return [(x, y) for y in range(MAPH) for x in range(MAPW)
            if grid[y][x] == FLOOR]


def build_level(level, seed):
    """Retourne (terrain, parametres, depart, escalier).

    Le plan est peuple dans un ordre precis pour rester jouable : escalier
    au plus loin, puis porte verrouillee sur le chemin et sa cle avant
    elle, puis coffres, objets, niches et monstres sur le reste."""
    grid, rnd = carve(level, seed)
    par = [[0] * MAPW for _ in range(MAPH)]
    cells = floors(grid)
    start = (1, 1)
    far = max(cells, key=lambda c: abs(c[0] - start[0]) + abs(c[1] - start[1]))
    grid[far[1]][far[0]] = STAIRS

    free = [c for c in cells if c not in (start, far)]
    rnd.shuffle(free)
    loot = LOOT[level]

    def take(n):
        out, free[:] = free[:n], free[n:]
        return out

    for x, y in take(4 + level):                     # coffres : or et objets
        grid[y][x] |= CHEST
        par[y][x] = ITEMS[rnd.choice(loot)]
    for x, y in take(3 + level):                     # objets au sol
        grid[y][x] |= ITEM
        par[y][x] = ITEMS[rnd.choice(loot)]
    tier = ENCOUNTERS[level]                         # bestiaire du niveau
    for i, (x, y) in enumerate(take(8 + 3 * level)):  # monstres postes
        grid[y][x] = (grid[y][x] & 0x0f) | MONSTER
        par[y][x] = tier[(i * 3 + level) % len(tier)]
    for x, y in take(2 + level):                     # portes ordinaires
        if grid[y][x] == FLOOR:
            grid[y][x] = DOOR
    # Serrures et cles : une serrure posee au hasard peut couper le niveau
    # en deux des le depart. On les place donc loin, et les cles pres.
    dist = distances(grid, start)
    far_cells = [c for c in free if dist.get(c, 99) >= 12]
    near_cells = [c for c in free if 2 <= dist.get(c, 99) <= 7]
    for x, y in far_cells[:1]:                       # une porte a runes
        if grid[y][x] == FLOOR:
            grid[y][x] = RUNE
            par[y][x] = level
            free.remove((x, y))
    placed = 0
    for x, y in far_cells[1:]:
        if placed >= 1 + level:
            break
        if grid[y][x] == FLOOR:
            grid[y][x] = LOCKED
            free.remove((x, y))
            placed += 1
    keys = 0
    for x, y in near_cells:
        if keys >= placed + 2:
            break
        if grid[y][x] == FLOOR:
            grid[y][x] |= ITEM
            par[y][x] = ITEMS["CLE DE FER"]
            free.remove((x, y))
            keys += 1

    # Herses et leviers : la herse coupe un couloir loin du depart, le
    # levier qui la commande est scelle dans un mur atteignable avant
    # elle. Le parametre porte le numero du mecanisme, pour les apparier.
    gates, placed_levers = 0, []
    for x, y in far_cells:
        if gates >= 1 + (level > 0):
            break
        if grid[y][x] != FLOOR:
            continue
        # distances(...) exclut deja les herses posees : en ajoutant la
        # case candidate on obtient exactement ce que le groupe pourra
        # atteindre une fois cette herse-la fermee.
        open_side = distances(grid, start, blocked={(x, y)})
        if far in open_side:                         # elle ne coupe rien
            continue
        if any(not any((px + dx, py + dy) in open_side      # ni enfermer un
                       for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
               for px, py in placed_levers):                # levier deja pose
            continue
        lever = None                                 # le levier doit rester
        for cx, cy in sorted(open_side, key=lambda c: -open_side[c]):
            if grid[cy][cx] != FLOOR or open_side[(cx, cy)] < 3:
                continue                             # du bon cote de la herse
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = cx + dx, cy + dy
                if grid[ny][nx] == WALL and not par[ny][nx]:
                    lever = (nx, ny)
                    break
            if lever:
                break
        if not lever:
            continue
        grid[y][x] = GATE
        par[y][x] = gates + 1
        grid[lever[1]][lever[0]] = LEVER
        par[lever[1]][lever[0]] = gates + 1
        placed_levers.append(lever)
        free.remove((x, y))
        gates += 1

    # niches : un mur borde par un couloir, avec une offrande dedans
    niches = 0
    for y in range(1, MAPH - 1):
        for x in range(1, MAPW - 1):
            if niches >= 3 + level:
                break
            if grid[y][x] != WALL or par[y][x]:
                continue
            if sum(1 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                   if grid[y + dy][x + dx] == FLOOR) == 1:
                if rnd.random() < 0.12:
                    grid[y][x] = NICHE
                    par[y][x] = ITEMS[rnd.choice(loot)]
                    niches += 1
    return grid, par, start, far


def build_maps():
    out = bytearray()
    levels = []
    for lv in range(3):
        grid, par, start, stairs = build_level(lv, 1000 + lv * 77)
        check_reachable(grid, start)
        check_solvable(grid, par, start)
        levels.append((grid, par, start, stairs))
        out += bytes((start[0], start[1], 1, 0))
        for y in range(MAPH):
            out += bytes(grid[y][x] & 0xff for x in range(MAPW))
        for y in range(MAPH):
            out += bytes(par[y][x] & 0xff for x in range(MAPW))
    return bytes(out), levels


def distances(grid, start, blocked=()):
    """Distance de chaque case au depart, murs exclus. `blocked` permet
    d'essayer une herse : on verifie ainsi qu'elle coupe bien la route."""
    import collections
    dist = {start: 0}
    q = collections.deque([start])
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if (nx, ny) in dist or not (0 <= nx < MAPW and 0 <= ny < MAPH):
                continue
            if (nx, ny) in blocked:
                continue
            if (grid[ny][nx] & 0x0f) in (WALL, NICHE, LEVER, GATE):
                continue
            dist[(nx, ny)] = dist[(x, y)] + 1
            q.append((nx, ny))
    return dist


def check_solvable(grid, par, start):
    """Le niveau doit rester finissable : au moins une cle atteignable
    sans forcer une serrure, ou l'escalier accessible directement."""
    import collections
    seen, q = {start}, collections.deque([start])
    keys, stairs = 0, False
    while q:
        x, y = q.popleft()
        cell = grid[y][x]
        if (cell & 0x0f) == STAIRS:
            stairs = True
        if (cell & 0x30) == ITEM and par[y][x] == ITEMS["CLE DE FER"]:
            keys += 1
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if (nx, ny) in seen or not (0 <= nx < MAPW and 0 <= ny < MAPH):
                continue
            if (grid[ny][nx] & 0x0f) in (WALL, NICHE, LOCKED, LEVER):
                continue
            seen.add((nx, ny))
            q.append((nx, ny))
    assert stairs or keys > 0, \
        "niveau bloque : ni escalier ni cle sans forcer une serrure"

    # Chaque levier doit s'atteindre sans franchir la herse qu'il commande,
    # sinon le mecanisme s'enferme lui-meme.
    shut = {(x, y) for y in range(MAPH) for x in range(MAPW)
            if (grid[y][x] & 0x0f) == GATE}
    if shut:
        reach, q = {start}, collections.deque([start])
        while q:
            x, y = q.popleft()
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if (nx, ny) in reach or (nx, ny) in shut:
                    continue
                if not (0 <= nx < MAPW and 0 <= ny < MAPH):
                    continue
                # Une serrure ne coupe pas la route : le groupe a des
                # cles. Seule la herse compte, c'est tout l'objet du
                # controle.
                if (grid[ny][nx] & 0x0f) in (WALL, NICHE, LEVER):
                    continue
                reach.add((nx, ny))
                q.append((nx, ny))
        for y in range(MAPH):
            for x in range(MAPW):
                if (grid[y][x] & 0x0f) != LEVER:
                    continue
                near = any((x + dx, y + dy) in reach
                           for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                assert near, f"levier inatteignable en {x},{y}"
    return len(seen), keys, stairs


def check_reachable(grid, start):
    """L'escalier doit etre atteignable : sinon le niveau est injouable."""
    import collections
    seen, q = {start}, collections.deque([start])
    stairs = None
    while q:
        x, y = q.popleft()
        if (grid[y][x] & 0x0f) == STAIRS:
            stairs = (x, y)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if (nx, ny) in seen or not (0 <= nx < MAPW and 0 <= ny < MAPH):
                continue
            if (grid[ny][nx] & 0x0f) in (WALL, NICHE):
                continue
            seen.add((nx, ny))
            q.append((nx, ny))
    assert stairs, "escalier inatteignable : niveau injouable"
    return len(seen), stairs


# --- sorties ------------------------------------------------------------
def write_palette(path):
    with open(path, "w") as f:
        f.write(";---------------------------------------------------------\n")
        f.write("; dgnpal.i - GENERE PAR tools/gen_dungeon.py\n")
        f.write(";---------------------------------------------------------\n\n")
        f.write("; 16 couleurs, deux mots chacune : quartets hauts puis bas.\n")
        f.write("DgnPalette:\n")
        for i, (r, g, b) in enumerate(PALETTE):
            hi = ((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4)
            lo = ((r & 15) << 8) | ((g & 15) << 4) | (b & 15)
            f.write(f"\tdc.w\t${hi:04x},${lo:04x}\t\t; couleur {i}\n")


def write_font8(path):
    import gen_data
    order = list(gen_data.GLYPHS)
    with open(path, "w") as f:
        f.write(";---------------------------------------------------------\n")
        f.write("; font8.i - GENERE PAR tools/gen_dungeon.py\n")
        f.write(";---------------------------------------------------------\n\n")
        f.write("; Police 8x8 : un octet par ligne, glyphe cale a gauche.\n")
        f.write("Font8:\n")
        for ch in order:
            rows = gen_data.GLYPHS[ch]
            vals = []
            for row in rows:
                bits = 0
                for x, c in enumerate(row):
                    if c == "#":
                        bits |= 0x80 >> (x + 1)
                vals.append(bits)
            vals.append(0)
            f.write("\tdc.b\t" + ",".join(f"${v:02x}" for v in vals)
                    + f"\t; '{ch}'\n")
        f.write("\n; ASCII 32..127 -> numero de glyphe, $ff si absent\n")
        f.write("Font8Map:\n")
        table = [order.index(chr(c).upper()) if chr(c).upper() in gen_data.GLYPHS
                 else 0xff for c in range(32, 128)]
        for i in range(0, 96, 16):
            f.write("\tdc.b\t" + ",".join(f"${v:02x}" for v in table[i:i + 16]) + "\n")
        return len(order)


if __name__ == "__main__":
    os.makedirs(os.path.join(ROOT, "data"), exist_ok=True)
    art, pieces = build_art()
    open(os.path.join(ROOT, "data", "dgnart.bin"), "wb").write(art)
    with open(os.path.join(ROOT, "src", "artidx.i"), "w") as f:
        f.write(";----------------------------------------------------------\n")
        f.write("; artidx.i - GENERE PAR tools/gen_dungeon.py\n")
        f.write("; Indices des morceaux de decor : ils bougent des qu'on en\n")
        f.write("; ajoute, d'ou leur generation plutot qu'une liste tenue a\n")
        f.write("; la main dans le source.\n")
        f.write(";----------------------------------------------------------\n\n")
        for k in ("ART_BG", "ART_FRONT", "ART_LEFT", "ART_RIGHT", "ART_DOOR",
                  "ART_MONSTER", "ART_FRONTL", "ART_FRONTR", "ART_OUTERL",
                  "ART_OUTERR", "ART_TITLE", "ART_GATE", "ART_LEVER",
                  "ART_NICHE",
                  "ART_PORTRAIT", "ART_ICON"):
            f.write(f"{k}\t= {ART_INDEX[k]}\n")
        f.write(f"NMONSTERART\t= {NMONSTERART}\n")
    maps, levels = build_maps()
    open(os.path.join(ROOT, "data", "dgnmap.bin"), "wb").write(maps)
    write_palette(os.path.join(ROOT, "src", "dgnpal.i"))
    n = write_font8(os.path.join(ROOT, "src", "font8.i"))
    print(f"dgnart.bin : {len(pieces)} morceaux, {len(art)} octets")
    for i, (grid, par, start, stairs) in enumerate(levels):
        reach, _ = check_reachable(grid, start)
        open_cells, keys, direct = check_solvable(grid, par, start)
        print(f"  niveau {i + 1} : depart {start}, escalier {stairs}, "
              f"{reach} cases ; sans forcer les serrures {open_cells} cases, "
              f"{keys} cles, escalier {'direct' if direct else 'derriere une porte'}")
    print(f"dgnmap.bin : {len(levels)} niveaux, {len(maps)} octets")
    print(f"font8.i    : {n} glyphes")
