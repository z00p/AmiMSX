"""Controller lag runs (4.7, Docs/agent_notes/lag-4.7.md).

A LAGLOG build (vasm -DPERF=1 -DLAGLOG=1 -DPERFTICKS=n) logs, per MSX frame,
the VBlank and beam line at the end of the emulated frame, after the input
read and after the render, plus a sum of the VRAM at the render; and, for
each input change, the frame and line where the Z80 first read it. It exits
to the menu after PERFTICKS frames and writes perf.bin.

One run without the press and one per press offset (the same key script with
a key pressed at frame AT+d). The first frame whose VRAM sum differs from the
no-press run is the game's response. Reported per offset, in MSX frames and
Amiga VBlanks:
  read   frame and line where the game first read the change (T1)
  resp   frames from the press to the first frame drawn differently
  shown  VBlanks from the input read to that frame's render (RTG: on screen
         from that VBlank; AGA Smooth Display: one VBlank after the next
         commit, see 'commit')

Usage:
  python tools/lagtest.py --rom R2K_Nemesis2.rom --exe AmiMSX_lag --config rtgrt
         [--base play_title] [--key UP] [--at 2150] [--offsets 0,1,2,3]
         [--jobs 3] [--lock] [--prefs file] [--tag name]
  python tools/lagtest.py --read build/perf/x_nopress.bin build/perf/x_p0.bin ...
"""
import argparse, os, struct, subprocess, sys
from concurrent.futures import ThreadPoolExecutor

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BATCH = os.path.join(BASE, "winuae", "batch_test.ps1")
sys.path.insert(0, os.path.join(BASE, "tools"))


def read_lag(path):
    d = open(path, "rb").read()
    i = d.rfind(b"LAGL")
    if i < 0:                       # (first builds: the marker assembled as 0)
        i = len(d) - (12 + 20 * 4096 + 12 * 64)
    n, t1n = struct.unpack(">II", d[i + 4:i + 12])
    rn = 4096
    recs = d[i + 12:i + 12 + 16 * rn]
    sums = d[i + 12 + 16 * rn:i + 12 + 20 * rn]
    t1 = d[i + 12 + 20 * rn:i + 12 + 20 * rn + 12 * 64]
    frames = {}
    for k in range(min(n, rn)):
        fr, ve, le, vs, ls, vr, lr = struct.unpack(">I6H", recs[16 * k:16 * k + 16])
        s, = struct.unpack(">I", sums[4 * k:4 * k + 4])
        frames[fr] = dict(ve=ve, le=le, vs=vs, ls=ls, vr=vr, lr=lr, sum=s)
    reads = [struct.unpack(">IIHH", t1[12 * k:12 * k + 12]) for k in range(min(t1n, 64))]
    return frames, reads


def vdiff(a, b):
    return (b - a) & 0xFFFF


def analyse(nopress, press, at):
    f0, _ = read_lag(nopress)
    f1, reads = read_lag(press)
    out = dict(at=at)
    rd = [r for r in reads if r[0] == at]
    out["read"] = (rd[0][1] - at, rd[0][2]) if rd else None
    resp = None
    for fr in sorted(f1):
        if fr >= at and fr in f0 and f1[fr]["vr"] != 0xFFFF and f1[fr]["sum"] != f0[fr]["sum"]:
            resp = fr
            break
    out["resp"] = None if resp is None else resp - at
    if resp is not None and at in f1:
        s, r = f1[at], f1[resp]
        out["shown"] = vdiff(s["vs"], r["vr"])
        out["render_line"] = r["lr"]
        nxt = f1.get(resp + 1)
        out["commit"] = vdiff(s["vs"], nxt["ve"]) + 1 if nxt else None
    return out


def busy(path):
    """Per frame: beam lines from the input read to the end of the emulated
    frame (render + emulation), as a share of the 313-line PAL frame."""
    f, _ = read_lag(path)
    ks = sorted(f)
    xs = []
    for a, b in zip(ks, ks[1:]):
        if b != a + 1:
            continue
        s, e = f[a], f[b]
        dv = vdiff(s["vs"], e["ve"])
        xs.append(dv * 313 + e["le"] - s["ls"])
    xs.sort()
    if not xs:
        return None
    return dict(n=len(xs), median=xs[len(xs) // 2] / 313, p95=xs[int(len(xs) * .95)] / 313, max=xs[-1] / 313)


def run_one(a, keys, tag, slot):
    cmd = ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", BATCH,
           "-Exe", a.exe, "-Roms", a.rom, "-Keys", keys, "-Config", f"AmiMSX-{a.config}.uae",
           "-Shots", str(a.secs + 25), "-WaitFile", "perf_rtg.bin" if a.config.startswith("rtg") else "perf.bin", "-MaxWait", "400",
           "-Tag", tag, "-Slot", str(slot)]
    if a.prefs:
        cmd += ["-Prefs", a.prefs]
    if a.config.startswith("rtg"):
        cmd += ["-Wb", "wbrtg"]          # the RTG configs boot their own Workbench
    p = subprocess.run(cmd, cwd=BASE, capture_output=True, text=True)
    return p.stdout.strip().splitlines()[-1:] or [p.stderr.strip()[:200]]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--rom")
    ap.add_argument("--exe", default="AmiMSX_lag")
    ap.add_argument("--config", default="rtgrt")
    ap.add_argument("--base", default="lag_play")
    ap.add_argument("--key", default="UP")
    ap.add_argument("--at", type=int, default=2150)
    ap.add_argument("--offsets", default="0,1,2,3")
    ap.add_argument("--secs", type=int, default=52)
    ap.add_argument("--jobs", type=int, default=3)
    ap.add_argument("--lock", action="store_true")
    ap.add_argument("--prefs", default="")
    ap.add_argument("--tag", default="")
    ap.add_argument("--opt", action="append", default=[], help="key-script option, e.g. 'dbuf 1'")
    ap.add_argument("--read", nargs="+")
    a = ap.parse_args()
    if a.read:
        for p in a.read:
            print(p, busy(p))
        return
    stem = os.path.splitext(a.rom)[0]
    tagb = a.tag or a.config
    kd = os.path.join(BASE, "build", "lag")
    os.makedirs(kd, exist_ok=True)
    offs = [int(x) for x in a.offsets.split(",")]
    jobs = [("nopress", None)] + [(f"p{d}", a.at + d) for d in offs]
    plan = []
    for name, fr in jobs:
        k = os.path.join(kd, f"{stem}_{tagb}_{name}.keys")
        with open(k, "w") as f:
            f.write(f"include ../../tests/keys/{a.base}.keys\n")
            for o in a.opt:
                f.write(f"option {o}\n")
            if fr is not None:
                f.write(f"{fr} {a.key} 10\n")
        plan.append((name, fr, k, f"{tagb}_{name}"))
    import regress
    if a.lock:
        regress.take_lock()
    try:
        import queue
        free = queue.Queue()
        for s in range(1, a.jobs + 1):
            free.put(s)

        def slotted(k, t):
            s = free.get()
            try:
                return run_one(a, k, t, s)
            finally:
                free.put(s)
        with ThreadPoolExecutor(a.jobs) as ex:
            futs = [ex.submit(slotted, k, t) for (_, _, k, t) in plan]
            for (name, *_), fu in zip(plan, futs):
                print(name, fu.result())
    finally:
        if a.lock:
            regress.give_lock()
    pd = os.path.join(BASE, "build", "perf")
    np_ = os.path.join(pd, f"{stem}_{tagb}_nopress.bin")
    print(f"\n{stem} on {a.config}: press {a.key} at {a.at}+d")
    print("busy (input read to end of frame, Amiga frames):", busy(np_))
    for name, fr, _, t in plan[1:]:
        print(name, analyse(np_, os.path.join(pd, f"{stem}_{t}.bin"), fr))


if __name__ == "__main__":
    main()
