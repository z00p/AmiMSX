"""DAA test cartridge (16 KB, page 1). For each case below it runs, for every
A from 00h to FFh: F = the case's flags (via PUSH/POP), the instruction, DAA,
then A and F (S Z P/V C only: AmiMSX doesn't model H, N, X and Y) go into a
16-bit checksum (rotate left, add the byte). It prints one line per case,
"INC 00 xxxx", in SCREEN 0 through the BIOS (INITXT, CHPUT), and stops.
The expected checksums come from the Z80's DAA (the model below).
The INC A / DEC A cases are issue #3: DEC A from 00h, then DAA, is 99h on a
Z80 (Invasion of the Zombie Monsters keeps its lives that way).
Usage: python tools/make_daatest.py out.rom"""
import sys

CASES = [("INC", 0x3C, None, 0x00), ("INC", 0x3C, None, 0x01),
         ("DEC", 0x3D, None, 0x00), ("DEC", 0x3D, None, 0x01),
         ("ADD", 0xC6, 0x01, 0x00), ("SUB", 0xD6, 0x01, 0x00),
         ("ADD", 0xC6, 0x27, 0x00), ("SUB", 0xD6, 0x27, 0x00)]
CHK, RES, STK, TAB = 0xC000, 0xC010, 0xF000, 0xD000
MASK = 0xC5                                     # S Z P/V C


def parity(v):
    return 0x04 if bin(v).count("1") % 2 == 0 else 0


def op(name, n, a, f):
    """(A, F) after the instruction: only C, H, N matter for DAA."""
    c = f & 1
    if name == "INC":
        r, h, nf = (a + 1) & 255, (a & 15) == 15, 0
    elif name == "DEC":
        r, h, nf = (a - 1) & 255, (a & 15) == 0, 1
    elif name == "ADD":
        r, h, nf, c = (a + n) & 255, (a & 15) + (n & 15) > 15, 0, int(a + n > 255)
    else:
        r, h, nf, c = (a - n) & 255, (a & 15) < (n & 15), 1, int(a < n)
    return r, (0x10 if h else 0) | (0x02 if nf else 0) | c


def daa(a, f):
    c, h, n = f & 1, f & 0x10, f & 0x02
    corr, cout = 0, c
    if h or (a & 15) > 9:
        corr |= 0x06
    if c or a > 0x99:
        corr |= 0x60
        cout = 1
    r = (a - corr if n else a + corr) & 255
    return r, (r & 0x80) | (0x40 if r == 0 else 0) | parity(r) | cout


def main():
    code = [0xF3, 0x31, STK & 255, STK >> 8]           # DI; LD SP,F000h
    lab, fix, expect = {}, [], []

    def call(name):
        code.extend([0xCD, 0, 0])
        fix.append((len(code) - 2, name))

    for i, (name, opc, n, f) in enumerate(CASES):
        code.extend([0x21, 0, 0, 0x22, CHK & 255, CHK >> 8])       # checksum = 0
        code.extend([0x1E, 0x00, 0x0E, f])                         # E = A, C = F
        loop = len(code)
        code.extend([0x63, 0x69, 0xE5, 0xF1])                      # LD H,E; LD L,C; PUSH HL; POP AF
        code.extend([opc] + ([n] if n is not None else []))
        code.extend([0x27, 0xF5, 0xE1])                            # DAA; PUSH AF; POP HL
        code.extend([0x7D, 0xE6, MASK, 0x6F])                      # LD A,L; AND MASK; LD L,A
        tab = TAB + 0x200 * i                                      # (tab + 2A) = F, A after DAA
        code.extend([0xD5, 0xE5, 0x6B, 0x26, 0x00, 0x29, 0x11, tab & 255, tab >> 8, 0x19,
                     0xD1, 0x73, 0x23, 0x72, 0xEB, 0xD1])
        # PUSH DE; PUSH HL; LD L,E; LD H,0; ADD HL,HL; LD DE,tab; ADD HL,DE; POP DE;
        # LD (HL),E; INC HL; LD (HL),D; EX DE,HL; POP DE
        call("acc")
        code.extend([0x1C, 0x20, (loop - (len(code) + 3)) & 255])  # INC E; JR NZ,loop
        code.extend([0x2A, CHK & 255, CHK >> 8, 0x22, (RES + 2 * i) & 255, (RES + 2 * i) >> 8])
        c = 0
        for a in range(256):
            r, rf = daa(*op(name, n, a, f))
            for byte in (r, rf & MASK):
                c = ((c << 1) | (c >> 15)) & 0xFFFF
                c = (c + byte) & 0xFFFF
        expect.append(("%s %02X" % (name, n if n is not None else f), c))
    code.extend([0xCD, 0x6C, 0x00, 0xCD, 0x44, 0x00, 0xFB])         # INITXT; ENASCR; EI
    for i, (txt, c) in enumerate(expect):
        for ch in txt + " ":
            code.extend([0x3E, ord(ch), 0xCD, 0xA2, 0x00])
        code.extend([0x2A, (RES + 2 * i) & 255, (RES + 2 * i) >> 8, 0x7C])
        call("hex")
        code.append(0x7D)
        call("hex")
        code.extend([0x3E, 13, 0xCD, 0xA2, 0x00, 0x3E, 10, 0xCD, 0xA2, 0x00])
    code.extend([0x18, 0xFE])                                      # JR $
    # acc: checksum += H then L, rotate left before each (keeps C, E)
    lab["acc"] = len(code)
    code.extend([0xC5, 0x44, 0x4D, 0x2A, CHK & 255, CHK >> 8,     # PUSH BC; LD B,H; LD C,L; LD HL,(CHK)
                 0x29, 0x30, 0x01, 0x23,                           # ADD HL,HL; JR NC,+1; INC HL
                 0x78, 0x85, 0x6F, 0x30, 0x01, 0x24,               # LD A,B; ADD A,L; LD L,A; JR NC,+1; INC H
                 0x29, 0x30, 0x01, 0x23,
                 0x79, 0x85, 0x6F, 0x30, 0x01, 0x24,               # LD A,C; ...
                 0x22, CHK & 255, CHK >> 8, 0xC1, 0xC9])           # LD (CHK),HL; POP BC; RET
    # hex: print A as two hex digits (keeps HL)
    lab["hex"] = len(code)
    code.extend([0xF5, 0x0F, 0x0F, 0x0F, 0x0F])
    call("dig")
    code.extend([0xF1])
    lab["dig"] = len(code)
    code.extend([0xE6, 0x0F, 0xC6, 0x90, 0x27, 0xCE, 0x40, 0x27,   # AND 0Fh / ADD 90h / DAA / ADC 40h / DAA
                 0xE5, 0xCD, 0xA2, 0x00, 0xE1, 0xC9])
    base = 0x4010
    for off, name in fix:
        adr = base + lab[name]
        code[off], code[off + 1] = adr & 255, adr >> 8
    rom = bytearray([0xFF] * 0x4000)
    rom[0:4] = b"AB\x10\x40"
    assert 0x10 + len(code) <= 0x4000, len(code)
    rom[0x10:0x10 + len(code)] = bytes(code)
    open(sys.argv[1], "wb").write(rom)
    for txt, c in expect:
        print("%s %04X" % (txt, c))


main()
