"""SCREEN 8 scanline test ROM (16 KB, plain, 4000h), for the RTG scanline check
(Docs/agent_notes/v46_scanlines.md): SCREEN 8, 212 lines, sprites off; line y, dot x
in G7 colour (x + y) AND 255 (all 256 colours, every line different). Each frame a
white line moves down one line (the line it leaves gets its colours back), so
single changed lines and the blend rows above and below them are exercised; every
64 frames the border (R#7) takes another G7 colour. No interrupts (DI), polls S#0.

Usage: python tools/make_scr8_test.py <out.rom>"""
import sys


def build():
    code, labels, fix = bytearray(), {}, []
    org = 0x4010

    def b(*xs):
        code.extend(xs)

    def lab(n):
        labels[n] = org + len(code)

    def jr(op, n):          # relative jump to label n
        b(op, 0); fix.append(('r', len(code) - 1, n))

    def ab(op, n):          # absolute (CALL/JP) to label n
        b(op, 0, 0); fix.append(('a', len(code) - 2, n))

    def reg(r, v):
        b(0x3E, v, 0xD3, 0x99, 0x3E, 0x80 | r, 0xD3, 0x99)

    b(0xF3)                                  # DI
    for r, v in ((0, 0x0E), (1, 0x40), (2, 0x1F), (7, 0x00), (8, 0x0A), (9, 0x80),
                 (15, 0x00), (18, 0x00), (23, 0x00)):
        reg(r, v)
    b(0x3E, 0x00, 0x32, 0x00, 0xC0)          # LD A,0 ; LD (C000h),A  (the white line's y)
    b(0x06, 0x00)                            # LD B,0
    lab('fill')
    b(0x78); ab(0xCD, 'grad')                # LD A,B ; CALL grad
    b(0x04, 0x78, 0xFE, 212); jr(0x20, 'fill')   # INC B ; LD A,B ; CP 212 ; JR NZ
    lab('main')
    b(0xDB, 0x99, 0xE6, 0x80); jr(0x28, 'main')  # IN A,(99h) ; AND 80h ; JR Z,main
    b(0x3A, 0x00, 0xC0); ab(0xCD, 'grad')    # LD A,(C000h) ; CALL grad (restore)
    b(0x3A, 0x00, 0xC0, 0x3C, 0xFE, 200); jr(0x38, 'ok')  # LD A,(y) ; INC A ; CP 200 ; JR C,ok
    b(0xAF)                                  # XOR A
    lab('ok')
    b(0x32, 0x00, 0xC0); ab(0xCD, 'white')   # LD (C000h),A ; CALL white
    b(0x3A, 0x00, 0xC0, 0xE6, 0x3F); jr(0x20, 'main')    # LD A,(y) ; AND 63 ; JR NZ,main
    b(0x3A, 0x00, 0xC0, 0xD3, 0x99, 0x3E, 0x87, 0xD3, 0x99)   # R#7 = y
    jr(0x18, 'main')
    lab('addr')                              # VRAM write address A * 256 (keeps A in B)
    b(0x47, 0x07, 0x07, 0xE6, 0x03, 0xD3, 0x99, 0x3E, 0x8E, 0xD3, 0x99)  # R#14 = y >> 6
    b(0xAF, 0xD3, 0x99, 0x78, 0xE6, 0x3F, 0xF6, 0x40, 0xD3, 0x99, 0xC9)
    lab('grad')                              # line A: (x + y) AND 255
    b(0xC5); ab(0xCD, 'addr')                # PUSH BC ; CALL addr
    b(0x2E, 0x00)                            # LD L,0
    lab('g1')
    b(0x7D, 0x80, 0xD3, 0x98, 0x2C); jr(0x20, 'g1')   # LD A,L ; ADD A,B ; OUT (98h),A ; INC L
    b(0xC1, 0xC9)                            # POP BC ; RET
    lab('white')                             # line A: colour FFh
    b(0xC5); ab(0xCD, 'addr')
    b(0x2E, 0x00, 0x3E, 0xFF)
    lab('w1')
    b(0xD3, 0x98, 0x2C); jr(0x20, 'w1')
    b(0xC1, 0xC9)
    for kind, at, n in fix:
        if kind == 'r':
            d = labels[n] - (org + at + 1)
            assert -128 <= d < 128, n
            code[at] = d & 255
        else:
            code[at], code[at + 1] = labels[n] & 255, labels[n] >> 8
    rom = bytearray(16384)
    rom[0:4] = b"AB\x10\x40"
    rom[0x10:0x10 + len(code)] = code
    return rom


if __name__ == '__main__':
    open(sys.argv[1], 'wb').write(build())
    print(sys.argv[1], 'written')
