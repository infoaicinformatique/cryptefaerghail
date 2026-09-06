#!/bin/sh
# Telecharge et compile vasm (assembleur 68k) et vlink (editeur de liens
# multi-formats) de Frank Wille, dans tools/bin. Necessite gcc et make.
set -e

ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORK="$ROOT/tools/.build"
BIN="$ROOT/tools/bin"
mkdir -p "$WORK" "$BIN"
cd "$WORK"

echo "==> vasm"
[ -f vasm.tar.gz ] || curl -sSLO http://sun.hasenbraten.de/vasm/release/vasm.tar.gz
rm -rf vasm && tar xzf vasm.tar.gz
make -C vasm CPU=m68k SYNTAX=mot
cp vasm/vasmm68k_mot "$BIN/"

echo "==> vlink"
[ -f vlink.tar.gz ] || curl -sSLO http://sun.hasenbraten.de/vlink/release/vlink.tar.gz
rm -rf vlink && tar xzf vlink.tar.gz
mkdir -p vlink/objects
make -C vlink
cp vlink/vlink "$BIN/"

echo "==> outils installes dans $BIN"
