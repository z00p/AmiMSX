; =========================================================================
; (4.0) Double-buffered SCREEN 4 display (PrefDbuf; PiStorm preset).
;
; On a fast Amiga the frame's render still takes longer than the vertical
; blank (BigMig: 120-140 lines from line ~252), so the tiles, drawn into the
; bitplanes on screen, land partly in one frame and partly in the next, while
; the scroll registers (copper) and sprites change at a frame start. In a
; scrolling game the scenery then jumps against the hero (Lilly's Saga,
; Space Manbow). Here each frame is drawn complete off screen and shown as
; one: tiles, HUD split lines, plane pointers, R#18/R#23, palette and
; sprite pointers all switch at the same frame start.
;
; - Two display buffers (SCREEN, SCREEN4D) and two HUD split buffers
;   (SCREENB, SCREENB1, each with its fast-RAM shadow). The tile renderer
;   (blitter, ScreenPtr) draws into the back one (DbScr). It only redraws
;   what changed since the last frame, so first the tile rows that changed in
;   the last frame are copied from the front buffer (DbCatch, blitter).
; - The per-line copper lists (CopperLine0/1, CopperOpts0/1, TabRasREST0/1)
;   alternate: ActCopperLine builds the back one.
; - At the end of the render the copper templates (MASTERCOPPER, COPPER4,
;   which the rest of AmiMSX writes as before) are copied to the back pair
;   (DbSnap); the next Emula1Frame points the copper at it (DbCommit), past
;   line $1C so the whole copy takes effect at the next frame start.
; Only SCREEN 4 (PRINT4S, with its table and SCREEN 5/4 mode splits); any other frame
; stops it (DbStop) and AmiMSX runs as before. A1200/030 presets: off.
; =========================================================================

DBROWBYTES=8*32*4			; One tile row: 8 lines of 128 bytes.

; Start or stop, then the catch-up copy. PRINT4S entry. Uses no registers.
	CNOP	0,4
DbPre:
	MOVEM.L	D0-D3/A0-A1/A6,DbSv
	TST.B	PrefDbuf
	BEQ.S	DbPreOff
	TST.B	DbOn
	BNE.S	DbPreOn
	ADDQ.L	#1,DbStarts
	ST	DbOn			; Start: this frame is drawn as before;
	ST	DbFirst			; DbPost sets the buffers up for the next.
	BRA.S	DbPreX
DbPreOff:
	TST.B	DbOn
	BEQ.S	DbPreX
	ADDQ.L	#1,DbStopP		; (debug: option off or a mode split)
	BSR	DbStop
	BRA.S	DbPreX
DbPreOn:
	TST.B	DbFirst
	BNE.S	DbPreX
	BSR	DbCatch
DbPreX:
	MOVEM.L	DbSv,D0-D3/A0-A1/A6
	RTS

; End of the frame's render (PRINT4S exit): the first frame sets up the
; back buffers; later ones snapshot the copper lists for DbCommit.
DbPost:
	TST.B	DbOn
	BEQ	DbPostX
	MOVEM.L	D0-D3/A0-A1/A6,DbSv
	TST.B	DbFirst
	BEQ.S	DbPostSnap
	SF	DbFirst			; Front: SCREEN/SCREENB (on screen now,
	MOVE.B	#1,DbB			; from the templates). Back: index 1.
	BSR	DbSetPtrs
	MOVEQ	#-1,D0			; The whole screen to the back first.
	MOVE.L	D0,DbRowsPrev
	MOVE.L	#SCREENB1,A0		; Back HUD buffer and its shadow agree.
	LEA	HudShadow1,A1
	MOVE.W	#(212*32*4)/4-1,D0
DbPostClr:
	CLR.L	(A0)+
	CLR.L	(A1)+
	DBF	D0,DbPostClr
	SF	DbTD			; SCREENT (mode split): buffer 0 is
	MOVE.L	MSFKey,DbTKey		; current, 1 gets a full copy.
	ST	DbTD+1
	BSR	DbSwapLines		; ActCopperLine: the back list from now on.
	BRA.S	DbPostR
DbPostSnap:
	MOVE.L	CopperLineDos,D0	; ZALTO4: the per-line list built this
	MOVE.W	D0,ZALTO4+6		; frame (swapped below).
	SWAP	D0
	MOVE.W	D0,ZALTO4+2
	MOVEQ	#0,D0
	MOVE.B	DbB,D0
	LSL.W	#2,D0
	MOVE.L	(DbCopTab,PC,D0.W),A1
	MOVE.L	A1,DbCopB
	LEA	COPPER4,A0
	MOVE.W	#(DBCOP4LEN/2)-1,D1
DbSnC:	MOVE.W	(A0)+,(A1)+
	DBF	D1,DbSnC
	MOVE.L	(DbMasTab,PC,D0.W),A1
	MOVE.L	A1,DbMasB
	LEA	MASTERCOPPER,A0
	MOVE.W	#(DBMASLEN/2)-1,D1
DbSnM:	MOVE.W	(A0)+,(A1)+
	DBF	D1,DbSnM
	MOVE.L	DbRowsCur,DbRowsPrev	; (rows the other buffer lacks)
	BSR	DbSwapLines
	ST	DbPend
DbPostR:
	MOVEM.L	DbSv,D0-D3/A0-A1/A6
DbPostX:
	RTS

; ActCopperLine runs before the render, so swap here, after DbPost read the
; list just built: from now on Dos is the other one.
DbSwapLines:
	MOVE.L	CopperLineDos,D0
	MOVE.L	CopperLineUno,CopperLineDos
	MOVE.L	D0,CopperLineUno
	MOVE.L	CopperOptsDos,D0
	MOVE.L	CopperOptsUno,CopperOptsDos
	MOVE.L	D0,CopperOptsUno
	MOVE.L	TabRasRESTDos,D0
	MOVE.L	TabRasRESTUno,TabRasRESTDos
	MOVE.L	D0,TabRasRESTUno
	RTS

; Emula1Frame start (and before a key-script SNAP): show the pending
; snapshot from the next frame start. Waits for the blitter (the catch-up
; and the tiles) and, if the beam is in lines 0-$1C, for line $1D: the
; master list and its jump to COPPER4D must come from the same frame.
DbCommit:
	TST.B	DbPend
	BEQ.S	DbComX
	MOVEM.L	D0-D1/A6,DbSv2
	LEA	$DFF002,A6
DbComB:	BTST	#$E,(A6)
	BNE.S	DbComB
DbComL:	MOVE.L	$DFF004,D0
	LSR.L	#8,D0
	AND.W	#$1FF,D0
	CMP.W	#$1C,D0
	BLS.S	DbComL
	MOVE.L	DbMasB,$DFF080		; COP1LC: from the next frame start
	MOVE.L	DbCopB,D1
	MOVE.L	D1,$DFF084		; COP2LC (the master's jump at $1A)
	MOVE.L	D1,NEXTCOPP		; (VDP_Emul sets it again at $FC)
	SF	DbPend
	ADDQ.L	#1,DbCommits		; (perf.bin: frames shown this way)
	BCHG	#0,DbB			; The buffer just shown is the front:
	BSR	DbSetPtrs		; draw the next frame in the other.
	MOVEM.L	DbSv2,D0-D1/A6
DbComX:
	RTS

; DbB -> DbScr/DbFront, the HUD buffer and its shadow (the back ones).
DbSetPtrs:
	MOVE.L	D0,-(SP)
	MOVEQ	#0,D0
	MOVE.B	DbB,D0
	LSL.W	#2,D0
	MOVE.L	(DbScrTab,PC,D0.W),DbScr
	MOVE.L	(DbHudTab,PC,D0.W),DbHudB
	MOVE.L	(DbShTab,PC,D0.W),DbHudSh
	MOVE.L	(DbTTab,PC,D0.W),DbScrT
	EOR.W	#4,D0
	MOVE.L	(DbScrTab,PC,D0.W),DbFront
	MOVE.L	(SP)+,D0
	RTS

; Copy the tile rows that changed in the last frame from the front buffer
; (complete) to the back one (two frames old), runs of rows as one blit.
DbCatch:
	MOVE.L	DbRowsPrev,D0
	CLR.L	DbRowsCur
	TST.L	D0
	BEQ.S	DbCaX
	LEA	$DFF002,A6
DbCaW0:	BTST	#$E,(A6)
	BNE.S	DbCaW0
	MOVE.W	#$09F0,$40-2(A6)	; BLTCON0: A -> D
	CLR.W	$42-2(A6)		; BLTCON1
	MOVE.L	#-1,$44-2(A6)		; first/last word masks
	CLR.W	$64-2(A6)		; BLTAMOD
	CLR.W	$66-2(A6)		; BLTDMOD
	MOVEQ	#0,D1			; Row.
DbCaR:	BFTST	D0{D1:1}
	BEQ.S	DbCaN
	MOVE.W	D1,D2			; Run start...
DbCaRun:
	ADDQ.W	#1,D1
	CMP.W	#32,D1
	BCC.S	DbCaBl
	BFTST	D0{D1:1}
	BNE.S	DbCaRun
DbCaBl:	MOVE.W	D1,D3			; ...rows D2..D1-1.
	SUB.W	D2,D3
	MULU	#DBROWBYTES,D2
	MOVE.L	DbFront,A0
	ADD.L	D2,A0
	MOVE.L	DbScr,A1
	ADD.L	D2,A1
DbCaW1:	BTST	#$E,(A6)
	BNE.S	DbCaW1
	MOVE.L	A0,$50-2(A6)		; BLTAPT
	MOVE.L	A1,$54-2(A6)		; BLTDPT
	LSL.W	#8,D3			; rows * 8 lines, height << 6
	ADD.W	D3,D3
	MOVE.W	D3,$58-2(A6)		; BLTSIZE (width 0 = 64 words)
DbCaN:	ADDQ.W	#1,D1
	CMP.W	#32,D1
	BCS.S	DbCaR
DbCaX:	MOVE.L	DbScr,ScreenPtr		; (RendTabCheck sets it again)
	RTS

; Back to the single display (another screen mode, a mode split, or the
; option off): the copper templates again, list 0, a full redraw.
DbStop:
	MOVEM.L	D0/A3,-(SP)
	SF	DbOn
	SF	DbFirst
	SF	DbPend
	MOVE.L	#MASTERCOPPER,$DFF080
	MOVE.L	#COPPER4,$DFF084
	MOVE.L	#COPPER4,NEXTCOPP
	CMP.L	#CopperLine0,CopperLineDos
	BEQ.S	DbStL0
	BSR	DbSwapLines
DbStL0:	MOVE.L	#CopperLine0,D0
	MOVE.W	D0,ZALTO4+6
	SWAP	D0
	MOVE.W	D0,ZALTO4+2
	CLR.B	DbB
	MOVE.L	#SCREEN,DbScr
	MOVE.L	#SCREEN,DbFront
	MOVE.L	#SCREENB,DbHudB
	MOVE.L	#HudShadow,DbHudSh
	MOVE.L	#SCREENT,DbScrT
	ST	SCRTDirty		; (SCREENT may be two frames old)
	MOVE.L	#SCREEN,ScreenPtr
	LEA	REGS,A3
	ST	ACTODO(A3)		; (SCREEN may be two frames old)
	ST	ACTODOB(A3)
	MOVEM.L	(SP)+,D0/A3
	RTS



	CNOP	0,4
DbScrTab:	DC.L	SCREEN,SCREEN4D
DbHudTab:	DC.L	SCREENB,SCREENB1
DbShTab:	DC.L	HudShadow,HudShadow1
DbTTab:		DC.L	SCREENT,SCREENT1
DbScrT:		DC.L	SCREENT		; Back SCREENT (lines above a mode split).
DbTKey:		DC.L	0,0		; Per SCREENT buffer: key of its copy,
DbCopTab:	DC.L	COPPER4D0,COPPER4D1
DbMasTab:	DC.L	MASTERD0,MASTERD1
DbScr:		DC.L	SCREEN		; Back display buffer (SCREEN when off).
DbFront:	DC.L	SCREEN
DbHudB:		DC.L	SCREENB
DbHudSh:	DC.L	HudShadow
DbCopB:		DC.L	0
DbMasB:		DC.L	0
DbRowsCur:	DC.L	0		; Tile rows drawn this frame (bit 0 = row 0).
DbRowsPrev:	DC.L	0
DbCommits:	DC.L	0
DbStopP:	DC.L	0
DbStopR:	DC.L	0
DbStarts:	DC.L	0
DbSv:		DS.L	7
DbSv2:		DS.L	3
DbOn:		DC.B	0
DbFirst:	DC.B	0
DbPend:		DC.B	0
DbB:		DC.B	0		; Back buffer index.
DbTD:		DC.B	0,0		; and whether the page changed since.
		EVEN
