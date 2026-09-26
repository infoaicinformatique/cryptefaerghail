#!/usr/bin/env python3
"""Les creatures de la crypte, modelees en volumes plutot que peintes a plat.

Les premieres silhouettes avaient ete dessinees pour seize couleurs :
des ellipses d'une seule teinte, des traits d'un pixel, et c'etait tout.
La palette en a maintenant deux cent cinquante-six, rangees matiere par
matiere en gammes continues ; on s'en sert ici comme d'un eclairage.

Chaque creature est une petite scene : des ellipsoides (un crane, un
ventre, une epaule), des membres en tronc de cone (un bras, un cou, une
hampe), des plaques planes (une aile, une lame, une oreille). On les
rend a travers un tampon de profondeur, on eclaire chaque pixel selon sa
normale -- la meme lumiere que les portraits, venue d'en haut a gauche
et de devant --, puis on cerne la silhouette et les recouvrements d'un
trait sombre, pour qu'elle se detache du couloir. Les yeux, les dents
et les griffes se posent ensuite, au pixel.

Trois poses par famille : deux qui respirent, et une qui frappe -- le
jeu la montre quand le monstre attaque.

    python3 tools/monsters.py planche.png      # les neuf familles
"""
import math
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import palette as pal                            # noqa: E402

W, H = 96, 88                                    # le cadre d'une creature
GROUND = 85                                      # la ligne des pieds
NPOSES = 3                                       # repos, souffle, attaque
LIGHT = (-0.50, -0.62, 0.60)
_n = math.sqrt(sum(c * c for c in LIGHT))
LIGHT = tuple(c / _n for c in LIGHT)


def noise(a, b, seed=0):
    h = (a * 374761393 + b * 668265263 + seed * 362437) & 0xffffffff
    h = (h ^ (h >> 13)) * 1274126177 & 0xffffffff
    return ((h >> 16) & 0xff) / 255.0


# --- les grains de matiere ----------------------------------------------
def tex_none(x, y):
    return 0.0


def tex_fur(x, y):
    """Des meches : un bruit etire vers le bas."""
    return (noise(x, y // 3, 5) - 0.5) * 0.20


def tex_scale(x, y):
    """Des ecailles en quinconce : un liseré sombre au bas de chacune."""
    row = y // 3
    col = (x + (row & 1) * 2) // 4
    dy = y % 3
    return (0.10 if dy == 2 else -0.03) + (noise(col, row, 9) - 0.5) * 0.06


def tex_wrap(x, y):
    """Des bandelettes en biais, qui ne se recouvrent jamais tout a fait."""
    k = (y * 2 + x) // 5
    return (0.14 if (y * 2 + x) % 5 == 0 else 0.0) + (noise(k, 1, 3) - 0.5) * 0.10


def tex_stone(x, y):
    return (noise(x // 2, y // 2, 11) - 0.5) * 0.14 + \
        (0.12 if noise(x, y, 12) > 0.93 else 0.0)


def tex_hide(x, y):
    """Une peau epaisse : un grain, sans motif."""
    return (noise(x // 2, y // 2, 31) - 0.5) * 0.10


def tex_rag(x, y):
    return (noise(x // 2, y, 21) - 0.5) * 0.16


TEX = {"none": tex_none, "fur": tex_fur, "scale": tex_scale,
       "wrap": tex_wrap, "stone": tex_stone, "rag": tex_rag,
       "hide": tex_hide}

BAYER = ((0, 8, 2, 10), (12, 4, 14, 6), (3, 11, 1, 9), (15, 7, 13, 5))

SHINY = {"IRON": 0.55, "STEEL": 0.70, "BONE": 0.20, "SCALE": 0.30,
         "GOLD": 0.60, "MAGIC": 0.40}


class Rig:
    """Une scene : des volumes, rendus ensemble a travers un tampon de
    profondeur."""

    def __init__(self):
        self.prims = []
        self.marks = []                          # les details au pixel

    # -- volumes --
    def ball(self, x, y, rx, ry, z, mat, rz=None, tex="none", lift=0.0):
        """Un ellipsoide centre en (x, y), de profondeur de base z."""
        self.prims.append(("ball", x, y, rx, ry, z, mat,
                           rz if rz is not None else min(rx, ry), tex, lift))

    def limb(self, x0, y0, x1, y1, r0, r1, z0, z1, mat, tex="none",
             lift=0.0):
        """Un membre : tronc de cone arrondi, de (x0,y0) a (x1,y1)."""
        self.prims.append(("limb", x0, y0, x1, y1, r0, r1, z0, z1, mat, tex,
                           lift))

    def plate(self, pts, z, mat, normal=(0.0, -0.3, 1.0), tex="none",
              lift=0.0):
        """Une plaque plane : une lame, une aile, une oreille."""
        n = math.sqrt(sum(c * c for c in normal))
        self.prims.append(("plate", pts, z, mat,
                           tuple(c / n for c in normal), tex, lift))

    # -- details --
    def dot(self, x, y, idx):
        self.marks.append((int(round(x)), int(round(y)), idx))

    def eye(self, x, y, mat="FIRE", size=1):
        """Un oeil qui luit : un coeur clair, un halo, pose par-dessus."""
        for dx in range(-size, size + 1):
            for dy in range(-size + 1, size):
                if abs(dx) + abs(dy) <= size:
                    self.dot(x + dx, y + dy, pal.lit(mat, 0.45))
        self.dot(x, y, pal.lit(mat, 0.0))
        if size > 1:
            self.dot(x - 1, y - 1, pal.one("WHITE"))

    def fang(self, x, y, length=3, down=True):
        for k in range(length):
            self.dot(x, y + (k if down else -k), pal.lit("BONE", 0.05 + 0.1 * k))

    # -- rendu --
    def _hit(self, prim, px, py):
        """-> (profondeur, normale, matiere, grain, eclat) ou None."""
        kind = prim[0]
        if kind == "ball":
            _, x, y, rx, ry, z, mat, rz, tex, lift = prim
            nx, ny = (px - x) / rx, (py - y) / ry
            d = nx * nx + ny * ny
            if d > 1.0:
                return None
            nz = math.sqrt(1.0 - d)
            return z + nz * rz, (nx, ny, nz * 1.1), mat, tex, lift
        if kind == "limb":
            _, x0, y0, x1, y1, r0, r1, z0, z1, mat, tex, lift = prim
            vx, vy = x1 - x0, y1 - y0
            L2 = vx * vx + vy * vy or 1e-6
            t = max(0.0, min(1.0, ((px - x0) * vx + (py - y0) * vy) / L2))
            cx, cy = x0 + vx * t, y0 + vy * t
            r = r0 + (r1 - r0) * t
            dx, dy = px - cx, py - cy
            d = math.sqrt(dx * dx + dy * dy)
            if d > r:
                return None
            nz = math.sqrt(max(0.0, 1.0 - (d / r) ** 2))
            return (z0 + (z1 - z0) * t + nz * r,
                    (dx / r, dy / r, nz), mat, tex, lift)
        _, pts, z, mat, normal, tex, lift = prim
        inside = False
        j = len(pts) - 1
        for i in range(len(pts)):
            xi, yi = pts[i]
            xj, yj = pts[j]
            if (yi > py) != (yj > py) and \
                    px < (xj - xi) * (py - yi) / ((yj - yi) or 1e-9) + xi:
                inside = not inside
            j = i
        if not inside:
            return None
        return z, normal, mat, tex, lift

    def render(self, ambient=0.20):
        """-> grille W x H d'index de palette (None = transparent)."""
        zbuf = [[None] * W for _ in range(H)]
        out = [[None] * W for _ in range(H)]
        for py in range(H):
            for px in range(W):
                best = None
                for prim in self.prims:
                    h = self._hit(prim, px + 0.5, py + 0.5)
                    if h and (best is None or h[0] > best[0]):
                        best = h
                if best is None:
                    continue
                depth, n, mat, tex, lift = best
                ln = math.sqrt(sum(c * c for c in n)) or 1.0
                n = tuple(c / ln for c in n)
                lam = max(0.0, sum(a * b for a, b in zip(n, LIGHT)))
                bright = ambient + (1.0 - ambient) * lam
                spec = SHINY.get(mat, 0.0)
                if spec:                              # un reflet net
                    r = 2 * lam * n[2] - LIGHT[2]
                    bright += spec * max(0.0, r) ** 12
                t = 1.0 - bright - lift + TEX[tex](px, py)
                zbuf[py][px] = depth
                out[py][px] = (mat, max(0.0, min(1.0, t)))

        grid = [[None] * W for _ in range(H)]
        for py in range(H):
            for px in range(W):
                c = out[py][px]
                if c is None:
                    continue
                mat, t = c
                edge = False
                crease = False
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    qx, qy = px + dx, py + dy
                    if not (0 <= qx < W and 0 <= qy < H) or \
                            out[qy][qx] is None:
                        edge = True
                    elif zbuf[qy][qx] - zbuf[py][px] > 3.0:
                        crease = True            # un volume passe devant
                if edge:
                    t = min(1.0, max(t, 0.80) + 0.12)
                elif crease:
                    t = min(1.0, t + 0.22)
                # Une gamme de huit teintes sur une panse de soixante
                # pixels fait des marches : un tramage ordonne d'un
                # demi-cran les fond en degrade.
                n = len(pal.ramp(mat))
                t += (BAYER[py & 3][px & 3] - 7.5) / 16.0 / n
                grid[py][px] = pal.lit(mat, max(0.0, min(1.0, t)))
        for x, y, idx in self.marks:
            if 0 <= x < W and 0 <= y < H:
                grid[y][x] = idx
        return grid


# --- les neuf familles ----------------------------------------------------
# Chacune recoit la pose : 0 et 1 respirent (le jeu les alterne), 2 frappe.
def beast(r, pose):
    """Loup, rat, worg, oursaloup : une bete de trois quarts, gueule en
    avant. Elle frappe en se jetant, gueule ouverte."""
    b = 1 if pose == 1 else 0
    a = pose == 2
    lx, ly = (-7, 5) if a else (0, 0)            # l'elan de la charge
    r.ball(58, 52 - b, 25, 14, 10, "HIDE", tex="fur")          # le corps
    r.ball(62, 45 - b, 20, 8, 16, "HIDE", tex="fur", lift=0.10)  # le dos
    r.ball(38 + lx, 52 + ly // 2 - b, 13, 13, 18, "HIDE", tex="fur")  # poitrail
    for x, s, z in ((42, -1, 22), (48, 1, 4), (70, -1, 20), (76, 1, 4)):
        fx = x + (lx if x < 60 else 0) - (4 if a and x < 60 else 0)
        r.limb(x, 58, fx - 2 * s, 72, 5, 4, z, z, "HIDE", tex="fur")
        r.limb(fx - 2 * s, 72, fx - 3 * s - 2, GROUND - 1, 4, 3, z, z + 1,
               "HIDE", tex="fur", lift=-0.06)
        for k in range(3):                       # les griffes
            r.dot(fx - 3 * s - 4 + k * 2, GROUND, pal.lit("BONE", 0.35))
    for i in range(10):                          # la queue, en fouet
        t = i / 9.0
        x = 82 + 10 * t
        y = 46 - 14 * t + (4 * t * t if pose == 1 else -2 * t * t)
        r.ball(x, y, 4 - 1.8 * t, 4 - 1.8 * t, 6, "HIDE", tex="fur")
    hx, hy = 24 + lx, 42 + ly - b                # la tete
    r.ball(hx, hy, 12, 10, 26, "HIDE", tex="fur")
    for s in (-1, 1):                            # les oreilles
        ex = hx + 3 + s * 5
        r.plate([(ex - 3, hy - 7), (ex + 3, hy - 7), (ex + s, hy - 17)],
                24 + s, "HIDE", normal=(-0.3, -0.4, 1.0), lift=-0.05)
    if a:                                        # la gueule grande ouverte
        r.limb(hx - 4, hy - 1, hx - 18, hy - 4, 6, 4, 28, 30, "HIDE",
               tex="fur")
        r.limb(hx - 4, hy + 5, hx - 16, hy + 12, 5, 3, 27, 29, "HIDE",
               tex="fur", lift=-0.08)
        r.plate([(hx - 17, hy + 1), (hx - 5, hy + 1), (hx - 5, hy + 7),
                 (hx - 15, hy + 9)], 29, "BLOOD", lift=-0.10)
        for k in range(5):
            r.fang(hx - 17 + k * 3, hy + 1, 3)
            r.fang(hx - 15 + k * 3, hy + 8, 2, down=False)
    else:
        r.limb(hx - 4, hy + 2, hx - 17, hy + 5, 6, 4, 28, 30, "HIDE",
               tex="fur")
        r.ball(hx - 18, hy + 4, 3, 3, 33, "HIDE", lift=-0.35)   # la truffe
        for k in range(3):
            r.fang(hx - 14 + k * 3, hy + 8, 2)
    r.eye(hx - 5, hy - 3, "FIRE", 1)
    r.eye(hx + 2, hy - 4, "FIRE", 1)


def undead(r, pose):
    """Squelette, zombi, goule : un mort debout, epee rouillee au poing,
    un lambeau de linceul aux hanches. Il frappe de haut en bas."""
    b = pose == 1
    a = pose == 2
    cx = 46
    # les jambes et le bassin
    for s in (-1, 1):
        r.limb(cx + s * 6, 58, cx + s * 8, 71, 2.5, 2.2, 10, 10, "BONE")
        r.limb(cx + s * 8, 71, cx + s * 9, GROUND - 2, 2.2, 2, 10, 11, "BONE")
        r.ball(cx + s * 8, 71, 3, 3, 12, "BONE")
        r.limb(cx + s * 9, GROUND - 2, cx + s * 9 - 4, GROUND, 2, 2, 12, 12,
               "BONE")
    r.ball(cx, 56, 10, 5, 12, "BONE")
    r.plate([(cx - 13, 54), (cx + 13, 54), (cx + 11, 68), (cx + 3, 64),
             (cx - 2, 70), (cx - 12, 66)], 15, "ROT", tex="rag")
    # la colonne et les cotes
    r.limb(cx, 55, cx, 26, 2.5, 2.5, 8, 8, "BONE")
    for i in range(5):
        y = 30 + i * 4 + (1 if b else 0)
        w = 11 - abs(i - 1.5) * 1.2
        for s in (-1, 1):
            r.limb(cx, y, cx + s * w, y + 3, 1.6, 1.3, 12, 14, "BONE")
    r.limb(cx - 11, 26, cx + 11, 26, 2, 2, 12, 12, "BONE")   # clavicules
    # le bras qui ne frappe pas
    r.limb(cx - 11, 26, cx - 16, 40, 2.2, 2, 14, 16, "BONE")
    r.limb(cx - 16, 40, cx - 20 + (2 if b else 0), 52, 2, 1.8, 16, 18, "BONE")
    # le bras arme, et l'epee
    if a:
        sh, el, ha = (cx + 11, 26), (cx + 20, 18), (cx + 10, 30)
        tip = (cx - 22, 58)
    else:
        sh, el = (cx + 11, 26), (cx + 17, 39)
        ha = (cx + 20, 50 - (2 if b else 0))
        tip = (cx + 30, 18 - (2 if b else 0))
    r.limb(sh[0], sh[1], el[0], el[1], 2.2, 2, 14, 18, "BONE")
    r.limb(el[0], el[1], ha[0], ha[1], 2, 1.8, 18, 22, "BONE")
    dx, dy = tip[0] - ha[0], tip[1] - ha[1]
    L = math.hypot(dx, dy)
    ux, uy = dx / L, dy / L
    r.limb(ha[0] - ux * 4, ha[1] - uy * 4, ha[0] + ux * 3, ha[1] + uy * 3,
           1.8, 1.8, 23, 23, "WOOD")                 # la poignee
    r.limb(ha[0] + ux * 3 - uy * 5, ha[1] + uy * 3 + ux * 5,
           ha[0] + ux * 3 + uy * 5, ha[1] + uy * 3 - ux * 5, 1.4, 1.4, 24, 24,
           "IRON")                                   # la garde
    r.plate([(ha[0] + ux * 4 - uy * 2.2, ha[1] + uy * 4 + ux * 2.2),
             (ha[0] + ux * 4 + uy * 2.2, ha[1] + uy * 4 - ux * 2.2),
             (tip[0] + uy * 0.8, tip[1] - ux * 0.8), tip,
             (tip[0] - uy * 0.8, tip[1] + ux * 0.8)],
            25, "IRON", normal=(-0.2, -0.6, 1.0), tex="stone")
    # le crane
    hx, hy = cx + (-3 if a else 0), 14 + (1 if b else 0)
    r.ball(hx, hy, 9, 10, 16, "BONE")
    r.ball(hx, hy + 8, 6, 4, 17, "BONE", lift=-0.05)     # la machoire
    for s in (-1, 1):
        r.ball(hx + s * 4, hy, 3, 3.5, 30, "IRON", lift=-0.7)  # orbites
        r.eye(hx + s * 4, hy, "MAGIC", 1)
    r.ball(hx, hy + 5, 1.5, 2, 30, "IRON", lift=-0.7)     # le nez
    for k in range(-3, 4, 2):
        r.dot(hx + k, hy + 9 + (1 if a else 0), pal.lit("IRON", 0.9))


def goblin(r, pose):
    """Kobold, gobelin, hobgobelin : petit, voute, de grandes oreilles,
    une lance plus haute que lui. Il frappe d'estoc, la pointe sur vous."""
    b = pose == 1
    a = pose == 2
    cx = 44
    for s in (-1, 1):                            # les jambes arquees
        r.limb(cx + s * 7, 60, cx + s * 11, 72, 4, 3.5, 10, 12, "MOSS")
        r.limb(cx + s * 11, 72, cx + s * 9, GROUND - 1, 3.5, 3, 12, 13, "MOSS")
        r.ball(cx + s * 9 - 2, GROUND - 1, 5, 2.5, 14, "HIDE")
    r.ball(cx, 52 + b, 15, 13, 14, "HIDE", tex="rag")    # la tunique
    r.limb(cx - 14, 58, cx + 14, 58, 2, 2, 20, 20, "WOOD")   # la ceinture
    r.ball(cx + 2, 60, 2, 2, 23, "GOLD")
    # la tete, enfoncee dans les epaules
    hx, hy = cx - 1 + (-2 if a else 0), 32 + b
    for s in (-1, 1):
        ex = hx + s * 11
        r.plate([(ex - s * 1, hy - 4), (ex - s * 1, hy + 3),
                 (ex + s * 14, hy - 10 + (2 if b else 0))], 18, "MOSS",
                normal=(s * 0.4, -0.3, 1.0), lift=-0.05)
    r.ball(hx, hy, 11, 10, 20, "MOSS")
    r.ball(hx, hy + 5, 7, 4, 24, "MOSS", lift=-0.04)       # le museau
    r.ball(hx, hy + 1, 2.5, 3, 28, "MOSS", lift=0.05)      # le nez
    r.eye(hx - 5, hy - 3, "GOLD", 1)
    r.eye(hx + 5, hy - 3, "GOLD", 1)
    for k in (-4, -1, 2, 5):
        r.fang(hx + k, hy + 7, 2)
    # le bras libre
    r.limb(cx - 13, 46, cx - 19, 58 - (2 if b else 0), 3.5, 3, 16, 18, "MOSS")
    # la lance
    if a:
        hand = (cx + 6, 54)
        butt, tip = (cx + 30, 30), (cx - 10, 74)
        r.limb(cx + 13, 46, hand[0], hand[1], 3.5, 3, 18, 26, "MOSS")
    else:
        hand = (cx + 20, 50 - (2 if b else 0))
        butt, tip = (cx + 22, GROUND - 2), (cx + 18, 4)
        r.limb(cx + 13, 46, hand[0], hand[1], 3.5, 3, 16, 20, "MOSS")
    r.limb(butt[0], butt[1], tip[0], tip[1], 1.4, 1.4, 22, 30 if a else 22,
           "WOOD")
    dx, dy = tip[0] - butt[0], tip[1] - butt[1]
    L = math.hypot(dx, dy)
    ux, uy = dx / L, dy / L
    base = (tip[0] - ux * 9, tip[1] - uy * 9)
    r.plate([(base[0] - uy * 3.5, base[1] + ux * 3.5), tip,
             (base[0] + uy * 3.5, base[1] - ux * 3.5)],
            31 if a else 23, "IRON", normal=(-0.3, -0.5, 1.0))
    r.ball(hand[0], hand[1], 3.5, 3.5, 32 if a else 24, "MOSS")


def brute_armed(r, pose):
    """Orc, gnoll, bugbear, homme-lezard : un guerrier trapu en
    cuir clouté, epaulieres de fer, une hache. Il frappe de toute sa
    hauteur, la hache ramenee sur l'epaule puis abattue."""
    b = pose == 1
    a = pose == 2
    cx = 46
    for s in (-1, 1):                            # les jambes
        r.limb(cx + s * 8, 58, cx + s * 11, 72, 6, 5, 10, 12, "SCALE",
               tex="hide")
        r.limb(cx + s * 11, 72, cx + s * 11, GROUND - 2, 5, 4.5, 12, 13,
               "HIDE")
        r.ball(cx + s * 11, GROUND - 1, 6, 3, 14, "HIDE")
    r.ball(cx, 44 + b, 20, 18, 14, "SCALE", tex="hide")      # le torse
    r.ball(cx, 48 + b, 17, 14, 18, "HIDE", tex="rag")          # la broigne
    for k in range(4):                                         # les clous
        for s in (-1, 1):
            r.dot(cx + s * (5 + k % 2 * 5), 42 + k * 5 + b, pal.lit("IRON", 0.15))
    r.limb(cx - 18, 58, cx + 18, 58, 3, 3, 24, 24, "WOOD")    # le ceinturon
    r.ball(cx, 58, 4, 3, 28, "IRON")
    for s in (-1, 1):                                          # epaulieres
        r.ball(cx + s * 18, 32 + b, 8, 6, 22, "IRON")
    # la tete : machoire lourde, defenses
    hx, hy = cx + (-3 if a else 0), 22 + b
    r.ball(hx, hy, 11, 11, 22, "SCALE", tex="hide")
    r.ball(hx, hy + 6, 9, 5, 26, "SCALE", tex="hide", lift=-0.04)
    r.limb(hx - 8, hy - 5, hx + 8, hy - 5, 2.5, 2.5, 28, 28, "SCALE",
           lift=-0.1)                                          # l'arcade
    r.eye(hx - 4, hy - 2, "BLOOD", 1)
    r.eye(hx + 4, hy - 2, "BLOOD", 1)
    for s in (-1, 1):
        r.fang(hx + s * 5, hy + 7, 4, down=False)
    for k in range(6):                                         # la criniere
        r.limb(hx - 6 + k * 2.4, hy - 10, hx - 8 + k * 3, hy - 16 + (k % 2),
               1.6, 1, 18, 18, "HAIRD")
    # le bras gauche, le poing serre
    r.limb(cx - 20, 34, cx - 26, 48, 5, 4.5, 18, 22, "SCALE", tex="hide")
    r.ball(cx - 27, 51 - (2 if b else 0), 5, 5, 24, "SCALE")
    # le bras de la hache
    if a:
        el, hand = (cx + 22, 22), (cx + 6, 40)
        head = (cx - 20, 52)
    else:
        el, hand = (cx + 28, 44), (cx + 30, 30 - (2 if b else 0))
        head = (cx + 33, 6 - (2 if b else 0))
    r.limb(cx + 20, 34, el[0], el[1], 5, 4.5, 18, 24, "SCALE", tex="hide")
    r.limb(el[0], el[1], hand[0], hand[1], 4.5, 4, 24, 28, "SCALE",
           tex="hide")
    dx, dy = head[0] - hand[0], head[1] - hand[1]
    L = math.hypot(dx, dy)
    ux, uy = dx / L, dy / L
    r.limb(hand[0] - ux * 12, hand[1] - uy * 12, head[0], head[1], 1.8, 1.8,
           30, 30, "WOOD")
    px, py = -uy, ux                                           # le fer :
    if px > 0:                                                 # un croissant
        px, py = -px, -py
    blade = []
    for k in range(9):
        ang = -1.1 + k * 2.2 / 8
        blade.append((head[0] - ux * 3 + px * (6 + 9 * math.cos(ang)) + ux * 11 * math.sin(ang),
                      head[1] - uy * 3 + py * (6 + 9 * math.cos(ang)) + uy * 11 * math.sin(ang)))
    blade += [(head[0] + ux * 5 + px * 3, head[1] + uy * 5 + py * 3),
              (head[0] - ux * 9 + px * 3, head[1] - uy * 9 + py * 3)]
    r.plate(blade, 31, "IRON", normal=(-0.3, -0.5, 1.0))
    for k in range(9):                                         # le fil
        ang = -1.1 + k * 2.2 / 8
        r.dot(head[0] - ux * 3 + px * (5 + 9 * math.cos(ang)) + ux * 11 * math.sin(ang),
              head[1] - uy * 3 + py * (5 + 9 * math.cos(ang)) + uy * 11 * math.sin(ang),
              pal.lit("STEEL", 0.05))
    r.ball(hand[0], hand[1], 4.5, 4.5, 32, "SCALE")


def ogre(r, pose):
    """Ogre, troll, minotaure, geant des collines : une masse qui remplit
    le couloir, des cornes, une massue. Il frappe en l'abattant."""
    b = pose == 1
    a = pose == 2
    cx = 46
    for s in (-1, 1):
        r.limb(cx + s * 12, 64, cx + s * 15, GROUND - 3, 9, 7, 8, 10, "ROT",
               lift=0.02)
        r.ball(cx + s * 16, GROUND - 1, 9, 4, 12, "ROT", lift=0.1)
    r.ball(cx, 52 + b, 30, 26, 10, "ROT", lift=0.02)            # la panse
    r.ball(cx, 58 + b, 22, 14, 18, "HIDE", tex="fur")              # le pagne
    r.limb(cx - 26, 56, cx + 26, 56, 3, 3, 22, 22, "WOOD")
    r.ball(cx - 4, 42 + b, 18, 13, 16, "ROT", tex="hide", lift=0.08)
    for k in range(14):                                          # le poil
        x = cx - 14 + (k * 7) % 22
        y = 34 + (k * 5) % 14 + b
        r.dot(x, y, pal.lit("HAIRD", 0.4))
    hx, hy = cx + (-4 if a else 0), 18 + b
    for s in (-1, 1):                                            # les cornes
        for k in range(6):
            t = k / 5.0
            r.ball(hx + s * (11 + 10 * t), hy - 6 - 10 * t + 8 * t * t,
                   3.2 - 1.6 * t, 3.2 - 1.6 * t, 18, "BONE")
    r.ball(hx, hy, 14, 13, 20, "ROT", lift=0.06)
    r.ball(hx, hy + 8, 10, 6, 24, "ROT", lift=0.02)
    r.limb(hx - 10, hy - 5, hx - 1, hy - 2, 3, 2.5, 28, 28, "ROT")  # l'arcade,
    r.limb(hx + 10, hy - 5, hx + 1, hy - 2, 3, 2.5, 28, 28, "ROT")  # froncee
    r.eye(hx - 5, hy - 1, "GOLD", 1)
    r.eye(hx + 5, hy - 1, "GOLD", 1)
    r.ball(hx, hy + 9, 5, 1.5, 30, "BLOOD", lift=-0.3)            # la gueule
    for s in (-1, 1):
        r.fang(hx + s * 4, hy + 10, 4, down=False)
    r.ball(hx, hy + 3, 3, 2.5, 30, "ROT", lift=0.06)              # le nez
    # le bras gauche, pendant
    r.limb(cx - 26, 34, cx - 36, 54, 7, 6, 16, 20, "ROT", lift=0.02)
    r.ball(cx - 37, 58 - (2 if b else 0), 7, 7, 22, "ROT", lift=0.02)
    # la massue
    if a:
        el, hand, top = (cx + 30, 20), (cx + 10, 34), (cx - 24, 58)
    else:
        el, hand = (cx + 36, 44), (cx + 38, 30 - (2 if b else 0))
        top = (cx + 42, 2 - (2 if b else 0))
    r.limb(cx + 26, 34, el[0], el[1], 7, 6, 16, 22, "ROT", lift=0.02)
    r.limb(el[0], el[1], hand[0], hand[1], 6, 5.5, 22, 26, "ROT", lift=0.02)
    dx, dy = top[0] - hand[0], top[1] - hand[1]
    L = math.hypot(dx, dy)
    ux, uy = dx / L, dy / L
    r.limb(hand[0] - ux * 6, hand[1] - uy * 6, top[0], top[1], 3, 7.5,
           28, 30, "WOOD", tex="rag")
    for k in range(4):                                           # les clous
        q = 0.55 + k * 0.12
        x = hand[0] + dx * q + (k % 2 * 2 - 1) * 5 * -uy
        y = hand[1] + dy * q + (k % 2 * 2 - 1) * 5 * ux
        r.dot(x, y, pal.lit("IRON", 0.1))
    r.ball(hand[0], hand[1], 6, 6, 32, "ROT", lift=0.02)


def shade(r, pose):
    """Ombre, ombre bleme, spectre : un voile qui ne touche pas le sol,
    une capuche vide ou brulent deux yeux. Il frappe en fondant sur vous,
    les griffes en avant."""
    b = pose == 1
    a = pose == 2
    cx, cy = 48, 44 + (2 if b else 0) + (4 if a else 0)
    grow = 1.15 if a else 1.0
    r.limb(cx, cy - 6, cx, cy + 30, 17 * grow, 8, 8, 8, "IRON", tex="rag",
           lift=-0.05)                           # le voile, qui s'effile
    for i in range(7):                           # les lambeaux, qui flottent
        x = cx - 18 + i * 6
        wob = ((i + pose) % 3 - 1) * 2
        x = cx - 9 + i * 3
        r.limb(x, cy + 28, x + wob * 2 + (i - 3), cy + 40 + (i % 3) * 3, 2.4,
               0.6, 9, 9, "IRON", tex="rag", lift=-0.1)
    hx, hy = cx, cy - 18
    r.ball(hx, hy, 13 * grow, 13, 16, "IRON", tex="rag", lift=0.02)
    r.ball(hx, hy + 2, 8.5 * grow, 9, 24, "IRON", lift=-0.75)    # le vide
    glow = "MAGIC"
    r.eye(hx - 4, hy + 1, glow, 2 if a else 1)
    r.eye(hx + 4, hy + 1, glow, 2 if a else 1)
    for s in (-1, 1):                            # les bras, les griffes
        if a:
            sh, hand = (cx + s * 16, cy - 6), (cx + s * 10, cy + 14)
        else:
            sh, hand = (cx + s * 16, cy - 6), (cx + s * 28, cy - 14 + (3 if b else 0))
        r.limb(sh[0], sh[1], hand[0], hand[1], 5, 3, 30 if a else 14,
               40 if a else 18, "IRON", tex="rag", lift=0.0)
        for k in range(3):
            ang = (-0.5 + k * 0.5) + (0 if s > 0 else math.pi)
            if a:
                ang = math.pi / 2 + (k - 1) * 0.4
            ex = hand[0] + math.cos(ang) * 7
            ey = hand[1] + math.sin(ang) * 7 - (0 if a else 3)
            r.limb(hand[0], hand[1], ex, ey, 1.4, 0.6, 42 if a else 20,
                   44 if a else 22, "BONE", lift=0.1)
    for k in range(40):                          # la lueur qui l'entoure
        ang = k * 2.4
        rad = 28 + (k * 7) % 9
        x = cx + math.cos(ang) * rad * 0.8
        y = cy + math.sin(ang) * rad
        if noise(k, pose, 4) > 0.55:
            r.dot(x, y, pal.lit("MAGIC", 0.55 + 0.3 * noise(k, 2, 5)))


def mummy(r, pose):
    """La momie : un Faerghail qui a refuse qu'on le raye. Des
    bandelettes jaunies, des bras tendus, des yeux de braise. Elle
    frappe en empoignant."""
    b = pose == 1
    a = pose == 2
    cx = 47
    for s in (-1, 1):
        r.limb(cx + s * 7, 58, cx + s * 8, GROUND - 2, 6, 5, 10, 11, "BONE",
               tex="wrap", lift=-0.08)
        r.ball(cx + s * 8, GROUND - 1, 6, 3, 12, "BONE", tex="wrap")
    r.ball(cx, 44, 17, 24, 12, "BONE", tex="wrap", lift=-0.06)
    r.ball(cx, 40, 13, 14, 18, "BONE", tex="wrap")
    for k in range(4):                           # les bandes qui pendent
        x = cx - 12 + k * 8
        r.limb(x, 60 + k % 2 * 3, x + (k % 2) * 2 - 1, 70 + k * 2, 2, 1.2,
               16, 16, "BONE", tex="wrap", lift=0.1)
    hx, hy = cx + (-2 if a else 0), 16 + (1 if b else 0)
    r.ball(hx, hy, 11, 12, 20, "BONE", tex="wrap")
    r.limb(hx - 9, hy - 1, hx + 9, hy - 1, 2.5, 2.5, 30, 30, "EARTH",
           lift=-0.1)                            # la fente des yeux
    r.eye(hx - 4, hy - 1, "FIRE", 1)
    r.eye(hx + 4, hy - 1, "FIRE", 1)
    r.ball(hx + 3, hy + 6, 3, 2, 28, "EARTH", lift=-0.45)     # la bouche
    for s in (-1, 1):                            # les bras tendus
        if a:
            sh, el, hand = (cx + s * 14, 28), (cx + s * 12, 38), (cx + s * 5, 50)
            zz = (18, 26, 32)
        else:
            sh = (cx + s * 14, 28)
            el = (cx + s * 24, 30 + (2 if b else 0))
            hand = (cx + s * 34, 30 + (4 if b else 0))
            zz = (18, 20, 22)
        r.limb(sh[0], sh[1], el[0], el[1], 5, 4.5, zz[0], zz[1], "BONE",
               tex="wrap")
        r.limb(el[0], el[1], hand[0], hand[1], 4.5, 3.5, zz[1], zz[2], "BONE",
               tex="wrap")
        for k in range(4):                       # les doigts decharnes
            fx = hand[0] + s * (3 if not a else 0) + (k - 1.5) * (1.5 if not a else 2.5)
            fy = hand[1] + (4 if not a else 5)
            r.limb(hand[0], hand[1], fx, fy, 1.2, 0.9, zz[2], zz[2] + 1, "ROT")


def winged(r, pose):
    """Gargouille, harpie : une bete de pierre aux ailes de chauve-souris,
    des cornes, des serres. Elle frappe en plongeant, ailes levees."""
    b = pose == 1
    a = pose == 2
    cx = 48
    up = -10 if a else (4 if b else 0)
    for s in (-1, 1):                            # les ailes, membrane et doigts
        root = (cx + s * 8, 36)
        tipx = cx + s * 46
        pts = [root, (cx + s * 22, 14 + up), (tipx, 8 + up * 2)]
        for k in range(4):
            pts.append((cx + s * (44 - k * 8), 34 + up + k * 4 + (2 if k % 2 else 6)))
        pts.append((cx + s * 12, 50))
        r.plate(pts, 4, "STONE", normal=(s * 0.35, -0.2, 1.0), tex="stone",
                lift=-0.12)
        for k in range(4):
            r.limb(cx + s * 22, 14 + up, cx + s * (44 - k * 8),
                   34 + up + k * 4, 1.4, 0.8, 6, 6, "STONE", lift=0.1)
        r.limb(root[0], root[1], cx + s * 22, 14 + up, 3, 2, 6, 6, "STONE",
               tex="stone")
        r.limb(cx + s * 22, 14 + up, tipx, 8 + up * 2, 2, 1, 6, 6, "STONE",
               tex="stone")
    lean = 6 if a else 0
    r.ball(cx, 48 + lean, 14, 18, 14, "STONE", tex="stone", lift=0.1)
    r.ball(cx, 42 + lean, 11, 10, 20, "STONE", tex="stone", lift=0.18)
    for s in (-1, 1):                            # les pattes, les serres
        kx = cx + s * 9
        r.limb(kx, 60 + lean, kx + s * 4, 72 + lean, 4.5, 3.5, 16, 20, "STONE",
               tex="stone")
        r.limb(kx + s * 4, 72 + lean, kx + s * 2, GROUND - 3, 3.5, 2.5, 20, 22,
               "STONE", tex="stone")
        for k in range(3):
            r.limb(kx + s * 2, GROUND - 3, kx + s * 2 + (k - 1) * 4,
                   GROUND, 1.2, 0.6, 22, 23, "IRON", lift=0.2)
        arm = (cx + s * 12, 36 + lean)
        hand = (cx + s * (8 if a else 20), (62 if a else 52) + lean)
        r.limb(arm[0], arm[1], hand[0], hand[1], 3.5, 2.8, 20, 28 if a else 22,
               "STONE", tex="stone")
        for k in range(3):
            r.limb(hand[0], hand[1], hand[0] + (k - 1) * 3, hand[1] + 6,
                   1.2, 0.5, 28 if a else 22, 29 if a else 23, "IRON", lift=0.2)
    hx, hy = cx, 22 + lean + (1 if b else 0)
    for s in (-1, 1):
        r.limb(hx + s * 6, hy - 6, hx + s * 12, hy - 18, 2.4, 0.8, 18, 18,
               "BONE", lift=0.1)
    r.ball(hx, hy, 10, 9, 22, "STONE", tex="stone", lift=0.15)
    r.ball(hx, hy + 5, 6, 4, 26, "STONE", tex="stone", lift=0.1)
    r.eye(hx - 4, hy - 1, "FIRE", 1)
    r.eye(hx + 4, hy - 1, "FIRE", 1)
    if a:
        r.ball(hx, hy + 7, 4, 2.5, 30, "BLOOD", lift=-0.2)
    for s in (-1, 1):
        r.fang(hx + s * 3, hy + 6, 3)


def hydra(r, pose):
    """L'hydre de la citerne : un corps d'ecailles sur ses anneaux, cinq
    cous, cinq tetes qui ne regardent pas ensemble. Elle frappe des trois
    tetes du milieu, gueules ouvertes."""
    b = pose == 1
    a = pose == 2
    cx = 48
    for i in range(12):                          # la queue, en anneau
        t = i / 11.0
        ang = 0.2 + t * 3.4
        r.ball(cx + math.cos(ang) * 28, 74 + math.sin(ang) * 6,
               6 - 2.5 * t, 5 - 2 * t, 6 + 6 * math.sin(ang), "SCALE",
               tex="scale")
    r.ball(cx, 68, 24, 14, 12, "SCALE", tex="scale")
    r.ball(cx, 72, 18, 7, 18, "SCALE", tex="scale", lift=0.25)  # le ventre
    heads = [(-34, 26, 0.0), (-20, 10, 0.6), (0, 4, 1.2), (20, 10, 1.8),
             (34, 26, 2.4)]
    for i, (hx, hy, ph) in enumerate(heads):
        strike = a and 1 <= i <= 3
        wob = math.sin(ph + pose * 1.7) * 3
        tx = cx + hx * (0.55 if strike else 1.0)
        ty = hy + wob + (26 if strike else 0)
        z = 30 if strike else 16 + (i == 2) * 2
        mid = ((cx + tx) / 2 + hx * 0.25, (62 + ty) / 2 - 8)
        for k in range(8):                       # le cou, en S
            t = k / 7.0
            x = (1 - t) ** 2 * cx + 2 * (1 - t) * t * mid[0] + t * t * tx
            y = (1 - t) ** 2 * 62 + 2 * (1 - t) * t * mid[1] + t * t * ty
            rr = 5.2 - 1.8 * t
            r.ball(x, y, rr, rr, 14 + (z - 14) * t, "SCALE", tex="scale")
        face = -1 if hx < 0 else 1
        if i == 2:
            face = 0
        r.ball(tx, ty, 7, 6, z + 2, "SCALE", tex="scale")
        mx = tx + face * 6
        if strike:                               # la gueule ouverte
            r.limb(tx, ty - 1, mx + face * 3, ty - 4, 3.5, 2.5, z + 4, z + 6,
                   "SCALE", tex="scale")
            r.limb(tx, ty + 3, mx + face * 2, ty + 7, 3, 2, z + 3, z + 5,
                   "SCALE", tex="scale", lift=-0.1)
            r.ball(mx, ty + 2, 3.5, 2.5, z + 5, "BLOOD", lift=-0.1)
            for k in range(3):
                r.fang(mx - 2 + k * 2, ty - 1, 2)
        else:
            r.limb(tx, ty + 1, mx + face * 2, ty + 2, 4, 3, z + 3, z + 5,
                   "SCALE", tex="scale")
        r.limb(tx - 4, ty - 5, tx - 6 - face * 2, ty - 10, 1.4, 0.5, z, z,
               "BONE")                           # les cretes
        r.limb(tx + 4, ty - 5, tx + 6 - face * 2, ty - 10, 1.4, 0.5, z, z,
               "BONE")
        r.eye(tx - 3 + face, ty - 2, "GOLD", 1)
        r.eye(tx + 3 + face, ty - 2, "GOLD", 1)


FAMILIES = [beast, undead, goblin, brute_armed, ogre, shade, mummy, winged,
            hydra]


def draw(kind, pose):
    """-> grille W x H d'index de palette, None pour le transparent."""
    r = Rig()
    FAMILIES[kind](r, pose)
    return r.render()


if __name__ == "__main__":
    from PIL import Image
    out = sys.argv[1] if len(sys.argv) > 1 else "monstres.png"
    only = [int(a) for a in sys.argv[2:]] or range(len(FAMILIES))
    tw, th = W * NPOSES + 8, H + 8
    rows = list(only)
    sheet = Image.new("RGB", (tw * 3, th * ((len(rows) + 2) // 3)),
                      (40, 38, 34))
    for n, k in enumerate(rows):
        for pose in range(NPOSES):
            g = draw(k, pose)
            for y in range(H):
                for x in range(W):
                    if g[y][x] is not None:
                        sheet.putpixel(((n % 3) * tw + pose * W + x,
                                        (n // 3) * th + y),
                                       tuple(pal.PALETTE[g[y][x]]))
    sheet.resize((sheet.width * 2, sheet.height * 2),
                 Image.NEAREST).save(out)
    print(out)
