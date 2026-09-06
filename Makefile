#-----------------------------------------------------------------------
# Demo AGA pour Amiga 1200 - cross-compilation depuis Linux/macOS
#
#   make toolchain   telecharge et compile vasm + vlink dans tools/bin
#   make             assemble bin/AGADemo et bin/AGAScroll (hunks Amiga)
#   make data        regenere les .i de donnees (Python 3)
#   make check       verifie l'arithmetique du scroll et de la copperlist
#   make preview     rend une image de AGAScroll dans docs/preview.png
#   make clean       nettoie build/ et bin/
#-----------------------------------------------------------------------

CPU     := -m68020

VASM    ?= $(if $(wildcard tools/bin/vasmm68k_mot),tools/bin/vasmm68k_mot,vasmm68k_mot)
VLINK   ?= $(if $(wildcard tools/bin/vlink),tools/bin/vlink,vlink)

INCS    := src/hardware.i src/sine.i src/sprite.i src/palette.i
TARGETS := bin/AGADemo bin/AGAScroll

.PHONY: all clean data check preview toolchain

all: $(TARGETS)

bin/%: build/%.o
	@mkdir -p bin
	$(VLINK) -bamigahunk -Bstatic -s -o $@ $<
	@echo "==> $@ pret : copiez-le sur l'Amiga (ou dans un repertoire monte par FS-UAE)"

build/AGADemo.o: src/demo.s $(INCS)
	@mkdir -p build
	$(VASM) $(CPU) -Fhunk -I src -o $@ src/demo.s

build/AGAScroll.o: src/scroll.s $(INCS)
	@mkdir -p build
	$(VASM) $(CPU) -Fhunk -I src -o $@ src/scroll.s

data:
	python3 tools/gen_data.py

check:
	python3 tools/preview.py 40 /dev/null

preview:
	python3 tools/preview.py 40 docs/preview.png

toolchain:
	sh scripts/get-toolchain.sh

clean:
	rm -rf build bin
