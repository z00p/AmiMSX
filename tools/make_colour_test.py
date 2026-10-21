"""Colour test ROM (16 KB, plain, 4000h): SCREEN 1 with 32 solid columns,
column c in colour c AND 15 (column 0 = colour 0 = backdrop, R#7 = 1).
Phase 1 (first 4 s after boot): the machine's default palette.
Phase 2 (after that, MSX2+ only): palette 1-7 = grey levels 1..7, 8 = 700,
9 = 070, 10 = 007, 11 = 754 (R G B), 12 = 743, 13 = 157, 14 = 555, 15 = 777.
Capture at ~5 s and ~16 s in AmiMSX and openMSX and compare the colours.

Usage: python tools/make_colour_test.py <out.rom>"""
import sys

PH2 = [(0, 0, 0)] + [(k, k, k) for k in range(1, 8)] + [
    (7, 0, 0), (0, 7, 0), (0, 0, 7), (7, 5, 4), (7, 4, 3), (1, 5, 7), (5, 5, 5), (7, 7, 7)]


def build():
    rom = bytearray(16384)
    rom[0:4] = b"AB\x10\x40"
    code_at = 0x4010
    names_at, col_at, pal_at = 0x4100, 0x4080, 0x40C0
    c = bytearray()
    c += b"\xCD\x6F\x00"                      # call INIT32
    c += b"\x21\x00\x08\x01\x00\x08\x3E\xFF\xCD\x56\x00"   # FILVRM 0800h,2048,FFh
    c += bytes([0x21, col_at & 255, col_at >> 8, 0x11, 0x00, 0x20, 0x01, 32, 0, 0xCD, 0x5C, 0x00])
    c += bytes([0x21, names_at & 255, names_at >> 8, 0x11, 0x00, 0x18, 0x01, 0x00, 0x03, 0xCD, 0x5C, 0x00])
    c += b"\x01\x07\x01\xCD\x47\x00"          # WRTVDP R#7 = 1
    c += b"\x01\xC8\x00"                      # ld bc,200 (4 s at 50 Hz)
    c += b"\xFB\x76\x0B\x78\xB1\x20\xF9"      # ei; halt; dec bc; ld a,b; or c; jr nz
    c += b"\xF3\xAF\xD3\x99\x3E\x90\xD3\x99"  # di; R#16 = 0
    c += bytes([0x21, pal_at & 255, pal_at >> 8, 0x01, 0x9A, 32, 0xED, 0xB3])  # otir
    c += b"\xFB\x76\x18\xFD"                  # ei; halt; jr halt
    assert len(c) < 0x70
    rom[code_at - 0x4000:code_at - 0x4000 + len(c)] = c
    for i in range(32):
        rom[col_at - 0x4000 + i] = ((i & 15) << 4) | (i & 15)
    for i, (r, g, b) in enumerate(PH2):
        rom[pal_at - 0x4000 + 2 * i] = (r << 4) | b
        rom[pal_at - 0x4000 + 2 * i + 1] = g
    for row in range(24):
        for col in range(32):
            rom[names_at - 0x4000 + row * 32 + col] = (col * 8) & 255
    return rom


if __name__ == "__main__":
    open(sys.argv[1], "wb").write(build())
