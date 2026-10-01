"""Apply an IPS patch (records, RLE records, optional truncation after EOF).
Usage: python tools/ips.py base.rom patch.ips out.rom"""
import sys

base, patch, out = sys.argv[1:4]
d = bytearray(open(base, "rb").read())
p = open(patch, "rb").read()
assert p[:5] == b"PATCH", "not an IPS file"
i = 5
records = 0
while True:
    if p[i:i + 3] == b"EOF" and (i + 3 == len(p) or i + 6 == len(p)):
        i += 3
        break
    off = int.from_bytes(p[i:i + 3], "big")
    size = int.from_bytes(p[i + 3:i + 5], "big")
    i += 5
    if size == 0:                       # RLE record
        n = int.from_bytes(p[i:i + 2], "big")
        data = p[i + 2:i + 3] * n
        i += 3
    else:
        data = p[i:i + size]
        i += size
    if off + len(data) > len(d):
        d.extend(b"\xff" * (off + len(data) - len(d)))
    d[off:off + len(data)] = data
    records += 1
if i + 3 == len(p):                     # truncation extension
    d = d[:int.from_bytes(p[i:i + 3], "big")]
open(out, "wb").write(d)
print(f"{records} records, {len(d)} bytes -> {out}")
