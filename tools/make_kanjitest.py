"""Turbo R kanji ROM port test cartridge (16 KB, page 1), for the FS-A1GT.
Latches addresses on both port pairs (level 1: D8h/D9h, read D9h; level 2:
DAh/DBh, read DBh), reads, and prints the bytes in hex, one test a line:
  P0  D9h, D9h, DBh, DBh as the BIOS left the latches (no write first)
  1A  level 1, D8h=15h D9h=07h, bytes 0-7 of 40 read (INIR)
  1W  the same read, bytes 32-39 (the 5-bit counter wraps: = 1A)
  2A  level 2, DAh=15h DBh=07h, bytes 0-7;  2W  bytes 32-39
  IX  both latched (L1, L2 below), reads mixed: D9 D9 DB D9 DB DB D9 DB
  R1  level 1 (lo 1Ch, hi 10h): 3 reads, lo again, 2 reads, hi again, 1
      read, lo = 1Eh, 1 read; then hi, lo = 1Eh, 1 read
  R2  the same on DAh/DBh (lo 14h, hi 0Ch, then 16h)
  MK  R1's and R2's latch values with bits 6-7 set, 2 reads each
  RD  both latched: IN D8 D9 D8 D9 DA DB DA DB (reads of D8h/DAh)
  X2  DAh/DBh latched, 1 read; D8h=11h D9h=12h, DB 1 read; DAh again, DB 1
  TP  D9h=3Fh D8h=3Fh 2 reads; DBh=3Fh DAh=3Fh 2 reads (the top)
  S1  level 1 whole font (D9h 0-3F, D8h 0-3F, 32 reads each): sum16, rotxor8
  S2  level 2 the same
--model FONT prints what openMSX's rules (MSXKanji: adr1/adr2, the counter in
bits 0-4, reset by a write to either port, bit 17 always set on level 2,
D8h/DAh read FFh) give with that font file.
Usage: python tools/make_kanjitest.py out.rom [--model font.rom]"""
import sys

BASE = 0x4010
INITXT, CHPUT, ENASCR = 0x006C, 0x00A2, 0x0044
BUF = 0xC000                  # 16 bytes a test
IBUF1, IBUF2 = 0xC200, 0xC240  # the 40-byte INIR reads
VARS = 0xC300


class Asm:
    def __init__(self):
        self.code, self.lab, self.fix = [], {}, []

    def b(self, *v):
        self.code.extend(v)

    def here(self, name):
        self.lab[name] = len(self.code)

    def jr(self, opc, name):
        self.code.extend([opc, 0])
        self.fix.append(("r", len(self.code) - 1, name))

    def call(self, name):
        self.code.extend([0xCD, 0, 0])
        self.fix.append(("a", len(self.code) - 2, name))

    def text(self, s):
        for ch in s:
            self.b(0x3E, ord(ch), 0xCD, CHPUT & 255, CHPUT >> 8)

    def ld_hl(self, v):
        self.b(0x21, v & 255, v >> 8)

    def out(self, port, v):
        self.b(0x3E, v, 0xD3, port)                     # LD A,v; OUT (port),A

    def rec(self, port):
        self.b(0xDB, port, 0x77, 0x23)                  # IN A,(port); LD (HL),A; INC HL

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


# The tests as (label, [ops]); op: ("o", port, value) or ("i", port).
# Cells with varied bytes: level 1 D9h=10h D8h=1Ch (and 1Eh), level 2
# DBh=0Ch DAh=14h (and 16h).
L1 = (0xD8, 0xD9, 0x1C, 0x10, 0x1E)
L2 = (0xDA, 0xDB, 0x14, 0x0C, 0x16)


def tests():
    t = []
    t.append(("P0", [("i", 0xD9), ("i", 0xD9), ("i", 0xDB), ("i", 0xDB)]))
    t.append(("IX", [("o", 0xD8, L1[2]), ("o", 0xD9, L1[3]), ("o", 0xDA, L2[2]), ("o", 0xDB, L2[3])]
              + [("i", p) for p in (0xD9, 0xD9, 0xDB, 0xD9, 0xDB, 0xDB, 0xD9, 0xDB)]))
    for lab, (lo, hi, vl, vh, vl2) in (("R1", L1), ("R2", L2)):
        t.append((lab, [("o", lo, vl), ("o", hi, vh), ("i", hi), ("i", hi), ("i", hi),
                        ("o", lo, vl), ("i", hi), ("i", hi), ("o", hi, vh), ("i", hi),
                        ("o", lo, vl2), ("i", hi), ("o", hi, vh), ("o", lo, vl2), ("i", hi)]))
    t.append(("MK", [("o", 0xD8, L1[2] | 0xC0), ("o", 0xD9, L1[3] | 0xC0), ("i", 0xD9), ("i", 0xD9),
                     ("o", 0xDA, L2[2] | 0xC0), ("o", 0xDB, L2[3] | 0xC0), ("i", 0xDB), ("i", 0xDB)]))
    t.append(("RD", [("o", 0xD8, L1[2]), ("o", 0xD9, L1[3]), ("o", 0xDA, L2[2]), ("o", 0xDB, L2[3])]
              + [("i", p) for p in (0xD8, 0xD9, 0xD8, 0xD9, 0xDA, 0xDB, 0xDA, 0xDB)]))
    t.append(("X2", [("o", 0xDA, L2[2]), ("o", 0xDB, L2[3]), ("i", 0xDB), ("o", 0xD8, 0x11),
                     ("o", 0xD9, 0x12), ("i", 0xDB), ("o", 0xDA, L2[2]), ("i", 0xDB)]))
    t.append(("TP", [("o", 0xD9, 0x3F), ("o", 0xD8, 0x3F), ("i", 0xD9), ("i", 0xD9),
                     ("o", 0xDB, 0x3F), ("o", 0xDA, 0x3F), ("i", 0xDB), ("i", 0xDB)]))
    return t


def model(font):
    """openMSX MSXKanji with a 256 KB font: the lines the cartridge should print."""
    st = {"a1": 0, "a2": 0x20000}

    def w(port, v):
        v &= 0x3F
        if port == 0xD8: st["a1"] = (st["a1"] & 0x1F800) | (v << 5)
        if port == 0xD9: st["a1"] = (st["a1"] & 0x007E0) | (v << 11)
        if port == 0xDA: st["a2"] = (st["a2"] & 0x3F800) | (v << 5)
        if port == 0xDB: st["a2"] = (st["a2"] & 0x207E0) | (v << 11)

    def r(port):
        if port == 0xD9:
            x = font[st["a1"]]; st["a1"] = (st["a1"] & ~0x1F) | ((st["a1"] + 1) & 0x1F); return x
        if port == 0xDB:
            x = font[st["a2"]]; st["a2"] = (st["a2"] & ~0x1F) | ((st["a2"] + 1) & 0x1F); return x
        return 0xFF

    lines = []
    tl = tests()
    # P0 depends on the BIOS: not modelled
    lines.append("P0 (BIOS)")
    for lab, lo, hi in (("1", 0xD8, 0xD9), ("2", 0xDA, 0xDB)):
        w(lo, 0x15); w(hi, 0x07)
        v = [r(hi) for _ in range(40)]
        lines.append(f"{lab}A " + "".join(f"{x:02X}" for x in v[0:8]))
        lines.append(f"{lab}W " + "".join(f"{x:02X}" for x in v[32:40]))
    for lab, ops in tl[1:]:
        out = []
        for op in ops:
            if op[0] == "o": w(op[1], op[2])
            else: out.append(r(op[1]))
        lines.append(f"{lab} " + "".join(f"{x:02X}" for x in out))
    for lab, lo, hi in (("S1", 0xD8, 0xD9), ("S2", 0xDA, 0xDB)):
        s, h = 0, 0
        for a in range(64):
            w(hi, a)
            for c in range(64):
                w(lo, c)
                for _ in range(32):
                    x = r(hi)
                    s = (s + x) & 0xFFFF
                    h = (((h << 1) | (h >> 7)) & 0xFF) ^ x
        lines.append(f"{lab} {s:04X}{h:02X}")
    return lines


def main():
    a = Asm()
    a.b(0xF3, 0x31, 0x00, 0xF0)                    # DI; LD SP,F000h
    a.b(0xCD, INITXT & 255, INITXT >> 8)           # INITXT
    a.b(0xCD, ENASCR & 255, ENASCR >> 8, 0xF3)     # ENASCR; DI
    tl = tests()
    # P0 first, before any write
    lab, ops = tl[0]
    a.ld_hl(BUF)
    for op in ops:
        a.rec(op[1])
    a.text(lab + " "); a.ld_hl(BUF); a.b(0x06, len(ops)); a.call("dump"); a.call("crlf")
    # 1A/1W, 2A/2W: 40 bytes by INIR
    for lab, lo, hi, ib in (("1", 0xD8, 0xD9, IBUF1), ("2", 0xDA, 0xDB, IBUF2)):
        a.out(lo, 0x15); a.out(hi, 0x07)
        a.ld_hl(ib); a.b(0x06, 40, 0x0E, hi, 0xED, 0xB2)   # LD B,40; LD C,hi; INIR
        a.text(lab + "A "); a.ld_hl(ib); a.b(0x06, 8); a.call("dump"); a.call("crlf")
        a.text(lab + "W "); a.ld_hl(ib + 32); a.b(0x06, 8); a.call("dump"); a.call("crlf")
    for k, (lab, ops) in enumerate(tl[1:], 1):
        buf = BUF + 16 * k
        a.ld_hl(buf)
        n = 0
        for op in ops:
            if op[0] == "o":
                a.out(op[1], op[2])
            else:
                a.rec(op[1]); n += 1
        a.text(lab + " "); a.ld_hl(buf); a.b(0x06, n); a.call("dump"); a.call("crlf")
    for lab, lo, hi in (("S1", 0xD8, 0xD9), ("S2", 0xDA, 0xDB)):
        hv, lv = VARS, VARS + 1
        a.b(0x11, 0, 0, 0x26, 0)                   # LD DE,0; LD H,0
        a.b(0xAF, 0x32, hv & 255, hv >> 8)         # XOR A; LD (hv),A
        a.here(lab + "h")
        a.b(0x3A, hv & 255, hv >> 8, 0xD3, hi)     # LD A,(hv); OUT (hi),A
        a.b(0xAF, 0x32, lv & 255, lv >> 8)         # XOR A; LD (lv),A
        a.here(lab + "l")
        a.b(0x3A, lv & 255, lv >> 8, 0xD3, lo)     # LD A,(lv); OUT (lo),A
        a.b(0x06, 32)                              # LD B,32
        a.here(lab + "r")
        a.b(0xDB, hi, 0x6F, 0x83, 0x5F, 0x7A, 0xCE, 0x00, 0x57,   # IN; LD L,A; ADD A,E; LD E,A;
            0x7C, 0x07, 0xAD, 0x67)                # LD A,D; ADC A,0; LD D,A; LD A,H; RLCA; XOR L; LD H,A
        a.jr(0x10, lab + "r")                      # DJNZ
        a.b(0x3A, lv & 255, lv >> 8, 0x3C, 0x32, lv & 255, lv >> 8, 0xFE, 0x40)
        a.jr(0x20, lab + "l")
        a.b(0x3A, hv & 255, hv >> 8, 0x3C, 0x32, hv & 255, hv >> 8, 0xFE, 0x40)
        a.jr(0x20, lab + "h")
        a.b(0xE5, 0xD5)                            # PUSH HL; PUSH DE
        a.text(lab + " ")
        a.b(0xD1, 0x7A); a.call("hex")             # POP DE; LD A,D
        a.b(0x7B); a.call("hex")                   # LD A,E
        a.b(0xE1, 0x7C); a.call("hex")             # POP HL; LD A,H
        a.call("crlf")
    a.text("END")
    a.here("stop")
    a.jr(0x18, "stop")
    # dump: B bytes from (HL) in hex
    a.here("dump")
    a.b(0x7E, 0xE5, 0xC5); a.call("hex"); a.b(0xC1, 0xE1, 0x23)
    a.jr(0x10, "dump")
    a.b(0xC9)
    a.here("crlf")
    a.text("\r\n")
    a.b(0xC9)
    a.here("hex")
    a.b(0xF5, 0x0F, 0x0F, 0x0F, 0x0F)
    a.call("dig")
    a.b(0xF1)
    a.here("dig")
    a.b(0xE6, 0x0F, 0xC6, 0x90, 0x27, 0xCE, 0x40, 0x27,
        0xCD, CHPUT & 255, CHPUT >> 8, 0xC9)
    code = a.done()
    assert len(code) < 0x3FF0
    rom = bytearray([0xFF] * 0x4000)
    rom[0:4] = b"AB\x10\x40"
    rom[0x10:0x10 + len(code)] = code
    open(sys.argv[1], "wb").write(rom)
    if "--model" in sys.argv:
        font = open(sys.argv[sys.argv.index("--model") + 1], "rb").read()
        print("\n".join(model(font)))


main()
