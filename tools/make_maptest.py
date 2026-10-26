"""SCREEN 7/8 planar VRAM mapping test: a cartridge that writes known bytes through
port 98h in SCREEN 5 and reads them back in SCREEN 8 and SCREEN 7 (and the reverse),
draws with HMMV/LMMV/LINE/HMMM/LMMM/HMMC in each of the three modes (plus a SCREEN 8
copy of SCREEN 5 data and a SCREEN 5 copy of SCREEN 8 data), reads POINT/SRCH/LMCM
results (SRCH is not emulated in AmiMSX yet, so not tested), and finally writes everything it read (the log) to VRAM 1C000h in SCREEN 5.
In G6/G7 the V9938 stores logical address A at physical (A >> 1) | (A & 1) << 16.
Compare the whole 128 KB of VRAM at the end loop with openMSX: tools/maptest.sh.
Usage: python tools/make_maptest.py <outdir>   (writes T_MapTest.rom, maptest.json)"""
import json, os, sys

STAGE = int(os.environ.get("STAGE", "9"))
FULL = os.environ.get("FULL") == "1"   # also what AmiMSX does not emulate yet (see Docs/agent_notes/screen78.md)   # 1: SCREEN 5 part only, 2: + SCREEN 8, 3: + SCREEN 7

ORG = 0x4000
LOGP, LOG = 0xC000, 0xC010          # log pointer, log start (RAM)
LOGVRAM = 0x1C000                   # where the log goes at the end (SCREEN 5)
MODES = {5: 0x06, 7: 0x0A, 8: 0x0E}  # R#0 per screen mode


class Asm:
    def __init__(self):
        self.b, self.lab, self.jr_fix, self.abs_fix = [], {}, [], []

    def pc(self):
        return ORG + 16 + len(self.b)

    def __call__(self, *bs):
        self.b += list(bs)

    def L(self, n):
        assert n not in self.lab, n
        self.lab[n] = self.pc()

    def jr(self, op, n):
        self.b += [op, 0]; self.jr_fix.append((len(self.b) - 1, n))

    def ab(self, op, n):            # op nn with a label (CALL, JP, LD HL,nn ...)
        self.b += list(op) + [0, 0]; self.abs_fix.append((len(self.b) - 2, n))

    def call(self, n):
        self.ab([0xCD], n)

    def done(self):
        for i, n in self.jr_fix:
            d = self.lab[n] - (ORG + 16 + i + 1)
            assert -128 <= d < 128, n
            self.b[i] = d & 255
        for i, n in self.abs_fix:
            v = self.lab[n]
            self.b[i], self.b[i + 1] = v & 255, v >> 8
        return bytes(self.b)


a = Asm()
data = []                           # (label, bytes) placed after the code
uid = [0]


def blob(bs):
    uid[0] += 1
    n = f"d{uid[0]}"
    data.append((n, bytes(bs)))
    return n


def reg(r, v):                      # R#r = v
    a(0x3E, v & 255, 0xD3, 0x99, 0x3E, 0x80 | r, 0xD3, 0x99)


def mode(m):                        # R#0, then about 15 lines' wait (openMSX switches the
    reg(0, MODES[m])                # mode, and the VRAM mapping, at the next line)
    n = f"mw{len(a.b)}"
    a(0x06, 0); a.L(n); a.jr(0x10, n)   # LD B,0; DJNZ $


def addr(ad, write):                # VRAM address (17 bits), read or write
    reg(14, ad >> 14 & 7)
    a(0x3E, ad & 255, 0xD3, 0x99, 0x3E, (ad >> 8 & 0x3F) | (0x40 if write else 0), 0xD3, 0x99)


def fill(ad, n, start, step):       # n bytes through port 98h: start, start+step, ...
    addr(ad, True)
    a(0x01, n & 255, n >> 8, 0x3E, start, 0x16, step)   # LD BC,n; LD A,start; LD D,step
    a.call("fill")


def readlog(ad, n):                 # read n bytes through port 98h into the log
    addr(ad, False)
    a(0x01, n & 255, n >> 8)
    a.call("rdlog")


def cmd(sx=0, sy=0, dx=0, dy=0, nx=0, ny=0, clr=0, arg=0, op=0):
    regs = [sx & 255, sx >> 8, sy & 255, sy >> 8, dx & 255, dx >> 8, dy & 255, dy >> 8,
            nx & 255, nx >> 8, ny & 255, ny >> 8, clr, arg, op]
    a.ab([0x21], blob(regs))        # LD HL,regs
    a.call("cmd")


def hmmc(dx, dy, nx, ny, bs):       # first byte in R#44, the rest through TR
    regs = [0, 0, 0, 0, dx & 255, dx >> 8, dy & 255, dy >> 8, nx & 255, nx >> 8, ny & 255, ny >> 8,
            bs[0], 0, 0xF0]
    a.ab([0x21], blob(regs)); a.call("cmd")
    a.ab([0x21], blob(bs[1:])); a(0x06, len(bs) - 1); a.call("trout")
    a.call("wce")


def point(x, y):                    # POINT, S#7 to the log
    cmd(sx=x, sy=y, op=0x40); a.call("wce"); a.call("s7log")


def srch(x, y, clr, arg):           # SRCH: S#2 (BD), S#8, S#9 to the log
    cmd(sx=x, sy=y, clr=clr, arg=arg, op=0x60); a.call("wce"); a.call("srlog")


def lmcm(sx, sy, nx, ny, n):        # LMCM: n bytes through S#7 to the log
    cmd(sx=sx, sy=sy, nx=nx, ny=ny, op=0xA0); a(0x06, n); a.call("trin"); a.call("wce")


def mark(v):                        # a log separator byte pair (FE, v)
    a(0x3E, 0xFE); a.call("log"); a(0x3E, v); a.call("log")


# ---- main ----
a(0xF3, 0x31, 0x80, 0xF3)           # DI; LD SP,F380h
a(0x3E, 5, 0xCD, 0x5F, 0x00, 0xF3)  # LD A,5; CALL CHGMOD; DI
reg(1, 0x40); reg(8, 0x0A); reg(2, 0x1F); reg(15, 0); reg(17, 0)
a(0x21, LOG & 255, LOG >> 8, 0x22, LOGP & 255, LOGP >> 8)   # log pointer
mode(5)
for pg in range(4):                 # clear all 128 KB (HMMV, a page at a time)
    cmd(dx=0, dy=pg * 256, nx=256, ny=256, clr=0, op=0xC0); a.call("wce")

# T1: SCREEN 5 writes, read back in SCREEN 5
fill(0x06000, 512, 3, 7); fill(0x16000, 512, 5, 13)
mark(1); readlog(0x06000, 16); readlog(0x16000, 16)
# SCREEN 5 commands, rows 0-39
cmd(dx=8, dy=2, nx=64, ny=8, clr=0x77, op=0xC0); a.call("wce")                  # HMMV (equal nibbles: see screen78.md)
cmd(dx=20, dy=4, nx=40, ny=10, clr=5, op=0x83); a.call("wce")                   # LMMV XOR
cmd(dx=0, dy=20, nx=100, ny=15, clr=9, op=0x70); a.call("wce")                  # LINE
cmd(sx=8, sy=2, dx=120, dy=24, nx=64, ny=8, op=0xD0); a.call("wce")             # HMMM
cmd(sx=20, sy=4, dx=150, dy=12, nx=40, ny=10, op=0x98); a.call("wce")           # LMMM TIMP
hmmc(40, 30, 16, 4, [(i * 37 + 11) & 255 for i in range(32)])                   # HMMC
mark(2); point(9, 3); point(21, 5); lmcm(8, 2, 4, 2, 8)

if STAGE >= 2:
  # T2: SCREEN 8: read SCREEN 5's bytes, write, cross the 64 KB line, commands rows 100-139
  mode(8)
  mark(3); readlog(0x0C000, 1024)
  fill(0x0D000, 256, 0x5A, 3)
  fill(0x0FFF0, 32, 0x11, 0x22); mark(4); readlog(0x0FFF0, 32)
  cmd(dx=10, dy=100, nx=50, ny=6, clr=0xA5, op=0xC0); a.call("wce")               # HMMV
  cmd(dx=30, dy=104, nx=30, ny=8, clr=0x3C, op=0x83 if FULL else 0x80); a.call("wce")   # LMMV XOR (IMP)
  if FULL:
    cmd(dx=0, dy=120, nx=200, ny=15, clr=0xE3, op=0x70); a.call("wce")           # LINE
  cmd(sx=10, sy=100, dx=100, dy=110, nx=50, ny=6, op=0xD0); a.call("wce")         # HMMM
  cmd(sx=30, sy=104, dx=180, dy=128, nx=30, ny=8, op=0x98); a.call("wce")         # LMMM TIMP
  if FULL:
    hmmc(5, 132, 8, 4, [(i * 29 + 7) & 255 for i in range(32)])                   # HMMC
  cmd(sx=0, sy=30, dx=0, dy=142, nx=128, ny=8, op=0xD0); a.call("wce")            # HMMM of SCREEN 5 data
  mark(5)
  if FULL:
    point(12, 101); point(31, 105); point(1, 32); lmcm(10, 100, 4, 2, 8)

if STAGE >= 3:
  # T3: SCREEN 7: read SCREEN 5's bytes, write, commands rows 50-89
  mode(7)
  mark(6); readlog(0x0C000, 1024)
  fill(0x0E000, 256, 0x99, 5)
  cmd(dx=16, dy=50, nx=100, ny=6, clr=0xEE, op=0xC0); a.call("wce")              # HMMV (equal nibbles)
  cmd(dx=40, dy=54, nx=60, ny=8, clr=0x0B, op=0x83); a.call("wce")               # LMMV XOR
  cmd(dx=0, dy=70, nx=300, ny=12, clr=6, op=0x70); a.call("wce")                 # LINE
  cmd(sx=16, sy=50, dx=200, dy=60, nx=100, ny=6, op=0xD0); a.call("wce")          # HMMM
  cmd(sx=40, sy=54, dx=300, dy=76, nx=60, ny=8, op=0x98); a.call("wce")           # LMMM TIMP
  hmmc(10, 82, 16, 4, [(i * 53 + 3) & 255 for i in range(32)])                    # HMMC
  mark(7); point(17, 51); point(41, 55); point(301, 77); lmcm(16, 50, 4, 2, 8)

if STAGE >= 4:
  # T4: back to SCREEN 5: read what SCREEN 8 and SCREEN 7 wrote, copy SCREEN 8 data
  mode(5)
  mark(8); readlog(0x06800, 128); readlog(0x16800, 128); readlog(0x07000, 128); readlog(0x17000, 128)
  cmd(sx=0, sy=100, dx=128, dy=160, nx=128, ny=8, op=0xD0); a.call("wce")         # HMMM of SCREEN 8 data
  mark(9); point(10, 100); point(11, 50)

# log to VRAM 1C000h: "MAPT", length, log
mode(5)
a(0x2A, LOGP & 255, LOGP >> 8, 0x11, LOG & 255, LOG >> 8, 0xB7, 0xED, 0x52)   # HL = length
a(0xE5)                             # PUSH HL
addr(LOGVRAM, True)
for c in b"MAPT":
    a(0x3E, c, 0xD3, 0x98)
a(0xE1, 0x7D, 0xD3, 0x98, 0x7C, 0xD3, 0x98)                                     # length lo, hi
a(0x44, 0x4D, 0x21, LOG & 255, LOG >> 8)                                        # BC = length; HL = LOG
a.L("wl"); a(0x7E, 0xD3, 0x98, 0x23, 0x0B, 0x78, 0xB1); a.jr(0x20, "wl")
mode(8); mode(5)                    # leave SCREEN 5 once more: AmiMSX flushes its command bands to VRAM
a.L("end"); a.jr(0x18, "end")       # JR $ (TRACEPC = end + 1)

# ---- subroutines ----
a.L("fill")                         # BC bytes, A start, D step
a(0xD3, 0x98, 0x82, 0x0B, 0x5F, 0x78, 0xB1, 0x7B); a.jr(0x20, "fill")
a(0xC9)
a.L("rdlog")                        # BC bytes from port 98h to the log
a(0xDB, 0x98); a.call("log"); a(0x0B, 0x78, 0xB1); a.jr(0x20, "rdlog"); a(0xC9)
a.L("log")                          # A to the log
a(0xE5, 0x2A, LOGP & 255, LOGP >> 8, 0x77, 0x23, 0x22, LOGP & 255, LOGP >> 8, 0xE1, 0xC9)
a.L("cmd")                          # HL = R#32..R#46 values
a.call("wce")
reg(17, 32)
a(0x0E, 0x9B, 0x06, 15, 0xED, 0xB3, 0xC9)                                       # OTIR
a.L("wce")                          # wait for CE = 0 (bounded: about 4 s; EEh to the log on a timeout)
reg(15, 2)
a(0x11, 0, 0, 0x0E, 5)
a.L("wce1"); a(0xDB, 0x99, 0x0F); a.jr(0x30, "wce2")
a(0x1B, 0x7A, 0xB3); a.jr(0x20, "wce1")
a(0x0D); a.jr(0x20, "wce1")
a(0x3E, 0xEE); a.call("log")
a.L("wce2"); reg(15, 0); a(0xC9)
a.L("wtr")                          # wait for TR = 1 (bounded), S#2 selected
a(0x11, 0, 0)
a.L("wtr1"); a(0xDB, 0x99, 0x07); a.jr(0x38, "wtr2")
a(0x1B, 0x7A, 0xB3); a.jr(0x20, "wtr1")
a.L("wtr2"); a(0xC9)
a.L("trout")                        # B bytes from HL to R#44 through TR
reg(17, 0x80 | 44); reg(15, 2)
a.L("tro1"); a.call("wtr"); a(0x7E, 0xD3, 0x9B, 0x23); a.jr(0x10, "tro1")
reg(15, 0); a(0xC9)
a.L("trin")                         # B bytes from S#7 through TR to the log
a.L("tri1"); reg(15, 2); a.call("wtr"); reg(15, 7); a(0xDB, 0x99); a.call("log"); a.jr(0x10, "tri1")
reg(15, 0); a(0xC9)
a.L("s7log")
reg(15, 7); a(0xDB, 0x99); a.call("log"); reg(15, 0); a(0xC9)
a.L("srlog")
reg(15, 2); a(0xDB, 0x99, 0xE6, 0x10); a.call("log")
reg(15, 8); a(0xDB, 0x99); a.call("log")
reg(15, 9); a(0xDB, 0x99, 0xE6, 0x03); a.call("log")
reg(15, 0); a(0xC9)

for n, bs in data:
    a.L(n); a(*bs)


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    code = a.done()
    assert len(code) + 16 <= 16384
    r = bytearray(16384)
    r[0:4] = b"AB" + bytes([(ORG + 16) & 255, (ORG + 16) >> 8])
    r[16:16 + len(code)] = code
    open(os.path.join(out, "T_MapTest.rom"), "wb").write(r)
    end = a.lab["end"]
    json.dump({"end": end, "logvram": LOGVRAM}, open(os.path.join(out, "maptest.json"), "w"))
    print(f"ROM end {end:04X} (TRACEPC=${end + 1:04X}), code {len(code)} bytes")


main()
