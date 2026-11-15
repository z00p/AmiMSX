"""R800 multiply test cartridge (16 KB, page 1). For each of ED C1/C9/D1/D9
(MULUB A,B/C/D/E) and ED C3/F3 (MULUW HL,BC/SP) it runs 16 cases (8 operand
sets, F = 00h and FFh) once with the CPU switched to the R800 (S1990 register
6 = 00h) and once on the Z80 (60h), where they are ED NOPs. On a turbo R
BIOS (002Dh >= 3) it switches through the BIOS's CHGCPU (0180h, A = 82h R800
DRAM mode / 80h Z80): the Z80 and the R800 have a register file each, and
the CPU that takes over carries on where it last left off, which on a real
machine is inside CHGCPU. Elsewhere (C-BIOS on a machine with an S1990 and
an R800: AmiMSX's TURBOR build, or openMSX) it does the same with a switch
routine of its own ("sw": saves SP, writes S1990 register 6, index on E4h,
data on E5h; the CPU that takes over carries on inside sw, loads that SP
and returns), with RAM in page 0 and "JP" into sw at 0000h for the R800's
first start (its power-on PC); page 0 goes back before the printing.
After each case HL, DE, F and A go into a 16-bit checksum (rotate left, add
the byte). It then prints one line per opcode and CPU: "C1 R8 xxxx", in
SCREEN 0 through the BIOS (INITXT, CHPUT), in the Z80, and stops.
The expected checksums come from the model below, which follows openMSX's
R800 (checked case by case against openMSX by --check, from a dump made with
the FS-A1GT: "ED C1 A=.. BC=.. DE=.. HL=.. SP=.. F=.. -> HL=.. DE=.. BC=.. A=.. F=..").
Usage: python tools/make_r800mul.py out.rom [--check openmsx_dump.txt]"""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_r800swap import page0_ram, page0_back   # noqa: E402

OPS = [0xC1, 0xC9, 0xD1, 0xD9, 0xC3, 0xF3]
VEC = [(0x00, 0x0005, 0x0000, 0x0000, 0xF000), (0x01, 0xFF02, 0x0304, 0x0506, 0xF000),
       (0x0F, 0x1111, 0x1111, 0x1111, 0x0011), (0x10, 0x1010, 0x1010, 0x1010, 0x0010),
       (0xFF, 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF), (0x02, 0x8080, 0x8080, 0x8080, 0x8000),
       (0x03, 0x0005, 0x0100, 0x0100, 0x0100), (0x80, 0x0201, 0x0403, 0x0000, 0x0002)]
STK, CHK, TMP, RES = 0xF000, 0xC000, 0xC002, 0xC010
TRF, SAVSP, SAV = 0xC008, 0xC00A, 0xC030        # BIOS id, sw's SP, page0_ram


def model(op, a, bc, de, hl, sp, f, r800):
    """(hl, de, f) after the instruction."""
    if not r800 or op not in OPS:
        return hl, de, f
    keep = f & 0x3A                         # Y H X N kept, S P/V cleared
    if op in (0xC3, 0xF3):
        r = hl * (bc if op == 0xC3 else sp)
        return r & 0xFFFF, r >> 16, keep | (0x40 if r == 0 else 0) | (0x01 if r >> 16 else 0)
    src = {0xC1: bc >> 8, 0xC9: bc & 255, 0xD1: de >> 8, 0xD9: de & 255}[op]
    r = a * src
    return r, de, keep | (0x40 if r == 0 else 0) | (0x01 if r >> 8 else 0)


def check(path):
    bad = n = 0
    for line in open(path):
        w = dict(x.split("=") for x in line.split("->")[0].split() if "=" in x)
        op = int(line.split()[1], 16)
        inp = [int(w[k], 16) for k in ("A", "BC", "DE", "HL", "SP", "F")]
        after = line.split("->")[1].split()
        o = dict(x.split("=") for x in after if "=" in x)
        exp = (int(o["HL"], 16), int(o["DE"], 16), int(o["F"], 16))
        got = model(op, *inp, r800=True)
        n += 1
        if got != exp:
            bad += 1
            print("model differs:", line.strip(), [hex(x) for x in got])
    print(f"model vs openMSX: {n} cases, {bad} differ")


def main():
    if "--check" in sys.argv:
        check(sys.argv[sys.argv.index("--check") + 1])
    code = [0xF3, 0x31, STK & 255, STK >> 8]           # DI; LD SP,F000h
    lab = {}
    fix = []                                           # (offset of a CALL operand, label)

    def call(name):
        code.extend([0xCD, 0, 0])
        fix.append((len(code) - 2, name))

    def cpusw(v):
        # LD A,(TRF); CP 3; JR C,raw; LD A,82h/80h; CALL 0180h; JR done;
        # raw: LD A,v; CALL sw; done:
        code.extend([0x3A, TRF & 255, TRF >> 8, 0xFE, 3, 0x38, 7, 0x3E, 0x80 if v & 0x20 else 0x82,
                     0xCD, 0x80, 0x01, 0x18, 5, 0x3E, v])
        call("sw")

    # the BIOS id (002Dh) into TRF; below 3 (not a turbo R BIOS): RAM into
    # page 0 with JP sw_r at 0000h for the R800's first start
    code.extend([0x3A, 0x2D, 0x00, 0x32, TRF & 255, TRF >> 8, 0xFE, 3])
    setup = page0_ram(SAV) + [0x3E, 0xC3, 0x32, 0x00, 0x00, 0x21, 0, 0, 0x22, 0x01, 0x00]
    code.extend([0x30, len(setup)])                   # JR NC (turbo R BIOS): skip
    code.extend(setup)
    fix.append((len(code) - 5, "sw_r"))

    expect = []
    slot = 0
    for cpu, v in (("R8", 0x00), ("Z8", 0x60)):
        for op in OPS:
            cpusw(v)
            code.extend([0x21, 0, 0, 0x22, CHK & 255, CHK >> 8])    # checksum = 0
            c = 0
            for a, bc, de, hl, sp in VEC:
                for f in (0x00, 0xFF):
                    af = a << 8 | f
                    code.extend([0x21, af & 255, af >> 8, 0xE5, 0xF1])   # LD HL,af; PUSH HL; POP AF
                    code.extend([0x01, bc & 255, bc >> 8, 0x11, de & 255, de >> 8, 0x21, hl & 255, hl >> 8])
                    if op == 0xF3:
                        code.extend([0x31, sp & 255, sp >> 8, 0xED, op, 0x31, STK & 255, STK >> 8])
                    else:
                        code.extend([0xED, op])
                    code.extend([0xF5, 0x22, TMP & 255, TMP >> 8, 0xED, 0x53, (TMP + 2) & 255, (TMP + 2) >> 8,
                                 0xE1, 0x22, (TMP + 4) & 255, (TMP + 4) >> 8])  # PUSH AF; (TMP)=HL,DE,F,A
                    call("acc")
                    rh, rd, rf = model(op, a, bc, de, hl, sp, f, cpu == "R8")
                    for byte in (rh & 255, rh >> 8, rd & 255, rd >> 8, rf, a):
                        c = ((c << 1) | (c >> 15)) & 0xFFFF
                        c = (c + byte) & 0xFFFF
            code.extend([0x2A, CHK & 255, CHK >> 8, 0x22, (RES + 2 * slot) & 255, (RES + 2 * slot) >> 8])
            expect.append((op, cpu, c))
            slot += 1
    # back to the Z80, page 0 back (C-BIOS path), SCREEN 0, print the lines
    cpusw(0x60)
    back = page0_back(SAV)
    code.extend([0x3A, TRF & 255, TRF >> 8, 0xFE, 3, 0x30, len(back)] + back)
    code.extend([0xCD, 0x6C, 0x00])                   # INITXT
    for i, (op, cpu, c) in enumerate(expect):
        txt = "%02X %s " % (op, cpu)
        for ch in txt:
            code.extend([0x3E, ord(ch), 0xCD, 0xA2, 0x00])
        code.extend([0x2A, (RES + 2 * i) & 255, (RES + 2 * i) >> 8, 0x7C])
        call("hex")
        code.append(0x7D)
        call("hex")
        code.extend([0x3E, 13, 0xCD, 0xA2, 0x00, 0x3E, 10, 0xCD, 0xA2, 0x00])
    code.extend([0x18, 0xFE])                          # JR $
    # acc: checksum += 6 bytes at TMP (L H E D F A), rotate left before each
    lab["acc"] = len(code)
    code.extend([0x2A, CHK & 255, CHK >> 8, 0x11, TMP & 255, TMP >> 8, 0x06, 6,
                 0x29, 0x30, 0x01, 0x23,                   # ADD HL,HL; JR NC,+1; INC HL
                 0x1A, 0x85, 0x6F, 0x30, 0x01, 0x24,       # LD A,(DE); ADD A,L; LD L,A; JR NC,+1; INC H
                 0x13, 0x10, 0xF3,                         # INC DE; DJNZ loop
                 0x22, CHK & 255, CHK >> 8, 0xC9])
    # sw: A = S1990 register 6. LD (SAVSP),SP; PUSH AF; LD A,6; OUT (E4h),A;
    # POP AF; OUT (E5h),A; sw_r: LD SP,(SAVSP); RET
    lab["sw"] = len(code)
    code.extend([0xED, 0x73, SAVSP & 255, SAVSP >> 8, 0xF5, 0x3E, 6, 0xD3, 0xE4, 0xF1, 0xD3, 0xE5])
    lab["sw_r"] = len(code)
    code.extend([0xED, 0x7B, SAVSP & 255, SAVSP >> 8, 0xC9])
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
    for op, cpu, c in expect:
        print("%02X %s %04X" % (op, cpu, c))


main()
