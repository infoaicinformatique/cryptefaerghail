#!/usr/bin/env python3
"""Ecrit dist/AGADemos.lha : archive LHA en-tete niveau 0, methode -lh0-.

-lh0- veut dire "stocke sans compression" : c'est la variante la plus
simple a produire et toutes les versions de LhA sur Amiga la lisent. Les
sous-repertoires suivent la convention du niveau 0, separateur $FF.

    python3 tools/make_lha.py
"""
import os
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "dist", "AGADemos.lha")


def crc16(data):
    """CRC-16/ARC, celui qu'attend l'en-tete LHA."""
    crc = 0
    for b in data:
        crc ^= b
        for _ in range(8):
            crc = (crc >> 1) ^ 0xa001 if crc & 1 else crc >> 1
    return crc


def dos_time(path):
    t = time.localtime(os.path.getmtime(path))
    date = ((t.tm_year - 1980) << 9) | (t.tm_mon << 5) | t.tm_mday
    return (date << 16) | (t.tm_hour << 11) | (t.tm_min << 5) | (t.tm_sec // 2)


def entry(name, data, mtime):
    """Un en-tete niveau 0 suivi des donnees."""
    name = name.encode("latin-1")
    body = (b"-lh0-"
            + len(data).to_bytes(4, "little")          # taille compressee
            + len(data).to_bytes(4, "little")          # taille d'origine
            + mtime.to_bytes(4, "little")
            + bytes((0x20, 0x00, len(name)))           # attribut, niveau, nom
            + name
            + crc16(data).to_bytes(2, "little"))
    header = bytes((len(body), sum(body) & 0xff)) + body
    return header + data


def build(files):
    out = bytearray()
    for local, amiga in files:
        with open(local, "rb") as f:
            data = f.read()
        out += entry(amiga.replace("/", "\xff"), data, dos_time(local))
    out += b"\0"                                       # fin d'archive
    return bytes(out)


def collect():
    files = [(os.path.join(ROOT, "bin", "AGACrawl"), "AGACrawl"),
             (os.path.join(ROOT, "bin", "AGAScroll"), "AGAScroll"),
             (os.path.join(ROOT, "bin", "AGADemo"), "AGADemo"),
             (os.path.join(ROOT, "disk", "Lisezmoi.txt"), "Lisezmoi.txt"),
             (os.path.join(ROOT, "disk", "S", "Startup-Sequence"),
              "S/Startup-Sequence"),
             (os.path.join(ROOT, "data", "music.mod"), "Src/data/music.mod"),
             (os.path.join(ROOT, "data", "dgnart.bin"), "Src/data/dgnart.bin"),
             (os.path.join(ROOT, "data", "dgnmap.bin"), "Src/data/dgnmap.bin")]
    src = os.path.join(ROOT, "src")
    for name in sorted(os.listdir(src)):
        if name.endswith((".s", ".i")):
            files.append((os.path.join(src, name), f"Src/{name}"))
    return files


if __name__ == "__main__":
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    files = collect()
    open(OUT, "wb").write(build(files))
    print(f"{OUT} : {len(files)} fichiers, {os.path.getsize(OUT)} octets")

    try:                                               # relecture de controle
        import lhafile
    except ImportError:
        sys.exit(0)
    archive = lhafile.Lhafile(OUT)
    names = archive.namelist()
    assert len(names) == len(files), f"{len(names)} entrees relues sur {len(files)}"
    for local, amiga in files:
        stored = archive.read(amiga.replace("/", "\xff"))
        assert stored == open(local, "rb").read(), f"contenu different : {amiga}"
    print(f"relecture verifiee : {len(names)} fichiers identiques")
