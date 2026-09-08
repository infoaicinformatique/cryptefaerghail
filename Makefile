#-----------------------------------------------------------------------
# La Crypte de Faerghail - cross-compilation depuis Linux/macOS
#
#   make toolchain   telecharge et compile vasm + vlink dans tools/bin
#   make             assemble bin/AGACrawl (executable hunk Amiga)
#   make dungeon     regenere toutes les donnees du jeu (art, cartes,
#                    police, tables d'objets et de sorts, bruitages)
#   make score       regenere les deux musiques
#   make wav         rend les musiques en WAV pour les ecouter sans Amiga
#   make test        fait tourner le jeu dans un 68020 emule
#   make shots       photographie les ecrans du jeu emule
#   make disk        fabrique dist/Faerghail.adf (disquette amorcable) et
#                    dist/Faerghail.lha -- necessite pip install amitools
#   make clean       nettoie build/ et bin/
#-----------------------------------------------------------------------

CPU     := -m68020

VASM    ?= $(if $(wildcard tools/bin/vasmm68k_mot),tools/bin/vasmm68k_mot,vasmm68k_mot)
VLINK   ?= $(if $(wildcard tools/bin/vlink),tools/bin/vlink,vlink)

TARGETS := bin/AGACrawl

.PHONY: all clean score wav dungeon disk test shots toolchain

all: $(TARGETS)

bin/%: build/%.o
	@mkdir -p bin
	$(VLINK) -bamigahunk -Bstatic -s -o $@ $<
	@echo "==> $@ pret : copiez-le sur l'Amiga (ou dans un repertoire monte par FS-UAE)"

build/AGACrawl.o: src/crawl.s src/hardware.i src/ptreplay.i src/vblank.i \
                  src/ciatimer.i src/dgnpal.i \
                  src/font8.i src/tables.i data/dgnart.bin data/dgnmap.bin \
                  data/sfx.bin data/crawlmus.mod data/titlemus.mod
	@mkdir -p build
	$(VASM) $(CPU) -Fhunk -I src -I . -o $@ src/crawl.s

score:
	python3 tools/gen_score.py

dungeon:
	python3 tools/gen_dungeon.py
	python3 tools/gen_tables.py
	python3 tools/gen_sfx.py
	python3 tools/gen_score.py

wav:
	python3 tools/render_mod.py 45 score.wav data/crawlmus.mod
	python3 tools/render_mod.py 32 accueil.wav data/titlemus.mod

# Fait tourner le jeu dans un 68020 emule et verifie son comportement.
test:
	python3 tools/test_game.py
	python3 tools/test_sfx.py
	python3 tools/test_replay.py
	python3 tools/test_copper.py
	python3 tools/test_save.py
	python3 tools/test_layout.py
	python3 tools/play_game.py

# Photographie les ecrans tels que le processeur les dessine.
shots:
	python3 tools/shot68k.py

disk:
	sh scripts/make-disk.sh

toolchain:
	sh scripts/get-toolchain.sh

clean:
	rm -rf build bin score.wav accueil.wav
