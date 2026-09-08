#!/usr/bin/env python3
"""Execute reellement l'executable Amiga dans un 68020 emule.

Le jeu n'a jamais tourne sur une machine : ce banc charge le binaire
hunk, le reloge, remplace exec.library et graphics.library par des
souches, simule le balayage video et le clavier, puis fait avancer la
boucle principale. On teste ainsi la logique -- creation, deplacements,
combats, sorts -- au lieu de la relire.

Le chipset n'est pas emule : les ecritures dans les registres custom
tombent dans de la RAM ordinaire, et le blitter ne recopie rien. Tout ce
qui passe par le processeur, en revanche, s'execute pour de vrai.

    python3 tools/run68k.py [bin/AGACrawl]
"""
import os
import struct
import sys

from machine68k import CPUType, Machine

RAM_KIB = 2 * 1024                       # 2 Mio de Chip, comme un A1200
BASE = 0x00010000                        # ou l'on charge les hunks
STACK = 0x0000f000
EXECBASE = 0x00001000
GFXBASE = 0x00002000
DOSBASE = 0x00003000
CUSTOM = 0xdff000
CIAA = 0xbfe001

HUNK_CODE, HUNK_DATA, HUNK_BSS = 0x3e9, 0x3ea, 0x3eb
HUNK_RELOC32, HUNK_SYMBOL, HUNK_END, HUNK_HEADER = 0x3ec, 0x3f0, 0x3f2, 0x3f3


class Loader:
    """Charge un executable hunk et applique les relocations."""

    def __init__(self, path):
        self.data = open(path, "rb").read()
        self.pos = 0
        self.segments = []

    def u32(self):
        v = struct.unpack(">I", self.data[self.pos:self.pos + 4])[0]
        self.pos += 4
        return v

    def load(self, mem, base):
        assert self.u32() == HUNK_HEADER
        while self.u32():                            # noms de bibliotheques
            pass
        count, first, last = self.u32(), self.u32(), self.u32()
        sizes = [self.u32() & 0x3fffffff for _ in range(count)]
        addr = base
        for s in sizes:                              # adresses, alignees
            self.segments.append([addr, s * 4, None])
            addr += s * 4 + 16
            addr = (addr + 7) & ~7
        idx = 0
        while self.pos < len(self.data):
            t = self.u32() & 0x3fffffff
            if t in (HUNK_CODE, HUNK_DATA):
                n = self.u32() * 4
                blob = self.data[self.pos:self.pos + n]
                self.pos += n
                self.segments[idx][2] = blob
                for i, b in enumerate(blob):
                    mem.w8(self.segments[idx][0] + i, b)
            elif t == HUNK_BSS:
                n = self.u32() * 4
                for i in range(0, n, 4):
                    mem.w32(self.segments[idx][0] + i, 0)
            elif t == HUNK_RELOC32:
                while True:
                    cnt = self.u32()
                    if cnt == 0:
                        break
                    target = self.u32()
                    for _ in range(cnt):
                        off = self.u32()
                        at = self.segments[idx][0] + off
                        mem.w32(at, (mem.r32(at) + self.segments[target][0])
                                & 0xffffffff)
            elif t == HUNK_SYMBOL:               # table des symboles : ignoree
                while True:
                    ln = self.u32()
                    if not ln:
                        break
                    self.pos += ln * 4 + 4
            elif t == HUNK_END:
                idx += 1
            else:
                raise SystemExit(f"hunk inattendu {t:#x} a {self.pos:#x}")
        return self.segments


# --- dos.library : un vrai acces au disque, servi par l'hote -----------
# Les souches rendent zero, ce qui suffit pour graphics.library mais
# laisserait la sauvegarde intestable. On installe donc a chaque LVO de
# dos.library une ecriture dans un guichet memoire : le callback Python
# lit les registres du 68000 et fait l'operation pour de vrai.
DOSPORT = 0x00f10000
DOS_LVOS = {-30: "open", -36: "close", -42: "read", -48: "write"}


# --- souches de bibliotheques : un petit bout de 68k a chaque LVO ------
def stub_library(mem, base, returns=None):
    """rts a chaque vecteur negatif ; certains renvoient une valeur."""
    for i in range(1, 200):                          # les LVO vont de six en six
        off = -6 * i
        addr = base + off
        if returns and off in returns:
            mem.w16(addr, 0x203c)                    # move.l #imm,d0
            mem.w32(addr + 2, returns[off])
            mem.w16(addr + 6, 0x4e75)                # rts
        else:
            mem.w16(addr, 0x4e75)


class Harness:
    """Le minimum de materiel pour que le code avance : balayage video,
    blitter jamais occupe, et le port serie du CIA pour le clavier."""

    def __init__(self, path):
        self.machine = Machine(CPUType.M68020, RAM_KIB)
        self.mem, self.cpu = self.machine.mem, self.machine.cpu
        self.segs = Loader(path).load(self.mem, BASE)
        self.line = 0
        self.keys = []
        self.pending = None
        self.icr = 0
        self.custom = {}
        self.intena = 0                  # INTENA, INTREQ et DMACON sont des
        self.intreq = 0                  # registres a bascule : bit 15 pose,
        self.dmacon = 0                  # sinon efface
        self.cia_mask = 0                # CIA-B : masque d'interruption,
        self.cia_flags = 0               # drapeaux, compte du timer A et
        self.cia_latch = 0               # accumulateur de tics
        self.cia_run = False
        self.cia_acc = 0.0
        self.frame_acc = 0
        self.frame_due = False
        self.coper_due = False
        self.irq_coper = 0
        self.coper_lists = {}            # copperlists deja examinees
        self.cia_due = 0
        self.irq6 = 0
        self.irq3 = 0                    # niveau 3 pris depuis le depart
        self.bad_blits = []
        self.dos_dir = os.environ.get("AGA_SAVEDIR", "/tmp")
        self.audio = []
        self.finished = False
        self.setup_hw()
        self.setup_os()

    # --- chipset ---------------------------------------------------
    def setup_hw(self):
        mem = self.mem
        mem.reserve_special_range()                  # $dff000
        mem.reserve_special_range()                  # $bf0000 : les deux CIA

        def raster(off):
            """VPOSR/VHPOSR : le balayage avance a chaque interrogation."""
            self.line = (self.line + 1) % 313
            if off == 0x04:
                return 1 if self.line > 255 else 0
            return ((self.line & 0xff) << 8) | (self.line & 0x7f)

        def r_custom(addr, *a):
            off = addr - CUSTOM
            if off in (0x04, 0x06):
                return raster(off)
            if off == 0x02:                          # DMACONR
                return self.dmacon & 0x1fff          # BBUSY/BZERO au repos
            if off == 0x1c:                          # INTENAR
                return self.intena
            if off == 0x1e:                          # INTREQR
                return self.intreq
            if off == 0x0a:                          # JOY0DAT : les deux
                return ((self.mouse_ry & 0xff) << 8) | (self.mouse_rx & 0xff)
            if off == 0x16:                          # POTGOR : bouton droit
                return 0xffff & ~(0x0400 if self.mouse_btn & 2 else 0)
            return self.custom.get(off, 0)

        def r_custom8(addr, *a):
            """Une lecture d'octet prend sa moitie du registre.

            Le banc rendait la valeur entiere tronquee, donc toujours la
            moitie basse : `btst #6,DMACONR(a6)` lisait l'octet de poids
            fort et y trouvait le bit 6 de l'octet faible -- le bit du
            DMA blitter au lieu de BBUSY. Tant que DMACONR rendait zero
            cela ne se voyait pas ; depuis qu'il rend l'etat reel,
            AGAScroll attendait un blitter eternellement occupe."""
            word = r_custom(addr & ~1)
            return (word >> 8) & 0xff if not addr & 1 else word & 0xff

        def r_custom32(addr, *a):
            """Une lecture longue de $dff004 ramene VPOSR et VHPOSR
            d'un coup : c'est ainsi que le jeu attend le retour trame."""
            off = addr - CUSTOM
            if off == 0x04:
                self.line = (self.line + 1) % 313
                hi = 1 if self.line > 255 else 0
                lo = ((self.line & 0xff) << 8) | (self.line & 0x7f)
                return (hi << 16) | lo
            return (r_custom(addr) << 16) | r_custom(addr + 2)

        AUDIO = set(range(0xa0, 0xe0)) | {0x96}       # Paula et DMACON

        def setclr(cur, val):
            """INTENA, INTREQ : bit 15 arme, sinon efface les bits poses."""
            return (cur | (val & 0x7fff)) if val & 0x8000 else (cur & ~val)

        def w_custom(addr, val, *a):
            off = addr - CUSTOM
            if off == 0x9a:                          # INTENA
                self.intena = setclr(self.intena, val) & 0x7fff
            elif off == 0x9c:                        # INTREQ
                self.intreq = setclr(self.intreq, val) & 0x7fff
            elif off == 0x96:                        # DMACON
                self.dmacon = setclr(self.dmacon, val) & 0x7fff
            self.custom[off] = val
            if off in AUDIO:                         # journal pour les tests
                self.audio.append((off, val))
            if off == 0x58:                          # BLTSIZE : demarre le blit
                self.blit(val)

        def w_custom32(addr, val, *a):
            off = addr - CUSTOM
            self.custom[off] = (val >> 16) & 0xffff
            self.custom[off + 2] = val & 0xffff
            if off in AUDIO:
                self.audio.append((off, val))

        # Les deux CIA tiennent dans la meme page de soixante-quatre kilos
        # ($bf0000) : un seul jeu de fonctions les sert, sans quoi le
        # second enregistrement effacerait le premier -- et le bouton de
        # la souris se lirait dans le CIA-B.
        def r_cia(addr, *a):
            if addr == 0xbfed01:                     # A : ICR, lecture efface
                v = self.icr
                self.icr = 0
                return v
            if addr == 0xbfec01:                     # A : SDR, code clavier
                return self.sdr
            if addr == 0xbfe001:                     # A : bouton gauche, 0 = mis
                return 0xff & ~(0x40 if self.mouse_btn & 1 else 0)
            if addr == 0xbfdd00:                     # B : ICR, lecture efface
                v = self.cia_flags
                self.cia_flags = 0
                return v
            return 0

        def w_cia(addr, val, *a):
            val &= 0xff
            if addr == 0xbfd400:                     # B : compte, poids faible
                self.cia_latch = (self.cia_latch & 0xff00) | val
            elif addr == 0xbfd500:                   # B : poids fort, recharge
                self.cia_latch = (self.cia_latch & 0x00ff) | (val << 8)
            elif addr == 0xbfdd00:                   # B : masque, a bascule
                if val & 0x80:
                    self.cia_mask |= val & 0x7f
                else:
                    self.cia_mask &= ~(val & 0x7f)
            elif addr == 0xbfde00:                   # B : commande du timer A
                self.cia_run = bool(val & 1)

        mem.set_special_range_read_funcs(CUSTOM, 1, r_custom8, r_custom,
                                         r_custom32)
        mem.set_special_range_write_funcs(CUSTOM, 1, w_custom, w_custom,
                                          w_custom32)
        mem.set_special_range_read_funcs(0xbf0000, 1, r_cia, r_cia, r_cia)
        mem.set_special_range_write_funcs(0xbf0000, 1, w_cia, w_cia, w_cia)
        self.sdr = 0xff
        self.mouse_rx = 0                            # compteurs quadrature
        self.mouse_ry = 0
        self.mouse_btn = 0

    # --- blitter : assez pour que l'ecran ressemble a l'ecran ------
    def ptr(self, off):
        return ((self.custom.get(off, 0) << 16)
                | self.custom.get(off + 2, 0)) & 0xffffff

    def blit(self, size):
        """Un blit rectangulaire ordinaire : quatre canaux, barillet,
        masques de bords, minterme. Assez pour les remplissages, les
        traits et les morceaux de decor decoupes au pochoir."""
        h, w = size >> 6, size & 0x3f
        if h == 0:
            h = 1024
        if w == 0:
            w = 64
        con0 = self.custom.get(0x40, 0)
        limit = RAM_KIB * 1024
        con1 = self.custom.get(0x42, 0)
        mt = con0 & 0xff
        use = {c: bool(con0 & b) for c, b in
               (("a", 0x800), ("b", 0x400), ("c", 0x200), ("d", 0x100))}
        if con1 & 0x01:                              # mode trait : ignore
            return
        desc = bool(con1 & 0x02)
        ash, bsh = con0 >> 12, con1 >> 12
        fwm, lwm = self.custom.get(0x44, 0xffff), self.custom.get(0x46, 0xffff)
        pt = {c: self.ptr(o) for c, o in
              (("c", 0x48), ("b", 0x4c), ("a", 0x50), ("d", 0x54))}
        mod = {c: self.custom.get(o, 0) for c, o in
               (("c", 0x60), ("b", 0x62), ("a", 0x64), ("d", 0x66))}
        for c in mod:
            if mod[c] > 0x7fff:
                mod[c] -= 0x10000
        for c, on in (("a", use["a"]), ("b", use["b"]), ("c", use["c"]),
                      ("d", use["d"])):
            if on and not 0 < pt[c] < limit:      # un blit hors RAM : on
                self.bad_blits.append((c, pt[c], con0, size))   # le signale
                return                                          # sans lire
        step = -2 if desc else 2
        old = {"a": 0, "b": 0}
        for _ in range(h):
            for x in range(w):
                mask = 0xffff
                if x == 0:
                    mask &= fwm
                if x == w - 1:
                    mask &= lwm
                vals = {}
                for c in ("a", "b", "c"):
                    if not use[c]:
                        vals[c] = 0 if c != "c" else 0
                        continue
                    v = self.mem.r16(pt[c] & 0xfffffe)
                    pt[c] = (pt[c] + step) & 0xffffff
                    vals[c] = v
                for c, sh in (("a", ash), ("b", bsh)):
                    v = vals[c] & (mask if c == "a" else 0xffff)
                    if sh:
                        if desc:
                            comb = (v << 16) | old[c]
                            vals[c] = (comb >> (16 - sh)) & 0xffff
                        else:
                            comb = (old[c] << 16) | v
                            vals[c] = (comb >> sh) & 0xffff
                    else:
                        vals[c] = v
                    old[c] = v
                a, b, cc = vals["a"], vals["b"], vals["c"]
                d = 0
                if mt & 0x80: d |= a & b & cc
                if mt & 0x40: d |= a & b & ~cc
                if mt & 0x20: d |= a & ~b & cc
                if mt & 0x10: d |= a & ~b & ~cc
                if mt & 0x08: d |= ~a & b & cc
                if mt & 0x04: d |= ~a & b & ~cc
                if mt & 0x02: d |= ~a & ~b & cc
                if mt & 0x01: d |= ~a & ~b & ~cc
                if use["d"]:
                    self.mem.w16(pt["d"] & 0xfffffe, d & 0xffff)
                    pt["d"] = (pt["d"] + step) & 0xffffff
            for c in ("a", "b", "c", "d"):
                if use[c] or c == "d":
                    pt[c] = (pt[c] + (-mod[c] if desc else mod[c])) & 0xffffff

    def setup_os(self):
        m = self.mem
        m.w32(4, EXECBASE)
        stub_library(m, EXECBASE)
        m.w16(EXECBASE + 296, 0x0001)                # AttnFlags : 68010+,
        self.setup_supervisor()                      # donc un VBR a demander
        self.setup_allocmem()
        stub_library(m, GFXBASE)
        stub_library(m, DOSBASE)
        self.setup_dos()
        thunk = EXECBASE + 0x400                     # OpenLibrary : le nom
        m.w16(EXECBASE - 552, 0x4ef9)                # decide de la base
        m.w32(EXECBASE - 552 + 2, thunk)
        m.w16(thunk, 0x23c9)                         # move.l a1,$00f10008
        m.w32(thunk + 2, DOSPORT + 8)
        m.w16(thunk + 6, 0x2039)                     # move.l $00f1000c,d0
        m.w32(thunk + 8, DOSPORT + 12)
        m.w16(thunk + 12, 0x4e75)

    # --- exec/Supervisor() ------------------------------------------
    def setup_supervisor(self):
        """Le jeu demande le VBR au processeur, et movec est privilegie :
        il passe donc par exec/Supervisor(), qui appelle (a5) en mode
        superviseur et dont la routine se termine par rte. La souche pose
        le cadre d'exception que ce rte attend -- format 0 du 68020 : SR,
        PC, puis le mot de format.

        Le banc fait tourner tout le programme en mode superviseur, la ou
        l'Amiga n'y passe que le temps de la routine : ce n'est pas une
        licence, c'est la seule difference que le code puisse voir, et
        elle ne change rien a ce qu'il execute."""
        m = self.mem
        thunk = EXECBASE + 0x480
        m.w16(EXECBASE - 30, 0x4ef9)                 # jmp (thunk).L
        m.w32(EXECBASE - 30 + 2, thunk)
        for word in (0x221f,                         # move.l (sp)+,d1
                     0x4267,                         # clr.w -(sp)  (format 0)
                     0x2f01,                         # move.l d1,-(sp)
                     0x40e7,                         # move.w sr,-(sp)
                     0x4ed5):                        # jmp (a5)
            m.w16(thunk, word)
            thunk += 2

    # --- exec/AllocMem() ---------------------------------------------
    HEAP = 0x00160000                    # au-dessus des hunks charges

    def setup_allocmem(self):
        """Les demos demandent leur bitmap a AllocMem ; la souche rendait
        zero et elles ressortaient aussitot. On leur donne un bloc, une
        fois pour toutes : le banc n'a qu'un programme a la fois, et
        aucune des deux ne libere pour realouer."""
        m = self.mem
        m.w16(EXECBASE - 198, 0x203c)                # move.l #HEAP,d0
        m.w32(EXECBASE - 198 + 2, self.HEAP)
        m.w16(EXECBASE - 198 + 6, 0x4e75)            # rts

    # --- interruptions : retour trame (3) et timer du CIA-B (6) ------
    #
    # Le banc avance par petites tranches et decide, a chaque bord, ce
    # qui est du. Une seule interruption part par tranche, le niveau 6
    # d'abord comme sur la machine, et ce qui n'a pas pu partir reste du
    # -- sans quoi le tic du module, dont le gestionnaire dure plusieurs
    # milliers de cycles, affamerait le retour trame.
    VBI_PERIOD = 12000                   # cycles entre deux trames
    SLICE = 2000                         # ou l'on regarde les interruptions

    CIA_CLOCK = 709379                   # horloge du CIA en PAL

    def due(self, cycles):
        """Fait avancer les deux horloges d'autant de cycles.

        Une trame vaut un cinquantieme de seconde ; le timer A y fait
        CIA_CLOCK / compte / 50 tics, soit exactement un au tempo par
        defaut de 125 BPM, et davantage si le module accelere."""
        avant = self.frame_acc
        self.frame_acc += cycles
        # A mi-trame, la ou une copperlist peut poser son MOVE vers
        # INTREQ : le banc n'emule pas le copper, il sait seulement que
        # celui-ci arrive au milieu de l'image.
        if avant < self.VBI_PERIOD // 2 <= self.frame_acc:
            self.coper_due = True
        if self.frame_acc >= self.VBI_PERIOD:
            self.frame_acc -= self.VBI_PERIOD
            self.frame_due = True
        if not (self.cia_run and self.cia_latch):
            return
        par_trame = self.CIA_CLOCK / self.cia_latch / 50.0
        self.cia_acc += par_trame * cycles / self.VBI_PERIOD
        while self.cia_acc >= 1.0:
            self.cia_acc -= 1.0
            self.cia_flags |= 0x81               # timer A, et la ligne IR
            if self.cia_due < 4:                 # on ne rattrape pas plus
                self.cia_due += 1

    def copper_raises(self):
        """La copperlist a l'affiche ecrit-elle dans INTREQ ?

        Le banc n'emule pas le copper ; il lit sa liste. Un MOVE vers
        $09c avec le bit COPER arme, c'est un reveil demande -- sans
        quoi le banc reveillerait aussi les programmes qui n'ont rien
        demande, et leur gestionnaire de niveau 3 y verrait une cause
        qui n'existe pas."""
        cop = (self.custom.get(0x80, 0) << 16) | self.custom.get(0x82, 0)
        if not cop:
            return False
        if cop in self.coper_lists:
            return self.coper_lists[cop]
        found, addr = False, cop
        for _ in range(8192):
            mot, val = self.mem.r16(addr), self.mem.r16(addr + 2)
            if mot == 0xffff and val == 0xfffe:      # fin de liste
                break
            if not mot & 1 and (mot & 0x1fe) == 0x09c and val & 0x8010 == 0x8010:
                found = True
                break
            addr += 4
        self.coper_lists[cop] = found
        return found

    def fire(self):
        """Envoie au plus une interruption, la plus prioritaire d'abord."""
        if self.cia_due and self.cia_mask & 0x01 \
                and self.intena & 0x4000 and self.intena & 0x2000:
            if self.interrupt(6, 0x78):
                self.cia_due -= 1
                self.irq6 += 1
                return
        if self.coper_due and not self.copper_raises():
            self.coper_due = False               # sa liste n'en demande pas
        if self.coper_due:
            self.intreq |= 0x0010                # INTF_COPER
            if self.intena & 0x4000 and self.intena & 0x0010:
                if self.interrupt(3, 0x6c):
                    self.coper_due = False
                    self.irq_coper += 1
                    return
            else:
                self.coper_due = False           # personne ne l'attend
        if self.frame_due:
            self.intreq |= 0x0020                # INTF_VERTB
            if self.intena & 0x4000 and self.intena & 0x0020:
                if self.interrupt(3, 0x6c):
                    self.frame_due = False
                    self.irq3 += 1
            else:
                self.frame_due = False           # personne ne l'attend

    def interrupt(self, level, vector_offset):
        """Detourne le processeur vers un autovecteur, cadre d'exception
        du 68020 compris (format 0 : SR, PC, mot de format)."""
        sr = self.cpu.r_sr()
        if ((sr >> 8) & 7) >= level:
            return False
        vector = self.mem.r32(vector_offset)         # VBR nul dans ce banc
        if not vector:
            return False
        sp = self.cpu.r_reg(15)
        sp -= 2
        self.mem.w16(sp, vector_offset)              # format 0, vecteur x 4
        sp -= 4
        self.mem.w32(sp, self.cpu.r_pc())
        sp -= 2
        self.mem.w16(sp, sr)
        self.cpu.w_reg(15, sp)
        self.cpu.w_sr((sr & ~0x8700) | 0x2000 | (level << 8))
        self.cpu.w_pc(vector)
        return True

    def execute(self, cycles):
        """Comme machine.execute, mais le retour trame tombe en cours de
        route : sans cela une boucle qui attend l'interruption tournerait
        jusqu'a la fin de la tranche."""
        done = 0
        while done < cycles:
            if self.cpu.r_pc() == self.EXIT:
                break                    # le programme a rendu la main
            self.fire()
            pas = min(self.SLICE, cycles - done)
            run = self.machine.execute(pas)
            done += max(getattr(run, "cycles", 0) or 0, 1)
            self.due(pas)
        return done

    # --- dos.library ------------------------------------------------
    def setup_dos(self):
        """Chaque vecteur de dos.library ecrit son numero dans un
        guichet ; le callback fait l'appel sur le disque de l'hote."""
        self.files = {}
        self.next_fh = 1
        self.dos_calls = []
        m = self.mem
        # Les vecteurs sont espaces de six octets : on n'y met qu'un saut
        # vers une amorce rangee plus loin, sinon les sequences se
        # recouvrent et le premier vecteur ecrit se fait effacer.
        for i, off in enumerate(DOS_LVOS):
            thunk = DOSBASE + 0x400 + i * 16
            m.w16(DOSBASE + off, 0x4ef9)             # jmp (xxx).L
            m.w32(DOSBASE + off + 2, thunk)
            m.w16(thunk, 0x33fc)                     # move.w #n,$00f10000
            m.w16(thunk + 2, i)
            m.w32(thunk + 4, DOSPORT)
            m.w16(thunk + 8, 0x2039)                 # move.l $00f10004,d0
            m.w32(thunk + 10, DOSPORT + 4)
            m.w16(thunk + 14, 0x4e75)                # rts

        def r_port(addr, *a):
            if addr == DOSPORT + 4:
                return self.dos_result & 0xffffffff
            if addr == DOSPORT + 12:                 # base de bibliotheque
                name = self.cstr(self.lib_name)
                return DOSBASE if name.startswith("dos") else GFXBASE
            return 0

        def w_port(addr, val, *a):
            if addr == DOSPORT:
                self.dos_result = self.dos_call(list(DOS_LVOS)[val & 0xff])
            elif addr == DOSPORT + 8:
                self.lib_name = val

        self.dos_result = 0
        self.lib_name = 0
        self.mem.reserve_special_range()
        self.mem.set_special_range_read_funcs(DOSPORT, 1, r_port, r_port,
                                              r_port)
        self.mem.set_special_range_write_funcs(DOSPORT, 1, w_port, w_port,
                                               w_port)

    def cstr(self, addr):
        out = b""
        while len(out) < 256:
            c = self.mem.r8(addr + len(out))
            if not c:
                break
            out += bytes([c])
        return out.decode("latin-1")

    def dos_call(self, off):
        name = DOS_LVOS[off]
        d1 = self.cpu.r_reg(1)
        d2 = self.cpu.r_reg(2)
        d3 = self.cpu.r_reg(3)
        self.dos_calls.append(name)
        if name == "open":
            path = self.cstr(d1).replace("PROGDIR:", "")
            full = os.path.join(self.dos_dir, path)
            mode = "r+b" if d2 == 1005 else "w+b"
            try:
                fh = open(full, mode)
            except OSError:
                return 0
            self.next_fh += 1
            self.files[self.next_fh] = fh
            return self.next_fh
        if name == "close":
            fh = self.files.pop(d1, None)
            if fh:
                fh.close()
            return 1
        if name == "read":
            fh = self.files.get(d1)
            if not fh:
                return -1
            data = fh.read(d3)
            for i, b in enumerate(data):
                self.mem.w8(d2 + i, b)
            return len(data)
        if name == "write":
            fh = self.files.get(d1)
            if not fh:
                return -1
            fh.write(bytes(self.mem.r8(d2 + i) for i in range(d3)))
            fh.flush()
            return d3
        return 0
        m.w32(GFXBASE + 34, 0)                       # ActiView
        m.w32(GFXBASE + 38, 0x00030000)              # copinit
        # les registres custom et le CIA sont servis par les callbacks

    def start(self):
        self.cpu.w_reg(15, STACK)                    # a7
        self.cpu.w_sr(0x2000)                        # mode superviseur : voir
        self.cpu.w_pc(self.segs[0][0])               # setup_supervisor()
        self.mem.w16(self.EXIT, 0x60fe)              # bra.s * : il s'arrete la
        self.mem.w32(STACK, self.EXIT)               # adresse de retour

    # --- appel direct d'une routine du jeu -------------------------
    RETURN = 0x0000e000                  # sous la pile, en RAM valide
    # Ou le programme retombe quand il rend la main. C'etait $deadbeef,
    # une adresse hors de la RAM : le processeur y allait chercher ses
    # instructions et machine68k criait a chaque octet lu, des millions
    # de fois par tranche -- vingt-quatre millions de lignes dans le
    # journal des bancs. On l'envoie maintenant sur un bra.s vers
    # lui-meme, en RAM : il tourne en rond sans rien dire.
    EXIT = 0x0000e100

    REGS = "d0 d1 d2 d3 d4 d5 d6 d7 a0 a1 a2 a3 a4 a5 a6 a7".split()

    def call(self, addr, **regs):
        """Execute une routine comme un bsr, puis rend la main.

        Le contexte est remis en place ensuite : sans cela chaque appel
        laisserait la pile du jeu soixante octets plus bas et la boucle
        principale finirait par travailler sur un cadre errant.

        Le retour trame est tenu a l'ecart pendant l'appel : c'est le
        banc qui tient l'horloge ici, et une interruption qui tomberait
        au milieu melerait son travail a celui de la routine examinee --
        un tic de musique par-dessus le bruitage que l'on mesure, par
        exemple. Les tests qui veulent une trame appellent PT_Tick.
        """
        ctx = self.cpu.get_cpu_context()
        self.mem.w16(self.RETURN, 0x60fe)    # bra.s * : on s'arrete la
        sp = (self.cpu.r_reg(15) - 256) & ~1
        self.mem.w32(sp, self.RETURN)
        self.cpu.w_reg(15, sp)
        for name, val in regs.items():
            self.cpu.w_reg(self.REGS.index(name), val & 0xffffffff)
        self.cpu.w_pc(addr)
        done = False
        for _ in range(80):
            self.machine.execute(100000)   # sans retour trame : l'appelant
            if self.cpu.r_pc() == self.RETURN:
                done = True
                break
        self.cpu.set_cpu_context(ctx)
        return done

    # --- souris ----------------------------------------------------
    def mouse_move(self, dx, dy):
        """Fait tourner les compteurs de quadrature, comme la vraie
        souris : le jeu ne lit jamais une position, seulement l'ecart
        depuis la trame precedente."""
        self.mouse_rx = (self.mouse_rx + dx) & 0xff
        self.mouse_ry = (self.mouse_ry + dy) & 0xff

    def mouse_button(self, mask):
        """1 = bouton gauche, 2 = droit ; 0 pour tout relacher."""
        self.mouse_btn = mask

    # --- clavier ---------------------------------------------------
    def press(self, code):
        """Depose une touche ; elle sera servie quand le jeu interrogera
        le CIA, et le drapeau s'efface a la lecture comme sur la machine."""
        self.keys.append(code)

    def offer_key(self):
        if self.icr == 0 and self.keys:
            raw = self.keys.pop(0)
            self.sdr = (~(((raw << 1) | (raw >> 7)) & 0xff)) & 0xff
            self.icr = 0x08

    def run(self, slices=400, cycles=300000, after=6, idle=None):
        """Tourne jusqu'a ce que la touche soit lue, puis quelques
        tranches de plus pour laisser le jeu finir son affichage. Huit
        bitplanes, c'est deux fois plus de blits qu'a quatre : il faut
        laisser le temps au redessin de s'achever."""
        if self.finished:                    # le jeu a rendu la main :
            return "programme termine"       # plus rien a executer
        extra = 0
        for _ in range(slices):
            self.offer_key()
            try:
                self.execute(cycles)
            except Exception as e:
                return f"exception CPU : {e} (pc={self.cpu.r_pc():#x})"
            if self.cpu.r_pc() == self.EXIT:
                self.finished = True
                return "programme termine"
            if not self.keys and self.icr == 0:
                if idle is not None and not idle():
                    continue        # le jeu redessine encore : on le laisse
                extra += 1
                if extra >= after:
                    return None
        return None


if __name__ == "__main__":
    path = sys.argv[1] if len(sys.argv) > 1 else "bin/AGACrawl"
    h = Harness(path)
    print(f"charge : {len(h.segs)} hunks")
    for i, (a, n, _) in enumerate(h.segs):
        print(f"  hunk {i} : {n:7d} octets a {a:#010x}")
    h.start()
    err = h.run(slices=60)
    print("resultat :", err or "toujours en cours (boucle principale)")
    print(f"pc = {h.cpu.r_pc():#x}")
