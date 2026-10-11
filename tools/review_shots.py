"""Side-by-side screenshots for the review package: AmiMSX 4.0 next to openMSX,
from tools/burst.py output (first frame of each burst), with a caption.

Usage: python tools/review_shots.py <burst tag> <id> <seconds> "<caption>" [...]
       (each further title as another id seconds caption triple)
Writes build/review_shots/<n>_<id>.png."""
import os, sys
from PIL import Image, ImageDraw, ImageFont

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(BASE, "build", "review_shots")


def font(size):
    for f in ("segoeui.ttf", "arial.ttf"):
        try:
            return ImageFont.truetype(f, size)
        except OSError:
            pass
    return ImageFont.load_default()


def main():
    tag, args = sys.argv[1], sys.argv[2:]
    os.makedirs(OUT, exist_ok=True)
    for n, i in enumerate(range(0, len(args), 3), 1):
        rid, secs, cap = args[i], args[i + 1], args[i + 2]
        d = os.path.join(BASE, "build", "bursts", tag, rid, f"{secs}s")
        a = Image.open(os.path.join(d, "amimsx", "f00.png")).convert("RGB").resize((640, 472))
        o = Image.open(os.path.join(d, "omsx", "f00.png")).convert("RGB").resize((640, 480))
        img = Image.new("RGB", (1300, 560), (24, 24, 28))
        img.paste(a, (10, 70)); img.paste(o, (650, 66))
        dr = ImageDraw.Draw(img)
        dr.text((10, 10), cap, fill=(255, 255, 255), font=font(24))
        dr.text((10, 44), "AmiMSX 4.0 (WinUAE, 68030/50)", fill=(255, 200, 80), font=font(16))
        dr.text((650, 44), "openMSX (reference)", fill=(120, 200, 255), font=font(16))
        p = os.path.join(OUT, f"{n:02d}_{rid}.png")
        img.save(p)
        print(p)


if __name__ == "__main__":
    main()
