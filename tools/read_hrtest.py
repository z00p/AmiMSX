"""Read the S#2 HR/VR timing cartridge (tools/make_hrtest.py).

Input: RAM 8000h-F0FFh as saved by tools/omsx_hrtest.tcl (openMSX), or an
AmiMSX STATEDUMP perf.bin (page 3 is found by its marker "HRT3").
All times are Z80 cycles on the run's one time base; phases are those times
mod 228 (one line). The FH event of a frame lies between the last two reads of
its poll; the intersection over all frames gives its phase.
Usage: python tools/read_hrtest.py hrtest.json <file> [--skip 200] [--lines]"""
import json, sys

LINE = 228


def load(path):
    d = open(path, "rb").read()
    if len(d) == 0x7100 and d[0x7000:0x7004] == b"HRT3":
        img = d
    else:                                   # AmiMSX dump: page 3 found by its marker
        p3 = d.rfind(b"HRT3")
        assert p3 >= 0, "marker not found"
        img = bytes(0x4000) + d[p3 - 0x3000:p3 + 0x1000]
    assert img[0x7008:0x700E] == b"HRDONE", "run not finished (no HRDONE)"
    return img


def ranges(mask):
    """Allowed phases (bool[228]) as text: circular runs."""
    if all(mask):
        return "any"
    if not any(mask):
        return "none (inconsistent)"
    out, p = [], 0
    while mask[p]:
        p += 1                              # start just after a False
    for k in range(1, LINE + 1):
        q = (p + k) % LINE
        if mask[q] and not mask[(q - 1) % LINE]:
            s = q
        if mask[q] and not mask[(q + 1) % LINE]:
            out.append(f"{s}" if s == q else f"{s}-{q}")
    return ", ".join(out)


def window(ts, vals):
    """Phase bins of a bit: its circular run of 1s (start, length), mixed bins."""
    ones, zeros = [0] * LINE, [0] * LINE
    for t, v in zip(ts, vals):
        (ones if v else zeros)[t % LINE] += 1
    mixed = sum(1 for p in range(LINE) if ones[p] and zeros[p])
    empty = sum(1 for p in range(LINE) if not ones[p] and not zeros[p])
    hi = [ones[p] > zeros[p] for p in range(LINE)]
    starts = [p for p in range(LINE) if hi[p] and not hi[p - 1]]
    runs = []
    for s in starts:
        n = 0
        while hi[(s + n) % LINE] and n < LINE:
            n += 1
        runs.append((s, n))
    return runs, mixed, empty


def period_fit(ts, vals):
    best = None
    for per in range(224, 233):
        ones, zeros = {}, {}
        for t, v in zip(ts, vals):
            (ones if v else zeros)[t % per] = (ones if v else zeros).get(t % per, 0) + 1
        mixed = sum(1 for p in ones if p in zeros)
        if best is None or mixed < best[1]:
            best = (per, mixed)
    return best


def main():
    meta = json.load(open(sys.argv[1]))
    img = load(sys.argv[2])
    skip = int(sys.argv[sys.argv.index("--skip") + 1]) if "--skip" in sys.argv else 200
    base, tend, last_falls, last_rises = 0, None, [], []
    res = {"hr": {}, "fh": {}, "vr": {}}
    for b in meta["blocks"]:
        if b["type"] == "rebase":
            base = tend
            continue
        if b["type"] == "samples":
            off = b["addr"] - 0x8000
            s2 = img[off:off + b["n"]]
            ts = [base + b["first"] + i * b["stride"] for i in range(b["n"])]
            hr = [(v >> 5) & 1 for v in s2]
            vr = [(v >> 6) & 1 for v in s2]
            per, pm = period_fit(ts[skip:], hr[skip:])
            runs, mixed, empty = window(ts[skip:], hr[skip:])
            print(f"== {b['name']}  ({b['n']} samples, t {ts[0]}..{ts[-1]})")
            print(f"   HR period fit {per} cycles ({pm} mixed bins); with 228: "
                  + ", ".join(f"HR=1 from phase {s} for {n} cycles" for s, n in runs)
                  + f"  [{mixed} mixed, {empty} empty bins]")
            for vv, tag in ((1, "VR=1 (vblank)"), (0, "VR=0 (display)")):
                sel = [(t, h) for t, h, v in zip(ts[skip:], hr[skip:], vr[skip:]) if v == vv]
                if sel:
                    r2, m2, _ = window([x[0] for x in sel], [x[1] for x in sel])
                    print(f"   {tag}: " + ", ".join(f"from {s} for {n}" for s, n in r2) + f" [{m2} mixed]")
            # VR runs (whole ones only) and edge phases
            edges, i = [], 1
            for i in range(1, len(vr)):
                if vr[i] != vr[i - 1]:
                    edges.append((i, vr[i]))
            fall, rise = [True] * LINE, [True] * LINE
            for i, v in edges:
                if i < skip:
                    continue
                m = fall if v == 0 else rise
                a, c = ts[i - 1], ts[i]
                ok = [False] * LINE
                for x in range(a + 1, c + 1):
                    ok[x % LINE] = True
                for p in range(LINE):
                    m[p] = m[p] and ok[p]
            lens = []
            for (i0, v0), (i1, v1) in zip(edges, edges[1:]):
                if i0 >= skip:
                    lens.append((v0, (i1 - i0) * b["stride"]))
            for v in (0, 1):
                ls = sorted({x for vv, x in lens if vv == v})
                if ls:
                    print(f"   VR={v} runs: {', '.join(str(x) for x in ls)} cycles "
                          f"(= {ls[0] / LINE:.2f}..{ls[-1] / LINE:.2f} lines)")
            print(f"   VR 1->0 phase: {ranges(fall)};  VR 0->1 phase: {ranges(rise)}")
            res["hr"][b["name"]] = runs
            res["vr"][b["name"]] = (ranges(fall), ranges(rise), lens)
            last_falls = [(ts[i - 1], ts[i]) for i, v in edges if v == 0 and i >= skip]
            last_rises = [(ts[i - 1], ts[i]) for i, v in edges if v == 1 and i >= skip]
            tend = ts[-1] + b["stride"]
        elif b["type"] == "fhpoll":
            off = b["addr"] - 0x8000
            nv, step = b.get("vr", 0), 2 + b.get("vr", 0)
            cnt = [img[off + step * f + nv] | img[off + step * f + nv + 1] << 8 for f in range(b["frames"])]
            s2f = [img[off + step * f:off + step * f + nv] for f in range(b["frames"])]
            rds = []
            fs = base + b["t"] + b["pre"]
            mask, evs = [True] * LINE, []
            for f, c in enumerate(cnt):
                rd = lambda k: fs + 18 + (k - 1) * b["poll"]
                if f > 0 and c > 1:                 # frame 0 may start with a pending FH
                    a, e = rd(c - 1), rd(c)
                    evs.append((a, e))
                    rds.append((a, e, f))
                    ok = [False] * LINE
                    for x in range(a + 1, e + 1):
                        ok[x % LINE] = True
                    mask = [m and o for m, o in zip(mask, ok)]
                fs = fs + 11 + c * b["poll"] - 5 + b.get("extra", 0) + 30 + (14 if f < len(cnt) - 1 else 9)
            tend = fs
            per = sorted({evs[i + 1][1] - evs[i][1] for i in range(len(evs) - 1)})
            fl = "F" if b.get("bit") == 7 else "FH"
            print(f"== {b['name']}  (counts {cnt[1]}..{max(cnt[1:])}; {fl} every {per[0]}..{per[-1]} cycles)")
            print(f"   {fl} phase: {ranges(mask)}")
            res["fh"][b["name"]] = (ranges(mask), evs)
            frame = round(per[len(per) // 2] / LINE) * LINE
            ph = [p for p in range(LINE) if mask[p]]
            if nv and len(ph) != 1:             # no time base (AmiMSX ends a line on an idle S#0 poll)
                seqs = sorted({" ".join(f"{v:02X}" for v in s2f[f]) for _, _, f in rds})
                print(f"   S#2 after F, reads 65 + 27j cycles after the IN that saw F: " + " | ".join(seqs))
            if nv and len(ph) == 1:             # S#2 after F: VR and HR against the F event
                pts = []
                for a, e, f in rds:
                    tf = next(x for x in range(a + 1, e + 1) if x % LINE == ph[0])
                    for j, v in enumerate(s2f[f]):
                        pts.append((e + 65 + 27 * j - tf, (v >> 6) & 1, (v >> 5) & 1))
                pts.sort()
                v0 = [d for d, v, h in pts if v == 0]
                v1 = [d for d, v, h in pts if v == 1]
                h1 = [d for d, v, h in pts if h == 1]
                print(f"   S#2 after F (read - F, {len(pts)} reads, {pts[0][0]}..{pts[-1][0]} cycles): "
                      f"VR=0 up to {max(v0) if v0 else '-'}, VR=1 from {min(v1) if v1 else '-'}"
                      f" (VR=0 at {sorted(set(v0))[:3]}..{sorted(set(v0))[-3:]}) ; HR=1 at "
                      f"{ranges([any(d % LINE == q for d in h1) for q in range(LINE)]) if h1 else 'none'} (mod a line)")
            for name, ed in (("1->0", last_falls), ("0->1", last_rises)):
                if not ed or (nv and len(ph) != 1):  # the event against the last segment's VR edges
                    continue
                fa, fc = ed[0]
                lo, hi = 0, frame
                for a, e in evs:
                    d0 = (a + 1 - fc) % frame
                    lo, hi = max(lo, d0), min(hi, d0 + (e - a - 1) + (fc - fa - 1))
                sg = lambda x: x - frame if x > frame // 2 else x
                print(f"   {fl} after the VR {name} edge: {lo}..{hi} cycles = line {lo // LINE} + {lo % LINE}"
                      f"..line {hi // LINE} + {hi % LINE} ({frame // LINE}-line frame; signed {sg(lo)}..{sg(hi)})")
    print(f"(end of run at t={tend})")
    if "--json" in sys.argv:
        json.dump(res, open(sys.argv[sys.argv.index("--json") + 1], "w"))


main()
