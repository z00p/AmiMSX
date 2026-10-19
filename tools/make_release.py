"""Stage the AmiMSX 4.0 release drawer and build the Aminet LHA (the LhA step
runs inside WinUAE, see winuae/make_lha.ps1).

Usage: python tools/make_release.py [build/AmiMSX] [release/AmiMSX4]
Output: <out>/AmiMSX/ (the drawer) + <out>/AmiMSX.info (its icon) and
<out>/AmiMSX4.readme. Icons: the presets' (make_presets.py), a tool icon for
AmiMSX and a drawer icon drawn the same way; the guide and keyboard picture
keep the icons of the original 3.1 package (AmiMSX_asm.lha)."""
import os, re, shutil, struct, subprocess, sys, textwrap
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_presets as mp

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def tool_icon(im):
    o = bytearray(mp.diskobject(im, "", []))
    o[48] = 3                                   # WBTOOL
    struct.pack_into(">I", o, 50, 0)            # no default tool
    struct.pack_into(">I", o, 54, 0)            # no tooltypes
    head, rest = bytes(o[:78]), o[78:]
    planar = mp.planar(im)
    return head + planar + mp.glow(im)


def drawer_icon(im, w=420, h=200):
    o = bytearray(mp.diskobject(im, "", []))
    o[48] = 2                                   # WBDRAWER
    struct.pack_into(">I", o, 50, 0)
    struct.pack_into(">I", o, 54, 0)
    struct.pack_into(">I", o, 66, 1)            # do_DrawerData present
    head = bytes(o[:78])
    nw = struct.pack(">hhhhBBIIIIIIIhhHHH", 60, 40, w, h, 255, 255, 0, 0, 0, 0, 0, 0, 0, 90, 40, 0xFFFF, 0xFFFF, 1)
    dd = nw + struct.pack(">ii", 0, 0)
    assert len(dd) == 56, len(dd)
    dd2 = struct.pack(">IH", 0, 0)              # OS 2+: dd_Flags (default), dd_ViewModes
    return head + dd + mp.planar(im) + dd2 + mp.glow(im)


def amiga_text(src, dst, wrap=0):
    """Copy a text file for the Amiga: LF line ends, Latin-1 (UTF-8 sources
    are converted; typographic quotes and dashes become ASCII)."""
    d = open(src, "rb").read()
    try:
        t = d.decode("utf-8")
    except UnicodeDecodeError:
        t = d.decode("latin-1")
    for a, b in {"‘": "'", "’": "'", "“": '"', "”": '"', "–": "-",
                 "—": "-", "…": "...", "→": "->", " ": " "}.items():
        t = t.replace(a, b)
    t = t.replace("\r\n", "\n").replace("\r", "\n")
    if wrap:   # long Markdown lines, wrapped with the list indent kept
        out = []
        for line in t.split("\n"):
            ind = " " * len(re.match(r"\s*(?:[-*] |\d+\. )?", line).group(0))
            out += textwrap.wrap(line, wrap, subsequent_indent=ind, break_long_words=False,
                                 break_on_hyphens=False) or [""]
        t = "\n".join(out)
    open(dst, "wb").write(t.encode("latin-1"))


FONT35 = {'M': '10001/11011/10101/10001/10001', 'S': '011100010001110', 'X': '101101010101101',
          'D': '110101101101110', 'O': '010101101101010', 'C': '011100100100011'}


def text35(d, x, y, t, col):
    for ch in t:
        g = FONT35[ch]
        rows = g.split('/') if '/' in g else [g[k:k + 3] for k in range(0, 15, 3)]
        for ry, row in enumerate(rows):
            for rx, bit in enumerate(row):
                if bit == '1':
                    d.point((x + rx, y + ry), fill=col)
        x += len(rows[0]) + 1


def draw_drawer(label=None):
    """An Amiga-style drawer, our own drawing in the shape of the Workbench
    3.x drawers: a lid that slopes out to the front panel, both dithered blue,
    a white handle near the bottom, a dark outline and drop shadow; optional
    label plate on the lid."""
    from PIL import Image, ImageDraw
    W, H = mp.W, mp.H
    im = Image.new("RGB", (W, H), (255, 0, 255))
    d = ImageDraw.Draw(im)
    out, base, lite, dark, shade = (24, 32, 56), (66, 106, 172), (104, 144, 206), (40, 66, 124), (60, 60, 70)
    top, mid, bot = 11, 25, 39
    def lid_x(y):                       # lid sides slope from x 10..36 to 6..40
        t = (y - top) / (mid - top)
        return round(10 - 4 * t), round(36 + 4 * t)
    for y in range(top, mid):           # lid
        a, b = lid_x(y)
        for x in range(a, b + 1):
            d.point((x, y), fill=lite if (x + y) % 2 == 0 and y < mid - 3 else base)
        d.point((a, y), fill=out); d.point((b, y), fill=out)
        d.point((b + 1, y + 1), fill=shade)
    d.line([12, top, 34, top], fill=out)
    d.point((11, top + 1), fill=out); d.point((35, top + 1), fill=out)
    d.line([7, mid - 1, 39, mid - 1], fill=(150, 180, 226))               # lid's front edge
    d.rectangle([6, mid, 40, bot], fill=base, outline=out)                # front panel
    for y in range(mid + 1, mid + 5):
        for x in range(7, 40):
            if (x + y) % 2 == 0:
                d.point((x, y), fill=lite)
    d.line([39, mid + 1, 39, bot - 1], fill=dark)
    d.line([7, bot - 1, 39, bot - 1], fill=dark)
    d.line([41, mid + 1, 41, bot + 1], fill=shade); d.line([7, bot + 1, 41, bot + 1], fill=shade)
    d.rounded_rectangle([15, bot - 7, 31, bot - 3], radius=2, fill=(240, 240, 240), outline=out)   # handle
    d.line([17, bot - 4, 29, bot - 4], fill=(150, 150, 160))
    if label:
        w = sum((5 if c == 'M' else 3) + 1 for c in label) - 1 + 4
        lx = (6 + 40 - w) // 2 + 1
        d.rectangle([lx, mid - 9, lx + w - 1, mid - 1], fill=(255, 255, 255), outline=out)
        text35(d, lx + 2, mid - 7, label, (40, 70, 160))
    return im


def main():
    binary = sys.argv[1] if len(sys.argv) > 1 else os.path.join(BASE, "build", "AmiMSX")
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(BASE, "release", "AmiMSX4")
    if os.path.exists(out):
        shutil.rmtree(out)
    d = os.path.join(out, "AmiMSX")
    os.makedirs(os.path.join(d, "Docs"))
    subprocess.run([sys.executable, os.path.join(BASE, "tools", "make_presets.py"), binary, d], check=True)
    os.remove(os.path.join(d, "presets.png"))
    shutil.copy(binary, os.path.join(d, "AmiMSX"))
    for f in ("AmiMSX2.data", "AmiMSX2.mapper", "AmiMSX4.romdb"):
        shutil.copy(os.path.join(BASE, f), os.path.join(d, f))
    amiga_text(os.path.join(BASE, "Docs", "AmiMSX.guide"), os.path.join(d, "AmiMSX.guide"))
    amiga_text(os.path.join(BASE, "Docs", "CHANGES_4.x.md"), os.path.join(d, "Docs", "CHANGES_4.x.txt"), wrap=76)
    amiga_text(os.path.join(BASE, "Docs", "AmiMSX4.readme"), os.path.join(d, "AmiMSX4.readme"))
    amiga_text(os.path.join(BASE, "Docs", "AmiMSX4.readme"), os.path.join(out, "AmiMSX4.readme"))
    amiga_text(os.path.join(BASE, "Docs", "LICENSE.emu2413"), os.path.join(d, "Docs", "LICENSE.emu2413"))
    shutil.copy(os.path.join(BASE, "Pics", "Keyboard.Iff"), os.path.join(d, "Docs", "Keyboard.Iff"))
    shutil.copy(os.path.join(BASE, "Pics", "Keyboard.Iff.info"), os.path.join(d, "Docs", "Keyboard.Iff.info"))
    lhasa = os.environ.get("LHASA")
    if lhasa:   # the guide's icon from the original 3.1 package
        tmp = os.path.join(out, "_orig")
        os.makedirs(tmp)
        subprocess.run([lhasa, "xq", os.path.join(BASE, "AmiMSX_asm.lha"), "AmiMSX/Docs/AmiMSX.guide.info"],
                       cwd=tmp, check=True)
        shutil.copy(os.path.join(tmp, "AmiMSX", "Docs", "AmiMSX.guide.info"), os.path.join(d, "AmiMSX.guide.info"))
        shutil.rmtree(tmp)
    shutil.copy(os.path.join(BASE, "Pics", "AmiMSX.info"), os.path.join(d, "AmiMSX.info"))   # the 3.x tool icon
    shutil.copy(os.path.join(BASE, "Pics", "Drawer_AmiMSX.info"), os.path.join(out, "AmiMSX.info"))   # OS 3.2 drawer, MSX emblem
    shutil.copy(os.path.join(BASE, "Pics", "Drawer_Docs.info"), os.path.join(d, "Docs.info"))         # OS 3.2 drawer
    mvd = os.path.join(BASE, "release", "assets", "mvd_files")   # the MVD disks of the 3.x package
    if os.path.isdir(mvd):                                        # (not in git: release/ is ignored)
        shutil.copytree(mvd, os.path.join(d, "MVD_Files"))
        shutil.copy(os.path.join(BASE, "Pics", "Drawer_Docs.info"), os.path.join(d, "MVD_Files.info"))
    for root, _, files in os.walk(out):
        for f in sorted(files):
            p = os.path.join(root, f)
            print(f"{os.path.getsize(p):9d}  {os.path.relpath(p, out)}")


if __name__ == "__main__":
    main()
