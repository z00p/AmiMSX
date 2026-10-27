"""Build AmiMSX4.diskdb: the machine for disk games (4.4 per-game defaults).

Disks have no SHA-1 database (openMSX's covers ROMs only), and a 720 KB image takes
seconds to hash on a 68020, so the key is what AmiMSX can work out at once as drive A
loads the image: the sum of its 16-bit big-endian words (29 bits, as CalCheckCart)
and its size in KB (720 or 360).

Sources: run/Disks with tests/titles.csv's machine: feature, and with --fh/--fhdir
File Hunter's MSXdev/Homebrew disk games (the WebMSX machine each page runs them on:
filehunter_map.tsv from the MiSTer curation tools, and the downloaded zips). Only
games for an MSX2 or later go in (MSX1 games keep the maintainer's machine). Where two
sources disagree, the later machine wins (a game for MSX2+ that also runs on an MSX2
gets the MSX2+).

File (big-endian): "AMXDD1",0,0, count.L, then 8-byte entries sorted by sum: sum.L,
KB.W, machine.B (1 MSX2, 2 MSX2+, 3 turbo R), 0.B.
Usage: python tools/make_diskdb.py [--out AmiMSX4.diskdb] [--copy run] [--fh map.tsv --fhdir dir]"""
import argparse, csv, os, struct, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_romdb import BASE, filehunter_files, titles_machine   # noqa: E402


def key(data):
    words = struct.unpack(f">{len(data) // 2}H", data[:len(data) // 2 * 2])
    return sum(words) & 0x1FFFFFFF, len(data) // 1024


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(BASE, "AmiMSX4.diskdb"))
    ap.add_argument("--copy", default=os.path.join(BASE, "run"))
    ap.add_argument("--fh", help="File Hunter map (filehunter_map.tsv)")
    ap.add_argument("--fhdir", help="folder with the File Hunter downloads")
    a = ap.parse_args()
    games = {}                               # (sum, KB) -> (machine, name)

    def add(name, data, mach):
        if len(data) not in (720 * 1024, 360 * 1024) or not mach:
            return
        k = key(data)
        if k not in games or mach > games[k][0]:
            games[k] = (mach, name)

    rows = list(csv.DictReader(open(os.path.join(BASE, "tests", "titles.csv"), encoding="utf-8")))
    ddir = os.path.join(BASE, "run", "Disks")
    for r in rows:
        p = os.path.join(ddir, r["file"])
        if r["kind"] == "disk" and os.path.isfile(p) and not r["file"].startswith("masktest"):
            add(r["file"], open(p, "rb").read(), titles_machine(r))
    nloc = len(games)
    if a.fh and a.fhdir:
        for name, data, mach in filehunter_files(a.fh, a.fhdir, ("DISKA_URL", "DISKB_URL")):
            add(name, data, mach)
    sums = {}
    for (s, kb) in games:
        sums.setdefault(s, set()).add(kb)
    with open(a.out, "wb") as fh:
        fh.write(b"AMXDD1\0\0" + struct.pack(">I", len(games)))
        for (s, kb), (mach, name) in sorted(games.items()):
            fh.write(struct.pack(">IHBB", s, kb, mach, 0))
    if a.copy and os.path.isdir(a.copy):
        import shutil
        shutil.copy(a.out, os.path.join(a.copy, os.path.basename(a.out)))
    mc = [0, 0, 0, 0]
    for mach, _ in games.values():
        mc[mach] += 1
    print(f"{a.out}: {len(games)} disks ({nloc} local); MSX2 {mc[1]}, MSX2+ {mc[2]}, turbo R {mc[3]}")
    for (s, kb), (mach, name) in sorted(games.items(), key=lambda x: x[1][1]):
        print(f"  {name}: {['', 'MSX2', 'MSX2+', 'turbo R'][mach]} ({s:08X}, {kb} KB)")


if __name__ == "__main__":
    main()
