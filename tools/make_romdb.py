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
    flags.B             bit 0: has SRAM (not emulated), bit 1: flash
    0.B
Only types that matter for MegaROMs are included (plain/mirrored 8-32 KB
ROMs are left to AmiMSX's size rules).

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
        "ascii8": "ASCII8", "ascii16": "ASCII16"}


def code_for(t):
    if t in CODES:
        return CODES[t]
    if t.startswith("ASCII8SRAM"):
        return 2
    if t.startswith("ASCII16SRAM"):
        return 3
    return 0xFE


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(BASE, "AmiMSX4.romdb"))
    ap.add_argument("--copy", default=os.path.join(BASE, "run"))
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
                if not h or t in PLAIN:
                    continue
                if t not in types:
                    types.append(t)
                entries[h] = (t, title)
    known = len(entries)
    # local ROMs the database doesn't know
    rows = {r["file"]: r for r in csv.DictReader(open(os.path.join(BASE, "tests", "titles.csv"), encoding="utf-8"))}
    extra = []
    romdir = os.path.join(BASE, "run", "Roms")
    for f in sorted(os.listdir(romdir)):
        if not f.lower().endswith((".rom", ".mx1", ".mx2")):
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
        entries[h] = (t, f)
        extra.append((f, t))
    # pack
    out, keys = [], {}
    for h, (t, title) in entries.items():
        key = int(h[:8], 16)
        flags = (1 if SRAM.search(t) or t.startswith("Koei") else 0) | (2 if t in FLASH else 0)
        rec = (key, code_for(t), types.index(t), flags)
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
    print(f"{a.out}: {len(recs)} entries ({known} from openMSX, {len(extra)} local), "
          f"{os.path.getsize(a.out)} bytes; by code: " + ", ".join(f"{k}: {v}" for k, v in sorted(by.items())))
    for f, t in extra:
        print(f"  local: {f} = {t}")
    with open(os.path.splitext(a.out)[0] + "_types.txt", "w") as fh:
        for i, t in enumerate(types):
            fh.write(f"{i}\t{t}\t{code_for(t)}\n")


if __name__ == "__main__":
    main()
