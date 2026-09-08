#!/usr/bin/env python3
"""Rend les ecrans du jeu en PNG, a partir des vraies donnees.

Rejoue les mises en page de src/crawl.s (creation, vue, combat, fiche,
sac, sorts, enigme) avec les tables generees : c'est le seul moyen de
verifier la disposition sans lancer le jeu sur Amiga.

    python3 tools/screens.py [dossier]
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import dungeon_preview as D
import gen_dungeon as G

SCRW, SCRH, SCRBPL = 320, 256, 40


# --- lecture des tables generees --------------------------------------
def parse_table(label, name_len, nwords):
    src = open(os.path.join(ROOT, "src", "tables.i"),
               encoding="latin-1").read()
    body = src.split(label + ":", 1)[1]
    rows, name = [], None
    for line in body.splitlines():
        if re.match(r"^[A-Za-z_]+:", line) or line.startswith("N") and "=" in line:
            if rows and name is None:
                break
            if not line.startswith("\t") and rows:
                break
        m = re.search(r'dc\.b\s+"([^"]*)"', line)
        if m:
            name = m.group(1)
            continue
        m = re.search(r"dc\.w\s+([-\d,\s]+)", line)
        if m and name is not None:
            vals = [int(v) for v in m.group(1).split(",")]
            if len(vals) == nwords:
                rows.append((name, vals))
                name = None
    return rows


ITEMS = parse_table("ItemTable", 18, 8)
SPELLS = parse_table("SpellTable", 20, 9)
MONSTERS = parse_table("MonTypes", 16, 16)
CLASSES = parse_table("ClassTable", 12, 6)
RAW, PIECES = D.load_art()
LEVELS = D.load_maps()


def blank():
    return [[0] * SCRW for _ in range(SCRH)]


def chrome(screen, party, log, status, help_line, sel=0):
    """Encadrements, panneau du groupe, journal et barre d'etat."""
    D.frame(screen, 8, 8, 216, 160, 6)
    D.frame(screen, 224, 8, 312, 160, 6)
    for i, h in enumerate(party):
        y = 14 + i * 36
        if h is None:
            D.text(screen, 32, y, 5, "-----")
            continue
        name, cls, hp, hpmax, slots = h
        off, w, hgt, _ = PIECES[D.PORTRAIT + cls]
        D.blit(screen, RAW, (off, w, hgt, y * SCRBPL + 28))
        D.text(screen, 32, y, 14 if i == sel else 13, name)
        D.text(screen, 32, y + 10, 12 if hp * 2 >= hpmax else 15, f"PV {hp}/{hpmax}")
        D.text(screen, 32, y + 20, 9 if slots else 2,
               f"SORTS {slots}" if slots else f"NIV 1")
    D.frame(screen, 8, 164, 312, 252, 6)
    for i, line in enumerate(log):
        D.text(screen, 2, 172 + i * 12, 13 if i == len(log) - 1 else 2, line)
    D.text(screen, 2, 224, 14, status)
    D.text(screen, 2, 238, 4, help_line)


def view_pane(screen):
    D.blit(screen, RAW, PIECES[D.BG], masked=False)


PARTY = [("ALDER", 0, 11, 13, 0), ("MYRA", 6, 5, 6, 4),
         ("BORIN", 1, 15, 15, 0), ("SELVA", 5, 8, 9, 4)]
STATUS = "NIVEAU 1   OR 166   CLES 2"


def screen_creation_class(path):
    s = blank()
    for i, (name, vals) in enumerate(CLASSES[:4]):
        D.text(s, 3, 42 + i * 24, 13, f"{i + 1} - {name}")
    D.text(s, 3, 22, 14, "HEROS 1 SUR 4")
    desc = ["SOLIDE, FRAPPE FORT", "TRES ROBUSTE, PEU SUR",
            "DISCRET ET AGILE", "PISTEUR, ARC ET SORTS"]
    for i, d in enumerate(desc):
        D.text(s, 4, 54 + i * 24, 2, d)
    D.text(s, 3, 140, 12, "CHOISISSEZ : 1 A 4")
    chrome(s, [None] * 4, ["CREEZ VOS QUATRE AVENTURIERS.",
                           "CHAQUE CLASSE A SES FORCES.", "", ""],
           "CREATION DU GROUPE", "1-4 CLASSE  R DES  ENTREE OK  ESC")
    D.write_png(path, s)


def screen_creation_stats(path):
    s = blank()
    D.text(s, 3, 22, 14, "HEROS 2 SUR 4")
    D.text(s, 3, 38, 13, "MAGICIEN")
    stats = [("FOR", 9, -1), ("DEX", 15, 2), ("CON", 12, 1),
             ("INT", 17, 3), ("SAG", 13, 1), ("CHA", 10, 0)]
    for i, (n, v, m) in enumerate(stats):
        col = 3 if i % 2 == 0 else 14
        D.text(s, col, 52 + (i // 2) * 11, 2,
               f"{n} {v} {'+' if m >= 0 else '-'}{abs(m)}")
    D.text(s, 3, 90, 12, "PV 5")
    D.text(s, 3, 106, 13, "NOM : MYRA_")
    D.text(s, 3, 120, 2, "TAPEZ OU FLECHES")
    D.text(s, 3, 132, 4, "TAB : AZERTY")
    chrome(s, [PARTY[0], None, None, None],
           ["ALDER REJOINT LE GROUPE.", "4D6, ON GARDE LES TROIS MEILLEURS.",
            "R RELANCE LE JET.", ""],
           "CREATION DU GROUPE", "1-4 CLASSE  R DES  ENTREE OK  ESC", sel=1)
    D.write_png(path, s)


def screen_dungeon(path):
    s = blank()
    sx, sy, sd, grid = LEVELS[0]
    D.draw_view(s, RAW, PIECES, grid, 3, 1, 1)
    chrome(s, PARTY, ["ON NE SORT DE FAERGHAIL QU'ACQUITTE.",
                      "VOUS TROUVEZ COTTE DE MAILLES.",
                      "ALDER EQUIPE COTTE DE MAILLES.",
                      "UNE PORTE COUVERTE DE RUNES."],
           STATUS, "FLECHES  ESPACE  C FICHE  I SAC  ESC")
    D.write_png(path, s)


def screen_combat(path, monster_index, lines):
    s = blank()
    name, v = MONSTERS[monster_index]
    art = v[15]
    view_pane(s)
    D.blit(s, RAW, PIECES[D.MONSTER + art * 2 + 1])
    chrome(s, PARTY, lines, STATUS, "A ATTAQUER  S SORT  F FUIR  I SAC")
    D.write_png(path, s)
    return name, v


def screen_sheet(path):
    s = blank()
    D.text(s, 3, 20, 14, "ALDER GUERRIER")
    D.text(s, 3, 32, 13, "NIV 3  PX 1450  PV 26/31")
    stats = [("FOR", 17, 3), ("DEX", 13, 1), ("CON", 14, 2),
             ("INT", 10, 0), ("SAG", 12, 1), ("CHA", 11, 0)]
    for i, (n, val, m) in enumerate(stats):
        col = 3 if i % 2 == 0 else 14
        D.text(s, col, 48 + (i // 2) * 11, 2,
               f"{n} {val} {'+' if m >= 0 else '-'}{abs(m)}")
    D.text(s, 3, 88, 12, "CA 18   ATT +6")
    D.text(s, 3, 100, 1, "ARME: EPEE LONGUE +1")
    D.text(s, 3, 110, 1, "ARM: COTTE DE MAILLES")
    D.text(s, 3, 120, 12, "VIG/REF/VOL +5 +2 +2")
    D.text(s, 3, 130, 9, "SORTS : AUCUNE")
    chrome(s, PARTY, ["ALDER PASSE UN NIVEAU !", "UN TROLL TOMBE ! +375 PX, 55 OR.",
                      "VOUS TROUVEZ HACHE RUNIQUE +2.", "LA PORTE S'OUVRE EN GRINCANT."],
           STATUS, "1-4 HEROS  I SAC  C FERMER  ESC")
    D.write_png(path, s)


def screen_inventory(path):
    s = blank()
    D.text(s, 3, 20, 14, "SAC A DOS")
    bag = ["EPEE LONGUE +1", "HACHE RUNIQUE +2", "COTTE DE MAILLES",
           "BOUCLIER", "POTION DE SOIN", "PARCH. ECLAIR",
           "CLE DE FER", "GEMME"]
    icons = [0, 0, 1, 1, 2, 3, 4, 4]
    for i, (nm, ic) in enumerate(zip(bag, icons)):
        y = 34 + i * 11
        off, w, hgt, _ = PIECES[D.ICON + ic]
        D.blit(s, RAW, (off, w, hgt, (y - 2) * SCRBPL + 2))
        D.text(s, 5, y, 13 if i == 5 else 1, ("> " if i == 5 else "  ") + nm)
    chrome(s, PARTY, ["VOUS TROUVEZ PARCH. ECLAIR.",
                      "MYRA APPREND ECLAIR.", "", ""],
           STATUS, "E EQUIPER U UTILISER D JETER 1-4", sel=1)
    D.write_png(path, s)


def screen_spells(path):
    s = blank()
    D.text(s, 3, 20, 14, "QUEL SORT ?")
    known = [0, 2, 3]
    slots = {0: 4, 1: 3, 2: 2, 3: 1}
    for i, (name, v) in enumerate(SPELLS[:6]):
        lvl = v[0]
        col = 13 if i in known else 5
        if i in known and slots.get(lvl, 0) == 0:
            col = 4
        D.text(s, 3, 40 + i * 13, col, f"{i + 1} - {name} NIV {lvl}")
    chrome(s, PARTY, ["UN MINOTAURE SURGIT !",
                      "LE GROUPE INFLIGE 14 DEGATS.",
                      "MINOTAURE TOUCHE BORIN : 11",
                      "MYRA LANCE MAINS BRULANTES."],
           STATUS, "1-6 CHOISIR   ESC ANNULER", sel=1)
    D.write_png(path, s)


def screen_riddle(path):
    s = blank()
    D.text(s, 3, 20, 14, "LA PORTE VOUS PARLE")
    for i, line in enumerate(["JE PARLE SANS BOUCHE", "ET J'ENTENDS SANS",
                              "OREILLE. QUI SUIS-JE ?"]):
        D.text(s, 3, 38 + i * 11, 13, line)
    for i, a in enumerate(["L'ECHO", "LE VENT", "LA PIERRE"]):
        D.text(s, 3, 84 + i * 13, 12, f"{i + 1} - {a}")
    D.text(s, 3, 128, 14, "REPONDEZ : 1, 2 OU 3")
    chrome(s, PARTY, ["UNE PORTE COUVERTE DE RUNES.",
                      "LES RUNES SE METTENT A LUIRE.", "", ""],
           STATUS, "1 2 OU 3 POUR REPONDRE  ESC")
    D.write_png(path, s)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/screens"
    os.makedirs(out, exist_ok=True)
    screen_creation_class(f"{out}/01-creation-classe.png")
    screen_creation_stats(f"{out}/02-creation-jets.png")
    screen_dungeon(f"{out}/03-donjon.png")
    n, v = screen_combat(f"{out}/04-combat-troll.png", 20,
                         ["UN TROLL SURGIT !",
                          "LE GROUPE INFLIGE 17 DEGATS.",
                          "TROLL TOUCHE ALDER : 9",
                          "COUP CRITIQUE ! 22 DEGATS."])
    print(f"combat : {n} DV {v[0]}d{v[1]}+{v[2]}, CA {v[3]}, "
          f"attaque +{v[4]}, {v[5]}d{v[6]}+{v[7]}")
    screen_combat(f"{out}/05-combat-momie.png", 22,
                  ["UNE MOMIE SURGIT !", "MYRA LANCE ECLAIR.",
                   "IL ESQUIVE EN PARTIE !", "LE SORT INFLIGE 9 DEGATS."])
    screen_sheet(f"{out}/06-fiche.png")
    screen_inventory(f"{out}/07-sac.png")
    screen_spells(f"{out}/08-sorts.png")
    screen_riddle(f"{out}/09-enigme.png")
    print("ecrans rendus dans", out)
