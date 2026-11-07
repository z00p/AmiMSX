"""Check the software PSG (tools/psg_synth.py) against openMSX.

Renders each PSG channel alone from an snd_capture write log and compares it
with openMSX's own recording of that channel, band-limited to the same rate
(the best any N-samples-a-frame output can do). Prints, per channel, the
error of the model against that reference (SNR, dB) and the same for plain
point sampling (no box filter) to show what the filter buys.

Usage: python tools/psg_compare.py <capture prefix> [--n 313] [--from s] [--secs s]
"""
import argparse, wave
import numpy as np
from math import gcd
from scipy.signal import resample_poly
import psg_synth as ps

Z80 = 3579545
FRAME = 313 * 228 / Z80               # seconds an MSX (PAL) frame


def load(path):
    w = wave.open(path)
    return np.frombuffer(w.readframes(w.getnframes()), "<i2").astype(np.float64), w.getframerate()


def events(prefix, n):
    ev = {}
    for l in open(prefix + "_writes.txt"):
        k, t, r, v = l.split()
        if k != "P":
            continue
        x = float(t) / FRAME
        f = int(x)
        ev.setdefault(f, []).append((int((x - f) * n), int(r), int(v)))
    return ev


def render(ev, n, f0, f1, only=None, point=False):
    p = ps.Psg(n)
    if point:
        p._tone = lambda c, p=p: _point_tone(p, c)
        p._noise = lambda p=p: _point_noise(p)
    out = []
    for f in range(f1):
        e = ev.get(f, [])
        if only is not None:          # the other channels silent
            e = [(i, r, 0 if 8 <= r <= 10 and r != 8 + only else v) for i, r, v in e]
        if f < f0:                    # registers only, up to the stretch
            for _, r, v in e:
                p.write(r, v)
            continue
        L, _ = p.frame(e)
        out += L
    return np.array(out, np.float64)


def _point_tone(p, c):
    cnt = p.cnt[c] + p.T
    flips = cnt // p.per[c]
    p.cnt[c] = cnt - flips * p.per[c]
    p.out[c] ^= flips & 1
    return 256 * p.out[c]


def _point_noise(p):
    p.npos += p.ndn
    if p.npos >> 14 >= ps.NOISE_LEN:
        p.npos -= ps.NOISE_LEN << 14
    return ps.NOISE[p.npos >> 14] << 8


def hp(x, fs):
    k = int(fs / 20)
    return x - np.convolve(x, np.ones(k) / k, "same")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("prefix")
    ap.add_argument("--n", type=int, default=313)
    ap.add_argument("--from", dest="t0", type=float, default=20)
    ap.add_argument("--secs", type=float, default=20)
    ap.add_argument("--start", type=float, default=None,
                    help="capture start time (snd_capture --from), default 15")
    a = ap.parse_args()
    start = a.start if a.start is not None else 15.0
    n = a.n
    fs = n / FRAME
    ev = events(a.prefix, n)
    f0 = int((start + a.t0) / FRAME)
    f1 = f0 + int(a.secs / FRAME)
    for c in range(3):
        ref, rr = load(f"{a.prefix}-PSG-ch{c + 1}_0001.wav")
        # openMSX channel files: 0..32767 at level 1.0, recorded from 'start'
        i0 = int((f0 * FRAME - start) * rr)
        seg = ref[i0:i0 + int((f1 - f0) * FRAME * rr) + rr]
        up, dn = round(fs * 10), round(rr * 10)
        g = gcd(up, dn)
        ideal = resample_poly(seg, up // g, dn // g) * ps.PSG_FULL / 32767
        m = render(ev, n, f0, f1, only=c)
        pt = render(ev, n, f0, f1, only=c, point=True)
        k = min(len(m), len(ideal))
        I, M, P = hp(ideal[:k], fs), hp(m[:k], fs), hp(pt[:k], fs)
        if (I ** 2).mean() < 1:
            print(f"ch{c + 1}: silent in this stretch")
            continue
        print(f"ch{c + 1}: model   " + fmt(metrics(I, M, fs)))
        print(f"     point   " + fmt(metrics(I, P, fs)))


W = 1024


def stft(x):
    h = np.hanning(W)
    n = (len(x) - W) // (W // 2)
    return np.array([np.abs(np.fft.rfft(x[i * W // 2:i * W // 2 + W] * h)) for i in range(n)])


def metrics(I, M, fs):
    """Phase-blind: loudness envelope correlation (after a +-100 ms lag
    search), level ratio, mean log-spectral distance where the reference has
    energy, and the energy the render adds over the reference (aliasing,
    wrong notes) relative to the reference energy."""
    h = 160
    eI = np.sqrt((I[:len(I) // h * h].reshape(-1, h) ** 2).mean(1))
    eM = np.sqrt((M[:len(M) // h * h].reshape(-1, h) ** 2).mean(1))
    lags = range(-10, 11)
    cs = [np.corrcoef(eI[20:-20], np.roll(eM, l)[20:-20])[0, 1] for l in lags]
    lag = lags[int(np.argmax(cs))]
    M = np.roll(M, lag * h)
    A, B = stft(I), stft(M)
    on = A.sum(1) > A.sum(1).max() * 0.01
    f = np.fft.rfftfreq(W, 1 / fs)
    band = f < 7000
    dA, dB = 20 * np.log10(A[on][:, band] + 30), 20 * np.log10(B[on][:, band] + 30)
    extra = np.clip(B[on] - A[on], 0, None)
    return dict(env=max(cs), level=np.sqrt((M ** 2).mean() / (I ** 2).mean()),
                specdist=np.abs(dA - dB).mean(),
                extra_dB=10 * np.log10((extra ** 2).sum() / (A[on] ** 2).sum() + 1e-12))


def fmt(m):
    return (f"env {m['env']:.3f}  level {m['level']:.2f}  spectral dist {m['specdist']:5.2f} dB"
            f"  added energy {m['extra_dB']:6.1f} dB")


if __name__ == "__main__":
    main()
