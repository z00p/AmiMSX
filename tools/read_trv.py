"""Decode the sprite-table event ring at the end of AmiMSX:trace.bin.
Usage: python tools/read_trv.py run/trace.bin [last_frames]"""
import sys, struct
d = open(sys.argv[1], "rb").read()
r = d[-(8200 + 4 + 0xC00):-(4 + 0xC00)]
regs = d[-0xC00:]          # emulator state REGS-$400..REGS+$800 at the freeze
ptr = struct.unpack(">I", r[:4])[0]
buf = r[8:]
ents = [struct.unpack(">HHBBH", buf[i:i + 8]) for i in range(0, len(buf), 8)]
# The ring pointer is an absolute Amiga address: find the oldest entry by frame number.
k = min(range(len(ents)), key=lambda i: (ents[i][0] == 0 and ents[i][1] == 0, ents[i][0]))
seq = ents[k:] + ents[:k]
seq = [e for e in seq if e != (0, 0, 0, 0, 0)]
names = {5: "R#5", 6: "R#6", 0xFF: "FRAME", 0xF8: "snapT", 0xF9: "snapM", 0xFE: "IMPSPR"}
lastf = int(sys.argv[2]) if len(sys.argv) > 2 else 60
fmax = max(e[0] for e in seq)
for f, line, tag, val, split in seq:
    if f < fmax - lastf:
        continue
    print(f"f{f:5d} line {line:4d}  {names.get(tag, hex(tag)):6s} {val:02X}  split={split}")

def reg(off, n=1):
    return regs[0x400 + off:0x400 + off + n]
if len(sys.argv) > 3:
    for a in sys.argv[3:]:
        name, off = a.split("=")
        print(name, reg(int(off, 0), 2).hex())
