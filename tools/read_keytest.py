"""Read the keyboard mapping test's log (see tools/make_keytest.py) and compare it with
the expected Amiga-to-MSX mapping.
Usage: python tools/read_keytest.py <trace.bin | vram.bin> <keytest.json>
Also compares the expected mapping (from the source table) with tests/keymap_golden.json,
so an edit to the table shows up even when AmiMSX follows it faithfully."""
import json, os, struct, sys

d = open(sys.argv[1], "rb").read()
vram = d[80 + 16384 + 16384:] if d[:4] == b"ATRC" else d
meta = json.load(open(sys.argv[2]))
ev, i, last = [], 0, -1
while i + 4 <= len(vram):
    f, row, val = vram[i] | vram[i + 1] << 8, vram[i + 2], vram[i + 3]
    if row > 10 or f < last or f > 60000:
        break
    ev.append((f, row, val)); last = f; i += 4
# rebuild the matrix after each event: list of (frame, row, bit, down)
state, changes = [0xFF] * 11, []
for f, row, val in ev:
    diff = state[row] ^ val
    for b in range(8):
        if diff >> b & 1:
            changes.append((f, row, b, not (val >> b & 1)))
    state[row] = val
if not changes:
    sys.exit("no key events in the log")
keys = meta["keys"]
# align the script with the cartridge's frame count: the offset where most key-downs
# land on their expected key
def score(off):
    n = 0
    for k in keys:
        if 0 <= k["row"] < 11:
            f = k["frame"] - off
            n += any(c[3] and (c[1], c[2]) == (k["row"], k["bit"]) and f - 2 <= c[0] <= f + 2 for c in changes)
    return n
gap, ok, bad = meta["gap"], 0, []
f0 = next(c[0] for c in changes if c[3])
off = max(range(keys[0]["frame"] - f0 - 40 * gap, keys[0]["frame"] - f0 + 40 * gap), key=score)
used = set()
for k in keys:
    lo, hi = k["frame"] - off - 2, k["frame"] - off + gap - 3
    win = [c for c in changes if lo <= c[0] <= hi]
    used.update(win)
    got = sorted({(r, b) for f, r, b, dn in win if dn})
    if k["row"] < 0:                       # Caps Lock: a short pulse of CAPS (row 6 bit 3)
        exp = [(6, 3)]
    elif k["row"] > 10:
        exp = []
    else:
        exp = [(k["row"], k["bit"])]
    released = all(any((r, b) == (c[1], c[2]) and not c[3] for c in win) for r, b in got)
    if got == exp and released:
        ok += 1
    else:
        bad.append((k["code"], k["key"], exp, got, released))
stray = [c for c in changes if c not in used]
print(f"{len(ev)} log entries, frame offset {off}; {ok} of {len(keys)} keys as expected")
for code, name, exp, got, rel in bad:
    print(f"  {code:02X} expected {name:14} {exp}  got {got}{'' if rel else '  (not released)'}")
if stray:
    print("changes outside any key's window:", stray[:20])
print("matrix at the end:", " ".join(f"{v:02X}" for v in state), "(all FF = nothing held)")
gold = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "tests", "keymap_golden.json")
if os.path.exists(gold):
    g = {x["code"]: (x["row"], x["bit"]) for x in json.load(open(gold))}
    d = [(k["code"], g.get(k["code"]), (k["row"], k["bit"])) for k in keys if g.get(k["code"]) != (k["row"], k["bit"])]
    print("table vs tests/keymap_golden.json:", "same" if not d else d)
