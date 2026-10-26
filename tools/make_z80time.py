"""Z80 timing audit cartridge (32 KB, pages 1-2): runs every documented instruction of
grauw's table (map.grauw.nl/resources/z80instr.php, saved as JSON by
build/z80t/grauw.json) once, in a straight line, conditional ones taken and not
taken, block ones with one repeat. Each test is preceded by a register restore
block (DI first: the EI, RETN and IM 2 tests would let the VBlank interrupt in), so all memory operands point at RAM. Run it with a CYCLOG trace build
(-DTRACE=1 -DCYCLOG=1 -DTRACEPC=<end+1>); tools/read_z80time.py compares each
instruction's cost (the drop of the line's cycle counter between two trace
entries) with the Z80+M1 column.
Usage: python tools/make_z80time.py grauw.json out.rom out.json"""
import itertools, json, re, sys

ORG, RAM, STK, PORT = 0x4000, 0xC000, 0xF000, 0x30
VARS = {"r": [0, 1, 2, 3, 4, 5, 7], "p": [0, 1, 2, 3, 4, 5, 7], "q": [0, 1, 2, 3, 4, 5, 7], "b": range(8)}
RN = "B C D E H L (HL) A".split()
SKIP = ("HALT", "RST", "MULUB", "MULUW")
COND = {"NZ": ("B", "A"), "Z": ("A", "B"), "NC": ("A", "AC"), "C": ("AC", "A"),
        "PO": ("B", "A"), "PE": ("A", "B"), "P": ("A", "B"), "M": ("B", "A")}
RESTORE = [("DI", [0xF3]), ("LD SP,nn", [0x31, STK & 255, STK >> 8]), ("LD HL,nn", [0x21, 0x00, 0xC0]),
           ("LD DE,nn", [0x11, 0x00, 0xC1]), ("LD BC,nn", [0x01, 0x00, 0xC2]),
           ("LD IX,nn", [0xDD, 0x21, 0x00, 0xC0]), ("LD IY,nn", [0xFD, 0x21, 0x00, 0xC0])]


def expand(row):
    toks = row["op"].split()
    names = sorted({v for t in toks if not re.fullmatch("[0-9A-F]{2}|nn|n|o|e", t)
                    for v in re.findall("[rpqb]", t)})
    for combo in itertools.product(*(VARS[n] for n in names)):
        env = dict(zip(names, combo))
        out = []
        for t in toks:
            if re.fullmatch("[0-9A-F]{2}|nn|n|o|e", t):
                out.append(t)
            else:
                out.append("%02X" % eval(re.sub(r"([0-9A-F]{2})", r"0x\1", t), {}, env))
        ins = row["ins"]
        for k, v in env.items():
            sub = str(v) if k == "b" else RN[v]
            if k in "pq":
                sub = {4: "IXh" if k == "p" else "IYh", 5: "IXl" if k == "p" else "IYl"}.get(v, RN[v])
            if k in "pq" and re.search("I[XY]" + k, ins):
                ins = re.sub("I[XY]" + k, sub, ins, count=1)
            else:
                ins = re.sub(r"\b%s\b" % k, sub, ins, count=1)
        yield ins, out


def main():
    rows = json.load(open(sys.argv[1]))
    code, tests = [], []
    pc = lambda: ORG + 16 + len(code)

    def emit(name, bts, test=None, expect=None):
        a = pc()
        code.extend(bts)
        tests.append({"addr": a, "len": len(bts), "ins": name, "test": test, "expect": expect})

    emit("DI", [0xF3]); emit("LD SP,nn", [0x31, STK & 255, STK >> 8])
    # page 2 = page 1's primary slot (the BIOS only maps page 1 of a cartridge)
    for nm, b in [("IN A,(n)", [0xDB, 0xA8]), ("AND n", [0xE6, 0x0C]), ("RLCA", [0x07]), ("RLCA", [0x07]),
                  ("LD C,A", [0x4F]), ("IN A,(n)", [0xDB, 0xA8]), ("AND n", [0xE6, 0xCF]), ("OR C", [0xB1]),
                  ("OUT (n),A", [0xD3, 0xA8])]:
        emit(nm, b)
    emit("LD HL,nn", [0x21, 0x00, 0xC0]); emit("LD (nn),HL", [0x22, 0x00, 0xC3])
    for row in rows:
        if not row["m1"] or row["ins"].startswith(SKIP):
            continue
        for ins, toks in expand(row):
            m = re.match(r"(JP|JR|CALL|RET) (NZ|Z|NC|C|PO|PE|P|M)\b", ins)
            exp = [int(x) for x in row["m1"].split("/")]
            variants = [("taken", COND[m.group(2)][0], exp[0]), ("not taken", COND[m.group(2)][1], exp[-1])] if m \
                else [("", None, None)]
            if ins.startswith("DJNZ"):
                variants = [("taken", "B2", exp[0]), ("not taken", "B1", exp[-1])]
            for tag, fl, e in variants:
                for nm, b in RESTORE:
                    emit(nm, b)
                if fl in ("A", "AC"):
                    emit("XOR A", [0xAF])
                if fl == "AC":
                    emit("SCF", [0x37])
                if fl == "B":
                    emit("LD A,n", [0x3E, 0x80]); emit("OR A", [0xB7])
                if fl == "B2":
                    emit("LD B,n", [0x06, 2])
                if fl == "B1":
                    emit("LD B,n", [0x06, 1])
                base = ins.split()[0]
                if re.match(r"(LD|CP|IN|OT|OUT)[ID]R?$", base) and base not in ("IN", "OUT", "LD"):
                    emit("LD BC,nn", [0x01, 0x30, 0x02] if base[:2] in ("IN", "OT", "OU") else [0x01, 0x02, 0x00])
                if base in ("CPI", "CPD", "CPIR", "CPDR"):   # no match: (C000/C001) = 55h, A = AAh
                    emit("LD A,n", [0x3E, 0x55]); emit("LD (nn),A", [0x32, 0x00, 0xC0])
                    emit("LD (nn),A", [0x32, 0x01, 0xC0]); emit("LD A,n", [0x3E, 0xAA])
                if re.match(r"(IN \w+,\(C\)|OUT \(C\))", ins) or ins in ("IN (C)", "IN F,(C)"):
                    emit("LD BC,nn", [0x01, PORT, 0x02])
                n = len(toks)
                if ins in ("JP (HL)",) or ins.startswith("RET"):
                    plen = 3 + (1 if ins.startswith("RET") else 0)
                    nxt = pc() + plen + n
                    emit("LD HL,nn", [0x21, nxt & 255, nxt >> 8])
                    if ins.startswith("RET"):
                        emit("PUSH HL", [0xE5])
                if ins in ("JP (IX)", "JP (IY)"):
                    nxt = pc() + 4 + n
                    emit("LD %s,nn" % ins[4:6], [0xDD if "IX" in ins else 0xFD, 0x21, nxt & 255, nxt >> 8])
                nxt = pc() + n
                bts, nhi = [], False
                for t in toks:
                    if t == "nn":          # (grauw writes a word as "nn nn": low, high)
                        if base in ("JP", "CALL"):
                            v = nxt
                        elif "SP," in ins and "(" not in ins:
                            v = STK
                        elif "(nn)" in ins:
                            v = 0xC300
                        else:
                            v = RAM
                        bts.append(v >> 8 if nhi else v & 255)
                        nhi = True
                    elif t == "n":
                        bts.append(PORT if "(n)" in ins else 1)
                    elif t in ("o", "e"):
                        bts.append(0)
                    else:
                        bts.append(int(t, 16))
                if e is None:
                    e = sum(int(x) for x in row["m1"].split("/")) if re.match(r"(LD|CP|IN|OT)[ID]R$", base) else exp[0]
                emit(ins, bts, test=(ins + (" (" + tag + ")" if tag else "")), expect=e)
    end = pc()
    emit("JR e", [0x18, 0xFE])              # end: JR $ (TRACEPC = end + 1)
    rom = bytearray(32768)
    rom[0:4] = b"AB" + bytes([(ORG + 16) & 255, (ORG + 16) >> 8])
    assert 16 + len(code) <= 32768, len(code)
    rom[16:16 + len(code)] = bytes(code)
    open(sys.argv[2], "wb").write(rom)
    json.dump({"end": end, "entries": tests}, open(sys.argv[3], "w"), indent=0)
    print(f"{sum(1 for t in tests if t['test'])} tests, {len(code)} bytes, end {end:04X} (TRACEPC=${end + 1:04X})")


main()
