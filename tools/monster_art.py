#!/usr/bin/env python3
"""Les monstres du donjon, sculptes puis peints a la maniere de 1991.

Les premieres creatures etaient des ellipses a plat, une teinte chacune.
On les modele ici en volumes -- spheres, membres effiles, plaques
biseautees -- qui laissent une carte de hauteurs. Mais on ne les rend
pas en relief lisse : comme les peintres d'Eye of the Beholder, on
pose quatre tons par matiere en aplats -- ombre, demi-teinte, lumiere,
eclat -- selon la torche en haut a gauche, un trait noir autour de la
creature, un trait sombre entre ses volumes, et des coups de pinceau
pour les meches, les fibres, les ecailles et les muscles.

Le resultat reste un bitmap 96 x 88 par pose, deux poses par famille,
que gen_dungeon.py encode comme le reste de l'art.

    python3 tools/monster_art.py      # planche dans /tmp/monstres.png
"""
import math
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import palette as pal                     # noqa: E402

W, H = 96, 88
NEG = -1e9

# matiere : gamme, grain, brillance, decalage de lumiere, emissive
MATS = {
    "fur":     ("STONE",  "fur",    0.0, -0.04, None),
    "furlt":   ("HAIRL",  "fur",    0.0, -0.05, None),
    "bone":    ("BONE",   "speck",  0.35, 0.00, None),
    "horn":    ("BONE",   "ring",   0.45, -0.12, None),
    "iron":    ("IRON",   "speck",  0.55, 0.05, None),
    "rust":    ("EARTH",  "speck",  0.25, -0.05, None),
    "steel":   ("STEEL",  None,     0.95, 0.00, None),
    "wood":    ("WOOD",   "grain",  0.10, 0.00, None),
    "gob":     ("MOSS",   "mottle", 0.15, 0.00, None),
    "orc":     ("ROT",    "mottle", 0.20, 0.00, None),
    "hide":    ("HIDE",   "mottle", 0.15, 0.05, None),
    "leather": ("EARTH",  "mottle", 0.20, -0.10, None),
    "clothr":  ("CLOTHR", "fold",   0.00, 0.05, None),
    "robe":    ("CLOTHP", "fold",   0.00, -0.05, None),
    "wrap":    ("BONE",   "band",   0.05, -0.08, None),
    "stone":   ("STONE",  "speck",  0.20, -0.05, None),
    "scale":   ("SCALE",  "scale",  0.50, 0.00, None),
    "belly":   ("EARTH",  "band",   0.20, 0.10, None),
    "gold":    ("GOLD",   None,     1.00, 0.05, None),
    "hair":    ("HAIRD",  "fur",    0.10, 0.00, None),
    "teeth":   ("BONE",   None,     0.30, 0.25, None),
    "dark":    ("MORTAR", None,     0.0,  0.00, 0.05),
    "gums":    ("BLOOD",  None,     0.10, -0.10, None),
    "eyeR":    ("FIRE",   None,     0.0,  0.00, 0.92),
    "eyeY":    ("GOLD",   None,     0.0,  0.00, 0.95),
    "eyeB":    ("MAGIC",  None,     0.0,  0.00, 0.95),
    "glow":    ("MAGIC",  None,     0.0,  0.00, 0.55),
}

LIGHT = (-0.46, -0.62, 0.64)              # torche : en haut, a gauche


def _norm(v):
    n = math.sqrt(sum(c * c for c in v))
    return tuple(c / n for c in v)


LIGHT = _norm(LIGHT)


def hash2(x, y, seed=0):
    n = (x * 374761393 + y * 668265263 + seed * 144665) & 0xffffffff
    n = ((n ^ (n >> 13)) * 1274126177) & 0xffffffff
    return ((n ^ (n >> 16)) & 0xffff) / 65535.0


def vnoise(x, y, seed=0):
    """Bruit de valeur lisse, deterministe."""
    xi, yi = math.floor(x), math.floor(y)
    fx, fy = x - xi, y - yi
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a, b = hash2(xi, yi, seed), hash2(xi + 1, yi, seed)
    c, d = hash2(xi, yi + 1, seed), hash2(xi + 1, yi + 1, seed)
    return (a + (b - a) * fx) * (1 - fy) + (c + (d - c) * fx) * fy


def stroke(kind, x, y):
    """Coup de pinceau d'une matiere : -1 assombrit d'un ton, +1
    eclaircit, 0 laisse l'aplat."""
    if kind == "fur":                    # meches qui tombent
        v = vnoise(x * 0.8, y * 0.2, 1)
        return -1 if v < 0.28 else (1 if v > 0.82 else 0)
    if kind == "mottle":
        return -1 if vnoise(x * 0.35, y * 0.35, 3) < 0.13 else 0
    if kind == "speck":
        return -1 if hash2(x, y, 6) < 0.07 else 0
    if kind == "grain":                  # fibres du bois
        return -1 if vnoise(x * 0.3, y * 1.4, 7) < 0.3 else 0
    if kind == "fold":                   # plis d'etoffe tombants
        v = math.sin(x * 0.55 + vnoise(x * 0.1, y * 0.08, 8) * 5)
        return -1 if v < -0.55 else (1 if v > 0.85 else 0)
    if kind == "band":                   # jours entre les bandelettes
        v = math.sin((y + 2.0 * math.sin(x * 0.25)) * 1.25)
        return -1 if v < -0.55 else 0
    if kind == "ring":                   # anneaux de la corne
        return -1 if (x + y) % 4 == 0 else 0
    if kind == "scale":                  # ecailles en quinconce
        row = y // 3
        u = (x + (row % 2) * 2) % 4
        return -1 if (y % 3 == 2 or u == 3) else (1 if u == 0 and y % 3 == 0
                                                  else 0)
    return 0


class Sculpt:
    def __init__(self):
        self.h = [[NEG] * W for _ in range(H)]
        self.m = [[None] * W for _ in range(H)]
        self.g = [[0] * W for _ in range(H)]
        self.ngroup = 0
        self.inked = {}

    def _grp(self, g):
        if g is None:
            self.ngroup += 1
            return self.ngroup
        return g

    def _put(self, x, y, z, mat, g):
        if 0 <= x < W and 0 <= y < H and z > self.h[y][x]:
            self.h[y][x], self.m[y][x], self.g[y][x] = z, mat, g

    # --- volumes -----------------------------------------------------
    def ell(self, cx, cy, rx, ry, z, mat, g=None, depth=None, clip=None):
        """Demi-ellipsoide pose a la hauteur z."""
        g = self._grp(g)
        depth = min(rx, ry) if depth is None else depth
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            if clip and not (clip[0] <= y <= clip[1]):
                continue
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                q = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
                if q <= 1.0:
                    self._put(x, y, z + depth * math.sqrt(1.0 - q), mat, g)
        return g

    def cap(self, pts, r, z, mat, g=None):
        """Membre effile le long d'une ligne brisee : pts, rayons et
        hauteurs par sommet (un scalaire vaut pour tous)."""
        g = self._grp(g)
        n = len(pts)
        rs = r if isinstance(r, (list, tuple)) else [r] * n
        zs = z if isinstance(z, (list, tuple)) else [z] * n
        for i in range(n - 1):
            (x0, y0), (x1, y1) = pts[i], pts[i + 1]
            r0, r1, z0, z1 = rs[i], rs[i + 1], zs[i], zs[i + 1]
            dx, dy = x1 - x0, y1 - y0
            ll = dx * dx + dy * dy or 1e-9
            rm = max(r0, r1)
            for y in range(int(min(y0, y1) - rm) - 1, int(max(y0, y1) + rm) + 2):
                for x in range(int(min(x0, x1) - rm) - 1,
                               int(max(x0, x1) + rm) + 2):
                    t = max(0.0, min(1.0, ((x - x0) * dx + (y - y0) * dy) / ll))
                    px, py = x0 + dx * t, y0 + dy * t
                    rr = r0 + (r1 - r0) * t
                    d2 = (x - px) ** 2 + (y - py) ** 2
                    if d2 <= rr * rr:
                        self._put(x, y, z0 + (z1 - z0) * t
                                  + math.sqrt(rr * rr - d2), mat, g)
        return g

    def poly(self, pts, z, mat, g=None, bevel=2.0):
        """Plaque plate, biseautee sur ses bords."""
        g = self._grp(g)
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        n = len(pts)
        for y in range(int(min(ys)), int(max(ys)) + 2):
            for x in range(int(min(xs)), int(max(xs)) + 2):
                inside, dmin = False, 1e9
                for i in range(n):
                    (ax, ay), (bx, by) = pts[i], pts[(i + 1) % n]
                    if (ay > y) != (by > y) and \
                            x < ax + (y - ay) * (bx - ax) / (by - ay):
                        inside = not inside
                    ex, ey = bx - ax, by - ay
                    ll = ex * ex + ey * ey or 1e-9
                    t = max(0.0, min(1.0, ((x - ax) * ex + (y - ay) * ey) / ll))
                    dmin = min(dmin, math.hypot(x - ax - ex * t, y - ay - ey * t))
                if inside:
                    self._put(x, y, z + min(dmin, bevel), mat, g)
        return g

    # --- decors poses sur un volume ----------------------------------
    def paint(self, cx, cy, rx, ry, mat, dz=0.0, only=None):
        """Recolore une ellipse sur ce qui est deja modele, en la
        creusant de dz : orbites, gueules, taches."""
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                if 0 <= x < W and 0 <= y < H and self.m[y][x] and \
                        ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                    if only and self.m[y][x] not in only:
                        continue
                    self.m[y][x] = mat
                    self.h[y][x] += dz

    def dot(self, x, y, mat, z=None):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < W and 0 <= y < H:
            if self.m[y][x] is None:
                self.h[y][x] = z if z is not None else 0.0
                self.g[y][x] = self._grp(None)
            self.m[y][x] = mat

    def line(self, x0, y0, x1, y1, mat):
        steps = int(max(abs(x1 - x0), abs(y1 - y0), 1))
        for i in range(steps + 1):
            self.dot(x0 + (x1 - x0) * i / steps, y0 + (y1 - y0) * i / steps, mat)

    def fang(self, x, y, length, down=True):
        """Croc : deux pixels de large a la racine, un a la pointe."""
        s = 1 if down else -1
        for k in range(length):
            self.dot(x, y + s * k, "teeth")
            if k < length // 2:
                self.dot(x + 1, y + s * k, "teeth")

    def ink(self, pts):
        """Trait de pinceau sur ce qui est modele : muscles, plis, cotes.
        Il prend le ton le plus sombre de la matiere qu'il traverse."""
        for i in range(len(pts) - 1):
            (x0, y0), (x1, y1) = pts[i], pts[i + 1]
            steps = int(max(abs(x1 - x0), abs(y1 - y0), 1))
            for k in range(steps + 1):
                x = int(round(x0 + (x1 - x0) * k / steps))
                y = int(round(y0 + (y1 - y0) * k / steps))
                if 0 <= x < W and 0 <= y < H and self.m[y][x]:
                    self.inked[(x, y)] = self.g[y][x]

    # --- eclairage ---------------------------------------------------
    def render(self):
        """-> lignes d'index de palette, None pour le transparent.

        A la maniere des peintres de 1991 : quatre tons par matiere, poses
        en aplats -- ombre, demi-teinte, lumiere, eclat --, un trait noir
        autour de la creature et un trait sombre entre ses volumes. Le
        grain n'est plus un bruit mais des coups de pinceau : une meche,
        une fibre, une ecaille baissent ou levent le ton d'un cran."""
        h, m, g = self.h, self.m, self.g
        black = pal.one("BLACK")

        def hz(x, y, own):
            if 0 <= x < W and 0 <= y < H and m[y][x]:
                return h[y][x]
            return own - 4.0                 # le vide tombe : bord arrondi

        out = [[None] * W for _ in range(H)]
        for y in range(H):
            for x in range(W):
                mat = m[y][x]
                if mat is None:
                    continue
                rampname, tex, spec, bias, emis = MATS[mat]
                ramp = pal.ramp(rampname)
                n = len(ramp)
                tones = [ramp[int(round(fr * (n - 1)))]
                         for fr in (0.0, 0.18, 0.42, 0.68, 0.94)]
                z = h[y][x]
                edge = False
                inner = False
                for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                    ax, ay = x + dx, y + dy
                    if not (0 <= ax < W and 0 <= ay < H) or m[ay][ax] is None:
                        edge = True
                    elif g[ay][ax] != g[y][x] and h[ay][ax] > z + 0.5:
                        inner = True
                if edge:
                    out[y][x] = black
                    continue
                if emis is not None:
                    out[y][x] = ramp[max(0, min(n - 1, int(round(emis * (n - 1)))))]
                    continue
                if inner or self.inked.get((x, y)) == g[y][x]:
                    out[y][x] = tones[0]
                    continue
                gx = (hz(x + 1, y, z) - hz(x - 1, y, z)) * 0.5
                gy = (hz(x, y + 1, z) - hz(x, y - 1, z)) * 0.5
                nx, ny, nz = _norm((-gx, -gy, 1.3))
                v = max(0.0, nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2])
                v += bias
                level = 1 if v < 0.5 else 2 if v < 0.78 else 3
                if spec and v > 0.93 - spec * 0.08:
                    level = 4                           # eclat
                level += stroke(tex, x, y)
                # ombre portee : un volume plus haut vers la torche
                for k in (2, 4, 6):
                    sx, sy = x - k, y - int(k * 1.3)
                    if 0 <= sx < W and 0 <= sy < H and m[sy][sx] \
                            and h[sy][sx] - z > 2.2 * k:
                        level -= 1
                        break
                # creux : les voisins le dominent
                occ = 0.0
                for dx, dy in ((-3, 0), (3, 0), (0, -3), (0, 3)):
                    occ += max(0.0, min(6.0, hz(x + dx, y + dy, z) - z))
                if occ > 9:
                    level -= 1
                if y > 76:                              # le sol boit la lumiere
                    level -= 1
                out[y][x] = tones[max(1, min(4, level))]
        return out


# --- les neuf familles ---------------------------------------------------
def wolf(s, f):
    """Bete : loup gris en arret, gueule ouverte (rat, loup, worg...)."""
    hd = 2 * f                                        # la tete plonge
    s.cap([(80, 44), (88, 36 - 3 * f), (93, 26 - 5 * f)], [4, 3, 1.5], 2, "fur")
    body = s.ell(60, 52, 26, 15, 0, "fur")
    s.cap([(74, 54), (80, 70), (77, 84)], [8, 4, 3], [2, 4, 4], "fur")
    s.cap([(66, 58), (64, 72), (66, 85)], [6, 3.5, 3], [0, 2, 2], "fur")
    s.ell(78, 85, 5, 2.5, 4, "fur")
    s.ell(42, 54, 18, 17, 6, "fur", g=body)
    s.cap([(34, 58), (31, 72), (32, 84)], [7, 4.5, 4], [10, 10, 12], "fur")
    s.cap([(51, 60), (53, 72), (54, 84)], [7, 4.5, 4], [8, 8, 10], "fur")
    s.ell(30, 85, 6, 2.5, 13, "fur")
    s.ell(55, 85, 6, 2.5, 11, "fur")
    ruff = s.ell(38, 42 + hd, 17, 15, 12, "fur")
    s.ell(38, 52 + hd, 11, 9, 14, "furlt", g=ruff)    # poitrail clair
    s.poly([(24, 32 + hd), (24, 14 + hd), (33, 27 + hd)], 20, "fur")
    s.poly([(42, 27 + hd), (50, 12 + hd), (50, 31 + hd)], 18, "fur")
    s.paint(27, 24 + hd, 1.5, 4, "dark", dz=-1)
    s.paint(47, 23 + hd, 1.5, 4, "dark", dz=-1)
    head = s.ell(36, 34 + hd, 12, 10, 20, "fur")
    s.cap([(33, 38 + hd), (27, 46 + hd)], [7, 5], [26, 30], "fur", g=head)
    s.ell(25, 48 + hd, 3, 2, 35, "dark")                # truffe
    # gueule ouverte, crocs
    s.paint(30, 52 + hd + f, 7, 3 + f, "gums", dz=-4)
    s.paint(30, 52 + hd + f, 5, 2 + f, "dark", dz=-2)
    for fx in (25, 29, 33):
        s.fang(fx, 50 + hd, 3)
    for fx in (27, 32):
        s.fang(fx, 55 + hd + 2 * f, 2, down=False)
    s.cap([(31, 32 + hd), (35, 30 + hd)], 1.2, 34, "dark")   # sourcils
    s.cap([(39, 30 + hd), (43, 32 + hd)], 1.2, 34, "dark")
    s.dot(33, 34 + hd, "eyeY"), s.dot(34, 34 + hd, "eyeY")
    s.dot(40, 34 + hd, "eyeY"), s.dot(41, 34 + hd, "eyeY")


def skeleton(s, f):
    """Mort-vivant : squelette en armes, rouille et bouclier fendu."""
    up = 6 * f
    for side in (-1, 1):
        s.cap([(48 + side * 6, 64), (48 + side * 8, 75), (48 + side * 9, 85)],
              [3, 2.2, 2], [6, 7, 7], "bone")
        s.ell(48 + side * 8, 75, 3, 3, 8, "bone")
        s.ell(48 + side * 10, 86, 4, 2, 8, "bone")
    s.poly([(38, 60), (58, 60), (60, 74), (54, 70), (50, 76), (45, 70),
            (40, 75)], 10, "clothr")
    s.ell(48, 61, 10, 5, 9, "bone")                    # bassin
    s.cap([(48, 30), (48, 60)], 2.5, 8, "bone")         # colonne
    for i in range(5):
        y = 37 + i * 5
        wdt = 12 - i
        s.cap([(49, y), (48 + wdt, y + 1), (48 + wdt + 1, y + 4)],
              1.3, 12, "bone")
        s.cap([(47, y), (48 - wdt, y + 1), (48 - wdt - 1, y + 4)],
              1.3, 12, "bone")
    s.cap([(35, 34), (48, 31), (61, 34)], 1.8, 14, "bone")   # clavicules
    # bras gauche (a droite de l'image) : bouclier rond
    s.cap([(61, 34), (66, 46), (64, 54)], 2.2, 12, "bone")
    sh = s.ell(66, 52, 13, 15, 16, "wood", depth=5)
    s.ell(66, 52, 13, 15, 16, "iron", g=sh, depth=5)
    s.ell(66, 52, 11, 13, 17, "wood", g=sh, depth=4)
    s.ell(66, 52, 4, 4, 20, "iron")
    s.line(62, 40, 68, 58, "dark")                     # fente
    # bras droit : l'epee levee
    s.cap([(35, 34), (29, 46), (26, 38 - up)], [2.4, 2, 2], 14, "bone")
    s.ell(26, 37 - up, 3, 3, 18, "bone")
    s.cap([(26, 42 - up), (26, 32 - up)], 1.6, 20, "leather")
    s.cap([(21, 32 - up), (31, 32 - up)], 1.5, 22, "iron")
    s.poly([(24, 31 - up), (28, 31 - up), (27, 2 - up), (26, -1 - up),
            (25, 2 - up)], 21, "steel", bevel=1.2)
    s.cap([(26, 30 - up), (26, 4 - up)], 0.3, 23, "iron")     # gorge
    # crane et heaume rouille
    skull = s.ell(48, 19, 9, 10, 18, "bone")
    s.ell(48, 27, 6, 4, 20, "bone", g=skull)
    s.ell(48, 14, 11, 7, 20, "rust", clip=(0, 15))
    s.cap([(37, 15), (59, 15)], 1.5, 26, "rust")
    s.cap([(48, 5), (48, 16)], 1.2, 27, "rust")
    s.paint(44, 19, 3, 3, "dark", dz=-6)
    s.paint(52, 19, 3, 3, "dark", dz=-6)
    s.dot(44, 19, "eyeR"), s.dot(52, 19, "eyeR")
    s.paint(48, 24, 1.2, 2, "dark", dz=-3)
    s.paint(48, 28 + f, 5, 1.2, "dark", dz=-3)
    for tx in range(44, 53, 2):
        s.dot(tx, 27 + f, "teeth")


def goblin(s, f):
    """Petit humanoide : gobelin voute, oreilles en lame, poignard."""
    for side in (-1, 1):
        s.cap([(48 + side * 6, 66), (48 + side * 10, 76), (48 + side * 8, 85)],
              [4, 3, 2.5], [6, 8, 8], "gob")
        s.ell(48 + side * 10, 86, 5, 2, 8, "gob")
    body = s.ell(48, 58, 14, 14, 6, "gob")
    s.poly([(36, 50), (60, 50), (62, 70), (56, 66), (52, 72), (46, 67),
            (40, 72), (34, 66)], 16, "leather")
    s.cap([(35, 66), (61, 66)], 2, 20, "leather")
    s.dot(48, 66, "gold")
    # bras gauche (image droite) : griffe tendue
    s.cap([(60, 50), (68, 58), (72, 52 - 2 * f)], [3.5, 2.5, 2], 16, "gob")
    for k in range(3):
        s.cap([(72, 52 - 2 * f), (76 + k, 47 - 2 * f + k * 3)], 0.8, 18,
              "teeth")
    # bras droit : poignard courbe
    up = 5 * f
    s.cap([(36, 50), (28, 56), (26, 46 - up)], [3.5, 2.5, 2.4], 16, "gob")
    s.ell(26, 45 - up, 3, 3, 20, "gob")
    s.poly([(24, 43 - up), (28, 43 - up), (26, 28 - up), (21, 22 - up),
            (23, 30 - up)], 22, "steel", bevel=1.2)
    # tete, oreilles, nez
    for side in (-1, 1):
        s.poly([(48 + side * 9, 26), (48 + side * 36, 16 - 2 * f),
                (48 + side * 10, 36)], 14, "gob")
        s.paint(48 + side * 20, 25, 6, 1.5, "gums", dz=-1)
    head = s.ell(48, 32, 13, 12, 18, "gob")
    s.ell(48, 38, 10, 6, 20, "gob", g=head)
    s.cap([(38, 27), (47, 29)], 2, 29, "gob", g=head)       # arcades
    s.cap([(49, 29), (58, 27)], 2, 29, "gob", g=head)
    s.ell(48, 36, 3, 5, 30, "gob")                      # nez crochu
    s.paint(43, 31, 2.5, 1.6, "eyeY", dz=-1)
    s.paint(53, 31, 2.5, 1.6, "eyeY", dz=-1)
    s.dot(43, 31, "dark"), s.dot(53, 31, "dark")
    s.paint(48, 42 + f, 8, 2 + f, "dark", dz=-3)       # rictus
    for tx in (42, 45, 51, 54):
        s.fang(tx, 41 + f, 2)


def orc(s, f):
    """Humanoide arme : orc cuirasse, hache de guerre."""
    for side in (-1, 1):
        s.cap([(48 + side * 9, 64), (48 + side * 11, 76)], [7, 6], 6, "orc")
        s.cap([(48 + side * 11, 74), (48 + side * 12, 84)], [6, 5], 8,
              "leather")
        s.ell(48 + side * 12, 86, 7, 2.5, 8, "leather")
    s.poly([(35, 62), (61, 62), (60, 76), (52, 72), (48, 78), (44, 72),
            (36, 76)], 14, "leather")
    torso = s.ell(48, 48, 19, 17, 6, "orc")
    s.ell(42, 44, 8, 6, 14, "orc", g=torso)            # pectoraux
    s.ell(54, 44, 8, 6, 14, "orc", g=torso)
    s.cap([(30, 62), (66, 62)], 3, 20, "leather")      # ceinturon
    s.ell(48, 62, 4, 3.5, 23, "iron")
    s.ink([(36, 49), (42, 51), (47, 48)])               # pectoraux
    s.ink([(49, 48), (54, 51), (60, 49)])
    for y in (54, 58):                                  # abdominaux
        s.ink([(44, y), (47, y + 1)]), s.ink([(49, y + 1), (52, y)])
    s.ink([(48, 51), (48, 60)])
    s.cap([(32, 34), (62, 60)], 2.2, 18, "leather")    # baudrier
    # bras gauche (image droite) : poing ferme
    s.cap([(66, 38), (72, 52), (68, 64)], [6, 5, 4.5], 12, "orc")
    s.ell(68, 66, 5, 5, 16, "orc")
    s.cap([(69, 50), (71, 58)], 5.5, 16, "iron")       # brassard
    # bras droit : la hache
    up = 5 * f
    s.cap([(30, 38), (22, 48), (26, 34 - up)], [6, 5, 4.5], 12, "orc")
    s.cap([(23, 50 - up), (31, 4 - up)], 2.2, 20, "wood")
    s.ell(26, 35 - up, 5, 5, 24, "orc")
    blade = [(30, 6 - up), (42, 0 - up), (46, 10 - up), (43, 22 - up),
             (31, 16 - up)]
    s.poly(blade, 22, "steel", bevel=2.5)
    s.poly([(30, 8 - up), (22, 4 - up), (20, 12 - up), (30, 14 - up)], 22,
           "iron", bevel=1.5)
    # epaulieres de fer
    for side in (-1, 1):
        g = s.ell(48 + side * 18, 34, 10, 8, 18, "iron")
        s.cap([(48 + side * 11, 33), (48 + side * 25, 33)], 1.3, 25, "iron",
              g=g)
        s.cap([(48 + side * 20, 29), (48 + side * 22, 23)], [2, 0.5], 24,
              "steel")
    # tete
    head = s.ell(48, 22, 10, 11, 18, "orc")
    s.ell(48, 28, 11, 6, 20, "orc", g=head)            # machoire lourde
    s.cap([(38, 18), (58, 18)], 2.4, 26, "orc", g=head)
    s.cap([(48, 11), (48, 4), (52, 0)], [3, 2.5, 1.5], 22, "hair")
    s.paint(44, 21, 2, 1.3, "eyeR", dz=-2)
    s.paint(52, 21, 2, 1.3, "eyeR", dz=-2)
    s.ell(48, 24, 2.5, 2.5, 28, "orc")
    s.paint(48, 31 + f, 6, 1.5, "dark", dz=-2)
    for side in (-1, 1):
        s.cap([(48 + side * 5, 31), (48 + side * 6, 25)], [1.5, 0.6], 29,
              "teeth")


def brute(s, f):
    """Grand brutal : minotaure cornu, massue ferree."""
    for side in (-1, 1):
        s.cap([(48 + side * 12, 66), (48 + side * 15, 78), (48 + side * 14, 84)],
              [9, 7, 6], [4, 6, 6], "hide")
        s.ell(48 + side * 15, 86, 7, 2.5, 7, "horn")   # sabots
    s.poly([(30, 62), (66, 62), (64, 78), (48, 74), (32, 78)], 12, "leather")
    torso = s.ell(48, 48, 24, 20, 4, "hide")
    s.ell(40, 42, 10, 8, 14, "hide", g=torso)
    s.ell(56, 42, 10, 8, 14, "hide", g=torso)
    s.ell(48, 58, 12, 8, 12, "hide", g=torso)
    s.ink([(31, 46), (40, 50), (47, 47)])               # pectoraux
    s.ink([(49, 47), (56, 50), (65, 46)])
    s.ink([(48, 50), (48, 61)])
    for y in (54, 58):
        s.ink([(42, y), (47, y + 1)]), s.ink([(49, y + 1), (54, y)])
    s.cap([(26, 63), (70, 63)], 2.5, 18, "leather")
    # bras gauche (image droite)
    s.cap([(70, 36), (80, 52), (76, 68)], [9, 7, 6], 10, "hide")
    s.ell(76, 70, 6, 6, 14, "hide")
    s.cap([(78, 50), (80, 58)], 7, 14, "iron")
    # bras droit : la massue
    up = 6 * f
    s.cap([(26, 36), (14, 48), (16, 36 - up)], [9, 7, 6], 10, "hide")
    s.cap([(14, 52 - up), (26, 6 - up)], [2.5, 7], 18, "wood")
    for k in range(4):
        s.dot(19 + k * 2, 26 - k * 5 - up, "iron", z=30)
        s.dot(29 - k, 20 - k * 4 - up, "iron")
    s.ell(16, 38 - up, 6, 6, 22, "hide")
    # tete de taureau
    for side in (-1, 1):
        s.cap([(48 + side * 10, 12), (48 + side * 22, 10),
               (48 + side * 28, 2 - f)], [3.5, 2.5, 1], 16, "horn")
        s.ell(48 + side * 13, 17, 4, 2.5, 18, "hide")  # oreilles
    head = s.ell(48, 18, 12, 12, 16, "hide")
    s.ell(48, 28, 10, 8, 22, "hide", g=head)
    s.ell(48, 31, 8, 5, 26, "leather")                 # mufle
    s.paint(45, 31, 1.5, 1.5, "dark", dz=-3)
    s.paint(51, 31, 1.5, 1.5, "dark", dz=-3)
    s.cap([(45, 34), (48, 37), (51, 34)], 1.2, 33, "gold")  # anneau
    s.cap([(39, 16), (46, 19)], 2, 28, "hide", g=head)
    s.cap([(50, 19), (57, 16)], 2, 28, "hide", g=head)
    s.paint(42, 20, 2, 1.3, "eyeR", dz=-2)
    s.paint(54, 20, 2, 1.3, "eyeR", dz=-2)


def spectre(s, f):
    """Spectre : robe en lambeaux qui flotte, capuche vide."""
    fl = -2 * f
    hem = []
    for i in range(9):
        x = 22 + i * 6.5
        hem.append((x, 84 + fl - (6 if i % 2 else 0) - 2 * math.sin(i + f)))
    robe = [(36, 26 + fl), (60, 26 + fl), (72, 52 + fl)] + hem[::-1] + \
           [(24, 52 + fl)]
    robe = [(36, 26 + fl), (60, 26 + fl), (74, 56 + fl)] + hem[::-1][:-1] + \
           [(22, 56 + fl)]
    s.poly(robe, 4, "robe", bevel=6)
    for k in range(4):                               # plis profonds
        x = 36 + k * 8
        s.cap([(x, 40 + fl), (x - 2 + k, 78 + fl)], 1.5, 5, "robe")
    # manches et mains osseuses tendues vers le groupe
    for side in (-1, 1):
        sl = s.cap([(48 + side * 12, 30 + fl), (48 + side * 22, 44 + fl),
                    (48 + side * 26, 50 + fl - 3 * f)], [6, 7, 8], 10, "robe")
        hx, hy = 48 + side * 28, 54 + fl - 3 * f
        s.ell(hx, hy, 3.5, 3, 16, "bone")
        for k in range(4):
            s.cap([(hx, hy + 1), (hx + side * (k - 1) * 2, hy + 7 + (k % 2))],
                  0.8, 17, "bone")
    hood = s.ell(48, 22 + fl, 14, 14, 12, "robe")
    s.poly([(38, 12 + fl), (48, -1 + fl), (58, 12 + fl)], 20, "robe")
    s.paint(48, 25 + fl, 9, 10, "dark", dz=-10)
    s.paint(44, 24 + fl, 1.5, 1.2, "eyeB")
    s.paint(52, 24 + fl, 1.5, 1.2, "eyeB")
    s.dot(44, 24 + fl, "glow"), s.dot(52, 24 + fl, "glow")
    # feux follets
    for i in range(7):
        x = 20 + (i * 37) % 58
        y = 64 + (i * 13) % 20 + fl + f * (i % 3)
        s.dot(x, y, "glow")


def mummy(s, f):
    """Momie : bandelettes, bras tendus, un oeil qui brule."""
    for side in (-1, 1):
        s.cap([(48 + side * 7, 62), (48 + side * 8, 84)], [6, 4.5], 6, "wrap")
        s.ell(48 + side * 9, 86, 5, 2, 8, "wrap")
    s.ell(48, 46, 17, 20, 6, "wrap")
    s.cap([(34, 60), (62, 60)], 2.5, 20, "rust")
    s.ell(48, 38, 5, 5, 22, "gold")                    # scarabee
    s.ell(48, 38, 2.5, 3, 25, "clothb" if False else "eyeB")
    # bras tendus vers le groupe
    for side in (-1, 1):
        dy = 2 * f if side > 0 else -2 * f
        s.cap([(48 + side * 14, 32), (48 + side * 22, 44 + dy),
               (48 + side * 20, 52 + dy)], [5, 4.5, 4], [12, 16, 20], "wrap")
        s.ell(48 + side * 20, 54 + dy, 4, 3.5, 22, "wrap")
        # bandelettes qui pendent
        s.cap([(48 + side * 23, 46 + dy), (48 + side * 26, 62 + dy + f)],
              [1.5, 1], 14, "wrap")
    s.cap([(40, 64), (37, 82 + f)], [1.5, 1], 12, "wrap")
    head = s.ell(48, 18, 10, 12, 16, "wrap")
    s.paint(44, 18, 2.5, 2, "dark", dz=-4)
    s.paint(53, 19, 3, 1.5, "dark", dz=-4)
    s.dot(44, 18, "eyeR"), s.dot(45, 18, "eyeR")
    s.paint(48, 26, 4, 1.2, "dark", dz=-3)
    s.cap([(38, 10), (58, 14)], 1, 27, "rust")           # bande de travers


def gargoyle(s, f):
    """Creature ailee : gargouille accroupie, ailes de chauve-souris."""
    flap = 5 * f
    for side in (-1, 1):
        tip = (48 + side * 47, 6 + flap)
        fingers = [tip, (48 + side * 44, 32 + flap // 2),
                   (48 + side * 38, 52), (48 + side * 26, 58)]
        shoulder = (48 + side * 12, 30)
        elbow = (48 + side * 32, 16 + flap // 2)
        mem = [shoulder, elbow, tip]
        for k in range(1, len(fingers)):
            a, b = fingers[k - 1], fingers[k]
            mem.append(((a[0] + b[0]) / 2 - side * 4, (a[1] + b[1]) / 2 - 2))
            mem.append(b)
        mem.append((48 + side * 14, 48))
        s.poly(mem, 0, "stone", bevel=2.5)
        s.cap([shoulder, elbow, tip], [3, 2.5, 1], 4, "stone")
        for fg in fingers[1:]:
            s.cap([elbow, fg], [1.8, 0.8], 3, "stone")
    s.cap([(58, 72), (74, 82), (84, 76), (88, 68)], [3, 2.5, 2, 1], 4, "stone")
    s.poly([(86, 70), (92, 64), (90, 72)], 5, "stone")
    for side in (-1, 1):                             # jambes repliees
        s.cap([(48 + side * 8, 62), (48 + side * 16, 70), (48 + side * 10, 84)],
              [7, 6, 4], [8, 12, 12], "stone")
        for k in range(3):
            s.cap([(48 + side * 10, 84), (48 + side * (8 + 3 * k), 87)], 1.2,
                  14, "horn")
    body = s.ell(48, 50, 15, 18, 8, "stone")
    s.ell(48, 42, 11, 8, 14, "stone", g=body)
    for side in (-1, 1):                             # bras et griffes
        s.cap([(48 + side * 12, 36), (48 + side * 16, 50),
               (48 + side * 10, 62)], [5, 4, 3.5], 16, "stone")
        for k in range(3):
            s.cap([(48 + side * 10, 62), (48 + side * (6 + k * 3), 67)], 1,
                  22, "horn")
    head = s.ell(48, 24, 10, 10, 16, "stone")
    s.ell(48, 31, 8, 5, 20, "stone", g=head)
    for side in (-1, 1):
        s.cap([(48 + side * 7, 17), (48 + side * 14, 9),
               (48 + side * 12, 1)], [2.8, 2, 0.8], 22, "horn")
        s.poly([(48 + side * 9, 22), (48 + side * 19, 16), (48 + side * 10, 27)],
               18, "stone")
    s.cap([(40, 21), (47, 24)], 1.6, 28, "stone", g=head)
    s.cap([(49, 24), (56, 21)], 1.6, 28, "stone", g=head)
    s.paint(44, 25, 2, 1.2, "eyeR", dz=-2)
    s.paint(52, 25, 2, 1.2, "eyeR", dz=-2)
    s.paint(48, 33 + f, 6, 2 + f, "dark", dz=-4)
    s.fang(43, 31, 3), s.fang(52, 31, 3)


def hydra(s, f):
    """Hydre : cinq tetes de serpent sur un tronc d'ecailles."""
    s.cap([(70, 76), (84, 80), (93, 70), (90, 60)], [8, 6, 4, 2], 2, "scale")
    s.ell(48, 72, 30, 15, 4, "scale")
    for side in (-1, 1):
        s.cap([(48 + side * 20, 76), (48 + side * 24, 86)], [6, 5], 8, "scale")
        for k in range(3):
            s.cap([(48 + side * 24, 86), (48 + side * (20 + 4 * k), 88)], 1,
                  12, "horn")
    s.ell(48, 70, 14, 12, 12, "belly")
    heads = [(-36, 30, -1), (-20, 14, -1), (0, 6, 0), (20, 14, 1), (36, 30, 1)]
    order = (0, 4, 1, 3, 2)                          # du fond vers l'avant
    for i in order:
        hx, hy, side = heads[i]
        wob = (2 if i % 2 else -2) * (1 if f else -1)
        tx, ty = 48 + hx + wob, hy + (i % 2) * 2 * f
        mid = (48 + hx * 0.4 - side * 6, 50 - (50 - ty) * 0.4)
        z = 10 + (4 - abs(i - 2)) * 4
        s.cap([(48 + hx * 0.2, 64), mid, (tx, ty + 8)], [7, 5, 4.5],
              [z, z + 2, z + 4], "scale")
        head = s.ell(tx, ty + 4, 8, 6, z + 6, "scale")
        s.ell(tx + side * 6, ty + 7, 6, 3.5, z + 7, "scale", g=head)
        s.cap([(tx - 5, ty + 1), (tx + 5, ty + 1)], 1.5, z + 11, "scale",
              g=head)
        s.paint(tx + side * 7, ty + 9 + f, 5, 1.5 + f, "gums", dz=-3)
        s.paint(tx + side * 7, ty + 9 + f, 4, 0.8 + f, "dark", dz=-2)
        s.fang(tx + side * 5, ty + 8, 2)
        s.fang(tx + side * 9, ty + 8, 2)
        s.cap([(tx - 3, ty + 1), (tx - side * 5 - 2, ty - 3)], [1.2, 0.4],
              z + 9, "horn")
        s.dot(tx + side * 2 - 1, ty + 3, "eyeY")
        s.dot(tx + side * 2, ty + 3, "eyeY")


FAMILIES = [wolf, skeleton, goblin, orc, brute, spectre, mummy, gargoyle,
            hydra]


def monster(kind, frame=0):
    """-> 88 lignes de 96 index (None = transparent)."""
    s = Sculpt()
    FAMILIES[kind](s, 1 if frame else 0)
    return s.render()


def write_png(path, rows):
    """rows : lignes de triplets RGB."""
    import struct
    import zlib
    h, w = len(rows), len(rows[0])
    raw = b"".join(b"\0" + bytes(c for px in r for c in px) for r in rows)

    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + \
            struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)))
        f.write(chunk(b"IDAT", zlib.compress(raw, 9)))
        f.write(chunk(b"IEND", b""))


def sheet(path, scale=3, kinds=None):
    """Planche de contact : une colonne par famille, une ligne par pose."""
    kinds = list(range(len(FAMILIES))) if kinds is None else kinds
    tw, th = W + 4, H + 4
    rows = [[(24, 22, 20)] * (len(kinds) * tw * scale)
            for _ in range(2 * th * scale)]
    for c, k in enumerate(kinds):
        for fr in (0, 1):
            px = monster(k, fr)
            for y in range(H):
                for x in range(W):
                    i = px[y][x]
                    rgb = pal.PALETTE[i] if i is not None else (40, 36, 32)
                    for dy in range(scale):
                        row = rows[((fr * th) + 2 + y) * scale + dy]
                        base = ((c * tw) + 2 + x) * scale
                        for dx in range(scale):
                            row[base + dx] = rgb
    write_png(path, rows)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/monstres.png"
    sheet(out)
    print(out)
