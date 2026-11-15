"""Point a test drawer's presets at its Games folder (a tester, 15 Nov 2026).

A test drawer on the NAS looks like:
    AmiMSX<ver>-TestN/
        AmiMSX/        program, presets (prefs files named by their icons' PREFS=)
        Games/         the test ROMs and disks
        TESTING-*.txt

The disk (prefs offset $080) and cartridge ($180) requester drawers are stored
in each preset, relative to the AmiMSX drawer (the icon's drawer is the current
directory). Setting both to "/Games" makes Drive A/B and Slot 1/2 open there.

Usage:
    python tools/set_test_drawer.py <test drawer>/AmiMSX [--drawer /Games] [--dry-run]
"""
import argparse, os, re, sys

DISK, CART, FIELD = 0x80, 0x180, 0x100


def presets(d):
    """Prefs files named by a PREFS= ToolType in the drawer's .info files."""
    names = set()
    for f in os.listdir(d):
        if f.lower().endswith(".info"):
            data = open(os.path.join(d, f), "rb").read()
            for m in re.finditer(rb"PREFS=([^\x00]+)\x00", data):
                names.add(m.group(1).decode("latin-1"))
    return sorted(n for n in names if os.path.isfile(os.path.join(d, n)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("drawer", help="the test drawer's AmiMSX folder")
    ap.add_argument("--drawer", dest="target", default="/Games")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    val = a.target.encode("latin-1")
    if len(val) >= FIELD:
        sys.exit("drawer name too long")
    found = presets(a.drawer)
    if not found:
        sys.exit("no presets (PREFS= ToolTypes) in " + a.drawer)
    for n in found:
        p = os.path.join(a.drawer, n)
        b = bytearray(open(p, "rb").read())
        if len(b) < CART + FIELD:
            print("skip (short file):", n)
            continue
        old = bytes(b[DISK:DISK + FIELD]).split(b"\0")[0].decode("latin-1")
        for off in (DISK, CART):
            b[off:off + FIELD] = val + bytes(FIELD - len(val))
        print("%-28s disk %r -> %r, cartridge -> %r" % (n, old, a.target, a.target))
        if not a.dry_run:
            open(p, "wb").write(b)


if __name__ == "__main__":
    main()
