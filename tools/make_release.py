"""Stage the AmiMSX 4.0 release drawer and build the Aminet LHA (the LhA step
runs inside WinUAE, see winuae/make_lha.ps1).

Usage: python tools/make_release.py [build/AmiMSX] [release/AmiMSX4]
Output: <out>/AmiMSX/ (the drawer) + <out>/AmiMSX.info (its icon) and
<out>/AmiMSX4.readme. Icons: the presets' (make_presets.py), a tool icon for
AmiMSX and a drawer icon drawn the same way; the guide and keyboard picture
keep the icons of the original 3.1 package (AmiMSX_asm.lha)."""
import os, shutil, struct, subprocess, sys
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


def amiga_text(src, dst):
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
    open(dst, "wb").write(t.encode("latin-1"))


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
    amiga_text(os.path.join(BASE, "Docs", "CHANGES_4.0.md"), os.path.join(d, "Docs", "CHANGES_4.0.txt"))
    amiga_text(os.path.join(BASE, "Docs", "AmiMSX4.readme"), os.path.join(d, "AmiMSX4.readme"))
    amiga_text(os.path.join(BASE, "Docs", "AmiMSX4.readme"), os.path.join(out, "AmiMSX4.readme"))
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
    im = mp.draw("4.0", (40, 70, 160))
    open(os.path.join(d, "AmiMSX.info"), "wb").write(tool_icon(im))
    open(os.path.join(out, "AmiMSX.info"), "wb").write(drawer_icon(mp.draw("MSX", (40, 70, 160))))
    open(os.path.join(d, "Docs.info"), "wb").write(drawer_icon(mp.draw("Doc", (90, 90, 90)), 300, 120))
    for root, _, files in os.walk(out):
        for f in sorted(files):
            p = os.path.join(root, f)
            print(f"{os.path.getsize(p):9d}  {os.path.relpath(p, out)}")


if __name__ == "__main__":
    main()
