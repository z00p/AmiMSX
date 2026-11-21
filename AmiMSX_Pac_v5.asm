;	 --------------------------------------------
;	- The FM-PAC and its battery SRAM (5.3) -
;	 --------------------------------------------
;
; An FM-PAC (Panasoft SW-M004) with its 8 KB of battery SRAM, which games
; use as a save slot ("PAC" saves). Two ways in, one FM-PAC at a time:
; - the cartridge: an FM-PAC ROM in Slot 1, or in Slot 2 (Disk ROM None),
;   found by "AB" and "PAC2OPLL" at 0018h (PacFind). Its ROM is banked by
;   7FF7h (16 KB as AmiMSX 2's "FM Pac.ROM", or 64 KB), its init runs as on
;   the real cartridge, and it brings the OPLL: Sound PSG plays as PSG+FM
;   (SCC and SCC+ stay as they are: AmiMSX plays one of SCC and FM). With
;   it, MSXMUSIC.ROM is not put in an empty Slot 1 or slot 3's RAM. Slot 1
;   is looked at first;
; - built in: with Sound PSG+FM, the user's MSXMUSIC.ROM and Slot 1 empty
;   (no FM-PAC cartridge), Slot 1 holds the ROM (MMusLoad: 16 KB, 'AB'
;   taken away) and the SRAM.
; As the real cartridge (openMSX's MSXFmPac for the behaviour):
; - 5FFEh and 5FFFh are registers: 4Dh in 5FFEh and 69h in 5FFFh map the
;   SRAM at 4000h-5FFDh (read and write), any other value maps the ROM again.
;   With the SRAM in, 5FFEh/5FFFh read 4Dh/69h and 6000h-7FFFh reads FFh;
; - 7FF6h: enable (bits 0 and 4 kept, read back). Bit 4 clears 5FFEh/5FFFh
;   (the SRAM goes) and ignores writes to them while set. Bit 0 switches the
;   cartridge's I/O ports on: not modelled, ports 7Ch/7Dh always work (they
;   are also the machine's own MSX-Music);
; - 7FF7h: the ROM bank (bits 0-1, read back), mirrored over the ROM's size;
; - 7FF4h/7FF5h: the OPLL's register and data, as ports 7Ch/7Dh (whatever
;   the enable bits say);
; - reset: all registers 0, bank 0, the ROM in. Continue keeps them.
; The SRAM is PacSram (the page as read: 1FFEh/1FFFh are the 4Dh/69h read
; back); it is saved to PROGDIR:FMPAC.PAC by the menu (AmiMSX_Saves_v4.asm).
; The pages: SRAM in, page 1's first half reads and writes PacSram (stores of
; any kind land there), its second half reads PacFFB; ROM in, the bank's
; first 8 KB and PacRomB (its upper 8 KB with the 7FF6h/7FF7h read-back),
; writes to NORAM. The register writes reach PacW through the hooked 8-bit
; writes (MapExp, with their cycle costs, or MapMapp with a megaROM) and
; LD (nn),HL (LDMHLd: a word to 5FFEh, as Bun-Ga-Rua writes 694Dh). Not
; hooked, as for the megaROM mappers: the other 16-bit stores, PUSH, LDIR
; and (IX+d) writes.
; Left out with -DNO_PACSRAM=1.

	CNOP	0,4
; PacFind (each run, before the Sound chip is set; all registers kept): an
; FM-PAC cartridge in Slot 1, or else in Slot 2 (only with Disk ROM None,
; when Slot 2 takes cartridges). The rule: "AB" and "PAC2OPLL" at 0018h of
; its first 16 KB, as the FM-PAC's own ROM looks for itself, and 64 KB at
; most (the FM-PAC's ROM: 16 KB as AmiMSX 2's "FM Pac.ROM", or the full 64
; KB). PacCart: its slot (0: none); PacRomBase/PacHiOff/PacNB: its ROM.
PacFind:
	MOVEM.L	D0/A0,-(SP)
	CLR.B	PacCart
	MOVE.L	DirCartS1,A0
	MOVE.L	BucCartS1,D0
	BSR.S	PacIs
	BEQ.S	PacF2
	MOVE.B	#1,PacCart
	MOVE.W	PagCartS1,D0
	BRA.S	PacFS
PacF2:	CMP.B	#2,DIRPREFS+$65		; Disk ROM None: Slot 2's cartridge.
	BNE.S	PacFX
	MOVE.L	DirCartS2,A0
	MOVE.L	BucCartS2,D0
	BSR.S	PacIs
	BEQ.S	PacFX
	MOVE.B	#2,PacCart
	MOVE.W	PagCartS2,D0
PacFS:	TST.W	D0			; 16 KB banks (1 or 4)
	BNE.S	PacFS1
	MOVEQ	#1,D0
PacFS1:	MOVE.W	D0,PacNBC
	ADD.W	#$80,A0
	MOVE.L	A0,PacRomBC
PacFX:	MOVEM.L	(SP)+,D0/A0
	RTS
; A0 = DirCart, D0 = BucCart: Z clear for an FM-PAC.
PacIs:	TST.L	D0
	BEQ.S	PacIsN
	CMP.L	#($2080*8)+$80,D0
	BHI.S	PacIsN
	CMP.W	#"AB",$80(A0)
	BNE.S	PacIsN
	CMP.L	#"PAC2",$80+$18(A0)
	BNE.S	PacIsN
	CMP.L	#"OPLL",$80+$1C(A0)
	BNE.S	PacIsN
	MOVEQ	#1,D0
	RTS
PacIsN:	MOVEQ	#0,D0
	RTS

; PacChk (hooks set-up, each run): which FM-PAC, if any. A cartridge
; (PacFind) wins; else the built-in one, the user's MSXMUSIC.ROM in an
; empty Slot 1 with Sound PSG+FM (MMusLoad, NoSlot1Cart).
PacChk:	SF	PacOn
	MOVE.B	PacCart,PacN
	BEQ.S	PacChk1
	MOVE.L	PacRomBC,PacRomBase
	MOVE.W	#$2080,PacHiOff		; the cartridge's 8 KB pages
	MOVE.W	PacNBC,PacNB
	BRA.S	PacChkY
PacChk1:TST.B	FMXOn
	BEQ.S	PacChkX
	TST.B	MMusOK
	BEQ.S	PacChkX
	TST.L	BucCartS1
	BNE.S	PacChkX
	MOVE.B	#1,PacN
	MOVE.L	#MMusic,PacRomBase
	MOVE.W	#$2000,PacHiOff
	MOVE.W	#1,PacNB
PacChkY:ST	PacOn
	MOVEQ	#0,D0
	MOVE.B	PacN,D0
	LSL.W	#3,D0
	MOVE.W	D0,PacRRO		; the slot's offset in SLOTSR
	LSL.W	#2,D0
	MOVE.W	D0,PacRO		; and in SLOTS and the mapper tables
PacChkX:RTS

; PacSlot (after Slot 2's mapper table, A3 = REGS): the FM-PAC slot's page
; 1 rows and write routines. Power on or reset (or the FM-PAC newly in, or
; in another slot): registers 0, the ROM in; Continue keeps the state. The
; slot that had the FM-PAC in the last run, if it has none now: page 1's
; write rows back to NORAM. Page 2 of the FM-PAC slot is empty (the 64 KB
; ROM as a megaROM); page 0 is left alone (Slot 2: the 4.x Sub ROM).
PacSlot:
	MOVEM.L	D0-D1/A4,-(SP)
	MOVEQ	#0,D0
	MOVE.B	PacLast,D0
	BEQ.S	PacSl0
	TST.B	PacOn
	BEQ.S	PacSlR
	CMP.B	PacN,D0
	BEQ.S	PacSl0
PacSlR:	LSL.W	#5,D0
	MOVE.L	#NORAM-$4000,SLOTS+12(A3,D0.W)
	MOVE.L	#NORAM-$4000,SUBSLOTS+12(A3,D0.W)
PacSl0:	TST.B	PacOn
	BNE.S	PacSl1
	CLR.B	PacLast
	BRA.S	PacSlX
PacSl1:	CMP.L	#BUCLE,DIRCONTI+2
	BEQ.S	PacSl2
	MOVE.B	PacLast,D0
	CMP.B	PacN,D0
	BEQ.S	PacSl3
PacSl2:	BSR	PacReset
PacSl3:	MOVE.B	PacN,PacLast
	MOVE.W	PacRO,D0
	MOVE.L	#NOMEM-$8000,SLOTS+16(A3,D0.W)
	MOVE.L	#NOMEM-$8000,SUBSLOTS+16(A3,D0.W)
	LEA	$640(A3,D0.W),A4	; the slot's write routines
	MOVEQ	#8-1,D1
PacSl4:	MOVE.L	#OtraInstr,(A4)+
	DBF	D1,PacSl4
	MOVE.L	#PacWA,$640+(2*4)(A3,D0.W)
	MOVE.L	#PacWB,$640+(3*4)(A3,D0.W)
	BSR	PacRows
PacSlX:	MOVEM.L	(SP)+,D0-D1/A4
	RTS

; PacRegs: the enable and bank registers' read-back at 7FF6h/7FF7h.
PacRegs	MACRO
	MOVE.B	PacEn,PacRomB+$1FF6
	MOVE.B	PacBank,PacRomB+$1FF7
	MOVE.B	PacEn,PacFFB+$1FF6
	MOVE.B	PacBank,PacFFB+$1FF7
	ENDM

PacReset:
	MOVEM.L	D0/A0-A2,-(SP)
	CLR.B	PacEn
	CLR.B	PacBank
	CLR.W	PacBnk
	CLR.B	PacR1FFE
	CLR.B	PacR1FFF
	SF	PacSramOn
	SF	PacWord
	MOVE.L	PacRomBase,A0		; bank 0
	MOVE.L	A0,PacRomLo
	ADD.W	PacHiOff,A0		; ROM 6000h-7FFFh; FFh for the SRAM's.
	LEA	PacRomB,A1
	LEA	PacFFB,A2
	MOVE.W	#($2000/4)-1,D0
PacRs1:	MOVE.L	(A0)+,(A1)+
	MOVE.L	#-1,(A2)+
	DBF	D0,PacRs1
	PacRegs
	MOVEM.L	(SP)+,D0/A0-A2
	RTS

; PacRows: the FM-PAC slot's page 1 rows for the state (A3 = REGS). D1 and
; A4 trashed (no D0: it is the Z80's SP in the emulation; no stack: PacW
; calls it at its one call level).
PacRows:MOVE.W	PacRO,A4
	TST.B	PacSramOn
	BEQ.S	PacRw1
	MOVE.W	#$4D69,PacSram+$1FFE	; 5FFEh/5FFFh read back.
	MOVE.L	#PacSram-$4000,D1
	MOVE.L	D1,SLOTS+8(A3,A4.W)
	MOVE.L	D1,SLOTS+12(A3,A4.W)
	MOVE.L	#PacFFB-$6000,D1
	BRA.S	PacRw2
PacRw1:	MOVE.L	PacRomLo,D1		; the ROM's bank
	SUB.L	#$4000,D1
	MOVE.L	D1,SLOTS+8(A3,A4.W)
	MOVE.L	#NORAM-$4000,SLOTS+12(A3,A4.W)
	MOVE.L	#PacRomB-$6000,D1
PacRw2:	MOVE.L	D1,SUBSLOTS+8(A3,A4.W)
	MOVE.L	#NORAM-$4000,SUBSLOTS+12(A3,A4.W)
	MOVE.W	SLOTS+10(A3,A4.W),D1
	SWAP	D1
	MOVE.W	SUBSLOTS+10(A3,A4.W),D1
	MOVE.W	PacRRO,A4
	MOVE.W	D1,SUBSLOTSR+2(A3,A4.W)
	SWAP	D1
	MOVE.W	D1,SLOTSR+2(A3,A4.W)
	RTS

; PagRuts entries for page 1 of the FM-PAC slot (a hooked write: A4 = the byte
; written; PacWord: LDMHLd's word, A4+1 the second byte). Only 5FFDh-5FFFh
; and 7FF3h-7FF7h matter; the SRAM's bytes are already in PacSram. A change
; of the mapping rebuilds the pages (OUTA8, as ExpFFFF). One call level at
; most: A7 is the page's Restas entry, and a second return address would
; land on the entry below it.
	CNOP	0,4
PacWA:	MOVE.L	A4,D1
	SUB.L	PagWrite+8(A3),D1
	BRA.S	PacW
PacWB:	MOVE.L	A4,D1
	SUB.L	PagWrite+12(A3),D1
PacW:	CMP.W	#$5FFD,D1
	BCS	PacWX0
	CMP.W	#$6000,D1
	BCS.S	PacW1
	CMP.W	#$7FF3,D1
	BCS	PacWX0
	CMP.W	#$7FF8,D1
	BCC	PacWX0
PacW1:	MOVE.L	D3,PacSv
	SF	PacChg
	MOVE.W	D1,PacAdr
	MOVE.L	A4,PacPtr
PacWL:	MOVE.W	PacAdr,D1		; A byte: D1.W = the address, D3 = the
	MOVE.L	PacPtr,A4		; value.
	MOVE.B	(A4),D3
	CMP.W	#$5FFE,D1
	BEQ	PacB1E
	CMP.W	#$5FFF,D1
	BEQ	PacB1F
	CMP.W	#$7FF4,D1
	BEQ	PacBRg
	CMP.W	#$7FF5,D1
	BEQ	PacBDt
	CMP.W	#$7FF6,D1
	BEQ	PacBEn
	CMP.W	#$7FF7,D1
	BNE	PacBX
	AND.B	#3,D3			; 7FF7h: the bank (read back as written,
	MOVE.B	D3,PacBank		; the ROM's 16 KB banks mirrored).
	MOVEQ	#0,D1
	MOVE.B	D3,D1
	DIVU.W	PacNB,D1
	SWAP	D1
	CMP.W	PacBnk,D1
	BEQ.S	PacBk2
	MOVE.W	D1,PacBnk		; another bank: its 4000h-5FFFh in the
	MULU.W	#$4100,D1		; rows, its 6000h-7FFFh in PacRomB.
	ADD.L	PacRomBase,D1
	MOVE.L	D1,PacRomLo
	MOVE.L	D1,A4
	ADD.W	PacHiOff,A4
	MOVEQ	#0,D1
PacBk1:	MOVE.L	(A4)+,(PacRomB.L,D1.L)
	ADDQ.W	#4,D1
	CMP.W	#$2000,D1
	BNE.S	PacBk1
	ST	PacChg
PacBk2:	PacRegs
	BRA	PacBX
PacBEn:	AND.B	#$11,D3			; 7FF6h: the enable bits.
	MOVE.B	D3,PacEn
	PacRegs
	BTST	#4,D3
	BEQ	PacBX
	CLR.B	PacR1FFE		; bit 4: 5FFEh/5FFFh cleared.
	CLR.B	PacR1FFF
	BRA.S	PacBCk
PacBRg:	MOVE.B	D3,D1			; 7FF4h/7FF5h: the OPLL, as OUT 7Ch/7Dh
	JSR	OUT7C			; (they trash D1, D2.B and A4).
	BRA.S	PacBX
PacBDt:	MOVE.B	D3,D1
	JSR	OUT7D
	BRA.S	PacBX
PacB1E:	BTST	#4,PacEn
	BNE.S	PacBX
	MOVE.B	D3,PacR1FFE
	BRA.S	PacBCk
PacB1F:	BTST	#4,PacEn
	BNE.S	PacBX
	MOVE.B	D3,PacR1FFF
PacBCk:	SF	D3			; SRAM in: 4Dh and 69h.
	CMP.B	#$4D,PacR1FFE
	BNE.S	PacBC1
	CMP.B	#$69,PacR1FFF
	SEQ	D3
PacBC1:	CMP.B	PacSramOn,D3
	BEQ.S	PacBX
	MOVE.B	D3,PacSramOn
	ST	PacChg
PacBX:	TST.B	PacWord			; LDMHLd: the second byte.
	BEQ.S	PacW2
	SF	PacWord
	ADDQ.W	#1,PacAdr
	ADDQ.L	#1,PacPtr
	BRA	PacWL
PacW2:	MOVE.L	PacSv,D3
	TST.B	PacChg
	BEQ.S	PacWX
	BSR	PacRows
	MOVE.B	DA8(A3),D1
	JSR	OUTA8			; pages rebuilt (same frame as an OUT)
PacWX:	MOVEQ	#0,D1
	Otra2
PacWX0:	SF	PacWord
	MOVEQ	#0,D1
	Otra2

; LD (nn),HL with the FM-PAC in: as LDMHL (MLDRR mode 9), with its cycles
; (R800: 6 + 1), then PacW when the word lands in the FM-PAC's page.
PacCost	MACRO
	IFD	R8SITE
	R8SUB	17,7,D2
	MOVE.W	#$0100,D2
	ELSE
	SUB.W	#17,(A3)
	ENDC
	ENDM

	CNOP	0,4
LDMHLd:	MOVE.W	(A5)+,D1
	TST.B	D1
	BNE.S	LDMHd1
	CheckW	D1
LDMHd1:	ROR.W	#8,D1
	MOVE.W	D1,PacLdA
	MOVE.L	D1,A4
	ADDQ.B	#1,D1
	BEQ.S	LDMHdD
	CogePagE2 D1,A4
	MOVE.W	D4,D1
	ROR.W	#8,D1
	MOVE.W	D1,(A4)
	PacCost
	MOVE.W	PacLdA,D1
	LSR.W	#8,D1
	LSR.B	#5,D1
	MOVE.L	(PagRuts.L,D1.W*4),A4
	CMP.L	#PacWA,A4
	BEQ.S	LDMHdP
	CMP.L	#PacWB,A4
	BNE.S	LDMHdX
LDMHdP:	MOVE.L	PagWrite(A3,D1.W*4),A4
	MOVEQ	#0,D1
	MOVE.W	PacLdA,D1
	ADD.L	D1,A4
	ST	PacWord
	BRA	PacW
LDMHdD:	SWAP	D0			; xxFFh: two bytes, two pages maybe
	MOVE.W	A4,D0			; (not hooked).
	MOVE.W	D0,D1
	CogePagE2 D1,A4
	MOVE.W	D0,D1
	ADDQ.W	#1,D1
	MOVE.W	D4,D0
	MOVE.B	D0,(A4)
	CogePagE D1,A4
	LSR.W	#8,D0
	MOVE.B	D0,(A4)
	SWAP	D0
	PacCost
LDMHdX:	MOVEQ	#0,D1
	Otra2

PacSv:		DC.L	0
PacPtr:		DC.L	0
PacAdr:		DC.W	0
PacLdA:		DC.W	0		; LDMHLd's address
PacRomBase:	DC.L	0		; the ROM's bank 0, first 8 KB (PacChk)
PacRomLo:	DC.L	0		; the bank in, first 8 KB
PacRomBC:	DC.L	0		; (PacFind: the cartridge's)
PacHiOff:	DC.W	0		; a bank's second 8 KB: + this
PacNB:		DC.W	0		; the ROM's 16 KB banks
PacNBC:		DC.W	0		; (PacFind: the cartridge's)
PacBnk:		DC.W	0		; the bank in (7FF7h mod PacNB)
PacRO:		DC.W	0		; the slot * 32 (SLOTS, mapper tables)
PacRRO:		DC.W	0		; the slot * 8 (SLOTSR)
PacCart:	DC.B	0		; an FM-PAC cartridge's slot (PacFind)
PacN:		DC.B	0		; the FM-PAC's slot (PacChk)
PacOn:		DC.B	0		; there is an FM-PAC (PacChk)
PacLast:	DC.B	0		; its slot in the last run (0: none)
PacEn:		DC.B	0		; 7FF6h
PacBank:	DC.B	0		; 7FF7h
PacR1FFE:	DC.B	0		; 5FFEh
PacR1FFF:	DC.B	0		; 5FFFh
PacSramOn:	DC.B	0		; the SRAM at 4000h-5FFDh
PacChg:		DC.B	0		; (PacW: the mapping changed)
PacWord:	DC.B	0		; (LDMHLd: two bytes written)
	EVEN
