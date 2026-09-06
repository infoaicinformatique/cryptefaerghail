#!/usr/bin/env python3
"""Verifie que les bruitages fonctionnent vraiment, dans le 68020 emule.

On ne relit pas le code : on appelle SfxPlay dans l'emulateur et on
regarde ce qui arrive aux registres de Paula -- pointeur, longueur,
periode, volume, et la sequence DMA coupe / relance qu'exige le
materiel. On joue ensuite pour de bon et on verifie que chaque geste
declenche le bon effet.

Ecrit aussi docs/sfx.wav pour les entendre sans Amiga.

    python3 tools/test_sfx.py
"""
import os
import struct
import sys
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import test_game as T

PAL_CLOCK = 3546895
RATE = 22050
NOMS = ["epee", "hache", "arc", "impact", "esquive", "porte", "coffre",
        "potion", "sort", "monstre", "niveau", "pas", "mort",
        "piege", "pieces"]
# indices attendus, dans l'ordre de SFX_ dans crawl.s
SFX_SWORD, SFX_AXE, SFX_BOW, SFX_HIT, SFX_MISS, SFX_DOOR, SFX_CHEST, \
    SFX_POTION, SFX_SPELL, SFX_GROWL, SFX_LEVEL, SFX_STEP, SFX_DEATH, \
    SFX_TRAP, SFX_COIN = range(15)

AUD3 = 0xd0                              # canal 3 : celui qu'on emprunte


def table():
    """Le contenu de data/sfx.bin, tel que SfxPlay le lira."""
    raw = open(os.path.join(ROOT, "data", "sfx.bin"), "rb").read()
    n = struct.unpack(">H", raw[:2])[0]
    out = []
    for i in range(n):
        off, words, per, vol, ticks = struct.unpack(
            ">IHHHH", raw[2 + i * 12:14 + i * 12])
        out.append(dict(offset=off, words=words, period=per, volume=vol,
                        ticks=ticks))
    return raw, out


def check_table(sfx, raw, fails):
    """Coherence de la table avant meme de la jouer."""
    for i, e in enumerate(sfx):
        nom = NOMS[i] if i < len(NOMS) else str(i)
        end = e["offset"] + e["words"] * 2
        if not (0 < e["offset"] < len(raw) and end <= len(raw)):
            fails.append(f"{nom} : echantillon hors du fichier "
                         f"({e['offset']}..{end} / {len(raw)})")
        if e["words"] < 1:
            fails.append(f"{nom} : longueur nulle")
        if not 124 <= e["period"] <= 1023:
            fails.append(f"{nom} : periode {e['period']} hors des limites "
                         "de Paula")
        if not 0 < e["volume"] <= 64:
            fails.append(f"{nom} : volume {e['volume']}")
        if e["ticks"] < 1:
            fails.append(f"{nom} : duree de verrou nulle")
        secondes = e["words"] * 2 / (PAL_CLOCK / e["period"])
        if abs(e["ticks"] / 50 - secondes) > 0.12:
            fails.append(f"{nom} : verrou {e['ticks']} tics pour "
                         f"{secondes*50:.0f} tics de son")


def play(g, index):
    """Appelle SfxPlay et rend le journal des ecritures Paula."""
    g.setw("PT_SfxLock", 0)               # le pas cede le pas a un bruit
    g.audio.clear()
    ok = g.call(g.addr("SfxPlay"), d0=index)
    return ok, list(g.audio)


def check_play(g, sfx, index, fails):
    nom = NOMS[index]
    ok, log = play(g, index)
    if not ok:
        fails.append(f"{nom} : SfxPlay ne rend pas la main")
        return
    base = g.addr("SfxData")
    e = sfx[index]
    seq = [off for off, _ in log]
    vals = dict(log)
    if 0x96 not in seq:
        fails.append(f"{nom} : DMACON jamais touche")
        return
    dma = [v for off, v in log if off == 0x96]
    if dma[0] != 0x0008:
        fails.append(f"{nom} : le DMA du canal 3 n'est pas coupe d'abord "
                     f"({dma[0]:#06x})")
    if 0x8008 not in dma:
        fails.append(f"{nom} : le DMA du canal 3 n'est jamais relance")
    if seq.index(0x96) > seq.index(AUD3):
        fails.append(f"{nom} : registres charges avant la coupure du DMA")
    ptr = [v for off, v in log if off == AUD3]
    if not ptr or ptr[0] != base + e["offset"]:
        fails.append(f"{nom} : pointeur {ptr[0] if ptr else None:#x} "
                     f"au lieu de {base + e['offset']:#x}")
    if len(ptr) < 2 or ptr[-1] != g.addr("SfxSilence"):
        fails.append(f"{nom} : le canal ne reboucle pas sur le silence")
    if vals.get(AUD3 + 6) != e["period"]:
        fails.append(f"{nom} : periode {vals.get(AUD3 + 6)} "
                     f"au lieu de {e['period']}")
    if vals.get(AUD3 + 8) != e["volume"]:
        fails.append(f"{nom} : volume {vals.get(AUD3 + 8)} "
                     f"au lieu de {e['volume']}")
    lens = [v for off, v in log if off == AUD3 + 4]
    if not lens or lens[0] != e["words"]:
        fails.append(f"{nom} : longueur {lens[0] if lens else None} "
                     f"au lieu de {e['words']}")
    if len(lens) < 2 or lens[-1] != 1:
        fails.append(f"{nom} : longueur de boucle du silence incorrecte")
    lock = g.w("PT_SfxLock")
    if lock != e["ticks"]:
        fails.append(f"{nom} : verrou {lock} au lieu de {e['ticks']}")


def check_lock(g, fails):
    """Le replayer doit laisser le canal 3 tranquille pendant l'effet."""
    play(g, SFX_SWORD)
    lock = g.w("PT_SfxLock")
    if lock < 2:
        fails.append("le verrou est trop court pour etre teste")
        return
    g.audio.clear()
    for _ in range(lock - 1):
        g.call(g.addr("PT_Tick"))
    touched = [off for off, _ in g.audio if AUD3 <= off < AUD3 + 16]
    if touched:
        fails.append(f"le replayer ecrit dans le canal 3 pendant l'effet "
                     f"({len(touched)} ecritures)")
    if g.w("PT_SfxLock") != 1:
        fails.append(f"le verrou ne descend pas ({g.w('PT_SfxLock')})")
    for _ in range(3):
        g.call(g.addr("PT_Tick"))
    if g.w("PT_SfxLock") != 0:
        fails.append("le verrou ne se libere pas")


def played(g, base, sfx):
    """Quels effets le journal Paula montre-t-il ?"""
    out = []
    for off, val in g.audio:
        if off != AUD3:
            continue
        for i, e in enumerate(sfx):
            if val == base + e["offset"]:
                out.append(i)
    return out


def check_in_game(g, sfx, fails):
    """Les gestes du jeu declenchent-ils le bon bruitage ?"""
    import play_game as P
    base = g.addr("SfxData")

    def probe(want, limit=None):
        """Marche vers la premiere case voulue, journal Paula remis a zero.
        Le verrou est libere d'abord : un pas ne coupe pas un bruit en
        cours, il resterait donc muet apres l'essai precedent."""
        g.setw("PT_SfxLock", 0)
        g.audio.clear()
        path = P.bfs(P.terrain(g), (g.w("PosX"), g.w("PosY")), want)
        if not path:
            return None
        for cell in path[1:limit]:
            if not P.step_to(g, cell, []) or g.w("InCombat"):
                break
        return played(g, base, sfx)

    heard = probe(lambda c: c & 0x0f == 0, limit=2)   # un seul pas
    if heard is None or SFX_STEP not in heard:
        fails.append("aucun bruit de pas en se deplacant")

    heard = probe(lambda c: c & 0x0f == 2)            # une porte fermee
    if heard is not None and SFX_DOOR not in heard:
        fails.append("aucun grincement en ouvrant une porte")

    P.pull_levers(g)                                  # ouvrir les herses
    while g.w("InCombat") and not g.w("GameOver"):    # finir un combat
        g.key(T.K_A)                                  # commence en chemin
    heard = probe(lambda c: c & 0x30 == 0x20)         # un monstre
    if heard is None:
        fails.append("aucun monstre atteignable pour l'essai")
        return
    g.audio.clear()
    for _ in range(2):
        if g.w("InCombat"):
            break
        path = P.bfs(P.terrain(g), (g.w("PosX"), g.w("PosY")),
                     lambda c: c & 0x30 == 0x20)
        for cell in (path or [])[1:]:
            P.step_to(g, cell, [])
            if g.w("InCombat"):
                break
    heard += played(g, base, sfx)
    if not g.w("InCombat"):
        fails.append("le combat ne se declenche pas")
        return
    if SFX_GROWL not in heard:
        fails.append("le monstre apparait sans grogner")
    armes = set()
    for _ in range(8):
        if not g.w("InCombat"):
            break
        g.setw("PT_SfxLock", 0)
        g.audio.clear()
        g.key(T.K_A)
        armes |= set(played(g, base, sfx))
    if not armes & {SFX_SWORD, SFX_AXE, SFX_BOW}:
        fails.append("aucun bruit d'arme pendant le combat")
    if not armes & {SFX_HIT, SFX_MISS}:
        fails.append("ni impact ni esquive pendant le combat")


def loaded(g):
    """Le nom du module que le replayer joue en ce moment."""
    base = g.mem.r32(g.addr("PT_Patterns")) - 1084
    return bytes(g.mem.r8(base + i) for i in range(20)).split(b"\0")[0]


def check_music(g, fails):
    """La musique doit vraiment tourner, et chaque moment avoir la sienne :
    la procession devant le portail, la marche dans le donjon, et les
    profondeurs a partir du quatrieme etage."""
    deep = T.read_equ("DEEP_LEVEL", 3)
    for nom, fichier in (("accueil", "titlemus.mod"),
                         ("donjon", "crawlmus.mod"),
                         ("profondeurs", "deepmus.mod")):
        attendu = open(os.path.join(ROOT, "data", fichier), "rb").read()[:20]
        if nom == "donjon":                # on quitte l'accueil
            g.key(T.K_1)
        if nom == "profondeurs":           # on s'enfonce
            g.setw("Level", deep)
            g.call(g.addr("LevelMusic"))
        if loaded(g) != attendu.split(b"\0")[0]:
            fails.append(f"{nom} : module {loaded(g)!r} au lieu de "
                         f"{attendu.split(chr(0).encode())[0]!r}")
    g.setw("Level", 0)                     # on remonte pour la suite
    g.call(g.addr("LevelMusic"))
    g.audio.clear()
    for _ in range(120):                  # deux secondes de replay
        g.call(g.addr("PT_Tick"))
    voies = {off & 0xf0 for off, _ in g.audio if 0xa0 <= off < 0xe0}
    if len(voies) < 3:
        fails.append(f"la musique n'anime que {len(voies)} voie(s)")
    return len(voies), loaded(g).decode("latin-1")


def write_wav(sfx, raw):
    """Tous les effets a la suite, pour les ecouter."""
    out = []
    for e in sfx:
        rate = PAL_CLOCK / e["period"]
        data = raw[e["offset"]:e["offset"] + e["words"] * 2]
        n = int(len(data) * RATE / rate)
        for i in range(n):
            v = data[min(len(data) - 1, int(i * rate / RATE))]
            out.append((v - 256 if v > 127 else v) * 200)
        out.extend([0] * (RATE // 4))
    path = os.path.join(ROOT, "docs", "sfx.wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", max(-32767, min(32767, v)))
                               for v in out))
    return path


if __name__ == "__main__":
    fails = []
    raw, sfx = table()
    print(f"--- table : {len(sfx)} effets, {len(raw)} octets ---")
    check_table(sfx, raw, fails)
    for i, e in enumerate(sfx):
        rate = PAL_CLOCK / e["period"]
        print(f"  {i:2d} {NOMS[i]:9s} {e['words']*2:5d} octets  "
              f"{rate/1000:5.1f} kHz  {e['words']*2/rate*1000:4.0f} ms  "
              f"verrou {e['ticks']:2d} tics")

    g = T.Game()
    print("--- registres de Paula, effet par effet ---")
    for i in range(len(sfx)):
        check_play(g, sfx, i, fails)
    print(f"  {len(sfx)} effets charges sur le canal 3")

    print("--- la musique tourne-t-elle ---")
    voies, titre = check_music(g, fails)
    print(f"  {voies} voies animees, module \"{titre}\" une fois descendu")

    print("--- le replayer respecte-t-il le verrou ---")
    check_lock(g, fails)
    print("  canal 3 laisse a l'effet, verrou decremente puis libere")

    print("--- en situation de jeu ---")
    T.create_party(g)
    check_in_game(g, sfx, fails)
    print("  pas, porte, apparition, armes et impacts")

    print("---", os.path.relpath(write_wav(sfx, raw), ROOT))
    print()
    if fails:
        print(f"{len(fails)} anomalie(s) :")
        for f in fails:
            print("  -", f)
        sys.exit(1)
    print("bruitages fonctionnels")
