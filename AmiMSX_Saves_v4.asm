;	 ------------------------------------------------------
;	- Saving flash cartridges and drive B (4.0) -
;	 ------------------------------------------------------
;
; Flash Konami SCC cartridges (Pampas & Selene): the emulation marks the
; 64 KB sectors a game erases or programs (FlSect, a bit per sector, and
; FlDirty). Back in the menu, FlashSave writes those sectors to
; "<cartridge>.flash" next to the ROM (the ROM file is never changed);
; inserting the cartridge in Slot 1 again (FlashLoad) reads them back in.
; File: "AMXF", count.W, 0.W, then per sector: number.W, 0.W, 64 KB.
;
; Drive B's virtual disk: written back to its image file when a game has
; written to it, on the way back to the menu (as a real disk keeps what was
; written to it). Drive A keeps its own rules (MVD: the quit requester).

	CNOP	0,4
FlashLoad:				; (InsertSl1, after the load)
	MOVEM.L	D0-D7/A0-A6,-(SP)
	CLR.L	FlSect
	CLR.L	FlSect+4
	SF	FlDirty
	CLR.B	CartPathS1
	TST.B	CartLoadOK
	BEQ	FlLdX
	LEA	FILENOM,A0		; The cartridge's file, for FlashSave.
	LEA	CartPathS1,A1
	MOVE.W	#250-1,D0
FlLdCp:	MOVE.B	(A0)+,(A1)+
	DBEQ	D0,FlLdCp
	CLR.B	(A1)
	MOVE.W	PagCartS1,D0		; Flash cartridges only (over 512 KB).
	ADD.W	D0,D0
	MOVE.W	D0,FlBanks
	CMP.W	#64,D0
	BLS	FlLdX
	BSR	FlName
	MOVE.L	#FlNameBuf,D1
	MOVE.L	#$3ED,D2
	JSR	OPENFILE
	BEQ	FlLdX
	MOVE.L	#FlHdr,D2
	MOVEQ	#8,D3
	JSR	READFILE
	BNE	FlLdC
	CMP.L	#"AMXF",FlHdr
	BNE	FlLdC
	MOVE.W	FlHdr+4,D7		; sectors
	BRA	FlLdS2
FlLdS1:	MOVE.L	#FlHdr,D2
	MOVEQ	#4,D3
	JSR	READFILE
	BNE	FlLdC
	MOVEQ	#0,D6
	MOVE.W	FlHdr,D6		; sector
	MOVE.W	D6,D0
	ADDQ.W	#1,D0
	LSL.W	#3,D0
	CMP.W	FlBanks,D0
	BHI	FlLdC
	MOVEQ	#0,D5			; bank of the sector
FlLdB:	MOVE.L	D6,D0
	LSL.L	#3,D0
	ADD.L	D5,D0
	MULU.L	#$2080,D0
	ADD.L	DirCartS1,D0
	ADD.L	#$80,D0
	MOVE.L	D0,D2
	MOVE.L	#$2000,D3
	JSR	READFILE
	BNE	FlLdC
	ADDQ.W	#1,D5
	CMP.W	#8,D5
	BNE.S	FlLdB
	BFSET	FlSect{D6:1}		; (saved again with later changes)
FlLdS2:	DBF	D7,FlLdS1
FlLdC:	JSR	CLOSEFILE
FlLdX:	MOVEM.L	(SP)+,D0-D7/A0-A6
	RTS

	CNOP	0,4
FlashSave:				; (back from the emulation)
	TST.B	FlDirty
	BEQ	FlSvR
	TST.B	CartPathS1
	BEQ	FlSvR
	MOVEM.L	D0-D7/A0-A6,-(SP)
	SF	FlDirty
	MOVEQ	#0,D6			; Count the marked sectors.
	MOVEQ	#0,D7
FlSvC:	BFTST	FlSect{D6:1}
	BEQ.S	FlSvC1
	ADDQ.W	#1,D7
FlSvC1:	ADDQ.W	#1,D6
	CMP.W	#64,D6
	BNE.S	FlSvC
	TST.W	D7
	BEQ	FlSvX
	BSR	FlName
	MOVE.L	#FlNameBuf,D1
	MOVE.L	#$3EE,D2
	JSR	OPENFILE
	BEQ	FlSvX
	MOVE.L	#"AMXF",FlHdr
	MOVE.W	D7,FlHdr+4
	CLR.W	FlHdr+6
	MOVE.L	#FlHdr,D2
	MOVEQ	#8,D3
	JSR	WRITEFILE
	MOVEQ	#0,D6
FlSvS:	BFTST	FlSect{D6:1}
	BEQ.S	FlSvS2
	MOVE.W	D6,FlHdr
	CLR.W	FlHdr+2
	MOVE.L	#FlHdr,D2
	MOVEQ	#4,D3
	JSR	WRITEFILE
	MOVEQ	#0,D5
FlSvB:	MOVE.L	D6,D0
	LSL.L	#3,D0
	ADD.L	D5,D0
	MULU.L	#$2080,D0
	ADD.L	DirCartS1,D0
	ADD.L	#$80,D0
	MOVE.L	D0,D2
	MOVE.L	#$2000,D3
	JSR	WRITEFILE
	ADDQ.W	#1,D5
	CMP.W	#8,D5
	BNE.S	FlSvB
FlSvS2:	ADDQ.W	#1,D6
	CMP.W	#64,D6
	BNE.S	FlSvS
	JSR	CLOSEFILE
FlSvX:	MOVEM.L	(SP)+,D0-D7/A0-A6
FlSvR:	RTS

; FlNameBuf = CartPathS1 + ".flash"
FlName:	LEA	CartPathS1,A0
	LEA	FlNameBuf,A1
FlNm1:	MOVE.B	(A0)+,(A1)+
	BNE.S	FlNm1
	SUBQ.L	#1,A1
	LEA	FlExt,A0
FlNm2:	MOVE.B	(A0)+,(A1)+
	BNE.S	FlNm2
	RTS

	CNOP	0,4
DiskBSave:				; (back from the emulation)
	TST.B	DskDirtyB
	BEQ.S	DkBSvR
	TST.L	DIRFILEB
	BEQ.S	DkBSvR
	TST.B	DISKBNOM
	BEQ.S	DkBSvR
	MOVEM.L	D0-D7/A0-A6,-(SP)
	SF	DskDirtyB
	MOVE.L	#DISKBNOM,D1
	MOVE.L	#$3EE,D2
	JSR	OPENFILE
	BEQ.S	DkBSvX
	MOVE.L	DIRFILEB,D2
	MOVE.L	DskBSize,D3
	JSR	WRITEFILE
	JSR	CLOSEFILE
DkBSvX:	MOVEM.L	(SP)+,D0-D7/A0-A6
DkBSvR:	RTS

	CNOP	0,4
FlHdr:		DS.L	2
DskBSize:	DC.L	0		; drive B's image size (LoadDiskB)
FlBanks:	DC.W	0
CartPathS1:	DS.B	256		; the Slot 1 cartridge's file
FlNameBuf:	DS.B	264
FlExt:		DC.B	".flash",0
	EVEN
