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
        for n in range(TABLEN * 6):
            k = n % TABLEN
            fm = (o0 + o1) >> (9 - m["FB"]) if m["FB"] else 0
            mo = op(k * sm + fm, att_m, m["WS"])
            o1, o0 = o0, mo
            co = op(k * sc + 2 * (mo >> 1), 0, c["WS"])
            if n >= TABLEN * 5:
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
        return [124] * 2
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
    return curve


class Env:
    def __init__(s):
        s.state, s.eg, s.pos = OFF, 127 * 256, 0


class Synth:
    def __init__(s, rate=11025, fps=50, ramp=4):
        s.rate, s.fps, s.ramp = rate, fps, ramp
        s.spf = FS / fps
        s.dec = [[decay_inc(rh, rl, s.spf) for rl in range(4)] for rh in range(16)]
        s.att = [[attack_curve(rh, rl, s.spf) for rl in range(4)] for rh in range(16)]
        s.regs = [0] * 64
        s.user = [0] * 8
        s.tabs = {i: make_tables(PATCHES[i]) for i in range(1, 16)}
        s.tabs[0] = make_tables(s.user)
        s.ch = [dict(car=Env(), mod=Env(), ph=0, key=0) for _ in range(9)]
        s.gain = [round(256 * 2 ** (-(2 * v) / 16)) for v in range(VOLSTEPS)]
        s.gain[VOLSTEPS - 1] = 0

    # register write (applied at the frame it was logged in)
    def write(s, r, v):
        if r < 8:
            s.user[r] = v
            s.tabs[0] = make_tables(s.user)      # the 68k rebuilds on patch change
            return
        old = s.regs[r]
        s.regs[r] = v
        if 0x20 <= r <= 0x28:
            c = s.ch[r - 0x20]
            if (v & 0x10) and not (old & 0x10):
                s.key_on(c)
            elif not (v & 0x10) and (old & 0x10):
                c["car"].state = RELEASE
                c["mod"].key = 0
            c["key"] = v & 0x10

    def patch(s, n):
        inst = s.regs[0x30 + n] >> 4
        return inst, decode(PATCHES[inst] if inst else s.user)

    def key_on(s, c):
        for e in (c["car"], c["mod"]):
            e.state, e.eg, e.pos = ATTACK, 124 * 256, 0
        c["mod"].key = 1
        c["ph"] = 0

    def rates(s, n, sl, r):
        """Effective rate (rh, rl) with key scaling."""
        fn = s.regs[0x10 + n] | (s.regs[0x20 + n] & 1) << 8
        blk = s.regs[0x20 + n] >> 1 & 7
        bf = blk << 1 | fn >> 8
        rks = bf if sl["KR"] else bf >> 2
        if r == 0:
            return 0, 0
        return min(15, r + (rks >> 2)), rks & 3

    def step_env(s, n, e, sl, is_car):
        if e.state == OFF:
            return
        if not is_car and not getattr(e, "key", 1):
            return                                   # modulator holds after key off
        if e.state == ATTACK:
            rh, rl = s.rates(n, sl, sl["AR"])
            cur = s.att[rh][rl]
            e.pos += 1
            e.eg = cur[min(e.pos, len(cur)) - 1] * 256 if e.pos <= len(cur) else 0
            if e.eg == 0:
                e.state = DECAY
            return
        if e.state == DECAY:
            r = sl["DR"]
        elif e.state == SUSTAIN:
            r = 0 if sl["EG"] else sl["RR"]
        else:
            sus = s.regs[0x20 + n] & 0x20
            r = 5 if sus else (sl["RR"] if sl["EG"] else 7)
        rh, rl = s.rates(n, sl, r)
        e.eg = min(127 * 256, e.eg + s.dec[rh][rl])
        if e.state == DECAY and (e.eg >> 11) >= sl["SL"]:
            e.state = SUSTAIN
        if e.state == RELEASE and e.eg >= 127 * 256:
            e.state = OFF

    def ksl(s, n, sl):
        if sl["KL"] == 0:
            return 0
        fn = s.regs[0x10 + n] | (s.regs[0x20 + n] & 1) << 8
        blk = s.regs[0x20 + n] >> 1 & 7
        tmp = int(KL_DB2[fn >> 5] - 6 * (7 - blk))
        return 0 if tmp <= 0 else int((tmp >> (3 - sl["KL"])) / 0.375)

    def frame(s):
        """Run the envelopes, then return this frame's samples."""
        s.acc = getattr(s, "acc", 0) + s.rate
        n_out, s.acc = divmod(s.acc, s.fps)
        mix = [0] * n_out
        for n, c in enumerate(s.ch):
            inst, (m, cr) = s.patch(n)
            s.step_env(n, c["mod"], m, False)
            s.step_env(n, c["car"], cr, True)
            g0 = c.get("g", 0)
            vol = s.regs[0x30 + n] & 15
            att = (c["car"].eg >> 8) + vol * 8 + s.ksl(n, cr)
            g = 0 if c["car"].state == OFF else s.gain[min(VOLSTEPS - 1, att >> 1)]
            c["g"] = g
            if not g and not g0:
                continue
            matt = (c["mod"].eg >> 8) + s.ksl(n, m)
            k = min(range(len(MOD_LEVELS)), key=lambda i: abs(MOD_LEVELS[i] - matt))
            tabs, gg = s.tabs[inst]
            tab = tabs[k]
            # a new modulator level cross-fades in over the frame (in RAMP steps),
            # since a sudden change of waveform clicks
            old_tab = c.get("tab", tab)
            c["tab"] = tab
            fn = s.regs[0x10 + n] | (s.regs[0x20 + n] & 1) << 8
            blk = s.regs[0x20 + n] >> 1 & 7
            f = FS * fn * (1 << blk) / (1 << 19) * gg / 2
            step = int(f / s.rate * (1 << 32)) & 0xffffffff
            ph = c["ph"]
            xf = old_tab is not tab
            rs = s.ramp or 1
            for i in range(n_out):
                # gain moves from last frame's value to this one's in RAMP steps
                gi = g if not s.ramp else g0 + (g - g0) * min(s.ramp, i * s.ramp // n_out + 1) // s.ramp
                if xf:
                    w = min(rs, i * rs // n_out + 1)
                    mix[i] += (old_tab[ph >> 24] * (rs - w) + tab[ph >> 24] * w) * gi // rs
                else:
                    mix[i] += tab[ph >> 24] * gi
                ph = (ph + step) & 0xffffffff
            c["ph"] = ph
        return [max(-32768, min(32767, v >> 3)) for v in mix]


def write_wav(path, rate, samples):
    w = wave.open(path, "wb")
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(rate)
    w.writeframes(struct.pack("<%dh" % len(samples), *samples))
    w.close()


def render(regs_path, out, rate, fps, frames=None):
    log = {}
    last = 0
    for line in open(regs_path):
        p = line.split()
        if len(p) >= 3:
            f = round(float(p[3]) * fps) if len(p) > 3 else int(p[0])   # 4th column: time (s)
            log.setdefault(f, []).append((int(p[1], 16), int(p[2], 16)))
            last = max(last, f)
    syn = Synth(rate, fps)
    out_s = []
    for f in range(frames or last + fps * 2):
        for r, v in log.get(f, []):
            syn.write(r, v)
        out_s += syn.frame()
    write_wav(out, rate, out_s)
    print(f"{out}: {len(out_s) / rate:.1f} s")


def demo(out, rate=22050, fps=50):
    syn = Synth(rate, fps)
    out_s = []
    notes = [(172, 4), (193, 4), (217, 4), (229, 4), (258, 4), (289, 4), (325, 4), (344, 4)]
    for inst in range(1, 16):
        syn.write(0x30, inst << 4)
        for fn, blk in notes:
            syn.write(0x10, fn & 255)
            syn.write(0x20, 0x10 | blk << 1 | fn >> 8)
            for _ in range(12):
                out_s += syn.frame()
            syn.write(0x20, blk << 1 | fn >> 8)
            for _ in range(3):
                out_s += syn.frame()
        for _ in range(25):
            out_s += syn.frame()
    write_wav(out, rate, out_s)
    print(f"{out}: {len(out_s) / rate:.1f} s, instruments 1-15 in order")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["render", "tables", "demo"])
    ap.add_argument("args", nargs="*")
    ap.add_argument("--rate", type=int, default=11025)
    ap.add_argument("--fps", type=int, default=50)
    ap.add_argument("--frames", type=int)
    a = ap.parse_args()
    if a.cmd == "render":
        render(a.args[0], a.args[1], a.rate, a.fps, a.frames)
    elif a.cmd == "demo":
        demo(a.args[0], a.rate, a.fps)
    else:
        with open(a.args[0], "wb") as fh:
            for i in range(1, 16):
                tabs, g = make_tables(PATCHES[i])
                fh.write(bytes([g]))
                for t in tabs:
                    fh.write(bytes(v & 255 for v in t))
        print(f"{a.args[0]}: 15 instruments x {len(MOD_LEVELS)} tables x {TABLEN} bytes")


if __name__ == "__main__":
    main()
