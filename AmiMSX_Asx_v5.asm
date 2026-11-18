;	 --------------------------------------------
;	- ASCII16-X cartridges (5.2) -
;	 --------------------------------------------
;
; The ASCII16-X type (openMSX's name) holds MSX Translations' big ROMs, such
; as Illusion City (4 MB). It is ASCII16 with more bank registers and longer
; bank numbers:
; - two 16 KB banks, the first at 4000h-7FFFh, the second at 8000h-BFFFh;
; - a bank register is written anywhere in the upper 8 KB of any page
;   (2000h-3FFFh, 6000h-7FFFh, A000h-BFFFh, E000h-FFFFh): address bit 12
;   picks the bank (0: the first, 1: the second);
; - the bank number is 12 bits: address bits 8-11 above the written byte;
;   a number past the ROM's end is masked, as BankNum does;
; - at reset the banks are 0 and 1 (as AmiMSX's MegaROM set-up already does).
; - the cartridge decodes all four pages: the first bank also shows at
;   C000h-FFFFh, the second at 0000h-3FFFh (Illusion City's FM/MIDI slot
;   scan selects the cartridge in page 3 and reads and writes FFFFh there:
;   the write sets the second bank, the code it then calls at 8000h).
; Not done: the cartridge's flash chip (writes to the ROM are ignored).
; Mapper8 (Slot 1) and Mapper8b (Slot 2) point here; menu index 8, ROM
; database code 7, file-name tag [ASCII16X] or [ASCII16-X].
;

; AsxPg slot, page: the bank at AsxBk shown in that page of the slot. The
; slot rows always; the page's read pointers too when the page is on the
; slot (DA8), as RTyp1 does for page 2. D1 trashed.
AsxPg	MACRO
	MOVE.L	AsxBk,D1
	IFNE	\2
	SUB.L	#\2*$4000,D1
	ENDC
	MOVE.L	D1,SLOTS+(32*\1)+(8*\2)(A3)
	MOVE.W	D1,SLOTSR+(8*\1)+(2*\2)(A3)
	ADD.L	#$0080,D1
	MOVE.L	D1,SubSLOTS+(32*\1)+(8*\2)(A3)
	MOVE.W	D1,SubSLOTSR+(8*\1)+(2*\2)(A3)
	BTST	#(2*\2)+1,DA8(A3)	; page on this slot? (slot 1: 01,
	IFEQ	\1-1			; slot 2: 10)
	BNE	.x\@
	ELSE
	BEQ	.x\@
	ENDC
	BTST	#2*\2,DA8(A3)
	IFEQ	\1-1
	BEQ	.x\@
	ELSE
	BNE	.x\@
	ENDC
	SUB.L	#$0080,D1
	MOVE.L	D1,PagRead+(8*\2)+0(A3)
	MOVE.W	D1,RESTA\2+0(A3)
	ADD.L	#$0080,D1
	MOVE.L	D1,PagRead+(8*\2)+4(A3)
	MOVE.W	D1,RESTA\2+8(A3)
	ADD.L	#(\2*$4000)+1-$80,D1
	MOVE.L	D1,RESTA\2+0+Desbor+0(A3)
	ADD.L	#$1FFF,D1
	MOVE.L	D1,RESTA\2+0+Desbor+4(A3)
	ADDQ.L	#$0001,D1
	MOVE.L	D1,RESTA\2+8+Desbor+0(A3)
	ADD.L	#$1FFF,D1
	MOVE.L	D1,RESTA\2+8+Desbor+4(A3)
.x\@:
	ENDM

; AsxBank slot, MapROMBase, NumROM, MaskROM
; Entered with D1.W = the Z80 address written, (A4) = the value.
AsxBank	MACRO
	SUB.W	(A7),A5
	MOVE.W	D1,AsxAdr
	IFD	VWLOG
	VWLA	$FC,(A4),D1		; (debug) the write: value, address
	ENDC
	AND.W	#$0F00,D1		; bank = address bits 8-11 : value
	MOVE.B	(A4),D1
	CMP.W	\3,D1
	BCS.S	.m\@
	AND.W	\4(A3),D1
.m\@:	MULU	#$4100,D1
	ADD.L	\2(A3),D1
	MOVE.L	D1,AsxBk
	BTST	#4,AsxAdr		; address bit 12: which bank
	BNE	.p2\@
; The first bank: 4000h-7FFFh and its mirror C000h-FFFFh.
	AsxPg	\1,1
	AsxPg	\1,3
	BRA	.x\@
; The second bank: 8000h-BFFFh and its mirror 0000h-3FFFh.
.p2\@:	AsxPg	\1,2
	AsxPg	\1,0
.x\@:	MOVEQ	#0,D1
	MOVE.W	A5,D1
	CogePag	D1,A5
	Otra2
	ENDM

	CNOP	0,4
; Slot 1: the write table's 8 KB segments 1, 3, 5 and 7.
AsxW1:	MOVE.L	A4,D1
	SUB.L	PagWrite+4(A3),D1
	BRA.S	AsxS1
AsxW3:	MOVE.L	A4,D1
	SUB.L	PagWrite+12(A3),D1
	BRA.S	AsxS1
AsxW5:	MOVE.L	A4,D1
	SUB.L	PagWrite+20(A3),D1
	BRA.S	AsxS1
AsxW7:	MOVE.L	A4,D1
	SUB.L	PagWrite+28(A3),D1
AsxS1:	AsxBank	1,MapROMBase1,NumROM2,MaskROM2

	CNOP	0,4
; Slot 2.
AsxW1b:	MOVE.L	A4,D1
	SUB.L	PagWrite+4(A3),D1
	BRA.S	AsxS2
AsxW3b:	MOVE.L	A4,D1
	SUB.L	PagWrite+12(A3),D1
	BRA.S	AsxS2
AsxW5b:	MOVE.L	A4,D1
	SUB.L	PagWrite+20(A3),D1
	BRA.S	AsxS2
AsxW7b:	MOVE.L	A4,D1
	SUB.L	PagWrite+28(A3),D1
AsxS2:	AsxBank	2,MapROMBase2,NumROM4,MaskROM4

	CNOP	0,2
AsxAdr:	DC.W	0			; the Z80 address written
	CNOP	0,4
AsxBk:	DC.L	0			; the bank's address (AsxPg)
