"""Per-frame horizontal position of a bright sprite (Manbow 2's ship) and the
background's scroll step in a burst (tools/sprburst.py or burst.py output):
a sprite shown with a stale R#18 adjust creeps or jumps while the scenery
scrolls evenly.

Usage: python tools/shipx.py <burst dir with f00.png..> [--rows 44,72] [--bg 120,212]
Prints, per frame: ship x (left edge, centroid) and the background's dx
against the previous frame (column-profile match over the --bg rows)."""
import argparse, glob, os
import numpy as np
from PIL import Image


def load(f):
    return np.asarray(Image.open(f).convert("RGB").resize((256, 212), Image.NEAREST)).astype(int)


def ship(im, r0, r1):
    band = im[r0:r1]
    bright = (band.min(axis=2) > 180)        # white-ish pixels
    cols = np.where(bright.any(axis=0))[0]
    if len(cols) == 0:
        return None
    xs = np.where(bright)[1]
    return int(cols.min()), round(float(xs.mean()), 1), int(cols.max())


def scroll(a, b, r0, r1):
    pa = a[r0:r1].sum(axis=2).mean(axis=0)
    pb = b[r0:r1].sum(axis=2).mean(axis=0)
    best, bd = None, None
    for d in range(-8, 9):
        if d >= 0:
            x, y = pa[d:], pb[:256 - d]
        else:
            x, y = pa[:256 + d], pb[-d:]
        e = np.abs(x - y).mean()
        if best is None or e < best:
            best, bd = e, d
    return bd


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dir")
    ap.add_argument("--rows", default="44,72")
    ap.add_argument("--bg", default="120,212")
    a = ap.parse_args()
    r0, r1 = (int(v) for v in a.rows.split(","))
    b0, b1 = (int(v) for v in a.bg.split(","))
    fs = sorted(glob.glob(os.path.join(glob.escape(a.dir), "f*.png")))
    ims = [load(f) for f in fs]
    prev = None
    for f, im in zip(fs, ims):
        s = ship(im, r0, r1)
        dx = scroll(prev, im, b0, b1) if prev is not None else 0
        print(f"{os.path.basename(f)}  ship {s}  bg dx {dx:+d}")
        prev = im


if __name__ == "__main__":
    main()
