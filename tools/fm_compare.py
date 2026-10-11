"""Compare a rendered FM track with a reference recording (e.g. openMSX).

Both are resampled to 22050 Hz and aligned on their loudness envelopes; then,
per 93 ms window:
- chroma: correlation of the 12 pitch-class energies (are the right notes there?)
- loudness: correlation of the RMS envelopes (do notes start and end together?)
- brightness: spectral centroid ratio, render / reference (timbre, roughly)
and a side-by-side spectrogram image.

Usage: python tools/fm_compare.py <reference.wav> <render.wav> [--png out.png] [--start s] [--secs n]
"""
import argparse, wave
import numpy as np
from scipy.signal import resample_poly

SR = 22050
WIN = 2048


def load(path):
    w = wave.open(path)
    a = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(np.float64)
    if w.getnchannels() == 2:
        a = a.reshape(-1, 2).mean(axis=1)
    r = w.getframerate()
    if r != SR:
        from math import gcd
        g = gcd(r, SR)
        a = resample_poly(a, SR // g, r // g)
    return a / 32768


def stft(a):
    n = (len(a) - WIN) // (WIN // 2)
    win = np.hanning(WIN)
    return np.array([np.abs(np.fft.rfft(a[i * WIN // 2: i * WIN // 2 + WIN] * win)) for i in range(n)])


def chroma(S):
    f = np.fft.rfftfreq(WIN, 1 / SR)
    ok = (f > 60) & (f < 5000)
    pc = np.round(12 * np.log2(f[ok] / 440)).astype(int) % 12
    C = np.zeros((S.shape[0], 12))
    for k in range(12):
        C[:, k] = (S[:, ok][:, pc == k] ** 2).sum(axis=1)
    return C


def rms(a, hop):
    n = len(a) // hop
    return np.sqrt((a[: n * hop].reshape(n, hop) ** 2).mean(axis=1))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("ref")
    ap.add_argument("ren")
    ap.add_argument("--png")
    ap.add_argument("--start", type=float, default=0)
    ap.add_argument("--secs", type=float, default=0)
    a = ap.parse_args()
    ref, ren = load(a.ref), load(a.ren)
    # align: loudness envelopes at 10 ms, search +-1.5 s
    hop = SR // 100
    e1, e2 = rms(ref, hop), rms(ren, hop)
    n = min(len(e1), len(e2)) - 300
    best = max(range(-150, 151), key=lambda d: np.corrcoef(e1[150:150 + n - 150], e2[150 + d:150 + d + n - 150])[0, 1])
    ren = ren[best * hop:] if best > 0 else np.concatenate([np.zeros(-best * hop), ren])
    s0 = int(a.start * SR)
    m = min(len(ref), len(ren))
    if a.secs:
        m = min(m, s0 + int(a.secs * SR))
    ref, ren = ref[s0:m], ren[s0:m]
    S1, S2 = stft(ref), stft(ren)
    loud = S1.sum(axis=1) > np.percentile(S1.sum(axis=1), 20)
    C1, C2 = chroma(S1), chroma(S2)
    cc = [np.corrcoef(C1[i], C2[i])[0, 1] for i in range(len(C1)) if loud[i]]
    f = np.fft.rfftfreq(WIN, 1 / SR)
    cen = lambda S: (S * f).sum(axis=1) / (S.sum(axis=1) + 1e-9)
    ratio = cen(S2)[loud] / cen(S1)[loud]
    r1, r2 = rms(ref, WIN // 2), rms(ren, WIN // 2)
    k = min(len(r1), len(r2))
    print(f"offset {best * 10} ms; windows {loud.sum()}")
    print(f"chroma correlation: median {np.median(cc):.2f}, 10th pct {np.percentile(cc, 10):.2f}")
    print(f"loudness envelope correlation: {np.corrcoef(r1[:k], r2[:k])[0, 1]:.2f}")
    print(f"brightness (centroid) render/ref: median {np.median(ratio):.2f}")
    if a.png:
        from PIL import Image
        def img(S):
            L = 20 * np.log10(S[:, :512].T[::-1] + 1e-6)
            L = np.clip((L - L.max() + 70) / 70, 0, 1)
            return (L * 255).astype(np.uint8)
        i1, i2 = img(S1), img(S2)
        w = min(i1.shape[1], i2.shape[1])
        both = np.vstack([i1[:, :w], np.full((6, w), 255, np.uint8), i2[:, :w]])
        Image.fromarray(both).resize((min(w * 2, 2400), both.shape[0])).save(a.png)
        print(f"{a.png}: top = reference, bottom = render (0-5.5 kHz)")


if __name__ == "__main__":
    main()
