#!/usr/bin/env python3
"""Pilote le jeu emule avec un but : atteindre les monstres et les objets.

La marche au hasard ne sort jamais du premier couloir. Ce pilote lit la
carte en memoire, calcule un chemin, oriente le groupe et frappe les
touches qu'un joueur frapperait -- ouvrir les portes comprises. On
verifie ensuite les invariants des combats et de l'inventaire.

    python3 tools/play_game.py
"""
import collections
import os
import random
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import test_game as T

MAPW = MAPH = 24
T_FLOOR, T_WALL, T_DOOR, T_STAIRS, T_LOCKED, T_NICHE, T_RUNE = range(7)
T_LEVER, T_GATE = 7, 8
C_CHEST, C_MONSTER, C_ITEM, C_MASK = 0x10, 0x20, 0x30, 0x30
DIRS = [(0, -1), (1, 0), (0, 1), (-1, 0)]     # meme ordre que DirTable


def path_to(grid, start, target):
    """Chemin jusqu'a une case precise."""
    seen = {start: None}
    q = collections.deque([start])
    while q:
        cur = q.popleft()
        if cur == target:
            out = []
            while cur:
                out.append(cur)
                cur = seen[cur]
            return out[::-1]
        for dx, dy in DIRS:
            nxt = (cur[0] + dx, cur[1] + dy)
            if not (0 <= nxt[0] < MAPW and 0 <= nxt[1] < MAPH):
                continue
            if nxt in seen or not passable(grid[nxt[1]][nxt[0]]):
                continue
            seen[nxt] = cur
            q.append(nxt)
    return None


def find(grid, kind):
    return [(x, y) for y in range(MAPH) for x in range(MAPW)
            if grid[y][x] & 0x0f == kind]


def goto(g, target, log=None, on_combat=None):
    """Marche jusqu'a la case voulue ; False si la route se ferme.

    Un monstre peut se trouver sur le chemin : le combat s'engage et le
    jeu refuse alors tout deplacement, y compris les demi-tours. Sans
    on_combat pour le vider, le parcours restait plante la et le banc
    n'annoncait plus que des cases bloquees."""
    for _ in range(120):
        if g.w("InCombat"):
            if on_combat is None:
                return False
            on_combat(g)
            if g.w("GameOver"):
                return False
        here = (g.w("PosX"), g.w("PosY"))
        if here == target:
            return True
        path = path_to(terrain(g), here, target)
        if not path or len(path) < 2:
            return False
        if not step_to(g, path[1], log if log is not None else []):
            return False
    return False


def pull_levers(g, fails=None, stats=None):
    """Va tirer chaque levier, et verifie que sa herse se leve."""
    done = 0

    def on_combat(gg):
        fight(gg, fails if fails is not None else [],
              stats if stats is not None else collections.defaultdict(int))

    for lx, ly in find(terrain(g), T_LEVER):
        grid = terrain(g)
        par = g.addr("MapParam")
        num = g.mem.r8(par + ly * MAPW + lx) & 0x7f
        mates = [(x, y) for x, y in find(grid, T_GATE)
                 if g.mem.r8(par + y * MAPW + x) & 0x7f == num]
        spot = next(((lx + dx, ly + dy) for dx, dy in DIRS
                     if 0 <= lx + dx < MAPW and 0 <= ly + dy < MAPH
                     and passable(grid[ly + dy][lx + dx])), None)
        if spot is None or not goto(g, spot, on_combat=on_combat):
            continue
        if g.w("GameOver"):
            break
        if not face(g, DIRS.index((lx - spot[0], ly - spot[1])), []):
            continue
        g.key(T.K_SPACE)
        after = terrain(g)
        if mates and all(after[y][x] & 0x0f == T_GATE for x, y in mates):
            if fails is not None:
                fails.append(f"le levier {num} n'ouvre pas sa herse")
        else:
            done += 1
            if stats is not None:
                stats["levers"] += 1
    return done


def inv_count(g):
    base = g.addr("Inventory")
    return sum(1 for i in range(24) if g.mem.r8(base + i))


def terrain(g):
    base = g.addr("MapTerrain")
    return [[g.mem.r8(base + y * MAPW + x) for x in range(MAPW)]
            for y in range(MAPH)]


def passable(cell):
    t = cell & 0x0f
    return t not in (T_WALL, T_NICHE, T_LEVER, T_GATE)


def bfs(grid, start, want):
    """Chemin vers la premiere case satisfaisant want()."""
    seen = {start: None}
    q = collections.deque([start])
    while q:
        cur = q.popleft()
        if cur != start and want(grid[cur[1]][cur[0]]):
            path = []
            while cur:
                path.append(cur)
                cur = seen[cur]
            return path[::-1]
        for dx, dy in DIRS:
            nxt = (cur[0] + dx, cur[1] + dy)
            if not (0 <= nxt[0] < MAPW and 0 <= nxt[1] < MAPH):
                continue
            if nxt in seen or not passable(grid[nxt[1]][nxt[0]]):
                continue
            seen[nxt] = cur
            q.append(nxt)
    return None


def face(g, want, log):
    """Tourne jusqu'a regarder dans la bonne direction."""
    for _ in range(4):
        if g.w("Dir") == want:
            return True
        g.key(T.K_RIGHT)
        log.append(("tourne", g.w("Dir")))
    return g.w("Dir") == want


def step_to(g, target, log):
    """Un pas vers une case adjacente ; ouvre la porte si besoin."""
    dx = target[0] - g.w("PosX")
    dy = target[1] - g.w("PosY")
    if (dx, dy) not in DIRS:
        return False
    if not face(g, DIRS.index((dx, dy)), log):
        return False
    before = (g.w("PosX"), g.w("PosY"))
    g.key(T.K_UP)
    if (g.w("PosX"), g.w("PosY")) != before:
        return True
    g.key(T.K_SPACE)                      # porte, rune, levier
    if g.w("UiMode") == 4:                # une enigme barre le passage
        for answer in range(3):
            g.key(T.K_1 + answer)
            if g.w("UiMode") != 4:
                break
        else:
            g.key(T.K_ESC)
        log.append(("enigme", g.w("RiddleIdx")))
    g.key(T.K_UP)
    return (g.w("PosX"), g.w("PosY")) != before


def exercise_ui(g, fails, stats):
    """Ouvre la fiche, le sac, le menu de sorts et tape dedans."""
    for hero in range(4):
        g.key(T.K_1 + hero)
        g.key(T.K_C)                      # fiche d'aventure
        if g.w("UiMode") != 1:
            fails.append(f"la fiche ne s'ouvre pas (UiMode={g.w('UiMode')})")
        g.key(T.K_C)
        g.key(T.K_I)                      # sac a dos
        if g.w("UiMode") != 2:
            fails.append(f"le sac ne s'ouvre pas (UiMode={g.w('UiMode')})")
        for _ in range(6):
            g.key(T.K_DOWN)
        g.key(T.K_E)                      # equiper
        g.key(T.K_U)                      # utiliser
        g.key(T.K_I)
        g.key(0x37)                       # carte du niveau
        if g.w("UiMode") != 5:
            fails.append("la carte ne s'ouvre pas (M)")
        g.key(0x37)
        if g.w("UiMode"):
            fails.append("la carte ne se referme pas")
        g.key(0x28)                       # grimoire
        if g.w("UiMode") != 6:
            fails.append("le grimoire ne s'ouvre pas (L)")
        for _ in range(4):
            g.key(T.K_DOWN)
        g.key(0x28)
        g.key(0x19)                       # reglages
        if g.w("UiMode") != 7:
            fails.append("les reglages ne s'ouvrent pas (P)")
        g.key(0x19)
        g.key(T.K_S)                      # sorts hors combat
        if g.w("UiMode") == 3:  # noqa: E501
            stats["menus"] += 1
            for n in range(10):
                g.key(T.K_1 + n)
                if g.w("UiMode") != 3:
                    break
            g.key(T.K_ESC)                # ESC ne ferme qu'un panneau :
        if g.w("UiMode"):                 # dans la vue, il quitte le jeu
            fails.append(f"UiMode reste a {g.w('UiMode')}")
        check_state(g, fails)


def check_state(g, fails):
    """Invariants que rien ne doit briser."""
    for i in range(4):
        hp, hpm = g.hero(i, "hr_Hp"), g.hero(i, "hr_HpMax")
        if not 0 <= hp <= hpm:
            fails.append(f"heros {i} : PV {hp}/{hpm}")
        mp, mpm = g.hero(i, "hr_Mp"), g.hero(i, "hr_MpMax")
        if not 0 <= mp <= max(mpm, 0):
            fails.append(f"heros {i} : sorts {mp}/{mpm}")
        lvl = g.hero(i, "hr_Level")
        if not 1 <= lvl <= 10:
            fails.append(f"heros {i} : niveau {lvl}")
        if not 0 <= g.hero(i, "hr_Weapon") <= 28:
            fails.append(f"heros {i} : arme {g.hero(i, 'hr_Weapon')}")
    if g.sw("Gold") < 0:
        fails.append(f"or negatif : {g.sw('Gold')}")
    if not 0 <= g.w("Level") < 3:
        fails.append(f"niveau de donjon {g.w('Level')}")
    if not 0 <= g.w("UiMode") <= 4:
        fails.append(f"UiMode {g.w('UiMode')}")
    base = g.addr("Inventory")
    for i in range(24):
        v = g.mem.r8(base + i)
        if v > 28:
            fails.append(f"objet inconnu {v} en case {i}")


def cast_first(g, stats):
    """Ouvre le menu de sorts du heros courant et lance le premier."""
    g.key(T.K_S)
    if g.w("UiMode") != 3:
        return False
    g.key(T.K_1)
    stats["spells"] += 1
    if g.w("UiMode") == 3:                # rien de lancable : on referme
        g.key(T.K_ESC)
        return False
    return True


def heal_up(g, stats):
    """Entre deux combats : potions et sorts de soin sur les blesses."""
    for i in range(4):
        if g.hero(i, "hr_Hp") * 2 > g.hero(i, "hr_HpMax"):
            continue
        g.key(T.K_1 + i)
        for slot in range(3):             # un lanceur soigne le groupe
            if g.hero(slot, "hr_Mp") > 0:
                g.key(T.K_1 + slot)
                if cast_first(g, stats):
                    stats["heals"] += 1
                    break
        g.key(T.K_I)                      # sinon, une potion
        if g.w("UiMode") == 2:
            for _ in range(4):
                g.key(T.K_U)
                g.key(T.K_DOWN)
            g.key(T.K_I)
        break


def fight(g, fails, stats):
    """Frappe -- et lance un sort de temps en temps -- jusqu'a la fin."""
    guard = 0
    while g.w("InCombat") and guard < 60:
        hp0 = g.sw("MonHp")
        guard += 1
        if guard % 4 == 2:
            g.key(T.K_1 + random.randrange(4))
            if cast_first(g, stats):
                stats["rounds"] += 1
                continue
        g.key(T.K_A)
        stats["rounds"] += 1
        if g.w("InCombat") and g.sw("MonHp") > hp0:
            fails.append(f"PV du monstre en hausse : {hp0} -> {g.sw('MonHp')}")
        for i in range(4):
            hp, hpm = g.hero(i, "hr_Hp"), g.hero(i, "hr_HpMax")
            if not 0 <= hp <= hpm:
                fails.append(f"heros {i} : PV {hp}/{hpm} en combat")
    if guard >= 60:
        fails.append("combat interminable (60 rounds)")
    else:
        stats["fights"] += 1
    if not g.w("GameOver"):
        heal_up(g, stats)


def main():
    random.seed(7)
    fails, log = [], []
    stats = {"rounds": 0, "fights": 0, "steps": 0, "items": 0,
             "spells": 0, "menus": 0, "heals": 0,
             "levers": 0}
    g = T.Game()
    T.create_party(g)
    if g.w("Phase") != 1:
        print("la creation n'aboutit pas"); return 1

    goals = [
        ("monstre", lambda c: c & C_MASK == C_MONSTER),
        ("objet", lambda c: c & C_MASK == C_ITEM),
        ("coffre", lambda c: c & C_MASK == C_CHEST),
        ("escalier", lambda c: c & 0x0f == T_STAIRS),
    ]
    exercise_ui(g, fails, stats)
    levers = len(find(terrain(g), T_LEVER))
    pull_levers(g, fails, stats)
    if levers and not stats["levers"]:
        fails.append(f"{levers} levier(s) sur le niveau, aucun tire")
    for tour in range(40):
        grid = terrain(g)
        here = (g.w("PosX"), g.w("PosY"))
        path = None
        for label, want in goals:
            path = bfs(grid, here, want)
            if path:
                break
        if not path:
            log.append(("plus de but atteignable", here))
            break
        for cell in path[1:]:
            if not step_to(g, cell, log):
                log.append(("bloque", here, cell))
                break
            stats["steps"] += 1
            check_state(g, fails)
            if g.w("InCombat"):
                fight(g, fails, stats)
                if g.w("GameOver"):
                    break
        if g.w("GameOver"):
            log.append(("groupe aneanti", g.w("Level")))
            break

    if not stats["steps"]:
        fails.append("le groupe n'a pas fait un pas : le parcours n'eprouve rien")
    print(f"  {stats['steps']} pas, {stats['fights']} combats, "
          f"{stats['rounds']} rounds, niveau {g.w('Level')}, "
          f"or {g.w('Gold')}, PX {g.hero(0, 'hr_Xp')}, "
          f"objets {inv_count(g)}, sorts {stats['spells']}, "
          f"soins {stats['heals']}, leviers {stats['levers']}, "
          f"fin {g.w('GameOver')}")
    for i in range(4):
        print(f"  {g.name(i):8s} PV {g.hero(i,'hr_Hp')}/{g.hero(i,'hr_HpMax')} "
              f"niv {g.hero(i,'hr_Level')} PX {g.hero(i,'hr_Xp')}")
    for entry in log[-6:]:
        print("   .", entry)
    if fails:
        print(f"{len(fails)} anomalie(s) :")
        for f in fails[:10]:
            print("  -", f)
        return 1
    print("  aucune anomalie sur ce parcours")
    return 0


if __name__ == "__main__":
    sys.exit(main())
