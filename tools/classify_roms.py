"""Classify MSX ROM files by layout, to see which ones AmiMSX v3.1 can map.
Usage: python tools/classify_roms.py <folder> [...]"""
import sys, os, collections

MAPPER_ADDRS = {  # typical bank-select write addresses per mapper type
    "Konami":     {0x6000, 0x8000, 0xA000},
    "KonamiSCC":  {0x5000, 0x7000, 0x9000, 0xB000},
    "ASCII8":     {0x6000, 0x6800, 0x7000, 0x7800},
    "ASCII16":    {0x6000, 0x7000, 0x77FF},
}

def ld_nn_a_targets(d):
    c = collections.Counter()
    for i in range(len(d) - 2):
        if d[i] == 0x32:
            c[d[i + 1] | d[i + 2] << 8] += 1
    return c

def classify(d):
    size = len(d)
    ab = [off for off in range(0, min(size, 0x10000), 0x4000) if d[off:off + 2] == b"AB"]
    tgt = ld_nn_a_targets(d)
    hits = {m: sum(tgt[a] for a in s) for m, s in MAPPER_ADDRS.items()}
    best = max(hits, key=hits.get)
    if size > 0x10000 or (size > 0x8000 and hits[best] >= 3 and 0 in ab):
        kind = f"MegaROM ({best}? {hits[best]} writes)"
    elif size <= 0x4000:
        kind = "16K plain"
    elif size <= 0x8000:
        kind = "32K plain" if 0 in ab else "32K, header not at 0"
    elif ab and ab[0] == 0x4000:
        kind = f"{size // 1024}K LINEAR from $0000 (header at file $4000)"
    elif ab and ab[0] == 0:
        kind = f"{size // 1024}K from $4000 (header at file 0)"
    else:
        kind = f"{size // 1024}K no AB header"
    return kind, ab

for root in sys.argv[1:]:
    for dp, _, fs in os.walk(root):
        for f in sorted(fs):
            if f.lower().endswith((".rom", ".mx1", ".mx2")):
                p = os.path.join(dp, f)
                d = open(p, "rb").read()
                kind, ab = classify(d)
                print(f"{len(d):>8}  {kind:<48} {os.path.relpath(p, root)}")
