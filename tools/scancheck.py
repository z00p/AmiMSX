"""Exact check of AmiMSX's RTG scanlines on in-emulator captures (RTGSHOT test builds write
AmiMSX:rtgshot.raw: the RTG screen as the board holds it at each key-script SNAP; see
Docs/agent_notes/v46_scanlines.md).

Each display line y is two rows on the screen: row 2y (the line) and row 2y+1:
  off      the line again
  hardP    the line's 12-bit colours with each nibble x (100 - P) / 100, rounded (RtgDimN),
           through the colour table (RtgCol)
  blendP   h(line y) + h(line y+1) per channel, h(v) = (v x (100 - P) + 100) // 200 in the
           screen's own channel bits (P = 25 light, 50 normal, 75 strong); the last line: h(y) + h(y)
Rows outside the display (the border fill) are the row above again.

Usage: python tools/scancheck.py rtgshot.raw MODE[,MODE...] [--ref other.raw] [--png prefix]
  modes per shot in order, e.g. off,hard25,hard50,hard75,blend25,blend50,blend75,off
  --ref: a capture of the same frames all Off: its rows must equal the lines here.
"""
import argparse, struct, sys
import numpy as np

LEV8 = [0, 17, 34, 36, 68, 73, 102, 109, 136, 146, 170, 182, 204, 219, 238, 255]
MSXNIB = [0, 3, 5, 7, 9, 11, 13, 15]
# P96 RGBFB number: (bytes, little-endian 16-bit, (bits, shift) of R, G, B) as RtgFmtTab
FMT = {4: (2, 1, (5, 11), (6, 5), (5, 0)), 10: (2, 0, (5, 11), (6, 5), (5, 0)),
       5: (2, 1, (5, 10), (5, 5), (5, 0)), 11: (2, 0, (5, 10), (5, 5), (5, 0)),
       12: (2, 1, (5, 0), (6, 5), (5, 11)), 13: (2, 1, (5, 0), (5, 5), (5, 10)),
       6: (4, 0, (8, 16), (8, 8), (8, 0)), 7: (4, 0, (8, 0), (8, 8), (8, 16)),
       8: (4, 0, (8, 24), (8, 16), (8, 8)), 9: (4, 0, (8, 8), (8, 16), (8, 24))}


def gun(n, bits):
    return (LEV8[n] * ((1 << bits) - 1) + 127) // 255


def load(path):
    b = open(path, 'rb').read()
    assert b[:4] == b'RSHT', path
    w, h, bpr, fmt, n = struct.unpack('>HHIII', b[4:20])
    hd = len(b) - n * bpr * h                    # 24 (20 in the first builds: no count)
    slow = struct.unpack('>I', b[20:24])[0] if hd == 24 else 0
    print(f'{path}: {n} shots, {w}x{h}, P96 format {fmt}, {slow} blend rows pixel by pixel (R#18 per line)')
    bpp, le, *ch = FMT[fmt]
    shots = []
    for i in range(n):
        raw = np.frombuffer(b[hd + i * bpr * h: hd + (i + 1) * bpr * h], np.uint8).reshape(h, bpr)
        raw = raw[:, :w * bpp]
        if bpp == 2:
            px = raw.reshape(h, w, 2).astype(np.uint32)
            v = px[:, :, 1] << 8 | px[:, :, 0] if le else px[:, :, 0] << 8 | px[:, :, 1]
        else:
            px = raw.reshape(h, w, 4).astype(np.uint32)
            v = px[:, :, 0] << 24 | px[:, :, 1] << 16 | px[:, :, 2] << 8 | px[:, :, 3]
        nat = np.stack([((v >> s) & ((1 << bt) - 1)).astype(np.int32) for bt, s in ch], axis=2)
        shots.append(nat)
    return shots, [bt for bt, s in ch], fmt, (w, h)


def check(nat, bits, mode):
    p = 0 if mode == 'off' else int(mode[-2:])
    luts = []
    for c in range(3):
        lut = np.full(1 << bits[c], -999, np.int32)
        for n in MSXNIB:
            lut[gun(n, bits[c])] = gun((n * (100 - p) + 50) // 100, bits[c])
        luts.append(lut)

    def scan_of(up, lo):
        if mode == 'off':
            return up
        if mode.startswith('hard'):
            return np.stack([luts[c][up[:, c]] for c in range(3)], axis=1)
        return (up * (100 - p) + 100) // 200 + (lo * (100 - p) + 100) // 200

    H = nat.shape[0]
    best = None
    for ph in (0, 1):
        K = (H - ph - 1) // 2
        rows = [nat[2 * k + ph] for k in range(K + 1)]
        odd = [nat[2 * k + ph + 1] for k in range(K)]
        eq = np.array([np.array_equal(odd[k], rows[k]) for k in range(K)])
        sc = np.array([np.array_equal(odd[k], scan_of(rows[k], rows[k + 1])) for k in range(K)])
        sl = np.array([np.array_equal(odd[k], scan_of(rows[k], rows[k])) for k in range(K)])
        pe = np.concatenate([[0], np.cumsum(eq)])
        ps = np.concatenate([[0], np.cumsum(sc)])
        for ka in range(K):
            for kb in range(ka + 1, K + 1):
                score = pe[ka] + (pe[K] - pe[kb]) + (ps[kb - 1] - ps[ka]) + sl[kb - 1]
                key = (score, kb - ka)
                if best is None or key > best[0]:
                    best = (key, ph, ka, kb, K)
    (score, _), ph, ka, kb, K = best
    bad, badrows = 0, []
    for k in range(K):
        r = 2 * k + ph
        if ka <= k < kb:
            e = scan_of(nat[r], nat[r + 2] if k < kb - 1 else nat[r])
        else:
            e = nat[r]
        d = (nat[r + 1] != e).any(axis=1)
        if d.any():
            bad += int(d.sum()); badrows.append(r + 1)
    return ph, ka, kb, bad, badrows


def expect(off, bits, mode, ph, ka, kb):
    """The screen in `mode` from an Off screen (line rows ph + 2k), lines ka..kb-1."""
    p = 0 if mode == 'off' else int(mode[-2:])
    out = off.copy()
    H = off.shape[0]
    for k in range(ka, kb):
        r = 2 * k + ph
        up = off[r]
        lo = off[r + 2] if k < kb - 1 else off[r]
        if mode == 'off':
            e = up
        elif mode.startswith('hard'):
            e = np.zeros_like(up)
            for c in range(3):
                lut = np.full(1 << bits[c], -999, np.int32)
                for n in MSXNIB:
                    lut[gun(n, bits[c])] = gun((n * (100 - p) + 50) // 100, bits[c])
                e[:, c] = lut[up[:, c]]
        else:
            e = (up * (100 - p) + 100) // 200 + (lo * (100 - p) + 100) // 200
        if r + 1 < H:
            out[r + 1] = e
    return out


def to8(nat, bits):
    return np.stack([(nat[:, :, c] * 255 + ((1 << bits[c]) - 1) // 2) // ((1 << bits[c]) - 1)
                     for c in range(3)], axis=2).astype(np.uint8)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('raw')
    ap.add_argument('modes')
    ap.add_argument('--ref')
    ap.add_argument('--png')
    a = ap.parse_args()
    shots, bits, fmt, (w, h) = load(a.raw)
    modes = a.modes.split(',')
    ref = load(a.ref)[0] if a.ref else None
    total = 0
    for i, nat in enumerate(shots):
        m = modes[i] if i < len(modes) else 'off'
        ph, ka, kb, bad, badrows = check(nat, bits, m)
        total += bad
        msg = (f'  shot {i}: {m:8s} lines at rows {2 * ka + ph}-{2 * kb + ph - 1} ({kb - ka} lines), '
               f'{bad} bad pixels' + (f' rows {badrows[:8]}' if badrows else ''))
        if ref is not None and i < len(ref):
            # The whole screen computed from the Off capture of the same frame (its line rows),
            # by the definition, against this capture.
            exp = expect(ref[i], bits, m, ph, ka, kb)
            dl = int((exp != nat).any(axis=2).sum())
            total += dl
            msg += f'; from the Off capture: {dl} pixels differ'
        print(msg)
        if a.png:
            from PIL import Image
            Image.fromarray(to8(nat, bits)).save(f'{a.png}_{i}_{m}.png')
    print(f'TOTAL bad pixels: {total}')
    return total


if __name__ == '__main__':
    sys.exit(1 if main() else 0)
