#!/usr/bin/env python3
"""Rend un ecran du donjon en PNG, a partir des memes donnees que le jeu.

    python3 tools/dungeon_preview.py [niveau] [x] [y] [dir] [sortie] [monstre]

Le dernier argument, s'il est donne, remplace la vue par l'ecran de combat
correspondant (0 rat, 1 squelette, 2 orc, 3 dragonnet).

Rejoue l'algorithme d'affichage de src/crawl.s : fond, mur du fond, puis
murs lateraux du plus loin au plus proche, puis l'interface. Sert a
verifier la geometrie, les descripteurs de morceaux et la disposition de
l'ecran sans passer par un Amiga.

    python3 tools/dungeon_preview.py [niveau] [x] [y] [direction] [sortie.png]
"""
import os
import re
import struct
import sys
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import gen_dungeon as G

SCRW, SCRH, PLANES = 320, 256, 4
SCRBPL = 40
MAPW = MAPH = 24
DIRS = ((0, -1), (1, 0), (0, 1), (-1, 0))            # N, E, S, O

# morceaux, dans l'ordre ou build_art les empile
def art_index():
    """Les indices viennent de src/artidx.i, genere avec l'art."""
    idx = {}
    for line in open(os.path.join(ROOT, "src", "artidx.i")):
        m = re.match(r"(ART_\w+|NMONSTERART)\s*=\s*(\d+)", line)
        if m:
            idx[m.group(1)] = int(m.group(2))
    return idx


_A = art_index()
BG, FRONT, LEFT, RIGHT = _A["ART_BG"], _A["ART_FRONT"], _A["ART_LEFT"], _A["ART_RIGHT"]
DOOR, MONSTER = _A["ART_DOOR"], _A["ART_MONSTER"]
FRONTL, FRONTR = _A["ART_FRONTL"], _A["ART_FRONTR"]
OUTERL, OUTERR = _A["ART_OUTERL"], _A["ART_OUTERR"]
NICHE, PORTRAIT, ICON = _A["ART_NICHE"], _A["ART_PORTRAIT"], _A["ART_ICON"]


def load_art():
    raw = open(os.path.join(ROOT, "data", "dgnart.bin"), "rb").read()
    n = struct.unpack(">H", raw[:2])[0]
    pieces = []
    for i in range(n):
        off, w, h, dst, _ = struct.unpack(">IHHHH", raw[2 + i * 12:14 + i * 12])
        pieces.append((off, w, h, dst))
    return raw, pieces


def load_maps():
    raw = open(os.path.join(ROOT, "data", "dgnmap.bin"), "rb").read()
    step = 4 + MAPW * MAPH
    levels = []
    for lv in range(len(raw) // step):
        blk = raw[lv * step:(lv + 1) * step]
        levels.append((blk[0], blk[1], blk[2], blk[4:]))
    return levels


def blit(screen, raw, piece, masked=True):
    """Meme operation que le blitter : copie a travers un masque, sans decalage."""
    off, w, h, dst = piece
    plane_size = w * 2 * h
    for y in range(h):
        for wx in range(w):
            m = struct.unpack(">H", raw[off + (y * w + wx) * 2:][:2])[0]
            for p in range(PLANES):
                src = struct.unpack(
                    ">H", raw[off + (1 + p) * plane_size + (y * w + wx) * 2:][:2])[0]
                base = dst + y * SCRBPL + wx * 2
                for b in range(16):
                    bit = 0x8000 >> b
                    if masked and not (m & bit):
                        continue
                    sx = (base % SCRBPL) * 8 + b
                    sy = base // SCRBPL
                    if 0 <= sx < SCRW and 0 <= sy < SCRH:
                        if src & bit:
                            screen[sy][sx] |= 1 << p
                        else:
                            screen[sy][sx] &= ~(1 << p)


def cell(grid, x, y):
    if 0 <= x < MAPW and 0 <= y < MAPH:
        return grid[y * MAPW + x]
    return G.WALL


def solid(c):
    """Ce qui bouche la vue -- la meme liste que IsWall dans crawl.s.

    Elle ne comptait que le mur et la porte : une niche, un levier, une
    herse, l'echoppe et le grand registre etaient traverses comme du
    vide, et les captures de ce fichier montraient donc des couloirs qui
    n'existent pas dans le jeu."""
    return (c & 0x0f) in (G.WALL, G.DOOR, G.LOCKED, G.NICHE, G.RUNE,
                          G.LEVER, G.GATE, G.SHOP, G.LEDGER)


def cell_at(grid, px, py, dirn, depth, offset):
    dx, dy = DIRS[dirn]
    rx, ry = DIRS[(dirn + 1) & 3]
    return cell(grid, px + dx * depth + rx * offset, py + dy * depth + ry * offset)


def draw_view(screen, raw, pieces, grid, px, py, dirn):
    dx, dy = DIRS[dirn]
    blit(screen, raw, pieces[BG], masked=False)

    block = 0
    for k in range(1, 5):
        if solid(cell(grid, px + dx * k, py + dy * k)):
            block = k
            break
    if block:
        c = cell(grid, px + dx * block, py + dy * block)
        if (c & 0x0f) == G.DOOR and block <= 3:
            blit(screen, raw, pieces[DOOR + block - 1])
        else:
            blit(screen, raw, pieces[FRONT + block - 1])

    maxd = (block - 1) if block else 3
    for i in range(min(maxd, 3), -1, -1):            # du plus loin au plus pres
        for side, wall, front, outer in ((-1, LEFT, FRONTL, OUTERL),
                                         (1, RIGHT, FRONTR, OUTERR)):
            if solid(cell_at(grid, px, py, dirn, i, side)):
                blit(screen, raw, pieces[wall + i])
                continue
            # passage ouvert : on voit le fond du passage, puis son mur
            if solid(cell_at(grid, px, py, dirn, i + 1, side)):
                blit(screen, raw, pieces[front + i])
            if i >= 2 and solid(cell_at(grid, px, py, dirn, i, 2 * side)):
                blit(screen, raw, pieces[outer + i - 2])


# --- texte 8x8 ----------------------------------------------------------
def load_font():
    src = open(os.path.join(ROOT, "src", "font8.i")).read()
    body = src.split("Font8:", 1)[1].split("Font8Map:", 1)
    glyphs = []
    for line in body[0].splitlines():
        if "dc.b" in line:
            vals = line.split("dc.b")[1].split(";")[0]
            glyphs.append([int(v.strip().lstrip("$"), 16) for v in vals.split(",")])
    table = []
    for line in body[1].splitlines():
        if "dc.b" in line:
            vals = line.split("dc.b")[1].split(";")[0]
            table += [int(v.strip().lstrip("$"), 16) for v in vals.split(",")]
    return glyphs, table


GLYPHS, MAP8 = load_font()


def text(screen, xc, y, colour, s):
    for i, ch in enumerate(s.upper()):
        code = ord(ch)
        g = MAP8[code - 32] if 32 <= code < 128 else 0xff
        if g == 0xff:
            continue
        for row in range(8):
            bits = GLYPHS[g][row]
            for b in range(8):
                if bits & (0x80 >> b):
                    x = (xc + i) * 8 + b
                    if 0 <= x < SCRW and 0 <= y + row < SCRH:
                        screen[y + row][x] = colour


def frame(screen, x0, y0, x1, y1, colour):
    for x in range(x0, x1):
        screen[y0][x] = screen[y1 - 1][x] = colour
    for y in range(y0, y1):
        screen[y][x0] = screen[y][x1 - 1] = colour


PARTY = [("ALDER", 3, 26, 32, 0), ("MYRA", 2, 18, 22, 3),
         ("BORIN", 3, 30, 30, 1), ("SELVA", 2, 14, 24, 2)]


def draw_ui(screen, level, px, py, dirn, log, help_line):
    frame(screen, 8, 8, 216, 160, 6)
    frame(screen, 224, 8, 312, 160, 6)
    raw, pieces = load_art()
    for i, (name, lvl, hp, hpmax, cls) in enumerate(PARTY):
        y = 14 + i * 36
        off, w, h, _ = pieces[PORTRAIT + cls]
        blit(screen, raw, (off, w, h, y * SCRBPL + 28))
        text(screen, 32, y, 14 if i == 0 else 13, name)
        text(screen, 32, y + 10, 12 if hp * 2 >= hpmax else 15,
             f"PV {hp}/{hpmax}")
        text(screen, 32, y + 20, 9 if cls >= 2 else 2,
             f"PM {lvl}/6" if cls >= 2 else f"NIV {lvl}")
    frame(screen, 8, 164, 312, 252, 6)
    for i, line in enumerate(log):
        text(screen, 2, 172 + i * 12, 13 if i == len(log) - 1 else 2, line)
    text(screen, 2, 224, 14, f"NIVEAU {level + 1}   OR 166   POTIONS 3")
    text(screen, 2, 238, 4, help_line)


def write_png(path, screen):
    raw = bytearray()
    for line in screen:
        raw.append(0)
        for idx in line:
            raw += bytes(G.PALETTE[idx & 0xff])

    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", SCRW, SCRH, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    open(path, "wb").write(png)


if __name__ == "__main__":
    raw, pieces = load_art()
    levels = load_maps()
    lv = int(sys.argv[1]) if len(sys.argv) > 1 else 0
    sx, sy, sd, grid = levels[lv]
    px = int(sys.argv[2]) if len(sys.argv) > 2 else sx
    py = int(sys.argv[3]) if len(sys.argv) > 3 else sy
    dirn = int(sys.argv[4]) if len(sys.argv) > 4 else sd
    out = sys.argv[5] if len(sys.argv) > 5 else os.path.join(ROOT, "dungeon.png")

    monster = int(sys.argv[6]) if len(sys.argv) > 6 else None
    screen = [[0] * SCRW for _ in range(SCRH)]
    if monster is None:
        draw_view(screen, raw, pieces, grid, px, py, dirn)
        log = ["LES CAVES DE FAERGHAIL. BONNE CHANCE.",
               "UN COFFRE ! VOUS TROUVEZ 46 OR.",
               "ET UNE POTION DE SOIN.",
               "LA PORTE S'OUVRE EN GRINCANT."]
        help_line = "FLECHES  ESPACE OUVRIR  P BOIRE  ESC"
    else:
        blit(screen, raw, pieces[BG], masked=False)
        blit(screen, raw, pieces[MONSTER + monster * 2])
        log = ["UN ORC SURGIT !",
               "LE GROUPE INFLIGE 21 DEGATS.",
               "ORC TOUCHE MYRA : 6",
               "LE GROUPE INFLIGE 19 DEGATS."]
        help_line = "A ATTAQUER  F FUIR  P BOIRE  ESC"
    draw_ui(screen, lv, px, py, dirn, log, help_line)
    write_png(out, screen)
    print(f"niveau {lv + 1}, position {px},{py} direction {dirn} -> {out}")
