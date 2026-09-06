#!/usr/bin/env python3
"""Genere data/music.mod : un module ProTracker 4 voies, 31 instruments.

Tout est synthetise ici (samples et partition), donc le module est libre de
droits et le depot reste autonome. Le fichier genere est commite ; relancer
seulement pour changer la musique :

    python3 tools/gen_module.py
"""
import math
import os
import random
import struct

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "data", "music.mod")

# Table de periodes ProTracker, finetune 0, octaves 1 a 3.
NOTE_NAMES = ["C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"]
PERIODS = [
    856, 808, 762, 720, 678, 640, 604, 570, 538, 508, 480, 453,
    428, 404, 381, 360, 339, 320, 302, 285, 269, 254, 240, 226,
    214, 202, 190, 180, 170, 160, 151, 143, 135, 127, 120, 113,
]


def period(note):
    """'A-2' -> periode ProTracker."""
    octave = int(note[2])
    return PERIODS[(octave - 1) * 12 + NOTE_NAMES.index(note[:2])]


def clamp8(v):
    return max(-128, min(127, int(round(v))))


# ----------------------------------------------------------------------
# Synthese des samples (8 bits signes, longueur paire)
# ----------------------------------------------------------------------
def kick(n=1500):
    out = []
    for i in range(n):
        t = i / n
        freq = 150 * math.exp(-4.0 * t) + 35        # descente de hauteur
        env = math.exp(-5.0 * t)
        out.append(clamp8(120 * env * math.sin(2 * math.pi * freq * i / 8287)))
    return out


def snare(n=1800):
    rnd = random.Random(1)
    out = []
    for i in range(n):
        t = i / n
        env = math.exp(-6.0 * t)
        noise = rnd.uniform(-1, 1)
        tone = math.sin(2 * math.pi * 190 * i / 8287)
        out.append(clamp8(110 * env * (0.75 * noise + 0.35 * tone)))
    return out


def hihat(n=700):
    rnd = random.Random(2)
    out = []
    for i in range(n):
        env = math.exp(-16.0 * i / n)
        out.append(clamp8(95 * env * rnd.uniform(-1, 1)))
    return out


def wave(n, fn):
    """Une periode de forme d'onde, bouclee par le replayer."""
    return [clamp8(fn(i / n)) for i in range(n)]


def saw_bass():                                     # dent de scie adoucie
    return wave(128, lambda p: 110 * (2 * p - 1) * (1 - 0.35 * math.sin(math.pi * p)))


def pulse_lead():                                   # impulsion 25 %
    return wave(64, lambda p: 100 if p < 0.25 else -85)


def triangle_pad():
    return wave(128, lambda p: 90 * (4 * abs(p - 0.5) - 1))


# nom, donnees, volume, (repeat_start, repeat_len) en octets ; None = one-shot
INSTRUMENTS = [
    ("kick",  kick(),         64, None),
    ("snare", snare(),        64, None),
    ("hihat", hihat(),        42, None),
    ("bass",  saw_bass(),     64, (0, 128)),
    ("lead",  pulse_lead(),   50, (0, 64)),
    ("pad",   triangle_pad(), 34, (0, 128)),
]


# ----------------------------------------------------------------------
# Partition
# ----------------------------------------------------------------------
KICK, SNARE, HAT, BASS, LEAD, PAD = 1, 2, 3, 4, 5, 6

# Am - F - C - G, un accord tous les 16 pas
CHORDS = [
    ("A-1", ["A-2", "C-3", "E-3"]),
    ("F-1", ["F-2", "A-2", "C-3"]),
    ("C-1", ["C-2", "E-2", "G-2"]),
    ("G-1", ["G-1", "B-1", "D-2"]),
]

MELODY_A = [
    ["A-2", None, "C-3", None, "E-3", None, "D-3", None,
     "C-3", None, None, None, "B-2", None, None, None],
    ["A-2", None, "F-2", None, "A-2", None, "C-3", None,
     "F-3", None, None, None, "E-3", None, None, None],
    ["E-3", None, "G-2", None, "C-3", None, "E-3", None,
     "G-3", None, None, None, "E-3", None, None, None],
    ["D-3", None, "B-2", None, "G-2", None, "B-2", None,
     "D-3", None, "E-3", None, "D-3", None, "B-2", None],
]

MELODY_B = [
    ["E-3", None, "E-3", "D-3", "C-3", None, "A-2", None,
     "C-3", None, "E-3", None, "A-3", None, None, None],
    ["F-3", None, "E-3", None, "C-3", None, "A-2", None,
     "C-3", None, "F-3", None, "E-3", None, "C-3", None],
    ["G-3", None, "E-3", None, "C-3", None, "G-2", None,
     "C-3", None, "E-3", None, "G-3", None, None, None],
    ["B-2", None, "D-3", None, "G-3", None, "D-3", None,
     "B-2", None, "G-2", None, "D-2", None, "G-2", None],
]


def cell(note=None, instrument=0, effect=0, param=0):
    """Encode une case de pattern sur 4 octets."""
    per = period(note) if note else 0
    b0 = (instrument & 0xf0) | ((per >> 8) & 0x0f)
    b1 = per & 0xff
    b2 = ((instrument & 0x0f) << 4) | (effect & 0x0f)
    return bytes((b0, b1, b2, param & 0xff))


def build_pattern(melody, fill):
    rows = [[cell() for _ in range(4)] for _ in range(64)]
    for bar, (bass_note, chord) in enumerate(CHORDS):
        base = bar * 16
        for step in range(16):
            row = base + step

            # voie 1 : basse, une croche sur deux
            if step % 2 == 0:
                note = bass_note if step % 8 != 6 else chord[1]
                rows[row][0] = cell(note, BASS)

            # voie 2 : melodie
            note = melody[bar][step]
            if note:
                rows[row][1] = cell(note, LEAD)

            # voie 3 : arpege de l'accord
            if step % 4 == 0:
                rows[row][2] = cell(chord[(step // 4) % 3], PAD)

            # voie 4 : batterie
            if step in (0, 6, 8):
                rows[row][3] = cell("C-2", KICK)
            elif step in (4, 12):
                rows[row][3] = cell("C-2", SNARE)
            elif step % 2 == 1:
                rows[row][3] = cell("C-3", HAT)

        if fill and bar == 3:                        # petit fill en fin de phrase
            for step in (13, 14, 15):
                rows[base + step][3] = cell("C-2", SNARE)

    # vitesse au premier pas, volumes de depart
    rows[0][0] = cell(CHORDS[0][0], BASS, 0xF, 6)
    return rows


def pattern_bytes(rows):
    return b"".join(b"".join(row) for row in rows)


def sample_header(name, data, volume, loop):
    length = len(data) // 2                          # en mots
    if loop:
        rep_start, rep_len = loop[0] // 2, loop[1] // 2
    else:
        rep_start, rep_len = 0, 1                    # convention "pas de boucle"
    return (name.encode("ascii")[:22].ljust(22, b"\0")
            + struct.pack(">H", length)
            + bytes((0, volume))
            + struct.pack(">HH", rep_start, rep_len))


def build():
    patterns = [pattern_bytes(build_pattern(MELODY_A, False)),
                pattern_bytes(build_pattern(MELODY_B, True))]
    order = [0, 1, 0, 1]

    out = bytearray()
    out += b"AGA scroll tune".ljust(20, b"\0")

    samples = []
    for i in range(31):
        if i < len(INSTRUMENTS):
            name, data, volume, loop = INSTRUMENTS[i]
            data = list(data)
            if len(data) % 2:
                data.append(0)
            if loop is None:
                data[0] = data[1] = 0                # silence au point de boucle
            out += sample_header(name, data, volume, loop)
            samples.append(bytes((v & 0xff) for v in data))
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


if __name__ == "__main__":
    data = build()
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    open(OUT, "wb").write(data)
    print(f"{OUT} : {len(data)} octets, 2 patterns, "
          f"{sum(1 for i in INSTRUMENTS)} instruments")
