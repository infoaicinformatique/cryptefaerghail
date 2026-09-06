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
import struct
import sys

from machine68k import CPUType, Machine

RAM_KIB = 2 * 1024                       # 2 Mio de Chip, comme un A1200
BASE = 0x00010000                        # ou l'on charge les hunks
STACK = 0x0000f000
EXECBASE = 0x00001000
GFXBASE = 0x00002000
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
        self.bad_blits = []
        self.audio = []
        self.finished = False
        self.setup_hw()
        self.setup_os()

    # --- chipset ---------------------------------------------------
    def setup_hw(self):
        mem = self.mem
        mem.reserve_special_range()                  # $dff000
        mem.reserve_special_range()                  # $bfe000

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
                return 0                             # blitter au repos
            return self.custom.get(off, 0)

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

        def w_custom(addr, val, *a):
            off = addr - CUSTOM
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

        def r_cia(addr, *a):
            if addr == 0xbfed01:                     # ICR : lecture = effacement
                v = self.icr
                self.icr = 0
                return v
            if addr == 0xbfec01:                     # SDR : code clavier
                return self.sdr
            if addr == 0xbfe001:                     # boutons souris relaches
                return 0xff
            return 0

        def w_cia(addr, val, *a):
            pass

        mem.set_special_range_read_funcs(CUSTOM, 1, r_custom, r_custom,
                                         r_custom32)
        mem.set_special_range_write_funcs(CUSTOM, 1, w_custom, w_custom,
                                          w_custom32)
        mem.set_special_range_read_funcs(0xbfe000, 1, r_cia, r_cia, r_cia)
        mem.set_special_range_write_funcs(0xbfe000, 1, w_cia, w_cia, w_cia)
        self.sdr = 0xff

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
        stub_library(m, EXECBASE, {-552: GFXBASE})   # OpenLibrary
        stub_library(m, GFXBASE)
        m.w32(GFXBASE + 34, 0)                       # ActiView
        m.w32(GFXBASE + 38, 0x00030000)              # copinit
        # les registres custom et le CIA sont servis par les callbacks

    def start(self):
        self.cpu.w_reg(15, STACK)                    # a7
        self.cpu.w_pc(self.segs[0][0])
        self.mem.w32(STACK, 0xdeadbeef)              # adresse de retour

    # --- appel direct d'une routine du jeu -------------------------
    RETURN = 0x0000e000                  # sous la pile, en RAM valide

    REGS = "d0 d1 d2 d3 d4 d5 d6 d7 a0 a1 a2 a3 a4 a5 a6 a7".split()

    def call(self, addr, **regs):
        """Execute une routine comme un bsr, puis rend la main.

        Le contexte est remis en place ensuite : sans cela chaque appel
        laisserait la pile du jeu soixante octets plus bas et la boucle
        principale finirait par travailler sur un cadre errant.
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
            self.machine.execute(100000)
            if self.cpu.r_pc() == self.RETURN:
                done = True
                break
        self.cpu.set_cpu_context(ctx)
        return done

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

    def run(self, slices=400, cycles=200000, after=3):
        """Tourne jusqu'a ce que la touche soit lue, puis quelques
        tranches de plus pour laisser le jeu finir son affichage."""
        if self.finished:                    # le jeu a rendu la main :
            return "programme termine"       # plus rien a executer
        extra = 0
        for _ in range(slices):
            self.offer_key()
            try:
                self.machine.execute(cycles)
            except Exception as e:
                return f"exception CPU : {e} (pc={self.cpu.r_pc():#x})"
            if self.cpu.r_pc() == 0xdeadbeef:
                self.finished = True
                return "programme termine"
            if not self.keys and self.icr == 0:
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
