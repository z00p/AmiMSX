"""Usage: python tools/n2_tearmodel.py <log from tools/omsx_ntdet.tcl> (Nemesis 2: name table at 3800h,
the whole-table redraw ends at 2BEh).

Model the name table seen by real hardware (row r at line 70+8r of the period, as the beam
reaches it) and by AmiMSX (the whole table as it is at the period's end, the VBlank), from an
openMSX OUT (98h) log (omsx_ntdet.tcl). Prints, per model, how many pictures show a mix of
two name-table generations (a torn picture) and in which rows the mix sits."""
import sys
NTB, NTL, LPF = 0x3800, 0x300, 262
log = sys.argv[1]
writes = []          # (period, rel, offset, value)
nt0 = None
for line in open(log):
    t = line.split()
    if t[0] == "NT0": nt0 = bytearray(bytes.fromhex(t[1]))
    elif t[0] == "W":
        a = int(t[3], 16)
        if NTB <= a < NTB + NTL: writes.append((int(t[1]), int(t[2]), a - NTB, int(t[4], 16)))
nper = max(w[0] for w in writes) + 1
# absolute time in lines
ev = sorted((p * LPF + l, o, v) for p, l, o, v in writes)
# bursts: gap > 20 lines ends one; settled states after each burst
states = [bytes(nt0)]; cur = bytearray(nt0); last = None
burst_end_times = []
for t, o, v in ev:
    cur[o] = v
    if o == 0x2BE:                  # the table's last byte: one whole redraw done
        states.append(bytes(cur))
settled = set(s[:0x2BF] for s in states)
def state_at(T):
    s = bytearray(nt0)
    for t, o, v in ev:
        if t >= T: break
        s[o] = v
    return s
res = {}
for model in ("hardware", "amimsx"):
    torn = []; rows = {}
    for k in range(1, nper - 1):
        if model == "amimsx":
            pic = bytes(state_at((k + 1) * LPF))
        else:
            pic = bytearray(NTL)
            for r in range(24):
                s = state_at(k * LPF + 70 + 8 * r)
                pic[r * 32:(r + 1) * 32] = s[r * 32:(r + 1) * 32]
            pic = bytes(pic)
        if pic[:0x2BF] not in settled:
            torn.append(k)
    res[model] = torn
    print("%-8s %d of %d pictures torn (%.1f%%)" % (model, len(torn), nper - 2, 100.0 * len(torn) / (nper - 2)))
print("whole-table redraws:", len(states) - 1, "in", nper, "frames")
