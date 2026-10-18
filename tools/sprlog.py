"""Per-frame sprite attribute log from openMSX (tools/omsx_sprlog.tcl) while a
key script plays a title: which sprites move, when the game writes the
attribute table and R#18/R#23 within the frame, and how many VDP commands it
issues per frame.

Usage: python tools/sprlog.py <rom-or-dsk file> <from s> <frames> [--keys play]
           [--machine C-BIOS_MSX2_EU] [--romtype KonamiSCC] [--nspr 8] [--out dir]
Output: <out>/<name>.spr.txt (default out: build/sprites). The emulator is
C:\\AMD\\amimsx\\tools\\openmsx; ROMs/disks come from C:\\AMD\\amimsx\\run."""
import argparse, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
BASE = os.path.dirname(HERE)
MAIN = r"C:\AMD\amimsx"
OMSX = os.path.join(MAIN, "tools", "openmsx", "openmsx.exe")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("file")
    ap.add_argument("frm", type=float)
    ap.add_argument("frames", type=int)
    ap.add_argument("--keys", default="play")
    ap.add_argument("--machine", default="C-BIOS_MSX2_EU")
    ap.add_argument("--romtype", default="")
    ap.add_argument("--nspr", type=int, default=8)
    ap.add_argument("--out", default=os.path.join(BASE, "build", "sprites"))
    ap.add_argument("--shots", default="", help="screenshot times, e.g. 50,60,70 (s)")
    ap.add_argument("--tag", default="", help="output name suffix")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    name = os.path.splitext(a.file)[0] + (("_" + a.tag) if a.tag else "")
    out = os.path.join(a.out, name).replace(os.sep, "/")
    keys = a.keys if os.path.exists(a.keys) else os.path.join(MAIN, "tests", "keys", a.keys + ".keys")
    tcl = os.path.join(a.out, name + "_keys.tcl")
    end = a.frm + a.frames / 50.0 + 2
    if a.shots:
        end = max(end, max(float(x) for x in a.shots.split(",") if x) + 1)
    subprocess.run([sys.executable, os.path.join(MAIN, "tools", "keyscript.py"),
                    keys, "--tcl", tcl,
                    "--shots", "", "--exit", str(end)], check=True, capture_output=True)
    s = open(tcl).read().replace("set throttle off\n", "")
    s += f"set ::out {{{out}}}\nset ::from {a.frm:g}\nset ::frames {a.frames}\nset ::nspr {a.nspr}\n"
    for t in [x for x in a.shots.split(",") if x]:
        s += "after time %s {screenshot {%s_%ss.png}}\n" % (t, out, t)
    s += "source {%s}\n" % os.path.join(HERE, "omsx_sprlog.tcl").replace(os.sep, "/")
    open(tcl, "w").write(s)
    cmd = [OMSX, "-machine", a.machine]
    if a.file.lower().endswith(".dsk"):
        cmd += ["-diska", os.path.join(MAIN, "run", "Disks", a.file)]
    else:
        cmd += ["-cart", os.path.join(MAIN, "run", "Roms", a.file)]
        if a.romtype:
            cmd += ["-romtype", a.romtype]
    cmd += ["-script", tcl]
    try:
        p = subprocess.run(cmd, cwd=os.path.dirname(OMSX), timeout=int(end) + 240, capture_output=True, text=True)
        print("openmsx exit", p.returncode, (p.stderr or "")[-400:])
    except subprocess.TimeoutExpired:
        print("openmsx: timeout")
    print(out + ".spr.txt")


if __name__ == "__main__":
    main()
