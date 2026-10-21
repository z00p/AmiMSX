"""Read the 15 bars of tools/make_colour_test.py's ROM from a capture: the
runs of one colour along the middle line, left to right (the brighter of two
adjacent lines, for openMSX's scanlines). Prints colour k (1..15) = R,G,B
(colour 1 is the backdrop: the first run).

Usage: python tools/colour_bars.py <png> [<png> ...]"""
import sys
from PIL import Image


def bars(path):
    im = Image.open(path).convert("RGB")
    y = im.height // 2
    best = []
    for yy in (y, y + 1):
        row = [im.getpixel((x, yy)) for x in range(im.width)]
        runs, start = [], 0
        for x in range(1, im.width + 1):
            if x == im.width or row[x] != row[start]:
                if x - start >= 6:
                    runs.append(row[start])
                start = x
        # drop the backdrop/border (colour 1 = black or the backdrop) runs at the edges
        runs = [runs[0]] + [c for c in runs if c != runs[0]] if runs else runs
        if sum(map(sum, runs)) > sum(map(sum, best)):
            best = runs
    return best


for p in sys.argv[1:]:
    b = bars(p)
    print(p, len(b))
    for k, c in enumerate(b[:16], 1):
        print(f"  {k:2d} = {c[0]:3d},{c[1]:3d},{c[2]:3d}")
