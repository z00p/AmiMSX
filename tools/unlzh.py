"""Minimal LZH (LHA) extractor: level 0/1/2 headers, -lh0- (stored) and
-lh5- (8 KB dictionary, static Huffman) methods.
Usage: python tools/unlzh.py archive.lzh outdir"""
import os, struct, sys


class Bits:
    def __init__(self, data):
        self.d, self.p, self.buf, self.n = data, 0, 0, 0

    def get(self, k):
        while self.n < k:
            b = self.d[self.p] if self.p < len(self.d) else 0
            self.p += 1
            self.buf = (self.buf << 8) | b
            self.n += 8
        self.n -= k
        v = (self.buf >> self.n) & ((1 << k) - 1)
        self.buf &= (1 << self.n) - 1
        return v

    def peek(self, k):
        while self.n < k:
            b = self.d[self.p] if self.p < len(self.d) else 0
            self.p += 1
            self.buf = (self.buf << 8) | b
            self.n += 8
        return (self.buf >> (self.n - k)) & ((1 << k) - 1)


def make_table(lengths):
    """Canonical Huffman decode table: dict (length, code) -> symbol."""
    tbl = {}
    code = 0
    maxlen = max(lengths) if lengths else 0
    for ln in range(1, maxlen + 1):
        for sym, l in enumerate(lengths):
            if l == ln:
                tbl[(ln, code)] = sym
                code += 1
        code <<= 1
    return tbl, maxlen


def decode(bits, table):
    tbl, maxlen = table
    if maxlen == 0:
        return None
    code = 0
    for ln in range(1, maxlen + 1):
        code = (code << 1) | bits.get(1)
        if (ln, code) in tbl:
            return tbl[(ln, code)]
    raise ValueError("bad Huffman code")


def read_pt_len(bits, nn, nbit, special):
    n = bits.get(nbit)
    if n == 0:
        c = bits.get(nbit)
        return [0] * nn, c
    lens = []
    while len(lens) < n:
        c = bits.get(3)
        if c == 7:
            while bits.get(1):
                c += 1
        lens.append(c)
        if len(lens) == special:
            k = bits.get(2)
            lens.extend([0] * k)
    lens += [0] * (nn - len(lens))
    return lens[:nn], None


def read_c_len(bits, pt):
    NC = 510
    n = bits.get(9)
    if n == 0:
        c = bits.get(9)
        return [0] * NC, c
    lens = []
    while len(lens) < n:
        c = pt_decode(bits, pt)
        if c <= 2:
            if c == 0:
                k = 1
            elif c == 1:
                k = bits.get(4) + 3
            else:
                k = bits.get(9) + 20
            lens.extend([0] * k)
        else:
            lens.append(c - 2)
    lens += [0] * (NC - len(lens))
    return lens[:NC], None


def pt_decode(bits, pt):
    lens, const = pt
    if const is not None:
        return const
    return decode(bits, make_table_cached(tuple(lens)))


_cache = {}


def make_table_cached(lens):
    if lens not in _cache:
        _cache[lens] = make_table(list(lens))
    return _cache[lens]


def lh5(data, osize):
    bits = Bits(data)
    out = bytearray()
    blocksize = 0
    NP, PBIT = 14, 4
    while len(out) < osize:
        if blocksize == 0:
            blocksize = bits.get(16)
            pt = read_pt_len(bits, 19, 5, 3)
            c_lens, c_const = read_c_len(bits, pt)
            p_lens, p_const = read_pt_len(bits, NP, PBIT, -1)
            c_tbl = make_table(c_lens) if c_const is None else None
            p_tbl = make_table(p_lens) if p_const is None else None
        blocksize -= 1
        c = c_const if c_const is not None else decode(bits, c_tbl)
        if c < 256:
            out.append(c)
        else:
            length = c - 256 + 3
            p = p_const if p_const is not None else decode(bits, p_tbl)
            if p > 1:
                p = (1 << (p - 1)) + bits.get(p - 1)
            src = len(out) - p - 1
            for i in range(length):
                out.append(out[src + i])
    return bytes(out[:osize])


def entries(d):
    p = 0
    while p < len(d) and d[p]:
        lvl = d[p + 20]
        method = d[p + 2:p + 7].decode("latin1")
        if lvl in (0, 1):
            hs = d[p]
            csize, osize = struct.unpack("<II", d[p + 7:p + 15])
            nl = d[p + 21]
            name = d[p + 22:p + 22 + nl].decode("latin1")
            q = p + 2 + hs
            ext_total = 0
            if lvl == 1:
                nxt = struct.unpack("<H", d[q - 2:q])[0]
                while nxt:
                    ext_total += nxt
                    q += nxt
                    nxt = struct.unpack("<H", d[q - 2:q])[0]
                csize -= ext_total
            start = q
        else:  # level 2
            hs = struct.unpack("<H", d[p:p + 2])[0]
            csize, osize = struct.unpack("<II", d[p + 7:p + 15])
            name = "?"
            q = p + 26
            nxt = struct.unpack("<H", d[q - 2:q])[0]
            while nxt:
                if d[q] == 1:
                    name = d[q + 1:q + nxt - 2].decode("latin1")
                q += nxt
                nxt = struct.unpack("<H", d[q - 2:q])[0]
            start = p + hs
        yield name, method, d[start:start + csize], osize
        p = start + csize


if __name__ == "__main__":
    arc, outdir = sys.argv[1], sys.argv[2]
    os.makedirs(outdir, exist_ok=True)
    for name, method, data, osize in entries(open(arc, "rb").read()):
        if method == "-lh0-":
            out = data[:osize]
        elif method == "-lh5-":
            out = lh5(data, osize)
        else:
            print("skip", name, method)
            continue
        open(os.path.join(outdir, name), "wb").write(out)
        print(f"{name:16s} {method} {len(out):7d}")
