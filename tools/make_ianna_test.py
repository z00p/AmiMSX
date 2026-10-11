"""Test ROM replaying Ianna's hero drawing (openMSX log, frames 262-263):
HMMM a blank page-2 tile over the hero's 32x32 area on page 1, LMMC TIMP
DIX 1 of the hero (Ianna's own 767 bytes, streamed with OTIR, no TR polling),
then HMMM the four 16x16 tiles to page 0 (16,96), as the game does, and the
whole area once more to (100,96) in one HMMM. Page 0 is shown.
Usage: python tools/make_ianna_test.py hero_bytes.bin out.rom"""
import sys

w = lambda v: [v & 0xFF, v >> 8]
code, data, fix = [], [], []


def ld_hl(blob):
    data.append(bytes(blob)); code.extend([0x21, 0, 0]); fix.append((len(code) - 2, len(data) - 1))


def wait_ce():
    code.extend([0x3E, 2, 0xD3, 0x99, 0x3E, 0x8F, 0xD3, 0x99, 0xDB, 0x99, 0x0F, 0x38, 0xFB,
                 0xAF, 0xD3, 0x99, 0x3E, 0x8F, 0xD3, 0x99])


def cmd(regs):                         # ends at R#46
    wait_ce()
    code.extend([0x3E, 47 - len(regs), 0xD3, 0x99, 0x3E, 0x80 + 17, 0xD3, 0x99])
    ld_hl(regs)
    code.extend([0x0E, 0x9B, 0x06, len(regs), 0xED, 0xB3])


def hmmv(x, y, nx, ny, c):
    cmd(w(x) + w(y) + w(nx) + w(ny) + [c, 0, 0xC0])


def hmmm(sx, sy, dx, dy, nx, ny):
    cmd(w(sx) + w(sy) + w(dx) + w(dy) + w(nx) + w(ny) + [0, 0, 0xD0])


hero = open(sys.argv[1], "rb").read()
assert len(hero) == 767
code.extend([0x3E, 5, 0xCD] + w(0x005F) + [0xF3])           # SCREEN 5, DI
hmmv(0, 0, 256, 212, 0x44)                                 # page 0: colour 4
hmmv(0, 256, 256, 212, 0x44)                               # page 1: colour 4
hmmv(0, 512, 16, 16, 0x00)                                 # page 2 tile: colour 0 (Ianna's sky)
for dx, dy in ((16, 352), (32, 352), (16, 368), (32, 368)):
    hmmm(0, 512, dx, dy, 16, 16)                           # clear the hero's area
cmd(w(39) + w(352) + w(24) + w(32) + [0x00, 0x04, 0xB8])   # LMMC TIMP DIX 1, CLR 0
code.extend([0x3E, 0x80 + 44, 0xD3, 0x99, 0x3E, 0x80 + 17, 0xD3, 0x99])
for k in range(0, 767, 255):                               # OTIR in chunks of up to 255
    part = hero[k:k + 255]
    ld_hl(part)
    code.extend([0x0E, 0x9B, 0x06, len(part) & 0xFF, 0xED, 0xB3])
for sx, sy, dx, dy in ((16, 352, 16, 96), (32, 352, 32, 96), (16, 368, 16, 112), (32, 368, 32, 112)):
    hmmm(sx, sy, dx, dy, 16, 16)                           # as the game copies it
hmmm(16, 352, 100, 96, 32, 32)                             # the whole area in one copy
code.extend([0x18, 0xFE])
base = 0x4010
addr = base + len(code); offs = []
for d in data:
    offs.append(addr); addr += len(d)
for at, k in fix:
    code[at:at + 2] = w(offs[k])
rom = bytearray(16384); rom[0:2] = b"AB"; rom[2:4] = bytes(w(base))
blob = bytes(code) + b"".join(data); rom[0x10:0x10 + len(blob)] = blob
open(sys.argv[2], "wb").write(rom)
print("wrote", sys.argv[2], len(blob), "bytes")
