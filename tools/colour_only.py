"""Is the difference between two captures colour only (a palette change), or
content/position? For each pair: 'map' = share of pixels whose new colour is
the usual new colour of their old colour; 'edges' = share of pixels where
"differs from the right/lower neighbour" disagrees between the two (content
or position moved). Colour-only changes: map ~1.0, edges ~0.

Usage: python tools/colour_only.py <run dir> [<baseline dir>]
       (both laid out as <id>/<n>s.png, as build/regress/<run>/)"""
import collections, glob, os, sys
from PIL import Image


def compare(a, b):
    A = Image.open(a).convert("RGB")
    B = Image.open(b).convert("RGB")
    if A.size != B.size:
        return None
    pa, pb = list(A.getdata()), list(B.getdata())
    m = collections.defaultdict(collections.Counter)
    for x, y in zip(pa, pb):
        m[x][y] += 1
    ok = sum(c.most_common(1)[0][1] for c in m.values())
    w, h = A.size
    bad = 0
    for i in range(0, len(pa) - w - 1):
        ea = (pa[i] != pa[i + 1], pa[i] != pa[i + w])
        eb = (pb[i] != pb[i + 1], pb[i] != pb[i + w])
        bad += ea != eb
    return ok / len(pa), bad / len(pa)


def main():
    run = sys.argv[1]
    base = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(run), "baseline")
    for new in sorted(glob.glob(os.path.join(run, "*", "*s.png"))):
        rid, s = new.split(os.sep)[-2:]
        old = os.path.join(base, rid, s)
        if not os.path.exists(old):
            print(f"{rid:32s} {s:5s} no baseline")
            continue
        r = compare(old, new)
        if r is None:
            print(f"{rid:32s} {s:5s} size differs")
            continue
        same = open(old, "rb").read() == open(new, "rb").read()
        print(f"{rid:32s} {s:5s} map {r[0]:.4f} edges {r[1]:.4f}" + ("  identical" if same else ""))


if __name__ == "__main__":
    main()
