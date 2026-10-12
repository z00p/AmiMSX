"""Space Manbow motion study (after the table-split regression): AmiMSX bursts
(gameplay with the play keys; the intro with no keys), display-timing runs
(PERF build with DispLog, 060 and 030), then tools/motion.py on each burst.

Usage: python tools/sm_motion_run.py [--wait build/regress/<run>/report.md]
Output: build/bursts/sm_vis/<t>s/, build/bursts/sm_demo/<t>s/ (motion.txt,
side_by_side.gif, real_time.gif) and build/overnight/sm_motion.md
"""
import argparse, os, subprocess, sys, time

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VASM = os.path.join(BASE, "tools", "vasmm68k_mot.exe")


def run(cmd, **kw):
    return subprocess.run(cmd, cwd=BASE, capture_output=True, text=True, **kw)


def perf_run(exe, keys, cfg, tag, secs=70):
    perf = os.path.join(BASE, "run", "perf.bin")
    if os.path.exists(perf):
        os.remove(perf)
    run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
         os.path.join(BASE, "winuae", "batch_test.ps1"), "-Exe", exe, "-Roms", "R2K_SpaceManbow.rom",
         "-Keys", keys, "-Config", f"AmiMSX-{cfg}.uae", "-Shots", str(secs + 25),
         "-WaitFile", "perf.bin", "-MaxWait", "400", "-Tag", tag])
    return os.path.join(BASE, "build", "perf", f"R2K_SpaceManbow_{tag}.bin")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--wait")
    a = ap.parse_args()
    if a.wait:
        while not os.path.exists(os.path.join(BASE, a.wait)):
            time.sleep(30)
        time.sleep(10)
    # bursts (AmiMSX side; openMSX frames are already on disk)
    run([sys.executable, "tools/burst.py", "R2K_SpaceManbow", "30,40,50,60", "--n", "16",
         "--tag", "sm_vis", "--no-omsx"], timeout=7200)
    run([sys.executable, "tools/burst.py", "R2K_SpaceManbow", "30,40,50,60,70", "--n", "16",
         "--tag", "sm_demo", "--keys", "none"], timeout=7200)
    # display timing: PERF build (DispLog), 70 s, normal runs (no SNAPs)
    r = run([VASM, "-devpac", "-nocase", "-m68020", "-Fhunkexe", "-nosym", "-maxerrors=0",
             "-DPERF=1", "-DPERFTICKS=3500", "-o", os.path.join("build", "AmiMSX_disp"), "AmiMSX_Main_v3.1.asm"])
    if r.returncode:
        sys.exit("assembly failed")
    play = os.path.join(BASE, "tests", "keys", "play.keys")
    none = os.path.join(BASE, "tests", "keys", "none.keys")
    bins = {("play", "060"): perf_run("AmiMSX_disp", play, "060", "disp_play_060"),
            ("play", "030"): perf_run("AmiMSX_disp", play, "030", "disp_play_030"),
            ("none", "060"): perf_run("AmiMSX_disp", none, "060", "disp_none_060")}
    out = ["# Space Manbow motion study", ""]
    for tag, keys, times in (("sm_vis", "play", (30, 40, 50, 60)), ("sm_demo", "none", (30, 40, 50, 60, 70))):
        for t in times:
            d = os.path.join(BASE, "build", "bursts", tag, f"{t}s")
            if not os.path.isdir(d):
                continue
            for cfg in ("060", "030"):
                b = bins.get((keys, cfg))
                if not b or not os.path.exists(b):
                    continue
                r = run([sys.executable, "tools/motion.py", d, "--region", "0,40,256,196" if keys == "play" else "0,0,256,212",
                         "--perf", b, "--start", str(t)])
                if cfg == "060":
                    os.replace(os.path.join(d, "real_time.gif"), os.path.join(d, "real_time_060.gif")) if os.path.exists(os.path.join(d, "real_time.gif")) else None
                else:
                    os.replace(os.path.join(d, "real_time.gif"), os.path.join(d, "real_time_030.gif")) if os.path.exists(os.path.join(d, "real_time.gif")) else None
                out.append(f"## {tag} {t}s, timing from the {cfg} config")
                out.append("```")
                out.append(r.stdout.strip())
                out.append("```")
                out.append("")
    open(os.path.join(BASE, "build", "overnight", "sm_motion.md"), "w").write("\n".join(out) + "\n")
    print("done: build/overnight/sm_motion.md")


if __name__ == "__main__":
    main()
