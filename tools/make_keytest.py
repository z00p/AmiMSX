"""Keyboard mapping test: a cartridge that logs every change of the MSX keyboard
matrix (rows 0-10, read through the PPI as a game does), a key script that presses
every Amiga raw key code 00-67 except Help (5F, which quits to AmiMSX's menu) through AmiMSX's own Amiga-to-MSX table (AKEY), and
the expected result parsed from that table (TECLADO in AmiMSX_Main_v3.1.asm, MSX2
machine, default options). Run with a TRACE build that freezes at the cartridge's
end loop (-DTRACE=1 -DTRACEPC=<end+1>); tools/read_keytest.py reads the log from the
VRAM copy in trace.bin and compares.
Usage: python tools/make_keytest.py <outdir>   (writes T_KeyTest.rom, keytest.keys,
keytest.json; copy the ROM to run/Roms)"""
import json, os, re, sys

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ORG, START, GAP, HOLD, ENDF = 0x4000, 450, 12, 4, 2000   # script frames; ROM end frame
ROWNAMES = ["0 1 2 3 4 5 6 7", "8 9 - ^ BSLASH @ [ ;", ": ] , . / _ A B", "C D E F G H I J",
            "K L M N O P Q R", "S T U V W X Y Z", "SHIFT CTRL GRAPH CAPS CODE F1 F2 F3",
            "F4 F5 ESC TAB STOP BS SELECT RETURN", "SPACE HOME INS DEL LEFT UP DOWN RIGHT",
            "KP* KP+ KP/ KP0 KP1 KP2 KP3 KP4", "KP5 KP6 KP7 KP8 KP9 KP- KP, KP."]


def name(row, bit):
    return ROWNAMES[row].split()[bit] if 0 <= row < 11 else f"row{row}"


def table():
    src = open(os.path.join(BASE, "AmiMSX_Main_v3.1.asm"), encoding="latin-1").read()
    a = src.index("\nTECLADO:")
    vals = []
    for line in src[a:].splitlines()[2:]:
        m = re.match(r"\s*DC\.B\s+([^;]+)", line)
        if not m:
            break
        vals += [int(x) for x in m.group(1).split(",")]
    return [(vals[2 * i], vals[2 * i + 1]) for i in range(len(vals) // 2)]


class Asm:
    def __init__(self):
        self.b, self.lab, self.fix = [], {}, []

    def pc(self):
        return ORG + 16 + len(self.b)

    def __call__(self, *bs):
        self.b += list(bs)

    def L(self, n):
        self.lab[n] = self.pc()

    def jr(self, op, n):
        self.b += [op, 0]; self.fix.append((len(self.b) - 1, n))

    def done(self):
        for i, n in self.fix:
            d = self.lab[n] - (ORG + 16 + i + 1)
            assert -128 <= d < 128, n
            self.b[i] = d & 255
        return bytes(self.b)


def rom():
    a = Asm()
    PREV, FR = 0xC000, 0xC010
    a(0xF3, 0x31, 0x80, 0xF3)                       # DI; LD SP,F380h
    a(0x3E, 0x00, 0xD3, 0x99, 0x3E, 0x40, 0xD3, 0x99)   # VRAM write address 0000h
    a(0x21, PREV & 255, PREV >> 8, 0x06, 11)        # LD HL,PREV; LD B,11
    a.L("ini"); a(0x36, 0xFF, 0x23); a.jr(0x10, "ini")  # LD (HL),FFh; INC HL; DJNZ
    a(0x21, 0, 0, 0x22, FR & 255, FR >> 8)          # LD HL,0; LD (FR),HL
    a.L("loop")
    a.L("vbl"); a(0xDB, 0x99, 0x07); a.jr(0x30, "vbl")   # IN A,(99h); RLCA; JR NC (S#0 bit 7)
    a(0x2A, FR & 255, FR >> 8, 0x23, 0x22, FR & 255, FR >> 8)   # frame + 1
    a(0x0E, 0x00)                                   # LD C,0 (row)
    a.L("row")
    a(0xDB, 0xAA, 0xE6, 0xF0, 0xB1, 0xD3, 0xAA, 0xDB, 0xA9)   # select row C; IN A,(A9h)
    a(0x21, PREV & 255, PREV >> 8, 0x06, 0x00, 0x09)          # LD HL,PREV; LD B,0; ADD HL,BC
    a(0xBE); a.jr(0x28, "same")                     # CP (HL); JR Z
    a(0x77, 0x57)                                   # LD (HL),A; LD D,A
    a(0x2A, FR & 255, FR >> 8, 0x7D, 0xD3, 0x98, 0x7C, 0xD3, 0x98)   # log frame lo, hi
    a(0x79, 0xD3, 0x98, 0x7A, 0xD3, 0x98)           # log row, value
    a.L("same")
    a(0x0C, 0x79, 0xFE, 11); a.jr(0x20, "row")      # INC C; LD A,C; CP 11; JR NZ
    a(0x2A, FR & 255, FR >> 8, 0x11, ENDF & 255, ENDF >> 8, 0xB7, 0xED, 0x52)   # HL - ENDF
    a.jr(0x38, "loop")                              # JR C (not yet)
    a.L("end"); a.jr(0x18, "end")                   # JR $ (TRACEPC = end + 1)
    code = a.done()
    r = bytearray(16384)
    r[0:4] = b"AB" + bytes([(ORG + 16) & 255, (ORG + 16) >> 8])
    r[16:16 + len(code)] = code
    return bytes(r), a.lab["end"]


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    r, end = rom()
    open(os.path.join(out, "T_KeyTest.rom"), "wb").write(r)
    tab = table()
    exp, lines = [], ["# Keyboard mapping test: every Amiga raw key 00-67 through AmiMSX's table (AKEY)"]
    codes = [c for c in range(0x68) if c != 0x5F]   # not Help: it quits to AmiMSX's menu
    for i, code in enumerate(codes):
        bit, row = tab[code]
        f = START + i * GAP
        lines.append(f"{f} AKEY:{code:02X} {HOLD}")
        exp.append({"code": code, "frame": f, "row": row, "bit": bit,
                    "key": "CAPS (toggle)" if row < 0 else name(row, bit)})
    open(os.path.join(out, "keytest.keys"), "w").write("\n".join(lines) + "\n")
    json.dump({"end": end, "start": START, "gap": GAP, "hold": HOLD, "keys": exp},
              open(os.path.join(out, "keytest.json"), "w"), indent=0)
    print(f"ROM end {end:04X} (TRACEPC=${end + 1:04X}), {len(exp)} keys, script ends at frame {exp[-1]['frame'] + HOLD}")


main()
