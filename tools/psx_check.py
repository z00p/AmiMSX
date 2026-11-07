"""Check the 68k sound mix (AmiMSX_Psx_v4.asm) against tools/psg_synth.py.

Reads the perf.bin of a check build (-DPERF -DFMXREC -DPSXREC): the PSG
registers at the start, every PSG write as the mixer applied it (frame,
sample, register, value) and, each frame, N then for each side the FM, PSG
and output words of every sample. Replays the writes through Psg and
checks, frame by frame:
- the PSG samples, bit for bit;
- the output: knee((FM + PSG) * gain >> 8), with the gain from the
  automatic gain run on the recorded FM + PSG.

The PSG's pitch follows the nominal N (FMXNnom), which the recording
doesn't hold: by default each N seen is tried on the first 300 frames with
sound and the best kept (Lilly's Saga on the 030: 226 while N ran 226-228).

Usage: python tools/psx_check.py <perf.bin> [--stereo] [--nnom N] [--lines 313]
"""
import argparse, struct
import numpy as np
import psg_synth as ps

E_SIZE, O_SIZE = 262144, 4194304


def parse(path, stereo):
    b = open(path, "rb").read()
    base = len(b) - (24 + E_SIZE + O_SIZE)
    init = list(b[base:base + 14])
    E = b[base + 24:base + 24 + E_SIZE]
    O = b[base + 24 + E_SIZE:]
    ev = [struct.unpack(">HHBBH", E[i:i + 8]) for i in range(0, E_SIZE, 8)]
    while ev and ev[-1] == (0, 0, 0, 0, 0):
        ev.pop()
    frames, i, sides = [], 0, 2 if stereo else 1
    while True:
        fr = []
        for _ in range(sides):
            if i + 2 > len(O):
                break
            n = struct.unpack(">H", O[i:i + 2])[0]
            i += 2
            if n == 0 or i + 6 * n > len(O):
                break
            w = np.frombuffer(O[i:i + 6 * n], ">i2").reshape(n, 3).astype(np.int64)
            i += 6 * n
            fr.append(w)
        if len(fr) < sides:
            break
        frames.append(fr)
    if i > len(O) - 1024 - 2048 and frames:   # the recording ran out in this one
        frames.pop()
    return init, ev, frames


def agc_gains(frames):
    k, cnt, ks = ps.AGC_K0, 0, []
    for fr in frames:
        ks.append(k)
        p = max(int(np.abs(s[:, 0] + s[:, 1]).max()) for s in fr) >> 4
        kk = k
        while kk > 0 and p > ps.AGC_DOWN[kk]:
            kk -= 1
        if kk != k:
            k, cnt = kk, 0
        elif k < ps.AGC_N - 1 and p >= ps.AGC_FLOOR:
            if p < ps.AGC_UP[k]:
                cnt += 1
                if cnt >= ps.AGC_HOLD:
                    k, cnt = k + 1, 0
            else:
                cnt = 0
    return ks


def pick_nnom(init, byf, frames, a):
    ns = sorted(set(fr[0].shape[0] for fr in frames))
    on = [f for f, fr in enumerate(frames) if fr[0][:, 1].any()]
    if len(ns) == 1 or not on:
        return ns[0]
    f1 = min(len(frames), on[0] + 300)
    best = None
    for nn in ns:
        p = ps.Psg(nn, lines=a.lines, pan=ps.PAN_STEREO if a.stereo else ps.PAN_MONO)
        p.load(init)
        bad = 0
        for f in range(f1):
            L, R = p.frame(byf.get(f, []), frames[f][0].shape[0])
            bad += sum(int((s[:, 1] != np.array(w)).sum()) for s, w in zip(frames[f], (L, R)))
        if best is None or bad < best[0]:
            best = (bad, nn)
    return best[1]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("perf")
    ap.add_argument("--stereo", action="store_true")
    ap.add_argument("--nnom", type=int, default=0)
    ap.add_argument("--lines", type=int, default=313)
    ap.add_argument("--show", type=int, default=5)
    a = ap.parse_args()
    init, ev, frames = parse(a.perf, a.stereo)
    ns = [fr[0].shape[0] for fr in frames]
    byf = {}
    for f, idx, r, v, _ in ev:
        byf.setdefault(f, []).append((idx, r, v))
    nnom = a.nnom or pick_nnom(init, byf, frames, a)
    print(f"{len(frames)} frames, {len(ev)} PSG writes, N {min(ns)}-{max(ns)} (nominal {nnom}),"
          f" registers at the start {' '.join(f'{v:02X}' for v in init)}")
    p = ps.Psg(nnom, lines=a.lines, pan=ps.PAN_STEREO if a.stereo else ps.PAN_MONO)
    p.load(init)
    ks = agc_gains(frames)
    bad_p = bad_o = shown = 0
    first_p = first_o = None
    for f, fr in enumerate(frames):
        n = fr[0].shape[0]
        L, R = p.frame(byf.get(f, []), n)
        g = ps.AGC_Q8[ks[f]]
        for side, want in zip(fr, (L, R)):
            dp = np.nonzero(side[:, 1] != np.array(want))[0]
            if len(dp):
                bad_p += 1
                if first_p is None:
                    first_p = f
                if shown < a.show:
                    j = dp[0]
                    print(f"frame {f}: PSG differs at sample {j} of {n}: 68k {side[j, 1]} model {want[j]}"
                          f" ({len(dp)} samples; writes {byf.get(f, [])[:6]})")
                    shown += 1
            mix = side[:, 0] + side[:, 1]
            out = np.array([ps.knee(int(v)) for v in (mix * g) >> 8])
            do = np.nonzero(side[:, 2] != out)[0]
            if len(do):
                bad_o += 1
                if first_o is None:
                    first_o = f
                if shown < a.show:
                    j = do[0]
                    print(f"frame {f}: output differs at sample {j}: 68k {side[j, 2]} model {out[j]}"
                          f" (FM {side[j, 0]} PSG {side[j, 1]} gain {g})")
                    shown += 1
    t = np.bincount(ks, minlength=ps.AGC_N)
    print(f"PSG: {bad_p} of {len(frames)} frames differ (first {first_p});"
          f" output: {bad_o} differ (first {first_o})")
    print("gain: " + "  ".join(f"x{ps.AGC_G[i]:.2f} {100 * t[i] / len(ks):.1f}%" for i in range(ps.AGC_N) if t[i]))
    allp = np.concatenate([fr[0][:, 1] for fr in frames])
    allf = np.concatenate([fr[0][:, 0] for fr in frames])
    print(f"rms FM {np.sqrt((allf ** 2).mean()):.0f}  PSG {np.sqrt((allp ** 2).mean()):.0f}"
          f"  peak out {max(int(np.abs(fr[0][:, 2]).max()) for fr in frames)}")


if __name__ == "__main__":
    main()
