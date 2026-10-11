"""MSX-Music (YM2413 / OPLL) model for AmiMSX's wavetable FM ("option 2" in
Docs/sound_fm_moonsound.md), written the way the 68k code will do it, so it
doubles as the spec and the reference for the Amiga routines.

How it works:
- Each instrument is turned into K one-cycle tables (256 signed bytes), one per
  modulator level: the carrier's steady-state output, computed with the chip's
  own log-sine / exp method at 256 points a cycle (feedback included).
- Envelopes run once a video frame (50 or 60 Hz), with per-rate step tables
  taken from the chip's envelope rules.
- A voice plays its table at the note's pitch; its volume (carrier envelope +
  volume register + key scaling) picks one of 64 gain steps (0.75 dB).
- Nine voices are summed into one output stream.
Not modelled (yet): AM/PM LFOs (tremolo/vibrato), rhythm mode, the modulator's
envelope inside a cycle.

The built-in instrument data and the log-sine/exp tables follow emu2413 by
Mitsutaka Okazaki (MIT licence, https://github.com/digital-sound-antiques/emu2413).

Usage:
  python tools/fm_synth.py render <regs.txt> <out.wav> [--rate 11025] [--fps 50]
      regs.txt: lines "frame reg value [time]" (hex reg/value), as logged from openMSX;
      with a time column, writes are placed by emulated time
  python tools/fm_synth.py tables <out.bin>     built-in tables for the 68k
  python tools/fm_synth.py demo <out.wav>       a scale on each built-in instrument
"""
import argparse, math, struct, sys, wave
from math import gcd

FS = 3579545 / 72            # chip sample rate, 49716 Hz

# --- emu2413 built-in YM2413 instruments (1-15; 0 is the user instrument) ---
PATCHES = [
    [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00],  # 0: User
    [0x71, 0x61, 0x1e, 0x17, 0xd0, 0x78, 0x00, 0x17],  # 1: Violin
    [0x13, 0x41, 0x1a, 0x0d, 0xd8, 0xf7, 0x23, 0x13],  # 2: Guitar
    [0x13, 0x01, 0x99, 0x00, 0xf2, 0xc4, 0x21, 0x23],  # 3: Piano
    [0x11, 0x61, 0x0e, 0x07, 0x8d, 0x64, 0x70, 0x27],  # 4: Flute
    [0x32, 0x21, 0x1e, 0x06, 0xe1, 0x76, 0x01, 0x28],  # 5: Clarinet
    [0x31, 0x22, 0x16, 0x05, 0xe0, 0x71, 0x00, 0x18],  # 6: Oboe
    [0x21, 0x61, 0x1d, 0x07, 0x82, 0x81, 0x11, 0x07],  # 7: Trumpet
    [0x33, 0x21, 0x2d, 0x13, 0xb0, 0x70, 0x00, 0x07],  # 8: Organ
    [0x61, 0x61, 0x1b, 0x06, 0x64, 0x65, 0x10, 0x17],  # 9: Horn
    [0x41, 0x61, 0x0b, 0x18, 0x85, 0xf0, 0x81, 0x07],  # A: Synthesizer
    [0x33, 0x01, 0x83, 0x11, 0xea, 0xef, 0x10, 0x04],  # B: Harpsichord
    [0x17, 0xc1, 0x24, 0x07, 0xf8, 0xf8, 0x22, 0x12],  # C: Vibraphone
    [0x61, 0x50, 0x0c, 0x05, 0xd2, 0xf5, 0x40, 0x42],  # D: Synth bass
    [0x01, 0x01, 0x55, 0x03, 0xe9, 0x90, 0x03, 0x02],  # E: Acoustic bass
    [0x41, 0x41, 0x89, 0x03, 0xf1, 0xe4, 0xc0, 0x13],  # F: Electric guitar
]
NAMES = ["User", "Violin", "Guitar", "Piano", "Flute", "Clarinet", "Oboe", "Trumpet",
         "Organ", "Horn", "Synthesizer", "Harpsichord", "Vibraphone", "Synth bass",
         "Acoustic bass", "Electric guitar"]

ML = [1, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 20, 24, 24, 30, 30]   # x2
KL_DB2 = [0, 18, 24, 27.75, 30, 32.25, 33.75, 35.25, 36, 37.5, 38.25, 39, 39.75, 40.5, 41.25, 42]
EG_STEP_TABLES = [[0, 1, 0, 1, 0, 1, 0, 1], [0, 1, 0, 1, 1, 1, 0, 1],
                  [0, 1, 1, 1, 0, 1, 1, 1], [0, 1, 1, 1, 1, 1, 1, 1]]

# log-sine (first quarter) and exp tables, as in the chip
LOGSIN = [round(-math.log2(math.sin((x + 0.5) * math.pi / 256 / 2)) * 256) for x in range(256)]
EXP = [round((2 ** (x / 256) - 1) * 1024) for x in range(256)]

TABLEN = 256
# modulator attenuation (0.375 dB units, on top of the patch's TL) for each table
MOD_LEVELS = [0, 4, 8, 12, 18, 26, 40, 127]
VOLSTEPS = 64                 # gain steps of 0.75 dB
PASSES = 3                    # table build: 2 cycles settle the feedback, the 3rd is kept
# Paula output locked to the PAL frame (313 lines x 227 colour clocks): 227
# samples a frame at period 313 (11,332 Hz), or 313 at period 227 (15,625 Hz)
PAULA_CLOCK = 3546895
MODES = {227: 313, 313: 227}          # samples per frame: Paula period
XO_OLD = [3, 8, 16, 63]               # cross-fade: gain index offsets per quarter
XO_NEW = [16, 8, 3, 0]                # (old table fades out, new fades in)
# 8-bit output: CLIP[(mix >> 4) + CLIPC] = mix / 64, with a soft knee above 96
CLIPC = 1152


def _clip(y):
    v = y / 4
    if abs(v) > 96:
        v = math.copysign(96 + 31 * math.tanh((abs(v) - 96) / 31), v)
    return max(-128, min(127, round(v)))


CLIP = [_clip(y - CLIPC) for y in range(2 * CLIPC)]


def decode(d):
    def slot(i):
        return dict(AM=d[i] >> 7 & 1, PM=d[i] >> 6 & 1, EG=d[i] >> 5 & 1, KR=d[i] >> 4 & 1,
                    ML=d[i] & 15, KL=d[2 + i] >> 6 & 3,
                    AR=d[4 + i] >> 4, DR=d[4 + i] & 15, SL=d[6 + i] >> 4, RR=d[6 + i] & 15)
    m, c = slot(0), slot(1)
    m["TL"], c["TL"] = d[2] & 63, 0
    m["FB"], c["FB"] = d[3] & 7, 0
    m["WS"], c["WS"] = d[3] >> 3 & 1, d[3] >> 4 & 1
    return m, c


def lookup_exp(i):
    t = EXP[(i & 0xff) ^ 0xff] + 1024
    res = t >> ((i & 0x7f00) >> 8)
    return (~res if i & 0x8000 else res) << 1


def wave_log(ph, ws):
    ph &= 1023
    q, idx = ph >> 8, ph & 255
    if q & 1:
        idx = 255 - idx
    h = LOGSIN[idx]
    if q >= 2:
        h = 0xfff if ws else (h | 0x8000)
    return h


def op(ph, att, ws):
    """One operator sample: phase 0..1023, attenuation in 0.375 dB units."""
    if att >= 124:
        return 0
    return lookup_exp(wave_log(ph, ws) + (min(127, att) << 4))


def make_tables(dump):
    """K tables of TABLEN signed bytes, and g: the table cycle is g/2 of the
    base note frequency (g = gcd of the two multipliers, x2)."""
    m, c = decode(dump)
    mm, mc = ML[m["ML"]], ML[c["ML"]]
    g = gcd(mm, mc)
    sm, sc = 1024 * (mm // g) // TABLEN, 1024 * (mc // g) // TABLEN
    tabs = []
    for lv in MOD_LEVELS:
        att_m = m["TL"] * 2 + lv
        o0 = o1 = 0
        out = []
        for n in range(TABLEN * PASSES):
            k = n % TABLEN
            fm = (o0 + o1) >> (9 - m["FB"]) if m["FB"] else 0
            mo = op(k * sm + fm, att_m, m["WS"])
            o1, o0 = o0, mo
            co = op(k * sc + 2 * (mo >> 1), 0, c["WS"])
            if n >= TABLEN * (PASSES - 1):
                out.append(max(-127, min(127, co >> 5)))
        tabs.append(out)
    return tabs, g


# --- envelopes, once a frame ---
ATTACK, DECAY, SUSTAIN, RELEASE, OFF = range(5)


def decay_inc(rh, rl, spf):
    """Average envelope increase per frame (x256) at rate rh/rl."""
    if rh == 0:
        return 0
    if rh >= 15:
        per = 2.0
    elif rh == 14:
        per = sum(EG_STEP_TABLES[rl][i] for i in (0, 2, 4, 6)) / 4 + 1
    elif rh == 13:
        per = sum(EG_STEP_TABLES[rl]) / 8
    else:
        per = sum(EG_STEP_TABLES[rl]) / 8 / (1 << (13 - rh))
    return round(per * spf * 256)


def attack_curve(rh, rl, spf, maxf=600):
    """Envelope level (0..127) at each frame of an attack from 124."""
    if rh >= 15:
        return [0]
    if rh == 0:
        return [255]                      # 255: hold (attack rate 0)
    shift = 13 - rh if rh < 12 else 0
    mask = (1 << shift) - 1
    eg, cnt, curve, acc = 124, 0, [], 0.0
    while eg > 0 and len(curve) < maxf:
        acc += spf
        while acc >= 1 and eg > 0:
            acc -= 1
            cnt = (cnt + 1) & 0xffff
            if (cnt & mask & ~3) == 0:
                if rh == 12:
                    s = 4 - EG_STEP_TABLES[rl][(cnt & 0xc) >> 1]
                elif rh == 13:
                    s = 3 - EG_STEP_TABLES[rl][(cnt & 0xc) >> 1]
                elif rh == 14:
                    s = 2 - EG_STEP_TABLES[rl][(cnt & 0xc) >> 1]
                else:
                    s = 4 if EG_STEP_TABLES[rl][(cnt >> shift) & 7] else 0
                if s > 0:
                    eg = max(0, eg - (eg >> s) - 1)
        curve.append(eg)
    if curve[-1]:
        curve.append(0)
    return curve


def tables_static():
    """The 68k's static tables (also written to Sound/fmx.dat)."""
    spf = FS / 50
    t = {}
    t["gain"] = [round(256 * 2 ** (-(2 * v) / 16)) for v in range(VOLSTEPS)]
    t["gain"][VOLSTEPS - 1] = 0
    t["dec"] = [min(32512, decay_inc(rh, rl, spf)) for rh in range(16) for rl in range(4)]   # (one frame to silence)
    t["att"] = [attack_curve(rh, rl, spf) for rh in range(16) for rl in range(4)]
    t["modlv"] = [min(range(len(MOD_LEVELS)), key=lambda i: abs(MOD_LEVELS[i] - m)) for m in range(128)]
    t["ksl"] = []
    for kl in (1, 2, 3):
        for blk in range(8):
            for f4 in range(16):
                tmp = int(KL_DB2[f4] - 6 * (7 - blk))
                t["ksl"].append(0 if tmp <= 0 else int((tmp >> (3 - kl)) / 0.375))
    return t


def step_k(period):
    """Phase step = ((fnum << block) * g * K) >> 4, in table entries x 65536 per sample."""
    return round(period * FS / (16 * PAULA_CLOCK) * 256 * 16)


class Slot:
    def __init__(s):
        s.state, s.eg, s.pos = OFF, 127 * 256, 0


class Synth:
    """Integer model of the 68k FMX engine, step for step."""

    def __init__(s, n_frame=227):
        s.n = n_frame
        s.period = MODES[n_frame]
        s.rate = PAULA_CLOCK / s.period
        s.K = step_k(s.period)
        t = tables_static()
        s.gain, s.dec, s.att, s.modlv, s.kslt = t["gain"], t["dec"], t["att"], t["modlv"], t["ksl"]
        s.voltab = [[(((u ^ 0x80) - 0x80) * g) >> 4 for u in range(256)] for g in s.gain]
        s.regs = [0] * 64
        s.keyev = [0] * 9
        s.pdirty = True
        s.tabs = {i: make_tables(PATCHES[i]) for i in range(1, 16)}
        s.ch = [dict(car=Slot(), mod=Slot(), modkey=0, prevkey=0, frac=0, idx=0, gi=63, tab=None)
                for _ in range(9)]

    def write(s, r, v):
        """OUT 7Dh: the register table, plus key-on edges and patch changes."""
        r &= 0x3f
        if r < 8:
            s.pdirty = True
        elif 0x20 <= r <= 0x28 and v & 0x10 and not s.regs[r] & 0x10:
            s.keyev[r - 0x20] = 1
        s.regs[r] = v

    def rix(s, n, sl, r):
        if r == 0:
            return 0
        fn = s.regs[0x10 + n] | (s.regs[0x20 + n] & 1) << 8
        blk = s.regs[0x20 + n] >> 1 & 7
        bf = blk << 1 | fn >> 8
        rks = bf if sl["KR"] else bf >> 2
        return min(15, r + (rks >> 2)) * 4 + (rks & 3)

    def env(s, n, e, sl):
        if e.state == OFF:
            return
        if e.state == ATTACK:
            cur = s.att[s.rix(n, sl, sl["AR"])]
            e.pos += 1
            v = cur[e.pos - 1]
            if v == 255:
                e.pos -= 1
            elif v == 0:
                e.eg, e.state = 0, DECAY
            else:
                e.eg = v << 8
            return
        if e.state == DECAY:
            r = sl["DR"]
        elif e.state == SUSTAIN:
            r = 0 if sl["EG"] else sl["RR"]
        else:
            r = 5 if s.regs[0x20 + n] & 0x20 else (sl["RR"] if sl["EG"] else 7)
        e.eg = min(127 * 256, e.eg + s.dec[s.rix(n, sl, r)])
        if e.state == DECAY and (e.eg >> 11) >= sl["SL"]:
            e.state = SUSTAIN
        if e.state == RELEASE and e.eg >= 127 * 256:
            e.state = OFF

    def ksl(s, n, sl):
        if not sl["KL"]:
            return 0
        fn = s.regs[0x10 + n] | (s.regs[0x20 + n] & 1) << 8
        blk = s.regs[0x20 + n] >> 1 & 7
        return s.kslt[(sl["KL"] - 1) * 128 + blk * 16 + (fn >> 5)]

    def frame(s):
        """One MSX frame: the 16-bit mix (before the 8-bit output step)."""
        if s.pdirty:
            s.tabs[0] = make_tables(s.regs[0:8])
            s.pdirty = False
        mix = [0] * s.n
        for n, c in enumerate(s.ch):
            key = s.regs[0x20 + n] & 0x10
            if s.keyev[n]:
                for e in (c["car"], c["mod"]):
                    e.state, e.eg, e.pos = ATTACK, 124 * 256, 0
                c["modkey"], c["frac"], c["idx"] = 1, 0, 0
                c["prevkey"] = 1
                s.keyev[n] = 0
            if c["prevkey"] and not key:
                c["car"].state = RELEASE
                c["modkey"] = 0
            c["prevkey"] = key
            inst = s.regs[0x30 + n] >> 4
            m, cr = decode(PATCHES[inst] if inst else s.regs[0:8])
            if c["modkey"]:
                s.env(n, c["mod"], m)
            s.env(n, c["car"], cr)
            g0 = c["gi"]
            vol = s.regs[0x30 + n] & 15
            if c["car"].state == OFF:
                g1 = 63
            else:
                g1 = min(63, ((c["car"].eg >> 8) + vol * 8 + s.ksl(n, cr)) >> 1)
            c["gi"] = g1
            if g0 == 63 and g1 == 63:
                continue
            k = s.modlv[min(127, (c["mod"].eg >> 8) + s.ksl(n, m))]
            tabs, g = s.tabs[inst]
            tab = tabs[k]
            old = c["tab"] if c["tab"] is not None else tab
            c["tab"] = tab
            fn = s.regs[0x10 + n] | (s.regs[0x20 + n] & 1) << 8
            blk = s.regs[0x20 + n] >> 1 & 7
            step = ((fn << blk) * g * s.K) >> 4
            si, sf = (step >> 16) & 255, step & 0xffff
            parts = [(tab, [min(63, g0 + ((g1 - g0) * (q + 1) >> 2)) for q in range(4)])]
            if old is not tab:
                gq = parts[0][1]
                parts = [(old, [min(63, gq[q] + XO_OLD[q]) for q in range(4)]),
                         (tab, [min(63, gq[q] + XO_NEW[q]) for q in range(4)])]
            for t, gq in parts:
                frac, idx, i = c["frac"], c["idx"], 0
                for q in range(4):
                    vt = s.voltab[gq[q]]
                    for _ in range(s.n * (q + 1) // 4 - s.n * q // 4):
                        frac += sf
                        idx = (idx + si + (frac >> 16)) & 255
                        frac &= 0xffff
                        mix[i] += vt[t[idx] & 255]
                        i += 1
            c["frac"], c["idx"] = frac, idx
        return mix

    @staticmethod
    def out8(mix):
        return [CLIP[(v >> 4) + CLIPC] for v in mix]


def write_wav(path, rate, samples):
    w = wave.open(path, "wb")
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(rate)
    w.writeframes(struct.pack("<%dh" % len(samples), *samples))
    w.close()


def frames8(syn, k=1):
    out = []
    for _ in range(k):
        out += [v << 8 for v in syn.out8(syn.frame())]
    return out


def render(regs_path, out, n_frame=227, fps=50, frames=None):
    log = {}
    last = 0
    for line in open(regs_path):
        p = line.split()
        if len(p) >= 3:
            f = round(float(p[3]) * fps) if len(p) > 3 else int(p[0])   # 4th column: time (s)
            log.setdefault(f, []).append((int(p[1], 16), int(p[2], 16)))
            last = max(last, f)
    syn = Synth(n_frame)
    out_s = []
    for f in range(frames or last + fps * 2):
        for r, v in log.get(f, []):
            syn.write(r, v)
        out_s += frames8(syn)
    write_wav(out, round(syn.rate), out_s)
    print(f"{out}: {len(out_s) / syn.rate:.1f} s at {syn.rate:.0f} Hz (8-bit Paula output)")


def demo(out, n_frame=313):
    syn = Synth(n_frame)
    out_s = []
    notes = [(172, 4), (193, 4), (217, 4), (229, 4), (258, 4), (289, 4), (325, 4), (344, 4)]
    for inst in range(1, 16):
        syn.write(0x30, inst << 4)
        for fn, blk in notes:
            syn.write(0x10, fn & 255)
            syn.write(0x20, 0x10 | blk << 1 | fn >> 8)
            out_s += frames8(syn, 12)
            syn.write(0x20, blk << 1 | fn >> 8)
            out_s += frames8(syn, 3)
        out_s += frames8(syn, 25)
    write_wav(out, round(syn.rate), out_s)
    print(f"{out}: {len(out_s) / syn.rate:.1f} s, instruments 1-15 in order")


def fmxdat(folder):
    """Sound/fmx.dat (the 68k's tables) and Sound/fmx.i (its offsets)."""
    import os
    os.makedirs(folder, exist_ok=True)
    t = tables_static()
    parts = []
    tab = bytearray()
    gs = bytearray(16)
    for i in range(1, 16):
        tabs, g = make_tables(PATCHES[i])
        gs[i] = g
        for x in tabs:
            tab += bytes(v & 255 for v in x)
    parts.append(("TAB", bytes(tab)))
    parts.append(("G", bytes(gs)))
    parts.append(("PATCH", bytes(b for p in PATCHES for b in p)))
    parts.append(("LOGSIN", struct.pack(">256H", *LOGSIN)))
    parts.append(("EXP", struct.pack(">256H", *EXP)))
    parts.append(("DEC", struct.pack(">64H", *t["dec"])))
    parts.append(("GAIN", struct.pack(">64H", *t["gain"])))
    parts.append(("KSL", bytes(t["ksl"])))
    parts.append(("MODLV", bytes(t["modlv"])))
    parts.append(("MODLEVELS", bytes(MOD_LEVELS)))
    curves, offs = bytearray(), []
    for c in t["att"]:
        offs.append(len(curves))
        curves += bytes(c)
    parts.append(("CLIP", bytes(v & 255 for v in CLIP)))
    parts.append(("ATTOFF", struct.pack(">64H", *offs)))
    parts.append(("ATT", bytes(curves)))
    data, inc = bytearray(), []
    for name, b in parts:
        inc.append(f"FMX_{name}=\t{len(data)}\t\t; {len(b)} bytes")
        data += b
        if len(data) & 1:
            data += b"\0"
    inc.append(f"FMX_SIZE=\t{len(data)}")
    inc.append(f"FMX_K227=\t{step_k(313)}\t\t; phase step factor, 227 samples/frame (period 313)")
    inc.append(f"FMX_K313=\t{step_k(227)}\t\t; 313 samples/frame (period 227)")
    open(os.path.join(folder, "fmx.dat"), "wb").write(data)
    with open(os.path.join(folder, "fmx.i"), "w", newline="\r\n") as fh:
        fh.write("; Generated by tools/fm_synth.py fmxdat: offsets into fmx.dat. Do not edit.\n"
                 "; Built-in YM2413 instrument data from emu2413 (MIT, Mitsutaka Okazaki).\n"
                 + "\n".join(inc) + "\n")
    print(f"{folder}/fmx.dat: {len(data)} bytes; {folder}/fmx.i")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["render", "fmxdat", "demo"])
    ap.add_argument("args", nargs="*")
    ap.add_argument("--n", type=int, default=227, choices=[227, 313],
                    help="samples per frame: 227 (11.3 kHz) or 313 (15.6 kHz)")
    ap.add_argument("--fps", type=int, default=50)
    ap.add_argument("--frames", type=int)
    a = ap.parse_args()
    if a.cmd == "render":
        render(a.args[0], a.args[1], a.n, a.fps, a.frames)
    elif a.cmd == "demo":
        demo(a.args[0], a.n)
    else:
        fmxdat(a.args[0] if a.args else "Sound")


if __name__ == "__main__":
    main()
