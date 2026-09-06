#!/usr/bin/env python3
"""Photographie l'ecran tel que le 68020 emule vient de le dessiner.

Le blitter n'est pas emule, donc les decors blittes manquent ; en
revanche tout ce que le processeur ecrit -- cadres, textes, listes --
apparait exactement ou il tombera sur l'Amiga. C'est ainsi qu'on
verifie qu'un menu deborde de son cadre.

    python3 tools/shot68k.py
"""
import os
import sys
import zlib
import struct

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import test_game as T

SCRW, SCRH, SCRBPL, DEPTH = 320, 256, 40, 4
PLANESIZE = SCRBPL * SCRH
PALETTE = [(0, 0, 0), (150, 140, 120), (90, 80, 70), (200, 60, 40),
           (60, 60, 90), (110, 110, 130), (160, 120, 60), (70, 100, 70),
           (200, 180, 120), (120, 40, 40), (40, 80, 120), (180, 180, 190),
           (230, 200, 90), (245, 230, 170), (255, 220, 60), (255, 255, 255)]


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


def png(path, px):
    rows = b"".join(b"\0" + bytes(c for i in range(SCRW)
                                  for c in PALETTE[px[y * SCRW + i]])
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
    png(out, grab(g, "ShowBuf"))
    print("  ", os.path.relpath(out, ROOT))


if __name__ == "__main__":
    g = T.Game()
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
    import play_game as P                 # marcher jusqu'a un monstre
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
    g.key(0x37)                           # M : la carte du niveau
    shoot(g, "carte")
    g.key(0x37)
