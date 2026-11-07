"""The whole PSG+FM mix against openMSX: balance, loudness and the gain.

Renders FM (tools/fm_synth.py) and PSG (tools/psg_synth.py) from an
snd_capture write log the way the 68k does (FM registers once a frame, PSG
writes at their sample), mixes them in FM mix units, and compares with
openMSX's full mix (<prefix>_mix.wav). Also runs the automatic gain on the
mix and reports what it did: time at each gain, and how far it pulled the
music down while sound effects played (the PSG's share of the peak).

Writes <prefix>_ours_mono.wav / _ours_stereo.wav (14-bit, as Paula plays it)
for listening.

Usage: python tools/mix_compare.py <capture prefix> [--start 15] [--from s] [--secs s]
"""
import argparse, wave
import numpy as np
import fm_synth as fm
import psg_synth as ps
from psg_compare import load, FRAME, metrics, fmt
from math import gcd
from scipy.signal import resample_poly


def logs(prefix):
    F, P = {}, {}
    for l in open(prefix + "_writes.txt"):
        k, t, r, v = l.split()
        x = float(t) / FRAME
        f = int(x)
        (F if k == "F" else P).setdefault(f, []).append((x - f, int(r), int(v)))
    return F, P


def render(prefix, n, f0, f1, pan):
    F, P = logs(prefix)
    syn, psg = fm.Synth(n), ps.Psg(n, pan=pan)
    fmo, pl, pr = [], [], []
    for f in range(f1):
        for _, r, v in F.get(f, []):
            syn.write(r, v)
        e = [(int(x * n), r, v) for x, r, v in P.get(f, [])]
        if f < f0:
            for _, r, v in e:
                psg.write(r, v)
            syn.frame()
            continue
        fmo += syn.frame()
        a, b = psg.frame(e)
        pl += a
        pr += b
    return np.array(fmo), np.array(pl), np.array(pr)


def agc(L, R, n):
    """The automatic gain once a frame on the peak of both sides (mix >> 4
    units, as FMXAgc), applied the next frame; 14-bit out with the knee."""
    k, cnt, ks = ps.AGC_K0, 0, []
    oL, oR = np.zeros(len(L)), np.zeros(len(R))
    for i in range(0, len(L) - n + 1, n):
        g = ps.AGC_Q8[k]
        a = (L[i:i + n] * g) >> 8
        b = (R[i:i + n] * g) >> 8
        oL[i:i + n] = [ps.knee(int(v)) for v in a]
        oR[i:i + n] = [ps.knee(int(v)) for v in b]
        ks.append(k)
        p = int(max(np.abs(L[i:i + n]).max(), np.abs(R[i:i + n]).max())) >> 4
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
    return oL, oR, np.array(ks)


def save(path, L, R, fs):
    w = wave.open(path, "wb")
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(round(fs))
    w.writeframes(np.stack([L * 4, R * 4], 1).astype("<i2").tobytes())
    w.close()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("prefix")
    ap.add_argument("--n", type=int, default=313)
    ap.add_argument("--start", type=float, default=15)
    ap.add_argument("--from", dest="t0", type=float, default=5)
    ap.add_argument("--secs", type=float, default=40)
    a = ap.parse_args()
    n, fs = a.n, a.n / FRAME
    f0 = int((a.start + a.t0) / FRAME)
    f1 = f0 + int(a.secs / FRAME)
    fmo, pl, _ = render(a.prefix, n, f0, f1, ps.PAN_MONO)
    mix = fmo + pl
    ref, rr = load(a.prefix + "_mix.wav")
    i0 = int((f0 * FRAME - a.start) * rr)
    seg = ref[i0:i0 + int((f1 - f0) * FRAME * rr)]
    up, dn = round(fs * 10), rr * 10
    g = gcd(up, dn)
    R = resample_poly(seg, up // g, dn // g)
    k = min(len(R), len(mix))
    # level: openMSX mix units per our mix unit, from the best fit of each part
    X = np.stack([fmo[:k], pl[:k]], 1).astype(float)
    print("openMSX vs ours, mono:", fmt(metrics(R[:k], mix[:k] * np.sqrt((R[:k] ** 2).mean() / (mix[:k] ** 2).mean()), fs)))
    print(f"rms: FM {np.sqrt((fmo ** 2).mean()):.0f}  PSG {np.sqrt((pl ** 2).mean()):.0f}  mix {np.sqrt((mix ** 2).mean()):.0f}"
          f"  peak mix {np.abs(mix).max()} (mix units; 8128 = full scale at gain x1)")
    # what the PSG alone and the FM alone would have the gain do
    for name, L in (("mix", mix), ("FM only", fmo)):
        _, _, ks = agc(L, L, n)
        t = np.bincount(ks, minlength=ps.AGC_N) / len(ks)
        ch = (np.diff(ks) != 0).sum() / (len(ks) * FRAME / 60)
        print(f"gain with {name:8s}: " + "  ".join(f"x{ps.AGC_G[i]:.2f} {100 * t[i]:4.1f}%" for i in range(ps.AGC_N) if t[i])
              + f"   changes/min {ch:.1f}")
    _, _, kmix = agc(mix, mix, n)
    _, _, kfm = agc(fmo, fmo, n)
    d = kfm - kmix
    print(f"frames where the PSG pulled the music down: {100 * (d > 0).mean():.1f}%"
          f" (by 3 dB {100 * (d == 1).mean():.1f}%, 6 dB+ {100 * (d >= 2).mean():.1f}%)")
    oL, oR, _ = agc(mix, mix, n)
    save(a.prefix + "_ours_mono.wav", oL, oR, fs)
    _, sl, sr = render(a.prefix, n, f0, f1, ps.PAN_STEREO)
    oL, oR, _ = agc(fmo + sl, fmo + sr, n)
    save(a.prefix + "_ours_stereo.wav", oL, oR, fs)


if __name__ == "__main__":
    main()
