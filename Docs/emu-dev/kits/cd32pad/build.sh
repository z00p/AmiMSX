#!/bin/sh
# Build the test tool and assemble-check the asm routine (amiga-gcc + vasm).
set -e
cd "$(dirname "$0")"
m68k-amigaos-gcc -O2 -m68000 -Wall -noixemul -o cd32test cd32test.c cd32pad.c
vasmm68k_mot -quiet -devpac -m68000 -Fhunk -o cd32pad.o cd32pad.s
ls -l cd32test cd32pad.o
