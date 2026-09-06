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
cp "$ROOT/data/music.mod" "$ROOT/data/dgnart.bin" "$ROOT/data/dgnmap.bin" \
	"$STAGE/Src/data/"

rm -f "$ADF"
xdftool "$ADF" create + format "AGADemos" \
	+ write "$STAGE/AGACrawl" \
	+ write "$STAGE/AGAScroll" \
	+ write "$STAGE/AGADemo" \
	+ write "$STAGE/Lisezmoi.txt" \
	+ makedir S \
	+ write "$STAGE/S/Startup-Sequence" S/Startup-Sequence \
	+ makedir Src \
	+ makedir Src/data
for f in "$STAGE"/Src/*.s "$STAGE"/Src/*.i; do
	xdftool "$ADF" write "$f" "Src/$(basename "$f")"
done
for f in "$STAGE"/Src/data/*; do
	xdftool "$ADF" write "$f" "Src/data/$(basename "$f")"
done
xdftool "$ADF" boot install			# bootblock DOS0 : la disquette demarre

python3 "$ROOT/tools/make_lha.py"		# meme contenu, en archive LhA

echo "==> $ADF"
xdftool "$ADF" boot show | grep -E "dos_type|bootable"
