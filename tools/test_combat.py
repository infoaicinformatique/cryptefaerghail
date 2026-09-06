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
                          "mt_Faces", "mt_Dmg", "mt_Xp", "mt_Gold",
                          "mt_Special", "mt_Pack", "mt_SIZEOF")}
HR = {k: equ(k) for k in ("hr_Hp", "hr_HpMax", "hr_Str", "hr_Stun",
                          "hr_StrLoss", "hr_Xp", "hr_SIZEOF")}


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

    def pack(self, kind):
        return self.g.mem.r16(self.table + kind * MT["mt_SIZEOF"]
                              + MT["mt_Pack"])

    def start(self, kind, hp=None, sure_hit=True, count=1):
        """Engage ce monstre, le groupe d'aplomb et bien portant.

        Les creatures faibles se presentent en bande : on n'en garde
        qu'une pour eprouver une capacite, sinon la mesure compterait
        les coups de toute la troupe."""
        g = self.g
        g.setw("MonKind", kind)
        g.call(g.addr("StartCombat"))
        if count is not None:
            g.setw("MonCount", count)
            g.setw("MonPack", count)
        g.setw("MonRange", 0)              # la distance est comblee : ce
                                           # qu'on mesure ici, c'est la
                                           # capacite, pas l'approche
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

    print("--- la bande : ils ne viennent plus un par un ---")
    levels_n = equ("LEVELS")
    # Un monstre seul, c'est une machine a sous. Le SRD range ses
    # creatures par facteur de puissance, et c'est lui qui dit combien
    # s'en presentent : le kobold a quatre, le troll seul.
    weak = [k for k in range(nmon) if f.pack(k) >= 3]
    lone = [k for k in range(nmon) if f.pack(k) == 1]
    print(f"  {len(weak)} creatures qui viennent en nombre, "
          f"{len(lone)} qui viennent seules")
    check(weak, "aucune creature ne vient en bande", fails)
    check(lone, "toutes les creatures viennent en bande", fails)
    check(f.pack(boss) == 1, "le gardien vient accompagne", fails)

    # StartCombat doit tirer entre une et pack creatures, et jamais plus.
    k = weak[0]
    was = g.w("Level")
    bands = {}
    for lv in range(levels_n):
        g.setw("Level", lv)
        seen = set()
        for _ in range(60):
            f.start(k, count=None)
            seen.add(g.w("MonCount"))
        bands[lv] = sorted(seen)
        check(min(seen) >= 1 and max(seen) <= f.pack(k),
              f"etage {lv + 1} : bande hors bornes {sorted(seen)}", fails)
        # La bande grossit avec la profondeur : deux au premier etage,
        # trois au deuxieme, puis autant que l'espece en compte.
        check(max(seen) <= lv + 2, f"etage {lv + 1} : jusqu'a {max(seen)} "
              f"creatures d'un coup, la ou {lv + 2} etait la borne", fails)
    print(f"  {f.name(k)} (au plus {f.pack(k)}) : "
          + ", ".join(f"etage {lv + 1} {b}" for lv, b in bands.items()))
    check(max(bands[levels_n - 1]) > 1,
          f"{f.name(k)} ne vient jamais a plusieurs", fails)
    check(max(bands[levels_n - 1]) > max(bands[0]),
          "la bande ne grossit pas d'un etage a l'autre", fails)
    g.setw("Level", was)
    f.start(k, count=None)
    check(g.w("MonPack") == g.w("MonCount"),
          "le compte de depart ne suit pas la bande", fails)

    # Toute la bande riposte : trois creatures font trois fois plus de
    # mal qu'une seule, a coups fixes.
    base = f.table + k * MT["mt_SIZEOF"]
    hit = []
    for n in (1, 3):
        f.start(k, hp=400, count=n)
        g.mem.w16(base + MT["mt_Special"], 0)     # rien que le coup nu
        g.mem.w16(base + MT["mt_Dice"], 1)
        g.mem.w16(base + MT["mt_Faces"], 1)
        g.mem.w16(base + MT["mt_Dmg"], 0)
        hp0 = sum(f.party("hr_Hp"))
        g.call(g.addr("MonsterTurn"))
        hit.append(hp0 - sum(f.party("hr_Hp")))
    print(f"  seule elle porte {hit[0]} coup, a trois elles en portent "
          f"{hit[1]}")
    check(hit == [1, 3], f"la bande ne riposte pas au complet : {hit}", fails)

    # L'effroi ne saisit que celle de devant : les autres avancent.
    # Sinon un seul sort figeait toute une bande, et la magie devenait
    # la seule reponse a tout.
    f.start(k, hp=400, count=3)
    g.mem.w16(base + MT["mt_Special"], 0)
    g.mem.w16(base + MT["mt_Dice"], 1)
    g.mem.w16(base + MT["mt_Faces"], 1)
    g.mem.w16(base + MT["mt_Dmg"], 0)
    g.setw("MonStun", 1)
    hp0 = sum(f.party("hr_Hp"))
    g.call(g.addr("MonsterTurn"))
    reste = hp0 - sum(f.party("hr_Hp"))
    print(f"  celle de devant terrifiee, les deux autres portent {reste} coups")
    check(reste == 2, f"l'effroi fige toute la bande ({reste} coups sur "
          "deux attendus)", fails)
    check(g.w("MonStun") == 0, "l'effroi ne se dissipe pas", fails)

    # Chacune tombe pour son compte : or et experience a chaque fois, et
    # le combat ne s'acheve qu'avec la derniere.
    f.start(k, hp=1, count=3)
    gold0, xp0 = g.w("Gold"), f.hero(0, "hr_Xp")
    g.call(g.addr("MonsterDies"))
    check(g.w("InCombat") == 1, "le combat s'acheve a la premiere tombee",
          fails)
    check(g.w("MonCount") == 2, f"il en reste {g.w('MonCount')} sur trois",
          fails)
    check(g.w("MonHp") > 0, "la suivante s'avance deja morte", fails)
    gold1, xp1 = g.w("Gold"), f.hero(0, "hr_Xp")
    check(xp1 > xp0, "une creature tombee ne rapporte rien", fails)
    g.call(g.addr("MonsterDies"))
    g.call(g.addr("MonsterDies"))
    check(g.w("InCombat") == 0, "la bande abattue, le combat continue", fails)
    check(g.w("MonCount") == 0, f"MonCount={g.w('MonCount')} apres la "
          "derniere", fails)
    print(f"  trois tombees : or {gold0} -> {g.w('Gold')}, "
          f"PX {xp0} -> {f.hero(0, 'hr_Xp')}")
    check(g.w("Gold") > gold1 > gold0, "l'or ne vient pas creature par "
          "creature", fails)
    print("--- l'approche : l'arc a une salve d'avance ---")
    # L'arc court existait, et rien ne le distinguait d'une lame : le
    # rodeur etait un guerrier en moins. Le premier round se joue a
    # distance -- seul l'arc porte, la bande ne riposte pas -- puis
    # elle comble le couloir.
    BOW = 7                               # arc court, cf. gen_tables.py
    SWORD = 3                             # epee longue
    def salve(arme):
        f.start(weak[0], hp=400, count=1)
        g.setw("MonRange", 1)
        for i in range(4):
            h = g.addr("Heroes") + i * HR["hr_SIZEOF"]
            g.mem.w16(h + equ("hr_Weapon"), arme)
            g.mem.w16(h + HR["hr_Hp"], 60)
        hp0 = g.w("MonHp")
        vif0 = sum(f.party("hr_Hp"))
        g.call(g.addr("CombatRound"))
        return hp0 - g.w("MonHp"), vif0 - sum(f.party("hr_Hp")), g.w("MonRange")

    tire, recu, loin = salve(BOW)
    print(f"  a l'arc : {tire} degats portes, {recu} recus, "
          f"distance {'comblee' if not loin else 'gardee'}")
    check(tire > 0, "les archers ne tirent pas pendant l'approche", fails)
    check(recu == 0, f"la bande frappe alors qu'elle est encore loin "
          f"({recu} degats)", fails)
    check(loin == 0, "la distance ne se comble jamais", fails)
    lame, recu2, _ = salve(SWORD)
    print(f"  a la lame : {lame} degats portes, {recu2} recus")
    check(lame == 0, f"une lame porte a distance ({lame} degats)", fails)
    # une fois la distance comblee, la lame reprend ses droits
    g.setw("MonRange", 0)
    hp0 = g.w("MonHp")
    g.call(g.addr("CombatRound"))
    check(hp0 - g.w("MonHp") > 0, "la lame ne porte plus une fois au "
          "contact", fails)
    # le gardien, lui, barre l'escalier : on lui marche dessus
    g.setw("MonKind", boss)
    g.call(g.addr("StartCombat"))
    check(g.w("MonRange") == 0, "le gardien laisse le temps d'une salve",
          fails)
    g.setw("InCombat", 0)

    print("--- la halte : souffler, et ce qu'elle reveille ---")
    # Les creatures viennent en bande depuis peu, et la halte entre
    # deux etages ne suffisait plus : le banc de jeu voyait le groupe
    # tomber au deuxieme etage faute d'avoir jamais pu souffler.
    g.setw("InCombat", 0)
    g.setw("GameOver", 0)
    g.setw("Level", 0)
    calmes = troubles = 0
    for _ in range(40):
        g.setw("InCombat", 0)
        for i in range(4):
            h = g.addr("Heroes") + i * HR["hr_SIZEOF"]
            g.mem.w16(h + HR["hr_HpMax"], 40)
            g.mem.w16(h + HR["hr_Hp"], 4)
            g.mem.w16(h + HR["hr_StrLoss"], 0)
        avant = sum(f.party("hr_Hp"))
        g.call(g.addr("CampRest"))
        apres = sum(f.party("hr_Hp"))
        if g.w("InCombat"):
            troubles += 1
            check(apres == avant, "une halte troublee soigne quand meme "
                  f"({avant} -> {apres})", fails)
            check(g.w("MonCount") >= 1, "la halte est troublee par personne",
                  fails)
        else:
            calmes += 1
            check(apres > avant, f"une halte calme ne rend rien "
                  f"({avant} -> {apres})", fails)
    print(f"  40 haltes : {calmes} calmes, {troubles} troublees")
    check(calmes > 0 and troubles > 0,
          f"la halte est toujours pareille ({calmes} calmes, "
          f"{troubles} troublees)", fails)
    # Ce qui rode doit venir de l'etage, pas du fond du bestiaire.
    g.setw("Level", 0)
    vus = set()
    for _ in range(60):
        g.setw("InCombat", 0)
        g.call(g.addr("WanderingFoe"))
        vus.add(g.w("MonKind"))
    print(f"  au premier etage, ce qui rode : {sorted(vus)}")
    check(len(vus) > 1, "toujours la meme creature en maraude", fails)
    check(max(vus) < 12, f"une creature du fond ({max(vus)}) rode au "
          "premier etage", fails)
    g.setw("InCombat", 0)
    g.setw("GameOver", 0)

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
    g.setw("MonRange", 0)                 # il est deja sur vous
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
    # groupe de niveau sept correctement arme, sans potion ni sort, et
    # on compte : ni mur ni formalite. Avec ses nombres d'origine -- CA
    # 22, 2d8+12, peau epaisse en plus de sa regeneration -- c'est lui
    # qui gagnait dix-sept fois sur dix-huit ; a CA 18 et 1d10+6 le
    # groupe l'emportait trente et une fois sur quarante.
    #
    # Quatre-vingts duels, pas dix-huit : a dix-huit l'ecart-type vaut
    # deux victoires, a quarante il en vaut trois, et une borne posee a
    # moins de deux ecarts-types de la moyenne se declenche toute seule
    # -- c'est arrive, avec les trois quarts pour borne haute alors que
    # le groupe gagne pres de deux fois sur trois. A quatre-vingts, le
    # groupe l'emporte 51 fois : les bornes vont du quart aux quatre
    # cinquiemes, soit trois ecarts-types de marge de chaque cote.
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

    N = 80
    issues = [duel() for _ in range(N)]
    wins = sum(1 for w, _ in issues if w)
    length = sum(n for _, n in issues) / N
    print(f"  {wins}/{N} victoires en {length:.1f} rounds, groupe de "
          f"niveau 7 sans potion ni sort")
    check(wins >= N // 4, f"le gardien ne perd que {wins} fois sur {N} : "
          "l'escalier serait ferme pour de bon", fails)
    check(wins <= N * 4 // 5, f"le gardien perd {wins} fois sur {N} : ce "
          "n'est plus un gardien", fails)
    check(length >= 4, f"le combat ne dure que {length:.1f} rounds : "
          "ce n'est pas un affrontement final", fails)

    print("--- la courbe des cinq etages ---")
    # Cinq etages ne valent rien s'ils forment un mur, ou s'ils sont
    # tous pareils. On oppose a chaque palier le groupe qu'on y aurait
    # plausiblement, et on regarde ce qu'une rencontre lui coute.
    #
    # Une rencontre, pas un monstre : depuis que les creatures faibles
    # arrivent en bande, la taille de la troupe est tiree au sort, et
    # trois duels par espece ne mesuraient plus rien -- un etage passait
    # de 5 % a 1 % d'une execution a l'autre. Huit, et la courbe tient.
    import re
    src = open(os.path.join(ROOT, "src", "tables.i")).read()
    tiers = [[int(v) for v in m.group(1).split(",")] for m in
             re.finditer(r"Encounter\d+:\n\tdc\.b\t\d+\n\tdc\.b\t([0-9,]+)",
                         src)]
    levels = equ("LEVELS")
    check(len(tiers) == levels,
          f"{len(tiers)} paliers de rencontres pour {levels} etages", fails)

    profils = [(1, 12, 3), (3, 22, 3), (5, 32, 4), (6, 40, 9), (7, 46, 9)]
    cout = []
    for lv in range(levels):
        plvl, php, weapon = profils[lv]
        g.setw("Level", lv)               # la bande grossit avec l'etage
        wins = taken = n = 0
        for kind in tiers[lv]:
            for _ in range(8):
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
              f" de victoires, une rencontre coute {part:4.1f} % du groupe")
        check(100 * wins // n >= 80, f"etage {lv + 1} : le groupe ne gagne "
              f"que {100 * wins // n} % de ses combats", fails)
        check(part < 40, f"etage {lv + 1} : une rencontre coute "
              f"{part:.0f} % du groupe, l'usure serait fatale", fails)
    check(cout[-1] > cout[0] * 1.4,
          f"le dernier etage ({cout[-1]:.1f} %) ne coute pas plus cher que "
          f"le premier ({cout[0]:.1f} %) : la courbe est plate", fails)

    print()
    if fails:
        print(f"{len(fails)} anomalie(s) :")
        for x in fails:
            print("  -", x)
        sys.exit(1)
    print("chaque creature se bat a sa maniere")
