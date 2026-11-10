"""Inventory for moving the Z80 cycle counter from the word at (A3) into D2's
upper half (Docs/agent_notes/c030_speed.md, "The Z80 dispatch").

Lists, with the enclosing label or macro and the line number:
  d2long   - instructions that write D2's upper word (long-sized or implicitly
             long destinations: MOVEQ, SWAP, EXT.L, MUL/DIV, EXG, MOVEM, shifts .L)
  counter  - every use of the counter word itself: (A3) with no displacement,
             0(A3), and (A3) as a bare operand of a word/byte instruction
Usage: python tools/d2_audit.py [AmiMSX_Main_v3.1.asm ...] [--summary] [--all]
(--all: the whole file, not just the core regions)
"""
import re, sys

files = [a for a in sys.argv[1:] if not a.startswith("--")] or ["AmiMSX_Main_v3.1.asm"]
summary = "--summary" in sys.argv
# The Z80 core: the handlers, port and mapper routines (Z80A up to the screen
# conversion) and the line-event code (MiraInter up to Emula1Frame).
REGIONS = [("Z80A", "PasaPun8Bpl"), ("MiraInter", "Emula1Frame")]
whole = "--all" in sys.argv

LBL = re.compile(r"^([A-Za-z_.@][\w.@]*):?\s*(MACRO)?", re.I)
INS = re.compile(r"^(?:[A-Za-z_.@\\][\w.@\\]*:?)?\s+([A-Za-z]+)(?:\.([BWLS]))?\s+([^;]*)")
D2DST = re.compile(r",\s*D2\s*$", re.I)
CNT = re.compile(r"(?:(?<=[\s,#])0|(?<![\w)\]+\-*/]))\(A3\)", re.I)   # (A3), 0(A3); not X+0(A3)

IMPLICIT_LONG = {"MOVEQ", "SWAP", "EXG", "MULU", "MULS", "DIVU", "DIVS", "DIVUL", "DIVSL",
                 "EXTB", "MOVEM", "BFEXTU", "BFEXTS", "BFFFO", "LEA"}


def cls(op, size, args):
    op = op.upper(); size = (size or "").upper()
    a = args.strip()
    out = []
    if op in ("SWAP",) and re.fullmatch(r"D2", a, re.I):
        out.append("d2long")
    elif op == "EXT" and size == "L" and re.fullmatch(r"D2", a, re.I):
        out.append("d2long")
    elif op == "EXTB" and re.fullmatch(r"D2", a, re.I):
        out.append("d2long")
    elif op == "EXG" and re.search(r"\bD2\b", a, re.I):
        out.append("d2long")
    elif op == "MOVEM" and re.search(r"D2|D\d-D\d", a, re.I):
        if re.search(r"\(.*\)\s*,", a):           # memory to registers
            out.append("d2long?")
    elif D2DST.search(a) and (size == "L" or op in IMPLICIT_LONG):
        out.append("d2long")
    elif op in ("CLR", "NOT", "NEG", "NEGX") and size == "L" and re.fullmatch(r"D2", a, re.I):
        out.append("d2long")
    if CNT.search(a) and not a.upper().startswith("([A3"):
        out.append("counter")
    return out


for fn in files:
    raw = open(fn, "rb").read().decode("latin1").replace("\r", "").split("\n")
    ctx = "?"
    tally = {}
    starts = {}
    for n, line in enumerate(raw, 1):
        m = re.match(r"^([A-Za-z_][\w]*):", line)
        if m: starts.setdefault(m.group(1), n)
    spans = [(starts[a], starts[b]) for a, b in REGIONS]
    for n, line in enumerate(raw, 1):
        s = line.split(";", 1)[0].rstrip()
        if not s.strip():
            continue
        if not whole and not any(a <= n < b for a, b in spans):
            continue
        m = LBL.match(s)
        if m and not s[0].isspace():
            ctx = m.group(1) + (" (macro)" if m.group(2) else "")
        mi = INS.match(s)
        if not mi:
            continue
        for k in cls(mi.group(1), mi.group(2), mi.group(3)):
            tally.setdefault(k, []).append((n, ctx, s.strip()))
    for k in sorted(tally):
        print(f"== {fn}: {k}: {len(tally[k])} lines")
        if summary:
            by = {}
            for n, c, s in tally[k]:
                by.setdefault(c, 0); by[c] += 1
            for c, v in sorted(by.items(), key=lambda x: -x[1])[:60]:
                print(f"   {v:4d}  {c}")
        else:
            for n, c, s in tally[k]:
                print(f"   {n:6d}  {c:24s} {s}")
