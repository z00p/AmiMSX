r"""R800 instruction costs for the turbo R build (tools/r8map.py).

Every Otra site of the Z80 core (an instruction's end, 'Resta Cycles R8O') gets
its R800 cost from Docs/agent_notes/r800time.tsv (openMSX, R800 cycles: the
instruction plus its 'after'), matched to the opcodes that reach it by walking
the handlers in a vasm listing; the path's Z80 cost picks the table row, so
taken / not taken paths sort themselves out. Sites no listed opcode reaches
(undocumented opcodes, RST, ...) take the median R800 cost of the mapped sites
with the same Z80 cost. Writes r800cost.i (DC.W per site, in listing order).
Sites with an explicit R800 cost in the source (Otra n,r: 'R8H') are skipped.

  vasm -devpac -nocase -m68020 -Fhunkexe -nosym -DTURBOR=1 -DR8GEN=1 \
       -o NUL -L build.lst -Lall AmiMSX_Main_v3.1.asm
  python tools/r8map.py build.lst Docs/agent_notes/r800time.tsv r800cost.i [map.json]
"""
import re, sys, json
from collections import defaultdict

lst, tsv, outp = sys.argv[1:4]
mapout = sys.argv[4] if len(sys.argv) > 4 else None

# ---------------------------------------------------------------- Z80 names
R = "B C D E H L (HL) A".split()
RP = "BC DE HL SP".split()
RP2 = "BC DE HL AF".split()
CC = "NZ Z NC C PO PE P M".split()
ALU = ["ADD A,", "ADC A,", "SUB ", "SBC A,", "AND ", "XOR ", "OR ", "CP "]
ROT = "RLC RRC RL RR SLA SRA SLL SRL".split()


def sub_ix(s, ix):
    if ix is None:
        return s
    if "(HL)" in s:
        return s.replace("(HL)", "(%s+o)" % ix)
    s = re.sub(r"\bHL\b", ix, s)
    s = re.sub(r"\bH\b", ix + "h", s)
    s = re.sub(r"\bL\b", ix + "l", s)
    return s


def name_main(op, ix=None):
    x, y, z, p, q = op >> 6, (op >> 3) & 7, op & 7, (op >> 4) & 3, (op >> 3) & 1
    if x == 0:
        if z == 0:
            return ["NOP", "EX AF,AF'", "DJNZ o", "JR o"][y] if y < 4 else "JR %s,o" % CC[y - 4]
        if z == 1:
            return sub_ix("LD %s,nn" % RP[p], ix) if q == 0 else sub_ix("ADD HL,%s" % RP[p], ix)
        if z == 2:
            return sub_ix([["LD (BC),A", "LD (DE),A", "LD (nn),HL", "LD (nn),A"],
                           ["LD A,(BC)", "LD A,(DE)", "LD HL,(nn)", "LD A,(nn)"]][q][p], ix)
        if z == 3:
            return sub_ix(("INC %s" if q == 0 else "DEC %s") % RP[p], ix)
        if z == 4:
            return sub_ix("INC %s" % R[y], ix)
        if z == 5:
            return sub_ix("DEC %s" % R[y], ix)
        if z == 6:
            return sub_ix("LD %s,n" % R[y], ix)
        return "RLCA RRCA RLA RRA DAA CPL SCF CCF".split()[y]
    if x == 1:
        if y == 6 and z == 6:
            return "HALT"
        if ix and (y == 6 or z == 6):           # LD (IX+o),r / LD r,(IX+o): r stays H/L
            return "LD %s,%s" % (sub_ix(R[y], ix) if y == 6 else R[y], sub_ix(R[z], ix) if z == 6 else R[z])
        return sub_ix("LD %s,%s" % (R[y], R[z]), ix)
    if x == 2:
        return sub_ix(ALU[y] + R[z], ix)
    if z == 0:
        return "RET %s" % CC[y]
    if z == 1:
        if q == 0:
            return sub_ix("POP %s" % RP2[p], ix)
        return [None, "EXX", "JP (%s)" % (ix or "HL"), sub_ix("LD SP,HL", ix)][p] or "RET"
    if z == 2:
        return "JP %s,nn" % CC[y]
    if z == 3:
        return ["JP nn", None, "OUT (n),A", "IN A,(n)", sub_ix("EX (SP),HL", ix), "EX DE,HL", "DI", "EI"][y]
    if z == 4:
        return "CALL %s,nn" % CC[y]
    if z == 5:
        if q == 0:
            return sub_ix("PUSH %s" % RP2[p], ix)
        return "CALL nn" if p == 0 else None
    if z == 6:
        return ALU[y] + "n"
    return None                                 # RST: not in the table


def name_cb(op, ix=None):
    x, y, z = op >> 6, (op >> 3) & 7, op & 7
    if ix and z != 6:
        return None                             # undocumented copies
    r = "(%s+o)" % ix if ix else R[z]
    return ROT[y] + " " + r if x == 0 else "%s %d,%s" % (["", "BIT", "RES", "SET"][x], y, r)


def name_ed(op):
    x, y, z, p, q = op >> 6, (op >> 3) & 7, op & 7, (op >> 4) & 3, (op >> 3) & 1
    if x == 1:
        if z == 0:
            return "IN F,(C)" if y == 6 else "IN %s,(C)" % R[y]
        if z == 1:
            return None if y == 6 else "OUT (C),%s" % R[y]
        if z == 2:
            return ("SBC HL,%s" if q == 0 else "ADC HL,%s") % RP[p]
        if z == 3:
            return ("LD (nn),%s" if q == 0 else "LD %s,(nn)") % RP[p]
        if z == 4:
            return "NEG"
        if z == 5:
            return "RETI" if y == 1 else "RETN"
        if z == 6:
            return "IM %d" % [0, 0, 1, 2, 0, 0, 1, 2][y]
        return ["LD I,A", "LD R,A", "LD A,I", "LD A,R", "RRD", "RLD", None, None][y]
    if x == 2 and z <= 3 and y >= 4:
        return [["LDI", "CPI", "INI", "OUTI"], ["LDD", "CPD", "IND", "OUTD"],
                ["LDIR", "CPIR", "INIR", "OTIR"], ["LDDR", "CPDR", "INDR", "OTDR"]][y - 4][z]
    return None


# ---------------------------------------------------------------- the table
rows = defaultdict(list)
for line in open(tsv, encoding="utf-8").read().splitlines()[1:]:
    ins, test, z80m1, z80, r8, after = (line.split("\t") + [""])[:6]
    if not after or (ins, int(z80m1)) in [(i, z) for i in [ins] for z, _, _ in rows[ins]]:
        continue                    # (the run's tail rows: no follower / repeats)
    rows[ins].append((int(z80m1), int(r8) + int(after), test))

# ---------------------------------------------------------------- listing
A = []          # (addr, text) of assembled lines, in order
labels = {}
pend = []
for raw in open(lst, encoding="latin-1"):
    m = re.match(r"^\d\d:([0-9A-F]{8}) ([0-9A-F]*)\s*\t\s*(\d+M?)(?::| ) ?(.*)$", raw.rstrip("\n"))
    m2 = re.match(r"^\s+\t\s*(\d+M?)(?::| ) ?(.*)$", raw.rstrip("\n")) if not m else None
    text = (m.group(4) if m else m2.group(2) if m2 else "").split(";")[0].rstrip()
    lab = re.match(r"^([A-Za-z_.][\w.]*):", text) or (re.match(r"^([A-Za-z_][\w]*)\s", text) if text[:1].strip() else None)
    if lab:
        pend.append(lab.group(1).upper())
    if m and m.group(2):
        idx = len(A)
        for l in pend:
            labels.setdefault(l, idx)
        pend = []
        body = text[lab.end():] if lab else text
        A.append((int(m.group(1), 16), body.strip(), raw.rstrip("\n")))


def table(name, n=256):
    """The DC.L rows after the assembled label `name`."""
    out = []
    i = labels[name]
    while len(out) < n:
        t = A[i][1]
        assert t.upper().startswith("DC.L"), (name, t)
        out += [s.strip().upper() for s in t[4:].split(",")]
        i += 1
    return out[:n]


def ev(expr):
    e = expr.replace("$", "0x")
    return eval(e, {})


CNT = re.compile(r"^(SUBQ?|ADDQ?)\.W\s+#(.+),\(A3\)$", re.I)
BR = re.compile(r"^(B(?:RA|EQ|NE|CS|CC|MI|PL|HI|LS|GT|GE|LT|LE|VS|VC)|JMP|DB\w+)(?:\.[SWLB])?\s+(?:D\d,)?([A-Za-z_][\w.]*)$", re.I)


def walk(start):
    """Paths from a handler: lists of (site index, delta)."""
    paths, seen = [], set()
    stack = [(start, ())]
    total = 0
    while stack and total < 4000:
        i, acc = stack.pop()
        steps = 0
        while True:
            steps += 1
            total += 1
            if steps > 400 or len(acc) > 5 or (i, acc) in seen:
                if len(acc) > 5:
                    paths.append(acc + (("end", "loop"),))
                break
            seen.add((i, acc))
            t = A[i][1]
            T = t.upper()
            m = CNT.match(t)
            if m:
                d = ev(m.group(2))
                acc = acc + ((i, d if m.group(1).upper().startswith("SUB") else -d),)
            if T.startswith("JMP\t([A3,D2.W*8])") or T.startswith("JMP ([A3,D2.W*8])") or "MIRAINTER" in T and T.startswith("JMP"):
                paths.append(acc)
                break
            if T.startswith(("RTS", "RTE")) or (T.startswith("JMP") and "([" in T):
                paths.append(acc + (("end", T[:40]),))
                break
            b = BR.match(t)
            if b:
                tgt = b.group(2).upper()
                op = b.group(1).upper()
                if tgt in labels:
                    if op in ("BRA", "JMP"):
                        i = labels[tgt]
                        continue
                    stack.append((labels[tgt], acc))
            i += 1
    return paths


# the assembled INSTR is the second copy (Key_ON): labels[] holds the first
# assembled label, which is the right one
tabs = {"": table("INSTR"), "CB": table("INSCB"), "DD": table("INSDD"), "FD": table("INSFD"),
        "ED": table("INSED"), "DDCB": table("INSCBIX"), "FDCB": table("INSCBIY")}
site_req = defaultdict(set)
site_ops = defaultdict(set)
unmatched = []
for pre, tab in tabs.items():
    for op in range(256):
        ix = "IX" if pre.startswith("DD") else "IY" if pre.startswith("FD") else None
        if pre in ("", "DD", "FD"):
            nm = name_main(op, ix)
            if pre and nm == name_main(op):
                nm = None                       # DD/FD on a plain opcode
        elif pre == "ED":
            nm = name_ed(op)
        else:
            nm = name_cb(op, ix)
        if not nm or nm not in rows:
            continue
        lab = tab[op]
        if lab not in labels:
            unmatched.append((pre, op, nm, "no label " + lab))
            continue
        npre = 1 if pre in ("DDCB", "FDCB") else len(pre) // 2
        for path in walk(labels[lab]):
            if any(p[0] == "end" for p in path):
                unmatched.append((pre, op, nm, "odd end %s" % str(path[-1])))
                continue
            z = sum(d for _, d in path) + npre
            hit = [r for r in rows[nm] if r[0] == z]
            if not hit and pre == "ED" and op in (0x63, 0x6B) and rows[nm]:
                hit = [(z, rows[nm][0][1] + 1, rows[nm][0][2])]   # long form: one more fetch
            if not hit:
                unmatched.append((pre, op, nm, "z80 %d not in %s" % (z, [r[0] for r in rows[nm]])))
                continue
            otra = [s for s, _ in path if "RESTA CYCLES * R8" in A[s][2].upper()]
            if not otra:
                unmatched.append((pre, op, nm, "no Otra site"))
                continue
            last = otra[-1]
            others = [s for s, _ in path if s != last]
            site_req[last].add(hit[0][1])
            site_ops[last].add("%s%02X %s%s" % (pre, op, nm, " (%s)" % hit[0][2].split("(")[-1] if "taken" in hit[0][2] else ""))
            for s in others:
                site_ops[s].add("(other) %s%02X %s" % (pre, op, nm))

conf = {s: v for s, v in site_req.items() if len(v) > 1}
print("sites with a cost:", len(site_req), " conflicts:", len(conf), " unmatched paths:", len(unmatched))
for s, v in sorted(conf.items()):
    print("CONFLICT %06X %s: %s" % (A[s][0], sorted(v), sorted(site_ops[s])[:8]))
if conf:
    sys.exit("conflicts: no output")

# Otra sites in listing order, their Z80 cost from the immediate
order = [i for i, (_, _, raw) in enumerate(A) if "Resta Cycles * R8O" in raw]
zc = {}
for i in order:
    m = re.search(r"#(.+?),\(A3\)", A[i][1])
    zc[i] = ev(m.group(1))
by_z = defaultdict(list)
for i in order:
    if i in site_req:
        by_z[zc[i]].append(min(site_req[i]))
med = {z: sorted(v)[len(v) // 2] for z, v in by_z.items()}


def fallback(z):
    if z in med:
        return med[z]
    near = min(med, key=lambda k: abs(k - z))
    return max(1, round(med[near] * z / near))


vals, nfb = [], 0
for i in order:
    if i in site_req:
        vals.append(min(site_req[i]))
    else:
        vals.append(fallback(zc[i]))
        nfb += 1
print("Otra sites:", len(order), " from the table:", len(order) - nfb, " fallback:", nfb)
with open(outp, "w", newline="\n") as f:
    f.write("; R800 costs of the Otra sites, in site order (R800 cycles: openMSX's\n"
            "; measured cost + its 'after', Docs/agent_notes/r800time.tsv). Generated by\n"
            "; tools/r8map.py from a -DTURBOR=1 -DR8GEN=1 listing: do not edit.\n"
            "; %d sites, %d from the table, %d by Z80 cost (median).\n" % (len(order), len(order) - nfb, nfb))
    f.write("R8OGEN=%d\n" % len(order))
    f.write("R8ORTab:\n")
    for k in range(0, len(vals), 16):
        f.write("\tDC.W\t" + ",".join(str(v) for v in vals[k:k + 16]) + "\n")
if mapout:
    json.dump({"sites": {"%06X" % A[s][0]: sorted(v) for s, v in site_req.items()},
               "ops": {"%06X" % A[s][0]: sorted(o) for s, o in site_ops.items()},
               "unmatched": unmatched}, open(mapout, "w"), indent=1)
