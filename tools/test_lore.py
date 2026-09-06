#!/usr/bin/env python3
"""Eprouve le journal : les steles, l'introduction et les deux fins.

Un donjon sans recit n'est qu'un couloir. Les pages sont posees dans le
source, les steles dans les cartes, et le numero de l'une doit designer
l'autre : une stele de trop lirait une page qui n'existe pas, et le jeu
afficherait l'introduction au fond du cinquieme etage.

    python3 tools/test_lore.py
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import test_game as T
import shot68k as S

SCRW = 320
T_STELE = 11


def equ(name, src="crawl.s"):
    for line in open(os.path.join(ROOT, "src", src)):
        if line.split("\t")[0].strip() == name:
            return int(line.split("=", 1)[1].split(";")[0].strip())
    raise SystemExit(f"{name} introuvable")


def page_text(g, n):
    """Le titre et les lignes de la page n, lus en memoire."""
    ptr = g.mem.r32(g.addr("LoreTable") + n * 4)
    out = []
    for _ in range(equ("LORELINES") + 1):
        s = b""
        while True:
            c = g.mem.r8(ptr)
            ptr += 1
            if not c:
                break
            s += bytes([c])
        out.append(s.decode("latin-1"))
    return out


def steles():
    """Les steles posees sur les cartes : (etage, page)."""
    raw = open(os.path.join(ROOT, "data", "dgnmap.bin"), "rb").read()
    mapw = 24
    step = 4 + mapw * mapw * 2
    out = []
    for lv in range(len(raw) // step):
        blk = raw[lv * step:(lv + 1) * step]
        grid, par = blk[4:4 + 576], blk[4 + 576:4 + 1152]
        for i in range(576):
            if grid[i] & 0x0f == T_STELE:
                out.append((lv, par[i], i % mapw, i // mapw))
    return out


def check(cond, msg, fails):
    if not cond:
        fails.append(msg)
    return cond


if __name__ == "__main__":
    fails = []
    g = T.Game()
    nlore = equ("NLORE")
    first = equ("LORE_FIRST")
    cols = equ("LORECOLS")
    lines = equ("LORELINES")

    print("--- les pages ---")
    vides = 0
    for n in range(nlore):
        page = page_text(g, n)
        titre, corps = page[0], page[1:]
        check(titre, f"la page {n} n'a pas de titre", fails)
        check(len(titre) <= cols, f"le titre de la page {n} fait "
              f"{len(titre)} colonnes, le panneau en tient {cols}", fails)
        for i, ln in enumerate(corps):
            check(len(ln) <= cols, f"page {n} ligne {i} : {len(ln)} colonnes "
                  f"pour {cols} : « {ln} »", fails)
        if not any(corps):
            vides += 1
    check(vides == 0, f"{vides} page(s) sans texte", fails)
    print(f"  {nlore} pages, {lines} lignes de {cols} colonnes au plus")
    print(f"  intro : « {page_text(g, 0)[0]} »")
    print(f"  fins  : « {page_text(g, 1)[0]} » / « {page_text(g, 2)[0]} »")

    print("--- les steles ---")
    st = steles()
    pages = sorted(p for _, p, _, _ in st)
    print(f"  {len(st)} steles sur {len(set(lv for lv, _, _, _ in st))} etages,"
          f" pages {pages}")
    check(len(st) == nlore - first,
          f"{len(st)} steles pour {nlore - first} pages de stele", fails)
    check(pages == list(range(nlore - first)),
          f"les pages des steles ne se suivent pas : {pages}", fails)
    for lv, p, x, y in st:
        check(p + first < nlore,
              f"la stele de l'etage {lv + 1} en {x},{y} demande la page "
              f"{p + first}, il n'y en a que {nlore}", fails)

    print("--- lire une stele ---")
    T.create_party(g, keep_lore=True)
    check(g.w("UiMode") == 9, "l'introduction ne s'ouvre pas apres la "
          f"creation (UiMode={g.w('UiMode')})", fails)
    check(g.w("LorePage") == 0, f"l'introduction montre la page "
          f"{g.w('LorePage')}", fails)
    g.key(T.K_SPACE)
    check(g.w("UiMode") == 0, "l'espace ne referme pas la page", fails)
    print("  l'introduction s'ouvre a la creation et se referme d'un espace")

    # chaque page doit vraiment noircir des pixels du panneau
    for n in range(nlore):
        g.call(g.addr("ShowLore"), d0=n)
        g.setw("NeedRedraw", 1)
        g.run(slices=60, idle=g.idle)
        px = S.grab(g, "ShowBuf")
        vus = {px[y * SCRW + x] for y in range(16, 152)
               for x in range(16, 208) if px[y * SCRW + x]}
        check(len(vus) >= 2, f"la page {n} ne dessine rien", fails)
    print(f"  les {nlore} pages s'affichent")
    g.setw("UiMode", 0)

    print()
    if fails:
        print(f"{len(fails)} anomalie(s) :")
        for f in fails[:10]:
            print("  -", f)
        sys.exit(1)
    print("le journal se tient")
