"""Make the AmiMSX 4.0 preset projects: a prefs file per target machine, each
with a Workbench project icon whose default tool is AmiMSX and whose ToolType
PREFS=<own name> makes AmiMSX load (and save) that file instead of
S:AmiMSX2.prefs (WBToolTypes in AmiMSX_Menu_v3.1.asm).

The prefs defaults are taken from the built binary (the DIRPrefs block, from
"MSX2v2.5" to the end of the credits string); only the preset fields change.

Usage: python tools/make_presets.py [build/AmiMSX] [out_dir]   (default release/stage)
       [--tool AmiMSX:AmiMSX] [--tooltype DONOTWAIT] [--only "AmiMSX 030"]
Writes <out>/AmiMSX <name> + .info for each preset and <out>/presets.png (preview).
--tool, --tooltype (repeatable) and --only make test copies (winuae/wb_preset_test.ps1)."""
import argparse, os, struct, sys
from PIL import Image, ImageDraw, ImageFont

# Prefs offsets (DIRPrefs in AmiMSX_Menu_v3.1.asm)
SPRITES = 0x16      # word: 0 = Amiga sprites (ECS), 1 = every frame, 2 = every 2nd frame, 3 = every 3rd
FREQ = 0x11         # byte: Display Hz gadget: 0 Auto (was From VDP, Follow MSX; R#9: 60 Hz games get an NTSC
                    # display, at full speed), 1 No Change (stay PAL), 2 NTSC, 3 PAL. Auto
                    # costs 20% more emulation per second for 60 Hz games: PiStorm only.
JAPAN = 0x7A        # byte: Emulation > Japanese Machine (60 Hz): FFh = Japanese BIOS ID, 60 Hz boot (the machines
                    # most games were written for). PiStorm only: 20% more emulation per second.
SOUND = 0x1D        # byte: sound chip: 0 PSG, 1 SCC, 2 SCC+, 3 PSG+FM (MSX-Music by FMX; Konami SCC
                    # ROMs still get the SCC). FM is on only where there's CPU to spare.
COLLIDE = 0x6C      # byte: the original "Sprites collisions ON (always)" hack: FFh makes every S#0
                    # read report a collision (IVDP0Spr). Real collision detection always runs. Keep 0.
# 4.0 block after the credits string (PrefMask, PrefFilter, PrefDbuf, PrefMaskNoAuto,
# then 4.1.1's PrefCD32, PrefCD32M; AmiMSX_Menu_v3.1.asm, DIRPrefs). 6 bytes, as in 4.0-4.1.
# Offsets count from the end of the block.
MASK = -6           # byte (from the end): PrefMask, mask screen edges: dots hidden each side,
                    # 0 (Off), 8 or 16 (4.2; 4.0-4.1 wrote FFh = 8). Off in every preset.
NOAUTO = -3         # byte (from the end): 4.0-4.1's Auto mask (PrefMaskNoAuto): unused since
                    # 4.2 (no automatic masking); written 0.
CD32_PORT1 = -1     # byte (from the end): CD32 pad in the mouse port (Amiga port 1), FFh.
CD32_PORT2 = -2     # byte (from the end): CD32 pad in the joystick port (Amiga port 2), FFh.
                    # Both left 0 (Standard, the plain two-button read) in every preset.
DBUF = -4           # byte (from the end): smooth display (SCREEN 4 double-buffered, fast CPUs)
FILTER = -5         # byte (from the end): audio filter (Amiga low-pass, the power LED bit),
                    # FFh = on while a game runs: less hiss from the 8-bit FM/PSG output.
BLOCK40 = 6         # bytes after the credits string (PrefMask .. PrefCD32M)

PRESETS = [   # file name, badge text, badge colour, {offset: (format, value)}
    ("AmiMSX 030",     "030",  (40, 150, 60),  {SPRITES: (">H", 1), COLLIDE: ("B", 0), SOUND: ("B", 0), FREQ: ("B", 1), MASK: ("B", 0), NOAUTO: ("B", 0)}),
    ("AmiMSX PiStorm", "Pi AGA", (200, 40, 60),  {SPRITES: (">H", 1), COLLIDE: ("B", 0), SOUND: ("B", 3), FREQ: ("B", 0), FILTER: ("B", 0xFF), DBUF: ("B", 0xFF), JAPAN: ("B", 0xFF), MASK: ("B", 0), NOAUTO: ("B", 0)}),
    ("AmiMSX RTG",     "RTG",  (30, 100, 200),  {SPRITES: (">H", 1), COLLIDE: ("B", 0), SOUND: ("B", 3), FREQ: ("B", 0), FILTER: ("B", 0xFF), DBUF: ("B", 0xFF), JAPAN: ("B", 0xFF), MASK: ("B", 0), NOAUTO: ("B", 0)}),
]
# (4.5) Extra ToolTypes: the RTG preset is the PiStorm one on an RTG screen (ToolType RTG,
# WBToolTypes; the picture through Picasso96, the menu too).
TOOLTYPES = {"AmiMSX RTG": ["RTG", "SCANLINES=50"]}

W, H = 46, 46
# Classic (planar) image uses the 4 Workbench pens: grey, black, white, blue.
PENS = [(170, 170, 170), (0, 0, 0), (255, 255, 255), (102, 136, 187)]


def default_prefs(binary):
    b = open(binary, "rb").read()
    i = b.find(b"MSX2v2.5")
    assert i >= 0, "no prefs block in " + binary
    j = b.find(b")*- ", i)
    assert 0 < j - i < 0x1000
    end = j + 4
    end += (-(end - i)) % 4      # CNOP 0,4 (DIRPrefs is 8-aligned)
    end += BLOCK40               # 4.0/4.1.1 block up to FINPREFS
    return bytearray(b[i:end])


def draw(badge, colour):
    """A cartridge with "MSX" on its label and a coloured preset badge."""
    im = Image.new("RGB", (W, H), (255, 0, 255))
    d = ImageDraw.Draw(im)
    d.fontmode = "1"
    body, dark, light = (60, 60, 70), (30, 30, 36), (110, 110, 125)
    d.rectangle([6, 4, 39, 35], fill=body)                 # cartridge shell
    d.line([6, 4, 39, 4], fill=light); d.line([6, 4, 6, 35], fill=light)
    d.line([39, 5, 39, 35], fill=dark); d.line([7, 35, 39, 35], fill=dark)
    for x in range(10, 36, 3):                             # edge connector
        d.rectangle([x, 36, x + 1, 39], fill=(200, 170, 60))
    d.rectangle([10, 8, 35, 22], fill=(235, 235, 235))     # label
    d.rectangle([10, 8, 35, 10], fill=(40, 70, 160))
    font = ImageFont.load_default()
    d.text((12, 11), "MSX", font=font, fill=(20, 20, 20))
    bw = int(d.textlength(badge, font=font)) + 6           # badge, bottom right
    x0, y0 = W - bw - 1, 26
    d.rectangle([x0, y0, W - 2, y0 + 13], fill=colour, outline=(0, 0, 0))
    d.text((x0 + 3, y0 + 1), badge, font=font, fill=(255, 255, 255))
    return im


def planar(im):
    """2-bitplane Image for the classic icon (nearest Workbench pen; magenta = pen 0)."""
    rows = (W + 15) // 16 * 2
    planes = [bytearray(rows * H) for _ in range(2)]
    px = im.load()
    for y in range(H):
        for x in range(W):
            c = px[x, y]
            pen = 0 if c == (255, 0, 255) else min(range(4), key=lambda k: sum((a - b) ** 2 for a, b in zip(c, PENS[k])))
            for p in range(2):
                if pen >> p & 1:
                    planes[p][y * rows + x // 8] |= 0x80 >> (x & 7)
    img = struct.pack(">hhhhhIBBI", 0, 0, W, H, 2, 1, 3, 0, 0)
    return img + bytes(planes[0]) + bytes(planes[1])


def glow(im):
    """ColorIcon FORM ICON (FACE + one uncompressed IMAG), pen 0 transparent."""
    q = im.convert("P", palette=Image.ADAPTIVE, colors=63)
    pal = q.getpalette()[:63 * 3]
    src = im.load()
    trans = 0
    pixels = bytearray()
    qp = q.load()
    for y in range(H):
        for x in range(W):
            pixels.append(trans if src[x, y] == (255, 0, 255) else qp[x, y] + 1)
    palette = bytes([0, 0, 0]) + bytes(pal)
    ncol = len(palette) // 3

    def chunk(tag, data):
        return tag + struct.pack(">I", len(data)) + data + (b"\0" if len(data) & 1 else b"")
    face = struct.pack(">BBBBH", W - 1, H - 1, 1, 0x11, len(palette) - 1)   # frameless
    imag = struct.pack(">BBBBBBHH", trans, ncol - 1, 3, 0, 0, 8, len(pixels) - 1, len(palette) - 1)
    form = b"ICON" + chunk(b"FACE", face) + chunk(b"IMAG", imag + bytes(pixels) + palette)
    return b"FORM" + struct.pack(">I", len(form)) + form


def string(s):
    s = s.encode("latin-1") + b"\0"
    return struct.pack(">I", len(s)) + s


def diskobject(im, tool, tooltypes, stack=16384):
    gadget = struct.pack(">IhhhhHHHIIIIIHI",
                         0, 0, 0, W, H + 1, 4, 3, 1,   # GADGIMAGE, complement highlight; RELVERIFY|GADGIMMEDIATE; BOOLGADGET
                         1, 0, 0, 0, 0, 0, 1)          # GadgetRender only; UserData 1 = OS 2+ icon
    head = struct.pack(">HH", 0xE310, 1) + gadget + struct.pack(">BBIIiiIII",
                         4, 0, 1, 1,                   # WBPROJECT, DefaultTool, ToolTypes present
                         -0x80000000, -0x80000000,     # NO_ICON_POSITION
                         0, 0, stack)
    assert len(head) == 78, len(head)
    tt = struct.pack(">I", (len(tooltypes) + 1) * 4) + b"".join(string(t) for t in tooltypes)
    return head + planar(im) + string(tool) + tt + glow(im)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("binary", nargs="?", default="build/AmiMSX")
    ap.add_argument("out", nargs="?", default="release/stage")
    ap.add_argument("--tool", default="AmiMSX")
    ap.add_argument("--tooltype", action="append", default=[])
    ap.add_argument("--only")
    a = ap.parse_args()
    binary, out = a.binary, a.out
    os.makedirs(out, exist_ok=True)
    base = default_prefs(binary)
    print(f"default prefs: {len(base)} bytes, sprites {struct.unpack('>H', base[SPRITES:SPRITES + 2])[0]}, collisions {base[COLLIDE]:02X}")
    sheet = Image.new("RGB", (len(PRESETS) * 120, 110), (170, 170, 170))
    sd = ImageDraw.Draw(sheet)
    for k, (name, badge, colour, fields) in enumerate(PRESETS):
        if a.only and name != a.only:
            continue
        p = bytearray(base)
        for off, (fmt, v) in fields.items():
            struct.pack_into(fmt, p, off, v)
        open(os.path.join(out, name), "wb").write(p)
        im = draw(badge, colour)
        open(os.path.join(out, name + ".info"), "wb").write(
            diskobject(im, a.tool, ["PREFS=" + name] + TOOLTYPES.get(name, []) + a.tooltype))
        big = im.resize((W * 2, H * 2), Image.NEAREST)
        mask = Image.new("L", big.size)
        mask.putdata([0 if c == (255, 0, 255) else 255 for c in (big.get_flattened_data() if hasattr(big, "get_flattened_data") else big.getdata())])
        sheet.paste(big, (k * 120 + 14, 4), mask)
        sd.text((k * 120 + 10, 96), name, fill=(0, 0, 0))
        print(f"{name}: prefs {len(p)} bytes, icon written")
    sheet.save(os.path.join(out, "presets.png"))


if __name__ == "__main__":
    main()
