"""Compare AmiMSX's Z80 instruction costs with grauw's Z80+M1 column, from a CYCLOG
trace (build with -DTRACE=1 -DCYCLOG=1 -DTRACEPC=<end+1>, run the cartridge of
tools/make_z80time.py; trace.bin is written when the trap fires).
Each trace entry is (address after the opcode byte, the line's cycles left); an
instruction's cost is the drop of the counter to the next instruction, +228
when a line ended in between (HPeriod).
Usage: python tools/read_z80time.py trace.bin z80time.json [--all]"""
import json, struct, sys

HP = 228
d = open(sys.argv[1], "rb").read()
assert d[:4] == b"ATRC"
off, count = struct.unpack(">II", d[4:12])
RING = 65536
ring = d[80:80 + RING]
ents = [struct.unpack(">Hh", ring[i:i + 4]) for i in range(0, RING, 4)]
k = off // 4
ents = ents[k:] + ents[:k]
meta = json.load(open(sys.argv[2]))
E = meta["entries"]
starts = {e["addr"]: i for i, e in enumerate(E)}
own = {}
for i, e in enumerate(E):
    for a in range(e["addr"], e["addr"] + e["len"]):
        own[a] = i
# walk the log: group entries by the test-list index that owns their address
# only the cartridge's own run: from the last entry at its first instruction (BIOS code
# elsewhere in the ring can sit at the same addresses in other slots)
first = E[0]["addr"]
k0 = max(j for j, (pca, _) in enumerate(ents) if (pca - 1) & 0xFFFF == first)
ents = ents[k0:]
seq = []
for pca, left in ents:
    pc = (pca - 1) & 0xFFFF
    if pc in own:
        i = own[pc]
        if seq and seq[-1][0] == i and pc != E[i]["addr"]:
            seq[-1][2].append(left)      # a prefix re-dispatch inside the same instruction
        elif seq and seq[-1][0] == i:
            seq[-1][2].append(left)      # a block repeat (same address)
        else:
            seq.append([i, pc, [left]])
    elif seq:
        seq.append([None, pc, [left]])
cost = {}
for (i, pc, lefts), nxt in zip(seq, seq[1:]):
    if i is None:
        continue
    chain = lefts + [nxt[2][0]]
    c, bad = 0, False
    for a, b in zip(chain, chain[1:]):
        x = a - b
        if x < 0:
            x += HP
        if x < 0 or x > 120:
            bad = True
        c += x
    cost.setdefault(i, []).append(None if bad else c)
diffs, ok, missing = [], 0, 0
for i, e in enumerate(E):
    if not e["test"]:
        continue
    got = cost.get(i)
    if not got:
        missing += 1
        diffs.append((e["test"], e["expect"], "not run"))
        continue
    g = got[0]
    if g == e["expect"]:
        ok += 1
    else:
        diffs.append((e["test"], e["expect"], g))
helpers = {}
for i, e in enumerate(E):
    if not e["test"] and i in cost:
        helpers.setdefault(e["ins"], set()).update(x for x in cost[i] if x is not None)
print(f"trace: {count} instructions; tests {sum(1 for e in E if e['test'])}: {ok} match, "
      f"{len(diffs) - missing} differ, {missing} not in the trace")
print(f"{'instruction':32} {'Z80+M1':>7} {'AmiMSX':>7}")
for t, e, g in sorted(diffs):
    print(f"{t:32} {e!s:>7} {g!s:>7}")
if "--all" in sys.argv:
    print("helper instructions (setup), costs seen:")
    for k2, v in sorted(helpers.items()):
        print(f"  {k2:20} {sorted(v)}")
