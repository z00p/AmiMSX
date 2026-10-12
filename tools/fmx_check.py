"""Check the 68k FMX engine against its spec (tools/fm_synth.py Synth).

Reads perf.bin from a check build (vasm -DPERF=1 -DFMXREC=1 ...), whose tail
holds: the OPLL registers at the start (64 bytes), the write and output
pointers (2 longs), the logged writes (frame.W, register, value; 64 KB) and
the output bytes (1 MB). Replays the writes through the Python model frame by
frame and compares the 8-bit output; writes a WAV of what the Amiga played.

Usage: python tools/fmx_check.py build/perf/<rom>_<tag>.bin [--wav out.wav] [--n 227]
"""
import argparse, os, struct, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fm_synth as fm

WSZ, OSZ = 65536, 1048576


def parse(path):
    d = open(path, "rb").read()
    o = d[-OSZ:]
    w = d[-OSZ - WSZ:-OSZ]
    wp, op = struct.unpack(">II", d[-OSZ - WSZ - 8:-OSZ - WSZ])
    init = d[-OSZ - WSZ - 8 - 64:-OSZ - WSZ - 8]
    return init, w, o, wp, op


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("bin")
    ap.add_argument("--wav")
    ap.add_argument("--n", type=int, default=227)
    ap.add_argument("--voices", type=int, default=9)
    a = ap.parse_args()
    init, w, o, wp, op = parse(a.bin)
    # pointers are absolute; the buffers' sizes in use come from the data:
    # writes end at the first all-zero record after data, output = whole frames
    writes = {}
    nw = 0
    for i in range(0, WSZ, 4):
        f, r, v = struct.unpack(">HBB", w[i:i + 4])
        if f == 0 and r == 0 and v == 0 and i > 0:
            break
        writes.setdefault(f, []).append((r, v))
        nw += 1
    frames = len(o.rstrip(b"\0")) // a.n + 1
    syn = fm.Synth(a.n, a.voices)
    syn.regs = list(init)
    syn.pdirty = True
    bad, first = 0, None
    for f in range(frames):
        for r, v in writes.get(f, []):
            syn.write(r, v)
        exp = [v & 255 for v in syn.out8(syn.frame())]
        got = list(o[f * a.n:(f + 1) * a.n])
        if len(got) < a.n:
            break
        if exp != got:
            bad += 1
            if first is None:
                k = next(i for i in range(a.n) if exp[i] != got[i])
                first = (f, k, exp[k], got[k])
    print(f"{nw} writes, {frames} frames compared; {bad} frames differ"
          + (f"; first: frame {first[0]} sample {first[1]} expected {first[2]} got {first[3]}" if first else ""))
    if a.wav:
        s = [((b ^ 0x80) - 0x80) << 8 for b in o[:frames * a.n]]
        fm.write_wav(a.wav, round(fm.PAULA_CLOCK / fm.MODES[a.n]), s)
        print(f"{a.wav}: what the Amiga played")


if __name__ == "__main__":
    main()
