"""Hardware-test report from a PERF build's perf.bin (4.4: Bombaman, Lotus F3).

Usage: python tools/read_hw.py <perf.bin> [--last N]

From the dump's tail (AmiMSX_Menu PerfDump):
- speed: the 250-frame windows (as tools/read_perf.py);
- display rhythm (DispLog): Amiga frames each MSX frame stayed on screen;
  1 = smooth, a 2 is a late frame (the one before was shown twice);
- where frames ended (DispLine, beam line);
- (4.4 builds, "SPRL" block) the sprite pass: how many Amiga frames before
  the frame's end it finished (SprTick against DispTick) and at which beam
  line. The frame's end comes after the wait for the next Amiga frame, so 1
  is the usual value; a steady game has one value, and a mix of 0 and 1 means the overlay
  switch lands one Amiga frame late in some frames and not others (moving
  sprites then read as doubled: Bombaman's ghosting theory).
Only the last N frames (default: all in the 4096-frame ring) are counted."""
import argparse, os, struct, sys
from collections import Counter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import read_perf  # noqa: E402

SPRL = 4 + 3 * 4096
# from the end of the base dump: AclN/AclLate, DbCommits, DispLine, DispLog, DispN
BASE_TAIL = [("acl", 8), ("dbcommits", 16), ("displine", 4096), ("displog", 4096), ("dispn", 4)]


def tail(d):
    out, end = {}, len(d)
    if d[end - SPRL:end - SPRL + 4] == b"SPRL":
        b = d[end - SPRL + 4:end]
        out["disptick"], out["sprtick"], out["sprline"] = b[:4096], b[4096:8192], b[8192:]
        end -= SPRL
    for name, n in BASE_TAIL:
        out[name] = d[end - n:end]
        end -= n
    return out


def ring(b, n, last):
    """Ring bytes oldest first: the n frames logged, at most the last 'last'."""
    k = min(n, 4096, last or 4096)
    return [b[(n - k + i) % 4096] for i in range(k)]


def hist(c, fmt=str):
    tot = sum(c.values()) or 1
    key = lambda kv: int(str(kv[0]).split("-")[0])
    return ", ".join(f"{fmt(k)}: {v} ({100 * v / tot:.0f}%)" for k, v in sorted(c.items(), key=key))


def bucket(line2):
    lo = line2 * 2 // 32 * 32
    return f"{lo}-{lo + 31}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("perf")
    ap.add_argument("--last", type=int, default=0, help="only the last N MSX frames")
    a = ap.parse_args()
    d = open(a.perf, "rb").read()
    r = read_perf.read(a.perf)
    print(f"{a.perf}: AttnFlags {r['attn']:02X}, 060 mode {r['is060']}, frame length {r['vmax'] + 1} lines")
    print("speed (250-frame windows, % of full speed / Amiga load %):")
    ws = read_perf.summary(r)
    print("  " + "  ".join(f"{w['speed']:.0f}/{w['load']:.0f}" for w in ws))
    t = tail(d)
    n = struct.unpack(">I", t["dispn"])[0]
    commits, = struct.unpack(">I", t["dbcommits"][:4])
    acl, late = struct.unpack(">II", t["acl"])
    hold = ring(t["displog"], n, a.last)
    print(f"MSX frames logged {n}, counted {len(hold)}; Smooth display commits {commits}; "
          f"copper list rebuilds {acl}, {late} begun inside the display")
    c = Counter(min(h, 4) for h in hold)
    print("display rhythm (Amiga frames per MSX frame, 4 = 4+): " + hist(c))
    runs, cur = Counter(), 0
    for h in hold:
        if h >= 2:
            runs[cur] += 1
            cur = 0
        else:
            cur += 1
    if runs:
        gaps = sorted(runs.elements())
        print(f"  late frames: {sum(runs.values())}, smooth frames between them: "
              f"median {gaps[len(gaps) // 2]}, shortest {gaps[0]}")
    print("frame end, beam line: " + hist(Counter(bucket(x) for x in ring(t["displine"], n, a.last))))
    if "sprtick" in t:
        dt, st, sl = (ring(t[k], n, a.last) for k in ("disptick", "sprtick", "sprline"))
        lag = Counter()
        for i in range(len(dt)):
            lag[(dt[i] - st[i]) & 255] += 1
        stale = sum(v for k, v in lag.items() if k > 8)
        lag = Counter({k: v for k, v in lag.items() if k <= 8})
        print("sprite pass, Amiga frames before the frame's end: " + hist(lag)
              + (f"; {stale} frames without a sprite pass (sprites off, or another path)" if stale else ""))
        print("sprite pass end, beam line: " + hist(Counter(bucket(sl[i]) for i in range(len(sl))
                                                           if ((dt[i] - st[i]) & 255) <= 8)))
        seq = "".join(str(min((dt[i] - st[i]) & 255, 9)) for i in range(max(0, len(dt) - 120), len(dt)))
        print(f"  last {len(seq)} frames (lag, 9 = none): {seq}")
    else:
        print("(no sprite-pass log: not a 4.4 hardware-test build)")


if __name__ == "__main__":
    main()
