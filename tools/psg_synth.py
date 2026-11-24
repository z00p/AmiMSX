"""Software PSG (YM2149) and the PSG+FM mix: the spec for the 68k code.

The 68k mixer (AmiMSX_Psx_v4.asm, PsxFrame/PsxOut) follows this step for step,
in the same integer arithmetic. Behaviour follows openMSX's AY8910.cc (type
YM2149, as on the reference machine):
- tone: a counter at the tone clock (Z80 clock / 16, 223.7 kHz) counts up to
  the period (0 counts as 1) and flips the output;
- noise: a 17-bit LFSR stepped every 2 * period tone ticks (period 0 = 1);
- envelope: 32 levels of 1.5 dB, a step every period tone ticks, shapes as
  in openMSX (a shape write restarts it);
- each channel is (tone | tone off) & (noise | noise off) times its volume
  (fixed 0-15 at 3 dB a step, or the envelope): a unipolar output, so volume
  writes with both off play samples.
Per output sample (Paula's rate, N a frame) each channel's tone is the
fraction of the sample it was high (a box filter: no aliasing whistle from
high notes), the noise the fraction of its bits that were 1 (the hiss keeps
its real level instead of folding the whole band below Paula's Nyquist), the
envelope its level at the sample. The sum goes through a one-pole high-pass
(about 10 Hz, as the MSX's output capacitor) so DC steps don't click.

Levels are in FM mix units (tools/fm_synth.py: a full FM voice peaks at
+-2032): openMSX mixes the PSG at volume 21000 and MSX-MUSIC at 9000, a
full-volume PSG channel reaching 1.0 where a full FM channel peaks at 0.66.
"""
import math

TICK_FRAME = {313: 313 * 228 / 16, 262: 262 * 228 / 16}   # tone ticks an MSX frame
FM_FULL = 2032                       # our full FM voice peak (mix units)
OMSX_FM_FULL = 21632 / 32768         # openMSX: full FM channel peak
PSG_FULL = round(FM_FULL / OMSX_FM_FULL * 21000 / 9000)   # a channel at level 1.0

# YM2149 levels: 32 steps of 1.5 dB, 0 = silent (openMSX YM2149EnvelopeTab)
ENV = [0] + [round(PSG_FULL * 2 ** (-(31 - i) / 4)) for i in range(1, 32)]
VOL = [0] + [ENV[2 * v + 1] for v in range(1, 16)]

# Noise: openMSX's LFSR from 1; the bit sequence, period 2^17 - 1
NOISE_LEN = (1 << 17) - 1


def _noise_bits():
    r, out = 1, bytearray(NOISE_LEN)
    for i in range(NOISE_LEN):
        out[i] = r & 1
        r = (r >> 1) ^ ((r & 1) << 13) ^ ((r & 1) << 16)
    return out


NOISE = _noise_bits()

# Stereo: each PSG channel's share of the left and right side, in quarters
# (FM stays in the centre, 4/4 each side). Mono is (4, 4) for all.
PAN_STEREO = [(6, 2), (4, 4), (2, 6)]
PAN_MONO = [(4, 4)] * 3

HP_SHIFT = 8                          # high-pass: y += x - x' - y >> 8 (~10 Hz)


class Psg:
    def __init__(s, n, lines=313, pan=PAN_MONO):
        s.n = n
        s.set_t(lines, n)
        s.pan = pan
        s.r = [0] * 16
        s.r[7] = 0xBF
        s.per = [1 << 16] * 3          # tone periods, 16.16
        s.cnt = [0] * 3
        s.out = [0] * 3
        s.npos = 0                    # noise: bit position, 18.14
        s.ndn = (s.T >> 2) // 2       # bits a sample (2 * period ticks a bit)
        s.eper = 1 << 14              # envelope: step period, ticks 18.14
        s.ecnt = 0
        s.estep, s.eatt, s.ehold, s.ealt, s.eheld = 0x1F, 0, True, False, True
        s.xl = s.xr = 0                # high-pass: last input, output (x 256)
        s.yl = s.yr = 0

    def set_t(s, lines, n):
        """Tone ticks a sample (16.16) for an MSX frame of 'lines' lines and n
        samples (the nominal N: pitch stays put while N moves for sync)."""
        s.T = (lines * 228 * 4096) // n
        s.invT = (1 << 32) // s.T
        if hasattr(s, 'r'):
            s.ndn = (s.T >> 2) // (2 * max(1, s.r[6] & 31))

    def load(s, regs):
        """Start from these 14 registers, envelope held (no shape restart)."""
        for i in range(13):
            s.write(i, regs[i])
        s.r[13] = regs[13]

    def write(s, reg, v):
        reg &= 15
        s.r[reg] = v
        if reg < 6:
            c = reg >> 1
            p = s.r[2 * c] + 256 * (s.r[2 * c + 1] & 15)
            s.per[c] = max(1, p) << 16
            s.cnt[c] = min(s.cnt[c], s.per[c] - 1)
        elif reg == 6:
            s.ndn = (s.T >> 2) // (2 * max(1, v & 31))
        elif reg in (11, 12):
            s.eper = max(1, s.r[11] + 256 * s.r[12]) << 14
            s.ecnt = min(s.ecnt, s.eper - 1)
        elif reg == 13:
            s.eatt = 0x1F if v & 4 else 0
            if not v & 8:
                s.ehold, s.ealt = True, s.eatt != 0
            else:
                s.ehold, s.ealt = bool(v & 1), bool(v & 2)
            s.estep, s.eheld = 0x1F, False

    def _env_steps(s, k):
        if s.eheld:
            return
        s.estep -= k
        if s.estep < 0:
            if s.ehold:
                if s.ealt:
                    s.eatt ^= 0x1F
                s.eheld, s.estep = True, 0
            else:
                if s.ealt and (s.estep & 0x10):
                    s.eatt ^= 0x1F
                s.estep &= 0x1F

    def _tone(s, c):
        """Fraction of this sample channel c's tone was high, 0-256."""
        T, P = s.T, s.per[c]
        if P <= T >> 2:                # 4 or more flips a sample: half
            return 128
        rem, hi, cnt, o = T, 0, s.cnt[c], s.out[c]
        while True:
            left = P - cnt
            if rem < left:
                cnt += rem
                if o:
                    hi += rem
                break
            if o:
                hi += left
            rem -= left
            cnt = 0
            o ^= 1
        s.cnt[c], s.out[c] = cnt, o
        return ((hi >> 8) * s.invT) >> 16

    def _noise(s):
        """Fraction of this sample's noise bits that were 1, 0-256."""
        p0 = s.npos >> 14
        s.npos += s.ndn
        p1 = s.npos >> 14
        if p1 >= NOISE_LEN:
            s.npos -= NOISE_LEN << 14
        c = p1 - p0
        if c == 0:
            return NOISE[p0 % NOISE_LEN] << 8
        c = min(c, 32)
        ones = sum(NOISE[(p0 + i) % NOISE_LEN] for i in range(c))
        return (ones << 8) // c

    def sample(s):
        """One output sample: (left, right) in mix units, high-passed."""
        en = s.r[7]
        nf = s._noise() if (en & 0x38) != 0x38 else 256
        ev = ENV[s.estep ^ s.eatt]
        l = r = 0
        for c in range(3):
            tf = 256 if en & (1 << c) else s._tone(c)
            v = s.r[8 + c]
            amp = ev if v & 0x10 else VOL[v & 15]
            if not en & (8 << c):
                tf = (tf * nf) >> 8
            x = (amp * tf) >> 8
            pl, pr = s.pan[c]
            l += x * pl
            r += x * pr
        if not s.eheld:
            s.ecnt += s.T >> 2
            if s.ecnt >= s.eper:
                k = s.ecnt // s.eper
                s.ecnt -= k * s.eper
                s._env_steps(k)
        l >>= 2
        r >>= 2
        s.yl += ((l - s.xl) << 8) - (s.yl >> HP_SHIFT)
        s.yr += ((r - s.xr) << 8) - (s.yr >> HP_SHIFT)
        s.xl, s.xr = l, r
        return s.yl >> 8, s.yr >> 8

    def frame(s, events, n=None):
        """events: [(sample index, reg, value)] in order; n samples (default
        the nominal N). Returns ([L], [R])."""
        L, R, e = [], [], 0
        for i in range(s.n if n is None else n):
            while e < len(events) and events[e][0] <= i:
                s.write(events[e][1], events[e][2])
                e += 1
            a, b = s.sample()
            L.append(a)
            R.append(b)
        while e < len(events):
            s.write(events[e][1], events[e][2])
            e += 1
        return L, R


# 14-bit output: v = mix * gain >> 8, held to -8192..8191 (only the lowest
# gain can reach that). Automatic gain (class Gain), x0.25 to x4 in 1.5 dB
# steps from x1, on the peak of both sides of the frame about to be written:
# down at once as far as that peak needs, by a straight ramp that ends at the
# first sample the old gain couldn't take, so no waveform is bent; up a step
# after 3 s under 6400 at the next gain (1.5 s for each step after it), by a
# ramp over the frame, counting only frames with something playing. (4.7 to
# 5.3: 3 dB steps from the last frame's peak, into a soft knee from 6144,
# which squashed loud notes and drums.)
FULL = 8191
AGC_N, AGC_K0 = 17, 8
AGC_G = [2 ** ((k - AGC_K0) / 4) for k in range(AGC_N)]
AGC_Q8 = [round(256 * g) for g in AGC_G]
AGC_DOWN = [FULL * 256 // q for q in AGC_Q8]        # highest |mix| the gain takes
AGC_UP = [400 * 256 // q for q in AGC_Q8[1:]] + [0]     # |mix| >> 4
AGC_FLOOR, AGC_HOLD, AGC_AGAIN = 8, 150, 75


class Gain:
    def __init__(s):
        s.k, s.count = AGC_K0, 0

    def frame(s, sides):
        """One frame's mix (a list of sides, samples as ints): each side's output."""
        peak = max(max(abs(int(v)) for v in m) for m in sides)
        k = old = s.k
        while k > 0 and peak > AGC_DOWN[k]:
            k -= 1
        n = len(sides[0])
        if k != old:
            s.count = 0
            n = min(next((i for i, v in enumerate(m) if abs(int(v)) > AGC_DOWN[old]), n) for m in sides)
        elif k < AGC_N - 1 and peak >> 4 >= AGC_FLOOR:
            if peak >> 4 < AGC_UP[k]:
                s.count += 1
                if s.count >= AGC_HOLD:
                    k, s.count = k + 1, AGC_AGAIN
            else:
                s.count = 0
        s.k = k
        start, end = AGC_Q8[old] << 8, AGC_Q8[k] << 8
        if k == old or not n:
            n, d = 0, 0
        else:
            d = int((end - start) / n)      # toward zero, as DIVS
        out = []
        for m in sides:
            side = []
            for i, v in enumerate(m):
                g = start + d * i if i < n else end
                side.append(max(-FULL - 1, min(FULL, (int(v) * (g >> 8)) >> 8)))
            out.append(side)
        return out


def write_inc(path):
    """Sound/psx.i: the tables the 68k mixer uses (AmiMSX_Psx_v4.asm)."""
    def dcw(name, vals, per=12):
        out = [f"{name}:"]
        for i in range(0, len(vals), per):
            out.append("\tDC.W\t" + ",".join(str(v) for v in vals[i:i + per]))
        return out
    L = ["; Generated by tools/psg_synth.py (write_inc): do not edit.",
         f"PSX_FULL=\t{FULL}",
         f"PSX_AGCN=\t{AGC_N}", f"PSX_AGCK0=\t{AGC_K0}",
         f"PSX_AGCFLOOR=\t{AGC_FLOOR}", f"PSX_AGCHOLD=\t{AGC_HOLD}",
         f"PSX_AGCAGAIN=\t{AGC_AGAIN}",
         f"PSX_NOISELEN=\t{NOISE_LEN}", f"PSX_HPSHIFT=\t{HP_SHIFT}"]
    L += dcw("PsxEnv", ENV) + dcw("PsxVol", VOL)
    L += dcw("PsxAgcQ8", AGC_Q8) + dcw("PsxAgcDn", AGC_DOWN) + dcw("PsxAgcUp", AGC_UP)
    open(path, "w", newline="\n").write("\n".join(L) + "\n")


if __name__ == "__main__":
    import os
    write_inc(os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "Sound", "psx.i"))
