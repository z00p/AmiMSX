"""Read the mapping test's VRAM (see tools/make_maptest.py): the log at 1C000h and,
with a second dump, the differences.
Usage: python tools/read_maptest.py <trace.bin | vram.bin> [<reference vram.bin>]
Dumps are physical VRAM (128 KB; a trace.bin carries it after the 80-byte header, the
16 KB ring and two 8 KB page dumps)."""
import sys

LOGVRAM = 0x1C000
SECTIONS = {1: "SCREEN 5 read-back (6000h, 16000h)", 2: "SCREEN 5 POINT x2, LMCM",
            3: "SCREEN 8 read of SCREEN 5 bytes (C000h, 1024)", 4: "SCREEN 8 write/read across 10000h",
            5: "SCREEN 8 POINT x3, LMCM", 6: "SCREEN 7 read of SCREEN 5 bytes (C000h, 1024)",
            7: "SCREEN 7 POINT x3, LMCM", 8: "SCREEN 5 read of SCREEN 8/7 writes (6800h, 16800h, 7000h, 17000h)",
            9: "SCREEN 5 POINT x2"}


def load(p):
    d = open(p, "rb").read()
    return d[80 + 16384 + 16384:][:0x20000] if d[:4] == b"ATRC" else d[:0x20000]


def log(v):
    if v[LOGVRAM:LOGVRAM + 4] != b"MAPT":
        return None
    n = v[LOGVRAM + 4] | v[LOGVRAM + 5] << 8
    b, out, cur, i = v[LOGVRAM + 6:LOGVRAM + 6 + n], {}, None, 0
    while i < len(b):
        if b[i] == 0xFE and i + 1 < len(b) and b[i + 1] in SECTIONS and (cur is None or b[i + 1] == cur + 1):
            cur = b[i + 1]; out[cur] = bytearray(); i += 2; continue
        out.setdefault(cur, bytearray()).append(b[i]); i += 1
    return out


def main():
    v = load(sys.argv[1])
    lg = log(v)
    if lg is None:
        sys.exit("no MAPT log at 1C000h (the cartridge did not reach its end)")
    ref = load(sys.argv[2]) if len(sys.argv) > 2 else None
    rl = log(ref) if ref else None
    bad = 0
    for s, b in lg.items():
        r = rl.get(s) if rl else None
        same = "" if r is None else ("  SAME" if r == b else "  DIFFERENT")
        print(f"[{s}] {SECTIONS.get(s, '?')}: {len(b)} bytes{same}")
        if r is not None and r != b:
            bad += 1
            diffs = [i for i in range(max(len(b), len(r))) if i >= len(b) or i >= len(r) or b[i] != r[i]]
            print(f"     {len(diffs)} differ, first at {diffs[0]}:")
            for i in diffs[:12]:
                print(f"       +{i:4d}: got {b[i] if i < len(b) else -1:02X} want {r[i] if i < len(r) else -1:02X}")
        elif r is None and len(b) <= 40:
            print("     " + " ".join(f"{x:02X}" for x in b))
    if ref:
        runs, i = [], 0
        while i < 0x20000:
            if v[i] != ref[i]:
                j = i
                while j < 0x20000 and (v[j] != ref[j] or (j + 16 < 0x20000 and v[j:j + 16] != ref[j:j + 16])):
                    j += 1
                runs.append((i, j)); i = j
            else:
                i += 1
        n = sum(1 for i in range(0x20000) if v[i] != ref[i])
        print(f"VRAM: {n} bytes differ in {len(runs)} runs")
        for s, e in runs[:40]:
            print(f"  {s:05X}-{e - 1:05X} ({e - s} B; SCREEN 5 page {s >> 15} row {(s >> 7) & 255})")
        bad += n > 0
    print("RESULT:", "PASS" if ref and not bad else ("FAIL" if ref else "(no reference)"))


main()
