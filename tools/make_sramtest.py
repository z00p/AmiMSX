"""Cartridge SRAM test (4.4): 128 KB cartridges for the four SRAM types AmiMSX
emulates (openMSX ASCII16SRAM2/8, ASCII8SRAM2/8). Each logs what it reads: the
SRAM as it found it (blank FFh, or the previous run's), the SRAM after adding 1 to
its first 16 bytes, the mirrors, page 1 (ASCII16: read only) or regions 2/3 (ASCII8:
read only), ROM banks around it, and a write while ROM is selected (ignored). The
log goes to VRAM 0000h ("SRMT", length, bytes); the cartridge then waits at 4080h
(JR $, TRACEPC=$4081). Run each twice: the second run starts from the first one's
saved SRAM (AmiMSX: <rom>.sram next to the ROM; openMSX: its persistent folder).
Compare with openMSX: tools/sramtest.sh.
Usage: python tools/make_sramtest.py <outdir>   (writes T_Sram*.rom)"""
import os, sys

ROMS = {"T_Sram16_2[ASCII16SRAM2].rom": (16, 0x800), "T_Sram16_8[ASCII16SRAM8].rom": (16, 0x2000),
        "T_Sram8_2[ASCII8SRAM2].rom": (8, 0x800), "T_Sram8_8[ASCII8SRAM8].rom": (8, 0x2000)}
ROMTYPE = {16: {0x800: "ASCII16SRAM2", 0x2000: "ASCII16SRAM8"}, 8: {0x800: "ASCII8SRAM2", 0x2000: "ASCII8SRAM8"}}
RUN, LOG, END = 0xC100, 0xD000, 0x4080
EN = 0x10            # ASCII16: SRAM bank; ASCII8: the bit above 16 8 KB banks (128 KB)
MARK = 0x1F00        # each 8 KB block j holds j + 0A0h at offset 1F00h


class Asm:
    def __init__(self, org):
        self.org, self.b, self.lab, self.fix = org, [], {}, []

    def pc(self):
        return self.org + len(self.b)

    def __call__(self, *bs):
        self.b += list(bs)

    def L(self, n):
        self.lab[n] = self.pc()

    def jr(self, op, n):
        self.b += [op, 0]; self.fix.append((len(self.b) - 1, n))

    def call(self, n):
        self.b += [0xCD, 0, 0]; self.fix.append((len(self.b) - 2, n, "abs"))

    def done(self):
        for f in self.fix:
            if len(f) == 3:
                i, n, _ = f; v = self.lab[n]; self.b[i], self.b[i + 1] = v & 255, v >> 8
            else:
                i, n = f; d = self.lab[n] - (self.org + i + 1)
                assert -128 <= d < 128, n
                self.b[i] = d & 255
        return bytes(self.b)


def code(fam, size):
    a = Asm(RUN)
    k = [0]

    def poke(ad, v):
        a(0x3E, v, 0x32, ad & 255, ad >> 8)

    def loop(name):
        k[0] += 1; return f"{name}{k[0]}"

    def logblk(ad, n):                  # n bytes from ad to the log
        l = loop("lb")
        a(0x21, ad & 255, ad >> 8, 0x06, n); a.L(l); a(0x7E); a.call("log"); a(0x23); a.jr(0x10, l)

    def incblk(ad, n):                  # (ad+i) += 1
        l = loop("ib")
        a(0x21, ad & 255, ad >> 8, 0x06, n); a.L(l); a(0x7E, 0x3C, 0x77, 0x23); a.jr(0x10, l)

    def mark(v):
        a(0x3E, 0xFE); a.call("log"); a(0x3E, v); a.call("log")

    a(0xFD, 0x21, LOG & 255, LOG >> 8)  # LD IY,LOG
    if fam == 16:
        poke(0x7000, EN)                # page 2: SRAM
        mark(1); logblk(0x8000, 16)
        incblk(0x8000, 16)
        mark(2); logblk(0x8000, 16); logblk(0x8000 + size, 16); logblk(0xBFF0, 16)
        poke(0x6000, EN)                # page 1: SRAM, read only
        mark(3); logblk(0x4000, 16); logblk(0x7FF0, 16)
        poke(0x4000, 0x5A); poke(0x5001, 0xA5)
        logblk(0x4000, 4); logblk(0x8000, 4)
        poke(0x6000, 0x11)              # not 10h: a ROM bank (17, masked to 1)
        mark(4); logblk(0x4000 + MARK, 1); logblk(0x6000 + MARK, 1)
        poke(0x7000, 3)                 # page 2: ROM bank 3; a write there is ignored
        poke(0x8000, 0x77)
        logblk(0x8000 + MARK, 1); logblk(0xA000 + MARK, 1)
        poke(0x7000, EN)
        mark(5); logblk(0x8000, 4)
        poke(0x6000, 0); poke(0x7000, 0)
    else:
        poke(0x7000, EN); poke(0x7800, EN)   # regions 4, 5: SRAM
        mark(1); logblk(0x8000, 16)
        incblk(0x8000, 16)
        mark(2); logblk(0x8000, 16); logblk(0xA000, 16); logblk(0x8000 + (size & 0x1FFF), 16); logblk(0xBFF0, 16)
        poke(0x6000, EN); poke(0x6800, EN)   # regions 2, 3: SRAM shown, read only
        mark(3); logblk(0x4000, 16); logblk(0x6000, 4)
        poke(0x4000, 0x5A)
        logblk(0x4000, 4); logblk(0x8000, 4)
        poke(0x7000, EN | 1)            # 8 KB SRAM: block 1 is block 0
        mark(4); logblk(0x8000, 4)
        poke(0x7000, 3)                 # region 4: ROM block 3; a write there is ignored
        poke(0x8000, 0x77)
        poke(0x6000, 5); poke(0x6800, 0x26)   # 26h: no SRAM bit, block 26h & 15 = 6
        logblk(0x8000 + MARK, 1); logblk(0x4000 + MARK, 1); logblk(0x6000 + MARK, 1)
        poke(0x7000, EN)
        mark(5); logblk(0x8000, 4); logblk(0xA000, 4)
        poke(0x6000, 0); poke(0x6800, 1); poke(0x7000, 2); poke(0x7800, 3)
    # the log to VRAM 0000h: "SRMT", length, bytes
    a(0xFD, 0xE5, 0xE1, 0x11, LOG & 255, LOG >> 8, 0xB7, 0xED, 0x52)   # HL = IY - LOG
    a(0xE5)                                                            # PUSH HL
    a(0xAF, 0xD3, 0x99, 0x3E, 0x8E, 0xD3, 0x99)                        # R#14 = 0
    a(0xAF, 0xD3, 0x99, 0x3E, 0x40, 0xD3, 0x99)                        # write address 0
    for c in b"SRMT":
        a(0x3E, c, 0xD3, 0x98)
    a(0xE1, 0x7D, 0xD3, 0x98, 0x7C, 0xD3, 0x98)                        # length lo, hi
    a(0x44, 0x4D, 0x21, LOG & 255, LOG >> 8)                           # BC = length
    a.L("wl"); a(0x7E, 0xD3, 0x98, 0x23, 0x0B, 0x78, 0xB1); a.jr(0x20, "wl")
    a(0xC3, END & 255, END >> 8)                                       # JP the end loop (ROM)
    a.L("log"); a(0xFD, 0x77, 0x00, 0xFD, 0x23, 0xC9)                  # LD (IY+0),A; INC IY
    return a.done()


def rom(fam, size):
    r = bytearray(0x20000)
    for j in range(16):
        r[j * 0x2000 + MARK] = 0xA0 + j
    c = code(fam, size)
    src = 0x4100
    boot = [0xF3, 0x31, 0x80, 0xF3,                                    # DI; LD SP,F380h
            0xDB, 0xA8, 0xE6, 0x0C, 0x07, 0x07, 0x4F, 0xDB, 0xA8, 0xE6, 0xCF, 0xB1, 0xD3, 0xA8,  # page 2 = page 1's slot
            0x21, src & 255, src >> 8, 0x11, RUN & 255, RUN >> 8, 0x01, len(c) & 255, len(c) >> 8,
            0xED, 0xB0, 0xC3, RUN & 255, RUN >> 8]                     # LDIR; JP RUN
    r[0:4] = b"AB\x10\x40"
    r[0x10:0x10 + len(boot)] = bytes(boot)
    assert 0x10 + len(boot) <= END - 0x4000
    r[END - 0x4000:END - 0x4000 + 2] = b"\x18\xFE"                     # JR $
    r[src - 0x4000:src - 0x4000 + len(c)] = c
    return bytes(r)


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    for name, (fam, size) in ROMS.items():
        open(os.path.join(out, name), "wb").write(rom(fam, size))
        print(f"{name}\t{ROMTYPE[fam][size]}")
    print(f"end loop {END:04X} (TRACEPC=${END + 1:04X})")


if __name__ == "__main__":
    main()
