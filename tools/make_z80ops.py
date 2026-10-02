"""Z80 operand-form and condition test cartridge (32 KB, pages 1-2). Companion to
make_z80flags.py, which only uses register B: this runs the 8-bit ALU
instructions with every operand form (B C D E H L (HL) (IX+d) (IY+d) n) and
checks the conditional jumps (JP/JR/CALL/RET cc) after POP AF for every
combination of S Z PV C. Results go to VRAM from address 0; compare with
openMSX as for make_z80flags.py.
Usage: python tools/make_z80ops.py out.rom [cases.txt]"""
import sys

VALS = [(0x00, 0x00), (0x01, 0xFF), (0x7F, 0x01), (0x80, 0x01), (0x80, 0x7F), (0x10, 0x20),
        (0x05, 0x80), (0x40, 0xC0)]
OUT_A = [0xD3, 0x98]                       # OUT (98h),A
OUT_F = [0xF5, 0xE1, 0x7D, 0xD3, 0x98]     # PUSH AF; POP HL; LD A,L; OUT (98h),A
RAM = 0xC000
ALU = {"ADD": 0, "ADC": 1, "SUB": 2, "SBC": 3, "AND": 4, "XOR": 5, "OR": 6, "CP": 7}
REG = {"B": 0, "C": 1, "D": 2, "E": 3, "H": 4, "L": 5}


def carry(c):
    return [0x37] if c else [0x37, 0x3F]   # SCF / SCF;CCF


code, cases = [], []
code += [0xF3, 0x31, 0x80, 0xF3]           # DI; LD SP,F380h
# page 2 = page 1's primary slot (the BIOS only maps page 1 of a cartridge)
code += [0xDB, 0xA8, 0xE6, 0x0C, 0x07, 0x07, 0x4F,   # IN A,(A8h); AND 0Ch; RLCA; RLCA; LD C,A
         0xDB, 0xA8, 0xE6, 0xCF, 0xB1, 0xD3, 0xA8]   # IN A,(A8h); AND CFh; OR C; OUT (A8h),A
code += [0x3E, 0x00, 0xD3, 0x99, 0x3E, 0x40, 0xD3, 0x99]   # VRAM write address 0000h
code += [0xDD, 0x21, (RAM - 5) & 255, (RAM - 5) >> 8]      # LD IX,RAM-5
code += [0xFD, 0x21, (RAM + 3) & 255, (RAM + 3) >> 8]      # LD IY,RAM+3
for name, n in ALU.items():
    for form in list(REG) + ["(HL)", "(IX+5)", "(IY-3)", "n"]:
        for a, b in VALS:
            for c in ((0, 1) if name in ("ADC", "SBC") else (0,)):
                if form in REG:
                    setup = [0x06 | REG[form] << 3, b]               # LD r,b
                    op = [0x80 | n << 3 | REG[form]]
                elif form == "(HL)":
                    setup = [0x21, RAM & 255, RAM >> 8, 0x36, b]     # LD HL,RAM; LD (HL),b
                    op = [0x86 | n << 3]
                elif form == "(IX+5)":
                    setup = [0xDD, 0x36, 5, b]                       # LD (IX+5),b
                    op = [0xDD, 0x86 | n << 3, 5]
                elif form == "(IY-3)":
                    setup = [0xFD, 0x36, 0xFD, b]                    # LD (IY-3),b
                    op = [0xFD, 0x86 | n << 3, 0xFD]
                else:
                    setup, op = [], [0xC6 | n << 3, b]
                code += setup + carry(c) + [0x3E, a] + op + OUT_A + OUT_F
                cases.append(f"{name} {form} A={a:02X} B={b:02X} C={c}: A F")

# Conditions: F from POP AF, then each cc. Result byte: bit k set = condition k taken
# (k = NZ Z NC C PO PE P M). Uses B as the accumulator for the bits.
CCS = ["NZ", "Z", "NC", "C", "PO", "PE", "P", "M"]
for kind in ("JP", "JR", "CALL", "RET"):
    for f in range(16):
        F = (f & 1) | ((f >> 1 & 1) << 2) | ((f >> 2 & 1) << 6) | ((f >> 3 & 1) << 7)   # C PV Z S
        code += [0x06, 0x00]                                     # LD B,0
        for k, cc in enumerate(CCS):
            if kind == "JR" and k >= 4:
                break
            code += [0x21, F, 0x00, 0xE5, 0xF1]                  # LD HL,00F; PUSH HL; POP AF
            if kind == "JP":
                code += [0xC2 | k << 3]; tgt = len(code) + 2 + 2  # JP cc,skip over "JR +2"
                code += [(0x4010 + tgt) & 255, (0x4010 + tgt) >> 8, 0x18, 0x02]
                code += [0xCB, 0xC0 | k << 3]                    # SET k,B
            elif kind == "JR":
                code += [0x20 | k << 3, 0x02, 0x18, 0x02, 0xCB, 0xC0 | k << 3]
            elif kind == "CALL":
                # CALL cc,sub where sub does SET k,B; RET (placed inline behind a JR)
                code += [0x18, 0x03, 0xCB, 0xC0 | k << 3, 0xC9]   # JR over sub
                sub = 0x4010 + len(code) - 3
                code += [0x21, F, 0x00, 0xE5, 0xF1]
                code += [0xC4 | k << 3, sub & 255, sub >> 8]
            else:
                # PUSH return target, RET cc: taken -> lands on SET k,B; not taken -> pop it
                tgt = 0x4010 + len(code) + 3 + 1 + 1 + 1 + 2
                code += [0x11, tgt & 255, tgt >> 8, 0xD5]        # LD DE,tgt; PUSH DE
                code += [0xC0 | k << 3]                           # RET cc
                code += [0xD1, 0x18, 0x02]                        # POP DE; JR +2 (not taken)
                code += [0xCB, 0xC0 | k << 3]                     # tgt: SET k,B
        code += [0x78, 0xD3, 0x98]                               # LD A,B; OUT (98h),A
        cases.append(f"{kind} cc F={F:02X}: taken")
code += [0x18, 0xFE]                       # JR $
rom = bytearray([0xFF] * 0x8000)
rom[0:4] = b"AB\x10\x40"
rom[0x10:0x10 + len(code)] = bytes(code)
assert 0x10 + len(code) <= 0x8000, len(code)
open(sys.argv[1], "wb").write(rom)
if len(sys.argv) > 2:
    open(sys.argv[2], "w").write("\n".join(cases) + "\n")
print(f"{len(cases)} cases, {len(code)} bytes of code")
