"""Build an AmiMSX2.data file with C-BIOS instead of the MSX system ROMs.

Format (see LoadROMs in AmiMSX_Menu_v3.1.asm): 16-byte signature ("AmiMSX2\0data v00";
"data CB1" here marks C-BIOS), then 12 longs
of block offsets relative to the end of the 64-byte header: DOS 1, DOS 2,
ROM sets MSX1 / MSX2 / MSX2+, Kanji, end. A block's size is the next offset
minus its own. Each block is XORed long by long with 17DB03A5h and may be
Imploder-packed ("IMP!"); unpacked blocks are used as they are (EXPLODE leaves
data without "IMP!" alone). ROM sets are 16 KB chunks spaced 4100h apart:
  MSX1:  BIOS 0000h, page 1 4000h            (slot 0)
  MSX2:  BIOS 0000h, page 1 4000h (slot 0), SUB-ROM (slot 2)
  MSX2+: BIOS 0000h, 4000h, 8000h (slot 0), SUB-ROM (slot 2)
C-BIOS has no BASIC and no working disk ROM: the DOS blocks are left empty
(disk images need the original AmiMSX2.data, from the AmiMSX 3.x package).

Usage: python tools/make_cbios_data.py <openMSX share/machines dir> out.data [eu|int|jp|br]"""
import struct, sys, os

KEY = 0x17DB03A5
CHUNK = 0x4100


def chunks(*roms):
    """16 KB pieces, each followed by 256 guard bytes (the next piece's start)."""
    pieces = []
    for r in roms:
        assert len(r) % 0x4000 == 0, len(r)
        pieces += [r[i:i + 0x4000] for i in range(0, len(r), 0x4000)]
    out = bytearray()
    for i, p in enumerate(pieces):
        nxt = pieces[i + 1][:0x100] if i + 1 < len(pieces) else bytes(0x100)
        out += p + nxt
    return bytes(out)


def xor(b):
    b = b + bytes((-len(b)) % 4)
    return b"".join(struct.pack(">I", struct.unpack(">I", b[i:i + 4])[0] ^ KEY) for i in range(0, len(b), 4))


def main():
    src, out = sys.argv[1], sys.argv[2]
    region = sys.argv[3] if len(sys.argv) > 3 else "eu"
    sfx = "" if region == "int" else "_" + region
    rd = lambda n: open(os.path.join(src, n), "rb").read()
    msx1 = chunks(rd(f"cbios_main_msx1{sfx}.rom"))
    msx2 = chunks(rd(f"cbios_main_msx2{sfx}.rom"), rd("cbios_sub.rom"))
    msx2p = chunks(rd(f"cbios_main_msx2+{sfx}.rom"), rd("cbios_logo_msx2+.rom"), rd("cbios_sub.rom"))
    assert len(msx1) == 2 * CHUNK and len(msx2) == 3 * CHUNK and len(msx2p) == 4 * CHUNK
    blocks = [b"", b"", msx1, msx2, msx2p, b""]          # DOS1, DOS2, MSX1, MSX2, MSX2+, Kanji
    offs, pos, data = [], 0, b""
    for b in blocks:
        offs.append(pos)
        enc = xor(b) if b else b""
        data += enc
        pos += len(enc)
    offs.append(pos)
    hdr = b"AmiMSX2\0data CB1" + struct.pack(   # "CB": C-BIOS, AmiMSX skips its SUB-ROM patches
">12I", *(offs + [0] * (12 - len(offs))))
    assert len(hdr) == 64
    open(out, "wb").write(hdr + data)
    print(f"{out}: {len(hdr) + len(data)} bytes, C-BIOS {region}; offsets {[hex(o) for o in offs]}")


if __name__ == "__main__":
    main()
