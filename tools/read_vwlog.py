"""Print the VDP register write log (VWLOG debug builds) from perf.bin.

Usage: python tools/read_vwlog.py build/perf/<rom>_<tag>.bin [--from F] [--to F] [--regs 0,1,25]

Each entry: MSX frame (KeyFrN, low word), display line (CurLine), register,
value, Z80 PC (after the OUT). The ring holds 16384 entries; older ones are
overwritten (the count says how many there were). --collapse prints a run of
frames with the same writes once, with the frame range.
"""
import argparse, struct

ap = argparse.ArgumentParser()
ap.add_argument("perf")
ap.add_argument("--from", dest="f0", type=int, default=0)
ap.add_argument("--to", dest="f1", type=int, default=1 << 30)
ap.add_argument("--regs", default="")
ap.add_argument("--collapse", action="store_true")
a = ap.parse_args()

d = open(a.perf, "rb").read()
i = d.rfind(b"VWLG")
if i < 0:
    raise SystemExit("no VWLG block (not a VWLOG build?)")
n = struct.unpack(">I", d[i + 4:i + 8])[0]
cap = 16384
ring = d[i + 8:i + 8 + 8 * cap]
ents = [struct.unpack(">HHBBH", ring[k * 8:k * 8 + 8]) for k in range(min(n, cap))]
if n > cap:
    s = n % cap
    ents = ents[s:] + ents[:s]
regs = {int(x) for x in a.regs.split(",") if x} if a.regs else None
print(f"{n} writes logged" + (f" (last {cap} kept)" if n > cap else ""))
rows = [e for e in ents if a.f0 <= e[0] <= a.f1 and (regs is None or e[2] in regs)]
if not a.collapse:
    for f, line, r, v, pc in rows:
        print(f"f{f:5d} line {line:3d}  R{r}={v:02X}  pc={pc:04X}")
else:
    frames = {}
    for f, line, r, v, pc in rows:
        frames.setdefault(f, []).append((line, r, v, pc))
    prev, start, last = None, None, None
    def out(start, last, prev):
        w = "  ".join(f"l{l} R{r}={v:02X}@{pc:04X}" for l, r, v, pc in prev)
        print(f"f{start:5d}-{last:5d}  {w}")
    for f in sorted(frames):
        if frames[f] == prev and f == last + 1:
            last = f
            continue
        if prev is not None:
            out(start, last, prev)
        prev, start, last = frames[f], f, f
    if prev is not None:
        out(start, last, prev)
