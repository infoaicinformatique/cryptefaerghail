#!/bin/sh
# Fabrique les deux disquettes 880 Ko OFS du jeu, et l'archive LhA.
#
#   dist/Faerghail.adf   amorcable : le jeu
#   dist/Source.adf      tout le source et les donnees generees
#
# Le jeu pese six cent soixante mille octets a huit bitplanes, avec
# dix-neuf apparences de creatures : sept cent mille une fois sur l'ADF,
# ou un bloc de 512 n'en porte que 488. Le source, cent cinquante mille
# de plus, ne tenait pas avec lui.
#
# Necessite xdftool (paquet amitools) :  pip install amitools
set -e

ROOT=$(cd "$(dirname "$0")/.." && pwd)
STAGE="$ROOT/build/disk"       # copie de travail ; disk/ ne contient que
                               # les fichiers ecrits a la main

if ! command -v xdftool >/dev/null; then
	echo "xdftool introuvable : pip install amitools" >&2
	exit 1
fi

make -C "$ROOT"
rm -rf "$STAGE"
mkdir -p "$ROOT/dist" "$STAGE/S" "$STAGE/Src/data"
cp "$ROOT/disk/Lisezmoi.txt" "$STAGE/"
cp "$ROOT/disk/S/Startup-Sequence" "$STAGE/S/"
cp "$ROOT/bin/AGACrawl" "$STAGE/"
cp "$ROOT"/src/*.s "$ROOT"/src/*.i "$STAGE/Src/"
cp "$ROOT/data/crawlmus.mod" \
	"$ROOT/data/titlemus.mod" "$ROOT/data/deepmus.mod" \
	"$ROOT/data/dgnart.bin" "$ROOT/data/dgnmap.bin" \
	"$ROOT/data/sfx.bin" "$STAGE/Src/data/"

# --- disquette 1 : le jeu -------------------------------------------
GAME="$ROOT/dist/Faerghail.adf"
rm -f "$GAME"
xdftool "$GAME" create + format "Faerghail" \
	+ write "$STAGE/AGACrawl" \
	+ write "$STAGE/Lisezmoi.txt" \
	+ makedir S \
	+ write "$STAGE/S/Startup-Sequence" S/Startup-Sequence
xdftool "$GAME" boot install		# bootblock DOS0 : elle demarre seule

# --- disquette 2 : tout le source -----------------------------------
# Y compris les tables generees, celles qui portent GENERE PAR en tete :
# elles pesent, mais une disquette de source qui ne se reassemble pas
# telle quelle ne vaut pas grand-chose.
SRC="$ROOT/dist/Source.adf"
rm -f "$SRC"
xdftool "$SRC" create + format "Faerghail-Src" + makedir Src
for f in "$STAGE"/Src/*.s "$STAGE"/Src/*.i; do
	xdftool "$SRC" write "$f" "Src/$(basename "$f")"
done

python3 "$ROOT/tools/make_lha.py"	# tout, en archive LhA

for d in "$GAME" "$SRC"; do
	printf '==> %s  ' "$d"
	xdftool "$d" info | awk '/^used:/ {printf "%s occupes, ", $3}
	                          /^free:/ {printf "%s libres\n", $3}'
done
