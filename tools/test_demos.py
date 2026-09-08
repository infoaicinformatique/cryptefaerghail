#!/usr/bin/env python3
"""Fait tourner les deux demos dans le 68020 emule.

Le jeu s'eprouvait ainsi depuis longtemps ; les demos, jamais -- le
README disait encore qu'elles n'avaient tourne nulle part. Ce banc les
lance pour de bon : prise de controle, interruption de retour trame,
echange de copperlist, tic de musique, puis la sortie au bouton de la
souris, en verifiant que la machine est rendue au systeme comme on l'a
trouvee.

    python3 tools/test_demos.py
"""
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import run68k as R
import test_game as T

CUSTOM = 0xdff000
DMAF_MASTER, DMAF_COPPER, DMAF_RASTER = 0x0200, 0x0080, 0x0100
INTF_INTEN, INTF_VERTB = 0x4000, 0x0020


class Demo(R.Harness):
    """Le meme banc que pour le jeu, relie avec ses symboles."""

    def __init__(self, name):
        obj = os.path.join(ROOT, "build", f"{name}.o")
        dbg = os.path.join(ROOT, "build", f"{name}.dbg")
        subprocess.run([os.path.join(ROOT, "tools/bin/vlink"), "-bamigahunk",
                        "-Bstatic", "-o", dbg, obj], check=True)
        super().__init__(dbg)
        self.syms = T.load_symbols(dbg)
        self.hunk_sym = {n: self.segs[h][0] + o
                         for n, (h, o) in self.syms.items()}
        self.start()

    def addr(self, name):
        return self.hunk_sym[name]

    def w(self, name):
        return self.mem.r16(self.addr(name))

    def spin(self, mcycles, until=None):
        """Tourne au plus mcycles millions de cycles, ou jusqu'a until()."""
        for _ in range(mcycles):
            self.execute(1000000)
            if until and until():
                return True
        return not until


def check(cond, msg, fails):
    if not cond:
        fails.append(msg)
    return cond


def run_demo(name, fails):
    g = Demo(name)

    # La prise de controle : elle passe par une generation de decor pour
    # AGAScroll, soixante-cinq millions de cycles, d'ou la longue laisse.
    if not check(g.spin(200, lambda: g.intena & INTF_INTEN),
                 f"{name} : la prise de controle n'aboutit pas "
                 f"(pc={g.cpu.r_pc():#x})", fails):
        return
    check(g.intena & INTF_VERTB, f"{name} : VERTB n'est pas armee "
          f"({g.intena:#06x})", fails)
    dma = g.dmacon
    for bit, quoi in ((DMAF_MASTER, "maitre"), (DMAF_COPPER, "copper"),
                      (DMAF_RASTER, "bitplanes")):
        check(dma & bit, f"{name} : DMA {quoi} coupe ({dma:#06x})", fails)
    vector = g.mem.r32(0x6c)
    check(vector, f"{name} : aucun vecteur de niveau 3 installe", fails)
    cop = (g.custom.get(0x80, 0) << 16) | g.custom.get(0x82, 0)
    check(cop, f"{name} : aucune copperlist a l'affiche", fails)
    print(f"  {name} : prise de controle, vecteur {vector:#x}, "
          f"copperlist {cop:#x}")

    # Le timer A doit battre le tempo du module, pas la trame.
    check(g.cia_run, f"{name} : le timer A du CIA-B ne tourne pas", fails)
    check(g.cia_mask & 1, f"{name} : le timer A n'a pas d'interruption", fails)
    check(g.mem.r32(0x78), f"{name} : aucun vecteur de niveau 6", fails)
    for bpm in (125, 250, 60):
        g.call(g.addr("CIA_SetBpm"), d0=bpm)
        attendu = 1773447 // bpm
        check(g.cia_latch == attendu, f"{name} : a {bpm} BPM le compte vaut "
              f"{g.cia_latch} au lieu de {attendu}", fails)
        hz = R.Harness.CIA_CLOCK / g.cia_latch
        check(abs(hz - bpm * 2 / 5) < 0.05, f"{name} : a {bpm} BPM le timer "
              f"bat a {hz:.2f} Hz au lieu de {bpm * 2 / 5:.2f}", fails)
    g.call(g.addr("CIA_SetBpm"), d0=125)
    print(f"  {name} : timer A a {R.Harness.CIA_CLOCK / g.cia_latch:.1f} Hz, "
          f"soit 125 BPM")

    # Une poignee de trames : l'interruption doit frapper, la boucle
    # avancer, et Paula recevoir des notes.
    irq0, audio0 = g.irq3, len(g.audio)
    frame0 = g.w("FrameCnt")
    liste = set()
    for _ in range(12):
        g.execute(400000)
        liste.add((g.custom.get(0x80, 0) << 16) | g.custom.get(0x82, 0))
    check(g.irq3 > irq0, f"{name} : le retour trame ne frappe pas", fails)
    check(g.w("FrameCnt") != frame0, f"{name} : le compteur de trames ne "
          f"bouge pas ({frame0})", fails)
    check(len(g.audio) > audio0, f"{name} : Paula ne recoit rien", fails)
    check(len(liste) > 1, f"{name} : la copperlist ne s'echange jamais "
          f"({liste})", fails)
    print(f"  {name} : {g.irq3 - irq0} trames, {len(g.audio) - audio0} "
          f"ecritures Paula, {len(liste)} copperlists a l'affiche")

    # Le bouton gauche : on rend la machine.
    old_intena = g.w("OldIntena")
    old_dmacon = g.w("OldDmacon")
    g.mouse_button(1)
    if not check(g.spin(60, lambda: g.cpu.r_pc() == g.EXIT),
                 f"{name} : le bouton ne fait pas sortir "
                 f"(pc={g.cpu.r_pc():#x})", fails):
        return
    check(g.mem.r32(0x6c) == 0, f"{name} : le vecteur de niveau 3 n'est pas "
          f"rendu ({g.mem.r32(0x6c):#x})", fails)
    check(g.intena == (old_intena & 0x7fff), f"{name} : INTENA rendu "
          f"{g.intena:#06x} au lieu de {old_intena & 0x7fff:#06x}", fails)
    check(g.dmacon == (old_dmacon & 0x7fff), f"{name} : DMACON rendu "
          f"{g.dmacon:#06x} au lieu de {old_dmacon & 0x7fff:#06x}", fails)
    print(f"  {name} : sortie propre, INTENA et DMACON rendus au systeme")


if __name__ == "__main__":
    fails = []
    print("--- les deux demos, dans le 68020 emule ---")
    for name in ("AGADemo", "AGAScroll"):
        run_demo(name, fails)
    print()
    if fails:
        print(f"{len(fails)} anomalie(s) :")
        for f in fails:
            print("  -", f)
        sys.exit(1)
    print("les deux demos prennent la machine et la rendent")
