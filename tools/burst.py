"""Consecutive-frame bursts: N frames in a row from AmiMSX (key-script SNAPs one
MSX frame apart) and from openMSX (a screenshot every frame, throttle on), at
the same scripted times, with a contact sheet of both. For flicker and
one-frame glitches the 3-shot regression captures cannot show.

Usage: python tools/burst.py <id> <seconds[,seconds..]> [--n 16] [--exe AmiMSX]
                             [--tag name] [--no-omsx] [--no-amimsx]
Output: build/bursts/<tag>/<seconds>s/{amimsx,omsx}/f00.png.., sheet.png, and
build/bursts/<tag>/flicker.txt. All bursts of a title come from one run of each
emulator (tag defaults to <id>). The emulators are not frame-locked: the same
script time is close, not the same frame (and they drift apart over a minute).
--no-amimsx / --no-omsx reuse frames already on disk.

Flicker score: pixels that go A, B, A over three consecutive frames (A != B),
averaged per frame triple, on a 256x212 scale. Sprite multiplexing on a real
MSX scores too, so compare AmiMSX with openMSX, not with zero."""
import argparse, csv, glob, os, subprocess, sys
from PIL import Image, ImageChops, ImageDraw

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(BASE, "tools"))
from regress import picture  # noqa: E402

OMSX = os.path.join(BASE, "tools", "openmsx", "openmsx.exe")
FPS = 50
MACHINE = "C-BIOS_MSX2_EU"   # --machine: openMSX machine (e.g. C-BIOS_MSX2+_EU)


def row(rid):
    for r in csv.DictReader(open(os.path.join(BASE, "tests", "titles.csv"), encoding="utf-8")):
        if r["id"] == rid:
            return r
    raise SystemExit(f"unknown id {rid}")


def tdir(out, t, who):
    d = os.path.join(out, f"{t:g}s", who)
    os.makedirs(d, exist_ok=True)
    return d


def amimsx(r, times, n, exe, out):
    keys = os.path.join(out, "burst.keys")
    base_keys = os.path.join(BASE, "tests", "keys", r["keys"] + ".keys")
    with open(keys, "w", encoding="utf-8") as f:
        f.write(f"include {os.path.relpath(base_keys, out)}\n")
        for t in times:
            for k in range(n):
                f.write(f"{int(round(t * FPS)) + k} SNAP 300\n")
    name = os.path.splitext(r["file"])[0]
    shots = os.path.join(BASE, "build", "shots")
    for old in glob.glob(os.path.join(shots, glob.escape(name) + "_*s.png")):
        os.remove(old)
    last = max(times)
    cmd = ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
           os.path.join(BASE, "winuae", "batch_test.ps1"), "-Exe", exe, "-Roms", r["file"],
           "-Keys", keys, "-Config", "AmiMSX-" + r["config"] + ".uae",
           "-Shots", str(int(last) + 30), "-SnapWait", str(int(last * 3) + 90 + n * 8 * len(times))]
    p = subprocess.run(cmd, capture_output=True, text=True)
    print("amimsx:", (p.stdout.strip().splitlines() or ["?"])[0])
    got = {}
    for t in times:
        d = tdir(out, t, "amimsx")
        for old in glob.glob(os.path.join(glob.escape(d), "f*.png")):
            os.remove(old)
        got[t] = []
        f0 = int(round(t * FPS))
        for k in range(n):
            src = os.path.join(shots, f"{name}_{(f0 + k) / FPS:g}s.png")
            if os.path.exists(src):
                dst = os.path.join(d, f"f{k:02d}.png")
                picture(src).save(dst)
                os.remove(src)
                got[t].append(dst)
    return got


def omsx(r, times, n, out):
    for t in times:
        for old in glob.glob(os.path.join(glob.escape(tdir(out, t, "omsx")), "f*.png")):
            os.remove(old)
    tcl = os.path.join(out, "burst.tcl")
    last = max(times)
    subprocess.run([sys.executable, os.path.join(BASE, "tools", "keyscript.py"),
                    os.path.join(BASE, "tests", "keys", r["keys"] + ".keys"), "--tcl", tcl,
                    "--shots", "", "--exit", str(last + n / FPS + 2)], check=True, capture_output=True)
    s = open(tcl).read().replace("set throttle off\n", "")
    s += "set ::bn 0\n"
    s += "proc ::burst {dir} {\n"
    s += "    screenshot [format \"%s/f%02d.png\" $dir $::bn]\n"
    s += "    incr ::bn\n"
    s += f"    if {{$::bn < {n}}} {{ after frame [list ::burst $dir] }} else {{ set ::bn 0; set throttle off }}\n"
    s += "}\n"
    for t in times:
        d = tdir(out, t, "omsx").replace(os.sep, "/")
        s += f"after time {max(t - 1, 0):g} {{set throttle on; set minframeskip 0; set maxframeskip 0}}\n"
        s += f"after time {t:g} {{::burst {{{d}}}}}\n"
    s += "set throttle off\n"
    open(tcl, "w").write(s)
    cmd = [OMSX, "-machine", MACHINE]
    if r["kind"] in ("dsk", "disk"):
        cmd += ["-diska", os.path.join(BASE, "run", "Disks", r["file"])]
    else:
        cmd += ["-cart", os.path.join(BASE, "run", "Roms", r["file"])]
        if r["romtype"]:
            cmd += ["-romtype", r["romtype"]]
    cmd += ["-script", tcl]
    try:
        subprocess.run(cmd, cwd=os.path.dirname(OMSX), timeout=int(last) + 300, capture_output=True)
    except subprocess.TimeoutExpired:
        print("omsx: timeout")
    got = {t: sorted(glob.glob(os.path.join(glob.escape(os.path.join(out, f"{t:g}s", "omsx")), "f*.png"))) for t in times}
    print("omsx:", ", ".join(f"{t:g}s {len(g)}/{n}" for t, g in got.items()))
    return got


def flicker(fs):
    """Mean count of pixels going A, B, A over consecutive frame triples."""
    if len(fs) < 3:
        return None
    ims = [Image.open(f).convert("RGB").resize((256, 212)) for f in fs]
    tot = 0
    for a, b, c in zip(ims, ims[1:], ims[2:]):
        ab = ImageChops.difference(a, b).convert("L").point(lambda v: 255 if v > 24 else 0)
        ac = ImageChops.difference(a, c).convert("L").point(lambda v: 255 if v <= 24 else 0)
        tot += sum(1 for v in ImageChops.multiply(ab, ac).get_flattened_data() if v)
    return tot / (len(ims) - 2)


def sheet(path, rows, w=256, h=200, cols=8):
    rows = [(lab, fs) for lab, fs in rows if fs]
    if not rows:
        return
    n = max(len(fs) for _, fs in rows)
    bands = (n + cols - 1) // cols
    out = Image.new("RGB", (w * cols, (h + 2) * bands * len(rows)), (40, 0, 0))
    d = ImageDraw.Draw(out)
    for b in range(bands):
        for j, (lab, fs) in enumerate(rows):
            y = ((b * len(rows)) + j) * (h + 2)
            for c in range(cols):
                k = b * cols + c
                if k < len(fs):
                    out.paste(Image.open(fs[k]).convert("RGB").resize((w, h)), (c * w, y))
                    d.text((c * w + 3, y + 2), f"{lab} {k}", fill=(255, 255, 0))
    out.save(path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("id")
    ap.add_argument("secs")
    ap.add_argument("--n", type=int, default=16)
    ap.add_argument("--exe", default="AmiMSX")
    ap.add_argument("--tag")
    ap.add_argument("--no-omsx", action="store_true")
    ap.add_argument("--no-amimsx", action="store_true")
    ap.add_argument("--keys", help="key script in tests/keys instead of the title's (e.g. none)")
    ap.add_argument("--machine", default="C-BIOS_MSX2_EU", help="openMSX machine (C-BIOS_MSX2+_EU for MSX2+ titles)")
    a = ap.parse_args()
    global MACHINE
    MACHINE = a.machine
    r = row(a.id)
    if a.keys:
        r = dict(r, keys=a.keys)
    times = [float(x) for x in a.secs.split(",") if x]
    out = os.path.join(BASE, "build", "bursts", a.tag or a.id)
    os.makedirs(out, exist_ok=True)
    am = {} if a.no_amimsx else amimsx(r, times, a.n, a.exe, out)
    om = {} if a.no_omsx else omsx(r, times, a.n, out)
    fmt = lambda v: "-" if v is None else f"{v:.0f}"
    lines = []
    for t in times:
        d = os.path.join(out, f"{t:g}s")
        fa = am.get(t) or sorted(glob.glob(os.path.join(glob.escape(os.path.join(d, "amimsx")), "f*.png")))
        fo = om.get(t) or sorted(glob.glob(os.path.join(glob.escape(os.path.join(d, "omsx")), "f*.png")))
        sheet(os.path.join(d, "sheet.png"), [("ami", fa), ("omsx", fo)])
        lines.append(f"{a.id}\t{t:g}s\tamimsx {len(fa)} flicker {fmt(flicker(fa))}"
                     f"\topenmsx {len(fo)} flicker {fmt(flicker(fo))}")
    with open(os.path.join(out, "flicker.txt"), "w") as f:
        f.write("\n".join(lines) + "\n")
    print("\n".join(lines))


if __name__ == "__main__":
    main()
