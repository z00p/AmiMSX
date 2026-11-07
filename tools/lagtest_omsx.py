"""The game's own lag in openMSX (4.7, Docs/agent_notes/lag-4.7.md): the same
press as tools/lagtest.py, VRAM saved at the end of each frame around it, a
run without the press as reference. Prints, per press offset, the frames from
the press to the first frame whose VRAM differs (openMSX shows a VRAM change
made in frame n during the scan of frame n+1).

Usage: python tools/lagtest_omsx.py --rom R2K_Nemesis2.rom [--key UP] [--at 2150]
       [--offsets 0,1,2,3] [--machine C-BIOS_MSX2_EU]
"""
import argparse, glob, os, subprocess

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OMSX = os.path.join(BASE, "tools", "openmsx", "openmsx.exe")
KEYS = {"UP": (8, 0x20), "DOWN": (8, 0x40), "LEFT": (8, 0x10), "RIGHT": (8, 0x80), "SPACE": (8, 0x01)}
FPS = 50


def tcl(path, out, press, key, at):
    row, mask = KEYS[key]
    with open(path, "w") as f:
        f.write("set throttle off\nset maxframeskip 0\n")
        for fr in range(700, 2001, 100):           # lag_play.keys: Space taps
            f.write(f"after time {fr / FPS:.3f} {{keymatrixdown 8 0x01}}\n")
            f.write(f"after time {(fr + 5) / FPS:.3f} {{keymatrixup 8 0x01}}\n")
        if press is not None:
            f.write(f"after time {press / FPS:.3f} {{keymatrixdown {row} 0x{mask:02X}}}\n")
            f.write(f"after time {(press + 10) / FPS:.3f} {{keymatrixup {row} 0x{mask:02X}}}\n")
        f.write("set ::n 0\n")
        f.write("proc ::dump {} {\n"
                f"  set f [open [format {{{out}_%03d.bin}} $::n] wb]\n"
                "  puts -nonewline $f [debug read_block VRAM 0 0x20000]\n"
                "  close $f\n"
                f"  set t [open {{{out}_t.txt}} a]; puts $t \"$::n [machine_info time]\"; close $t\n"
                "  incr ::n\n"
                "  if {$::n < 24} { after frame ::dump } else { exit }\n"
                "}\n")
        f.write(f"after time {(at - 4) / FPS:.3f} {{after frame ::dump}}\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--rom", required=True)
    ap.add_argument("--key", default="UP")
    ap.add_argument("--at", type=int, default=2150)
    ap.add_argument("--offsets", default="0,1,2,3")
    ap.add_argument("--machine", default="C-BIOS_MSX2_EU")
    a = ap.parse_args()
    stem = os.path.splitext(a.rom)[0]
    od = os.path.join(BASE, "build", "lag", "omsx")
    os.makedirs(od, exist_ok=True)
    runs = [("nopress", None)] + [(f"p{d}", a.at + int(d)) for d in a.offsets.split(",")]
    for name, press in runs:
        out = os.path.join(od, f"{stem}_{name}").replace("\\", "/")
        for old in glob.glob(out + "_*"):
            os.remove(old)
        t = out + ".tcl"
        tcl(t, out, press, a.key, a.at)
        subprocess.run([OMSX, "-machine", a.machine, "-cart", os.path.join(BASE, "run", "Roms", a.rom),
                        "-script", t], cwd=os.path.dirname(OMSX), timeout=600, capture_output=True)

    def frames(name):
        out = os.path.join(od, f"{stem}_{name}")
        ts = {}
        for line in open(out + "_t.txt"):
            n, tm = line.split()
            ts[int(n)] = float(tm)
        return {n: (tm, open(f"{out}_{n:03d}.bin", "rb").read()) for n, tm in ts.items()}
    ref = frames("nopress")
    print(f"{stem} in openMSX ({a.machine}): press {a.key} at {a.at}+d")
    for name, press in runs[1:]:
        f = frames(name)
        tp = press / FPS
        first = next((n for n in sorted(f) if n in ref and f[n][1] != ref[n][1]), None)
        if first is None:
            print(name, "no change within the dumps")
            continue
        # frame ends after the press, up to and including the first changed one
        k = sum(1 for n in sorted(f) if tp < f[n][0] <= f[first][0])
        print(f"{name}: VRAM differs at the end of frame {k} after the press "
              f"(press {tp:.3f} s, frame end {f[first][0]:.3f} s); on screen in the scan after it")


if __name__ == "__main__":
    main()
