"""Motion study for any suite title: consecutive-frame bursts from AmiMSX and
openMSX (tools/burst.py), a display-timing run (PERF build, DispLog), then
tools/motion.py on each burst (scroll steps, repeated frames, flicker,
side_by_side.gif, real_time.gif).

Usage: python tools/motion_study.py <id> <s[,s..]> [--n 16] [--cfg 030] [--keys play]
       [--region x0,y0,x1,y1] [--wait <file>]
Output: build/bursts/<id>_motion/<s>s/... and build/overnight/<id>_motion.md
"""
import argparse, os, subprocess, sys, time

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VASM = os.path.join(BASE, "tools", "vasmm68k_mot.exe")


def run(cmd, **kw):
    return subprocess.run(cmd, cwd=BASE, capture_output=True, text=True, **kw)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("id")
    ap.add_argument("secs")
    ap.add_argument("--n", type=int, default=16)
    ap.add_argument("--cfg", default="030")
    ap.add_argument("--keys", help="key script name in tests/keys (default: the title's)")
    ap.add_argument("--region", default="0,0,256,212")
    ap.add_argument("--wait")
    a = ap.parse_args()
    if a.wait:
        while not os.path.exists(os.path.join(BASE, a.wait)):
            time.sleep(30)
        time.sleep(10)
    import csv
    row = next(r for r in csv.DictReader(open(os.path.join(BASE, "tests", "titles.csv"), encoding="utf-8"))
               if r["id"] == a.id)
    keys = a.keys or row["keys"]
    tag = f"{a.id}_motion"
    cmd = [sys.executable, "tools/burst.py", a.id, a.secs, "--n", str(a.n), "--tag", tag]
    if a.keys:
        cmd += ["--keys", a.keys]
    run(cmd, timeout=7200)
    times = [float(t) for t in a.secs.split(",")]
    exe = "AmiMSX_disp"
    secs = int(max(times)) + 10
    r = run([VASM, "-devpac", "-nocase", "-m68020", "-Fhunkexe", "-nosym", "-maxerrors=0",
             "-DPERF=1", f"-DPERFTICKS={secs * 50}", "-o", os.path.join("build", exe), "AmiMSX_Main_v3.1.asm"])
    if r.returncode:
        sys.exit("assembly failed")
    perf = os.path.join(BASE, "run", "perf.bin")
    if os.path.exists(perf):
        os.remove(perf)
    rom = row["file"]
    run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
         os.path.join(BASE, "winuae", "batch_test.ps1"), "-Exe", exe, "-Roms", rom,
         "-Keys", os.path.join(BASE, "tests", "keys", keys + ".keys"), "-Config", f"AmiMSX-{a.cfg}.uae",
         "-Shots", str(secs + 25), "-WaitFile", "perf.bin", "-MaxWait", "400", "-Tag", f"disp_{a.cfg}"])
    binf = os.path.join(BASE, "build", "perf", f"{os.path.splitext(rom)[0]}_disp_{a.cfg}.bin")
    out = [f"# {a.id}: motion study ({a.cfg} config)", ""]
    for t in times:
        d = os.path.join(BASE, "build", "bursts", tag, f"{t:g}s")
        if not os.path.isdir(d):
            continue
        cmd = [sys.executable, "tools/motion.py", d, "--region", a.region]
        if os.path.exists(binf):
            cmd += ["--perf", binf, "--start", f"{t:g}"]
        r = run(cmd)
        out += [f"## {t:g} s", "```", r.stdout.strip(), "```", ""]
    rep = os.path.join(BASE, "build", "overnight", f"{a.id}_motion.md")
    open(rep, "w").write("\n".join(out) + "\n")
    print(rep)


if __name__ == "__main__":
    main()
