#-----------------------------------------------------------------------
# Demo AGA pour Amiga 1200 - cross-compilation depuis Linux/macOS
#
#   make toolchain   telecharge et compile vasm + vlink dans tools/bin
#   make             assemble bin/AGADemo et bin/AGAScroll (hunks Amiga)
#   make data        regenere les .i de donnees (Python 3)
#   make music       regenere data/music.mod (module des demos)
#   make score       regenere les deux musiques du jeu
#   make dungeon     regenere toutes les donnees du jeu (art, cartes,
#                    police, tables d'objets et de sorts, bruitages)
#   make wav         rend la musique en WAV pour l'ecouter sans Amiga
#   make check       verifie l'arithmetique du scroll et de la copperlist
#   make test        fait tourner le jeu dans un 68020 emule
#   make shots       photographie les ecrans du jeu emule
#   make preview     rend une image de AGAScroll dans docs/preview.png
#   make disk        fabrique dist/AGADemos.adf (disquette amorcable) et
#                    dist/AGADemos.lha -- necessite pip install amitools
#   make clean       nettoie build/ et bin/
#-----------------------------------------------------------------------

CPU     := -m68020

VASM    ?= $(if $(wildcard tools/bin/vasmm68k_mot),tools/bin/vasmm68k_mot,vasmm68k_mot)
VLINK   ?= $(if $(wildcard tools/bin/vlink),tools/bin/vlink,vlink)

INCS    := src/hardware.i src/sine.i src/sprite.i src/palette.i \
           src/ptreplay.i data/music.mod
TARGETS := bin/AGADemo bin/AGAScroll bin/AGACrawl

.PHONY: all clean data music score wav dungeon check preview disk \
        test shots toolchain

all: $(TARGETS)

bin/%: build/%.o
	@mkdir -p bin
	$(VLINK) -bamigahunk -Bstatic -s -o $@ $<
	@echo "==> $@ pret : copiez-le sur l'Amiga (ou dans un repertoire monte par FS-UAE)"

build/AGADemo.o: src/demo.s $(INCS)
	@mkdir -p build
	$(VASM) $(CPU) -Fhunk -I src -I . -o $@ src/demo.s

build/AGAScroll.o: src/scroll.s $(INCS)
	@mkdir -p build
	$(VASM) $(CPU) -Fhunk -I src -I . -o $@ src/scroll.s

build/AGACrawl.o: src/crawl.s src/hardware.i src/ptreplay.i src/dgnpal.i \
                  src/font8.i src/tables.i data/dgnart.bin data/dgnmap.bin \
                  data/sfx.bin data/crawlmus.mod data/titlemus.mod
	@mkdir -p build
	$(VASM) $(CPU) -Fhunk -I src -I . -o $@ src/crawl.s

data:
	python3 tools/gen_data.py

music:
	python3 tools/gen_module.py

score:
	python3 tools/gen_score.py

dungeon:
	python3 tools/gen_dungeon.py
	python3 tools/gen_tables.py
	python3 tools/gen_sfx.py
	python3 tools/gen_score.py

wav:
	python3 tools/render_mod.py 30 music.wav
	python3 tools/render_mod.py 45 score.wav data/crawlmus.mod
	python3 tools/render_mod.py 32 accueil.wav data/titlemus.mod

check:
	python3 tools/preview.py 40 /dev/null

# Fait tourner le jeu dans un 68020 emule et verifie son comportement.
test:
	python3 tools/test_game.py
	python3 tools/test_sfx.py
	python3 tools/test_save.py
	python3 tools/test_layout.py
	python3 tools/play_game.py

# Photographie les ecrans tels que le processeur les dessine.
shots:
	python3 tools/shot68k.py

preview:
	python3 tools/preview.py 40 docs/preview.png

disk:
	sh scripts/make-disk.sh

toolchain:
	sh scripts/get-toolchain.sh

clean:
	rm -rf build bin music.wav score.wav accueil.wav
