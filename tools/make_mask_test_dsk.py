"""Build run/Disks/masktest.dsk: a 720 KB MSX disk whose AUTOEXEC.BAS draws
edge-test boxes, so the Mask screen edges option can be checked without typing.

Screens (any key moves to the next; the program loops):
  1. SCREEN 7 (512 dots): white box at the edge, red 8 MSX dots in (16 SCREEN 7
     dots), green 16 dots in (32).
  2. SCREEN 0, WIDTH 80: a full row of '#' and a column ruler.
  3. SCREEN 5 (256 dots): the same boxes at 0, 8 and 16 dots.
With the option Off all three boxes show; with 8 dots the white sides go; with
16 dots the red sides go too. Top and bottom stay (the mask is horizontal).

Usage: python tools/make_mask_test_dsk.py [out.dsk]"""
import os, struct, sys

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROG = r'''10 SCREEN 7:COLOR 15,1,1:CLS
20 LINE(0,0)-(511,211),15,B:LINE(16,16)-(495,195),8,B:LINE(32,32)-(479,179),2,B
30 IF INKEY$="" THEN 30
40 SCREEN 0:WIDTH 80:COLOR 15,1,1:CLS
50 PRINT STRING$(80,"#");
60 PRINT "1234567890123456789012345678901234567890123456789012345678901234567890123456789"
70 IF INKEY$="" THEN 70
80 SCREEN 5:COLOR 15,1,1:CLS
90 LINE(0,0)-(255,211),15,B:LINE(8,8)-(247,203),8,B:LINE(16,16)-(239,195),2,B
100 IF INKEY$="" THEN 100
110 GOTO 10
'''


def build():
    data = PROG.replace("\n", "\r\n").encode("ascii") + b"\x1a"
    img = bytearray(737280)
    # Boot sector: 720 KB double-sided, 9 sectors/track (MSX media F9)
    bpb = struct.pack("<3s8sHBHBHHBHHHI", b"\xeb\xfe\x90", b"MASKTEST", 512, 2, 1, 2, 112,
                      1440, 0xF9, 3, 9, 2, 0)
    img[0:len(bpb)] = bpb
    img[0x1E] = 0xC9            # boot program: RET (the disk ROM then starts
                                # BASIC, which runs AUTOEXEC.BAS)
    img[510:512] = b"\x55\xaa"
    clusters = (len(data) + 1023) // 1024
    fat = bytearray(3 * 512)
    fat[0:3] = b"\xf9\xff\xff"
    def setfat(n, v):
        o = n * 3 // 2
        if n & 1:
            fat[o] = (fat[o] & 0x0F) | ((v << 4) & 0xF0); fat[o + 1] = (v >> 4) & 0xFF
        else:
            fat[o] = v & 0xFF; fat[o + 1] = (fat[o + 1] & 0xF0) | ((v >> 8) & 0x0F)
    for i in range(clusters):
        setfat(2 + i, 0xFFF if i == clusters - 1 else 3 + i)
    for k in range(2):
        img[512 * (1 + 3 * k):512 * (4 + 3 * k)] = fat
    root = 7 * 512
    ent = struct.pack("<8s3sB10sHHHI", b"AUTOEXEC", b"BAS", 0x20, b"\0" * 10, 0, 0x5555, 2, len(data))
    img[root:root + 32] = ent
    dstart = 14 * 512
    img[dstart:dstart + len(data)] = data
    return bytes(img)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(BASE, "run", "Disks", "masktest.dsk")
    open(out, "wb").write(build())
    print("wrote", out)
