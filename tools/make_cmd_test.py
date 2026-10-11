"""Build an MSX2 test ROM for LMMC (and HMMM after it) in SCREEN 5: fill the screen with colour 4
(HMMV), then draw 24x8 LMMC blocks left-to-right (DIX 0) and right-to-left
(DIX 1), with IMP and TIMP, at even and odd X (Ianna draws its hero with
LMMC TIMP, DIX 1, from X 39). Pixel colour = (column + row) % 15 + 1; for the
TIMP blocks every third column is 0 (transparent: the fill shows through).
Usage: python tools/make_cmd_test.py out.rom"""
import sys

CHGMOD = 0x005F
w = lambda v: [v & 0xFF, v >> 8]

# (DX, DY, ARG, CMD, transparent zeros)
TESTS = [(40, 20, 0x00, 0xB0, False),    # A: DIX 0, IMP
         (139, 20, 0x04, 0xB0, False),   # B: DIX 1, IMP
         (40, 40, 0x00, 0xB8, True),     # C: DIX 0, TIMP
         (139, 40, 0x04, 0xB8, True),    # D: DIX 1, TIMP
         (39, 60, 0x04, 0xB8, True),     # E: DIX 1, TIMP, odd X (Ianna)
         (41, 80, 0x00, 0xB0, False),    # F: DIX 0, IMP, odd X
         (140, 80, 0x04, 0xB0, False),   # G: DIX 1, IMP, even X
         (39, 352, 0x04, 0xB8, True),    # H: DIX 1, TIMP, odd X, on page 1 (copied below)
         (40, 368, 0x00, 0xB8, True)]    # I: DIX 0, TIMP, on page 1 (copied below)
# HMMM page 1 -> page 0 after the LMMCs (Ianna draws off-screen, then copies):
COPIES = [(0, 352, 0, 120, 64, 8),       # H's area -> y 120
          (32, 368, 32, 140, 48, 8)]     # I's area -> y 140
NX, NY = 24, 8


def pixels(transp):
    out = []
    for y in range(NY):
        for x in range(NX):
            out.append(0 if transp and x % 3 == 0 else (x + y) % 15 + 1)
    return out


code, data = [], []          # data: (label index, bytes), placed after the code
fix = []                     # (code offset of a 16-bit operand, data index)


def ld_hl_data(blob):
    data.append(bytes(blob))
    code.extend([0x21, 0, 0]); fix.append((len(code) - 2, len(data) - 1))


def wait_ce():
    # R#15 = 2; loop: IN A,(99h); RRCA; JR C,loop; R#15 = 0
    code.extend([0x3E, 2, 0xD3, 0x99, 0x3E, 0x8F, 0xD3, 0x99,
                 0xDB, 0x99, 0x0F, 0x38, 0xFB,
                 0xAF, 0xD3, 0x99, 0x3E, 0x8F, 0xD3, 0x99])


def cmd(regs):               # R#46 last: from R#36 (11 bytes) or R#32 (15 bytes)
    wait_ce()
    first = 47 - len(regs)
    code.extend([0x3E, first, 0xD3, 0x99, 0x3E, 0x80 + 17, 0xD3, 0x99])
    ld_hl_data(regs)
    code.extend([0x0E, 0x9B, 0x06, len(regs)])   # LD C,9Bh / LD B,n
    code.extend([0xED, 0xB3])                    # OTIR


code.extend([0x3E, 5, 0xCD] + w(CHGMOD))         # SCREEN 5
code.append(0xF3)                                # DI (R#15 stays ours)
cmd(w(0) + w(0) + w(256) + w(212) + [0x44, 0x00, 0xC0])   # HMMV fill, colour 4
for dx, dy, arg, op, tr in TESTS:
    px = pixels(tr)
    cmd(w(dx) + w(dy) + w(NX) + w(NY) + [px[0], arg, op])
    # R#17 = 44, no autoincrement; then each pixel when TR is set, until CE clears.
    code.extend([0x3E, 0x80 + 44, 0xD3, 0x99, 0x3E, 0x80 + 17, 0xD3, 0x99])
    ld_hl_data(px[1:])
    code.extend([0x11] + w(len(px) - 1))         # LD DE,count
    loop = len(code)
    code.extend([0x3E, 2, 0xD3, 0x99, 0x3E, 0x8F, 0xD3, 0x99])   # R#15 = 2
    wt = len(code)
    code.extend([0xDB, 0x99,                     # IN A,(99h)
                 0xCB, 0x47, 0x28, 0x00,         # BIT 0,A / JR Z,done (patched)
                 0xCB, 0x7F, 0x28, (wt - (len(code) + 10)) & 0xFF])   # BIT 7,A / JR Z,wt
    jz_done = len(code) - 5
    code.extend([0xAF, 0xD3, 0x99, 0x3E, 0x8F, 0xD3, 0x99,       # R#15 = 0
                 0x7E, 0xD3, 0x9B, 0x23, 0x1B, 0x7A, 0xB3])     # LD A,(HL) OUT (9Bh) INC HL DEC DE LD A,D OR E
    code.extend([0x20, (loop - (len(code) + 2)) & 0xFF])        # JR NZ,loop
    done = len(code)
    code[jz_done] = (done - (jz_done + 1)) & 0xFF
    code.extend([0xAF, 0xD3, 0x99, 0x3E, 0x8F, 0xD3, 0x99])      # R#15 = 0
for sx, sy, dx, dy, nx, ny in COPIES:              # HMMM
    cmd(w(sx) + w(sy) + w(dx) + w(dy) + w(nx) + w(ny) + [0, 0x00, 0xD0])
code.extend([0x18, 0xFE])                        # JR $

base = 0x4010
addr = base + len(code)
offs = []
for d in data:
    offs.append(addr); addr += len(d)
for at, k in fix:
    code[at:at + 2] = w(offs[k])
rom = bytearray(16384)
rom[0:2] = b"AB"; rom[2:4] = bytes(w(base))
blob = bytes(code) + b"".join(data)
rom[0x10:0x10 + len(blob)] = blob
open(sys.argv[1], "wb").write(rom)
print("wrote", sys.argv[1], len(code), "bytes of code,", sum(map(len, data)), "of data")
