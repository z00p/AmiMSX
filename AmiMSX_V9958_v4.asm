; =========================================================================
; (4.0) V9958 phase 2, step 2: wide SCREEN 5 plane layouts, so R#26 (coarse
; horizontal scroll) wraps a row without a seam and SP2 (R#25 bit 0 with
; R#2 bit 5) shows the 512-dot two-page line. Docs/msx2plus_phase2.md.
;
; PlMode (the layout the SCR0 planes hold):
;   0: 32-byte rows, 32 KB planes (MSX2, ECS, and SCREEN 7 always).
;   1: 64-byte rows: the row then a copy of it (R#26 wraps at 256 dots).
;   2: 128-byte page-pair rows: even page row, odd page row, then the two
;      again (SP2: the line is even|odd and wraps at 512 dots).
; In 1 and 2 the planes are 64 KB (PLSZW), the mask plane is SCR0-$10000
; (MASK), TMASK before it. Every writer writes the row and its copy; every
; reader reads the first copy. VDP commands run on the blitter as rows of
; PlCopyW bytes with twice the height (the copy is the next "half-row"),
; see CALCULAR/COPIA.
; Only the MSX2+ machine on AGA with "Refresh 100% Graphics" (planes can be
; rebuilt from VRAM) uses 1 and 2: V9Scr5, ModoGfx5, PRINT5.
; =========================================================================

PLSZW=64*1024				; Plane size in layouts 1 and 2.

PlMode:		DC.B	0
PlWant:		DC.B	0		; Layout the frames ask for (PRINT5).
Sp2Cnt:		DC.B	0		; Frames PlWant has differed from PlMode.
		EVEN
PlCopyW:	DC.W	32		; Copy distance (the blitter half-row).
PlStrideW:	DC.W	32		; Row stride.
PlSkipW:	DC.W	0		; Stride - 32: after a row's 16 words.
PlStr2W:	DC.W	64		; Two rows.
PlSizeL:	DC.L	64*512		; Plane size.
PlCnt:		DC.W	0		; Loop counters (no free registers).
PlRows:		DC.W	0
PlTab:	DC.W	32,32,0,64		; PlCopyW, PlStrideW, PlSkipW, PlStr2W,
	DC.L	64*512			; PlSizeL: layout 0,
	DC.W	32,64,32,128
	DC.L	PLSZW			; 1,
	DC.W	64,128,96,256
	DC.L	PLSZW			; 2.

; PlSet: D0.B = layout -> PlMode and the constants above. Uses A0, D1.
PlSet:
	MOVE.B	D0,PlMode
	MOVEQ	#0,D1
	MOVE.B	D0,D1
	MULU	#12,D1
	LEA	(PlTab.L,D1.W),A0
	MOVE.L	(A0)+,PlCopyW		; PlCopyW, PlStrideW
	MOVE.L	(A0)+,PlSkipW		; PlSkipW, PlStr2W
	MOVE.L	(A0)+,PlSizeL
	RTS

; PlRowOff: D0.L = VRAM line (0-1023) -> D0.L = byte offset in a plane of
; the line's first copy (layout 2: +32 for an odd page). The PLROWOFF macro
; (main source, by the other macros) does it inline with no stack and no
; other register: the Z80 core's A7 is the Restas table, with room for one
; return address only, so the VDP command engine and the conversions it
; calls use the macro. This subroutine is for the frame-level callers
; (ActCopperLine, PRINT5, MSplitFill, PlAddrOff), where A7 is a stack.
PlRowOff:
	PLROWOFF	D0
	RTS
BltSzTmp:	DC.L	0		; BLTSZ's D4 (no stack in the engine).
LmmcSv:		DC.L	0,0,0		; LMMC/HMMC start: D0, D0-D1 saves.
LineSv0:	DC.L	0		; LINE: D0 across PLROWOFF.
PlBufSv:	DS.L	16		; Pl5Frame: the Z80 registers in BUFER.

; -------------------------------------------------------------------------
; Port 98h writes (DREGOUT98 in SCREEN 5): OUT98A with the wide layouts.
; D1.B = value, A2 = VRAM pointer; D1/A4 scratch, D0's high word scratch.
; The bit offset of VRAM byte a (2 pixels) in a plane:
;   layout 1: 2*(a + (a & ~127))             (row*512 + column*2)
;   layout 2: (a & $7F80)<<3 + (a & $10000)<<2 + (a & $8000)>>7 + (a & $7F)<<1
; and the copy 256 (layout 1) or 512 (layout 2) bits on: BFINS twice.
; -------------------------------------------------------------------------
	CNOP	0,8
OUT98WT:				; (During a mode split: the SCREEN 4
	MOVE.B	D1,D2			; cache's dirty flags too, as OUT98AT.)
	MOVE.L	A2,D1
	SUB.L	#DIRVRAM,D1
	TST.B	D1
	BNE.S	CRAM98WT
	AND.L	#$1FFFF,D1
	LEA	(DIRVRAM.L,D1.L),A2
	MOVE.L	A2,D1
	SUB.L	#DIRVRAM,D1
CRAM98WT:
	ROR.L	#3,D1
	ST	(TAB98-REGS.W,A3,D1.W)
	ST	(TAB98B-REGS.W,A3,D1.W)
	ROL.L	#3,D1
	CMP.L	SCRTLo,D1
	BCS	CRAM98W
	CMP.L	SCRTHi,D1
	BCC	CRAM98W
	ST	SCRTDirty
	BRA	CRAM98W

	CNOP	0,8
OUT98W:					; Layout 1.
	MOVE.B	D1,D2
	MOVE.L	A2,D1
	SUB.L	#DIRVRAM,D1
	TST.B	D1
	BEQ.S	VRAM98W
CRAM98W:MOVE.B	D2,(A2)+
	MOVE.L	D1,A4
	AND.L	#$1FF80,D1
	ADD.L	A4,D1
	ADD.L	D1,D1
	MOVE.W	(TABOUTSC5-$200.L,D2.W*2),D2
	BFINS	D2,SCR0+(PLSZW*3){D1:2}
	BFINS	D2,SCR0+(PLSZW*3)+32{D1:2}
	LSR.W	#2,D2
	BFINS	D2,SCR0+(PLSZW*2){D1:2}
	BFINS	D2,SCR0+(PLSZW*2)+32{D1:2}
	LSR.B	#2,D2
	BFINS	D2,SCR0+PLSZW{D1:2}
	BFINS	D2,SCR0+PLSZW+32{D1:2}
	LSR.B	#2,D2
	BFINS	D2,SCR0{D1:2}
	BFINS	D2,SCR0+32{D1:2}
	LSR.B	#2,D2
	BFINS	D2,SCR0-PLSZW{D1:2}
	BFINS	D2,SCR0-PLSZW+32{D1:2}
	MOVEQ	#0,D1
	RTS
VRAM98W:
	AND.L	#$1FFFF,D1
	LEA	(DIRVRAM.L,D1.L),A2
	MOVE.L	A2,D1
	SUB.L	#DIRVRAM,D1
	BRA	CRAM98W

	CNOP	0,8
OUT98PT:
	MOVE.B	D1,D2
	MOVE.L	A2,D1
	SUB.L	#DIRVRAM,D1
	TST.B	D1
	BNE.S	CRAM98PT
	AND.L	#$1FFFF,D1
	LEA	(DIRVRAM.L,D1.L),A2
	MOVE.L	A2,D1
	SUB.L	#DIRVRAM,D1
CRAM98PT:
	ROR.L	#3,D1
	ST	(TAB98-REGS.W,A3,D1.W)
	ST	(TAB98B-REGS.W,A3,D1.W)
	ROL.L	#3,D1
	CMP.L	SCRTLo,D1
	BCS	CRAM98P
	CMP.L	SCRTHi,D1
	BCC	CRAM98P
	ST	SCRTDirty
	BRA	CRAM98P

	CNOP	0,8
OUT98P:					; Layout 2.
	MOVE.B	D1,D2
	MOVE.L	A2,D1
	SUB.L	#DIRVRAM,D1
	TST.B	D1
	BEQ	VRAM98P
CRAM98P:MOVE.B	D2,(A2)+
	MOVE.L	D1,A4			; a
	SWAP	D0
	MOVE.W	D1,D0
	AND.W	#$7F,D0
	ADD.W	D0,D0			; column*2
	AND.L	#$1FF80,D1		; line<<7 | page bits 15-16
	BCLR	#15,D1
	BEQ.S	CRAM98P0
	ADD.W	#256,D0			; odd page: the copy's 32 bytes in
CRAM98P0:
	BCLR	#16,D1
	BEQ.S	CRAM98P1
	LSL.L	#3,D1			; line*1024
	ADD.L	#$40000,D1		; pair 1: 256 rows of 128 bytes
	BRA.S	CRAM98P2
CRAM98P1:
	LSL.L	#3,D1
CRAM98P2:
	MOVEA.W	D0,A4
	ADD.L	A4,D1
	SWAP	D0
	MOVE.W	(TABOUTSC5-$200.L,D2.W*2),D2
	BFINS	D2,SCR0+(PLSZW*3){D1:2}
	BFINS	D2,SCR0+(PLSZW*3)+64{D1:2}
	LSR.W	#2,D2
	BFINS	D2,SCR0+(PLSZW*2){D1:2}
	BFINS	D2,SCR0+(PLSZW*2)+64{D1:2}
	LSR.B	#2,D2
	BFINS	D2,SCR0+PLSZW{D1:2}
	BFINS	D2,SCR0+PLSZW+64{D1:2}
	LSR.B	#2,D2
	BFINS	D2,SCR0{D1:2}
	BFINS	D2,SCR0+64{D1:2}
	LSR.B	#2,D2
	BFINS	D2,SCR0-PLSZW{D1:2}
	BFINS	D2,SCR0-PLSZW+64{D1:2}
	MOVEQ	#0,D1
	RTS
VRAM98P:
	AND.L	#$1FFFF,D1
	LEA	(DIRVRAM.L,D1.L),A2
	MOVE.L	A2,D1
	SUB.L	#DIRVRAM,D1
	BRA	CRAM98P

; -------------------------------------------------------------------------
; Port 98h reads and POINT (DREGIN98, descriptor $24): IN98A/POINTA with the
; wide layouts. In: D1 = VRAM address (POINTx) or A2 (IN98x). Out: D1.B =
; the byte, from the planes' first copy. DARBITW reads the four planes.
; -------------------------------------------------------------------------
DARBITW:MACRO
	MOVE.B	-(A4),D2
	LSL.B	#\1+1,D2
	ROXR.B	#4,D1
	ADD.B	D2,D2
	ROXR.B	#4,D1
	SUBA.L	#PLSZW-1,A4
	MOVE.B	-(A4),D2
	LSL.B	#\1+1,D2
	ROXR.B	#4,D1
	ADD.B	D2,D2
	ROXR.B	#4,D1
	SUBA.L	#PLSZW-1,A4
	MOVE.B	-(A4),D2
	LSL.B	#\1+1,D2
	ROXR.B	#4,D1
	ADD.B	D2,D2
	ROXR.B	#4,D1
	SUBA.L	#PLSZW-1,A4
	MOVE.B	-(A4),D2
	LSL.B	#\1+1,D2
	ROXR.B	#4,D1
	ADD.B	D2,D2
	ROXR.B	#4,D1
	ROL.B	#4,D1
	ENDM

	CNOP	0,8
IN98W:
	MOVE.L	A2,D1
	SUB.L	#DIRVRAM,D1
	TST.B	D1
	BNE.S	IVRAM98W
	AND.L	#$1FFFF,D1
	LEA	(DIRVRAM.L,D1.L),A2
IVRAM98W:
	ADDQ.W	#1,A2
POINTW:					; Layout 1: X = a + (a & ~127);
	MOVE.L	D1,A4			; X>>2 is the plane byte, X&3 the pixel
	AND.L	#$1FF80,D1		; pair, as POINTA.
	ADD.L	A4,D1
POINTWX:
	MOVE.L	D1,A4
	LSR.L	#2,D1
	ADD.L	#SCR0+1+(PLSZW*3),D1
	EXG	D1,A4			; A4: plane 3, D1: X
	ROR.L	#2,D1
	LSL.L	#1,D1
	BCS	IN98CONW
	BMI.S	IN98W2
	DARBITW	0
	RTS
IN98W2:
	MOVEQ	#0,D1
	DARBITW	2
	RTS
IN98CONW:
	BMI.S	IN98W4
	DARBITW	4
	RTS
IN98W4:
	MOVEQ	#0,D1
	DARBITW	6
	RTS

	CNOP	0,8
IN98P:
	MOVE.L	A2,D1
	SUB.L	#DIRVRAM,D1
	TST.B	D1
	BNE.S	IVRAM98P
	AND.L	#$1FFFF,D1
	LEA	(DIRVRAM.L,D1.L),A2
IVRAM98P:
	ADDQ.W	#1,A2
POINTP:					; Layout 2: X = (a&$7F80)<<2 +
	MOVE.L	D1,A4			; (a&$10000)<<1 + (a&$8000)>>8 + (a&$7F).
	SWAP	D0
	MOVE.W	D1,D0
	AND.W	#$7F,D0
	AND.L	#$7F80,D1
	LSL.L	#2,D1
	ADD.W	D0,D1
	MOVE.W	A4,D0
	AND.W	#$8000,D0
	LSR.W	#8,D0
	ADD.W	D0,D1
	SWAP	D0
	CMPA.L	#$10000,A4
	BCS	POINTWX
	ADD.L	#$20000,D1
	BRA	POINTWX

; -------------------------------------------------------------------------
; VRAM -> planes, one 1 KB block (8 lines) in layouts 1 and 2 (ActPlanos5:
; ActPlaBlk). In: A0/A1/A2/A5 the planes at the block's first row, A4 the
; VRAM; PlRows = 8. C2PTab as PU4_BUC, each word written to the row and
; its copy (D7 = PlCopyW). Returns through ActPRet.
; -------------------------------------------------------------------------
	CNOP	0,4
PU4W_ROW:
	MOVE.W	#16,PlCnt
	MOVE.W	PlCopyW,D7
PU4W_BUC:
	MOVEQ	#0,D6
	MOVE.B	(A4)+,D6
	MOVE.L	(C2PTab.L,D6.W*4),D4
	LSL.L	#6,D4
	MOVE.B	(A4)+,D6
	MOVE.L	(C2PTab.L,D6.W*4),D5
	LSL.L	#4,D5
	OR.L	D5,D4
	MOVE.B	(A4)+,D6
	MOVE.L	(C2PTab.L,D6.W*4),D5
	ADD.L	D5,D5
	ADD.L	D5,D5
	OR.L	D5,D4
	MOVE.B	(A4)+,D6
	OR.L	(C2PTab.L,D6.W*4),D4
	MOVE.B	(A4)+,D6
	MOVE.L	(C2PTab.L,D6.W*4),D5
	LSL.L	#6,D5
	MOVE.B	(A4)+,D6
	MOVE.L	(C2PTab.L,D6.W*4),D3
	LSL.L	#4,D3
	OR.L	D3,D5
	MOVE.B	(A4)+,D6
	MOVE.L	(C2PTab.L,D6.W*4),D3
	ADD.L	D3,D3
	ADD.L	D3,D3
	OR.L	D3,D5
	MOVE.B	(A4)+,D6
	OR.L	(C2PTab.L,D6.W*4),D5
	MOVE.W	D4,D0
	LSL.W	#8,D0
	MOVE.B	D5,D0
	MOVE.W	D0,(A0)
	MOVE.W	D0,(A0,D7.W)
	ADDQ.W	#2,A0
	LSR.L	#8,D4
	LSR.L	#8,D5
	MOVE.W	D4,D0
	LSL.W	#8,D0
	MOVE.B	D5,D0
	MOVE.W	D0,(A1)
	MOVE.W	D0,(A1,D7.W)
	ADDQ.W	#2,A1
	LSR.L	#8,D4
	LSR.L	#8,D5
	MOVE.W	D4,D0
	LSL.W	#8,D0
	MOVE.B	D5,D0
	MOVE.W	D0,(A2)
	MOVE.W	D0,(A2,D7.W)
	ADDQ.W	#2,A2
	LSR.L	#8,D4
	LSR.L	#8,D5
	MOVE.W	D4,D0
	LSL.W	#8,D0
	MOVE.B	D5,D0
	MOVE.W	D0,(A5)
	MOVE.W	D0,(A5,D7.W)
	ADDQ.W	#2,A5
	SUBQ.W	#1,PlCnt
	BNE	PU4W_BUC
	ADDA.W	PlSkipW,A0
	ADDA.W	PlSkipW,A1
	ADDA.W	PlSkipW,A2
	ADDA.W	PlSkipW,A5
	SUBQ.W	#1,PlRows
	BNE	PU4W_ROW
	JMP	([ActPRet.L])

; ActPlaBlk's wide case: A6.W = block (0-127). Sets up the planes and jumps
; to PU4W_ROW. Stack: PlRowOff.
ActPlaBlkW:				; (No BSR: ActPlanos5 is a handler's
	MOVE.L	A6,D0			; first-level call, as PU4_BUC says.)
	LSL.L	#3,D0			; 8 lines a block
	PLROWOFF	D0
	LEA	(SCR0.L,D0.L),A0
	LEA	(SCR0+PLSZW,D0.L),A1
	LEA	(SCR0+(PLSZW*2),D0.L),A2
	LEA	(SCR0+(PLSZW*3),D0.L),A5
	MOVE.L	A6,D7
	MOVEQ	#10,D0
	LSL.L	D0,D7
	LEA	(DIRVRAM.L,D7.L),A4
	MOVE.W	#8,PlRows
	MOVE.L	#ActPlaNx,ActPRet
	BRA	PU4W_ROW

; -------------------------------------------------------------------------
; Planes -> VRAM, one 16-line band in layouts 1 and 2 (ModoChg5a0: the bands
; VDP commands drew in). In: D0.W = band (0-63). P2CTab as P4_BUC, reading
; the first copy. Entered by JMP and leaves by JMP to P5BandN: ModoChg5a0 is
; itself a handler's first-level call (no second level on the Restas A7).
; -------------------------------------------------------------------------
P4W_BAND:
	LSL.L	#4,D0			; 16 lines a band
	MOVE.L	D0,D7
	PLROWOFF	D0
	LEA	(SCR0.L,D0.L),A0
	LEA	(SCR0+PLSZW,D0.L),A1
	LEA	(SCR0+(PLSZW*2),D0.L),A2
	LEA	(SCR0+(PLSZW*3),D0.L),A5
	LSL.L	#7,D7			; 128 VRAM bytes a line
	LEA	(DIRVRAM.L,D7.L),A4
	MOVE.W	#16,PlRows
P4W_ROW:
	MOVE.W	#16,PlCnt
P4W_BUC:
	MOVE.W	(A0)+,D0
	MOVE.W	(A1)+,D1
	MOVE.W	(A2)+,D2
	MOVE.W	(A5)+,D3
	MOVE.W	D0,D6
	LSR.W	#8,D6
	MOVE.L	(P2CTab.L,D6.W*4),D4
	MOVE.W	D1,D6
	LSR.W	#8,D6
	MOVE.L	(P2CTab.L,D6.W*4),D5
	ADD.L	D5,D5
	OR.L	D5,D4
	MOVE.W	D2,D6
	LSR.W	#8,D6
	MOVE.L	(P2CTab.L,D6.W*4),D5
	LSL.L	#2,D5
	OR.L	D5,D4
	MOVE.W	D3,D6
	LSR.W	#8,D6
	MOVE.L	(P2CTab.L,D6.W*4),D5
	LSL.L	#3,D5
	OR.L	D5,D4
	MOVE.L	D4,(A4)+
	MOVEQ	#0,D6
	MOVE.B	D0,D6
	MOVE.L	(P2CTab.L,D6.W*4),D4
	MOVE.B	D1,D6
	MOVE.L	(P2CTab.L,D6.W*4),D5
	ADD.L	D5,D5
	OR.L	D5,D4
	MOVE.B	D2,D6
	MOVE.L	(P2CTab.L,D6.W*4),D5
	LSL.L	#2,D5
	OR.L	D5,D4
	MOVE.B	D3,D6
	MOVE.L	(P2CTab.L,D6.W*4),D5
	LSL.L	#3,D5
	OR.L	D5,D4
	MOVE.L	D4,(A4)+
	SUBQ.W	#1,PlCnt
	BNE	P4W_BUC
	ADDA.W	PlSkipW,A0
	ADDA.W	PlSkipW,A1
	ADDA.W	PlSkipW,A2
	ADDA.W	PlSkipW,A5
	SUBQ.W	#1,PlRows
	BNE	P4W_ROW
	JMP	P5BandN

; -------------------------------------------------------------------------
; Mode5Layout: SCREEN 5's descriptor, port 98h handlers and per-line copper
; modulo for PlMode (ModoGfx5, and PRINT5 after a layout switch). Uses D0,
; D1, A0.
; -------------------------------------------------------------------------
Mode5Layout:
	MOVEQ	#0,D0
	MOVE.B	PlMode,D0
	MULU	#16,D0
	LEA	(Mode5LTab.L,D0.W),A0
	MOVE.L	(A0)+,MSXVideoMode(A3)
	MOVE.L	(A0)+,DREGIN98(A3)
	MOVE.L	(A0)+,DREGOUT98(A3)
	TST.B	M5Tracked
	BEQ.S	Mode5LNT
	MOVE.L	(A0),DREGOUT98(A3)
Mode5LNT:
; (4.1.2) Mode5Fetch (also PRINT5 every frame through Pl5Frame): the fetch
; mode and the per-line modulo. The 32-bit fetch (FMODE $D, Adj5Calc's
; pointer step and delay) only once the game has scrolled with R#26
; (V9R26Used); FMODE itself is written here only where it is this mode's
; to set (V9Fm32Ok: not a pair-split regime, whose AcCoBMSw writes it).
; Else the MSX2 machine's 64-bit fetch, so a game that never writes R#26
; is fetched and positioned exactly as on MSX2, whatever the AGA chips make
; of a 32-bit fetch at DDFSTRT $40 (an A1200 showed MSX2+ shifted, WinUAE
; does not). The modulo is the layout's stride less the fetch (-8 for the
; MSX2 layout, as before).
Mode5Fetch:
	MOVEQ	#0,D0
	TST.B	V9Scr5			; The V9958 SCREEN 5 path (AGA)...
	BEQ.S	Mode5FSet
	TST.B	V9R26Used		; ...once the game scrolls with R#26:
	BEQ.S	Mode5FSet		; the 32-bit fetch, in a pair-split
	MOVEQ	#-1,D0			; regime too (AcCoBMSw writes its FMODE
Mode5FSet:				; there, as in 4.1.1).
	MOVE.B	D0,V9Fm32
	TST.B	V9Fm32Ok		; (Only this mode's own FMODE: not in a
	BEQ.S	Mode5FNoFm		; pair-split regime, nor on ECS/MSX2.)
	AND.W	#2,D0			; $000F (64-bit) or $000D (32-bit) in one
	EOR.W	#$000F,D0		; write: the copper never reads the other
	MOVE.W	D0,MCAGA+2		; value in between.
Mode5FNoFm:
	MOVE.W	PlStrideW,D0		; The per-line modulo: stride less the
	SUB.W	#W5FETCH,D0		; 32-bit fetch...
	TST.B	V9Fm32
	BNE.S	Mode5LMod
	MOVE.W	PlStrideW,D0		; ...or the 64-bit one (-8 with 32-byte
	SUB.W	#W5FETCH64,D0		; rows: the MSX2 value, never written on
Mode5LMod:				; ECS, whose tables hold 0).
	JMP	Mode5Mod
; (4.1.2) DdfSync (every rendered frame, after BMSPost): the frame's data
; fetch window follows its FMODE (MCAGA+2). The 32-bit fetch ($000D) runs
; from DDFSTRT $38 to DDFSTOP $B0 (9 units, 36 bytes as before): $38 is on
; a 16-cycle unit boundary, so the AGA delay is BPLCON1 & 31 and Adj5Calc
; reaches every offset. At $40 (8 cycles into a unit) the delay became
; (BPLCON1 + 16) & 31, which put the picture 32 dots right for delays
; 1..15 (Gradius III Legends: a rock column at the left edge and a jump).
; Every other FMODE keeps $40/$B8; ECS ($48/$C0) is never touched.
DdfSync:
	CMP.W	#$000D,MCAGA+2
	BNE.S	DdfSStd
	MOVE.W	#$0038,AdjustX+2
	MOVE.W	#$00B0,AdjustX+6
	RTS
DdfSStd:
	CMP.W	#$0038,AdjustX+2
	BNE.S	DdfSX
	MOVE.W	#$0040,AdjustX+2
	MOVE.W	#$00B8,AdjustX+6
DdfSX:	RTS

Mode5LTab:
	DC.L	Modo5Dats,IN98A,OUT98A,OUT98AT
	DC.L	Modo5WDats,IN98W,OUT98W,OUT98WT
	DC.L	Modo5PDats,IN98P,OUT98P,OUT98PT

; -------------------------------------------------------------------------
; Pl5Want: the layout the frame asks for -> D0.B: 0 on MSX2/ECS or without
; "Refresh 100% Graphics" (the planes could not be rebuilt), else 2 while
; SP2 is in effect (R#25 bit 0 and R#2 bit 5, as openMSX), else 1.
; -------------------------------------------------------------------------
Pl5Want:
	MOVEQ	#0,D0
	TST.B	V9Scr5
	BEQ.S	Pl5WantX
	TST.B	DirPrefs+$6B
	BEQ.S	Pl5WantX
	TST.B	V9R26Used		; (4.1.2) Layout 1 once the game scrolls
	BEQ.S	Pl5WantSp		; with R#26; until then (and without SP2)
	MOVEQ	#1,D0			; the MSX2 layout: the same planes,
Pl5WantSp:				; writers, readers and fetch as MSX2.
	BTST	#0,V9R25
	BEQ.S	Pl5WantX
	BTST	#5,REGS+DVDP2
	BEQ.S	Pl5WantX
	MOVEQ	#2,D0
Pl5WantX:
	RTS

; -------------------------------------------------------------------------
; Pl5Frame (PRINT5, once a frame): switch the layout when the frame has
; asked for another one for two frames running (a game that flips the SP2
; page every frame keeps its layout): planes -> VRAM for the bands commands
; drew in (ModoChg5a0), the new layout, VRAM -> planes (ActPlanos5), then
; the descriptor and handlers. About 0.2 s on a 68030/50. Uses D0, D1, A0,
; A1.
; -------------------------------------------------------------------------
Pl5Frame:
	BSR	Pl5Want
	MOVE.B	D0,PlWant
	CMP.B	PlMode,D0
	BEQ.S	Pl5FrSame
	ADDQ.B	#1,Sp2Cnt
	CMP.B	#2,Sp2Cnt
	BCS.S	Pl5FrX
	MOVE.L	D0,-(SP)
	LEA	BUFER(A3),A0		; ModoChg5a0 and ActPlanos5 save their
	LEA	PlBufSv,A1		; registers in BUFER, which here (the
	MOVEQ	#16-1,D1		; frame render) holds the Z80's: keep it.
Pl5FrSv:
	MOVE.L	(A0)+,(A1)+
	DBF	D1,Pl5FrSv
	JSR	ModoChg5a0
	MOVE.L	(SP)+,D0
	BSR	PlSet
	ST	V5All
	ST	SCRTDirty
	JSR	ActPlanos5
	LEA	PlBufSv,A0
	LEA	BUFER(A3),A1
	MOVEQ	#16-1,D1
Pl5FrRs:
	MOVE.L	(A0)+,(A1)+
	DBF	D1,Pl5FrRs
	BSR	Mode5Layout
Pl5FrSame:
	CLR.B	Sp2Cnt
	BSR	Mode5Fetch		; (4.1.2) FMODE and modulo follow R#26's
Pl5FrX:					; first use (a word write, then only when
	RTS				; the modulo changes).

; PlAddrOff: D0.L = VRAM address -> D0.L = byte offset in a plane of its
; first copy (PlRowOff of the line, plus the column). Stack: 8 bytes.
PlAddrOff:
	MOVE.L	D0,-(SP)
	LSR.L	#7,D0
	BSR	PlRowOff
	MOVE.L	D0,-(SP)
	MOVE.L	4(SP),D0
	AND.L	#127,D0
	LSR.W	#2,D0
	ADD.L	(SP)+,D0
	ADDQ.W	#4,SP
	RTS

; Pl5DispOff: D0.L = VRAM line (page*256 + line) -> the display's plane
; offset: as PlRowOff, but in layout 2 the pair row's start (the SP2 line
; begins with the even page whichever page R#2 names).
Pl5DispOff:
	CMP.B	#2,PlMode
	BNE	PlRowOff
	BCLR	#8,D0
	BRA	PlRowOff

; =========================================================================
; (4.0) R#26 and SP2 in the tile modes (SCREEN 2 and 4): the tile pass reads
; the name table through NtSrc, which hands it a copy rotated by R#26 (name
; column (c + n) & 31 at screen column c; with SP2 the other 32 KB half's
; table past column 31, as openMSX's CharacterConverter), per name row with
; the R#26 in effect at the row's first display line (R26Ev, this frame's
; writes). Changed names redraw their tiles as usual, so an R#26 step costs
; a full tile redraw (as a game that rewrites its name table does). Nothing
; changes while R#26 is 0 and SP2 is off: the VRAM table is used directly.
; =========================================================================
R26EVMAX=16
R26Top:		DC.B	0		; R#26 at the frame start (MiraInter0),
NtFrame:	DC.B	0		; NTROT built this frame,
R26EvN:		DC.W	0		; and the frame's R#26 writes: line.W,
R26Ev:		DS.W	R26EVMAX*2	; value.B, pad (VDPR26).
NtKey:		DC.L	0		; NTROT's table (PVDP2) and SP2 state.
	CNOP	0,4
NTROT:		DS.B	1024

; NtSrc: A0 = the name table the tile pass reads (A3 = REGS). Other
; registers kept.
NtSrc:
	LEA	DIRVRAM,A0
	ADD.L	PVDP2(A3),A0
	TST.B	V9958On
	BEQ	NtSrcX
	MOVEM.L	D0-D7/A1-A2/A4,-(SP)
	MOVEQ	#0,D7			; D7: SP2 in effect (R#25 bit 0 and R#2
	BTST	#0,V9R25		; bit 5).
	BEQ.S	NtSrcS0
	BTST	#5,DVDP2(A3)
	BEQ.S	NtSrcS0
	MOVEQ	#1,D7
NtSrcS0:
	TST.B	R26Top			; Nothing to rotate: the VRAM table.
	BNE.S	NtSrcGo
	TST.W	R26EvN
	BNE.S	NtSrcGo
	TST.B	D7
	BEQ	NtSrcR
NtSrcGo:
	MOVE.L	PVDP2(A3),D0		; Built already this frame for this
	MOVE.B	D7,D0			; table and state?
	TST.B	NtFrame
	BEQ.S	NtSrcB
	CMP.L	NtKey,D0
	BEQ	NtSrcDone
NtSrcB:
	MOVE.L	D0,NtKey
	ST	NtFrame
	MOVE.L	A0,A2			; A2: the table (SP2: its even half).
	TST.B	D7
	BEQ.S	NtSrcT
	MOVE.L	PVDP2(A3),D0
	AND.L	#$1FFFF-$8000,D0
	LEA	(DIRVRAM.L,D0.L),A2
NtSrcT:
	LEA	NTROT,A1
	MOVEQ	#0,D6			; D6: name row 0-31.
NtSrcRow:
	MOVE.W	D6,D0			; Its first display line: row*8 - R#23.
	LSL.W	#3,D0
	SUB.B	VDPLinY(A3),D0
	AND.W	#255,D0
	MOVEQ	#0,D1
	MOVE.B	R26Top,D1		; R#26 there: the frame's start value,
	MOVE.W	R26EvN,D2		; then this frame's writes at or above
	BEQ.S	NtSrcEvX		; the line, in order.
	LEA	R26Ev,A4
NtSrcEv:
	CMP.W	(A4),D0
	BCS.S	NtSrcEvN
	MOVE.B	2(A4),D1
NtSrcEvN:
	ADDQ.W	#4,A4
	SUBQ.W	#1,D2
	BNE.S	NtSrcEv
NtSrcEvX:
	TST.B	D7
	BNE.S	NtSrcN6
	AND.W	#31,D1			; No SP2: within the table.
NtSrcN6:
	MOVE.W	D6,D2
	LSL.W	#5,D2
	LEA	(A2,D2.W),A4		; This row's names.
	MOVEQ	#32-1,D3
NtSrcCol:
	MOVEQ	#0,D4
	MOVE.W	D1,D4
	AND.W	#31,D4			; Column (n + c) & 31...
	TST.B	D7
	BEQ.S	NtSrcC1
	BTST	#5,D1			; ...in the other half's table past 31
	BEQ.S	NtSrcC1			; (SP2).
	ADD.L	#$8000,D4
NtSrcC1:
	MOVE.B	(A4,D4.L),(A1)+
	ADDQ.W	#1,D1
	AND.W	#63,D1
	DBF	D3,NtSrcCol
	ADDQ.W	#1,D6
	CMP.W	#32,D6
	BNE	NtSrcRow
NtSrcDone:
	LEA	NTROT,A0
NtSrcR:
	MOVEM.L	(SP)+,D0-D7/A1-A2/A4
NtSrcX:
	RTS
