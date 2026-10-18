"""Consecutive-frame burst (tools/burst.py's AmiMSX or openMSX side) with a
WinUAE config and key script of your choice, for sprite-position checks on
a fast-CPU config (AmiMSX-060.uae) that burst.py cannot select.

Usage: python tools/sprburst.py <id> <seconds> --exe AmiMSX_x [--cfg 060] [--keys <name or path>]
           [--n 16] [--tag name] [--omsx] [--machine C-BIOS_MSX2_EU]
Output: build/sprites/bursts/<tag>/<seconds>s/{amimsx,omsx}/f00.png.. and sheet.png.
Runs the harness from C:\\AMD\\amimsx (WinUAE lock: take it yourself first)."""
import argparse, glob, os, sys

MAIN = r"C:\AMD\amimsx"
HERE = os.path.dirname(os.path.abspath(__file__))
BASE = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(MAIN, "tools"))
import burst  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("id")
    ap.add_argument("secs", type=float)
    ap.add_argument("--exe", default="AmiMSX")
    ap.add_argument("--cfg", default="060")
    ap.add_argument("--keys")
    ap.add_argument("--n", type=int, default=16)
    ap.add_argument("--tag")
    ap.add_argument("--omsx", action="store_true", help="the openMSX side instead of AmiMSX")
    ap.add_argument("--machine", default="C-BIOS_MSX2_EU")
    a = ap.parse_args()
    r = burst.row(a.id)
    r = dict(r, config=a.cfg)
    if a.keys:
        k = a.keys
        if os.path.exists(k):          # a path: make it relative to MAIN/tests/keys
            k = os.path.relpath(os.path.abspath(k), os.path.join(MAIN, "tests", "keys"))
            if k.lower().endswith(".keys"):
                k = k[:-5]
        r["keys"] = k
    out = os.path.join(BASE, "build", "sprites", "bursts", a.tag or a.id)
    os.makedirs(out, exist_ok=True)
    burst.MACHINE = a.machine
    if a.omsx:
        got = burst.omsx(r, [a.secs], a.n, out)
    else:
        got = burst.amimsx(r, [a.secs], a.n, a.exe, out)
    d = os.path.join(out, f"{a.secs:g}s")
    fa = sorted(glob.glob(os.path.join(glob.escape(os.path.join(d, "amimsx")), "f*.png")))
    fo = sorted(glob.glob(os.path.join(glob.escape(os.path.join(d, "omsx")), "f*.png")))
    burst.sheet(os.path.join(d, "sheet.png"), [("ami", fa), ("omsx", fo)])
    print({t: len(g) for t, g in got.items()}, d)


if __name__ == "__main__":
    main()
