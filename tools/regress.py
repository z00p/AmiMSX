"""Tiered regression runner for AmiMSX.

Tiers:  smoke              titles with smoke=Y in tests/titles.csv (Docs/coverage.md)
        full               every title in scope
        feature:<name>     titles whose features include <name> (prefix match,
                           e.g. feature:cmd:LMMC, feature:split:mode, feature:mapper:KonamiSCC)
        ids:<id,id,...>    named titles
        auto[:REF]         picked from the files changed since REF (AUTO_RULES below);
                           REF defaults to where this branch left master (HEAD~1 on master)
Each title runs in WinUAE through winuae/batch_test.ps1 with its key script
(tests/keys/<keys>.keys) plus SNAP markers at its shot times, so every capture
is an exact MSX frame. Captures are compared pixel for pixel with the accepted
baseline (build/regress/baseline/<id>/), or with an earlier run (--base); the
report lists new, changed and missing captures, with a side-by-side sheet of
the changed titles.

--jobs N runs N WinUAEs side by side (slots 1..N, each on its own copy of run/
and the Workbench); --lock takes the shared build/winuae.lock first and gives it
up between titles every --hold minutes, so other sessions get their turn.

Usage:
    python tools/regress.py smoke [--exe AmiMSX] [--run NAME] [--jobs 3 --lock]
    python tools/regress.py auto --jobs 3 --lock   (what the changes since master need)
    python tools/regress.py full --accept          (run, then make it the baseline)
    python tools/regress.py --accept-run NAME [--ids a,b]   (accept an earlier run)
"""
import argparse, csv, datetime, os, queue, shutil, subprocess, sys, threading, time
from concurrent.futures import ThreadPoolExecutor, FIRST_COMPLETED, wait
from PIL import Image, ImageChops, ImageDraw

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REG = os.path.join(BASE, "build", "regress")
BASELINE = os.path.join(REG, "baseline")
BATCH = os.path.join(BASE, "winuae", "batch_test.ps1")
LOCK = os.path.join(BASE, "build", "winuae.lock")
CROP = (8, 30, -8, -28)          # WinUAE window grab -> emulator picture

# (4.7) Tier "auto": what each changed file needs, first matching prefix wins; a file
# that matches nothing needs the full set (the Z80 core and VDP live in Main). The
# captures are pictures, so sound changes, and the menus, saves, RTG and Smooth
# Display (not in the 030 runs), only need the smoke set to show nothing broke.
AUTO_RULES = [
    ("Docs/", None), (".github/", None), ("Pics/", None), ("README", None),
    ("CONTRIBUTING", None), ("NOTICE", None), (".gitignore", None),
    ("tests/keys/try/", None), ("tests/", "smoke"),
    ("tools/keyscript.py", "smoke"), ("tools/", None), ("winuae/", "smoke"),
    ("AmiMSX_FM_v4.asm", "smoke"), ("AmiMSX_Psx_v4.asm", "smoke"), ("Sound/", "smoke"),
    ("AmiMSX_Menu", "smoke"), ("GadToolsBox/", "smoke"), ("AmiMSX_Saves_v4.asm", "smoke"),
    ("AmiMSX_Rtg_v4.asm", "smoke"), ("AmiMSX_Dbuf_v4.asm", "smoke"),
    ("AmiMSX_RomDb_v4.asm", "feature:mapper:"), ("AmiMSX4.romdb", "feature:mapper:"),
    ("AmiMSX2.mapper", "feature:mapper:"), ("AmiMSX4.diskdb", "feature:disk"),
]


def titles():
    return list(csv.DictReader(open(os.path.join(BASE, "tests", "titles.csv"), encoding="utf-8")))


def git(*args):
    return subprocess.run(["git", "-C", BASE] + list(args), capture_output=True, text=True).stdout.strip()


def auto_tiers(ref):
    """The tiers the files changed since ref (working tree included) need."""
    if not ref:
        ref = "HEAD~1" if git("rev-parse", "--abbrev-ref", "HEAD") == "master" else git("merge-base", "HEAD", "master")
    files = git("diff", "--name-only", ref).splitlines()
    files += [f for f in git("ls-files", "--others", "--exclude-standard").splitlines()
              if f.endswith((".asm", ".i", ".s"))]
    need = {}
    for f in files:
        if f.startswith("tests/keys/") and f.endswith(".keys") and "/try/" not in f:
            t = "keys:" + os.path.basename(f)[:-5]      # the titles that use that key script
        else:
            t = next((t for p, t in AUTO_RULES if f.startswith(p)), "full")
        if t:
            need.setdefault(t, []).append(f)
    for t, fs in need.items():
        print(f"auto ({ref[:12]}): {t:18s} for {', '.join(fs[:4])}" + (" ..." if len(fs) > 4 else ""))
    if not need:
        print(f"auto ({ref[:12]}): no changes that need a run")
    return list(need)


def select(rows, tier):
    rows = [r for r in rows if "out of scope" not in r["notes"]]
    if tier.startswith("auto"):
        want = set()
        for t in auto_tiers(tier[5:]):
            want |= {r["id"] for r in select(rows, t)}
        return [r for r in rows if r["id"] in want]
    if tier == "smoke":
        return [r for r in rows if r["smoke"] == "Y"]
    if tier == "full":
        return rows
    if tier.startswith("feature:"):
        f = tier[8:]
        return [r for r in rows if any(x.startswith(f) for x in r.get("features", "").split())]
    if tier.startswith("keys:"):
        return [r for r in rows if r["keys"] == tier[5:]]
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


def run_title(r, exe, outdir, slot=0):
    """One WinUAE run per title, all its SNAPs in it (12 Oct 2026: 24 of 24
    captures of 8 titles matched the one-run-per-capture baselines, and MSX
    RAM/VRAM state dumps matched with and without an earlier freeze). With
    --per-shot, one run per capture as before (a freeze once perturbed later
    captures)."""
    shots = [s.strip() for s in r["shots"].split(",") if s.strip()]
    base_keys = os.path.join(BASE, "tests", "keys", r["keys"] + ".keys")
    cfg = "AmiMSX-" + (CONFIG or r["config"]) + ".uae"
    name = os.path.splitext(r["file"])[0]
    shotdir = os.path.join(BASE, "build", "shots", f"slot{slot}" if slot else "")
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
               BATCH, "-Exe", exe, "-Roms", r["file"],
               "-Keys", keys, "-Config", cfg, "-Shots", str(int(last) + 5),
               "-SnapWait", str(int(last * 3) + 90 * len(grp)), "-Slot", str(slot)]
        cmd += slot2_args(r)
        if cfg.startswith("AmiMSX-rtg"):
            cmd += ["-Wb", "wbrtg"]          # the RTG configs boot their own Workbench
        p = subprocess.run(cmd, capture_output=True, text=True)
        msgs.append(p.stdout.strip().splitlines()[0] if p.stdout.strip() else p.stderr.strip()[:200])
        for s in grp:
            src = os.path.join(shotdir, f"{name}_{s}s.png")
            if os.path.exists(src) and os.path.getmtime(src) > t0:
                dst = os.path.join(outdir, r["id"], f"{s}s.png")
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                shutil.move(src, dst)
                got.append(s)
    return got, "; ".join(msgs)


def winuae_running():
    out = subprocess.run(["tasklist", "/FO", "CSV", "/NH"], capture_output=True, text=True).stdout.lower()
    return "winuae" in out or "arnold-uae" in out


def take_lock():
    """The shared WinUAE lock (memory: winuae-lock-protocol): no WinUAE running and
    the lock folder made by us. A lock over 30 minutes old with no WinUAE is stale."""
    said = False
    while True:
        if not winuae_running():
            try:
                os.mkdir(LOCK)
                return
            except FileExistsError:
                if time.time() - os.path.getmtime(LOCK) > 30 * 60:
                    print("removing a stale lock (over 30 min, no WinUAE)")
                    os.rmdir(LOCK)
                    continue
        if not said:
            print(f"{time.strftime('%H:%M:%S')} waiting for the WinUAE lock"); said = True
        time.sleep(5)


def give_lock():
    try:
        os.rmdir(LOCK)
    except OSError:
        pass


def run_many(sel, exe, rundir, jobs=1, lock=False, hold=12, done=None):
    """Runs every title of sel: on slot 0 for jobs=1, else on slots 1..jobs side by
    side. With lock, the shared lock is held for at most hold minutes of starts at a
    time, then given up (after the running titles end) for 20 s. done(r, got, msg)
    is called as each title ends, in finishing order."""
    slots = queue.Queue()
    for k in range(1, jobs + 1) if jobs > 1 else [0]:
        slots.put(k)

    def one(r):
        k = slots.get()
        try:
            return r, run_title(r, exe, rundir, k)
        finally:
            slots.put(k)

    todo = list(sel)
    results = {}
    with ThreadPoolExecutor(max(jobs, 1)) as ex:
        while todo:
            if lock:
                take_lock()
            t_held = time.time()
            running = set()
            try:
                while todo and (not lock or time.time() - t_held < hold * 60):
                    while len(running) >= max(jobs, 1):
                        fin, running = wait(running, return_when=FIRST_COMPLETED)
                        for f in fin:
                            r, (got, msg) = f.result(); results[r["id"]] = (got, msg)
                            if done: done(r, got, msg)
                    running.add(ex.submit(one, todo.pop(0)))
                for f in running:
                    r, (got, msg) = f.result(); results[r["id"]] = (got, msg)
                    if done: done(r, got, msg)
            finally:
                if lock:
                    give_lock()
            if todo and lock:
                time.sleep(20)
    return results


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


def sheet(rundir, changed, base=None):
    if not changed:
        return None
    base = base or BASELINE
    W, H = 240, 180
    rows = [(rid, s) for rid, ss in changed for s in ss]
    img = Image.new("RGB", (W * 2 + 8, (H + 14) * len(rows)), (30, 30, 30))
    d = ImageDraw.Draw(img)
    for k, (rid, s) in enumerate(rows):
        y = k * (H + 14)
        for j, p in enumerate((os.path.join(base, rid, f"{s}s.png"), os.path.join(rundir, rid, f"{s}s.png"))):
            if os.path.exists(p):
                img.paste(picture(p).resize((W, H)), (j * (W + 8), y + 14))
        d.text((3, y + 1), f"{rid} {s}s   {'baseline' if base == BASELINE else os.path.basename(base)} | this run", fill=(255, 255, 0))
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
    ap.add_argument("--jobs", type=int, default=1,
                    help="WinUAEs side by side (slots 1..N in build/slots); 1 = the shared run/ as before")
    ap.add_argument("--lock", action="store_true",
                    help="take the shared build/winuae.lock, giving it up every --hold minutes")
    ap.add_argument("--hold", type=float, default=12, help="minutes per lock hold (default 12)")
    ap.add_argument("--base", default="",
                    help="compare with this earlier run (build/regress/NAME) instead of the baseline")
    ap.add_argument("--list", action="store_true", help="only list the titles the tier picks")
    a = ap.parse_args()
    global PER_SHOT, OPTS, CONFIG
    PER_SHOT = a.per_shot
    CONFIG = a.config
    OPTS = [o.replace("=", " ") for o in a.opt]
    if a.accept_run:
        accept(os.path.join(REG, a.accept_run), set(a.ids.split(",")) if a.ids else None); return
    if not a.tier:
        ap.error("tier needed")
    sel = select(titles(), a.tier)
    if a.list:
        print(f"{len(sel)} titles: " + " ".join(r["id"] for r in sel)); return
    if not sel:
        return
    base = os.path.join(REG, a.base) if a.base else None
    START = datetime.datetime.now().timestamp()
    run = a.run or datetime.datetime.now().strftime("%Y%m%d-%H%M") + "-" + a.tier.replace(":", "_").replace(",", "+")[:40]
    rundir = os.path.join(REG, run)
    os.makedirs(rundir, exist_ok=True)
    print(f"{run}: {len(sel)} titles, build {a.exe}" + (f", {a.jobs} side by side" if a.jobs > 1 else ""))
    res_by_id = {}
    pr = threading.Lock()

    def done(r, got, msg):
        shots = [s.strip() for s in r["shots"].split(",") if s.strip()]
        res = compare(r["id"], rundir, shots, base)
        res_by_id[r["id"]] = (got, res)
        with pr:
            print(f"  {r['id']:34s} " + ", ".join(f"{s}s {st}" for s, st in res), flush=True)

    run_many(sel, a.exe, rundir, a.jobs, a.lock, a.hold, done)
    lines = [f"# Regression run {run}", "", f"Tier `{a.tier}`, build `{a.exe}`, {len(sel)} titles"
             + (f", compared with run `{a.base}`" if a.base else "") + ".", "",
             "| Title | Captures | Result |", "|---|---|---|"]
    changed, problems = [], 0
    for r in sel:
        got, res = res_by_id[r["id"]]
        ch = [s for s, st in res if st == "changed"]
        miss = [s for s, st in res if st == "missing"]
        if ch:
            changed.append((r["id"], ch))
        problems += bool(ch or miss)
        lines.append(f"| {r['id']} | {len(got)}/{len(res)} | {', '.join(f'{s}s {st}' for s, st in res)} |")
    sh = sheet(rundir, changed, base)
    mins = (datetime.datetime.now().timestamp() - START) / 60
    lines += ["", f"{len(sel) - problems} unchanged, {len(changed)} changed, "
              f"{sum(1 for l in lines if 'missing' in l)} with missing captures; {mins:.0f} min."]
    if sh:
        lines += ["", f"Changed captures side by side: `{os.path.relpath(sh, BASE)}`"]
    open(os.path.join(rundir, "report.md"), "w", encoding="utf-8").write("\n".join(lines) + "\n")
    print(f"{len(sel) - problems} unchanged, {len(changed)} changed, {mins:.0f} min; "
          f"report: {os.path.relpath(os.path.join(rundir, 'report.md'), BASE)}"
          + (f", sheet: {os.path.relpath(sh, BASE)}" if sh else ""))
    if a.accept or a.calibrate:
        accept(rundir, set(r["id"] for r in sel))
    if a.calibrate:
        run2 = run + "-repeat"
        rundir2 = os.path.join(REG, run2)
        os.makedirs(rundir2, exist_ok=True)
        START = datetime.datetime.now().timestamp()
        print(f"{run2}: repeat for stability")

        def done2(r, got, msg):
            shots = [s.strip() for s in r["shots"].split(",") if s.strip()]
            res = compare(r["id"], rundir2, shots, base=rundir)
            vary = [s for s, st in res if st == "changed"]
            p = os.path.join(BASELINE, r["id"], "unstable.txt")
            if vary:
                open(p, "w").write(" ".join(vary) + "\n")
            elif os.path.exists(p):
                os.remove(p)
            with pr:
                print(f"  {r['id']:34s} " + (f"unstable: {', '.join(v + 's' for v in vary)}" if vary else "stable"))

        run_many(sel, a.exe, rundir2, a.jobs, a.lock, a.hold, done2)


START = 0
if __name__ == "__main__":
    main()
