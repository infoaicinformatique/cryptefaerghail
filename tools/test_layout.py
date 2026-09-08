#!/usr/bin/env python3
"""Verifie qu'aucun panneau ne deborde de la zone que le fond repeint.

La vue du donjon est repeinte par un seul morceau de decor, de (16,16)
a (208,152). Tout ce qu'un panneau ecrit en dehors de ce rectangle mais
a l'interieur du cadre y reste indefiniment : c'est ainsi qu'un nom de
sort trop long laissait deux chiffres colles au bord. Ce banc ouvre
chaque ecran avec le contenu le plus large possible et regarde les
pixels un par un.

    python3 tools/test_layout.py
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import test_game as T
import shot68k as S

SCRW = 320
VIEW = (16, 16, 208, 152)                # ce que le fond du donjon repeint
FRAME = (11, 11, 213, 157)               # bord interieur du cadre cisele


NOIR = S.PALETTE[0]


def outside(px):
    """Pixels visibles entre le cadre et la zone que le decor repeint.

    On compare la couleur rendue, pas l'index : le jeu efface avec une
    teinte nommee de la palette, qui est noire mais n'est pas l'index
    zero -- la comparer a zero faisait crier le banc a tort.
    """
    x0, y0, x1, y1 = VIEW
    fx0, fy0, fx1, fy1 = FRAME
    bad = []
    for y in range(fy0 + 1, fy1 - 1):
        for x in range(fx0 + 1, fx1 - 1):
            if x0 <= x < x1 and y0 <= y < y1:
                continue
            if S.PALETTE[px[y * SCRW + x]] != NOIR:
                bad.append((x, y))
    return bad


def widest(g):
    """Met dans le groupe et le sac les noms les plus longs des tables."""
    items = g.addr("ItemTable")
    longest = {}
    for n in range(1, 29):                # nom sur 18 octets, en tete
        name = bytes(g.mem.r8(items + (n - 1) * 34 + k) for k in range(18))
        longest[n] = len(name.split(b"\0")[0])
    order = sorted(longest, key=lambda n: -longest[n])
    inv = g.addr("Inventory")
    for slot in range(24):                # sac rempli des noms les plus longs
        g.mem.w8(inv + slot, order[slot % len(order)])
    spells = T.read_equ("hr_Spells", 40)
    for h in range(4):                    # et tout le monde equipe pareil
        base = g.addr("Heroes") + h * T.HR["hr_SIZEOF"]
        g.mem.w16(base + T.HR["hr_Weapon"], order[0])
        g.mem.w16(base + spells, 0xffff)  # tous les sorts connus
    g.setw("NeedRedraw", 1)


def richest(g):
    """Un etal aux noms les plus longs, et une bourse a cinq chiffres :
    c'est la ligne la plus large que le panneau puisse avoir a ecrire."""
    items = g.addr("ItemTable")
    longest = {}
    for n in range(1, 29):
        name = bytes(g.mem.r8(items + (n - 1) * 34 + k) for k in range(18))
        longest[n] = len(name.split(b"\0")[0])
    order = sorted(longest, key=lambda n: -longest[n])
    stock = g.addr("ShopStock")
    for slot in range(8):
        g.mem.w8(stock + slot, order[slot])
    g.setw("Gold", 0xffff)                # la bourse la plus encombrante


PROLOG_ROWS = (7, 249)                   # lignes hors du cadre du prologue
PROLOG_COLS = (6, 314)                   # colonnes idem, sur les lignes
PROLOG_GAP = (20, 220, 300, 226)         # le blanc entre texte et pied


def prolog_pages(g, fails):
    """Le prologue : quatre pages de texte libre, donc quatre occasions
    d'ecrire hors du cadre.

    On regarde deux choses. La bordure de l'ecran d'abord : une ligne de
    trop deborde du plan et retombe en haut du suivant, ou elle se voit.
    Puis la bande laissee entre la derniere ligne et le pied de page --
    c'est elle qui se remplit en premier quand une page grossit."""
    oy0, oy1 = PROLOG_ROWS
    ox0, ox1 = PROLOG_COLS
    gx0, gy0, gx1, gy1 = PROLOG_GAP

    def out(x, y):
        """Hors du cadre, bordure comprise : depuis que HLine trace au
        pixel pres, l'ombre portee du cadre ne deborde plus a gauche."""
        return x < ox0 or x >= ox1 or y < oy0 or y >= oy1

    for page in range(T.read_equ("PROLOGPAGES", 4)):
        px = S.grab(g, "ShowBuf")
        bad = [(x, y)
               for y in range(256) for x in range(SCRW)
               if out(x, y) and S.PALETTE[px[y * SCRW + x]] != NOIR]
        gap = [(x, y)
               for y in range(gy0, gy1) for x in range(gx0, gx1)
               if S.PALETTE[px[y * SCRW + x]] != NOIR]
        name = f"prologue {page + 1}"
        if bad:
            ys = sorted({y for _, y in bad})
            fails.append(f"{name} : {len(bad)} pixels hors du cadre, "
                         f"y {ys[0]}..{ys[-1]}")
        if gap:
            fails.append(f"{name} : {len(gap)} pixels dans la bande qui "
                         "separe le texte du pied de page")
        print(f"  {name:16s} "
              f"{'deborde' if bad or gap else 'dans le cadre'}")
        g.key(T.K_SPACE)


def frame(g):
    """Fait tourner le jeu jusqu'a ce qu'il ait redessine.

    Poser NeedRedraw ne dessine rien : c'est la boucle principale qui
    lit ce drapeau. Sans ce tour de manivelle, les panneaux montes a la
    main -- l'echoppe, le registre -- etaient photographies sur l'image
    precedente, et le banc declarait dans le cadre un panneau qui n'y
    avait jamais ete dessine."""
    g.setw("NeedRedraw", 1)
    g.run(slices=120, idle=g.idle)


def shot(g, name, fails, ring=True):
    """`ring` a faux pour l'accueil : son illustration couvre l'ecran
    entier, elle a le droit d'occuper la bordure."""
    frame(g)
    px = S.grab(g, "ShowBuf")
    bad = outside(px) if ring else []
    if bad:
        xs = sorted({x for x, _ in bad})
        ys = sorted({y for _, y in bad})
        fails.append(f"{name} : {len(bad)} pixels hors zone, "
                     f"x {xs[0]}..{xs[-1]}, y {ys[0]}..{ys[-1]}")
    print(f"  {name:16s} {'deborde' if bad else 'dans le cadre'}")


if __name__ == "__main__":
    fails = []
    g = T.Game()
    print("--- ecrans, avec les textes les plus larges des tables ---")
    shot(g, "titre", fails, ring=False)
    g.key(T.K_1 + 2)                      # 3 : le prologue, page a page
    prolog_pages(g, fails)                # la derniere page rend l'accueil
    g.key(T.K_1)                          # sortir de l'accueil
    shot(g, "creation", fails)
    g.key(T.K_1 + 6)
    shot(g, "jets", fails)
    g.key(T.K_RET); g.key(T.K_RET)
    for c in (0, 5, 2):
        g.key(T.K_1 + c); g.key(T.K_RET); g.key(T.K_RET)
    widest(g)
    g.key(T.K_1)                          # forcer un redessin
    shot(g, "vue", fails)
    g.key(T.K_C)
    shot(g, "fiche", fails)
    g.key(T.K_C); g.key(T.K_I)
    shot(g, "sac", fails)
    g.key(T.K_I); g.key(T.K_S)
    shot(g, "sorts", fails)
    g.key(T.K_ESC); g.key(0x37)
    shot(g, "carte", fails)
    g.key(0x37); g.key(0x28)              # L : le grimoire
    shot(g, "grimoire", fails)
    for _ in range(12):                   # jusqu'au dernier sort
        g.key(T.K_DOWN)
    shot(g, "grimoire-bas", fails)
    g.key(0x28); g.key(0x19)              # P : les reglages
    shot(g, "reglages", fails)
    g.key(0x19)

    richest(g)                            # l'echoppe, des deux cotes
    g.setw("UiMode", T.read_equ("UI_SHOP", 8))
    g.setw("ShopMode", 0)
    g.setw("ShopCursor", 0)
    g.setw("ShopTop", 0)
    g.setw("NeedRedraw", 1)
    shot(g, "echoppe-achat", fails)
    g.setw("ShopMode", 1)                 # le sac, deja rempli par widest()
    g.setw("ShopCursor", 23)
    g.setw("ShopTop", 16)
    g.setw("NeedRedraw", 1)
    shot(g, "echoppe-vente", fails)
    g.setw("UiMode", 0)
    g.setw("NeedRedraw", 1)

    # Le grand registre, dans ses deux etats : la page porte les quatre
    # noms du groupe, et le pied change une fois la ligne rayee.
    for state, name in ((0, "registre"), (1, "registre-raye")):
        g.setw("Acquitted", state)
        g.setw("UiMode", T.read_equ("UI_LEDGER", 9))
        g.setw("NeedRedraw", 1)
        shot(g, name, fails)
    g.setw("Acquitted", 0)
    g.setw("UiMode", 0)
    g.setw("NeedRedraw", 1)

    import play_game as P                 # une enigme, si on en trouve une
    grid = P.terrain(g)
    path = P.bfs(grid, (g.w("PosX"), g.w("PosY")), lambda c: c & 0x0f == 6)
    if path:
        for cell in path[1:-1]:
            P.step_to(g, cell, [])
        g.key(T.K_SPACE)
        if g.w("UiMode") == 4:
            shot(g, "enigme", fails)
            g.key(T.K_1)
    print()
    if fails:
        print(f"{len(fails)} debordement(s) :")
        for f in fails:
            print("  -", f)
        sys.exit(1)
    print("aucun panneau ne deborde")
