"""Record a title's sound in openMSX for the sound model checks.

Runs the title with its regression keys on the reference machine
(AmiMSX_MSX2_RealFM: YM2149 PSG at volume 21000, MSX-MUSIC at 9000) and writes,
under the output prefix:
  <out>-PSG-ch1..3_0001.wav, <out>-MSX-MUSIC-ch1..14_0001.wav  each channel
  <out>_mix.wav                                                the full mix
  <out>_writes.txt   "P time reg value" (PSG), "F time reg value" (OPLL)

Usage: python tools/snd_capture.py <title id> <out prefix> [--from s] [--to s]
"""
import argparse, csv, os, subprocess, sys

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OMSX = os.path.join(BASE, "tools", "openmsx", "openmsx.exe")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("title")
    ap.add_argument("out")
    ap.add_argument("--from", dest="t0", type=float, default=15)
    ap.add_argument("--to", dest="t1", type=float, default=75)
    ap.add_argument("--machine", default="AmiMSX_MSX2_RealFM")
    a = ap.parse_args()
    row = next(r for r in csv.DictReader(open(os.path.join(BASE, "tests", "titles.csv")))
               if r["id"] == a.title)
    out = os.path.abspath(a.out).replace(os.sep, "/")
    tcl = out + "_keys.tcl"
    subprocess.run([sys.executable, os.path.join(BASE, "tools", "keyscript.py"),
                    os.path.join(BASE, "tests", "keys", row["keys"] + ".keys"),
                    "--tcl", tcl, "--shots", "", "--exit", str(a.t1 + 2)],
                   check=True, capture_output=True)
    s = open(tcl).read().replace("set throttle off\n", "")
    s += f"""set ::f [open {{{out}_writes.txt}} w]
set ::r 0
set ::p 0
debug set_watchpoint write_io 0x7C {{}} {{set ::r $::wp_last_value}}
debug set_watchpoint write_io 0x7D {{}} {{puts $::f "F [machine_info time] $::r $::wp_last_value"}}
debug set_watchpoint write_io 0xA0 {{}} {{set ::p $::wp_last_value}}
debug set_watchpoint write_io 0xA1 {{}} {{puts $::f "P [machine_info time] $::p $::wp_last_value"}}
after time {a.t0} {{record_channels all -prefix {{{out}}}; record start -audioonly {{{out}_mix.wav}}}}
after time {a.t1} {{record stop; record_channels stop; close $::f}}
set throttle off
"""
    open(tcl, "w").write(s)
    cmd = [OMSX, "-machine", a.machine, "-cart", os.path.join(BASE, "run", "Roms", row["file"])]
    if row["romtype"]:
        cmd += ["-romtype", row["romtype"]]
    cmd += ["-script", tcl]
    p = subprocess.run(cmd, cwd=os.path.dirname(OMSX), timeout=a.t1 + 240,
                       capture_output=True, text=True)
    print("exit", p.returncode, (p.stderr or "")[-400:])


if __name__ == "__main__":
    main()
