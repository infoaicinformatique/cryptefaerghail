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
DEPTHS = 4

# --- palette 16 couleurs ------------------------------------------------
PALETTE = [
    (0x00, 0x00, 0x00),                  # 0  noir
    (0xc8, 0xc4, 0xb4),                  # 1  pierre, la plus claire
    (0xa8, 0xa4, 0x96),                  # 2
    (0x88, 0x84, 0x78),                  # 3
    (0x68, 0x64, 0x5c),                  # 4
    (0x48, 0x46, 0x40),                  # 5
    (0x2c, 0x2b, 0x28),                  # 6  pierre, la plus sombre
    (0x1a, 0x18, 0x16),                  # 7  joints
    (0x96, 0x60, 0x28),                  # 8  porte, clair
    (0x5c, 0x38, 0x14),                  # 9  porte, sombre
    (0x6e, 0x5c, 0x40),                  # 10 sol
    (0x3a, 0x30, 0x22),                  # 11 sol lointain
    (0x50, 0xc8, 0x5a),                  # 12 vert
    (0xff, 0xff, 0xff),                  # 13 blanc
    (0xf0, 0xc8, 0x3c),                  # 14 or
    (0xc8, 0x32, 0x28),                  # 15 rouge
]
STONE = [1, 2, 3, 4, 5, 6]


BRICK_W, BRICK_H = 0.25, 0.125           # taille d'un bloc, en cases


def shade(dist, side):
    """Niveau de gris : plus c'est loin, plus c'est sombre ; les murs
    lateraux sont un cran plus sombres que les murs de face."""
    level = (dist - 1.0) * 1.15 + (0.85 if side else 0.0)
    return max(0, min(len(STONE) - 1, int(level)))


def jitter(a, b):
    """Variation pseudo-aleatoire mais stable d'un bloc a l'autre."""
    h = (a * 73856093) ^ (b * 19349663)
    return ((h >> 7) & 3) - 1


def brick(u, v, dist, side):
    """Blocs de pierre : joints en creux, rangees decalees, aretes
    eclairees en haut et a l'ombre en bas."""
    row = int((v + 8.0) / BRICK_H)
    uu = u + (BRICK_W / 2 if row & 1 else 0.0)
    col = int((uu + 8.0) / BRICK_W)
    du = ((uu + 8.0) / BRICK_W) % 1.0
    dv = ((v + 8.0) / BRICK_H) % 1.0
    if du < 0.07 or dv < 0.12:
        return 7                                     # joint
    lvl = shade(dist, side) + jitter(col, row)
    if dv < 0.28:                                    # arete eclairee
        lvl -= 1
    elif dv > 0.82 or du > 0.93:                     # arete a l'ombre
        lvl += 1
    return STONE[max(0, min(len(STONE) - 1, lvl))]


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


def make_front(k, door=False, offset=0):
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
            if door and -0.22 < u < 0.22 and v > -0.30:
                p.set(x, y, door_pixel(u, v, k))
            else:
                p.set(x, y, brick(u, v, k, False))
    return p


def door_pixel(u, v, k):
    """Planches verticales, encadrement, poignee."""
    if abs(u) > 0.19 or v < -0.27:
        return 9 if (k > 2) else 6                   # encadrement
    if (int((u + 8.0) / 0.055) % 2) == 0:
        return 8 if k < 3 else 9
    if 0.10 < u < 0.16 and -0.02 < v < 0.06:
        return 14                                    # poignee
    return 9


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
    """Sol et plafond : bandes de plus en plus sombres avec la distance."""
    p = Piece(0, 0, VIEW_W, VIEW_H)
    for y in range(VIEW_H):
        dy = abs(y - CY)
        if dy < 1:
            idx = 0
        else:
            dist = F / dy                            # distance du sol vu en y
            if y > CY:
                idx = 10 if dist < 1.2 else (11 if dist < 2.4 else 6)
            else:
                idx = 5 if dist < 1.2 else (6 if dist < 2.4 else 7)
        for x in range(VIEW_W):
            p.set(x, y, idx)
    return p


# --- monstres -----------------------------------------------------------
def ellipse(p, cx, cy, rx, ry, idx):
    for y in range(int(cy - ry), int(cy + ry) + 1):
        for x in range(int(cx - rx), int(cx + rx) + 1):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                p.set(x, y, idx)


def make_monster(kind):
    """Silhouettes simples : 80x80, centrees dans la vue."""
    w = h = 80
    x0 = ((CX - w // 2) // 16) * 16
    p = Piece(x0, CY - h // 2 + 8, w, h)
    cx, cy = x0 + w // 2, CY - h // 2 + 8 + h // 2
    if kind == 0:                                    # rat geant
        ellipse(p, cx, cy + 12, 28, 16, 4)
        ellipse(p, cx, cy + 8, 22, 11, 3)
        ellipse(p, cx - 22, cy + 4, 12, 10, 4)       # tete
        ellipse(p, cx - 30, cy - 4, 5, 6, 5)         # oreille
        p.set(cx - 27, cy + 2, 15), p.set(cx - 26, cy + 2, 15)
        for t in range(30):                          # queue
            p.set(cx + 26 + t // 2, cy + 12 - t, 5)
    elif kind == 1:                                  # squelette
        ellipse(p, cx, cy - 22, 12, 14, 13)          # crane
        for e in (-5, 5):
            ellipse(p, cx + e, cy - 24, 3, 4, 0)
        ellipse(p, cx, cy + 8, 14, 20, 13)           # cage thoracique
        for r in range(-12, 14, 6):
            for x in range(cx - 13, cx + 14):
                p.set(x, cy + r, 6)
        for s in (-1, 1):                            # bras
            for t in range(24):
                p.set(cx + s * (14 + t // 3), cy - 8 + t, 13)
    elif kind == 2:                                  # orc
        ellipse(p, cx, cy + 12, 24, 24, 12)          # torse
        ellipse(p, cx, cy - 18, 15, 15, 12)          # tete
        for e in (-6, 6):
            ellipse(p, cx + e, cy - 20, 3, 3, 14)    # yeux
        for e in (-5, 5):
            p.set(cx + e, cy - 10, 13), p.set(cx + e, cy - 9, 13)
        for s in (-1, 1):                            # bras
            ellipse(p, cx + s * 26, cy + 8, 8, 18, 12)
        ellipse(p, cx + 30, cy - 10, 4, 16, 3)       # arme
    else:                                            # dragon
        ellipse(p, cx, cy + 14, 26, 20, 15)          # corps
        ellipse(p, cx, cy - 16, 18, 16, 15)          # tete
        for s in (-1, 1):                            # ailes
            ellipse(p, cx + s * 34, cy - 4, 16, 26, 9)
            ellipse(p, cx + s * 34, cy - 4, 12, 21, 15)
        for e in (-7, 7):
            ellipse(p, cx + e, cy - 20, 4, 4, 14)    # yeux
        for t in range(8):                           # crocs
            p.set(cx - 8 + 2 * t, cy - 4 + (t % 2), 13)
    return p


# --- encodage planaire --------------------------------------------------
def encode(piece):
    """Masque puis quatre plans, mots de 16 pixels."""
    wwords = piece.w // 16
    assert piece.w % 16 == 0, piece.w
    out = bytearray()
    for plane in range(-1, 4):                       # -1 = masque
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


def build_art():
    pieces = [make_background()]
    pieces += [make_front(k) for k in (1, 2, 3, 4)]              # 1..4
    pieces += [make_side(i, -0.5) for i in range(DEPTHS)]        # 5..8
    pieces += [make_side(i, 0.5) for i in range(DEPTHS)]         # 9..12
    pieces += [make_front(k, door=True) for k in (1, 2, 3)]      # 13..15
    pieces += [make_monster(k) for k in range(4)]                # 16..19
    # de quoi habiller les passages lateraux : la face du fond du passage
    # et son mur exterieur, sans quoi une ouverture n'est qu'un trou noir
    pieces += [make_front(k, offset=-1) for k in (1, 2, 3, 4)]   # 20..23
    pieces += [make_front(k, offset=1) for k in (1, 2, 3, 4)]    # 24..27
    pieces += [make_side(i, -1.5) for i in (2, 3)]               # 28..29
    pieces += [make_side(i, 1.5) for i in (2, 3)]                # 30..31

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
WALL, FLOOR, DOOR, STAIRS = 1, 0, 2, 3
CHEST, MONSTER = 0x10, 0x20                          # quartet haut


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
    grid, rnd = carve(level, seed)
    cells = floors(grid)
    start = (1, 1)
    far = max(cells, key=lambda c: abs(c[0] - start[0]) + abs(c[1] - start[1]))
    grid[far[1]][far[0]] = STAIRS

    free = [c for c in cells if c != start and c != far]
    rnd.shuffle(free)
    for x, y in free[:5 + level]:                    # coffres
        grid[y][x] |= CHEST
    for i, (x, y) in enumerate(free[6 + level:6 + level + 7 + 3 * level]):
        kind = min(3, (i + level) % 4)               # monstres postes
        grid[y][x] = (grid[y][x] & 0x0f) | MONSTER | (kind << 6)
    for x, y in free[-3 - level:]:                   # quelques portes
        if grid[y][x] == FLOOR:
            grid[y][x] = DOOR
    return grid, start, far


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
            if (grid[ny][nx] & 0x0f) == WALL:
                continue
            seen.add((nx, ny))
            q.append((nx, ny))
    assert stairs, "escalier inatteignable : niveau injouable"
    return len(seen), stairs


def build_maps():
    out = bytearray()
    levels = []
    for lv in range(3):
        grid, start, stairs = build_level(lv, 1000 + lv * 77)
        reach, _ = check_reachable(grid, start)
        levels.append((grid, start, stairs))
        out += bytes((start[0], start[1], 1, 0))     # depart : x, y, direction
        for y in range(MAPH):
            out += bytes(grid[y][x] for x in range(MAPW))
    return bytes(out), levels


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
    maps, levels = build_maps()
    open(os.path.join(ROOT, "data", "dgnmap.bin"), "wb").write(maps)
    write_palette(os.path.join(ROOT, "src", "dgnpal.i"))
    n = write_font8(os.path.join(ROOT, "src", "font8.i"))
    print(f"dgnart.bin : {len(pieces)} morceaux, {len(art)} octets")
    for i, (grid, start, stairs) in enumerate(levels):
        reach, _ = check_reachable(grid, start)
        print(f"  niveau {i + 1} : depart {start}, escalier {stairs}, "
              f"{reach} cases accessibles")
    print(f"dgnmap.bin : {len(levels)} niveaux, {len(maps)} octets")
    print(f"font8.i    : {n} glyphes")
