"""Coverage scan: run every ROM title of tests/titles.csv in openMSX (C-BIOS
MSX2) with its key script and tools/omsx_featurescan.tcl, collect the
features into build/scan/scan.json.
Usage: python tools/scan_titles.py [--secs 60] [--only id,id]"""
import argparse, csv, json, os, re, subprocess, sys

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OMSX = os.path.join(BASE, "tools", "openmsx", "openmsx.exe")
OUT = os.path.join(BASE, "build", "scan")


def tcl_dict(text):
    """Parse a flat Tcl list of key/value pairs (values may be {nested} lists)."""
    toks, i, depth, cur = [], 0, 0, ""
    for ch in text.strip():
        if ch == "{":
            if depth:
                cur += ch
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth:
                cur += ch
            elif not cur:
                toks.append(""); continue
        elif ch.isspace() and not depth:
            if cur:
                toks.append(cur); cur = ""
        else:
            cur += ch
    if cur:
        toks.append(cur)
    d = {}
    for k, v in zip(toks[::2], toks[1::2]):
        if v == "":
            d[k] = {}
        elif " " in v:
            p = v.split()
            d[k] = {a: int(b) for a, b in zip(p[::2], p[1::2])}
        else:
            d[k] = int(v) if re.fullmatch(r"-?\d+", v) else v
    return d


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--secs", type=int, default=60)
    ap.add_argument("--only", default="")
    a = ap.parse_args()
    os.makedirs(OUT, exist_ok=True)
    rows = list(csv.DictReader(open(os.path.join(BASE, "tests", "titles.csv"), encoding="utf-8")))
    only = set(x for x in a.only.split(",") if x)
    resf = os.path.join(OUT, "scan.json")
    res = json.load(open(resf)) if os.path.exists(resf) else {}
    scan = open(os.path.join(BASE, "tools", "omsx_featurescan.tcl"), encoding="utf-8").read()
    for r in rows:
        if r["kind"] != "rom" or (only and r["id"] not in only) or "out of scope" in r["notes"]:
            continue
        kt = os.path.join(OUT, r["id"] + ".keys.tcl")
        subprocess.run([sys.executable, os.path.join(BASE, "tools", "keyscript.py"),
                        os.path.join(BASE, "tests", "keys", r["keys"] + ".keys"), "--tcl", kt],
                       check=True, capture_output=True)
        keys = [l for l in open(kt).read().splitlines() if "exit" not in l and "throttle" not in l]
        outtxt = os.path.join(OUT, r["id"] + ".txt").replace("\\", "/")
        if os.path.exists(outtxt):
            os.remove(outtxt)
        run = os.path.join(OUT, r["id"] + ".tcl")
        with open(run, "w", encoding="ascii") as f:
            f.write("\n".join(keys) + f"\nset ::out {{{outtxt}}}\nset ::secs {a.secs}\n" + scan)
        cmd = [OMSX, "-machine", "C-BIOS_MSX2_EU", "-cart", os.path.join(BASE, "run", "Roms", r["file"])]
        if r["romtype"]:
            cmd += ["-romtype", r["romtype"]]
        cmd += ["-script", run]
        try:
            subprocess.run(cmd, cwd=os.path.dirname(OMSX), timeout=240, capture_output=True)
        except subprocess.TimeoutExpired:
            print(r["id"], "timeout"); continue
        if not os.path.exists(outtxt):
            print(r["id"], "no result"); continue
        res[r["id"]] = tcl_dict(open(outtxt).read())
        d = res[r["id"]]
        print(f"{r['id']:34s} modes {d.get('modes')}  ie1 {d.get('ie1')}  cmds {d.get('cmds')}")
        json.dump(res, open(resf, "w"), indent=1)
    print(len(res), "titles in", resf)


if __name__ == "__main__":
    main()
