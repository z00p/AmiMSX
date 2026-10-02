"""Z80 flag test cartridge (16 KB, page 1): runs arithmetic/logic instructions
over edge-case operands, with carry in clear and set, and writes each result
(A then F; HL then F for 16-bit) to VRAM from address 0. Run it in AmiMSX and
openMSX and compare VRAM to find instructions whose results or flags differ.
Usage: python tools/make_z80flags.py out.rom [cases.txt]"""
import sys

V8 = [0x00, 0x01, 0x0F, 0x7F, 0x80, 0xFF]
V16 = [0x0000, 0x0001, 0x7FFF, 0x8000, 0x0FFF, 0xFFFF]
OUT_A = [0xD3, 0x98]                       # OUT (98h),A
OUT_F = [0xF5, 0xE1, 0x7D, 0xD3, 0x98]     # PUSH AF; POP HL; LD A,L; OUT (98h),A


def carry(c):
    return [0x37] if c else [0x37, 0x3F]   # SCF / SCF;CCF


code, cases = [], []
code += [0xF3, 0x31, 0x80, 0xF3]           # DI; LD SP,F380h
code += [0x3E, 0x00, 0xD3, 0x99, 0x3E, 0x40, 0xD3, 0x99]   # VRAM write address 0000h
binops = {"ADD A,B": [0x80], "ADC A,B": [0x88], "SUB B": [0x90], "SBC A,B": [0x98],
          "AND B": [0xA0], "XOR B": [0xA8], "OR B": [0xB0], "CP B": [0xB8]}
for name, op in binops.items():
    for a in V8:
        for b in V8:
            for c in (0, 1):
                code += carry(c) + [0x3E, a, 0x06, b] + op + OUT_A + OUT_F
                cases.append(f"{name} A={a:02X} B={b:02X} C={c}: A F")
unops = {"INC A": [0x3C], "DEC A": [0x3D], "NEG": [0xED, 0x44], "CPL": [0x2F],
         "RLCA": [0x07], "RRCA": [0x0F], "RLA": [0x17], "RRA": [0x1F], "DAA": [0x27]}
for name, op in unops.items():
    for a in V8 + [0x09, 0x99, 0x9A, 0x50]:
        for c in (0, 1):
            code += carry(c) + [0x3E, a] + op + OUT_A + OUT_F
            cases.append(f"{name} A={a:02X} C={c}: A F")
for name, op in {"ADD;DAA": [0x80, 0x27], "SUB;DAA": [0x90, 0x27]}.items():
    for a in (0x09, 0x15, 0x45, 0x99, 0x50, 0x01):
        for b in (0x01, 0x09, 0x27, 0x55, 0x99):
            code += [0x37, 0x3F, 0x3E, a, 0x06, b] + op + OUT_A + OUT_F
            cases.append(f"{name} A={a:02X} B={b:02X}: A F")
w16 = {"ADD HL,BC": [0x09], "ADC HL,BC": [0xED, 0x4A], "SBC HL,BC": [0xED, 0x42]}
for name, op in w16.items():
    for hl in V16:
        for bc in V16:
            for c in (0, 1):
                code += carry(c) + [0x21, hl & 255, hl >> 8, 0x01, bc & 255, bc >> 8] + op
                code += [0xF5, 0x7C, 0xD3, 0x98, 0x7D, 0xD3, 0x98, 0xF1]   # PUSH AF; out H, L; POP AF
                code += OUT_F                                            # (HL lost: F last)
                cases.append(f"{name} HL={hl:04X} BC={bc:04X} C={c}: H L F")
code += [0x18, 0xFE]                       # JR $
rom = bytearray([0xFF] * 0x4000)
rom[0:4] = b"AB\x10\x40"
rom[0x10:0x10 + len(code)] = bytes(code)
assert 0x10 + len(code) <= 0x4000, len(code)
open(sys.argv[1], "wb").write(rom)
if len(sys.argv) > 2:
    open(sys.argv[2], "w").write("\n".join(cases) + "\n")
print(f"{len(cases)} cases, {len(code)} bytes of code")
