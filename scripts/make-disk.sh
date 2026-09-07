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
# trois programmes en occupent six cent trente mille sur huit cent
# quatre-vingt.
#
# On y met donc les trois programmes, et le source du jeu : crawl.s
# avec les trois fichiers ecrits a la main dont il depend. Le reste --
# le source des deux demos, leurs tables, et toutes les tables
# generees, dont surfgrad.i qui pese a lui seul quatre-vingt mille
# octets -- vit dans l'archive LhA, qui porte tout.
for f in crawl.s hardware.i ptreplay.i vblank.i; do
	xdftool "$ADF" write "$STAGE/Src/$f" "Src/$f"
done
xdftool "$ADF" boot install			# bootblock DOS0 : la disquette demarre

python3 "$ROOT/tools/make_lha.py"		# meme contenu, en archive LhA

echo "==> $ADF"
xdftool "$ADF" boot show | grep -E "dos_type|bootable"
