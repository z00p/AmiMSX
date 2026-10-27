"""Read the SRAM test's log (tools/make_sramtest.py) from VRAM: "SRMT", length, bytes,
sections marked FE n. With a reference dump, compare section by section.
Usage: python tools/read_sramtest.py <trace.bin | vram.bin> [<reference vram.bin>]"""
import sys

NAMES = {1: "SRAM as found (16 bytes)", 2: "after +1: start, mirror(s), end of page",
         3: "page 1 / regions 2-3 (read only), then a write there", 4: "bank values (ROM markers / SRAM block)",
         5: "SRAM after a write with ROM selected"}


def load(p):
    d = open(p, "rb").read()
    return d[80 + 16384 + 16384:][:0x20000] if d[:4] == b"ATRC" else d[:0x20000]


def log(v):
    if v[:4] != b"SRMT":
        return None
    n = v[4] | v[5] << 8
    b, out, cur, i = v[6:6 + n], {}, None, 0
    while i < len(b):
        if b[i] == 0xFE and i + 1 < len(b) and b[i + 1] == (cur or 0) + 1:
            cur = b[i + 1]; out[cur] = bytearray(); i += 2; continue
        out.setdefault(cur, bytearray()).append(b[i]); i += 1
    return out


def main():
    a = log(load(sys.argv[1]))
    if a is None:
        print("no SRMT log"); sys.exit(1)
    r = log(load(sys.argv[2])) if len(sys.argv) > 2 else None
    bad = 0
    for k in sorted(a):
        same = r is not None and r.get(k) == a[k]
        bad += r is not None and not same
        print(f"[{k}] {NAMES.get(k, '?')}: {a[k].hex(' ')}" + ("" if r is None else ("  SAME" if same else f"\n    reference: {r.get(k, b'').hex(' ')}")))
    if r is not None:
        print("RESULT:", "PASS" if not bad and set(a) == set(r) else "FAIL")
        sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
