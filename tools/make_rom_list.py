"""Write run/Roms/roms.csv (file, title, developer, year) for the AmiMSX Tester's
game list (cartridges in run/Roms and disk images in run/Disks): from an MSX top-list (top_MSX1.tsv: $AMIMSX_TOPLIST or run/), a
table for the commercial and test ROMs, and blanks for the rest. Rows already
in roms.csv are kept as they are (hand edits win); new ROM files are added.
Usage: python tools/make_rom_list.py"""
import csv, os, re

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROMS = os.path.join(BASE, "run", "Roms")
OUT = os.path.join(ROMS, "roms.csv")
TOP = os.environ.get("AMIMSX_TOPLIST", os.path.join(BASE, "run", "top_MSX1.tsv"))

KNOWN = {   # file stem: (title, developer, year)
    "R2K_Galious": ("The Maze of Galious", "Konami", "1987"),
    "R2K_GaliousEnh": ("The Maze of Galious (Enhanced)", "Konami", "1987"),
    "R2K_Gradius2VC": ("Gradius 2", "Konami", "1987"),
    "R2K_KingsValley2": ("King's Valley II", "Konami", "1988"),
    "R2K_MetalGear": ("Metal Gear", "Konami", "1987"),
    "R2K_Nemesis2": ("Nemesis 2", "Konami", "1987"),
    "R2K_Nemesis3": ("Nemesis 3: The Eve of Destruction", "Konami", "1988"),
    "R2K_Nemesis3Enh": ("Nemesis 3 (Enhanced)", "Konami", "1988"),
    "R2K_Salamander": ("Salamander", "Konami", "1987"),
    "R2K_SalamanderEnh": ("Salamander (Enhanced)", "Konami", "1987"),
    "R2K_SpaceManbow": ("Space Manbow", "Konami", "1989"),
    "R2K_Usas": ("Usas", "Konami", "1987"),
    "R2K_UsasEnh": ("Usas (Enhanced)", "Konami", "1987"),
    "R2K_VampireKiller": ("Vampire Killer", "Konami", "1986"),
    "R2K_VampireKillerSCC": ("Vampire Killer (SCC)", "Konami", "1986"),
    "R2K_Zanac": ("Zanac", "Compile", "1986"),
    "R2K_ZanacEx": ("Zanac EX", "Compile", "1987"),
    "R2K_ZanacExEnh": ("Zanac EX (Enhanced)", "Compile", "1987"),
    "M_Ianna_A16": ("Sword of IANNA", "RetroWorks", "2020s"),
    "M_Lilly_A16": ("Lilly's Saga - The Stones of Evergreen", "(MSXdev22 team)", "2022"),
    "R2_DEVA": ("Angelic Warrior DEVA", "Team Deva", "2020s"),
    "R2_Delta[ASCII16]": ("Delta", "", ""),
    "R2_NeonRevMSX1[ASCII8]": ("Neon Revenant (MSX1)", "", ""),
    "R2_NeonRevMSX2[ASCII8]": ("Neon Revenant (MSX2)", "", ""),
    "R2_Popolon": ("Popolon", "", ""),
    "R2_Unleashed": ("MSX Unleashed (demo)", "", ""),
    # disk images (run/Disks)
    "020_GradiusIIILegends": ("Gradius III Legends", "Imanok", "2001"),
    "R2_akin1": ("Akin (disk 1)", "Parallax / UMAX (Sunrise)", "1995"),
    "R2_akin2": ("Akin (disk 2)", "Parallax / UMAX (Sunrise)", "1995"),
    "R2_bold": ("Bold (demo)", "", ""),
    "R2_invasion": ("Invasion of the Big Pixels (demo)", "Noice", "2008"),
    "R2_io": ("io (timing test)", "", ""),
}
DISKS = os.path.join(BASE, "run", "Disks")


def norm(s):
    return re.sub(r"[^a-z0-9]", "", s.lower())


def main():
    rows = {}
    if os.path.exists(OUT):
        for r in csv.DictReader(open(OUT, encoding="utf-8")):
            rows[r["file"]] = r
    top = {}
    if os.path.exists(TOP):
        for r in csv.reader(open(TOP, encoding="utf-8"), delimiter="\t"):
            if len(r) > 3:
                top[norm(r[1])] = (r[1], r[3], r[2])
    files = sorted(f for f in os.listdir(ROMS) if f.lower().endswith((".rom", ".mx1", ".mx2")))
    if os.path.isdir(DISKS):
        files += sorted(f for f in os.listdir(DISKS) if f.lower().endswith(".dsk"))
    added = 0
    for f in files:
        if f in rows:
            continue
        stem = os.path.splitext(f)[0]
        if stem in KNOWN:
            t, d, y = KNOWN[stem]
        elif stem.startswith("T_"):
            t, d, y = stem[2:] + " (AmiMSX test ROM)", "AmiMSX tests", "2026"
        else:
            core = re.sub(r"^(\d+_|M_|R2_)", "", stem)
            core = re.sub(r"_(A8|A16|Kon|SCC)$|\[.*\]", "", core)
            if f.lower().endswith(".dsk"):
                core = re.sub(r"^\d+_", "", core)
            n, m = norm(core), None
            for k, v in top.items():
                if len(n) >= 4 and (n == k or (len(n) >= 6 and (n in k or k in n))):
                    m = v
                    break
            t, d, y = m if m else (core, "", "")
        rows[f] = {"file": f, "title": t, "developer": d, "year": y}
        added += 1
    for f in list(rows):
        if f not in files:
            del rows[f]                       # ROM gone from the folder
    with open(OUT, "w", encoding="utf-8", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=["file", "title", "developer", "year"])
        w.writeheader()
        for f in sorted(rows):
            w.writerow(rows[f])
    print(f"{OUT}: {len(rows)} ROMs, {added} added")


if __name__ == "__main__":
    main()
