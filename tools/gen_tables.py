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
    ("DAGUE",            W, 1, 4, 0, 2, SFX_SWORD, 19, 2),
    ("EPEE COURTE",      W, 1, 6, 0, 10, SFX_SWORD, 19, 2),
    ("EPEE LONGUE",      W, 1, 8, 0, 15, SFX_SWORD, 19, 2),
    ("HACHE",            W, 1, 8, 0, 12, SFX_AXE, 20, 3),
    ("HACHE DE GUERRE",  W, 1, 12, 0, 20, SFX_AXE, 20, 3),
    ("MASSE",            W, 1, 8, 0, 12, SFX_AXE, 20, 2),
    ("ARC COURT",        W, 1, 6, 0, 30, SFX_BOW, 20, 3),
    ("BATON",            W, 1, 6, 0, 5, SFX_SWORD, 20, 2),
    ("EPEE LONGUE +1",   W, 1, 8, 1, 100, SFX_SWORD, 19, 2),
    ("HACHE RUNIQUE +2", W, 1, 12, 2, 200, SFX_AXE, 20, 3),
    ("DAGUE DE FEU +1",  W, 2, 4, 1, 120, SFX_SWORD, 19, 2),
    ("ROBE",             A, 0, 0, 0, 5, 0, 20, 2),
    ("ARMURE DE CUIR",   A, 2, 0, 0, 20, 0, 20, 2),
    ("COTTE DE MAILLES", A, 5, 0, 0, 80, 0, 20, 2),
    ("HARNOIS",          A, 8, 0, 0, 300, 0, 20, 2),
    ("BOUCLIER",         SH, 2, 0, 0, 25, 0, 20, 2),
    ("POTION DE SOIN",   PO, 2, 4, 2, 25, 0, 20, 2),
    ("POTION MAJEURE",   PO, 3, 8, 3, 70, 0, 20, 2),
    ("PARCH. TRAIT",     SC, 0, 0, 0, 40, 0, 20, 2),
    ("PARCH. SOINS",     SC, 1, 0, 0, 40, 0, 20, 2),
    ("PARCH. BRULURE",   SC, 2, 0, 0, 60, 0, 20, 2),
    ("PARCH. ARMURE",    SC, 3, 0, 0, 60, 0, 20, 2),
    ("PARCH. EFFROI",    SC, 4, 0, 0, 80, 0, 20, 2),
    ("PARCH. ECLAIR",    SC, 5, 0, 0, 120, 0, 20, 2),
    ("CLE DE FER",       KE, 0, 0, 0, 10, 0, 20, 2),
    ("CLE D'ARGENT",     KE, 0, 0, 0, 25, 0, 20, 2),
    ("GEMME",            TR, 0, 0, 0, 120, 0, 20, 2),
    ("COURONNE",         TR, 0, 0, 0, 400, 0, 20, 2),
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

# --- Bestiaire, d'apres le SRD 3.5 (Open Game License) ---------------
# Les creatures "Product Identity" (beholder, flagelleur mental, etc.) ne
# sont pas dans le SRD : elles ne figurent donc pas ici.
#
# Capacites particulieres, en champ de bits. Vingt-cinq creatures qui se
# battaient toutes de la meme facon -- un jet, des dagats -- ne valaient
# que par leurs nombres : une goule et un orc, c'etait le meme combat.
SP_POISON = 0x01                         # Vigueur, ou la force s'en va
SP_PARALYSE = 0x02                       # Vigueur, ou le heros perd un tour
SP_DRAIN = 0x04                          # Volonte, ou des PV pour de bon
SP_FEAR = 0x08                           # Volonte, ou il n'ose pas frapper
SP_REGEN = 0x10                          # la creature se referme
SP_DR = 0x20                             # sa peau encaisse les coups
SP_MULTI = 0x40                          # elle frappe deux fois

# nom, des de vie, faces, bonus PV, CA, attaque, des degats, faces, bonus
# degats, marge critique (19 = 19-20), multiplicateur, Vig, Ref, Vol, FP,
# or, silhouette (0 bete, 1 mort-vivant, 2 humanoide, 3 monstre aile),
# capacites
MONSTERS = [
    ("KOBOLD", 1, 8, 0, 15, 1, 1, 6, -1, 20, 2, 2, 2, 0, 0.25, 4, 2, 0),
    ("GOBELIN", 1, 8, 1, 15, 2, 1, 6, 0, 20, 2, 3, 1, -1, 0.33, 6, 2, 0),
    ("RAT SANGUIN", 1, 8, 1, 15, 4, 1, 4, 0, 20, 2, 3, 3, 3, 0.33, 0, 0, SP_POISON),
    ("SQUELETTE", 1, 12, 0, 15, 1, 1, 6, 1, 18, 2, 0, 1, 2, 0.33, 0, 1, 0),
    ("ORC", 1, 8, 1, 15, 4, 2, 4, 4, 18, 2, 3, 0, -2, 0.5, 10, 3, 0),
    ("HOBGOBELIN", 1, 8, 2, 15, 2, 1, 8, 1, 19, 2, 4, 1, -1, 0.5, 12, 2, 0),
    ("ZOMBI", 2, 12, 3, 11, 2, 1, 6, 1, 20, 2, 0, -1, 3, 0.5, 0, 1, SP_DR),
    ("LOUP", 2, 8, 4, 14, 3, 1, 6, 1, 20, 2, 5, 5, 1, 1.0, 0, 0, SP_MULTI),
    ("GNOLL", 2, 8, 2, 15, 3, 1, 8, 2, 20, 3, 4, 0, 0, 1.0, 14, 3, 0),
    ("GOULE", 2, 12, 0, 14, 2, 1, 6, 1, 20, 2, 0, 2, 5, 1.0, 0, 1, SP_PARALYSE),
    ("BUGBEAR", 3, 8, 3, 17, 5, 1, 8, 2, 20, 2, 4, 3, 1, 2.0, 22, 3, 0),
    ("WORG", 4, 10, 8, 14, 7, 1, 6, 4, 20, 2, 6, 6, 3, 2.0, 0, 0, SP_MULTI),
    ("OMBRE", 3, 12, 0, 13, 3, 1, 6, 0, 20, 2, 1, 3, 4, 3.0, 0, 5, SP_DRAIN),
    ("OGRE", 4, 8, 11, 16, 8, 2, 8, 7, 20, 2, 6, 0, 1, 3.0, 45, 4, 0),
    ("HOMME-LEZARD", 2, 8, 2, 15, 3, 1, 8, 1, 20, 2, 3, 3, 0, 1.0, 12, 3, 0),
    ("GARGOUILLE", 4, 8, 19, 16, 6, 1, 4, 2, 20, 2, 5, 6, 4, 4.0, 30, 7, SP_DR),
    ("OMBRE BLEME", 4, 12, 0, 15, 3, 1, 4, 1, 20, 2, 1, 2, 5, 3.0, 25, 5, SP_DRAIN | SP_FEAR),
    ("OURSALOUP", 5, 10, 25, 15, 9, 1, 6, 5, 20, 2, 9, 5, 2, 4.0, 0, 0, SP_MULTI),
    ("HARPIE", 7, 8, 0, 15, 7, 1, 6, 0, 20, 2, 2, 7, 6, 4.0, 40, 7, SP_FEAR),
    ("MINOTAURE", 6, 8, 12, 15, 9, 3, 6, 6, 20, 3, 6, 5, 5, 4.0, 60, 4, SP_MULTI),
    ("TROLL", 6, 8, 36, 16, 9, 1, 6, 6, 20, 2, 11, 4, 3, 5.0, 55, 4, SP_REGEN | SP_MULTI),
    ("SPECTRE", 7, 12, 0, 15, 6, 1, 8, 0, 20, 2, 2, 5, 7, 7.0, 70, 5, SP_DRAIN | SP_FEAR),
    ("MOMIE", 8, 12, 3, 20, 11, 1, 6, 10, 20, 2, 4, 2, 8, 5.0, 90, 6, SP_FEAR | SP_DR),
    ("HYDRE", 5, 10, 28, 15, 6, 1, 10, 3, 20, 2, 9, 5, 3, 5.0, 80, 8, SP_MULTI),
    ("GEANT COLLINE", 12, 8, 48, 17, 16, 2, 8, 10, 20, 2, 12, 3, 4, 7.0, 200, 4, 0),
    # Le gardien du dernier escalier. Ses nombres ne sont pas choisis au
    # jugé : tools/test_combat.py fait s'affronter un groupe de niveau
    # sept sans potion ni sort et exige qu'il l'emporte souvent, mais
    # pas toujours. Avec CA 22, 2d8+12 et une peau epaisse en plus de sa
    # regeneration, il gagnait dix-sept fois sur dix-huit.
    ("LE GARDIEN", 14, 12, 60, 18, 14, 1, 10, 6, 19, 3, 14, 8, 12, 12.0, 400, 5,
     SP_MULTI | SP_REGEN | SP_FEAR),
]

# Les rencontres, etage par etage : indices dans MONSTERS, ranges par
# facteur de puissance. Cette liste etait ecrite deux fois -- ici et
# dans gen_dungeon.py -- et rien ne garantissait qu'elles restent
# d'accord ; le generateur de donjons la lit maintenant d'ici.
#
#   1 : FP 0,25 a 0,5   2 : 0,5 a 1   3 : 1 a 3   4 : 3 a 5   5 : 5 a 7
TIERS = [
    [0, 1, 2, 3, 4, 5],
    [4, 5, 6, 7, 8, 9, 14],
    [7, 8, 9, 10, 11, 14, 12, 13],
    [12, 13, 16, 15, 17, 18, 19],
    [20, 22, 23, 21, 24, 15, 19],
]

# Ce que rapporte une victoire, selon le facteur de puissance (FP) :
# le SRD donne 300 x FP pour un groupe de niveau egal, divise par quatre
# aventuriers, ce qui tient dans un mot.
def monster_xp(cr):
    return max(5, int(300 * cr / 4))

# --- Classes du SRD 3.5 ----------------------------------------------
# nom, de de vie, progression d'attaque (0 complete, 1 trois quarts,
# 2 demie), sauvegardes fortes (Vig, Ref, Vol), lanceur (0 aucun,
# 1 profane sur l'Intelligence, 2 divin sur la Sagesse)
CLASSES = [
    ("GUERRIER",  10, 0, (1, 0, 0), 0),
    ("BARBARE",   12, 0, (1, 0, 0), 0),
    ("ROUBLARD",   6, 1, (0, 1, 0), 0),
    ("RODEUR",     8, 0, (1, 1, 0), 2),
    ("PALADIN",   10, 0, (1, 0, 1), 2),
    ("CLERC",      8, 1, (1, 0, 1), 2),
    ("MAGICIEN",   4, 2, (0, 0, 1), 1),
    ("ENSORCELEUR", 4, 2, (0, 0, 1), 1),
]

# arme, armure, bouclier, sorts connus (masque de 16 bits)
START_GEAR = [
    (3, 14, 16, 0),                      # guerrier : epee longue, cotte
    (4, 13, 0, 0),                       # barbare : hache, cuir
    (2, 13, 0, 0),                       # roublard : epee courte
    (7, 13, 0, 0),                       # rodeur : arc
    (3, 14, 16, 0b10),                   # paladin : soins legers
    (6, 13, 16, 0b1000010),              # clerc : soins + benediction
    (8, 12, 0, 0b1101),                  # magicien : givre, projectile, mains
    (8, 12, 0, 0b101),                   # ensorceleur : givre, projectile
]

# --- Sorts du SRD 3.5 -------------------------------------------------
# nom, niveau, effet (0 degats, 1 soin, 2 armure, 3 terreur, 4 benediction),
# des par niveau de lanceur, faces, bonus, plafond de des, jet de
# sauvegarde (0 aucun, 1 Vigueur, 2 Reflexes, 3 Volonte), moitie si
# sauvegarde reussie, ecole (1 profane, 2 divin, 3 les deux)
SPELLS = [
    ("RAYON DE GIVRE",   0, 0, 0, 3, 0, 1, 0, 0, 1),
    ("PROJECTILE MAGIQUE", 1, 0, 0, 4, 1, 5, 0, 0, 1),
    ("MAINS BRULANTES",  1, 0, 1, 4, 0, 5, 2, 1, 1),
    ("ARMURE DE MAGE",   1, 2, 0, 0, 4, 0, 0, 0, 1),
    ("SOINS LEGERS",     1, 1, 0, 8, 1, 5, 0, 0, 2),
    ("BENEDICTION",      1, 4, 0, 0, 1, 0, 0, 0, 2),
    ("TERREUR",          1, 3, 0, 0, 0, 0, 3, 0, 3),
    ("FLECHE ACIDE",     2, 0, 0, 4, 0, 2, 0, 0, 1),
    ("RAYON ARDENT",     2, 0, 0, 6, 0, 4, 0, 0, 1),
    ("SOINS MODERES",    2, 1, 0, 8, 1, 10, 0, 0, 2),
    ("IMMOBILISATION",   2, 3, 0, 0, 0, 0, 3, 0, 3),
    ("BOULE DE FEU",     3, 0, 1, 6, 0, 10, 2, 1, 1),
    ("ECLAIR",           3, 0, 1, 6, 0, 10, 2, 1, 1),
    ("SOINS IMPORTANTS", 3, 1, 0, 8, 1, 15, 0, 0, 2),
    ("FLEAU",            3, 0, 1, 8, 0, 5, 1, 1, 2),
    ("BOUCLIER DE FOI",  1, 2, 0, 0, 2, 0, 0, 0, 2),
]

# Emplacements de sorts par niveau de personnage (1 a 8), pour les
# niveaux de sort 0 a 3 : progression du SRD, memes valeurs pour les
# lanceurs profanes et divins.
SLOTS = [
    (3, 1, 0, 0), (4, 2, 0, 0), (4, 2, 1, 0), (4, 3, 2, 0),
    (4, 3, 2, 1), (4, 3, 3, 2), (4, 4, 3, 2), (4, 4, 3, 3),
]

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

    f.write("; nom (18), type, des, faces, bonus, valeur, bruitage,\n")
    f.write("; marge critique, multiplicateur\n")
    f.write("ItemTable:\n")
    for n, (name, typ, dice, faces, bonus, val, sfx, crit, mult) in enumerate(ITEMS, 1):
        f.write(f"\t; {n} {name}\n")
        f.write(pad(name, 18))
        f.write(f"\tdc.w\t{typ},{dice},{faces},{bonus},{val},{sfx},{crit},{mult}\n")

    f.write("\n; nom (20), niveau, effet, des/niveau, faces, bonus, plafond,\n")
    f.write("; sauvegarde, moitie si reussie, ecole\n")
    f.write("SpellTable:\n")
    for name, lvl, kind, dice, faces, plus, cap, save, half, school in SPELLS:
        f.write(pad(name, 20))
        f.write(f"\tdc.w\t{lvl},{kind},{dice},{faces},{plus},{cap},"
                f"{save},{half},{school}\n")
    f.write(f"NSPELLS\t\t= {len(SPELLS)}\n")

    f.write("\n; nom (16), des de vie, faces, bonus PV, CA, attaque, des,\n")
    f.write("; faces, bonus degats, marge critique, multiplicateur,\n")
    f.write("; Vigueur, Reflexes, Volonte, PX, or, silhouette,\n")
    f.write("; capacites particulieres\n")
    f.write("MonTypes:\n")
    for (name, hd, hdf, hpb, ac, atk, dice, faces, dmg, crit, mult,
         fort, ref, will, cr, gold, art, spec) in MONSTERS:
        f.write(pad(name, 16))
        f.write(f"\tdc.w\t{hd},{hdf},{hpb},{ac},{atk},{dice},{faces},{dmg},"
                f"{crit},{mult},{fort},{ref},{will},{monster_xp(cr)},"
                f"{gold},{art},{spec}\n")
    f.write(f"NMONSTERS\t= {len(MONSTERS)}\n")
    f.write(f"MON_BOSS\t= {len(MONSTERS) - 1}"
            f"\t; le gardien, au bout du dernier etage\n")

    f.write("\n; rencontres par niveau de donjon : numeros de monstres\n")
    for i, t in enumerate(TIERS):
        f.write(f"Encounter{i}:\n\tdc.b\t" + ",".join(str(v) for v in t) + "\n")
        f.write(f"\tdc.b\t{len(t)}\n\teven\n")
    f.write("EncounterTab:\n\tdc.l\t"
            + ",".join(f"Encounter{i}" for i in range(len(TIERS))) + "\n")
    f.write(f"NTIERS\t\t= {len(TIERS)}\n")

    f.write("\n; nom (12), de de vie, attaque, sauvegardes fortes, lanceur\n")
    f.write("ClassTable:\n")
    for name, hd, bab, saves, caster in CLASSES:
        f.write(pad(name, 12))
        f.write(f"\tdc.w\t{hd},{bab},{saves[0]},{saves[1]},{saves[2]},{caster}\n")
    f.write(f"NCLASSES\t= {len(CLASSES)}\n")

    f.write("\n; emplacements de sorts : niveaux 1 a 8, sorts de niveau 0 a 3\n")
    f.write("SlotTable:\n")
    for row in SLOTS:
        f.write("\tdc.w\t" + ",".join(str(v) for v in row) + "\n")

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
