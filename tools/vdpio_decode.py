"""Decode tools/omsx_vdpio.tcl logs: VDP register writes (port 99 pairs, reset
by status reads, and
port 9B indirect writes), screen mode changes and VDP commands with their
full parameters as issued, per frame and line.
Usage: python tools/vdpio_decode.py x.vdpio.txt [--regs] [--frames a-b]"""
import sys

CMDS = {0x4: "POINT", 0x5: "PSET", 0x6: "SRCH", 0x7: "LINE", 0x8: "LMMV", 0x9: "LMMM", 0xA: "LMCM",
        0xB: "LMMC", 0xC: "HMMV", 0xD: "HMMM", 0xE: "YMMM", 0xF: "HMMC"}
MODES = {(0, 0): "S1", (0x02, 0): "S2", (0x04, 0): "S4", (0x06, 0): "S5", (0x08, 0): "S6", (0x0A, 0): "S7",
         (0x0E, 0): "S8", (0, 0x10): "S0", (0x04, 0x10): "S0w80", (0, 0x08): "S3"}
args = sys.argv[1:]
show_regs = "--regs" in args
rng = None
if "--frames" in args:
    a, b = args[args.index("--frames") + 1].split("-"); rng = (int(a), int(b))
regs = [0] * 47
latch = None
for l in open(args[0]):
    t = l.split()
    if t[0] == "R":
        regs = [int(x, 16) for x in t[1:]]
        continue
    if t[0] == "V":
        if not rng or rng[0] <= int(t[1]) <= rng[1]:
            print(f"--- end of frame {t[1]}: {t[2]} port-98 writes")
        continue
    kind, fr, line, v = t[0], int(t[1]), int(t[2]), int(t[3], 16)
    if kind == "r":                     # status read: resets the port-99 latch
        latch = None
        continue
    show = not rng or rng[0] <= fr <= rng[1]
    reg = None
    if kind == "9":
        if latch is None:
            latch = v
            continue
        if v & 0x80:
            reg, val = v & 0x3F, latch
        latch = None
        if reg is None:
            continue
    else:
        reg = regs[17] & 0x3F
        val = v
        if not regs[17] & 0x80:
            regs[17] = (regs[17] & 0xC0) | ((reg + 1) & 0x3F)
    if reg == 17 and kind == "B":
        pass
    old = regs[reg] if reg < 47 else None
    if reg < 47:
        regs[reg] = val
    if not show:
        continue
    if reg in (0, 1):
        m = MODES.get(((regs[0] & 0x0E), (regs[1] & 0x18)), f"R0={regs[0]:02X} R1={regs[1]:02X}")
        if reg == 0 or show_regs:
            print(f"f{fr} l{line:3d} R#{reg}={val:02X} mode {m}")
    elif reg == 46:
        c = val >> 4
        sx = regs[32] | (regs[33] & 1) << 8; sy = regs[34] | (regs[35] & 3) << 8
        dx = regs[36] | (regs[37] & 1) << 8; dy = regs[38] | (regs[39] & 3) << 8
        nx = regs[40] | (regs[41] & 1) << 8; ny = regs[42] | (regs[43] & 3) << 8
        m = MODES.get(((regs[0] & 0x0E), (regs[1] & 0x18)), "?")
        print(f"f{fr} l{line:3d} {CMDS.get(c, 'STOP'):5s} op{val & 15:X} S({sx},{sy}) D({dx},{dy}) N({nx},{ny}) "
              f"CLR {regs[44]:02X} ARG {regs[45]:02X}  [{m}]")
    elif show_regs or reg in (2, 3, 4, 5, 6, 10, 11, 14, 23, 18, 19):
        print(f"f{fr} l{line:3d} R#{reg}={val:02X}" + (f" (was {old:02X})" if old is not None else ""))
