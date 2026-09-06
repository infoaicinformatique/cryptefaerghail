#!/usr/bin/env python3
"""Verifie l'ecran d'accueil, la sauvegarde et la reprise de partie.

Le banc sert vraiment dos.library : les vecteurs Open, Read, Write et
Close aboutissent a des fichiers de l'hote. On peut donc sauver une
partie, relancer le jeu depuis zero et verifier qu'il retrouve le
groupe, le sac, la position et le releve de la carte.

    python3 tools/test_save.py
"""
import os
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SAVEDIR = "/tmp/aga-sauvegarde"
os.environ["AGA_SAVEDIR"] = SAVEDIR
sys.path.insert(0, os.path.join(ROOT, "tools"))
import test_game as T
import play_game as P

PHASE_TITLE, PHASE_CREATE, PHASE_PLAY = 2, 0, 1


def party(g):
    """L'etat qui doit survivre a une sauvegarde."""
    inv = g.addr("Inventory")
    seen = g.addr("MapSeen")
    return dict(
        heros=[(g.name(i), g.hero(i, "hr_Class"), g.hero(i, "hr_Hp"),
                g.hero(i, "hr_HpMax"), g.hero(i, "hr_Xp"),
                g.hero(i, "hr_Weapon")) for i in range(4)],
        sac=[g.mem.r8(inv + i) for i in range(24)],
        pos=(g.w("PosX"), g.w("PosY"), g.w("Dir")),
        niveau=g.w("Level"), or_=g.w("Gold"), cles=g.w("KeyCount"),
        vues=sum(g.mem.r8(seen + i) for i in range(576)),
        carte=[g.mem.r8(g.addr("MapTerrain") + i) for i in range(576)])


if __name__ == "__main__":
    fails = []
    shutil.rmtree(SAVEDIR, ignore_errors=True)
    os.makedirs(SAVEDIR)

    print("--- premiere partie ---")
    g = T.Game()
    if g.w("Phase") != PHASE_TITLE:
        fails.append(f"le jeu ne demarre pas sur l'accueil ({g.w('Phase')})")
    if g.w("HasSave"):
        fails.append("une sauvegarde est annoncee alors qu'il n'y en a pas")
    if not g.mem.r32(g.addr("DosBase")):
        fails.append("dos.library non ouverte")

    g.key(T.K_1)                          # 1 : nouvelle partie
    if g.w("Phase") != PHASE_CREATE:
        fails.append("la touche 1 n'ouvre pas la creation")
    T.create_party(g)
    if g.w("Phase") != PHASE_PLAY:
        fails.append("la creation n'aboutit pas")
    if not os.path.exists(os.path.join(SAVEDIR, "AGACrawl.sav")):
        fails.append("aucun fichier ecrit apres la creation")

    for _ in range(30):                   # on joue un peu
        grid = P.terrain(g)
        path = P.bfs(grid, (g.w("PosX"), g.w("PosY")),
                     lambda c: c & 0x30 in (0x10, 0x30))
        if not path or len(path) < 2:
            break
        if not P.step_to(g, path[1], []):
            break
        while g.w("InCombat") and not g.w("GameOver"):
            g.key(T.K_A)
    g.key(T.K_ESC)                        # deux ESC : on abandonne
    g.key(T.K_ESC)
    avant = party(g)
    taille = os.path.getsize(os.path.join(SAVEDIR, "AGACrawl.sav"))
    print(f"  sauvegarde de {taille} octets, position {avant['pos']}, "
          f"or {avant['or_']}, {avant['vues']} cases relevees")

    print("--- on relance le jeu ---")
    h = T.Game()
    if not h.w("HasSave"):
        fails.append("la sauvegarde n'est pas reconnue au demarrage")
    h.key(T.K_1 + 1)                      # 2 : reprendre
    if h.w("Phase") != PHASE_PLAY:
        fails.append(f"la reprise echoue (Phase {h.w('Phase')})")
    else:
        apres = party(h)
        for cle in ("heros", "sac", "pos", "niveau", "or_", "cles",
                    "vues", "carte"):
            if apres[cle] != avant[cle]:
                fails.append(f"{cle} n'est pas restaure")
        print(f"  reprise : {apres['pos']}, or {apres['or_']}, "
              f"{apres['vues']} cases relevees")
        for i in range(4):
            print(f"  {apres['heros'][i][0]:8s} PV {apres['heros'][i][2]}"
                  f"/{apres['heros'][i][3]} PX {apres['heros'][i][4]}")

    print("--- sauvegarde abimee ---")
    with open(os.path.join(SAVEDIR, "AGACrawl.sav"), "r+b") as f:
        f.write(b"XXXX")                  # on casse la signature
    k = T.Game()
    if k.w("HasSave"):
        fails.append("une sauvegarde illisible est acceptee")
    k.key(T.K_1 + 1)
    if k.w("Phase") != PHASE_TITLE:
        fails.append("le jeu quitte l'accueil sur une sauvegarde illisible")
    print("  refusee, le jeu reste sur l'accueil")

    print()
    if fails:
        print(f"{len(fails)} anomalie(s) :")
        for f in fails:
            print("  -", f)
        sys.exit(1)
    print("accueil, sauvegarde et reprise en ordre")
