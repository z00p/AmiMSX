"""Block instruction test cartridge (16 KB, page 1): runs LDIR, LDDR, CPIR, CPDR,
OTIR, OTDR, INIR and INDR with long counts and the VBlank interrupt on (IM 2,
own handler), so on a real Z80 the interrupt comes between steps, then checks
each one's final registers, flags and memory against a model of the Z80
(computed here). Per test it prints (SCREEN 0):

    n BC   DE   HL   F  RAM  VRAM OK mmcc

F is masked to the flags checked (S Z P/V C for the memory ones, Z for the I/O
ones, whose other flags AmiMSX doesn't model); RAM and VRAM are checksums of
C000-E7FF and of VRAM 2000-37FF; mm = interrupts taken with the return address
on an ED B0-BB (i.e. between the steps of a block instruction), cc = all
interrupts during the test (both timing-dependent: compare with openMSX, not
with a fixed value). Last line: DONE nn FAIL.
Usage: python tools/make_blktest.py out.rom"""
import random
import sys

ROM, RAM0, RAMN = 0x4000, 0xC000, 0x2800      # RAM checked: C000-E7FF
RES, CNT, MID, VEC = 0xE800, 0xE900, 0xE902, 0xE9FF
VR0, VRN = 0x2000, 0x1800                     # VRAM checked: 2000-37FF
DATA = 0x6000                                 # 8 KB of test data in the ROM (an LDIR
                                              # sits across 5FFF/6000, an 8 KB page end)
CHPUT, INITXT = 0x00A2, 0x006C

# ------------------------------------------------------------ assembler
code, labels, fix = [], {}, []


def L(name):
    labels[name] = ROM + len(code)


def b(*xs):
    code.extend(xs)


def w(v):
    if isinstance(v, str):
        fix.append(("w", len(code), v)); code.extend([0, 0])
    else:
        code.extend([v & 255, v >> 8])


def jr(op, lab):
    code.append(op); fix.append(("r", len(code), lab)); code.append(0)


def call(lab): b(0xCD); w(lab)
def ld_hl(v): b(0x21); w(v)
def ld_de(v): b(0x11); w(v)
def ld_bc(v): b(0x01); w(v)
def st_hl(a): b(0x22); w(a)
def ld_hl_m(a): b(0x2A); w(a)
def st_de(a): b(0xED, 0x53); w(a)
def st_bc(a): b(0xED, 0x43); w(a)
def out99(v): b(0x3E, v, 0xD3, 0x99)


def vaddr(a, write):
    out99(0); out99(0x8E)                      # R#14 = 0
    out99(a & 255); out99((a >> 8) & 0x3F | (0x40 if write else 0))


# ------------------------------------------------------------ model
rnd = random.Random(1103)
data = [rnd.randrange(0xFD) for _ in range(0x2000)]
data[0x0300] = 0xFD
data[0x1A00] = 0xFE
data[0], data[1] = 0xB0, 0xC9                 # 5FFF: ED, B0; RET
rom = bytearray(0x4000)
rom[DATA - ROM:DATA - ROM + 0x2000] = bytes(data)
ram = bytearray(RAMN)
vram = bytearray(0x4000)
vp = [0]


def rd(a):
    if ROM <= a < ROM + 0x4000:
        return rom[a - ROM]
    assert RAM0 <= a < RAM0 + RAMN, hex(a)
    return ram[a - RAM0]


def wr(a, v):
    assert RAM0 <= a < RAM0 + RAMN, hex(a)
    ram[a - RAM0] = v


def ck(seq):
    d = e = 0
    for v in seq:
        d = (d + v) & 255
        e = (e + d) & 255
    return d << 8 | e


tests = []        # (name, mask, expected (bc, de, hl, f&mask, ckr, ckv))


def emit_test(name, mask, af, bc, de, hl, body, model, ei=True, prep=None):
    """body(): emits the block code; model(): returns (bc, de, hl, f) after it."""
    n = len(tests)
    s = RES + n * 16
    ld_hl(0); st_hl(CNT); st_hl(MID)
    if prep:
        prep()
    ld_hl(af); b(0xE5, 0xF1)                   # PUSH HL; POP AF
    ld_bc(bc); ld_de(de); ld_hl(hl)
    if ei:
        b(0xFB)
    body()
    b(0xF3)                                    # DI
    st_hl(s + 4); st_de(s + 2); st_bc(s + 0)
    b(0xF5, 0xE1); st_hl(s + 6)                # PUSH AF; POP HL
    ld_hl_m(CNT); st_hl(s + 8); ld_hl_m(MID); st_hl(s + 10)
    call("CKRAM"); st_de(s + 12)
    call("CKVRAM"); st_de(s + 14)
    rbc, rde, rhl, rf = model()
    tests.append((name, mask, (rbc, rde, rhl, rf & mask, ck(ram), ck(vram[VR0:VR0 + VRN]))))


def m_ldir(hl, de, bc, f, step):
    while True:
        wr(de, rd(hl)); hl = (hl + step) & 0xFFFF; de = (de + step) & 0xFFFF; bc = (bc - 1) & 0xFFFF
        if bc == 0:
            return bc, de, hl, f & 0xC1           # P/V = 0


def m_cpir(a, hl, bc, f, step):
    while True:
        r = (a - rd(hl)) & 255; hl = (hl + step) & 0xFFFF; bc = (bc - 1) & 0xFFFF
        if r == 0 or bc == 0:
            return bc, None, hl, (r & 0x80) | (0x40 if r == 0 else 0) | (4 if bc else 0) | (f & 1)


def m_out(hl, n, step):
    for _ in range(n * 256):
        vram[vp[0]] = rd(hl); vp[0] += 1; hl = (hl + step) & 0xFFFF
    return hl


def m_in(hl, n, step):
    for _ in range(n * 256):
        wr(hl, vram[vp[0]]); vp[0] += 1; hl = (hl + step) & 0xFFFF
    return hl


def blk(op):
    return lambda: b(0xED, op)


def rep_io(op, n):
    return lambda: [b(0x06, 0x00, 0xED, op) for _ in range(n)]


def setv(a, write):
    def p():
        vaddr(a, write); vp[0] = a
    return p


# ------------------------------------------------------------ program
b(ord("A"), ord("B")); w("INIT"); code.extend([0] * 12)
L("INIT")
b(0xF3, 0x31); w(0xEFF0)                       # DI; LD SP,EFF0h
b(0xED, 0x5E, 0x3E, VEC >> 8, 0xED, 0x47)      # IM 2; LD A,E9h; LD I,A
ld_hl("ISR"); st_hl(VEC)
out99(0x20); out99(0x81)                       # R#1 = 20h: blank (all VRAM slots), IE0 on
ld_hl(RAM0); ld_de(RAM0 + 1); ld_bc(RAMN - 1); b(0x36, 0, 0xED, 0xB0)   # clear RAM
# 0: OTIR with interrupts off: VRAM 2000-37FF cleared from the zero RAM
emit_test("OTIR di", 0x40, 0x0000, 0x0098, 0x1234, RAM0, rep_io(0xB3, 24),
          lambda: (0x0098, 0x1234, m_out(RAM0, 24, 1), 0x40), ei=False, prep=setv(VR0, True))
emit_test("LDIR", 0xC5, 0x55C1, 0x2000, RAM0, DATA, blk(0xB0),
          lambda: m_ldir(DATA, RAM0, 0x2000, 0xC1, 1))
emit_test("LDDR", 0xC5, 0xAA04, 0x1800, 0xE3FF, 0xDFFF, blk(0xB8),
          lambda: m_ldir(0xDFFF, 0xE3FF, 0x1800, 0x04, -1))


def cp_model(a, hl, bc, f, de, step):
    def m():
        rbc, _, rhl, rf = m_cpir(a, hl, bc, f, step)
        return rbc, de, rhl, rf
    return m


emit_test("CPIR", 0xC5, 0xFE01, 0x2000, 0x1111, RAM0, blk(0xB1), cp_model(0xFE, RAM0, 0x2000, 0x01, 0x1111, 1))
emit_test("CPIR no", 0xC5, 0xFF00, 0x0800, 0x2222, RAM0, blk(0xB1), cp_model(0xFF, RAM0, 0x0800, 0x00, 0x2222, 1))
emit_test("CPDR", 0xC5, 0xFD01, 0x2400, 0x3333, 0xE3FF, blk(0xB9), cp_model(0xFD, 0xE3FF, 0x2400, 0x01, 0x3333, -1))
emit_test("OTIR", 0x40, 0x0000, 0x0098, 0x4444, RAM0, rep_io(0xB3, 16),
          lambda: (0x0098, 0x4444, m_out(RAM0, 16, 1), 0x40), prep=setv(0x2000, True))
emit_test("OTDR", 0x40, 0x0000, 0x0098, 0x5555, 0xDFFF, rep_io(0xBB, 8),
          lambda: (0x0098, 0x5555, m_out(0xDFFF, 8, -1), 0x40), prep=setv(0x3000, True))
emit_test("INIR", 0x40, 0x0000, 0x0098, 0x6666, 0xE000, rep_io(0xB2, 8),
          lambda: (0x0098, 0x6666, m_in(0xE000, 8, 1), 0x40), prep=setv(0x2000, False))
emit_test("INDR", 0x40, 0x0000, 0x0098, 0x7777, 0xD7FF, rep_io(0xBA, 8),
          lambda: (0x0098, 0x7777, m_in(0xD7FF, 8, -1), 0x40), prep=setv(0x3000, False))
emit_test("LDIR pg", 0xC5, 0x0080, 0x1000, 0xD400, RAM0, lambda: call(0x5FFF),
          lambda: m_ldir(RAM0, 0xD400, 0x1000, 0x80, 1))
emit_test("LDIR 1", 0xC5, 0x0004, 0x0001, 0xE7F0, RAM0, blk(0xB0),
          lambda: m_ldir(RAM0, 0xE7F0, 1, 0x04, 1))
emit_test("CPIR 1", 0xC5, 0xFF04, 0x0001, 0x8888, RAM0, blk(0xB1), cp_model(0xFF, RAM0, 1, 0x04, 0x8888, 1))
emit_test("CPDR no", 0xC5, 0xFF81, 0x1000, 0x9999, 0xDFFF, blk(0xB9), cp_model(0xFF, 0xDFFF, 0x1000, 0x81, 0x9999, -1))

# print the results
b(0xED, 0x56)                                  # IM 1 (DI stays)
b(0x3E, 40, 0x32); w(0xF3AE)                   # LINL40 = 40
call(INITXT)
call(0x0044)                                   # ENASCR (R#1 was blanked)
ld_hl("TITLE"); call("PSTR")
b(0xAF, 0x32); w(0xE9F0)                       # XOR A; LD (fails),A
ld_hl(RES); ld_de("EXP")
b(0x06, len(tests))                            # LD B,n
L("PLOOP")
b(0xC5)                                        # PUSH BC
b(0x3E, len(tests)); b(0x90); call("PNIB")     # test number (n - B)
b(0x3E, 0x20); call("PUTC")
call("PROW")
b(0xC1, 0x10); fix.append(("r", len(code), "PLOOP")); b(0)   # POP BC; DJNZ
ld_hl("DONE"); call("PSTR")
b(0x3A); w(0xE9F0); call("PHEX8")
ld_hl("FAILS"); call("PSTR")
L("HANG"); jr(0x18, "HANG")

# PROW: HL = result slot, DE = expected record (BC DE HL F mask CKR CKV = 12 bytes);
# prints the slot and OK/!!; HL += 16, DE += 12. C = mismatch flag.
L("PROW")
b(0x0E, 0x00)                                  # LD C,0
for k in range(3):                             # BC DE HL words
    call("PWCMP")
b(0x23, 0x23)                                  # skip F, A (HL at slot+8)
b(0xE5)                                        # PUSH HL
b(0x2B, 0x2B)                                  # HL -> F
b(0x1A, 0x13)                                  # LD A,(DE) (expected F); INC DE
b(0x47)                                        # LD B,A
b(0x1A, 0x13)                                  # LD A,(DE) (mask); INC DE
b(0xA6)                                        # AND (HL)
b(0xB8)                                        # CP B
jr(0x28, "PFOK"); b(0x0E, 0x01)                # JR Z; LD C,1
L("PFOK")
call("PHEX8"); b(0x3E, 0x20); call("PUTC")
b(0xE1)                                        # POP HL (slot+8)
b(0x23, 0x23, 0x23, 0x23)                      # skip CNT, MID -> CKR
call("PWCMP"); call("PWCMP")
b(0x79, 0xB7)                                  # LD A,C; OR A
jr(0x20, "PBAD")
b(0xE5); ld_hl("OK"); call("PSTR"); b(0xE1)
jr(0x18, "PCNT")
L("PBAD")
b(0xE5); ld_hl("BAD"); call("PSTR"); b(0x3A); w(0xE9F0); b(0x3C, 0x32); w(0xE9F0); b(0xE1)
L("PCNT")
b(0xE5)                                        # PUSH HL (slot+16)
b(0x01); w((-6) & 0xFFFF); b(0x09)             # LD BC,-6; ADD HL,BC -> MID
b(0x7E); call("PHEX8")                         # MID low
b(0x2B, 0x2B, 0x7E); call("PHEX8")             # CNT low
b(0x3E, 0x0D); call("PUTC"); b(0x3E, 0x0A); call("PUTC")
b(0xE1, 0xC9)                                  # POP HL; RET

# PWCMP: prints word (HL) (HL += 2), compares with word (DE) (DE += 2), C = 1 if different
L("PWCMP")
b(0x23, 0x7E); call("PHEX8")                   # INC HL; high byte
b(0x2B, 0x7E); call("PHEX8")                   # DEC HL; low byte
b(0x3E, 0x20); call("PUTC")
b(0x1A, 0xBE, 0x13, 0x23)                      # LD A,(DE); CP (HL); INC DE; INC HL
jr(0x28, "PW1"); b(0x0E, 0x01)
L("PW1")
b(0x1A, 0xBE, 0x13, 0x23)
jr(0x28, "PW2"); b(0x0E, 0x01)
L("PW2")
b(0xC9)

L("PHEX8")
b(0xF5, 0x0F, 0x0F, 0x0F, 0x0F); call("PNIB"); b(0xF1)
L("PNIB")
b(0xE6, 0x0F, 0xFE, 0x0A); jr(0x38, "PN1"); b(0xC6, 0x07)
L("PN1")
b(0xC6, 0x30); b(0xC3); w("PUTC")

L("PUTC")                                      # CHPUT, all registers kept
b(0xE5, 0xD5, 0xC5); call(CHPUT); b(0xC1, 0xD1, 0xE1, 0xC9)

L("PSTR")
b(0x7E, 0xB7, 0xC8, 0xE5); call("PUTC"); b(0xE1, 0x23); jr(0x18, "PSTR")

L("CKRAM")
ld_hl(RAM0); ld_bc(RAMN); ld_de(0)
L("CK1")
b(0x7E, 0x82, 0x57, 0x83, 0x5F, 0x23, 0x0B, 0x78, 0xB1); jr(0x20, "CK1"); b(0xC9)

L("CKVRAM")
vaddr(VR0, False)
ld_bc(VRN); ld_de(0)
L("CK2")
b(0xDB, 0x98, 0x82, 0x57, 0x83, 0x5F, 0x0B, 0x78, 0xB1); jr(0x20, "CK2"); b(0xC9)

L("ISR")
b(0xE5, 0xF5, 0xDB, 0x99)                      # PUSH HL; PUSH AF; IN A,(99h)
ld_hl_m(CNT); b(0x23); st_hl(CNT)
ld_hl(4); b(0x39, 0x7E, 0x23, 0x66, 0x6F)      # ADD HL,SP; LD A,(HL); INC HL; LD H,(HL); LD L,A
b(0x7E, 0xFE, 0xED); jr(0x20, "ISRX")
b(0x23, 0x7E, 0xE6, 0xF4, 0xFE, 0xB0); jr(0x20, "ISRX")
ld_hl_m(MID); b(0x23); st_hl(MID)
L("ISRX")
b(0xF1, 0xE1, 0xFB, 0xED, 0x4D)                # POP AF; POP HL; EI; RETI


def s(lab, t):
    L(lab); code.extend(t.encode("ascii") + b"\0")


s("TITLE", "  BC   DE   HL   F  RAM  VRAM    mmcc\r\n")
s("OK", "OK ")
s("BAD", "!! ")
s("DONE", "DONE ")
s("FAILS", " FAIL")
L("EXP")
for name, mask, (rbc, rde, rhl, rf, ckr, ckv) in tests:
    for v in (rbc, rde, rhl):
        w(v)
    b(rf, mask)
    w(ckr); w(ckv)
for kind, at, lab in fix:
    v = labels[lab]
    if kind == "w":
        code[at], code[at + 1] = v & 255, v >> 8
    else:
        d = v - (ROM + at + 1)
        assert -128 <= d < 128, lab
        code[at] = d & 255
assert len(code) < 0x1FFF, hex(len(code))
rom[:len(code)] = bytes(code)
rom[0x1FFF] = 0xED
open(sys.argv[1], "wb").write(rom)
for i, (name, mask, e) in enumerate(tests):
    print(f"{i:X} {name:8s} " + " ".join(f"{v:04X}" for v in e[:3]) + f" {e[3]:02X} {e[4]:04X} {e[5]:04X}")
print(f"{len(code)} bytes of code, {len(tests)} tests")
