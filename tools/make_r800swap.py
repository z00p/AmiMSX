"""turbo R CPU switch test cartridge (16 KB, page 1): checks that the Z80 and
the R800 keep a register file each across S1990 register 6 switches (index
on E4h, data on E5h), as openMSX does. Runs on C-BIOS (or any BIOS) on a
machine with an S1990 and an R800; no turbo R BIOS needed.

1. Z80: DI, RAM into page 0 (the slot of page 3), "JP R8E" at 0000h, then
   every register to known values (ZV) and OUT (E5h),00h: the R800 runs.
2. R800 (from 0000h, its power-on state): dumps its registers (buffer R0),
   loads its own values (RV), OUT (E5h),60h: the Z80 runs.
3. Z80 (after its OUT): dumps its registers (buffer Z1) and switches again.
4. R800 (after its OUT): dumps its registers (buffer R1) and switches back.
5. Z80: slots back, SCREEN 0 (INITXT), prints the three buffers through the
   BIOS (CHPUT): "R0", "Z1", "R1", each SP AF BC DE HL IX / IY AF' BC' DE'
   HL' I. Z1 must be ZV and R1 must be RV (A is the switch value); R0 is
   the R800's power-on state, compared with openMSX.
Usage: python tools/make_r800swap.py out.rom"""
import sys

ZV = dict(SP=0xE800, AF=0x00D7, BC=0x1234, DE=0x5678, HL=0x9ABC, IX=0xDEF0,
          IY=0x1357, AF_=0x246B, BC_=0x1122, DE_=0x3344, HL_=0x5566, I=0x5A)
RV = dict(SP=0xE400, AF=0x60A9, BC=0x8765, DE=0x4321, HL=0x0FED, IX=0xCBA9,
          IY=0x7531, AF_=0x8642, BC_=0x99AA, DE_=0xBBCC, HL_=0xDDEE, I=0xA5)
ORDER = ["SP", "AF", "BC", "DE", "HL", "IX", "IY", "AF_", "BC_", "DE_", "HL_", "I"]
BUF = {"R0": 0xC100, "Z1": 0xC120, "R1": 0xC140}    # SP, then 10 words, then I
TAB = {"Z": 0xC180, "R": 0xC1A0}                     # register tables for POP
SAV = 0xC1F0                                         # A8, subslot, SP, expanded flag
BASE = 0x4010


def w(v):
    return [v & 255, v >> 8]


def page0_ram(sav):
    """Z80 code: RAM into page 0 (the slot of page 3: A8 bits 0-1 = bits
    6-7; if that slot is expanded, EXPTBL bit 7, its sub-slot register
    likewise). Keeps A8 at sav, the sub-slot register at sav+1, the EXPTBL
    byte at sav+4. Trashes AF BC DE HL."""
    c = [0xDB, 0xA8, 0x32] + w(sav)                     # IN A,(A8h); LD (sav),A
    c += [0x47, 0x07, 0x07, 0xE6, 0x03, 0x4F]           # LD B,A; RLCA x2; AND 3; LD C,A
    # LD HL,EXPTBL (FCC1h); LD A,L; ADD A,C; LD L,A; LD A,(HL); LD (sav+4),A
    c += [0x21, 0xC1, 0xFC, 0x7D, 0x81, 0x6F, 0x7E, 0x32] + w(sav + 4)
    exp = [0x3A, 0xFF, 0xFF, 0x2F, 0x32] + w(sav + 1)   # LD A,(FFFFh); CPL; LD (sav+1),A
    exp += [0x57, 0x07, 0x07, 0xE6, 0x03, 0x5F]         # LD D,A; RLCA x2; AND 3; LD E,A
    exp += [0x7A, 0xE6, 0xFC, 0xB3, 0x32, 0xFF, 0xFF]   # LD A,D; AND FCh; OR E; LD (FFFFh),A
    c += [0xE6, 0x80, 0x28, len(exp)] + exp             # AND 80h; JR Z (not expanded)
    c += [0x78, 0xE6, 0xFC, 0xB1, 0xD3, 0xA8]           # LD A,B; AND FCh; OR C; OUT (A8h),A
    return c


def page0_back(sav):
    """Z80 code: page 0 back as page0_ram found it. Trashes AF."""
    c = [0x3A] + w(sav + 4) + [0xE6, 0x80, 0x28, 6]     # expanded?
    c += [0x3A] + w(sav + 1) + [0x32, 0xFF, 0xFF]       # sub-slot register back
    c += [0x3A] + w(sav) + [0xD3, 0xA8]                 # A8 back
    return c


def main():
    code = []
    lab, fix = {}, []

    def ref(name):                                   # 16-bit address of a label
        fix.append((len(code), name))
        code.extend([0, 0])

    def dump(buf):
        # LD (buf),SP; LD SP,buf+22; PUSH AF BC DE HL IX IY; EXX; EX AF,AF';
        # PUSH AF BC DE HL (the alternates); LD A,I; LD (buf+22),A
        b = BUF[buf]
        code.extend([0xED, 0x73] + w(b) + [0x31] + w(b + 22))
        code.extend([0xF5, 0xC5, 0xD5, 0xE5, 0xDD, 0xE5, 0xFD, 0xE5, 0xD9, 0x08,
                     0xF5, 0xC5, 0xD5, 0xE5, 0xED, 0x57, 0x32] + w(b + 22))

    def load(t, vals):
        # LD A,i; LD I,A; LD SP,table; POP IY IX HL DE BC AF; EXX; EX AF,AF';
        # POP HL DE BC AF; EX AF,AF'; EXX; LD SP,sp
        code.extend([0x3E, vals["I"], 0xED, 0x47, 0x31] + w(TAB[t]))
        code.extend([0xFD, 0xE1, 0xDD, 0xE1, 0xE1, 0xD1, 0xC1, 0xF1, 0xD9, 0x08,
                     0xE1, 0xD1, 0xC1, 0xF1, 0x08, 0xD9, 0x31] + w(vals["SP"]))

    def table(t, vals):
        # the POP order: IY IX HL DE BC AF, then HL' DE' BC' AF'
        ws = [vals[k] for k in ("IY", "IX", "HL", "DE", "BC", "AF", "HL_", "DE_", "BC_", "AF_")]
        data = sum((w(v) for v in ws), [])
        # LD HL,table data in ROM; LD DE,TAB; LD BC,20; LDIR
        code.extend([0x21]); ref("tab" + t)
        code.extend([0x11] + w(TAB[t]) + [0x01, 20, 0, 0xED, 0xB0])
        return data

    # --- 1. Z80 set-up
    code.extend([0xF3, 0xED, 0x73] + w(SAV + 2))     # DI; LD (SAV+2),SP
    data_z = table("Z", ZV)
    data_r = table("R", RV)
    code.extend(page0_ram(SAV))
    code.extend([0x3E, 0xC3, 0x32, 0x00, 0x00, 0x21]); ref("r8e")
    code.extend([0x22, 0x01, 0x00])                  # (0000h) = JP r8e
    code.extend([0x3E, 6, 0xD3, 0xE4])               # S1990 index 6
    load("Z", ZV)
    code.extend([0xD3, 0xE5])                        # OUT (E5h),A (A = 00h): R800
    # --- 3. Z80 again
    dump("Z1")
    code.extend([0x31] + w(ZV["SP"]) + [0xAF, 0xD3, 0xE5])  # XOR A; OUT (E5h),A: R800
    # --- 5. Z80, last
    code.extend(page0_back(SAV))
    code.extend([0xED, 0x7B] + w(SAV + 2))           # LD SP,(SAV+2)
    code.extend([0xCD, 0x6C, 0x00])                  # INITXT
    for name in ("R0", "Z1", "R1"):
        b = BUF[name]
        for i, k in enumerate(ORDER):
            if i in (0, 6):
                txt = (name + " ") if i == 0 else "   "
                for ch in txt:
                    code.extend([0x3E, ord(ch), 0xCD, 0xA2, 0x00])
            if k == "SP":
                adr = b
            elif k == "I":
                adr = None
            else:                                    # pushed downward from b+22
                adr = b + 20 - 2 * (i - 1)
            if k == "I":
                code.extend([0x3A] + w(b + 22)); code.extend([0xCD]); ref("hex")
            else:
                code.extend([0x2A] + w(adr) + [0x7C]); code.extend([0xCD]); ref("hex")
                code.append(0x7D); code.extend([0xCD]); ref("hex")
            code.extend([0x3E, 32, 0xCD, 0xA2, 0x00])
            if i in (5, 11):
                code.extend([0x3E, 13, 0xCD, 0xA2, 0x00, 0x3E, 10, 0xCD, 0xA2, 0x00])
    code.extend([0x18, 0xFE])                        # JR $
    # --- 2. and 4. R800
    lab["r8e"] = len(code)
    dump("R0")
    load("R", RV)
    code.extend([0xD3, 0xE5])                        # OUT (E5h),A (A = 60h): Z80
    dump("R1")
    code.extend([0x3E, 0x60, 0xD3, 0xE5])            # Z80
    code.extend([0x18, 0xFE])                        # (not reached)
    # hex: print A as two hex digits (keeps HL)
    lab["hex"] = len(code)
    code.extend([0xF5, 0x0F, 0x0F, 0x0F, 0x0F, 0xCD]); ref("dig")
    code.extend([0xF1])
    lab["dig"] = len(code)
    code.extend([0xE6, 0x0F, 0xC6, 0x90, 0x27, 0xCE, 0x40, 0x27,
                 0xE5, 0xCD, 0xA2, 0x00, 0xE1, 0xC9])
    lab["tabZ"] = len(code); code.extend(data_z)
    lab["tabR"] = len(code); code.extend(data_r)
    for off, name in fix:
        adr = BASE + lab[name]
        code[off], code[off + 1] = adr & 255, adr >> 8
    rom = bytearray([0xFF] * 0x4000)
    rom[0:4] = b"AB\x10\x40"
    assert 0x10 + len(code) <= 0x4000, len(code)
    rom[0x10:0x10 + len(code)] = bytes(code)
    open(sys.argv[1], "wb").write(rom)
    for name, vals in (("Z1", ZV), ("R1", RV)):
        print(name, " ".join("%04X" % vals[k] if k != "I" else "%02X" % vals[k] for k in ORDER))


if __name__ == "__main__":
    main()
