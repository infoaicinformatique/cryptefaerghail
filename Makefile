#-----------------------------------------------------------------------
# Demo AGA pour Amiga 1200 - cross-compilation depuis Linux/macOS
#
#   make toolchain   telecharge et compile vasm + vlink dans tools/bin
#   make             assemble et lie bin/AGADemo (executable hunk Amiga)
#   make data        regenere src/sine.i et src/sprite.i (Python 3)
#   make clean       nettoie build/ et bin/
#-----------------------------------------------------------------------

NAME    := AGADemo
CPU     := -m68020

VASM    ?= $(if $(wildcard tools/bin/vasmm68k_mot),tools/bin/vasmm68k_mot,vasmm68k_mot)
VLINK   ?= $(if $(wildcard tools/bin/vlink),tools/bin/vlink,vlink)

SRC     := src/demo.s
INCS    := src/hardware.i src/sine.i src/sprite.i
OBJ     := build/demo.o
TARGET  := bin/$(NAME)

.PHONY: all clean data toolchain

all: $(TARGET)

$(TARGET): $(OBJ)
	@mkdir -p bin
	$(VLINK) -bamigahunk -Bstatic -s -o $@ $<
	@echo "==> $@ pret : copiez-le sur l'Amiga (ou dans un repertoire monte par FS-UAE)"

$(OBJ): $(SRC) $(INCS)
	@mkdir -p build
	$(VASM) $(CPU) -Fhunk -I src -o $@ $(SRC)

data:
	python3 tools/gen_data.py

toolchain:
	sh scripts/get-toolchain.sh

clean:
	rm -rf build bin
