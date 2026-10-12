"""Space Manbow performance runs (Docs/perf_spacemanbow_plan.md, step 1).

For each config (WinUAE 68060 and 68030) and machine (MSX2, MSX2+): a perf
build with sub-timers and the PC profile runs the game's 'play' key script for
60 s, then exits to the menu, which writes perf.bin. Reports: per-window
speed/load and sub-timers (read_perf.py), and the top routines in the second
half of the run, which is gameplay (read_prof.py).

Usage: python tools/sm_perf.py [--rom R2K_SpaceManbow.rom] [--secs 60]
       [--configs 060,030] [--machines 1,2]
Output: build/overnight/sm_<config>_<machine>.txt and a summary in build/overnight/sm_summary.md
"""
import argparse, os, subprocess, sys

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VASM = os.path.join(BASE, "tools", "vasmm68k_mot.exe")
MACH = {"0": "MSX", "1": "MSX2", "2": "MSX2+"}


def run(cmd, **kw):
    return subprocess.run(cmd, cwd=BASE, capture_output=True, text=True, **kw)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--rom", default="R2K_SpaceManbow.rom")
    ap.add_argument("--secs", type=int, default=60)
    ap.add_argument("--configs", default="060,030")
    ap.add_argument("--machines", default="1,2")
    a = ap.parse_args()
    out = os.path.join(BASE, "build", "overnight")
    os.makedirs(out, exist_ok=True)
    exe = "AmiMSX_smperf"
    lst = os.path.join(BASE, "build", exe + ".lst")
    r = run([VASM, "-devpac", "-nocase", "-m68020", "-Fhunkexe", "-nosym", "-maxerrors=0",
             "-DPERF=1", "-DPERFSUBS=1", f"-DPERFTICKS={a.secs * 50}", "-L", lst,
             "-o", os.path.join("build", exe), "AmiMSX_Main_v3.1.asm"])
    if r.returncode:
        sys.exit("assembly failed:\n" + r.stdout[-2000:] + r.stderr[-2000:])
    stem = os.path.splitext(a.rom)[0]
    summary = ["# Space Manbow performance runs", "",
               f"ROM `{a.rom}`, {a.secs} s from power on with the play key script; perf build with sub-timers and PC profile.", ""]
    for cfg in a.configs.split(","):
        for m in a.machines.split(","):
            keys = os.path.join(BASE, "build", f"sm_{m}.keys")
            open(keys, "w").write(f"include ../tests/keys/play.keys\noption machine {m}\noption sprites 1\n")
            tag = f"sm_{cfg}_{m}"
            perf = os.path.join(BASE, "run", "perf.bin")
            if os.path.exists(perf):
                os.remove(perf)
            run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                 os.path.join(BASE, "winuae", "batch_test.ps1"), "-Exe", exe, "-Roms", a.rom,
                 "-Keys", keys, "-Config", f"AmiMSX-{cfg}.uae", "-Shots", str(a.secs + 25),
                 "-WaitFile", "perf.bin", "-MaxWait", "400", "-Tag", tag])
            binf = os.path.join(BASE, "build", "perf", f"{stem}_{tag}.bin")
            rep = os.path.join(out, f"{tag}.txt")
            if not os.path.exists(binf):
                open(rep, "w").write("no perf.bin\n")
                summary.append(f"- {cfg} / {MACH[m]}: no perf.bin")
                continue
            rp = run([sys.executable, os.path.join("tools", "read_perf.py"), binf]).stdout
            # profile: the second half of the samples (gameplay)
            pr = run([sys.executable, os.path.join("tools", "read_prof.py"), binf, lst, "0", "30"]).stdout
            open(rep, "w").write(rp + "\n\n" + pr)
            lines = [l for l in rp.splitlines() if l.strip()[:1].isdigit()]
            last = lines[-3:] if lines else []
            summary.append(f"## {cfg} / {MACH[m]}")
            summary.append("```")
            summary.extend([rp.splitlines()[1] if len(rp.splitlines()) > 1 else ""] + last)
            summary.append("```")
            summary.append(f"Full report: `build/overnight/{tag}.txt`")
            summary.append("")
            print(tag, "done")
    open(os.path.join(out, "sm_summary.md"), "w").write("\n".join(summary) + "\n")
    print("summary: build/overnight/sm_summary.md")


if __name__ == "__main__":
    main()
