"""Motion analysis of two consecutive-frame sequences (tools/burst.py output):
AmiMSX against openMSX, for what shows in motion and not in single frames.

Per frame pair it measures:
- scroll: the horizontal and vertical shift of a region (default: the whole
  picture) from the previous frame, by matching column and row profiles;
  a steady game scrolls by the same step every frame, judder shows as
  uneven steps;
- change: how much of the picture changed (0 = the same frame twice);
- flicker: pixels that go A, B, A over three frames.
It writes a report, a strip chart of the scroll steps (both emulators, one
row each) and a side-by-side animated GIF to watch.

With --perf <perf.bin> --start <s> (a PERF build's dump from a normal run,
no SNAPs: its DispLog holds, for each MSX frame, the Amiga frames since the
one before) the AmiMSX side of the GIF is also played as the Amiga showed
it: each MSX frame held for as many Amiga frames as it really was
(real_time.gif), and the report gives the hold pattern. The burst and the
timing come from different runs, so this is the typical rhythm at that
point, not the same frames.

Usage: python tools/motion.py <burst dir> [--region x0,y0,x1,y1] [--fps 50]
                              [--perf build/perf/x.bin --start 30]
       e.g. build/bursts/sm_vis/30s  (with amimsx/ and omsx/ inside)
"""
import struct, sys
import argparse, glob, os
import numpy as np
from PIL import Image, ImageDraw

W, H = 256, 212


def frames(d):
    out = []
    for f in sorted(glob.glob(os.path.join(d, "f*.png"))):
        im = Image.open(f).convert("RGB").resize((W, H), Image.NEAREST)
        out.append(np.asarray(im).astype(np.int16))
    return out


def shift_1d(a, b, maxs=12):
    """Best s with b[i] ~ a[i - s] (profile b is a moved by s), and its error."""
    best, err = 0, None
    n = len(a)
    for s in range(-maxs, maxs + 1):
        lo, hi = max(0, s), min(n, n + s)
        if hi - lo < n // 2:
            continue
        e = np.mean(np.abs(b[lo:hi] - a[lo - s:hi - s]))
        if err is None or e < err:
            best, err = s, e
    return best, err


def analyse(seq, region):
    x0, y0, x1, y1 = region
    res = []
    for i in range(1, len(seq)):
        a = seq[i - 1][y0:y1, x0:x1].sum(axis=2)
        b = seq[i][y0:y1, x0:x1].sum(axis=2)
        dx, _ = shift_1d(a.mean(axis=0), b.mean(axis=0))
        dy, _ = shift_1d(a.mean(axis=1), b.mean(axis=1))
        change = float(np.mean(np.any(seq[i] != seq[i - 1], axis=2)))
        flick = 0.0
        if i >= 2:
            p, q, r = seq[i - 2], seq[i - 1], seq[i]
            flick = float(np.mean(np.all(p == r, axis=2) & np.any(p != q, axis=2)))
        res.append((dx, dy, change, flick))
    return res


def describe(name, res):
    dx = [r[0] for r in res]
    ch = [r[2] for r in res]
    rep = sum(1 for c in ch if c == 0)
    steps = {}
    for s in dx:
        steps[s] = steps.get(s, 0) + 1
    flick = np.mean([r[3] for r in res]) * W * H
    return (f"{name}: {len(res) + 1} frames; horizontal steps {dict(sorted(steps.items()))}; "
            f"repeated frames {rep}; flicker {flick:.0f} px/frame")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dir")
    ap.add_argument("--region", default=f"0,0,{W},{H}")
    ap.add_argument("--fps", type=int, default=50)
    ap.add_argument("--perf")
    ap.add_argument("--start", type=float)
    a = ap.parse_args()
    region = tuple(int(v) for v in a.region.split(","))
    seqs = {}
    for name in ("amimsx", "omsx"):
        d = os.path.join(a.dir, name)
        if os.path.isdir(d):
            seqs[name] = frames(d)
    lines, results = [], {}
    for name, seq in seqs.items():
        if len(seq) < 3:
            continue
        results[name] = analyse(seq, region)
        lines.append(describe(name, results[name]))
        lines.append("  dx per frame: " + " ".join(f"{r[0]:+d}" for r in results[name]))
        lines.append("  dy per frame: " + " ".join(f"{r[1]:+d}" for r in results[name]))
    holds = None
    if a.perf and a.start is not None:
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        import pal_probe
        b = pal_probe.blocks(open(a.perf, "rb").read())
        log, n = b["displog"], struct.unpack(">I", b["dispn"])[0]
        f0 = int(a.start * a.fps)
        m = len(seqs.get("amimsx", [])) or 16
        if n - 4096 <= f0 and f0 + m + 1 < n:
            holds = [log[(f0 + i + 1) & 4095] for i in range(m)]
            lines.append("AmiMSX display holds (Amiga frames per MSX frame) from %gs: %s"
                         % (a.start, " ".join(str(h) for h in holds)))
            w0, w1 = max(0, n - 4096, f0 - 500), min(n, f0 + 500)
            win = [log[i & 4095] for i in range(w0 + 1, w1)]
            dist = {}
            for h in win:
                dist[h] = dist.get(h, 0) + 1
            lines.append("  10 s around it: " + ", ".join(f"{k} frame(s): {v}" for k, v in sorted(dist.items()))
                         + f"; MSX frames shown {len(win)} in {sum(win)} Amiga frames"
                           f" = {100 * len(win) / max(1, sum(win)):.0f}% speed")
        else:
            lines.append(f"(no display timing for {a.start}s in {a.perf}: {n} frames logged)")
    rep = os.path.join(a.dir, "motion.txt")
    open(rep, "w").write("\n".join(lines) + "\n")
    print("\n".join(lines))
    # strip chart of horizontal steps
    if results:
        n = max(len(r) for r in results.values())
        ch = Image.new("RGB", (max(200, n * 8 + 90), 40 * len(results) + 10), (24, 24, 24))
        d = ImageDraw.Draw(ch)
        for k, (name, res) in enumerate(results.items()):
            y = 10 + k * 40
            d.text((2, y + 10), name, fill=(255, 255, 0))
            for i, r in enumerate(res):
                h = max(-15, min(15, r[0] * 3))
                x = 80 + i * 8
                col = (90, 200, 90) if r[2] > 0 else (220, 60, 60)
                d.rectangle([x, y + 15 - max(h, 0), x + 5, y + 15 - min(h, 0) + 1], fill=col)
        ch.save(os.path.join(a.dir, "motion_steps.png"))
    # side-by-side GIF
    if len(seqs) == 2:
        A, B = seqs["amimsx"], seqs["omsx"]
        m = min(len(A), len(B))
        gif = []
        for i in range(m):
            im = Image.new("RGB", (W * 2 + 6, H + 14), (40, 40, 40))
            im.paste(Image.fromarray(A[i].astype(np.uint8)), (0, 14))
            im.paste(Image.fromarray(B[i].astype(np.uint8)), (W + 6, 14))
            dd = ImageDraw.Draw(im)
            dd.text((2, 1), f"AmiMSX  frame {i}", fill=(255, 255, 0))
            dd.text((W + 8, 1), "openMSX", fill=(255, 255, 0))
            gif.append(im)
        gif[0].save(os.path.join(a.dir, "side_by_side.gif"), save_all=True, append_images=gif[1:],
                    duration=int(1000 / a.fps), loop=0)
        if holds:
            # real time: one GIF frame per Amiga frame; AmiMSX's MSX frame i is
            # held holds[i] Amiga frames, openMSX shows one frame per Amiga frame
            rt, ia, ib = [], 0, 0
            left = holds[0] if holds else 1
            for t in range(sum(holds[:m])):
                im = Image.new("RGB", (W * 2 + 6, H + 14), (40, 40, 40))
                im.paste(Image.fromarray(A[min(ia, m - 1)].astype(np.uint8)), (0, 14))
                im.paste(Image.fromarray(B[min(t, len(B) - 1)].astype(np.uint8)), (W + 6, 14))
                dd = ImageDraw.Draw(im)
                dd.text((2, 1), f"AmiMSX (as shown)  MSX frame {ia}", fill=(255, 255, 0))
                dd.text((W + 8, 1), "openMSX", fill=(255, 255, 0))
                rt.append(im)
                left -= 1
                if left == 0 and ia + 1 < len(holds):
                    ia += 1
                    left = holds[ia]
            rt[0].save(os.path.join(a.dir, "real_time.gif"), save_all=True, append_images=rt[1:],
                       duration=int(1000 / a.fps), loop=0)
    print(f"{rep}; motion_steps.png; side_by_side.gif")


if __name__ == "__main__":
    main()
