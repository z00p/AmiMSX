"""Contact sheet of film strips (winuae/strips.ps1 output): one row band per
strip, frames in time order, each labelled. WinUAE grabs are cropped to the
emulator picture; openMSX screenshots are used as they are.
Usage: python tools/strip_sheet.py out.png label=dir [label=dir ...] [--cols N] [--w 192]"""
import os, re, sys
from PIL import Image, ImageDraw


def frames(d):
    out = []
    for f in os.listdir(d):
        m = re.search(r"_(\d+)s\.png$", f)
        if m:
            out.append((int(m.group(1)), os.path.join(d, f)))
    return sorted(out)


def load(path, w, h):
    im = Image.open(path).convert("RGB")
    if im.size != (640, 480):            # WinUAE window grab: drop frame/status bar
        im = im.crop((8, 30, im.width - 8, im.height - 28))
    return im.resize((w, h))


def main():
    args = sys.argv[1:]
    cols, w = 6, 192
    if "--cols" in args:
        i = args.index("--cols"); cols = int(args[i + 1]); del args[i:i + 2]
    if "--w" in args:
        i = args.index("--w"); w = int(args[i + 1]); del args[i:i + 2]
    out, strips = args[0], [a.split("=", 1) for a in args[1:]]
    h, lab = w * 3 // 4, 13
    bands = []
    for label, d in strips:
        fr = frames(d)
        rows = (len(fr) + cols - 1) // cols
        bands.append((label, fr, rows))
    total = sum(r * (h + lab) + 4 for _, _, r in bands)
    sheet = Image.new("RGB", (cols * w, total), (30, 30, 30))
    dr = ImageDraw.Draw(sheet)
    y0 = 0
    for label, fr, rows in bands:
        for k, (t, p) in enumerate(fr):
            x, y = (k % cols) * w, y0 + (k // cols) * (h + lab)
            sheet.paste(load(p, w, h), (x, y + lab))
            dr.text((x + 3, y + 1), f"{label} {t}s", fill=(255, 255, 0))
        y0 += rows * (h + lab) + 4
    sheet.save(out)
    print(out, sheet.size)


if __name__ == "__main__":
    main()
