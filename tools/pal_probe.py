"""Palette probe: AmiMSX's MSX palette and mid-frame palette state at a moment
(perf build with PERFTICKS, its perf.bin dump) against openMSX's palette at
the same script time.

Usage: python tools/pal_probe.py <id> <seconds> [--exe AmiMSX_perfpal] [--decode file]
The exe must be a PERF build with PERFTICKS = seconds * 50 (it exits there and
writes perf.bin). Report: build/overnight/pal_<id>_<seconds>s.txt"""
import argparse, csv, os, shutil, struct, subprocess, sys

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OMSX = os.path.join(BASE, "tools", "openmsx", "openmsx.exe")
PALEVMAX = 6
COPPLINE = 0x10

# perf.bin tail, from the end (AmiMSX_Menu PerfDump): SCCalls, KeyFrN, RAM E000
# and C000, TAB98B, TAB98, GfxCaAdr, GfxCaPtr, cache, SCREEN, the two copper
# pointers, copper routines, copper line slots, PalDbg block, TSplit, MSX2Pal.
TAIL = [("acl", 8), ("dbcommits", 16), ("displine", 4096), ("displog", 4096), ("dispn", 4), ("flash", 12), ("opllcnt", 4), ("opll", 0x44), ("SCCalls", 4), ("KeyFrN", 4), ("ramE", 0x2000), ("ramC", 0x2000), ("tab98b", 0x4000),
        ("tab98", 0x4000), ("gfxcaadr", 8), ("gfxcaptr", 4), ("cache", 0x10000), ("screen", 0x8000),
        ("copopsptr", 4), ("coplnptr", 4), ("copops", 4096), ("coplines", 212 * COPPLINE),
        ("paldbg", 2 + 6 + PALEVMAX * 2 + 32 * PALEVMAX + 32), ("tsplit", 2), ("msx2pal", 32)]


def row(rid):
    for r in csv.DictReader(open(os.path.join(BASE, "tests", "titles.csv"), encoding="utf-8")):
        if r["id"] == rid:
            return r
    raise SystemExit(f"unknown id {rid}")


def blocks(d):
    out, end = {}, len(d)
    if d[end - 12292:end - 12288] == b"SPRL":    # (4.4) hardware-test log after AclN
        end -= 12292
    for name, n in TAIL:
        out[name] = d[end - n:end]
        end -= n
    return out


# 4.1.2+: MSX level n -> nibble 0,3,5,7,9,11,13,15 (PalLvRB/PalLvG); older builds 2n.
LEVEL = {v: n for n, v in enumerate((0, 3, 5, 7, 9, 11, 13, 15))}
LEVEL.update({2 * n: n for n in range(1, 8) if 2 * n not in LEVEL})


def ocs(w):
    """MSX2Pal word (Amiga 12-bit) -> MSX RGB digits (both the 4.1.2 levels and the old 2n)."""
    return "".join(str(LEVEL.get((w >> s) & 15, "?")) for s in (8, 4, 0))


def pal16(b):
    return [ocs(w) for w in struct.unpack(">16H", b)]


def decode(path):
    b = blocks(open(path, "rb").read())
    lines = [f"KeyFrN (MSX frames) {struct.unpack('>I', b['KeyFrN'])[0]}"]
    lines.append("MSX2Pal  " + " ".join(f"{i:x}:{c}" for i, c in enumerate(pal16(b["msx2pal"]))))
    p = b["paldbg"]
    seen = p[0]
    n, _, last = struct.unpack(">HHH", p[2:8])
    evl = struct.unpack(f">{PALEVMAX}H", p[8:8 + PALEVMAX * 2])
    o = 8 + PALEVMAX * 2
    lines.append(f"PalSplitSeen {seen}, PalEvN {n}, PalEvLast {last}, lines {list(evl[:max(n, 0)])}")
    for k in range(min(n, PALEVMAX)):
        lines.append(f"event {k} @{evl[k]} " + " ".join(
            f"{i:x}:{c}" for i, c in enumerate(pal16(p[o + 32 * k:o + 32 * k + 32]))))
    top = p[o + 32 * PALEVMAX:o + 32 * PALEVMAX + 32]
    lines.append("PalTop   " + " ".join(f"{i:x}:{c}" for i, c in enumerate(pal16(top))))
    return lines


def omsx_palette(r, secs):
    tcl = os.path.join(BASE, "build", "omsx", f"pal_{r['id']}.tcl")
    txt = os.path.join(BASE, "build", "omsx", f"pal_{r['id']}.txt").replace(os.sep, "/")
    subprocess.run([sys.executable, os.path.join(BASE, "tools", "keyscript.py"),
                    os.path.join(BASE, "tests", "keys", r["keys"] + ".keys"), "--tcl", tcl,
                    "--shots", "", "--exit", str(secs + 1)], check=True, capture_output=True)
    s = open(tcl).read().replace("set throttle off\n", "")
    s += (f'after time {secs} {{ set f [open "{txt}" w]; '
          'puts $f [string map {"\\n" " "} [palette]]; close $f }\nset throttle off\n')
    open(tcl, "w").write(s)
    cmd = [OMSX, "-machine", "C-BIOS_MSX2_EU", "-cart", os.path.join(BASE, "run", "Roms", r["file"])]
    if r["romtype"]:
        cmd += ["-romtype", r["romtype"]]
    subprocess.run(cmd + ["-script", tcl], cwd=os.path.dirname(OMSX), timeout=int(secs) + 200,
                   capture_output=True)
    d = dict(x.split(":") for x in open(txt).read().split())
    return [d[f"{i:x}"] for i in range(16)]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("id")
    ap.add_argument("secs", type=float)
    ap.add_argument("--exe", default="AmiMSX_perfpal")
    ap.add_argument("--decode")
    a = ap.parse_args()
    r = row(a.id)
    out = os.path.join(BASE, "build", "overnight")
    os.makedirs(out, exist_ok=True)
    binf = a.decode
    if not binf:
        perf = os.path.join(BASE, "run", "perf.bin")
        if os.path.exists(perf):
            os.remove(perf)
        tag = f"pal{a.secs:g}"
        subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                        os.path.join(BASE, "winuae", "batch_test.ps1"), "-Exe", a.exe, "-Roms", r["file"],
                        "-Keys", os.path.join(BASE, "tests", "keys", r["keys"] + ".keys"),
                        "-Config", "AmiMSX-" + r["config"] + ".uae", "-Shots", str(int(a.secs) + 20),
                        "-WaitFile", "perf.bin", "-MaxWait", "400", "-Tag", tag],
                       capture_output=True, text=True)
        binf = os.path.join(BASE, "build", "perf", f"{os.path.splitext(r['file'])[0]}_{tag}.bin")
    lines = [f"{a.id} at {a.secs:g}s", ""] + (decode(binf) if os.path.exists(binf) else [f"no dump {binf}"])
    t = a.secs
    if os.path.exists(binf):                 # openMSX at AmiMSX's actual MSX frame
        t = struct.unpack(">I", blocks(open(binf, "rb").read())["KeyFrN"])[0] / 50
        lines.append(f"openMSX read at {t:g}s (AmiMSX's MSX frame count)")
    try:
        om = omsx_palette(r, t)
        lines.append("openMSX  " + " ".join(f"{i:x}:{c}" for i, c in enumerate(om)))
    except Exception as e:  # noqa: BLE001
        lines.append(f"openMSX palette failed: {e}")
    rep = os.path.join(out, f"pal_{a.id}_{a.secs:g}s.txt")
    open(rep, "w").write("\n".join(lines) + "\n")
    print("\n".join(lines))


if __name__ == "__main__":
    main()
