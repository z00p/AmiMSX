"""Turbo R PCM test cartridge (16 KB, page 1), for the FS-A1GT.
1. Counts the A4h counter's steps over one frame (from one VBlank flag to the
   next, polled on S#0 with interrupts off) and prints "LINES xxxx": the
   lines in a frame, 0106h at 60 Hz (262), 0139h at 50 Hz (313), give or
   take one.
2. Plays a square wave through the PCM for ever: A5h = 03h (play), then a
   write to A4h each time the counter moves on (one sample a line, 15.7
   kHz), 16 samples at C0h and 16 at 40h: 490.6 Hz.
Usage: python tools/make_pcmtest.py out.rom"""
import sys

BASE = 0x4010
INITXT, CHPUT, ENASCR = 0x006C, 0x00A2, 0x0044


class Asm:
    def __init__(self):
        self.code, self.lab, self.fix = [], {}, []

    def b(self, *v):
        self.code.extend(v)

    def here(self, name):
        self.lab[name] = len(self.code)

    def jr(self, opc, name):                       # JR / JR cc / DJNZ to a label
        self.code.extend([opc, 0])
        self.fix.append(("r", len(self.code) - 1, name))

    def call(self, name):
        self.code.extend([0xCD, 0, 0])
        self.fix.append(("a", len(self.code) - 2, name))

    def text(self, s):
        for ch in s:
            self.b(0x3E, ord(ch), 0xCD, CHPUT & 255, CHPUT >> 8)

    def done(self):
        for kind, off, name in self.fix:
            t = self.lab[name]
            if kind == "r":
                d = t - (off + 1)
                assert -128 <= d <= 127, name
                self.code[off] = d & 255
            else:
                a = BASE + t
                self.code[off], self.code[off + 1] = a & 255, a >> 8
        return bytes(self.code)


def main():
    a = Asm()
    a.b(0xF3, 0x31, 0x00, 0xF0)                    # DI; LD SP,F000h
    a.b(0xCD, INITXT & 255, INITXT >> 8)           # INITXT
    a.b(0xCD, ENASCR & 255, ENASCR >> 8, 0xF3)     # ENASCR; DI
    a.b(0x3E, 0x03, 0xD3, 0xA5)                    # LD A,03h; OUT (A5h),A
    a.b(0xDB, 0x99)                                # IN A,(99h): flag cleared
    a.here("w1")
    a.b(0xDB, 0x99, 0x07)                          # IN A,(99h); RLCA
    a.jr(0x30, "w1")                               # JR NC,w1: frame start
    a.b(0x3E, 0x80, 0xD3, 0xA4)                    # LD A,80h; OUT (A4h),A
    a.b(0x21, 0, 0, 0x06, 0)                       # LD HL,0; LD B,0
    a.here("m1")
    a.b(0xDB, 0xA4, 0xE6, 0x03, 0xB8)              # IN A,(A4h); AND 3; CP B
    a.jr(0x28, "m2")                               # JR Z,m2
    a.b(0x47, 0x23)                                # LD B,A; INC HL
    a.here("m2")
    a.b(0xDB, 0x99, 0x07)                          # IN A,(99h); RLCA
    a.jr(0x30, "m1")                               # JR NC,m1
    a.b(0xE5)                                      # PUSH HL
    a.text("LINES ")
    a.b(0xE1, 0x7C)                                # POP HL; LD A,H
    a.call("hex")
    a.b(0x7D)                                      # LD A,L
    a.call("hex")
    a.text("\r\nPCM 490 HZ")
    a.b(0xF3, 0x3E, 0x03, 0xD3, 0xA5)              # DI; A5h = 03h again
    a.b(0x0E, 16, 0x1E, 0xC0)                      # LD C,16; LD E,C0h
    a.here("t1")
    a.b(0xDB, 0xA4, 0xE6, 0x03)                    # IN A,(A4h); AND 3
    a.jr(0x28, "t1")                               # JR Z,t1: same line
    a.b(0x7B, 0xD3, 0xA4, 0x0D)                    # LD A,E; OUT (A4h),A; DEC C
    a.jr(0x20, "t1")                               # JR NZ,t1
    a.b(0x0E, 16, 0x7B, 0xEE, 0x80, 0x5F)          # LD C,16; LD A,E; XOR 80h; LD E,A
    a.jr(0x18, "t1")                               # JR t1
    # hex: print A as two hex digits
    a.here("hex")
    a.b(0xF5, 0x0F, 0x0F, 0x0F, 0x0F)
    a.call("dig")
    a.b(0xF1)
    a.here("dig")
    a.b(0xE6, 0x0F, 0xC6, 0x90, 0x27, 0xCE, 0x40, 0x27,
        0xCD, CHPUT & 255, CHPUT >> 8, 0xC9)
    code = a.done()
    rom = bytearray([0xFF] * 0x4000)
    rom[0:4] = b"AB\x10\x40"
    rom[0x10:0x10 + len(code)] = code
    open(sys.argv[1], "wb").write(rom)


main()
