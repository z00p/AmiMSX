; (4.5) RTG display, stage 1: SCREEN 1, 2 and 4 with their sprites on a 16 or
; 32-bit Picasso96 screen (Docs/agent_notes/v45_rtg.md). The screen is opened and
; its bitmap's address read (locked briefly) with the OS alive (RtgPlayOpen,
; before the takeover); in play
; each frame is drawn straight into that memory, from VRAM, at the end of the MSX
; frame (RtgFrame, from Emula1Frame). No OS call in play: the colour lookup is
; ours, so no palette load. The other screen modes stay on AGA (RtgUse).
; Rules from openMSX (CharacterConverter, SpriteChecker, SpriteConverter, VDP).

P96IDA_WIDTH=0
P96IDA_HEIGHT=1
P96IDA_DEPTH=2
P96IDA_RGBFORMAT=5
P96IDA_ISP96=6
RGBFB_CLUT=1
RTGMAXW=2048			; RtgRow: widest mode accepted
RTGLINES=212
RTGHREC=1024+8			; blended: a line's h(dots), h(border), x
RTGHSIZE=RTGLINES*RTGHREC+4096*4	; (then RtgHCol)
	IFD	RTGSHOT			; (test builds: a hook after each
RTGSNAPHK	SET	1		; key-script SNAP, RtgFrame)
	ENDC
	IFD	SCANCYC
RTGSNAPHK	SET	1
	ENDC

; ---------------------------------------------------------------------------
; Program start, OS alive (PROGRAMA, before SETUPSCREEN): with the RTG
; ToolType, find the play mode and the menu's 8-bit mode; the menu screen then
; opens on RTG too (one output, the HDMI on a PiStorm). Without P96 or a mode
; the option is dropped and everything stays on AGA.
	CNOP	0,4
RtgInit:
	MOVEM.L	D0-D7/A0-A6,-(SP)
	IFD	RTGFORCE
	ST	RtgWant
	ENDC
	TST.B	RtgWant
	BEQ	RtgIX
	MOVE.L	4.W,A6
	LEA	RtgGfxNom(PC),A1
	MOVEQ	#39,D0
	JSR	-$228(A6)		; OpenLibrary
	MOVE.L	D0,RtgGfx
	BEQ	RtgINo
	LEA	RtgP96Nom(PC),A1
	MOVEQ	#2,D0
	JSR	-$228(A6)
	MOVE.L	D0,RtgP96
	BEQ	RtgINo
	MOVEQ	#0,D7			; The play mode,
	BSR	RtgFind
	MOVE.L	D0,RtgModeID
	CMP.L	#-1,D0
	BEQ	RtgINo
	MOVEQ	#1,D7			; then the menu's.
	BSR	RtgFind
	CMP.L	#-1,D0
	BEQ	RtgIX			; (none: the menu stays on AGA)
	MOVE.L	D0,RtgMModeID
	LEA	ScreenTags,A0		; SA_DisplayID of the menu screen.
RtgITag:
	MOVE.L	(A0)+,D1
	BEQ.S	RtgIMenu
	CMP.L	#$80000032,D1
	BEQ.S	RtgITagS
	ADDQ.L	#4,A0
	BRA.S	RtgITag
RtgITagS:
	MOVE.L	D0,(A0)
RtgIMenu:
	ST	RtgMenuOn
	BSR	RtgTallInit
	BRA.S	RtgIX
RtgINo:
	SF	RtgWant
RtgIX:
	MOVEM.L	(SP)+,D0-D7/A0-A6
	RTS

; Best P96 mode, D7 = 0: play (a 16/32-bit format of RtgFmtTab: 960x540 first,
; the 1080p HDMI's exact 2x, then the smallest that holds the picture at 2x,
; then at 1x; 16-bit before 32-bit), 1: menu (8-bit CLUT, at least 640x212:
; 640x480 first, else the smallest). D0 = ModeID or -1. D1-D6/A0-A2/A6 used.
RtgFind:
	MOVEQ	#-1,D6			; Best key so far,
	MOVEQ	#-1,D5			; its ModeID.
	MOVEQ	#-1,D4			; NextDisplayInfo from INVALID_ID.
RtgFNext:
	MOVE.L	D4,D0
	MOVE.L	RtgGfx,A6
	JSR	-732(A6)		; NextDisplayInfo
	MOVE.L	D0,D4
	CMP.L	#-1,D4
	BEQ	RtgFDone
	MOVE.L	D4,D0
	MOVEQ	#P96IDA_ISP96,D1
	BSR	RtgIdAttr
	TST.L	D0
	BEQ.S	RtgFNext
	MOVE.L	D4,D0
	MOVEQ	#P96IDA_WIDTH,D1
	BSR	RtgIdAttr
	MOVE.L	D0,D2			; D2 = width
	MOVE.L	D4,D0
	MOVEQ	#P96IDA_HEIGHT,D1
	BSR	RtgIdAttr
	MOVE.L	D0,D3			; D3 = height
	MOVE.L	D4,D0
	MOVEQ	#P96IDA_RGBFORMAT,D1
	BSR	RtgIdAttr		; D0 = format
	CMP.L	#RTGMAXW,D2
	BHI.S	RtgFNext
	TST.W	D7
	BNE.S	RtgFMenu
	BSR	RtgFmtFind		; A0 = its RtgFmtTab entry, or 0
	MOVE.L	A0,D0
	BEQ.S	RtgFNext
	MOVEQ	#0,D1			; Class: 2 bytes a pixel even,
	CMP.B	#4,1(A0)
	IFD	RTG32			; (test builds: -DRTG32, 32-bit first)
	BEQ.S	RtgFCl
	ELSE
	BNE.S	RtgFCl
	ENDC
	MOVEQ	#1,D1			; 4 bytes odd.
RtgFCl:	CMP.W	#960,D2
	BNE.S	RtgF2x
	CMP.W	#540,D3
	BEQ.S	RtgFKey
RtgF2x:	ADDQ.W	#2,D1
	CMP.W	#544,D2
	BCS.S	RtgF1x
	CMP.W	#460,D3
	BCC.S	RtgFKey
RtgF1x:	ADDQ.W	#2,D1
	CMP.W	#272,D2
	BCS	RtgFNext
	CMP.W	#230,D3
	BCS	RtgFNext
	BRA.S	RtgFKey
RtgFMenu:
	CMP.L	#RGBFB_CLUT,D0
	BNE	RtgFNext
	CMP.W	#640,D2
	BCS	RtgFNext
	CMP.W	#212,D3
	BCS	RtgFNext
	MOVEQ	#1,D1
	CMP.W	#640,D2
	BNE.S	RtgFKey
	CMP.W	#480,D3
	BNE.S	RtgFKey
	MOVEQ	#0,D1
RtgFKey:				; Key = class << 24 + area.
	MOVE.L	D2,D0
	MULU.W	D3,D0
	AND.L	#$00FFFFFF,D0
	ROR.L	#8,D1
	OR.L	D1,D0
	CMP.L	D6,D0
	BCC	RtgFNext
	MOVE.L	D0,D6
	MOVE.L	D4,D5
	BRA	RtgFNext
RtgFDone:
	MOVE.L	D5,D0
	RTS

; The menu on RTG at double height: with square pixels the 640x212 layout came
; out flat, in the top 45% of the picture. A topaz 8 with every row doubled
; (amimsxtall.font 16: built once, left in the font list for the next run) and
; every y of the layout doubled: windows, file requesters and the logo here,
; gadgets (TallNG), bevel boxes (TallBevel) and texts (TallIText) as drawn.
; Without the memory the menu stays as it was. OS alive.
RTGWINS=(MatraHeight+2-MC68020Left)/8	; GadToolsBox's Left/Top/Width/Height
	IFNE	(MatraHeight+2-MC68020Left)-RTGWINS*8
	FAIL	"window table not contiguous"
	ENDC
RtgTallInit:
	MOVE.L	RtgMModeID,D0		; (a mode with the lines for it)
	MOVEQ	#P96IDA_HEIGHT,D1
	BSR	RtgIdAttr
	CMP.L	#424,D0
	BLT	RtgTX
	MOVE.L	RtgGfx,A6
	LEA	RtgTallTA(PC),A0
	JSR	-72(A6)			; OpenFont: still there from a run before?
	TST.L	D0
	BEQ.S	RtgTBuild
	MOVE.L	D0,A1
	MOVE.L	10(A1),A0		; ln_Name
	LEA	RtgTallNom(PC),A2
	MOVEQ	#0,D2
	CMP.W	#16,20(A1)
	BNE.S	RtgTOld
RtgTCmp:
	MOVE.B	(A0)+,D1
	CMP.B	(A2)+,D1
	BNE.S	RtgTOld
	TST.B	D1
	BNE.S	RtgTCmp
	MOVEQ	#1,D2			; yes
RtgTOld:
	JSR	-78(A6)			; CloseFont
	TST.W	D2
	BNE	RtgTUse
RtgTBuild:
	LEA	topaz8,A0
	JSR	-72(A6)			; OpenFont topaz 8
	TST.L	D0
	BEQ	RtgTX
	MOVE.L	D0,A3
	MOVEQ	#0,D3
	MOVE.W	38(A3),D3		; tf_Modulo
	MOVE.L	D3,D0
	MULU.W	20(A3),D0		; tf_YSize rows,
	ADD.L	D0,D0			; each twice,
	ADD.L	#52+16,D0		; after the TextFont and the name.
	MOVE.L	#$10003,D1		; MEMF_PUBLIC|MEMF_CHIP|MEMF_CLEAR
	MOVE.L	4.W,A6
	JSR	-198(A6)		; AllocMem
	MOVE.L	RtgGfx,A6
	TST.L	D0
	BEQ	RtgTNoMem
	MOVE.L	D0,A2
	MOVE.L	A3,A0
	MOVE.L	A2,A1
	MOVEQ	#52/4-1,D1
RtgTCpy:
	MOVE.L	(A0)+,(A1)+
	DBF	D1,RtgTCpy
	LEA	RtgTallNom(PC),A0	; (A1 = the name's place)
RtgTNm:
	MOVE.B	(A0)+,(A1)+
	BNE.S	RtgTNm
	CLR.L	(A2)			; ln_Succ, ln_Pred
	CLR.L	4(A2)
	MOVE.W	#$0C00,8(A2)		; NT_FONT, pri 0
	LEA	52(A2),A0
	MOVE.L	A0,10(A2)		; ln_Name
	CLR.L	14(A2)			; mn_ReplyPort
	MOVE.W	#52,18(A2)		; mn_Length
	MOVE.W	#16,20(A2)		; tf_YSize
	AND.B	#$BF,22(A2)		; no FSF_TAGGED: no extension (yet)
	MOVE.B	23(A3),D0
	AND.B	#$FC,D0			; not ROM, not disk
	OR.B	#$40,D0			; FPF_DESIGNED
	MOVE.B	D0,23(A2)
	MOVE.W	26(A3),D0
	ADD.W	D0,D0
	ADDQ.W	#1,D0
	MOVE.W	D0,26(A2)		; tf_Baseline
	CLR.W	30(A2)			; tf_Accessors
	LEA	52+16(A2),A1
	MOVE.L	A1,34(A2)		; tf_CharData
	MOVE.L	34(A3),A0
	MOVE.W	20(A3),D2
	SUBQ.W	#1,D2
RtgTRow:
	LEA	(A1,D3.W),A4		; (the copy below)
	MOVE.W	D3,D1
	SUBQ.W	#1,D1
RtgTB:	MOVE.B	(A0,D1.W),D0
	MOVE.B	D0,(A1,D1.W)
	MOVE.B	D0,(A4,D1.W)
	DBF	D1,RtgTB
	ADD.W	D3,A0
	ADD.W	D3,A1
	ADD.W	D3,A1
	DBF	D2,RtgTRow
	MOVE.L	A2,A1
	JSR	-480(A6)		; AddFont
	MOVE.L	A3,A1
	JSR	-78(A6)			; CloseFont
	BRA.S	RtgTUse
RtgTNoMem:
	MOVE.L	A3,A1
	JSR	-78(A6)			; CloseFont
	BRA	RtgTX
RtgTUse:
	ST	RtgTall
	LEA	topaz8,A0		; Every topaz 8 of the menu is the tall one,
	LEA	RtgTallNom(PC),A1
	MOVE.L	A1,(A0)
	MOVE.W	#16,4(A0)
	MOVE.B	#$40,7(A0)
	LEA	MC68020Left,A0		; the windows,
	MOVEQ	#RTGWINS-1,D1
RtgTWin:
	MOVE.W	2(A0),D0
	CMP.W	#11,D0			; (under the title bar: still just under it)
	BLT.S	RtgTWinT
	ADD.W	D0,D0
	SUBQ.W	#3,D0
RtgTWinT:
	MOVE.W	D0,2(A0)
	ASL.W	6(A0)
	ADDQ.L	#8,A0
	DBF	D1,RtgTWin
	LEA	ScreenTags,A0		; the screen,
RtgTSc:
	MOVE.L	(A0)+,D0
	BEQ.S	RtgTScX
	CMP.L	#$80000024,D0		; SA_Height
	BNE.S	RtgTScN
	ASL.W	2(A0)
RtgTScN:
	ADDQ.L	#4,A0
	BRA.S	RtgTSc
RtgTScX:
	LEA	TAGS0,A0		; the file requesters,
	BSR	RtgTAsl
	LEA	TAGS1,A0
	BSR	RtgTAsl
	LEA	TAGS2,A0
	BSR	RtgTAsl
	LEA	TAGS3,A0
	BSR	RtgTAsl
	LEA	DATMSXPIC,A0		; and the logo (planes of rows of words).
	LEA	RtgTallPic,A1
	MOVEQ	#20/2-1,D0
RtgTPc:	MOVE.W	(A0)+,(A1)+
	DBF	D0,RtgTPc
	LEA	RtgTallPic,A3
	MOVE.W	2(A3),D0		; (D1 is the window's BorderTop there)
	ADD.W	D0,D0
	SUB.W	#6,D0
	MOVE.W	D0,2(A3)
	MOVE.W	4(A3),D3
	ADD.W	#15,D3
	LSR.W	#4,D3
	ADD.W	D3,D3			; D3 = bytes a row
	MOVE.W	6(A3),D4		; D4 = rows
	MOVE.W	D3,D0
	MULU.W	D4,D0
	MULU.W	8(A3),D0		; x planes
	ADD.L	D0,D0
	MOVE.L	#$10002,D1		; MEMF_CHIP|MEMF_CLEAR
	MOVE.L	4.W,A6
	JSR	-198(A6)		; AllocMem
	TST.L	D0
	BEQ.S	RtgTX			; (none: the logo stays short)
	MOVE.L	D0,A1
	MOVE.L	10(A3),A0
	MOVE.L	A1,10(A3)
	MOVE.W	D4,D2
	MULU.W	8(A3),D2		; rows of all planes
	SUBQ.W	#1,D2
RtgTPR:	MOVE.W	D3,D1
	SUBQ.W	#1,D1
	MOVE.L	A0,A2
RtgTPB:	MOVE.B	(A2)+,(A1)+
	DBF	D1,RtgTPB
	MOVE.W	D3,D1
	SUBQ.W	#1,D1
RtgTPB2:
	MOVE.B	(A0)+,(A1)+
	DBF	D1,RtgTPB2
	DBF	D2,RtgTPR
	ADD.W	D4,6(A3)		; Height x2
RtgTX:
	RTS

; An ASL requester's tags: InitialTopEdge and InitialHeight.
RtgTAsl:
	MOVE.L	28(A0),D0
	ADD.L	D0,D0
	SUBQ.L	#3,D0
	MOVE.L	D0,28(A0)
	MOVE.L	36(A0),D0
	ADD.L	D0,D0
	MOVE.L	D0,36(A0)
	RTS

; Drawing at double height (RtgTall): GadToolsBox's NewGadget (A0) y and
; height, its bevel boxes (D1 = y + the window's BorderTop D5, D3 = height),
; and IntuiText chains (TopEdge, for the call only).
TallNG:
	TST.B	RtgTall
	BEQ.S	TallNGX
	ASL.W	2(A0)
	ASL.W	6(A0)
TallNGX:
	RTS
TallBevel:
	TST.B	RtgTall
	BEQ.S	TallBvX
	ADD.W	D1,D1
	SUB.W	D5,D1
	ADD.W	D3,D3
TallBvX:
	JMP	DrawBevelBoxA(A6)
TallIText:
	TST.B	RtgTall
	BEQ.S	TallITX
	MOVEM.L	D0-D1/A0-A1,-(SP)
	MOVE.L	A1,D0
TallIT1:
	MOVE.L	D0,A1
	ASL.W	6(A1)
	MOVE.L	16(A1),D0
	BNE.S	TallIT1
	MOVEM.L	(SP),D0-D1/A0-A1
	JSR	PrintIText(A6)
	MOVE.L	12(SP),D0
TallIT2:
	MOVE.L	D0,A1
	ASR.W	6(A1)
	MOVE.L	16(A1),D0
	BNE.S	TallIT2
	MOVEM.L	(SP)+,D0-D1/A0-A1
	RTS
TallITX:
	JMP	PrintIText(A6)

; p96GetModeIDAttr(D0 = ModeID, D1 = attribute) -> D0. Keeps D2-D7/A2-A5.
RtgIdAttr:
	MOVE.L	A6,-(SP)
	MOVE.L	RtgP96,A6
	JSR	-84(A6)
	MOVE.L	(SP)+,A6
	RTS

; A0 = the RtgFmtTab entry of P96 format D0.B, or 0.
RtgFmtFind:
	LEA	RtgFmtTab(PC),A0
RtgFFL:	TST.B	(A0)
	BEQ.S	RtgFF0
	CMP.B	(A0),D0
	BEQ.S	RtgFFX
	LEA	10(A0),A0
	BRA.S	RtgFFL
RtgFF0:	SUB.L	A0,A0
RtgFFX:	RTS

; Formats: P96 RGBFB number, bytes a pixel, then bits and shift of R, G, B,
; and 1 when the 16-bit word is little-endian (PC).
RtgFmtTab:
	DC.B	4,2, 5,11, 6,5, 5,0, 1,0	; R5G6B5PC (VideoCore, uaegfx)
	DC.B	10,2, 5,11, 6,5, 5,0, 0,0	; R5G6B5
	DC.B	5,2, 5,10, 5,5, 5,0, 1,0	; R5G5B5PC
	DC.B	11,2, 5,10, 5,5, 5,0, 0,0	; R5G5B5
	DC.B	12,2, 5,0, 6,5, 5,11, 1,0	; B5G6R5PC
	DC.B	13,2, 5,0, 5,5, 5,10, 1,0	; B5G5R5PC
	DC.B	6,4, 8,16, 8,8, 8,0, 0,0	; A8R8G8B8
	DC.B	7,4, 8,0, 8,8, 8,16, 0,0	; A8B8G8R8
	DC.B	8,4, 8,24, 8,16, 8,8, 0,0	; R8G8B8A8
	DC.B	9,4, 8,8, 8,16, 8,24, 0,0	; B8G8R8A8
	DC.B	0
	EVEN

; ---------------------------------------------------------------------------
; MSXEMUL, OS alive, before the takeover: open the play screen, then lock its
; bitmap only to read its address and clear it, build the colour table.
; Failure: this run stays on AGA.
	CNOP	0,4
RtgPlayOpen:
	MOVEM.L	D0-D7/A0-A6,-(SP)
	SF	RtgOn
	TST.B	RtgWant
	BEQ	RtgPOX
	MOVE.L	RtgModeID,D0
	MOVEQ	#P96IDA_WIDTH,D1
	BSR	RtgIdAttr
	MOVE.W	D0,RtgW
	MOVE.L	D0,RtgSTW+4
	MOVE.L	RtgModeID,D0
	MOVEQ	#P96IDA_HEIGHT,D1
	BSR	RtgIdAttr
	MOVE.W	D0,RtgH
	MOVE.L	D0,RtgSTH+4
	MOVE.L	RtgModeID,D0
	MOVEQ	#P96IDA_DEPTH,D1
	BSR	RtgIdAttr
	MOVE.L	D0,RtgSTD+4
	MOVE.L	RtgModeID,RtgSTM+4
	SUB.L	A0,A0
	LEA	RtgSTags(PC),A1
	MOVE.L	_INTUITIONBASE,A6
	JSR	-612(A6)		; OpenScreenTagList
	MOVE.L	D0,RtgScr
	BEQ	RtgPOX
	MOVE.L	RtgGfx,A6		; Let the board show it first (two frames),
	JSR	-270(A6)		; with no lock held: the VideoCore driver
	JSR	-270(A6)		; switches and pans holding the board, and a
					; lock kept across OS calls could deadlock
					; (a hang at Power ON, now and then, A1200).
	MOVE.L	RtgScr,A0
	MOVE.L	$58(A0),A0		; sc_RastPort.rp_BitMap
	MOVE.L	A0,RtgBm
	LEA	RtgRI(PC),A1
	MOVEQ	#12,D0
	MOVE.L	RtgP96,A6
	JSR	-48(A6)			; p96LockBitMap
	MOVE.L	D0,RtgLock
	BEQ	RtgPOFail
	MOVE.L	RtgRI+8,D0		; The bitmap's real format.
	BSR	RtgFmtFind
	MOVE.L	A0,D0
	BEQ	RtgPOUnl
	MOVE.L	RtgRI,RtgMem
	MOVEQ	#0,D0
	MOVE.W	RtgRI+4,D0
	MOVE.L	D0,RtgBpr
	SF	RtgBpp4
	CMP.B	#4,1(A0)
	SEQ	RtgBpp4
	BSR	RtgMkTab		; The 12-bit colour table (A0 = format).
	MOVE.L	A0,RtgFmtP
	MOVE.B	8(A0),RtgIsPC
	BSR	RtgMkDim		; (scanlines: the dimmed levels)
	BSR	RtgMkDbl
	MOVE.B	#2,RtgScl		; 2x when 544x460 fit, else 1x.
	IFD	RTG1X			; (test builds: -DRTG1X, 1x always)
	BRA.S	RtgPO1x
	ENDC
	CMP.W	#544,RtgW
	BCS.S	RtgPO1x
	CMP.W	#460,RtgH
	BCC.S	RtgPOGeo
RtgPO1x:MOVE.B	#1,RtgScl
RtgPOGeo:
	MOVEQ	#0,D1			; RtgOX = (W - 256 s) / 2,
	MOVE.B	RtgScl,D1
	MOVE.W	RtgW,D0
	MOVE.W	D1,D2
	LSL.W	#8,D2
	SUB.W	D2,D0
	ASR.W	#1,D0
	MOVE.W	D0,RtgOX
	MOVE.W	RtgH,D0			; RtgOY = (H - 212 s) / 2.
	MULU.W	#RTGLINES,D1
	SUB.W	D1,D0
	ASR.W	#1,D0
	MOVE.W	D0,RtgOY
	BSR	RtgBlSet		; (blended scanlines: memory, tables)
	IFD	RTGSHOT
	BSR	RtgShAlloc
	ENDC
	BSR	RtgMkG7			; SCREEN 8's 256 colours.
	MOVE.L	RtgMem,A0		; Clear the screen.
	MOVE.L	RtgBpr,D0
	MULU.W	RtgH,D0
	LSR.L	#2,D0
	BRA.S	RtgPOClE
RtgPOCl:CLR.L	(A0)+
RtgPOClE:
	SUBQ.L	#1,D0
	BPL.S	RtgPOCl
	ST	RtgFull			; First frame: fill all, every line new.
	SF	RtgPrev
	CLR.W	RtgHold
	MOVE.L	RtgBm,A0		; The address is kept, the lock let go: in
	MOVE.L	RtgLock,D0		; play the OS is stopped and nothing else
	MOVE.L	RtgP96,A6		; uses the board; until the takeover the
	JSR	-54(A6)			; OS still runs (p96UnlockBitMap).
	CLR.L	RtgLock
	ST	RtgOn
	BRA.S	RtgPOX
RtgPOUnl:
	MOVE.L	RtgBm,A0
	MOVE.L	RtgLock,D0
	MOVE.L	RtgP96,A6
	JSR	-54(A6)			; p96UnlockBitMap
	CLR.L	RtgLock
RtgPOFail:
	MOVE.L	RtgScr,A0
	MOVE.L	_INTUITIONBASE,A6
	JSR	-66(A6)			; CloseScreen
	CLR.L	RtgScr
RtgPOX:
	MOVEM.L	(SP)+,D0-D7/A0-A6
	RTS

; Back in the menu, OS alive: unlock and close the play screen.
	CNOP	0,4
RtgPlayClose:
	MOVEM.L	D0-D1/A0-A1/A6,-(SP)
	IFD	RTGSHOT			; (test builds: the last frame too, the
	TST.B	RtgOn			; screen still open)
	BEQ.S	RtgPCS
	BSR	RtgShGrab
RtgPCS:
	ENDC
	SF	RtgOn
	SF	RtgNow
	TST.L	RtgLock
	BEQ.S	RtgPCScr
	MOVE.L	RtgBm,A0
	MOVE.L	RtgLock,D0
	MOVE.L	RtgP96,A6
	JSR	-54(A6)			; p96UnlockBitMap
	CLR.L	RtgLock
RtgPCScr:
	TST.L	RtgScr
	BEQ.S	RtgPCX
	MOVE.L	RtgScr,A0
	MOVE.L	_INTUITIONBASE,A6
	JSR	-66(A6)			; CloseScreen
	CLR.L	RtgScr
RtgPCX:
	IFD	RTGSHOT
	BSR	RtgShWrite
	ENDC
	SF	RfBlOn			; (blended scanlines: their memory)
	TST.L	RtgHMem
	BEQ.S	RtgPCY
	MOVE.L	RtgHMem,A1
	MOVE.L	RtgHSz,D0
	MOVE.L	4.W,A6
	JSR	-210(A6)		; FreeMem
	CLR.L	RtgHMem
RtgPCY:
	MOVEM.L	(SP)+,D0-D1/A0-A1/A6
	RTS

; Colour table: AmiMSX's 12-bit palette word (MSX2Pal: 0RGB, MSX levels 0-7 as
; nibbles 0,3,5,7,9,B,D,F) -> the screen's pixel, a long (16-bit: the pixel
; twice, for 2x writes). MSX levels give openMSX's 8-bit values (n*255/7),
; other nibbles n*17. A0 = RtgFmtTab entry.
RtgMkTab:
	MOVEM.L	D0-D7/A0-A2,-(SP)
	SF	RfMkH
	LEA	RtgCol,A2
	BRA.S	RtgMT0
; (blended scanlines) The same at A1 with each channel's value v made
; h(v) = (v x (100 - RtgScan) + 100) / 200, in the screen's own channel bits:
; two of them add with no carry out of a channel (h <= max x 75 / 200 + 1). In
; the big-endian order for every format (RtgBRow swaps the PC ones' bytes).
RtgMkTabH:
	MOVEM.L	D0-D7/A0-A2,-(SP)
	ST	RfMkH
	MOVE.L	A1,A2
RtgMT0:	MOVE.L	A2,RtgMkDst
	LEA	RtgGun(PC),A1		; 3 x 16 longs: R, G, B, shifted.
	MOVEQ	#3-1,D7
	ADDQ.L	#2,A0
RtgMTG:	MOVEQ	#0,D2
	MOVE.B	(A0)+,D2		; bits
	MOVEQ	#0,D3
	MOVE.B	(A0)+,D3		; shift
	MOVEQ	#1,D4
	LSL.L	D2,D4
	SUBQ.L	#1,D4			; max = 2^bits - 1
	LEA	RtgLev8(PC),A2
	MOVEQ	#16-1,D6
RtgMTN:	MOVEQ	#0,D0
	MOVE.B	(A2)+,D0		; 8-bit value
	MULU.W	D4,D0
	ADD.L	#127,D0
	DIVU.W	#255,D0
	AND.L	#$FFFF,D0
	TST.B	RfMkH
	BEQ.S	RtgMTV
	MOVEQ	#100,D1
	SUB.B	RtgScan,D1
	MULU.W	D1,D0
	ADD.L	#100,D0
	DIVU.W	#200,D0
	AND.L	#$FFFF,D0
RtgMTV:	LSL.L	D3,D0
	MOVE.L	D0,(A1)+
	DBF	D6,RtgMTN
	DBF	D7,RtgMTG
	MOVE.B	(A0),D5			; 1: little-endian 16-bit
	TST.B	RfMkH
	BEQ.S	RtgMTE
	MOVEQ	#0,D5
RtgMTE:	MOVE.L	RtgMkDst,A1
	LEA	RtgGun(PC),A2
	MOVEQ	#0,D7			; 0RGB
RtgMTC:	MOVE.W	D7,D0
	LSR.W	#8,D0
	AND.W	#15,D0
	MOVE.L	(A2,D0.W*4),D1
	MOVE.W	D7,D0
	LSR.W	#4,D0
	AND.W	#15,D0
	OR.L	64(A2,D0.W*4),D1
	MOVE.W	D7,D0
	AND.W	#15,D0
	OR.L	128(A2,D0.W*4),D1
	TST.B	RtgBpp4
	BNE.S	RtgMTS
	TST.B	D5
	BEQ.S	RtgMTW
	ROL.W	#8,D1
RtgMTW:	MOVE.W	D1,D0			; the pixel twice
	SWAP	D1
	MOVE.W	D0,D1
RtgMTS:	MOVE.L	D1,(A1)+
	ADDQ.W	#1,D7
	CMP.W	#4096,D7
	BNE.S	RtgMTC
	MOVEM.L	(SP)+,D0-D7/A0-A2
	RTS

; RtgDbl: a byte's 8 dots each twice (sprite MAG), as a word.
RtgMkDbl:
	MOVEM.L	D0-D3/A0,-(SP)
	LEA	RtgDbl,A0
	MOVEQ	#0,D0
RtgMDL:	MOVEQ	#0,D2
	MOVEQ	#8-1,D3
RtgMDB:	LSL.W	#2,D2
	BTST	D3,D0
	BEQ.S	RtgMDN
	OR.W	#3,D2
RtgMDN:	DBF	D3,RtgMDB
	MOVE.W	D2,(A0)+
	ADDQ.W	#1,D0
	CMP.W	#256,D0
	BNE.S	RtgMDL
	MOVEM.L	(SP)+,D0-D3/A0
	RTS

RtgLev8:DC.B	0,17,34,36,68,73,102,109,136,146,170,182,204,219,238,255

; SCREEN 8's colours (RtgCol built): byte GGGRRRBB -> RtgG7Lut. R and G are
; MSX levels 0-7 (nibbles 0,3,5,7,9,B,D,F), blue 0-3 is level 0, 2, 4, 7
; (openMSX PALETTE256).
RtgMkG7:
	MOVEM.L	D0-D3/A0-A2,-(SP)
	LEA	RtgG7Lut,A0
	LEA	RtgCol,A1
	LEA	RtgG7Nb(PC),A2
	MOVEQ	#0,D3
RtgMG7:	MOVE.W	D3,D0			; R
	LSR.W	#2,D0
	AND.W	#7,D0
	MOVEQ	#0,D1
	MOVE.B	(A2,D0.W),D1
	LSL.W	#8,D1
	MOVE.W	D3,D0			; G
	LSR.W	#5,D0
	AND.W	#7,D0
	MOVEQ	#0,D2
	MOVE.B	(A2,D0.W),D2
	LSL.W	#4,D2
	OR.W	D2,D1
	MOVE.W	D3,D0			; B
	AND.W	#3,D0
	MOVE.B	8(A2,D0.W),D2
	OR.W	D2,D1
	MOVE.L	(A1,D1.W*4),(A0)+
	MOVE.W	D1,D0			; (and dimmed, 1 KB on: RtgG7LutD;
	TST.B	RfBlOn			; blended: half-dimmed, RtgHCol)
	BEQ.S	RtgMG7D
	MOVE.L	([RtgHCol],D0.W*4),1024-4(A0)
	BRA.S	RtgMG7N
RtgMG7D:BSR	RtgDimC
	MOVE.L	(A1,D0.W*4),1024-4(A0)
RtgMG7N:
	ADDQ.W	#1,D3
	CMP.W	#256,D3
	BNE.S	RtgMG7
	MOVEM.L	(SP)+,D0-D3/A0-A2
	RTS

; RtgDimN from RtgScan: each 4-bit level x (100 - RtgScan) / 100, rounded.
RtgMkDim:
	MOVEM.L	D0-D2/A0,-(SP)
	LEA	RtgDimN,A0
	MOVEQ	#100,D2
	MOVEQ	#0,D0
	MOVE.B	RtgScan,D0
	SUB.W	D0,D2			; 100 - %
	MOVEQ	#0,D1
RtgMDm:	MOVE.W	D1,D0
	MULU.W	D2,D0
	ADD.L	#50,D0
	DIVU.W	#100,D0
	MOVE.B	D0,(A0)+
	ADDQ.W	#1,D1
	CMP.W	#16,D1
	BNE.S	RtgMDm
	MOVEM.L	(SP)+,D0-D2/A0
	RTS

; D0.W = the 12-bit colour D0.W dimmed (RtgDimN per nibble).
RtgDimC:
	MOVEM.L	D1-D2/A0,-(SP)
	LEA	RtgDimN,A0
	MOVE.W	D0,D1
	LSR.W	#8,D1
	AND.W	#15,D1
	MOVE.B	(A0,D1.W),D1
	LSL.W	#8,D1
	MOVE.W	D0,D2
	LSR.W	#4,D2
	AND.W	#15,D2
	MOVE.B	(A0,D2.W),D2
	LSL.W	#4,D2
	OR.W	D2,D1
	AND.W	#15,D0
	MOVE.B	(A0,D0.W),D0
	OR.W	D1,D0
	MOVEM.L	(SP)+,D1-D2/A0
	RTS
RtgG7Nb:DC.B	0,3,5,7,9,11,13,15	; MSX level -> nibble
	DC.B	0,5,9,15		; G7 blue
; The 16 sprite colours in SCREEN 8, as G7 bytes (openMSX's GRAPHIC7 sprite
; palette; AmiMSX's Scr8PalSwap on AGA).
RtgG7Sp:DC.B	$00,$01,$0C,$0D,$60,$61,$6C,$6D,$9D,$03,$1C,$1F,$E0,$E3,$FC,$FF
	EVEN

; ---------------------------------------------------------------------------
; Emula1Frame: does this frame go to RTG? RtgNow (and NE) when the play screen
; is open and every mode in the frame is drawn here (RtgMOk), also above a
; mode split. Otherwise the AGA path draws it and the RTG screen keeps its last
; picture; after RTGWAITF AGA frames in a row it goes black (the next RTG
; frame then fills all of it). A game with an odd AGA frame among RTG ones
; (Lilly's Saga) so costs no clear and no full redraw each time.
RTGWAITF=50
	CNOP	0,4
RtgUse:
	SF	RtgNow
	TST.B	RtgOn
	BEQ	RtgUOff
	MOVE.L	D1,-(SP)
	MOVE.B	REGS+ScrModo,D1		; (4.6) Any split of two RTG modes, the
	TST.W	MSplitL			; SCREEN 5/8 pair included: the mode
	BEQ.S	RtgUS			; below it is the one MODESW saw (the
	MOVE.B	RtgMsBot,D1		; frame may end in another).
RtgUS:	MOVE.B	D1,RfBotM
	BSR.S	RtgMOk
	BNE.S	RtgUA
	TST.W	MSplitL
	BEQ.S	RtgUY
	MOVE.B	MSplitTop,D1
	BSR.S	RtgMOk
	BNE.S	RtgUA
RtgUY:	ST	RtgNow
	CLR.W	RtgHold
	BRA.S	RtgUP
RtgUA:	CMP.W	#RTGWAITF,RtgHold	; AGA frames in a row (stops counting
	BCC.S	RtgUP			; once black).
	ADDQ.W	#1,RtgHold
	CMP.W	#RTGWAITF,RtgHold
	BNE.S	RtgUP
	BSR	RtgBlack
RtgUP:	MOVE.B	RtgNow,RtgPrev
	BSR	R5Chk			; (4.5) SCREEN 5 commands on VRAM, or the
	IFD	RTGDBG			; planes rebuilt for this frame.
	BSR	RtgDbSpd
	ENDC
	MOVE.L	(SP)+,D1
RtgUX:	TST.B	RtgNow
	RTS
RtgUOff:TST.B	Rtg5Dir			; (RTG off: the planes are the picture.)
	BEQ.S	RtgUX
	BSR	R5Off
	BRA.S	RtgUX

; ScrModo D1.B drawn on RTG? EQ: SCREEN 1, 2, 4 (0-2), SCREEN 8 (7), and
; SCREEN 5 (3) when its planes mirror VRAM ("100% refresh", DirPrefs+$6B:
; RtgFrame flushes the bands VDP commands drew in to VRAM first); (4.6)
; SCREEN 7 (5) the same way, SCREEN 6 (4: from its planes), SCREEN 3 (8),
; TEXT1 and TEXT2 ($10-$1F). Not: 6 and 9-F (no such mode).
RtgMOk:	CMP.B	#2,D1
	BLS.S	RtgMOY
	CMP.B	#7,D1
	BEQ.S	RtgMOY
	CMP.B	#3,D1
	BEQ.S	RtgMO5
	CMP.B	#4,D1
	BEQ.S	RtgMOY
	CMP.B	#5,D1
	BEQ.S	RtgMO5
	CMP.B	#8,D1
	BEQ.S	RtgMOY
	CMP.B	#$10,D1
	BCC.S	RtgMOY
	BRA.S	RtgMON
RtgMO5:	TST.B	DirPrefs+$6B
	BEQ.S	RtgMON
RtgMOY:	ORI.B	#4,CCR			; EQ
	RTS
RtgMON:	ANDI.B	#$FB,CCR		; NE
	RTS

RtgBlack:
	MOVEM.L	D0-D1/A0-A1,-(SP)
	MOVE.L	RtgMem,A1
	MOVE.W	RtgH,D1
	SUBQ.W	#1,D1
RtgBkR:	MOVE.L	A1,A0
	MOVE.W	RtgW,D0
	TST.B	RtgBpp4
	BNE.S	RtgBk4
	LSR.W	#1,D0
RtgBk4:	SUBQ.W	#1,D0
RtgBkP:
	IFD	RTGDBG
	MOVE.L	#$00F800F8,(A0)+	; (debug: AGA frames red)
	ELSE
	CLR.L	(A0)+
	ENDC
	DBF	D0,RtgBkP
	ADD.L	RtgBpr,A1
	DBF	D1,RtgBkR
	ST	RtgFull
	MOVEM.L	(SP)+,D0-D1/A0-A1
	RTS

; A frame not rendered (frame skip) or not on RTG: its line events are used up
; by ActCopperLine; on RTG frames that is skipped, so they are cleared here.
RtgClrEv:
	MOVEM.L	D0/A0,-(SP)
	LEA	TabRasCMDS,A0
	MOVEQ	#(RTGLINES/4)-1,D0
RtgCEL:	CLR.L	(A0)+
	DBF	D0,RtgCEL
	MOVEM.L	(SP)+,D0/A0
	RTS

; ---------------------------------------------------------------------------
; (4.5) SCREEN 5 VDP commands on VRAM, for RTG frames. On AGA the commands
; draw in the planes with the blitter and VRAM catches up from the planes
; (Pl5Band, ModChg5Go); on RTG that flush, reading the planes in chip RAM,
; was most of the frame on the A1200 (Manbow 2's walls: 70% speed). So while
; Rtg5Dir is set the commands write VRAM (fast RAM) instead, as on the MSX:
; - R5On (RtgFrame, after the flush) sets it for a plain SCREEN 5 frame drawn
;   on RTG (R5Plain: ScrModo 3, no mode split, layout Modo5Dats, not the pair
;   split's BMSK5), the planes valid (V5All clear) and Pl5Band clear.
; - R5Chk (RtgUse, every frame end, before the render) clears it (R5Off)
;   unless this frame is such a frame on RTG again. The planes are then
;   rebuilt from VRAM where commands drew since (R5Rebuild): VBlk5, the 1 KB
;   blocks ActPlanos5 already rebuilds on entering SCREEN 5 (written outside
;   it), mask plane included. In another mode the marks wait for that entry.
; - While it is set VRAM is the master copy: commands write it (VDP2E5V:
;   no Pl5Band, so no flush; the blocks into VBlk5), POINT, SRCH, LMCM and
;   port 98h reads read it (POINTA -> POINTV). Port 98h writes go to VRAM
;   only (CRAM98A -> OUT98V, the block marked). HMMC/LMMC bytes keep going
;   to VRAM (C5In, V5CAct) after
;   it is cleared, then into the planes too.
; Rules as openMSX's VDPCmdEngine (and the SCREEN 8 commands, VDP2Escr8):
; X 0-255 (a DX/SX past it: one dot or byte, at X AND 255), NX 0 = 256,
; clipped at the edge on the DIX side; NY 0 = 1024, Y wraps at 1024; dots 4
; bits, the high nibble the left (even) dot, 128 bytes a line. Logical ops
; 0-4 and T 8-C; 5-7 and D-F write nothing. The registers keep their values
; (as on AGA). Command code: no stack (A7 is the Restas table); the CETm busy
; time is VDP2E's, before this.
	CNOP	0,4
VDP2E5V:
	CMP.L	#MODO5DATS,MSXVideoMode(A3)
	BNE.S	V5Back0
	TST.B	BMSK5
	BNE.S	V5Back0
	MOVEM.L	D0-D7/A0-A6,BUFER(A3)
	MOVEQ	#0,D3
	MOVE.B	D2,D3
	LSR.B	#4,D3
	MOVE.L	(V5Tab.L,D3.W*4),D4
	BEQ.S	V5Back			; (POINT, SRCH, LMCM: as before, reading
	MOVE.B	D2,DVDPREG(A3)		; VRAM through POINTA)
	BCLR	#0,DVDPS2(A3)		; Done (CETm models the busy time).
	SF	V8CAct
	SF	V5CAct
	CLR.W	CONTA2C(A3)
	MOVE.L	D4,A0
	JMP	(A0)
V5Back:	MOVEM.L	BUFER(A3),D0-D7/A0-A6
V5Back0:JMP	Torna5

V5Done:	LEA	REGS,A3			; (the pixel loops use A3)
	MOVEM.L	BUFER(A3),D0-D7/A0-A6
	SWAP	D2
	RTS

	CNOP	0,4
V5Tab:	DC.L	V5Done,V5Done,V5Done,V5Done	; 0-3 STOP
	DC.L	0,V5Pset,0,V5Line		; 4 POINT, 5 PSET, 6 SRCH, 7 LINE
	DC.L	V5Lmmv,V5Lmmm,0,V5Cpu		; 8 LMMV, 9 LMMM, A LMCM, B LMMC
	DC.L	V5Hmmv,V5Hmmm,V5Ymmm,V5Cpu	; C HMMV, D HMMM, E YMMM, F HMMC

; X clip on the DIX side: \1 = X (dots or bytes, 9-bit / 2), \2 = N (1 up),
; \3 scratch, \4 the line's width (256 dots or 128 bytes). \1 past the line:
; one, at \1 AND (\4-1).
V5CL1:	MACRO
	CMP.W	#\4,\1
	BCS.S	\@i
	AND.W	#\4-1,\1
	MOVEQ	#1,\2
	BRA.S	\@x
\@i:	BTST	#2,DVDPARG(A3)
	BEQ.S	\@r
	MOVE.W	\1,\3			; DIX: at most X+1,
	ADDQ.W	#1,\3
	BRA.S	\@m
\@r:	MOVE.W	#\4,\3			; else to the edge.
	SUB.W	\1,\3
\@m:	CMP.W	\3,\2
	BLS.S	\@x
	MOVE.W	\3,\2
\@x:
	ENDM
; The same for two X (\1 source, \2 destination): \3 = N, \4 scratch.
V5CL2:	MACRO
	CMP.W	#\5,\1
	BCC.S	\@o
	CMP.W	#\5,\2
	BCS.S	\@i
\@o:	AND.W	#\5-1,\1
	AND.W	#\5-1,\2
	MOVEQ	#1,\3
	BRA.S	\@x
\@i:	BTST	#2,DVDPARG(A3)
	BEQ.S	\@r
	MOVE.W	\1,\4			; DIX: min(SX, DX) + 1,
	CMP.W	\2,\4
	BLS.S	\@l
	MOVE.W	\2,\4
\@l:	ADDQ.W	#1,\4
	BRA.S	\@m
\@r:	MOVE.W	\1,\4			; else W - max(SX, DX).
	CMP.W	\2,\4
	BCC.S	\@h
	MOVE.W	\2,\4
\@h:	NEG.W	\4
	ADD.W	#\5,\4
\@m:	CMP.W	\4,\3
	BLS.S	\@x
	MOVE.W	\4,\3
\@x:
	ENDM
; NY (0 = 1024) into \1.
V5NY:	MACRO
	MOVE.W	DVDPNY(A3),\1
	AND.W	#$3FF,\1
	BNE.S	\@n
	MOVE.W	#$400,\1
\@n:
	ENDM
; One dot: op \1 (0 IMP, 1 AND, 2 OR, 3 XOR) of colour D3 (0-15) into the
; byte at A0, the left nibble if \2 (X) is even. \3 scratch.
V5PX:	MACRO
	BTST	#0,\2
	BNE.S	\@o
	MOVE.B	D3,\3
	LSL.B	#4,\3
	IFEQ	\1
	AND.B	#$0F,(A0)
	OR.B	\3,(A0)
	ENDC
	IFEQ	\1-1
	OR.B	#$0F,\3
	AND.B	\3,(A0)
	ENDC
	IFEQ	\1-2
	OR.B	\3,(A0)
	ENDC
	IFEQ	\1-3
	EOR.B	\3,(A0)
	ENDC
	BRA.S	\@x
\@o:
	IFEQ	\1
	AND.B	#$F0,(A0)
	OR.B	D3,(A0)
	ENDC
	IFEQ	\1-1
	MOVE.B	D3,\3
	OR.B	#$F0,\3
	AND.B	\3,(A0)
	ENDC
	IFEQ	\1-2
	OR.B	D3,(A0)
	ENDC
	IFEQ	\1-3
	EOR.B	D3,(A0)
	ENDC
\@x:
	ENDM
; The colour (R#44) and op of a one-colour command: D3 = colour 0-15, D4 =
; op 0-3 (NOT: the inverse colour, IMP); T with colour 0, or ops 5-7: done.
V5COP:	MACRO
	MOVE.B	DVDPCL(A3),D3
	AND.W	#15,D3
	MOVEQ	#15,D4
	AND.B	DVDPREG(A3),D4
	BCLR	#3,D4
	BEQ.S	\@t
	TST.B	D3
	BEQ	V5Done
\@t:	CMP.B	#5,D4
	BCC	V5Done
	CMP.B	#4,D4
	BNE.S	\@n
	NOT.B	D3
	AND.W	#15,D3
	MOVEQ	#0,D4
\@n:
	ENDM

; HMMV: bytes of R#44.
V5Hmmv:	MOVE.W	DVDPDX(A3),D5
	AND.W	#$1FF,D5
	LSR.W	#1,D5
	MOVE.W	DVDPNX(A3),D4
	AND.W	#$1FF,D4
	LSR.W	#1,D4
	BNE.S	V5HvN
	MOVE.W	#128,D4
V5HvN:	V5CL1	D5,D4,D6,128
	BTST	#2,DVDPARG(A3)		; (A fill: the same bytes either way.)
	BEQ.S	V5HvR
	SUB.W	D4,D5
	ADDQ.W	#1,D5
V5HvR:	MOVE.B	DVDPCL(A3),D3
	MOVE.B	D3,D1
	LSL.W	#8,D3
	MOVE.B	D1,D3
	MOVE.W	D3,D1
	SWAP	D3
	MOVE.W	D1,D3
	V5NY	D0
	MOVE.W	DVDPDY(A3),D2
	MOVEQ	#1,D7
	BTST	#3,DVDPARG(A3)
	BEQ.S	V5HvL
	MOVEQ	#-1,D7
V5HvL:	MOVEQ	#0,D1
	MOVE.W	D2,D1
	AND.W	#1023,D1
	MOVE.W	D1,D6
	LSR.W	#3,D6
	ST	(VBlk5.L,D6.W)
	LSL.L	#7,D1
	OR.W	D5,D1
	LEA	(DIRVRAM.L,D1.L),A1
	MOVE.W	D4,D6
	LSR.W	#2,D6
	BRA.S	V5HvLc
V5HvLl:	MOVE.L	D3,(A1)+
V5HvLc:	DBF	D6,V5HvLl
	MOVE.W	D4,D6
	AND.W	#3,D6
	BRA.S	V5HvBc
V5HvBl:	MOVE.B	D3,(A1)+
V5HvBc:	DBF	D6,V5HvBl
	ADD.W	D7,D2
	SUBQ.W	#1,D0
	BNE.S	V5HvL
	BRA	V5Done

; HMMM: bytes from (SX, SY); YMMM: from (DX, SY), the whole line from DX on
; the DIX side. Then V5Mv: D0 rows, D1 SY, D2 DY, D4 bytes a row, D5 the
; source byte, A4 the destination byte, D7 the row step, A2 DIX.
V5Hmmm:	MOVE.W	DVDPSX(A3),D5
	AND.W	#$1FF,D5
	LSR.W	#1,D5
	MOVE.W	DVDPDX(A3),D6
	AND.W	#$1FF,D6
	LSR.W	#1,D6
	MOVE.W	DVDPNX(A3),D4
	AND.W	#$1FF,D4
	LSR.W	#1,D4
	BNE.S	V5HmN
	MOVE.W	#128,D4
V5HmN:	V5CL2	D5,D6,D4,D3,128
	BRA.S	V5MvGo
V5Ymmm:	MOVE.W	DVDPDX(A3),D6
	AND.W	#$1FF,D6
	LSR.W	#1,D6
	MOVE.W	#256,D4
	V5CL1	D6,D4,D3,128
	MOVE.W	D6,D5
V5MvGo:	MOVE.W	D6,A4
	V5NY	D0
	MOVE.W	DVDPSY(A3),D1
	MOVE.W	DVDPDY(A3),D2
	MOVEQ	#1,D7
	BTST	#3,DVDPARG(A3)
	BEQ.S	V5MvY
	MOVEQ	#-1,D7
V5MvY:	SUB.L	A2,A2
	BTST	#2,DVDPARG(A3)
	BEQ.S	V5MvR
	ADDQ.W	#1,A2
V5MvR:	MOVEQ	#0,D3
	MOVE.W	D1,D3
	AND.W	#1023,D3
	LSL.L	#7,D3
	OR.W	D5,D3
	LEA	(DIRVRAM.L,D3.L),A0
	MOVEQ	#0,D3
	MOVE.W	D2,D3
	AND.W	#1023,D3
	MOVE.W	D3,D6
	LSR.W	#3,D6
	ST	(VBlk5.L,D6.W)
	LSL.L	#7,D3
	LEA	(DIRVRAM.L,D3.L),A1
	ADDA.W	A4,A1
	CMPA.W	#0,A2
	BNE.S	V5MvD
	MOVE.L	A1,D3			; Rightwards: longs, unless the
	SUB.L	A0,D3			; destination is 1-3 bytes after the
	BLS.S	V5MvL			; source (byte by byte, the VDP's order,
	CMP.L	#4,D3			; repeats them).
	BCS.S	V5MvB
V5MvL:	MOVE.W	D4,D6
	LSR.W	#2,D6
	BRA.S	V5MvLc
V5MvLl:	MOVE.L	(A0)+,(A1)+
V5MvLc:	DBF	D6,V5MvLl
	MOVE.W	D4,D6
	AND.W	#3,D6
	BRA.S	V5MvBc
V5MvB:	MOVE.W	D4,D6
	BRA.S	V5MvBc
V5MvBl:	MOVE.B	(A0)+,(A1)+
V5MvBc:	DBF	D6,V5MvBl
	BRA.S	V5MvN
V5MvD:	ADDQ.L	#1,A0			; Leftwards: bytes downwards.
	ADDQ.L	#1,A1
	MOVE.W	D4,D6
	BRA.S	V5MvDc
V5MvDl:	MOVE.B	-(A0),-(A1)
V5MvDc:	DBF	D6,V5MvDl
V5MvN:	ADD.W	D7,D1
	ADD.W	D7,D2
	SUBQ.W	#1,D0
	BNE	V5MvR
	BRA	V5Done

; Row setup of the dot loops: A4 = VRAM line \1 (a word in memory or a
; register), its block marked. Uses D4, D7.
V5ROW:	MACRO
	MOVEQ	#0,D4
	MOVE.W	\1,D4
	AND.W	#1023,D4
	MOVE.W	D4,D7
	LSR.W	#3,D7
	ST	(VBlk5.L,D7.W)
	LSL.L	#7,D4
	LEA	(DIRVRAM.L,D4.L),A4
	ENDM
; A0 = the byte of dot \1 in line A4. Uses D7.
V5DOT:	MACRO
	MOVE.W	\1,D7
	AND.W	#255,D7
	LSR.W	#1,D7
	LEA	(A4,D7.W),A0
	ENDM

; LMMV: R#44's colour with the op. D0 rows, D1 dots a row, D2 dots left,
; D5 X, D6 Y; A1 DX, A2 X step, A5 Y step.
V5Lmmv:	V5COP
	MOVE.W	DVDPDX(A3),D5
	AND.W	#$1FF,D5
	MOVE.W	DVDPNX(A3),D1
	AND.W	#$1FF,D1
	BNE.S	V5LvN
	MOVE.W	#256,D1
V5LvN:	V5CL1	D5,D1,D2,256
	MOVE.W	D5,A1
	V5NY	D0
	MOVE.W	DVDPDY(A3),D6
	MOVE.W	#1,A2
	BTST	#2,DVDPARG(A3)
	BEQ.S	V5LvX
	MOVE.W	#-1,A2
V5LvX:	MOVE.W	#1,A5
	BTST	#3,DVDPARG(A3)
	BEQ.S	V5LvY
	MOVE.W	#-1,A5
V5LvY:	MOVE.L	(V5LvT.L,D4.W*4),A0
	JMP	(A0)
V5LVLP:	MACRO
\@r:	V5ROW	D6
	MOVE.W	A1,D5
	MOVE.W	D1,D2
\@p:	V5DOT	D5
	V5PX	\1,D5,D4
	ADD.W	A2,D5
	SUBQ.W	#1,D2
	BNE.S	\@p
	ADD.W	A5,D6
	SUBQ.W	#1,D0
	BNE.S	\@r
	BRA	V5Done
	ENDM
	CNOP	0,4
V5LvT:	DC.L	V5Lv0,V5Lv1,V5Lv2,V5Lv3
V5Lv0:	V5LVLP	0
V5Lv1:	V5LVLP	1
V5Lv2:	V5LVLP	2
V5Lv3:	V5LVLP	3

; LMMM: dot by dot from (SX, SY) with the op (T: source 0 leaves the dot).
; D0 rows, D1 dots a row, D2 dots left, D3 the dot, D5 DX, D6 SX; A1 SX, A6
; DX at the row start, A2 X step, A3 Y step, A4/A5 the lines; V5DY/V5SY.
V5Lmmm:	MOVE.W	DVDPSX(A3),D6
	AND.W	#$1FF,D6
	MOVE.W	DVDPDX(A3),D5
	AND.W	#$1FF,D5
	MOVE.W	DVDPNX(A3),D1
	AND.W	#$1FF,D1
	BNE.S	V5LmN
	MOVE.W	#256,D1
V5LmN:	V5CL2	D6,D5,D1,D2,256
	MOVE.W	D6,A1
	MOVE.W	D5,A6
	MOVE.W	DVDPSY(A3),V5SY
	MOVE.W	DVDPDY(A3),V5DY
	V5NY	D0
	MOVE.W	#1,A2
	BTST	#2,DVDPARG(A3)
	BEQ.S	V5LmX
	MOVE.W	#-1,A2
V5LmX:	MOVEQ	#15,D4
	AND.B	DVDPREG(A3),D4
	MOVE.W	D4,D7
	AND.W	#7,D7
	CMP.W	#5,D7
	BCC	V5Done			; (ops 5-7, D-F: nothing)
	BTST	#3,D4
	BEQ.S	V5LmT
	ADDQ.W	#5,D7
V5LmT:	MOVE.L	(V5LmTb.L,D7.W*4),A0
	MOVEQ	#1,D7
	BTST	#3,DVDPARG(A3)
	BEQ.S	V5LmY
	MOVEQ	#-1,D7
V5LmY:	MOVE.W	D7,A3			; (V5Done sets A3 again)
	JMP	(A0)
V5LMLP:	MACRO
\@r:	MOVEQ	#0,D4
	MOVE.W	V5SY,D4
	AND.W	#1023,D4
	LSL.L	#7,D4
	LEA	(DIRVRAM.L,D4.L),A5
	V5ROW	V5DY
	MOVE.W	A6,D5
	MOVE.W	A1,D6
	MOVE.W	D1,D2
\@p:	MOVE.W	D6,D7
	AND.W	#255,D7
	LSR.W	#1,D7
	MOVE.B	(A5,D7.W),D3
	BTST	#0,D6
	BNE.S	\@o
	LSR.B	#4,D3
\@o:	AND.W	#15,D3
	IFNE	\2
	BEQ.S	\@s
	ENDC
	IFEQ	\1-4
	NOT.B	D3
	AND.W	#15,D3
	ENDC
	V5DOT	D5
	IFEQ	\1-4
	V5PX	0,D5,D4
	ELSE
	V5PX	\1,D5,D4
	ENDC
\@s:	ADD.W	A2,D5
	ADD.W	A2,D6
	SUBQ.W	#1,D2
	BNE	\@p
	MOVE.W	A3,D7
	ADD.W	D7,V5DY
	ADD.W	D7,V5SY
	SUBQ.W	#1,D0
	BNE	\@r
	BRA	V5Done
	ENDM
	CNOP	0,4
V5LmTb:	DC.L	V5Lm0,V5Lm1,V5Lm2,V5Lm3,V5Lm4
	DC.L	V5Lm5,V5Lm6,V5Lm7,V5Lm8,V5Lm9
V5Lm0:	V5LMLP	0,0
V5Lm1:	V5LMLP	1,0
V5Lm2:	V5LMLP	2,0
V5Lm3:	V5LMLP	3,0
V5Lm4:	V5LMLP	4,0
V5Lm5:	V5LMLP	0,1
V5Lm6:	V5LMLP	1,1
V5Lm7:	V5LMLP	2,1
V5Lm8:	V5LMLP	3,1
V5Lm9:	V5LMLP	4,1

; PSET: one dot at (DX, DY).
V5Pset:	V5COP
	MOVE.W	D4,D1			; (V5ROW uses D4)
	MOVE.W	DVDPDX(A3),D5
	V5ROW	DVDPDY(A3)
	V5DOT	D5
	MOVE.L	(V5PsT.L,D1.W*4),A1
	JMP	(A1)
	CNOP	0,4
V5PsT:	DC.L	V5Ps0,V5Ps1,V5Ps2,V5Ps3
V5Ps0:	V5PX	0,D5,D4
	BRA	V5Done
V5Ps1:	V5PX	1,D5,D4
	BRA	V5Done
V5Ps2:	V5PX	2,D5,D4
	BRA	V5Done
V5Ps3:	V5PX	3,D5,D4
	BRA	V5Done

; LINE as LINE8 (openMSX): NX the long side, NY the short one, NX+1 dots,
; ends early if X leaves the line. D0 NX, D1 NY, D2 dots done, D3 the
; colour, D4 the error (ASX), D5 X, D6 Y; A2/A5 the X/Y steps.
V5Line:	V5COP
	BTST	#0,DVDPARG(A3)		; MAJ: Y the long side.
	BEQ.S	V5LnM
	ADDQ.W	#4,D4
V5LnM:	MOVE.L	(V5LnT.L,D4.W*4),A6
	MOVE.W	DVDPNX(A3),D0
	AND.W	#$03FF,D0
	MOVE.W	DVDPNY(A3),D1
	AND.W	#$03FF,D1
	MOVE.W	D0,D4			; ASX = (NX - 1) / 2.
	SUBQ.W	#1,D4
	LSR.W	#1,D4
	MOVE.W	DVDPDX(A3),D5
	AND.W	#$1FF,D5
	MOVE.W	DVDPDY(A3),D6
	MOVE.W	#1,A2
	BTST	#2,DVDPARG(A3)
	BEQ.S	V5LnX
	MOVE.W	#-1,A2
V5LnX:	MOVE.W	#1,A5
	BTST	#3,DVDPARG(A3)
	BEQ.S	V5LnY
	MOVE.W	#-1,A5
V5LnY:	MOVEQ	#0,D2
	JMP	(A6)
V5LNLP:	MACRO
\@l:	MOVEQ	#0,D7
	MOVE.W	D6,D7
	AND.W	#1023,D7
	LSL.L	#7,D7
	LEA	(DIRVRAM.L,D7.L),A0
	MOVE.W	D5,D7
	AND.W	#255,D7
	LSR.W	#1,D7
	ADDA.W	D7,A0
	MOVE.W	D6,D7
	AND.W	#1023,D7
	LSR.W	#3,D7
	ST	(VBlk5.L,D7.W)
	V5PX	\1,D5,D7
	IFEQ	\2
	ADD.W	A2,D5			; The long side's step each dot,
	ELSE
	ADD.W	A5,D6
	ENDC
	CMP.W	D1,D4			; the short side's when ASX < NY.
	BCC.S	\@n
	ADD.W	D0,D4
	IFEQ	\2
	ADD.W	A5,D6
	ELSE
	ADD.W	A2,D5
	ENDC
\@n:	SUB.W	D1,D4
	AND.W	#$03FF,D4
	CMP.W	D0,D2			; NX+1 dots, or X past the edge.
	BEQ.S	\@x
	ADDQ.W	#1,D2
	BTST	#8,D5
	BEQ	\@l
\@x:	BRA	V5Done
	ENDM
	CNOP	0,4
V5LnT:	DC.L	V5Ln0,V5Ln1,V5Ln2,V5Ln3,V5Ln4,V5Ln5,V5Ln6,V5Ln7
V5Ln0:	V5LNLP	0,0
V5Ln1:	V5LNLP	1,0
V5Ln2:	V5LNLP	2,0
V5Ln3:	V5LNLP	3,0
V5Ln4:	V5LNLP	0,1
V5Ln5:	V5LNLP	1,1
V5Ln6:	V5LNLP	2,1
V5Ln7:	V5LNLP	3,1

; HMMC (bytes) and LMMC (dots with the op): the first byte (R#44) now, the
; others as the CPU writes R#44 (VDP2C: C5In while V5CAct), as CPU8.
; V5COp: the op, -1 for HMMC; V5CX in bytes (HMMC) or dots.
V5Cpu:	MOVEQ	#15,D0
	AND.B	DVDPREG(A3),D0
	MOVE.B	D2,D1
	AND.B	#$F0,D1
	CMP.B	#$F0,D1
	BNE.S	V5CpL
	MOVEQ	#-1,D0
	MOVE.W	DVDPDX(A3),D5
	AND.W	#$1FF,D5
	LSR.W	#1,D5
	MOVE.W	DVDPNX(A3),D4
	AND.W	#$1FF,D4
	LSR.W	#1,D4
	BNE.S	V5CpN
	MOVE.W	#128,D4
V5CpN:	V5CL1	D5,D4,D6,128
	BRA.S	V5CpC
V5CpL:	MOVE.W	DVDPDX(A3),D5
	AND.W	#$1FF,D5
	MOVE.W	DVDPNX(A3),D4
	AND.W	#$1FF,D4
	BNE.S	V5CpM
	MOVE.W	#256,D4
V5CpM:	V5CL1	D5,D4,D6,256
V5CpC:	MOVE.W	D0,V5COp
	MOVE.W	D5,V5CDX
	MOVE.W	D5,V5CX
	MOVE.W	D4,V5CNX
	MOVE.W	D4,V5CN
	MOVE.W	DVDPDY(A3),D1
	AND.W	#$3FF,D1
	MOVE.W	D1,V5CY
	V5NY	D1
	MOVE.W	D1,V5CNY
	BSET	#0,DVDPS2(A3)		; Busy until the last byte.
	ST	V5CAct
	MOVE.B	DVDPCL(A3),D3
	BRA.S	C5Byte
C5In:	MOVE.B	DVDPCL(A3),D3		; (VDP2C) The next byte.
C5Byte:	MOVEQ	#0,D5
	MOVE.W	V5CY,D5
	AND.W	#1023,D5
	MOVE.W	D5,D6
	LSR.W	#3,D6			; D6 = its 1 KB block
	LSL.L	#7,D5
	MOVE.W	V5CX,D4
	MOVE.W	V5COp,D0
	BPL.S	C5Px
	OR.W	D4,D5			; HMMC: the byte.
	LEA	(DIRVRAM.L,D5.L),A0
	MOVE.B	D3,(A0)
	BRA	C5Upd
C5Px:	MOVE.W	D4,D1
	LSR.W	#1,D1
	OR.W	D1,D5
	LEA	(DIRVRAM.L,D5.L),A0
	AND.W	#15,D3
	BCLR	#3,D0			; T: colour 0 leaves the dot.
	BEQ.S	C5NT
	TST.B	D3
	BEQ	C5Next
C5NT:	CMP.W	#5,D0
	BCC	C5Next
	CMP.W	#4,D0
	BNE.S	C5Op
	NOT.B	D3
	AND.W	#15,D3
	MOVEQ	#0,D0
C5Op:	MOVE.L	(C5OpT.L,D0.W*4),A1
	JMP	(A1)
	CNOP	0,4
C5OpT:	DC.L	C5O0,C5O1,C5O2,C5O3
C5O0:	V5PX	0,D4,D1
	BRA.S	C5Upd
C5O1:	V5PX	1,D4,D1
	BRA.S	C5Upd
C5O2:	V5PX	2,D4,D1
	BRA.S	C5Upd
C5O3:	V5PX	3,D4,D1
; The planes: stale while Rtg5Dir (the block marked); once it is cleared and
; the planes are SCREEN 5's again, the byte goes there too (as OUT98A).
C5Upd:	TST.B	Rtg5Dir
	BNE.S	C5Mk
	CMP.L	#MODO5DATS,MSXVideoMode(A3)
	BNE.S	C5Mk
	TST.B	BMSK5
	BNE.S	C5Mk
	TST.B	PlMode
	BNE.S	C5Mk
	TST.B	V5All
	BNE.S	C5Next
	MOVE.L	A0,D1
	SUB.L	#DIRVRAM,D1
	ADD.L	D1,D1
	MOVEQ	#0,D2
	MOVE.B	(A0),D2
	MOVE.W	(TABOUTSC5.L,D2.W*2),D2
	BFINS	D2,SCR0+$18000{D1:2}
	LSR.W	#2,D2
	BFINS	D2,SCR0+$10000{D1:2}
	LSR.B	#2,D2
	BFINS	D2,SCR0+$08000{D1:2}
	LSR.B	#2,D2
	BFINS	D2,SCR0+$00000{D1:2}
	LSR.B	#2,D2
	BFINS	D2,SCR0-$08000{D1:2}
	BRA.S	C5Next
C5Mk:	ST	(VBlk5.L,D6.W)
C5Next:	MOVEQ	#1,D0
	BTST	#2,DVDPARG(A3)
	BEQ.S	C5TX
	MOVEQ	#-1,D0
C5TX:	ADD.W	D0,V5CX
	SUBQ.W	#1,V5CN
	BNE.S	C5Ret
	MOVE.W	V5CDX,V5CX		; The next row.
	MOVE.W	V5CNX,V5CN
	MOVEQ	#1,D0
	BTST	#3,DVDPARG(A3)
	BEQ.S	C5TY
	MOVEQ	#-1,D0
C5TY:	ADD.W	D0,V5CY
	SUBQ.W	#1,V5CNY
	BEQ.S	C5End
	TST.W	V5CY
	BPL.S	C5Ret
C5End:	BCLR	#0,DVDPS2(A3)
	SF	V5CAct
C5Ret:	MOVEM.L	BUFER(A3),D0-D7/A0-A6
	SWAP	D2
	RTS

; POINTA (POINT, SRCH, LMCM, port 98h reads in SCREEN 5/7) with Rtg5Dir:
; SCREEN 5's byte D1 (VRAM offset) from VRAM, not the planes.
POINTV:	CMP.L	#MODO5DATS,REGS+MSXVideoMode
	BNE.L	POINTA2
	TST.B	BMSK5
	BNE.L	POINTA2
	AND.L	#$1FFFF,D1
	MOVE.B	(DIRVRAM.L,D1.L),D1
	AND.W	#$FF,D1
	RTS

; OUT98A/OUT98AT (SCREEN 5, layout Modo5Dats) with Rtg5Dir: the byte is in
; VRAM (CRAM98A); the planes (5 bit-field writes to chip RAM) wait, the block
; marked for R5Rebuild. D1 = its VRAM offset.
OUT98V:	LSR.L	#8,D1
	LSR.L	#2,D1
	ST	(VBlk5.L,D1.W)
	MOVEQ	#0,D1
	RTS

; EQ: a plain SCREEN 5 frame (R5On/R5Chk).
R5Plain:CMP.B	#3,REGS+ScrModo
	BNE.S	R5PlX
	TST.W	MSplitL
	BNE.S	R5PlX
	CMP.L	#MODO5DATS,REGS+MSXVideoMode
	BNE.S	R5PlX
	TST.B	BMSK5
R5PlX:	RTS

; RtgFrame, after the flush: VRAM-direct commands from the next frame on.
; Not while HMMC/LMMC still draws in the planes (until it ends).
R5On:	TST.B	Rtg5Dir
	BNE.S	R5OnX
	BSR	R5Plain
	BNE.S	R5OnX
	TST.B	V5All
	BNE.S	R5OnX
	TST.B	PlMode
	BNE.S	R5OnX
	TST.B	Pl5Dirty
	BNE.S	R5OnX
	TST.B	DirPrefs+$6B
	BEQ.S	R5OnX
	BTST	#0,REGS+DVDPS2
	BEQ.S	R5OnY
	TST.B	V5CAct
	BNE.S	R5OnY
	BTST	#7,REGS+DVDPREG		; (Bits 7, 5 and 4: B LMMC, F HMMC.)
	BEQ.S	R5OnY
	BTST	#5,REGS+DVDPREG
	BEQ.S	R5OnY
	BTST	#4,REGS+DVDPREG
	BNE.S	R5OnX
R5OnY:	ST	Rtg5Dir
	IFD	RTGDBG
	ADDQ.W	#1,RdOn
	ENDC
R5OnX:	RTS

; RtgUse, the frame's path decided: Rtg5Dir stays only for a plain SCREEN 5
; frame on RTG.
R5Chk:	TST.B	Rtg5Dir
	BEQ.S	R5CkX
	TST.B	RtgNow
	BEQ.S	R5Off
	BSR	R5Plain
	BNE.S	R5Off
R5CkX:	RTS
R5Off:	SF	Rtg5Dir
	CMP.L	#MODO5DATS,REGS+MSXVideoMode	; (In another layout or mode
	BNE.S	R5OfX			; the marks wait for ActPlanos5.)
	TST.B	BMSK5
	BNE.S	R5OfX
	TST.B	V5All
	BNE.S	R5OfX
	TST.B	PlMode
	BNE.S	R5OfX
	BSR	R5Rebuild
R5OfX:	RTS

; The SCREEN 5 planes from VRAM for the 1 KB blocks marked in VBlk5 (as
; ActPlanos5's PU4_BUC), and the mask plane (any dot not 0), which the
; transparent ops read and PU4_BUC leaves. Keeps every register.
R5Rebuild:
	MOVEM.L	D0-D7/A0-A6,-(SP)
R5RbW:	BTST	#14,$DFF002		; (no blit since R5On: a guard)
	BNE.S	R5RbW
	LEA	VBlk5,A6
R5RbB:	TST.B	(A6)
	BEQ	R5RbN
	SF	(A6)
	ST	SCRTDirty
	IFD	RTGDBG
	ADDQ.W	#1,RdReb
	ENDC
	MOVE.L	A6,D7
	SUB.L	#VBlk5,D7
	LSL.L	#8,D7			; 256 plane bytes per 1 KB of VRAM.
	LEA	(SCR0.L,D7.L),A0
	LEA	(SCR0+$8000,D7.L),A1
	LEA	(SCR0+$10000,D7.L),A2
	LEA	(SCR0+$18000,D7.L),A5
	LEA	(SCR0-$8000,D7.L),A3
	LSL.L	#2,D7
	LEA	(DIRVRAM.L,D7.L),A4
	MOVE.W	#(1024/8)-1,D7
R5RbL:	MOVEQ	#0,D6
	MOVE.B	(A4)+,D6		; Pixels 0-7 (VRAM bytes 0-3) -> D4,
	MOVE.L	(C2PTab.L,D6.W*4),D4	; plane p in byte p.
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
	MOVE.B	(A4)+,D6		; Pixels 8-15 (bytes 4-7) -> D5.
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
	MOVE.W	D4,D0			; Plane words: pixels 0-7 high byte,
	LSL.W	#8,D0			; 8-15 low byte.
	MOVE.B	D5,D0
	MOVE.W	D0,(A0)+
	MOVE.W	D0,D1
	LSR.L	#8,D4
	LSR.L	#8,D5
	MOVE.W	D4,D0
	LSL.W	#8,D0
	MOVE.B	D5,D0
	MOVE.W	D0,(A1)+
	OR.W	D0,D1
	LSR.L	#8,D4
	LSR.L	#8,D5
	MOVE.W	D4,D0
	LSL.W	#8,D0
	MOVE.B	D5,D0
	MOVE.W	D0,(A2)+
	OR.W	D0,D1
	LSR.L	#8,D4
	LSR.L	#8,D5
	MOVE.W	D4,D0
	LSL.W	#8,D0
	MOVE.B	D5,D0
	MOVE.W	D0,(A5)+
	OR.W	D0,D1
	MOVE.W	D1,(A3)+		; The mask plane.
	DBF	D7,R5RbL
R5RbN:	ADDQ.L	#1,A6
	CMPA.L	#VBlk5+128,A6
	BCS	R5RbB
	MOVEM.L	(SP)+,D0-D7/A0-A6
	RTS

; ---------------------------------------------------------------------------
; The frame, at the end of the MSX frame (Emula1Frame, RtgNow): every display
; line from VRAM with its own events (TabRasCMDS/TabRasDATA, PalEvBuf,
; BlankTab), the table split (TSplit) and mode split (MSplitL), into RtgLB as
; palette indices, sprites on top, then written to the screen unless the line
; is as last frame. Uses the stack lightly (BufBasura).
	CNOP	0,4
RtgFrame:
	MOVEM.L	D0-D7/A0-A6,-(SP)
	IFD	RTGSNAPHK		; (test builds: after a key-script SNAP)
	TST.W	SnapHold
	BEQ.S	RtgFrSH
	CLR.W	SnapHold
	IFD	RTGSHOT
	BSR	RtgShGrab
	ENDC
	IFD	SCANCYC
	BSR	RtgCyc
	ENDC
RtgFrSH:
	ENDC
	IFD	RTGDBG
	BSR	RtgBeam
	MOVE.L	D0,RtgTa
	ENDC
	LEA	REGS,A3
; SCREEN 5 in the frame: VDP commands draw in the AGA planes only (Pl5Band),
; so those bands go to VRAM first (ModChg5Go, as on leaving the mode). It
; keeps its registers in BUFER(A3), where Emula1Frame's caller keeps all 16
; of its own (A7 too): those are copied aside and back.
	TST.B	BMSK5			; (4.6) The pair split, SCR0 SCREEN 8's:
	BNE	RtgFr5N			; SCREEN 5 is in VRAM only.
	CMP.B	#3,RfBotM
	BEQ.S	RtgFr5
	CMP.B	#5,RfBotM		; (4.6) SCREEN 7: its bands (P7Band, the
	BEQ.S	RtgFr7			; planar mapping) the same way.
	TST.W	MSplitL
	BEQ.S	RtgFr5N
	CMP.B	#3,MSplitTop
	BNE.S	RtgFr5N
RtgFr5:
	IFD	RTGFLUSHALL		; (debug: every band, every frame)
	MOVE.L	#-1,Pl5Band
	MOVE.L	#-1,Pl5Band+4
	ST	Pl5Dirty
	ENDC
	IFD	RTGNOFLUSH		; (debug: VRAM never from the planes)
	BRA	RtgFr5N
	ENDC
	TST.B	Pl5Dirty
	BEQ.S	RtgFr5N
	SF	Chg7
RtgFr5G:LEA	BUFER(A3),A0
	LEA	RtgBufSv,A1
	MOVEQ	#16-1,D0
RtgFr5S:MOVE.L	(A0)+,(A1)+
	DBF	D0,RtgFr5S
	JSR	ModChg5Go
	LEA	RtgBufSv,A0
	LEA	BUFER(A3),A1
	MOVEQ	#16-1,D0
RtgFr5R:MOVE.L	(A0)+,(A1)+
	DBF	D0,RtgFr5R
	BRA.S	RtgFr5N
RtgFr7:	TST.B	Pl5Dirty
	BEQ.S	RtgFr5N
	ST	Chg7
	BRA.S	RtgFr5G
RtgFr5N:
	BSR	R5On			; (4.5) VRAM-direct commands from now on?
	IFD	RTGDBG
	MOVE.L	A0,-(SP)
	LEA	RdFlush,A0
	BSR	RtgTime
	MOVE.L	(SP)+,A0
	ENDC
; SCREEN 8 in the frame: the sprites read SPRSH (SprVB), the logical view
; that PRINT8 brings up to date on AGA frames (SprShChk keeps every register).
; (4.6) SCREEN 7 too (its sprites read SPRSH as well: PRINT7's SprShChk).
	SF	RfG7F
	CMP.B	#7,RfBotM
	BEQ.S	RtgFr8
	CMP.B	#5,RfBotM
	BEQ.S	RtgFr8
	TST.W	MSplitL
	BEQ.S	RtgFr8N
	CMP.B	#5,MSplitTop
	BEQ.S	RtgFr8
	CMP.B	#7,MSplitTop
	BNE.S	RtgFr8N
RtgFr8:	ST	RfG7F
	JSR	SprShChk
RtgFr8N:
; (4.6) SCREEN 6 reads its planes (VDP commands draw there only): no blit
; may still be running. TEXT2's blink phase: MIRAFLASH, as PRINT9 on AGA.
	CMP.B	#4,RfBotM
	BEQ.S	RtgFrW6
	TST.W	MSplitL
	BEQ.S	RtgFrW6N
	CMP.B	#4,MSplitTop
	BNE.S	RtgFrW6N
RtgFrW6:BTST	#14,$DFF002
	BNE.S	RtgFrW6
RtgFrW6N:
	CMP.B	#$12,RfBotM
	BNE.S	RtgFrT2N
	JSR	MIRAFLASH
RtgFrT2N:
	MOVE.W	#192,RfN
	BTST	#7,DVDP9(A3)		; LN: 212 lines.
	BEQ.S	RtgFr1
	MOVE.W	#212,RfN
RtgFr1:	MOVE.B	DVDP7(A3),D0
	AND.B	#15,D0
	CMP.B	#4,RfBotM		; (4.6) SCREEN 6: R#7 AND 3 (as on AGA).
	BNE.S	RtgFrB6
	AND.B	#3,D0
RtgFrB6:MOVE.B	D0,RfBord
	MOVE.B	TopR8,RfR8		; R#8 of the playfield (MIDSAMPLE).
	MOVE.B	DVDP1(A3),RfR1
	SF	RfV9
	TST.B	V9958On
	SNE	RfV9
; Line 0's state.
	MOVE.B	TabRasDATA+1,RfR2
	MOVE.B	TabRasDATA+3,RfR18
	MOVE.B	TabRasDATA+4,RfR23
	MOVE.B	TabRasDATA+5,RfR27
	MOVE.B	TabRasDATA+6,RfR25
	MOVE.B	TabRasDATA+7,RfR26
	IFD	RTGDBG
	MOVE.B	RfR2,RtgDb0R2
	MOVE.B	RfR23,RtgDb0R23
	ENDC
	SF	RfBlank
	CMP.W	#$8100,MCOPP96+2	; R#1 BL as the frame started.
	SNE	RfBlank
	LEA	PalTop,A0
	BSR	RtgPal
; The display's top: R#18's vertical adjust (high nibble, 7 = centre: openMSX
; (R18 >> 4) ^ 7), and 10 lines lower in 192-line mode.
	MOVE.B	RfR18,D0
	LSR.B	#4,D0
	EOR.B	#7,D0
	EXT.W	D0
	SUBQ.W	#7,D0
	CMP.W	#192,RfN
	BNE.S	RtgFrY
	ADD.W	#10,D0
RtgFrY:	MOVEQ	#0,D1
	MOVE.B	RtgScl,D1
	MULS.W	D1,D0
	ADD.W	RtgOY,D0
	BPL.S	RtgFrY1
	MOVEQ	#0,D0
RtgFrY1:MOVE.W	RfN,D2			; (Y0 + N s <= H)
	MULU.W	D1,D2
	MOVE.W	RtgH,D3
	SUB.W	D2,D3
	CMP.W	D3,D0
	BLE.S	RtgFrY2
	MOVE.W	D3,D0
RtgFrY2:MOVE.W	D0,RfY0
; The border: the whole screen again when its colour or the display's top
; changed (the lines then are all new).
	MOVEQ	#0,D0
	MOVE.B	RfBord,D0
	MOVE.L	(RfLut,PC,D0.W*4),D0
	CMP.B	#7,RfBotM		; SCREEN 8: R#7 is a G7 colour.
	BNE.S	RtgFrB7
	MOVEQ	#0,D0
	MOVE.B	DVDP7(A3),D0
	MOVE.L	(RtgG7Lut.L,D0.W*4),D0
RtgFrB7:MOVE.L	D0,RfBdPix
	TST.B	RtgFull
	BNE.S	RtgFrFill
	CMP.L	RtgBdLast,D0
	BNE.S	RtgFrFill
	MOVE.W	RfY0,D1
	CMP.W	RtgY0Last,D1
	BNE.S	RtgFrFill
	TST.B	RfBlOn			; (blended: and when the lines' count
	BEQ.S	RtgFrNoFill		; changed: the last blend row's lower
	MOVE.W	RfN,D1			; line is another)
	CMP.W	RtgNLast,D1
	BEQ.S	RtgFrNoFill
RtgFrFill:
	BSR	RtgFill
RtgFrNoFill:
	SF	RfPrvN
	MOVEQ	#0,D7			; D7 = display line
RtgFrL:
	LEA	TabRasCMDS,A0
	MOVE.B	(A0,D7.W),D6		; This line's events, used up.
	CLR.B	(A0,D7.W)
	IFD	RTGDBG
	MOVE.B	D6,RfDbgFl
	ENDC
	TST.B	D6
	BEQ	RtgFrEvX
	LEA	(TabRasDATA.L,D7.W*8),A1
	BTST	#0,D6
	BEQ.S	RtgFrE1
	MOVE.B	1(A1),RfR2
	MOVE.B	4(A1),RfR23
RtgFrE1:BTST	#1,D6
	BEQ.S	RtgFrE2
	MOVE.B	3(A1),RfR18
	MOVE.B	5(A1),RfR27
	MOVE.B	6(A1),RfR25
	MOVE.B	7(A1),RfR26
RtgFrE2:BTST	#2,D6
	BEQ.S	RtgFrE3
	TST.W	D7
	BEQ.S	RtgFrE3			; (line 0: PalTop, above)
	MOVE.W	PalEvN,D0		; This line's palette event (the last).
RtgFrPE:SUBQ.W	#1,D0
	BMI.S	RtgFrE3
	CMP.W	(PalEvLines.L,D0.W*2),D7
	BNE.S	RtgFrPE
	LSL.W	#5,D0
	LEA	(PalEvBuf.L,D0.W),A0
	BSR	RtgPal
RtgFrE3:BTST	#3,D6
	BEQ.S	RtgFrEvX
	LEA	BlankTab,A0
	CMP.B	#1,(A0,D7.W)
	SEQ	RfBlank
RtgFrEvX:
	CMP.W	RfN,D7
	BCC	RtgFrNext		; (events below the display: used up only)
; The line's mode and tables.
	MOVE.B	RfBotM,D0
	MOVE.W	MSplitL,D1
	BEQ.S	RtgFrM
	CMP.W	D1,D7
	BCC.S	RtgFrM
	MOVE.B	MSplitTop,D0
RtgFrM:	MOVE.B	D0,RfMode
	CMP.B	#7,D0
	SEQ	RfG7			; (G7 colours in the line: RtgPut)
	AND.W	#$1F,D0			; (4.6) Wide (512 dots), the sprite tables.
	MOVE.B	(RtgMAtT,PC,D0.W),RfMAt
	MOVE.W	DVDP3(A3),RfR3		; (R#10 high, R#3 low)
	MOVE.B	DVDP4+1(A3),RfR4
	MOVE.W	TSplit,D1		; Above a table split: the tables before.
	BEQ.S	RtgFrT
	CMP.W	D1,D7
	BCC.S	RtgFrT
	MOVE.W	TA_DVDP3,RfR3
	MOVE.B	TA_DVDP4+1,RfR4
RtgFrT:
	LEA	RtgLB,A4		; A4 = the line's 256 indices
	TST.B	RfBlank
	BEQ.S	RtgFrDraw
	BCLR	#0,RfMAt		; (256 dots)
	MOVE.B	RfBord,D0		; Display off: the border colour.
	TST.B	RfG7
	BEQ.S	RtgFrBF
	MOVE.B	DVDP7(A3),D0
RtgFrBF:BSR	RtgLBFill
	BRA	RtgFrOut
RtgFrDraw:
	BSR	RtgBg
	BTST	#1,RfR8			; SPD: sprites off.
	BEQ.S	RtgFrSp
	TST.B	BandSprOn		; (4.6) Unless a band has them on (as
	BEQ.S	RtgFrMsk		; AGA's SPRMODE5/6: Manbow 2's title, the
	TST.W	BandN			; logo off, START on): sprite mode 2
	BEQ.S	RtgFrMsk		; lines, RtgSpr2 reads each band's SPD.
	MOVE.B	RfMode,D0
	CMP.B	#1,D0
	BLS.S	RtgFrMsk
	CMP.B	#8,D0
	BCC.S	RtgFrMsk
	BSR	RtgSpr2
	BRA.S	RtgFrMsk
RtgFrSp:MOVE.B	RfMode,D0
	BEQ.S	RtgFrS1
	CMP.B	#1,D0
	BNE.S	RtgFrS2
RtgFrS1:BSR	RtgSpr1
	BRA.S	RtgFrMsk
RtgFrS2:CMP.B	#8,D0			; (4.6) SCREEN 3: mode 1; TEXT: none.
	BEQ.S	RtgFrS1
	BHI.S	RtgFrMsk
	BSR	RtgSpr2
RtgFrMsk:
	TST.B	RfV9			; V9958 MSK: the left 8 dots in the
	BEQ.S	RtgFrOut		; border colour.
	BTST	#1,RfR25
	BEQ.S	RtgFrOut
	MOVE.B	RfBord,D0
	MOVEQ	#8-1,D1
	BTST	#0,RfMAt		; (wide: 16)
	BEQ.S	RtgFrMk
	MOVEQ	#16-1,D1
RtgFrMk:MOVE.B	D0,(A4,D1.W)
	DBF	D1,RtgFrMk
RtgFrOut:
	IFD	RTGDBG			; (debug: blank lines marked green, dots
	TST.B	RfBlank			; 0-3)
	BEQ.S	RtgFrDb
	MOVE.L	#$04040404,(A4)
RtgFrDb:
	ENDC
	BSR	RtgPut
RtgFrNext:
	ADDQ.W	#1,D7
	CMP.W	#RTGLINES,D7
	BCS	RtgFrL
	TST.B	RfPrvN			; (blended: the last line new: its blend
	BEQ.S	RtgFrBX			; row, with no line below it, from itself)
	MOVE.W	RfN,D0
	SUBQ.W	#1,D0
	MOVE.W	D0,D1
	BSR	RtgBRow
RtgFrBX:SF	RtgFull
	IFD	RTGDBG
	BSR	RtgDbgStrip
	LEA	RdRend,A0
	BSR	RtgTime
	ENDC
	MOVEM.L	(SP)+,D0-D7/A0-A6
	RTS

	IFD	RTGDBG
; (debug) D0.L = the CIA-B TOD counter (24 bits, one count a native HSYNC):
; a time in lines of the native display, whatever its mode (under RTG it is
; not a 313-line PAL frame: FMXVbl * 313 + the beam line gave F30F for a
; flush that did not run). The high byte first (it latches), the low last.
RtgBeam:
	MOVEQ	#0,D0
	MOVE.B	$BFDA00,D0
	LSL.L	#8,D0
	MOVE.B	$BFD900,D0
	LSL.L	#8,D0
	MOVE.B	$BFD800,D0
	RTS
; (debug) The lines since RtgTa added to the word at A0; RtgTa = now.
RtgTime:
	MOVEM.L	D0-D1,-(SP)
	BSR	RtgBeam
	MOVE.L	D0,D1
	SUB.L	RtgTa,D1
	AND.L	#$FFFFFF,D1
	ADD.W	D1,(A0)
	MOVE.L	D0,RtgTa
	MOVEM.L	(SP)+,D0-D1
	RTS
RtgTa:	DC.L	0
	ENDC

	IFD	RTGDBG
; (debug) Screen rows 0-7: the frame-start palette (16 swatches of 8 dots),
; rows 10-13: a bar as long as the lines written this frame (x4), rows 16-19:
; ScrModo x 16 dots, rows 22-25: R#2 x 2. 16-bit screens only.
RtgDbgStrip:
	MOVEM.L	D0-D3/A0-A2,-(SP)
	TST.B	RtgBpp4
	BNE	RtgDSX
	LEA	PalTop,A0
	LEA	RtgCol,A2
	MOVE.L	RtgMem,A1
	MOVEQ	#16-1,D2
RtgDSs:	MOVEQ	#0,D0
	MOVE.W	(A0)+,D0
	AND.W	#$FFF,D0
	MOVE.L	(A2,D0.W*4),D0
	MOVEQ	#8-1,D3
RtgDSr:	MOVE.L	D0,(A1)
	MOVE.L	D0,4(A1)
	MOVE.L	D0,8(A1)
	MOVE.L	D0,12(A1)
	ADD.L	RtgBpr,A1
	DBF	D3,RtgDSr
	MOVE.L	RtgBpr,D1
	LSL.L	#3,D1
	SUB.L	D1,A1
	LEA	16(A1),A1
	DBF	D2,RtgDSs
	MOVE.W	RtgDbgW,D0
	LSL.W	#2,D0
	MOVEQ	#10,D1
	BSR	RtgDSBar
	MOVEQ	#0,D0
	MOVE.B	REGS+ScrModo,D0
	LSL.W	#4,D0
	ADDQ.W	#1,D0
	MOVEQ	#16,D1
	BSR	RtgDSBar
	MOVEQ	#0,D0
	MOVE.B	RfR2,D0
	ADD.W	D0,D0
	ADDQ.W	#1,D0
	MOVEQ	#22,D1
	BSR	RtgDSBar
	CLR.W	RtgDbgW
	BSR	RtgDbHex
RtgDSX:	MOVEM.L	(SP)+,D0-D3/A0-A2
	RTS

; (debug) Words in hex at row 30 (16-bit screens): see RtgDbVals.
RtgDbHex:
	MOVEM.L	D0-D7/A0-A3,-(SP)
	LEA	REGS,A3
	LEA	RtgDbV,A0
	MOVE.B	ScrModo(A3),(A0)+
	MOVE.B	MSplitTop,(A0)+
	MOVE.W	MSplitL,(A0)+
	MOVE.W	TSplit,(A0)+
	MOVE.W	DVDP3(A3),(A0)+
	MOVE.W	TA_DVDP3,(A0)+
	MOVE.W	DVDP4(A3),(A0)+
	MOVE.W	TA_DVDP4,(A0)+
	MOVE.B	RtgDb0R2,(A0)+
	MOVE.B	RtgDb0R23,(A0)+
	MOVE.B	RfR2,(A0)+
	MOVE.B	RfR23,(A0)+
	MOVE.B	DVDP7(A3),(A0)+
	MOVE.B	DVDP8(A3),(A0)+
	MOVE.B	DVDP1(A3),(A0)+
	MOVE.B	DVDP9(A3),(A0)+
	MOVE.W	MCOPP96+2,(A0)+
	MOVE.W	PalEvN,(A0)+
	MOVE.W	BandN,(A0)+
	MOVE.W	SprSplit,(A0)+
	MOVE.L	VRAM(A3),(A0)+
	MOVE.W	DVDP5(A3),(A0)+
	MOVE.B	TopR8,(A0)+
	MOVE.B	DVDP0(A3),(A0)+
	MOVE.L	PVDP6(A3),(A0)+
	MOVE.B	RfBotM,(A0)+		; (4.6) The split's bottom mode, the pair
	MOVE.B	BMSK5,(A0)+		; flags, and MSplitL's R#2/R#23.
	MOVE.B	BMSK8,(A0)+
	MOVE.B	LastRend,(A0)+
	MOVE.W	MSplitL,D0
	MOVE.B	(TabRasDATA+1.L,D0.W*8),(A0)+
	MOVE.B	(TabRasDATA+4.L,D0.W*8),(A0)+
	LEA	RtgDbV,A2
	MOVEQ	#RTGDBN-1,D7
	MOVEQ	#0,D6			; column (words)
	MOVEQ	#30,D5			; row
RtgDHW:	MOVE.W	(A2)+,D4
	MOVEQ	#4-1,D3
RtgDHD:	ROL.W	#4,D4
	MOVE.W	D4,D0
	AND.W	#15,D0
	BSR	RtgDbGlyph		; D0 at column D6*? row D5
	ADDQ.W	#1,D6
	DBF	D3,RtgDHD
	ADDQ.W	#1,D6			; a gap
	CMP.W	#60,D6
	BCS.S	RtgDHN
	MOVEQ	#0,D6
	ADD.W	#14,D5
RtgDHN:	DBF	D7,RtgDHW
	MOVEM.L	(SP)+,D0-D7/A0-A3
	RTS
; Glyph D0 (0-15) at x = D6*8, y = D5: 3x5 dots, each 2x2 white.
RtgDbGlyph:
	MOVEM.L	D0-D3/A0-A1,-(SP)
	LEA	RtgDbFont(PC),A0
	MULU.W	#5,D0
	ADD.W	D0,A0
	MOVE.L	RtgMem,A1
	MOVE.L	RtgBpr,D1
	MULU.W	D5,D1
	ADD.L	D1,A1
	MOVE.W	D6,D1
	LSL.W	#4,D1			; 8 pixels x 2 bytes
	ADD.W	D1,A1
	MOVEQ	#5-1,D2
RtgDGR:	MOVE.B	(A0)+,D1
	MOVEQ	#0,D0
	BTST	#2,D1
	BEQ.S	RtgDG1
	MOVEQ	#-1,D0
RtgDG1:	MOVE.L	D0,(A1)
	MOVEQ	#0,D0
	BTST	#1,D1
	BEQ.S	RtgDG2
	MOVEQ	#-1,D0
RtgDG2:	MOVE.L	D0,4(A1)
	MOVEQ	#0,D0
	BTST	#0,D1
	BEQ.S	RtgDG3
	MOVEQ	#-1,D0
RtgDG3:	MOVE.L	D0,8(A1)
	CLR.L	12(A1)
	MOVE.L	RtgBpr,D3
	MOVE.L	(A1),(A1,D3.L)
	MOVE.L	4(A1),4(A1,D3.L)
	MOVE.L	8(A1),8(A1,D3.L)
	CLR.L	12(A1,D3.L)
	ADD.L	D3,A1
	ADD.L	D3,A1
	DBF	D2,RtgDGR
	MOVEM.L	(SP)+,D0-D3/A0-A1
	RTS
RtgDbFont:
	DC.B	7,5,5,5,7, 2,6,2,2,7, 7,1,7,4,7, 7,1,7,1,7
	DC.B	5,5,7,1,1, 7,4,7,1,7, 7,4,7,5,7, 7,1,1,1,1
	DC.B	7,5,7,5,7, 7,5,7,1,7, 7,5,7,5,5, 6,5,6,5,6
	DC.B	7,4,4,4,7, 6,5,5,5,6, 7,4,7,4,7, 7,4,7,4,4
	EVEN
; (debug) Speed, every frame (RtgUse), on AGA frames too: per 50 Amiga
; VBlanks (FMXVbl) the MSX frames, how many went to RTG and to AGA, the
; Wait60fps spins / 256 (0 = no time to spare) and the VBlanks counted, as a
; third hex row (row 58); then the TOD lines (RtgBeam) spent on the SCREEN 5
; flush, on the rest of RtgFrame and in the whole window (so flush / window
; is its share of the time); then the frames with VRAM-direct SCREEN 5
; commands (Rtg5Dir) and the 1 KB blocks rebuilt in the planes (R5Rebuild);
; then (blended scanlines) the blend rows written.
RtgDbSpd:
	MOVEM.L	D0-D7/A0-A3,-(SP)
	ADDQ.W	#1,RdMsx
	TST.B	Rtg5Dir
	BEQ.S	RtgDSn5
	ADDQ.W	#1,RdDir
RtgDSn5:TST.B	RtgNow
	BEQ.S	RtgDSA
	ADDQ.W	#1,RdRtg
	BRA.S	RtgDSV
RtgDSA:	ADDQ.W	#1,RdAga
RtgDSV:	MOVE.W	FMXVbl,D0
	SUB.W	RdV0,D0
	CMP.W	#50,D0
	BCS	RtgDSD
	LEA	RdOut,A0
	MOVE.W	RdMsx,(A0)+
	MOVE.W	RdRtg,(A0)+
	MOVE.W	RdAga,(A0)+
	MOVE.L	RtgDbSpin,D1
	LSR.L	#8,D1
	CMP.L	#$FFFF,D1
	BLS.S	RtgDS1
	MOVE.W	#$FFFF,D1
RtgDS1:	MOVE.W	D1,(A0)+
	MOVE.W	D0,(A0)+
	MOVE.W	RdFlush,(A0)+		; (and the TOD lines spent on the SCREEN 5
	MOVE.W	RdRend,(A0)+		; flush and on the rest of RtgFrame)
	BSR	RtgBeam			; (the window, in TOD lines)
	MOVE.L	D0,D1
	SUB.L	RdT0,D1
	AND.L	#$FFFFFF,D1
	CMP.L	#$FFFF,D1
	BLS.S	RtgDS2
	MOVE.W	#$FFFF,D1
RtgDS2:	MOVE.W	D1,(A0)+
	MOVE.L	D0,RdT0
	MOVE.W	RdDir,(A0)+
	MOVE.W	RdReb,(A0)+
	MOVE.W	RdBlr,(A0)+		; (blended: blend rows written)
	CLR.W	RdBlr
	CLR.W	RdDir
	CLR.W	RdReb
	CLR.W	RdFlush
	CLR.W	RdRend
	CLR.W	RdMsx
	CLR.W	RdRtg
	CLR.W	RdAga
	CLR.L	RtgDbSpin
	MOVE.W	FMXVbl,RdV0
RtgDSD:	TST.B	RtgBpp4			; (glyphs: 16-bit screens)
	BNE.S	RtgDSq
	LEA	RdOut,A2
	MOVEQ	#RDOUTN-1,D7
	MOVEQ	#0,D6
	MOVEQ	#58,D5
RtgDSW:	MOVE.W	(A2)+,D4
	MOVEQ	#4-1,D3
RtgDSG:	ROL.W	#4,D4
	MOVE.W	D4,D0
	AND.W	#15,D0
	BSR	RtgDbGlyph
	ADDQ.W	#1,D6
	DBF	D3,RtgDSG
	ADDQ.W	#1,D6
	DBF	D7,RtgDSW
RtgDSq:	MOVEM.L	(SP)+,D0-D7/A0-A3
	RTS
RdMsx:	DC.W	0
RdRtg:	DC.W	0
RdAga:	DC.W	0
RdV0:	DC.W	0
RDOUTN=11
RdOut:	DS.W	RDOUTN
RdFlush:	DC.W	0
RdRend:	DC.W	0
RdDir:	DC.W	0
RdReb:	DC.W	0
RdOn:	DC.W	0
RdBlr:	DC.W	0
	CNOP	0,4
RdT0:	DC.L	0
RtgDbSpin:	DC.L	0
RTGDBN=25
RtgDbV:	DS.W	RTGDBN
RtgDb0R2:	DC.B	0
RtgDb0R23:	DC.B	0
	EVEN
; A white bar D0 dots long (cleared to black after it, to 512) at rows D1..D1+3.
RtgDSBar:
	MOVE.L	RtgMem,A1
	MOVE.L	RtgBpr,D2
	MULU.W	D1,D2
	ADD.L	D2,A1
	MOVEQ	#4-1,D3
RtgDSB1:MOVE.L	A1,A0
	MOVE.W	#512-1,D2
	MOVE.W	D0,D1
RtgDSB2:TST.W	D1
	BEQ.S	RtgDSB3
	MOVE.W	#$FFFF,(A0)+
	SUBQ.W	#1,D1
	DBF	D2,RtgDSB2
	BRA.S	RtgDSB4
RtgDSB3:CLR.W	(A0)+
	DBF	D2,RtgDSB2
RtgDSB4:ADD.L	RtgBpr,A1
	DBF	D3,RtgDSB1
	RTS
RtgDbgW:	DC.W	0
	ENDC

; RfLut = the 16 colours of palette A0 (16 words, MSX2Pal format) as screen
; pixels, RfSig a sum of them (the line cache's key).
RtgPal:
	MOVEM.L	D0-D2/A1-A2,-(SP)
	LEA	RtgCol,A1
	LEA	RfLut(PC),A2
	MOVEQ	#0,D2
	MOVEQ	#16-1,D1
RtgPalL:	MOVEQ	#0,D0
	MOVE.W	(A0)+,D0
	AND.W	#$0FFF,D0
	TST.B	RtgScan			; (scanlines: the dimmed colour too)
	BEQ.S	RtgPalN
	TST.B	RfBlOn			; (blended: the half-dimmed one)
	BEQ.S	RtgPalD
	MOVE.L	([RtgHCol],D0.W*4),64(A2)
	BRA.S	RtgPalN
RtgPalD:MOVE.L	D0,-(SP)
	BSR	RtgDimC
	MOVE.L	(A1,D0.W*4),64(A2)	; (RfLutD follows RfLut)
	MOVE.L	(SP)+,D0
RtgPalN:	MOVE.L	(A1,D0.W*4),D0
	MOVE.L	D0,(A2)+
	ROL.L	#3,D2
	ADD.L	D0,D2
	DBF	D1,RtgPalL
	MOVE.L	D2,RfSig
	MOVEM.L	(SP)+,D0-D2/A1-A2
	RTS

; The whole screen in the border colour (RfBdPix); every line cache invalid.
RtgFill:
	MOVEM.L	D0-D3/A0-A1,-(SP)
	MOVE.L	RfBdPix,D0
	MOVE.L	D0,RtgBdLast
	MOVE.W	RfY0,RtgY0Last
	MOVE.W	RfN,RtgNLast
	MOVE.L	RtgMem,A1
	MOVE.W	RtgH,D3
	SUBQ.W	#1,D3
RtgFiR:	MOVE.L	A1,A0
	MOVE.W	RtgW,D1
	TST.B	RtgBpp4
	BNE.S	RtgFi4
	LSR.W	#1,D1
RtgFi4:	SUBQ.W	#1,D1
RtgFiP:	MOVE.L	D0,(A0)+
	DBF	D1,RtgFiP
	ADD.L	RtgBpr,A1
	DBF	D3,RtgFiR
	LEA	RtgLV,A0		; Line caches: invalid.
	MOVE.W	#RTGLINES-1,D1
RtgFiK:	SF	(A0)+
	DBF	D1,RtgFiK
	MOVEM.L	(SP)+,D0-D3/A0-A1
	RTS

; A4 = 256 bytes of D0.B.
RtgLBFill:
	MOVE.L	D1,-(SP)
	MOVE.B	D0,D1
	LSL.W	#8,D0
	MOVE.B	D1,D0
	MOVE.W	D0,D1
	SWAP	D0
	MOVE.W	D1,D0
	MOVEQ	#64-1,D1
RtgLBF:	MOVE.L	D0,(A4)+
	DBF	D1,RtgLBF
	LEA	-256(A4),A4
	MOVE.L	(SP)+,D1
	RTS

; ---------------------------------------------------------------------------
; The background of display line D7 into A4 (SCREEN 1, 2, 4: RfMode 0, 1, 2).
; VRAM line = (D7 + R#23) AND 255. Colour 0 is the backdrop (R#7) unless TP.
; The V9958's R#26 (8-dot steps, with SP2 the second page) and R#27 (0-7 dots
; right; the dots left of it in the border colour) apply.
RtgBg:
	MOVEM.L	D0-D7/A0-A2/A5,-(SP)
	LEA	DIRVRAM,A5		; (not VRAM(A3): that is the CPU's R#14 page)
	MOVEQ	#0,D5
	MOVE.B	RfR23,D5
	ADD.W	D7,D5
	AND.W	#$FF,D5			; D5 = VRAM line
	MOVEQ	#0,D6			; D6 = the colour 0 index
	BTST	#5,RfR8
	BNE.S	RtgBg0
	MOVE.B	RfBord,D6
RtgBg0:	MOVEQ	#0,D4			; D4 = R#26 (chars), D3 = R#27 dots
	MOVEQ	#0,D3
	TST.B	RfV9
	BEQ.S	RtgBgS
	MOVE.B	RfR26,D4
	AND.W	#$3F,D4
	MOVE.B	RfR27,D3
	AND.W	#7,D3
RtgBgS:	MOVE.W	D3,RfFine
	LEA	RtgBgBuf+8,A2		; Drawn 8 dots in, then moved by R#27.
	MOVEQ	#0,D0
	MOVE.B	RfR2,D0			; Name base = R#2 << 10 (the page bit
	AND.W	#$7F,D0			; with SP2: AND the scroll's page).
	MOVEQ	#10,D1
	LSL.L	D1,D0
	MOVE.L	D0,RfNameB
	MOVE.W	D5,D0			; Row's names: (line / 8) * 32.
	LSR.W	#3,D0
	LSL.W	#5,D0
	MOVE.W	D0,RfRowN
	MOVE.B	RfMode,D0
	BEQ	RtgBgG1
	CMP.B	#3,D0
	BEQ	RtgBgG4
	CMP.B	#7,D0
	BEQ	RtgBgG7
	CMP.B	#2,D0			; (4.6) SCREEN 6, 7, 3, TEXT1/2.
	BHI	RtgBgNw
; SCREEN 2/4: index = name*8 | (row AND $18)*256 | line AND 7, pattern =
; (R#4 << 11 | $7FF) AND ($1E000 | index), colour = (R#10 << 14 | R#3 << 6
; | $3F) AND ($1E000 | index).
	MOVEQ	#0,D0
	MOVE.B	RfR4,D0
	MOVEQ	#11,D1
	LSL.L	D1,D0
	OR.L	#$7FF,D0
	AND.L	#$1FFFF,D0
	MOVE.L	D0,RfPatB
	MOVEQ	#0,D0
	MOVE.W	RfR3,D0
	LSL.L	#6,D0			; R#10 << 14 | R#3 << 6
	OR.L	#$3F,D0
	AND.L	#$1FFFF,D0
	MOVE.L	D0,RfColB
	MOVE.W	D5,D0
	AND.W	#$C0,D0			; (row AND $18) * 256 = (line AND $C0) * 32
	LSL.W	#5,D0
	MOVE.W	D5,D1
	AND.W	#7,D1
	OR.W	D1,D0
	OR.L	#$1E000,D0
	MOVE.L	D0,RfIdxB
	MOVEQ	#32-1,D7		; (D7 saved: the tile counter here)
RtgBg2L:
	BSR	RtgName			; D0 = name of tile (D4)
	LSL.W	#3,D0
	OR.L	RfIdxB,D0
	MOVE.L	D0,D1
	AND.L	RfPatB,D0
	AND.L	RfColB,D1
	MOVE.B	(A5,D0.L),D2		; pattern
	MOVE.B	(A5,D1.L),D1		; colour
	BSR	RtgDraw8
	ADDQ.W	#1,D4
	DBF	D7,RtgBg2L
	BRA	RtgBgMove
; SCREEN 1: pattern = (R#4 << 11) AND $1F800 | name*8 + line AND 7, colour =
; ((R#10 << 14 | R#3 << 6) AND $1FFC0) | name / 8.
RtgBgG1:
	MOVEQ	#0,D0
	MOVE.B	RfR4,D0
	MOVEQ	#11,D1
	LSL.L	D1,D0
	AND.L	#$1F800,D0
	MOVE.W	D5,D1
	AND.W	#7,D1
	OR.W	D1,D0
	MOVE.L	D0,RfPatB
	MOVEQ	#0,D0
	MOVE.W	RfR3,D0
	LSL.L	#6,D0
	AND.L	#$1FFC0,D0
	MOVE.L	D0,RfColB
	MOVEQ	#32-1,D7
RtgBg1L:
	BSR	RtgName
	MOVE.L	D0,D1
	LSL.W	#3,D0
	OR.L	RfPatB,D0
	LSR.W	#3,D1
	OR.L	RfColB,D1
	MOVE.B	(A5,D0.L),D2
	MOVE.B	(A5,D1.L),D1
	BSR	RtgDraw8
	ADDQ.W	#1,D4
	DBF	D7,RtgBg1L
; SCREEN 5: VRAM line = ((R#2 << 3) | 7) AND ($300 | line) (openMSX's name
; mask: R#2 bits 5-6 the page; EO/blink pages not modelled), 128 bytes, two
; dots a byte (high nibble left), colour 0 = D6. R#26 (V9958) starts the line
; 8 dots a step later, wrapping in the 256 dots.
RtgBgG4:
	MOVEQ	#0,D0
	MOVE.B	RfR2,D0
	LSL.W	#3,D0
	OR.W	#7,D0
	MOVE.W	D5,D1
	OR.W	#$300,D1
	AND.W	D1,D0
	LSL.L	#7,D0
	LEA	(A5,D0.L),A0
	MOVE.W	D4,D1
	LSL.W	#2,D1
	AND.W	#127,D1
	MOVEQ	#128-1,D7
RtgBg4L:MOVE.B	(A0,D1.W),D0
	ADDQ.W	#1,D1
	AND.W	#127,D1
	MOVE.B	D0,D2
	LSR.B	#4,D2
	BNE.S	RtgBg4a
	MOVE.B	D6,D2
RtgBg4a:MOVE.B	D2,(A2)+
	AND.B	#15,D0
	BNE.S	RtgBg4b
	MOVE.B	D6,D0
RtgBg4b:MOVE.B	D0,(A2)+
	DBF	D7,RtgBg4L
	BRA	RtgBgMove
; SCREEN 8: logical line L = ((R#2 << 3) | 7) AND ($100 | line) (R#2 bit 5
; the page), 256 bytes, one dot a byte (GGGRRRBB, no transparency). VRAM is
; physical: logical A is at (A >> 1) | (A AND 1) << 16, so even dots come
; from bank 0 at L*128 + x/2 and odd ones from bank 1. R#26 as in SCREEN 5.
RtgBgG7:
	MOVEQ	#0,D0
	MOVE.B	RfR2,D0
	LSL.W	#3,D0
	OR.W	#7,D0
	MOVE.W	D5,D1
	OR.W	#$100,D1
	AND.W	D1,D0
	LSL.L	#7,D0
	LEA	(A5,D0.L),A0		; bank 0
	LEA	$10000(A0),A1		; bank 1
	MOVE.W	D4,D1
	LSL.W	#2,D1
	AND.W	#127,D1
	MOVEQ	#128-1,D7
RtgBg7L:MOVE.B	(A0,D1.W),(A2)+
	MOVE.B	(A1,D1.W),(A2)+
	ADDQ.W	#1,D1
	AND.W	#127,D1
	DBF	D7,RtgBg7L
	BRA	RtgBgMove
; The 256 dots into A4, R#27 dots to the right (the border colour left of them).
RtgBgMove:
	LEA	RtgBgBuf+8,A0
	MOVE.W	RfFine,D0
	SUB.W	D0,A0
	MOVE.L	A4,A1
	MOVEQ	#64-1,D1
RtgBgM:	MOVE.B	(A0)+,(A1)+
	MOVE.B	(A0)+,(A1)+
	MOVE.B	(A0)+,(A1)+
	MOVE.B	(A0)+,(A1)+
	DBF	D1,RtgBgM
	SUBQ.W	#1,D0
	BMI.S	RtgBgX
	MOVE.B	RfBord,D1
RtgBgF:	MOVE.B	D1,(A4,D0.W)
	DBF	D0,RtgBgF
RtgBgX:	MOVEM.L	(SP)+,D0-D7/A0-A2/A5
	RTS

; ---------------------------------------------------------------------------
; (4.6) The other modes' backgrounds (RtgBg's registers: D4 = R#26 chars,
; D5 = VRAM line, D6 = the colour 0 index, A2 = RtgBgBuf+8, A5 = DIRVRAM).
; Wide lines (SCREEN 6, 7, TEXT2: 512 dots, RfMAt bit 0) are drawn at
; RtgBgBuf+16 and moved by RtgBgMvW (R#27: 2 dots a step).
RtgBgNw:CMP.B	#4,D0
	BEQ	RtgBgG5
	CMP.B	#5,D0
	BEQ	RtgBgG6
	CMP.B	#8,D0
	BEQ	RtgBgMC
	CMP.B	#$12,D0
	BEQ	RtgBgT2
; TEXT1 (and the other M1 modes): 40 characters of 6 dots, 8 dots of the
; backdrop each side. Name = ((R#2 << 10) | $3FF) AND ((row*40 + c + $C00)
; | $1F000), pattern = (R#4 << 11) AND $1F800 | name*8 | line AND 7 (openMSX
; renderText1); colours R#7 (foreground high nibble, background low).
RtgBgT1:BSR	RtgTxtB
	MOVE.W	D5,D4
	LSR.W	#3,D4
	MULU.W	#40,D4
	MOVEQ	#8-1,D1
RtgT1B:	MOVE.B	D3,(A2)+
	DBF	D1,RtgT1B
	MOVEQ	#40-1,D7
RtgT1L:	MOVE.L	D4,D0
	ADD.W	#$C00,D0
	AND.L	#$FFF,D0
	OR.L	#$1F000,D0
	AND.L	RfNameB,D0
	MOVEQ	#0,D1
	MOVE.B	(A5,D0.L),D1
	LSL.W	#3,D1
	OR.L	RfPatB,D1
	MOVE.B	(A5,D1.L),D1
	MOVE.W	D3,D0
	BSR	RtgDraw6
	ADDQ.W	#1,D4
	DBF	D7,RtgT1L
	MOVEQ	#8-1,D1
RtgT1E:	MOVE.B	D3,(A2)+
	DBF	D1,RtgT1E
	BRA	RtgBgMove
; TEXT2: 80 characters at 512 dots (16 of the backdrop each side). Name =
; ((R#2 << 10) | $3FF) AND ((row*80 + c) | $1F000); the blink bits (bit 7 =
; the leftmost of 8 characters) at ((R#10 << 14 | R#3 << 6) | $3F) AND
; ((row*10 + c/8) | $1FE00). While AGA's blink phase shows them (MIRAFLASH:
; NBIT9 at 2 planes) those characters take R#12's colours.
RtgBgT2:BSR	RtgTxtB
	MOVEQ	#0,D0
	MOVE.W	RfR3,D0
	LSL.L	#6,D0
	OR.L	#$3F,D0
	AND.L	#$1FFFF,D0
	MOVE.L	D0,RfColB
	MOVE.W	D3,D6			; D6 = the blink characters' colours
	CMP.B	#$A2,NBIT9+6
	BNE.S	RtgT2C
	MOVEQ	#0,D0
	MOVE.B	REGS+DVDPC,D0
	MOVE.W	D0,D6
	LSL.W	#4,D6
	LSR.B	#4,D6
	AND.W	#$0F0F,D6
RtgT2C:	MOVE.W	D5,D4
	LSR.W	#3,D4
	MOVE.W	D4,D0
	MULU.W	#10,D0
	MOVE.L	D0,A0			; A0 = the row's blink bytes
	MULU.W	#80,D4
	LEA	RtgBgBuf+16,A2
	MOVEQ	#16-1,D1
RtgT2B:	MOVE.B	D3,(A2)+
	DBF	D1,RtgT2B
	MOVEQ	#80-1,D7
RtgT2L:	MOVE.W	D7,D0
	AND.W	#7,D0
	CMP.W	#7,D0
	BNE.S	RtgT2A
	MOVE.L	A0,D0			; (every 8 characters)
	OR.L	#$1FE00,D0
	AND.L	RfColB,D0
	MOVE.B	(A5,D0.L),D2
	ADDQ.L	#1,A0
RtgT2A:	MOVE.L	D4,D0
	AND.L	#$FFF,D0
	OR.L	#$1F000,D0
	AND.L	RfNameB,D0
	MOVEQ	#0,D1
	MOVE.B	(A5,D0.L),D1
	LSL.W	#3,D1
	OR.L	RfPatB,D1
	MOVE.B	(A5,D1.L),D1
	MOVE.W	D3,D0
	ADD.B	D2,D2
	BCC.S	RtgT2P
	MOVE.W	D6,D0
RtgT2P:	BSR	RtgDraw6
	ADDQ.W	#1,D4
	DBF	D7,RtgT2L
	MOVEQ	#16-1,D1
RtgT2E:	MOVE.B	D3,(A2)+
	DBF	D1,RtgT2E
	BRA	RtgBgMvW
; The text modes' bases: RfNameB = ((R#2 << 10) | $3FF) AND $1FFFF, RfPatB
; = (R#4 << 11) AND $1F800 | line AND 7; D3.W = R#7's colours (foreground
; in the high byte, background in the low). D4 = 0 (no R#26 here).
RtgTxtB:MOVEQ	#0,D0
	MOVE.B	RfR2,D0
	MOVEQ	#10,D1
	LSL.L	D1,D0
	OR.L	#$3FF,D0
	AND.L	#$1FFFF,D0
	MOVE.L	D0,RfNameB
	MOVEQ	#0,D0
	MOVE.B	RfR4,D0
	MOVEQ	#11,D1
	LSL.L	D1,D0
	AND.L	#$1F800,D0
	MOVE.W	D5,D1
	AND.W	#7,D1
	OR.W	D1,D0
	MOVE.L	D0,RfPatB
	MOVEQ	#0,D3
	MOVE.B	REGS+DVDP7,D3
	LSL.W	#4,D3
	LSR.B	#4,D3
	AND.W	#$0F0F,D3
	MOVEQ	#0,D4
	RTS
; 6 dots at (A2)+: pattern D1.B bits 7-2, colours D0.W (foreground high
; byte, background low).
RtgDraw6:
	MOVEM.L	D0/D2-D3,-(SP)
	MOVE.W	D0,D3
	LSR.W	#8,D0
	MOVEQ	#6-1,D2
RtgD6L:	ADD.B	D1,D1
	BCC.S	RtgD6B
	MOVE.B	D0,(A2)+
	DBF	D2,RtgD6L
	BRA.S	RtgD6X
RtgD6B:	MOVE.B	D3,(A2)+
	DBF	D2,RtgD6L
RtgD6X:	MOVEM.L	(SP)+,D0/D2-D3
	RTS
; SCREEN 3 (multicolour): per tile one pattern byte, (R#4 << 11) AND $1F800
; | name*8 | (line / 4) AND 7; its high nibble the left 4 dots, the low one
; the right 4; colour 0 = D6.
RtgBgMC:MOVEQ	#0,D0
	MOVE.B	RfR4,D0
	MOVEQ	#11,D1
	LSL.L	D1,D0
	AND.L	#$1F800,D0
	MOVE.W	D5,D1
	LSR.W	#2,D1
	AND.W	#7,D1
	OR.W	D1,D0
	MOVE.L	D0,RfPatB
	MOVEQ	#32-1,D7
RtgMCL:	BSR	RtgName
	LSL.W	#3,D0
	OR.L	RfPatB,D0
	MOVE.B	(A5,D0.L),D1
	MOVE.B	D1,D2
	LSR.B	#4,D2
	BNE.S	RtgMCa
	MOVE.B	D6,D2
RtgMCa:	MOVE.B	D2,(A2)+
	MOVE.B	D2,(A2)+
	MOVE.B	D2,(A2)+
	MOVE.B	D2,(A2)+
	AND.B	#15,D1
	BNE.S	RtgMCb
	MOVE.B	D6,D1
RtgMCb:	MOVE.B	D1,(A2)+
	MOVE.B	D1,(A2)+
	MOVE.B	D1,(A2)+
	MOVE.B	D1,(A2)+
	ADDQ.W	#1,D4
	DBF	D7,RtgMCL
	BRA	RtgBgMove
; SCREEN 6: from its planes (SCR0 bit 0, SCR0 + 64 KB bit 1: OUT98C and the
; VDP commands draw there; the commands never reach VRAM, so the planes are
; the picture, as on AGA). VRAM line L = ((R#2 << 3) | 7) AND ($300 | line)
; is plane line L (64 bytes each); the two rows are copied out of chip RAM
; as longs, then 4 dots a plane byte pair (RtgExp). R#26: 2 bytes a step.
RtgBgG5:MOVEQ	#0,D0
	MOVE.B	RfR2,D0
	LSL.W	#3,D0
	OR.W	#7,D0
	MOVE.W	D5,D1
	OR.W	#$300,D1
	AND.W	D1,D0
	LSL.L	#6,D0
	LEA	(SCR0.L,D0.L),A0
	LEA	RtgP6B,A1
	MOVEQ	#16-1,D1
RtgG5c:	MOVE.L	(A0)+,(A1)+
	DBF	D1,RtgG5c
	LEA	$10000-64(A0),A0
	MOVEQ	#16-1,D1
RtgG5d:	MOVE.L	(A0)+,(A1)+
	DBF	D1,RtgG5d
	LEA	RtgBgBuf+16,A2
	LEA	RtgP6B,A0
	LEA	RtgExp,A1
	MOVE.W	D4,D3
	ADD.W	D3,D3
	MOVEQ	#64-1,D7
RtgG5L:	AND.W	#63,D3
	MOVEQ	#0,D0
	MOVE.B	(A0,D3.W),D0		; bit 0
	MOVEQ	#0,D1
	MOVE.B	64(A0,D3.W),D1		; bit 1
	MOVE.L	(A1,D1.W*8),D2
	ADD.L	D2,D2
	OR.L	(A1,D0.W*8),D2
	MOVE.L	D2,(A2)+
	MOVE.L	4(A1,D1.W*8),D2
	ADD.L	D2,D2
	OR.L	4(A1,D0.W*8),D2
	MOVE.L	D2,(A2)+
	ADDQ.W	#1,D3
	DBF	D7,RtgG5L
	TST.B	D6			; Colour 0: the backdrop, unless TP.
	BEQ.S	RtgG5X
	LEA	RtgBgBuf+16,A2
	MOVE.W	#512-1,D7
RtgG5Z:	TST.B	(A2)+
	BNE.S	RtgG5N
	MOVE.B	D6,-1(A2)
RtgG5N:	DBF	D7,RtgG5Z
RtgG5X:	BRA	RtgBgMvW
; SCREEN 7: as SCREEN 8's line (logical L = ((R#2 << 3) | 7) AND ($100 |
; line), even bytes in bank 0 at L*128 + x/2, odd ones in bank 1), two dots
; a byte (high nibble left), colour 0 = D6. VRAM is right here: RtgFrame
; flushed the bands the commands drew in the planes (P7Band). R#26: 8 bytes
; (16 dots) a step.
RtgBgG6:MOVEQ	#0,D0
	MOVE.B	RfR2,D0
	LSL.W	#3,D0
	OR.W	#7,D0
	MOVE.W	D5,D1
	OR.W	#$100,D1
	AND.W	D1,D0
	LSL.L	#7,D0
	LEA	(A5,D0.L),A0		; bank 0
	LEA	$10000(A0),A1		; bank 1
	LEA	RtgBgBuf+16,A2
	MOVE.W	D4,D1
	LSL.W	#2,D1
	AND.W	#127,D1
	MOVEQ	#128-1,D7
RtgG6L:	MOVE.B	(A0,D1.W),D0
	MOVE.B	D0,D2
	LSR.B	#4,D2
	BNE.S	RtgG6a
	MOVE.B	D6,D2
RtgG6a:	MOVE.B	D2,(A2)+
	AND.B	#15,D0
	BNE.S	RtgG6b
	MOVE.B	D6,D0
RtgG6b:	MOVE.B	D0,(A2)+
	MOVE.B	(A1,D1.W),D0
	MOVE.B	D0,D2
	LSR.B	#4,D2
	BNE.S	RtgG6c
	MOVE.B	D6,D2
RtgG6c:	MOVE.B	D2,(A2)+
	AND.B	#15,D0
	BNE.S	RtgG6d
	MOVE.B	D6,D0
RtgG6d:	MOVE.B	D0,(A2)+
	ADDQ.W	#1,D1
	AND.W	#127,D1
	DBF	D7,RtgG6L
; The 512 dots into A4, 2 R#27 dots to the right (the border colour left).
RtgBgMvW:
	LEA	RtgBgBuf+16,A0
	MOVE.W	RfFine,D0
	ADD.W	D0,D0
	SUB.W	D0,A0
	MOVE.L	A4,A1
	MOVEQ	#128-1,D1
RtgBgMW:MOVE.B	(A0)+,(A1)+
	MOVE.B	(A0)+,(A1)+
	MOVE.B	(A0)+,(A1)+
	MOVE.B	(A0)+,(A1)+
	DBF	D1,RtgBgMW
	SUBQ.W	#1,D0
	BMI	RtgBgX
	MOVE.B	RfBord,D1
RtgBgFW:MOVE.B	D1,(A4,D0.W)
	DBF	D0,RtgBgFW
	BRA	RtgBgX

; D0.L = name of tile D4 (scroll-adjusted column) on row RfRowN: VRAM at
; RfNameB | row*32 | (D4 AND 31), the page from the scroll with SP2.
RtgName:
	MOVE.L	RfNameB,D0
	TST.B	RfV9
	BEQ.S	RtgNm1
	BTST	#0,RfR25		; SP2: bit 15 = R#2's AND the scroll's.
	BEQ.S	RtgNm1
	BTST	#5,D4
	BNE.S	RtgNm1
	BCLR	#15,D0
RtgNm1:	MOVE.W	D4,D1
	AND.W	#31,D1
	OR.W	RfRowN,D1
	OR.W	D1,D0
	MOVEQ	#0,D1
	MOVE.B	(A5,D0.L),D1
	MOVE.L	D1,D0
	RTS

; 8 dots at (A2)+: pattern D2.B (bit 7 first), colour D1.B (fg high nibble,
; bg low); colour 0 = D6.
RtgDraw8:
	MOVEM.L	D0/D3,-(SP)
	MOVE.B	D1,D3
	LSR.B	#4,D3
	BNE.S	RtgD8a
	MOVE.B	D6,D3
RtgD8a:	AND.B	#15,D1
	BNE.S	RtgD8b
	MOVE.B	D6,D1
RtgD8b:	MOVEQ	#8-1,D0
RtgD8L:	ADD.B	D2,D2
	BCC.S	RtgD8Bg
	MOVE.B	D3,(A2)+
	DBF	D0,RtgD8L
	BRA.S	RtgD8X
RtgD8Bg:MOVE.B	D1,(A2)+
	DBF	D0,RtgD8L
RtgD8X:	MOVEM.L	(SP)+,D0/D3
	RTS

; ---------------------------------------------------------------------------
; Sprites on display line D7 into A4. They are checked one line above where
; they show: sprite line = (D7 - 1 + R#23 - Y) AND 255 < size (x2 with MAG).
; Lower numbers win. Colour 0 sprites show only with TP.

; Sprite mode 1 (SCREEN 1-3): Y = 208 ends the table, 4 a line. The table as
; IMPSPR takes it: the top snapshot above a R#5/R#6 split (SprSnapT), else
; the line-96 snapshot (SprSnap), else VRAM at the frame's end.
RtgSpr1:
	MOVEM.L	D0-D7/A0-A2/A5,-(SP)
	LEA	DIRVRAM,A5		; (not VRAM(A3): that is the CPU's R#14 page)
	MOVE.L	A5,RfSprV
	TST.W	SprSplit
	BEQ.S	RtgS1M
	TST.B	SnapTOK
	BEQ.S	RtgS1M
	CMP.W	SprSplit,D7
	BCC.S	RtgS1M
	LEA	SprSnapT+512,A0
	MOVE.L	SnapT6,RfSprP
	BRA.S	RtgS1Go
RtgS1M:	TST.B	SnapOK
	BEQ.S	RtgS1V
	LEA	SprSnap+512,A0
	MOVE.L	SnapM6,RfSprP
	BRA.S	RtgS1Go
RtgS1V:	MOVEQ	#0,D0
	MOVE.W	DVDP5(A3),D0		; (R#11 << 8 | R#5) << 7, AND $1FF80
	LSL.L	#7,D0
	AND.L	#$1FF80,D0
	LEA	(A5,D0.L),A0
	MOVE.L	PVDP6(A3),RfSprP
RtgS1Go:
	BSR	RtgSprPrep		; D5 = check line, D4 = size, D3 = mask
	MOVEQ	#0,D6			; D6 = sprites on the line
	MOVEQ	#0,D7			; D7 = sprite number
RtgS1L:	MOVEQ	#0,D0
	MOVE.B	(A0),D0
	CMP.B	#208,D0
	BEQ.S	RtgS1D
	MOVE.W	D5,D1
	SUB.W	D0,D1
	AND.W	#$FF,D1			; D1 = line in the sprite
	CMP.W	D4,D1
	BCC.S	RtgS1N
	CMP.W	#4,D6
	BEQ.S	RtgS1D
	MOVEQ	#0,D0
	MOVE.B	1(A0),D0
	MOVE.W	D0,RfSx
	MOVE.B	2(A0),D0		; pattern number
	MOVE.B	3(A0),D2		; colour, EC
	BSR	RtgSprAdd
RtgS1N:	ADDQ.L	#4,A0
	ADDQ.W	#1,D7
	CMP.W	#32,D7
	BNE.S	RtgS1L
RtgS1D:	LEA	RtgSp,A2
RtgS1Dr:SUBQ.W	#1,D6			; Draw: the highest number first.
	BMI.S	RtgS1X
	MOVE.W	D6,D1
	LSL.W	#3,D1
	MOVEQ	#0,D0
	MOVE.B	2(A2,D1.W),D0
	AND.B	#15,D0
	BNE.S	RtgS1C
	BTST	#5,RfR8			; colour 0: only with TP
	BEQ.S	RtgS1Dr
RtgS1C:	MOVE.L	4(A2,D1.W),D2
	MOVE.W	(A2,D1.W),D1
	LEA	(A4,D1.W),A1
RtgS1P:	ADD.L	D2,D2
	BCC.S	RtgS1Q
	MOVE.B	D0,(A1)
RtgS1Q:	ADDQ.L	#1,A1
	TST.L	D2
	BNE.S	RtgS1P
	BRA.S	RtgS1Dr
RtgS1X:	MOVEM.L	(SP)+,D0-D7/A0-A2/A5
	RTS

; Sprite mode 2 (SCREEN 4-8): Y = 216 ends the table, 8 a line, a colour per
; line from the table 512 bytes below the attributes (bits 0-3 colour, 5 IC,
; 6 CC, 7 EC). A CC=1 sprite ORs its colour into the sprites before it, and
; shows only after a CC=0 one. The band snapshots (BANDSHOT: line interrupt
; frames) give the tables and R#8's SPD per band, else VRAM: address =
; (R#11 << 15 | R#5 << 7 | $7F) AND ($1FC00 | index).
RtgSpr2:
	MOVEM.L	D0-D7/A0-A2/A5,-(SP)
	LEA	DIRVRAM,A5		; (not VRAM(A3): that is the CPU's R#14 page;
	BTST	#1,RfMAt		; SPRSH, the logical view, in SCREEN 7/8:
	BEQ.S	RtgS2Vb			; the line's mode, as SprVB is the frame
	LEA	SPRSH,A5		; end's)
RtgS2Vb:MOVE.L	A5,RfSprV
	MOVE.W	BandN,D0
	BEQ.S	RtgS2V
	LEA	BandLine,A1		; The last band at or above this line.
	MOVEQ	#0,D1
RtgS2B:	ADDQ.W	#1,D1
	CMP.W	D0,D1
	BCC.S	RtgS2Bf
	CMP.W	(A1,D1.W*2),D7
	BCC.S	RtgS2B
RtgS2Bf:SUBQ.W	#1,D1
	LEA	BandR8,A1
	BTST	#1,(A1,D1.W)		; SPD in that band.
	BNE	RtgS2X
	MULU.W	#640,D1
	LEA	BandBuf,A0
	ADD.L	D1,A0
	MOVE.L	A0,RfSprC		; The band's copy: colours, then the
	MOVE.L	#$3FF,RfSprM		; attributes at 512.
	BRA.S	RtgS2Go
RtgS2V:	MOVEQ	#0,D0
	MOVE.W	DVDP5(A3),D0
	LSL.L	#7,D0
	OR.L	#$7F,D0
	AND.L	#$1FFFF,D0
	MOVE.L	D0,D1
	AND.L	#$3FF,D1
	MOVE.L	D1,RfSprM		; index AND these low bits,
	AND.L	#$1FC00,D0
	LEA	(A5,D0.L),A0		; in this 1 KB window.
	MOVE.L	A0,RfSprC
RtgS2Go:
	MOVE.L	PVDP6(A3),RfSprP
	BSR	RtgSprPrep
	MOVEQ	#0,D6
	MOVEQ	#0,D7
RtgS2L:	MOVE.W	D7,D0			; Attributes at 512 + n*4: Y,
	LSL.W	#2,D0
	ADD.W	#512,D0
	BSR	RtgS2Rd
	CMP.B	#216,D1
	BEQ	RtgS2D
	MOVE.W	D5,D2
	SUB.B	D1,D2
	AND.W	#$FF,D2			; line in the sprite
	CMP.W	D4,D2
	BCC.S	RtgS2N
	CMP.W	#8,D6
	BEQ.S	RtgS2D
	MOVE.W	D7,D0			; X,
	LSL.W	#2,D0
	ADD.W	#513,D0
	BSR	RtgS2Rd
	AND.W	#$FF,D1
	MOVE.W	D1,RfSx
	MOVE.W	D2,-(SP)
	TST.B	RfMag			; colour line = sprite line / MAG
	BEQ.S	RtgS2Ml
	LSR.W	#1,D2
RtgS2Ml:MOVE.W	D7,D0			; colour at n*16 + line,
	LSL.W	#4,D0
	ADD.W	D2,D0
	BSR	RtgS2Rd
	MOVE.B	D1,D2
	MOVE.W	D7,D0			; pattern number.
	LSL.W	#2,D0
	ADD.W	#514,D0
	BSR	RtgS2Rd
	MOVE.B	D1,D0
	MOVE.W	(SP)+,D1
	BSR	RtgSprAdd
RtgS2N:	ADDQ.W	#1,D7
	CMP.W	#32,D7
	BNE.S	RtgS2L
RtgS2D:	LEA	RtgSp,A2
	MOVE.W	D6,D0			; Sentinel after the last (CC = 0).
	LSL.W	#3,D0
	CLR.B	2(A2,D0.W)
	MOVEQ	#0,D3			; D3 = the first CC=0 sprite
	MOVE.L	A2,A0
RtgS2F:	CMP.W	D6,D3
	BCC	RtgS2X
	BTST	#6,2(A0)
	BEQ.S	RtgS2Dr
	ADDQ.W	#1,D3
	ADDQ.L	#8,A0
	BRA.S	RtgS2F
RtgS2Dr:SUBQ.W	#1,D6			; From the last down to that one.
	CMP.W	D3,D6
	BLT	RtgS2X
	MOVE.W	D6,D1
	LSL.W	#3,D1
	LEA	(A2,D1.W),A1		; A1 = this sprite
	MOVEQ	#0,D0
	MOVE.B	2(A1),D0
	AND.B	#15,D0
	BNE.S	RtgS2C
	BTST	#5,RfR8			; colour 0: only with TP
	BEQ.S	RtgS2Dr
RtgS2C:	MOVE.W	(A1),D5			; D5 = dot x
	MOVE.L	4(A1),D2
	BTST	#0,RfMAt		; (4.6) SCREEN 6/7: dots 2 wide.
	BNE	RtgS2PW
RtgS2P:	ADD.L	D2,D2
	BCC.S	RtgS2Q
	MOVE.B	D0,D4			; This dot: OR in the CC=1 sprites after.
	LEA	8(A1),A0
RtgS2CC:BTST	#6,2(A0)
	BEQ.S	RtgS2W
	MOVE.W	D5,D1
	SUB.W	(A0),D1			; dot - its x: 0-31 inside
	CMP.W	#32,D1
	BCC.S	RtgS2CN
	MOVE.L	4(A0),D7
	LSL.L	D1,D7
	BPL.S	RtgS2CN
	MOVE.B	2(A0),D7
	AND.B	#15,D7
	OR.B	D7,D4
RtgS2CN:ADDQ.L	#8,A0
	BRA.S	RtgS2CC
RtgS2W:	TST.B	RfG7			; SCREEN 8: the fixed G7 sprite colours.
	BEQ.S	RtgS2W1
	AND.W	#15,D4
	MOVE.B	(RtgG7Sp,PC,D4.W),D4
RtgS2W1:MOVE.B	D4,(A4,D5.W)
RtgS2Q:	ADDQ.W	#1,D5
	TST.L	D2
	BNE.S	RtgS2P
	BRA	RtgS2Dr
RtgS2X:	MOVEM.L	(SP)+,D0-D7/A0-A2/A5
	RTS
; (4.6) The same on a wide line (SCREEN 6/7): each dot at 2x, 2x+1; in
; SCREEN 6 the left one colour bits 3-2, the right one bits 1-0 (openMSX).
RtgS2PW:ADD.L	D2,D2
	BCC.S	RtgS2QW
	MOVE.B	D0,D4
	LEA	8(A1),A0
RtgS2CW:BTST	#6,2(A0)
	BEQ.S	RtgS2WW
	MOVE.W	D5,D1
	SUB.W	(A0),D1
	CMP.W	#32,D1
	BCC.S	RtgS2NW
	MOVE.L	4(A0),D7
	LSL.L	D1,D7
	BPL.S	RtgS2NW
	MOVE.B	2(A0),D7
	AND.B	#15,D7
	OR.B	D7,D4
RtgS2NW:ADDQ.L	#8,A0
	BRA.S	RtgS2CW
RtgS2WW:MOVE.W	D5,D1
	ADD.W	D1,D1
	CMP.B	#4,RfMode
	BEQ.S	RtgS2W6
	MOVE.B	D4,(A4,D1.W)
	MOVE.B	D4,1(A4,D1.W)
	BRA.S	RtgS2QW
RtgS2W6:MOVE.B	D4,D7
	LSR.B	#2,D7
	AND.B	#3,D7
	MOVE.B	D7,(A4,D1.W)
	AND.B	#3,D4
	MOVE.B	D4,1(A4,D1.W)
RtgS2QW:ADDQ.W	#1,D5
	TST.L	D2
	BNE.S	RtgS2PW
	BRA	RtgS2Dr

; D1 = byte D0.W (0-1023) of the mode 2 sprite tables: RfSprC + (index AND
; RfSprM). Uses A2.
RtgS2Rd:
	MOVE.L	A2,-(SP)
	MOVE.L	RfSprC,A2
	AND.W	RfSprM+2,D0
	MOVE.B	(A2,D0.W),D1
	MOVE.L	(SP)+,A2
	RTS

; Both modes: D5 = check line (D7 - 1 + R#23) AND 255, D4 = size (8/16, x2
; with MAG), D3 = pattern number mask; RfMag, RfSize.
RtgSprPrep:
	MOVEQ	#0,D5
	MOVE.B	RfR23,D5
	ADD.W	D7,D5
	SUBQ.W	#1,D5
	AND.W	#$FF,D5
	MOVEQ	#8,D4
	MOVE.W	#$FF,D3
	SF	RfSize
	BTST	#1,RfR1			; SI: 16x16
	BEQ.S	RtgSP8
	MOVEQ	#16,D4
	MOVE.W	#$FC,D3
	ST	RfSize
RtgSP8:	SF	RfMag
	BTST	#0,RfR1			; MAG
	BEQ.S	RtgSPX
	ADD.W	D4,D4
	ST	RfMag
RtgSPX:	RTS

; Sprite D6 into the line's list (RtgSp: x.W, colour attribute.B, -, pattern.L
; with dot 0 in bit 31): D0 = pattern number, D1 = line in the sprite (before
; MAG), D2 = colour attribute (bit 7 EC: x - 32), D3 = pattern number mask,
; RfSx = x. D6 + 1.
RtgSprAdd:
	MOVEM.L	D0-D3/A1-A2,-(SP)
	TST.B	RfMag
	BEQ.S	RtgSA1
	LSR.W	#1,D1
RtgSA1:	AND.W	D3,D0
	AND.L	#$FF,D0			; (all of D0: RtgSpr2 leaves a table
					; address's bit 16 in its high word)
	LSL.W	#3,D0
	ADD.W	D1,D0			; pattern*8 + line
	MOVE.L	RfSprP,D1
	ADD.L	D0,D1
	AND.L	#$1FFFF,D1
	MOVE.L	RfSprV,A1		; (SPRSH, the logical view, in SCREEN 7/8)
	MOVEQ	#0,D3
	MOVE.B	(A1,D1.L),D3
	LSL.W	#8,D3
	TST.B	RfSize
	BEQ.S	RtgSA2
	ADD.L	#16,D1			; the right half
	AND.L	#$1FFFF,D1
	MOVE.B	(A1,D1.L),D3
RtgSA2:	TST.B	RfMag			; MAG: every dot twice
	BEQ.S	RtgSA3
	MOVE.W	D3,D1
	LSR.W	#8,D1
	MOVE.W	(RtgDbl.L,D1.W*2),D0
	SWAP	D0
	AND.W	#$FF,D3
	MOVE.W	(RtgDbl.L,D3.W*2),D0
	MOVE.L	D0,D3
	BRA.S	RtgSA4
RtgSA3:	SWAP	D3
	CLR.W	D3
RtgSA4:	LEA	RtgSp,A2
	MOVE.W	D6,D1
	LSL.W	#3,D1
	ADD.W	D1,A2
	MOVE.L	D3,4(A2)
	MOVE.B	D2,2(A2)
	MOVE.W	RfSx,D0
	TST.B	D2
	BPL.S	RtgSAx
	SUB.W	#32,D0
RtgSAx:	MOVE.W	D0,(A2)
	MOVEM.L	(SP)+,D0-D3/A1-A2
	ADDQ.W	#1,D6
	RTS

; ---------------------------------------------------------------------------
; Line D7 (indices in A4) to the screen, unless it is as last frame: same 256
; indices (RtgLC), same palette and position (RtgLK). Row RfY0 + D7*s, x from
; R#18's horizontal adjust (low nibble, 7 = centre: (R18 AND 15) ^ 7), the
; rest of the row in the border colour; written s times.
RtgPut:
	MOVEM.L	D0-D7/A0-A2,-(SP)
	MOVE.B	RfR18,D0
	AND.B	#15,D0
	EOR.B	#7,D0
	EXT.W	D0
	SUBQ.W	#7,D0
	MOVEQ	#0,D5
	MOVE.B	RtgScl,D5		; D5 = s
	MULS.W	D5,D0
	ADD.W	RtgOX,D0
	BPL.S	RtgPu1
	MOVEQ	#0,D0
RtgPu1:	MOVE.W	RtgW,D1			; x + 256 s <= W
	MOVE.W	D5,D2
	LSL.W	#8,D2
	SUB.W	D2,D1
	CMP.W	D1,D0
	BLE.S	RtgPu2
	MOVE.W	D1,D0
RtgPu2:	MOVE.W	D0,D4			; D4 = x
	MOVE.L	RfSig,D0		; Key: palette + x.
	TST.B	RfG7			; (SCREEN 8 lines: no palette)
	BEQ.S	RtgPuK
	MOVE.L	#$47374737,D0
RtgPuK:
	MOVE.W	D4,D1
	SWAP	D1
	MOVE.W	D4,D1
	EOR.L	D1,D0
	BTST	#0,RfMAt		; (4.6) A wide line (512 dots): another
	BEQ.S	RtgPuKw			; key, 512 bytes cached.
	NOT.L	D0
RtgPuKw:LEA	RtgLK,A0
	LEA	RtgLV,A1
	MOVE.W	D7,D1
	MULU.W	#512,D1
	LEA	RtgLC,A2
	ADD.L	D1,A2			; A2 = the line's cache
	IFD	RTGNOCACHE		; (debug: every line, every frame)
	BRA.S	RtgPuNew
	ENDC
	TST.B	(A1,D7.W)
	BEQ.S	RtgPuNew
	CMP.L	(A0,D7.W*4),D0
	BNE.S	RtgPuNew
	MOVE.L	A4,A0			; Same key: same indices?
	MOVE.L	A2,A1
	MOVEQ	#64-1,D1
	BTST	#0,RfMAt
	BEQ.S	RtgPuC
	MOVEQ	#128-1,D1
RtgPuC:	CMP.L	(A0)+,(A1)+
	DBNE	D1,RtgPuC
	BEQ	RtgPuHt			; (all 64 equal)
	LEA	RtgLK,A0
	LEA	RtgLV,A1
RtgPuNew:
	IFD	RTGDBG
	ADDQ.W	#1,RtgDbgW
	ENDC
	MOVE.L	D0,(A0,D7.W*4)
	ST	(A1,D7.W)
	MOVE.L	A4,A0
	MOVE.L	A2,A1
	MOVEQ	#64-1,D1
	BTST	#0,RfMAt
	BEQ.S	RtgPuS
	MOVEQ	#128-1,D1
RtgPuS:	MOVE.L	(A0)+,(A1)+
	DBF	D1,RtgPuS
; Build the row in RtgRow; with scanlines (2x) a second time from the dimmed
; colours, in RtgRowD (the second of the two rows).
	SF	RfPass
	LEA	RtgRow,A1
RtgPuBd:TST.B	RfG7			; SCREEN 8: G7 colours, R#7 one of them.
	BEQ.S	RtgPuLP
	LEA	RtgG7Lut,A2
	TST.B	RfPass
	BEQ.S	RtgPuG
	LEA	RtgG7LutD,A2
RtgPuG:	MOVEQ	#0,D3
	MOVE.B	REGS+DVDP7,D3
	BRA.S	RtgPuLB
RtgPuLP:LEA	RfLut(PC),A2
	TST.B	RfPass
	BEQ.S	RtgPuP
	LEA	RfLutD,A2
RtgPuP:	MOVEQ	#0,D3			; The border in this line's palette.
	MOVE.B	RfBord,D3
RtgPuLB:MOVE.L	(A2,D3.W*4),D3
	MOVE.W	D4,D1			; left border
	TST.B	RtgBpp4
	BNE.S	RtgPu4
	BSR	RtgPuBW
	MOVE.L	A4,A0
	BTST	#0,RfMAt		; (4.6) wide
	BNE	RtgPuW16
	MOVE.W	#256-1,D1
	CMP.B	#2,D5
	BNE.S	RtgPu21
RtgPu22:MOVEQ	#0,D0			; 16-bit, 2x: a long a dot
	MOVE.B	(A0)+,D0
	MOVE.L	(A2,D0.W*4),(A1)+
	DBF	D1,RtgPu22
	BRA.S	RtgPuR2
RtgPu21:MOVEQ	#0,D0			; 16-bit, 1x: a word
	MOVE.B	(A0)+,D0
	MOVE.W	2(A2,D0.W*4),(A1)+
	DBF	D1,RtgPu21
RtgPuR2:MOVE.W	RtgW,D1			; right border
	SUB.W	D4,D1
	MOVE.W	D5,D2
	LSL.W	#8,D2
	SUB.W	D2,D1
	BSR	RtgPuBW
	BRA	RtgPuDb
RtgPu4:	BSR	RtgPuBL
	MOVE.L	A4,A0
	BTST	#0,RfMAt		; (4.6) wide
	BNE	RtgPuW32
	MOVE.W	#256-1,D1
	CMP.B	#2,D5
	BNE.S	RtgPu41
RtgPu42:MOVEQ	#0,D0			; 32-bit, 2x
	MOVE.B	(A0)+,D0
	MOVE.L	(A2,D0.W*4),D2
	MOVE.L	D2,(A1)+
	MOVE.L	D2,(A1)+
	DBF	D1,RtgPu42
	BRA.S	RtgPuR4
RtgPu41:MOVEQ	#0,D0
	MOVE.B	(A0)+,D0
	MOVE.L	(A2,D0.W*4),(A1)+
	DBF	D1,RtgPu41
RtgPuR4:MOVE.W	RtgW,D1
	SUB.W	D4,D1
	MOVE.W	D5,D2
	LSL.W	#8,D2
	SUB.W	D2,D1
	BSR	RtgPuBL
RtgPuDb:
	IFD	RTGDBGL			; (debug, 16-bit: the line's state in the
	TST.B	RtgBpp4			; left border: R#2 AND $7F as a white bar
	BNE	RtgPuCp			; at 0, the events at 130 (bit 0 red, 1
	LEA	RtgRow,A1		; green, 2 blue, 3 white), R#4 AND $3F at
	MOVEQ	#0,D1			; 140, R#23 / 4 at 260 (bars x2 dots))
	MOVE.B	RfR2,D1
	AND.W	#$7F,D1
	BSR	RtgDbBar
	LEA	RtgRow+260,A1
	MOVE.B	RfDbgFl,D1
	MOVE.W	#$F800,D0
	BSR	RtgDbDot
	MOVE.W	#$07E0,D0
	BSR	RtgDbDot
	MOVE.W	#$001F,D0
	BSR	RtgDbDot
	MOVE.W	#$FFFF,D0
	BSR	RtgDbDot
	LEA	RtgRow+280,A1
	MOVEQ	#0,D1
	MOVE.B	RfR4,D1
	AND.W	#$3F,D1
	BSR	RtgDbBar
	LEA	RtgRow+520,A1
	MOVEQ	#0,D1
	MOVE.B	RfR23,D1
	LSR.W	#2,D1
	BSR	RtgDbBar
	ENDC
; Copy the row s times (scanlines: the second from RtgRowD).
RtgPuCp:TST.B	RfPass
	BNE.S	RtgPuCq
	TST.B	RtgScan
	BEQ.S	RtgPuCq
	CMP.B	#2,D5
	BNE.S	RtgPuCq
	TST.B	RfBlOn
	BNE	RtgPuBn
	ST	RfPass
	LEA	RtgRowD,A1
	BRA	RtgPuBd
RtgPuCq:MOVE.W	D7,D0
	MULU.W	D5,D0
	ADD.W	RfY0,D0
	MOVE.L	RtgBpr,D2
	MULU.L	D2,D0
	MOVE.L	RtgMem,A1
	ADD.L	D0,A1
	MOVEQ	#0,D3
	MOVE.W	RtgW,D3
	TST.B	RtgBpp4
	BNE.S	RtgPuL4
	LSR.W	#1,D3
RtgPuL4:SUBQ.W	#1,D3			; longs - 1
	SUBQ.W	#1,D5
RtgPuRw:LEA	RtgRow,A0
	TST.B	RfPass
	BEQ.S	RtgPuR0
	TST.W	D5			; (0: the second row)
	BNE.S	RtgPuR0
	LEA	RtgRowD,A0
RtgPuR0:MOVE.L	A1,A2
	MOVE.W	D3,D1
RtgPuRL:MOVE.L	(A0)+,(A2)+
	DBF	D1,RtgPuRL
	ADD.L	D2,A1
	DBF	D5,RtgPuRw
RtgPuX:	MOVEM.L	(SP)+,D0-D7/A0-A2
	RTS
; (4.6) A wide line's row (512 dots): at 2x a dot a pixel, at 1x the even
; dots only (every other dot dropped).
RtgPuW16:
	CMP.B	#2,D5
	BNE.S	RtgPuW61
	MOVE.W	#512-1,D1
RtgPuW62:
	MOVEQ	#0,D0
	MOVE.B	(A0)+,D0
	MOVE.W	2(A2,D0.W*4),(A1)+
	DBF	D1,RtgPuW62
	BRA	RtgPuR2
RtgPuW61:
	MOVE.W	#256-1,D1
RtgPuW63:
	MOVEQ	#0,D0
	MOVE.B	(A0)+,D0
	ADDQ.L	#1,A0
	MOVE.W	2(A2,D0.W*4),(A1)+
	DBF	D1,RtgPuW63
	BRA	RtgPuR2
RtgPuW32:
	MOVE.W	#512-1,D1
	CMP.B	#2,D5
	BNE.S	RtgPuW41
RtgPuW42:
	MOVEQ	#0,D0
	MOVE.B	(A0)+,D0
	MOVE.L	(A2,D0.W*4),(A1)+
	DBF	D1,RtgPuW42
	BRA	RtgPuR4
RtgPuW41:
	MOVE.W	#256-1,D1
RtgPuW43:
	MOVEQ	#0,D0
	MOVE.B	(A0)+,D0
	ADDQ.L	#1,A0
	MOVE.L	(A2,D0.W*4),(A1)+
	DBF	D1,RtgPuW43
	BRA	RtgPuR4

; (blended scanlines) Line D7 as last frame: the blend row above it is new
; only when line D7-1 was (RfPrvN).
RtgPuHt:TST.B	RfPrvN
	BEQ.S	RtgPuX
	SF	RfPrvN
	MOVE.W	D7,D1
	MOVE.W	D7,D0
	SUBQ.W	#1,D0
	BSR	RtgBRow
	BRA.S	RtgPuX

; (blended scanlines, 2x) Line D7 is new, its row in RtgRow: its dots
; half-dimmed (RfLutD / RtgG7LutD hold h(c)), its border's and its x kept in
; RtgHMem (a RTGHREC record a line); then, in screen order, the blend row
; above it (lines D7-1 and D7) and its own row (once).
RtgPuBn:MOVE.L	RtgHMem,A1
	MOVE.W	D7,D0
	MULU.W	#RTGHREC,D0
	ADD.L	D0,A1
	LEA	RfLutD,A2
	MOVEQ	#0,D3
	MOVE.B	RfBord,D3
	TST.B	RfG7
	BEQ.S	RtgPuN0
	LEA	RtgG7LutD,A2
	MOVE.B	REGS+DVDP7,D3
RtgPuN0:MOVE.L	A4,A0
	BTST	#0,RfMAt
	BNE	RtgPuNw
	MOVE.W	#256-1,D1
RtgPuNh:MOVEQ	#0,D0
	MOVE.B	(A0)+,D0
	MOVE.L	(A2,D0.W*4),(A1)+
	DBF	D1,RtgPuNh
	MOVE.L	(A2,D3.W*4),(A1)+	; (+1024: the border, +1028: x,
	MOVE.W	D4,(A1)			; +1030: 0, or 1 for a wide line)
	CLR.W	2(A1)
RtgPuNb:TST.W	D7
	BEQ.S	RtgPuN1
	MOVE.W	D7,D1
	MOVE.W	D7,D0
	SUBQ.W	#1,D0
	BSR	RtgBRow
RtgPuN1:ST	RfPrvN
	MOVE.W	D7,D0			; Row RfY0 + 2 D7.
	ADD.W	D0,D0
	ADD.W	RfY0,D0
	EXT.L	D0			; (D0's high word is not clear here)
	MULU.L	RtgBpr,D0
	MOVE.L	RtgMem,A1
	ADD.L	D0,A1
	LEA	RtgRow,A0
	MOVE.W	RtgW,D1
	TST.B	RtgBpp4
	BNE.S	RtgPuN4
	LSR.W	#1,D1
RtgPuN4:SUBQ.W	#1,D1
RtgPuNr:MOVE.L	(A0)+,(A1)+
	DBF	D1,RtgPuNr
	BRA	RtgPuX
; (4.6) A wide line's half-dimmed dots: 16-bit a word a dot (so a long is
; two dots, and the blend row's one add a long still works); 32-bit a long
; a dot, dots 256-511 in RtgHExt (1 KB a line).
RtgPuNw:TST.B	RtgBpp4
	BNE.S	RtgPuNw4
	MOVE.W	#512-1,D1
RtgPuNw2:
	MOVEQ	#0,D0
	MOVE.B	(A0)+,D0
	MOVE.W	2(A2,D0.W*4),(A1)+
	DBF	D1,RtgPuNw2
	BRA.S	RtgPuNwB
RtgPuNw4:
	MOVE.W	#256-1,D1
RtgPuNw5:
	MOVEQ	#0,D0
	MOVE.B	(A0)+,D0
	MOVE.L	(A2,D0.W*4),(A1)+
	DBF	D1,RtgPuNw5
	MOVE.L	A1,-(SP)
	MOVE.L	RtgHExt,A1
	MOVE.W	D7,D0
	MULU.W	#1024,D0
	ADD.L	D0,A1
	MOVE.W	#256-1,D1
RtgPuNw6:
	MOVEQ	#0,D0
	MOVE.B	(A0)+,D0
	MOVE.L	(A2,D0.W*4),(A1)+
	DBF	D1,RtgPuNw6
	MOVE.L	(SP)+,A1
RtgPuNwB:
	MOVE.L	(A2,D3.W*4),(A1)+
	MOVE.W	D4,(A1)
	MOVE.W	#1,2(A1)
	BRA	RtgPuNb

; (blended scanlines) The row between line D0 and line D1 (D1 = D0 + 1, or
; D0 for the last line): screen row RfY0 + 2 D0 + 1 = h(upper) + h(lower),
; one add a dot (h: RtgMkTabH, no carry between channels); PC formats then
; swap the bytes of each pixel (a 2x dot's long is the pixel twice: ROL.L #8).
; Lines with another x (R#18 per line): pixel by pixel. D0-D3/A1 used.
RtgBRow:
	MOVEM.L	D4-D7/A2-A3,-(SP)
	IFD	RTGDBG
	ADDQ.W	#1,RdBlr
	ENDC
	MOVE.L	RtgHMem,A2
	MOVE.L	A2,A3
	MOVE.W	D1,D2
	MULU.W	#RTGHREC,D2
	ADD.L	D2,A3			; A3 = the lower line's record,
	MOVE.W	D0,D2
	MULU.W	#RTGHREC,D2
	ADD.L	D2,A2			; A2 = the upper's.
	ADD.W	D0,D0
	ADDQ.W	#1,D0
	ADD.W	RfY0,D0
	EXT.L	D0			; (the caller's high word: not clear)
	MULU.L	RtgBpr,D0
	MOVE.L	RtgMem,A1
	ADD.L	D0,A1			; A1 = the screen row.
	MOVE.L	1024(A2),D3		; D3 = the border,
	ADD.L	1024(A3),D3
	MOVE.L	1028(A2),D4		; D4 = x (high word), wide (low word).
	CMP.L	1028(A3),D4
	BNE	RtgBRs
	TST.W	D4			; (4.6) Both wide: 16-bit as two narrow
	BNE	RtgBRw			; lines (a long is two pixels either way)
	SWAP	D4			; but for the PC swap; 32-bit 512 longs.
	MOVE.W	RtgW,D6			; D6 = the right border's pixels.
	SUB.W	D4,D6
	SUB.W	#512,D6
	MOVE.W	#256-1,D7
	TST.B	RtgBpp4
	BNE.S	RtgBR4
	TST.B	RtgIsPC
	BNE.S	RtgBRp
RtgBRn2:MOVE.W	D4,D1			; 16-bit
	BSR	RtgPuBW
RtgBR2:	MOVE.L	(A2)+,D0
	ADD.L	(A3)+,D0
	MOVE.L	D0,(A1)+
	DBF	D7,RtgBR2
	MOVE.W	D6,D1
	BSR	RtgPuBW
	BRA.S	RtgBRX
RtgBRp:	ROL.L	#8,D3			; 16-bit PC
	MOVE.W	D4,D1
	BSR	RtgPuBW
RtgBRq:	MOVE.L	(A2)+,D0
	ADD.L	(A3)+,D0
	ROL.L	#8,D0
	MOVE.L	D0,(A1)+
	DBF	D7,RtgBRq
	MOVE.W	D6,D1
	BSR	RtgPuBW
	BRA.S	RtgBRX
RtgBR4:	MOVE.W	D4,D1			; 32-bit
	BSR	RtgPuBL
RtgBR4L:MOVE.L	(A2)+,D0
	ADD.L	(A3)+,D0
	MOVE.L	D0,(A1)+
	MOVE.L	D0,(A1)+
	DBF	D7,RtgBR4L
	MOVE.W	D6,D1
	BSR	RtgPuBL
RtgBRX:	MOVEM.L	(SP)+,D4-D7/A2-A3
	RTS
RtgBRs:
	IFD	RTGSHOT
	ADDQ.L	#1,RtgShSlow
	ENDC
	SWAP	D4			; D4 = the upper line's x, D7 the lower's.
	MOVE.W	1028(A3),D7		; Each pixel p: upper + lower, each its
	MOVEQ	#0,D5			; dot at p - x or its border.
	TST.B	RtgBpp4
	BNE.S	RtgBRt
RtgBRsL:MOVE.W	D5,D0			; 16-bit: a word a pixel, narrow (the dot
	SUB.W	D4,D0			; twice) or wide (4.6) alike.
	CMP.W	#512,D0
	BCC.S	RtgBRs1
	MOVE.W	(A2,D0.W*2),D2
	BRA.S	RtgBRs2
RtgBRs1:MOVE.W	1026(A2),D2
RtgBRs2:MOVE.W	D5,D0
	SUB.W	D7,D0
	CMP.W	#512,D0
	BCC.S	RtgBRs3
	ADD.W	(A3,D0.W*2),D2
	BRA.S	RtgBRs4
RtgBRs3:ADD.W	1026(A3),D2
RtgBRs4:TST.B	RtgIsPC
	BEQ.S	RtgBRs5
	ROL.W	#8,D2
RtgBRs5:MOVE.W	D2,(A1)+
	ADDQ.W	#1,D5
	CMP.W	RtgW,D5
	BCS.S	RtgBRsL
	BRA	RtgBRX
; 32-bit: a narrow line's long is a dot (2 pixels), a wide one's a pixel
; (dots 256-511 in RtgHExt: A0 upper, A4 lower).
RtgBRt:	MOVEM.L	A0/A4,-(SP)
	MOVE.L	A2,A0
	BSR	RtgHExA
	MOVE.L	A0,A4
	MOVE.L	A3,A0
	BSR	RtgHExA
	EXG	A0,A4
RtgBRtL:MOVE.W	D5,D0
	SUB.W	D4,D0
	CMP.W	#512,D0
	BCC.S	RtgBRt1
	TST.W	1030(A2)
	BNE.S	RtgBRtw
	LSR.W	#1,D0
	MOVE.L	(A2,D0.W*4),D2
	BRA.S	RtgBRt2
RtgBRtw:CMP.W	#256,D0
	BCC.S	RtgBRte
	MOVE.L	(A2,D0.W*4),D2
	BRA.S	RtgBRt2
RtgBRte:MOVE.L	-1024(A0,D0.W*4),D2
	BRA.S	RtgBRt2
RtgBRt1:MOVE.L	1024(A2),D2
RtgBRt2:MOVE.W	D5,D0
	SUB.W	D7,D0
	CMP.W	#512,D0
	BCC.S	RtgBRt3
	TST.W	1030(A3)
	BNE.S	RtgBRtv
	LSR.W	#1,D0
	ADD.L	(A3,D0.W*4),D2
	BRA.S	RtgBRt4
RtgBRtv:CMP.W	#256,D0
	BCC.S	RtgBRtf
	ADD.L	(A3,D0.W*4),D2
	BRA.S	RtgBRt4
RtgBRtf:ADD.L	-1024(A4,D0.W*4),D2
	BRA.S	RtgBRt4
RtgBRt3:ADD.L	1024(A3),D2
RtgBRt4:MOVE.L	D2,(A1)+
	ADDQ.W	#1,D5
	CMP.W	RtgW,D5
	BCS.S	RtgBRtL
	MOVEM.L	(SP)+,A0/A4
	BRA	RtgBRX
; (4.6) Both lines wide, the same x.
RtgBRw:	SWAP	D4
	MOVE.W	RtgW,D6
	SUB.W	D4,D6
	SUB.W	#512,D6
	MOVE.W	#256-1,D7
	TST.B	RtgBpp4
	BNE.S	RtgBRw4
	TST.B	RtgIsPC
	BEQ	RtgBRn2			; (16-bit: as narrow lines)
	ROL.L	#8,D3			; 16-bit PC: each pixel's bytes swapped.
	MOVE.W	D4,D1
	BSR	RtgPuBW
RtgBRwq:MOVE.L	(A2)+,D0
	ADD.L	(A3)+,D0
	ROL.W	#8,D0
	SWAP	D0
	ROL.W	#8,D0
	SWAP	D0
	MOVE.L	D0,(A1)+
	DBF	D7,RtgBRwq
	MOVE.W	D6,D1
	BSR	RtgPuBW
	BRA	RtgBRX
RtgBRw4:MOVE.W	D4,D1			; 32-bit: dots 0-255, then RtgHExt's.
	BSR	RtgPuBL
RtgBRw5:MOVE.L	(A2)+,D0
	ADD.L	(A3)+,D0
	MOVE.L	D0,(A1)+
	DBF	D7,RtgBRw5
	MOVE.L	A0,-(SP)
	LEA	-1024(A2),A0
	BSR	RtgHExA
	MOVE.L	A0,A2
	LEA	-1024(A3),A0
	BSR	RtgHExA
	MOVE.L	A0,A3
	MOVE.L	(SP)+,A0
	MOVE.W	#256-1,D7
RtgBRw6:MOVE.L	(A2)+,D0
	ADD.L	(A3)+,D0
	MOVE.L	D0,(A1)+
	DBF	D7,RtgBRw6
	MOVE.W	D6,D1
	BSR	RtgPuBL
	BRA	RtgBRX
; A0 = the record A0's RtgHExt part (1 KB a line). Keeps D-registers.
RtgHExA:MOVE.L	D0,-(SP)
	MOVE.L	A0,D0
	SUB.L	RtgHMem,D0
	DIVU.W	#RTGHREC,D0
	AND.L	#$FFFF,D0
	LSL.L	#8,D0
	LSL.L	#2,D0
	ADD.L	RtgHExt,D0
	MOVE.L	D0,A0
	MOVE.L	(SP)+,D0
	RTS

; (blended scanlines) At RtgPlayOpen (OS alive), the scale and RtgScan
; known: RfBlOn when blended is chosen (RtgBlnd) at 2x; RtgHMem (the lines'
; half-dimmed dots, then RtgHCol, the half-dimmed RtgCol) allocated; without
; the memory, hard scanlines. Freed by RtgPlayClose.
RtgBlSet:
	MOVEM.L	D0-D1/A0-A1/A6,-(SP)
	SF	RfBlOn
	IFND	SCANCYC			; (test builds: the memory always)
	TST.B	RtgBlnd
	BEQ.S	RtgBSX
	TST.B	RtgScan
	BEQ.S	RtgBSX
	ENDC
	CMP.B	#2,RtgScl
	BNE.S	RtgBSX
	TST.L	RtgHMem
	BNE.S	RtgBSM
	MOVE.L	#RTGHSIZE,D0
	TST.B	RtgBpp4			; (4.6) 32-bit: the wide lines' second
	BEQ.S	RtgBSA			; 256 dots, RtgHExt.
	ADD.L	#RTGLINES*1024,D0
RtgBSA:	MOVE.L	D0,RtgHSz
	MOVEQ	#1,D1			; MEMF_PUBLIC
	MOVE.L	4.W,A6
	JSR	-198(A6)		; AllocMem
	MOVE.L	D0,RtgHMem
	BEQ.S	RtgBSX
	ADD.L	#RTGLINES*RTGHREC,D0
	MOVE.L	D0,RtgHCol
	ADD.L	#4096*4,D0
	MOVE.L	D0,RtgHExt
RtgBSM:
	IFD	SCANCYC
	TST.B	RtgBlnd
	BEQ.S	RtgBSX
	TST.B	RtgScan
	BEQ.S	RtgBSX
	ENDC
	MOVE.L	RtgHCol,A1
	MOVE.L	RtgFmtP,A0
	BSR	RtgMkTabH
	ST	RfBlOn
RtgBSX:	MOVEM.L	(SP)+,D0-D1/A0-A1/A6
	RTS

	IFD	SCANCYC
; (test builds: -DSCANCYC) After each key-script SNAP the next of the seven
; choices (PrefScan 1-7, from Off), the tables rebuilt with no OS call and
; the whole picture redrawn: one run shows the same title in all of them.
RtgCyc:	MOVEM.L	D0/A0-A1,-(SP)
	MOVE.B	RtgCycN,D0
	ADDQ.B	#1,D0
	CMP.B	#8,D0
	BCS.S	RtgCy1
	MOVEQ	#1,D0
RtgCy1:	MOVE.B	D0,RtgCycN
	JSR	ScanSet
	BSR	RtgMkDim
	SF	RfBlOn
	TST.L	RtgHMem
	BEQ.S	RtgCy2
	TST.B	RtgBlnd
	BEQ.S	RtgCy2
	TST.B	RtgScan
	BEQ.S	RtgCy2
	MOVE.L	RtgHCol,A1
	MOVE.L	RtgFmtP,A0
	BSR	RtgMkTabH
	ST	RfBlOn
RtgCy2:	BSR	RtgMkG7
	ST	RtgFull
	MOVEM.L	(SP)+,D0/A0-A1
	RTS
RtgCycN:DC.B	1
	EVEN
	ENDC

	IFD	RTGSHOT
; (test builds: -DRTGSHOT) The RTG screen as it was at each key-script SNAP
; (the frame after it, before anything is drawn) and at the end of each play
; (RtgPlayClose: back to the menu), copied to memory, up to
; RTGSHOTN; written to AmiMSX:rtgshot.raw when the play screen closes (back
; in the menu): "RSHT", W.W, H.W, BytesPerRow.L, P96 format.L, shots.L,
; blend rows drawn pixel by pixel so far (RtgBRs).L, then the shots
; (BytesPerRow x H each), as the board holds them.
RTGSHOTN=8
RtgShAlloc:				; (RtgPlayOpen, OS alive)
	MOVEM.L	D0-D1/A0-A1/A6,-(SP)
	CLR.L	RtgShN
	TST.L	RtgShMem
	BNE.S	RtgShAX
	MOVE.L	RtgBpr,D0
	MULU.W	RtgH,D0
	MOVE.L	D0,RtgShSz
	MULU.L	#RTGSHOTN,D0
	MOVE.L	#$10000,D1		; MEMF_CLEAR
	MOVE.L	4.W,A6
	JSR	-198(A6)		; AllocMem
	MOVE.L	D0,RtgShMem
RtgShAX:MOVEM.L	(SP)+,D0-D1/A0-A1/A6
	RTS
RtgShGrab:				; (no OS)
	MOVEM.L	D0-D1/A0-A1,-(SP)
	TST.L	RtgShMem
	BEQ.S	RtgShGX
	MOVE.L	RtgShN,D0
	CMP.L	#RTGSHOTN,D0
	BCC.S	RtgShGX
	MULU.L	RtgShSz,D0
	MOVE.L	RtgShMem,A1
	ADD.L	D0,A1
	MOVE.L	RtgMem,A0
	MOVE.L	RtgShSz,D0
	LSR.L	#2,D0
	BRA.S	RtgShGE
RtgShGL:MOVE.L	(A0)+,(A1)+
RtgShGE:SUBQ.L	#1,D0
	BPL.S	RtgShGL
	ADDQ.L	#1,RtgShN
RtgShGX:MOVEM.L	(SP)+,D0-D1/A0-A1
	RTS
RtgShWrite:				; (RtgPlayClose, OS alive)
	MOVEM.L	D0-D3/A0-A1/A6,-(SP)
	TST.L	RtgShMem
	BEQ	RtgShWX
	TST.L	RtgShN
	BEQ	RtgShWF
	MOVE.W	RtgW,RtgShHd+4
	MOVE.W	RtgH,RtgShHd+6
	MOVE.L	RtgBpr,RtgShHd+8
	MOVE.L	RtgRI+8,RtgShHd+12
	MOVE.L	RtgShN,RtgShHd+16
	MOVE.L	RtgShSlow,RtgShHd+20
	MOVE.L	#RtgShNom,D1
	MOVE.L	#1006,D2		; MODE_NEWFILE
	JSR	OPENFILE
	TST.L	D0
	BEQ	RtgShWF
	MOVE.L	#RtgShHd,D2
	MOVEQ	#24,D3
	JSR	WRITEFILE
	MOVE.L	RtgShMem,D2
	MOVE.L	RtgShSz,D3
	MULU.L	RtgShN,D3
	JSR	WRITEFILE
	JSR	CLOSEFILE
RtgShWF:MOVE.L	RtgShMem,A1
	MOVE.L	RtgShSz,D0
	MULU.L	#RTGSHOTN,D0
	MOVE.L	4.W,A6
	JSR	-210(A6)		; FreeMem
	CLR.L	RtgShMem
	CLR.L	RtgShN
RtgShWX:MOVEM.L	(SP)+,D0-D3/A0-A1/A6
	RTS
RtgShMem:	DC.L	0
RtgShSz:	DC.L	0
RtgShN:		DC.L	0
RtgShSlow:	DC.L	0		; blend rows drawn pixel by pixel (RtgBRs)
RtgShHd:	DC.B	"RSHT"
		DS.B	20
RtgShNom:	DC.B	"AmiMSX:rtgshot.raw",0
	EVEN
	ENDC

	IFD	RTGDBG
; (debug) D1 dots of white at (A1)+ as 2 pixels each, then 1 black.
RtgDbBar:
	SUBQ.W	#1,D1
	BMI.S	RtgDbBX
RtgDbB1:MOVE.L	#$FFFFFFFF,(A1)+
	DBF	D1,RtgDbB1
RtgDbBX:CLR.L	(A1)+
	RTS
; (debug) 4 pixels of D0 at (A1)+ if bit 0 of D1, else black; D1 >> 1.
RtgDbDot:
	MOVE.W	D0,D2
	BTST	#0,D1
	BNE.S	RtgDbD1
	MOVEQ	#0,D2
RtgDbD1:MOVE.W	D2,(A1)+
	MOVE.W	D2,(A1)+
	MOVE.W	D2,(A1)+
	MOVE.W	D2,(A1)+
	LSR.B	#1,D1
	RTS
RfDbgFl:	DC.B	0
	EVEN
	ENDC

; D1 pixels of the border (D3) at (A1)+: words (RtgPuBW), longs (RtgPuBL).
RtgPuBW:SUBQ.W	#1,D1
	BMI.S	RtgPuBX
RtgPuB1:MOVE.W	D3,(A1)+
	DBF	D1,RtgPuB1
RtgPuBX:RTS
RtgPuBL:SUBQ.W	#1,D1
	BMI.S	RtgPuBX
RtgPuB2:MOVE.L	D3,(A1)+
	DBF	D1,RtgPuB2
	RTS

; ---------------------------------------------------------------------------
; The scanline choice (the menu's Options > RTG scanlines, the prefs'
; PrefScan, the ToolType SCANLINES: AmiMSX_Menu_v3.1.asm).
; RTG scanlines from a PrefScan code D0.B (1 Off, 2-4 hard 25/50/75%, 5-7
; blended light/normal/strong: 25/50/75% darker); 0 (not set) or another
; value leaves them as they are. Keeps every register.
ScanSet:
	MOVE.L	D1,-(SP)
	MOVEQ	#0,D1
	MOVE.B	D0,D1
	BEQ.S	ScanSetX
	CMP.B	#7,D1
	BHI.S	ScanSetX
	MOVE.B	ScanPct-1(PC,D1.W),RtgScan
	CMP.B	#5,D1
	SCC	RtgBlnd
ScanSetX:
	MOVE.L	(SP)+,D1
	RTS
ScanPct:DC.B	0,25,50,75,25,50,75
	EVEN
; D0.L = the PrefScan code of RtgScan and RtgBlnd (1-7), or 0 when it is
; none of the seven (a SCANLINES=n ToolType of another percentage).
ScanCode:
	MOVEQ	#1,D0
	TST.B	RtgScan
	BEQ.S	ScanCdX
	MOVEQ	#2,D0
	TST.B	RtgBlnd
	BEQ.S	ScanCd1
	MOVEQ	#5,D0
ScanCd1:CMP.B	#25,RtgScan
	BEQ.S	ScanCdX
	ADDQ.W	#1,D0
	CMP.B	#50,RtgScan
	BEQ.S	ScanCdX
	ADDQ.W	#1,D0
	CMP.B	#75,RtgScan
	BEQ.S	ScanCdX
	MOVEQ	#0,D0
ScanCdX:RTS
; D0.L = the PrefScan code of the word at A0 (blendlight 5, blend 6,
; blendstrong 7; any case, the whole value), or 0. Keeps A0.
ScanWord:
	MOVEM.L	D1-D2/A1-A2,-(SP)
	LEA	ScanWds(PC),A1
ScanWdN:MOVE.B	(A1)+,D0		; (a word's code, 0: the table's end)
	BEQ.S	ScanWdX
	MOVE.L	A0,A2
ScanWdC:MOVE.B	(A2)+,D1
	CMP.B	#'A',D1
	BCS.S	ScanWdL
	CMP.B	#'Z',D1
	BHI.S	ScanWdL
	OR.B	#$20,D1
ScanWdL:MOVE.B	(A1)+,D2
	CMP.B	D2,D1
	BNE.S	ScanWdM
	TST.B	D2
	BNE.S	ScanWdC
	BRA.S	ScanWdX			; (the same, to the end)
ScanWdM:TST.B	D2			; Not this one: the next.
	BEQ.S	ScanWdN
ScanWdK:TST.B	(A1)+
	BNE.S	ScanWdK
	BRA.S	ScanWdN
ScanWdX:AND.L	#$FF,D0
	MOVEM.L	(SP)+,D1-D2/A1-A2
	RTS
ScanWds:DC.B	5,"blendlight",0,6,"blend",0,7,"blendstrong",0,0
	EVEN

; ---------------------------------------------------------------------------
	CNOP	0,4
RtgP96:		DC.L	0
RtgGfx:		DC.L	0
RtgModeID:	DC.L	-1
RtgMModeID:	DC.L	-1
RtgScr:		DC.L	0
RtgBm:		DC.L	0
RtgLock:	DC.L	0
RtgRI:		DS.L	3		; RenderInfo: Memory, BytesPerRow, -, format
RtgMem:		DC.L	0
RtgHMem:	DC.L	0		; blended: RTGHSIZE bytes (RtgBlSet)
RtgHCol:	DC.L	0		; in it: 12-bit colour -> h(pixel)
RtgHExt:	DC.L	0		; in it (32-bit): wide lines' dots 256-511
RtgHSz:		DC.L	0		; its size
RfSprV:		DC.L	0		; the line's sprite tables (DIRVRAM/SPRSH)
RtgFmtP:	DC.L	0		; the screen's RtgFmtTab entry
RtgMkDst:	DC.L	0
RtgBpr:		DC.L	0
RtgBdLast:	DC.L	0
RfBdPix:	DC.L	0
RfSig:		DC.L	0
RfNameB:	DC.L	0
RfPatB:		DC.L	0
RfColB:		DC.L	0
RfIdxB:		DC.L	0
RfSprP:		DC.L	0		; sprite patterns (VRAM offset)
RfSprC:		DC.L	0		; mode 2 tables
RfSprM:		DC.L	0
RfLut:		DS.L	16		; the line's palette as pixels
RfLutD:		DS.L	16		; (right after RfLut) the same, dimmed
RfPass:		DC.B	0		; RtgPut: building the dimmed row
	IFND	SCANTEST		; (test builds: -DSCANTEST=n; n > 100:
SCANTEST=0				; blended, n - 100)
	ENDC
	IFGT	SCANTEST-100
RtgScan:	DC.B	SCANTEST-100
RtgBlnd:	DC.B	1
	ELSE
RtgScan:	DC.B	SCANTEST		; ToolType SCANLINES: % darker, 0 = off
RtgBlnd:	DC.B	0		; blended (RtgScan 25, 50, 75), not hard
	ENDC
RfBlOn:		DC.B	0		; this run: blended (RtgBlSet)
RfPrvN:		DC.B	0		; blended: the line before was new
RfMkH:		DC.B	0		; RtgMkTabH
RtgIsPC:	DC.B	0		; the 16-bit pixel is little-endian
RtgDimN:	DS.B	16		; nibble -> dimmed nibble (RtgMkDim)
	EVEN
RtgGun:		DS.L	48
RtgW:		DC.W	0
RtgH:		DC.W	0
RtgOX:		DC.W	0
RtgOY:		DC.W	0
RtgY0Last:	DC.W	-1
RtgNLast:	DC.W	0		; RfN at the last RtgFill
RfN:		DC.W	0
RfY0:		DC.W	0
RfR3:		DC.W	0		; R#10 << 8 | R#3
RfFine:		DC.W	0
RfRowN:		DC.W	0
RfSx:		DC.W	0
RtgHold:	DC.W	0		; AGA frames in a row (RtgUse)
	CNOP	0,4
RtgBufSv:	DS.L	16		; BUFER(A3) across ModChg5Go
RtgWant:	DC.B	0		; ToolType RTG (or -DRTGFORCE)
RtgMenuOn:	DC.B	0		; the menu screen is on RTG
RtgOn:		DC.B	0		; this run: play screen open and locked
RtgNow:		DC.B	0		; this frame drawn on RTG
RtgPrev:	DC.B	0		; the frame before was
Rtg5Dir:	DC.B	0		; (4.5) SCREEN 5 commands on VRAM (R5On)
V5CAct:		DC.B	0		; HMMC/LMMC to VRAM running (V5Cpu)
		EVEN
V5SY:		DC.W	0		; LMMM's lines
V5DY:		DC.W	0
V5COp:		DC.W	0		; HMMC/LMMC: op (-1 HMMC), X, start X,
V5CX:		DC.W	0		; Y, left in the row, a row, rows left
V5CDX:		DC.W	0
V5CY:		DC.W	0
V5CN:		DC.W	0
V5CNX:		DC.W	0
V5CNY:		DC.W	0
RtgFull:	DC.B	0		; fill the whole screen next frame
RtgBpp4:	DC.B	0		; 4 bytes a pixel
RtgScl:		DC.B	2		; 1x or 2x
RfBord:		DC.B	0
RfR1:		DC.B	0
RfR2:		DC.B	0
RfR4:		DC.B	0
RfR8:		DC.B	0
RfR18:		DC.B	0
RfR23:		DC.B	0
RfR25:		DC.B	0
RfR26:		DC.B	0
RfR27:		DC.B	0
RfV9:		DC.B	0
RfBlank:	DC.B	0
RfMode:		DC.B	0
RfG7:		DC.B	0		; this line SCREEN 8 (G7 colours)
RfG7F:		DC.B	0		; SCREEN 8 in this frame
RfMAt:		DC.B	0		; the line's mode: bit 0 wide (512 dots),
					; bit 1 sprites from SPRSH (RtgMAtT)
RfMag:		DC.B	0
RtgMsBot:	DC.B	0		; (4.6) MODESW: the mode below MSplitL
RfBotM:		DC.B	0		; the frame's bottom mode (RtgMsBot or ScrModo)
RfSize:		DC.B	0
RtgTall:	DC.B	0		; the menu at double height
RtgTallNom:	DC.B	"amimsxtall.font",0
		EVEN
RtgTallTA:	DC.L	RtgTallNom	; (TextAttr)
		DC.W	16
		DC.B	0,$40
RtgTallPic:	DS.B	20		; the logo's Image at double height
RtgGfxNom:	DC.B	"graphics.library",0
RtgP96Nom:	DC.B	"Picasso96API.library",0
	CNOP	0,4
RtgSTags:
RtgSTW:		DC.L	$80000023,0	; SA_Width
RtgSTH:		DC.L	$80000024,0	; SA_Height
RtgSTD:		DC.L	$80000025,0	; SA_Depth
RtgSTM:		DC.L	$80000032,0	; SA_DisplayID
		DC.L	$80000038,1	; SA_Quiet
		DC.L	$80000036,0	; SA_ShowTitle
		DC.L	$8000002D,$000F	; SA_Type: CUSTOMSCREEN
		DC.L	$8000003E,0	; SA_Draggable
		DC.L	$8000003F,1	; SA_Exclusive
		DC.L	0

; The modes' attributes by ScrModo (RfMAt): bit 0 a wide line (SCREEN 6, 7,
; TEXT2: 512 dots), bit 1 the sprite tables in SPRSH (SCREEN 7, 8: G6/G7's
; interleaved banks).
RtgMAtT:	DC.B	0,0,0,0,1,3,0,2		; SCREEN 1 2 4 5 6 7 - 8
		DC.B	0,0,0,0,0,0,0,0		; SCREEN 3
		DC.B	0,0,1,0,0,0,0,0		; TEXT1, TEXT2 ($12)
		DC.B	0,0,0,0,0,0,0,0
; A plane byte -> its 8 dots as bytes 0/1 (bit 7 first): SCREEN 6's planes.
	CNOP	0,4
RtgExp:
RtgExV	SET	0
	REPT	256
	DC.B	(RtgExV>>7)&1,(RtgExV>>6)&1,(RtgExV>>5)&1,(RtgExV>>4)&1
	DC.B	(RtgExV>>3)&1,(RtgExV>>2)&1,(RtgExV>>1)&1,RtgExV&1
RtgExV	SET	RtgExV+1
	ENDR

; ---------------------------------------------------------------------------
	SECTION	RtgBss,BSS
RtgCol:		DS.L	4096		; 12-bit colour -> pixel (RtgMkTab)
RtgG7Lut:	DS.L	256		; SCREEN 8 byte -> pixel (RtgMkG7)
RtgG7LutD:	DS.L	256		; the same, dimmed (scanlines)
RtgDbl:		DS.W	256
RtgLK:		DS.L	RTGLINES	; line cache: key (palette, x),
RtgLV:		DS.B	RTGLINES	; valid,
		EVEN
RtgLC:		DS.B	RTGLINES*512	; the line's 256 indices (512: wide).
		DS.B	64		; (sprites up to 32 dots left of 0, x2 wide)
RtgLB:		DS.B	512+64		; the line being drawn
RtgBgBuf:	DS.B	16+512+16
RtgP6B:		DS.B	128		; (SCREEN 6: the line's two plane rows)
RtgSp:		DS.B	8*9		; the line's sprites (+ sentinel)
RtgRow:		DS.L	RTGMAXW
RtgRowD:	DS.L	RTGMAXW		; the dimmed row (scanlines)
	SECTION	MSX2,CODE
