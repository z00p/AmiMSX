"""Build run/Disks/rtgscr.dsk: a 720 KB MSX disk whose AUTOEXEC.BAS shows each of the
modes the RTG display gained in 4.6 (Docs/agent_notes/v46_rtgscreens.md), one after the
other; any key moves on (the program loops):
  1. SCREEN 7: 16 colour bars (top), 1-dot lines in every colour (512 dots, bottom),
     two 16x16 sprites moving, a line (XOR) moving down.
  2. SCREEN 6: 4 colour bars, 1-dot lines, sprites (colours split in two half dots).
  3. SCREEN 0, WIDTH 80: 24 rows of text, blink on every other group of 8 characters in
     the even rows (R#12 = A1h, R#13 = 22h), a character changing each loop.
  4. SCREEN 0, WIDTH 40: text, a character changing.
  5. SCREEN 3: 16 colour blocks, a mode 1 sprite moving.
The drawing is done with LINE/PSET (VDP commands), as a game would.

Usage: python tools/make_rtgscr_dsk.py [out.dsk]"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_mask_test_dsk as mm

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROG = r'''10 DEFINT A-Z:S$=STRING$(32,255)
20 SCREEN 7,2:COLOR 15,0,4:CLS:SPRITE$(0)=S$:SPRITE$(1)=S$
30 FOR I=0 TO 15:LINE(I*32,0)-(I*32+31,99),I,BF:NEXT
40 FOR X=0 TO 511:LINE(X,100)-(X,211),X AND 15:NEXT
50 GOSUB 900
60 SCREEN 6,2:COLOR 3,0,1:CLS:SPRITE$(0)=S$:SPRITE$(1)=S$
70 FOR I=0 TO 3:LINE(I*128,0)-(I*128+127,99),I,BF:NEXT
80 FOR X=0 TO 511:LINE(X,100)-(X,211),X AND 3:NEXT
90 GOSUB 900
100 SCREEN 0:WIDTH 80:COLOR 15,4,4:CLS
110 FOR I=0 TO 22:LOCATE 0,I:PRINT STRING$(80,65+I);:NEXT
115 FOR I=0 TO 269:VPOKE &H800+I,0:NEXT
120 FOR I=0 TO 22 STEP 2:FOR J=0 TO 9 STEP 2:VPOKE &H800+I*10+J,255:NEXT:NEXT
130 VDP(13)=&HA1:VDP(14)=&H22
140 T=0
150 LOCATE T MOD 80,23:PRINT CHR$(48+(T\80) MOD 10);:T=T+1:IF INKEY$="" THEN 150
160 VDP(14)=0:SCREEN 0:WIDTH 40:COLOR 11,1,1:CLS
170 FOR I=0 TO 22:LOCATE 0,I:PRINT STRING$(40,97+I);:NEXT
180 T=0
190 LOCATE T MOD 40,23:PRINT CHR$(48+(T\40) MOD 10);:T=T+1:IF INKEY$="" THEN 190
200 SCREEN 3,2:COLOR 15,1,7:CLS:SPRITE$(0)=S$
210 FOR I=0 TO 15:LINE((I AND 7)*32,(I\8)*96)-((I AND 7)*32+31,(I\8)*96+95),I,BF:NEXT
220 T=0
230 PUT SPRITE 0,(T AND 255,(T*3) AND 127),15:T=T+1:IF INKEY$="" THEN 230
240 GOTO 20
900 T=0:Y=0:Z=300
910 PUT SPRITE 0,(T AND 255,(T\2) AND 127),10
920 PUT SPRITE 1,(255-(T AND 255),60),5
930 LINE(0,Y)-(511,Y),15,,XOR:LINE(0,Z)-(511,Z),15,,XOR:Z=Y:T=T+1:Y=(Y+1) MOD 212
940 IF INKEY$="" THEN 910
950 RETURN
'''


if __name__ == "__main__":
    mm.PROG = PROG
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(BASE, "run", "Disks", "rtgscr.dsk")
    open(out, "wb").write(mm.build())
    print("wrote", out)
