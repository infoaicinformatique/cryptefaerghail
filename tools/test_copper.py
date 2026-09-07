#!/usr/bin/env python3
"""Relit la copperlist que le jeu construit, instruction par instruction.

Rien ne la verifiait : elle est batie a l'execution, et une erreur d'un
mot y decale tout ce qui suit sans que rien ne proteste. Depuis que le
sol et la voute tiennent leur profondeur du copper -- douze registres
reecrits toutes les deux lignes -- une liste de travers ne donnerait
pas un ecran de travers mais un ecran noir.

On charge donc le jeu, on laisse InitScreen s'executer, et on decode :
les MOVE, les WAIT, la fin, et surtout que le degrade tombe bien sur les
bonnes lignes et dans la bonne banque de couleurs.

    python3 tools/test_copper.py
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import test_game as T

BPLCON0, BPLCON3, BPLCON4 = 0x100, 0x106, 0x10c
FMODE, COLOR00 = 0x1fc, 0x180
BPL1PTH, SPR0PTH = 0x0e0, 0x120


def read_equ(name, default=None, src="crawl.s"):
    for line in open(os.path.join(ROOT, "src", src),
                     encoding="latin-1"):
        if line.split("\t")[0].strip() == name:
            body = line.split("=", 1)[1].split(";")[0].strip()
            try:
                return int(body)
            except ValueError:
                return body
    if default is None:
        raise SystemExit(f"{name} introuvable dans src/{src}")
    return default


def decode(g):
    """-> la liste des instructions : ('move', reg, val) ou ('wait', v, h)."""
    base = g.addr("CopList")
    size = read_equ("COPSIZE")
    out = []
    for off in range(0, size, 4):
        a = g.mem.r16(base + off)
        b = g.mem.r16(base + off + 2)
        if a == 0xffff and b == 0xfffe:
            out.append(("end", 0, 0))
            return out, off + 4
        if a & 1:
            out.append(("wait", (a >> 8) & 0xff, a & 0xfe))
        else:
            out.append(("move", a & 0x1fe, b))
    raise SystemExit("la copperlist ne se termine pas dans COPSIZE")


def check(cond, msg, fails):
    if not cond:
        fails.append(msg)
    return cond


if __name__ == "__main__":
    fails = []
    g = T.Game()
    prog, used = decode(g)
    size = read_equ("COPSIZE")
    moves = [i for i in prog if i[0] == "move"]
    waits = [i for i in prog if i[0] == "wait"]
    print("--- la liste ---")
    print(f"  {len(prog)} instructions, {used} octets sur {size} "
          f"({100 * used // size} %)")
    print(f"  {len(moves)} MOVE, {len(waits)} WAIT")
    check(used <= size, f"la liste deborde : {used} > {size}", fails)
    check(prog[-1][0] == "end", "la liste ne se termine pas", fails)

    print("--- l'ecran ---")
    setup = {reg: val for kind, reg, val in prog[:24] if kind == "move"}
    check(setup.get(BPLCON0) == 0x0211,
          f"BPLCON0 = {setup.get(BPLCON0):#06x}, attendu $0211 (8 plans)", fails)
    check(setup.get(FMODE) == 0, "FMODE devrait rester a zero en lores", fails)
    print(f"  BPLCON0 {setup.get(BPLCON0):#06x} : huit bitplanes, ECSENA")
    print(f"  BPLCON4 {setup.get(BPLCON4):#06x} : couleurs des sprites")
    check(setup.get(BPLCON4) == 0x00ff,
          "BPLCON4 devrait donner le bloc $f0 aux sprites", fails)

    print("--- les pointeurs ---")
    depth = read_equ("DEPTH")
    bpl = [m for m in moves if BPL1PTH <= m[1] < BPL1PTH + 4 * depth]
    spr = [m for m in moves if SPR0PTH <= m[1] < SPR0PTH + 4 * 8]
    check(len(bpl) == 2 * depth, f"{len(bpl)} mots de pointeur de bitplane "
          f"au lieu de {2 * depth}", fails)
    check(len(spr) == 16, f"{len(spr)} mots de pointeur de sprite au lieu "
          f"de 16", fails)
    ptr = (spr[0][2] << 16) | spr[1][2]
    check(ptr == g.addr("MousePointer"),
          f"le sprite 0 pointe sur {ptr:#x} et non sur MousePointer", fails)
    print(f"  {depth} bitplanes, 8 sprites, sprite 0 -> MousePointer")

    print("--- la palette ---")
    banks = [m for m in moves if m[1] == BPLCON3]
    colours = [m for m in moves if COLOR00 <= m[1] < COLOR00 + 64]
    print(f"  {len(banks)} bascules de banque, {len(colours)} ecritures "
          f"de couleur")
    check(len(colours) >= 512, "moins de 512 ecritures : la palette 256 "
          "couleurs n'est pas chargee en entier (LOCT compris)", fails)

    print("--- le degrade du sol et de la voute ---")
    blocks = read_equ("SURF_BLOCKS", src="surfgrad.i")
    lines = read_equ("SURF_LINES", src="surfgrad.i")
    first = read_equ("SURF_FIRST", src="surfgrad.i")
    nsurf = read_equ("N_SURF", src="dgncol.i")
    csurf = read_equ("C_SURF", src="dgncol.i")
    vstart = read_equ("SPR_VSTART")
    if isinstance(vstart, str):
        vstart = int(vstart.lstrip("$"), 16)

    # les WAIT du degrade : ceux qui suivent le chargement de la palette
    grad = [w for w in waits if w[1] >= first + vstart]
    check(len(grad) == blocks,
          f"{len(grad)} attentes de degrade au lieu de {blocks}", fails)
    want = [first + vstart + b * lines for b in range(blocks)]
    got = [w[1] for w in grad]
    check(got == want, "les attentes ne tombent pas sur les bonnes lignes "
          f"(premiere {got[0] if got else '-'}, attendue {want[0]})", fails)

    # chaque bloc doit ecrire N_SURF couleurs deux fois, dans la banque 7
    idx = prog.index(("wait", want[0], grad[0][2]))
    blk = prog[idx:idx + 2 + 2 * nsurf + 1]
    reg0 = COLOR00 + 2 * (csurf - 224)
    check(blk[1] == ("move", BPLCON3, 0xe000),
          f"le bloc n'ouvre pas la banque 7 ({blk[1]})", fails)
    check(blk[2][1] == reg0,
          f"le degrade ecrit {blk[2][1]:#05x} au lieu de {reg0:#05x}", fails)
    check(blk[2 + nsurf] == ("move", BPLCON3, 0xe200),
          "les quartets bas ne sont pas ecrits sous LOCT", fails)
    print(f"  {blocks} blocs de {lines} lignes, {nsurf} couleurs deux fois")
    print(f"  premieres lignes raster {got[:4]}, derniere {got[-1]}")
    print(f"  registres {reg0:#05x}..{reg0 + 2 * nsurf - 2:#05x}, banque 7")
    print(f"  {blocks * nsurf} teintes de profondeur a l'ecran, "
          f"la palette n'en tient que 20")

    # cout : le copper vole des cycles au balayage
    per_line = (2 + 2 * nsurf + 2) * 2 / lines
    print(f"  cout copper : {per_line:.0f} cycles couleur par ligne "
          f"sur 227")
    check(per_line < 60, f"{per_line:.0f} cycles par ligne : le copper "
          "mangerait le balayage", fails)

    print("--- la flamme ---")
    # Le degrade est recopie depuis l'une des clartes preparees : on
    # verifie que la copperlist bouge, et qu'elle ne sort jamais de la
    # table -- une valeur inventee ferait un eclair de couleur fausse.
    variants = read_equ("SURF_VARIANTS", src="surfgrad.i")
    table = g.addr("SurfGradient")
    varsize = read_equ("SURF_VARSIZE", src="surfgrad.i")
    known = set()
    for v in range(variants):
        for w in range(varsize):
            known.add(g.mem.r16(table + (v * varsize + w) * 2))

    def surf_values():
        base = g.mem.r32(g.addr("CopSurf"))
        vals, off = [], 0
        for _ in range(blocks):
            off += 8
            for _ in range(nsurf):
                off += 2
                vals.append(g.mem.r16(base + off))
                off += 2
            off += 4
            for _ in range(nsurf):
                off += 2
                vals.append(g.mem.r16(base + off))
                off += 2
        return vals

    seen, phases = set(), set()
    for _ in range(40):
        g.run(slices=2)
        vals = surf_values()
        seen.add(tuple(vals))
        phases.add(g.w("SurfPhase"))
        check(all(x in known for x in vals),
              "une valeur du degrade ne vient pas de la table", fails)
    print(f"  {len(seen)} etats du degrade en 40 trames, "
          f"phases visitees {sorted(phases)}")
    check(len(seen) > 1, "la flamme ne bouge jamais", fails)
    check(max(phases) < variants, f"phase {max(phases)} hors des "
          f"{variants} clartes", fails)
    cost = blocks * 2 * nsurf
    print(f"  {cost} mots de couleur recopies par changement de clarte")
    check(sorted(phases)[0] <= 1 and max(phases) >= variants - 2,
          f"la flamme ne parcourt que {sorted(phases)} : la marche derive",
          fails)

    print()
    if fails:
        print(f"{len(fails)} anomalie(s) :")
        for f in fails:
            print("  -", f)
        sys.exit(1)
    print("copperlist conforme")
