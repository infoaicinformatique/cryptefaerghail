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
                g.hero(i, "hr_Weapon")) for i in range(T.NH)],
        sac=[g.mem.r8(inv + i) for i in range(24)],
        pos=(g.w("PosX"), g.w("PosY"), g.w("Dir")),
        niveau=g.w("Level"), or_=g.w("Gold"), cles=g.w("KeyCount"),
        vues=sum(g.mem.r8(seen + i) for i in range(576)),
        carte=[g.mem.r8(g.addr("MapTerrain") + i) for i in range(576)],
        param=[g.mem.r8(g.addr("MapParam") + i) for i in range(576)],
        etal=[g.mem.r8(g.addr("ShopStock") + i) for i in range(8)],
        quittance=g.w("Acquitted"),
        reglages=(g.w("OptMusic"), g.w("OptSfx"), g.w("KbLayout")))


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
    stock = g.addr("ShopStock")           # une piece vendue doit le rester
    g.mem.w8(stock + 0, 0)
    g.mem.w8(stock + 3, 0)
    g.setw("OptMusic", 0)                 # les reglages aussi se sauvent :
    g.setw("KbLayout", 1)                 # on coupe la musique et on passe
    g.setw("Acquitted", 1)                # en QWERTY, et on raye la ligne
    g.key(T.K_ESC)                        # deux ESC : on abandonne
    g.key(T.K_ESC)
    avant = party(g)
    if avant["etal"].count(0) < 2:
        fails.append("l'etal vide ne part pas dans la sauvegarde")
    taille = os.path.getsize(os.path.join(SAVEDIR, "AGACrawl.sav"))
    print(f"  sauvegarde de {taille} octets, position {avant['pos']}, "
          f"or {avant['or_']}, {avant['vues']} cases relevees, "
          f"etal {8 - avant['etal'].count(0)}/8")

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
                    "vues", "carte", "param", "etal", "quittance",
                    "reglages"):
            if apres[cle] != avant[cle]:
                fails.append(f"{cle} n'est pas restaure")
        print(f"  reprise : {apres['pos']}, or {apres['or_']}, "
              f"{apres['vues']} cases relevees, "
              f"quittance {apres['quittance']}, reglages {apres['reglages']}")
        for i in range(T.NH):
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

    print("--- sans son donjon ---")
    # Le paquet du donjon manque : le jeu doit le dire dans le Shell et
    # rendre la main, sans toucher a l'ecran.
    import tempfile
    vide = tempfile.mkdtemp(prefix="aga-progdir-")
    old_prog = os.environ.get("AGA_PROGDIR")
    os.environ["AGA_PROGDIR"] = vide
    try:
        n = T.Game()
    finally:
        if old_prog is None:
            del os.environ["AGA_PROGDIR"]
        else:
            os.environ["AGA_PROGDIR"] = old_prog
    if not n.finished:
        fails.append("sans Donjons/Crypte.dgn, le jeu demarre quand meme")
    if "Crypte.dgn" not in n.console:
        fails.append(f"sans son donjon, le jeu ne dit rien ({n.console!r})")
    print(f"  il le dit et rend la main : {n.console.strip()}")

    print("--- la disquette des donnees ---")
    # Le paquet n'est plus sur la disquette du jeu : il vit sur
    # FaerghailData, que le jeu appelle par son nom de volume quand
    # PROGDIR: ne l'a pas.
    old_data = os.environ.get("AGA_DATADIR")
    os.environ["AGA_PROGDIR"] = vide
    os.environ["AGA_DATADIR"] = os.path.join(T.ROOT, "bin")
    try:
        d = T.Game()
    finally:
        for var, old in (("AGA_PROGDIR", old_prog), ("AGA_DATADIR", old_data)):
            if old is None:
                del os.environ[var]
            else:
                os.environ[var] = old
    if d.finished:
        fails.append(f"le paquet de FaerghailData n'est pas lu ({d.console!r})")
    elif "FaerghailData:Donjons/Crypte.dgn" not in d.opened:
        fails.append(f"le paquet vient d'ailleurs : {d.opened}")
    else:
        print("  PROGDIR: vide, le paquet vient de FaerghailData:")
    # L'ecran pris, DOS ne doit plus poser de requete que personne ne
    # verrait : une sauvegarde sans sa disquette echoue, sans attendre.
    win = d.mem.r32(d.PROCESS + 184)
    if win != 0xffffffff:
        fails.append(f"pr_WindowPtr vaut {win:#x} une fois l'ecran pris")
    else:
        print("  les requetes de DOS sont coupees une fois l'ecran pris")

    print()
    if fails:
        print(f"{len(fails)} anomalie(s) :")
        for f in fails:
            print("  -", f)
        sys.exit(1)
    print("accueil, sauvegarde et reprise en ordre")
