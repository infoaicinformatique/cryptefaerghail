#!/usr/bin/env python3
"""Modele Python du pipeline de src/scroll.s.

Deux roles :

1. verifier l'arithmetique du code 68k (disposition de la copperlist,
   adresses patchees a chaque image, calcul du scroll) ;
2. produire un apercu PNG d'une image, pour voir le resultat attendu
   sans passer par un emulateur.

    python3 tools/preview.py [numero_d_image] [sortie.png]

ATTENTION : ce script reproduit ce que le code assembleur *demande* au
chipset ; il ne remplace pas un test sur machine reelle ou emulateur.
"""
import os
import re
import struct
import sys
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# --- constantes, identiques a src/scroll.s -----------------------------
BMW, BMH, DEPTH = 640, 384, 8
BMWB = BMW // 8
PLSIZE = BMWB * BMH
SCRW, SCRH = 320, 256
FETCHWORDS = 21                      # DDFSTRT recule de 8 => un mot de plus
PALROT = 240
PALBANKSZ = 264
PANX_MIN, PANX_AMP, PANY_AMP = 16, 288, 128

BPLCON0, BPLCON1, BPLCON2, BPLCON3, BPLCON4 = 0x100, 0x102, 0x104, 0x106, 0x10c
BPL1MOD, BPL2MOD, BPL1PTH = 0x108, 0x10a, 0x0e0
DIWSTRT, DIWSTOP, DDFSTRT, DDFSTOP = 0x08e, 0x090, 0x092, 0x094
COLOR00, FMODE = 0x180, 0x1fc


def parse_bytes(path):
    out = []
    for line in open(path):
        m = re.match(r"\s*dc\.b\s+(.*)", line)
        if m:
            out += [int(v.strip().lstrip("$"), 16) for v in m.group(1).split(",")]
    return out


def parse_words(path):
    out = []
    for line in open(path):
        m = re.match(r"\s*dc\.w\s+([^;]*)", line)
        if m:
            out += [int(v.strip().lstrip("$"), 16) for v in m.group(1).split(",")]
    return out


SIN = parse_bytes(os.path.join(ROOT, "src", "sine.i"))
PAL = parse_words(os.path.join(ROOT, "src", "palette.i"))       # hi, lo, hi, lo...
SPR = parse_words(os.path.join(ROOT, "src", "sprite.i"))
assert len(SIN) == 256 and len(PAL) == 512


# --- 1. copperlist : on rejoue BuildCopperList ------------------------
def build_copper():
    """Retourne (mots, li_Pal, li_Ptrs, li_Con1) en octets, comme l'asm."""
    w = []                                   # liste de mots
    def move(reg, val):
        w.append(reg)
        w.append(val)

    for reg, val in ((FMODE, 0), (BPLCON0, 0x0211), (BPLCON2, 0x0024),
                     (BPLCON3, 0), (BPLCON4, 0x00ff), (DIWSTRT, 0x2c81),
                     (DIWSTOP, 0x2cc1), (DDFSTRT, 0x0030), (DDFSTOP, 0x00d0),
                     (BPL1MOD, BMWB - FETCHWORDS * 2), (BPL2MOD, BMWB - FETCHWORDS * 2)):
        move(reg, val)
    for s in range(8):                       # pointeurs de sprites
        move(0x120 + s * 4, 0)
        move(0x122 + s * 4, 0)

    li_pal = len(w) * 2
    for bank in range(8):
        move(BPLCON3, bank << 13)
        for i in range(32):
            move(COLOR00 + i * 2, 0)
        move(BPLCON3, (bank << 13) | 0x0200)
        for i in range(32):
            move(COLOR00 + i * 2, 0)
    move(BPLCON3, 0)

    li_ptrs = len(w) * 2
    for p in range(DEPTH):
        move(BPL1PTH + p * 4, 0)
        move(BPL1PTH + p * 4 + 2, 0)

    w.append(BPLCON1)
    li_con1 = len(w) * 2
    w.append(0)
    w += [0xffff, 0xfffe]
    return w, li_pal, li_ptrs, li_con1


def check_layout():
    w, li_pal, li_ptrs, li_con1 = build_copper()

    # UpdatePalette : hi en +6+4i, lo en +138+4i, banque tous les 264 octets
    for index in range(256):
        bank, i = index >> 5, index & 31
        off = bank * PALBANKSZ + i * 4
        hi = (li_pal + off + 6) // 2
        lo = (li_pal + off + 138) // 2
        assert w[hi - 1] == COLOR00 + i * 2, f"hi index {index}"
        assert w[lo - 1] == COLOR00 + i * 2, f"lo index {index}"
        assert w[(li_pal + bank * PALBANKSZ) // 2] == BPLCON3
        assert w[(li_pal + bank * PALBANKSZ) // 2 + 1] == bank << 13
        assert w[(li_pal + bank * PALBANKSZ + 132) // 2 + 1] == (bank << 13) | 0x0200

    # UpdateBitplanes : PTH en +2, PTL en +6, un plan tous les 8 octets
    for p in range(DEPTH):
        base = li_ptrs + p * 8
        assert w[(base + 2) // 2 - 1] == BPL1PTH + p * 4
        assert w[(base + 6) // 2 - 1] == BPL1PTH + p * 4 + 2
    assert w[li_con1 // 2 - 1] == BPLCON1
    assert len(w) * 2 <= 4096, "COPMAXSIZE depasse"
    print(f"copperlist : {len(w) * 2} octets, li_Pal={li_pal} li_Ptrs={li_ptrs} "
          f"li_Con1={li_con1} - disposition OK")


def check_camera():
    """Bornes du fetch et exactitude du scroll sur un cycle complet."""
    for frame in range(256):
        x, y = camera(frame)
        word, delay = (x - 1) >> 4, (-x) & 15
        assert PANX_MIN <= x <= BMW - SCRW - 16, f"X={x} hors bitmap (image {frame})"
        assert 0 <= y <= BMH - SCRH, f"Y={y} hors bitmap (image {frame})"
        assert 0 <= word * 2 and word * 2 + FETCHWORDS * 2 <= BMWB, \
            f"fetch hors ligne (image {frame})"
        # le pixel affiche en colonne 0 est word*16 + 16 - delai
        assert word * 16 + 16 - delay == x, f"scroll faux (image {frame})"
    print("camera et scroll : 256 images verifiees")


# --- 2. generation du playfield (meme formule + meme c2p que l'asm) ----
def generate_planes():
    planes = [bytearray(PLSIZE) for _ in range(DEPTH)]
    for y in range(BMH):
        line_term = SIN[(5 * y) & 255]
        xacc, diag = 0, (2 * y) & 0xffff
        row = bytearray(BMW)
        for x in range(BMW):
            c = SIN[xacc & 255] + line_term + SIN[diag & 255]
            row[x] = (c * 80) >> 8
            xacc += 3
            diag += 2
        base = y * BMWB
        for wx in range(BMW // 16):
            for p in range(DEPTH):
                acc = 0
                for i in range(16):
                    acc = (acc << 1) | ((row[wx * 16 + i] >> p) & 1)
                planes[p][base + wx * 2] = acc >> 8
                planes[p][base + wx * 2 + 1] = acc & 0xff
    return planes


# --- 3. camera et fetch DMA -------------------------------------------
def camera(frame):
    x = PANX_MIN + ((SIN[frame & 255] * PANX_AMP) >> 8)
    y = (SIN[((frame * 3) + 64) & 255] * PANY_AMP) >> 8
    return x, y


def render(planes, frame):
    x, y = camera(frame)
    word = (x - 1) >> 4                      # deplacement grossier
    delay = (-x) & 15                        # scroll fin via BPLCON1
    assert 0 <= word * 2 and word * 2 + FETCHWORDS * 2 <= BMWB, "fetch hors ligne"
    assert y + SCRH <= BMH, "camera hors bitmap"

    screen = [[0] * SCRW for _ in range(SCRH)]
    for l in range(SCRH):
        off = (y + l) * BMWB + word * 2
        fetched = [0] * (FETCHWORDS * 16)
        for p in range(DEPTH):
            for wi in range(FETCHWORDS):
                v = (planes[p][off + wi * 2] << 8) | planes[p][off + wi * 2 + 1]
                for i in range(16):
                    if v & (0x8000 >> i):
                        fetched[wi * 16 + i] |= 1 << p
        for s in range(SCRW):
            screen[l][s] = fetched[s + 16 - delay]

    # la colonne 0 doit montrer exactement le pixel X de l'image
    assert screen[0][0] == plasma_pixel(x, y), "scroll : mauvais pixel en colonne 0"

    # sprite (couleurs 241..243, banque $F via BPLCON4)
    sx = 152 + (((SIN[(frame * 2) & 255] - 128) * 7) >> 3)
    sy = 120 + (((SIN[((frame * 2) + 64) & 255] - 128) * 5) >> 3)
    for row in range(16):
        p0, p1 = SPR[row * 2], SPR[row * 2 + 1]
        for i in range(16):
            c = ((p0 >> (15 - i)) & 1) | (((p1 >> (15 - i)) & 1) << 1)
            if c and 0 <= sy + row < SCRH and 0 <= sx + i < SCRW:
                screen[sy + row][sx + i] = 240 + c
    return screen, x, y, delay


def plasma_pixel(x, y):
    c = SIN[(3 * x) & 255] + SIN[(5 * y) & 255] + SIN[(2 * (x + y)) & 255]
    return (c * 80) >> 8


# --- 4. sortie PNG -----------------------------------------------------
def colour(index, rot):
    src = index if index >= PALROT else (index + rot) % PALROT
    hi, lo = PAL[src * 2], PAL[src * 2 + 1]
    return tuple(((hi >> s) & 15) << 4 | ((lo >> s) & 15) for s in (8, 4, 0))


def write_png(path, screen, rot):
    raw = bytearray()
    for line in screen:
        raw.append(0)
        for idx in line:
            raw += bytes(colour(idx, rot))

    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", SCRW, SCRH, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    open(path, "wb").write(png)


if __name__ == "__main__":
    frame = int(sys.argv[1]) if len(sys.argv) > 1 else 40
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, "preview.png")
    check_layout()
    check_camera()
    planes = generate_planes()
    screen, x, y, delay = render(planes, frame)
    write_png(out, screen, frame % PALROT)
    print(f"image {frame} : camera X={x} Y={y}, scroll fin={delay} px "
          f"(mot {(x - 1) >> 4}) -> {out}")
