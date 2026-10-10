"""Overnight batch: the full regression, then consecutive-frame bursts
(tools/burst.py) for the sprite-mode-2 titles and the cross-reference queue, then
a summary. Runs detached (Start-Process) so no 30-minute limit applies.

Usage: python tools/overnight.py <tag> [--skip-regress] [--only id,id]
Log: build/overnight/<tag>.log; summary: build/overnight/<tag>.md"""
import argparse, csv, datetime, os, subprocess, sys, time

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(BASE, "build", "overnight")

# Cross-reference queue: times picked for the reported problems.
QUEUE = {
    "M_Ianna_A16": "50,60,68",          # hero drawn as stripes (openMSX ~65-70 s)
    "M_Lilly_A16": "30,45,60",          # line in the right border at the HUD split
    "M_Barbarian_A16": "22,28,34,40",   # sprite flicker during the fight
}


def log(msg):
    line = f"{datetime.datetime.now():%H:%M:%S} {msg}"
    print(line, flush=True)
    with open(LOGF, "a", encoding="utf-8") as f:
        f.write(line + "\n")


def winuae_running():
    p = subprocess.run(["tasklist", "/FI", "IMAGENAME eq winuae64.exe"], capture_output=True, text=True)
    q = subprocess.run(["tasklist", "/FI", "IMAGENAME eq winuae.exe"], capture_output=True, text=True)
    return "winuae" in (p.stdout + q.stdout).lower()


def run(cmd, timeout):
    t0 = time.time()
    try:
        p = subprocess.run(cmd, cwd=BASE, capture_output=True, text=True, timeout=timeout)
        out = (p.stdout or "") + (p.stderr or "")
    except subprocess.TimeoutExpired:
        out = "TIMEOUT"
        subprocess.run(["taskkill", "/F", "/IM", "winuae64.exe"], capture_output=True)
        subprocess.run(["taskkill", "/F", "/IM", "openmsx.exe"], capture_output=True)
    return out, time.time() - t0


def main():
    global LOGF
    ap = argparse.ArgumentParser()
    ap.add_argument("tag")
    ap.add_argument("--skip-regress", action="store_true")
    ap.add_argument("--only")
    a = ap.parse_args()
    os.makedirs(OUT, exist_ok=True)
    LOGF = os.path.join(OUT, a.tag + ".log")
    log(f"overnight {a.tag} start")
    while winuae_running():                 # an earlier capture still going
        time.sleep(20)

    regress = ""
    if not a.skip_regress:
        log("full regression")
        out, dt = run([sys.executable, "tools/regress.py", "full", "--run", a.tag], 6 * 3600)
        regress = out.strip()
        log(f"full regression done in {dt / 60:.0f} min")
        with open(os.path.join(OUT, a.tag + "_regress.txt"), "w", encoding="utf-8") as f:
            f.write(out)

    rows = list(csv.DictReader(open(os.path.join(BASE, "tests", "titles.csv"), encoding="utf-8")))
    rows = [r for r in rows if "out of scope" not in r["notes"]]
    plan = dict(QUEUE)
    for r in rows:
        if "sprites:mode2" in r["features"] and r["id"] not in plan:
            plan[r["id"]] = r["shots"]
    if a.only:
        plan = {k: v for k, v in plan.items() if k in a.only.split(",")}
    results = []
    for i, (rid, times) in enumerate(plan.items(), 1):
        log(f"burst {i}/{len(plan)} {rid} at {times}")
        out, dt = run([sys.executable, "tools/burst.py", rid, times, "--tag", f"{a.tag}/{rid}"], 1800)
        lines = [l for l in out.splitlines() if l.startswith(rid + "\t")]
        log(f"  {dt / 60:.1f} min; " + ("; ".join(l.replace(chr(9), " ") for l in lines) or out.strip()[-200:]))
        results += lines

    # Summary: flag bursts where AmiMSX flickers clearly more than openMSX.
    md = [f"# Overnight {a.tag}", ""]
    if regress:
        md += ["## Full regression", "", "```", regress[-3000:], "```", ""]
    md += ["## Bursts (16 consecutive frames; flicker = pixels going A,B,A)", "",
           "| Title | Time | AmiMSX frames | AmiMSX flicker | openMSX frames | openMSX flicker | Flag |",
           "|---|---|---|---|---|---|---|"]
    for l in results:
        p = l.split("\t")
        if len(p) < 4:
            continue
        am, om = p[2].split(), p[3].split()
        fa, fo = am[3], om[3]
        flag = ""
        if am[1] != "16":
            flag = "frames missing"
        elif fa != "-" and fo != "-" and float(fa) > 2 * float(fo) + 50:
            flag = "**AmiMSX flickers more**"
        md.append(f"| {p[0]} | {p[1]} | {am[1]} | {fa} | {om[1]} | {fo} | {flag} |")
    md += ["", f"Sheets: build/bursts/{a.tag}/<id>/<time>s/sheet.png. The emulators are not "
           "frame-locked, and they drift apart over a minute: compare the flicker pattern, not the scene."]
    with open(os.path.join(OUT, a.tag + ".md"), "w", encoding="utf-8") as f:
        f.write("\n".join(md) + "\n")
    log(f"overnight {a.tag} done")


if __name__ == "__main__":
    main()
