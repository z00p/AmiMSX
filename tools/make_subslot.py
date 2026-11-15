"""Expanded-slot test cartridge (16 KB, page 1) for C-BIOS on a machine whose
slots 0 and 3 are expanded (0-0 BIOS, 3-0 the RAM mapper, the other
sub-slots empty): the AmiMSX TURBOR build, or openMSX with the same layout.
Interrupts off; it prints one line per test through the BIOS (INITXT,
CHPUT), bytes in hex:

T1  EXPTBL (FCC1h-FCC4h) as the BIOS found it (80 00 00 80 here).
T2  slot 3's register as read at FFFFh (inverted), and that byte.
T3  page 0 in slot 3: 3-0 RAM write/read 5Ah; 3-1 (empty) read, write 33h
    and read again (FF FF); 3-0 again (5A).
T4  page 3 to 3-1 (no stack): C000h (FF) and FFFFh (the inverted value
    just written); back to 3-0, FFFFh (slot 3's register inverted).
T5  page 3 to slot 0 (no stack): FFFFh (slot 0's register inverted),
    C000h (FF); page 0 to 0-1: 0000h (FF); back to 0-0: 0000h (BIOS F3).
T6  mapper with page 2 in slot 3: segments 4 = 77h and 5 = 66h at 8000h;
    page 2 to 3-1, OUT (FEh),4 while hidden: 8000h (FF); back to 3-0:
    8000h (77, the segment chosen while hidden).
T7  the page-3 segment (0) through page 2: write A5h at BFFFh, read it,
    then FFFFh through page 3 (a real expanded slot: the register, not A5).
Usage: python tools/make_subslot.py out.rom"""
import sys

RES, SAV = 0xC800, 0xC880          # results; A8, slot 3 register, slot 0 register
BASE = 0x4010


def w(v):
    return [v & 255, v >> 8]


def main():
    c = []
    lab, fix = {}, []

    def ld_a(n): c.extend([0x3E, n])
    def lda(adr): c.extend([0x3A] + w(adr))        # LD A,(adr)
    def sta(adr): c.extend([0x32] + w(adr))        # LD (adr),A
    def out(p): c.extend([0xD3, p])
    nres = [0]

    def res():                                      # LD (RES+n),A
        sta(RES + nres[0])
        nres[0] += 1
        return nres[0] - 1

    lines = []
    c.extend([0xF3])                                # DI
    in_a8 = [0xDB, 0xA8]
    c.extend(in_a8); sta(SAV)                       # A8 as found
    lda(0xFFFF); c.append(0x2F); sta(SAV + 1)       # slot 3 register (page 3 is slot 3)
    # T1, T2
    t = []
    for i in range(4):
        lda(0xFCC1 + i); t.append(res())
    lines.append(("T1", t))
    t = []
    lda(SAV + 1); t.append(res())
    lda(0xFFFF); t.append(res())
    lines.append(("T2", t))
    # T3: page 0 in slot 3
    t = []
    lda(SAV); c.extend([0xF6, 0x03]); out(0xA8)     # OR 3: page 0 -> slot 3
    lda(SAV + 1); c.extend([0xE6, 0xFC]); sta(0xFFFF)   # page 0 -> 3-0
    ld_a(0x5A); sta(0x0010); lda(0x0010); t.append(res())
    lda(SAV + 1); c.extend([0xE6, 0xFC, 0xF6, 0x01]); sta(0xFFFF)   # page 0 -> 3-1
    lda(0x0010); t.append(res())
    ld_a(0x33); sta(0x0010); lda(0x0010); t.append(res())
    lda(SAV + 1); c.extend([0xE6, 0xFC]); sta(0xFFFF)   # 3-0 again
    lda(0x0010); t.append(res())
    lda(SAV + 1); sta(0xFFFF)                       # register as it was
    lda(SAV); out(0xA8)
    lines.append(("T3", t))
    # T4: page 3 -> 3-1, no stack, results in B C D
    # (page 3 is not readable RAM meanwhile: the register is kept in E)
    lda(SAV + 1); c.append(0x5F)                    # LD E,A
    c.extend([0xE6, 0x3F, 0xF6, 0x40]); sta(0xFFFF)
    lda(0xC000); c.append(0x47)                     # LD B,A
    lda(0xFFFF); c.append(0x4F)                     # LD C,A
    c.append(0x7B); sta(0xFFFF)                     # LD A,E: page 3 back to 3-0
    lda(0xFFFF); c.append(0x57)                     # LD D,A
    t = []
    for r in (0x78, 0x79, 0x7A):                    # LD A,B / C / D
        c.append(r); t.append(res())
    lines.append(("T4", t))
    # T5: page 3 -> slot 0, no stack, results in B C D H
    lda(SAV); c.extend([0xD9, 0x47, 0xD9])          # B' = A8 as found (EXX)
    c.extend([0xE6, 0x3F]); c.append(0x6F)          # L = A8 with page 3 -> slot 0
    c.append(0x7D); out(0xA8)                       # LD A,L; OUT (A8h),A
    lda(0xFFFF); c.append(0x47)                     # B = ~slot 0 register
    lda(0xC000); c.append(0x4F)                     # C
    c.extend([0x78, 0x2F, 0x5F])                    # LD A,B; CPL; LD E,A (slot 0 register)
    c.extend([0xE6, 0xFC, 0xF6, 0x01]); sta(0xFFFF) # page 0 -> 0-1
    lda(0x0000); c.append(0x57)                     # D
    c.append(0x7B); sta(0xFFFF)                     # LD A,E: back
    lda(0x0000); c.append(0x67)                     # H
    c.extend([0xD9, 0x78, 0xD9]); out(0xA8)        # A8 back from B' (page 3 to slot 3)
    t = []
    for r in (0x78, 0x79, 0x7A, 0x7C):
        c.append(r); t.append(res())
    lines.append(("T5", t))
    # T6: mapper with page 2 in slot 3
    t = []
    lda(SAV); c.extend([0xF6, 0x30]); out(0xA8)     # page 2 -> slot 3
    ld_a(4); out(0xFE); ld_a(0x77); sta(0x8000)
    ld_a(5); out(0xFE); ld_a(0x66); sta(0x8000)
    lda(SAV + 1); c.extend([0xE6, 0xCF, 0xF6, 0x10]); sta(0xFFFF)   # page 2 -> 3-1
    ld_a(4); out(0xFE)
    lda(0x8000); t.append(res())
    lda(SAV + 1); sta(0xFFFF)                       # 3-0 again
    lda(0x8000); t.append(res())
    lines.append(("T6", t))
    # T7: the page-3 segment through page 2
    t = []
    ld_a(0); out(0xFE)
    ld_a(0xA5); sta(0xBFFF); lda(0xBFFF); t.append(res())
    lda(0xFFFF); t.append(res())
    ld_a(1); out(0xFE)
    lda(SAV); out(0xA8)
    lines.append(("T7", t))
    # print
    c.extend([0xCD, 0x6C, 0x00])                    # INITXT
    for name, idx in lines:
        for ch in name + " ":
            c.extend([0x3E, ord(ch), 0xCD, 0xA2, 0x00])
        for i in idx:
            lda(RES + i); c.extend([0xCD]); fix.append((len(c), "hex")); c.extend([0, 0])
            c.extend([0x3E, 32, 0xCD, 0xA2, 0x00])
        c.extend([0x3E, 13, 0xCD, 0xA2, 0x00, 0x3E, 10, 0xCD, 0xA2, 0x00])
    c.extend([0x18, 0xFE])                          # JR $
    lab["hex"] = len(c)
    c.extend([0xF5, 0x0F, 0x0F, 0x0F, 0x0F, 0xCD]); fix.append((len(c), "dig")); c.extend([0, 0])
    c.extend([0xF1])
    lab["dig"] = len(c)
    c.extend([0xE6, 0x0F, 0xC6, 0x90, 0x27, 0xCE, 0x40, 0x27,
              0xE5, 0xCD, 0xA2, 0x00, 0xE1, 0xC9])
    for off, name in fix:
        adr = BASE + lab[name]
        c[off], c[off + 1] = adr & 255, adr >> 8
    rom = bytearray([0xFF] * 0x4000)
    rom[0:4] = b"AB\x10\x40"
    assert 0x10 + len(c) <= 0x4000, len(c)
    rom[0x10:0x10 + len(c)] = bytes(c)
    open(sys.argv[1], "wb").write(rom)


if __name__ == "__main__":
    main()
