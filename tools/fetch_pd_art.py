#!/usr/bin/env python3
"""Recupere sur Wikimedia Commons des illustrations du domaine public
pour servir de portraits de monstres.

Les illustrations de D&D sont sous droits : l'Open Game License couvre le
texte des regles et des blocs de statistiques, pas les images. On puise
donc dans le domaine public — Dore, Bauer, gravures anciennes — et le
script refuse tout fichier dont Commons ne dit pas explicitement qu'il
est dans le domaine public.

    python3 tools/fetch_pd_art.py
"""
import json
import os
import re
import subprocess
import sys
import urllib.parse

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "art", "pd")
API = "https://commons.wikimedia.org/w/api.php"

# cle interne, requete de recherche
# cle interne, categories Commons a explorer, mots attendus dans le titre
WANTED = [
    ("dragon",   ["Saint George and the Dragon in art", "Dragons in art",
                  "Dragons in painting"], None),
    ("troll",    ["Paintings by John Bauer", "John Bauer", "Trolls"], None),
    ("skeleton", ["Danse Macabre", "Skeletons in art"], None),
    ("goblin",   ["Goblins", "Illustrations by Arthur Rackham"],
                 ("goblin", "gnome", "kobold")),
    ("minotaur", ["Minotaur"], None),
    ("harpy",    ["Harpies"], None),
    ("medusa",   ["Medusa in art"], None),
    ("giant",    ["Giants in art", "Giants"], None),
    ("wolf",     ["Wolves in art", "Canis lupus in art"], None),
    ("ogre",     ["Ogres"], None),
    ("ghost",    ["Ghosts in art"], None),
    ("gargoyle", ["Gargoyles of Notre-Dame de Paris", "Gargoyles"], None),
    ("hydra",    ["Lernaean Hydra"], None),
    ("rat",      ["Rattus in art", "Rats in art"], None),
    ("demon",    ["Illustrations by Gustave Dore", "Demons in art"], None),
    ("mummy",    ["Mummies in art"], None),
    ("spider",   ["Araneae in art", "Spiders in art"], None),
    ("boar",     ["Sus scrofa in art", "Wild boar in art"], None),
]


def api(params):
    """L'API repond parfois a vide : on reessaie plutot que d'echouer."""
    url = API + "?" + urllib.parse.urlencode(params)
    for _ in range(3):
        raw = subprocess.run(["curl", "-sS", "-m", "40", "-A",
                              "AmigaCrawl/1.0 (art fetch; public domain only)",
                              url], capture_output=True).stdout
        try:
            return json.loads(raw)
        except Exception:
            continue
    return {}


def search(query, limit=12):
    r = api({"action": "query", "format": "json", "generator": "search",
             "gsrsearch": f"filetype:bitmap {query}", "gsrnamespace": 6,
             "gsrlimit": limit, "prop": "imageinfo",
             "iiprop": "url|size|extmetadata", "iiurlwidth": 900})
    return list(r.get("query", {}).get("pages", {}).values())


def category(name, limit=40):
    """Les categories donnent bien plus de resultats utiles qu'une
    recherche en texte libre."""
    r = api({"action": "query", "format": "json",
             "generator": "categorymembers", "gcmtitle": f"Category:{name}",
             "gcmtype": "file", "gcmlimit": limit, "prop": "imageinfo",
             "iiprop": "url|size|extmetadata", "iiurlwidth": 900})
    return list(r.get("query", {}).get("pages", {}).values())


def is_public_domain(info):
    em = info.get("extmetadata", {})
    lic = (em.get("LicenseShortName", {}).get("value", "") + " "
           + em.get("License", {}).get("value", "")).lower()
    return "public domain" in lic or lic.strip().startswith("pd")


# Auteurs dont l'oeuvre est sans ambiguite dans le domaine public :
# tous morts depuis plus d'un siecle.
OLD_MASTERS = ("dore", "doré", "bauer", "durer", "dürer", "goya", "delacroix",
               "blake", "fuseli", "rackham", "tenniel", "grandville",
               "aldrovandi", "redon", "bocklin", "böcklin", "moreau",
               "rubens", "uccello", "holbein", "bruegel", "brueghel",
               "bosch", "piranesi", "gericault", "géricault", "schongauer",
               "cranach", "beardsley", "crane", "hokusai", "kuniyoshi")


def old_enough(info):
    """Retenu si l'auteur est un maitre ancien, ou si l'oeuvre est datee
    d'avant 1900."""
    em = info.get("extmetadata", {})
    who = re.sub(r"<[^>]+>", " ", em.get("Artist", {}).get("value", "")).lower()
    if any(m in who for m in OLD_MASTERS):
        return True
    for field in ("DateTimeOriginal", "DateTime", "date"):
        raw = re.sub(r"<[^>]+>", " ", em.get(field, {}).get("value", ""))
        for y in re.findall(r"\b(1[0-8]\d\d)\b", raw):
            return True
    return False


def artist(info):
    raw = info.get("extmetadata", {}).get("Artist", {}).get("value", "")
    return re.sub(r"<[^>]+>", "", raw).strip()[:60] or "inconnu"


def fetch_from(key, pages, words=None):
    for page in pages:
        info = (page.get("imageinfo") or [{}])[0]
        title = page.get("title", "").lower()
        if words and not any(w in title for w in words):
            continue
        if not info.get("thumburl") or not is_public_domain(info):
            continue
        if not old_enough(info):
            continue                                 # provenance trop recente
        w, h = info.get("thumbwidth", 0), info.get("thumbheight", 0)
        if w < 350 or h < 350:
            continue
        if max(w, h) / max(1, min(w, h)) > 2.0:      # trop panoramique
            continue
        path = os.path.join(OUT, key + ".jpg")
        rc = subprocess.run(["curl", "-sS", "-m", "60", "-o", path,
                             info["thumburl"]]).returncode
        if rc or not os.path.exists(path) or os.path.getsize(path) < 8000:
            continue
        return {"key": key, "file": page["title"], "artist": artist(info),
                "licence": info["extmetadata"].get("LicenseShortName", {})
                .get("value", "?"),
                "page": info.get("descriptionurl", ""), "local": path}
    return None


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    credits = []
    for key, cats, words in WANTED:
        got = None
        for cat in cats:
            got = fetch_from(key, category(cat), words)
            if got:
                break
        if got:
            credits.append(got)
            print(f"  {key:9s} {got['file'][:46]:46s} | {got['artist'][:28]}")
        else:
            print(f"  {key:9s} -- rien de clairement libre de droits")
    with open(os.path.join(OUT, "CREDITS.txt"), "w") as f:
        f.write("Illustrations du domaine public, via Wikimedia Commons.\n")
        f.write("Chaque fichier a ete retenu parce que Commons le declare\n")
        f.write("dans le domaine public ; la source est indiquee ci-dessous.\n\n")
        for c in credits:
            f.write(f"{c['key']}\n  {c['file']}\n  auteur : {c['artist']}\n"
                    f"  licence : {c['licence']}\n  {c['page']}\n\n")
    print(f"{len(credits)} illustrations dans {OUT}")
