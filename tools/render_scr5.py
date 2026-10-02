"""Render a 128 KB VRAM dump as four SCREEN 5 pages (256x256, 4 bpp) side by side.
Usage: python tools/render_scr5.py vram.bin palette.bin out.png
palette.bin: openMSX 'VDP palette' (16 x 2 bytes, 0RRR0BBB 00000GGG), or '-' for grey."""
import sys
from PIL import Image

vram = open(sys.argv[1], "rb").read()
if sys.argv[2] != "-":
    p = open(sys.argv[2], "rb").read()
    pal = [((p[2 * i] >> 4 & 7) * 255 // 7, (p[2 * i + 1] & 7) * 255 // 7, (p[2 * i] & 7) * 255 // 7) for i in range(16)]
else:
    pal = [(i * 17,) * 3 for i in range(16)]
img = Image.new("RGB", (256 * 4 + 12, 256))
px = img.load()
for page in range(4):
    for y in range(256):
        for x in range(0, 256, 2):
            b = vram[page * 0x8000 + y * 128 + x // 2]
            px[page * 259 + x, y] = pal[b >> 4]
            px[page * 259 + x + 1, y] = pal[b & 15]
img.save(sys.argv[3])
