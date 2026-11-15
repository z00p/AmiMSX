"""Per-instruction costs from the openMSX log of tools/omsx_r800time.tcl.
Each log line "pc cycles" holds the cost of the instruction executed before pc,
and the first line is at the second entry (openMSX checks the condition
from the second instruction on): line i = entry i's cost, at entry i+1.
A block instruction (one repeat) logs its address twice: the repeat's cost
is added to the line that leaves it. Z80 mode is the
check of the harness (every test must match grauw's Z80+M1 column). R800: the
DRAM and ROM mode runs are taken together, the lower of the two, as the R800's
DRAM refresh (openMSX: every 210 cycles, about 27 lost) lands on different
instructions in each run. 'after' is what the test adds to the next
instruction (the DI of the next restore block, over its lowest cost here, 2
cycles): the page break back to the code's page after a data access elsewhere.
The cost of an instruction in running code is about r800 + after.
Usage: python tools/read_r800time.py tests.json omsx.log out.tsv"""
import json, sys

meta = json.load(open(sys.argv[1]))
ent = meta["entries"]
runs, cur = {}, None
for line in open(sys.argv[2]):
    if line.startswith("=="):
        cur = line.split()[1]
        runs[cur], carry = [], 0
        continue
    pc, c = int(line.split()[0], 16), int(line.split()[1])
    if runs[cur] and runs[cur][-1][0] == pc:     # a block instruction's repeat:
        carry += c                                 # its cost goes with the
    else:                                          # line that leaves it
        runs[cur].append((pc, c + carry))
        carry = 0

costs = {}
for mode, rows in runs.items():
    pcs = [p for p, _ in rows]
    assert pcs[:len(ent) - 1] == [e["addr"] for e in ent[1:]], mode
    costs[mode] = [rows[i][1] for i in range(len(ent) - 1)] + [None]

def nextdi(i):
    if i + 1 >= len(ent) - 1 or ent[i + 1]["ins"] != "DI":
        return None
    return min(costs["R800DRAM"][i + 1], costs["R800ROM"][i + 1])


dibase = min(n for n in (nextdi(i) for i in range(len(ent))) if n is not None)
bad = 0
out = ["ins\ttest\tz80m1\tz80\tr800\tafter"]
for i, e in enumerate(ent[:-1]):
    if not e["test"]:
        continue
    z = costs["Z80"][i]
    if z != e["expect"]:
        bad += 1
        print("Z80 mismatch:", e["test"], z, e["expect"])
    r = min(costs["R800DRAM"][i], costs["R800ROM"][i])
    nxt = nextdi(i)
    after = "" if nxt is None else nxt - dibase
    out.append(f"{e['ins']}\t{e['test']}\t{e['expect']}\t{z}\t{r}\t{after}")
open(sys.argv[3], "w").write("\n".join(out) + "\n")
print(f"{len(out) - 1} tests, Z80 mismatches {bad}, DI alone {dibase} R800 cycles")
