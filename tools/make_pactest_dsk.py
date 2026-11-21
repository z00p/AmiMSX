"""FM-PAC SRAM test (5.3): a 720 KB disk whose AUTOEXEC.BAS runs a machine-code
check of the FM-PAC in Slot 1 (Sound PSG+FM, MSXMUSIC.ROM, Slot 1 empty) and
prints what it read, a line per step:
  1 ID      4018h-401Fh (the ROM's ID)
  2 ROM     5FFEh 5FFFh 7FF6h 7FF7h, then 4010h before and after writing 5Ah
            there with FFFFh in 5FFEh (ROM: unchanged)
  3 ON16    LD (5FFEh),HL with 694Dh: 5FFEh 5FFFh, 4000h-4007h (the SRAM as
            found: FFh blank, or the last run's), 6000h 7FF6h 7FF7h
  4 WRITE   INC (4000h), "PAC!" at 4001h-4004h (LD (HL),n), 5FFDh = (4000h)
            (LD (nn),A); then 4000h-4004h and 5FFDh read back
  5 OFF8    XOR A, LD (5FFEh),A: 4000h 5FFEh (the ROM again)
  6 ON8     4Dh/69h by LD (nn),A: 4000h
  7 EN10    7FF6h = 10h: 4000h 7FF6h; 4Dh/69h again: 4000h (still the ROM);
            7FF6h = 0, 4Dh/69h: 4000h (the SRAM)
  8 BANK    7FF7h = 3: 7FF7h; 7FF7h = 0: 7FF7h
  9 OPLL    7FF4h = 30h, 7FF5h = A5h: IN 7Dh (AmiMSX's register table: A5h);
            OUT 7Ch,31h, OUT 7Dh,5Ah: IN 7Dh (5Ah)
 10 OFF16   LD (5FFEh),HL with FFFFh: 4000h (the ROM)
The SRAM keeps the counter at 4000h: each run adds 1 (FFh blank -> 00h, then
01h after a restart that read PROGDIR:FMPAC.PAC back).
--rom: the same test as a 16 KB cartridge instead, for an FM-PAC cartridge
in the other slot (Slot 2 takes cartridges only with Disk ROM None, so no
disk then). Its init finds the FM-PAC ("P" at 4018h and "2" at 401Bh, by
RDSLT) in slot 1 or 2, runs the test from RAM with page 1 in that slot,
prints the log (CHPUT; the first line "FM-PAC SRAM test, slot n") and
stays there.
Usage: python tools/make_pactest_dsk.py [out.dsk]
       python tools/make_pactest_dsk.py --rom [out.rom]"""
import os, struct, sys

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ORG, LOG = 0xD000, 0xD400
SLOTVAR, OWNVAR = 0xD3FE, 0xD3FD        # (--rom) the FM-PAC's slot, the test ROM's


class Asm:
    def __init__(self, org):
        self.org, self.b = org, []

    def __call__(self, *bs):
        self.b += list(bs)


def code(rom=False):
    a = Asm(ORG)

    def rd(*ads):                       # LD A,(ad); LD (IY+0),A; INC IY
        for ad in ads:
            a(0x3A, ad & 255, ad >> 8, 0xFD, 0x77, 0x00, 0xFD, 0x23)

    def st(ad, v):                      # LD A,v; LD (ad),A
        a(0x3E, v, 0x32, ad & 255, ad >> 8)

    def sthl(ad, v):                    # LD HL,v; LD (ad),HL
        a(0x21, v & 255, v >> 8, 0x22, ad & 255, ad >> 8)

    def mark(n):                        # LD (IY+0),FEh; INC IY; LD (IY+0),n; INC IY
        a(0xFD, 0x36, 0x00, 0xFE, 0xFD, 0x23, 0xFD, 0x36, 0x00, n, 0xFD, 0x23)

    if rom:
        a(0xF3, 0x3A, SLOTVAR & 255, SLOTVAR >> 8)      # DI; LD A,(SLOTVAR)
    else:
        a(0xF3, 0x3E, 0x01)                             # DI; LD A,1
    a(0x26, 0x40, 0xCD, 0x24, 0x00)                     # ENASLT: page 1 = the FM-PAC
    a(0xFD, 0x21, LOG & 255, LOG >> 8)                  # LD IY,LOG (ENASLT trashes IY)
    mark(1); rd(*range(0x4018, 0x4020))
    mark(2); rd(0x5FFE, 0x5FFF, 0x7FF6, 0x7FF7)
    sthl(0x5FFE, 0xFFFF); rd(0x4010); st(0x4010, 0x5A); rd(0x4010)
    mark(3); sthl(0x5FFE, 0x694D); rd(0x5FFE, 0x5FFF, *range(0x4000, 0x4008)); rd(0x6000, 0x7FF6, 0x7FF7)
    mark(4)
    a(0x21, 0x00, 0x40, 0x34)                            # LD HL,4000h; INC (HL)
    a(0x23, 0x36, ord('P'), 0x23, 0x36, ord('A'), 0x23, 0x36, ord('C'), 0x23, 0x36, ord('!'))
    a(0x3A, 0x00, 0x40, 0x32, 0xFD, 0x5F)                # LD A,(4000h); LD (5FFDh),A
    rd(*range(0x4000, 0x4005)); rd(0x5FFD)
    mark(5); a(0xAF, 0x32, 0xFE, 0x5F); rd(0x4000, 0x5FFE)
    mark(6); st(0x5FFE, 0x4D); st(0x5FFF, 0x69); rd(0x4000)
    mark(7); st(0x7FF6, 0x10); rd(0x4000, 0x7FF6); st(0x5FFE, 0x4D); st(0x5FFF, 0x69); rd(0x4000)
    st(0x7FF6, 0x00); st(0x5FFE, 0x4D); st(0x5FFF, 0x69); rd(0x4000)
    mark(8); st(0x7FF7, 0x03); rd(0x7FF7); st(0x7FF7, 0x00); rd(0x7FF7)
    mark(9); st(0x7FF4, 0x30); st(0x7FF5, 0xA5)
    a(0xDB, 0x7D, 0xFD, 0x77, 0x00, 0xFD, 0x23)          # IN A,(7Dh); log
    a(0x3E, 0x31, 0xD3, 0x7C, 0x3E, 0x5A, 0xD3, 0x7D)    # OUT 7Ch,31h; OUT 7Dh,5Ah
    a(0xDB, 0x7D, 0xFD, 0x77, 0x00, 0xFD, 0x23)
    mark(10); sthl(0x5FFE, 0xFFFF); rd(0x4000)
    # the log's length at LOG-1, page 1 back to the BASIC ROM
    a(0xFD, 0xE5, 0xE1, 0x7D, 0x32, (LOG - 1) & 255, (LOG - 1) >> 8)   # PUSH IY; POP HL; LD (LOG-1),L
    back = OWNVAR if rom else 0xFCC1                    # the test ROM, or EXPTBL (BASIC)
    a(0x3A, back & 255, back >> 8, 0x26, 0x40, 0xCD, 0x24, 0x00)   # LD A,(back); ENASLT page 1
    a(0xFB, 0xC9)                                        # EI; RET
    return bytes(a.b)


NAMES = ["", "ID", "ROM", "ON16", "WRITE", "OFF8", "ON8", "EN10", "BANK", "OPLL", "OFF16"]


def program():
    c = code()
    hx = c.hex().upper()
    lines = ["10 CLEAR 200,&HCFFF:SCREEN 0:WIDTH 40:KEY OFF:CLS",
             "20 A=&H%04X:RESTORE 1000" % ORG,
             "30 READ D$:IF D$=\"*\" THEN 60",
             "40 FOR I=1 TO LEN(D$) STEP 2:POKE A,VAL(\"&H\"+MID$(D$,I,2)):A=A+1:NEXT",
             "50 GOTO 30",
             "60 DEFUSR=&H%04X:X=USR(0)" % ORG,
             "70 N=PEEK(&H%04X):PRINT \"FM-PAC SRAM test, log\";N" % (LOG - 1),
             "80 FOR I=0 TO N-1:V=PEEK(&H%04X+I)" % LOG,
             "90 IF V=254 AND I+1<N THEN IF PEEK(&H%04X+I+1)<11 THEN PRINT:I=I+1:PRINT MID$(STR$(PEEK(&H%04X+I)),2);\" \";:GOTO 110" % (LOG, LOG),
             "100 PRINT RIGHT$(\"0\"+HEX$(V),2);\" \";",
             "110 NEXT:PRINT:PRINT \"END\""]
    n = 1000
    for i in range(0, len(hx), 64):
        lines.append("%d DATA %s" % (n, hx[i:i + 64])); n += 10
    lines.append("%d DATA *" % n)
    return "\r\n".join(lines) + "\r\n"


def build():
    data = program().encode("ascii") + b"\x1a"
    img = bytearray(737280)
    bpb = struct.pack("<3s8sHBHBHHBHHHI", b"\xeb\xfe\x90", b"PACTEST ", 512, 2, 1, 2, 112,
                      1440, 0xF9, 3, 9, 2, 0)
    img[0:len(bpb)] = bpb
    img[0x1E] = 0xC9            # boot program: RET (BASIC then runs AUTOEXEC.BAS)
    img[510:512] = b"\x55\xaa"
    clusters = (len(data) + 1023) // 1024
    fat = bytearray(3 * 512)
    fat[0:3] = b"\xf9\xff\xff"

    def setfat(n, v):
        o = n * 3 // 2
        if n & 1:
            fat[o] = (fat[o] & 0x0F) | ((v << 4) & 0xF0); fat[o + 1] = (v >> 4) & 0xFF
        else:
            fat[o] = v & 0xFF; fat[o + 1] = (fat[o + 1] & 0xF0) | ((v >> 8) & 0x0F)
    for i in range(clusters):
        setfat(2 + i, 0xFFF if i == clusters - 1 else 3 + i)
    for k in range(2):
        img[512 * (1 + 3 * k):512 * (4 + 3 * k)] = fat
    root = 7 * 512
    img[root:root + 32] = struct.pack("<8s3sB10sHHHI", b"AUTOEXEC", b"BAS", 0x20, b"\0" * 10, 0, 0x5555, 2, len(data))
    dstart = 14 * 512
    img[dstart:dstart + len(data)] = data
    return bytes(img)


class Rom:
    """A little Z80 assembler with labels, for the cartridge's init."""
    def __init__(self, org):
        self.org, self.b, self.lab, self.fix = org, bytearray(), {}, []

    def __call__(self, *bs):
        self.b += bytes(bs)

    def L(self, name):
        self.lab[name] = self.org + len(self.b)

    def jr(self, op, name):             # JR / JR cc to a label
        self(op, 0)
        self.fix.append(("r", len(self.b) - 1, name))

    def ab(self, op, name):             # an opcode and a label's address
        self(op, 0, 0)
        self.fix.append(("a", len(self.b) - 2, name))

    def done(self):
        for k, at, name in self.fix:
            t = self.lab[name]
            if k == "r":
                d = t - (self.org + at + 1)
                assert -128 <= d <= 127, name
                self.b[at] = d & 255
            else:
                self.b[at:at + 2] = bytes((t & 255, t >> 8))
        return bytes(self.b)


def rom_image():
    CHPUT, RDSLT, RSLREG, INITXT = 0xA2, 0x0C, 0x138, 0x6C
    S, W = SLOTVAR, OWNVAR
    t = code(rom=True)
    r = Rom(0x4000)
    r(ord("A"), ord("B"))
    r.ab(0x00, "init")                                  # INIT (the 00h is dropped)
    del r.b[2]
    r.fix[-1] = ("a", 2, "init")
    r(*bytes(12))                                       # 4004h-400Fh: 0
    r.L("init")
    r(0x3E, 40, 0x32, 0xAE, 0xF3)                       # LD A,40; LD (LINL40),A
    r(0xCD, INITXT & 255, INITXT >> 8)                  # CALL INITXT (SCREEN 0)
    r(0xCD, 0x44, 0x00)                                 # CALL ENASCR (off while inits run)
    r(0xCD, RSLREG & 255, RSLREG >> 8)                  # CALL RSLREG: page 1's slot
    r(0x0F, 0x0F, 0xE6, 0x03, 0x32, W & 255, W >> 8)    # RRCA; RRCA; AND 3; LD (W),A
    r(0x3E, 0x01, 0x32, S & 255, S >> 8)                # LD A,1; LD (S),A
    r.L("scan")
    r(0x3A, S & 255, S >> 8, 0x21, W & 255, W >> 8, 0xBE)   # LD A,(S); LD HL,W; CP (HL)
    r.jr(0x28, "next")                                  # JR Z: the test ROM's own slot
    r(0x21, 0x18, 0x40, 0xCD, RDSLT, 0x00, 0xFE, ord("P"))  # LD HL,4018h; RDSLT; CP 'P'
    r.jr(0x20, "next")
    r(0x3A, S & 255, S >> 8, 0x21, 0x1B, 0x40)          # LD A,(S); LD HL,401Bh
    r(0xCD, RDSLT, 0x00, 0xFE, ord("2"))                # RDSLT; CP '2'
    r.jr(0x28, "found")
    r.L("next")
    r(0x3A, S & 255, S >> 8, 0x3C, 0x32, S & 255, S >> 8)   # INC (S)
    r(0xFE, 0x03)
    r.jr(0x20, "scan")                                  # CP 3; JR NZ,scan
    r.ab(0x21, "nopac")
    r.ab(0xCD, "prs")
    r.jr(0x18, "hang")
    r.L("found")
    r.ab(0x21, "test")
    r(0x11, ORG & 255, ORG >> 8, 0x01, len(t) & 255, len(t) >> 8, 0xED, 0xB0)   # LDIR
    r(0xCD, ORG & 255, ORG >> 8)                        # CALL the test
    r.ab(0x21, "title")
    r.ab(0xCD, "prs")
    r(0x3A, S & 255, S >> 8, 0xC6, ord("0"), 0xCD, CHPUT, 0)   # the slot's digit
    r(0x21, LOG & 255, LOG >> 8, 0x3A, (LOG - 1) & 255, (LOG - 1) >> 8, 0x47)   # HL; B = length
    r.L("ploop")
    r(0x78, 0xB7)
    r.jr(0x28, "pend")                                  # LD A,B; OR A; JR Z,pend
    r(0x7E, 0x23, 0x05, 0xFE, 0xFE)                     # LD A,(HL); INC HL; DEC B; CP FEh
    r.jr(0x20, "phex")
    r(0x3E, 13, 0xCD, CHPUT, 0, 0x3E, 10, 0xCD, CHPUT, 0)      # a new line, the step
    r(0x7E, 0x23, 0x05, 0xFE, 10)
    r.jr(0x38, "p1")
    r(0xD6, 10, 0xF5, 0x3E, ord("1"), 0xCD, CHPUT, 0, 0xF1)    # 10: '1', then 0
    r.L("p1")
    r(0xC6, ord("0"), 0xCD, CHPUT, 0, 0x3E, ord(" "), 0xCD, CHPUT, 0)
    r.jr(0x18, "ploop")
    r.L("phex")
    r(0xF5, 0x0F, 0x0F, 0x0F, 0x0F)
    r.ab(0xCD, "nib")
    r(0xF1)
    r.ab(0xCD, "nib")
    r(0x3E, ord(" "), 0xCD, CHPUT, 0)
    r.jr(0x18, "ploop")
    r.L("nib")
    r(0xE6, 0x0F, 0xC6, 0x90, 0x27, 0xCE, 0x40, 0x27, 0xC3, CHPUT, 0)   # a hex digit
    r.L("pend")
    r.ab(0x21, "endm")
    r.ab(0xCD, "prs")
    r.L("hang")
    r(0xFB, 0x76)
    r.jr(0x18, "hang")                                  # EI; HALT; JR hang
    r.L("prs")
    r(0x7E, 0xB7, 0xC8, 0xCD, CHPUT, 0, 0x23)           # print to the 0
    r.jr(0x18, "prs")
    r.L("title")
    r(*b"FM-PAC SRAM test, slot ", 0)
    r.L("endm")
    r(*b"\r\nEND\r\n", 0)
    r.L("nopac")
    r(*b"FM-PAC SRAM test: no FM-PAC in slot 1 or 2\r\n", 0)
    r.L("test")
    r(*t)
    img = r.done()
    assert len(img) <= 0x4000
    return img + b"\xff" * (0x4000 - len(img))


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--rom":
        out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(BASE, "run", "Roms", "pactest.rom")
        open(out, "wb").write(rom_image())
        print(out, len(code(rom=True)), "bytes of test code")
        return
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(BASE, "run", "Disks", "pactest.dsk")
    open(out, "wb").write(build())
    print(out, len(code()), "bytes of code")
    print(program())


if __name__ == "__main__":
    main()
