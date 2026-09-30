"""Decode AmiMSX:trace.bin from the debug trap build (vasm -DTRACE=1).
Usage: python tools/read_trace.py run/trace.bin [last_n]"""
import sys, struct
d = open(sys.argv[1], "rb").read()
n_last = int(sys.argv[2]) if len(sys.argv) > 2 else 120
assert d[:4] == b"ATRC"
ring_off, count = struct.unpack(">II", d[4:12])
a8 = d[15]
pagread = struct.unpack(">8I", d[16:48]); pagwrite = struct.unpack(">8I", d[48:80])
ring = d[80:80 + 16384]; page3 = d[80 + 16384:]
ents = [ring[i:i + 4] for i in range(0, len(ring), 4)]
k = ring_off // 4
order = ents[k:] + ents[:k]
print(f"instructions traced: {count}, port A8 at freeze: {a8:02X} "
      f"(pages 0..3 -> slots {a8 & 3},{a8 >> 2 & 3},{a8 >> 4 & 3},{a8 >> 6 & 3})")
print("PagRead :", " ".join(f"{p:08X}" for p in pagread))
print("PagWrite:", " ".join(f"{p:08X}" for p in pagwrite))
print(f"--- last {n_last} instructions (PC, opcode, A8) ---")
prev = None
for e in order[-n_last:]:
    pc = (struct.unpack(">H", e[:2])[0] - 1) & 0xFFFF
    mark = "  <-- A8 changed" if prev is not None and e[3] != prev else ""
    print(f"{pc:04X}  {e[2]:02X}  A8={e[3]:02X}{mark}")
    prev = e[3]
open(sys.argv[1] + ".page3", "wb").write(page3)
