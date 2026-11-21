"""ASCII16-X flash chip test (5.3): a 1 MB cartridge that drives the flash chip
from RAM through page 1 (first bank, bank register at 6000h) and prints what it
reads in SCREEN 0, for comparison with openMSX (-romtype ASCII16-X).

First run (16 KB bank 4 still blank at 4000h):
  ID   autoselect (AAh 55h 90h): 4000h 4002h 401Ch 401Eh 4004h, then CFI (98h at
       40AAh): 4020h 4022h 4024h 404Eh, then F0h: 4000h (the ROM's "A").
  then program 5Ah, 3Ch at bank 4 4000h/4001h; buffer program 11h 22h 33h 44h at
  bank 4 4100h; erase the 64 KB sector of bank 8 (ROM bytes 55h there) and
  program 77h at bank 8 4010h; a broken buffer program (data outside its page):
  status read, then AAh 55h F0h and the array again.
Every run then prints the read-back line, so a second run (bank 4 4000h = 5Ah)
shows whether the changes were kept (AmiMSX: <rom>.flash; openMSX: its
persistent flash).
Expected, first run:
  R1
  01 7E 10 00 00 51 52 59 17 41
  5A 3C 11 22 33 44 FF 77 FF FF 55
  82 FF
Second run: R2 and the same read-back line.
Usage: python tools/make_asxflash_test.py <out.rom>"""
import sys

ORG = 0xC100                        # the program runs from RAM
CHPUT, INITXT = 0x00A2, 0x006C
RES = 0xC000                        # results (RAM)


class Asm:
    def __init__(self):
        self.b, self.lab, self.fix = [], {}, []

    def pc(self):
        return ORG + len(self.b)

    def __call__(self, *bs):
        self.b += list(bs)

    def L(self, n):
        assert n not in self.lab, n
        self.lab[n] = self.pc()

    def jr(self, op, n):
        self.b += [op, 0]; self.fix.append(("r", len(self.b) - 1, n))

    def ab(self, op, n):
        self.b += list(op) + [0, 0]; self.fix.append(("a", len(self.b) - 2, n))

    def nn(self, op, v):
        self.b += list(op) + [v & 0xFF, v >> 8]

    def ld_a(self, v): self(0x3E, v)
    def st(self, addr): self.nn([0x32], addr)        # LD (nn),A
    def ldm(self, addr): self.nn([0x3A], addr)       # LD A,(nn)
    def call(self, n): self.ab([0xCD], n)

    def wr(self, addr, v):
        self.ld_a(v); self.st(addr)

    def keep(self, addr, i):                          # LD A,(addr): LD (RES+i),A
        self.ldm(addr); self.st(RES + i)

    def done(self):
        for k, at, n in self.fix:
            t = self.lab[n]
            if k == "r":
                d = t - (ORG + at + 1)
                assert -128 <= d < 128, n
                self.b[at] = d & 0xFF
            else:
                self.b[at], self.b[at + 1] = t & 0xFF, t >> 8
        return bytes(self.b)


a = Asm()
a.L("start")
a.nn([0xCD], INITXT)
a.wr(0x6000, 4)                      # first bank = 4
a.ldm(0x4000); a(0xFE, 0x5A); a.ab([0xCA], "run2")
a.ab([0x21], "m1"); a.call("print")
a.wr(0x6000, 0)
a(0xF3)                              # DI
a.call("unlock"); a.wr(0x4AAA, 0x90)                 # autoselect
for i, ad in enumerate((0x4000, 0x4002, 0x401C, 0x401E, 0x4004)):
    a.keep(ad, i)
a.wr(0x40AA, 0x98)                                   # CFI query
for i, ad in enumerate((0x4020, 0x4022, 0x4024, 0x404E)):
    a.keep(ad, 5 + i)
a.wr(0x4000, 0xF0)                                   # read the array
a.keep(0x4000, 9)
a(0xFB)
a.nn([0x21], RES); a(0x06, 10); a.call("hexn"); a.call("crlf")
a.wr(0x6000, 4)
a(0xF3)
a.call("unlock"); a.wr(0x4AAA, 0xA0); a.wr(0x4000, 0x5A)
a.nn([0x21], 0x4000); a(0x06, 0x5A); a.call("poll")
a.call("unlock"); a.wr(0x4AAA, 0xA0); a.wr(0x4001, 0x3C)
a.nn([0x21], 0x4001); a(0x06, 0x3C); a.call("poll")
a.call("unlock"); a.wr(0x4100, 0x25); a.wr(0x4100, 3)  # buffer program
for i, v in enumerate((0x11, 0x22, 0x33, 0x44)):
    a.wr(0x4100 + i, v)
a.wr(0x4100, 0x29)
a.nn([0x21], 0x4103); a(0x06, 0x44); a.call("poll")
a.wr(0x6000, 8)
a.call("unlock"); a.wr(0x4AAA, 0x80); a.call("unlock"); a.wr(0x4000, 0x30)
a.nn([0x21], 0x4000); a(0x06, 0xFF); a.call("poll")   # erase done: FFh
a.call("unlock"); a.wr(0x4AAA, 0xA0); a.wr(0x4010, 0x77)
a.nn([0x21], 0x4010); a(0x06, 0x77); a.call("poll")
a.wr(0x6000, 4)                                      # broken buffer program
a.call("unlock"); a.wr(0x4200, 0x25); a.wr(0x4200, 1); a.wr(0x4200, 0x66)
a.wr(0x4300, 0x77)                                   # another page: abort
a.keep(0x4000, 11)                                   # status
a.call("unlock"); a.wr(0x4AAA, 0xF0)
a.keep(0x4200, 12)                                   # array: nothing written
a(0xFB)
a.ab([0xC3], "back")
a.L("run2")
a.ab([0x21], "m2"); a.call("print")
a.nn([0x21], RES + 11); a(0x36, 0); a(0x23); a(0x36, 0)
a.L("back")
a.wr(0x6000, 4)
for i, ad in enumerate((0x4000, 0x4001, 0x4100, 0x4101, 0x4102, 0x4103)):
    a.keep(ad, 16 + i)
a.wr(0x6000, 8)
a.keep(0x4000, 22); a.keep(0x4010, 23); a.keep(0x7FFF, 24)
a.wr(0x6000, 9); a.keep(0x4000, 25)
a.wr(0x6000, 12); a.keep(0x4000, 26)
a.wr(0x6000, 0)
a.nn([0x21], RES + 16); a(0x06, 11); a.call("hexn"); a.call("crlf")
a.nn([0x21], RES + 11); a(0x06, 2); a.call("hexn"); a.call("crlf")
a.L("halt"); a(0xFB, 0x76); a.jr(0x18, "halt")      # EI: HALT (AmiMSX's key script
                                                     # stops in an EI: JR $ loop in RAM)
# subroutines
a.L("unlock"); a.wr(0x4AAA, 0xAA); a.wr(0x4555, 0x55); a(0xC9)
a.L("poll"); a(0x7E, 0xB8); a.jr(0x20, "poll"); a(0xC9)        # LD A,(HL): CP B
a.L("hexn"); a(0x7E); a.call("hex2"); a.ld_a(0x20); a.nn([0xCD], CHPUT)
a(0x23); a.jr(0x10, "hexn"); a(0xC9)
a.L("hex2"); a(0xF5, 0x0F, 0x0F, 0x0F, 0x0F); a.call("nib"); a(0xF1)
a.L("nib"); a(0xE6, 0x0F, 0xC6, 0x90, 0x27, 0xCE, 0x40, 0x27); a.nn([0xC3], CHPUT)
a.L("crlf"); a.ld_a(13); a.nn([0xCD], CHPUT); a.ld_a(10); a.nn([0xC3], CHPUT)
a.L("print"); a(0x7E, 0xB7, 0xC8); a.nn([0xCD], CHPUT); a(0x23); a.jr(0x18, "print")
a.L("m1"); a(*b"ASCII16-X flash R1\r\n\0")
a.L("m2"); a(*b"ASCII16-X flash R2\r\n\0")
prog = a.done()

rom = bytearray(b"\xFF" * 0x100000)
boot = bytes([0x41, 0x42, 0x10, 0x40]) + bytes(12)
# 4010h: copy the program to RAM and run it there
boot += bytes([0x21, 0x00, 0x41, 0x11, ORG & 0xFF, ORG >> 8,
               0x01, len(prog) & 0xFF, len(prog) >> 8, 0xED, 0xB0,
               0xC3, ORG & 0xFF, ORG >> 8])
rom[0:len(boot)] = boot
rom[0x100:0x100 + len(prog)] = prog
rom[0x20000:0x40000] = b"\x55" * 0x20000           # banks 8-15: 55h
open(sys.argv[1], "wb").write(rom)
print(sys.argv[1], len(prog), "bytes of program")
