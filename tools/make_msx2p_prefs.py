"""Make the MSX2 / MSX2+ test prefs for the cmd411 WinUAE runs from run/scroll_r2/FM030.prefs
(the 030 preset): $10 = ROM/machine (1 MSX2, 2 MSX2+), $1D = sound 0 (PSG), filter off
(the LED-based SNAP capture needs it), $6B = Refresh 100% Graphics (already FF)."""
import os
src = r"C:\AMD\amimsx\run\scroll_r2\FM030.prefs"
out = r"C:\AMD\amimsx\run\cmd411"
os.makedirs(out, exist_ok=True)
b = bytearray(open(src, "rb").read())
assert b[:8] == b"MSX2v2.5"
assert b[0x6B] == 0xFF, hex(b[0x6B])
b[0x1D] = 0
for name, machine in (("msx2.prefs", 1), ("msx2p.prefs", 2)):
    b[0x10] = machine
    open(os.path.join(out, name), "wb").write(b)
    print(name, "machine", machine, "filter byte", hex(b[-3]), "dbuf", hex(b[-2]))
