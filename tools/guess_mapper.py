"""openMSX RomFactory::guessRomType port (MegaROM part), for checking ROM folders.
Usage: python tools/guess_mapper.py <folder>"""
import sys, os, re

AMIMSX = {"KONAMI": "Konami 2", "KONAMI_SCC": "SCC 1", "ASCII8": "ASCII 1",
          "ASCII16": "ASCII 2", "GENERIC_8KB": "(none: SCC 1 default)"}

def guess(d):
    # openMSX RomType enum order (ties go to the later type)
    g = dict.fromkeys(["ASCII8", "ASCII16", "GENERIC_8KB", "KONAMI", "KONAMI_SCC"], 0)
    for i in range(len(d) - 3):
        if d[i] == 0x32:
            v = d[i + 1] | d[i + 2] << 8
            if v in (0x5000, 0x9000, 0xB000): g["KONAMI_SCC"] += 1
            elif v in (0x4000, 0x8000, 0xA000): g["KONAMI"] += 1
            elif v in (0x6800, 0x7800): g["ASCII8"] += 1
            elif v == 0x6000: g["KONAMI"] += 1; g["ASCII8"] += 1; g["ASCII16"] += 1
            elif v == 0x7000: g["KONAMI_SCC"] += 1; g["ASCII8"] += 1; g["ASCII16"] += 1
            elif v == 0x77FF: g["ASCII16"] += 1
    if g["ASCII8"]: g["ASCII8"] -= 1
    best = "GENERIC_8KB"
    for k, v in g.items():
        if v and v >= g[best]: best = k
    return best, g

if __name__ == "__main__":
    for dp, _, fs in os.walk(sys.argv[1]):
        for f in sorted(fs):
            if not f.lower().endswith(".rom"): continue
            d = open(os.path.join(dp, f), "rb").read()
            if len(d) <= 0x10000 and not (len(d) == 0x10000 and d[:2] == b"AB"): continue
            best, g = guess(d)
            tag = re.search(r"\[(ASCII8|ASCII16|Konami(?:SCC)?)\]", f)
            print(f"{len(d)//1024:>5}K {best:<11} -> {AMIMSX[best]:<22} tag={tag.group(1) if tag else '-':<9} {f[:55]}")
