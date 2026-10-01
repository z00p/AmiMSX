"""Build tiny MSX test ROMs: SCREEN <mode>, one solid white 16x16 sprite at
(100,80); optional R#18 value. Usage: python tools/make_sprite_test.py out.rom mode [r18]"""
import sys
out, mode = sys.argv[1], int(sys.argv[2])
r18 = int(sys.argv[3], 0) if len(sys.argv) > 3 and sys.argv[3] != "-" else None
cc = len(sys.argv) > 4 and sys.argv[4] == "cc"     # mode 2: sprite pair, #1 with CC (OR colour)
CHGMOD, WRTVDP, FILVRM, LDIRVM, RG1SAV = 0x005F, 0x0047, 0x0056, 0x005C, 0xF3E0
# VRAM layout after CHGMOD (BIOS defaults): mode 1 sprites (SCREEN 2) vs mode 2 (SCREEN 4)
if mode == 2:
    spg, sat, sct = 0x3800, 0x1B00, None
else:
    spg, sat, sct = 0x3800, 0x1E00, 0x1C00
w = lambda v: [v & 0xFF, v >> 8]
code = []
code += [0x3E, mode] + [0xCD] + w(CHGMOD)                       # LD A,mode / CALL CHGMOD
code += [0x3A] + w(RG1SAV) + [0xF6, 0x02, 0x47, 0x0E, 0x01, 0xCD] + w(WRTVDP)   # R#1 |= SI (16x16)
code += [0x21] + w(spg) + [0x01] + w(64) + [0x3E, 0xFF, 0xCD] + w(FILVRM)       # patterns 0 and 4 solid
if sct is not None and not cc:
    code += [0x21] + w(sct) + [0x01] + w(16) + [0x3E, 0x0F, 0xCD] + w(FILVRM)   # mode 2 colours: white
if cc:
    code += [0x21] + w(0x4200) + [0x11] + w(sct) + [0x01] + w(32) + [0xCD] + w(LDIRVM)
if r18 is not None:
    code += [0x06, r18, 0x0E, 18, 0xCD] + w(WRTVDP)                            # R#18 set-adjust
sat_src = 0x4000 + 0x100
code += [0x21] + w(sat_src) + [0x11] + w(sat) + [0x01] + w(12 if cc else 8) + [0xCD] + w(LDIRVM)
code += [0x18, 0xFE]                                                          # JR $
rom = bytearray(16384)
rom[0:2] = b"AB"; rom[2:4] = bytes(w(0x4010))
rom[0x10:0x10 + len(code)] = bytes(code)
attr = 0x0F if mode == 2 else 0x00           # mode 1: colour in byte 3; mode 2: from SCT
if cc:
    code_len_fix = None
    rom[0x100:0x10C] = bytes([80, 100, 0, 0, 80, 100, 4, 0, 216, 0, 0, 0])
    rom[0x200:0x220] = bytes([0x03] * 16 + [0x44] * 16)          # #0 colour 3, #1 colour 4 + CC
else:
    rom[0x100:0x108] = bytes([80, 100, 0, attr, 208 if mode == 2 else 216, 0, 0, 0])
open(out, "wb").write(rom)
print("wrote", out, len(code), "bytes of code")
