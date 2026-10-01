"""Decode AmiMSX:trace.bin from the debug trap build (vasm -DTRACE=1).
Usage: python tools/read_trace.py run/trace.bin [last_n]"""
import sys, struct
d = open(sys.argv[1], "rb").read()
n_last = int(sys.argv[2]) if len(sys.argv) > 2 else 120
assert d[:4] == b"ATRC"
ring_off, count = struct.unpack(">II", d[4:12])
a8 = d[15]
pagread = struct.unpack(">8I", d[16:48]); n_print2, n_full2 = struct.unpack(">II", d[48:56])
ring = d[80:80 + 16384]; page3 = d[80 + 16384:]
ents = [ring[i:i + 4] for i in range(0, len(ring), 4)]
k = ring_off // 4
order = ents[k:] + ents[:k]
print(f"instructions traced: {count}, port A8 at freeze: {a8:02X} "
      f"(pages 0..3 -> slots {a8 & 3},{a8 >> 2 & 3},{a8 >> 4 & 3},{a8 >> 6 & 3})")
print("PagRead :", " ".join(f"{p:08X}" for p in pagread))
print(f"SCREEN 2 redraws (PRINT2): {n_print2}, of which full (ACTUTODO2): {n_full2}")
m6, imp6, off6 = struct.unpack(">III", d[56:68]); pref16 = struct.unpack(">H", d[70:72])[0]
print(f"SPRMODE6 calls {m6}, IMPSPR2 {imp6}, sprites-off {off6}; Sprites pref (DirPrefs+$16) {pref16}, COSPR2 {d[72]}")
print(f"--- last {n_last} instructions (PC, opcode, A8) ---")
prev = None
for e in order[-n_last:]:
    pc = (struct.unpack(">H", e[:2])[0] - 1) & 0xFFFF
    mark = "  <-- A8 changed" if prev is not None and e[3] != prev else ""
    print(f"{pc:04X}  {e[2]:02X}  A8={e[3]:02X}{mark}")
    prev = e[3]
open(sys.argv[1] + ".page3", "wb").write(page3)
