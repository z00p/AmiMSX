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
; - (5.3) the cartridge's flash chip in Slot 1 (AxFlash below): game saves,
;   kept in "<cartridge>.flash" (FlashSave, AmiMSX_Saves_v4.asm). Slot 2:
;   writes to the ROM are ignored.
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
.m\@:
	IFEQ	\1-1
	MOVE.W	D1,AxNt			; (5.3) the bank number, for the flash
	ENDC
	MULU	#$4100,D1
	ADD.L	\2(A3),D1
	MOVE.L	D1,AsxBk
	BTST	#4,AsxAdr		; address bit 12: which bank
	BNE	.p2\@
; The first bank: 4000h-7FFFh and its mirror C000h-FFFFh.
	IFEQ	\1-1
	MOVE.W	AxNt,AxN1		; (5.3) kept for the flash chip; while
	MOVE.L	D1,AxB1			; its ID, CFI or status shows, the pages
	TST.B	AxMode			; keep showing that (AxMap)
	BNE	.x\@
	ENDC
	AsxPg	\1,1
	AsxPg	\1,3
	BRA	.x\@
; The second bank: 8000h-BFFFh and its mirror 0000h-3FFFh.
.p2\@:
	IFEQ	\1-1
	MOVE.W	AxNt,AxN2
	MOVE.L	D1,AxB2
	TST.B	AxMode
	BNE	.x\@
	ENDC
	AsxPg	\1,2
	AsxPg	\1,0
.x\@:	MOVEQ	#0,D1
	MOVE.W	A5,D1
	CogePag	D1,A5
	Otra2
	ENDM

	CNOP	0,4
; Slot 1: the write table's 8 KB segments 1, 3, 5 and 7: (5.3) the flash
; chip first (with the bank as it was), then the bank register.
AsxW1:	MOVE.L	A4,D1
	SUB.L	PagWrite+4(A3),D1
	BRA.S	AsxFo
AsxW3:	MOVE.L	A4,D1
	SUB.L	PagWrite+12(A3),D1
	BRA.S	AsxFo
AsxW5:	MOVE.L	A4,D1
	SUB.L	PagWrite+20(A3),D1
	BRA.S	AsxFo
AsxW7:	MOVE.L	A4,D1
	SUB.L	PagWrite+28(A3),D1
AsxFo:	ST	AxOdd
	BRA	AxFlash
AsxS1:	AsxBank	1,MapROMBase1,NumROM2,MaskROM2

	CNOP	0,4
; (5.3) Slot 1, segments 0, 2, 4 and 6: the flash chip only.
AsxF0:	MOVE.L	A4,D1
	SUB.L	PagWrite+0(A3),D1
	BRA.S	AsxFe
AsxF2:	MOVE.L	A4,D1
	SUB.L	PagWrite+8(A3),D1
	BRA.S	AsxFe
AsxF4:	MOVE.L	A4,D1
	SUB.L	PagWrite+16(A3),D1
	BRA.S	AsxFe
AsxF6:	MOVE.L	A4,D1
	SUB.L	PagWrite+24(A3),D1
AsxFe:	SF	AxOdd
	BRA	AxFlash

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

;	 --------------------------------------------
;	- The ASCII16-X flash chip (5.3) -
;	 --------------------------------------------
;
; openMSX models the cartridge's flash as a Spansion S29GL064S (8 MB, used
; 8 bits wide): sectors of 8 KB for the first 64 KB, then of 64 KB. Every
; write to the cartridge in Slot 1 reaches the chip, at the flash address
; the page's bank gives it (bank * 16 KB + address bits 0-13); commands
; look at address bits 1-11 only (xAAAh/xAABh and x554h/x555h):
; - AAh 55h A0h, then a byte at an address: program it (bits only go to 0);
; - AAh 55h 80h AAh 55h, 30h at an address: erase its sector (more 30h
;   writes straight after add sectors); 10h instead: erase the whole chip;
; - AAh 55h, 25h at a sector, count - 1, that many + 1 bytes in one 256-byte
;   page, 29h at the sector: buffer program. A broken sequence aborts: the
;   chip then reads its status (DQ1 set) until AAh 55h F0h;
; - AAh 55h 90h: autoselect (ID 01h 7Eh 10h 00h, as openMSX), 98h at xAAh:
;   CFI query; F0h, AAh 55h F0h (and FFh in CFI) read the array again.
; Program and erase end at once (openMSX times them), so a game's status
; poll (DQ7, or FFh after an erase) reads the final data at once.
; Changed sectors are marked in FlSect for FlashSave (64 KB a bit: an 8 KB
; sector marks its 64 KB). While the ID, CFI or status shows, all four
; pages read AxVBuf (a 16 KB page laid out as the ROM's, as SramView).
; Not done: the status register command (70h), suspend and resume, and the
; chip's upper 4 MB beyond a 4 MB ROM (bank numbers wrap at the ROM's end,
; as AsxBank always did).

; AxSec Dn, Dm: Dm.W = the sector of flash address Dn.
AxSec	MACRO
	MOVE.L	\1,\2
	CMP.L	#$10000,\2
	BCC.S	.b\@
	LSR.L	#8,\2
	LSR.L	#5,\2			; 8 KB sectors 0-7,
	BRA.S	.x\@
.b\@:	SWAP	\2
	ADDQ.W	#7,\2			; then 64 KB ones from 8
.x\@:
	ENDM

; AxHost Dn, label: A0 = the byte of flash address Dn in the ROM image (8 KB
; bank k at MapROMBase1 + k * $2080); to the label when past the ROM. D7.
AxHost	MACRO
	MOVE.L	\1,D7
	LSR.L	#8,D7
	LSR.L	#5,D7
	CMP.W	NumROM,D7
	BCC	\2
	MULU.W	#$2080,D7
	ADD.L	MapROMBase1(A3),D7
	MOVE.L	D7,A0
	MOVE.L	\1,D7
	AND.W	#$1FFF,D7
	ADD.W	D7,A0
	ENDM

; D1.W = the Z80 address, (A4) = the byte, AxOdd: a bank register write too
; (then on to AsxS1). No stack here: registers kept in AxSv.
	CNOP	0,4
AxFlash:
	MOVEM.L	D3-D7/A0-A2,AxSv
	MOVE.W	D1,AxZA
	MOVEQ	#0,D3
	MOVE.B	(A4),D3			; D3 = the byte
	MOVEQ	#0,D5			; D5 = the flash address: 4000h-7FFFh
	MOVE.W	AxN1,D5			; and C000h-FFFFh the first bank,
	BTST	#14,D1			; 0000h-3FFFh and 8000h-BFFFh the
	BNE.S	AxF1			; second
	MOVE.W	AxN2,D5
AxF1:	LSL.L	#8,D5
	LSL.L	#6,D5
	MOVE.W	D1,D4
	AND.W	#$3FFF,D4
	OR.W	D4,D5
	MOVE.W	D1,D6			; D6 = command address bits 1-11
	AND.W	#$FFE,D6
	TST.B	AxMore			; After a sector erase: 30h adds a
	BEQ.S	AxF2			; sector.
	SF	AxMore
	CMP.B	#$30,D3
	BEQ	AxErS
AxF2:	MOVEQ	#0,D4
	MOVE.B	AxCmd,D4
	MOVE.L	AxJT(PC,D4.W*4),A0
	JMP	(A0)
AxJT:	DC.L	AxC0,AxC1,AxC2,AxC3,AxC4,AxC5,AxC6,AxC7,AxC8,AxC9,AxC10

AxC0:	CMP.B	#$AA,D3			; 0: first unlock cycle,
	BNE.S	AxC0b
	CMP.W	#$AAA,D6
	BNE.S	AxC0b
	MOVE.B	#1,AxCmd
	BRA	AxX
AxC0b:	MOVE.B	AxMode,D4		; or one-cycle commands.
	BEQ.S	AxC0q
	CMP.B	#3,D4			; Status: AAh 55h F0h only.
	BEQ	AxX
	CMP.B	#$F0,D3			; ID, CFI: F0h reads the array again,
	BEQ	AxRead
	CMP.B	#2,D4
	BNE.S	AxC0q
	CMP.B	#$FF,D3			; and so does FFh in CFI.
	BEQ	AxRead
	BRA	AxX
AxC0q:	CMP.B	#$98,D3			; Array, ID: 98h at xAAh, CFI query.
	BNE	AxX
	MOVE.W	D1,D4
	AND.W	#$1FE,D4
	CMP.W	#$AA,D4
	BNE	AxX
	MOVEQ	#2,D4
	BRA	AxView

AxC1:	CMP.B	#$55,D3			; 1: second unlock cycle.
	BNE.S	AxIdle
	CMP.W	#$554,D6
	BNE.S	AxIdle
	MOVE.B	#2,AxCmd
	BRA	AxX
AxIdle:	CLR.B	AxCmd
	BRA	AxX

AxC2:	CLR.B	AxCmd			; 2: the command.
	TST.B	AxMode
	BEQ.S	AxC2r
	CMP.B	#$F0,D3			; ID, CFI, status: AAh 55h F0h.
	BNE	AxX
	CMP.W	#$AAA,D6
	BNE	AxX
	BRA	AxRead
AxC2r:	CMP.B	#$25,D3			; 25h at a sector: buffer program.
	BEQ.S	AxC2b
	CMP.W	#$AAA,D6
	BNE	AxX
	CMP.B	#$A0,D3
	BEQ.S	AxC2p
	CMP.B	#$80,D3
	BEQ.S	AxC2e
	CMP.B	#$90,D3
	BNE	AxX
	MOVEQ	#1,D4			; 90h: the ID.
	BRA	AxView
AxC2p:	MOVE.B	#3,AxCmd		; A0h: program a byte.
	BRA	AxX
AxC2e:	MOVE.B	#4,AxCmd		; 80h: erase, unlock again.
	BRA	AxX
AxC2b:	AxSec	D5,D4
	MOVE.W	D4,AxBS
	SF	AxDQ7
	LEA	AxBuf,A0		; The buffer blank: FFh programs
	MOVEQ	#256/4-1,D4		; nothing.
AxC2f:	MOVE.L	#-1,(A0)+
	DBF	D4,AxC2f
	MOVE.B	#7,AxCmd
	BRA	AxX

AxC3:	CLR.B	AxCmd			; 3: program the byte.
	AxHost	D5,AxX
	AND.B	D3,(A0)
	MOVE.L	D5,D4
	BRA	AxMark

AxC4:	CMP.B	#$AA,D3			; 4, 5: erase's unlock cycles.
	BNE	AxIdle
	CMP.W	#$AAA,D6
	BNE	AxIdle
	MOVE.B	#5,AxCmd
	BRA	AxX
AxC5:	CMP.B	#$55,D3
	BNE	AxIdle
	CMP.W	#$554,D6
	BNE	AxIdle
	MOVE.B	#6,AxCmd
	BRA	AxX

AxC6:	CLR.B	AxCmd			; 6: 30h sector, 10h chip.
	CMP.B	#$30,D3
	BEQ.S	AxErS
	CMP.B	#$10,D3
	BNE	AxX
	CMP.W	#$AAA,D6		; Chip erase only at AAAh, as the unlock
	BNE	AxX			; cycles (elsewhere: back to reading).
	MOVE.L	MapROMBase1(A3),A0	; The whole chip (as far as the ROM
	MOVE.W	NumROM,D4		; goes).
	SUBQ.W	#1,D4
AxEc1:	MOVE.W	#$2000/4-1,D7
AxEc2:	MOVE.L	#-1,(A0)+
	DBF	D7,AxEc2
	LEA	$80(A0),A0
	DBF	D4,AxEc1
	MOVEQ	#0,D4			; Every 64 KB sector changed.
AxEc3:	MOVE.W	D4,D7
	ADDQ.W	#8,D7
	CMP.W	NumROM,D7
	BHI	AxX
	CMP.W	#64*8,D7
	BHI	AxX
	FLMARK	D4
	ADDQ.W	#8,D4
	BRA.S	AxEc3

AxErS:	ST	AxMore			; Sector erase (D5 in it).
	MOVE.L	D5,D4
	MOVEQ	#1-1,D6
	CMP.L	#$10000,D4
	BCC.S	AxEs0
	AND.W	#$E000,D4		; 8 KB,
	BRA.S	AxEs1
AxEs0:	CLR.W	D4			; or 64 KB.
	MOVEQ	#8-1,D6
AxEs1:	MOVE.L	D4,D7
	LSR.L	#8,D7
	LSR.L	#5,D7
AxEs2:	CMP.W	NumROM,D7
	BCC	AxMark
	MOVE.L	D7,D1
	MULU.W	#$2080,D1
	ADD.L	MapROMBase1(A3),D1
	MOVE.L	D1,A0
	MOVE.W	#$2000/4-1,D1
AxEs3:	MOVE.L	#-1,(A0)+
	DBF	D1,AxEs3
	ADDQ.W	#1,D7
	DBF	D6,AxEs2
	BRA	AxMark

AxC7:	AxSec	D5,D4			; 7: the count - 1, at the sector.
	CMP.W	AxBS,D4
	BNE	AxAbort
	MOVE.W	D3,AxBC
	MOVE.B	#8,AxCmd
	BRA	AxX
AxC8:	AxSec	D5,D4			; 8: the first byte, in the sector:
	CMP.W	AxBS,D4			; its 256-byte page.
	BNE	AxAbort
	MOVE.L	D5,D4
	CLR.B	D4
	MOVE.L	D4,AxBP
	MOVE.B	#9,AxCmd
	BRA.S	AxBd
AxC9:	MOVE.L	D5,D4			; 9: more bytes, in that page.
	CLR.B	D4
	CMP.L	AxBP,D4
	BNE	AxAbort
	SUBQ.W	#1,AxBC
AxBd:	LEA	AxBuf,A0		; Into the buffer (the last write to
	MOVEQ	#0,D4			; a byte wins).
	MOVE.B	D5,D4
	MOVE.B	D3,(A0,D4.W)
	MOVE.B	D3,D4			; DQ7 polls as NOT the last data's.
	NOT.B	D4
	AND.B	#$80,D4
	MOVE.B	D4,AxDQ7
	TST.W	AxBC
	BNE	AxX
	MOVE.B	#10,AxCmd
	BRA	AxX
AxC10:	CMP.B	#$29,D3			; 10: 29h at the sector programs the
	BNE.S	AxAbort			; buffer.
	AxSec	D5,D4
	CMP.W	AxBS,D4
	BNE.S	AxAbort
	CLR.B	AxCmd
	MOVE.L	AxBP,D4
	AxHost	D4,AxX
	LEA	AxBuf,A1
	MOVEQ	#256/4-1,D6
AxB10:	MOVE.L	(A1)+,D7
	AND.L	D7,(A0)+
	DBF	D6,AxB10
	BRA.S	AxMark
AxAbort:CLR.B	AxCmd			; A broken buffer program: status,
	MOVE.B	AxDQ7,D3		; DQ1 (abort) set.
	OR.B	#$02,D3
	MOVEQ	#3,D4
	BRA.S	AxView

; D4 = a flash address: its 64 KB sector changed, for FlashSave (FlSect
; holds 64 sectors, 4 MB; FlashLoad takes whole 64 KB sectors only).
AxMark:	MOVE.L	D4,D7
	LSR.L	#8,D7
	LSR.L	#5,D7
	AND.W	#$FFF8,D7
	ADDQ.W	#8,D7
	CMP.W	NumROM,D7
	BHI	AxX
	CMP.W	#64*8,D7
	BHI	AxX
	SUBQ.W	#8,D7
	FLMARK	D7
	BRA	AxX

; D4 = 1 ID, 2 CFI, 3 status (D3 its byte): fill AxVBuf, show it.
AxView:	MOVE.B	D4,AxMode
	LEA	AxIdT,A1
	CMP.B	#1,D4
	BEQ.S	AxV1
	LEA	AxCfT,A1
	CMP.B	#2,D4
	BEQ.S	AxV1
	LEA	AxStT,A1
	MOVE.L	A1,A2
	MOVE.W	#256-1,D1
AxVs:	MOVE.B	D3,(A2)+
	DBF	D1,AxVs
AxV1:	LEA	AxVBuf+$80,A0		; The 256 bytes over both 8 KB halves.
	MOVEQ	#2-1,D6
AxV2:	MOVEQ	#32-1,D7
AxV3:	MOVE.L	A1,A2
	MOVEQ	#256/4-1,D1
AxV4:	MOVE.L	(A2)+,(A0)+
	DBF	D1,AxV4
	DBF	D7,AxV3
	LEA	$80(A0),A0
	DBF	D6,AxV2
	BRA.S	AxMap

AxRead:	CLR.B	AxMode			; The array again: the banks.

; All four pages of Slot 1: AxVBuf (AxMode set) or the banks (AxB1, AxB2).
AxMap:	SUB.W	(A7),A5
	TST.B	AxMode
	BEQ	AxMp1
	MOVE.L	#AxVBuf+$80,AsxBk
	AsxPg	1,1
	AsxPg	1,3
	AsxPg	1,2
	AsxPg	1,0
	BRA	AxMp2
AxMp1:	MOVE.L	AxB1,AsxBk
	AsxPg	1,1
	AsxPg	1,3
	MOVE.L	AxB2,AsxBk
	AsxPg	1,2
	AsxPg	1,0
AxMp2:	MOVEQ	#0,D1
	MOVE.W	A5,D1
	CogePag	D1,A5

AxX:	MOVEM.L	AxSv,D3-D7/A0-A2
	TST.B	AxOdd			; A bank register write too: on to it.
	BEQ.S	AxX2
	MOVE.W	AxZA,D1
	BRA	AsxS1
AxX2:	MOVEQ	#0,D1
	Otra2

; Autoselect, CFI: what the chip reads at byte address & FFh (openMSX's
; S29GL064S in byte mode: ID bytes repeat every 32; CFI words low byte at
; even addresses, high at odd).
AxIdT:	REPT	4
	DC.B	$01,$01,$7E,$7E,$00,$00,$0A,$0A,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
	DC.B	$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$10,$10,$00,$00
	ENDR
	REPT	4			; (sector protect: with bit 6 of the
	DC.B	$01,$01,$7E,$7E,$FF,$FF,$0A,$0A,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
	DC.B	$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$10,$10,$00,$00
	ENDR				; word address set, undefined)
AxCfT:	DC.B	$01,$00,$7E,$22,$FF,$FF,$0A,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
	DC.B	$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$10,$22,$00,$22
	DC.B	$51,$00,$52,$00,$59,$00,$02,$00,$00,$00,$40,$00,$00,$00,$00,$00
	DC.B	$00,$00,$00,$00,$00,$00,$27,$00,$36,$00,$00,$00,$00,$00,$08,$00
	DC.B	$08,$00,$09,$00,$10,$00,$03,$00,$03,$00,$01,$00,$00,$00,$17,$00
	DC.B	$02,$00,$00,$00,$08,$00,$00,$00,$02,$00,$07,$00,$00,$00,$20,$00
	DC.B	$00,$00,$7E,$00,$00,$00,$00,$00,$01,$00,$00,$00,$00,$00,$00,$00
	DC.B	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF
	DC.B	$50,$00,$52,$00,$49,$00,$31,$00,$33,$00,$20,$00,$02,$00,$01,$00
	DC.B	$00,$00,$08,$00,$00,$00,$00,$00,$02,$00,$B5,$00,$C5,$00,$02,$00
	DC.B	$01,$00
	DCB.B	256-$A2,$FF

	CNOP	0,4
AxB1:	DC.L	0			; the first bank's address (pages 1, 3)
AxB2:	DC.L	0			; the second's (pages 0, 2)
AxN1:	DC.W	0			; their bank numbers (reset: 0 and 1,
AxN2:	DC.W	1			; the Slot 1 set-up)
AxMode:	DC.B	0			; 0 array, 1 ID, 2 CFI, 3 status
AxCmd:	DC.B	0			; command cycle (AxJT)
AxMore:	DC.B	0			; a sector erase takes more 30h
AxOdd:	DC.B	0			; the write sets a bank too
AxBP:	DC.L	0			; buffer program: its page
AxBS:	DC.W	0			; its sector
AxBC:	DC.W	0			; bytes still to come
AxNt:	DC.W	0
AxZA:	DC.W	0			; the Z80 address written
AxDQ7:	DC.B	0			; DQ7 of the buffer's last byte
	EVEN
AxSv:	DS.L	8

	SECTION	AsxFlash,BSS
	CNOP	0,4
AxBuf:	DS.B	256			; buffer program's page
AxStT:	DS.B	256			; the status byte, for AxView
AxVBuf:	DS.B	$4180			; ID / CFI / status page
	SECTION	MSX2,CODE
