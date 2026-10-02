"""Check every word-size PC-relative displacement in a vasm listing (-L): flags
operands whose 16-bit displacement doesn't reach the intended label (vasm
doesn't range-check explicit .W base displacements in memory-indirect modes).
Usage: python tools/check_pcdisp.py build/x.lst"""
import re, sys

lines = open(sys.argv[1], encoding="latin-1").read().splitlines()
syms = {}
i = lines.index("Symbols by name:")
for l in lines[i + 1:]:
    if l.startswith("Symbols by value"):
        break
    m = re.match(r"(\S+)\s+(?:([0-9A-F]{2}):)?([0-9A-F]{8})", l)
    if m:
        syms[m.group(1).lower()] = (m.group(2), int(m.group(3), 16))
bad = 0
for l in lines[:i]:
    m = re.match(r"00:([0-9A-F]{8}) ([0-9A-F]+)\s+.*?\(\[?\(?([A-Za-z_][\w]*)([-+]\$?[0-9A-Fa-f]+)?\.W,PC", l)
    if not m:
        continue
    addr, hexb, lab, off = int(m.group(1), 16), m.group(2), m.group(3).lower(), m.group(4)
    if lab not in syms or syms[lab][0] != "00":
        continue
    o = 0
    if off:
        o = int(off.replace("$", "0x"), 0) if "$" in off else int(off)
    want = syms[lab][1] + o
    b = bytes.fromhex(hexb)
    ext = int.from_bytes(b[2:4], "big")
    if ext & 0x100:                     # full format: bd follows
        bd = int.from_bytes(b[4:6], "big", signed=True)
    else:                               # brief: d8
        bd = int.from_bytes(b[3:4], "big", signed=True)
    got = addr + 2 + bd
    dist = want - (addr + 2)
    if got != want:
        bad += 1
        print(f"{addr:06X} {l.split(chr(9))[-1].strip()[:70]:70s} wants {want:06X} (dist {dist:+d}) gets {got & 0xFFFFFF:06X}")
print(f"{bad} bad displacements")
