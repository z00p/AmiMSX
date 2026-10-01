"""Render an MSX SCREEN 2 image from a VRAM dump with TMS9918 rules
(R#2 name table, R#3/R#4 colour/pattern tables with their masks).
Usage: python tools/render_scr2.py <vram.bin|trace.bin> R2 R3 R4 out.png"""
import sys
from PIL import Image
PAL = [(0,0,0),(0,0,0),(33,200,66),(94,220,120),(84,85,237),(125,118,252),(212,82,77),(66,235,245),
       (252,85,84),(255,121,120),(212,193,84),(230,206,128),(33,176,59),(201,91,186),(204,204,204),(255,255,255)]
src, r2, r3, r4, out = sys.argv[1], *(int(a, 0) for a in sys.argv[2:5]), sys.argv[5]
d = open(src, "rb").read()
vram = d[80 + 32768:80 + 32768 + 131072] if d[:4] == b"ATRC" else d
names = (r2 & 0x0F) << 10
cbase, cmask = (r3 & 0x80) << 6, (r3 & 0x7F)
pbase, pmask = (r4 & 0x04) << 11, (r4 & 0x03)
img = Image.new("RGB", (256, 192))
px = img.load()
for row in range(24):
    t = row >> 3
    for col in range(32):
        c = vram[names + row * 32 + col]
        for y in range(8):
            pa = pbase | ((t & pmask) << 11) | (c << 3) | y
            ca = cbase | ((((t << 5) | (c >> 3)) & cmask) << 6) | ((c & 7) << 3) | y
            p, k = vram[pa], vram[ca]
            fg, bg = PAL[k >> 4], PAL[k & 15]
            for x in range(8):
                px[col * 8 + x, row * 8 + y] = fg if p & (0x80 >> x) else bg
img.resize((512, 384), Image.NEAREST).save(out)
print("rendered", out)
