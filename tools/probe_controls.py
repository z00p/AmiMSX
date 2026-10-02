"""Control probe: run titles in openMSX with their key script and take
screenshots, to see which reach play and respond to the scripted movement.
Writes build/probe/<keys>/<id>_<t>s.png and contact sheets build/probe/sheet_<n>.png.
Usage: python tools/probe_controls.py [--shots 38,44,50,56] [--only id,id] [--keys play]"""
import argparse, csv, os, subprocess, sys
from PIL import Image, ImageDraw

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OMSX = os.path.join(BASE, "tools", "openmsx", "openmsx.exe")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--shots", default="38,44,50,56")
    ap.add_argument("--only", default="")
    ap.add_argument("--keys", default="", help="override every title's key script")
    ap.add_argument("--tag", default="probe")
    a = ap.parse_args()
    rows = [r for r in csv.DictReader(open(os.path.join(BASE, "tests", "titles.csv"), encoding="utf-8"))
            if r["kind"] == "rom" and "out of scope" not in r["notes"]]
    only = set(x for x in a.only.split(",") if x)
    if only:
        rows = [r for r in rows if r["id"] in only]
    out = os.path.join(BASE, "build", a.tag)
    os.makedirs(out, exist_ok=True)
    shots = [float(x) for x in a.shots.split(",")]
    for r in rows:
        keys = a.keys or r["keys"]
        prefix = os.path.join(out, r["id"]).replace("\\", "/")
        tcl = os.path.join(out, r["id"] + ".tcl")
        subprocess.run([sys.executable, os.path.join(BASE, "tools", "keyscript.py"),
                        os.path.join(BASE, "tests", "keys", keys + ".keys"), "--tcl", tcl,
                        "--shots", a.shots, "--shots-prefix", prefix], check=True, capture_output=True)
        cmd = [OMSX, "-machine", "C-BIOS_MSX2_EU", "-cart", os.path.join(BASE, "run", "Roms", r["file"])]
        if r["romtype"]:
            cmd += ["-romtype", r["romtype"]]
        cmd += ["-script", tcl]
        try:
            subprocess.run(cmd, cwd=os.path.dirname(OMSX), timeout=240, capture_output=True)
        except subprocess.TimeoutExpired:
            print(r["id"], "timeout")
        print(r["id"], keys)
    # Sheets: 8 titles per sheet, one row each.
    W, H = 200, 150
    per = 8
    for n in range(0, len(rows), per):
        part = rows[n:n + per]
        img = Image.new("RGB", (W * len(shots), (H + 14) * len(part)), (30, 30, 30))
        d = ImageDraw.Draw(img)
        for j, r in enumerate(part):
            for i, t in enumerate(shots):
                p = os.path.join(out, f"{r['id']}_{t:g}s.png")
                if os.path.exists(p):
                    img.paste(Image.open(p).convert("RGB").resize((W, H)), (i * W, j * (H + 14) + 14))
            d.text((3, j * (H + 14) + 1), f"{r['id']}  ({a.keys or r['keys']})  " + " | ".join(f"{t:g}s" for t in shots), fill=(255, 255, 0))
        img.save(os.path.join(out, f"sheet_{n // per + 1}.png"))
    print("sheets in", out)


if __name__ == "__main__":
    main()
