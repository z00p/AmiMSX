;	 --------------------------------------------
;	- NEO-16 cartridges (5.4) -
;	 --------------------------------------------
;
; The NEO-16 mapper (MSXgl's NEO mapper specification, version 1.2), as used by
; Puzzle Mania XXXL / XXXS (16 MB):
; - three 16 KB banks: 0000h-3FFFh, 4000h-7FFFh and 8000h-BFFFh; C000h-FFFFh
;   is not banked and reads FFh;
; - each bank has a 16-bit segment register. Address bits 13-11 pick it: 010
;   bank 0 (5000h), 100 bank 1 (6000h), 110 bank 2 (7000h); bits 15-14 are
;   not decoded (mirrors at 1000h/9000h/D000h and so on), nor are bits 10-1;
;   bit 0 picks the byte: even the low byte, odd the high byte, whose bits
;   7-6 are reserved (masked off): 14-bit segment numbers;
; - every bank is segment 0 at reset;
; - the ROM carries "ROM_NE16" at offset 10h (HeadMapper, the menu).
; A segment past the ROM's end is masked, as BankNum does (the specification
; leaves it open). Writes elsewhere are ignored: no SRAM, no flash.
; Mapper9 (Slot 1) and Mapper9b (Slot 2) point here; menu index 9, mapper
; code 8 (not in the ROM database; a saved mapper can't hold it, so it isn't
; saved), file-name tag [NEO16] or [NEO-16].
;

; NeoSet slot, bank, MapROMBase, NumROM, MaskROM, segment registers: the
; byte written into the bank's register, then the segment shown in the
; bank's page (AsxPg, AmiMSX_Asx_v5.asm). Ends the instruction.
NeoSet	MACRO
	SUB.W	(A7),A5
	BTST	#0,NeoAdr+1		; odd address: the high byte
	BNE.S	.h\@
	MOVE.B	(A4),\6+(\2*2)+1
	BRA.S	.s\@
.h\@:	MOVE.B	(A4),D1
	AND.B	#$3F,D1
	MOVE.B	D1,\6+(\2*2)
.s\@:	MOVE.W	\6+(\2*2),D1
	CMP.W	\4,D1
	BCS.S	.m\@
	AND.W	\5(A3),D1
.m\@:	MULU	#$4100,D1
	ADD.L	\3(A3),D1
	MOVE.L	D1,AsxBk
	AsxPg	\1,\2
	MOVEQ	#0,D1
	MOVE.W	A5,D1
	CogePag	D1,A5
	Otra2
	ENDM

; NeoBank slot, MapROMBase, NumROM, MaskROM, segment registers.
; Entered with D1.W = the Z80 address written, (A4) = the value.
NeoBank	MACRO
	MOVE.W	D1,NeoAdr
	AND.W	#$3800,D1		; address bits 13-11
	CMP.W	#$1000,D1
	BEQ	.b0\@
	CMP.W	#$2000,D1
	BEQ	.b1\@
	CMP.W	#$3000,D1
	BEQ	.b2\@
	Otra2				; not a register
.b0\@:	NeoSet	\1,0,\2,\3,\4,\5
.b1\@:	NeoSet	\1,1,\2,\3,\4,\5
.b2\@:	NeoSet	\1,2,\2,\3,\4,\5
	ENDM

	CNOP	0,4
; Slot 1: the write table's 8 KB segments 0-7.
NeoW0:	MOVE.L	A4,D1
	SUB.L	PagWrite+0(A3),D1
	BRA	NeoS1
NeoW1:	MOVE.L	A4,D1
	SUB.L	PagWrite+4(A3),D1
	BRA	NeoS1
NeoW2:	MOVE.L	A4,D1
	SUB.L	PagWrite+8(A3),D1
	BRA	NeoS1
NeoW3:	MOVE.L	A4,D1
	SUB.L	PagWrite+12(A3),D1
	BRA	NeoS1
NeoW4:	MOVE.L	A4,D1
	SUB.L	PagWrite+16(A3),D1
	BRA	NeoS1
NeoW5:	MOVE.L	A4,D1
	SUB.L	PagWrite+20(A3),D1
	BRA	NeoS1
NeoW6:	MOVE.L	A4,D1
	SUB.L	PagWrite+24(A3),D1
	BRA	NeoS1
NeoW7:	MOVE.L	A4,D1
	SUB.L	PagWrite+28(A3),D1
NeoS1:	NeoBank	1,MapROMBase1,NumROM2,MaskROM2,NeoSg1

	CNOP	0,4
; Slot 2.
NeoW0b:	MOVE.L	A4,D1
	SUB.L	PagWrite+0(A3),D1
	BRA	NeoS2
NeoW1b:	MOVE.L	A4,D1
	SUB.L	PagWrite+4(A3),D1
	BRA	NeoS2
NeoW2b:	MOVE.L	A4,D1
	SUB.L	PagWrite+8(A3),D1
	BRA	NeoS2
NeoW3b:	MOVE.L	A4,D1
	SUB.L	PagWrite+12(A3),D1
	BRA	NeoS2
NeoW4b:	MOVE.L	A4,D1
	SUB.L	PagWrite+16(A3),D1
	BRA	NeoS2
NeoW5b:	MOVE.L	A4,D1
	SUB.L	PagWrite+20(A3),D1
	BRA	NeoS2
NeoW6b:	MOVE.L	A4,D1
	SUB.L	PagWrite+24(A3),D1
	BRA	NeoS2
NeoW7b:	MOVE.L	A4,D1
	SUB.L	PagWrite+28(A3),D1
NeoS2:	NeoBank	2,MapROMBase2,NumROM4,MaskROM4,NeoSg2

	CNOP	0,2
NeoAdr:	DC.W	0			; the Z80 address written
NeoSg1:	DC.W	0,0,0			; Slot 1: banks 0-2' segments
NeoSg2:	DC.W	0,0,0			; Slot 2
