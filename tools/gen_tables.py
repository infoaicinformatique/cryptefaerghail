#!/usr/bin/env python3
"""Genere src/tables.i : objets, sorts, monstres, classes et noms.

Ecrire ces tables a la main en assembleur veut dire compter les octets de
bourrage de chaque nom ; autant les produire, avec la garantie que les
numeros d'objets correspondent a ceux que gen_dungeon.py seme dans les
niveaux.

    python3 tools/gen_tables.py
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "src", "tables.i")

W, A, SH, PO, SC, KE, TR = range(7)          # types d'objets
SFX_SWORD, SFX_AXE, SFX_BOW = 0, 1, 2

# nom, type, des/CA, faces, bonus, valeur, bruitage
ITEMS = [
    ("DAGUE",            W, 1, 4, 0, 2, SFX_SWORD),
    ("EPEE COURTE",      W, 1, 6, 0, 10, SFX_SWORD),
    ("EPEE LONGUE",      W, 1, 8, 0, 15, SFX_SWORD),
    ("HACHE",            W, 1, 8, 0, 12, SFX_AXE),
    ("HACHE DE GUERRE",  W, 1, 10, 0, 20, SFX_AXE),
    ("MASSE",            W, 1, 8, 0, 12, SFX_AXE),
    ("ARC COURT",        W, 1, 6, 0, 30, SFX_BOW),
    ("BATON",            W, 1, 6, 0, 5, SFX_SWORD),
    ("EPEE LONGUE +1",   W, 1, 8, 1, 100, SFX_SWORD),
    ("HACHE RUNIQUE +2", W, 1, 10, 2, 200, SFX_AXE),
    ("DAGUE DE FEU +1",  W, 2, 4, 1, 120, SFX_SWORD),
    ("ROBE",             A, 0, 0, 0, 5, 0),
    ("ARMURE DE CUIR",   A, 2, 0, 0, 20, 0),
    ("COTTE DE MAILLES", A, 5, 0, 0, 80, 0),
    ("HARNOIS",          A, 8, 0, 0, 300, 0),
    ("BOUCLIER",         SH, 2, 0, 0, 25, 0),
    ("POTION DE SOIN",   PO, 2, 4, 2, 25, 0),
    ("POTION MAJEURE",   PO, 3, 8, 3, 70, 0),
    ("PARCH. TRAIT",     SC, 0, 0, 0, 40, 0),
    ("PARCH. SOINS",     SC, 1, 0, 0, 40, 0),
    ("PARCH. BRULURE",   SC, 2, 0, 0, 60, 0),
    ("PARCH. ARMURE",    SC, 3, 0, 0, 60, 0),
    ("PARCH. EFFROI",    SC, 4, 0, 0, 80, 0),
    ("PARCH. ECLAIR",    SC, 5, 0, 0, 120, 0),
    ("CLE DE FER",       KE, 0, 0, 0, 10, 0),
    ("CLE D'ARGENT",     KE, 0, 0, 0, 25, 0),
    ("GEMME",            TR, 0, 0, 0, 120, 0),
    ("COURONNE",         TR, 0, 0, 0, 400, 0),
]

# nom, cout, genre (0 degats, 1 soin, 2 armure, 3 effroi), des, faces, bonus
SPELLS = [
    ("TRAIT MAGIQUE",   2, 0, 1, 4, 1),
    ("SOINS LEGERS",    2, 1, 1, 8, 1),
    ("MAINS BRULANTES", 3, 0, 2, 4, 0),
    ("ARMURE DE MAGE",  3, 2, 0, 0, 4),
    ("EFFROI",          4, 3, 0, 0, 0),
    ("ECLAIR",          6, 0, 3, 6, 0),
]

# nom, PV, CA, bonus d'attaque, des, faces, PX, or
MONSTERS = [
    ("RAT GEANT", 12, 12, 2, 1, 4, 12, 6),
    ("SQUELETTE", 20, 14, 3, 1, 6, 24, 15),
    ("ORC",       30, 15, 5, 1, 8, 38, 30),
    ("DRAGONNET", 48, 17, 7, 2, 6, 75, 95),
]

# nom, de de vie, magie de base, attaque rapide
CLASSES = [
    ("GUERRIER", 10, 0, 1),
    ("BARBARE", 12, 0, 1),
    ("ECLAIREUR", 8, 2, 0),
    ("CLERC", 8, 6, 0),
]

# arme, armure, bouclier, sorts connus (masque)
START_GEAR = [(3, 14, 16, 0), (4, 13, 0, 0), (7, 13, 0, 0), (6, 13, 0, 0b10)]

NAMES = ["ALDER", "MYRA", "BORIN", "SELVA", "THORGAL", "ELWIN", "KAREN",
         "DRAKE", "LYRA", "GORIM", "NESSA", "VALDIS", "ORRIN", "SIBYL",
         "HAKON", "MAEVE"]
NAMELEN = 9

AZERTY = {0x10: "AZERTYUIOP", 0x20: "QSDFGHJKLM", 0x31: "WXCVBN"}
QWERTY = {0x10: "QWERTYUIOP", 0x20: "ASDFGHJKL", 0x31: "ZXCVBNM"}


def pad(name, width):
    assert len(name) < width, f"{name} depasse {width - 1} caracteres"
    zeros = ",".join(["0"] * (width - len(name)))
    return f'\tdc.b\t"{name}",{zeros}\n'


def keymap(label, rows):
    table = [0] * 64
    for i in range(1, 10):
        table[i] = ord(str(i))
    table[0x0a] = ord("0")
    for base, letters in rows.items():
        for i, c in enumerate(letters):
            table[base + i] = ord(c)
    out = f"{label}:\n"
    for i in range(0, 64, 16):
        out += "\tdc.b\t" + ",".join(f"${v:02x}" for v in table[i:i + 16]) + "\n"
    return out


with open(OUT, "w") as f:
    f.write(";----------------------------------------------------------\n")
    f.write("; tables.i - GENERE PAR tools/gen_tables.py\n")
    f.write(";----------------------------------------------------------\n\n")

    f.write("; nom (18 octets), type, des, faces, bonus, valeur, bruitage\n")
    f.write("ItemTable:\n")
    for n, (name, typ, dice, faces, bonus, val, sfx) in enumerate(ITEMS, 1):
        f.write(f"\t; {n} {name}\n")
        f.write(pad(name, 18))
        f.write(f"\tdc.w\t{typ},{dice},{faces},{bonus},{val},{sfx}\n")

    f.write("\n; nom (20 octets), cout, genre, des, faces, bonus\n")
    f.write("SpellTable:\n")
    for name, cost, kind, dice, faces, plus in SPELLS:
        f.write(pad(name, 20))
        f.write(f"\tdc.w\t{cost},{kind},{dice},{faces},{plus}\n")

    f.write("\n; nom (12 octets), PV, CA, attaque, des, faces, PX, or\n")
    f.write("MonTypes:\n")
    for name, hp, ac, atk, dice, faces, xp, gold in MONSTERS:
        f.write(pad(name, 12))
        f.write(f"\tdc.w\t{hp},{ac},{atk},{dice},{faces},{xp},{gold}\n")

    f.write("\n; nom (12 octets), de de vie, magie, attaque rapide\n")
    f.write("ClassTable:\n")
    for name, hd, mp, fast in CLASSES:
        f.write(pad(name, 12))
        f.write(f"\tdc.w\t{hd},{mp},{fast}\n")

    f.write("\nStartGear:\t\t\t; arme, armure, bouclier, sorts\n")
    for w, a, sh, sp in START_GEAR:
        f.write(f"\tdc.w\t{w},{a},{sh},{sp}\n")

    f.write(f"\nNameList:\t\t\t; {NAMELEN} octets par nom\n")
    for name in NAMES:
        f.write(pad(name, NAMELEN))
    f.write(f"NNAMES\t\t= {len(NAMES)}\n")

    f.write("\n; Le CIA rend la position de la touche, pas le caractere.\n")
    f.write(keymap("KeyAzerty", AZERTY))
    f.write(keymap("KeyQwerty", QWERTY))

print(f"{OUT} : {len(ITEMS)} objets, {len(SPELLS)} sorts, "
      f"{len(MONSTERS)} monstres, {len(NAMES)} noms")
