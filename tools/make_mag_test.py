"""Build a tiny MSX test ROM for magnified sprites (R#1 MAG) in sprite mode 1:
SCREEN 2, MAG on, SI off (8x8 patterns shown 16x16) unless 'si' is given, and
six sprites that exercise SPRMAG's cases: distinct patterns (triangle, box,
checker, diamond), one with EC (32 dots left), one at Y=241 (starts above the
top line: two rows on lines 0-1), two side by side on one line, one at the
bottom. Usage: python tools/make_mag_test.py out.rom [si|nomag]
('nomag': the same sprites unmagnified, for the colour/position reference)."""
import sys
out = sys.argv[1]
si = len(sys.argv) > 2 and sys.argv[2] == "si"
nomag = len(sys.argv) > 2 and sys.argv[2] == "nomag"
CHGMOD, WRTVDP, LDIRVM, RG1SAV = 0x005F, 0x0047, 0x005C, 0xF3E0
spg, sat = 0x3800, 0x1B00           # SCREEN 2 BIOS defaults (sprite mode 1)
w = lambda v: [v & 0xFF, v >> 8]
code = []
code += [0x3E, 2, 0xCD] + w(CHGMOD)                                          # SCREEN 2
r1 = 0x00 if nomag else 0x03 if si else 0x01
code += [0x3A] + w(RG1SAV) + [0xF6, r1, 0x47, 0x0E, 0x01, 0xCD] + w(WRTVDP)   # R#1 |= MAG (|SI)
code += [0x21] + w(0x4200) + [0x11] + w(spg) + [0x01] + w(8 * 8) + [0xCD] + w(LDIRVM)   # patterns 0-7
code += [0x21] + w(0x4100) + [0x11] + w(sat) + [0x01] + w(7 * 4) + [0xCD] + w(LDIRVM)   # attributes
code += [0x18, 0xFE]                                                         # JR $
rom = bytearray(16384)
rom[0:2] = b"AB"; rom[2:4] = bytes(w(0x4010))
rom[0x10:0x10 + len(code)] = bytes(code)
pats = [
    [0x80, 0xC0, 0xE0, 0xF0, 0xF8, 0xFC, 0xFE, 0xFF],   # 0 triangle
    [0xFF, 0x81, 0x81, 0x81, 0x81, 0x81, 0x81, 0xFF],   # 1 box
    [0xFF] * 8,                                          # 2 solid
    [0xAA, 0x55] * 4,                                    # 3 checker (2x2 blocks when doubled)
    [0x18, 0x3C, 0x7E, 0xFF, 0xFF, 0x7E, 0x3C, 0x18],   # 4 diamond
    [0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80],   # 5 diagonal
    [0xF0, 0xF0, 0xF0, 0xF0, 0x0F, 0x0F, 0x0F, 0x0F],   # 6 quarters
    [0x00] * 8,                                          # 7 empty
]
for i, p in enumerate(pats):
    rom[0x200 + i * 8:0x208 + i * 8] = bytes(p)
# Attributes: Y, X, pattern, colour (bit 7 EC). SI: patterns 0 and 4 (16x16 from 0-3, 4-7).
p = (lambda n: n & 0xFC) if si else (lambda n: n)
attr = [
    (40, 40, p(0), 15),          # white triangle
    (40, 100, p(1), 8 | 0x80),   # red box with EC: shown at X=68
    (241, 60, p(2), 11),         # yellow solid, rows 14-15 on lines 0-1
    (100, 160, p(3), 2),         # green checker and
    (100, 176, p(4), 5),         # blue diamond side by side (touching at 16 dots)
    (180, 200, p(5), 9),         # light red diagonal at the bottom (rows 181-196)
    (208, 0, 0, 0),              # end
]
for i, a in enumerate(attr):
    rom[0x100 + i * 4:0x104 + i * 4] = bytes(a)
open(out, "wb").write(rom)
print("wrote", out, len(code), "bytes of code", "SI" if si else "8x8")
