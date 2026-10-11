"""Key scripts for test runs: one text file drives AmiMSX (binary records for
its CLI key-script hook, see KeyScrRun) and openMSX (a Tcl script).

Text format, one action per line ('#' starts a comment):
    <time> <KEY>[+KEY...] [hold] [every <period> [until <time>]]
    include <file>              (another .keys file, relative to this one)
    option sprites <n>          (AmiMSX sprite frames for the run: 1 = every frame)
Times and lengths are MSX frames (50 Hz) or seconds with an 's' suffix,
counted from power on. Hold defaults to 5 frames.
SNAP [freeze] marks a snapshot (AmiMSX holds the frame with the power LED on;
openMSX takes a screenshot there).
Keys: SPACE LEFT RIGHT UP DOWN RETURN (ENTER) ESC TAB BS SELECT STOP HOME
INS DEL SHIFT CTRL GRAPH CAPS CODE F1-F5, 0-9, A-Z, and - ^ \\ @ [ ; : ] , . /

Usage:
    python tools/keyscript.py in.keys --amimsx out.key [--tcl out.tcl --shots-prefix C:/x/y --shots 20,30]
"""
import argparse, os, re, struct, sys

ROWS = [
    "0 1 2 3 4 5 6 7",
    "8 9 - ^ \\ @ [ ;",
    ": ] , . / _ A B",
    "C D E F G H I J",
    "K L M N O P Q R",
    "S T U V W X Y Z",
    "SHIFT CTRL GRAPH CAPS CODE F1 F2 F3",
    "F4 F5 ESC TAB STOP BS SELECT RETURN",
    "SPACE HOME INS DEL LEFT UP DOWN RIGHT",
]
KEYS = {}
for r, line in enumerate(ROWS):
    for b, k in enumerate(line.split()):
        KEYS[k] = (r, 1 << b)
KEYS["ENTER"] = KEYS["RETURN"]
KEYS["SNAP"] = (0xFF, 0)          # snapshot marker (hold = freeze, Amiga frames)
FPS = 50
MAXREC = 256


def frames(tok):
    tok = tok.strip().lower()
    if tok.endswith("s"):
        return int(round(float(tok[:-1]) * FPS))
    return int(tok)


def parse(path, seen=None):
    seen = seen or set()
    path = os.path.abspath(path)
    if path in seen:
        raise SystemExit(f"include loop: {path}")
    seen.add(path)
    out = []
    for n, raw in enumerate(open(path, encoding="utf-8"), 1):
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        t = line.split()
        if t[0].lower() == "option":
            opts = {"sprites": 1, "collisions": 2, "mask": 3}   # sprites <n>: sprite frames (1 = every frame); mask 1: edges
            out.append((0, 0xFE, opts[t[1].lower()], int(t[2])))
            continue
        if t[0].lower() == "include":
            out += parse(os.path.join(os.path.dirname(path), t[1]), seen)
            continue
        try:
            start = frames(t[0])
            keys = [KEYS[k.upper()] for k in t[1].split("+")]
        except (KeyError, ValueError, IndexError):
            raise SystemExit(f"{path}:{n}: bad line: {raw.rstrip()}")
        hold, every, until = (300 if t[1].upper() == "SNAP" else 5), None, None
        i = 2
        if i < len(t) and t[i].lower() != "every":
            hold = frames(t[i]); i += 1
        if i < len(t) and t[i].lower() == "every":
            every = frames(t[i + 1]); i += 2
            if i < len(t) and t[i].lower() == "until":
                until = frames(t[i + 1]); i += 2
            else:
                raise SystemExit(f"{path}:{n}: 'every' needs 'until'")
        times = [start] if every is None else list(range(start, until + 1, every))
        for f in times:
            for row, mask in keys:
                out.append((f, row, mask, hold))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("script")
    ap.add_argument("--amimsx")
    ap.add_argument("--tcl")
    ap.add_argument("--shots", default="")
    ap.add_argument("--shots-prefix", default="")
    ap.add_argument("--exit", type=float, default=0)
    ap.add_argument("--snaps", help="write the SNAP labels (one per line, in order)")
    a = ap.parse_args()
    recs = sorted(parse(a.script))
    if len(recs) > MAXREC:
        raise SystemExit(f"{len(recs)} records: AmiMSX takes {MAXREC}")
    if a.amimsx:
        with open(a.amimsx, "wb") as f:
            for fr, row, mask, hold in recs:
                f.write(struct.pack(">IBBH", fr, row, mask, hold))
            f.write(struct.pack(">i", -1))
    snaps = [fr for fr, row, mask, hold in recs if row == 0xFF]
    if a.snaps:
        with open(a.snaps, "w") as f:
            for fr in snaps:
                f.write(f"{fr / FPS:g}s\n")
    if a.tcl:
        with open(a.tcl, "w", encoding="ascii") as f:
            f.write("set maxframeskip 0\n")
            for fr, row, mask, hold in recs:
                if row == 0xFE:
                    continue
                if row == 0xFF:
                    f.write(f'after time {fr / FPS:.3f} {{screenshot {{{a.shots_prefix}_{fr / FPS:g}s.png}}}}\n')
                    continue
                f.write(f"after time {fr / FPS:.3f} {{keymatrixdown {row} 0x{mask:02X}}}\n")
                f.write(f"after time {(fr + hold) / FPS:.3f} {{keymatrixup {row} 0x{mask:02X}}}\n")
            shots = [float(x) for x in a.shots.split(",") if x]
            for s in shots:
                f.write(f'after time {s} {{screenshot {{{a.shots_prefix}_{s:g}s.png}}}}\n')
            end = a.exit or (max(shots + [fr / FPS for fr in snaps]) + 1 if (shots or snaps) else 0)
            if end:
                f.write(f"after time {end} exit\n")
            f.write("set throttle off\n")
    print(f"{len(recs)} key records" + (f" -> {a.amimsx}" if a.amimsx else "") + (f", {a.tcl}" if a.tcl else ""))


if __name__ == "__main__":
    main()
