"""Build AmiMSX4.romdb: mapper by ROM SHA-1, for AmiMSX's cartridge auto-setup.

Source: openMSX's software database (tools/openmsx/share/softwaredb.xml),
MSX systems only, plus the local ROMs it doesn't know (run/Roms, mapper from
tests/titles.csv romtype or the file-name tag).

File format (big-endian):
  "AMXDB1",0,0          8 bytes
  count.L               entries
  entries, 8 bytes each, sorted by key (unsigned):
    key.L               first 4 bytes of the SHA-1
    code.B              AmiMSX mapper: 0 standard, 1 Konami, 2 ASCII8, 3 ASCII16,
                        4 Konami SCC (also its flash variants), $FE not emulated
    type.B              openMSX type number (TYPES list below; for messages)
    flags.B             bit 0: has SRAM, bit 1: flash; bits 2-3: machine (4.4: 0 MSX or
                        unknown, 1 MSX2, 2 MSX2+, 3 turbo R; the per-game defaults);
                        bits 4-5: SRAM size AmiMSX
                        emulates (1: 2 KB, 2: 8 KB), bit 6: ASCII16 (else ASCII8):
                        the ASCII8SRAM2/8 and ASCII16SRAM2/8 types (4.4)
    0.B
Only types that matter for MegaROMs are included (plain/mirrored 8-32 KB
ROMs are left to AmiMSX's size rules), and (4.4) plain ones for an MSX2 or
later machine, with code $FD (the size rules decide the mapper): the machine.
Machines: openMSX's <system>, and with --fh/--fhdir File Hunter's MSXdev/
Homebrew pages (the WebMSX machine each game's page runs it on;
filehunter_map.tsv from the MiSTer curation tools, and the downloaded files).
(tests/titles.csv's machine: feature is a guess from the coverage scan, so the
ROMs don't use it; make_diskdb.py does, for the disks, set by hand.)

Usage: python tools/make_romdb.py [--out AmiMSX4.romdb] [--copy run]
"""
import argparse, csv, hashlib, os, re, struct, sys
import xml.etree.ElementTree as ET

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB = os.path.join(BASE, "tools", "openmsx", "share", "softwaredb.xml")
MSX_SYSTEMS = {"MSX", "MSX2", "MSX2+", "MSX turbo R", "MSXturboR", "TURBO-R", ""}

CODES = {"Normal": 0, "Konami": 1, "GenericKonami": 1, "ASCII8": 2, "ASCII16": 3,
         "KonamiSCC": 4, "manbow2": 4, "Manbow2_2": 4, "KonamiUltimateCollection": 4,
         "RBSC_Flash_KonamiSCC": 4}
SRAM = re.compile(r"SRAM")
FLASH = {"manbow2", "Manbow2_2", "KonamiUltimateCollection", "RBSC_Flash_KonamiSCC"}
PLAIN = {"Mirrored", "page2", "page23", "page12", "page1", "page3", "16kb", "8kB", "Mirrored4000",
         "Mirrored0000", "Mirrored8000", "MirroredC000", "Normal0000", "Normal4000", "Normal8000"}
TAGS = {"konamiscc": "KonamiSCC", "scc": "KonamiSCC", "konami": "Konami", "konami4": "Konami",
        "ascii8": "ASCII8", "ascii16": "ASCII16", "ascii8sram2": "ASCII8SRAM2",
        "ascii8sram8": "ASCII8SRAM8", "ascii16sram2": "ASCII16SRAM2", "ascii16sram8": "ASCII16SRAM8"}


SYSTEMS = {"MSX": 0, "MSX2": 1, "MSX2+": 2, "MSX turbo R": 3, "MSXturboR": 3, "TURBO-R": 3, "": 0}
CODE_PLAIN = 0xFD


def webmsx_machine(code):
    """File Hunter's WMSX.MACHINE (MSX1E, MSX2A, MSX2PJ, MSXTRA...) -> 0-3, or None."""
    m = re.match(r"MSX(TR|2P|2|1)", code or "")
    return {"1": 0, "2": 1, "2P": 2, "TR": 3}[m.group(1)] if m else None


def titles_machine(row):
    m = re.search(r"machine:(MSX2\+|MSX2|MSX1)", (row or {}).get("features", ""))
    return {"MSX1": 0, "MSX2": 1, "MSX2+": 2}[m.group(1)] if m else None


def filehunter_files(mapfile, fhdir, kinds, cap=1):
    """(name, bytes, machine) for each File Hunter game file found in fhdir (zips as
    downloaded, or the files themselves). The machine is capped (default MSX2): it is
    the machine File Hunter's WebMSX page runs the game on, often a turbo R or an MSX2+
    for games that need no more than an MSX2 (Knight Lore Remake, Alien 8 Remake on a
    turbo R, Jailbreak on an MSX2+, Chikubi Ninja, an MSX1 game, on an MSX2+), so it is
    only trusted as "an MSX2 or later"."""
    import zipfile
    out = []
    for row in csv.DictReader(open(mapfile, encoding="utf-8"), delimiter="\t"):
        mach = webmsx_machine(row.get("machine"))
        if mach is None or row.get("kind") not in kinds:
            continue
        p = os.path.join(fhdir, os.path.basename(row["url"]))
        if not os.path.isfile(p):
            continue
        exts = (".rom", ".mx1", ".mx2") if "CARTRIDGE" in row["kind"] else (".dsk",)
        if p.lower().endswith(".zip"):
            with zipfile.ZipFile(p) as z:
                for n in z.namelist():
                    if n.lower().endswith(exts):
                        out.append((row["title"] + " / " + n, z.read(n), min(mach, cap)))
        elif p.lower().endswith(exts):
            out.append((row["title"], open(p, "rb").read(), min(mach, cap)))
    return out


def code_for(t):
    if t in CODES:
        return CODES[t]
    if t.startswith("ASCII8SRAM"):
        return 2
    if t.startswith("ASCII16SRAM"):
        return 3
    return 0xFE


def sram_bits(t):
    m = re.fullmatch(r"ASCII(8|16)SRAM(2|8)", t)
    if not m:
        return 0
    return ({"2": 1, "8": 2}[m.group(2)] << 4) | (0x40 if m.group(1) == "16" else 0)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(BASE, "AmiMSX4.romdb"))
    ap.add_argument("--copy", default=os.path.join(BASE, "run"))
    ap.add_argument("--tests", action="store_true", help="include run/Roms/T_* (test cartridges)")
    ap.add_argument("--fh", help="File Hunter map (filehunter_map.tsv)")
    ap.add_argument("--fhdir", help="folder with the File Hunter downloads")
    a = ap.parse_args()
    types, entries, titles = [], {}, {}
    root = ET.parse(DB).getroot()
    for sw in root.iter("software"):
        system = (sw.findtext("system") or "").strip()
        if system not in MSX_SYSTEMS:
            continue
        title = sw.findtext("title") or ""
        for dump in sw.iter("dump"):
            for rom in list(dump):
                if rom.tag not in ("rom", "megarom"):
                    continue
                t = (rom.findtext("type") or "Mirrored").strip()
                h = (rom.findtext("hash") or "").strip().lower()
                mach = SYSTEMS.get(system, 0)
                if not h or (t in PLAIN and mach == 0):
                    continue
                if t not in types:
                    types.append(t)
                entries[h] = [t, title, mach]
    known = len(entries)
    # local ROMs the database doesn't know
    rows = {r["file"]: r for r in csv.DictReader(open(os.path.join(BASE, "tests", "titles.csv"), encoding="utf-8"))}
    extra = []
    romdir = os.path.join(BASE, "run", "Roms")
    for f in sorted(os.listdir(romdir)):
        if not f.lower().endswith((".rom", ".mx1", ".mx2")) or (f.startswith("T_") and not a.tests):
            continue
        data = open(os.path.join(romdir, f), "rb").read()
        h = hashlib.sha1(data).hexdigest()
        if h in entries or len(data) <= 0x8000:
            continue
        t = (rows.get(f, {}).get("romtype") or "").strip()
        if not t:
            m = re.search(r"\[([A-Za-z0-9]+)\]", f)
            t = TAGS.get(m.group(1).lower(), "") if m else ""
        if not t:
            continue
        if t not in types:
            types.append(t)
        entries[h] = [t, f, 0]
        extra.append((f, t))
    nfh = 0
    if a.fh and a.fhdir:
        for name, data, mach in filehunter_files(a.fh, a.fhdir, ("CARTRIDGE1_URL", "CARTRIDGE2_URL")):
            h = hashlib.sha1(data).hexdigest()
            if h in entries:
                if mach > entries[h][2]:
                    entries[h][2] = mach; nfh += 1
            elif mach:
                if "Mirrored" not in types:
                    types.append("Mirrored")
                entries[h] = ["Mirrored", name, mach]; nfh += 1
    # pack
    out, keys = [], {}
    for h, (t, title, mach) in entries.items():
        key = int(h[:8], 16)
        flags = (1 if SRAM.search(t) or t.startswith("Koei") else 0) | (2 if t in FLASH else 0) | sram_bits(t)
        flags |= mach << 2
        code = CODE_PLAIN if t in PLAIN else code_for(t)
        rec = (key, code, types.index(t), flags)
        if key in keys and keys[key][1:] != rec[1:]:
            print(f"warning: key {key:08X} collides with different data ({title})", file=sys.stderr)
        keys[key] = rec
    recs = sorted(keys.values())
    with open(a.out, "wb") as fh:
        fh.write(b"AMXDB1\0\0" + struct.pack(">I", len(recs)))
        for key, code, ti, flags in recs:
            fh.write(struct.pack(">IBBBB", key, code, ti, flags, 0))
    if a.copy and os.path.isdir(a.copy):
        import shutil
        shutil.copy(a.out, os.path.join(a.copy, os.path.basename(a.out)))
    by = {}
    for _, code, _, _ in recs:
        by[code] = by.get(code, 0) + 1
    mc = [0, 0, 0, 0]
    for _, _, _, fl in recs:
        mc[fl >> 2 & 3] += 1
    print(f"machines: MSX/unknown {mc[0]}, MSX2 {mc[1]}, MSX2+ {mc[2]}, turbo R {mc[3]}; File Hunter {nfh}")
    print(f"{a.out}: {len(recs)} entries ({known} from openMSX, {len(extra)} local), "
          f"{os.path.getsize(a.out)} bytes; by code: " + ", ".join(f"{k}: {v}" for k, v in sorted(by.items())))
    for f, t in extra:
        print(f"  local: {f} = {t}")
    with open(os.path.join(BASE, "Docs", "romdb_types.txt"), "w") as fh:
        for i, t in enumerate(types):
            fh.write(f"{i}\t{t}\t{CODE_PLAIN if t in PLAIN else code_for(t)}\n")


if __name__ == "__main__":
    main()
