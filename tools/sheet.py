"""Contact sheet of a folder of timed captures (<name>_<t>s.png), in time order.
Usage: python tools/sheet.py <folder> <out.png> [cols] [scale]"""
import glob, os, sys
from PIL import Image, ImageDraw


def t_of(f):
    return float(os.path.basename(f).rsplit("_", 1)[-1][:-5])


def main():
    folder, out = sys.argv[1], sys.argv[2]
    cols = int(sys.argv[3]) if len(sys.argv) > 3 else 5
    sc = float(sys.argv[4]) if len(sys.argv) > 4 else 0.4
    fs = sorted(glob.glob(os.path.join(folder, "*.png")), key=t_of)
    w, h = Image.open(fs[0]).size
    tw, th = int(w * sc), int(h * sc)
    rows = (len(fs) + cols - 1) // cols
    sheet = Image.new("RGB", (tw * cols, (th + 14) * rows), (30, 30, 30))
    d = ImageDraw.Draw(sheet)
    for k, f in enumerate(fs):
        c, r = k % cols, k // cols
        sheet.paste(Image.open(f).convert("RGB").resize((tw, th)), (c * tw, r * (th + 14) + 14))
        d.text((c * tw + 2, r * (th + 14)), "%gs" % t_of(f), fill=(255, 255, 0))
    sheet.save(out)
    print(out, len(fs), "frames")


if __name__ == "__main__":
    main()
