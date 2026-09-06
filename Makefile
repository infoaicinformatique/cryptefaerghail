#-----------------------------------------------------------------------
# Demo AGA pour Amiga 1200 - cross-compilation depuis Linux/macOS
#
#   make toolchain   telecharge et compile vasm + vlink dans tools/bin
#   make             assemble bin/AGADemo et bin/AGAScroll (hunks Amiga)
#   make data        regenere les .i de donnees (Python 3)
#   make music       regenere data/music.mod (module ProTracker)
#   make dungeon     regenere les donnees du jeu (art, cartes, police 8x8)
#   make wav         rend la musique en WAV pour l'ecouter sans Amiga
#   make check       verifie l'arithmetique du scroll et de la copperlist
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

.PHONY: all clean data music wav dungeon check preview disk toolchain

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
                  src/font8.i data/dgnart.bin data/dgnmap.bin data/music.mod
	@mkdir -p build
	$(VASM) $(CPU) -Fhunk -I src -I . -o $@ src/crawl.s

data:
	python3 tools/gen_data.py

music:
	python3 tools/gen_module.py

dungeon:
	python3 tools/gen_dungeon.py

wav:
	python3 tools/render_mod.py 30 music.wav

check:
	python3 tools/preview.py 40 /dev/null

preview:
	python3 tools/preview.py 40 docs/preview.png

disk:
	sh scripts/make-disk.sh

toolchain:
	sh scripts/get-toolchain.sh

clean:
	rm -rf build bin music.wav
