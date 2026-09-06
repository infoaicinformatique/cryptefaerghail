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
K_A, K_S, K_F, K_I, K_C, K_E, K_U, K_D = 0x20, 0x21, 0x23, 0x17, 0x33, 0x12, 0x16, 0x22

hr_SIZEOF = 46 + 8                       # relu ci-dessous depuis le source


def read_equ(name, default):
    src = open(os.path.join(ROOT, "src", "crawl.s")).read()
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
        top, end = self.addr("WaitVBlank"), self.addr("WaitBlit")
        return (top <= pc < end and self.w("NeedRedraw") == 0
                and self.w("DrawReady") == 0)

    def key(self, code, slices=80):
        self.press(code)
        err = self.run(slices=slices, idle=self.idle)
        assert err is None or "termine" in err, err

    def keys(self, seq, slices=40):
        for k in seq:
            self.key(k, slices)


def create_party(g, classes=(0, 6, 1, 5)):
    """Choix de classe, acceptation des jets, nom par defaut."""
    for c in classes:
        g.key(K_1 + c)                   # touche 1 a 8
        g.key(K_RET)                     # garder les caracteristiques
        g.key(K_RET)                     # garder le nom propose
    return g.w("Phase")


def check(cond, msg, fails):
    if not cond:
        fails.append(msg)
    return cond


if __name__ == "__main__":
    random.seed(12)
    fails = []
    g = Game()
    print("--- amorcage ---")
    check(g.w("Phase") == 0, "le jeu devrait demarrer en creation", fails)
    print(f"  phase de creation, {len(g.syms)} symboles")

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
    for _ in range(400):
        if g.w("InCombat"):
            hp0 = g.w("MonHp")
            g.key(K_A)
            rounds += 1
            if not g.w("InCombat"):
                fights += 1
            check(g.sw("MonHp") <= hp0, "les PV du monstre remontent", fails)
        else:
            g.key(random.choice(moves))
        for i in range(4):
            hp, hpm = g.hero(i, "hr_Hp"), g.hero(i, "hr_HpMax")
            if not check(0 <= hp <= hpm, f"heros {i} PV {hp}/{hpm}", fails):
                break
        if g.w("GameOver"):
            break
    print(f"  {rounds} rounds, {fights} monstres vaincus, "
          f"or {g.w('Gold')}, PX {g.hero(0,'hr_Xp')}, "
          f"fin de partie {g.w('GameOver')}")

    print("--- fuzzing clavier ---")
    allkeys = [K_UP, K_DOWN, K_LEFT, K_RIGHT, K_SPACE, K_A, K_S, K_F, K_I,
               K_C, K_E, K_U, K_D, K_TAB, K_RET, K_M_QW, K_M_AZ] \
        + [K_1 + i for i in range(8)]
    for n in range(800):
        g.key(random.choice(allkeys))
        ui, phase = g.w("UiMode"), g.w("Phase")
        if not check(ui <= 5, f"UiMode={ui}", fails):
            break
        if not check(phase <= 1, f"Phase={phase}", fails):
            break
        if not check(g.w("InvCursor") < 24, f"InvCursor={g.w('InvCursor')}", fails):
            break
        if not check(g.w("Level") < 3, f"Level={g.w('Level')}", fails):
            break
        if not check(g.sw("Gold") >= 0, f"Or negatif {g.sw('Gold')}", fails):
            break
    print(f"  800 touches au hasard, ui={g.w('UiMode')} phase={g.w('Phase')} "
          f"niveau {g.w('Level')} or {g.w('Gold')}")

    print()
    if fails:
        print(f"{len(fails)} anomalie(s) :")
        for f in fails[:12]:
            print("  -", f)
        sys.exit(1)
    print("aucune anomalie detectee par ce banc")
