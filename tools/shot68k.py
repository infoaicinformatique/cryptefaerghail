#!/usr/bin/env python3
"""Photographie l'ecran tel que le 68020 emule vient de le dessiner.

Le blitter n'est pas emule, donc les decors blittes manquent ; en
revanche tout ce que le processeur ecrit -- cadres, textes, listes --
apparait exactement ou il tombera sur l'Amiga. C'est ainsi qu'on
verifie qu'un menu deborde de son cadre.

    python3 tools/shot68k.py
"""
import os
import re
import sys
import zlib
import struct

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import test_game as T

def read_equ(name, default):
    """Une constante lue dans le source : le banc doit suivre le jeu
    quand il passe de quatre a huit bitplanes."""
    for line in open(os.path.join(ROOT, "src", "crawl.s")):
        m = re.match(r"%s\s*=\s*(\d+)" % name, line)
        if m:
            return int(m.group(1))
    return default


SCRW, SCRH, SCRBPL = 320, 256, 40
DEPTH = read_equ("DEPTH", 4)
PLANESIZE = SCRBPL * SCRH


def read_palette():
    """La palette du jeu, lue dans src/dgnpal.i : deux mots par couleur,
    quartets hauts puis quartets bas. La deviner menait a des captures
    aux couleurs fausses -- les portraits en particulier."""
    out = []
    for line in open(os.path.join(ROOT, "src", "dgnpal.i")):
        m = re.match(r"\s*dc\.w\s+\$([0-9a-f]{4}),\$([0-9a-f]{4})", line)
        if not m:
            continue
        hi, lo = int(m.group(1), 16), int(m.group(2), 16)
        out.append(tuple(((hi >> s) & 0xf) << 4 | ((lo >> s) & 0xf)
                         for s in (8, 4, 0)))
    assert len(out) >= 1 << DEPTH, f"{len(out)} couleurs pour "\
                                   f"{DEPTH} bitplanes"
    return out


PALETTE = read_palette()


def read_surf_gradient():
    """Le degrade que le copper ecrit ligne par ligne.

    Sans lui, une capture montrerait le sol et la voute dans les
    couleurs de repli de la palette : plates, et fausses. Le materiel
    reecrit ces douze registres toutes les SURF_LINES lignes ; on en
    fait ici une table indexee par ligne d'ecran."""
    src = open(os.path.join(ROOT, "src", "surfgrad.i")).read()

    def equ(name):
        m = re.search(r"^%s\s*=\s*(\d+)" % name, src, re.M)
        return int(m.group(1))

    blocks, lines, first = equ("SURF_BLOCKS"), equ("SURF_LINES"), equ("SURF_FIRST")
    rows = [[int(v.lstrip("$"), 16) for v in m.group(1).split(",")]
            for m in re.finditer(r"dc\.w\s+((?:\$[0-9a-f]{4},?)+)", src)]
    grad = {}
    for b in range(blocks):
        hi, lo = rows[2 * b], rows[2 * b + 1]
        cols = [tuple(((h >> sh) & 0xf) << 4 | ((l >> sh) & 0xf)
                      for sh in (8, 4, 0)) for h, l in zip(hi, lo)]
        for k in range(lines):
            grad[first + b * lines + k] = cols
    return grad


SURF = read_surf_gradient()
C_SURF = int(re.search(r"^C_SURF\s*=\s*(\d+)",
                       open(os.path.join(ROOT, "src", "dgncol.i")).read(),
                       re.M).group(1))
N_SURF = int(re.search(r"^N_SURF\s*=\s*(\d+)",
                       open(os.path.join(ROOT, "src", "dgncol.i")).read(),
                       re.M).group(1))


def copper_surf(g):
    """Le degrade tel qu'il est vraiment dans la copperlist du jeu.

    La table du fichier dit ce que le generateur a prevu ; celle-ci dit
    ce que le materiel lira, flamme comprise. Une capture doit montrer
    la seconde."""
    base = g.mem.r32(g.addr("CopSurf"))
    if not base:
        return SURF
    src = open(os.path.join(ROOT, "src", "surfgrad.i")).read()

    def equ(name):
        return int(re.search(r"^%s\s*=\s*(\d+)" % name, src, re.M).group(1))

    blocks, lines, first = equ("SURF_BLOCKS"), equ("SURF_LINES"), equ("SURF_FIRST")
    out, off = {}, 0
    for b in range(blocks):
        off += 8                                  # le WAIT et le BPLCON3
        hi = []
        for _ in range(N_SURF):
            off += 2
            hi.append(g.mem.r16(base + off))
            off += 2
        off += 4                                  # le BPLCON3 qui arme LOCT
        lo = []
        for _ in range(N_SURF):
            off += 2
            lo.append(g.mem.r16(base + off))
            off += 2
        cols = [tuple(((h >> sh) & 0xf) << 4 | ((l >> sh) & 0xf)
                      for sh in (8, 4, 0)) for h, l in zip(hi, lo)]
        for k in range(lines):
            out[first + b * lines + k] = cols
    return out


def colour(idx, y, surf=None):
    """La couleur d'un pixel, copper compris."""
    if C_SURF <= idx < C_SURF + N_SURF:
        cols = (surf or SURF).get(y)
        if cols:
            return cols[idx - C_SURF]
    return PALETTE[idx]


def grab(g, buf="ShowBuf"):
    base = g.mem.r32(g.addr(buf))
    raw = bytes(g.mem.r8(base + i) for i in range(PLANESIZE * DEPTH))
    px = bytearray(SCRW * SCRH)
    for p in range(DEPTH):
        off = p * PLANESIZE
        bit = 1 << p
        for y in range(SCRH):
            row = off + y * SCRBPL
            for xb in range(SCRBPL):
                v = raw[row + xb]
                if not v:
                    continue
                for b in range(8):
                    if v & (0x80 >> b):
                        px[y * SCRW + xb * 8 + b] |= bit
    return px


def png(path, px, surf=None):
    rows = b"".join(b"\0" + bytes(c for i in range(SCRW)
                                  for c in colour(px[y * SCRW + i], y, surf))
                    for y in range(SCRH))

    def chunk(tag, data):
        c = tag + data
        return struct.pack(">I", len(data)) + c + struct.pack(">I",
                                                              zlib.crc32(c))
    hdr = struct.pack(">IIBBBBB", SCRW, SCRH, 8, 2, 0, 0, 0)
    open(path, "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", hdr) +
                           chunk(b"IDAT", zlib.compress(rows, 9)) +
                           chunk(b"IEND", b""))


def shoot(g, name):
    out = os.path.join(ROOT, "docs", f"emu-{name}.png")
    png(out, grab(g, "ShowBuf"), copper_surf(g))
    print("  ", os.path.relpath(out, ROOT))


if __name__ == "__main__":
    g = T.Game()
    shoot(g, "titre")
    g.key(T.K_1 + 2)                      # 3 : le prologue
    shoot(g, "prologue")
    for _ in range(3):                    # jusqu'a la derniere page
        g.key(T.K_SPACE)
    shoot(g, "prologue-fin")
    g.key(T.K_ESC)                        # retour a l'accueil
    g.key(T.K_1)                          # 1 : commencer une partie
    shoot(g, "creation")
    g.key(T.K_1 + 6)                      # magicien : les jets s'affichent
    shoot(g, "creation-jets")
    g.key(T.K_RET); g.key(T.K_RET)        # garder les jets, garder le nom
    for c in (0, 5, 2):                   # guerrier, clerc, roublard
        g.key(T.K_1 + c); g.key(T.K_RET); g.key(T.K_RET)
    shoot(g, "vue")
    g.key(T.K_C)
    shoot(g, "fiche")
    g.key(T.K_C); g.key(T.K_I)
    shoot(g, "sac")
    g.key(T.K_I); g.key(T.K_S)
    shoot(g, "sorts")
    g.key(T.K_ESC)
    g.key(0x28)                           # L : le grimoire
    shoot(g, "grimoire")
    g.key(T.K_DOWN); g.key(T.K_DOWN)
    shoot(g, "grimoire2")
    g.key(0x28)
    g.key(0x19)                           # P : les reglages
    shoot(g, "reglages")
    g.key(0x19)
    import play_game as P                 # d'abord l'echoppe, puis un monstre
    grid = P.terrain(g)
    shops = P.find(grid, P.T_SHOP)
    if shops:
        sx, sy = shops[0]
        spot = next(((sx + dx, sy + dy) for dx, dy in P.DIRS
                     if 0 <= sx + dx < P.MAPW and 0 <= sy + dy < P.MAPH
                     and P.passable(grid[sy + dy][sx + dx])), None)
        def settle(gg):                   # un monstre en chemin se regle
            for _ in range(40):
                if not gg.w("InCombat") or gg.w("GameOver"):
                    break
                gg.key(T.K_A)

        if spot and P.goto(g, spot, on_combat=settle):
            P.face(g, P.DIRS.index((sx - spot[0], sy - spot[1])), [])
            g.setw("Gold", 260)           # de quoi que l'etal ait du sens
            g.setw("NeedRedraw", 1)
            shoot(g, "echoppe-vue")       # l'etal, vu du couloir
            g.key(T.K_SPACE)
            if g.w("UiMode") == 8:
                shoot(g, "echoppe")
                g.key(T.K_TAB)
                shoot(g, "echoppe-vente")
                g.key(T.K_ESC)
    while g.w("InCombat") and not g.w("GameOver"):
        g.key(T.K_A)
    grid = P.terrain(g)
    path = P.bfs(grid, (g.w("PosX"), g.w("PosY")),
                 lambda c: c & 0x30 == 0x20)
    if path:
        for cell in path[1:]:
            if not P.step_to(g, cell, []) or g.w("InCombat"):
                break
    shoot(g, "combat")
    g.key(T.K_S)
    shoot(g, "combat-sorts")
    g.key(T.K_ESC)
    while g.w("InCombat") and not g.w("GameOver"):
        g.key(T.K_A)
    for want in (lambda c: c & 0x30 == 0x30,          # explorer un peu
                 lambda c: c & 0x0f == 2,
                 lambda c: c & 0x30 == 0x10):
        path = P.bfs(P.terrain(g), (g.w("PosX"), g.w("PosY")), want)
        for cell in (path or [])[1:]:
            if not P.step_to(g, cell, []):
                break
            while g.w("InCombat") and not g.w("GameOver"):
                g.key(T.K_A)
    # Un couloir degage : c'est la que le degrade du copper se voit, le
    # sol et la voute occupant presque toute la vue.
    for _ in range(200):
        grid = P.terrain(g)
        dx, dy = P.DIRS[g.w("Dir")]
        x, y = g.w("PosX"), g.w("PosY")
        far = 0
        for k in range(1, 6):
            cx, cy = x + dx * k, y + dy * k
            if not (0 <= cx < P.MAPW and 0 <= cy < P.MAPH):
                break
            if not P.passable(grid[cy][cx]):
                break
            far = k
        if far >= 3:
            break
        g.key(T.K_RIGHT if g.w("Dir") % 2 else T.K_UP)
        while g.w("InCombat") and not g.w("GameOver"):
            g.key(T.K_A)
    shoot(g, "couloir")

    g.key(0x37)                           # M : la carte du niveau
    shoot(g, "carte")
    g.key(0x37)

    # Le greffe du dernier etage. Y arriver en jouant prendrait tout le
    # banc : on descend d'autorite, et on deblaie la traversee -- ce
    # qu'on veut photographier, c'est le pupitre et sa page.
    g.setw("GameOver", 0)
    g.setw("InCombat", 0)
    g.setw("UiMode", 0)
    for i in range(4):
        base = g.addr("Heroes") + i * T.HR["hr_SIZEOF"]
        g.mem.w16(base + T.HR["hr_Hp"], g.hero(i, "hr_HpMax"))
    g.setw("Level", 2)
    g.call(g.addr("LoadLevel"))
    g.setw("Acquitted", 0)
    ter = g.addr("MapTerrain")
    for y in range(P.MAPH):
        for x in range(P.MAPW):
            cell = g.mem.r8(ter + y * P.MAPW + x)
            if cell & 0x0f in (10, 8):        # dalles piegees et herses
                g.mem.w8(ter + y * P.MAPW + x, cell & 0xf0)
            elif cell & 0x30 == 0x20:
                g.mem.w8(ter + y * P.MAPW + x, cell & 0x0f)
    g.setw("NeedRedraw", 1)
    g.key(T.K_1)
    grid = P.terrain(g)
    seats = P.find(grid, 11)
    if seats:
        lx, ly = seats[0]
        spot = next(((lx + dx, ly + dy) for dx, dy in P.DIRS
                     if 0 <= lx + dx < P.MAPW and 0 <= ly + dy < P.MAPH
                     and P.passable(grid[ly + dy][lx + dx])), None)
        if spot and P.goto(g, spot):
            P.face(g, P.DIRS.index((lx - spot[0], ly - spot[1])), [])
            shoot(g, "greffe")            # le pupitre, vu du couloir
            g.key(T.K_SPACE)
            if g.w("UiMode") == 9:
                shoot(g, "registre")
                g.key(T.K_RET)            # la ligne rayee
                shoot(g, "registre-raye")
                g.key(T.K_ESC)
