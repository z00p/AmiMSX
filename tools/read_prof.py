"""PC profile from a PERF build's perf.bin (VBlank + copper interrupt samples).
Usage: python tools/read_prof.py build/perf/<rom>.bin build/AmiMSX_prof.lst [last_n] [top]

The listing must come from the same build (vasm -L ... with the same -D
options). Samples are mapped to the nearest preceding code label."""
import sys, struct, bisect, re, collections

perf, lst = sys.argv[1], sys.argv[2]
last_n = int(sys.argv[3]) if len(sys.argv) > 3 else 0
top = int(sys.argv[4]) if len(sys.argv) > 4 else 40

d = open(perf, "rb").read()
assert d[:4] == b"APRF"
hdr = 24 + 16 * 128 * 4
base_addr, count, ptr = struct.unpack(">III", d[hdr:hdr + 12])
buf = d[hdr + 12:]
n_slots = len(buf) // 4
pcs = list(struct.unpack(f">{n_slots}I", buf[:n_slots * 4]))
if count >= n_slots:                       # wrapped: oldest first
    k = count % n_slots
    pcs = pcs[k:] + pcs[:k]
else:
    pcs = pcs[:count]
if last_n:
    pcs = pcs[-last_n:]

syms = []
size0 = None
text = open(lst, encoding="latin1").read()
m = re.search(r'00: "MSX2" \(0-([0-9A-F]+)\)', text)
size0 = int(m.group(1), 16)
by_name = text[text.index("Symbols by name:"):text.index("Symbols by value:")]
for line in by_name.splitlines():
    mm = re.match(r"(\S+)\s+00:([0-9A-F]{8})$", line.strip())
    if mm:
        syms.append((int(mm.group(2), 16), mm.group(1)))
syms.sort()
offs = [o for o, _ in syms]
anchor = dict((n, o) for o, n in syms)["Emula1Frame"]
base = base_addr - anchor

hist = collections.Counter()
for pc in pcs:
    off = pc - base
    if 0 <= off < size0:
        i = bisect.bisect_right(offs, off) - 1
        hist[syms[i][1] if i >= 0 else "?"] += 1
    else:
        hist["<outside AmiMSX code>"] += 1
total = sum(hist.values())
print(f"{total} samples ({count} taken), code base {base:08X}")
for name, c in hist.most_common(top):
    print(f"{100.0 * c / total:6.2f}%  {c:6d}  {name}")
