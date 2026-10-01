"""Render an MSX SCREEN 2/4 image from a VRAM dump with TMS9918/V9938 rules
(R#2 name table, R#3/R#4 colour/pattern tables with their masks), plus
sprites when R5 R6 R1 [mode] are given (mode 1 = TMS sprites, 2 = V9938
sprite mode 2 with the colour table 512 bytes below the attribute table).
Usage: python tools/render_scr2.py <vram.bin|trace.bin> R2 R3 R4 out.png [R5 R6 R1 mode]"""
import sys
from PIL import Image
PAL = [(0,0,0),(0,0,0),(33,200,66),(94,220,120),(84,85,237),(125,118,252),(212,82,77),(66,235,245),
       (252,85,84),(255,121,120),(212,193,84),(230,206,128),(33,176,59),(201,91,186),(204,204,204),(255,255,255)]
src, r2, r3, r4, out = sys.argv[1], *(int(a, 0) for a in sys.argv[2:5]), sys.argv[5]
spr = [int(a, 0) for a in sys.argv[6:10]]
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
if spr:
    r5, r6, r1, mode = spr
    size = 16 if r1 & 2 else 8
    mag = 2 if r1 & 1 else 1
    sat = (r5 << 7) & (0x1FC00 if mode == 2 else 0x1FF80)
    sat = sat | 0x200 if mode == 2 else sat
    sct = sat - 0x200
    spg = (r6 & 0x3F) << 11
    end = 216 if mode == 2 else 208
    sprites = []
    for i in range(32):
        y, x, pat, att = vram[sat + 4 * i: sat + 4 * i + 4]
        if y == end: break
        sprites.append((i, y, x, pat & (0xFC if size == 16 else 0xFF), att))
    for i, y, x, pat, att in reversed(sprites):       # lower numbers on top
        top = y + 1 if y < 0xE0 else y + 1 - 256
        for line in range(size * mag):
            sy = top + line
            if not 0 <= sy < 192: continue
            row = line // mag
            colour = (vram[sct + 16 * i + row] if mode == 2 else att) & 15
            ec = (vram[sct + 16 * i + row] if mode == 2 else att) & 0x80
            if colour == 0: continue
            bits = vram[spg + pat * 8 + row] << 8 | (vram[spg + pat * 8 + row + 16] if size == 16 else 0)
            for b in range(size):
                if bits & (0x8000 >> b):
                    for m in range(mag):
                        sx = x - (32 if ec else 0) + b * mag + m
                        if 0 <= sx < 256: px[sx, sy] = PAL[colour]
img.resize((512, 384), Image.NEAREST).save(out)
print("rendered", out)
