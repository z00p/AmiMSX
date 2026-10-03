"""Render all 32 name rows (256 lines) of a V9938 SCREEN 4 (G3) page from a
128 KB VRAM dump (or an AmiMSX trace.bin), without sprites or scroll: rows
24-31 are what R#23 brings into view in 212-line mode. Tables as the V9938:
names (R#2 & 7Fh) << 10; patterns (R#4 & 3Ch) << 11, block (row >> 3) masked
by R#4 bits 1-0; colours (R#10 << 14) | (R#3 & 80h) << 6, block masked by
R#3 bits 6-5. TMS9918 palette (no MSX2 palette).
Usage: python tools/render_scr4_full.py <vram.bin|trace.bin> R2 R3 R4 R10 out.png"""
import sys
from PIL import Image, ImageDraw

PAL = [(0, 0, 0), (0, 0, 0), (33, 200, 66), (94, 220, 120), (84, 85, 237), (125, 118, 252),
       (212, 82, 77), (66, 235, 245), (252, 85, 84), (255, 121, 120), (212, 193, 84), (230, 206, 128),
       (33, 176, 59), (201, 91, 186), (204, 204, 204), (255, 255, 255)]

src, out = sys.argv[1], sys.argv[6]
r2, r3, r4, r10 = (int(a, 0) for a in sys.argv[2:6])
d = open(src, "rb").read()
v = d[80 + 32768:80 + 32768 + 131072] if d[:4] == b"ATRC" else d
names = (r2 & 0x7F) << 10
pbase, pmask = (r4 & 0x3C) << 11, r4 & 3
cbase, cmask = (r10 << 14) | ((r3 & 0x80) << 6), (r3 >> 5) & 3
img = Image.new("RGB", (256, 256))
px = img.load()
for row in range(32):
    blk = row >> 3
    for col in range(32):
        ch = v[names + row * 32 + col]
        for y in range(8):
            p = v[pbase | ((blk & pmask) << 11) | (ch << 3) | y]
            c = v[cbase | ((blk & cmask) << 11) | (ch << 3) | y]
            fg, bg = PAL[c >> 4], PAL[c & 15]
            for x in range(8):
                px[col * 8 + x, row * 8 + y] = fg if p & (0x80 >> x) else bg
big = img.resize((512, 512), Image.NEAREST)
ImageDraw.Draw(big).line([(0, 384), (511, 384)], fill=(255, 0, 255))   # row 24 starts here
big.save(out)
print("rendered", out)
