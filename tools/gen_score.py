#!/usr/bin/env python3
"""Genere data/crawlmus.mod : la musique de La Crypte de Faerghail.

Un module ProTracker quatre voies, entierement synthetise ici -- samples
et partition -- donc libre de droits et reproductible. Le ton vise est
celui des musiques de donjon de l'epoque : cuivres tenus, choeur sombre,
timbales, en re mineur avec la sensible du mineur harmonique.

Repartition des voies, imposee par le jeu : la voie 4 est celle que
SfxPlay emprunte pour les bruitages, on n'y met donc que la percussion,
dont l'interruption s'entend le moins.

    voie 1  basse et bourdon
    voie 2  cor solo (le theme)
    voie 3  choeur et cordes (accords, arpeges)
    voie 4  timbales et cymbale   <- empruntee par les bruitages

Deux morceaux en sortent : celui du donjon, une marche, et celui de
l'ecran d'accueil, beaucoup plus lent et depouille -- on est devant le
portail, pas encore descendu.

    python3 tools/gen_score.py
"""
import math
import os
import random
import struct

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "data", "crawlmus.mod")
OUT_TITLE = os.path.join(ROOT, "data", "titlemus.mod")

NOTE_NAMES = ["C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#",
              "A-", "A#", "B-"]
PERIODS = [
    856, 808, 762, 720, 678, 640, 604, 570, 538, 508, 480, 453,
    428, 404, 381, 360, 339, 320, 302, 285, 269, 254, 240, 226,
    214, 202, 190, 180, 170, 160, 151, 143, 135, 127, 120, 113,
]


def period(note):
    octave = int(note[2])
    return PERIODS[(octave - 1) * 12 + NOTE_NAMES.index(note[:2])]


def clamp8(v):
    return max(-128, min(127, int(round(v))))


# ----------------------------------------------------------------------
# Samples. Les instruments tenus sont une seule periode d'onde, bouclee
# par le replayer ; les percussions sont des coups uniques.
# ----------------------------------------------------------------------
def cycle(n, fn):
    return [clamp8(fn(i / n)) for i in range(n)]


def additive(n, harmonics, gain=100.0):
    """Une periode faite d'une somme d'harmoniques (amplitude, phase)."""
    total = sum(abs(a) for a, _ in harmonics) or 1.0

    def fn(p):
        v = 0.0
        for k, (amp, phase) in enumerate(harmonics, start=1):
            v += amp * math.sin(2 * math.pi * (k * p + phase))
        return gain * v / total
    return cycle(n, fn)


def horn():
    """Cor : harmoniques paires et impaires, la troisieme en relief."""
    return additive(128, [(1.0, 0), (0.65, 0), (0.80, 0.1), (0.35, 0),
                          (0.28, 0.2), (0.16, 0), (0.10, 0), (0.06, 0)],
                    gain=104)


def choir():
    """Choeur : fondamentale forte, formant vers la cinquieme."""
    return additive(128, [(1.0, 0), (0.42, 0.25), (0.30, 0), (0.22, 0.5),
                          (0.34, 0), (0.12, 0), (0.07, 0.3)], gain=88)


def strings():
    """Cordes : dent de scie adoucie, un peu de corps."""
    return cycle(128, lambda p: 96 * ((2 * p - 1) * (1 - 0.30 * math.sin(math.pi * p))
                                      + 0.12 * math.sin(4 * math.pi * p)))


def drone():
    """Bourdon grave : sinus plus quinte discrete."""
    return additive(128, [(1.0, 0), (0.18, 0), (0.30, 0), (0.08, 0)],
                    gain=110)


def timpani(n=2400):
    """Timbale : hauteur qui descend vite, peau bruitee au depart."""
    rnd = random.Random(11)
    out = []
    for i in range(n):
        t = i / n
        freq = 105 * math.exp(-3.2 * t) + 52
        env = math.exp(-4.2 * t)
        skin = rnd.uniform(-1, 1) * math.exp(-40.0 * t)
        out.append(clamp8(118 * env * (math.sin(2 * math.pi * freq * i / 8287)
                                       + 0.30 * skin)))
    return out


def taiko(n=3200):
    """Grosse frappe, plus grave et plus longue que la timbale."""
    rnd = random.Random(12)
    out = []
    for i in range(n):
        t = i / n
        freq = 74 * math.exp(-2.4 * t) + 38
        env = math.exp(-3.0 * t)
        skin = rnd.uniform(-1, 1) * math.exp(-30.0 * t)
        out.append(clamp8(124 * env * (math.sin(2 * math.pi * freq * i / 8287)
                                       + 0.22 * skin)))
    return out


def cymbal(n=4000):
    """Cymbale : bruit filtre, longue extinction."""
    rnd = random.Random(13)
    prev = 0.0
    out = []
    for i in range(n):
        t = i / n
        env = math.exp(-3.6 * t)
        raw = rnd.uniform(-1, 1)
        prev = 0.55 * prev + 0.45 * raw          # un peu de passe-bas
        out.append(clamp8(96 * env * (raw - 0.5 * prev)))
    return out


def harp(n=2600):
    """Harpe : pincee claire qui s'eteint."""
    out = []
    for i in range(n):
        t = i / n
        env = math.exp(-4.5 * t)
        v = (math.sin(2 * math.pi * 220 * i / 8287)
             + 0.45 * math.sin(4 * math.pi * 220 * i / 8287)
             + 0.22 * math.sin(6 * math.pi * 220 * i / 8287))
        out.append(clamp8(78 * env * v))
    return out


# nom, donnees, volume, (depart, longueur) de boucle en octets
INSTRUMENTS = [
    ("timbale", timpani(),  64, None),
    ("taiko",   taiko(),    64, None),
    ("cymbale", cymbal(),   40, None),
    ("bourdon", drone(),    62, (0, 128)),
    ("cor",     horn(),     54, (0, 128)),
    ("choeur",  choir(),    38, (0, 128)),
    ("cordes",  strings(),  40, (0, 128)),
    ("harpe",   harp(),     48, None),
]
TIMB, TAIKO, CYM, DRONE, HORN, CHOIR, STR, HARP = 1, 2, 3, 4, 5, 6, 7, 8


# ----------------------------------------------------------------------
# Partition : re mineur, seize pas par mesure, quatre mesures par motif.
# ----------------------------------------------------------------------
# Chaque mesure : les trois notes de basse (registre grave) puis les
# trois notes de l'accord pour le choeur et les cordes.
# Refrain heroique : i - VI - III - VII
SECTION_A = [
    (["D-1", "A-1", "F-1"], ["D-2", "F-2", "A-2"]),
    (["A#1", "F-1", "D-1"], ["A#2", "D-3", "F-3"]),
    (["F-1", "C-2", "A-1"], ["F-2", "A-2", "C-3"]),
    (["C-1", "G-1", "E-1"], ["C-2", "E-2", "G-2"]),
]
# Pont plus sombre : i - VII - VI - V, avec la sensible du mineur
# harmonique (do diese) qui ramene vers re
SECTION_B = [
    (["D-1", "A-1", "F-1"], ["D-2", "F-2", "A-2"]),
    (["C-1", "G-1", "E-1"], ["C-2", "E-2", "G-2"]),
    (["A#1", "F-1", "D-1"], ["A#2", "D-3", "F-3"]),
    (["A-1", "E-1", "C#1"], ["A-2", "C#3", "E-3"]),
]

# Le theme au cor. Un point = on tient la note precedente.
THEME_A = [
    ["D-2", None, None, None, None, None, "F-2", None,
     "A-2", None, None, None, "D-3", None, None, None],
    ["C-3", None, None, None, "A#2", None, None, None,
     "A-2", None, None, None, "F-2", None, None, None],
    ["A-2", None, None, None, "C-3", None, None, None,
     "F-3", None, None, None, None, None, "E-3", None],
    ["D-3", None, None, None, "C-3", None, None, None,
     "A-2", None, None, None, "G-2", None, None, None],
]
THEME_A2 = [
    ["A-2", None, None, None, "D-3", None, None, None,
     "F-3", None, "E-3", None, "D-3", None, None, None],
    ["F-3", None, None, None, "D-3", None, None, None,
     "C-3", None, None, None, "A#2", None, None, None],
    ["C-3", None, None, None, "F-3", None, None, None,
     "A-3", None, None, None, "G-3", None, "F-3", None],
    ["E-3", None, None, None, "D-3", None, None, None,
     "C-3", None, "A-2", None, "G-2", None, None, None],
]
THEME_B = [
    ["A-3", None, None, None, None, None, "G-3", None,
     "F-3", None, None, None, "E-3", None, None, None],
    ["E-3", None, None, None, "D-3", None, None, None,
     "C-3", None, None, None, None, None, None, None],
    ["D-3", None, None, None, "C-3", None, None, None,
     "A#2", None, None, None, "A-2", None, None, None],
    ["A-2", None, None, None, "C#3", None, None, None,
     "E-3", None, None, None, "A-3", None, None, None],
]
THEME_B2 = [
    ["D-3", None, "E-3", None, "F-3", None, "G-3", None,
     "A-3", None, None, None, None, None, "G-3", None],
    ["F-3", None, None, None, "E-3", None, None, None,
     "D-3", None, "C-3", None, "A#2", None, None, None],
    ["D-3", None, None, None, "F-3", None, None, None,
     "A-3", None, None, None, "F-3", None, "D-3", None],
    ["C#3", None, None, None, "E-3", None, None, None,
     "A-2", None, None, None, None, None, None, None],
]


def cell(note=None, instrument=0, effect=0, param=0):
    per = period(note) if note else 0
    b0 = (instrument & 0xf0) | ((per >> 8) & 0x0f)
    b1 = per & 0xff
    b2 = ((instrument & 0x0f) << 4) | (effect & 0x0f)
    return bytes((b0, b1, b2, param & 0xff))


def build_pattern(section, theme, *, opening=False, roll=False, plucks=False):
    rows = [[cell() for _ in range(4)] for _ in range(64)]
    for bar, (bass, chord) in enumerate(section):
        base = bar * 16
        for step in range(16):
            row = base + step

            # voie 1 : la basse, refrappee au debut de la mesure, a
            # mi-mesure, puis une note d'approche avant la suivante
            if step == 0:
                rows[row][0] = cell(bass[0], DRONE)
            elif step == 8:
                rows[row][0] = cell(bass[1], DRONE)
            elif step == 14:
                rows[row][0] = cell(bass[2], DRONE)

            # voie 2 : le cor
            note = theme[bar][step]
            if note:
                rows[row][1] = cell(note, HORN)

            # voie 3 : choeur en accords tenus, cordes en arpege
            if step == 0:
                rows[row][2] = cell(chord[0], CHOIR)
            elif step == 4:
                rows[row][2] = cell(chord[1], STR)
            elif step == 10:
                rows[row][2] = cell(chord[2], STR)
            elif plucks and step in (7, 13):
                rows[row][2] = cell(chord[2], HARP)

            # voie 4 : percussion seule -- les bruitages empruntent
            # cette voie et ne doivent pas couper une note tenue
            if step == 0:
                rows[row][3] = cell("C-2", TAIKO)
            elif step == 8:
                rows[row][3] = cell("C-2", TIMB)
            elif step in (6, 11):
                rows[row][3] = cell("G-1", TIMB)

        if roll and bar == 3:                     # roulement de fin de phrase
            for k, step in enumerate((12, 13, 14, 15)):
                rows[base + step][3] = cell("G-1" if k % 2 else "C-2", TIMB)

    if opening:
        rows[0][3] = cell("C-2", CYM)             # coup de cymbale d'entree
    rows[0][0] = cell(section[0][0][0], DRONE, 0xF, 8)   # tempo : large
    return rows


def pattern_bytes(rows):
    return b"".join(b"".join(row) for row in rows)


def sample_header(name, data, volume, loop):
    length = len(data) // 2
    rep_start, rep_len = (loop[0] // 2, loop[1] // 2) if loop else (0, 1)
    return (name.encode("ascii")[:22].ljust(22, b"\0")
            + struct.pack(">H", length)
            + bytes((0, volume))
            + struct.pack(">HH", rep_start, rep_len))


# --- l'accueil : lent, large, presque immobile -----------------------
# Meme monde tonal que le donjon, mais quatre fois moins de notes et un
# tempo de procession : le portail attend, il ne presse personne.
TITLE_SECTIONS = [
    [(["D-1", "A-1", "F-1"], ["D-2", "F-2", "A-2"]),
     (["D-1", "F-1", "A-1"], ["D-2", "F-2", "A-2"]),
     (["A#1", "F-1", "D-1"], ["A#2", "D-3", "F-3"]),
     (["A-1", "E-1", "C#1"], ["A-2", "C#3", "E-3"])],
    [(["D-1", "A-1", "F-1"], ["D-2", "F-2", "A-2"]),
     (["F-1", "C-2", "A-1"], ["F-2", "A-2", "C-3"]),
     (["A#1", "F-1", "D-1"], ["A#2", "D-3", "F-3"]),
     (["A-1", "E-1", "C#1"], ["A-2", "C#3", "E-3"])],
]
TITLE_THEMES = [
    [["D-2", None, None, None, None, None, None, None,
      "A-2", None, None, None, None, None, None, None],
     ["F-2", None, None, None, None, None, "E-2", None,
      None, None, "D-2", None, None, None, None, None],
     ["D-3", None, None, None, None, None, None, None,
      "C-3", None, None, None, "A#2", None, None, None],
     ["A-2", None, None, None, None, None, None, None,
      "C#3", None, None, None, None, None, None, None]],
    [["A-2", None, None, None, None, None, "D-3", None,
      None, None, None, None, None, None, None, None],
     ["C-3", None, None, None, None, None, None, None,
      "A-2", None, None, None, None, "F-2", None, None],
     ["D-3", None, None, None, None, None, "F-3", None,
      None, None, None, None, "E-3", None, None, None],
     ["E-3", None, None, None, None, None, None, None,
      "C#3", None, None, None, None, "A-2", None, None]],
]


def build_title_pattern(section, theme, opening=False):
    """Un motif d'accueil : une note tenue par voie et par demi-mesure,
    et la percussion reduite a une frappe sourde en tete de phrase."""
    rows = [[cell() for _ in range(4)] for _ in range(64)]
    for bar, (bass, chord) in enumerate(section):
        base = bar * 16
        for step in range(16):
            row = base + step
            if step == 0:                        # basse : la fondamentale
                rows[row][0] = cell(bass[0], DRONE)
            elif step == 10:                     # puis une note d'appui
                rows[row][0] = cell(bass[1], DRONE)

            note = theme[bar][step]
            if note:
                rows[row][1] = cell(note, HORN)

            if step == 0:                        # choeur tenu
                rows[row][2] = cell(chord[0], CHOIR)
            elif step == 8:                      # cordes a mi-mesure
                rows[row][2] = cell(chord[2], STR)
            elif step == 13 and bar % 2 == 1:
                rows[row][2] = cell(chord[1], HARP)

            if step == 0 and bar % 2 == 0:       # une frappe par phrase
                rows[row][3] = cell("C-2", TAIKO)
    if opening:
        rows[0][3] = cell("C-2", CYM)
    rows[0][0] = cell(section[0][0][0], DRONE, 0xF, 12)  # tres lent
    return rows


def assemble(title, patterns, order):
    """Entete, entetes de samples, ordre, puis motifs et echantillons."""
    out = bytearray()
    out += title.encode("ascii")[:20].ljust(20, b"\0")
    samples = []
    for i in range(31):
        if i < len(INSTRUMENTS):
            name, data, volume, loop = INSTRUMENTS[i]
            data = list(data)
            if len(data) % 2:
                data.append(0)
            if loop is None:
                data[0] = data[1] = 0            # silence au point de boucle
            out += sample_header(name, data, volume, loop)
            samples.append(bytes(v & 0xff for v in data))
        else:
            out += sample_header("", [], 0, None)
            samples.append(b"")
    out += bytes((len(order), 127))
    out += bytes(order).ljust(128, b"\0")
    out += b"M.K."
    for p in patterns:
        out += p
    for s in samples:
        out += s
    return bytes(out)


def build_title():
    patterns = [
        pattern_bytes(build_title_pattern(TITLE_SECTIONS[0], TITLE_THEMES[0],
                                          opening=True)),
        pattern_bytes(build_title_pattern(TITLE_SECTIONS[1], TITLE_THEMES[1])),
    ]
    return assemble("Le portail", patterns, [0, 1])


def build():
    patterns = [
        pattern_bytes(build_pattern(SECTION_A, THEME_A, opening=True)),
        pattern_bytes(build_pattern(SECTION_A, THEME_A2, plucks=True)),
        pattern_bytes(build_pattern(SECTION_B, THEME_B)),
        pattern_bytes(build_pattern(SECTION_B, THEME_B2, roll=True,
                                    plucks=True)),
    ]
    return assemble("Crypte de Faerghail", patterns, [0, 1, 2, 3, 0, 1, 3, 2])


if __name__ == "__main__":
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    data = build()
    open(OUT, "wb").write(data)
    print(f"{OUT} : {len(data)} octets, 4 motifs, "
          f"{len(INSTRUMENTS)} instruments, 8 positions")
    data = build_title()
    open(OUT_TITLE, "wb").write(data)
    print(f"{OUT_TITLE} : {len(data)} octets, 2 motifs, "
          f"{len(INSTRUMENTS)} instruments, 2 positions")
