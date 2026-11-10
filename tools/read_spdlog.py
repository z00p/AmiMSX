"""Decode the speed log (perf.bin) from a speed-log build:
vasm -DPERF=1 -DPERFPROG=n -DPERFWIN=50 -DPERFRECS=1024 (one record per 50 MSX frames;
PROGDIR:perf_A.bin for n=1, perf_B.bin for n=2...). Only the first return to the menu
after the program starts writes the log.

Usage: python tools/read_spdlog.py perf.bin [more.bin ...] [--recs 1024] [--timeline]

Speed is MSX frames run per Amiga PAL frame, as %: 100% is full speed (50 fps),
70% means the game ran at 35 fps for that second. Load is the work per MSX frame
(core + other + render, without the wait) as % of one Amiga frame: over 100% is
where the slowdown comes from. Records are in play order (oldest first)."""
import argparse, struct

CC_FRAME = 313 * 227          # colour clocks per PAL frame


def read(path, nrec):
    d = open(path, "rb").read()
    assert d[:4] == b"APRF", path
    count, ptr, ticks = struct.unpack(">III", d[4:16])
    ring = d[24:24 + nrec * 64]
    recs = [struct.unpack(">16I", ring[i:i + 64]) for i in range(0, nrec * 64, 64)]
    n = min(count, nrec)
    if count > nrec:
        k = count % nrec
        recs = recs[k:] + recs[:k]
    return count, recs[:n]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="+")
    ap.add_argument("--recs", type=int, default=1024)
    ap.add_argument("--timeline", action="store_true")
    a = ap.parse_args()
    for f in a.files:
        count, recs = read(f, a.recs)
        sp, ld = [], []
        for r in recs:
            el, fr, core, wait, other, rend = r[:6]
            if not el or not fr:
                continue
            sp.append(min(100.0, 100.0 * fr * CC_FRAME / el))
            ld.append(100.0 * (core + other + rend) / fr / CC_FRAME)
        print(f"{f}: {count} records{' (ring wrapped: oldest lost)' if count > a.recs else ''}, "
              f"{len(sp)} usable")
        if not sp:
            continue
        s = sorted(sp)
        slow = [x for x in sp if x < 95]
        print(f"  speed: median {s[len(s) // 2]:.0f}%, worst {s[0]:.0f}%, "
              f"10th pct {s[len(s) // 10]:.0f}%, mean {sum(sp) / len(sp):.1f}%")
        print(f"  windows under 95%: {len(slow)} of {len(sp)}; under 80%: {sum(x < 80 for x in sp)}")
        print(f"  load: median {sorted(ld)[len(ld) // 2]:.0f}%")
        if a.timeline:
            for i in range(0, len(sp), 20):
                print("  " + " ".join(f"{x:3.0f}" for x in sp[i:i + 20]))


if __name__ == "__main__":
    main()
