"""Tiered regression runner for AmiMSX.

Tiers:  smoke              titles with smoke=Y in tests/titles.csv (Docs/coverage.md)
        full               every title in scope
        feature:<name>     titles whose features include <name> (prefix match,
                           e.g. feature:cmd:LMMC, feature:split:mode, feature:mapper:KonamiSCC)
        ids:<id,id,...>    named titles
Each title runs in WinUAE through winuae/batch_test.ps1 with its key script
(tests/keys/<keys>.keys) plus SNAP markers at its shot times, so every capture
is an exact MSX frame. Captures are compared pixel for pixel with the accepted
baseline (build/regress/baseline/<id>/); the report lists new, changed and
missing captures, with a side-by-side sheet of the changed titles.

Usage:
    python tools/regress.py smoke [--exe AmiMSX] [--run NAME]
    python tools/regress.py full --accept          (run, then make it the baseline)
    python tools/regress.py --accept-run NAME [--ids a,b]   (accept an earlier run)
"""
import argparse, csv, datetime, os, shutil, subprocess, sys
from PIL import Image, ImageChops, ImageDraw

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REG = os.path.join(BASE, "build", "regress")
BASELINE = os.path.join(REG, "baseline")
CROP = (8, 30, -8, -28)          # WinUAE window grab -> emulator picture


def titles():
    return list(csv.DictReader(open(os.path.join(BASE, "tests", "titles.csv"), encoding="utf-8")))


def select(rows, tier):
    rows = [r for r in rows if "out of scope" not in r["notes"]]
    if tier == "smoke":
        return [r for r in rows if r["smoke"] == "Y"]
    if tier == "full":
        return rows
    if tier.startswith("feature:"):
        f = tier[8:]
        return [r for r in rows if any(x.startswith(f) for x in r.get("features", "").split())]
    if tier.startswith("ids:"):
        ids = tier[4:].split(",")
        return [r for r in rows if r["id"] in ids]
    raise SystemExit(f"unknown tier {tier}")


def picture(path):
    im = Image.open(path).convert("RGB")
    l, t, r, b = CROP
    return im.crop((l, t, im.width + r, im.height + b))


PER_SHOT = False
CONFIG = ""             # --config: one WinUAE config for every title
OPTS = []              # --opt name=value: key-script options for every run


def slot2_args(r):
    """(4.5) features "slot2:<file>": that cartridge (run/Roms) in Slot 2 too, through
    AmiMSX's test hook 'S2=' (Disk ROM None), e.g. the R-Type FM loader pair."""
    s2 = [f[6:] for f in r.get("features", "").split() if f.startswith("slot2:")]
    return ["-ExtraArg", f"S2=AmiMSX:Roms/{s2[0]}"] if s2 else []


def run_title(r, exe, outdir):
    """One WinUAE run per title, all its SNAPs in it (12 Oct 2026: 24 of 24
    captures of 8 titles matched the one-run-per-capture baselines, and MSX
    RAM/VRAM state dumps matched with and without an earlier freeze). With
    --per-shot, one run per capture as before (a freeze once perturbed later
    captures)."""
    shots = [s.strip() for s in r["shots"].split(",") if s.strip()]
    base_keys = os.path.join(BASE, "tests", "keys", r["keys"] + ".keys")
    cfg = "AmiMSX-" + (CONFIG or r["config"]) + ".uae"
    name = os.path.splitext(r["file"])[0]
    got, msgs = [], []
    groups = [[s] for s in shots] if PER_SHOT else [shots]
    for grp in groups:
        keys = os.path.join(outdir, f"{r['id']}_{'+'.join(grp)}s.keys")
        with open(keys, "w", encoding="utf-8") as f:
            f.write(f"include {os.path.relpath(base_keys, outdir)}\n")
            for opt in OPTS:
                f.write(f"option {opt}\n")
            for s in grp:
                f.write(f"{s}s SNAP\n")
        last = max(float(s) for s in grp)
        t0 = datetime.datetime.now().timestamp()
        cmd = ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
               os.path.join(BASE, "winuae", "batch_test.ps1"), "-Exe", exe, "-Roms", r["file"],
               "-Keys", keys, "-Config", cfg, "-Shots", str(int(last) + 5),
               "-SnapWait", str(int(last * 3) + 90 * len(grp))]
        cmd += slot2_args(r)
        p = subprocess.run(cmd, capture_output=True, text=True)
        msgs.append(p.stdout.strip().splitlines()[0] if p.stdout.strip() else p.stderr.strip()[:200])
        for s in grp:
            src = os.path.join(BASE, "build", "shots", f"{name}_{s}s.png")
            if os.path.exists(src) and os.path.getmtime(src) > t0:
                dst = os.path.join(outdir, r["id"], f"{s}s.png")
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                shutil.move(src, dst)
                got.append(s)
    return got, "; ".join(msgs)


def unstable(rid):
    p = os.path.join(BASELINE, rid, "unstable.txt")
    return set(open(p).read().split()) if os.path.exists(p) else set()


def compare(rid, rundir, shots, base=None):
    base = base or BASELINE
    vary = unstable(rid) if base == BASELINE else set()
    res = []
    for s in shots:
        new = os.path.join(rundir, rid, f"{s}s.png")
        old = os.path.join(base, rid, f"{s}s.png")
        if not os.path.exists(new):
            res.append((s, "missing")); continue
        if not os.path.exists(old):
            res.append((s, "new")); continue
        a, b = picture(old), picture(new)
        if a.size != b.size:
            res.append((s, "changed")); continue
        box = ImageChops.difference(a, b).getbbox()
        res.append((s, "same" if box is None else ("varies" if s in vary else "changed")))
    return res


def sheet(rundir, changed):
    if not changed:
        return None
    W, H = 240, 180
    rows = [(rid, s) for rid, ss in changed for s in ss]
    img = Image.new("RGB", (W * 2 + 8, (H + 14) * len(rows)), (30, 30, 30))
    d = ImageDraw.Draw(img)
    for k, (rid, s) in enumerate(rows):
        y = k * (H + 14)
        for j, p in enumerate((os.path.join(BASELINE, rid, f"{s}s.png"), os.path.join(rundir, rid, f"{s}s.png"))):
            if os.path.exists(p):
                img.paste(picture(p).resize((W, H)), (j * (W + 8), y + 14))
        d.text((3, y + 1), f"{rid} {s}s   baseline | this run", fill=(255, 255, 0))
    out = os.path.join(rundir, "changed.png")
    img.save(out)
    return out


def accept(rundir, ids=None):
    n = 0
    for rid in os.listdir(rundir):
        src = os.path.join(rundir, rid)
        if not os.path.isdir(src) or (ids and rid not in ids):
            continue
        dst = os.path.join(BASELINE, rid)
        os.makedirs(dst, exist_ok=True)
        for f in os.listdir(src):
            shutil.copy2(os.path.join(src, f), os.path.join(dst, f)); n += 1
    print(f"accepted {n} captures from {rundir} into the baseline")


def main():
    global START
    ap = argparse.ArgumentParser()
    ap.add_argument("tier", nargs="?")
    ap.add_argument("--exe", default="AmiMSX")
    ap.add_argument("--run", default="")
    ap.add_argument("--accept", action="store_true")
    ap.add_argument("--accept-run", default="")
    ap.add_argument("--ids", default="")
    ap.add_argument("--opt", action="append", default=[],
                    help="key-script option for every run, e.g. --opt dbuf=1 (see tools/keyscript.py)")
    ap.add_argument("--config", default="",
                    help="WinUAE config for every title (030, 060, a1200...), not the title's own")
    ap.add_argument("--per-shot", action="store_true",
                    help="one WinUAE run per capture (the old, slower mode)")
    ap.add_argument("--calibrate", action="store_true",
                    help="run the tier twice: the first run becomes the baseline, captures that "
                         "differ between the two are marked unstable (reported as 'varies')")
    a = ap.parse_args()
    global PER_SHOT, OPTS, CONFIG
    PER_SHOT = a.per_shot
    CONFIG = a.config
    OPTS = [o.replace("=", " ") for o in a.opt]
    if a.accept_run:
        accept(os.path.join(REG, a.accept_run), set(a.ids.split(",")) if a.ids else None); return
    if not a.tier:
        ap.error("tier needed")
    START = datetime.datetime.now().timestamp()
    run = a.run or datetime.datetime.now().strftime("%Y%m%d-%H%M") + "-" + a.tier.replace(":", "_").replace(",", "+")[:40]
    rundir = os.path.join(REG, run)
    os.makedirs(rundir, exist_ok=True)
    sel = select(titles(), a.tier)
    print(f"{run}: {len(sel)} titles, build {a.exe}")
    lines = [f"# Regression run {run}", "", f"Tier `{a.tier}`, build `{a.exe}`, {len(sel)} titles.", "",
             "| Title | Captures | Result |", "|---|---|---|"]
    changed, problems = [], 0
    for r in sel:
        got, msg = run_title(r, a.exe, rundir)
        shots = [s.strip() for s in r["shots"].split(",") if s.strip()]
        res = compare(r["id"], rundir, shots)
        ch = [s for s, st in res if st == "changed"]
        vr = [s for s, st in res if st == "varies"]
        miss = [s for s, st in res if st == "missing"]
        if ch:
            changed.append((r["id"], ch))
        problems += bool(ch or miss)
        summ = ", ".join(f"{s}s {st}" for s, st in res)
        lines.append(f"| {r['id']} | {len(got)}/{len(shots)} | {summ} |")
        print(f"  {r['id']:34s} {summ}")
    sh = sheet(rundir, changed)
    lines += ["", f"{len(sel) - problems} unchanged, {len(changed)} changed, "
              f"{sum(1 for l in lines if 'missing' in l)} with missing captures."]
    if sh:
        lines += ["", f"Changed captures side by side: `{os.path.relpath(sh, BASE)}`"]
    open(os.path.join(rundir, "report.md"), "w", encoding="utf-8").write("\n".join(lines) + "\n")
    print(f"report: {os.path.relpath(os.path.join(rundir, 'report.md'), BASE)}" + (f", sheet: {os.path.relpath(sh, BASE)}" if sh else ""))
    if a.accept or a.calibrate:
        accept(rundir, set(r["id"] for r in sel))
    if a.calibrate:
        run2 = run + "-repeat"
        rundir2 = os.path.join(REG, run2)
        os.makedirs(rundir2, exist_ok=True)
        START = datetime.datetime.now().timestamp()
        print(f"{run2}: repeat for stability")
        for r in sel:
            run_title(r, a.exe, rundir2)
            shots = [s.strip() for s in r["shots"].split(",") if s.strip()]
            res = compare(r["id"], rundir2, shots, base=rundir)
            vary = [s for s, st in res if st == "changed"]
            p = os.path.join(BASELINE, r["id"], "unstable.txt")
            if vary:
                open(p, "w").write(" ".join(vary) + "\n")
            elif os.path.exists(p):
                os.remove(p)
            print(f"  {r['id']:34s} " + (f"unstable: {', '.join(v + 's' for v in vary)}" if vary else "stable"))


START = 0
if __name__ == "__main__":
    main()
