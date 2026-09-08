#!/bin/sh
# Fabrique dist/Faerghail.adf : une disquette 880 Ko OFS amorcable
# contenant le jeu, ce qui tient de son source, et le Lisezmoi.
#
# Necessite xdftool (paquet amitools) :  pip install amitools
set -e

ROOT=$(cd "$(dirname "$0")/.." && pwd)
ADF="$ROOT/dist/Faerghail.adf"
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
cp "$ROOT/data/dgnart.bin" "$ROOT/data/dgnmap.bin" "$ROOT/data/sfx.bin" \
	"$ROOT/data/crawlmus.mod" "$ROOT/data/titlemus.mod" "$STAGE/Src/data/"

rm -f "$ADF"
xdftool "$ADF" create + format "Faerghail" \
	+ write "$STAGE/AGACrawl" \
	+ write "$STAGE/Lisezmoi.txt" \
	+ makedir S \
	+ write "$STAGE/S/Startup-Sequence" S/Startup-Sequence \
	+ makedir Src

# Il ne reste plus la place de tout mettre. A huit bitplanes le jeu pese
# a lui seul plus d'un demi-megaoctet -- six cent mille octets une fois
# sur la disquette, ou un bloc de 512 n'en porte que 488 -- sur huit
# cent quatre-vingt.
#
# On ecrit ce qui rentre, dans l'ordre ci-dessous, et l'on dit ce qu'on
# laisse ; l'archive LhA, elle, porte tout. Les tables generees ne sont
# sur aucune des deux : surfgrad.i pese a lui seul quatre-vingt mille
# octets, et les generateurs Python les refont en une seconde.
blocks_free() {
	xdftool "$ADF" info | awk '/^free:/ { print $2 }'
}

blocks_for() {			# blocs OFS d'un fichier : donnees, extensions,
	python3 -c '		# et l en-tete -- 488 octets par bloc, 72 par liste
import math, sys
data = max(1, math.ceil(int(sys.argv[1]) / 488))
print(data + max(0, math.ceil(data / 72) - 1) + 1)' "$1"
}

for f in hardware.i vblank.i ciatimer.i ptreplay.i crawl.s; do
	size=$(wc -c < "$STAGE/Src/$f" | tr -d ' ')
	if [ "$(blocks_for "$size")" -le "$(blocks_free)" ]; then
		xdftool "$ADF" write "$STAGE/Src/$f" "Src/$f"
	else
		echo "    Src/$f reste dans l'archive LhA (pas la place)"
	fi
done
xdftool "$ADF" boot install			# bootblock DOS0 : la disquette demarre

python3 "$ROOT/tools/make_lha.py"		# meme contenu, en archive LhA

echo "==> $ADF"
xdftool "$ADF" boot show | grep -E "dos_type|bootable"
