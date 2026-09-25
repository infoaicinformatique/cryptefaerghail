#!/bin/sh
# Fabrique les deux disquettes 880 Ko OFS du jeu :
#
#   dist/Faerghail1.adf   amorcable : le jeu, son Lisezmoi, son
#                         Startup-Sequence
#   dist/Faerghail2.adf   le source : tout ce qui s'assemble, ecrit a la
#                         main ou genere, et les donnees qui tiennent
#
# Une seule disquette ne suffisait plus : a huit bitplanes le jeu pese a
# lui seul plus d'un demi-megaoctet, et il fallait choisir entre le
# source et les decors. Le jeu a maintenant sa disquette a lui, et la
# place d'y grandir.
#
# Necessite xdftool (paquet amitools) :  pip install amitools
set -e

ROOT=$(cd "$(dirname "$0")/.." && pwd)
ADF1="$ROOT/dist/Faerghail1.adf"
ADF2="$ROOT/dist/Faerghail2.adf"
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

# --- disquette 1 : le jeu -------------------------------------------------
rm -f "$ADF1"
xdftool "$ADF1" create + format "Faerghail" \
	+ write "$STAGE/AGACrawl" \
	+ write "$STAGE/Lisezmoi.txt" \
	+ makedir S \
	+ write "$STAGE/S/Startup-Sequence" S/Startup-Sequence
xdftool "$ADF1" boot install			# bootblock DOS0 : la disquette demarre

# --- disquette 2 : le source ---------------------------------------------
# Le source tient tout entier, tables generees comprises : on peut
# reassembler sur l'Amiga. Les decors, eux, pesent plus d'un
# demi-megaoctet a eux seuls ; on ecrit ce qui rentre, dans l'ordre
# ci-dessous, et l'on dit ce qu'on laisse. L'archive LhA porte tout.
rm -f "$ADF2"
xdftool "$ADF2" create + format "Faerghail2" \
	+ write "$STAGE/Lisezmoi.txt" \
	+ makedir Src + makedir Src/data

blocks_free() {
	xdftool "$ADF2" info | awk '/^free:/ { print $2 }'
}

blocks_for() {			# blocs OFS d'un fichier : donnees, extensions,
	python3 -c '		# et l en-tete -- 488 octets par bloc, 72 par liste
import math, sys
data = max(1, math.ceil(int(sys.argv[1]) / 488))
print(data + max(0, math.ceil(data / 72) - 1) + 1)' "$1"
}

put() {				# $1 = fichier de la copie, $2 = chemin Amiga
	size=$(wc -c < "$1" | tr -d ' ')
	if [ "$(blocks_for "$size")" -le "$(blocks_free)" ]; then
		xdftool "$ADF2" write "$1" "$2"
	else
		echo "    $2 reste dans l'archive LhA (pas la place)"
	fi
}

for f in crawl.s hardware.i vblank.i ciatimer.i ptreplay.i; do
	put "$STAGE/Src/$f" "Src/$f"
done
for f in "$STAGE"/Src/*.i; do			# les tables generees
	n=$(basename "$f")
	case " hardware.i vblank.i ciatimer.i ptreplay.i " in
	*" $n "*) ;;
	*) put "$f" "Src/$n" ;;
	esac
done
for f in dgnmap.bin sfx.bin titlemus.mod crawlmus.mod dgnart.bin; do
	put "$STAGE/Src/data/$f" "Src/data/$f"
done

python3 "$ROOT/tools/make_lha.py"		# meme contenu, en archive LhA

for adf in "$ADF1" "$ADF2"; do
	echo "==> $adf"
	xdftool "$adf" info | awk '/^used:|^free:/'
done
xdftool "$ADF1" boot show | grep -E "dos_type|bootable"
