"""Z80 instruction ring from a TRACE dump (trace.bin): oldest first.
Usage: python tools/trace_ring.py trace.bin [n]   (last n entries, default 40)"""
import struct, sys


def ring(path):
    d = open(path, "rb").read()
    off, count = struct.unpack(">II", d[4:12])
    buf = d[80:80 + 16384]
    ents = [struct.unpack(">HBB", buf[i:i + 4]) for i in range(0, 16384, 4)]
    k = off // 4
    return (ents[k:] + ents[:k]), count, d[12:80]


if __name__ == "__main__":
    e, count, hdr = ring(sys.argv[1])
    n = int(sys.argv[2]) if len(sys.argv) > 2 else 40
    print("instructions", count, "A8", hex(hdr[3]))
    for pc, op, a8 in e[-n:]:
        print(f"{pc - 1:04X} {op:02X} A8={a8:02X}")
