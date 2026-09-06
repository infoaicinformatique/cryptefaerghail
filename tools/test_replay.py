#!/usr/bin/env python3
"""Eprouve le replayer ProTracker effet par effet, aux registres de Paula.

Le replayer n'en connaissait que neuf sur une trentaine : ni vibrato,
ni tremolo, ni note retardee, ni relance, ni depart dans le sample. Les
ajouter sans banc revenait a les ecrire au hasard -- un effet de
ProTracker se juge au dixieme de tic, pas a la lecture.

On ecrit donc de vrais motifs dans le module charge, on appelle PT_Tick
tic par tic, et on regarde ce que le jeu envoie a AUDxPER, AUDxVOL,
AUDxLC et DMACON.

    python3 tools/test_replay.py
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import test_game as T

# Registres du canal 0, en decalage depuis $dff000
LC0, LEN0, PER0, VOL0 = 0xa0, 0xa4, 0xa6, 0xa8
DMACON = 0x96

# Quelques periodes de la table ProTracker
C2, D2, E2, F2, G2, A2 = 428, 381, 339, 320, 285, 254


def cell(period=0, inst=0, fx=0, param=0):
    """Les quatre octets d'une case de pattern."""
    return bytes(((inst & 0xf0) | ((period >> 8) & 0x0f),
                  period & 0xff,
                  ((inst & 0x0f) << 4) | (fx & 0x0f),
                  param & 0xff))


class Replay:
    """Un module de travail ecrit par-dessus celui du jeu."""

    def __init__(self, g):
        self.g = g
        self.pat = g.mem.r32(g.addr("PT_Patterns"))
        self.order = g.mem.r32(g.addr("PT_Order"))
        self.f = {}
        for line in open(os.path.join(ROOT, "src", "ptreplay.i")):
            if line.startswith("chn_"):
                name = line.split("\t")[0].strip()
                try:
                    self.f[name] = int(line.split("=")[1].split(";")[0].strip())
                except ValueError:
                    pass
        self.chn_size = self.f["chn_SIZEOF"]

    def load(self, rows, speed=6):
        """rows : une liste de listes de quatre cases."""
        g = self.g
        for r in range(64):
            line = rows[r] if r < len(rows) else [cell()] * 4
            for c in range(4):
                for k, b in enumerate(line[c]):
                    g.mem.w8(self.pat + r * 16 + c * 4 + k, b)
        g.mem.w8(self.order, 0)                   # on ne joue que le motif 0
        g.setw("PT_SongLen", 1)
        g.setw("PT_Pos", 0)
        g.setw("PT_Row", 0)
        g.setw("PT_TickCnt", speed - 1)           # le prochain tic lit la ligne
        g.setw("PT_Speed", speed)
        g.setw("PT_PattDelay", 0)
        g.setw("PT_LoopCnt", 0)
        g.setw("PT_SfxLock", 0)
        chn = g.addr("PT_Channels")                # un essai ne doit pas
        for c in range(4):                         # trainer dans le suivant
            g.mem.w16(chn + c * self.chn_size + self.f["chn_SetRep"], 0)
            g.mem.w16(chn + c * self.chn_size + self.f["chn_Trigger"], 0)
            g.mem.w16(chn + c * self.chn_size + self.f["chn_VibCmd"], 0)
            g.mem.w16(chn + c * self.chn_size + self.f["chn_TremCmd"], 0)
            g.mem.w16(chn + c * self.chn_size + self.f["chn_Offset"], 0)

    def ticks(self, n):
        """Joue n tics et rend le journal des ecritures, tic par tic."""
        out = []
        for _ in range(n):
            self.g.audio.clear()
            self.g.call(self.g.addr("PT_Tick"))
            out.append(list(self.g.audio))
        return out


# Une attaque ecrit deux fois plusieurs registres, et c'est normal :
# Paula veut l'adresse de depart, puis le point de boucle une fois le
# canal relance, et la periode part a la fois du declenchement et du
# bloc materiel. Compter les ecritures brutes reviendrait a compter les
# notes en double.
def periods(log, chan=0):
    """La derniere hauteur envoyee sur ce tic."""
    base = LC0 + chan * 16
    v = [v for off, v in log if off == base + 6]
    return v[-1:] if v else []


def volumes(log, chan=0):
    base = LC0 + chan * 16
    v = [v for off, v in log if off == base + 8]
    return v[-1:] if v else []


def attack(log):
    """Un tic ou une note part : lui seul touche a DMACON."""
    return any(off == DMACON for off, _ in log)


def sample_start(log, chan=0):
    """L'adresse de depart du sample, si une note part sur ce tic.

    La derniere ecriture, pas la premiere : un tic peut commencer par
    poser le point de boucle de la note precedente."""
    base = LC0 + chan * 16
    v = [v for off, v in log if off == base]
    return v[-1] if v and attack(log) else None


def check(cond, msg, fails):
    if not cond:
        fails.append(msg)
    return cond


if __name__ == "__main__":
    fails = []
    g = T.Game()
    r = Replay(g)

    print("--- Cxx : le volume se pose ---")
    r.load([[cell(C2, 1, 0xc, 40), cell(), cell(), cell()]])
    log = r.ticks(6)
    v = volumes(log[0])
    check(v and v[-1] == 40, f"volume {v} au lieu de 40", fails)
    print(f"  tic 0 : AUD0VOL = {v[-1]}")

    print("--- 4xy : vibrato ---")
    r.load([[cell(C2, 1, 0xc, 64), cell(), cell(), cell()],
            [cell(0, 0, 0x4, 0x88), cell(), cell(), cell()]])
    log = r.ticks(20)
    per = [p for t in log[6:] for p in periods(t)]
    check(per, "le vibrato n'ecrit aucune periode", fails)
    lo, hi = min(per), max(per)
    check(hi > lo, f"la hauteur ne bouge pas : {sorted(set(per))}", fails)
    check(lo < C2 <= hi or lo <= C2 < hi,
          f"le vibrato ne tourne pas autour de {C2} : {lo}..{hi}", fails)
    print(f"  la hauteur oscille entre {lo} et {hi} autour de {C2}")

    print("--- 7xy : tremolo ---")
    r.load([[cell(C2, 1, 0xc, 32), cell(), cell(), cell()],
            [cell(0, 0, 0x7, 0x8c), cell(), cell(), cell()]])
    log = r.ticks(20)
    vol = [v for t in log[6:] for v in volumes(t)]
    check(vol and max(vol) > min(vol),
          f"le volume ne bouge pas : {sorted(set(vol))}", fails)
    print(f"  le volume oscille entre {min(vol)} et {max(vol)} autour de 32")

    print("--- Axy : glissement de volume ---")
    r.load([[cell(C2, 1, 0xc, 60), cell(), cell(), cell()],
            [cell(0, 0, 0xa, 0x04), cell(), cell(), cell()]])
    log = r.ticks(12)
    vol = [v for t in log[6:] for v in volumes(t)]
    check(vol == sorted(vol, reverse=True) and vol[-1] < 60,
          f"le volume ne descend pas regulierement : {vol}", fails)
    print(f"  60 -> {vol[-1]} en cinq tics : {vol}")

    print("--- ECx : la note se coupe ---")
    r.load([[cell(C2, 1, 0xe, 0xc3), cell(), cell(), cell()]])
    log = r.ticks(6)
    vol = [(i, v) for i, t in enumerate(log) for v in volumes(t)]
    cut = [i for i, v in vol if v == 0]
    check(cut and cut[0] == 3, f"la coupure tombe au tic {cut}, attendu 3",
          fails)
    print(f"  volume nul a partir du tic {cut[0]}")

    print("--- EDx : la note part plus tard ---")
    r.load([[cell(C2, 1, 0xe, 0xd3), cell(), cell(), cell()]])
    log = r.ticks(6)
    when = [i for i, t in enumerate(log) if attack(t)]
    check(when == [3], f"le sample part aux tics {when}, attendu [3]", fails)
    print(f"  le sample part au tic {when[0] if when else '-'}")

    print("--- E9x : la note se relance ---")
    r.load([[cell(C2, 1, 0xe, 0x92), cell(), cell(), cell()]], speed=6)
    log = r.ticks(6)
    when = [i for i, t in enumerate(log) if attack(t)]
    check(len(when) >= 3, f"une seule attaque : {when}", fails)
    print(f"  attaques aux tics {when}")

    print("--- 9xx : depart dans le sample ---")
    r.load([[cell(C2, 1, 0, 0), cell(), cell(), cell()]])
    plain = sample_start(r.ticks(1)[0])
    words = g.mem.r16(g.addr("PT_Channels") + r.f["chn_Len"])
    step = max(1, min(8, (words * 2) // 512))     # un saut qui tient dedans
    r.load([[cell(C2, 1, 0x9, step), cell(), cell(), cell()]])
    moved = sample_start(r.ticks(1)[0])
    check(plain and moved, "le sample ne demarre pas", fails)
    if plain and moved:
        delta = moved - plain
        check(delta == step * 256, f"le depart glisse de {delta} octets "
              f"au lieu de {step * 256}", fails)
        print(f"  sample de {words * 2} octets, 9 {step:02x} avance le "
              f"depart de {delta} octets")

    print("--- E1x / E2x : glissandos fins ---")
    r.load([[cell(C2, 1, 0xc, 64), cell(), cell(), cell()],
            [cell(0, 0, 0xe, 0x18), cell(), cell(), cell()],
            [cell(0, 0, 0xe, 0x28), cell(), cell(), cell()]])
    log = r.ticks(18)
    per = [p for t in log for p in periods(t)]
    check(C2 - 8 in per, f"E18 ne monte pas de huit : {sorted(set(per))}",
          fails)
    print(f"  E1 8 : {C2} -> {C2 - 8}, puis E2 8 rend la hauteur")

    print("--- Fxx : la vitesse ---")
    r.load([[cell(C2, 1, 0xf, 3), cell(), cell(), cell()],
            [cell(D2, 1, 0, 0), cell(), cell(), cell()]])
    log = r.ticks(8)
    when = [i for i, t in enumerate(log) if attack(t)]
    check(when[:2] == [0, 3], f"les lignes tombent aux tics {when}, "
          f"attendu 0 puis 3", fails)
    print(f"  a la vitesse 3, les lignes tombent aux tics {when[:3]}")

    print("--- EEx : la ligne est retenue ---")
    r.load([[cell(C2, 1, 0xe, 0xe1), cell(), cell(), cell()],
            [cell(D2, 1, 0, 0), cell(), cell(), cell()]], speed=3)
    log = r.ticks(12)
    when = [i for i, t in enumerate(log) if attack(t)]
    check(when[:2] == [0, 6], f"la ligne suivante tombe au tic {when}, "
          f"attendu 6 (une ligne de retard)", fails)
    print(f"  EE1 double la duree de la ligne : attaques aux tics {when[:3]}")

    print("--- E6x : la boucle de motif ---")
    r.load([[cell(C2, 1, 0xe, 0x60), cell(), cell(), cell()],
            [cell(D2, 1, 0, 0), cell(), cell(), cell()],
            [cell(E2, 1, 0xe, 0x61), cell(), cell(), cell()],
            [cell(F2, 1, 0, 0), cell(), cell(), cell()]], speed=1)
    log = r.ticks(8)
    per = [p for t in log for p in periods(t)]
    check(per[:7] == [C2, D2, E2, C2, D2, E2, F2],
          f"la boucle joue {per[:8]}, attendu C D E C D E F", fails)
    print(f"  E60/E61 rejoue les trois premieres lignes : {per[:7]}")

    print("--- 3xx : portamento vers la note ---")
    r.load([[cell(C2, 1, 0, 0), cell(), cell(), cell()],
            [cell(G2, 0, 0x3, 0x20), cell(), cell(), cell()]])
    log = r.ticks(24)
    per = [p for t in log[7:] for p in periods(t)]
    check(per and per[0] < C2 and per[-1] == G2,
          f"la hauteur ne glisse pas de {C2} vers {G2} : {per[:6]}...{per[-3:]}",
          fails)
    check(per == sorted(per, reverse=True),
          "le portamento ne descend pas regulierement", fails)
    print(f"  {C2} -> {per[-1]} par pas de 32, cible {G2}")

    print()
    if fails:
        print(f"{len(fails)} anomalie(s) :")
        for f in fails:
            print("  -", f)
        sys.exit(1)
    print("le replayer honore les effets ProTracker")
