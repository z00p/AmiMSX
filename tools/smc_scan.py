"""Find run-time writes into code (self-modifying code) from a vasm -L listing.
Marks every address in section 00 that holds an instruction (not DC/DS/DCB),
then reports instructions whose destination operand is an absolute
label[+offset] resolving into that code. Each needs a cache flush after it
on 68040/060 and Emu68 unless it runs before the start-up CacheClearU.
Usage: python tools/smc_scan.py build/main.lst"""
import re, sys
L = open(sys.argv[1], encoding="latin-1").read().splitlines()
syms = {}
i = L.index("Symbols by name:")
for l in L[i + 1:]:
    if l.startswith("Symbols by value"): break
    m = re.match(r"(\S+)\s+(?:([0-9A-F]{2}):)?([0-9A-F]{8})", l)
    if m and m.group(2) == "00": syms[m.group(1).lower()] = int(m.group(3), 16)
code = set()
rows = []
for l in L[:i]:
    m = re.match(r"00:([0-9A-F]{8}) ([0-9A-F]+)\s*\t\s*(\d+)\+?: (.*)$", l)
    if not m: continue
    addr, hexb, line, src = int(m.group(1), 16), m.group(2), int(m.group(3)), m.group(4)
    s = src.split(";")[0].strip()
    s = re.sub(r"^[A-Za-z_][\w]*:?\s*", "", s) if not src.startswith(("\t", " ")) else s
    mn = s.split()[0].upper() if s.split() else ""
    if mn.split(".")[0] in ("DC", "DS", "DCB", "CNOP", "EVEN", "ALIGN", ""): continue
    for k in range(len(hexb) // 2): code.add(addr + k)
    rows.append((addr, line, s))
wr = re.compile(r"^(MOVE|MOVEQ|ADD|ADDQ|SUB|SUBQ|OR|AND|EOR|BSET|BCLR|BCHG|ST|SF|CLR|NOT|NEG|S[A-Z]{2}|MOVEM|BFINS|BFSET|BFCLR)(\.[BWL])?\s+(.*)$", re.I)
hits = 0
for addr, line, s in rows:
    m = wr.match(s)
    if not m: continue
    ops = m.group(3)
    dst = ops.rsplit(",", 1)[-1].strip() if "," in ops else ops.strip()
    dst = re.sub(r"\{.*\}$", "", dst)
    md = re.match(r"^\(?([A-Za-z_]\w*)(?:\s*([+-])\s*(\$?[0-9A-Fa-f]+))?\)?(\.[WL])?$", dst)
    if not md or md.group(1).lower() not in syms: continue
    off = 0
    if md.group(3):
        v = md.group(3); off = int(v[1:], 16) if v.startswith("$") else int(v)
        if md.group(2) == "-": off = -off
    t = syms[md.group(1).lower()] + off
    if t in code:
        hits += 1
        print(f"line {line:6d} @{addr:06X}: {s[:60]:60s} -> code at {t:06X}")
print(hits, "writes into code")

# Indirect: LEA <code label>,An followed (within 6 instructions) by a write through (An)/d(An).
print("--- indirect (LEA code label, then a write through that register)")
lea = re.compile(r"^LEA\s+\(?([A-Za-z_]\w*)(?:\s*([+-])\s*(\$?[0-9A-Fa-f]+))?(?:\(PC\)|\.L|\.W)?\)?(?:\(PC\))?,\s*(A[0-6])$", re.I)
n2 = 0
for k, (addr, line, s) in enumerate(rows):
    m = lea.match(s)
    if not m or m.group(1).lower() not in syms: continue
    t = syms[m.group(1).lower()]
    if t not in code: continue
    reg = m.group(4).upper()
    for addr2, line2, s2 in rows[k + 1:k + 7]:
        m2 = wr.match(s2)
        if m2:
            dst = m2.group(3).rsplit(",", 1)[-1].strip().upper()
            if re.search(r"\(%s\)\+?|-\(%s\)|\(\s*-?\$?[0-9A-F]+\s*,\s*%s" % (reg, reg, reg), dst) or re.match(r"^-?\$?[0-9A-F]*\(%s\)" % reg, dst):
                n2 += 1
                print(f"line {line:6d}: {s[:40]:40s} / line {line2}: {s2[:40]}")
                break
        if re.match(r"^(LEA|MOVE(A)?\.L)\s+.*,\s*%s$" % reg, s2, re.I): break
print(n2, "indirect candidates")
