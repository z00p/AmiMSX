import sys, struct, os, glob
sys.path.insert(0, 'tools'); import pal_probe as pp
D = 'build/perf/classic'
def speed(f):
    b = pp.blocks(open(f, 'rb').read())
    n = struct.unpack('>I', b['dispn'])[0]; log = b['displog'][:min(n, 4096)]
    seg = log[750:n]                      # from 15 s (title screens done)
    return 100.0 * len(seg) / max(1, sum(seg)) if seg else None
roms = sorted(set(os.path.basename(f).rsplit('_', 2)[0] for f in glob.glob(D + '/*.bin')))
exes = sys.argv[1:] or ['base', 'head']
print(f"{'title':22s} " + " ".join(f"{c}:{e:>6s}" for c in ('a1200', '030') for e in exes))
for r in roms:
    row = []
    for c in ('a1200', '030'):
        for e in exes:
            f = f'{D}/{r}_{c}_{e}.bin'
            v = speed(f) if os.path.exists(f) else None
            row.append(f"{v:12.1f}" if v is not None else f"{'-':>12s}")
    print(f"{r:22s} " + " ".join(row))
