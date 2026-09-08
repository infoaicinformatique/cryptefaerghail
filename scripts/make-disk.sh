#!/bin/sh
# Fabrique dist/AGADemos.adf : une disquette 880 Ko OFS amorcable
# contenant les deux demos, leur source et le module.
#
# Necessite xdftool (paquet amitools) :  pip install amitools
set -e

ROOT=$(cd "$(dirname "$0")/.." && pwd)
ADF="$ROOT/dist/AGADemos.adf"
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
cp "$ROOT/bin/AGADemo" "$ROOT/bin/AGAScroll" "$ROOT/bin/AGACrawl" "$STAGE/"
cp "$ROOT"/src/*.s "$ROOT"/src/*.i "$STAGE/Src/"
cp "$ROOT/data/music.mod" "$ROOT/data/crawlmus.mod" \
	"$ROOT/data/titlemus.mod" \
	"$ROOT/data/dgnart.bin" "$ROOT/data/dgnmap.bin" \
	"$ROOT/data/sfx.bin" "$STAGE/Src/data/"

rm -f "$ADF"
xdftool "$ADF" create + format "AGADemos" \
	+ write "$STAGE/AGACrawl" \
	+ write "$STAGE/AGAScroll" \
	+ write "$STAGE/AGADemo" \
	+ write "$STAGE/Lisezmoi.txt" \
	+ makedir S \
	+ write "$STAGE/S/Startup-Sequence" S/Startup-Sequence \
	+ makedir Src
# Les sources tiennent sur la disquette, pas les donnees generees : a
# huit bitplanes les decors pesent a eux seuls plus de trois cent
# quatre-vingt mille octets. Elles restent dans l'archive LhA, et les
# generateurs Python les refabriquent.
#
# Les tables ecrites en dc.w sont du meme bois : surfgrad.i pese a lui
# seul quatre-vingt mille octets -- les huit cent seize couleurs que le
# copper pose par trame, fois six clartes. Elles portent toutes la
# mention GENERE PAR en tete, et les generateurs Python les refont en
# une seconde ; on ne met sur la disquette que ce qui est ecrit a la
# main.
#
# Il ne reste plus la place de tout mettre. A huit bitplanes le jeu
# pese a lui seul plus d'un demi-megaoctet -- six cent mille octets une
# fois sur la disquette, ou un bloc de 512 n'en porte que 488 -- et les
# trois programmes en occupent six cent quarante mille sur huit cent
# quatre-vingt.
#
# Le source du jeu ne tient donc plus : crawl.s pese cent quarante-huit
# mille octets, trois cents blocs, et il n'en reste pas dix. On ecrit
# ce qui rentre, dans l'ordre ci-dessous, et on dit ce qu'on laisse --
# l'archive LhA, elle, porte tout. Les tables generees ne sont sur
# aucune des deux : surfgrad.i pese a lui seul quatre-vingt mille
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

for f in hardware.i vblank.i ptreplay.i demo.s scroll.s crawl.s; do
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
