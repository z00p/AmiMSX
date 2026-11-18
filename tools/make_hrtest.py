"""S#2 HR/VR timing cartridge (32 KB at 4000h, code in the first 16 KB).

One continuous run on one time base: DI, the VDP set up directly, then a list
of blocks whose costs are known (Z80 + the MSX M1 wait), so every VDP read has
a known time (in Z80 cycles) from the start of the first block:
- samples: IN A,(99h) with R#15 = 2 every 55 cycles (55 doesn't divide 228,
  so the sample phase walks the line; the raw S#2 byte goes to RAM);
- fhpoll: R#15 = 1, a poll of S#1 bit 0 (FH, the R#19 line interrupt) every 37
  cycles, once per frame for n frames; the poll count of each frame goes to RAM
  (the reader puts the FH event between the last two reads);
- fpoll: the same on S#0 bit 7 (F, the VBlank interrupt), R#15 = 0, and once F
  is seen R#15 = 2 and 16 S#2 reads 27 cycles apart (VR and HR against F).
Data: C010h-EFFFh (page 3 only: AmiMSX's page 2 didn't take the RAM slot
switch), marker "HRT3" at F000h, "HRDONE" at F008h when the run has finished.
The layout and every block's cost are written to the JSON for tools/read_hrtest.py.
Usage: python tools/make_hrtest.py out.rom out.json"""
import json, sys

ORG, INIT = 0x4000, 0x4010
DATA0, DATAEND = 0xC010, 0xF000
STRIDE = 55                     # the sample loop (below)
POLL = 37                       # the FH poll loop

code = bytearray()
t = 0                           # straight-line time (Z80+M1 cycles) since the time base start
blocks = []


def op(bts, cyc=0):
    global t
    code.extend(bts)
    if t is not None:                               # (None: after a poll, untimed)
        t += cyc


def pc():
    return ORG + 16 + len(code)


def vreg(r, v):                 # LD A,v / OUT (99h),A / LD A,80h+r / OUT (99h),A
    op([0x3E, v, 0xD3, 0x99, 0x3E, 0x80 | r, 0xD3, 0x99], 8 + 12 + 8 + 12)


# ---- set-up (not timed) ----
op([0xF3])                                          # DI
op([0x31, 0x00, 0xF3])                              # LD SP,F300h
for addr, txt in ((0xF000, b"HRT3"),):
    for i, c in enumerate(txt):
        op([0x3E, c, 0x32, (addr + i) & 255, (addr + i) >> 8])    # LD A,c / LD (nn),A
op([0x3A, 0xE8, 0xFF, 0xE6, 0x02, 0x32, 0x00, 0xF1])  # LD A,(RG9SAV) AND 2 LD (F100h),A: the machine's NT bit
op([0x3A, 0x00, 0xF1, 0xF6, 0x80, 0xD3, 0x99, 0x3E, 0x89, 0xD3, 0x99])  # R#9 = 80h | NT (LN=1)
for r, v in ((0, 0x16), (1, 0x40), (2, 0x1F), (8, 0x0A), (18, 0), (19, 100), (23, 0), (25, 0), (15, 2)):
    vreg(r, v)
op([0x21, DATA0 & 255, DATA0 >> 8])                 # LD HL,DATA0
op([0xDB, 0x99])                                    # IN A,(99h): S#2 once (nothing pending)
t = 0                                               # ---- the time base starts here ----

hl = DATA0


def regs(name, writes, r9=None):
    t0 = t
    for r, v in writes:
        vreg(r, v)
    if r9 is not None:                              # R#9 = r9 | NT: LD A,(F100h) OR n OUT LD A,89h OUT
        op([0x3A, 0x00, 0xF1, 0xF6, r9, 0xD3, 0x99, 0x3E, 0x89, 0xD3, 0x99], 14 + 8 + 12 + 8 + 12)
    blocks.append({"type": "regs", "name": name, "t": t0, "cost": t - t0})


def samples(name, n, mode):
    """LD DE,n; loop: IN A,(99h) / LD (HL),A / INC HL / DEC DE / LD A,D / OR E / JP NZ,loop."""
    global hl, t
    t0 = t
    op([0x11, n & 255, n >> 8], 11)
    loop = pc()
    op([0xDB, 0x99, 0x77, 0x23, 0x1B, 0x7A, 0xB3, 0xC2, loop & 255, loop >> 8])
    blocks.append({"type": "samples", "name": name, "mode": mode, "t": t0, "first": t, "stride": STRIDE,
                   "n": n, "addr": hl})
    t += n * STRIDE
    hl += n


def fhpoll(name, frames, mode, bit=0, vr=0):
    """IN A,(99h) (clear FH) / LD B,frames
    frame: LD DE,0
    poll:  INC DE / IN A,(99h) / RRCA / JR NC,poll
           LD (HL),E / INC HL / LD (HL),D / INC HL / DJNZ frame
    Read k (1..) of a frame at frame start + 11 + 7 + (k-1)*37; the frame after
    it starts at frame start + 11 + count*37 - 5 + 30 + 14."""
    global hl, t
    t0 = t
    op([0xDB, 0x99, 0x06, frames], 12 + 8)
    fr = pc()
    op([0x11, 0x00, 0x00])
    poll = pc()
    op([0x13, 0xDB, 0x99, 0x0F if bit == 0 else 0x07, 0x30, (poll - (pc() + 6)) & 255])  # RRCA (FH) / RLCA (F)
    if vr:                                          # then R#15 = 2 and vr S#2 reads, 27 cycles apart, R#15 = 0
        vreg(15, 2)
        for i in range(vr):
            op([0xDB, 0x99, 0x77, 0x23])            # IN A,(99h) / LD (HL),A / INC HL
        vreg(15, 0)
    op([0x73, 0x23, 0x72, 0x23, 0x10, (fr - (pc() + 6)) & 255])
    extra = 80 + 27 * vr if vr else 0
    blocks.append({"type": "fhpoll", "name": name, "mode": mode, "t": t0, "pre": 20, "frames": frames, "bit": bit, "vr": vr, "extra": extra,
                   "addr": hl, "poll": POLL})
    hl += (2 + vr) * frames
    t = None                                        # data-dependent from here: the reader carries on


G4, TX1 = [(0, 0x16), (1, 0x40)], [(0, 0x10), (1, 0x50)]
S2, S1 = [(15, 2)], [(15, 1)]
PLAN = [
    ("regs", "G4 R18=00", G4 + [(18, 0)] + S2), ("samples", "A G4 R18=00", 2000, "G4 r18=00"),
    ("regs", "FH", S1), ("fhpoll", "FH G4 R18=00", 64, "G4 r18=00"),
    ("regs", "S2", S2), ("samples", "B G4 R18=00 (check)", 800, "G4 r18=00"),
    ("regs", "R18=08", [(18, 0x08)]), ("samples", "C G4 R18=08", 1200, "G4 r18=08"),
    ("regs", "FH", S1), ("fhpoll", "FH G4 R18=08", 64, "G4 r18=08"),
    ("regs", "R18=03", S2 + [(18, 0x03)]), ("samples", "D G4 R18=03", 1200, "G4 r18=03"),
    ("regs", "TEXT1", TX1 + [(18, 0)]), ("samples", "E TEXT1", 1600, "TEXT1 r18=00"),
    ("regs", "FH", S1), ("fhpoll", "FH TEXT1", 64, "TEXT1 r18=00"),
    ("regs", "G4 LN=0", S2 + G4, 0x00), ("samples", "F G4 LN=0", 3000, "G4 LN=0"),
    ("regs", "LN=1", [], 0x80), ("samples", "G G4 LN=1 (check)", 800, "G4 r18=00"),
    ("regs", "F", [(15, 0)]), ("fpoll", "F G4 LN=1, then S#2", 32, "G4 r18=00"),
    ("regs", "LN=0", [], 0x00), ("fpoll", "F G4 LN=0, then S#2", 32, "G4 LN=0"),
]
for p in PLAN:
    if t is None:                                   # after a poll: a fresh relative base
        t = 0
        blocks.append({"type": "rebase"})
    if p[0] == "regs":
        regs(p[1], p[2], p[3] if len(p) > 3 else None)
    elif p[0] == "samples":
        samples(p[1], p[2], p[3])
    elif p[0] == "fpoll":                           # the VBlank flag: S#0 bit 7
        fhpoll(p[1], p[2], p[3], 7, 16)
    else:
        fhpoll(p[1], p[2], p[3])
assert hl <= DATAEND, hex(hl)
for i, c in enumerate(b"HRDONE"):
    op([0x3E, c, 0x32, (0xF008 + i) & 255, (0xF008 + i) >> 8])
op([0x18, 0xFE])                                    # JR $
rom = bytearray(32768)
rom[0:4] = b"AB" + bytes([INIT & 255, INIT >> 8])
assert 16 + len(code) <= 16384, len(code)
rom[16:16 + len(code)] = code
open(sys.argv[1], "wb").write(rom)
json.dump({"data0": DATA0, "blocks": blocks}, open(sys.argv[2], "w"), indent=1)
print(f"{len(code)} bytes of code, data {DATA0:04X}-{hl - 1:04X}")
