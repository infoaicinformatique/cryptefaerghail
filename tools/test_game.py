#!/usr/bin/env python3
"""Fait tourner le jeu dans un 68020 emule et verifie son comportement.

Le jeu n'ayant jamais tourne sur Amiga, ce banc est le seul moyen de le
mettre a l'epreuve : il charge l'executable avec ses symboles, execute
le vrai code, pilote le clavier et relit l'etat en memoire.

Le balayage video, l'etat du blitter et le port serie du clavier sont
emules par des plages memoire a callbacks, si bien que les boucles
d'attente du jeu se terminent normalement. Le blitter ne recopie rien :
seul l'affichage manque, pas la logique.

    python3 tools/test_game.py
"""
import collections
import os
import random
import struct
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import run68k as R

DBG = "/tmp/AGACrawl.dbg"

K_1, K_RET, K_ESC, K_SPACE, K_TAB = 0x01, 0x44, 0x45, 0x40, 0x42
K_UP, K_DOWN, K_RIGHT, K_LEFT = 0x4c, 0x4d, 0x4e, 0x4f
K_M_QW, K_M_AZ = 0x37, 0x29
K_L, K_P = 0x28, 0x19
K_A, K_S, K_F, K_I, K_C, K_E, K_U, K_D = 0x20, 0x21, 0x23, 0x17, 0x33, 0x12, 0x16, 0x22

hr_SIZEOF = 46 + 8                       # relu ci-dessous depuis le source


def read_equ(name, default):
    src = open(os.path.join(ROOT, "src", "crawl.s"),
               encoding="latin-1").read()
    for line in src.splitlines():
        if line.startswith(name):
            try:
                return int(line.split("=")[1].split(";")[0].strip())
            except ValueError:
                pass
    return default


HR = {k: read_equ(k, 0) for k in
      ("hr_Name", "hr_Class", "hr_Level", "hr_Xp", "hr_Hp", "hr_HpMax",
       "hr_Mp", "hr_MpMax", "hr_Str", "hr_Weapon", "hr_SIZEOF", "hr_Slots")}
MAPW = 24


def load_symbols(path):
    d = open(path, "rb").read()

    def u32(p):
        return struct.unpack(">I", d[p:p + 4])[0]

    p, syms, hunk = 4, {}, -1
    while u32(p):
        p += 4
    p += 4
    cnt = u32(p)
    p += 12 + 4 * cnt
    while p < len(d):
        t = u32(p) & 0x3fffffff
        p += 4
        if t in (0x3e9, 0x3ea):
            p += 4 + u32(p) * 4
        elif t == 0x3eb:
            p += 4
        elif t == 0x3ec:
            while True:
                c = u32(p)
                p += 4
                if not c:
                    break
                p += 4 + 4 * c
        elif t == 0x3f0:
            hunk += 1
            while True:
                ln = u32(p)
                p += 4
                if not ln:
                    break
                name = d[p:p + ln * 4].split(b"\0")[0].decode()
                p += ln * 4
                syms.setdefault(name, (hunk, u32(p)))
                p += 4
        elif t == 0x3f2:
            continue
        else:
            break
    return syms


class Game(R.Harness):
    def __init__(self):
        subprocess.run([os.path.join(ROOT, "tools/bin/vlink"), "-bamigahunk",
                        "-Bstatic", "-o", DBG,
                        os.path.join(ROOT, "build/AGACrawl.o")], check=True)
        super().__init__(DBG)
        self.syms = load_symbols(DBG)
        self.hunk_sym = {}
        for name, (h, off) in self.syms.items():
            self.hunk_sym[name] = self.segs[h][0] + off
        self.start()
        self.run(slices=12)              # amorcage jusqu'a la boucle

    def addr(self, name):
        return self.hunk_sym[name]

    def span(self, name):
        """Debut et fin d'une routine : jusqu'au symbole suivant du meme
        hunk. Sert a reconnaitre le processeur arrete dedans."""
        hunk, off = self.syms[name]
        after = [o for h, o in self.syms.values() if h == hunk and o > off]
        base = self.segs[hunk][0]
        return base + off, base + (min(after) if after else off + 16)

    def w(self, name, off=0):
        return self.mem.r16(self.addr(name) + off)

    def sw(self, name, off=0):
        v = self.w(name, off)
        return v - 0x10000 if v > 0x7fff else v

    def setw(self, name, val, off=0):
        self.mem.w16(self.addr(name) + off, val & 0xffff)

    def byte(self, name, off=0):
        return self.mem.r8(self.addr(name) + off)

    def hero(self, i, field):
        base = self.addr("Heroes") + i * HR["hr_SIZEOF"]
        v = self.mem.r16(base + HR[field])
        return v - 0x10000 if v > 0x7fff else v

    def name(self, i):
        base = self.addr("Heroes") + i * HR["hr_SIZEOF"]
        out = b""
        for k in range(9):
            c = self.mem.r8(base + k)
            if not c:
                break
            out += bytes([c])
        return out.decode("latin-1")

    def idle(self):
        """Le jeu a-t-il fini de dessiner ?

        A huit bitplanes une image coute pres de deux millions de
        cycles, bien plus qu'une tranche : s'arreter sur un compteur
        donnait des captures tronquees en plein journal. On attend donc
        que le processeur soit revenu attendre le retour trame, sans
        redessin en cours ni image en attente d'echange."""
        pc = self.cpu.r_pc()
        top, end = self.span("VBI_Wait")
        return (top <= pc < end and self.w("NeedRedraw") == 0
                and self.w("DrawReady") == 0)

    def mouse_to(self, x, y):
        """Amene le pointeur en (x,y). On ne peut pas l'y poser : le jeu
        ne lit que des ecarts de quadrature, comme sur la machine."""
        for _ in range(90):
            dx = max(-100, min(100, x - self.w("MouseX")))
            dy = max(-100, min(100, y - self.w("MouseY")))
            if not dx and not dy:
                return True
            self.mouse_move(dx, dy)
            self.run(slices=3)
        return (self.w("MouseX"), self.w("MouseY")) == (x, y)

    def click(self, x, y, button=1, slices=80):
        """Un clic complet : on vise, on presse, on relache."""
        self.mouse_to(x, y)
        self.mouse_button(button)
        self.run(slices=4)
        self.mouse_button(0)
        err = self.run(slices=slices, idle=self.idle)
        assert err is None or "termine" in err, err

    def key(self, code, slices=80):
        self.press(code)
        err = self.run(slices=slices, idle=self.idle)
        assert err is None or "termine" in err, err

    def keys(self, seq, slices=40):
        for k in seq:
            self.key(k, slices)


MAPH = 24
PANEL_X, PANEL_TOP, PANEL_STEP = 224, 12, 37
DIRS = [(0, -1), (1, 0), (0, 1), (-1, 0)]        # meme ordre que DirTable
T_WALL, T_LOCKED, T_NICHE, T_LEVER, T_GATE = 1, 4, 5, 7, 8
T_SHOP, T_TRAP = 9, 10
T_LEDGER = 11                                    # le grand registre
T_STAIRSUP = 12                                  # l'escalier qui remonte
C_MASK, C_MONSTER = 0x30, 0x20      # contenu de la case, cf. crawl.s


def grid_of(g):
    base = g.addr("MapTerrain")
    return [[g.mem.r8(base + y * MAPW + x) for x in range(MAPW)]
            for y in range(MAPH)]


def walk_towards(g, want, budget=60):
    """Marche vers la case la plus proche satisfaisant want().

    Le banc tirait ses deplacements au hasard : selon la graine et le
    trace du niveau le groupe pouvait tourner en rond sans jamais
    croiser un monstre, et toute la partie combat restait alors sans
    objet. On y va donc en droite ligne."""
    for _ in range(budget):
        if g.w("InCombat"):
            return True
        grid = grid_of(g)
        here = (g.w("PosX"), g.w("PosY"))
        seen, q, path = {here: None}, collections.deque([here]), None
        while q:
            cur = q.popleft()
            if cur != here and want(grid[cur[1]][cur[0]]):
                path = []
                while cur:
                    path.append(cur)
                    cur = seen[cur]
                path.reverse()
                break
            for dx, dy in DIRS:
                nxt = (cur[0] + dx, cur[1] + dy)
                if not (0 <= nxt[0] < MAPW and 0 <= nxt[1] < MAPH):
                    continue
                t = grid[nxt[1]][nxt[0]] & 0x0f
                if nxt in seen or t in (T_WALL, T_NICHE, T_LEVER, T_GATE, T_SHOP):
                    continue
                seen[nxt] = cur
                q.append(nxt)
        if not path or len(path) < 2:
            return g.w("InCombat") != 0
        step = path[1]
        d = (step[0] - here[0], step[1] - here[1])
        for _ in range(4):                       # se tourner vers la case
            if g.w("Dir") == DIRS.index(d):
                break
            g.key(K_RIGHT)
        g.key(K_UP)
        if (g.w("PosX"), g.w("PosY")) == here:   # porte close : l'ouvrir
            g.key(K_SPACE)
            if g.w("UiMode") == 4:               # une enigme barre le chemin
                for answer in range(3):
                    g.key(K_1 + answer)
                    if g.w("UiMode") != 4:
                        break
                else:
                    g.key(K_ESC)
            g.key(K_UP)
            if (g.w("PosX"), g.w("PosY")) == here:
                return g.w("InCombat") != 0
    return g.w("InCombat") != 0


def prolog_test(g, fails):
    """Le prologue, depuis l'accueil : les pages tournent, les fleches
    reviennent, et la page tournee apres la derniere rend l'accueil --
    c'est la sortie de qui lit sans regarder les touches."""
    pages = read_equ("PROLOGPAGES", 4)
    title, prolog = read_equ("PHASE_TITLE", 2), read_equ("PHASE_PROLOG", 3)
    g.key(K_1 + 2)
    check(g.w("Phase") == prolog, f"la touche 3 mene en phase "
          f"{g.w('Phase')} au lieu de {prolog}", fails)
    check(g.w("PrologPage") == 0, "le prologue ne s" + chr(39)
          + "ouvre pas sur sa premiere page", fails)
    for n in range(1, pages):
        g.key(K_SPACE)
        check(g.w("PrologPage") == n, f"page {g.w('PrologPage')} "
              f"au lieu de {n}", fails)
    g.key(K_SPACE)
    check(g.w("Phase") == title, "la page d" + chr(39) + "apres la "
          "derniere devrait rendre l" + chr(39) + "accueil", fails)

    g.key(K_1 + 2)                       # les fleches reviennent en arriere
    g.key(K_SPACE)
    g.key(K_LEFT)
    check(g.w("PrologPage") == 0, f"la fleche gauche laisse la page "
          f"{g.w('PrologPage')}", fails)
    g.key(K_LEFT)
    check(g.w("PrologPage") == 0, "on remonte avant la premiere page", fails)
    g.key(K_ESC)
    check(g.w("Phase") == title, "ESC ne rend pas l" + chr(39) + "accueil",
          fails)
    print(f"  {pages} pages, les fleches reviennent, ESC rend l'accueil")


def create_party(g, classes=(0, 6, 1, 5)):
    """Choix de classe, acceptation des jets, nom par defaut.

    Le jeu s'ouvre sur l'ecran d'accueil : on demande d'abord une
    nouvelle partie."""
    if g.w("Phase") == 2:
        g.key(K_1)
    for c in classes:
        g.key(K_1 + c)                   # touche 1 a 8
        g.key(K_RET)                     # garder les caracteristiques
        g.key(K_RET)                     # garder le nom propose
    return g.w("Phase")


def face_cell(g, target):
    """Tourne le groupe vers une case voisine."""
    d = (target[0] - g.w("PosX"), target[1] - g.w("PosY"))
    if d not in DIRS:
        return False
    for _ in range(4):
        if g.w("Dir") == DIRS.index(d):
            return True
        g.key(K_RIGHT)
    return False


def shop_test(g, fails):
    """Aller au marchand, acheter, revendre, et verifier la bourse.

    C'est le seul emploi de l'or dans le jeu : s'il se casse, le joueur
    amasse des pieces pour rien et rien ne le signale."""
    grid = grid_of(g)
    shops = [(x, y) for y in range(MAPH) for x in range(MAPW)
             if grid[y][x] & 0x0f == T_SHOP]
    if not check(shops, "aucune echoppe sur cet etage", fails):
        return
    sx, sy = shops[0]
    spot = [(sx + dx, sy + dy) for dx, dy in DIRS
            if 0 <= sx + dx < MAPW and 0 <= sy + dy < MAPH
            and grid[sy + dy][sx + dx] & 0x0f not in
            (T_WALL, T_NICHE, T_LEVER, T_GATE, T_SHOP)]
    if not check(spot, f"echoppe murée en {sx},{sy}", fails):
        return
    if not walk_to(g, spot[0]):
        fails.append(f"impossible d'atteindre l'echoppe en {spot[0]}")
        return
    if not check(face_cell(g, (sx, sy)), "impossible de faire face a l'echoppe",
                 fails):
        return
    g.key(K_SPACE)
    ui = g.w("UiMode")
    if not check(ui == 8, f"l'echoppe ne s'ouvre pas (UiMode={ui})", fails):
        return

    g.setw("Gold", 500)                   # de quoi conclure une affaire
    g.setw("NeedRedraw", 1)
    stock = g.addr("ShopStock")
    before = [g.mem.r8(stock + i) for i in range(8)]
    check(any(before), "l'etal du marchand est vide", fails)
    line = next(i for i, v in enumerate(before) if v)
    g.setw("ShopCursor", line)
    gold0, bag0 = g.w("Gold"), inv_used(g)
    g.key(K_RET)                          # acheter
    after = [g.mem.r8(stock + i) for i in range(8)]
    check(after[line] == 0, "l'objet achete reste sur l'etal", fails)
    check(g.w("Gold") < gold0, f"l'achat ne coute rien ({gold0} -> "
          f"{g.w('Gold')})", fails)
    check(inv_used(g) == bag0 + 1, "l'objet achete n'arrive pas dans le sac",
          fails)
    print(f"  achat : or {gold0} -> {g.w('Gold')}, sac {bag0} -> {inv_used(g)}")

    g.key(K_TAB)                          # passer a la vente
    check(g.w("ShopMode") == 1, "TAB ne change pas de cote du comptoir", fails)
    g.setw("ShopCursor", 0)
    gold1, bag1 = g.w("Gold"), inv_used(g)
    g.key(K_RET)
    check(g.w("Gold") > gold1, f"la vente ne rapporte rien ({gold1} -> "
          f"{g.w('Gold')})", fails)
    check(inv_used(g) == bag1 - 1, "l'objet vendu reste dans le sac", fails)
    print(f"  vente : or {gold1} -> {g.w('Gold')}, sac {bag1} -> {inv_used(g)}")

    g.setw("Gold", 0)                     # sans le sou, on n'achete rien
    g.key(K_TAB)
    g.setw("ShopCursor", next(i for i, v in enumerate(
        [g.mem.r8(stock + i) for i in range(8)]) if v))
    bag2 = inv_used(g)
    g.key(K_RET)
    check(g.sw("Gold") == 0, f"l'or passe sous zero : {g.sw('Gold')}", fails)
    check(inv_used(g) == bag2, "un objet arrive sans etre paye", fails)
    print("  sans le sou : le marchand ne cede rien")
    g.key(K_ESC)
    check(g.w("UiMode") == 0, "l'echoppe ne se referme pas", fails)


def walk_test(g, fails):
    """Les monstres marchent, et celui qui vient a nous meurt chez lui.

    Deux choses a la fois : le pas vers le groupe, et la case que la
    mort nettoie. Tant que le groupe entrait toujours dans le monstre,
    les deux cases etaient la meme ; ce n'est plus vrai."""
    ter, par = g.addr("MapTerrain"), g.addr("MapParam")
    for i in range(MAPW * MAPH):          # l'etage a nous seuls
        cell = g.mem.r8(ter + i)
        if cell & 0x30 == 0x20:
            g.mem.w8(ter + i, cell & 0x0f)
    heal(g)
    px, py = g.w("PosX"), g.w("PosY")
    grid = grid_of(g)
    spot = next(((x, y) for d in (2, 3, 4)
                 for x in range(MAPW) for y in range(MAPH)
                 if abs(x - px) + abs(y - py) == d and grid[y][x] == 0
                 and g.mem.r8(par + y * MAPW + x) == 0), None)
    if not check(spot, "pas de dallage nu ou poser un monstre", fails):
        return
    mx, my = spot
    g.mem.w8(ter + my * MAPW + mx, 0x20)  # un kobold, espece 0
    g.mem.w8(par + my * MAPW + mx, 0)

    for _ in range(30):                   # il vient
        g.run(slices=2)
        if g.w("InCombat"):
            break
    if not check(g.w("InCombat"), f"le monstre pose en {spot} n'est jamais "
                 "venu jusqu'au groupe", fails):
        return
    here = (g.w("PosX"), g.w("PosY"))
    mon = (g.w("MonX"), g.w("MonY"))
    check(here == (px, py), f"le groupe a bouge tout seul : {here}", fails)
    check(mon != here, "le monstre combat depuis la case du groupe", fails)
    print(f"  pose en {spot}, il aborde le groupe en {here} depuis {mon}")

    for _ in range(80):
        if not g.w("InCombat"):
            break
        g.key(K_A)
    if g.w("GameOver"):
        fails.append("le groupe tombe contre un kobold")
        return
    grid = grid_of(g)
    restes = [(x, y) for y in range(MAPH) for x in range(MAPW)
              if grid[y][x] & 0x30 == 0x20]
    check(not restes, f"le monstre mort tient encore sa case {restes}", fails)
    marques = [(x, y) for y in range(MAPH) for x in range(MAPW)
               if grid[y][x] & 0x40]
    check(not marques, f"des marques de travail restent sur la carte "
          f"{marques[:4]}", fails)
    print("  vaincu, sa case est rendue au dallage")


def stairs_test(g, fails):
    """L'escalier qui remonte, et l'etage qui reste comme on l'a laisse.

    Sans etat garde, remonter puis redescendre rendrait l'etage neuf --
    coffres pleins, monstres debout -- et le donjon se moissonnerait en
    boucle. On vide donc un coffre, on remonte, on redescend."""
    g.setw("GameOver", 0)
    g.setw("UiMode", 0)
    g.setw("InCombat", 0)
    heal(g)
    g.setw("Level", 1)
    if not check(g.call(g.addr("LevelEnter")), "LevelEnter ne rend pas la "
                 "main", fails):
        return
    ter = g.addr("MapTerrain")
    grid = grid_of(g)
    px, py = g.w("PosX"), g.w("PosY")
    check(grid[py][px] & 0x0f == T_STAIRSUP, "on n'arrive pas sur l'escalier "
          f"qui remonte (terrain {grid[py][px] & 0x0f})", fails)

    coffres = [(x, y) for y in range(MAPH) for x in range(MAPW)
               if grid[y][x] & 0x30 == 0x10]
    if not check(coffres, "aucun coffre au deuxieme etage", fails):
        return
    cx, cy = coffres[0]
    g.mem.w8(ter + cy * MAPW + cx, grid[cy][cx] & 0x0f)   # on le vide

    voisin = next(((px + dx, py + dy) for dx, dy in DIRS
                   if 0 <= px + dx < MAPW and 0 <= py + dy < MAPH
                   and grid[py + dy][px + dx] & 0x0f == 0), None)
    if not check(voisin, "l'escalier montant n'a pas de voisin libre", fails):
        return
    # Un pas, pas un trajet : remonter deplace le groupe a l'etage du
    # dessus, et walk_to, qui vise une case, ne s'y retrouverait plus.
    if not check(walk_to(g, voisin, budget=20), "impossible de descendre de "
                 "l'escalier", fails):
        return
    if not check(face_cell(g, (px, py)), "impossible de faire face a "
                 "l'escalier", fails):
        return
    g.key(K_UP)
    check(g.w("Level") == 0, f"remonter laisse au niveau {g.w('Level')}", fails)
    here = (g.w("PosX"), g.w("PosY"))
    check(grid_of(g)[here[1]][here[0]] & 0x0f == 3, "on ne remonte pas sur "
          f"l'escalier qui descend (en {here})", fails)
    print(f"  remonte du 2 au 1, on arrive sur l'escalier en {here}")

    g.setw("Level", 1)                    # et l'etage n'a pas repousse
    g.call(g.addr("LevelEnter"))
    apres = [(x, y) for y in range(MAPH) for x in range(MAPW)
             if grid_of(g)[y][x] & 0x30 == 0x10]
    check(len(apres) == len(coffres) - 1, f"l'etage a ete relu : "
          f"{len(apres)} coffres au lieu de {len(coffres) - 1}", fails)
    print(f"  et le coffre vide en {(cx, cy)} l'est reste")


def ledger_test(g, fails):
    """Le grand registre du dernier etage, et la porte des quittances.

    On descend d'autorite au troisieme -- y arriver en jouant prendrait
    la moitie du banc -- puis on verifie les deux moities de la regle :
    l'escalier ne rend pas le jour tant que la ligne n'est pas rayee, et
    la rayer suffit a l'ouvrir."""
    g.setw("GameOver", 0)                 # le fuzzing a pu achever le groupe
    g.setw("UiMode", 0)
    g.setw("InCombat", 0)
    heal(g)
    g.setw("Level", 2)
    if not check(g.call(g.addr("LevelEnter")), "LevelEnter ne rend pas la "
                 "main", fails):
        return
    g.setw("Acquitted", 0)
    g.setw("NeedRedraw", 1)
    g.key(K_1)                            # laisser le jeu se remettre en place

    # La marche jusqu'au greffe puis jusqu'a l'escalier traverse un
    # etage entier de dalles piegees, de herses et de monstres du
    # troisieme, qui aurait raison d'un groupe arrive la par la porte de
    # service. On deblaie : ce qui est eprouve ici, c'est le registre et
    # la porte des quittances, pas la traversee -- les pieges, les
    # leviers et les combats ont chacun leur banc.
    ter = g.addr("MapTerrain")
    for y in range(MAPH):
        for x in range(MAPW):
            cell = g.mem.r8(ter + y * MAPW + x)
            if cell & 0x0f == T_TRAP:
                g.mem.w8(ter + y * MAPW + x, cell & 0xf0)
            elif cell & 0x0f == T_GATE:          # une herse et son levier
                g.mem.w8(ter + y * MAPW + x, cell & 0xf0)
            elif cell & 0x30 == 0x20:            # un monstre poste la
                g.mem.w8(ter + y * MAPW + x, cell & 0x0f)

    grid = grid_of(g)
    seats = [(x, y) for y in range(MAPH) for x in range(MAPW)
             if grid[y][x] & 0x0f == T_LEDGER]
    if not check(seats, "aucun grand registre au dernier etage", fails):
        return
    lx, ly = seats[0]
    spot = [(lx + dx, ly + dy) for dx, dy in DIRS
            if 0 <= lx + dx < MAPW and 0 <= ly + dy < MAPH
            and grid[ly + dy][lx + dx] & 0x0f not in
            (T_WALL, T_NICHE, T_LEVER, T_GATE, T_SHOP, T_LEDGER)]
    if not check(spot, f"registre mure en {lx},{ly}", fails):
        return
    if not walk_to(g, spot[0], budget=200):
        fails.append(f"impossible d'atteindre le registre en {spot[0]} "
                     f"(arret en {(g.w('PosX'), g.w('PosY'))}, "
                     f"combat {g.w('InCombat')}, fin {g.w('GameOver')}, "
                     f"ui {g.w('UiMode')})")
        return
    if not check(face_cell(g, (lx, ly)), "impossible de faire face au "
                 "registre", fails):
        return

    stairs = [(x, y) for y in range(MAPH) for x in range(MAPW)
              if grid[y][x] & 0x0f == 3]
    g.key(K_SPACE)
    ui = g.w("UiMode")
    if not check(ui == 9, f"le registre ne s'ouvre pas (UiMode={ui})", fails):
        return
    check(g.w("Acquitted") == 0, "la ligne est rayee avant qu'on signe", fails)
    xp0 = g.hero(0, "hr_Xp")
    g.key(K_RET)
    check(g.w("Acquitted") == 1, "ENTREE ne raye pas la ligne", fails)
    check(g.hero(0, "hr_Xp") > xp0, "rayer la ligne ne vaut aucune "
          "experience", fails)
    g.key(K_RET)                          # on ne la raye pas deux fois
    check(g.w("Acquitted") == 1, "la quittance se defait", fails)
    g.key(K_ESC)
    print(f"  registre en {lx},{ly} : la ligne se raye, et une seule fois")

    if not check(stairs, "pas d'escalier au dernier etage", fails):
        return
    g.setw("Acquitted", 0)                # la porte, ligne non rayee
    g.setw("KeyCount", 5)                 # les serrures ne sont pas le sujet
    if not walk_to(g, stairs[0], budget=400):
        fails.append(f"impossible d'atteindre l'escalier en {stairs[0]} "
                     f"(arret en {(g.w('PosX'), g.w('PosY'))}, "
                     f"fin {g.w('GameOver')})")
        return
    check(g.w("GameOver") == 0, "la sortie s'ouvre sans quittance", fails)

    # La quittance signee, la meme porte. Il faut redescendre la marche :
    # c'est le pas qui la franchit qui compte, pas le fait d'etre dessus.
    grid = grid_of(g)
    back = [(stairs[0][0] + dx, stairs[0][1] + dy) for dx, dy in DIRS
            if 0 <= stairs[0][0] + dx < MAPW and 0 <= stairs[0][1] + dy < MAPH
            and grid[stairs[0][1] + dy][stairs[0][0] + dx] & 0x0f == 0]
    if not check(back, "escalier sans case voisine ou reculer", fails):
        return
    g.setw("Acquitted", 1)
    g.setw("NeedRedraw", 1)
    if not walk_to(g, back[0], budget=20) or not walk_to(g, stairs[0],
                                                         budget=20):
        fails.append("impossible de revenir a l'escalier")
        return
    check(g.w("GameOver") == 1, "la sortie reste fermee malgre la quittance",
          fails)
    print("  la porte des quittances : fermee sans, ouverte avec")


def trap_test(g, fails):
    """Marcher jusqu'a un piege et voir ce qu'il fait."""
    grid = grid_of(g)
    traps = [(x, y) for y in range(MAPH) for x in range(MAPW)
             if grid[y][x] & 0x0f == T_TRAP]
    if not check(traps, "aucun piege sur cet etage", fails):
        return
    print(f"  {len(traps)} dalles piegees sur l'etage")
    hp0 = sum(g.hero(i, "hr_Hp") for i in range(4))
    sprung = spotted = disarmed = 0
    for tx, ty in traps:
        if g.w("GameOver") or spotted + sprung >= 6:
            break
        grid = grid_of(g)
        if grid[ty][tx] & 0x0f != T_TRAP:
            continue
        spot = [(tx + dx, ty + dy) for dx, dy in DIRS
                if 0 <= tx + dx < MAPW and 0 <= ty + dy < MAPH
                and grid[ty + dy][tx + dx] & 0x0f not in
                (T_WALL, T_NICHE, T_LEVER, T_GATE, T_SHOP, T_TRAP)]
        if not spot or not walk_to(g, spot[0]):
            continue
        if not face_cell(g, (tx, ty)):
            continue
        heal(g)                           # on veut voir le piege, pas mourir
        before = (g.w("PosX"), g.w("PosY"))
        hpa = sum(g.hero(i, "hr_Hp") for i in range(4))
        g.key(K_UP)                       # marcher dessus
        par = g.mem.r8(g.addr("MapParam") + ty * MAPW + tx)
        now = grid_of(g)[ty][tx] & 0x0f
        moved = (g.w("PosX"), g.w("PosY")) != before
        if now == T_TRAP:
            # Repere a temps : la dalle reste armee, marquee, et le
            # groupe s'arrete devant.
            spotted += 1
            check(par & 0x80, "le piege reste arme sans etre marque", fails)
            check(not moved, "le piege est repere et le groupe avance quand"
                  " meme", fails)
            check(sum(g.hero(i, "hr_Hp") for i in range(4)) == hpa,
                  "un piege repere blesse quand meme", fails)
            g.key(K_SPACE)                # tenter le desamorcage
            if grid_of(g)[ty][tx] & 0x0f != T_TRAP:
                disarmed += 1
        else:
            # Detendu : la dalle redevient du sol et le groupe est dessus.
            sprung += 1
            check(moved, "le piege se detend mais le groupe n'avance pas",
                  fails)
            check(g.mem.r8(g.addr("MapParam") + ty * MAPW + tx) == 0,
                  "un piege detendu garde son parametre", fails)
        for i in range(4):
            hp, hpm = g.hero(i, "hr_Hp"), g.hero(i, "hr_HpMax")
            if not check(0 <= hp <= hpm, f"heros {i} PV {hp}/{hpm}", fails):
                return
    hp1 = sum(g.hero(i, "hr_Hp") for i in range(4))
    print(f"  {spotted} reperes ({disarmed} desamorces), {sprung} declenches, "
          f"PV du groupe {hp0} -> {hp1}")
    check(spotted + sprung > 0, "aucun piege n'a pu etre approche", fails)
    check(spotted > 0, "aucun piege n'est jamais repere : le jet de detection"
          " ne sert a rien", fails)

    # Le declenchement se couvre a part : a difficulte moderee la
    # detection l'emporte presque toujours, et la moitie du mecanisme
    # ne serait jamais eprouvee. Enjamber sciemment une dalle reperee
    # est un vrai chemin du jeu, et il passe par SpringTrap.
    # On pose la dalle nous-memes, a cote du groupe : la phase
    # precedente peut avoir desamorce toutes celles du niveau, et
    # l'epreuve ne doit pas dependre de ce qu'elle a laisse.
    grid = grid_of(g)
    here = (g.w("PosX"), g.w("PosY"))
    rest = [(here[0] + dx, here[1] + dy) for dx, dy in DIRS
            if 0 <= here[0] + dx < MAPW and 0 <= here[1] + dy < MAPH
            and grid[here[1] + dy][here[0] + dx] == 0]
    for tx, ty in rest:
        g.mem.w8(g.addr("MapTerrain") + ty * MAPW + tx, T_TRAP)
        g.mem.w8(g.addr("MapParam") + ty * MAPW + tx, 1)   # lame de faux
        if not face_cell(g, (tx, ty)):
            continue
        heal(g)
        par = g.addr("MapParam") + ty * MAPW + tx
        g.mem.w8(par, g.mem.r8(par) | 0x80)     # le groupe sait, et y va
        hpa = sum(g.hero(i, "hr_Hp") for i in range(4))
        g.key(K_UP)
        now = grid_of(g)[ty][tx] & 0x0f
        hpb = sum(g.hero(i, "hr_Hp") for i in range(4))
        check(now != T_TRAP, "on enjambe une dalle reperee et elle reste"
              " armee", fails)
        check((g.w("PosX"), g.w("PosY")) == (tx, ty),
              "la dalle se detend mais le groupe reste en arriere", fails)
        check(hpb <= hpa, f"le piege rend des points de vie ({hpa} -> {hpb})",
              fails)
        print(f"  dalle enjambee sciemment : elle se detend, "
              f"PV {hpa} -> {hpb}")
        break
    else:
        check(False, "aucune dalle n'a pu etre enjambee sciemment", fails)


def mouse_test(g, fails):
    """Le pointeur suit-il, et un clic vaut-il la touche correspondante ?"""
    for x, y in ((160, 80), (0, 0), (319, 255), (48, 130)):
        check(g.mouse_to(x, y), f"le pointeur n'atteint pas {x},{y}", fails)
    got = (g.w("MouseX"), g.w("MouseY"))
    print(f"  le pointeur atteint les quatre coins, dernier {got}")

    # Le sprite materiel doit suivre au pixel : VSTART et VSTOP portent
    # chacun un neuvieme bit dans SPR0CTL, HSTART le sien.
    g.mouse_to(100, 60)
    ptr = g.addr("MousePointer")
    pos, ctl = g.mem.r16(ptr), g.mem.r16(ptr + 2)
    vstart = ((pos >> 8) & 0xff) | ((ctl & 4) << 6)
    hstart = ((pos & 0xff) << 1) | (ctl & 1)
    vstop = ((ctl >> 8) & 0xff) | ((ctl & 2) << 7)
    check((hstart - 0x81, vstart - 0x2c) == (100, 60),
          f"le sprite est en {hstart - 0x81},{vstart - 0x2c} et non 100,60",
          fails)
    check(vstop - vstart == 16, f"le sprite fait {vstop - vstart} lignes",
          fails)
    print(f"  sprite 0 pose en {hstart - 0x81},{vstart - 0x2c}, "
          f"{vstop - vstart} lignes")

    g.setw("UiMode", 0)                   # --- la rose des vents
    g.setw("NeedRedraw", 1)
    d0 = g.w("Dir")
    g.click(40, 80)                       # colonne de gauche : tourner
    check(g.w("Dir") == (d0 + 3) % 4, "cliquer a gauche ne tourne pas", fails)
    g.click(190, 80)                      # colonne de droite
    check(g.w("Dir") == d0, "cliquer a droite ne rend pas la direction",
          fails)
    before = (g.w("PosX"), g.w("PosY"))
    for _ in range(4):                    # avancer : il faut regarder un
        g.click(112, 30)                  # couloir, sinon on cogne un mur
        if (g.w("PosX"), g.w("PosY")) != before:
            break
        g.click(190, 80)
    moved = (g.w("PosX"), g.w("PosY")) != before
    check(moved, "cliquer en haut de la vue ne fait jamais avancer", fails)
    print(f"  rose des vents : {before} -> {(g.w('PosX'), g.w('PosY'))}")

    for hero in (2, 0, 3):                # --- le panneau du groupe
        g.click(PANEL_X + 40, PANEL_TOP + hero * PANEL_STEP + 8)
        check(g.w("SelHero") == hero,
              f"cliquer sur le bloc {hero} choisit {g.w('SelHero')}", fails)
    print("  un clic sur un bloc choisit son aventurier")

    g.key(K_I)                            # --- une liste : le sac
    check(g.w("UiMode") == 2, "le sac ne s'ouvre pas", fails)
    g.setw("InvTop", 0)
    g.setw("InvCursor", 0)
    g.setw("NeedRedraw", 1)
    g.click(80, 34 + 3 * 11 + 2)          # quatrieme ligne
    check(g.w("InvCursor") == 3,
          f"le clic vise la ligne {g.w('InvCursor')} au lieu de 3", fails)
    g.click(80, 34 + 1 * 11 + 2)
    check(g.w("InvCursor") == 1,
          f"le clic vise la ligne {g.w('InvCursor')} au lieu de 1", fails)
    print("  dans une liste, le clic pose le curseur sur la bonne ligne")

    g.click(80, 60, button=2)             # bouton droit : refermer
    check(g.w("UiMode") == 0, f"le bouton droit ne referme pas "
          f"(UiMode={g.w('UiMode')})", fails)
    print("  le bouton droit referme le panneau")


def heal(g):
    """Remet le groupe d'aplomb, pour eprouver un piege et non l'usure."""
    for i in range(4):
        base = g.addr("Heroes") + i * HR["hr_SIZEOF"]
        g.mem.w16(base + HR["hr_Hp"], g.hero(i, "hr_HpMax"))


def inv_used(g):
    base = g.addr("Inventory")
    return sum(1 for i in range(24) if g.mem.r8(base + i))


def walk_to(g, target, budget=80):
    """Marche jusqu'a une case precise, en reglant les combats croises."""
    for _ in range(budget):
        here = (g.w("PosX"), g.w("PosY"))
        if here == target:
            return True
        if g.w("InCombat"):
            for _ in range(40):
                if not g.w("InCombat"):
                    break
                g.key(K_A)
            if g.w("GameOver"):
                return False
            continue
        grid = grid_of(g)
        seen, q, path = {here: None}, collections.deque([here]), None
        while q:
            cur = q.popleft()
            if cur == target:
                path = []
                while cur:
                    path.append(cur)
                    cur = seen[cur]
                path.reverse()
                break
            for dx, dy in DIRS:
                nxt = (cur[0] + dx, cur[1] + dy)
                if not (0 <= nxt[0] < MAPW and 0 <= nxt[1] < MAPH):
                    continue
                t = grid[nxt[1]][nxt[0]] & 0x0f
                if nxt in seen or t in (T_WALL, T_NICHE, T_LEVER, T_GATE,
                                        T_SHOP, T_LEDGER, T_TRAP):
                    continue                 # les pieges se testent a part
                if t == T_LOCKED and g.w("KeyCount") == 0:
                    continue                 # sans cle, ce n'est pas un chemin
                seen[nxt] = cur
                q.append(nxt)
        if not path or len(path) < 2:
            return False
        step = path[1]
        if not face_cell(g, step):
            return False
        g.key(K_UP)
        if (g.w("PosX"), g.w("PosY")) == here:
            g.key(K_SPACE)                # porte ou enigme
            if g.w("UiMode") == 4:
                for answer in range(3):
                    g.key(K_1 + answer)
                    if g.w("UiMode") != 4:
                        break
                else:
                    g.key(K_ESC)
            g.key(K_UP)
            if (g.w("PosX"), g.w("PosY")) == here:
                return False
    return False


def check(cond, msg, fails):
    if not cond:
        fails.append(msg)
    return cond


if __name__ == "__main__":
    random.seed(12)
    fails = []
    g = Game()
    print("--- amorcage ---")
    check(g.w("Phase") == 2, "le jeu devrait demarrer sur l" + chr(39)
          + "accueil", fails)
    print(f"  ecran d'accueil, {len(g.syms)} symboles")

    print("--- le prologue ---")
    prolog_test(g, fails)

    print("--- creation du groupe ---")
    phase = create_party(g)
    check(phase == 1, f"phase {phase} apres creation, attendu 1", fails)
    for i in range(4):
        hp, hpm = g.hero(i, "hr_Hp"), g.hero(i, "hr_HpMax")
        lvl, wpn = g.hero(i, "hr_Level"), g.hero(i, "hr_Weapon")
        print(f"  {g.name(i):8s} classe {g.hero(i,'hr_Class')} "
              f"PV {hp}/{hpm} niv {lvl} arme {wpn} "
              f"FOR {g.hero(i,'hr_Str')} sorts {g.hero(i,'hr_MpMax')}")
        check(0 < hp == hpm, f"heros {i} : PV {hp}/{hpm}", fails)
        check(lvl == 1, f"heros {i} : niveau {lvl}", fails)
        check(wpn != 0, f"heros {i} : sans arme", fails)
        check(3 <= g.hero(i, "hr_Str") <= 18, f"heros {i} : FOR hors bornes", fails)

    print("--- exploration ---")
    moves = [K_UP, K_DOWN, K_LEFT, K_RIGHT, K_SPACE]
    start = (g.w("PosX"), g.w("PosY"))
    for _ in range(120):
        g.key(random.choice(moves))
        x, y = g.w("PosX"), g.w("PosY")
        if not check(0 <= x < MAPW and 0 <= y < MAPW, f"position {x},{y}", fails):
            break
        cell = g.mem.r8(g.addr("MapTerrain") + y * MAPW + x) & 0x0f
        if not check(cell not in (1, 5), f"dans un mur en {x},{y}", fails):
            break
    print(f"  depart {start} -> {(g.w('PosX'), g.w('PosY'))}, "
          f"or {g.w('Gold')}, combat {g.w('InCombat')}")

    print("--- combats ---")
    fights = rounds = 0
    monster = lambda c: (c & C_MASK) == C_MONSTER
    for _ in range(300):
        if fights >= 3:
            break
        if not g.w("InCombat") and not walk_towards(g, monster, 30):
            g.key(random.choice(moves))
            continue
        hp0 = g.w("MonHp")
        qui = (g.w("MonX"), g.w("MonY"), g.w("MonKind"))
        g.key(K_A)
        rounds += 1
        if not g.w("InCombat"):
            fights += 1
        # Le monstre suivant peut arriver dans la trame ou le precedent
        # tombe : on ne compare que si c'est le meme.
        if (g.w("MonX"), g.w("MonY"), g.w("MonKind")) == qui:
            check(g.sw("MonHp") <= hp0, "les PV du monstre remontent", fails)
        for i in range(4):
            hp, hpm = g.hero(i, "hr_Hp"), g.hero(i, "hr_HpMax")
            if not check(0 <= hp <= hpm, f"heros {i} PV {hp}/{hpm}", fails):
                break
        if g.w("GameOver"):
            break
    print(f"  {rounds} rounds, {fights} monstres vaincus, "
          f"or {g.w('Gold')}, PX {g.hero(0,'hr_Xp')}, "
          f"fin de partie {g.w('GameOver')}")
    check(fights > 0, "aucun combat mene : la partie combat n" + chr(39)
          + "a rien eprouve", fails)
    check(rounds == 0 or g.hero(0, "hr_Xp") > 0 or g.w("GameOver"),
          "des combats sans le moindre point d" + chr(39) + "experience", fails)

    print("--- l'echoppe ---")
    shop_test(g, fails)

    print("--- les pieges ---")
    trap_test(g, fails)

    print("--- les monstres marchent ---")
    walk_test(g, fails)

    print("--- la souris ---")
    mouse_test(g, fails)

    print("--- fuzzing clavier ---")
    allkeys = [K_UP, K_DOWN, K_LEFT, K_RIGHT, K_SPACE, K_A, K_S, K_F, K_I,
               K_C, K_E, K_U, K_D, K_TAB, K_RET, K_M_QW, K_M_AZ,
               K_L, K_P] \
        + [K_1 + i for i in range(8)]
    for n in range(800):
        g.key(random.choice(allkeys))
        ui, phase = g.w("UiMode"), g.w("Phase")
        if not check(ui <= 9, f"UiMode={ui}", fails):
            break
        if not check(phase <= 3, f"Phase={phase}", fails):
            break
        if not check(g.w("InvCursor") < 24, f"InvCursor={g.w('InvCursor')}", fails):
            break
        if not check(g.w("Level") < 3, f"Level={g.w('Level')}", fails):
            break
        if not check(g.sw("Gold") >= 0, f"Or negatif {g.sw('Gold')}", fails):
            break
    print(f"  800 touches au hasard, ui={g.w('UiMode')} phase={g.w('Phase')} "
          f"niveau {g.w('Level')} or {g.w('Gold')}")

    print("--- l'escalier qui remonte ---")
    stairs_test(g, fails)

    print("--- le grand registre ---")
    ledger_test(g, fails)

    print()
    if fails:
        print(f"{len(fails)} anomalie(s) :")
        for f in fails[:12]:
            print("  -", f)
        sys.exit(1)
    print("aucune anomalie detectee par ce banc")
