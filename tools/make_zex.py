"""ZEXALL-style Z80 test cartridge for the MSX (32 KB, pages 1-2).

Each test group runs one family of instructions over many register, flag
and memory-operand combinations (a ZEXALL-like base/counter/shifter vector
scheme) and accumulates a CRC-32 of the results (registers, F and the two
memory-operand bytes). The CRC is printed next to the reference value, with
OK or !! after it. The reference values are computed here with the `z80`
PyPI package (pip install z80), whose core passes ZEXALL, so a ROM is
self-checking: openMSX should print OK everywhere, and every !! on AmiMSX
is a Z80 core difference. The same ROM also serves to compare AmiMSX
with openMSX directly (same screen, same numbers).

Usage:
  python tools/make_zex.py out.rom [--flags doc|all|szpc] [--quick]
         [--list groups.txt] [--selftest]

  --flags doc   masks the undocumented X/Y flags (F & D7h), as ZEXDOC
          all   every flag bit (ZEXALL)
          szpc  only S, Z, P/V and C (F & C5h): the flags AmiMSX models
  --quick       counter vectors only, no shifter (a few seconds of Z80 time)
  --selftest    runs the ROM in the Python emulator and shows its screen
  --list        writes the group table: name, instructions, cases, CRC

The ROM needs no interrupts and no RAM other than page 3; results go to
SCREEN 0 through the BIOS (CHPUT). Interrupts stay disabled, so R, I, the
alternate registers, HALT, I/O and jumps are not covered: see
tools/make_z80ops.py for the conditional jumps and
tools/make_z80flags.py for a readable list of single results.
"""
import sys
import zlib

try:
    import z80
except ImportError:
    sys.exit("pip install z80 (ZEXALL-verified Z80 emulator: reference CRCs)")

# ---------------------------------------------------------------- layout
ROM = 0x4000          # cartridge pages 1-2
IUT = 0xC000          # instruction under test (4 bytes) + JP DONE
MSBT = 0xC100         # memory operand (2 bytes watched)
VEC = 0xC200          # current test vector (16 bytes)
COUNT = 0xC210        # counter state (16)
SHIFT = 0xC220        # shifter state (16)
CRC = 0xC230          # 4 bytes
SPSAV = 0xC234        # 2
DESC = 0xC236         # 2: current group descriptor
IUTP = 0xC238         # 2: current instruction entry
IUTN = 0xC23A         # 1: instructions left
SHI = 0xC23B          # 1: shifter byte index
SHB = 0xC23C          # 1: shifter bit (0 = not started)
NFAIL = 0xC23D        # 1
FMASK = 0xC23E        # 1
RES = 0xC240          # result record (16): memop iy ix hl de bc f a sp
CRCT = 0xC300         # CRC tables, 4 pages (copied from ROM at start)
STACK = 0xF380
CRCTAB = 0x7C00       # the tables in ROM (copied to CRCT at start)
CHPUT = 0x00A2
INITXT = 0x006C

FLAGMASK = {"doc": 0xD7, "all": 0xFF, "szpc": 0xC5}
FIELDS = ("memop", "iy", "ix", "hl", "de", "bc", "f", "a", "sp")
SIZES = {"memop": 2, "iy": 2, "ix": 2, "hl": 2, "de": 2, "bc": 2,
         "f": 1, "a": 1, "sp": 2}


def vec(**kw):
    """16-byte state vector from field values (missing fields are 0)."""
    out = b""
    for name in FIELDS:
        v = kw.get(name, 0)
        out += v.to_bytes(SIZES[name], "little")
    return out


def ins(*codes):
    """Instruction entries: each a list of up to 4 bytes, NOP padded."""
    return [bytes(c) + b"\x00" * (4 - len(c)) for c in codes]


D = 0x20              # displacement used with IX/IY (IX = MSBT - D)
B = {                 # the usual base vector: HL -> memop, IX/IY -> memop-D
    "memop": 0x9A5C, "hl": MSBT, "ix": MSBT - D, "iy": MSBT - D,
    "de": 0x6B3F, "bc": 0x17C4, "f": 0x00, "a": 0x3C, "sp": 0xA5C3}


def base(**kw):
    d = dict(B)
    d.update(kw)
    return vec(**d)


ALU = [0x80 | op << 3 for op in range(8)]                 # ADD ADC SUB SBC AND XOR OR CP
REGS = [0, 1, 2, 3, 4, 5, 7]                                # B C D E H L A
CB_ROT = list(range(0x00, 0x40))                            # RLC..SRL, SLL


class Group:
    def __init__(self, name, iuts, base, count, shift, note):
        assert len(name) <= 8, name
        self.name, self.iuts, self.base = name, iuts, base
        self.count, self.shift, self.note = count, shift, note
        self.cases = 0
        self.crc = None


GROUPS = [
    Group("adc16", ins(*[[0xED, c] for c in (0x4A, 0x5A, 0x6A, 0x7A, 0x42, 0x52, 0x62, 0x72)]),
          base(hl=0x1234, de=0x7FFF, bc=0x8000, sp=0x0FFF),
          vec(f=0x01, hl=0xF800), vec(de=0xFFFF, bc=0xFFFF),
          "ADC/SBC HL,BC/DE/HL/SP"),
    Group("add16", ins([0x09], [0x19], [0x29], [0x39]),
          base(hl=0x1234, de=0x7FFF, bc=0x8000, sp=0x0FFF),
          vec(f=0x01, hl=0xF800), vec(de=0xFFFF, bc=0xFFFF, sp=0xFFFF),
          "ADD HL,BC/DE/HL/SP"),
    Group("add16x", ins([0xDD, 0x09], [0xDD, 0x19], [0xDD, 0x29], [0xDD, 0x39],
                        [0xFD, 0x09], [0xFD, 0x19], [0xFD, 0x29], [0xFD, 0x39]),
          base(ix=0x1234, iy=0x7FFF, de=0x7FFF, bc=0x8000, sp=0x0FFF),
          vec(f=0x01, ix=0xF800, iy=0x8000), vec(de=0xFFFF, bc=0xFFFF),
          "ADD IX/IY,BC/DE/IX/SP"),
    Group("alu8i", ins(*[[op | 0x46, 0] for op in ALU]),
          base(a=0x3C), vec(f=0x01, a=0x81), vec(a=0x7E),
          "ADD/ADC/SUB/SBC/AND/XOR/OR/CP A,n (n = 00h and shifted)"),
    Group("alu8i2", ins(*[[op | 0x46, 0x9B] for op in ALU] + [[op | 0x46, 0x0F] for op in ALU]),
          base(a=0x3C), vec(f=0x01, a=0xFF), vec(),
          "ALU A,9Bh and A,0Fh over every A"),
    Group("alu8r", ins(*[[op | r] for op in ALU for r in REGS + [6]]),
          base(a=0x3C, bc=0x0F7F, de=0x80FF, hl=MSBT, memop=0x0001),
          vec(f=0x01, a=0x81), vec(bc=0xFFFF, de=0xFFFF, memop=0x00FF),
          "ALU A,r and A,(HL)"),
    Group("alu8x", ins(*[[0xDD, op | 6, D] for op in ALU] + [[0xFD, op | 6, D] for op in ALU]),
          base(a=0x3C, memop=0x0001), vec(f=0x01, a=0x81), vec(memop=0x00FF),
          "ALU A,(IX+d) and A,(IY+d)"),
    Group("alu8xh", ins(*[[0xDD, op | r] for op in ALU for r in (4, 5)]
                        + [[0xFD, op | r] for op in ALU for r in (4, 5)]),
          base(a=0x3C, ix=0x0F7F, iy=0x80FF), vec(f=0x01, a=0x81), vec(ix=0xFFFF, iy=0xFFFF),
          "ALU A,IXH/IXL/IYH/IYL (undocumented)"),
    Group("bitz80", ins(*[[0xCB, 0x40 | b << 3 | r] for b in range(8) for r in REGS + [6]]),
          base(a=0x00, bc=0x0000, de=0x0000, hl=MSBT, memop=0x0000),
          vec(f=0x01), vec(a=0xFF, bc=0xFFFF, de=0xFFFF, memop=0x00FF),
          "BIT n,r and n,(HL)"),
    Group("setres", ins(*[[0xCB, 0x80 | b << 3 | r] for b in range(8) for r in REGS + [6]]
                        + [[0xCB, 0xC0 | b << 3 | r] for b in range(8) for r in REGS + [6]]),
          base(a=0x5A, bc=0xA55A, de=0x0FF0, hl=MSBT, memop=0x3CC3),
          vec(), vec(a=0xFF, memop=0x00FF),
          "SET/RES n,r and n,(HL)"),
    Group("bitx", ins(*[[0xDD, 0xCB, D, 0x46 | b << 3] for b in range(8)]
                      + [[0xFD, 0xCB, D, 0x46 | b << 3] for b in range(8)]),
          base(memop=0x0000), vec(f=0x01), vec(memop=0x00FF),
          "BIT n,(IX+d) and n,(IY+d)"),
    Group("setresx", ins(*[[0xDD, 0xCB, D, 0x86 | b << 3] for b in range(8)]
                         + [[0xDD, 0xCB, D, 0xC6 | b << 3] for b in range(8)]
                         + [[0xFD, 0xCB, D, 0x86 | b << 3] for b in range(8)]),
          base(memop=0x3CC3), vec(), vec(memop=0x00FF),
          "SET/RES n,(IX+d) and RES n,(IY+d)"),
    Group("cpd1", ins([0xED, 0xA9], [0xED, 0xB9]),
          base(hl=MSBT + 1, bc=0x0001, a=0x00, memop=0xC37F),
          vec(f=0x01, a=0xFF), vec(bc=0x0002, memop=0xFFFF),
          "CPD, CPDR with BC = 1, 2"),
    Group("cpi1", ins([0xED, 0xA1], [0xED, 0xB1]),
          base(hl=MSBT, bc=0x0001, a=0x00, memop=0xC37F),
          vec(f=0x01, a=0xFF), vec(bc=0x0002, memop=0xFFFF),
          "CPI, CPIR with BC = 1, 2"),
    Group("daaop", ins([0x27], [0x2F], [0x37], [0x3F]),
          base(a=0x00, f=0x00), vec(a=0xFF, f=0x13), vec(f=0xC4),
          "DAA, CPL, SCF, CCF over every A and C/H/N (other flags shifted)"),
    Group("inc8", ins(*[[0x04 | r << 3] for r in REGS + [6]] + [[0x05 | r << 3] for r in REGS + [6]]),
          base(a=0x00, bc=0x0000, de=0x0000, hl=MSBT, memop=0x0000),
          vec(f=0x01), vec(a=0xFF, bc=0xFFFF, de=0xFFFF, memop=0x00FF),
          "INC/DEC r and (HL)"),
    Group("inc8x", ins([0xDD, 0x34, D], [0xDD, 0x35, D], [0xFD, 0x34, D], [0xFD, 0x35, D]),
          base(memop=0x0000), vec(f=0x01, memop=0x00FF), vec(memop=0xFF00),
          "INC/DEC (IX+d) and (IY+d)"),
    Group("inc8xh", ins([0xDD, 0x24], [0xDD, 0x25], [0xDD, 0x2C], [0xDD, 0x2D],
                        [0xFD, 0x24], [0xFD, 0x25], [0xFD, 0x2C], [0xFD, 0x2D]),
          base(ix=0x0000, iy=0x0000), vec(f=0x01), vec(ix=0xFFFF, iy=0xFFFF),
          "INC/DEC IXH, IXL, IYH, IYL (undocumented)"),
    Group("inc16", ins([0x03], [0x0B], [0x13], [0x1B], [0x23], [0x2B], [0x33], [0x3B],
                       [0xDD, 0x23], [0xDD, 0x2B], [0xFD, 0x23], [0xFD, 0x2B]),
          base(bc=0x0000, de=0x0000, hl=0x0000, sp=0x0000, ix=0x0000, iy=0x0000),
          vec(f=0x01), vec(bc=0xFFFF, de=0xFFFF, hl=0xFFFF, sp=0xFFFF, ix=0xFFFF, iy=0xFFFF),
          "INC/DEC BC/DE/HL/SP/IX/IY"),
    Group("ld16im", ins([0x01, 0x34, 0x12], [0x11, 0x34, 0x12], [0x21, 0x34, 0x12],
                        [0x31, 0x34, 0x12], [0xDD, 0x21, 0x34, 0x12], [0xFD, 0x21, 0x34, 0x12]),
          base(), vec(f=0x01), vec(),
          "LD rr,nn / IX,nn / IY,nn / SP,nn"),
    Group("ld16m", ins([0x2A, MSBT & 255, MSBT >> 8], [0xED, 0x4B, MSBT & 255, MSBT >> 8],
                       [0xED, 0x5B, MSBT & 255, MSBT >> 8], [0xED, 0x6B, MSBT & 255, MSBT >> 8],
                       [0xED, 0x7B, MSBT & 255, MSBT >> 8], [0xDD, 0x2A, MSBT & 255, MSBT >> 8],
                       [0xFD, 0x2A, MSBT & 255, MSBT >> 8]),
          base(memop=0x0000), vec(f=0x01), vec(memop=0xFFFF),
          "LD HL/BC/DE/SP/IX/IY,(nn)"),
    Group("st16m", ins([0x22, MSBT & 255, MSBT >> 8], [0xED, 0x43, MSBT & 255, MSBT >> 8],
                       [0xED, 0x53, MSBT & 255, MSBT >> 8], [0xED, 0x63, MSBT & 255, MSBT >> 8],
                       [0xED, 0x73, MSBT & 255, MSBT >> 8], [0xDD, 0x22, MSBT & 255, MSBT >> 8],
                       [0xFD, 0x22, MSBT & 255, MSBT >> 8]),
          base(memop=0x0000, hl=0x0000, bc=0x0000, de=0x0000, sp=0x0000, ix=0x0000, iy=0x0000),
          vec(f=0x01), vec(hl=0xFFFF, bc=0xFFFF, de=0xFFFF, sp=0xFFFF, ix=0xFFFF, iy=0xFFFF),
          "LD (nn),HL/BC/DE/SP/IX/IY"),
    Group("ldsp", ins([0xF9], [0xDD, 0xF9], [0xFD, 0xF9]),
          base(hl=0x0000, ix=0x0000, iy=0x0000), vec(f=0x01), vec(hl=0xFFFF, ix=0xFFFF, iy=0xFFFF),
          "LD SP,HL/IX/IY"),
    Group("ld8bd", ins([0x0A], [0x1A], [0x02], [0x12]),
          base(bc=MSBT, de=MSBT, a=0x00, memop=0x0000), vec(f=0x01),
          vec(a=0xFF, memop=0x00FF), "LD A,(BC)/(DE), LD (BC)/(DE),A"),
    Group("ld8im", ins(*[[0x06 | r << 3, 0] for r in REGS + [6]]),
          base(memop=0x0000), vec(f=0x01), vec(), "LD r,n and (HL),n (n = 00h)"),
    Group("ld8im2", ins(*[[0x06 | r << 3, 0xA5] for r in REGS + [6]]),
          base(memop=0x0000), vec(f=0x01), vec(), "LD r,A5h and (HL),A5h"),
    Group("ld8ix", ins(*[[0xDD, 0x46 | r << 3, D] for r in REGS] + [[0xFD, 0x46 | r << 3, D] for r in REGS]),
          base(memop=0x0000), vec(f=0x01), vec(memop=0x00FF), "LD r,(IX+d) and r,(IY+d)"),
    Group("st8ix", ins(*[[0xDD, 0x70 | r, D] for r in REGS] + [[0xFD, 0x70 | r, D] for r in REGS]
                       + [[0xDD, 0x36, D, 0x5A], [0xFD, 0x36, D, 0xA5]]),
          base(memop=0x0000, a=0x00, bc=0x0000, de=0x0000, hl=0x0000), vec(f=0x01),
          vec(a=0xFF, bc=0xFFFF, de=0xFFFF, hl=0xFFFF), "LD (IX+d),r/n and (IY+d),r/n"),
    Group("ld8rr", ins(*[[0x40 | d << 3 | s] for d in REGS + [6] for s in REGS + [6] if not (d == 6 and s == 6)]),
          base(memop=0x0000, a=0x00, bc=0x0000, de=0x0000, hl=MSBT), vec(f=0x01),
          vec(a=0xFF, bc=0xFFFF, de=0xFFFF, memop=0x00FF), "LD r,r' with (HL) (no HALT)"),
    Group("ld8rrx", ins(*[[0xDD, 0x40 | d << 3 | s] for d in (0, 1, 2, 3, 4, 5, 7) for s in (4, 5)]
                        + [[0xDD, 0x40 | d << 3 | s] for d in (4, 5) for s in (0, 1, 2, 3, 7)]
                        + [[0xFD, 0x40 | d << 3 | s] for d in (0, 1, 2, 3, 4, 5, 7) for s in (4, 5)]
                        + [[0xFD, 0x40 | d << 3 | s] for d in (4, 5) for s in (0, 1, 2, 3, 7)]),
          base(a=0x00, bc=0x0000, de=0x0000, hl=0x0000, ix=0x0000, iy=0x0000), vec(f=0x01),
          vec(a=0xFF, bc=0xFFFF, de=0xFFFF, hl=0xFFFF, ix=0xFFFF, iy=0xFFFF),
          "LD r,IXH/IXL/IYH/IYL and back (undocumented)"),
    Group("lda", ins([0x3A, MSBT & 255, MSBT >> 8], [0x32, MSBT & 255, MSBT >> 8]),
          base(memop=0x0000, a=0x00), vec(f=0x01), vec(memop=0x00FF, a=0xFF),
          "LD A,(nn) and LD (nn),A"),
    Group("ldd1", ins([0xED, 0xA8], [0xED, 0xB8]),
          base(hl=MSBT, de=MSBT + 1, bc=0x0001, memop=0x0000), vec(f=0x01, a=0x81),
          vec(bc=0x0002, memop=0xFFFF), "LDD, LDDR with BC = 1, 2"),
    Group("ldi1", ins([0xED, 0xA0], [0xED, 0xB0]),
          base(hl=MSBT, de=MSBT + 1, bc=0x0001, memop=0x0000), vec(f=0x01, a=0x81),
          vec(bc=0x0002, memop=0xFFFF), "LDI, LDIR with BC = 1, 2"),
    Group("neg", ins([0xED, 0x44], [0xED, 0x4C], [0xED, 0x7C]),
          base(a=0x00), vec(f=0x01, a=0xFF), vec(), "NEG (ED 44 and the undocumented ED 4C, 7C)"),
    Group("rld", ins([0xED, 0x6F], [0xED, 0x67]),
          base(a=0x00, memop=0x0000), vec(f=0x01, a=0xFF), vec(memop=0x00FF), "RLD and RRD"),
    Group("rot8080", ins([0x07], [0x0F], [0x17], [0x1F]),
          base(a=0x00), vec(f=0x01, a=0xFF), vec(f=0xC4), "RLCA, RRCA, RLA, RRA"),
    Group("rotz80", ins(*[[0xCB, c] for c in CB_ROT]),
          base(a=0x00, bc=0x0000, de=0x0000, hl=MSBT, memop=0x0000), vec(f=0x01),
          vec(a=0xFF, bc=0xFFFF, de=0xFFFF, memop=0x00FF),
          "RLC/RRC/RL/RR/SLA/SRA/SLL/SRL r and (HL)"),
    Group("rotx", ins(*[[0xDD, 0xCB, D, c] for c in range(0x06, 0x40, 8)]
                      + [[0xFD, 0xCB, D, c] for c in range(0x06, 0x40, 8)]),
          base(memop=0x0000), vec(f=0x01), vec(memop=0x00FF),
          "RLC..SRL (IX+d) and (IY+d)"),
    Group("ex", ins([0xEB], [0xE3], [0xDD, 0xE3], [0xFD, 0xE3]),
          base(sp=MSBT, hl=0x0000, de=0x0000, ix=0x0000, iy=0x0000, memop=0x0000), vec(f=0x01),
          vec(hl=0xFFFF, de=0xFFFF, ix=0xFFFF, iy=0xFFFF, memop=0xFFFF),
          "EX DE,HL and EX (SP),HL/IX/IY"),
    Group("push", ins([0xC5], [0xD5], [0xE5], [0xF5], [0xDD, 0xE5], [0xFD, 0xE5]),
          base(sp=MSBT + 2, bc=0x0000, de=0x0000, hl=0x0000, ix=0x0000, iy=0x0000, a=0x00, memop=0x0000),
          vec(f=0x01), vec(bc=0xFFFF, de=0xFFFF, hl=0xFFFF, ix=0xFFFF, iy=0xFFFF, a=0xFF, f=0xFE),
          "PUSH rr/IX/IY (into the memory operand)"),
    Group("pop", ins([0xC1], [0xD1], [0xE1], [0xF1], [0xDD, 0xE1], [0xFD, 0xE1]),
          base(sp=MSBT, memop=0x0000), vec(f=0x01), vec(memop=0xFFFF),
          "POP rr/IX/IY (from the memory operand)"),
    Group("ddnop", ins([0xDD, 0x00], [0xDD, 0x3C], [0xFD, 0x47], [0xDD, 0x80], [0xDD, 0xDD, 0x23]),
          base(a=0x00, bc=0x0000), vec(f=0x01, a=0x81), vec(bc=0xFFFF),
          "DD/FD before an opcode without IX/IY: the prefix is a NOP"),
    Group("ednop", ins([0xED, 0x77], [0xED, 0x7F], [0xED, 0xA4], [0xED, 0x80], [0xED, 0xC0], [0xED, 0xFF]),
          base(a=0x00), vec(f=0x01, a=0x81), vec(), "Undefined ED opcodes: NOP on a Z80"),
    Group("r800", ins([0xED, 0xC1], [0xED, 0xC9], [0xED, 0xC3], [0xED, 0xF3]),
          base(a=0x00, hl=0x1234, bc=0x5678, de=0x9ABC), vec(f=0x01, a=0x81), vec(hl=0xFFFF),
          "ED C1/C9/C3/F3: R800 MULUB/MULUW, NOPs on a Z80"),
    Group("edim", ins([0xED, 0x46], [0xED, 0x4E], [0xED, 0x56], [0xED, 0x5E], [0xED, 0x66], [0xED, 0x7E]),
          base(a=0x00), vec(f=0x01, a=0x81), vec(), "IM 0/1/2 and the undocumented duplicates"),
]

# ------------------------------------------------------- Z80 engine (ROM)
ENGINE = """
    org 0x4000
    db 0x41, 0x42       ; 'AB'
    dw init
    dw 0, 0, 0, 0, 0, 0
init:
    di
    ld sp, {STACK}
    in a, (0xa8)        ; page 2 = page 1's primary slot
    and 0x0c
    rlca
    rlca
    ld c, a
    in a, (0xa8)
    and 0xcf
    or c
    out (0xa8), a
    ld hl, crctab
    ld de, {CRCT}
    ld bc, 1024
    ldir
    xor a
    ld ({NFAIL}), a
    call {INITXT}
    ld hl, title
    call puts
    ld hl, groups
grploop:
    ld e, (hl)
    inc hl
    ld d, (hl)
    inc hl
    ld a, d
    or e
    jr z, alldone
    push hl
    ex de, hl
    call rungroup
    pop hl
    jr grploop
alldone:
    ld hl, donemsg
    call puts
    ld a, ({NFAIL})
    call puthex
    ld hl, failmsg
    call puts
stop:
    jr stop

; ---- one group: HL = descriptor
rungroup:
    ld ({DESC}), hl
    ld a, 0xff
    ld ({CRC}), a
    ld ({CRC1}), a
    ld ({CRC2}), a
    ld ({CRC3}), a
    ld de, 4
    add hl, de
    ld a, (hl)
    ld ({FMASK}), a
    inc hl
    ld a, (hl)
    ld ({IUTN}), a
    inc hl
    ld de, 48
    add hl, de
    ld e, (hl)
    inc hl
    ld d, (hl)
    ld ({IUTP}), de
    inc hl
    push hl
    call puts           ; name (8 chars, padded)
    pop hl
iutloop:
    ld hl, ({IUTP})
    ld de, {IUT}
    ld bc, 4
    ldir
    ld ({IUTP}), hl
    ld a, 0xc3
    ld ({IUT4}), a
    ld hl, done
    ld ({IUT5}), hl
    xor a
    ld ({SHI}), a
    ld ({SHB}), a
    call clrshift
shiftloop:
    ld hl, {COUNT}
    call clear16
countloop:
    call execute
    call countinc
    jr nc, countloop
    call shiftnext
    jr nc, shiftloop
    ld hl, ({IUTP})
    ld a, ({IUTN})
    dec a
    ld ({IUTN}), a
    jr nz, iutloop
    ; print the CRC and compare it with the descriptor's
    ld a, ({CRC3})
    cpl
    call puthex
    ld a, ({CRC2})
    cpl
    call puthex
    ld a, ({CRC1})
    cpl
    call puthex
    ld a, ({CRC})
    cpl
    call puthex
    ld hl, ({DESC})
    ld de, {CRC}
    ld b, 4
cmploop:
    ld a, (de)
    cpl
    cp (hl)
    jr nz, bad
    inc hl
    inc de
    djnz cmploop
    ld hl, okmsg
    jp puts
bad:
    ld a, ({NFAIL})
    inc a
    ld ({NFAIL}), a
    ld hl, badmsg
    jp puts

; ---- vector = base ^ count ^ shift; run the instruction; CRC the results
execute:
    ld hl, ({DESC})
    ld de, 6
    add hl, de          ; base
    ld de, {VEC}
    ld b, 16
    ld ix, {COUNT}
    ld iy, {SHIFT}
mixloop:
    ld a, (hl)
    xor (ix+0)
    xor (iy+0)
    ld (de), a
    inc hl
    inc de
    inc ix
    inc iy
    djnz mixloop
    ld a, ({VEC})
    ld ({MSBT}), a
    ld a, ({VEC1})
    ld ({MSBT1}), a
    ld ({SPSAV}), sp
    ld sp, {VEC2}
    pop iy
    pop ix
    pop hl
    pop de
    pop bc
    pop af
    ld sp, ({VEC14})
    jp {IUT}
done:
    ld ({RES14}), sp
    ld sp, {RES14}
    push af
    push bc
    push de
    push hl
    push ix
    push iy
    ld sp, ({SPSAV})
    ld a, ({MSBT})
    ld ({RES}), a
    ld a, ({MSBT1})
    ld ({RES1}), a
    ld a, ({FMASK})
    ld hl, {RES12}
    and (hl)
    ld (hl), a
    ld hl, {RES}
    ld b, 16
crcloop:
    ld a, (hl)
    push hl
    push bc
    call updcrc
    pop bc
    pop hl
    inc hl
    djnz crcloop
    ret

; ---- CRC-32 (reflected, EDB88320h), one byte in A
updcrc:
    ld hl, {CRC}
    xor (hl)
    ld e, a
    ld d, {CRCTH}
    ld a, (de)
    inc hl
    xor (hl)
    ld ({CRC}), a
    inc d
    ld a, (de)
    inc hl
    xor (hl)
    ld ({CRC1}), a
    inc d
    ld a, (de)
    inc hl
    xor (hl)
    ld ({CRC2}), a
    inc d
    ld a, (de)
    ld ({CRC3}), a
    ret

; ---- binary counter over the bits of the counter mask; CY = wrapped
countinc:
    ld hl, ({DESC})
    ld de, 22
    add hl, de          ; counter mask
    ld de, {COUNT}
    ld b, 16
cntloop:
    ld a, (hl)
    or a
    jr z, cntnext
    cpl
    ld c, a             ; ~mask
    ld a, (de)
    or c
    inc a
    jr z, cntwrap
    and (hl)
    ld (de), a
    or a                ; CY clear: not wrapped
    ret
cntwrap:
    xor a
    ld (de), a
cntnext:
    inc hl
    inc de
    djnz cntloop
    scf
    ret

; ---- shifter: one bit of the shifter mask at a time; CY = no more bits
shiftnext:
    call clrshift
    ld a, ({SHI})
    ld c, a
    ld a, ({SHB})
    or a
    jr nz, shiftadv
    ld a, 1
    jr shiftfind
shiftadv:
    rlca
    jr nc, shiftfind
    inc c
shiftfind:
    ld b, a
    ld a, c
    cp 16
    jr nc, shiftend
    ld hl, ({DESC})
    ld de, 38
    add hl, de          ; shifter mask
    ld e, c
    ld d, 0
    add hl, de
    ld a, (hl)
    and b
    jr nz, shifthit
    ld a, b
    rlca
    jr nc, shiftfind
    inc c
    jr shiftfind
shifthit:
    ld a, c
    ld ({SHI}), a
    ld a, b
    ld ({SHB}), a
    ld hl, {SHIFT}
    add hl, de
    ld (hl), b
    or a
    ret
shiftend:
    scf
    ret

clrshift:
    ld hl, {SHIFT}
clear16:
    ld b, 16
    xor a
clrloop:
    ld (hl), a
    inc hl
    djnz clrloop
    ret

; ---- text through the BIOS
puts:
    ld a, (hl)
    or a
    ret z
    push hl
    call {CHPUT}
    pop hl
    inc hl
    jr puts
puthex:
    push af
    rrca
    rrca
    rrca
    rrca
    call putnib
    pop af
putnib:
    and 0x0f
    add a, 0x90
    daa
    adc a, 0x40
    daa
    jp {CHPUT}
"""


def assemble(groups, flagmask, label):
    """Returns the 32 KB ROM image with the group descriptors and tables."""
    consts = dict(STACK=STACK, CRCT=CRCT, CRCTH=CRCT >> 8, NFAIL=NFAIL, INITXT=INITXT,
                  CHPUT=CHPUT, DESC=DESC, CRC=CRC, CRC1=CRC + 1, CRC2=CRC + 2, CRC3=CRC + 3,
                  FMASK=FMASK, IUTN=IUTN, IUTP=IUTP, IUT=IUT, IUT4=IUT + 4, IUT5=IUT + 5,
                  SHI=SHI, SHB=SHB, COUNT=COUNT, VEC=VEC, VEC1=VEC + 1, VEC2=VEC + 2,
                  VEC14=VEC + 14, SHIFT=SHIFT, MSBT=MSBT, MSBT1=MSBT + 1, SPSAV=SPSAV,
                  RES=RES, RES1=RES + 1, RES12=RES + 12, RES14=RES + 14)
    src = ENGINE.format(**consts)
    src = "\n".join(line.split(";")[0].rstrip() for line in src.split("\n"))
    lines = [src]
    msg = "ZEX MSX %s F&%02Xh\r\n" % (label, flagmask)
    lines.append("title:\n    db " + ",".join(str(c) for c in msg.encode()) + ",0")
    lines.append("donemsg:\n    db 13,10,68,79,78,69,32,0")        # "\r\nDONE "
    lines.append("failmsg:\n    db 32,70,65,73,76,13,10,0")         # " FAIL\r\n"
    lines.append("okmsg:\n    db 32,79,75,32,0")                     # " OK "
    lines.append("badmsg:\n    db 32,33,33,32,0")                    # " !! "
    lines.append("groups:\n    dw " + ", ".join("g%d" % i for i in range(len(groups))) + ", 0")
    for i, g in enumerate(groups):
        crc = g.crc if g.crc is not None else 0
        d = crc.to_bytes(4, "little") + bytes([flagmask, len(g.iuts)]) + g.base + g.count + g.shift
        name = g.name.ljust(8).encode() + b"\0"
        iuts = b"".join(g.iuts)
        lines.append("g%d:\n    db %s\n    dw i%d\n    db %s\ni%d:\n    db %s" % (
            i, ",".join(str(c) for c in d), i, ",".join(str(c) for c in name), i,
            ",".join(str(c) for c in iuts)))
    table = bytearray(1024)
    for k in range(4):
        for i in range(256):
            c = i
            for _ in range(8):
                c = (c >> 1) ^ 0xEDB88320 if c & 1 else c >> 1
            table[k * 256 + i] = (c >> (8 * k)) & 0xFF
    lines.append("    org %d\ncrctab:\n    db " % CRCTAB + ",".join(str(c) for c in table))
    code = z80.Asm().assemble(z80.SourceFile("zex.asm", "\n".join(lines) + "\n"))
    code.resolve()
    rom = bytearray([0xFF] * 0x8000)
    for addr, data in code.encode():
        assert ROM <= addr and addr + len(data) <= ROM + 0x8000, (hex(addr), len(data))
        if addr < CRCTAB:
            assert addr + len(data) <= CRCTAB, "code overruns the CRC tables"
        rom[addr - ROM:addr - ROM + len(data)] = data
    return bytes(rom), code.get_symbol("stop").evaluate()


# ----------------------------------------------- reference run (Python)
def count_values(mask):
    """Every value of a binary counter over the set bits of a 16-byte mask."""
    bits = [(i, 1 << b) for i in range(16) for b in range(8) if mask[i] >> b & 1]
    for n in range(1 << len(bits)):
        v = bytearray(16)
        for k, (i, b) in enumerate(bits):
            if n >> k & 1:
                v[i] |= b
        yield bytes(v)


def shift_values(mask, quick):
    yield bytes(16)
    if quick:
        return
    for i in range(16):
        for b in range(8):
            if mask[i] >> b & 1:
                v = bytearray(16)
                v[i] = 1 << b
                yield bytes(v)


def reference(g, flagmask, quick):
    """CRC of the group as the ROM computes it, from the z80 package."""
    m = z80.Z80Machine()
    m.set_input_callback(lambda port: 0xFF)
    m.set_output_callback(lambda port, value: None)
    crc = 0xFFFFFFFF
    cases = 0
    for iut in g.iuts:
        m.set_memory_block(IUT, iut + b"\xC3" + (IUT + 7).to_bytes(2, "little") + b"\x00")
        m.set_breakpoint(IUT + 7)
        for sh in shift_values(g.shift, quick):
            for cn in count_values(g.count):
                v = bytes(a ^ b ^ c for a, b, c in zip(g.base, cn, sh))
                m.set_memory_block(MSBT, v[0:2])
                m.iy = int.from_bytes(v[2:4], "little")
                m.ix = int.from_bytes(v[4:6], "little")
                m.hl = int.from_bytes(v[6:8], "little")
                m.de = int.from_bytes(v[8:10], "little")
                m.bc = int.from_bytes(v[10:12], "little")
                m.f, m.a = v[12], v[13]
                m.sp = int.from_bytes(v[14:16], "little")
                m.pc = IUT
                while True:                 # run() also returns at frame ends
                    m.ticks_to_stop = 1000
                    m.run()
                    if m.pc == IUT + 7:     # the JP after the instruction
                        break
                    assert m.ticks_to_stop, (g.name, iut.hex(), hex(m.pc))
                res = (bytes(m.memory[MSBT:MSBT + 2]) + m.iy.to_bytes(2, "little")
                       + m.ix.to_bytes(2, "little") + m.hl.to_bytes(2, "little")
                       + m.de.to_bytes(2, "little") + m.bc.to_bytes(2, "little")
                       + bytes([m.f & flagmask, m.a]) + m.sp.to_bytes(2, "little"))
                crc = zlib.crc32(res, crc ^ 0xFFFFFFFF) ^ 0xFFFFFFFF
                cases += 1
    g.cases = cases
    return crc ^ 0xFFFFFFFF


def selftest(rom, stop):
    """Runs the ROM in the Python emulator with a BIOS stub; returns the text."""
    m = z80.Z80Machine()
    m.set_memory_block(ROM, rom)
    m.set_memory_block(CHPUT, b"\xC9")
    m.set_memory_block(INITXT, b"\xC9")
    m.set_input_callback(lambda port: 0xFF)
    m.set_output_callback(lambda port, value: None)
    m.set_breakpoint(CHPUT)
    m.set_breakpoint(stop)
    m.pc = ROM + 0x10
    out = []
    for _ in range(1 << 24):
        m.ticks_to_stop = 1 << 30
        m.run()                             # returns at breakpoints and frame ends
        if m.pc == stop:
            break
        if m.pc == CHPUT:
            out.append(chr(m.a))
            m.step_over_breakpoint()
    else:
        raise AssertionError("the ROM does not finish")
    text = "".join(out)
    # SCREEN 0 wraps at 40 columns; the ROM prints two groups per line
    lines = []
    for ln in text.split("\r\n"):
        lines += [ln[i:i + 40] for i in range(0, max(len(ln), 1), 40)]
    return "\n".join(lines)


def main():
    args = sys.argv[1:]
    if not args:
        sys.exit(__doc__)
    out, flags, quick, listing, test = args[0], "doc", False, None, False
    i = 1
    while i < len(args):
        if args[i] == "--flags":
            flags = args[i + 1]; i += 2
        elif args[i] == "--quick":
            quick = True; i += 1
        elif args[i] == "--list":
            listing = args[i + 1]; i += 2
        elif args[i] == "--selftest":
            test = True; i += 1
        else:
            sys.exit("unknown option " + args[i])
    flagmask = FLAGMASK[flags]
    total = 0
    for g in GROUPS:
        if quick:
            g.shift = bytes(16)
        g.crc = reference(g, flagmask, quick)
        total += g.cases
    label = flags + ("-quick" if quick else "")
    rom, stop = assemble(GROUPS, flagmask, label)
    open(out, "wb").write(rom)
    print("%s: %d groups, %d cases, %d bytes of ROM" % (out, len(GROUPS), total, len(rom)))
    if listing:
        with open(listing, "w") as f:
            f.write("group     cases     crc       instructions\n")
            for g in GROUPS:
                f.write("%-9s %8d  %08X  %s\n" % (g.name, g.cases, g.crc, g.note))
    if test:
        text = selftest(rom, stop)
        print(text)
        if " !! " in text or "DONE 00" not in text:
            sys.exit("selftest: the ROM's CRCs differ from the reference")


if __name__ == "__main__":
    main()
