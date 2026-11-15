"""Build run/Disks/kanjibas.dsk: a 720 KB disk whose AUTOEXEC.BAS switches the
turbo R's BASIC 4.1 to kanji mode (CALL KANJI) and prints level 1 and level 2
characters through the kanji ROM (Shift-JIS bytes by CHR$):
  level 1: 889F-88A6 (亜唖娃阿哀愛挨姶), hiragana 82A0-82AE, 9340-9347
  level 2: 989F-98A6 (弌丐丕个丱丶丼丿), E040-E047, EA9F-EAA4 (the last ones)
On a machine without the font the characters come out blank.

Usage: python tools/make_kanjibas_dsk.py [out.dsk]"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_mask_test_dsk as mm

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROG = r'''10 CALL KANJI
20 PRINT "LEVEL 1"
30 FOR I=0 TO 7:PRINT CHR$(&H88)+CHR$(&H9F+I);:NEXT:PRINT
40 FOR I=0 TO 7:PRINT CHR$(&H82)+CHR$(&HA0+I*2);:NEXT:PRINT
50 FOR I=0 TO 7:PRINT CHR$(&H93)+CHR$(&H40+I);:NEXT:PRINT
60 PRINT "LEVEL 2"
70 FOR I=0 TO 7:PRINT CHR$(&H98)+CHR$(&H9F+I);:NEXT:PRINT
80 FOR I=0 TO 7:PRINT CHR$(&HE0)+CHR$(&H40+I);:NEXT:PRINT
90 FOR I=0 TO 5:PRINT CHR$(&HEA)+CHR$(&H9F+I);:NEXT:PRINT
100 PRINT "END"
110 GOTO 110
'''


if __name__ == "__main__":
    mm.PROG = PROG
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(BASE, "run", "Disks", "kanjibas.dsk")
    open(out, "wb").write(mm.build())
    print("wrote", out)
