#!/usr/bin/env python3
"""Eprouve les capacites des creatures, une par une, dans le vrai combat.

Vingt-cinq monstres se battaient tous de la meme facon : un jet, des
degats. Une goule et un orc, c'etait le meme combat a un chiffre pres.
Chacun a maintenant ce qui le distingue -- poison, paralysie, energie
drainee, effroi, regeneration, peau epaisse, seconde attaque -- et cela
se juge en memoire, pas a la lecture.

On installe le monstre voulu, on lance des rounds, et on regarde ce
qu'il advient du groupe.

    python3 tools/test_combat.py
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import test_game as T

SP_POISON, SP_PARALYSE, SP_DRAIN, SP_FEAR = 0x01, 0x02, 0x04, 0x08
SP_REGEN, SP_DR, SP_MULTI = 0x10, 0x20, 0x40


def equ(name, src="crawl.s"):
    for line in open(os.path.join(ROOT, "src", src)):
        if line.split("\t")[0].strip() == name:
            body = line.split("=", 1)[1].split(";")[0].strip()
            return int(body.lstrip("$"), 16) if body.startswith("$") else int(body)
    raise SystemExit(f"{name} introuvable")


MT = {k: equ(k) for k in ("mt_Name", "mt_Hd", "mt_Ac", "mt_Atk", "mt_Dice",
                          "mt_Faces", "mt_Dmg", "mt_Xp", "mt_Special",
                          "mt_SIZEOF")}
HR = {k: equ(k) for k in ("hr_Hp", "hr_HpMax", "hr_Str", "hr_Stun",
                          "hr_StrLoss", "hr_SIZEOF")}


class Fight:
    def __init__(self, g):
        self.g = g
        self.table = g.addr("MonTypes")

    def name(self, kind):
        base = self.table + kind * MT["mt_SIZEOF"]
        out = b""
        for i in range(16):
            c = self.g.mem.r8(base + i)
            if not c:
                break
            out += bytes([c])
        return out.decode("latin-1")

    def special(self, kind):
        return self.g.mem.r16(self.table + kind * MT["mt_SIZEOF"]
                              + MT["mt_Special"])

    def start(self, kind, hp=None, sure_hit=True):
        """Engage ce monstre, le groupe d'aplomb et bien portant."""
        g = self.g
        g.setw("MonKind", kind)
        g.call(g.addr("StartCombat"))
        if hp is not None:
            g.setw("MonHp", hp)
            g.setw("MonHpMax", hp)
        if sure_hit:                       # on veut voir la capacite, pas
            base = self.table + kind * MT["mt_SIZEOF"]   # rater le jet
            g.mem.w16(base + MT["mt_Atk"], 40)
        for i in range(4):
            h = g.addr("Heroes") + i * HR["hr_SIZEOF"]
            g.mem.w16(h + HR["hr_Hp"], 60)
            g.mem.w16(h + HR["hr_HpMax"], 60)
            g.mem.w16(h + HR["hr_Str"], 14)
            g.mem.w16(h + HR["hr_Stun"], 0)
            g.mem.w16(h + HR["hr_StrLoss"], 0)
        g.setw("GameOver", 0)

    def hero(self, i, field):
        return self.g.mem.r16(self.g.addr("Heroes") + i * HR["hr_SIZEOF"]
                              + HR[field])

    def party(self, field):
        return [self.hero(i, field) for i in range(4)]

    def rounds(self, n):
        for _ in range(n):
            if self.g.w("GameOver") or not self.g.w("InCombat"):
                break
            self.g.call(self.g.addr("MonsterTurn"))


def check(cond, msg, fails):
    if not cond:
        fails.append(msg)
    return cond


def find(f, bit, nmon):
    return [k for k in range(nmon) if f.special(k) & bit]


if __name__ == "__main__":
    fails = []
    g = T.Game()
    T.create_party(g)
    f = Fight(g)
    nmon = equ("NMONSTERS", "tables.i")
    boss = equ("MON_BOSS", "tables.i")

    print("--- le bestiaire ---")
    armed = [k for k in range(nmon) if f.special(k)]
    print(f"  {nmon} creatures, {len(armed)} avec une capacite propre")
    check(len(armed) >= 12, f"seulement {len(armed)} creatures armees d'une "
          "capacite : le bestiaire reste plat", fails)
    check(f.special(boss), "le gardien n'a aucune capacite", fails)

    print("--- poison : la force s'en va, et ne descend pas sous trois ---")
    k = find(f, SP_POISON, nmon)[0]
    f.start(k, hp=400)
    f.rounds(30)
    lost = [14 - s for s in f.party("hr_Str")]
    print(f"  {f.name(k)} : force {f.party('hr_Str')}, perdue {lost}")
    check(any(l > 0 for l in lost), "le poison n'enleve jamais de force", fails)
    check(all(s >= 3 for s in f.party("hr_Str")),
          f"la force tombe sous trois : {f.party('hr_Str')}", fails)
    check(all(a == b for a, b in zip(lost, f.party("hr_StrLoss"))),
          "la force perdue n'est pas retenue pour le repos", fails)
    g.call(g.addr("PartyRest"))
    check(f.party("hr_Str") == [14] * 4,
          f"le repos ne rend pas la force : {f.party('hr_Str')}", fails)
    check(f.party("hr_StrLoss") == [0] * 4, "la dette de poison subsiste",
          fails)
    print(f"  apres le repos : force {f.party('hr_Str')}")

    print("--- paralysie : le heros perd des tours ---")
    k = find(f, SP_PARALYSE, nmon)[0]
    f.start(k, hp=400)
    f.rounds(20)
    stun = f.party("hr_Stun")
    print(f"  {f.name(k)} : tours a passer {stun}")
    check(any(s > 0 for s in stun), "personne n'est jamais paralyse", fails)
    # un heros fige ne frappe pas, et son compteur descend
    i = next(n for n, s in enumerate(stun) if s > 0)
    base = g.addr("Heroes") + i * HR["hr_SIZEOF"]
    before = f.hero(i, "hr_Stun")
    g.setw("MonHp", 400)
    hp0 = g.w("MonHp")
    g.call(g.addr("HeroAttack"), a6=base)
    check(f.hero(i, "hr_Stun") == before - 1,
          "le compteur de paralysie ne descend pas", fails)
    print(f"  le heros {i} passe son tour, compteur {before} -> "
          f"{f.hero(i, 'hr_Stun')}")

    print("--- energie drainee : les points de vie maximaux baissent ---")
    k = find(f, SP_DRAIN, nmon)[0]
    f.start(k, hp=400)
    f.rounds(25)
    mx = f.party("hr_HpMax")
    print(f"  {f.name(k)} : PV maximaux {mx}")
    check(any(m < 60 for m in mx), "personne ne perd de vie pour de bon",
          fails)
    check(all(m >= 1 for m in mx), f"des PV maximaux nuls : {mx}", fails)
    check(all(h <= m for h, m in zip(f.party("hr_Hp"), mx)),
          "les PV depassent le maximum apres un drain", fails)

    print("--- effroi : le heros n'ose plus frapper ---")
    k = find(f, SP_FEAR, nmon)[0]
    f.start(k, hp=400)
    f.rounds(20)
    print(f"  {f.name(k)} : tours a passer {f.party('hr_Stun')}")
    check(any(s > 0 for s in f.party("hr_Stun")),
          "l'effroi ne fige jamais personne", fails)

    print("--- peau epaisse : chaque coup est retenu ---")
    k = find(f, SP_DR, nmon)[0]
    base = f.table + k * MT["mt_SIZEOF"]
    keep = g.mem.r16(base + MT["mt_Special"])
    f.start(k, hp=4000)
    hero = g.addr("Heroes")
    g.mem.w16(hero + HR["hr_Stun"], 0)
    tot = 0
    for _ in range(12):
        before = g.w("MonHp")
        g.call(g.addr("CombatRound"))
        tot += before - g.w("MonHp")
    g.mem.w16(base + MT["mt_Special"], keep & ~SP_DR)   # la meme, sans peau
    f.start(k, hp=4000)
    g.mem.w16(base + MT["mt_Special"], keep & ~SP_DR)
    bare = 0
    for _ in range(12):
        before = g.w("MonHp")
        g.call(g.addr("CombatRound"))
        bare += before - g.w("MonHp")
    g.mem.w16(base + MT["mt_Special"], keep)
    print(f"  {f.name(k)} : {tot} degats encaisses avec la peau, "
          f"{bare} sans")
    check(tot < bare, f"la peau epaisse ne retient rien ({tot} contre "
          f"{bare})", fails)

    print("--- regeneration : la chair se referme ---")
    k = find(f, SP_REGEN, nmon)[0]
    f.start(k, hp=200)
    g.setw("MonHp", 100)
    before = g.w("MonHp")
    g.call(g.addr("MonsterTurn"))
    print(f"  {f.name(k)} : {before} -> {g.w('MonHp')} PV")
    check(g.w("MonHp") > before, "la creature ne se referme pas", fails)
    g.setw("MonHp", 200)                  # jamais au-dela du depart
    g.call(g.addr("MonsterTurn"))
    check(g.w("MonHp") <= 200, f"elle depasse ses PV de depart : "
          f"{g.w('MonHp')}", fails)
    print("  et jamais au-dela de ses points de depart")

    print("--- seconde attaque ---")
    k = find(f, SP_MULTI, nmon)[0]
    f.start(k, hp=400)
    base = f.table + k * MT["mt_SIZEOF"]
    g.mem.w16(base + MT["mt_Special"], SP_MULTI)   # rien d'autre en jeu
    g.mem.w16(base + MT["mt_Dice"], 1)
    g.mem.w16(base + MT["mt_Faces"], 1)
    g.mem.w16(base + MT["mt_Dmg"], 0)
    hp0 = sum(f.party("hr_Hp"))
    g.call(g.addr("MonsterTurn"))
    twice = hp0 - sum(f.party("hr_Hp"))
    g.mem.w16(base + MT["mt_Special"], 0)
    f.start(k, hp=400)
    g.mem.w16(base + MT["mt_Special"], 0)
    g.mem.w16(base + MT["mt_Dice"], 1)
    g.mem.w16(base + MT["mt_Faces"], 1)
    g.mem.w16(base + MT["mt_Dmg"], 0)
    hp0 = sum(f.party("hr_Hp"))
    g.call(g.addr("MonsterTurn"))
    once = hp0 - sum(f.party("hr_Hp"))
    print(f"  {f.name(k)} : {twice} degats avec la seconde attaque, "
          f"{once} sans")
    check(twice == 2 and once == 1,
          f"la seconde attaque ne double pas les coups ({twice} contre "
          f"{once})", fails)

    print("--- le gardien : la sortie se merite ---")
    levels = equ("LEVELS")
    g.setw("Level", levels - 1)           # au pied du dernier escalier
    g.setw("BossDead", 0)
    g.setw("GameOver", 0)
    g.setw("InCombat", 0)
    g.call(g.addr("Descend"))
    check(g.w("GameOver") == 0,
          "on sort du donjon sans avoir affronte le gardien", fails)
    check(g.w("InCombat") == 1, "le gardien ne se dresse pas", fails)
    check(g.w("MonKind") == boss,
          f"c'est {f.name(g.w('MonKind'))} qui garde la sortie, pas le "
          f"gardien", fails)
    print(f"  l'escalier reveille {f.name(g.w('MonKind'))}, "
          f"{g.w('MonHp')} PV, capacites {f.special(boss):#04x}")
    check(g.w("MonHp") > 100, f"le gardien ne tient que {g.w('MonHp')} PV",
          fails)

    base = f.table + boss * MT["mt_SIZEOF"]   # on l'abat : sa peau et sa
    keep = (g.mem.r16(base + MT["mt_Ac"]),    # garde ne sont pas le sujet
            g.mem.r16(base + MT["mt_Special"]))
    g.mem.w16(base + MT["mt_Ac"], 1)
    g.mem.w16(base + MT["mt_Special"], 0)
    g.setw("MonHp", 1)
    g.call(g.addr("CombatRound"))
    g.mem.w16(base + MT["mt_Ac"], keep[0])
    g.mem.w16(base + MT["mt_Special"], keep[1])
    check(g.w("BossDead") == 1, "le gardien tombe sans que rien ne le note",
          fails)
    check(g.w("InCombat") == 0, "le combat continue apres sa chute", fails)
    print("  abattu, la voie s'ouvre")

    g.setw("Level", levels - 1)
    g.setw("GameOver", 0)
    g.call(g.addr("Descend"))
    check(g.w("GameOver") == 1,
          "la sortie reste fermee alors que le gardien est tombe", fails)
    print("  l'escalier mene enfin dehors")

    print("--- le gardien est-il seulement battable ? ---")
    # Un boss se regle par la mesure, pas au jugé. On lui oppose un
    # groupe de niveau sept correctement arme, sans potion ni sort : il
    # doit l'emporter souvent, sans que ce soit acquis. Avec ses nombres
    # d'origine -- CA 22, 2d8+12, peau epaisse en plus de sa
    # regeneration -- il gagnait dix-sept fois sur dix-huit.
    def duel():
        g.setw("MonKind", boss)
        g.call(g.addr("StartCombat"))
        for i in range(4):
            h = g.addr("Heroes") + i * HR["hr_SIZEOF"]
            g.mem.w16(h + equ("hr_Level"), 7)
            g.mem.w16(h + HR["hr_HpMax"], 45)
            g.mem.w16(h + HR["hr_Hp"], 45)
            g.mem.w16(h + HR["hr_Str"], 16)
            g.mem.w16(h + HR["hr_Stun"], 0)
            g.mem.w16(h + equ("hr_Weapon"), 9)     # epee longue +1
        g.setw("GameOver", 0)
        n = 0
        while g.w("InCombat") and not g.w("GameOver") and n < 120:
            g.call(g.addr("CombatRound"))
            n += 1
        return (not g.w("GameOver") and not g.w("InCombat")), n

    N = 18
    issues = [duel() for _ in range(N)]
    wins = sum(1 for w, _ in issues if w)
    length = sum(n for _, n in issues) / N
    print(f"  {wins}/{N} victoires en {length:.1f} rounds, groupe de "
          f"niveau 7 sans potion ni sort")
    check(wins >= N // 3, f"le gardien ne perd que {wins} fois sur {N} : "
          "l'escalier serait ferme pour de bon", fails)
    check(wins <= N - 2, f"le gardien perd {wins} fois sur {N} : ce n'est "
          "plus un gardien", fails)
    check(length >= 4, f"le combat ne dure que {length:.1f} rounds : "
          "ce n'est pas un affrontement final", fails)

    print("--- la courbe des cinq etages ---")
    # Cinq etages ne valent rien s'ils forment un mur, ou s'ils sont
    # tous pareils. On oppose a chaque palier le groupe qu'on y aurait
    # plausiblement, et on regarde ce qu'un monstre lui coute.
    import re
    src = open(os.path.join(ROOT, "src", "tables.i")).read()
    tiers = [[int(v) for v in m.group(1).split(",")] for m in
             re.finditer(r"Encounter\d+:\n\tdc\.b\t([0-9,]+)", src)]
    levels = equ("LEVELS")
    check(len(tiers) == levels,
          f"{len(tiers)} paliers de rencontres pour {levels} etages", fails)

    profils = [(1, 12, 3), (3, 22, 3), (5, 32, 4), (6, 40, 9), (7, 46, 9)]
    cout = []
    for lv in range(levels):
        plvl, php, weapon = profils[lv]
        wins = taken = n = 0
        for kind in tiers[lv]:
            for _ in range(3):
                g.setw("MonKind", kind)
                g.call(g.addr("StartCombat"))
                for i in range(4):
                    h = g.addr("Heroes") + i * HR["hr_SIZEOF"]
                    g.mem.w16(h + equ("hr_Level"), plvl)
                    g.mem.w16(h + HR["hr_HpMax"], php)
                    g.mem.w16(h + HR["hr_Hp"], php)
                    g.mem.w16(h + HR["hr_Str"], 15)
                    g.mem.w16(h + HR["hr_Stun"], 0)
                    g.mem.w16(h + HR["hr_StrLoss"], 0)
                    g.mem.w16(h + equ("hr_Weapon"), weapon)
                g.setw("GameOver", 0)
                prev, k = sum(f.party("hr_Hp")), 0
                while g.w("InCombat") and not g.w("GameOver") and k < 60:
                    g.call(g.addr("CombatRound"))
                    k += 1
                    now = sum(f.party("hr_Hp"))
                    if now < prev:        # une montee de niveau soigne :
                        taken += prev - now   # on ne compte que les baisses
                    prev = now
                n += 1
                if not g.w("GameOver") and not g.w("InCombat"):
                    wins += 1
        part = 100.0 * taken / n / (4 * php)
        cout.append(part)
        print(f"  etage {lv + 1} : groupe niveau {plvl}, {100 * wins // n:3d} %"
              f" de victoires, un monstre coute {part:4.1f} % du groupe")
        check(100 * wins // n >= 80, f"etage {lv + 1} : le groupe ne gagne "
              f"que {100 * wins // n} % de ses combats", fails)
        check(part < 40, f"etage {lv + 1} : un seul monstre coute "
              f"{part:.0f} % du groupe, l'usure serait fatale", fails)
    check(cout[-1] > cout[0] * 1.5,
          f"le dernier etage ({cout[-1]:.1f} %) ne coute pas plus cher que "
          f"le premier ({cout[0]:.1f} %) : la courbe est plate", fails)

    print()
    if fails:
        print(f"{len(fails)} anomalie(s) :")
        for x in fails:
            print("  -", x)
        sys.exit(1)
    print("chaque creature se bat a sa maniere")
