"""Decode AmiMSX:perf.bin from the speed-counter build (vasm -DPERF=1).
Usage: python tools/read_perf.py build/perf/<rom>.bin [...]

Each record covers 250 emulated MSX frames. Times are shown in PAL beam
lines (313 per Amiga frame = 20 ms). 'load' is the Amiga time the emulator
needs per MSX frame, as % of one Amiga frame: under 100% runs at full speed
(the rest is spent waiting), over 100% runs slower (speed = 100 / load).
v2 files (16-long records) count colour clocks (227 per line) and carry
eight sub-timers (PERFSUB 0-7)."""
import sys, struct

LINES = 313
SUBS = {0: "BITPLASPR", 1: "BITSPRCOL", 2: "CREASPR", 3: "IMPSPR2", 4: "CLEARSPR2",
        5: "S4tiles", 6: "S4full", 7: "S4sprites"}


def read(path):
    d = open(path, "rb").read()
    assert d[:4] == b"APRF", path
    count, ptr, ticks = struct.unpack(">III", d[4:16])
    vmax, scr, intmax, cpu = struct.unpack(">HHHH", d[16:24])
    ring = d[24:]
    v2 = len(ring) >= 16 * 128 * 4
    nl = 16 if v2 else 8
    unit = 227 if v2 else 1
    recs = [struct.unpack(f">{nl}I", ring[i:i + nl * 4]) for i in range(0, nl * 4 * 128, nl * 4)]
    n = min(count, len(recs))
    if count > len(recs):            # wrapped: oldest first
        k = count % len(recs)
        recs = recs[k:] + recs[:k]
    return dict(count=count, ticks=ticks, vmax=vmax, scr=scr, intmax=intmax, v2=v2, unit=unit,
                attn=cpu >> 8, is060=cpu & 0xFF, recs=recs[:n])


def summary(r):
    rows = []
    u = r["unit"]
    for rec in r["recs"]:
        el, fr, core, wait, other, rend, nrend, tk = rec[:8]
        if fr == 0:
            continue
        busy = core + other + rend
        w = dict(frames=fr, elapsed=el / u, core=core / fr / u, wait=wait / fr / u,
                 other=other / fr / u, render=rend / fr / u, renders=nrend,
                 load=100.0 * busy / fr / u / LINES,
                 speed=100.0 * fr * LINES * u / el if el else 0)
        w["subs"] = [x / fr / u for x in rec[8:]] if r["v2"] else []
        rows.append(w)
    return rows


if __name__ == "__main__":
    for path in sys.argv[1:]:
        r = read(path)
        print(f"{path}: {r['count']} windows, AttnFlags {r['attn']:02X}, 060 mode {r['is060']}, "
              f"frame length {r['vmax'] + 1} lines, VBlank int latency up to {r['intmax']} lines"
              + (f", last render ScrModo {r['scr'] >> 8:02X} R#0 {r['scr'] & 0xFF:02X}" if r['v2'] else ""))
        hdr = "  win  speed%  load%   core  render(n)  other   wait"
        if r["v2"]:
            hdr += "  | " + " ".join(f"{SUBS[i]:>9s}" for i in range(8))
        print(hdr + "   (lines per MSX frame)")
        for i, w in enumerate(summary(r)):
            line = (f"  {i:3d}  {w['speed']:6.1f}  {w['load']:5.1f}  {w['core']:5.0f}  "
                    f"{w['render']:5.0f}({w['renders']:3d})  {w['other']:5.0f}  {w['wait']:5.0f}")
            if w["subs"]:
                line += "  | " + " ".join(f"{x:9.1f}" for x in w["subs"][:8])
            print(line)
