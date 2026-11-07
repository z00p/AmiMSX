"""Smooth Display timing from LAGLOG logs (4.7, Docs/agent_notes/lag-4.7.md):
VBlanks from the input read to the commit of the frame that answers it (the
picture is on screen from the next VBlank).

Pass n samples the input (vs); the Z80 then emulates the frame that uses it,
drawn in pass n+1. Late order (NO_EARLYDB): drawn after pass n+1's wait,
committed at pass n+2's entry (ve). Early order: drawn and committed at pass
n+1's entry, before its wait and before LagSample n+1 (vr, in record n).

Usage: python tools/lagshown.py --early build/perf/a.bin --late build/perf/b.bin
       (on hardware logs, records in order: KeyFrN is 0 there)
"""
import argparse, collections, os, struct, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lagtest import read_lag, vdiff


def recs(path):
    f, _ = read_lag(path)
    if len(f) > 1:
        return [f[k] for k in sorted(f)]
    # Hardware log: KeyFrN is 0 in every record, so read them in order.
    d = open(path, "rb").read()
    i = d.rfind(b"LAGL")
    if i < 0:
        i = len(d) - (12 + 20 * 4096 + 12 * 64)
    n, _ = struct.unpack(">II", d[i + 4:i + 12])
    out = []
    for k in range(min(n, 4096)):
        _, ve, le, vs, ls, vr, lr = struct.unpack(">I6H", d[i + 12 + 16 * k:i + 28 + 16 * k])
        out.append(dict(ve=ve, le=le, vs=vs, ls=ls, vr=vr, lr=lr))
    return out


def shown(path, early):
    r = recs(path)
    out = []
    for n in range(len(r) - 2):
        vs = r[n]["vs"]
        if early:
            if r[n]["vr"] == 0xFFFF:     # (rendered at pass n+1's entry,
                continue                 # before LagSample n+1: record n)
            c = r[n]["vr"]
        else:
            c = r[n + 2]["ve"]
        out.append(vdiff(vs, c) + 1)
    return out


def report(name, xs):
    if not xs:
        print(name, "no frames")
        return
    xs = sorted(xs)
    h = collections.Counter(xs)
    print(f"{name}: {len(xs)} frames, median {xs[len(xs) // 2]}, p95 {xs[int(len(xs) * .95)]}, "
          f"VBlanks read->shown: " + ", ".join(f"{k}:{h[k]}" for k in sorted(h)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--early", nargs="*", default=[])
    ap.add_argument("--late", nargs="*", default=[])
    a = ap.parse_args()
    for p in a.late:
        report("late  " + os.path.basename(p), shown(p, False))
    for p in a.early:
        report("early " + os.path.basename(p), shown(p, True))


if __name__ == "__main__":
    main()
