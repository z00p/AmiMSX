
;	 -----------------------------------------------
;	/  AmiMSX Emulator v3.1  (For AMIGA Computers)  \
;	|  1994/00 (c) RED Soft.  (10-4/94 => 25-9/00)  |
;	|  Sistemas de emulaci�n y programaci�n por:    |
;	\  Juan Antonio G�mez G�lvez.   (Alias 007!)    /
;	 -----------------------------------------------

;  **  Escrito con Devpac III  **  C�digo para MC68020 o superiores. **

Usuario=0		; N�mero de usuario registrado.
MENU=0
TOTAL=0			; 1=No prepara datos fundamentales AmigaDos.

Key_ON=1		; 1=Off.

FM_Pak_ROM=1
FFFF_ON=1

HPeriod=228		; Z80 cycles per line (3.58 MHz / 15.7 kHz). The MSX adds a
			; wait state to every M1 fetch: Otra charges T-states + 1,
			; CB/DD/ED/FD prefixes 1 more. (Was 202 with plain T-states,
			; ~1.13 on average: io measured 'not 50 Hz'.)
VPeriodPAL=313
VPeriodNTSC=262

ColorDebug=1

; Linear 48/64Kb cartridges (common in modern homebrew): no mapper, the ROM
; maps straight from &H0000, so the "AB" header is at file offset &H4000.
; \1 = DirCart (An, 8Kb pages already spaced at $2080), \2 = BucCart (ea),
; \3 = Dn out: 16Kb pages to map (3 or 4), or 0 with Z set if not linear.
; Inline on purpose: A7 is not a stack while the Z80 core is set up.
MiraLin:	MACRO
	MOVEQ	#3,\3
	CMP.L	#(6*$2080)+$80,\2	; 48Kb?
	BEQ.S	\@T
	MOVEQ	#4,\3
	CMP.L	#(8*$2080)+$80,\2	; 64Kb?
	BNE.S	\@N
\@T:	CMP.W	#"AB",$80(\1)		; "AB" at &H0000: normal ROM.
	BEQ.S	\@N
	CMP.W	#"AB",$80+(2*$2080)(\1)	; "AB" at &H4000: linear ROM.
	BEQ.S	\@F
\@N:	MOVEQ	#0,\3
\@F:	TST.L	\3
	ENDM

; Bank number written by the Z80, as openMSX RomBlocks::setRom does: used as
; is below the number of banks, else wrapped with the mask. The mask alone
; broke ROMs whose size is not a power of two (1088Kb Barbarian: 68 banks).
; \1 = MaskROMx (A3 offset), \2 = NumROMx (bank count).  Out: D1.W
; Sprite snapshot (MiraInterSnap/T): copy the sprite attribute table and
; the 512 bytes before it (the mode 2 colour table) to \1 and R#6's table
; to \3, then set \2. IMPSPR/IMPSPR2 draw from the snapshots instead of
; VRAM at the end of the frame, so mid-frame changes show as on screen:
; Chikubi Ninja ends its list (Y=216 in #0) under its HUD and in VBlank,
; Uridium switches sprite tables (R#5/R#6) under its HUD at line 63.
; Scanline handlers may only change D1: the rest is the Z80 core's.
; TRACE builds: log a sprite-table event (8 bytes: frame.w, CurLine.w, tag.b,
; value.b, SprSplit.w). Only uses memory: safe in I/O and line handlers.
	IFD	TRACE
TRVLOG:	MACRO
	MOVE.L	A0,TrvA0
	MOVE.L	TrvPtr,A0
	MOVE.W	TrvFrame,(A0)+
	MOVE.W	REGS+CurLine,(A0)+
	MOVE.B	#\1,(A0)+
	MOVE.B	\2,(A0)+
	MOVE.W	SprSplit,(A0)+
	CMP.L	#TrvRegs,A0		; (Not TrvEnd: TraceFreeze fills TrvRegs.)
	BCS.S	\@ok
	LEA	TrvBuf,A0
\@ok:	MOVE.L	A0,TrvPtr
	MOVE.L	TrvA0,A0
	ENDM
	ENDC

; CORRCHK (TRACE builds, vasm -DTRACE=1 -DCORRCHK=1): every line, look for a
; code address in the page tables below REGS (Desbor -160..-97, Restas longs
; -92+8p). The Z80 core keeps A7 in that table, and a port or line handler's
; first-level JSR leaves its return address in the page's scratch long
; (-96+8p); anything pushed deeper (a nested BSR/JSR, MOVEM -(SP)) lands on
; another page's Restas or Desbor entry. On the first hit: CorrVal (the
; value: a return address names the call), CorrAt (where + 4), CorrLine,
; CorrFrame, then TraceFreeze (trace.bin).
	IFD	CORRCHK
CORRCHECK:	MACRO
	MOVEM.L	D0-D1/A0,CorrSv
	LEA	REGS-160,A0
	MOVEQ	#16-1,D0
\@D:	MOVE.L	(A0)+,D1
	CMP.L	#CodeLo,D1
	BCS.S	\@Dn
	CMP.L	#CodeHi,D1
	BCS	\@Hit
\@Dn:	DBF	D0,\@D
	LEA	REGS-92+4,A0
	MOVEQ	#8-1,D0
\@R:	MOVE.L	-4(A0),D1
	CMP.L	#CodeLo,D1
	BCS.S	\@Rn
	CMP.L	#CodeHi,D1
	BCS	\@Hit
\@Rn:	ADDQ.L	#8,A0
	DBF	D0,\@R
	BRA	\@X
\@Hit:	SUB.L	#CodeLo,D1		; Offset in the code section,
	MOVE.L	D1,CorrVal
	SUB.L	#REGS,A0		; the slot's offset from REGS (+4),
	MOVE.L	A0,CorrAt
	MOVE.W	REGS+CurLine,CorrLine
	MOVE.W	TrvFrame,CorrFrame
	TRVLOG	$C0,CorrVal		; into the event ring (read_trv.py).
	TRVLOG	$C1,CorrVal+1
	TRVLOG	$C2,CorrVal+2
	TRVLOG	$C3,CorrVal+3
	TRVLOG	$C4,CorrAt+2
	TRVLOG	$C5,CorrAt+3
	MOVEM.L	CorrSv,D0-D1/A0
	JMP	TraceFreeze
\@X:	MOVEM.L	CorrSv,D0-D1/A0
	ENDM
	ENDC

; PERF builds: sub-timers (see PerfStamp). PERFSUB0 marks, PERFSUB n adds the
; time since the last mark to sub-timer n (0-7) and marks again.
; Sub-timers are opt-in (vasm -DPERF=1 -DPERFSUBS=1). The boot hangs they
; seemed to cause (2 Oct 2026) were a layout bug elsewhere: BNE.S *+10 over a
; MOVE.L to DREGOUT98(A3), which grows from 8 to 12 bytes once OUTS is more
; than 32 KB from REGS (fixed 3 Oct 2026; build.sh now rejects *+n branches).
; No stack: these run inside the Z80 core's render paths, where A7 is the
; Restas table; pushes there overwrite the Desbor entries below it with
; return addresses (layout-dependent boot hangs in PERF builds, 2 Oct 2026).
PERFSTAMPI:	MACRO			; PerfNow = now (as PerfStamp), no stack.
	MOVEM.L	D0-D1,PerfSv
\@B:	MOVE.L	PerfTick,D1
	MOVE.L	$DFF004,D0
	CMP.L	PerfTick,D1
	BNE.S	\@B
	MOVE.L	D0,PerfSv+8
	LSR.L	#8,D0
	AND.L	#$1FF,D0
	CMP.W	PerfVMax,D0
	BLS.S	\@P
	MOVE.W	D0,PerfVMax
\@P:	MULU.L	#313,D1
	ADD.L	D1,D0
	MULU.L	#227,D0
	MOVE.L	PerfSv+8,D1
	AND.L	#$FF,D1
	ADD.L	D1,D0
	MOVE.L	D0,PerfNow
	MOVEM.L	PerfSv,D0-D1
	ENDM
PERFMARK:	MACRO
	IFD	PERFSUBS
	PERFSTAMPI
	MOVE.L	PerfNow,PerfSubT
	ENDC
	ENDM
PERFSUB:	MACRO
	IFD	PERFSUBS
	PERFSTAMPI
	MOVE.L	D0,PerfSv+12
	MOVE.L	PerfNow,D0
	SUB.L	PerfSubT,D0
	ADD.L	D0,PerfRec+32+(\1*4)
	MOVE.L	PerfNow,PerfSubT
	MOVE.L	PerfSv+12,D0
	ENDC
	ENDM

; Table split (SCREEN 4, see PRINT4S): the first change of R#2, R#3, R#10 or
; R#4 during the display. \1 = the register's byte in REGS, D2.B = the new
; value. Saves the tables in use until then (the playfield) and asks the
; copper (AcCoRutGBY4) to switch to SCREENB from the next line.
TSPLITCHK:	MACRO
	CMP.B	\1(A3),D2
	BEQ	\@n
	TST.W	TSplit
	BNE	\@n
	MOVE.W	CurLine(A3),D1
	BEQ	\@n
	CMP.W	#191,D1
	BCC	\@n
	ADDQ.W	#1,D1
	MOVE.W	D1,TSplit
	SEGEND				; (The playfield may be below it.)
	OR.B	#$01,(TabRasCMDS.L,D1.W)
	IFD	TRACE
	TRVLOG	$FA,D2
	ENDC
	MOVE.B	DVDP2(A3),TA_DVDP2
	MOVE.B	MidLinY,TA_LinY		; R#23 before the split (MIDSAMPLE).
	MOVE.W	DVDP3(A3),TA_DVDP3
	MOVE.W	DVDP4(A3),TA_DVDP4
	MOVE.L	PVDP2(A3),TA_PVDP2
	MOVE.L	PVDP3(A3),TA_PVDP3
	MOVE.L	PVDP3B(A3),TA_PVDP3B
	MOVE.L	PVDP4(A3),TA_PVDP4
	MOVE.L	PVDP4B(A3),TA_PVDP4B
\@n:
	ENDM

; End the current segment at this line (register or table split): if it is
; the longest so far, keep its MIDSAMPLE values. Registers kept.
SEGEND:	MACRO
	MOVE.L	D1,SegSv
	MOVE.W	CurLine(A3),D1
	SUB.W	SegStart,D1		; Length of the segment it ends.
	CMP.W	SegBest,D1
	BLS.S	\@k
	MOVE.W	D1,SegBest		; Longest so far: keep its samples.
	MOVE.B	TopR8,SegR8
	MOVE.B	MidAdj,SegAdj
	MOVE.B	MidLinY,SegLinY
\@k:	MOVE.W	CurLine(A3),SegStart
	ST	SegSeen
	MOVE.L	SegSv,D1
	ENDM

; Register splits: a change of R#8, R#18 or R#23 during the display (lines
; 16-191; earlier ones are the frame's own setup) ends a segment, and so does
; a table split (TSPLITCHK). The playfield is the longest segment: SEGCLOSE (line
; 192, before the render) puts that segment's MIDSAMPLE values (TopR8, MidAdj,
; MidLinY) in place. Uridium 2: sprites off and R#2 unchanged for its HUD at
; line 167 (playfield above); Bun-Ga-Rua: sprites off above line 79 (playfield
; below); Space Manbow: status bar above a table split at line 30, sprites
; on below it (playfield below); Lilly's Saga: HUD below a table split at
; line ~173 (playfield above). One sample a frame took the wrong region.
; \1 = the register's byte in REGS, D2.B = the new value. Registers kept.
RSPLITCHK:	MACRO
	CMP.B	\1(A3),D2
	BEQ.W	\@n
	BANDPEND
	CMP.W	#16,CurLine(A3)
	BCS.W	\@n
	CMP.W	#192,CurLine(A3)
	BCC.W	\@n
	SEGEND
	IFD	TRACE
	TRVLOG	$F6,D2
	ENDC
\@n:
	ENDM

; Line 192: if the last segment (to line 192) isn't the
; longest, the longest one's samples replace MIDSAMPLE's. Uses D1.W.
SEGCLOSE:	MACRO
	TST.B	SegSeen
	BEQ.S	\@x
	MOVE.W	#192,D1
	SUB.W	SegStart,D1
	CMP.W	SegBest,D1
	BHI.S	\@x
	MOVE.B	SegR8,TopR8
	MOVE.B	SegAdj,MidAdj
	MOVE.B	SegLinY,MidLinY
\@x:
	ENDM

; Sprite mode 2 band snapshot (see IMPSPR2B): colour table (512 bytes) and
; attributes (128) into BandBuf[BandN], when BandOn (set per frame).
; Playfield R#8/R#18/R#23 for the frame: sampled every 16 lines; with splits,
; the longest segment's samples win (SEGEND, SEGCLOSE).
MIDSAMPLE:	MACRO
	MOVE.B	DVDP8(A3),TopR8
	MOVE.B	VDPAdjust(A3),MidAdj
	MOVE.B	VDPLinY(A3),MidLinY
\@x:
	ENDM

BANDSHOT:	MACRO
	TST.B	BandOn
	BEQ.W	\@x
	CMP.W	#BANDMAX,BandN
	BCC.W	\@x
	MOVEM.L	D0/A0-A1,SnapSave
	MOVEQ	#0,D0
	MOVE.W	BandN,D0
	MULU	#640,D0
	LEA	BandBuf,A1
	ADD.L	D0,A1
	MOVEQ	#0,D0
	MOVE.W	DVDP5(A3),D0
	AND.W	#$03FC,D0
	LSL.L	#7,D0
	LEA	DIRVRAM-512,A0
	ADD.L	D0,A0
	MOVE.W	#(640/4)-1,D0
\@c:	MOVE.L	(A0)+,(A1)+
	DBF	D0,\@c
	MOVE.W	BandN,D0
	LEA	BandLine,A1		; First line of the band (a 16-line
	MOVE.W	REGS+CurLine,(A1,D0.W*2) ; step or a split: BANDPEND).
	SF	BandSplitP
	MOVE.W	BandN,D0		; R#23 of the band: sprites move with
	LEA	BandLinY,A1		; the vertical scroll in effect on
	MOVE.B	VDPLinY(A3),(A1,D0.W)	; each line (Space Manbow: C0h over its
	LEA	BandR8,A1		; status bar, 24h below), and R#8: SPD
	MOVE.B	DVDP8(A3),(A1,D0.W)	; (sprites off) over that status bar.
	ADDQ.W	#1,BandN
	MOVEM.L	SnapSave,D0/A0-A1
\@x:
	ENDM

; A sprite-relevant register changed during the display (R#5/R#6 sprite
; tables, R#8 SPD, R#23 scroll): start a new band at the next line, so the
; band holds that line's state (Zanac EX: sprites vanished just below its
; status bar, whose sprites-off band ran on into the playfield). No registers.
BANDPEND:	MACRO
	TST.B	BandOn
	BEQ.S	\@x
	CMP.W	#192,CurLine(A3)
	BCC.S	\@x
	ST	BandSplitP
\@x:
	ENDM

; Scanline handlers: D1's high word must stay as the core left it (zero):
; it indexes with D1.L. Long arithmetic here goes in the saved D0 (a
; SCREEN 5 table above 64 KB in D1 sent Barbarian's Z80 into a NOP sled).
; The snapshot is sprite mode 1 only: IMPSPR2 doesn't read it.
SNAPSPR:	MACRO
	MOVE.B	DVDP0(A3),D1
	AND.B	#$0C,D1
	BNE.S	\@Fin
	MOVEM.L	D0/A0-A1,SnapSave
	LEA	DIRVRAM-512,A0
	ADD.L	PVDP5(A3),A0
	LEA	\1,A1
	MOVE.W	#((512+128)/4)-1,D0
\@Buc:	MOVE.L	(A0)+,(A1)+
	DBF	D0,\@Buc
	MOVE.L	PVDP6(A3),\3
	ST	\2
	MOVEM.L	SnapSave,D0/A0-A1
\@Fin:
	ENDM

; Screen mode change (VDP0/VDP1, D1.W = new mode). During the display it is
; a mode split (MSplitL = first line in the new mode); while splits keep
; coming (MSplitSeen), SCREEN 4 <-> SCREEN 5 flips keep the SCREEN 4 screen
; and caches (no full redraw) unless VDP commands drew in SCREEN 5.
MODESW:	MACRO
	MOVE.W	D1,MsNewW
	MOVE.B	ScrModo(A3),MsOld
	MOVE.B	D1,ScrModo(A3)
	MOVE.W	CurLine(A3),D1
	BEQ.S	\@ns
	CMP.W	#191,D1
	BCC.S	\@ns
	TST.W	MSplitL
	BNE.S	\@ns
	ADDQ.W	#1,D1
	MOVE.W	D1,MSplitL
	OR.B	#$01,(TabRasCMDS.L,D1.W)
	MOVE.B	MsOld,MSplitTop
	MOVE.B	DVDP2(A3),MS_DVDP2
	MOVE.B	VDPLinY(A3),MS_LinY
	MOVE.B	#3,MSplitSeen
\@ns:
	TST.B	MSplitSeen
	BEQ.S	\@full
	MOVE.B	MsNewW+1,D1
	CMP.B	#3,D1			; 4 -> 5: SCREEN 5 isn't rendered.
	BNE.S	\@n5
	CMP.B	#2,MsOld
	BEQ.S	\@keep
	BRA.S	\@full
\@n5:	CMP.B	#2,D1			; 5 -> 4: keep unless commands drew.
	BNE.S	\@full
	CMP.B	#3,MsOld
	BNE.S	\@full
	TST.B	M5Tracked		; Only if SCREEN 5 marked the SCREEN 4
	BEQ.S	\@full			; cache all along (OUT98AT).
	TST.B	Pl5Dirty
	BEQ.S	\@keep
	BRA.S	\@full
\@keep:
	BRA.S	\@end
\@full:	ST	ACTODO(A3)
	ST	ACTODOB(A3)
\@end:
	MOVE.W	MsNewW,D1
	ENDM

BankNum:	MACRO
	MOVEQ	#0,D1
	MOVE.B	(A4),D1
	CMP.W	\2,D1
	BCS.S	\@B
	AND.W	\1(A3),D1
\@B:
	ENDM

; --------------------------------
	SECTION	MSX2,CODE
CodeLo:
; --------------------------------

	IFEQ	Usuario
	IFNE	Key_ON
	LEA	REGS,A3
	BRA.S	VAMOS
	LEA	DEBUG,A0
	MOVEM.L	(A0),D0-D7/A0-A7
	MOVE.B	(A5)+,D2
	JMP	([A3,D2.W*8])
	ENDC
	ENDC
VAMOS:
	JMP	ANEM
	DC.B	"$VER:AmiMSX Emulator v3.1  (25.9.00)",0,0
	DC.B	" By Juan Antonio G�mez.",0,0



; -----------------------------------------------------------------
; =================================================================
; *****************************************************************
; ***								***
; ***            Rutinas Inicializadoras de Tablas		***
; ***								***
; *****************************************************************
; =================================================================
; -----------------------------------------------------------------


; -------------------------------=> Inicializa Sistema (Precalcula Tablas)
	CNOP	0,8
InitSistema:
	JSR	CreaCoorSprits
	JSR	CREATABSC5
	JSR	CREATABCORX
	JSR	CREATABB4P

	BSR	CreaCoppLine		; *Z0*

	BSR	ArreglaScr8Pal

	BSR	CreaTabPun8	; Crea Tabla conversion PUN8 => BPL8

	RTS
; -------------------------------<=

; -------------------------------=> Inicializa datos en CopperLine.
CoppLineSize=$10
	CNOP	0,8
CreaCoppLine:
	MOVE.L	#$2AC1FFFE,D1		; Wait Y and X lines.
	LEA	CopperLine0,A0
	LEA	CopperLine1,A1
	MOVE.L	#CopperRet,D3
	MOVE.W	#(212)-1,D0
CrCoLiBuc:
	MOVE.L	D1,(A0)+		; $00 - Wait
	MOVE.L	D1,(A1)+		; $00 - Wait

	MOVE.W	#$0084,(A0)+		; $04 - DirCoppJump
	MOVE.W	#$0084,(A1)+		; $04 - DirCoppJump
	SWAP	D3
	MOVE.W	D3,(A0)+
	MOVE.W	D3,(A1)+
	MOVE.W	#$0086,(A0)+
	MOVE.W	#$0086,(A1)+
	SWAP	D3
	MOVE.W	D3,(A0)+
	MOVE.W	D3,(A1)+

	MOVE.L	#$009C0000,(A0)+	; $0C - ExeCoppJump
	MOVE.L	#$009C0000,(A1)+	; $0C - ExeCoppJump

	ADD.L	#$01000000,D1
	DBF	D0,CrCoLiBuc
	RTS

;	Ejemplo:

;	DC.W	$xxC1,$FFFE	$00 Wait
;	DC.W	$84,x,$86,x	$04 DirCoppJump
;	DC.W	$xxxx,$0000	$0C ExeCoppJump

; -------------------------------<=


; -------------------------------=> Arregla Paleta Screen 8 para Sprites.
	CNOP	0,8
ArreglaScr8Pal:

	LEA	PasScr8Out,A0
	LEA	PasScr8In,A1
	MOVEQ	#0,D1
	MOVE.W	#(256)-1,D0
ArrScr8PalBuc2:
	MOVE.B	D1,(A0)+
	MOVE.B	D1,(A1)+
	ADDQ.B	#1,D1
	DBF	D0,ArrScr8PalBuc2


	LEA	Scr8PalSwap(PC),A0
	LEA	PasScr8Out,A1
	MOVE.W	#(15)-1,D3
ArrScr8PalBuc1:
	MOVE.W	(A0)+,D0
	MOVE.W	(A0)+,D1
	MOVE.B	(A1,D0.W),D2
	MOVE.B	(A1,D1.W),(A1,D0.W)
	MOVE.B	D2,(A1,D1.W)
	DBF	D3,ArrScr8PalBuc1


	LEA	Scr8Pal,A0
	LEA	PasScr8Out,A1
	LEA	PaletaG7,A2
	MOVE.W	#(256)-1,D0
	MOVEQ	#0,D1
ArrScr8PalBuc:
	MOVE.B	(A1)+,D1
	LEA	(A0,D1.W*4),A3
	LSR.W	#5,D1
	LSL.W	#2,D1
	ADD.W	D1,A3
	MOVE.W	(A2)+,2(A3)
	DBF	D0,ArrScr8PalBuc


	LEA	Scr8PalSwap(PC),A0
	LEA	ILBM8+$30,A1
	MOVE.W	#(15)-1,D3
ArrScr8PalBuc3:
	MOVE.W	(A0)+,D0
	MULU	#3,D0
	MOVE.W	(A0)+,D1
	MULU	#3,D1
	MOVE.L	(A1,D0.W),D2
	MOVE.W	(A1,D1.W),(A1,D0.W)
	MOVE.B	2(A1,D1.W),2(A1,D0.W)
	LSR.W	#8,D2
	MOVE.B	D2,2(A1,D1.W)
	SWAP	D2
	MOVE.W	D2,(A1,D1.W)
	DBF	D3,ArrScr8PalBuc3

	RTS

	CNOP	0,8
Scr8PalSwap:
	DC.W	$21,$01,$22,$0C,$23,$0D,$24,$60,$25,$61,$26,$6C,$27,$6D
	DC.W	$28,$9D,$29,$03,$2A,$1C,$2B,$1F,$2C,$E0,$2D,$E3,$2E,$FC,$2F,$FF
; -------------------------------<=


; -------------------------------=> Crea Tabla conversion PUN8 => BPL8
	CNOP	0,4
CreaTabPun8:
	LEA	TablaPun8Bpl,A0
	MOVEQ	#0,D1
	MOVE.W	#(256*8),D5
	MOVE.W	#(256)-1,D0
CrTaPu8Buc:
	MOVE.W	D1,D2
	MOVEQ	#0,D3
	MOVEQ	#0,D4

	MOVE.B	(PasScr8Out,D2.W),D2
; -=-=-
	LSL.B	#1,D2
	ROXL.L	#8,D4
	LSL.B	#1,D2
	ROXL.L	#8,D4
	LSL.B	#1,D2
	ROXL.L	#8,D4
	LSL.B	#1,D2
	ROXL.L	#8,D4	; 8
; -=-=-
	LSL.B	#1,D2
	ROXL.L	#8,D3
	LSL.B	#1,D2
	ROXL.L	#8,D3
	LSL.B	#1,D2
	ROXL.L	#8,D3
	LSL.B	#1,D2
	ROXL.L	#8,D3	; 8
; -=-=-
	MOVE.L	D3,(A0)+
	MOVE.L	D4,(A0)+
	LEA	-8(A0,D5.W),A1
	REPT	7
	LSR.L	#1,D3
	LSR.L	#1,D4
	MOVE.L	D3,(A1)
	MOVE.L	D4,4(A1)
	ADD.W	D5,A1
	ENDR

	ADDQ.B	#1,D1
	DBF	D0,CrTaPu8Buc
	RTS

	CNOP	0,8
TablaPun8Bpl:	DS.B	$100*8*8
; -------------------------------<=

; -------------------------------=> CALLcc MACRO
CALLEQ:	MACRO
	BNE.S	\@Salto
	BSR	\1
\@Salto:
	ENDM

CALLNE:	MACRO
	BEQ.S	\@Salto
	BSR	\1
\@Salto:
	ENDM

CALLCS:	MACRO
	BCC.S	\@Salto
	BSR	\1
\@Salto:
	ENDM

CALLCC:	MACRO
	BCS.S	\@Salto
	BSR	\1
\@Salto:
	ENDM
; -------------------------------<=














	CNOP	0,8
ANEM:
; ------------------------------------> Test hook: "AmiMSX <cartridge>" from
;	the CLI inserts it in Slot 1 and powers on (no splash, no requester);
;	"AmiMSX <image>.dsk" loads it into drive A instead. An optional second
;	argument names a key script (KeyScr: scripted keyboard input).
	MOVEM.L	D0/A0,-(SP)
	SUB.L	A1,A1
	MOVE.L	4.W,A6
	JSR	-294(A6)		; FindTask(0)
	MOVE.L	D0,A1
	MOVEM.L	(SP)+,D0/A0
	TST.L	$AC(A1)			; pr_CLI = 0: started from Workbench.
	BEQ	NoAutoCart
	LEA	FILENOM,A1
AutoCartSp:
	SUBQ.L	#1,D0
	BMI.S	AutoCartFin
	MOVE.B	(A0)+,D1
	CMP.B	#' ',D1
	BEQ.S	AutoCartSp
	MOVEQ	#' ',D2			; Name ends at a space...
	CMP.B	#'"',D1
	BNE.S	AutoCartCon
	MOVEQ	#'"',D2			; ...or at the closing quote.
AutoCartBuc:
	SUBQ.L	#1,D0
	BMI.S	AutoCartFin
	MOVE.B	(A0)+,D1
AutoCartCon:
	CMP.B	D2,D1
	BEQ.S	AutoCartFin
	CMP.B	#' ',D1			; Newline or control char.
	BCS.S	AutoCartFin
	MOVE.B	D1,(A1)+
	BRA.S	AutoCartBuc
AutoCartFin:
	CLR.B	(A1)
	MOVE.L	A1,-(SP)		; Optional second argument: a key script
	LEA	KEYNOM,A1		; (test input, see KeyScrRun).
AutoKeySp:
	SUBQ.L	#1,D0
	BMI.S	AutoKeyFin
	MOVE.B	(A0)+,D1
	CMP.B	#' ',D1
	BEQ.S	AutoKeySp
	MOVEQ	#' ',D2
	CMP.B	#'"',D1
	BNE.S	AutoKeyCon
	MOVEQ	#'"',D2
AutoKeyBuc:
	SUBQ.L	#1,D0
	BMI.S	AutoKeyFin
	MOVE.B	(A0)+,D1
AutoKeyCon:
	CMP.B	D2,D1
	BEQ.S	AutoKeyFin
	CMP.B	#' ',D1
	BCS.S	AutoKeyFin
	MOVE.B	D1,(A1)+
	BRA.S	AutoKeyBuc
AutoKeyFin:
	CLR.B	(A1)
	MOVE.L	(SP)+,A1
	TST.B	FILENOM
	SNE	AutoCart
	BEQ.S	NoAutoCart
	MOVE.L	A1,D1			; "*.dsk": a disk image for drive A.
	SUB.L	#FILENOM,D1
	CMP.W	#5,D1
	BCS.S	NoAutoCart
	CMP.B	#'.',-4(A1)
	BNE.S	NoAutoCart
	MOVE.B	-3(A1),D1
	OR.B	#$20,D1
	CMP.B	#'d',D1
	BNE.S	NoAutoCart
	MOVE.B	-2(A1),D1
	OR.B	#$20,D1
	CMP.B	#'s',D1
	BNE.S	NoAutoCart
	MOVE.B	-1(A1),D1
	OR.B	#$20,D1
	CMP.B	#'k',D1
	BNE.S	NoAutoCart
	SF	AutoCart
	ST	AutoDisk
NoAutoCart:
; ------------------------------------<

; ------------------------------------> Arregla Tabla de Instrucciones Z-80A.
	LEA	INSTR,A0
	MOVE.W	#256-1,D0
INSTBUC:
	MOVE.L	(A0,D0.W*4),(A0,D0.W*8)
	MOVE.L	(A0,D0.W*4),4(A0,D0.W*8)
	DBF	D0,INSTBUC
; ------------------------------------<

; ------------------------------------> Pone A $FF p�gina ROM.
	LEA	NOMEM,A0
	MOVEQ	#-1,D1
	MOVE.W	#((16*1024)/8)-1,D0
SetFFBuc:
	MOVE.L	D1,(A0)+
	MOVE.L	D1,(A0)+
	DBF	D0,SetFFBuc
; ------------------------------------<


	BSR	InitSistema


; ------------------------------------> Pone bufer completo para Sprites.
	MOVE.L	#NOSPRIT,D0
	MOVE.L	#NOSPRIT2,D1
	MOVE.L	#NOSPRIT8,D2
	MOVE.L	#NOSPRIT28,D3
	SWAP	D0
	SWAP	D1
	CMP.W	D0,D1
	BEQ.S	SPRBUFBIEN
	EXG.L	D1,D0
	EXG.L	D3,D2
SPRBUFBIEN:
	SWAP	D1
	MOVE.L	D1,DirCaset
	MOVE.L	D1,LoadCaset
	MOVE.L	D1,SaveCaset
	SWAP	D0
	MOVE.L	D0,A0
	MOVE.W	#(INIPANT-22)*$100,(A0)+
	MOVE.W	#(INIPANT-21)*$100,(A0)
	MOVE.L	D0,GFXSPR
	MOVE.L	D2,GFXSPR8
	ADD.L	#(24*4),GFXSPR
	MOVE.L	D0,DIRSPRITES+04
	MOVE.L	D0,DIRSPRITES+16
	MOVE.L	D0,DIRSPRITES+28
	MOVE.L	D0,DIRSPRITES+40
	MOVE.L	D0,DIRSPRITES+52
	MOVE.L	D0,DIRSPRITES+64
	MOVE.L	D0,DIRSPRITES+76
	MOVE.L	D0,DIRSPRITES+88
; ------------------------------------<

; ------------------------------------> Chequea y prepara datos para NO AGA.
	LEA	$DFF000,A6
	MOVE.W	$7C(A6),D1
	MOVE.W	#30-1,D3
BucAGA:
	MOVE.W	$7C(A6),D2
	CMP.B	D2,D1
	BNE.S	NoAGA
	DBF	D3,BucAGA
	ORI.B	#$F0,D1
	CMPI.B	#$F8,D1
;;;;	BRA.s	NoAGA				; *=* TRUCO para ECS ON *=*
	BEQ	SiAGA
NoAGA:
; =--------------------------------=> Base NO AGA.
	MOVE.W	#$01A0,MCAGA
	MOVE.W	#$01A0,MCAGA+4
	MOVE.W	#$01A0,MCAGA+8

;;;;	MOVE.L	#$01FC0000,MCAGA+4		; *=* TRUCO para ECS ON *=*

	CLR.L	DIRSPRITES2
	CLR.L	DIRSPRITES2b
; =--------------------------------=> Copper N
	ADDQ.W	#8,COPPERN+2
	ADDQ.W	#8,COPPERN+6
	MOVE.L	#$01A00000,CNXOR
; =--------------------------------=> Copper 0
	MOVE.W	#$0038,COPPER0+2
	MOVE.W	#$00D0,COPPER0+6
	ADDQ.W	#8,COPPER0+14
	ADDQ.W	#8,COPPER0+18
	LEA	ModSC0+6,A0
	MOVE.W	#(24*2)-1,D0
ModSC0Buc:
	ADDQ.W	#8,(A0)+
	ADDQ	#6,A0
	DBF	D0,ModSC0Buc
	MOVE.L	#$01A00000,C0XOR
; =--------------------------------=> Copper 9
	MOVE.W	#$003C,COPPER9+2
	MOVE.W	#$00D4,COPPER9+6
	ADDQ.W	#8,COPPER9+14
	ADDQ.W	#8,COPPER9+18
	LEA	ModSC9+6,A0
	MOVE.W	#(27*2)-2,D0
ModSC9Buc:
	ADDQ.W	#8,(A0)
	ADDQ.W	#8,4(A0)
	ADD.W	#12,A0
	DBF	D0,ModSC9Buc
	ADDQ.W	#8,4(A0)
	ADDQ.W	#8,4+4(A0)
	MOVE.L	#$01A00000,C9XOR
; =--------------------------------=> Copper 2
	ADDQ.W	#8,C2AGA+2
	ADDQ.W	#8,C2AGA+6
	ADDQ.W	#8,C2BAGA+2
	ADDQ.W	#8,C2BAGA+6
; =--------------------------------=> Copper 5,6,7,8
	MOVE.W	#$0048,AdjustX+2
	MOVE.W	#$00C0,AdjustX+6
	CLR.W	AdjustX+10
	MOVE.L	#$92004C,COPPER6
	MOVE.L	#$9400C4,COPPER6+4
	MOVE.L	#$92004C,COPPER7
	MOVE.L	#$9400C4,COPPER7+4
; =--------------------------------=> Copper 5
;	ADDQ.W	#8,COPPER5+14
;	ADDQ.W	#8,COPPER5+18
	ADDQ.B	#8,ModC50+1
	ADDQ.W	#8,ModC51+2
	MOVE.W	#$4E71,ModC52
	LEA	TabCop5+6,A0
	MOVE.W	#(212+1)-1,D0
ModSC5Buc:
	ADDQ.W	#8,(A0)
	ADDQ.W	#8,4(A0)
	ADD.W	#TabCop5Add,A0
	DBF	D0,ModSC5Buc
; =--------------------------------=> Copper 6
	MOVE.L	#PRINT6ecs,TabScr+($04*8)
	ADDQ.B	#8,ModC60+1
	ADDQ.W	#8,ModC61+2
; =--------------------------------=> Copper 7
	ADDQ.B	#8,ModC70+1
	ADDQ.W	#8,ModC71+2
	MOVE.W	#$4E71,ModC72
; =--------------------------------=> Copper 8
	MOVE.L	#PRINT8ecs,TabScr+($07*8)
	MOVE.L	#VDP17,M8Chap+2
; =--------------------------------=> VDPs ECS
	MOVE.L	#VDP7ecs,VDPPunt+($07*4)
	MOVE.L	#VDP12mT,M5Cap+2
	MOVE.L	#VDP12mT,M6Cap+2
	MOVE.L	#VDP12mT,M7Cap+2
	MOVE.L	#VDP12mT,M8Cap+2
	MOVE.W	#$4E75,Act_Adjust
; =--------------------------------<=
SiAGA:
; --------------------------------------------------------------------<

; --------------------------------------------
	LEA	DIRPLANOS,A0
	JSR	CREAPLANOS
	LEA	DIRCOLORES,A0
	JSR	CREACOLORES
	LEA	DIRSPRITES,A0
	JSR	CREASPRITES
	LEA	DIRSALTOS,A0
	JSR	CREASALTOS
; --------------------------------------------

; ---------------------------------------

	CLR.W	DIRCONTI
	MOVE.L	#BUCLE,DIRCONTI+2
	MOVE.L	#COPPERN,NEXTCOPP

	IFEQ	MENU
	INCLUDE	"AmiMSX_Menu_v3.1.asm"

	LEA	KeyBase(PC),A6
	ADDQ.L	#8,A4
	MOVE.L	A4,(A6)

	MOVE.L	A0,DIRVD0
	MOVE.B	$61(A5),MVDPROT
	MOVE.B	$6A(A5),SwapJoyD
	MOVE.B	D2,LEEJOY2D
	LSR.L	#8,D2
	MOVE.B	D2,MULTIKEY
	LSR.L	#8,D2
	MOVE.B	D2,SCRFRECD
	MOVE.W	D5,UNIDADA
	MOVE.W	D6,UNIDADB
	MOVE.W	D7,VELOCID
	SWAP	D7

; ---------------------------------------=> PSG Outs On/Off
	MOVE.L	#OUTA1S,OUTS+($A1*4)
	MOVE.B	D7,SFXCHIP
	BNE.S	ESSCC0
	MOVE.L	#OUTA1,OUTS+($A1*4)
ESSCC0:
; ---------------------------------------<=

; ---------------------------------------=> Kanji Outs On/Off
	MOVE.L	#OutXX,Outs+($D8*4)
	MOVE.L	#OutXX,Outs+($D9*4)
	MOVE.L	#InXX,Ins+($D9*4)
	TST.B	DirPrefs+$7B		; �Usar Kanji ROM?
	BEQ.S	NoUsaKanji
	TST.B	KanjiDat		; �Est� ya residente?
	BEQ.S	NoUsaKanji
	MOVE.L	#OutD8,Outs+($D8*4)
	MOVE.L	#OutD9,Outs+($D9*4)
	MOVE.L	#InD9,Ins+($D9*4)
NoUsaKanji:
; ---------------------------------------<=

; ---------------------------------------=> And de Paginaci�n segun RAM
	LSR.W	#8,D7
	MOVE.B	D7,PAGIND
; ---------------------------------------<=

; ---------------------------------------=> Modo Pause On/Off
	MOVE.W	#$0308,TECLADO+($46*2)
	TST.B	D4
	BEQ.S	ESMPAUSA
	MOVE.W	#$030E,TECLADO+($46*2)
ESMPAUSA:
; ---------------------------------------<=

; ---------------------------------------=> Emulaci�n de Shifs como Space
	MOVE.W	#$0006,TECLADO+($60*2)
	TST.B	$62(A5)
	BEQ.S	NOLSPACE
	MOVE.W	#$0008,TECLADO+($60*2)
NOLSPACE:
	MOVE.W	#$0006,TECLADO+($61*2)
	TST.B	$63(A5)
	BEQ.S	NORSPACE
	MOVE.W	#$0008,TECLADO+($61*2)
NORSPACE:
; ---------------------------------------<=

; ---------------------------------------=> Parche para MC68060.
	TST.B	EsUn060
	BPL.S	NoMC060
	MOVE.L	#NOP060,Regs+$800
	MOVE.L	#NOP060,Regs+$804
NoMC060:
; ---------------------------------------<=

; ---------------------------------------=> Modo IN VDP (2)
	LEA	IVDP2,A0
	LEA	IVDP2060,A1
	LEA	IVDP2tr,A2
	LEA	IVDP2tr060,A3
	TST.B	EsUn060			; �Es un 060?
	BPL.S	NoMC060b
	MOVE.L	A1,A0
	MOVE.L	A3,A2
NoMC060b:
	TST.B	DirPrefs+$6E		; �Modo tr?
	BEQ.S	NoVDP2TR
	MOVE.L	A2,A0
NoVDP2TR:
	MOVE.L	A0,IVDPPUNT+(2*4)
; ---------------------------------------<=

; ---------------------------------------=> Modo Sprites Collision ON (IN VDP 0)
	MOVE.L	#IVDP0,IVDPPUNT+(0*4)	; (4.0: DirPrefs+$6C, the old 'collisions
					; always' option, is ignored: IVDP0Spr
					; is no longer installed.)
; ---------------------------------------<=

; ---------------------------------------=> Actualiza Punteros de Memory Mapper
	LEA	PUNTSRAM,A0
	LEA	MEMORYMAPPER,A1
	MOVEQ	#6-1,D0
ACTPAG0:
	MOVE.L	(A0)+,A2
	MOVE.L	(A0)+,D1
ACTPAG1:
	MOVE.L	(A2)+,A3
	ADD.W	#$100,A3
	MOVE.L	A3,(A1)+
	MOVE.L	A3,(A1)+
	REPT	7
	ADD.W	#$4100,A3
	MOVE.L	A3,(A1)+
	MOVE.L	A3,(A1)+
	ENDR
	DBF	D1,ACTPAG1
	DBF	D0,ACTPAG0
; ---------------------------------------<=

; -----------------------------------<= Parche de MSX2 para mostrar Kb RAM y Rat�n
	CMP.B	#"C",DirBaseROM+13	; C-BIOS data file ("data CB1"): its
	BEQ	NoROMPatSub		; SUB-ROM differs, no patches there.
	LEA	ROM33+$1AE,A1		; Parche para Rat�n. (MSX2+)
	CMP.B	#1,DirPrefs+$10
	BNE.S	NoROM_MSX2
	LEA	ROM22+$1AE,A1		; Parche para Rat�n. (MSX2)
; 	--------------------
	LEA	ROM22,A0
	MOVE.W	#$4B00,$1C67(A0)
	MOVE.B	#$6D,$1BA7(A0)
	MOVE.L	#$218C3ECD,$3E6C(A0)
	MOVEQ	#0,D0
	MOVE.B	DirPrefs+$1C,D0
	MOVE.L	(DatosRAM.W,PC,D0.W*4),D0
	MOVE.L	D0,$3E8C(A0)
NoROM_MSX2:
; 	--------------------
	MOVE.W	#$ED16,(A1)+
	MOVE.B	#$C9,(A1)+
NoROMPatSub:
; -----------------------------------<=

; -------------------------------------------
	LEA	DirROM+$E1,A0		; Parche para Caset.
	MOVE.L	#$ED18C9ED,(A0)+
	MOVE.W	#$19C9,(A0)+
	ADDQ	#3,A0	
	MOVE.L	#$ED1AC9ED,(A0)+
	MOVE.W	#$1BC9,(A0)+
; -------------------------------------------

; -------------------------------------------
	CMP.B	#2,DirPrefs+$10		; �MSX2+ ROM?
	BEQ.S	SiJapanID
	LEA	DirROM+$2B,A0		; Parche Japanese ID.
	MOVE.W	#$9000,(A0)
	TST.B	DirPrefs+$7A		; Use Japanese ID.
	BNE.S	SiJapanId
	MOVE.W	#$9111,(A0)	; MSX1
	TST.B	DirPrefs+$10		; �MSX1 ROM?
	BEQ.S	SiJapanID
	MOVE.W	#$9116,(A0)	; MSX2
SiJapanId:
; -------------------------------------------


; ---------------------------------------=> �Es Continuar?
 	TST.B	D3
	BEQ	ESCONTINUAR
; ---------------------------------------<=

; ---------------------------------------=> Pone ROM en Slots.
	CLR.W	DIRCONTI
	MOVE.L	#BUCLE,DIRCONTI+2
	MOVE.L	#COPPERN,NEXTCOPP

	LSR.L	#8,D2		; Actualiza ROMs.
	MOVE.L	#ROM10-$0000,SLOT0+(0*8)
	MOVE.L	#ROM11-$4000,SLOT0+(1*8)
	MOVE.L	#NOMEM-$8000,SLOT0+(2*8)
	MOVE.L	#NOMEM-$0000,SLOT2+(0*8)
	MOVE.W	#$0102,TECLADO
	MOVE.W	#$0701,TECLADO+($29*2)
	TST.B	D2
	BEQ	EsContinuar
	MOVE.L	#ROM20-$0000,SLOT0+(0*8)
	MOVE.L	#ROM21-$4000,SLOT0+(1*8)
	MOVE.L	#NOMEM-$8000,SLOT0+(2*8)
	MOVE.L	#ROM22-$0000,SLOT2+(0*8)
	MOVE.W	#$0701,TECLADO
	MOVE.W	#$0102,TECLADO+($29*2)
	SUBQ.B	#1,D2
	BEQ.S	EsContinuar
	MOVE.L	#ROM30-$0000,SLOT0+(0*8)
	MOVE.L	#ROM31-$4000,SLOT0+(1*8)
	MOVE.L	#ROM32-$8000,SLOT0+(2*8)
	MOVE.L	#ROM33-$0000,SLOT2+(0*8)
	SUBQ.B	#1,D2
	BEQ.S	EsContinuar
	MOVE.L	#ROM20-$0000,SLOT0+(0*8)
	MOVE.L	#ROM21-$4000,SLOT0+(1*8)
	MOVE.L	#NOMEM-$8000,SLOT0+(2*8)
	MOVE.L	#ROM22-$0000,SLOT2+(0*8)
EsContinuar:
	ENDC
; ---------------------------------------<=

; ---------------------------------------=> Pone FM Pak en Slots.
	IFEQ	FM_Pak_ROM
	MOVE.L	#NOMEM-$0000,SLOT1
	MOVE.L	#NOMEM-$4000,SLOT1+8
	MOVE.L	#NOMEM-$8000,SLOT1+16
	MOVE.L	#NOMEM-$C000,SLOT1+24
	CMP.B	#3,SFXCHIP
	BNE.S	NoEsFMPak
	MOVE.L	#FMPak0-$0000,SLOT1
	MOVE.L	#FMPak1-$4000,SLOT1+8
	MOVE.L	#FMPak2-$8000,SLOT1+16
	MOVE.L	#FMPak3-$C000,SLOT1+24
;;	MOVE.L	#"APRL",FMPak1+$18
;;	MOVE.L	#"OPLL",FMPak1+$1C
NoEsFMPak:
	ENDC
; ---------------------------------------<=

; ---------------------------------------=> Pone Frecuencia de Pantalla.
	CMP.L	#BUCLE,DIRCONTI+2
	BEQ.S	VD9CON1B
	TST.B	SCRFRECD
	BEQ.S	VD9CON1B
	MOVEQ	#0,D1
	LEA	REGS,A3
	MOVE.B	DVDP9(A3),D2
	BTST	#1,D2
	BEQ.S	VD9CON0B
	MOVE.W	#$20,D1
VD9CON0B:MOVE.W	D1,$DFF1DC
VD9CON1B:
; ---------------------------------------<=

; ------------------------------------=> Pone modo de Paginaci�n.

	MOVE.L	DirCartS1,A0		; Linear 48/64Kb carts: no mapper.
	MiraLin	A0,BucCartS1,D0
	BNE.S	MiraMapperS2

	CMP.L	#($2080*5),BucCartS1	; �Es mayor de 40Kb?
	BCC.S	ConMapperS
MiraMapperS2:
	MOVE.L	DirCartS2,A0
	MiraLin	A0,BucCartS2,D0
	BNE.S	SinMapper

	CMP.L	#($2080*5),BucCartS2	; �Es menor de 40Kb?
	BCS.S	SinMapper

	CMP.B	#2,DIRPREFS+$65		; �Disk ROM = None?
	BEQ.S	ConMapperS
SinMapper:
	LEA	MapNorm(PC),A0
	BRA.S	ConMapper
ConMapperS:
	LEA	MapMapp(PC),A0
ConMapper:
	LEA	Instr+4,A1

	MOVE.L	(A0)+,($32*8)(A1)
	MOVE.L	(A0)+,($77*8)(A1)
	MOVE.L	(A0)+,($70*8)(A1)
	MOVE.L	(A0)+,($71*8)(A1)
	MOVE.L	(A0)+,($72*8)(A1)
	MOVE.L	(A0)+,($73*8)(A1)
	MOVE.L	(A0)+,($74*8)(A1)
	MOVE.L	(A0)+,($75*8)(A1)
	MOVE.L	(A0)+,($02*8)(A1)
	MOVE.L	(A0)+,($12*8)(A1)
	MOVE.L	(A0)+,($36*8)(A1)

; ------------------------------------<=

	IFD	TRACE
	IFND	TRACELITE		; TRACELITE: only the sprite-table event
	BSR	TraceInstala		; ring (TRVLOG), at full speed.
	ENDC
	ENDC

; ---------------------------------------=> Actualiza Relentizador.
	LEA	REGS,A3
	LEA	KeyBase-$538(PC),A0
	JSR	RutRelen
; ---------------------------------------<=


; ---------------------------------------<= Pone Disk ROM en Slots.
	MOVE.L	SLOT2+8,ActDosROM

	CMP.L	#BUCLE,DIRCONTI+2
	BNE	SETDRIVESC

	CMP.B	#2,DIRPREFS+$65			; �Disk ROM?
	BEQ	NoDrives

	TST.B	DIRPREFS+$65			; Tipo de DOS version.
	BNE	SETDOS2

	MOVE.L	#DISK1-$4000,ActDosROM		; DOS

	MOVE.W	#$ED10,DISK1+$1850
	SF	DISK1+$1852

	LEA	DISK1+$10,A0
	MOVE.L	#$ED11C9ED,(A0)+
	MOVE.L	#$12C9ED13,(A0)+
	MOVE.L	#$C9ED14C9,(A0)+
	MOVE.W	#$ED15,(A0)+
	MOVE.B	#$C9,(A0)+

	MOVE.L	#NADA,INSED+($17*4)

	BRA	SETDRIVESC
; *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
SetDOS2:
	MOVE.L	#DISK2-$4000,ActDosROM		; DOS2
; ---
	MOVE.L	#$ED17C900,DISK2+($4000*0)+$92
	MOVE.L	#$ED17C900,DISK2+($4000*1)+$92
	MOVE.L	#$ED17C900,DISK2+($4000*2)+$92
	MOVE.L	#$ED17C900,DISK2+($4000*3)+$92
; ---
	MOVE.W	#$ED10,DISK2+$08B8
	SF	DISK2+$08BA
; ---
	LEA	DISK2+($4000*0)+$10,A0
	MOVE.L	#$ED11C9ED,(A0)+
	MOVE.L	#$12C9ED13,(A0)+
	MOVE.L	#$C9ED14C9,(A0)+
	MOVE.W	#$ED15,(A0)+
	MOVE.B	#$C9,(A0)+
	LEA	DISK2+($4000*1)+$10,A0
	MOVE.L	#$ED11C9ED,(A0)+
	MOVE.L	#$12C9ED13,(A0)+
	MOVE.L	#$C9ED14C9,(A0)+
	MOVE.W	#$ED15,(A0)+
	MOVE.B	#$C9,(A0)+
	LEA	DISK2+($4000*2)+$10,A0
	MOVE.L	#$ED11C9ED,(A0)+
	MOVE.L	#$12C9ED13,(A0)+
	MOVE.L	#$C9ED14C9,(A0)+
	MOVE.W	#$ED15,(A0)+
	MOVE.B	#$C9,(A0)+
	LEA	DISK2+($4000*3)+$10,A0
	MOVE.L	#$ED11C9ED,(A0)+
	MOVE.L	#$12C9ED13,(A0)+
	MOVE.L	#$C9ED14C9,(A0)+
	MOVE.W	#$ED15,(A0)+
	MOVE.B	#$C9,(A0)+
; ---
	MOVE.L	#DOS2MAP,INSED+($17*4)
; *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

SETDRIVESC:
	MOVE.L	#NOMEM-$4000,SLOT2+8
	CLR.W	UNIDADES

	CMP.W	#4,UNIDADA
	BEQ	NODRIVEA
	MOVE.L	ActDosROM,SLOT2+8
	CMP.W	#7,UNIDADA
	BEQ	NODRIVEA
	CMP.W	#5,UNIDADA
	BEQ	NODRIVEA
	MOVE.L	$4,A6
	SUB.L	A1,A1
	JSR	-$126(A6)
	LEA	DISKPORT0,A0
	MOVE.L	D0,16(A0)
	MOVEQ	#0,D0		; Unidad de disco.
	MOVE.W	UNIDADA,D0
	MOVEQ	#0,D1
	LEA	DISKIOREQ0,A1
	MOVE.L	#DISKPORT0,14(A1)
	LEA	MFMDISK,A0
	CMP.W	#6,UNIDADA
	BNE.S	NoRADDriveA
	LEA	RADDISK,A0
	MOVEQ	#2,D0		; Unidad de disco.
NoRADDriveA:
	MOVE.L	$4,A6
	JSR	-$1BC(A6)	; Abre device.
	TST.L	D0
	SEQ	UNIDADES
NODRIVEA:
	CMP.W	#4,UNIDADB
	BEQ	NODRIVES
	MOVE.L	ActDosROM,SLOT2+8
	CMP.W	#7,UNIDADB
	BEQ	NODRIVES
	CMP.W	#5,UNIDADB
	BEQ	NODRIVES
	MOVE.L	$4,A6
	SUB.L	A1,A1
	JSR	-$126(A6)
	LEA	DISKPORT1,A0
	MOVE.L	D0,16(A0)
	MOVEQ	#0,D0		; Unidad de disco.
	MOVE.W	UNIDADB,D0
	MOVEQ	#0,D1
	LEA	DISKIOREQ1,A1
	MOVE.L	#DISKPORT1,14(A1)
	LEA	MFMDISK,A0
	CMP.W	#6,UNIDADB
	BNE.S	NoRADDriveB
	LEA	RADDISK,A0
	MOVEQ	#2,D0		; Unidad de disco.
NoRADDriveB:
	MOVE.L	$4,A6
	JSR	-$1BC(A6)	; Abre device.
	TST.L	D0
	SEQ	UNIDADES+1
NODRIVES:
; ---------------------------------------<=

; ---------------------------------------=> Calcula Checksum de ROMs
	JSR	CALCHECK
	MOVE.L	D0,CHECKSUM
; ---------------------------------------<=

; ---------------------------------------=> Clear Caches.
	MOVE.L	$4.W,A6
	JSR	-$27C(A6)	; ClearCacheU
; ---------------------------------------<=

; ---------------------------------------=> Prepara Amiga Hardware para MSX2.
	LEA	DAMEVBR,A5
	MOVE.L	$4.W,A6
	JSR	-$1E(A6)
	BRA.S	EXCON
	CNOP	0,8
DAMEVBR:
	MOVEC	VBR,A0
	MOVE.L	A0,VBRPun
	NOP
	RTE
	CNOP	0,8
EXCON:
	IFEQ	TOTAL

	JSR	CONGELA

	LEA	$BFE001,A6
	BFEXTU	(A6){6:1},D7		; Filtro.
	MOVE.B	D7,FILTRO

	LEA	$DFF000,A6
	MOVE.W	#$7FFF,D7
	MOVE.W	$1C(A6),INTENA
	MOVE.W	D7,$9A(A6)
	MOVE.W	$1E(A6),INTREQ
	MOVE.W	D7,$9C(A6)
	MOVE.W	$02(A6),DMACON
	MOVE.W	#$8400,$96(A6)
ESPBLI:	BTST	#$06,$02(A6)
	BNE.S	ESPBLI
	MOVE.W	D7,$96(A6)
	MOVE.L	VBRPun,A0
	MOVE.L	$6C(A0),vBlank
	MOVE.L	$4.W,A5
	MOVE.L	$9C(A5),A5
	MOVE.L	$26(A5),WBCOPP
	ENDC

	LEA	$DFF000,A6
	MOVE.W	#$75F0,$096(A6)
	MOVE.L	#COPPERN,$084(A6)
	MOVE.L	#MASTERCOPPER,$080(A6)
	MOVE.W	#0,$088(A6)

	MOVE.W	#$4000,$09A(A6)
	MOVE.W	#$0028,$09C(A6)
ESPERA:
	BTST	#$05,$01F(A6)
	BEQ.S	ESPERA

	CLR.B	$BFEC01
	MOVE.L	VBRPun,A0
	MOVE.L	#Inter,$6C(A0)
	IFD	EXCCHK
	MOVEQ	#10-1,D0		; Vectors 2-11: bus and address error,
	LEA	8(A0),A1		; illegal, zero divide, CHK, TRAPV,
	LEA	ExcOrig,A2		; privilege, trace, line A, line F.
ExcInst:MOVE.L	(A1),(A2)+
	MOVE.L	#ExcCatch,(A1)+
	DBF	D0,ExcInst
	ENDC
	MOVE.W	#$86E0,$096(A6)		; BPL Off
;;;	MOVE.W	#$C028,$09A(A6)
	JMP	MSX			; (BRA: out of range with TRACE code.)
; ---------------------------------------<=

; ---------------------------------------=> Punteros para Paginaci�n.
	CNOP	0,8
MapNorm:DC.L	LDMA,LDHLA,LDHLB,LDHLC,LDHLD,LDHLE
	DC.L	LDHLH,LDHLL,LDBCA,LDDEA,LDHLMN

MapMapp:DC.L	LDMAd,LDHLAd,LDHLBd,LDHLCd,LDHLDd,LDHLEd
	DC.L	LDHLHd,LDHLLd,LDBCAd,LDDEAd,LDHLMNd
; ---------------------------------------<=

; ---------------------------------------=> Texto para Kb de RAM.
	CNOP	0,8
DatosRAM:	DC.L	"128K","256K","512K","1.0M","2.0M","4.0M",0
; ---------------------------------------<=

; ---------------------------------------=>
KeyBase:	DC.L	0
NumROM:		DC.W	0		; Banks in the Slot 1 cartridge: 8Kb,
NumROM2:	DC.W	0		; 16Kb,
NumROM3:	DC.W	0		; and Slot 2: 8Kb,
NumROM4:	DC.W	0		; 16Kb.
SNAPLIN=96				; Sprite snapshot lines (MiraInterSnap/T).
SNAPTOP=8
SnapOK:		DC.B	0
SnapTOK:	DC.B	0
SplitOK:	DC.B	0
SprPass2:	DC.B	0
		EVEN
SnapSave:	DS.L	3
SnapM6:		DC.L	0
SnapT6:		DC.L	0
SprSatM:	DC.L	0
SprSplit:	DC.W	0		; Line where R#5/R#6 changed, 0: none.
SprWinLo:	DC.W	0
SprWinHi:	DC.W	0
SlotMark:	DS.B	64
SlotFromT:	DS.B	64
SlotRemap:	DS.B	64		; Top slot -> remapped slot + 1 (SprSlotsT).
SlotSrc:	DS.B	64		; Remapped slot -> top slot.
SlotTDone:	DS.B	64		; Slots converted into GFXSPRT this frame.
SprTInit:	DC.B	0		; GFXSPRT checked.
		EVEN
GFXSPRT:	DC.L	0		; Top table's pattern slots, 0: none (remap).
SprSnap:	DS.B	512+128		; 512 bytes before the table, then the table.
SprSnapT:	DS.B	512+128
S5Valid:	DC.B	0		; 5th sprite flag (see IVDP0).
RFrame:		DC.B	0		; MSX frames, low byte (LD A,R).
S0LastV:	DC.B	0		; Idle poll (S0Nada): last S#0 value,
S0IdleN:	DC.B	0		; repeats,
		EVEN
S0LastA5:	DC.L	0		; and where it was read.
		EVEN
S5Next:		DC.W	0
S5D2:		DC.L	0
S5Save:		DS.L	9
S5Cnt:		DS.B	256
S5Tab:		DS.B	192
; Sprite collision (S#0 bit 5, see SCCalc).
	IFD	PERF
SCCalls:	DC.L	0
	ENDC
SCPend:		DC.B	0		; Frame ended: check at the next S#0 read.
SCHit:		DC.B	0
SCDblOK:	DC.B	0		; SCDbl built.
SCSI:		DC.B	0		; 16x16,
SCMag:		DC.B	0		; magnified,
SCM2:		DC.B	0		; sprite mode 2.
		EVEN
SCH:		DC.W	0		; Sprite height = width (8, 16, 32).
SCNL:		DC.W	0		; Display lines.
SCLim:		DC.W	0		; Sprites per line (4, 8).
SCStop:		DC.W	0		; Y that ends the list (208, 216).

; ---------------------------------------=> Debug trap (vasm -DTRACE=1).
; Every INSTR entry points at a stub that logs the Z80 PC, opcode and port
; A8 into a ring buffer, then jumps to the saved real handler. A reset (an
; opcode at &H0000 from the BIOS slot) after boot freezes the log, exits,
; which writes AmiMSX:trace.bin (see TraceDump in the menu).
; Uses only D1/A4 (scratch at every handler entry) and no stack: A7 points
; at the Restas table while the Z80 core runs.
	IFD	TRACE
TraceStub:	MACRO
	MOVE.W	A5,D1
	SUB.W	(A7),D1			; Z80 address after the opcode byte.
	MOVE.L	TracePtr,A4
	MOVE.W	D1,(A4)+
	MOVE.B	D2,(A4)+
	MOVE.B	DA8(A3),(A4)+
	CMP.L	#TraceBufEnd,A4
	BCS.S	\@W
	LEA	TraceBuf,A4
\@W:	MOVE.L	A4,TracePtr
	ADDQ.L	#1,TraceCount
	IFD	TRACEAT
	CMP.L	#TRACEAT,TraceCount	; Optional trigger: N instructions.
	BEQ	TraceFreeze
	ENDC
	IFD	TRACEPC
	CMP.W	#TRACEPC,D1		; Optional trigger: this PC (+1)...
	IFND	TRACEFR
	BEQ	TraceFreeze
	ELSEIF
	BNE.S	\@P			; ...from MSX frame TRACEFR on, at its
	CMP.L	#TRACEFR,KeyFrN		; TRACEPCN-th pass (default 1).
	BCS.S	\@P
	ADDQ.W	#1,TrPcPass
	IFND	TRACEPCN
	BRA	TraceFreeze
	ELSEIF
	CMP.W	#TRACEPCN,TrPcPass
	BEQ	TraceFreeze
	ENDC
\@P:
	ENDC
	ENDC
	IFD	TRACENOPS
	TST.B	D2			; Optional trigger: TRACENOPS NOPs in a
	BNE.S	\@N0			; row (the Z80 running through empty
	ADDQ.W	#1,TraceNopN		; memory).
	CMP.W	#TRACENOPS,TraceNopN
	BEQ	TraceFreeze
	BRA.S	\@N1
\@N0:	CLR.W	TraceNopN
\@N1:
	ENDC
	CMP.W	#1,D1			; Opcode at &H0000...
	BNE.S	\@J
	MOVE.B	DA8(A3),D1		; ...with page 0 on the BIOS slot (games
	AND.B	#3,D1			; may CALSLT their own page 0 there)...
	BNE.S	\@J
	CMP.L	#200000,TraceCount	; ...and not the power-on one.
	BCC	TraceFreeze
\@J:	JMP	([TraceTab-$800+\1,D2.W*8])
	ENDM

	CNOP	0,4
TraceStubA:
	TraceStub	0
	CNOP	0,4
TraceStubB:
	TraceStub	4

	CNOP	0,4
	IFD	TRACEFR
TrPcPass:	DC.W	0
	ENDC
	IFD	EXCCHK
; EXCCHK (TRACE builds, -DEXCCHK=1 -DHANGCHK=1): a CPU exception during
; emulation (vectors 2-11). Note the PC, SR and format/vector word, drop
; the exception frame, and RTE into HangGo in user mode (trace.bin with the
; PC in the event ring: $C8-$CB PC, $CC-$CD SR, $CE-$CF format/vector).
ExcCatch:
	MOVE.L	D0,-(SP)		; Only exceptions in AmiMSX's code:
	MOVE.L	4+2(SP),D0		; the rest (the OS's own uses) go to
	CMP.L	#CodeLo,D0		; the original handler.
	BCS.S	ExcChain
	CMP.L	#CodeHi,D0
	BCC.S	ExcChain
	MOVE.L	(SP)+,D0
	MOVE.L	2(SP),HangPC
	MOVE.W	(SP),HangSR
	MOVE.W	6(SP),ExcFmt
	MOVEQ	#0,D0
	MOVE.B	6(SP),D0
	LSR.B	#4,D0
	MOVE.B	(ExcSize.L,D0.W),D0	; Frame size by format.
	ADD.L	D0,SP
	CLR.W	-(SP)			; Format 0.
	PEA	HangGo
	CLR.W	-(SP)			; User mode, IPL 0.
	RTE
ExcChain:
	MOVE.W	4+6(SP),D0
	AND.W	#$0FFF,D0		; Vector offset.
	MOVE.L	(ExcOrig-8.L,D0.W),D0
	MOVE.L	D0,-(SP)		; Target, saved D0, frame.
	MOVE.L	4(SP),D0
	MOVE.L	(SP)+,(SP)		; Target over the saved D0...
	RTS				; ...and go there, frame intact.
ExcRestore:				; Put the original vectors back.
	MOVEM.L	D0/A0-A1,-(SP)
	MOVE.L	VBRPun,A0
	ADDQ.L	#8,A0
	LEA	ExcOrig,A1
	MOVEQ	#10-1,D0
ExcRBuc:MOVE.L	(A1)+,(A0)+
	DBF	D0,ExcRBuc
	MOVEM.L	(SP)+,D0/A0-A1
	RTS
ExcOrig:	DS.L	10
ExcSize:	DC.B	8,8,12,12,16,8,8,60,58,20,32,92,24,8,8,8
ExcFmt:		DC.W	0
		DS.L	32
HangStk:
		EVEN
	ENDC
	IFD	HANGCHK
; HANGCHK (TRACE builds, -DHANGCHK=1): the VBlank interrupt saw no MSX frame
; for 3 s. Log the interrupted PC (offset in the code section) and its SR
; into the event ring ($C8-$CB, $CC-$CD), then freeze (trace.bin).
HangGo:
	IFD	EXCCHK
	LEA	HangStk,SP		; (A7 was the Z80 core's table.)
	BSR	ExcRestore
	ENDC
	LEA	REGS,A3
	MOVE.L	HangPC,D1
	SUB.L	#CodeLo,D1
	MOVE.L	D1,HangPC
	TRVLOG	$C8,HangPC
	TRVLOG	$C9,HangPC+1
	TRVLOG	$CA,HangPC+2
	TRVLOG	$CB,HangPC+3
	TRVLOG	$CC,HangSR
	TRVLOG	$CD,HangSR+1
	IFD	EXCCHK
	TRVLOG	$CE,ExcFmt
	TRVLOG	$CF,ExcFmt+1
	ENDC
	JMP	TraceFreeze
	ENDC
	IFD	CORRCHK
CorrTest:
	CORRCHECK
	JMP	CorrRet
	ENDC
TraceFreeze:
	LEA	TraceHdr+16,A4
	MOVEQ	#8-1,D1
TrFrzBuc:
	MOVE.L	PagRead(A3,D1.W*4),(A4,D1.W*4)	; PagRead (+16).
	DBF	D1,TrFrzBuc
	MOVE.B	DA8(A3),TraceHdr+15
	ST	TraceFrozen
	LEA	-$400(A3),A4		; Emulator state block (REGS-$400..+$800).
	MOVE.L	A5,TrvRegs
	LEA	TrvRegs+4,A5
	MOVE.W	#($C00/4)-1,D1
TrFrzReg:
	MOVE.L	(A4)+,(A5)+
	DBF	D1,TrFrzReg
	MOVE.L	TrvRegs,A5
	JMP	ZALI			; Back to the menu, no Continue.

TraceInstala:
	TST.B	TraceOn
	BNE.S	TrInsFin
	ST	TraceOn
	LEA	INSTR,A0
	LEA	TraceTab,A1
	MOVE.W	#(256*2)-1,D0
TrInsCop:
	MOVE.L	(A0)+,(A1)+
	DBF	D0,TrInsCop
	LEA	INSTR,A0
	MOVE.W	#256-1,D0
TrInsBuc:
	MOVE.L	#TraceStubA,(A0)+
	MOVE.L	#TraceStubB,(A0)+
	DBF	D0,TrInsBuc
	MOVE.L	#TraceBuf,TracePtr
TrInsFin:
	RTS

TraceNopN:	DC.W	0
TraceOn:	DC.B	0
TraceFrozen:	DC.B	0
		CNOP	0,4
TracePtr:	DC.L	0
TraceCount:	DC.L	0
TraceTab:	DS.L	256*2
TraceHdr:	DC.L	"ATRC",0,0,0		; +4 ring offset, +8 count, +15 A8
		DS.L	16			; +16 PagRead[8], +48 PRINT2 count, +52 ACTUTODO2
TraceBuf:	DS.L	4096			; PC.w, opcode.b, A8.b
TraceBufEnd:
	IFD	HANGCHK
HangPC:		DC.L	0
HangLastF:	DC.W	0
HangCnt:	DC.W	0
HangSR:		DC.W	0
	ENDC
	IFD	CORRCHK
CorrSv:		DS.L	3
CorrVal:	DC.L	0		; (CORRCHECK)
CorrAt:		DC.L	0
CorrLine:	DC.W	0
CorrFrame:	DC.W	0
	ENDC
TrvA0:		DC.L	0
TrvLmmcDone:	DC.B	0
		EVEN
TrvPtr:		DC.L	TrvBuf
TrvFrame:	DC.W	0
		DC.W	0
TrvBuf:		DS.B	8*1024
TrvRegs:	DS.B	4+$C00		; (A5, then the state block.)
TrvEnd:
	ENDC
; ---------------------------------------<=
; ---------------------------------------<=

; ---------------------------------------=> Retorna Amiga Hardware para Amiga.
	CNOP	0,8
SALIR:
	MOVEM.L	D0-D7/A0-A7,DEBUG
	MOVE.L	PILA,SP
	IFEQ	TOTAL

	MOVE.B	FILTRO,D7
	LEA	$BFE001,A6
	BFINS	D7,(A6){6:1}		; Filtro.

	LEA	$DFF000,A6
	MOVE.W	#$7FFF,D7
	MOVE.W	#$8000,D6
	MOVE.W	D7,$09A(A6)
	MOVE.W	D7,$096(A6)
	MOVE.W	D7,$09C(A6)
	OR.W	D6,DMACON
	OR.W	D6,INTENA
	OR.W	D6,INTREQ
	MOVE.L	VBRPun,A0
	MOVE.L	vBlank,$6C(A0)
	CLR.W	$180(A6)
	CLR.W	$100(A6)
	MOVE.L	WBCOPP,$080(A6)
	MOVE.L	WBCOPP,$084(A6)
	CLR.W	$088(A6)
	MOVE.W	#$8280,$096(A6)
	MOVE.W	#$0020,$09C(A6)
ESPERA1:
	BTST	#$05,$01F(A6)
	BEQ.S	ESPERA1
	MOVE.W	#$0020,$09C(A6)
ESPERA2:
	BTST	#$05,$01F(A6)
	BEQ.S	ESPERA2
	MOVE.W	D7,$09C(A6)
	MOVE.W	DMACON,$096(A6)
	MOVE.W	INTREQ,$09C(A6)
	MOVE.W	INTENA,$09A(A6)

	LEA	KeyBase-$738(PC),A0
	JSR	DESCONGELA


	CMP.B	#2,DIRPREFS+$65			; �Disk ROM?
	BEQ	NoDrives2

	TST.B	UNIDADES
	BEQ.S	NODRIVES1
	LEA	DISKIOREQ0,A1
	MOVE.W	#$9,28(A1)
	MOVE.L	#$0,36(A1)
	MOVE.L	$4,A6
	JSR	-$1C8(A6)
	LEA	DISKIOREQ0,A1
	MOVE.L	$4,A6
	JSR	-$1C2(A6)	
NODRIVES1:
	TST.B	UNIDADES+1
	BEQ.S	NODRIVES2
	LEA	DISKIOREQ1,A1
	MOVE.W	#$9,28(A1)
	MOVE.L	#$0,36(A1)
	MOVE.L	$4,A6
	JSR	-$1C8(A6)
	LEA	DISKIOREQ1,A1
	MOVE.L	$4,A6
	JSR	-$1C2(A6)	
NODRIVES2:

	ENDC

	MOVEQ	#0,D0
	JSR	CALCHECK
	CMP.L	CHECKSUM,D0
	SNE	D7
	LSL.W	#8,D7

	MOVE.B	DERSTACK,D7

	RTS
; ---------------------------------------<=

; ---------------------------------------=> Retornos con RTS!!!
	CNOP	0,8
RET:
PrtRET:
ModoChgRET:
	RTS
	RTS
	CNOP	0,8
; ---------------------------------------<=



;   --------------------------------------------------------------------------
;   *=*-*=*-*=*-*=*-*=*-*=*-*=*-*=*-*=*-*=*-*=*-*=*-*=*-*=*-*=*-*=*-*=*-*=*-*=
;   --------------------------------------------------------------------------
;   *=*-*=*-*=*-*=*-*=*-*=*-*=*-*=*-*=*-*=*-*=*-*=*-*=*-*=*-*=*-*=*-*=*-*=*-*=
;   --------------------------------------------------------------------------
;   *=*-*=*-*=*-*=*-*=*-*=*-*=*-*=*-*=*-*=*-*=*-*=*-*=*-*=*-*=*-*=*-*=*-*=*-*=
;   --------------------------------------------------------------------------



;	/------------------------\
;	|  MM   MM  SSSSS X   X  |
;	|  M M M M SS      X X   |  	-*  Emulador  Z-80A  *-
;	|  M  M  M  SSSS    X    |
;	|  M     M     SS  X X   |  Por  Juan Antonio G�mez G�lvez.
;	|  M     M SSSSS  X   X  |
;	\------------------------/

;		-*(  Ejecutar bajo MC68020 o superior. )*-

;	Datos de etiquetas:

;	D0 = Pila y uso en PUN=>BPL.	A0 = IX.
;	D1 = Uso libre en .l		A1 = IY.
;	D2 = $01xx.w (Usar en .b)	A2 = VPC (VRAM)
;	D3 = CCF de Amiga. (F y F')	A3 = Datos y Punteros.
;	D4 = HL	(.w)			A4 = Uso libre.
;	D5 = BC	(.w)			A5 = PC (Actual)
;	D6 = DE	(.w)			A6 = SP (Actual)
;	D7 = A y A' (Swap) (.b)		A7 = Punteros paginaci�n.


DVDP4=$6F6
RVDP=-$134
RSPR=$50
DVDP0=$36
DVDP1=$37
PVDP2=-304
PVDP3=-300
PVDP4=-296
PVDP5=-292
PVDP6=-288
PVDP3B=-284
PVDP4B=-280
DatDAA=$6F4
PEXX=2
I=$A
IFF=$B
DA8=$F
D99=$C
DA0=$D
DFC=-164
DFD=-163
DFE=-162
DFF=-161
PSG=$60
ESTADO=$E
PAA=$34
KEY=$40
BUFER=-276
VRAM=$38
RESTA0=-96+4
RESTA1=-80+4
RESTA2=-64+4
RESTA3=-48+4
SLOTS=$520
SLOTSR=$500
SUBSLOTS=$5C0
SUBSLOTSR=$5A0
RESAB=-166
ACTODO=$35
ACTODOB=$7B
ACTSPR=$3F
DATOJOY1=$3C
DATOJOY2=$3D
RUNINT=9
CONTPILA=$70
Ant_PC=-170
MULTEC=$6E7
INTERDAT=$78
LEEJOY2=$3E
Int_EI_V=$72
Int_EI_H=$73
SCRMODO=$7A
ModoInt=$6E6
VDPREGE=-175
VDPREGP=-176
VDPREGL=-177
DATPAL=-180
VDPLINY=-181
DVDP2=-182
DVDP8=-184
DVDP9=-183
DVDPSX=-196
DVDPSY=-194
DVDPDX=-192
DVDPDY=-190
DVDPNX=-188
DVDPNY=-186
VDPINTY=-197
DVDPARG=-198
DB4=-199
DB5=-200
DVDP3=-204
DVDP5=-202
FLASH=-206
DInsBuc=-207
SCRFREC=$6E8
DFFFF=-208
R=-209
DIRPILA=$6C0
DVDP7=$6C4
DVDPC=$6C5
DVDPCL=$6C6
DVDPS1=$6CB
DVDPS2=$6C7
MMOR=$6CA
MMAND=$6C8
DVDPSX2=$6D0
DVDPSY2=$6D2
DVDPDX2=$6D4
DVDPDY2=$6D6
DVDPNX2=$6D8
DVDPNY2=$6DA
CONTA2C=$6CC
CONTA2CX=$6CE
CONTA3CX=$6EA
DVDPREG=$6E0
PetInt38=$6E2
COLREAD=$6E1
PAUSA=8
COSPR2=$6E4
PRINTER=-210
D7C=$6EC
Tipo_Int=$6E5
VDPAdjust=-178
Modo_EI=$6ED
ScanningY=$6EE
TAB_Flags=$7C
Flags_Par=$7C
Flags_Push=$7D
Flags_Pop=$7E
Flags_DAA=$7F
Relen=$74
IntDesbor=$76
CapsLock=$79
MSXVideoMode=$6DC
CPUCopyBufer=$6F0
DirModoChg=-174

MapROMBase1=$54
MapROMBase2=$58
MaskROM=$5C
MaskROM2=$5E
MaskROM3=$30
MaskROM4=$32

KanjiD9=-$137
KanjiD8=-$136
KanjiCnt=-$135

Contador1=-212
Contador2=-$138

Modo060=$6EF

; ---------------------------------------=> Actualiza Datos MSX2.
	CNOP	0,8
MSX:
	MOVE.L	SP,PILA
; ------------------------------
	JSR	PRINT
	JSR	CREATAB7E
; ------------------------------
; ---------------------------------------=> Go / Hard Reset.
HARDRESET:
	MOVE.L	PILA,SP
	MOVE.L	#COPPERN,NEXTCOPP
	MOVE.L	#COPPERN,$DFF084
	LEA	REGS,A3

	LEA	AMITECLAS,A0
	MOVEQ	#-1,D0
	MOVE.L	D0,(A0)+
	MOVE.L	D0,(A0)+
	MOVE.L	D0,(A0)+
	MOVE.L	D0,(A0)+

; ------------------------------	; �Es continuar?
	CMP.L	#BUCLE,DIRCONTI+2
	BNE	CONTINUAR
; ------------------------------

; ------------------------------	; Mira si Reset o HardReset.
	TST.B	EsReset
	BEQ	NoReset
; ------------------------------

; ---------------------------------------=> Borrado de la MSX RAM.
	LEA	PUNTSRAM,A1
	MOVEQ	#(6-1),D1
BUCCR1:
	MOVE.L	(A1)+,A2
	MOVE.L	(A1)+,D2
BUCCR2:
	MOVE.L	(A2)+,D0
	BEQ.S	BUCCR3
	MOVE.L	D0,A0
	MOVE.W	#((($4100*8)+$100)/16)-1,D0
BUCCR:
	CLR.L	(A0)+
	CLR.L	(A0)+
	CLR.L	(A0)+
	CLR.L	(A0)+
	DBF	D0,BUCCR
BUCCR3:
	DBF	D2,BUCCR2
	DBF	D1,BUCCR1
; ---------------------------------------<=

; ---------------------------------------=> Borrado de la VRAM.
	LEA	DIRVRAM,A0
	MOVE.W	#($20000/4)-1,D0
BUCAR:	CLR.L	(A0)+
	DBF	D0,BUCAR

	LEA	SCR0,A0
	MOVE.W	#($20000/8)-1,D0
BUCARG:	CLR.L	(A0)+
	CLR.L	(A0)+
	DBF	D0,BUCARG
; ---------------------------------------<=

	BRA.S	NORESET


; ---------------------------------------=> Reset.
	CNOP	0,8
MSXRESET:
	MOVE.L	PILA,SP
	MOVE.L	#COPPERN,NEXTCOPP
	MOVE.L	#COPPERN,$DFF084
	LEA	REGS,A3

	LEA	AMITECLAS,A0
	MOVE.L	KEY+0(A3),(A0)+
	MOVE.L	KEY+4(A3),(A0)+
	MOVE.L	KEY+8(A3),(A0)+
	MOVE.L	KEY+12(A3),(A0)+


NORESET:
; -----------------------------------------------------------------------
	LEA	DIRSPRITES,A0		; Restaura MSX1 Sprites.
	JSR	CREASPRITES
; -----------------------------------------------------------------------
	LEA	REGS-212,A0
	MOVE.W	#(($80+212)/4)-1,D0
BUCLR:	CLR.L	(A0)+
	DBF	D0,BUCLR

	LEA	REGS+$6C0,A0
	MOVE.W	#(($800-$6C0)/4)-1,D0
BUCLR2:	CLR.L	(A0)+
	DBF	D0,BUCLR2
; -----------------------------------------------------------------------
	SF	MCAGA+10
	LEA	DIRCOLORES,A0		; Restaura colores para MSX1 ROM.
	JSR	CREACOLORES
	LEA	MSX1PAL,A0
	LEA	MSX2Pal,A1
	REPT	16/2
	MOVE.L	(A0)+,(A1)+
	ENDR
; -----------------------------------------------------------------------
	LEA	TABLA7C,A0		; Borra bufers FM-Pak
	MOVEQ	#-1,D0
	REPT	$40/4
	MOVE.L	D0,(A0)+
	ENDR
; -----------------------------------------------------------------------
	CLR.L	SCCKO+$188A		; Borra bufers SCC
	CLR.W	SCCKO+$188A+4
	CLR.L	SCCKO+$38AA
	CLR.W	SCCKO+$38AA+4
; -----------------------------------------------------------------------
; -----------------------------------------------------------------------
	MOVE.B	#$C0,$BFD200		; Inicializa impresora.
	MOVE.B	#$FF,$BFE301		; Inicializa impresora.
;   ---------------------------------------------------------------------
; -----------------------------------------------------------------------
	MOVE.L	#RET,RVDP(A3)
	MOVE.L	#SPRMODE5,RSPR(A3)
	MOVE.L	#$03020100,DFC(A3)
	MOVE.B	#$5,COSPR2(A3)

	MOVE.L	#IN98,DREGIN98(A3)
	MOVE.L	#OUT98,DREGOUT98(A3)
	MOVE.L	#OUT99a,DREGOUT99(A3)
	MOVE.L	#OUT9Aa,DREGOUT9A(A3)

	MOVE.L	#VDP2Enada,VDPPUNT+($2E*4)
	MOVE.L	#ModoChgRET,DirModoChg(A3)

	MOVE.B	EsUn060,Modo060(A3)

	MOVE.L	#DIRVRAM,VRAM(A3)

	LEA	SLOT3,A0
	MOVE.L	#RAM03-$0000,(A0)+
	MOVE.L	#RAM03-$0000,(A0)+
	MOVE.L	#RAM02-$4000,(A0)+
	MOVE.L	#RAM02-$4000,(A0)+
	MOVE.L	#RAM01-$8000,(A0)+
	MOVE.L	#RAM01-$8000,(A0)+
	MOVE.L	#RAM00-$C000,(A0)+
	MOVE.L	#RAM00-$C000,(A0)+

; ------------------------------------> Prepara punteros Paginaci�n.
	MOVE.L	SLOT0,D0
	LEA	RESTA0(A3),A7
	MOVE.W	D0,RESAB(A3)
	MOVE.W	D0,(A7)

	LEA	SLOTS(A3),A0
	MOVE.L	A3,A1
	MOVE.W	#(4)-1,D0
BUCST:	MOVE.L	(A0),PagRead(A1)
	MOVE.L	(A0)+,PagRead+4(A1)
	MOVE.L	(A0),PagWrite(A1)
	MOVE.L	(A0)+,PagWrite+4(A1)
	ADDQ.W	#8,A1
	DBF	D0,BUCST

	LEA	SlotsR(A3),A0
	LEA	SubSlotsR(A3),A1
	MOVE.W	#((SubSlots-Slots)/4)-1,D0
BucSS:	MOVE.L	(A0)+,(A1)+
	DBF	D0,BucSS

; ------------------------------------<

CONTINUAR:


; ------------------------------------> Crea Tablas para Flags.
	IFEQ	Key_ON
	MOVE.L	([KeyBase.W,PC],$10.w),A0
	JSR	(A0)				; Salto a Key
	ELSEIF

PONP:	MACRO
	MOVEQ	#8-1,D1
	MOVE.B	#9,D2
\@:
	ROR.B	#1,D7
	DBCS	D2,\@2
\@2:	DBF	D1,\@
	BFINS	D2,D3{30:1}
	ENDM


	LEA	TAB_Flags(A3),A0
	MOVE.W	#256-1,D6
	MOVEQ	#0,D0
FLAGSBUC:
	MOVEQ	#0,D7
	OR.B	D0,D7
	MOVE.W	CCR,D3
	PONP
	MOVE.B	D3,(A0)+
;	----
	MOVE.B	D0,D1
	MOVEQ	#0,D2
	BFINS	D1,D2{31:1}	; C	(Ami-b0 => MSX-b0)
	LSR.B	#1,D1
	BFINS	D1,D2{29:1}	; P/V	(Ami-b1 => MSX-b2)
	LSR.B	#1,D1
	BFINS	D1,D2{25:1}	; Z	(Ami-b2 => MSX-b6)
	LSR.B	#1,D1
	BFINS	D1,D2{24:1}	; S	(Ami-b3 => MSX-b7)
;	---
	LSR.B	#1,D1
	BFINS	D1,D2{30:1}	; 	(Ami-b4 => MSX-b1)
	LSR.B	#1,D1
	BFINS	D1,D2{28:1}	; 	(Ami-b5 => MSX-b3)
	LSR.B	#1,D1
	BFINS	D1,D2{27:1}	; 	(Ami-b6 => MSX-b4)
	LSR.B	#1,D1
	BFINS	D1,D2{26:1}	; 	(Ami-b7 => MSX-b5)
;	---
	MOVE.B	D2,(A0)+
;	----
	MOVE.B	D0,D1
	MOVEQ	#0,D2
	BFEXTU	D1{24:1},D3	; S	(MSX-b7 => Ami-b3)
	BFINS	D3,D2{28:1}
	BFEXTU	D1{25:1},D3	; Z	(MSX-b6 => Ami-b2)
	BFINS	D3,D2{29:1}
	BFEXTU	D1{29:1},D3	; P/V	(MSX-b2 => Ami-b1)
	BFINS	D3,D2{30:1}
	BFINS	D1,D2{31:1}	; C	(MSX-b0 => Ami-b0)
;	---
	BFEXTU	D1{26:1},D3	; 	(MSX-b5 => Ami-b7)
	BFINS	D3,D2{24:1}
	BFEXTU	D1{27:1},D3	; 	(MSX-b4 => Ami-b6)
	BFINS	D3,D2{25:1}
	BFEXTU	D1{28:1},D3	; 	(MSX-b3 => Ami-b5)
	BFINS	D3,D2{26:1}
	BFEXTU	D1{30:1},D3	; 	(MSX-b1 => Ami-b4)
	BFINS	D3,D2{27:1}
;	---
	MOVE.B	D2,(A0)+
;	----
	MOVE.B	D0,(A0)+
;	----
	ADDQ.B	#1,D0
	DBF	D6,FLAGSBUC

	ENDC
; ------------------------------------<

	MOVE.B	PAGIND,MMOR(A3)
	MOVE.B	MMOR(A3),MMAND+1(A3)
	NOT.B	MMAND+1(A3)

; -----------------------------------------------------------------------
	LEA	AMITECLAS,A0
	MOVE.L	(A0)+,KEY+0(A3)
	MOVE.L	(A0)+,KEY+4(A3)
	MOVE.L	(A0)+,KEY+8(A3)
	MOVE.L	(A0)+,KEY+12(A3)

	SF	PauseDat(A3)		; Variables para MSX PAUSE
	MOVE.B	KEY+$E(A3),PauseKey(A3)
; -----------------------------------------------------------------------

	MOVE.B	LEEJOY2D,LEEJOY2(A3)
	MOVE.B	MULTIKEY,MULTEC(A3)
	MOVE.B	SCRFRECD,SCRFREC(A3)
	MOVE.W	VELOCID,Relen(A3)

	MOVE.B	DirPrefs+$67,Contador2(A3)

; ------------------------------------=>
	BCLR	#2,DVDPS1(A3)			; Desactivaci�n modo MSX2+
	CMP.B	#2,DirPrefs+$10
	BLT.S	NOES2Plus
	BSET	#2,DVDPS1(A3)			; Activaci�n modo MSX2+
NOES2Plus:
; ------------------------------------<=

; ------------------------------------> Actualiza Paleta de colores SPR2
;	CLR.W	$DFF104
;	LEA	CEROS,A0
;	BTST	#1,DVDP8(A3)
;	BNE.S	ActSprCol
;	MOVE.W	#$003F,$DFF104
;	LEA	MSX2Pal+2,A0
;ActSprCol:
;	LEA	$DFF1A0+2,A4
;	MOVE.W	(A0)+,(A4)+
;	REPT	7
;	MOVE.L	(A0)+,(A4)+
;	ENDR
; ------------------------------------<

	BSR	DATOSINIT

; ----------------------------------


; ---------------------------------------=> Actualiza Slots de Cartuchos.

	LEA	REGS,A3

	CMP.L	#Bucle,DirConti+2		; �Power ON?
	BEQ.S	Slt1EsPowerOn

	TST.B	Slot1Cart			; �Insertado un cartucho?
	BNE.S	Slt1EsPowerOn

	MOVE.L	CheckIdS1Old,D0			; �El mismo Cartucho?
	CMP.L	CheckIdS1,D0
	BEQ	NoSlot1Cart
	MOVE.L	CheckIdS1,CheckIdS1Old

Slt1EsPowerOn:
	SF	Slot1Cart

;-;	MOVE.L	#NOMEM-$0000,SLOT1		; Para P�gina 0
;-;	MOVE.L	#NOMEM-$0000,SubSLOT1		; Para P�gina 0

	MOVE.L	#NOMEM-$4000,SLOT1+8
	MOVE.L	#NOMEM-$8000,SLOT1+16
	MOVE.L	#NOMEM-$4000,SubSLOT1+8
	MOVE.L	#NOMEM-$8000,SubSLOT1+16
	MOVE.L	#NOMEM-$0000,SLOT1+0		; Pages 0 and 3: linear carts.
	MOVE.L	#NOMEM-$C000,SLOT1+24
	MOVE.L	#NOMEM-$0000,SubSLOT1+0
	MOVE.L	#NOMEM-$C000,SubSLOT1+24

	TST.L	BucCartS1			; �Hay cartucho en Slot 1?
	BEQ	NoSlot1Cart

	MOVE.L	DirCartS1,A0			; Linear 48/64Kb cart from &H0000:
	MiraLin	A0,BucCartS1,D0		; 8Kb page k is at base+k*$2080,
	BEQ.S	NoLinealS1			; so page p (16Kb) is base+p*$100.
	ADD.W	#$0080,A0
	MOVE.L	A0,MapROMBase1(A3)
	MOVE.L	A0,SLOT1+0
	ADD.W	#$80,A0
	MOVE.L	A0,SubSLOT1+0
	ADD.W	#$80,A0
	MOVE.L	A0,SLOT1+8
	ADD.W	#$80,A0
	MOVE.L	A0,SubSLOT1+8
	ADD.W	#$80,A0
	MOVE.L	A0,SLOT1+16
	ADD.W	#$80,A0
	MOVE.L	A0,SubSLOT1+16
	CMP.W	#4,D0				; 64Kb: page 3 too.
	BNE	NoSlot1Cart
	ADD.W	#$80,A0
	MOVE.L	A0,SLOT1+24
	ADD.W	#$80,A0
	MOVE.L	A0,SubSLOT1+24
	BRA	NoSlot1Cart
NoLinealS1:

	CMP.L	#($2080*3+$80),BucCartS1	; �Es de 16Kb? (menor de 24Kb)
	BCC	EsMegaROMS1

	MOVE.L	DirCartS1,A0			; Pone Cartucho de 16Kb
	ADD.W	#$0080,A0
	MOVE.L	A0,MapROMBase1(A3)

;-;	LEA	SLOT1,A1		; Para P�gina 0
;-;	LEA	SubSLOT1,A2		; Para P�gina 0
;-;	BFTST	(A0){24:2}		; Para P�gina 0
;-;	BEQ.S	PonCarConS1		; Para P�gina 0

	LEA	SLOT1+8,A1
	LEA	SubSLOT1+8,A2
	SUB.W	#$4000,A0
	TST.B	$4003(A0)			; �En p�gina 1 o 2?
	BPL.S	PonCarConS1
	LEA	SLOT1+16,A1
	LEA	SubSLOT1+16,A2
	SUB.W	#$4000,A0
PonCarConS1:
	MOVE.L	A0,(A1)
	ADD.W	#$0080,A0
	MOVE.L	A0,(A2)

	BRA.S	NoSlot1Cart

EsMegaROMS1:
	MOVE.L	DirCartS1,A0			; Pone Cartucho de 32Kb o m�s.
	ADD.W	#$0080,A0
	MOVE.L	A0,MapROMBase1(A3)
	SUB.W	#$4000,A0
	MOVE.L	A0,SLOT1+8
	ADD.W	#$80,A0
	MOVE.L	A0,SubSLOT1+8
	ADD.W	#$80,A0
	MOVE.L	A0,SLOT1+16
	ADD.W	#$80,A0
	MOVE.L	A0,SubSLOT1+16

NoSlot1Cart:
; ===

	CMP.B	#2,DIRPREFS+$65			; �Disk ROM?
	BNE	NoSlot2Cart


	CMP.L	#Bucle,DirConti+2		; �Power ON?
	BEQ.S	Slt2EsPowerOn

	TST.B	Slot2Cart			; �Insertado un cartucho?
	BNE.S	Slt2EsPowerOn

	MOVE.L	CheckIdS2Old,D0			; �El mismo Cartucho?
	CMP.L	CheckIdS2,D0
	BEQ	NoSlot2Cart
	MOVE.L	CheckIdS2,CheckIdS2Old

Slt2EsPowerOn:
	SF	Slot2Cart

	MOVE.L	#NOMEM-$4000,SLOT2+8
	MOVE.L	#NOMEM-$8000,SLOT2+16
	MOVE.L	#NOMEM-$4000,SubSLOT2+8
	MOVE.L	#NOMEM-$8000,SubSLOT2+16
	MOVE.L	#NOMEM-$C000,SLOT2+24		; Page 3: linear carts.
	MOVE.L	#NOMEM-$C000,SubSLOT2+24

	TST.L	BucCartS2			; �Hay Cartucho en Slot 2?
	BEQ	NoSlot2Cart

	MOVE.L	DirCartS2,A0			; Linear 48/64Kb cart from &H0000,
	MiraLin	A0,BucCartS2,D0		; pages 1-3 only: page 0 of Slot 2
	BEQ.S	NoLinealS2			; is the MSX2 SUB-ROM. (See Slot 1)
	ADD.W	#$0080,A0
	MOVE.L	A0,MapROMBase2(A3)
	ADD.W	#$100,A0
	MOVE.L	A0,SLOT2+8
	ADD.W	#$80,A0
	MOVE.L	A0,SubSLOT2+8
	ADD.W	#$80,A0
	MOVE.L	A0,SLOT2+16
	ADD.W	#$80,A0
	MOVE.L	A0,SubSLOT2+16
	CMP.W	#4,D0				; 64Kb: page 3 too.
	BNE	NoSlot2Cart
	ADD.W	#$80,A0
	MOVE.L	A0,SLOT2+24
	ADD.W	#$80,A0
	MOVE.L	A0,SubSLOT2+24
	BRA	NoSlot2Cart
NoLinealS2:

	CMP.L	#($2080*3+$80),BucCartS2	; �Es de 16Kb? (menor de 24Kb)
	BCC	EsMegaROMS2

	MOVE.L	DirCartS2,A0			; Pone Cartucho de 16Kb
	ADD.W	#$0080,A0
	MOVE.L	A0,MapROMBase2(A3)

	LEA	SLOT2+8,A1
	LEA	SubSLOT2+8,A2
	SUB.W	#$4000,A0
	TST.B	$4003(A0)			; �En p�gina 1 o 2?
	BPL.S	PonCarConS2
	LEA	SLOT2+16,A1
	LEA	SubSLOT2+16,A2
	SUB.W	#$4000,A0
PonCarConS2:
	MOVE.L	A0,(A1)
	ADD.W	#$0080,A0
	MOVE.L	A0,(A2)

	BRA.S	NoSlot2Cart

EsMegaROMS2:
	MOVE.L	DirCartS2,A0
	ADD.W	#$0080,A0
	MOVE.L	A0,MapROMBase2(A3)
	SUB.W	#$4000,A0
	MOVE.L	A0,SLOT2+8
	ADD.W	#$80,A0
	MOVE.L	A0,SubSLOT2+8
	ADD.W	#$80,A0
	MOVE.L	A0,SLOT2+16
	ADD.W	#$80,A0
	MOVE.L	A0,SubSLOT2+16

NoSlot2Cart:

; ---------------------------------------<=

; ---------------------------------------=> Pone Mappers de Slot 1 y 2.

	MOVEQ	#0,D0
	MOVE.B	DirPrefs+$76,D0		; Tipo de Mapper Para Slot 1
	LSL.W	#5,D0
	LEA	(Mapper0,D0.W),A0

	CMP.L	#($2080*5),BucCartS1	; �Es mayor de 40Kb?
	BCS.S	StdMappS1
	MOVE.L	A0,A1
	MOVE.L	DirCartS1,A0
	MiraLin	A0,BucCartS1,D0
	MOVE.L	A1,A0
	BEQ.S	NoStdMappS1
StdMappS1:
	LEA	Mapper0,A0
NoStdMappS1:

	MOVE.W	PagCartS1,D0		; Pone N� de P�ginas en Slot 1

	IFEQ	Key_ON
	MOVE.L	([KeyBase.W,PC],$14.w),A1
	JSR	(A1)				; Salto a Key
	ELSEIF

	MOVE.W	D0,NumROM2		; 16Kb banks (see BankNum)
	MOVE.W	D0,D1
	ADD.W	D1,D1
	MOVE.W	D1,NumROM		; 8Kb banks
	MOVE.W	D0,D1
	SUBQ.W	#$1,D1
	MOVE.W	D1,MaskROM2(A3)
	LSL.W	#1,D0
	SUBQ.W	#$1,D0
	CMP.W	#$FF,D0			; 8Kb banks reach 2Mb at most, and the
	BLS.S	MaskOkS1			; bank byte is read with MOVE.B.
	MOVE.W	#$FF,D0
MaskOkS1:
	MOVE.W	D0,MaskROM(A3)


	LEA	$660(A3),A1		; Mapper en Slot 1
	REPT	8
	MOVE.L	(A0)+,(A1)+
	ENDR

	ENDC
; -=-=-

	MOVEQ	#0,D0
	MOVE.B	DirPrefs+$77,D0		; Tipo de Mapper Para Slot 2
	LSL.W	#5,D0
	LEA	(Mapper0b,D0.W),A0

	CMP.B	#2,DIRPREFS+$65		; �Disk ROM = None?
	BEQ.S	PonMapper

	LEA	Mapper0b,A0
PonMapper:
	CMP.L	#($2080*5),BucCartS2	; �Es mayor de 40Kb?
	BCS.S	StdMappS2
	MOVE.L	A0,A1
	MOVE.L	DirCartS2,A0
	MiraLin	A0,BucCartS2,D0
	MOVE.L	A1,A0
	BEQ.S	NoStdMappS2
StdMappS2:
	LEA	Mapper0b,A0
NoStdMappS2:

	MOVE.W	PagCartS2,D0		; Pone N� de P�ginas en Slot 2

	IFEQ	Key_ON
	MOVE.L	([KeyBase.W,PC],$18.w),A1
	JSR	(A1)				; Salto a Key
	ELSEIF

	MOVE.W	D0,NumROM4		; 16Kb banks (see BankNum)
	MOVE.W	D0,D1
	ADD.W	D1,D1
	MOVE.W	D1,NumROM3		; 8Kb banks
	MOVE.W	D0,D1
	SUBQ.W	#$1,D1
	MOVE.W	D1,MaskROM4(A3)
	LSL.W	#1,D0
	SUBQ.W	#$1,D0
	CMP.W	#$FF,D0			; 8Kb banks reach 2Mb at most, and the
	BLS.S	MaskOkS2			; bank byte is read with MOVE.B.
	MOVE.W	#$FF,D0
MaskOkS2:
	MOVE.W	D0,MaskROM3(A3)


	LEA	$680(A3),A1		; Mapper en Slot 2
	REPT	8
	MOVE.L	(A0)+,(A1)+
	ENDR

	ENDC
; ---------------------------------------<=

; ---------------------------------------=> Refresca 'Restas' para Mapeaci�n.
	IFEQ	Key_ON
	MOVE.L	KeyBase(PC),A0
	JSR	([A0,$1C.w])			; Salto a Key
	ELSEIF

	LEA	SLOTS(A3),A0
	LEA	SLOTSR(A3),A1
	MOVE.W	#(4*4)-1,D0
BUCSL:
	MOVE.W	2(A0),(A1)+
	ADDQ	#8,A0
	DBF	D0,BUCSL


	LEA	SUBSLOTS(A3),A0
	LEA	SUBSLOTSR(A3),A1
	MOVE.W	#(4*4)-1,D0
BUCSLS:
	MOVE.W	2(A0),(A1)+
	ADDQ	#8,A0
	DBF	D0,BUCSLS

	ENDC
; ---------------------------------------<=


; ---------------------------------------=> Power ON  Zilog Z-80A Processor.
Z80A:
	LEA	DEBUG,A0
	MOVEM.L	(A0),D0-D7/A0-A7
	LEA	REGS,A3 	;  Tabla de datos y Punteros instrucciones Z-80A. 

	CMP.L	#BUCLE,DIRCONTI+2
	BNE	CONTINUAR2

	LEA	RESTA0(A3),A7
	LEA	DIRVRAM,A2	;  VPC=0000 (VRAM)
	MOVE.L	SLOT0,A5	;  PC=0000 (Slot 0)
	LEA	NORAM,A6	;  SP=0000
	MOVEQ	#0,D0		;  SP Pila
	MOVEQ	#0,D1		;  (Usar solo en .w)
	MOVEQ	#0,D2		;  (Usar solo en .b)
	MOVE.L	#$0100,D2	;  (Truco para DEC/DJNZ)
	MOVEQ	#0,D3		;  F=00   (Flags/CCR)
	MOVEQ	#0,D4		;  HL=0000
	MOVEQ	#0,D5		;  BC=0000
	MOVEQ	#0,D6		;  DE=0000
	MOVEQ	#0,D7		;  A=00   (Acumulador)
	SUB.L	A0,A0		;  IX=0000
	SUB.L	A1,A1		;  IY=0000
	SUB.L	A4,A4		;  (Uso libre)
CONTINUAR2:
; ----------------------------------

; ----------------------------------
	MOVE.W	#$7FFF,$DFF09C
	NOP
EsperaInt0:
	BTST	#$05,$DFF01F
	BEQ.S	EsperaInt0
	NOP
	MOVE.W	#$7FFF,$DFF09C
	NOP
EsperaInt1:
	BTST	#$05,$DFF01F
	BEQ.S	EsperaInt1
	NOP
	MOVE.W	#$7FFF,$DFF09C
	NOP
EsperaInt2:
	BTST	#$05,$DFF01F
	BEQ.S	EsperaInt2
	NOP
	NOP
	MOVE.W	#$7FFF,$DFF09C
	NOP
	NOP
; ----------------------------------
	NOP
;	NOP
;	MOVE.W	#$0FFF,$DFF098		; Colisi�n de sprites.
;	NOP
;	MOVE.W	#$0000,$DFF10C
;	NOP
	NOP
; ----------------------------------
	MOVEM.L	D1/D2,ClrKeyBuf

	MOVE.W	#4,D1
	OR.B	#$40,$BFEE01		; CIAA Libre
TRETARDO0:
	MOVE.B	$DFF006,D2
TRETARDOB0:
	CMP.B	$DFF006,D2
	BEQ.S	TRETARDOB0
	DBF	D1,TRETARDO0
	AND.B	#$BF,$BFEE01		; CIAA Libre

	MOVEM.L	ClrKeyBuf(PC),D1/D2

	NOP
	NOP
	SF	$BFEC01
	NOP
	NOP
; ----------------------------------

	MOVE.W	#$C030,$DFF09A

	MOVE.B	(A5)+,D2
	JMP	MiraInter

; ----------------------------------
	CNOP	0,8
ClrKeyBuf:
	DS.L	3
; ----------------------------------


	CNOP	0,8
	DC.B	"RAFY"
BUCLE:
	MOVE.B	(A5)+,D2
	JMP	([A3,D2.W*8])

	CNOP	0,8
	DC.B	"RAFY"
NOCO:
	MOVE.B	-1(A5),D2
	JMP	([A3,D2.W*8])

	CNOP	0,8
	DC.B	"RAFY"
NADA:
;	JMP	SALIR
;	MOVE.W	#$0F0,$DFF180
	MOVE.B	(A5)+,D2
	JMP	([A3,D2.W*8])

; -----------------------------------------

; -----------------------------------------
	CNOP	0,8
DATOSINIT:
	MOVE.L	A6,-(SP)
	LEA	$DFF000,A6

	BSET	#1,$BFE001		; Datos Musica.

	TST.B	SFXCHIP
	BNE.S	ESSCC1

	MOVE.L	#ONDA,$A0(A6)
	MOVE.L	#ONDA,$B0(A6)
	MOVE.L	#ONDA,$C0(A6)
	MOVE.L	#ONDA,$D0(A6)

	MOVE.W	#1,$A4(A6)
	MOVE.W	#1,$B4(A6)
	MOVE.W	#1,$C4(A6)
	MOVE.W	#1,$D4(A6)

	MOVE.W	#1,$D6(A6)

	MOVE.W	#0,$A8(A6)
	MOVE.W	#0,$B8(A6)
	MOVE.W	#0,$C8(A6)
	MOVE.W	#0,$D8(A6)

	MOVE.W	#$800F,$DFF096

	MOVE.L	(SP)+,A6
	RTS
; ------------------------------
	CNOP	0,8
ESSCC1:
	MOVE.L	#SCCKO+$1800,$A0(A6)	; Datos SCC.
	MOVE.L	#SCCKO+$1820,$B0(A6)
	MOVE.L	#SCCKO+$1840,$C0(A6)
	MOVE.L	#SCCKO+$1860,$D0(A6)

	MOVE.W	#16,$A4(A6)
	MOVE.W	#16,$B4(A6)
	MOVE.W	#16,$C4(A6)
	MOVE.W	#16,$D4(A6)

	MOVE.W	#1,$A6(A6)
	MOVE.W	#1,$B6(A6)
	MOVE.W	#1,$C6(A6)
	MOVE.W	#1,$D6(A6)

	MOVE.W	#0,$A8(A6)
	MOVE.W	#0,$B8(A6)
	MOVE.W	#0,$C8(A6)
	MOVE.W	#0,$D8(A6)

	MOVE.W	#$800F,$DFF096

	MOVE.L	(SP)+,A6
	RTS
; ------------------------------



; ------------------------------------------------ ;


;	/------------------------------------------------------\
;	|  Z-80A & R-800  Macros v4.0  Por Juan Antonio G�mez  |
;	\------------------------------------------------------/

;	D0 = Pila y Gfx.		A0 = IX.
;	D1 = Uso libre en .w		A1 = IY.
;	D2 = $01xx.w (Usar en .b)	A2 = VPC (VRAM)
;	D3 = CCF de Amiga. (F y F')	A3 = Datos y Punteros.
;	D4 = HL	(.w)			A4 = Uso libre.
;	D5 = BC	(.w)			A5 = PC (Actual)
;	D6 = DE	(.w)			A6 = SP (Actual)
;	D7 = A y A' (Swap) (.b)		A7 = Punteros paginaci�n.

;	ANA:  en (A3)
	
NOINT:	MACRO
;	MOVE.W	#$0030,$DFF09A
	ENDM

SIINT:	MACRO
;	TST.B	ModoTraza(A3)
;	BNE.S	\@
;	MOVE.W	#$8030,$DFF09A
;\@:
	ENDM


NOINT2:	MACRO
;	MOVE.W	#$0034,$DFF09A
	ENDM

SIINT2:	MACRO
;	TST.B	ModoTraza(A3)
;	BNE.S	\@
;	MOVE.W	#$8034,$DFF09A
;\@:
	ENDM


CogePag:MACRO
	MOVE.L	\1,\2
	IFC	"D1","\1"
	LSR.W	#8,D1
	LSR.B	#5,D1
	ELSEIF
	BFEXTU	\1{16:3},D1
	ENDC
	ADD.L	PagRead(A3,D1.W*4),\2
	ENDM

CogePag2:MACRO
	IFC	"D1","\1"
	LSR.W	#8,D1
	LSR.B	#5,D1
	ELSEIF
	BFEXTU	\1{16:3},D1
	ENDC
	ADD.L	PagRead(A3,D1.W*4),\2
	ENDM

CogePagI:MACRO
	ADD.W	\1,D1
	MOVE.L	D1,\2
	LSR.W	#8,D1
	LSR.B	#5,D1
	ADD.L	PagRead(A3,D1.W*4),\2
	ENDM

CogePagE:MACRO
	MOVE.L	\1,\2
	IFC	"D1","\1"
	LSR.W	#8,D1
	LSR.B	#5,D1
	ELSEIF
	BFEXTU	\1{16:3},D1
	ENDC
	ADD.L	PagWrite(A3,D1.W*4),\2
	ENDM

; Stack pointer (A6) for Z80 address \1 (like CogePagE): the page's write
; pointer, except for ROM, where it is the read pointer so POP/RET can read
; tables in ROM ("LD SP,table / RET" dispatch: Godzilla Balls reset there, as
; the write side of ROM is the NORAM dummy). Unmapped pages keep the write
; pointer so a push can never corrupt NOMEM. Trashes D1/A4, no stack.
CogePagS:	MACRO
	MOVE.L	\1,\2
	IFC	"D1","\1"
	LSR.W	#8,D1
	LSR.B	#5,D1
	ELSEIF
	BFEXTU	\1{16:3},D1
	ENDC
	MOVE.L	PagRead(A3,D1.W*4),A4
	CMP.L	PagWrite(A3,D1.W*4),A4
	BEQ.S	\@W			; RAM: read = write.
	AND.L	#6,D1
	LSL.L	#8,D1
	LSL.L	#5,D1			; Base of the 16Kb page.
	ADD.L	D1,A4
	CMP.L	#NOMEM,A4
	BEQ.S	\@U			; Unmapped.
	SUB.L	D1,A4
	ADD.L	A4,\2			; ROM: read pointer.
	BRA.S	\@F
\@U:	MOVE.W	\2,D1
	LSR.W	#8,D1
	LSR.B	#5,D1
\@W:	ADD.L	PagWrite(A3,D1.W*4),\2
\@F:
	ENDM

CogePagE2:MACRO
	IFC	"D1","\1"
	LSR.W	#8,D1
	LSR.B	#5,D1
	ELSEIF
	BFEXTU	\1{16:3},D1
	ENDC
	ADD.L	PagWrite(A3,D1.W*4),\2
	ENDM

CogePagIE:MACRO
	ADD.W	\1,D1
	MOVE.L	D1,\2
	LSR.W	#8,D1
	LSR.B	#5,D1
	ADD.L	PagWrite(A3,D1.W*4),\2
	ENDM


PARDAAS:MACRO
	MOVE.B	D7,DatDAA(A3)
	ENDM

PARDAAR:MACRO
	MOVE.B	D7,DatDAA(A3)
	ENDM

IInsBuc:MACRO
;	ST	DInsBuc(A3)
;	TST.B	ModoTraza(A3)
;	BEQ.S	\@
;	TRAP	#1
;\@:
	ENDM

FInsBuc:MACRO
;	SF	DInsBuc(A3)
;	TST.B	ModoTraza(A3)
;	BEQ.S	\@
;	TRAP	#2
;\@:
	ENDM

Otra:	MACRO				; (T-states + the M1 wait, see HPeriod)
	MOVE.B	(A5)+,D2
	IFNE	(\1+1)>(8)
	SUB.W	#(\1+1),(A3)			; * Resta Cycles *
	ELSEIF
	SUBQ.W	#(\1+1),(A3)			; * Resta Cycles *
	ENDC
	BMI.S	\@Buc
	JMP	([A3,D2.W*8])
\@Buc:	JMP	(MiraInter-Regs.W,A3)
	CNOP	0,4
	ENDM

Otra2:	MACRO
	MOVE.B	(A5)+,D2
	JMP	([A3,D2.W*8])
	CNOP	0,4
	ENDM

OtraEI:	MACRO
	MOVE.B	(A5)+,D2
	SUBQ.W	#(\1+1),(A3)			; * Resta Cycles *
	JMP	([A3,D2.W*8])
	CNOP	0,4
	ENDM


OtraT:	MACRO
	MOVE.W	CCR,D3
	Otra	\1
	ENDM

OtraC:	MACRO
	ROXL.B	#1,D3
	Otra	\1
	ENDM

OtraC2:	MACRO
	BCC.S	\@
	OR.B	#$01,D3
	Otra	\1
\@:
	AND.B	#$FE,D3
	Otra	\1
	ENDM

OtraP:	MACRO
	MOVE.B	Flags_PAR(A3,D7.W*4),D3
	Otra	\1
	ENDM

OtraV:	MACRO
	BNE.S	\@
	AND.B	#$FD,D3
	Otra	\1
\@:
	OR.B	#$02,D3
	Otra	\1
	ENDM

OtraZ:	MACRO
	BEQ.S	\@
	AND.B	#$FB,D3
	Otra	\1
\@:
	OR.B	#$04,D3
	Otra	\1
	ENDM

PONF:	MACRO
	IFC	"S","\1"
	MOVE.B	D3,D1
	ELSEIF
	IFC	"X","\2"
	LSR.B	#1,D3
	OR.B	#$04,CCR
	ELSEIF
	IFC	"C","\1"
	LSR.B	#1,D3
	ENDC
	ENDC
	ENDC
	ENDM

PONS:	MACRO
	MOVE.W	CCR,D3
	BFINS	D1,D3{31:1}
	ENDM

OtraS:	MACRO
	PONS
	Otra	\1
	ENDM

SUBBZ:	MACRO
	MOVE.B	D5,D2
	SUB.W	D2,D5
	BEQ.S	\@
	AND.B	#$FB,D3
	BRA.S	\@2
	CNOP	0,4
\@:	OR.B	#$04,D3
\@2:
	MOVE.B	D2,D5
	ENDM

PonCCR:	MACRO
	IFC	"N","\1"
	Otra	\2		; NO guarda flags.
	ENDC
	IFC	"T","\1"
	OtraT	\2		; Guarda todos los flags.
	ENDC
	IFC	"S","\1"
	OtraS	\2		; Guarda flags SZV.
	ENDC
	IFC	"C","\1"
	OtraC	\2		; Guarda flag C.
	ENDC
	IFC	"Z","\1"
	OtraZ	\2		; Guarda flag Z.
	ENDC
	IFC	"P","\1"
	OtraP	\2		; Guarda flag P y dem�s.
	ENDC
	ENDM


CheckB:	MACRO
	CMP.L	Desbor+4(A7),A5
	BLE.S	\@NO
	SUBQ.W	#1,A5
	MOVE.W	A5,D1
	SUB.W	(A7),D1
	CogePag	D1,A5
	LEA	Restas(A3,D1.W*8),A7
	MOVE.B	(A5)+,\1
\@NO:
	ENDM


CheckW:	MACRO
	CMP.L	Desbor+4(A7),A5
	BLE.S	\@NO
	ROR.W	#8,\1
	MOVE.B	\1,D2
	SUBQ.W	#1,A5
	MOVE.W	A5,D1
	SUB.W	(A7),D1
	TST.B	D1
	BEQ.S	\@M2
	SUBQ.W	#1,D1
	CogePag	D1,A5
	LEA	Restas(A3,D1.W*8),A7
	MOVE.W	(A5)+,\1
	BRA.S	\@NO
	CNOP	0,4
\@M2:
	CogePag	D1,A5
	LEA	Restas(A3,D1.W*8),A7
	MOVE.B	D2,\1
	LSL.W	#8,\1
	MOVE.B	(A5)+,\1
\@NO:
	ENDM



; ---------------------------------------------------------------------
; *********************************************************************
; ---------------------------------------------------------------------

;;		  \1    \2      \3    \4   \5     \6
;;	MIns	Instr,Destino,Origen,Modo,Flags,Ini.Flags

MIns:	MACRO

	IFC	"0","\4"		; Todo con registro bajos.
	PONF	\5,\6
	\1	\3,\2
	PonCCR	\5,\7			; Recoge Flags.
	ENDC

	IFC	"0B","\4"		; Todo con registro bajos.
	PONF	\5,\6
	\1	\3,\2
	PonCCR	\5,\7			; Recoge Flags.
	ENDC

	IFC	"1","\4"		; Registro alto con registro bajo.
	MOVE.W	\3,D1
	LSR.W	#8,D1
	PONF	\5,\6
	\1	D1,\2
	PonCCR	\5,\7			; Recoge Flags.
	ENDC

	IFC	"2","\4"		; Todo con registros (HL,DE,BC)
	PONF	\5,\6
	\1	\3,\2
	PonCCR	\5,\7			; Recoge Flags.
	ENDC

	IFC	"2I","\4"		; Todo con registros (IX,IY) 
	MOVE.W	\2,D1
	PONF	\5,\6			; * No modificar D1 *
	\1	\3,D1
	MOVE.L	D1,\2
	PonCCR	\5,\7			; Recoge Flags.
	ENDC

	IFC	"3","\4"		; Registro (HL) con registro A.
	CogePag	\3,A4
	\1	(A4),\2
	PonCCR	\5,\7			; Recoge Flags.
	ENDC

	IFC	"4","\4"		; Registros (IX,IY) con registro A.
	MOVE.B	(A5)+,D1
	BEQ.S	\@M
	EXT.W	D1
	CogePagI \3,A4
	\1	(A4),\2
	PonCCR	\5,\7			; Recoge Flags.
\@M:	CheckB	D1
	EXT.W	D1
	CogePagI \3,A4
	\1	(A4),\2
	PonCCR	\5,\7			; Recoge Flags.
	ENDC

	IFC	"7","\4"		; Ins. DEC. registros Altos.
	MOVE.B	D3,D1
	MOVE.B	\2,D2
	\1	D2,\2
	MOVE.W	CCR,D3
	BFINS	D1,D3{31:1}
	MOVE.B	D2,\2
	Otra	\7
 	ENDC

	IFC	"7B","\4"		; Ins. INC registros Altos.
	MOVE.B	D3,D1
	\1	#$100,\2
	MOVE.W	CCR,D3
	BFINS	D3,D3{29:1}
	BFINS	D1,D3{31:1}
	Otra	\7
 	ENDC

	IFC	"8","\4"		; Para Ins. destino (HL)
	CogePagE \2,A4
	PONF	\5,\6
	\1	\3,(A4)
	PonCCR	\5,\7			; Recoge Flags.
	ENDC

	IFC	"8I","\4"		; Para Ins. destino (HL)
	CogePagE \2,A4
	PONF	\5,\6
	\1	\3,(A4)
	PonCCR	\5,\7			; Recoge Flags.
	ENDC

	IFC	"8Y","\4"		; Para Ins. destino (HL) Leer
	CogePag \2,A4
	PONF	\5,\6
	\1	\3,(A4)
	PonCCR	\5,\7			; Recoge Flags.
	ENDC

	IFC	"9","\4"		; Para Ins. destino (IX,IY)
	MOVE.B	(A5)+,D1
	BEQ.S	\@M
	EXT.W	D1
	CogePagIE \2,A4
	PONF	\5,\6
	\1	\3,(A4)
	PonCCR	\5,\7			; Recoge Flags.
\@M:	CheckB	D1
	EXT.W	D1
	CogePagIE \2,A4
	PONF	\5,\6
	\1	\3,(A4)
	PonCCR	\5,\7			; Recoge Flags.
	ENDC

	IFC	"9I","\4"		; Para Ins.de bits con destino (IX,IY)
	CogePagIE \2,A4
	PONF	\5,\6
	\1	\3,(A4)
	PonCCR	\5,\7			; Recoge Flags.
	ENDC

	IFC	"9Y","\4"		; Para Ins.de bits con destino (IX,IY) Leer
	CogePagI \2,A4
	PONF	\5,\6
	\1	\3,(A4)
	PonCCR	\5,\7			; Recoge Flags.
	ENDC

	IFC	"10","\4"		; Operaci�n de (N) en registro A.
	MOVE.B	(A5)+,D2
	BEQ.S	\@M
	PONF	\5,\6
	\1	D2,\2
	PonCCR	\5,\7			; Recoge Flags.
\@M:	CheckB	D2
	PONF	\5,\6
	\1	D2,\2
	PonCCR	\5,\7			; Recoge Flags.
	ENDC

	IFC	"11","\4"		; (Modo no soportado de "3")
	CogePag	\3,A4			; Registro (HL) con registro A.
	MOVE.B	(A4),D2
	PONF	\5,\6
	\1	D2,\2
	PonCCR	\5,\7			; Recoge Flags.
	ENDC

	IFC	"12","\4"		; (Modo no soportado de "4")
	MOVE.B	(A5)+,D1
	BEQ.S	\@M
	EXT.W	D1
	CogePagI \3,A4
	MOVE.B	(A4),D2
	PONF	\5,\6
	\1	D2,\2
	PonCCR	\5,\7			; Recoge Flags.
\@M:	CheckB	D1
	EXT.W	D1
	CogePagI \3,A4
	MOVE.B	(A4),D2
	PONF	\5,\6
	\1	D2,\2
	PonCCR	\5,\7			; Recoge Flags.
	ENDC

	ENDM


; ---------------------------------------------------------------------
; *********************************************************************
; ---------------------------------------------------------------------


MROT:	MACRO
	IFC	"2","\4"		; Rotaci�n con (HL)
	CogePagE \2,A4
	MOVE.B	(A4),D2
	IFC	"S","\3"
	OR.B	#$10,CCR
	ENDC
	IFC	"X","\3"
	LSR.B	#1,D3
	ENDC
	\1	#1,D2
	MOVE.W	CCR,D3
	MOVE.B	D2,(A4)
	ENDC

	IFC	"2I","\4"		; Rotaci�n con (IX,IY)
	CogePagIE \2,A4
	MOVE.B	(A4),D2
	IFC	"S","\3"
	OR.B	#$10,CCR
	ENDC
	IFC	"X","\3"
	LSR.B	#1,D3
	ENDC
	\1	#1,D2
	MOVE.W	CCR,D3
	MOVE.B	D2,(A4)
	ENDC

	IFC	"0","\4"		; Rotaci�n en registros bajos.
	IFC	"S","\3"
	OR.B	#$10,CCR
	ENDC
	IFC	"X","\3"
	LSR.B	#1,D3
	ENDC
	\1	#1,\2
	MOVE.W	CCR,D3
	ENDC

	IFC	"1","\4"		; Rotaci�n en registros altos.
	ROR.W	#8,\2
	IFC	"S","\3"
	OR.B	#$10,CCR
	ENDC
	IFC	"X","\3"
	LSR.B	#1,D3
	ENDC
	\1	#1,\2
	MOVE.W	CCR,D3
	ROR.W	#8,\2
	ENDC
; ---------------------------
	Otra	\5			; Recoge Flags.
; ---------------------------
	ENDM


; ---------------------------------------------------------------------
; *********************************************************************
; ---------------------------------------------------------------------


MLDRR:	MACRO

	IFC	"0","\3"	; Mover registros bajos.
	MOVE.B	\2,\1
	Otra	\4
	ENDC


	IFC	"0A","\3"	; Mover de (N) a registro bajo.
	CogePag	\2,A4
	MOVE.B	(A4),\1
	Otra	\4
	ENDC


	IFC	"0B","\3"	; Mover de (N) a registro alto.
	MOVE.B	\1,D2
	CogePag	\2,A4
	MOVE.W	(A4),\1
	MOVE.B	D2,\1
	Otra	\4
	ENDC


	IFC	"1","\3"	; Mover registros altos.
	MOVE.W	\2,D1
	MOVE.B	\1,D1
	MOVE.W	D1,\1
	Otra	\4
	ENDC


	IFC	"2","\3"	; Mover registro bajo a alto de reg. de 16bits.
	MOVE.B	\1,D1
	LSL.W	#8,\2
	MOVE.B	D1,\1
	Otra	\4
	ENDC


	IFC	"3","\3"	; Mover registro alto a bajo de reg. de 16bits.
	MOVE.W	\2,D1
	LSR.W	#8,D1
	MOVE.B	D1,\1
	Otra	\4
	ENDC


	IFC	"4","\3"	; Mover registro bajo a alto.
	BFINS	\2,\1{16:8}
	Otra	\4
	ENDC


	IFC	"5","\3"	; Mover registro alto a bajo.
	MOVE.W	\2,D1
	LSR.W	#8,D1
	MOVE.B	D1,\1
	Otra	\4
	ENDC


	IFC	"6","\3"	; Mover de (IX,IY) a registro bajo.
	MOVE.B	(A5)+,D1
	BEQ.S	\@M
	EXT.W	D1
	CogePagI \2,A4
	MOVE.B	(A4),\1
	Otra	\4
\@M:	CheckB	D1
	EXT.W	D1
	CogePagI \2,A4
	MOVE.B	(A4),\1
	Otra	\4
	ENDC


	IFC	"6B","\3"	; Mover de (IX,IY) a registro alto.
	MOVE.B	(A5)+,D1
	BEQ.S	\@M
	EXT.W	D1
	CogePagI \2,A4
	MOVE.B	\1,D2
	MOVE.W	(A4),\1
	MOVE.B	D2,\1
	Otra	\4
\@M:	CheckB	D1
	EXT.W	D1
	CogePagI \2,A4
	MOVE.B	\1,D2
	MOVE.W	(A4),\1
	MOVE.B	D2,\1
	Otra	\4
	ENDC


	IFC	"7","\3"	; Mover registro alto a registro A.
	MOVE.W	\2,\1
	LSR.W	#8,\1
	Otra	\4
	ENDC


	IFC	"8","\3"	; Mover de (NN) a registros HL,BC,DE.
	MOVE.W	(A5)+,D1
	TST.B	D1
	BEQ.S	\@M
	ROR.W	#8,D1
	MOVE.L	D1,A4
	ADDQ.B	#1,D1
	BEQ.S	\@D
	CogePag2 D1,A4
	MOVE.W	(A4),\1
	ROR.W	#8,\1
	Otra	\4
\@M:	CheckW	D1
	ROR.W	#8,D1
	MOVE.L	D1,A4
	ADDQ.B	#1,D1
	BEQ.S	\@D
	CogePag2 D1,A4
	MOVE.W	(A4),\1
	ROR.W	#8,\1
	Otra	\4
\@D:
	SWAP	D0
	MOVE.W	A4,D1
	MOVE.W	D1,D0
	ADDQ.W	#1,D1
	CogePag D1,A4
	MOVE.W	(A4),\1
	MOVE.W	D0,D1
	CogePag	D1,A4
	MOVE.B	(A4),\1
	SWAP	D0
	Otra	\4
	ENDC


	IFC	"8I","\3"	; Mover de (NN) a registros IX,IY.
	MOVE.W	(A5)+,D1
	TST.B	D1
	BEQ.S	\@M
	ROR.W	#8,D1
	MOVE.L	D1,A4
	ADDQ.B	#1,D1
	BEQ.S	\@D
	CogePag2 D1,A4
	MOVE.W	(A4),D1
	ROR.W	#8,D1
	MOVE.L	D1,\1
	Otra	\4
\@D:
	SWAP	D0
	MOVE.W	A4,D0
	MOVE.W	D0,D1
	ADDQ.W	#1,D1
	CogePag D1,A4
	MOVE.W	D0,D1
	MOVE.W	(A4),D0
	CogePag	D1,A4
	MOVE.W	D0,D1
	MOVE.B	(A4),D1
	MOVE.L	D1,\1
	SWAP	D0
	Otra	\4
\@M:	CheckW	D1
	ROR.W	#8,D1
	MOVE.L	D1,A4
	ADDQ.B	#1,D1
	BEQ.S	\@D
	CogePag2 D1,A4
	MOVE.W	(A4),D1
	ROR.W	#8,D1
	MOVE.L	D1,\1
	Otra	\4
	ENDC


	IFC	"8S","\3"	; Mover de (NN) a registro SP.
	MOVE.W	(A5)+,D1
	TST.B	D1
	BEQ	\@M
	ROR.W	#8,D1
	MOVE.L	D1,A4
	ADDQ.B	#1,D1
	BEQ.S	\@D
	CogePag2 D1,A4
	MOVE.W	(A4),D0
	ROR.W	#8,D0
	MOVE.W	D0,D1
	CogePagS D1,\1
	Otra	\4
\@D:
	MOVE.W	A4,D0
	MOVE.W	D0,D1
	ADDQ.W	#1,D1
	CogePag D1,A4
	MOVE.W	D0,D1
	MOVE.W	(A4),D0
	CogePag	D1,A4
	MOVE.B	(A4),D0
	MOVE.W	D0,D1
	CogePagS D1,\1
	Otra	\4
\@M:
	CheckW	D1
	ROR.W	#8,D1
	MOVE.L	D1,A4
	ADDQ.B	#1,D1
	BEQ	\@D
	CogePag2 D1,A4
	MOVE.W	(A4),D0
	ROR.W	#8,D0
	MOVE.W	D0,D1
	CogePagS D1,\1
	Otra	\4
	ENDC


	IFC	"9","\3"	; Mover de HL,BC,DE,IX,IY a (NN)
	MOVE.W	(A5)+,D1
	TST.B	D1
	BEQ.S	\@M
	ROR.W	#8,D1
	MOVE.L	D1,A4
	ADDQ.B	#1,D1
	BEQ.S	\@D
	CogePagE2 D1,A4
	MOVE.W	\1,D1
	ROR.W	#8,D1
	MOVE.W	D1,(A4)
	Otra	\4
\@D:
	IFNC	"D0","\1"
	SWAP	D0
	MOVE.W	A4,D0
	MOVE.W	D0,D1
	CogePagE2 D1,A4
	MOVE.W	D0,D1
	ADDQ.W	#1,D1
	MOVE.W	\1,D0
	MOVE.B	D0,(A4)
	CogePagE D1,A4
	LSR.W	#8,D0
	MOVE.B	D0,(A4)
	SWAP	D0
	Otra	\4
	ELSEIF
	SWAP	D0
	MOVE.W	A4,D1
	MOVE.W	D1,D0
	CogePagE2 D1,A4
	MOVE.W	D0,D1
	ADDQ.W	#1,D1
	SWAP	D0
	MOVE.B	D0,(A4)
	CogePagE D1,A4
	ROR.W	#8,D0
	MOVE.B	D0,(A4)
	ROR.W	#8,D0
	Otra	\4
	ENDC
\@M:	CheckW	D1
	ROR.W	#8,D1
	MOVE.L	D1,A4
	ADDQ.B	#1,D1
	BEQ.S	\@D
	CogePagE2 D1,A4
	MOVE.W	\1,D1
	ROR.W	#8,D1
	MOVE.W	D1,(A4)
	Otra	\4
	ENDC


	IFC	"10","\3"	; Mover registros bajos a (HL,DE,BC)
	CogePagE \1,A4
	MOVE.B	\2,(A4)
	Otra	\4
	ENDC


	IFC	"11","\3"	; Mover registros altos a (HL,DE,BC)
	CogePagE \1,A4
	MOVE.W	\2,D1
	LSR.W	#8,D1
	MOVE.B	D1,(A4)
	Otra	\4
	ENDC


	IFC	"10F","\3"	; Mover registros bajos a (HL,DE,BC) con (FFFF)
	CogePagE \1,A4
	MOVE.B	\2,(A4)
	ADDQ.W	#1,\1
	BEQ.S	\@LD10F
	SUBQ.W	#1,\1
	Otra	\4
\@LD10F:SUBQ.W	#1,\1
	JMP	FFFF
	CNOP	0,4
	ENDC


	IFC	"11F","\3"	; Mover registros bajos a (HL,DE,BC) con (FFFF)
	CogePagE \1,A4
	MOVE.W	\2,D1
	LSR.W	#8,D1
	MOVE.B	D1,(A4)
	ADDQ.W	#1,\1
	BEQ.S	\@LD11F
	SUBQ.W	#1,\1
	Otra	\4
\@LD11F:SUBQ.W	#1,\1
	JMP	FFFF
	CNOP	0,4
	ENDC


	IFC	"12","\3"	; Mover registros bajos a (IX.IY)
	MOVE.B	(A5)+,D1
	BEQ.S	\@M
	EXT.W	D1
	CogePagIE \1,A4
	MOVE.B	\2,(A4)
	Otra	\4
\@M:	CheckB	D1
	EXT.W	D1
	CogePagIE \1,A4
	MOVE.B	\2,(A4)
	Otra	\4
	ENDC


	IFC	"13","\3"	; Mover registros altos a (IX.IY)
	MOVE.B	(A5)+,D1
	BEQ.S	\@M
	EXT.W	D1
	CogePagIE \1,A4
	MOVE.W	\2,D1
	LSR.W	#8,D1
	MOVE.B	D1,(A4)
	Otra	\4
\@M:	CheckB	D1
	EXT.W	D1
	CogePagIE \1,A4
	MOVE.W	\2,D1
	LSR.W	#8,D1
	MOVE.B	D1,(A4)
	Otra	\4
	ENDC


	IFC	"12N","\3"	; Mover (N) a (IX.IY)
	MOVE.B	(A5)+,D1
	BEQ.S	\@M
	EXT.W	D1
	CogePagIE \1,A4
	MOVE.B	(A5)+,(A4)
	BEQ.S	\@M2
	Otra	\4
\@M:	CheckB	D1
	EXT.W	D1
	CogePagIE \1,A4
	MOVE.B	(A5)+,(A4)
	BEQ.S	\@M2
	Otra	\4
\@M2:	CheckB	(A4)
	Otra	\4
	ENDC


	IFC	"14","\3"		; LD.b \1,N  Altos
	MOVE.B	\1,D2
	MOVE.B	(A5)+,\1
	BEQ.S	\@M
	LSL.W	#8,\1
	MOVE.B	D2,\1
	Otra	\4
\@M:	CheckB	\1
	LSL.W	#8,\1
	MOVE.B	D2,\1
	Otra	\4
	ENDC


	IFC	"15","\3"		; LD.b \1,N  Bajos
	MOVE.B	(A5)+,\1
	BEQ.S	\@M
	Otra	\4
\@M:	CheckB	\1
	Otra	\4
	ENDC


	IFC	"16","\3"		; LD.w \1,NN
	MOVE.W	(A5)+,\1
	TST.B	\1
	BEQ.S	\@M
	ROR.W	#8,\1
	Otra	\4
\@M:	CheckW	\1
	ROR.W	#8,\1
	Otra	\4
	ENDC


	IFC	"17I","\3"		; LD.w \1,NN  Indexados
	MOVE.W	(A5)+,D1
	TST.B	D1
	BEQ.S	\@M
	ROR.W	#8,D1
	MOVE.L	D1,\1
	Otra	\4
\@M:	CheckW	D1
	ROR.W	#8,D1
	MOVE.L	D1,\1
	Otra	\4
	ENDC


	IFC	"17S","\3"		; LD.w \1,NN  SP
	MOVE.W	(A5)+,D0
	TST.B	D0
	BEQ.S	\@M
	ROR.W	#8,D0
	MOVE.W	D0,D1
	CogePagS D1,\1
	Otra	\4
\@M:	CheckW	D0
	ROR.W	#8,D0
	MOVE.W	D0,D1
	CogePag	D1,\1
	Otra	\4
	ENDC


	IFC	"10d","\3"	; Mover registros bajos a (HL,DE,BC)
	CogePagE \1,A4
	MOVE.B	\2,(A4)
	JMP	([PagRuts.W,PC,D1.W*4])
	ENDC


	IFC	"11d","\3"	; Mover registros altos a (HL,DE,BC)
	CogePagE \1,A4
	ROR.W	#8,\2
	MOVE.B	\2,(A4)
	ROR.W	#8,\2
	JMP	([PagRuts.W,PC,D1.W*4])
	ENDC


	IFC	"12d","\3"	; Mover registros bajos a (IX.IY)
	MOVE.B	(A5)+,D1
	BEQ.S	\@M
	EXT.W	D1
	CogePagIE \1,A4
	MOVE.B	\2,(A4)
	JMP	([PagRuts.W,PC,D1.W*4])
	CNOP	0,4
\@M:	CheckB	D1
	EXT.W	D1
	CogePagIE \1,A4
	MOVE.B	\2,(A4)
	JMP	([PagRuts.W,PC,D1.W*4])
	ENDC


	IFC	"13d","\3"	; Mover registros altos a (IX.IY)
	MOVE.B	(A5)+,D1
	BEQ.S	\@M
	EXT.W	D1
	CogePagIE \1,A4
	ROR.W	#8,\2
	MOVE.B	\2,(A4)
	ROR.W	#8,\2
	JMP	([PagRuts.W,PC,D1.W*4])
	CNOP	0,4
\@M:	CheckB	D1
	EXT.W	D1
	CogePagIE \1,A4
	ROR.W	#8,\2
	MOVE.B	\2,(A4)
	ROR.W	#8,\2
	JMP	([PagRuts.W,PC,D1.W*4])
	ENDC


	IFC	"12Nd","\3"	; Mover (N) a (IX.IY)
	MOVE.B	(A5)+,D1
	BEQ.S	\@M
	EXT.W	D1
	CogePagIE \1,A4
	MOVE.B	(A5)+,(A4)
	BEQ.S	\@M2
	JMP	([PagRuts.W,PC,D1.W*4])
	CNOP	0,4
\@M:	CheckB	D1
	EXT.W	D1
	CogePagIE \1,A4
	MOVE.B	(A5)+,(A4)
	BEQ.S	\@M2
	Otra2
\@M2:	MOVE.B	D1,D2
	CheckB	(A4)
	JMP	([PagRuts-$400.W,PC,D2.W*4])
	ENDC


	ENDM


; ---------------------------------------------------------------------
; *********************************************************************
; ---------------------------------------------------------------------


MJR:	MACRO
	MOVE.B	(A5)+,D1
	BEQ.S	\@M
	EXT.W	D1
	ADD.W	D1,A5
	Otra	\1
\@M:	CheckB	D1
	EXT.W	D1
	ADD.W	D1,A5
	Otra	\1
	ENDM

MJRC:	MACRO
	MOVE.W	D3,CCR
	B\1.S	\@
	ADDQ.W	#1,A5
	Otra	\3
\@:	MJR	\2
	ENDM

; ---------------------------------------------------------------------
; *********************************************************************
; ---------------------------------------------------------------------

MJP:	MACRO
	MOVE.W	(A5)+,D1
	TST.B	D1
	BEQ.S	\@M
	ROR.W	#8,D1
	CogePag	D1,A5
	LEA	Restas(A3,D1.W*8),A7
	Otra	\1
\@M:	CheckW	D1
	ROR.W	#8,D1
	CogePag	D1,A5
	LEA	Restas(A3,D1.W*8),A7
	Otra	\1
	ENDM

MJPC:	MACRO
	MOVE.W	D3,CCR
	B\1.S	\@
	ADDQ.W	#2,A5
	Otra	\2
\@:	MJP	\2
	ENDM

; ---------------------------------------------------------------------
; *********************************************************************
; ---------------------------------------------------------------------

MCALL:	MACRO
	MOVE.W	(A5)+,D1
	TST.B	D1
	BEQ.S	\@M
	ROR.W	#8,D1
	MOVE.L	A5,A4
	SUB.W	(A7),A4
	CogePag	D1,A5
	LEA	Restas(A3,D1.W*8),A7
	SUBQ.B	#2,D0
	BCS.S	\@D
	MOVE.W	A4,D1
	ROR.W	#8,D1
	MOVE.W	D1,-(A6)
	Otra	\1
\@D:
	SUB.W	#$100,D0		; Esta Parte esta dos veces.
	MOVE.W	D0,D1
	ADDQ.W	#1,D1
	CogePagE D1,A6
	MOVE.W	A4,D1
	MOVE.B	D1,D2
	LSR.W	#8,D1
	MOVE.B	D1,(A6)
	MOVE.W	D0,D1
	CogePagE D1,A6
	MOVE.B	D2,(A6)
	Otra	\1
\@M:
	CheckW	D1
	ROR.W	#8,D1
	MOVE.L	A5,A4
	SUB.W	(A7),A4
	CogePag	D1,A5
	LEA	Restas(A3,D1.W*8),A7
	SUBQ.B	#2,D0
	BCS.S	\@D2
	MOVE.W	A4,D1
	ROR.W	#8,D1
	MOVE.W	D1,-(A6)
	Otra	\1
\@D2:
	SUB.W	#$100,D0
	MOVE.W	D0,D1
	ADDQ.W	#1,D1
	CogePagE D1,A6
	MOVE.W	A4,D1
	MOVE.B	D1,D2
	LSR.W	#8,D1
	MOVE.B	D1,(A6)
	MOVE.W	D0,D1
	CogePagE D1,A6
	MOVE.B	D2,(A6)
	Otra	\1
	ENDM

MCALLC:	MACRO
	MOVE.W	D3,CCR
	B\1.S	\@
	ADDQ.W	#2,A5
	Otra	\3
\@:	MCALL	\2
	ENDM

; ---------------------------------------------------------------------
; *********************************************************************
; ---------------------------------------------------------------------

MRST:	MACRO
	MOVE.W	A5,D1
	SUB.W	(A7),D1
	LEA	Restas(A3),A7
	MOVE.L	PagRead(A3),A4
	LEA	\1(A4),A5
	SUBQ.B	#2,D0
	BCS.S	\@D
	ROR.W	#8,D1
	MOVE.W	D1,-(A6)
	Otra	\2
\@D:
	MOVE.W	D1,A4
	SUB.W	#$100,D0
	MOVE.W	D0,D1
	ADDQ.W	#1,D1
	CogePagE D1,A6
	MOVE.W	A4,D1
	MOVE.B	D1,D2
	LSR.W	#8,D1
	MOVE.B	D1,(A6)
	MOVE.W	D0,D1
	CogePagE D1,A6
	MOVE.B	D2,(A6)
	Otra	\2
	ENDM

; ---------------------------------------------------------------------
; *********************************************************************
; ---------------------------------------------------------------------

MPUSH:	MACRO
	IFC	"AF","\1"
	BFEXTU	D0{23:8},D1
	MOVE.B	DatDAA(A3),Flags_DAA(A3,D1.W*4)
	ENDC

	SUBQ.B	#2,D0
	BCS.S	\@D
	IFNC	"AF","\1"
	MOVE.W	\1,D1
	ROR.W	#8,D1
	MOVE.W	D1,-(A6)
	Otra	\2
\@D:
	SUB.W	#$100,D0
	MOVE.W	D0,D1
	ADDQ.W	#1,D1
	CogePagE D1,A6
	MOVE.W	\1,D1
	MOVE.B	D1,D2
	LSR.W	#8,D1
	MOVE.B	D1,(A6)
	MOVE.W	D0,D1
	CogePagE D1,A6
	MOVE.B	D2,(A6)
	Otra	\2

	ELSEIF
	MOVE.B	D7,-(A6)
	MOVE.B	Flags_Push(A3,D3.W*4),-(A6)
	Otra	\2
\@D:
	SUB.W	#$100,D0
	MOVE.W	D0,D1
	ADDQ.W	#1,D1
	CogePagE D1,A6
	MOVE.B	D7,(A6)
	MOVE.W	D0,D1
	CogePagE D1,A6
	MOVE.B	Flags_Push(A3,D3.W*4),(A6)
	Otra	\2
	ENDC
	ENDM


; POP/RET crossing a 256-byte boundary: read the next byte through the read
; pointer and rebuild A6 with CogePagS (ROM: read pointer). It used the write
; pointer, so a POP sequence through ROM (Barbarian's fighters: LD SP,source
; and POP into OUT (98h)) turned to NORAM/BIOS bytes after 256 bytes.
MPOP:	MACRO
	ADDQ.B	#2,D0
	BCS.S	\@D
	IFC	"0","\2"
	MOVE.W	(A6)+,\1
	ROR.W	#8,\1
	Otra	\3
\@D:	ADD.W	#$100,D0
	MOVE.W	D0,D1
	SUBQ.W	#1,D1
	CogePag	D1,A4
	MOVE.W	(A4),\1
	MOVE.B	(A6),\1
	MOVE.W	D0,D1
	CogePagS D1,A6
	Otra	\3

	ELSEIF
	IFNC	"AF","\1"
	MOVE.W	(A6)+,D1
	ROR.W	#8,D1
	MOVE.L	D1,\1
	Otra	\3
\@D:
	ADD.W	#$100,D0
	MOVE.W	D0,D1
	SUBQ.W	#1,D1
	CogePag	D1,A4
	MOVE.W	(A4),D1
	MOVE.B	(A6),D1
	MOVE.L	D1,\1
	MOVE.W	D0,D1
	CogePagS D1,A6
	Otra	\3

	ELSEIF
	MOVE.B	(A6)+,D3
	MOVE.B	(A6)+,D7
	MOVE.B	Flags_Pop(A3,D3.W*4),D3
	BFEXTU	D0{23:8},D1
	MOVE.B	Flags_DAA(A3,D1.W*4),DatDAA(A3)
	Otra	\3
\@D:	ADD.W	#$100,D0
	MOVE.W	D0,D1
	SUBQ.W	#1,D1
	MOVE.B	(A6),D3
	CogePagS D1,A6
	MOVE.B	(A6),D7
	MOVE.B	Flags_Pop(A3,D3.W*4),D3
	MOVE.W	D0,D1
	CogePagS D1,A6
	BFEXTU	D0{23:8},D1
	MOVE.B	Flags_DAA(A3,D1.W*4),DatDAA(A3)
	Otra	\3
	ENDC
	ENDC
	ENDM

; ---------------------------------------------------------------------
; *********************************************************************
; ---------------------------------------------------------------------

MRET:	MACRO
	ADDQ.B	#2,D0
	BCS.S	\@D
	MOVE.W	(A6)+,D1
\@2:	ROR.W	#8,D1
\@3:	CogePag	D1,A5
	LEA	Restas(A3,D1.W*8),A7
	Otra	\1
\@D:
	ADD.W	#$100,D0
	MOVE.W	D0,D1
	SUBQ.W	#1,D1
	CogePag	D1,A4
	MOVE.W	(A4),D1
	MOVE.B	(A6),D1
	MOVE.W	D1,A5			; (Not A4: CogePagS uses it.)
	MOVE.W	D0,D1
	CogePagS D1,A6
	MOVE.W	A5,D1
	BRA.S	\@3
	CNOP	0,4
	ENDM

MRETC:	MACRO
	MOVE.W	D3,CCR
	B\1.S	\@
	Otra	\3
\@:	MRET	\2
	ENDM

; ---------------------------------------------------------------------
; *********************************************************************
; ---------------------------------------------------------------------

MINC:	MACRO
	MOVE.B	D5,D2
	JSR	([Ins-$400.W,PC,D2.W*4])	; Salta a puntero de emulaci�n.
	MOVE.B	D3,D2
	IFC	"1","\2"
	LSL.W	#8,D1
	MOVE.W	CCR,D3
	MOVE.B	\1,D1
	MOVE.W	D1,\1
	ELSEIF
	MOVE.B	D1,\1
	MOVE.W	CCR,D3
	ENDC
	BFINS	D2,D3{31:1}
	Otra	\3
	ENDM


MOUTC:	MACRO
	MOVE.B	D5,D2
	IFC	"1","\2"
	MOVE.W	\1,D1
	ASR.W	#8,D1
	ELSEIF
	MOVE.B	\1,D1
	ENDC
	JSR	([OUTS-$400.W,PC,D2.W*4])	; Salta a puntero de emulaci�n.
	Otra	\3
	CNOP	0,4
	ENDM


; ---------------------------------------------------------------------
; *********************************************************************
; ---------------------------------------------------------------------

; -----------------------  ADD / SUB  ---------------
ADCAA:	PARDAAS
	MIns	ADDX.B,D7,D7,0,T,X,4
ADDAA:	PARDAAS
	MIns	ADD.B,D7,D7,0,T,N,4
ADCAB:	PARDAAS
	MIns	ADDX.B,D7,D5,1,T,X,4
ADDAB:	PARDAAS
	MIns	ADD.B,D7,D5,1,T,N,4
ADCAC:	PARDAAS
	MIns	ADDX.B,D7,D5,0,T,X,4
ADDAC:	PARDAAS
	MIns	ADD.B,D7,D5,0,T,N,4
ADCAD:	PARDAAS
	MIns	ADDX.B,D7,D6,1,T,X,4
ADDAD:	PARDAAS
	MIns	ADD.B,D7,D6,1,T,N,4
ADCAE:	PARDAAS
	MIns	ADDX.B,D7,D6,0,T,X,4
ADDAE:	PARDAAS
	MIns	ADD.B,D7,D6,0,T,N,4
ADCAH:	PARDAAS
	MIns	ADDX.B,D7,D4,1,T,X,4
ADDAH:	PARDAAS
	MIns	ADD.B,D7,D4,1,T,N,4
ADCAL:	PARDAAS
	MIns	ADDX.B,D7,D4,0,T,X,4
ADDAL:	PARDAAS
	MIns	ADD.B,D7,D4,0,T,N,4
ADCAN:	PARDAAS
	MIns	ADDX.B,D7,N,10,T,X,7
ADDAN:	PARDAAS
	MIns	ADD.B,D7,N,10,T,N,7
ADCAHL:	PARDAAS
	MIns	ADDX.B,D7,D4,11,T,X,7
ADDAHL:	PARDAAS
	MIns	ADD.B,D7,D4,3,T,N,7

ADCAIX:	PARDAAS
	MIns	ADDX.B,D7,A0,12,T,X,19
ADDAIX:	PARDAAS
	MIns	ADD.B,D7,A0,4,T,N,19
ADCAIY:	PARDAAS
	MIns	ADDX.B,D7,A1,12,T,X,19
ADDAIY:	PARDAAS
	MIns	ADD.B,D7,A1,4,T,N,19

ADCHLHL:MIns	ADDX.W,D4,D4,2,T,X,15
ADDHLHL:MIns	ADD.W,D4,D4,2,C,N,11
ADCHLBC:MIns	ADDX.W,D4,D5,2,T,X,15
ADDHLBC:MIns	ADD.W,D4,D5,2,C,N,11
ADCHLDE:MIns	ADDX.W,D4,D6,2,T,X,15
ADDHLDE:MIns	ADD.W,D4,D6,2,C,N,11
ADCHLSP:MIns	ADDX.W,D4,D0,2,T,X,15
ADDHLSP:MIns	ADD.W,D4,D0,2,C,N,11

ADDIXIX:MIns	ADD.W,A0,A0,2I,C,N,15
ADDIXBC:MIns	ADD.W,A0,D5,2I,C,N,15
ADDIXDE:MIns	ADD.W,A0,D6,2I,C,N,15
ADDIXSP:MIns	ADD.W,A0,D0,2I,C,N,15

ADDIYIY:MIns	ADD.W,A1,A1,2I,C,N,15
ADDIYBC:MIns	ADD.W,A1,D5,2I,C,N,15
ADDIYDE:MIns	ADD.W,A1,D6,2I,C,N,15
ADDIYSP:MIns	ADD.W,A1,D0,2I,C,N,15

SBCA:	PARDAAR
	MIns	SUBX.B,D7,D7,0,T,X,4
SUBA:	PARDAAR
	MIns	SUB.B,D7,D7,0,T,N,4
SBCB:	PARDAAR
	MIns	SUBX.B,D7,D5,1,T,X,4
SUBB:	PARDAAR
	MIns	SUB.B,D7,D5,1,T,N,4
SBCC:	PARDAAR
	MIns	SUBX.B,D7,D5,0,T,X,4
SUBC:	PARDAAR
	MIns	SUB.B,D7,D5,0,T,N,4
SBCD:	PARDAAR
	MIns	SUBX.B,D7,D6,1,T,X,4
SUBD:	PARDAAR
	MIns	SUB.B,D7,D6,1,T,N,4
SBCE:	PARDAAR
	MIns	SUBX.B,D7,D6,0,T,X,4
SUBE:	PARDAAR
	MIns	SUB.B,D7,D6,0,T,N,4
SBCH:	PARDAAR
	MIns	SUBX.B,D7,D4,1,T,X,4
SUBH:	PARDAAR
	MIns	SUB.B,D7,D4,1,T,N,4
SBCL:	PARDAAR
	MIns	SUBX.B,D7,D4,0,T,X,4
SUBL:	PARDAAR
	MIns	SUB.B,D7,D4,0,T,N,4
SBCN:	PARDAAR
	MIns	SUBX.B,D7,N,10,T,X,7
SUBN:	PARDAAR
	MIns	SUB.B,D7,N,10,T,N,7
SBCHL:	PARDAAR
	MIns	SUBX.B,D7,D4,11,T,X,7
SUBHL:	PARDAAR
	MIns	SUB.B,D7,D4,3,T,N,7

SBCIX:	PARDAAR
	MIns	SUBX.B,D7,A0,12,T,X,19
SUBIX:	PARDAAR
	MIns	SUB.B,D7,A0,4,T,N,19
SBCIY:	PARDAAR
	MIns	SUBX.B,D7,A1,12,T,X,19
SUBIY:	PARDAAR
	MIns	SUB.B,D7,A1,4,T,N,19

SBCHLHL:MIns	SUBX.W,D4,D4,2,T,X,15
SBCHLBC:MIns	SUBX.W,D4,D5,2,T,X,15
SBCHLDE:MIns	SUBX.W,D4,D6,2,T,X,15
SBCHLSP:MIns	SUBX.W,D4,D0,2,T,X,15

; -------------------  INC / DEC  ---------------

INCA:	PARDAAS
	MIns	ADDQ.B,D7,#1,0,S,N,4
INCH:	MIns	ADDI.W,D4,#0,7B,S,N,4
INCL:	MIns	ADDQ.B,D4,#1,0,S,N,4
INCB:	MIns	ADDI.W,D5,#0,7B,S,N,4
INCC:	MIns	ADDQ.B,D5,#1,0,S,N,4
INCD:	MIns	ADDI.W,D6,#0,7B,S,N,4
INCE:	MIns	ADDQ.B,D6,#1,0,S,N,4

INCHLM:	MIns	ADDQ.B,D4,#1,8,S,N,11
INCIXM:	MIns	ADDQ.B,A0,#1,9,S,N,23
INCIYM:	MIns	ADDQ.B,A1,#1,9,S,N,23

INCHL:	MIns	ADDQ.W,D4,#1,2,N,N,6
INCBC:	MIns	ADDQ.W,D5,#1,2,N,N,6
INCDE:	MIns	ADDQ.W,D6,#1,2,N,N,6
INCIX:	MIns	ADDQ.W,A0,#1,2,N,N,10
INCIY:	MIns	ADDQ.W,A1,#1,2,N,N,10
INCSP:
	ADDQ.W	#1,D0
	MOVE.W	D0,D1
	CogePagE D1,A6
	Otra	6


DECA:	PARDAAR
	MIns	SUBQ.B,D7,#1,0,S,N,4
DECH:	MIns	SUB.W,D4,#0,7,S,N,4
DECL:	MIns	SUBQ.B,D4,#1,0,S,N,4
DECB:	MIns	SUB.W,D5,#0,7,S,N,4
DECC:	MIns	SUBQ.B,D5,#1,0,S,N,4
DECD:	MIns	SUB.W,D6,#0,7,S,N,4
DECE:	MIns	SUBQ.B,D6,#1,0,S,N,4

DECHLM:	MIns	SUBQ.B,D4,#1,8,S,N,11
DECIXM:	MIns	SUBQ.B,A0,#1,9,S,N,23
DECIYM:	MIns	SUBQ.B,A1,#1,9,S,N,23

DECHL:	MIns	SUBQ.W,D4,#1,2,N,N,6
DECBC:	MIns	SUBQ.W,D5,#1,2,N,N,6
DECDE:	MIns	SUBQ.W,D6,#1,2,N,N,6
DECIX:	MIns	SUBQ.W,A0,#1,2,N,N,10
DECIY:	MIns	SUBQ.W,A1,#1,2,N,N,10
DECSP:
	SUBQ.W	#1,D0
	MOVE.W	D0,D1
	CogePagE D1,A6
	Otra	6

; -----------------------  AND  ---------------

ANDA:	MIns	AND.B,D7,D7,0,P,N,4
ANDH:	MIns	AND.B,D7,D4,1,P,N,4
ANDL:	MIns	AND.B,D7,D4,0,P,N,4
ANDB:	MIns	AND.B,D7,D5,1,P,N,4
ANDC:	MIns	AND.B,D7,D5,0,P,N,4
ANDD:	MIns	AND.B,D7,D6,1,P,N,4
ANDE:	MIns	AND.B,D7,D6,0,P,N,4
ANDN:	MIns	AND.B,D7,N,10,P,N,7

ANDHL:	MIns	AND.B,D7,D4,3,P,N,7
ANDIX:	MIns	AND.B,D7,A0,4,P,N,19
ANDIY:	MIns	AND.B,D7,A1,4,P,N,19

; -----------------------  OR  ---------------

ORA:	MIns	OR.B,D7,D7,0,P,N,4
ORH:	MIns	OR.B,D7,D4,1,P,N,4
ORL:	MIns	OR.B,D7,D4,0,P,N,4
ORB:	MIns	OR.B,D7,D5,1,P,N,4
ORC:	MIns	OR.B,D7,D5,0,P,N,4
ORD:	MIns	OR.B,D7,D6,1,P,N,4
ORE:	MIns	OR.B,D7,D6,0,P,N,4
ORN:	MIns	OR.B,D7,N,10,P,N,7

ORHL:	MIns	OR.B,D7,D4,3,P,N,7
ORIX:	MIns	OR.B,D7,A0,4,P,N,19
ORIY:	MIns	OR.B,D7,A1,4,P,N,19

; -----------------------  CP  ---------------

CPA:	MIns	CMP.B,D7,D7,0,T,N,4
CPH:	MIns	CMP.B,D7,D4,1,T,N,4
CPL:	MIns	CMP.B,D7,D4,0,T,N,4
CPB:	MIns	CMP.B,D7,D5,1,T,N,4
CPC:	MIns	CMP.B,D7,D5,0,T,N,4
CPD:	MIns	CMP.B,D7,D6,1,T,N,4
CPE:	MIns	CMP.B,D7,D6,0,T,N,4
CPN:	MIns	CMP.B,D7,N,10,T,N,7

CPHL:	MIns	CMP.B,D7,D4,3,T,N,7
CPIX:	MIns	CMP.B,D7,A0,4,T,N,19
CPIY:	MIns	CMP.B,D7,A1,4,T,N,19

; -----------------------  XOR  ---------------

XORA:	MIns	EOR.B,D7,D7,0,P,N,4
XORH:	MIns	EOR.B,D7,D4,1,P,N,4
XORL:	MIns	EOR.B,D7,D4,0,P,N,4
XORB:	MIns	EOR.B,D7,D5,1,P,N,4
XORC:	MIns	EOR.B,D7,D5,0,P,N,4
XORD:	MIns	EOR.B,D7,D6,1,P,N,4
XORE:	MIns	EOR.B,D7,D6,0,P,N,4
XORN:	MIns	EOR.B,D7,N,10,P,N,7

XORHL:	MIns	EOR.B,D7,D4,11,P,N,7
XORIX:	MIns	EOR.B,D7,A0,12,P,N,19
XORIY:	MIns	EOR.B,D7,A1,12,P,N,19

; ---------------------  LD  ---------------------

LDBB:	Otra	4
LDBC:	MLDRR	D5,D5,2,4
LDBD:	MLDRR	D5,D6,1,4
LDBE:	MLDRR	D5,D6,4,4
LDBH:	MLDRR	D5,D4,1,4
LDBL:	MLDRR	D5,D4,4,4
LDBHL:	MLDRR	D5,D4,0B,7
LDBIX:	MLDRR	D5,A0,6B,19
LDBIY:	MLDRR	D5,A1,6B,19
LDBA:	MLDRR	D5,D7,4,4
; ---------------------	; $48 ; ---------------- ;
LDCB:	MLDRR	D5,D5,3,4
LDCC:	Otra	4
LDCD:	MLDRR	D5,D6,5,4
LDCE:	MLDRR	D5,D6,0,4
LDCH:	MLDRR	D5,D4,5,4
LDCL:	MLDRR	D5,D4,0,4
LDCHL:	MLDRR	D5,D4,0A,7
LDCIX:	MLDRR	D5,A0,6,19
LDCIY:	MLDRR	D5,A1,6,19
LDCA:	MLDRR	D5,D7,0,4
; ---------------------	; $50 ; ---------------- ;
LDDB:	MLDRR	D6,D5,1,4
LDDC:	MLDRR	D6,D5,4,4
LDDD:	Otra	4
LDDE:	MLDRR	D6,D6,2,4
LDDH:	MLDRR	D6,D4,1,4
LDDL:	MLDRR	D6,D4,4,4
LDDHL:	MLDRR	D6,D4,0B,7
LDDIX:	MLDRR	D6,A0,6B,19
LDDIY:	MLDRR	D6,A1,6B,19
LDDA:	MLDRR	D6,D7,4,4
; ---------------------	; $58 ; ---------------- ;
LDEB:	MLDRR	D6,D5,5,4
LDEC:	MLDRR	D6,D5,0,4
LDED:	MLDRR	D6,D6,3,4
LDEE:	Otra	4
LDEH:	MLDRR	D6,D4,5,4
LDEL:	MLDRR	D6,D4,0,4
LDEHL:	MLDRR	D6,D4,0A,7
LDEIX:	MLDRR	D6,A0,6,19
LDEIY:	MLDRR	D6,A1,6,19
LDEA:	MLDRR	D6,D7,0,4
; ---------------------	; $60 ; ---------------- ;
LDHB:	MLDRR	D4,D5,1,4
LDHC:	MLDRR	D4,D5,4,4
LDHD:	MLDRR	D4,D6,1,4
LDHE:	MLDRR	D4,D6,4,4
LDHH:	Otra	4
LDHL:	MLDRR	D4,D4,2,4
LDHHL:	MLDRR	D4,D4,0B,7
LDHIX:	MLDRR	D4,A0,6B,19
LDHIY:	MLDRR	D4,A1,6B,19
LDHA:	MLDRR	D4,D7,4,4
; ---------------------	; $68 ; ---------------- ;
LDLB:	MLDRR	D4,D5,5,4
LDLC:	MLDRR	D4,D5,0,4
LDLD:	MLDRR	D4,D6,5,4
LDLE:	MLDRR	D4,D6,0,4
LDLH:	MLDRR	D4,D4,3,4
LDLL:	Otra	4
LDLHL:	MLDRR	D4,D4,0A,7
LDLIX:	MLDRR	D4,A0,6,19
LDLIY:	MLDRR	D4,A1,6,19
LDLA:	MLDRR	D4,D7,0,4
; ---------------------	; $70 ; ---------------- ;

	IFNE	FFFF_ON
LDHLB:	MLDRR	D4,D5,11,7
LDHLC:	MLDRR	D4,D5,10,7
LDHLD:	MLDRR	D4,D6,11,7
LDHLE:	MLDRR	D4,D6,10,7
LDHLH:	MLDRR	D4,D4,11,7
LDHLL:	MLDRR	D4,D4,10,7
	ELSEIF
LDHLB:	MLDRR	D4,D5,11F,7
LDHLC:	MLDRR	D4,D5,10F,7
LDHLD:	MLDRR	D4,D6,11F,7
LDHLE:	MLDRR	D4,D6,10F,7
LDHLH:	MLDRR	D4,D4,11F,7
LDHLL:	MLDRR	D4,D4,10F,7
	ENDC


Halt:
	ST	HaltDat(A3)
	CLR.W	(A3)			; * Resta Cycles *
	JMP	MiraInter
	CNOP	0,4


	IFNE	FFFF_ON

LDHLMN:	CogePagE D4,A4
	MOVE.B	(A5)+,(A4)
	BEQ.S	LDHLMN0
	Otra	10
LDHLMN0:CheckB	(A4)
	Otra	10

LDHLA:	MLDRR	D4,D7,10,7
LDBCA:	MLDRR	D5,D7,10,7
LDDEA:	MLDRR	D6,D7,10,7

	ELSEIF

LDHLMN:	CogePagE D4,A4
	MOVE.B	(A5)+,(A4)
	BEQ.S	LDHLMN0
	ADDQ.W	#4,D4
	BCS.S	LDHLMNF
	SUBQ.W	#4,D4
	Otra	10
LDHLMNF:SUBQ.W	#4,D4
	JMP	Mapper
LDHLMN0:CheckB	(A4)
	ADDQ.W	#4,D4
	BCS.S	LDHLMNF
	SUBQ.W	#4,D4
	Otra	10

LDHLA:	MLDRR	D4,D7,10F,7
LDBCA:	MLDRR	D5,D7,10F,7
LDDEA:	MLDRR	D6,D7,10F,7

	ENDC

; ---------------------	; $70 ; ---------------- ;
LDIXB:	MLDRR	A0,D5,13,19
LDIXC:	MLDRR	A0,D5,12,19
LDIXD:	MLDRR	A0,D6,13,19
LDIXE:	MLDRR	A0,D6,12,19
LDIXH:	MLDRR	A0,D4,13,19
LDIXL:	MLDRR	A0,D4,12,19
LDIXA:	MLDRR	A0,D7,12,19
LDIXMN:	MLDRR	A0,MN,12N,19
; ---------------------	; $70 ; ---------------- ;
LDIYB:	MLDRR	A1,D5,13,19
LDIYC:	MLDRR	A1,D5,12,19
LDIYD:	MLDRR	A1,D6,13,19
LDIYE:	MLDRR	A1,D6,12,19
LDIYH:	MLDRR	A1,D4,13,19
LDIYL:	MLDRR	A1,D4,12,19
LDIYA:	MLDRR	A1,D7,12,19
LDIYMN:	MLDRR	A1,MN,12N,19
; ---------------------	; $78 ; ---------------- ;
LDSPHL:	MOVE.L	D4,D0
	CogePagS D0,A6
	Otra	6
LDSPIX:
	MOVE.W	A0,D0
	MOVE.W	D0,D1
	CogePagS D1,A6
	Otra	10
LDSPIY:
	MOVE.W	A1,D0
	MOVE.W	D0,D1
	CogePagS D1,A6
	Otra	10
; ---------------------	; $78 ; ---------------- ;
LDAB:	MLDRR	D7,D5,7,4
LDAC:	MLDRR	D7,D5,0,4
LDAD:	MLDRR	D7,D6,7,4
LDAE:	MLDRR	D7,D6,0,4
LDAH:	MLDRR	D7,D4,7,4
LDAL:	MLDRR	D7,D4,0,4
LDAHL:	MLDRR	D7,D4,0A,7
LDABC:	MLDRR	D7,D5,0A,7
LDADE:	MLDRR	D7,D6,0A,7
LDAIX:	MLDRR	D7,A0,6,19
LDAIY:	MLDRR	D7,A1,6,19
LDAA:	Otra	4

LDAM:	MOVE.W	(A5)+,D1
	TST.B	D1
	BEQ.S	LDAMM
	ROR.W	#8,D1
	CogePag	D1,A4
	MOVE.B	(A4),D7
	Otra	13
LDAMM:	CheckW	D1
	ROR.W	#8,D1
	CogePag	D1,A4
	MOVE.B	(A4),D7
	Otra	13

LDAI:
	MOVE.B	D3,D1
	MOVE.B	I(A3),D7
	MOVE.W	CCR,D3
	BFINS	D1,D3{31:1}
	MOVE.B	IFF(A3),D1
	BFINS	D1,D3{30:1}
	Otra	9
; LD A,R: R from the emulated time (line, cycles left in it, frame), so it
; varies like the real refresh counter but is the same on every run. It
; read the Amiga beam ($DFF007): games that seed randomness from R (Zanac)
; ran differently every time.
LDAR:
	MOVE.W	CurLine(A3),D1
	MULU	#57,D1			; ~M1 cycles per line (228 / 4)
	SUB.W	(A3),D1			; cycles left in the line count down
	ADD.B	RFrame,D1
	AND.W	#$007F,D1
	MOVE.B	D1,D7
	MOVE.B	D3,D1
	OR.B	R(A3),D7
	MOVE.W	CCR,D3
	BFINS	D1,D3{31:1}
	MOVE.B	IFF(A3),D1
	BFINS	D1,D3{30:1}
	Otra	9
; ---------------------------------------------- ;
LDIA:	MOVE.B	D7,I(A3)
	Otra	9
LDRA:
	MOVE.B	D7,R(A3)
	AND.B	#$80,R(A3)
	Otra	9
; ---------------------	; $78 ; ---------------- ;
LDHLM:	MLDRR	D4,M,8,16
LDBCM:	MLDRR	D5,M,8,20
LDDEM:	MLDRR	D6,M,8,20
LDIXM:	MLDRR	A0,M,8I,20
LDIYM:	MLDRR	A1,M,8I,20
LDSPM:	MLDRR	A6,M,8S,20


	IFNE	FFFF_ON
LDMA:	MOVE.W	(A5)+,D1
	TST.B	D1
	BEQ.S	LDMAM
	ROR.W	#8,D1
	CogePagE D1,A4
	MOVE.B	D7,(A4)
	Otra	13
LDMAM:	CheckW	D1
	ROR.W	#8,D1
	CogePagE D1,A4
	MOVE.B	D7,(A4)
	Otra	13

	ELSEIF

LDMA:	MOVE.W	(A5)+,D1
	TST.B	D1
	BEQ.S	LDMAM
	ROR.W	#8,D1
	ADDQ.W	#4,D1
	BCS.S	LDMAF
	SUBQ.W	#4,D1
	CogePagE D1,A4
	MOVE.B	D7,(A4)
	Otra	13
LDMAF:
	SUBQ.W	#4,D1
	CogePagE D1,A4
	MOVE.B	D7,(A4)
	JMP	Mapper
	CNOP	0,4
LDMAM:	CheckW	D1
	ROR.W	#8,D1
	ADDQ.W	#4,D1
	BCS.S	LDMAF
	SUBQ.W	#4,D1
	CogePagE D1,A4
	MOVE.B	D7,(A4)
	Otra	13
	ENDC


LDMHL:	MLDRR	D4,M,9,16
LDMBC:	MLDRR	D5,M,9,20
LDMDE:	MLDRR	D6,M,9,20
LDMIX:	MLDRR	A0,M,9,20
LDMIY:	MLDRR	A1,M,9,20
LDMSP:	MLDRR	D0,M,9,20

LDAN:	MLDRR	D7,N,15,7
LDHN:	MLDRR	D4,N,14,7
LDLN:	MLDRR	D4,N,15,7
LDBN:	MLDRR	D5,N,14,7
LDCN:	MLDRR	D5,N,15,7
LDDN:	MLDRR	D6,N,14,7
LDEN:	MLDRR	D6,N,15,7

LDHLN:	MLDRR	D4,N,16,10
LDBCN:	MLDRR	D5,N,16,10
LDDEN:	MLDRR	D6,N,16,10
LDIXN:	MLDRR	A0,N,17I,14
LDIYN:	MLDRR	A1,N,17I,14
LDSPN:	MLDRR	A6,N,17S,10



; -----------------------   InsCB   ---------------

	CNOP	0,4
RLCB0:
	CMP.L	Desbor+4(A7),A5
	BLE.S	RLCB
	MOVE.B	D1,D2
	SUBQ.W	#1,A5
	MOVE.W	A5,D1
	SUB.W	(A7),D1
	CogePag	D1,A5
	LEA	Restas(A3,D1.W*8),A7
	MOVE.B	(A5)+,D2
	JMP	([InsCB-$400,D2.W*4])	; Salta a puntero de emulaci�n.
	CNOP	0,4

MInsCB2:MACRO
\1B:	MROT	\2.B,D5,\3,1,8
\1C:	MROT	\2.B,D5,\3,0,8
\1D:	MROT	\2.B,D6,\3,1,8
\1E:	MROT	\2.B,D6,\3,0,8
\1H:	MROT	\2.B,D4,\3,1,8
\1L:	MROT	\2.B,D4,\3,0,8
\1HL:	MROT	\2.B,D4,\3,2,15
\1A:	MROT	\2.B,D7,\3,0,8
\1IX:	MROT	\2.B,A0,\3,2I,23
\1IY:	MROT	\2.B,A1,\3,2I,23
	ENDM

	MInsCB2	RLC,ROL,N	; CB  0 0xxx
	MInsCB2	RRC,ROR,N	; CB  0 1xxx
	MInsCB2	RL,ROXL,X	; CB  1 0xxx
	MInsCB2	RR,ROXR,X	; CB  1 1xxx
	MInsCB2	SLA,ASL,N	; CB  2 0xxx
	MInsCB2	SRA,ASR,N	; CB  2 1xxx
	MInsCB2	SRR,ROXL,S	; CB  3 0xxx
	MInsCB2	SRL,LSR,N	; CB  3 1xxx

MInsCB:	MACRO
\5\2A:	MIns	\1,D7,#\2,0B,\3,N,8
\5\2H:	MIns	\1,D4,#\2+8,0B,\3,N,8
\5\2L:	MIns	\1,D4,#\2,0B,\3,N,8
\5\2B:	MIns	\1,D5,#\2+8,0B,\3,N,8
\5\2C:	MIns	\1,D5,#\2,0B,\3,N,8
\5\2D:	MIns	\1,D6,#\2+8,0B,\3,N,8
\5\2E:	MIns	\1,D6,#\2,0B,\3,N,8
\5\2HL:	MIns	\1,D4,#\2,8\4,\3,N,12+\6
\5\2IX:	MIns	\1,A0,#\2,9\4,\3,N,20+\6
\5\2IY:	MIns	\1,A1,#\2,9\4,\3,N,20+\6
	ENDM

	MInsCB	BTST,0,Z,Y,BIT,0	; CB  4 0xxx
	MInsCB	BTST,1,Z,Y,BIT,0	; CB  4 1xxx
	MInsCB	BTST,2,Z,Y,BIT,0	; CB  5 0xxx
	MInsCB	BTST,3,Z,Y,BIT,0	; CB  5 1xxx
	MInsCB	BTST,4,Z,Y,BIT,0	; CB  6 0xxx
	MInsCB	BTST,5,Z,Y,BIT,0	; CB  6 1xxx
	MInsCB	BTST,6,Z,Y,BIT,0	; CB  7 0xxx
	MInsCB	BTST,7,Z,Y,BIT,0	; CB  7 1xxx

	MInsCB	BCLR,0,N,I,RES,3	; CB  8 0xxx
	MInsCB	BCLR,1,N,I,RES,3	; CB  8 1xxx
	MInsCB	BCLR,2,N,I,RES,3	; CB  9 0xxx
	MInsCB	BCLR,3,N,I,RES,3	; CB  9 1xxx
	MInsCB	BCLR,4,N,I,RES,3	; CB  A 0xxx
	MInsCB	BCLR,5,N,I,RES,3	; CB  A 1xxx
	MInsCB	BCLR,6,N,I,RES,3	; CB  B 0xxx
	MInsCB	BCLR,7,N,I,RES,3	; CB  B 1xxx

	MInsCB	BSET,0,N,I,SET,3	; CB  C 0xxx
	MInsCB	BSET,1,N,I,SET,3	; CB  C 1xxx
	MInsCB	BSET,2,N,I,SET,3	; CB  D 0xxx
	MInsCB	BSET,3,N,I,SET,3	; CB  D 1xxx
	MInsCB	BSET,4,N,I,SET,3	; CB  E 0xxx
	MInsCB	BSET,5,N,I,SET,3	; CB  E 1xxx
	MInsCB	BSET,6,N,I,SET,3	; CB  F 0xxx
	MInsCB	BSET,7,N,I,SET,3	; CB  F 1xxx

; -----------------------  FIN InsCB ---------------

NOP:
	CMP2.L	Desbor(A7),A5
	BCS.S	DESNOP
	Otra	4
DESNOP:
	SUBQ.W	#1,A5
	MOVE.W	A5,D1
	SUB.W	(A7),D1
	CogePag	D1,A5
	LEA	Restas(A3,D1.W*8),A7
	Otra	4
NOP060:
	CMP.L	Desbor+4(A7),A5
	BGT.S	DESNOP
	CMP.L	Desbor(A7),A5
	BLT.S	DESNOP
	Otra	4


DAA:
	MOVE.B	DatDAA(A3),D2
	BEQ	MIRAC
	SF	DatDAA(A3)
CONTD:
	SUB.B	D2,D7
	BCS.S	RESTA
	MOVE.W	D3,CCR
	BCS.S	RESTAB
SUMA:
	MOVE.W	#04,CCR
	ABCD.B	D2,D7
	OtraT	4
RESTA:
	MOVE.W	D3,CCR
	BCS.S	SUMA
RESTAB:
	NEG.B	D7
	MOVE.B	D2,D1
	MOVE.B	D7,D2
	MOVE.B	D1,D7
	MOVE.W	#04,CCR
	SBCD.B	D2,D7
	OtraT	4
MIRAC:
	MOVE.W	D3,CCR
	BCC	CONTD
	MOVE.B	D7,D2
	NEG.B	D2
	SF	D7
	MOVE.W	#04,CCR
	SBCD.B	D2,D7
	OtraT	4

SCF:	BSET	#0,D3
	Otra	4
CCF:	BCHG	#0,D3
	Otra	4

ICPL:	NOT.B	D7
	OR.B	#$50,D3			; H and N set (D3 b6 = H, b4 = N)
	Otra	4

; NEG: the 68k NEG flags are the Z80 ones (C and X = A was not 0, so N via
; X; V = A was 80h); only N needs forcing, for A = 0.
NEG:	NEG.B	D7
	MOVE.W	CCR,D3
	OR.B	#$10,D3
	Otra	8

IRLA:	LSR.B	#1,D3
	ROXL.B	#1,D7
	ROXL.B	#1,D3
	Otra	4
IRRA:	LSR.B	#1,D3
	ROXR.B	#1,D7
	ROXL.B	#1,D3
	Otra	4
IRLCA:	ROL.B	#1,D7
	OtraC2	4
IRRCA:	ROR.B	#1,D7
	OtraC2	4


DI:	SF	IFF(A3)
	Otra	4

EI:
	ST	IFF(A3)

;	BTST	#4,DVDP0(A3)		; �Interrupci�n Horizontal?
;	BEQ.S	EIcon
;	TST.B	PetInt38(A3)		; LineInt Flag
;	BEQ.S	EIcon
;	CLR.W	(A3)			; * Resta Cycles *
;EIcon:
	OtraEI	4


EXAF:	SWAP	D7
	SWAP	D3
	Otra	4
EXX:	MOVE.W	PEXX(A3),D1
	MOVE.W	D4,PEXX(A3)
	MOVE.W	D1,D4
	MOVE.W	PEXX+2(A3),D1
	MOVE.W	D5,PEXX+2(A3)
	MOVE.W	D1,D5
	MOVE.W	PEXX+4(A3),D1
	MOVE.W	D6,PEXX+4(A3)
	MOVE.W	D1,D6
	Otra	4
EXSPHL:	MOVE.W	(A6),D1
	ROR.W	#8,D1
	EXG.L	D4,D1
	ROR.W	#8,D1
	MOVE.W	D1,(A6)
	Otra	4
EXDEHL:	EXG.L	D6,D4
	Otra	4
EXSPMIX:MOVE.W	(A6),D1
	ROR.W	#8,D1
	EXG.L	A0,D1
	ROR.W	#8,D1
	MOVE.W	D1,(A6)
	MOVEQ	#0,D1
	Otra	23
EXSPMIY:MOVE.W	(A6),D1
	ROR.W	#8,D1
	EXG.L	A1,D1
	ROR.W	#8,D1
	MOVE.W	D1,(A6)
	MOVEQ	#0,D1
	Otra	23

DJNZ:	MOVE.B	D5,D2
	SUB.W	D2,D5
	BEQ.S	NODJNZ
	MOVE.B	D2,D5
	MJR	13
NODJNZ:	MOVE.B	D2,D5
	ADDQ.W	#1,A5
	Otra	8

JR:	MJR	12
JRNZ:	MJRC	NE,12,7
JRZ:	MJRC	EQ,12,7
JRNC:	MJRC	CC,12,7
JRC:	MJRC	CS,12,7

JP:	MJP	10
JPNZ:	MJPC	NE,10
JPZ:	MJPC	EQ,10
JPNC:	MJPC	CC,10
JPC:	MJPC	CS,10
JPP:	MJPC	PL,10
JPM:	MJPC	MI,10
JPPO:	MJPC	VC,10
JPPE:	MJPC	VS,10

JPHL:
	MOVE.W	D4,D1
	CogePag	D1,A5
	LEA	Restas(A3,D1.W*8),A7
	Otra	4
JPIX:
	MOVE.W	A0,D1
	CogePag D1,A5
	LEA	Restas(A3,D1.W*8),A7
	Otra	8
JPIY:
	MOVE.W	A1,D1
	CogePag D1,A5
	LEA	Restas(A3,D1.W*8),A7
	Otra	8

CALL:	MCALL	17
CALLNZ:	MCALLC	NE,17,10
CALLZ:	MCALLC	EQ,17,10
CALLNC:	MCALLC	CC,17,10
CALLC:	MCALLC	CS,17,10
CALLP:	MCALLC	PL,17,10
CALLM:	MCALLC	MI,17,10
CALLPO:	MCALLC	VC,17,10
CALLPE:	MCALLC	VS,17,10

IRET:	MRET	10
RETNZ:	MRETC	NE,11,5
RETZ:	MRETC	EQ,11,5
RETNC:	MRETC	CC,11,5
RETC:	MRETC	CS,11,5
RETP:	MRETC	PL,11,5
RETM:	MRETC	MI,11,5
RETPO:	MRETC	VC,11,5
RETPE:	MRETC	VS,11,5

RETN:	;MOVE.B	IFF0(A3),IFF(A3)
	MRET	14

RETI:	ST	IFF(A3)
	MRET	14


RST0:	MRST	$00,11
RST8:	MRST	$08,11
RST10:	MRST	$10,11
RST18:	MRST	$18,11
RST20:	MRST	$20,11
RST28:	MRST	$28,11
RST30:	MRST	$30,11
RST38:	MRST	$38,11

PUSHAF:	MPUSH	AF,11
PUSHHL:	MPUSH	D4,11
PUSHBC:	MPUSH	D5,11
PUSHDE:	MPUSH	D6,11
PUSHIX:	MPUSH	A0,15
PUSHIY:	MPUSH	A1,15

POPAF:	MPOP	AF,1,10
POPHL:	MPOP	D4,0,10
POPBC:	MPOP	D5,0,10
POPDE:	MPOP	D6,0,10
POPIX:	MPOP	A0,1,14
POPIY:	MPOP	A1,1,14


INBC:	MINC	D5,1,12
IINCC:	MINC	D5,0,12
INDC:	MINC	D6,1,12
INEC:	MINC	D6,0,12
INHC:	MINC	D4,1,12
INLC:	MINC	D4,0,12
INAC:	MINC	D7,0,12
INAN:	MOVE.B	(A5)+,D2
	JSR	([Ins-$400.W,PC,D2.W*4])	; Salta a puntero de emulaci�n.
	MOVE.B	D1,D7
	Otra	11

OUTCB:	MOUTC	D5,1,12
OUTCC:	MOUTC	D5,0,12
OUTCD:	MOUTC	D6,1,12
OUTCE:	MOUTC	D6,0,12
OUTCH:	MOUTC	D4,1,12
OUTCL:	MOUTC	D4,0,12
OUTCA:	MOUTC	D7,0,12
OUTNA:	MOVE.B	(A5)+,D2
	MOVE.B	D7,D1
	JSR	([OUTS-$400.W,PC,D2.W*4])	; Salta a puntero de emulaci�n.
	Otra	11


IM0:	MOVE.B	#$7F,ModoInt(A3)
	Otra	8
IM1:	SF	ModoInt(A3)
	Otra	8
IM2:	ST	ModoInt(A3)
	Otra	8


;	-----------------------
;	Instrucciones Secretas.
;	-----------------------
INCHX:
	MOVE.W	A0,D1
	ROR.W	#8,D1
	MOVE.B	D3,D2
	ADDQ.B	#1,D1
	MOVE.W	CCR,D3
	BFINS	D2,D3{31:1}
	ROR.W	#8,D1
	MOVE.L	D1,A0
	Otra	9
INCLX:
	MOVE.W	A0,D1
	MOVE.B	D3,D2
	ADDQ.B	#1,D1
	MOVE.W	CCR,D3
	BFINS	D2,D3{31:1}
	MOVE.L	D1,A0
	Otra	9
DECHX:
	MOVE.W	A0,D1
	ROR.W	#8,D1
	MOVE.B	D3,D2
	SUBQ.B	#1,D1
	MOVE.W	CCR,D3
	BFINS	D2,D3{31:1}
	ROR.W	#8,D1
	MOVE.L	D1,A0
	Otra	9
DECLX:
	MOVE.W	A0,D1
	MOVE.B	D3,D2
	SUBQ.B	#1,D1
	MOVE.W	CCR,D3
	BFINS	D2,D3{31:1}
	MOVE.L	D1,A0
	Otra	9
LDHXN:
	MOVE.W	A0,D1
	LSL.W	#8,D1
	MOVE.B	(A5)+,D1
	ROR.W	#8,D1
	MOVE.L	D1,A0
	Otra	9
LDLXN:
	MOVE.W	A0,D1
	MOVE.B	(A5)+,D1
	MOVE.L	D1,A0
	Otra	9
LDAHX:
	MOVE.W	A0,D7
	LSR.W	#8,D7
	Otra	9
LDALX:
	MOVE.W	A0,D1
	MOVE.B	D1,D7
	Otra	9
LDLHX:
	MOVE.W	A0,D1
	LSR.W	#8,D1
	MOVE.B	D1,D4
	Otra	9
LDLLX:
	MOVE.W	A0,D1
	MOVE.B	D1,D4
	Otra	9
LDCHX:
	MOVE.W	A0,D1
	LSR.W	#8,D1
	MOVE.B	D1,D5
	Otra	9
LDCLX:
	MOVE.W	A0,D1
	MOVE.B	D1,D5
	Otra	9
LDEHX:
	MOVE.W	A0,D1
	LSR.W	#8,D1
	MOVE.B	D1,D6
	Otra	9
LDELX:
	MOVE.W	A0,D1
	MOVE.B	D1,D6
	Otra	9
LDHHX:
	MOVE.W	A0,D1
	MOVE.B	D4,D1
	MOVE.W	D1,D4
	Otra	9
LDHLX:
	MOVE.W	A0,D1
	LSL.W	#8,D1
	MOVE.B	D4,D1
	MOVE.W	D1,D4
	Otra	9
LDBHX:
	MOVE.W	A0,D1
	MOVE.B	D5,D1
	MOVE.W	D1,D5
	Otra	9
LDBLX:
	MOVE.W	A0,D1
	LSL.W	#8,D1
	MOVE.B	D5,D1
	MOVE.W	D1,D5
	Otra	9
LDDHX:
	MOVE.W	A0,D1
	MOVE.B	D6,D1
	MOVE.W	D1,D6
	Otra	9
LDDLX:
	MOVE.W	A0,D1
	LSL.W	#8,D1
	MOVE.B	D6,D1
	MOVE.W	D1,D6
	Otra	9
LDLXA:
	MOVE.W	A0,D1
	MOVE.B	D7,D1
	MOVE.L	D1,A0
	Otra	9
LDLXC:
	MOVE.W	A0,D1
	MOVE.B	D5,D1
	MOVE.L	D1,A0
	Otra	9
LDLXE:
	MOVE.W	A0,D1
	MOVE.B	D6,D1
	MOVE.L	D1,A0
	Otra	9
LDLXL:
	MOVE.W	A0,D1
	MOVE.B	D4,D1
	MOVE.L	D1,A0
	Otra	9
LDLXB:
	MOVE.W	A0,D1
	ROR.W	#8,D5
	MOVE.B	D5,D1
	ROR.W	#8,D5
	MOVE.L	D1,A0
	Otra	9
LDLXD:
	MOVE.W	A0,D1
	ROR.W	#8,D6
	MOVE.B	D6,D1
	ROR.W	#8,D6
	MOVE.L	D1,A0
	Otra	9
LDLXH:
	MOVE.W	A0,D1
	LSR.W	#8,D1
	MOVE.B	D1,D2
	LSL.W	#8,D1
	MOVE.B	D2,D1
	MOVE.L	D1,A0
	Otra	9
LDHXL:
	MOVE.W	A0,D1
	MOVE.B	D1,D2
	LSL.W	#8,D1
	MOVE.B	D2,D1
	MOVE.L	D1,A0
	Otra	9
LDHXA:
	MOVE.W	A0,D1
	ROR.W	#8,D1
	MOVE.B	D7,D1
	ROR.W	#8,D1
	MOVE.L	D1,A0
	Otra	9
LDHXC:
	MOVE.W	A0,D1
	ROR.W	#8,D1
	MOVE.B	D5,D1
	ROR.W	#8,D1
	MOVE.L	D1,A0
	Otra	9
LDHXE:
	MOVE.W	A0,D1
	ROR.W	#8,D1
	MOVE.B	D6,D1
	ROR.W	#8,D1
	MOVE.L	D1,A0
	Otra	9
LDHXB:
	MOVE.W	A0,D1
	MOVE.B	D1,D2
	MOVE.W	D5,D1
	MOVE.B	D2,D1
	MOVE.L	D1,A0
	Otra	9
LDHXD:
	MOVE.W	A0,D1
	MOVE.B	D1,D2
	MOVE.W	D6,D1
	MOVE.B	D2,D1
	MOVE.L	D1,A0
	Otra	9
LDHXH:
	MOVE.W	A0,D1
	MOVE.B	D1,D2
	MOVE.W	D4,D1
	MOVE.B	D2,D1
	MOVE.L	D1,A0
	Otra	9

ADCAHX:	PARDAAS
	MIns	ADDX.B,D7,A0,1,T,X,4
ADDAHX:	PARDAAS
	MIns	ADD.B,D7,A0,1,T,N,4
SBCHX:	PARDAAR
	MIns	SUBX.B,D7,A0,1,T,X,4
SUBHX:	PARDAAR
	MIns	SUB.B,D7,A0,1,T,N,4
ADCALX:	PARDAAS
	MOVE.W	A0,D1
	MIns	ADDX.B,D7,D1,0,T,X,4
ADDALX:	PARDAAS
	MOVE.W	A0,D1
	MIns	ADD.B,D7,D1,0,T,N,4
SBCLX:	PARDAAR
	MOVE.W	A0,D1
	MIns	SUBX.B,D7,D1,0,T,X,4
SUBLX:	PARDAAR
	MOVE.W	A0,D1
	MIns	SUB.B,D7,D1,0,T,N,4
ANDHX:	MIns	AND.B,D7,A0,1,P,N,4
ANDLX:	MOVE.W	A0,D1
	MIns	AND.B,D7,D1,0,P,N,4
ORHX:	MIns	OR.B,D7,A0,1,P,N,4
ORLX:	MOVE.W	A0,D1
	MIns	OR.B,D7,D1,0,P,N,4
XORHX:	MIns	EOR.B,D7,A0,1,P,N,4
XORLX:	MOVE.W	A0,D1
	MIns	EOR.B,D7,D1,0,P,N,4
CPHX:	MIns	CMP.B,D7,A0,1,T,N,4
CPLX:	MOVE.W	A0,D1
	MIns	CMP.B,D7,D1,0,T,N,4


INCHY:
	MOVE.W	A1,D1
	ROR.W	#8,D1
	MOVE.B	D3,D2
	ADDQ.B	#1,D1
	MOVE.W	CCR,D3
	BFINS	D2,D3{31:1}
	ROR.W	#8,D1
	MOVE.L	D1,A1
	Otra	9
INCLY:
	MOVE.W	A1,D1
	MOVE.B	D3,D2
	ADDQ.B	#1,D1
	MOVE.W	CCR,D3
	BFINS	D2,D3{31:1}
	MOVE.L	D1,A1
	Otra	9
DECHY:
	MOVE.W	A1,D1
	ROR.W	#8,D1
	MOVE.B	D3,D2
	SUBQ.B	#1,D1
	MOVE.W	CCR,D3
	BFINS	D2,D3{31:1}
	ROR.W	#8,D1
	MOVE.L	D1,A1
	Otra	9
DECLY:
	MOVE.W	A1,D1
	MOVE.B	D3,D2
	SUBQ.B	#1,D1
	MOVE.W	CCR,D3
	BFINS	D2,D3{31:1}
	MOVE.L	D1,A1
	Otra	9
LDHYN:
	MOVE.W	A1,D1
	LSL.W	#8,D1
	MOVE.B	(A5)+,D1
	ROR.W	#8,D1
	MOVE.L	D1,A1
	Otra	9
LDLYN:
	MOVE.W	A1,D1
	MOVE.B	(A5)+,D1
	MOVE.L	D1,A1
	Otra	9
LDAHY:
	MOVE.W	A1,D7
	LSR.W	#8,D7
	Otra	9
LDALY:
	MOVE.W	A1,D1
	MOVE.B	D1,D7
	Otra	9
LDLHY:
	MOVE.W	A1,D1
	LSR.W	#8,D1
	MOVE.B	D1,D4
	Otra	9
LDLLY:
	MOVE.W	A1,D1
	MOVE.B	D1,D4
	Otra	9
LDCHY:
	MOVE.W	A1,D1
	LSR.W	#8,D1
	MOVE.B	D1,D5
	Otra	9
LDCLY:
	MOVE.W	A1,D1
	MOVE.B	D1,D5
	Otra	9
LDEHY:
	MOVE.W	A1,D1
	LSR.W	#8,D1
	MOVE.B	D1,D6
	Otra	9
LDELY:
	MOVE.W	A1,D1
	MOVE.B	D1,D6
	Otra	9
LDHHY:
	MOVE.W	A1,D1
	MOVE.B	D4,D1
	MOVE.W	D1,D4
	Otra	9
LDHLY:
	MOVE.W	A1,D1
	LSL.W	#8,D1
	MOVE.B	D4,D1
	MOVE.W	D1,D4
	Otra	9
LDBHY:
	MOVE.W	A1,D1
	MOVE.B	D5,D1
	MOVE.W	D1,D5
	Otra	9
LDBLY:
	MOVE.W	A1,D1
	LSL.W	#8,D1
	MOVE.B	D5,D1
	MOVE.W	D1,D5
	Otra	9
LDDHY:
	MOVE.W	A1,D1
	MOVE.B	D6,D1
	MOVE.W	D1,D6
	Otra	9
LDDLY:
	MOVE.W	A1,D1
	LSL.W	#8,D1
	MOVE.B	D6,D1
	MOVE.W	D1,D6
	Otra	9
LDLYA:
	MOVE.W	A1,D1
	MOVE.B	D7,D1
	MOVE.L	D1,A1
	Otra	9
LDLYC:
	MOVE.W	A1,D1
	MOVE.B	D5,D1
	MOVE.L	D1,A1
	Otra	9
LDLYE:
	MOVE.W	A1,D1
	MOVE.B	D6,D1
	MOVE.L	D1,A1
	Otra	9
LDLYL:
	MOVE.W	A1,D1
	MOVE.B	D4,D1
	MOVE.L	D1,A1
	Otra	9
LDLYB:
	MOVE.W	A1,D1
	ROR.W	#8,D5
	MOVE.B	D5,D1
	ROR.W	#8,D5
	MOVE.L	D1,A1
	Otra	9
LDLYD:
	MOVE.W	A1,D1
	ROR.W	#8,D6
	MOVE.B	D6,D1
	ROR.W	#8,D6
	MOVE.L	D1,A1
	Otra	9
LDLYH:
	MOVE.W	A1,D1
	LSR.W	#8,D1
	MOVE.B	D1,D2
	LSL.W	#8,D1
	MOVE.B	D2,D1
	MOVE.L	D1,A1
	Otra	9
LDHYL:
	MOVE.W	A1,D1
	MOVE.B	D1,D2
	LSL.W	#8,D1
	MOVE.B	D2,D1
	MOVE.L	D1,A1
	Otra	9
LDHYA:
	MOVE.W	A1,D1
	ROR.W	#8,D1
	MOVE.B	D7,D1
	ROR.W	#8,D1
	MOVE.L	D1,A1
	Otra	9
LDHYC:
	MOVE.W	A1,D1
	ROR.W	#8,D1
	MOVE.B	D5,D1
	ROR.W	#8,D1
	MOVE.L	D1,A1
	Otra	9
LDHYE:
	MOVE.W	A1,D1
	ROR.W	#8,D1
	MOVE.B	D6,D1
	ROR.W	#8,D1
	MOVE.L	D1,A1
	Otra	9
LDHYB:
	MOVE.W	A1,D1
	MOVE.B	D1,D2
	MOVE.W	D5,D1
	MOVE.B	D2,D1
	MOVE.L	D1,A1
	Otra	9
LDHYD:
	MOVE.W	A1,D1
	MOVE.B	D1,D2
	MOVE.W	D6,D1
	MOVE.B	D2,D1
	MOVE.L	D1,A1
	Otra	9
LDHYH:
	MOVE.W	A1,D1
	MOVE.B	D1,D2
	MOVE.W	D4,D1
	MOVE.B	D2,D1
	MOVE.L	D1,A1
	Otra	9

ADCAHY:	PARDAAS
	MIns	ADDX.B,D7,A1,1,T,X,4
ADDAHY:	PARDAAS
	MIns	ADD.B,D7,A1,1,T,N,4
SBCHY:	PARDAAR
	MIns	SUBX.B,D7,A1,1,T,X,4
SUBHY:	PARDAAR
	MIns	SUB.B,D7,A1,1,T,N,4
ADCALY:	PARDAAS
	MOVE.W	A1,D1
	MIns	ADDX.B,D7,D1,0,T,X,4
ADDALY:	PARDAAS
	MOVE.W	A1,D1
	MIns	ADD.B,D7,D1,0,T,N,4
SBCLY:	PARDAAR
	MOVE.W	A1,D1
	MIns	SUBX.B,D7,D1,0,T,X,4
SUBLY:	PARDAAR
	MOVE.W	A1,D1
	MIns	SUB.B,D7,D1,0,T,N,4
ANDHY:	MIns	AND.B,D7,A1,1,P,N,4
ANDLY:	MOVE.W	A1,D1
	MIns	AND.B,D7,D1,0,P,N,4
ORHY:	MIns	OR.B,D7,A1,1,P,N,4
ORLY:	MOVE.W	A1,D1
	MIns	OR.B,D7,D1,0,P,N,4
XORHY:	MIns	EOR.B,D7,A1,1,P,N,4
XORLY:	MOVE.W	A1,D1
	MIns	EOR.B,D7,D1,0,P,N,4
CPHY:	MIns	CMP.B,D7,A1,1,T,N,4
CPLY:	MOVE.W	A1,D1
	MIns	CMP.B,D7,D1,0,T,N,4

; --------------------------------------------------------------
LDMHL2:	MLDRR	D4,M,9,20
LDHLM2:	MLDRR	D4,M,8,20
; --------------------------------------------------------------

;	-------------------
;	Instrucciones R-800
;	-------------------

MULUBAB:
	MOVE.W	D5,D4
	LSR.W	#8,D4
	MULU	D7,D4
	OtraT	8

MULUBAC:
	MOVEQ	#0,D4
	MOVE.B	D5,D4
	MULU	D7,D4
	OtraT	8

MULUBAD:
	MOVE.W	D6,D4
	LSR.W	#8,D4
	MULU	D7,D4
	OtraT	8

MULUBAE:
	MOVEQ	#0,D4
	MOVE.B	D6,D4
	MULU	D7,D4
	OtraT	8

MULUWHLBC:
	MULU	D5,D4
	MOVE.W	CCR,D3
	SWAP	D4
	MOVE.W	D4,D6
	CLR.W	D4
	SWAP	D4
	Otra	8

MULUWHLSP:
	MULU	D0,D4
	MOVE.W	CCR,D3
	SWAP	D4
	MOVE.W	D4,D6
	CLR.W	D4
	SWAP	D4
	Otra	8

IINFC:	MINC	D1,0,12

; --------------------------------------------------------------

; --------------------------------------------------------------

RInsCB:	MOVE.B	(A5)+,D2
	SUBQ.W	#1,(A3)			; Prefix: its own M1 wait.
	JMP	([InsCB-$400.W,PC,D2.W*4])	; Salta a puntero de emulaci�n.
	CNOP	0,4
CB00:
	CMP.L	Desbor+4(A7),A5
	BGT.S	CB00C
	Otra	4
CB00C:	SUBQ.W	#1,(A3)			; Prefix: its own M1 wait.
	SUBQ.W	#1,A5
	MOVE.W	A5,D1
	SUB.W	(A7),D1
	CogePag	D1,A5
	LEA	Restas(A3,D1.W*8),A7
	MOVE.B	(A5)+,D2
	JMP	([InsCB-$400.W,PC,D2.W*4])	; Salta a puntero de emulaci�n.


	CNOP	0,4
RInsDD:	MOVE.B	(A5)+,D2
	SUBQ.W	#1,(A3)			; Prefix: its own M1 wait.
	JMP	([InsDD-$400.W,PC,D2.W*4])	; Salta a puntero de emulaci�n.
	CNOP	0,4
DD00:
	CMP.L	Desbor+4(A7),A5
	BGT.S	DD00C
	Otra	4
DD00C:	SUBQ.W	#1,(A3)			; Prefix: its own M1 wait.
	SUBQ.W	#1,A5
	MOVE.W	A5,D1
	SUB.W	(A7),D1
	CogePag	D1,A5
	LEA	Restas(A3,D1.W*8),A7
	MOVE.B	(A5)+,D2
	JMP	([InsDD-$400.W,PC,D2.W*4])	; Salta a puntero de emulaci�n.


	CNOP	0,4
RInsED:	MOVE.B	(A5)+,D2
	SUBQ.W	#1,(A3)			; Prefix: its own M1 wait.
	JMP	([InsED-$400.W,PC,D2.W*4])	; Salta a puntero de emulaci�n.
	CNOP	0,4
ED00:
	CMP.L	Desbor+4(A7),A5
	BGT.S	ED00C
	Otra	4
ED00C:	SUBQ.W	#1,(A3)			; Prefix: its own M1 wait.
	SUBQ.W	#1,A5
	MOVE.W	A5,D1
	SUB.W	(A7),D1
	CogePag	D1,A5
	LEA	Restas(A3,D1.W*8),A7
	MOVE.B	(A5)+,D2
	JMP	([InsED-$400.W,PC,D2.W*4])	; Salta a puntero de emulaci�n.


	CNOP	0,4
RInsFD:	MOVE.B	(A5)+,D2
	SUBQ.W	#1,(A3)			; Prefix: its own M1 wait.
	JMP	([InsFD-$400.W,PC,D2.W*4])	; Salta a puntero de emulaci�n.
	CNOP	0,4
FD00:
	CMP.L	Desbor+4(A7),A5
	BGT.S	FD00C
	Otra	4
FD00C:	SUBQ.W	#1,(A3)			; Prefix: its own M1 wait.
	SUBQ.W	#1,A5
	MOVE.W	A5,D1
	SUB.W	(A7),D1
	CogePag	D1,A5
	LEA	Restas(A3,D1.W*8),A7
	MOVE.B	(A5)+,D2
	JMP	([InsFD-$400.W,PC,D2.W*4])	; Salta a puntero de emulaci�n.


	CNOP	0,4
RInsCBIX:
	MOVE.B	(A5)+,D1
	EXT.W	D1
	MOVE.B	(A5)+,D2
	JMP	([InsCBIX-$400.W,PC,D2.W*4])	; Salta a puntero de emulaci�n.
	CNOP	0,4
CBX0:
	CMP.L	Desbor+4(A7),A5
	BGT.S	CBX0C
	Otra	4
CBX0C:
	LSL.W	#8,D1
	MOVE.B	D2,D1
	CheckW	D1
	MOVE.B	D1,D2
	LSR.W	#8,D1
	EXT.W	D1
	JMP	([InsCBIX-$400.W,PC,D2.W*4])	; Salta a puntero de emulaci�n.


	CNOP	0,4
RInsCBIY:
	MOVE.B	(A5)+,D1
	EXT.W	D1
	MOVE.B	(A5)+,D2
	JMP	([InsCBIY-$400.W,PC,D2.W*4])	; Salta a puntero de emulaci�n.
	CNOP	0,4
CBY0:
	CMP.L	Desbor+4(A7),A5
	BGT.S	CBY0C
	Otra	4
CBY0C:
	LSL.W	#8,D1
	MOVE.B	D2,D1
	CheckW	D1
	MOVE.B	D1,D2
	LSR.W	#8,D1
	EXT.W	D1
	JMP	([InsCBIY-$400.W,PC,D2.W*4])	; Salta a puntero de emulaci�n.


	CNOP	0,4
; RRD/RLD read (HL) through the page's read pointer and write the result
; through its write pointer: on ROM the write goes to the NORAM dummy, as a
; real Z80's write is ignored. Both through the write pointer, ROM read as
; zero: Ianna rotates its hero graphics straight out of ROM, and every second
; pixel came out 0 (transparent), the hero in stripes.
IRRD:
	CogePag	D4,A4
	MOVE.B	D7,D1
	LSL.W	#8,D1
	MOVE.B	D3,D2		; Flag S
	MOVE.B	(A4),D1
	AND.W	#$0FFF,D1
	ROR.W	#4,D1
	MOVE.B	D1,RxDNew	; New (HL).
	SF	D1
	ROL.W	#4,D1
	AND.B	#$F0,D7
	OR.B	D1,D7
	MOVE.W	CCR,D3
	BFINS	D2,D3{31:1}
	CogePagE D4,A4
	MOVE.B	RxDNew,(A4)
	Otra	12

IRLD:
	CogePag	D4,A4
	MOVEQ	#0,D1
	MOVE.B	(A4),D1
	MOVE.B	D3,D2		; Flag S
	MOVE.B	D7,RxDNew
	AND.B	#$0F,RxDNew
	LSL.W	#4,D1
	OR.B	D1,RxDNew	; New (HL).
	LSR.W	#8,D1
	AND.B	#$F0,D7
	OR.B	D1,D7
	MOVE.W	CCR,D3
	BFINS	D2,D3{31:1}
	CogePagE D4,A4
	MOVE.B	RxDNew,(A4)
	Otra	12

RxDNew:	DC.B	0
	EVEN


INI:
	MOVE.B	D5,D2
	JSR	([Ins-$400.W,PC,D2.W*4])	; Salta a puntero de emulaci�n.
	MOVE.B	D1,D2
	CogePagE D4,A4
	MOVE.B	D2,(A4)
	ADDQ.W	#1,D4
	SUBBZ	2
	Otra	16

IND:
	MOVE.B	D5,D2
	JSR	([Ins-$400.W,PC,D2.W*4])	; Salta a puntero de emulaci�n.
	MOVE.B	D1,D2
	CogePagE D4,A4
	MOVE.B	D2,(A4)
	SUBQ.W	#1,D4
	SUBBZ	2
	Otra	16

OUTI:
	CogePag	D4,A4
	ADDQ.W	#1,D4
	MOVE.B	D5,D2
	SUB.W	D2,D5
	BEQ.S	OUTIfZ
	AND.B	#$FB,D3
	MOVE.B	D2,D5
	MOVE.B	(A4),D1
	JSR	([OUTS-$400.W,PC,D2.W*4])	; Salta a puntero de emulaci�n.
	Otra	16
OUTIfZ:
	OR.B	#$04,D3
	MOVE.B	D2,D5
	MOVE.B	(A4),D1
	JSR	([OUTS-$400.W,PC,D2.W*4])	; Salta a puntero de emulaci�n.
	Otra	16

OUTD:
	CogePag	D4,A4
	SUBQ.W	#1,D4
	MOVE.B	D5,D2
	SUB.W	D2,D5
	BEQ.S	OUTDfZ
	AND.B	#$FB,D3
	MOVE.B	D2,D5
	MOVE.B	(A4),D1
	JSR	([OUTS-$400.W,PC,D2.W*4])	; Salta a puntero de emulaci�n.
	Otra	16
OUTDfZ:
	OR.B	#$04,D3
	MOVE.B	D2,D5
	MOVE.B	(A4),D1
	JSR	([OUTS-$400.W,PC,D2.W*4])	; Salta a puntero de emulaci�n.
	Otra	16

INIR:
	MOVE.W	D5,D1
	LSR.W	#8,D1
	MULU	#23,D1			; B*(21+2) - 12, + the final Otra 5:
	SUB.W	#12,D1			; (B-1)*23 + 18 as on the MSX.
	SUB.W	D1,(A3)			; * Resta Cycles *

	MOVE.B	D5,D2
INIRB:
	JSR	([Ins-$400.W,PC,D2.W*4])	; Salta a puntero de emulaci�n.
	MOVE.B	D1,D2
	CogePagE D4,A4
	MOVE.B	D2,(A4)
	ADDQ.W	#1,D4
	MOVE.B	D5,D2
	SUB.W	D2,D5
	BEQ.S	INIRF
	MOVE.B	D2,D5
	BRA.S	INIRB
INIRF:	MOVE.B	D2,D5
	OR.B	#$04,D3		; Flag Z a 'ON'
	Otra	5

INDR:
	MOVE.W	D5,D1
	LSR.W	#8,D1
	MULU	#23,D1			; B*(21+2) - 12, + the final Otra 5:
	SUB.W	#12,D1			; (B-1)*23 + 18 as on the MSX.
	SUB.W	D1,(A3)			; * Resta Cycles *

	MOVE.B	D5,D2
INDRB:
	JSR	([Ins-$400.W,PC,D2.W*4])	; Salta a puntero de emulaci�n.
	MOVE.B	D1,D2
	CogePagE D4,A4
	MOVE.B	D2,(A4)
	SUBQ.W	#1,D4
	MOVE.B	D5,D2
	SUB.W	D2,D5
	BEQ.S	INDRF
	MOVE.B	D2,D5
	BRA.S	INDRB
INDRF:	MOVE.B	D2,D5
	OR.B	#$04,D3		; Flag Z a 'ON'
	Otra	5


OTIR:
	MOVE.W	D5,D1
	LSR.W	#8,D1
	MULU	#23,D1			; B*(21+2) - 12, + the final Otra 5:
	SUB.W	#12,D1			; (B-1)*23 + 18 as on the MSX.
	SUB.W	D1,(A3)			; * Resta Cycles *

	MOVE.B	D5,D2
OTIRCon:
	MOVE.B	D2,D5
	CogePag	D4,A4
	MOVE.B	(A4),D1
	JSR	([OUTS-$400.W,PC,D2.W*4])	; Salta a puntero de emulaci�n.
	ADDQ.W	#1,D4
	MOVE.B	D5,D2
	SUB.W	D2,D5
	BNE.S	OTIRCon
	OR.B	#$04,D3		; Flag Z a 'ON'
	MOVE.B	D2,D5
	Otra	5

OTDR:
	MOVE.W	D5,D1
	LSR.W	#8,D1
	MULU	#23,D1			; B*(21+2) - 12, + the final Otra 5:
	SUB.W	#12,D1			; (B-1)*23 + 18 as on the MSX.
	SUB.W	D1,(A3)			; * Resta Cycles *

	MOVE.B	D5,D2
OTDRCon:
	MOVE.B	D2,D5
	CogePag	D4,A4
	MOVE.B	(A4),D1
	JSR	([OUTS-$400.W,PC,D2.W*4])	; Salta a puntero de emulaci�n.
	SUBQ.W	#1,D4
	MOVE.B	D5,D2
	SUB.W	D2,D5
	BNE.S	OTDRCon
	OR.B	#$04,D3		; Flag Z a 'ON'
	MOVE.B	D2,D5
	Otra	5


LDI:
	CogePag	D4,A4
	MOVE.B	(A4),D2
	CogePagE D6,A4
	MOVE.B	D2,(A4)
	ADDQ.W	#1,D4
	ADDQ.W	#1,D6
	SUBQ.W	#1,D5
	OtraV	16

LDD:
	CogePag	D4,A4
	MOVE.B	(A4),D2
	CogePagE D6,A4
	MOVE.B	D2,(A4)
	SUBQ.W	#1,D4
	SUBQ.W	#1,D6
	SUBQ.W	#1,D5
	OtraV	16


LDIR:
	MOVEQ	#0,D1
	MOVE.W	D5,D1
	MULU.L	#23,D1			; BC*(21+2) - 12, + the final Otra 5,
	SUB.L	#12,D1			; at most $7000 (~125 lines: the
	CMP.L	#$7000,D1		; counter is a word).
	BLS.S	BlkCyc1
	MOVE.L	#$7000,D1
BlkCyc1:
	SUB.W	D1,(A3)			; * Resta Cycles *

	MOVE.L	A0,-(SP)
	SUBQ.W	#1,D5
	CogePag	D4,A0
	CogePagE D6,A4
LDIRBUC:MOVE.B	(A0)+,(A4)+
	ADDQ.B	#1,D4
	BCS.S	LDIRD0
LDIRC0:	ADDQ.B	#1,D6
	DBCS	D5,LDIRBUC
	CMPI.W	#-1,D5
	BEQ.S	LDIRC1
	ADDI.W	#$100,D6
	CogePagE D6,A4
	DBF	D5,LDIRBUC
LDIRC1:	MOVEQ	#0,D5
	MOVE.L	(SP)+,A0
	AND.B	#$FD,D3		; Flag V a 'OFF'
	Otra	5
LDIRD0:	ADDI.W	#$100,D4
	CogePag	D4,A0
	BRA.S	LDIRC0
	CNOP	0,4


LDDR:
	MOVEQ	#0,D1
	MOVE.W	D5,D1
	MULU.L	#23,D1			; BC*(21+2) - 12, + the final Otra 5,
	SUB.L	#12,D1			; at most $7000 (~125 lines: the
	CMP.L	#$7000,D1		; counter is a word).
	BLS.S	BlkCyc2
	MOVE.L	#$7000,D1
BlkCyc2:
	SUB.W	D1,(A3)			; * Resta Cycles *

	MOVE.L	A0,-(SP)
	SUBQ.W	#1,D5
	CogePag	D4,A0
	ADDQ.W	#1,A0
	CogePagE D6,A4
	ADDQ.W	#1,A4
LDDRBUC:MOVE.B	-(A0),-(A4)
	SUBQ.B	#1,D4
	BCS.S	LDDRD0
LDDRC0:	SUBQ.B	#1,D6
	DBCS	D5,LDDRBUC
	CMPI.W	#-1,D5
	BEQ.S	LDDRC1
	SUBI.W	#$100,D6
	CogePagE D6,A4
	ADDQ.W	#1,A4
	DBF	D5,LDDRBUC
LDDRC1:	MOVEQ	#0,D5
	MOVE.L	(SP)+,A0
	AND.B	#$FD,D3		; Flag V a 'OFF'
	Otra	5
LDDRD0:	SUBI.W	#$100,D4
	CogePag	D4,A0
	ADDQ.W	#1,A0
	BRA.S	LDDRC0
	CNOP	0,4



CPIR:
	SUBQ.W	#1,D5
CPIRB:
	CogePag	D4,A4
	CMP.B	(A4),D7
	BEQ.S	CPIR0
	ADDQ.W	#1,D4
	DBF	D5,CPIRB
	MOVEQ	#0,D5
	AND.B	#$F9,D3
	Otra	16
CPIR0:	OR.B	#$06,D3
	ADDQ.W	#1,D4
	Otra	16

CPI:
	CogePag	D4,A4
	CMP.B	(A4),D7
	BEQ.S	CPI0
	AND.B	#$FB,D3
	ADDQ.W	#1,D4
	SUBQ.W	#1,D5
	OtraV	16
CPI0:	OR.B	#$04,D3
	ADDQ.W	#1,D4
	SUBQ.W	#1,D5
	OtraV	16

CPDR:
	SUBQ.W	#1,D5
CPDRB:
	CogePag	D4,A4
	CMP.B	(A4),D7
	BEQ.S	CPDR0
	SUBQ.W	#1,D4
	DBF	D5,CPDRB
	MOVEQ	#0,D5
	AND.B	#$F9,D3
	Otra	16
CPDR0:	OR.B	#$06,D3
	SUBQ.W	#1,D4
	Otra	16

ICPD:
	CogePag	D4,A4
	CMP.B	(A4),D7
	BEQ.S	CPD0
	AND.B	#$FB,D3
	SUBQ.W	#1,D4
	SUBQ.W	#1,D5
	OtraV	16
CPD0:	OR.B	#$04,D3
	SUBQ.W	#1,D4
	SUBQ.W	#1,D5
	OtraV	16

; ------------------------------------------------------------------


; -========================================================-

LDHLBd:	MLDRR	D4,D5,11d,1
LDHLCd:	MLDRR	D4,D5,10d,1
LDHLDd:	MLDRR	D4,D6,11d,1
LDHLEd:	MLDRR	D4,D6,10d,1
LDHLHd:	MLDRR	D4,D4,11d,1
LDHLLd:	MLDRR	D4,D4,10d,1

LDHLMNd:CogePagE D4,A4
	MOVE.B	(A5)+,(A4)
	BEQ.S	LDHLMN0d
	JMP	([PagRuts.W,PC,D1.W*4])
	CNOP	0,4
LDHLMN0d:MOVE.B	D1,D2
	CheckB	(A4)
	JMP	([PagRuts-$400.W,PC,D2.W*4])

LDHLAd:	MLDRR	D4,D7,10d,1
LDBCAd:	MLDRR	D5,D7,10d,1
LDDEAd:	MLDRR	D6,D7,10d,1

LDMAd:	MOVE.W	(A5)+,D1
	TST.B	D1
	BEQ.S	LDMAMd
	ROR.W	#8,D1
	CogePagE D1,A4
	MOVE.B	D7,(A4)
	JMP	([PagRuts.W,PC,D1.W*4])
	CNOP	0,4
LDMAMd:	CheckW	D1
	ROR.W	#8,D1
	CogePagE D1,A4
	MOVE.B	D7,(A4)
	JMP	([PagRuts.W,PC,D1.W*4])

; -========================================================-


	CNOP	0,4
RutRelen:
	IFEQ	Key_ON
	LEA	$804(A3),A2
	MOVE.L	([A0,$538.W],$30.W),A0
	JSR	Cambio
	ENDC


	MOVE.W	VELOCID,D0

	MOVEQ	#0,D1
	MOVE.W	D0,D1
	SUBQ.W	#6,D0
	BCC.S	RelenTipo1
	LSL.W	#1,D1
	BEQ.S	NoRelen
	ADDQ.W	#2,D1
NoRelen:LEA	Instr,A0
	MOVE.W	#256-1,D0
BucRelen0:
	MOVE.L	4(A0,D0.W*8),(A0,D0.W*8)
	SUB.L	D1,(A0,D0.W*8)
	DBF	D0,BucRelen0
	RTS
RelenTipo1:
	SUB.W	#13,D0
	BCC.S	RelenTipo2
	SUBQ.W	#6,D1
	MOVE.L	(TablaRelen.W,PC,D1.W*4),A1
	LEA	Instr,A0
	MOVE.W	#256-1,D0
BucRelen1:
	MOVE.L	A1,(A0,D0.W*8)
	DBF	D0,BucRelen1
	RTS
RelenTipo2:
	SUB.W	#6+13,D1
	MOVE.W	D1,VELOCID
	LEA	Relentizar2,A1
	LEA	Instr,A0
	MOVE.W	#256-1,D0
BucRelen2:
	MOVE.L	A1,(A0,D0.W*8)
	DBF	D0,BucRelen2
	RTS

	CNOP	0,4
TablaRelen:
	DC.L	Relentizar+(12*2)
	DC.L	Relentizar+(11*2)
	DC.L	Relentizar+(10*2)
	DC.L	Relentizar+(09*2)
	DC.L	Relentizar+(08*2)
	DC.L	Relentizar+(07*2)
	DC.L	Relentizar+(06*2)
	DC.L	Relentizar+(05*2)
	DC.L	Relentizar+(04*2)
	DC.L	Relentizar+(03*2)
	DC.L	Relentizar+(02*2)
	DC.L	Relentizar+(01*2)
	DC.L	Relentizar+(00*2)

	CNOP	0,8
Relentizar:
	REPT	12
	NOP
	ENDR
	JMP	([4.W,A3,D2.W*8])

	CNOP	0,8
Relentizar2:
	MOVE.W	D1,-(SP)
	MOVE.W	Relen(A3),D1
RelBuc:	DBF	D1,RelBuc
	MOVE.W	(SP)+,D1
	JMP	([4.W,A3,D2.W*8])

;   ---------------------------------------------------------------------
;  -=====================================================================-
; <***********************************************************************>
;  -=====================================================================-
;   ---------------------------------------------------------------------



;	 -----------------------------
;	- Puertos de Entrada y Salida -
;	 -----------------------------


; -------------------------------
	CNOP	0,8
InXX:	ST	D1
	RTS
; -------------------------------
	CNOP	0,8
INA9:
	MOVE.B	PAA(A3),D1
	AND.W	#$0F,D1
	MOVE.B	KEY(A3,D1.W),D1
	RTS

; -------------------------------
	CNOP	0,8
INAA:
	MOVE.B	PAA(A3),D1
	RTS

	CNOP	0,8
OUTAA:
	MOVE.B	D1,PAA(A3)
	RTS

; -------------------------------
	CNOP	0,8
OUTAB:
	CMP.B	#$0C,D1
	BNE.S	NoEsCaps0
	BCLR	#6,PAA(A3)
	RTS
NoEsCaps0:
	CMP.B	#$0D,D1
	BNE.S	NoEsCaps1
	BSET	#6,PAA(A3)
	RTS
NoEsCaps1:

	TST.B	SFXCHIP
	BNE.S	OUTABR

	MOVE.B	PSG+7(A3),D2
	AND.B	#%00111000,D2
	EOR.B	#%00111000,D2
	BNE.S	OUTABR
	MOVE.L	#ONDA1,$DFF0D0	; ** Cuando no hay ruido **
	MOVE.W	#1,$DFF0D4
	MOVE.W	#1,$DFF0D6
	LSR.B	#1,D1
	BCS.S	SUENA1
	MOVE.W	#0,$DFF0D8
OUTABR:	RTS
SUENA1:
	MOVE.W	#50,$DFF0D8
	RTS

; -------------------------------
	CNOP	0,8
INA0:
	ST	D1
	RTS

	CNOP	0,8
INA1:
	ST	D1
	RTS

	CNOP	0,8
OUTA0:
	MOVE.B	D1,DA0(A3)
	RTS

	CNOP	0,8
OUTA1:
	MOVE.B	D1,D2
	MOVE.B	DA0(A3),D1
	AND.W	#$000F,D1
	MOVE.B	D2,PSG(A3,D1.W)
	JMP	([SOUND.W,PC,D1.W*4])
	RTS

	CNOP	0,8
OUTA1S:
	MOVE.B	D1,D2
	MOVE.B	DA0(A3),D1
	AND.W	#$000F,D1
	CMPI.W	#$F,D1
	BNE.S	ESSCC3
	MOVE.B	D2,PSG(A3,D1.W)
	JMP	([SOUND.W,PC,D1.W*4])
ESSCC3:	RTS


	CNOP	0,8
SOUND:
	DC.L	SOUND0
	DC.L	SOUND1
	DC.L	SOUND2
	DC.L	SOUND3
	DC.L	SOUND4
	DC.L	SOUND5
	DC.L	SOUND6
	DC.L	SOUND7
	DC.L	SOUND8
	DC.L	SOUND9
	DC.L	SOUND10
	DC.L	SOUND11
	DC.L	SOUND12
	DC.L	SOUND13
	DC.L	SOUND14
	DC.L	SOUND15
; -------------------------------

	CNOP	0,8
INA2:
	MOVE.B	DA0(A3),D1
	AND.W	#$000F,D1
	CMP.B	#$0E,D1
	BEQ.S	ESLEERJOY
	MOVE.B	PSG(A3,D1.W),D1
	RTS
ESLEERJOY:
	BTST	#6,PSG+$F(A3)
	BNE.S	ES_PORT2B
	MOVE.B	DATOJOY1(A3),D1
	RTS
ES_PORT2B:
	MOVE.B	DATOJOY2(A3),D1
	RTS

; -------------------------------
	CNOP	0,8
DOS2MAP:
	NOINT
	MOVE.B	D7,D1
	AND.W	#$03,D1
	LEA	DOS2MAPPER(PC),A4
	MOVE.L	0(A4,D1.W*8),SLOTS+$40+(1*8)+00(A3)
	MOVE.L	4(A4,D1.W*8),SLOTS+$40+(1*8)+04(A3)
	MOVE.W	2(A4,D1.W*8),SLOTSR+$12(A3)

	MOVE.L	0(A4,D1.W*8),SubSLOTS+$40+(1*8)+00(A3)
	MOVE.L	4(A4,D1.W*8),SubSLOTS+$40+(1*8)+04(A3)
	MOVE.W	2(A4,D1.W*8),SubSLOTSR+$12(A3)

	MOVE.B	DA8(A3),D2

	SUB.W	(A7),A5			<-- Cuidado.

	BFEXTU	D2{28:2},D1
	LSL.B	#2,D1
	LEA	SLOTS(A3),A3		<-- Cuidado. A3 Modificado.
	MOVE.W	-$1E(A3,D1.W*2),RESTA1+0-SLOTS(A3)
	MOVE.L	(1*8)+4(A3,D1.W*8),PagWrite+8+0-SLOTS(A3)

	MOVE.L	(1*8)+0(A3,D1.W*8),A4
	MOVE.L	A4,PagRead+8+0-SLOTS(A3)
	ADD.W	#$4001,A4
	MOVE.L	A4,RESTA1+0+Desbor-SLOTS(A3)
	ADD.W	#$8000-$4001,A4
	MOVE.L	A4,RESTA1+0+Desbor+4-SLOTS(A3)

	LEA	SubSlots-SLOTS(A3),A3		<-- Cuidado. A3 Modificado.
	MOVE.W	-$1E(A3,D1.W*2),RESTA1+8-SubSLOTS(A3)
	MOVE.L	(1*8)+4(A3,D1.W*8),PagWrite+8+4-SubSLOTS(A3)

	MOVE.L	(1*8)+0(A3,D1.W*8),A4
	MOVE.L	A4,PagRead+8+4-SubSLOTS(A3)
	ADD.W	#$4001,A4
	MOVE.L	A4,RESTA1+8+Desbor-SubSLOTS(A3)
	ADD.W	#$8000-$4001,A4
	MOVE.L	A4,RESTA1+8+Desbor+4-SubSLOTS(A3)

	LEA	Regs,A3

	MOVE.W	A5,D1
	CogePag	D1,A5

	MOVE.W	D0,D1
	CogePagE D1,A6

	SIINT
	Otra2

	CNOP	0,8
DOS2MAPPER:
	DC.L	DISK2+($4000*0)-$4000,NORAM-$4000
	DC.L	DISK2+($4000*1)-$4000,NORAM-$4000
	DC.L	DISK2+($4000*2)-$4000,NORAM-$4000
	DC.L	DISK2+($4000*3)-$4000,NORAM-$4000

; -------------------------------

	CNOP	0,8
INA8:
	MOVE.B	DA8(A3),D1
	RTS

	CNOP	0,8
INFC:	MOVE.B	DFC(A3),D1
	OR.B	MMOR(A3),D1
	RTS
	CNOP	0,8
INFD:	MOVE.B	DFD(A3),D1
	OR.B	MMOR(A3),D1
	RTS
	CNOP	0,8
INFE:	MOVE.B	DFE(A3),D1
	OR.B	MMOR(A3),D1
	RTS
	CNOP	0,8
INFF:	MOVE.B	DFF(A3),D1
	OR.B	MMOR(A3),D1
	RTS


	CNOP	0,8
OUTFC:
	NOINT
	AND.W	MMAND(A3),D1
	MOVE.B	D1,DFC(A3)
	LEA	MEMORYMAPPER(PC),A4
	MOVE.L	0(A4,D1.W*8),SLOTS+$60+(0*8)+00(A3)
	MOVE.L	4(A4,D1.W*8),SLOTS+$60+(0*8)+04(A3)
	MOVE.W	2(A4,D1.W*8),SLOTSR+$18(A3)

	MOVE.L	0(A4,D1.W*8),SubSLOTS+$60+(0*8)+00(A3)
	MOVE.L	4(A4,D1.W*8),SubSLOTS+$60+(0*8)+04(A3)
	MOVE.W	2(A4,D1.W*8),SubSLOTSR+$18(A3)

	MOVE.B	DA8(A3),D2
	BFEXTU	D2{30:2},D1
	CMP.B	#3,D1
	BEQ.S	OutFCcon
	SIINT
	RTS
OutFCcon:
	SUB.W	4(A7),A5			<-- Cuidado.

	LEA	SLOTS(A3),A3		<-- Cuidado. A3 Modificado.
	LSL.B	#2,D1
	MOVE.W	-$20(A3,D1.W*2),RESTA0+0-SLOTS(A3)
	MOVE.W	-$20(A3,D1.W*2),RESTA0+8-SLOTS(A3)
	MOVE.L	(0*8)+4(A3,D1.W*8),PagWrite+0+0-SLOTS(A3)
	MOVE.L	(0*8)+4(A3,D1.W*8),PagWrite+0+4-SLOTS(A3)

	MOVE.L	(0*8)+0(A3,D1.W*8),A4
	MOVE.L	A4,PagRead+0+0-SLOTS(A3)
	MOVE.L	A4,PagRead+0+4-SLOTS(A3)
	ADDQ.W	#$0001,A4
	MOVE.L	A4,RESTA0+0+Desbor-SLOTS(A3)
	MOVE.L	A4,RESTA0+8+Desbor-SLOTS(A3)
	ADD.W	#$4000-$0001,A4
	MOVE.L	A4,RESTA0+0+Desbor+4-SLOTS(A3)
	MOVE.L	A4,RESTA0+8+Desbor+4-SLOTS(A3)

	LEA	Regs,A3

	MOVE.W	A5,D1
	CogePag	D1,A5

	MOVE.W	D0,D1
	CogePagE D1,A6

	SIINT
	RTS


	CNOP	0,8
OUTFD:
	NOINT
	AND.W	MMAND(A3),D1
	MOVE.B	D1,DFD(A3)
	LEA	MEMORYMAPPER(PC),A4
	MOVE.L	0(A4,D1.W*8),SLOTS+$60+(1*8)+00(A3)
	MOVE.L	4(A4,D1.W*8),SLOTS+$60+(1*8)+04(A3)
	SUB.L	#$4000,SLOTS+$60+(1*8)+00(A3)
	SUB.L	#$4000,SLOTS+$60+(1*8)+04(A3)
	MOVE.W	2(A4,D1.W*8),SLOTSR+$1A(A3)
	SUB.W	#$4000,SLOTSR+$1A(A3)

	MOVE.L	0(A4,D1.W*8),SubSLOTS+$60+(1*8)+00(A3)
	MOVE.L	4(A4,D1.W*8),SubSLOTS+$60+(1*8)+04(A3)
	SUB.L	#$4000,SubSLOTS+$60+(1*8)+00(A3)
	SUB.L	#$4000,SubSLOTS+$60+(1*8)+04(A3)
	MOVE.W	2(A4,D1.W*8),SubSLOTSR+$1A(A3)
	SUB.W	#$4000,SubSLOTSR+$1A(A3)

	MOVE.B	DA8(A3),D2
	BFEXTU	D2{28:2},D1
	CMP.B	#3,D1
	BEQ.S	OutFDcon
	SIINT
	RTS
OutFDcon:
	SUB.W	4(A7),A5			<-- Cuidado.

	LEA	SLOTS(A3),A3		<-- Cuidado. A3 Modificado.
	LSL.B	#2,D1
	MOVE.W	-$1E(A3,D1.W*2),RESTA1+0-SLOTS(A3)
	MOVE.W	-$1E(A3,D1.W*2),RESTA1+8-SLOTS(A3)
	MOVE.L	(1*8)+4(A3,D1.W*8),PagWrite+8+0-SLOTS(A3)
	MOVE.L	(1*8)+4(A3,D1.W*8),PagWrite+8+4-SLOTS(A3)

	MOVE.L	(1*8)+0(A3,D1.W*8),A4
	MOVE.L	A4,PagRead+8+0-SLOTS(A3)
	MOVE.L	A4,PagRead+8+4-SLOTS(A3)
	ADD.W	#$4001,A4
	MOVE.L	A4,RESTA1+0+Desbor-SLOTS(A3)
	MOVE.L	A4,RESTA1+8+Desbor-SLOTS(A3)
	ADD.W	#$8000-$4001,A4
	MOVE.L	A4,RESTA1+0+Desbor+4-SLOTS(A3)
	MOVE.L	A4,RESTA1+8+Desbor+4-SLOTS(A3)

	LEA	Regs,A3

	MOVE.W	A5,D1
	CogePag	D1,A5

	MOVE.W	D0,D1
	CogePagE D1,A6

	SIINT
	RTS


	CNOP	0,8
OUTFE:
	NOINT
	AND.W	MMAND(A3),D1
	MOVE.B	D1,DFE(A3)
	LEA	MEMORYMAPPER(PC),A4
	MOVE.L	0(A4,D1.W*8),SLOTS+$60+(2*8)+00(A3)
	MOVE.L	4(A4,D1.W*8),SLOTS+$60+(2*8)+04(A3)
	SUB.L	#$8000,SLOTS+$60+(2*8)+00(A3)
	SUB.L	#$8000,SLOTS+$60+(2*8)+04(A3)
	MOVE.W	2(A4,D1.W*8),SLOTSR+$1C(A3)
	SUB.W	#$8000,SLOTSR+$1C(A3)

	MOVE.L	0(A4,D1.W*8),SubSLOTS+$60+(2*8)+00(A3)
	MOVE.L	4(A4,D1.W*8),SubSLOTS+$60+(2*8)+04(A3)
	SUB.L	#$8000,SubSLOTS+$60+(2*8)+00(A3)
	SUB.L	#$8000,SubSLOTS+$60+(2*8)+04(A3)
	MOVE.W	2(A4,D1.W*8),SubSLOTSR+$1C(A3)
	SUB.W	#$8000,SubSLOTSR+$1C(A3)

	MOVE.B	DA8(A3),D2
	BFEXTU	D2{26:2},D1
	CMP.B	#3,D1
	BEQ.S	OutFEcon
	SIINT
	RTS
OutFEcon:
	SUB.W	4(A7),A5			<-- Cuidado.

	LEA	SLOTS(A3),A3		<-- Cuidado. A3 Modificado.
	LSL.B	#2,D1
	MOVE.W	-$1C(A3,D1.W*2),RESTA2+0-SLOTS(A3)
	MOVE.W	-$1C(A3,D1.W*2),RESTA2+8-SLOTS(A3)
	MOVE.L	(2*8)+4(A3,D1.W*8),PagWrite+16+0-SLOTS(A3)
	MOVE.L	(2*8)+4(A3,D1.W*8),PagWrite+16+4-SLOTS(A3)

	MOVE.L	(2*8)+0(A3,D1.W*8),A4
	MOVE.L	A4,PagRead+16+0-SLOTS(A3)
	MOVE.L	A4,PagRead+16+4-SLOTS(A3)
	ADD.L	#$8001,A4
	MOVE.L	A4,RESTA2+0+Desbor-SLOTS(A3)
	MOVE.L	A4,RESTA2+8+Desbor-SLOTS(A3)
	ADD.W	#$C000-$8001,A4
	MOVE.L	A4,RESTA2+0+Desbor+4-SLOTS(A3)
	MOVE.L	A4,RESTA2+8+Desbor+4-SLOTS(A3)

	LEA	Regs,A3

	MOVE.W	A5,D1
	CogePag	D1,A5

	MOVE.W	D0,D1
	CogePagE D1,A6

	SIINT
	RTS


	CNOP	0,8
OUTFF:
	NOINT
	AND.W	MMAND(A3),D1
	MOVE.B	D1,DFF(A3)
	LEA	MEMORYMAPPER(PC),A4
	MOVE.L	0(A4,D1.W*8),SLOTS+$60+(3*8)+00(A3)
	MOVE.L	4(A4,D1.W*8),SLOTS+$60+(3*8)+04(A3)
	SUB.L	#$C000,SLOTS+$60+(3*8)+00(A3)
	SUB.L	#$C000,SLOTS+$60+(3*8)+04(A3)
	MOVE.W	2(A4,D1.W*8),SLOTSR+$1E(A3)
	SUB.W	#$C000,SLOTSR+$1E(A3)

	MOVE.L	0(A4,D1.W*8),SubSLOTS+$60+(3*8)+00(A3)
	MOVE.L	4(A4,D1.W*8),SubSLOTS+$60+(3*8)+04(A3)
	SUB.L	#$C000,SubSLOTS+$60+(3*8)+00(A3)
	SUB.L	#$C000,SubSLOTS+$60+(3*8)+04(A3)
	MOVE.W	2(A4,D1.W*8),SubSLOTSR+$1E(A3)
	SUB.W	#$C000,SubSLOTSR+$1E(A3)

	MOVE.B	DA8(A3),D2
	BFEXTU	D2{24:2},D1
	CMP.B	#3,D1
	BEQ.S	OutFFcon
	SIINT
	RTS
OutFFcon:
	SUB.W	4(A7),A5			<-- Cuidado.

	LEA	SLOTS(A3),A3		<-- Cuidado. A3 Modificado.
	LSL.B	#2,D1
	MOVE.W	-$1A(A3,D1.W*2),RESTA3+0-SLOTS(A3)
	MOVE.W	-$1A(A3,D1.W*2),RESTA3+8-SLOTS(A3)
	MOVE.L	(3*8)+4(A3,D1.W*8),PagWrite+24+0-SLOTS(A3)
	MOVE.L	(3*8)+4(A3,D1.W*8),PagWrite+24+4-SLOTS(A3)

	MOVE.L	(3*8)+0(A3,D1.W*8),A4
	MOVE.L	A4,PagRead+24+0-SLOTS(A3)
	MOVE.L	A4,PagRead+24+4-SLOTS(A3)
	ADD.L	#$C001,A4
	MOVE.L	A4,RESTA3+0+Desbor-SLOTS(A3)
	MOVE.L	A4,RESTA3+8+Desbor-SLOTS(A3)
	ADD.W	#$10000-$C001,A4
	MOVE.L	A4,RESTA3+0+Desbor+4-SLOTS(A3)
	MOVE.L	A4,RESTA3+8+Desbor+4-SLOTS(A3)

	LEA	Regs,A3

	MOVE.W	A5,D1
	CogePag	D1,A5

	MOVE.W	D0,D1
	CogePagE D1,A6

	SIINT
	RTS


	CNOP	0,8
OUTA8:
	NOINT
	MOVE.B	D1,D2
	MOVE.B	D2,DA8(A3)

	SUB.W	4(A7),A5			<-- Cuidado.

	BFEXTU	D2{30:2},D1
	LSL.B	#2,D1
	LEA	SLOTS(A3),A3		<-- Cuidado. A3 Modificado.	0-A
	MOVE.W	-$20(A3,D1.W*2),RESTA0+0-SLOTS(A3)
	MOVE.L	(0*8)+4(A3,D1.W*8),PagWrite+0+0-SLOTS(A3)

	MOVE.L	(0*8)+0(A3,D1.W*8),A4
	MOVE.L	A4,PagRead+0+0-SLOTS(A3)
	ADDQ.W	#$0001,A4
	MOVE.L	A4,RESTA0+0+Desbor-SLOTS(A3)
	ADD.W	#$2000-$0001,A4
	MOVE.L	A4,RESTA0+0+Desbor+4-SLOTS(A3)

	MOVE.L	($640-SLOTS.W,A3,D1.W*8),PagRuts+0


	LEA	SubSlots-SLOTS(A3),A3	<-- Cuidado. A3 Modificado.	0-B
	MOVE.W	-$20(A3,D1.W*2),RESTA0+8-SubSLOTS(A3)
	MOVE.L	(0*8)+4(A3,D1.W*8),PagWrite+0+4-SubSLOTS(A3)

	MOVE.L	(0*8)+0(A3,D1.W*8),A4
	MOVE.L	A4,PagRead+0+4-SubSLOTS(A3)
	ADD.W	#$2001,A4
	MOVE.L	A4,RESTA0+8+Desbor-SubSLOTS(A3)
	ADD.W	#$4000-$2001,A4
	MOVE.L	A4,RESTA0+8+Desbor+4-SubSLOTS(A3)

	MOVE.L	($644-SubSLOTS.W,A3,D1.W*8),PagRuts+4


	BFEXTU	D2{28:2},D1
	LSL.B	#2,D1
	LEA	Slots-SubSLOTS(A3),A3	<-- Cuidado. A3 Modificado.	1-A
	MOVE.W	-$1E(A3,D1.W*2),RESTA1+0-SLOTS(A3)
	MOVE.L	(1*8)+4(A3,D1.W*8),PagWrite+8+0-SLOTS(A3)

	MOVE.L	(1*8)+0(A3,D1.W*8),A4
	MOVE.L	A4,PagRead+8+0-SLOTS(A3)
	ADD.W	#$4001,A4
	MOVE.L	A4,RESTA1+0+Desbor-SLOTS(A3)
	ADD.W	#$6000-$4001,A4
	MOVE.L	A4,RESTA1+0+Desbor+4-SLOTS(A3)

	MOVE.L	($648-SLOTS.W,A3,D1.W*8),PagRuts+8


	LEA	SubSlots-SLOTS(A3),A3	<-- Cuidado. A3 Modificado.	1-B
	MOVE.W	-$1E(A3,D1.W*2),RESTA1+8-SubSLOTS(A3)
	MOVE.L	(1*8)+4(A3,D1.W*8),PagWrite+8+4-SubSLOTS(A3)

	MOVE.L	(1*8)+0(A3,D1.W*8),A4
	MOVE.L	A4,PagRead+8+4-SubSLOTS(A3)
	ADD.W	#$6001,A4
	MOVE.L	A4,RESTA1+8+Desbor-SubSLOTS(A3)
	ADD.W	#$8000-$6001,A4
	MOVE.L	A4,RESTA1+8+Desbor+4-SubSLOTS(A3)

	MOVE.L	($64C-SubSLOTS.W,A3,D1.W*8),PagRuts+$C


	BFEXTU	D2{26:2},D1
	LSL.B	#2,D1
	LEA	Slots-SubSLOTS(A3),A3	<-- Cuidado. A3 Modificado.	2-A
	MOVE.W	-$1C(A3,D1.W*2),RESTA2+0-SLOTS(A3)
	MOVE.L	(2*8)+4(A3,D1.W*8),PagWrite+16+0-SLOTS(A3)

	MOVE.L	(2*8)+0(A3,D1.W*8),A4
	MOVE.L	A4,PagRead+16+0-SLOTS(A3)
	ADD.L	#$8001,A4
	MOVE.L	A4,RESTA2+0+Desbor-SLOTS(A3)
	ADD.W	#$A000-$8001,A4
	MOVE.L	A4,RESTA2+0+Desbor+4-SLOTS(A3)

	MOVE.L	($650-SLOTS.W,A3,D1.W*8),PagRuts+$10


	LEA	SubSlots-SLOTS(A3),A3	<-- Cuidado. A3 Modificado.	2-B
	MOVE.W	-$1C(A3,D1.W*2),RESTA2+8-SubSLOTS(A3)
	MOVE.L	(2*8)+4(A3,D1.W*8),PagWrite+16+4-SubSLOTS(A3)

	MOVE.L	(2*8)+0(A3,D1.W*8),A4
	MOVE.L	A4,PagRead+16+4-SubSLOTS(A3)
	ADD.L	#$A001,A4
	MOVE.L	A4,RESTA2+8+Desbor-SubSLOTS(A3)
	ADD.W	#$C000-$A001,A4
	MOVE.L	A4,RESTA2+8+Desbor+4-SubSLOTS(A3)

	MOVE.L	($654-SubSLOTS.W,A3,D1.W*8),PagRuts+$14


	BFEXTU	D2{24:2},D1
	LSL.B	#2,D1
	LEA	Slots-SubSLOTS(A3),A3	<-- Cuidado. A3 Modificado.	3-A
	MOVE.W	-$1A(A3,D1.W*2),RESTA3+0-SLOTS(A3)
	MOVE.L	(3*8)+4(A3,D1.W*8),PagWrite+24+0-SLOTS(A3)

	MOVE.L	(3*8)+0(A3,D1.W*8),A4
	MOVE.L	A4,PagRead+24+0-SLOTS(A3)
	ADD.L	#$C001,A4
	MOVE.L	A4,RESTA3+0+Desbor-SLOTS(A3)
	ADD.W	#$E000-$C001,A4
	MOVE.L	A4,RESTA3+0+Desbor+4-SLOTS(A3)

	MOVE.L	($658-SLOTS.W,A3,D1.W*8),PagRuts+$18


	LEA	SubSlots-SLOTS(A3),A3	<-- Cuidado. A3 Modificado.	3-B
	MOVE.W	-$1A(A3,D1.W*2),RESTA3+8-SubSLOTS(A3)
	MOVE.L	(3*8)+4(A3,D1.W*8),PagWrite+24+4-SubSLOTS(A3)

	MOVE.L	(3*8)+0(A3,D1.W*8),A4
	MOVE.L	A4,PagRead+24+4-SubSLOTS(A3)
	ADD.L	#$E001,A4
	MOVE.L	A4,RESTA3+8+Desbor-SubSLOTS(A3)
	ADD.W	#$10000-$E001,A4
	MOVE.L	A4,RESTA3+8+Desbor+4-SubSLOTS(A3)

	MOVE.L	($65C-SubSLOTS.W,A3,D1.W*8),PagRuts+$1C


	LEA	Regs,A3		; */*\*/*\*  A3 Restaurado.

	MOVE.W	A5,D1
	CogePag	D1,A5

	MOVE.W	D0,D1
	CogePagE D1,A6

	SIINT
	RTS

; -------------------------------

	IFEQ	FFFF_ON
	CNOP	0,4
FFFF:
	MOVE.B	DA8(A3),D2
	AND.B	#$C0,D2
	BEQ.S	SiFFFF
	Otra2
SiFFFF:
	NOINT
	MOVE.B	(A4),D2
	NOT.B	(A4)
	MOVE.B	(A4),ESROM+$3FFF

	LEA	SUBSLOTS(A3),A4

	BFEXTU	D2{30:2},D1
	LSL.B	#2,D1
	MOVE.W	-$20(A4,D1.W*2),SLOTS-$20(A3)
	MOVE.L	(0*8)+4(A4,D1.W*8),SLOTS+(0*8)+4(A3)
	MOVE.L	(0*8)+0(A4,D1.W*8),SLOTS+(0*8)+0(A3)

	BFEXTU	D2{28:2},D1
	LSL.B	#2,D1
	MOVE.W	-$1E(A4,D1.W*2),SLOTS-$1E(A3)
	MOVE.L	(1*8)+4(A4,D1.W*8),SLOTS+(1*8)+4(A3)
	MOVE.L	(1*8)+0(A4,D1.W*8),SLOTS+(1*8)+0(A3)

	BFEXTU	D2{26:2},D1
	LSL.B	#2,D1
	MOVE.W	-$1C(A4,D1.W*2),SLOTS-$1C(A3)
	MOVE.L	(2*8)+4(A4,D1.W*8),SLOTS+(2*8)+4(A3)
	MOVE.L	(2*8)+0(A4,D1.W*8),SLOTS+(2*8)+0(A3)

	BFEXTU	D2{24:2},D1
	LSL.B	#2,D1
	MOVE.W	-$1A(A4,D1.W*2),SLOTS-$1A(A3)
	MOVE.L	(3*8)+4(A4,D1.W*8),SLOTS+(3*8)+4(A3)
	MOVE.L	(3*8)+0(A4,D1.W*8),SLOTS+(3*8)+0(A3)

	MOVE.B	DA8(A3),D1
	BRA	OUTA8
	ENDC

; -------------------------------

PONBITC:MACRO				; Scr 6
	SWAP	D0
	MOVE.L	#(64*1024),D1
	LSL.B	#1,D2
	ROXL.B	#1,D0
	LSL.W	#1,D2
	LSL.B	#1,D2
	ROXL.B	#1,D0
	LSL.W	#1,D2
	LSL.B	#1,D2
	ROXL.B	#1,D0
	LSL.W	#1,D2
	LSL.B	#1,D2
	ROXL.B	#1,D0
	LSL.W	#1,D2
	BFINS	D0,(A4){\1:4}
	SUB.L	D1,A4
	LSR.W	#4,D2
	LSR.B	#4,D2
	BFINS	D2,(A4){\1:4}
	OR.B	D2,D0
	SUB.L	D1,A4
	BFINS	D0,(A4){\1:4}
	MOVEQ	#0,D1
	SWAP	D0
	ENDM

; --------------------------------------------------------

DARBITA:MACRO				; Scr 5 y 7
	SWAP	D0
	MOVE.W	#(64*512)-1,D0

	MOVE.B	-(A4),D2
	LSL.B	#\1+1,D2
	ROXR.B	#4,D1
	ADD.B	D2,D2
	ROXR.B	#4,D1

	SUB.W	D0,A4

	MOVE.B	-(A4),D2
	LSL.B	#\1+1,D2
	ROXR.B	#4,D1
	ADD.B	D2,D2
	ROXR.B	#4,D1

	SUB.W	D0,A4

	MOVE.B	-(A4),D2
	LSL.B	#\1+1,D2
	ROXR.B	#4,D1
	ADD.B	D2,D2
	ROXR.B	#4,D1

	SUB.W	D0,A4

	MOVE.B	-(A4),D2
	LSL.B	#\1+1,D2
	ROXR.B	#4,D1
	ADD.B	D2,D2
	ROXR.B	#4,D1

	ROL.B	#4,D1
	SWAP	D0
	ENDM


;;PONBITA:MACRO				; Scr 5 y 7
;;	ENDM

; --------------------------------------------------------




DARBITB:MACRO
	SWAP	D0
	MOVE.W	#(32*512),D0
	MOVE.B	(A4),D2
	LSL.B	#\1+1,D2
	ADDX.B	D1,D1
	SUB.W	D0,A4
	MOVE.B	(A4),D2
	LSL.B	#\1+1,D2
	ADDX.B	D1,D1
	SUB.W	D0,A4
	MOVE.B	(A4),D2
	LSL.B	#\1+1,D2
	ADDX.B	D1,D1
	SUB.W	D0,A4
	MOVE.B	(A4),D2
	LSL.B	#\1+1,D2
	ADDX.B	D1,D1
	SUB.W	D0,A4
	MOVE.B	(A4),D2
	LSL.B	#\1+1,D2
	ADDX.B	D1,D1
	SUB.W	D0,A4
	MOVE.B	(A4),D2
	LSL.B	#\1+1,D2
	ADDX.B	D1,D1
	SUB.W	D0,A4
	MOVE.B	(A4),D2
	LSL.B	#\1+1,D2
	ADDX.B	D1,D1
	SUB.W	D0,A4
	MOVE.B	(A4),D2
	LSL.B	#\1+1,D2
	ADDX.B	D1,D1
	SWAP	D0
	ENDM


PONBITB:MACRO				; Scr 8
	SWAP	D0
	MOVE.W	#(32*512),D1
	ROL.B	#1,D2
	BFINS	D2,(A4){\1:1}
	MOVE.B	D2,D0
	SUB.W	D1,A4
	ROL.B	#1,D2
	BFINS	D2,(A4){\1:1}
	OR.B	D2,D0
	SUB.W	D1,A4
	ROL.B	#1,D2
	BFINS	D2,(A4){\1:1}
	OR.B	D2,D0
	SUB.W	D1,A4
	ROL.B	#1,D2
	BFINS	D2,(A4){\1:1}
	OR.B	D2,D0
	SUB.W	D1,A4
	ROL.B	#1,D2
	BFINS	D2,(A4){\1:1}
	OR.B	D2,D0
	SUB.W	D1,A4
	ROL.B	#1,D2
	BFINS	D2,(A4){\1:1}
	OR.B	D2,D0
	SUB.W	D1,A4
	ROL.B	#1,D2
	BFINS	D2,(A4){\1:1}
	OR.B	D2,D0
	SUB.W	D1,A4
	ROL.B	#1,D2
	BFINS	D2,(A4){\1:1}
	OR.B	D2,D0
	SUB.W	D1,A4
	BFINS	D0,(A4){\1:1}
	SWAP	D0
	ENDM

;	------------------------

	CNOP	0,8
IN98:
	MOVE.L	A2,D1
	SUB.L	#DIRVRAM,D1
	TST.B	D1
	BNE.S	IVRAM98
	AND.W	#$3FFF,D1
	LEA	([VRAM.W,A3],D1.W),A2
IVRAM98:
	MOVEQ	#0,D1
	MOVE.B	(A2)+,D1
	RTS


	CNOP	0,8		; Screen 0, 1 y 2
OUT98:
	IFD	TRAPVA			; Debug (TRACE): freeze on a VRAM write to
	CMPA.L	#DIRVRAM+TRAPVA,A2	; TRAPVA from MSX frame TRAPVF on.
	BNE.S	OUT98NoTrap
	CMP.W	#TRAPVF,TrvFrame
	BCS.S	OUT98NoTrap
	IFD	TRAPVV			; ...and with this value.
	CMP.B	#TRAPVV,D1
	BNE.S	OUT98NoTrap
	ENDC
	JMP	TraceFreeze
OUT98NoTrap:
	ENDC
	MOVE.B	D1,D2
	MOVE.L	A2,D1
	SUB.L	#DIRVRAM,D1
	TST.B	D1
	BEQ.S	VRAM98
	MOVE.B	D2,(A2)+
	LSR.L	#3,D1
	ST	(TAB98-REGS.W,A3,D1.W)
	ST	(TAB98B-REGS.W,A3,D1.W)	; (Cache bank 2.)
	RTS
VRAM98:
	AND.W	#$3FFF,D1
	LEA	([VRAM.W,A3],D1.W),A2
	MOVE.L	A2,D1
	SUB.L	#DIRVRAM,D1
	MOVE.B	D2,(A2)+
	LSR.L	#3,D1
	ST	(TAB98-REGS.W,A3,D1.W)
	ST	(TAB98B-REGS.W,A3,D1.W)	; (Cache bank 2.)
	RTS

;	-----------

	CNOP	0,8
IN98X:
	MOVE.L	A2,D1
	SUB.L	#DIRVRAM,D1
	TST.B	D1
	BNE.S	IVRAM98X
	AND.L	#$1FFFF,D1
	LEA	(DIRVRAM.L,D1.L),A2
IVRAM98X:
	MOVEQ	#0,D1
	MOVE.B	(A2)+,D1
	RTS


	CNOP	0,8		; Screen 0 (Width 80)
OUT98X:
	MOVE.B	D1,D2
	MOVE.L	A2,D1
	SUB.L	#DIRVRAM,D1
	TST.B	D1
	BEQ.S	VRAM98X
	MOVE.B	D2,(A2)+
	LSR.L	#3,D1
	ST	(TAB98-REGS.W,A3,D1.W)
	ST	(TAB98B-REGS.W,A3,D1.W)	; (Cache bank 2.)
	RTS
VRAM98X:
	AND.L	#$1FFFF,D1
	LEA	(DIRVRAM.L,D1.L),A2
	MOVE.L	A2,D1
	SUB.L	#DIRVRAM,D1
	MOVE.B	D2,(A2)+
	LSR.L	#3,D1
	ST	(TAB98-REGS.W,A3,D1.W)
	ST	(TAB98B-REGS.W,A3,D1.W)	; (Cache bank 2.)
	RTS


; OUT98/OUT98X once the SCREEN 5/7 planes are valid (V5All clear): also
; the 1 KB dirty blocks for ActPlanos5. Plain ones otherwise (no cost).
	CNOP	0,8
OUT98M:
	MOVE.B	D1,D2
	MOVE.L	A2,D1
	SUB.L	#DIRVRAM,D1
	TST.B	D1
	BEQ.S	VRAM98M
	MOVE.B	D2,(A2)+
	LSR.L	#3,D1
	ST	(TAB98-REGS.W,A3,D1.W)
	ST	(TAB98B-REGS.W,A3,D1.W)	; (Cache bank 2.)
	LSR.W	#7,D1			; 1 KB block: not in the SCREEN 5/7 planes.
	ST	(VBlk5-REGS.W,A3,D1.W)
	RTS
VRAM98M:
	AND.W	#$3FFF,D1
	LEA	([VRAM.W,A3],D1.W),A2
	MOVE.L	A2,D1
	SUB.L	#DIRVRAM,D1
	MOVE.B	D2,(A2)+
	LSR.L	#3,D1
	ST	(TAB98-REGS.W,A3,D1.W)
	ST	(TAB98B-REGS.W,A3,D1.W)	; (Cache bank 2.)
	LSR.W	#7,D1			; 1 KB block: not in the SCREEN 5/7 planes.
	ST	(VBlk5-REGS.W,A3,D1.W)
	RTS


	CNOP	0,8
OUT98XM:
	MOVE.B	D1,D2
	MOVE.L	A2,D1
	SUB.L	#DIRVRAM,D1
	TST.B	D1
	BEQ.S	VRAM98XM
	MOVE.B	D2,(A2)+
	LSR.L	#3,D1
	ST	(TAB98-REGS.W,A3,D1.W)
	ST	(TAB98B-REGS.W,A3,D1.W)	; (Cache bank 2.)
	LSR.W	#7,D1			; 1 KB block: not in the SCREEN 5/7 planes.
	ST	(VBlk5-REGS.W,A3,D1.W)
	RTS
VRAM98XM:
	AND.L	#$1FFFF,D1
	LEA	(DIRVRAM.L,D1.L),A2
	MOVE.L	A2,D1
	SUB.L	#DIRVRAM,D1
	MOVE.B	D2,(A2)+
	LSR.L	#3,D1
	ST	(TAB98-REGS.W,A3,D1.W)
	ST	(TAB98B-REGS.W,A3,D1.W)	; (Cache bank 2.)
	LSR.W	#7,D1			; 1 KB block: not in the SCREEN 5/7 planes.
	ST	(VBlk5-REGS.W,A3,D1.W)
	RTS

;	-----------

	CNOP	0,8
IN98A:
	MOVE.L	A2,D1
	SUB.L	#DIRVRAM,D1
	TST.B	D1
	BNE.S	IVRAM98A
	AND.L	#$1FFFF,D1
	LEA	(DIRVRAM.L,D1.L),A2
IVRAM98A:
	ADDQ.W	#1,A2
POINTA:
	ROR.L	#2,D1
	LEA	(SCR0+1+(64*512*3),D1.W),A4
	LSL.L	#1,D1
	BCS	IN98CONA
	BMI.S	IN98A2
	DARBITA	0
	RTS
	CNOP	0,8
IN98A2:
	MOVEQ	#0,D1
	DARBITA	2
	RTS
	CNOP	0,8
IN98CONA:
	BMI.S	IN98A4
IN98A3:
	DARBITA	4
	RTS
	CNOP	0,8
IN98A4:
	MOVEQ	#0,D1
	DARBITA	6
	RTS


	CNOP	0,8
VRAM98A:
	AND.L	#$1FFFF,D1
	LEA	(DIRVRAM.L,D1.L),A2
	MOVE.L	A2,D1
	SUB.L	#DIRVRAM,D1
	BRA.S	CRAM98A

	CNOP	0,8
OUT98AT:				; OUT98A during a mode split: also the
	MOVE.B	D1,D2			; SCREEN 4 cache's dirty flags.
	MOVE.L	A2,D1
	SUB.L	#DIRVRAM,D1
	TST.B	D1
	BNE.S	CRAM98AT
	AND.L	#$1FFFF,D1
	LEA	(DIRVRAM.L,D1.L),A2
	MOVE.L	A2,D1
	SUB.L	#DIRVRAM,D1
CRAM98AT:
	ROR.L	#3,D1
	ST	(TAB98-REGS.W,A3,D1.W)
	ST	(TAB98B-REGS.W,A3,D1.W)
	ROL.L	#3,D1
	CMP.L	SCRTLo,D1		; In the page shown above the split?
	BCS	CRAM98A
	CMP.L	SCRTHi,D1
	BCC	CRAM98A
	ST	SCRTDirty
	BRA	CRAM98A

	CNOP	0,8		; Screen 5 y 7
OUT98A:
	MOVE.B	D1,D2
	MOVE.L	A2,D1
	SUB.L	#DIRVRAM,D1
	TST.B	D1
	BEQ.S	VRAM98A
CRAM98A:MOVE.B	D2,(A2)+
	ADD.L	D1,D1
INIOUTSC5:
	MOVE.W	(INIOUTSC5+2,PC,D2.W*2),D2	; d8=0: Devpac form was (PC,D2.W*2)

	BFINS	D2,SCR0+$18000{D1:2}
	LSR.W	#2,D2
	BFINS	D2,SCR0+$10000{D1:2}
	LSR.B	#2,D2
	BFINS	D2,SCR0+$08000{D1:2}
	LSR.B	#2,D2
	BFINS	D2,SCR0+$00000{D1:2}
	LSR.B	#2,D2
	BFINS	D2,SCR0-$08000{D1:2}
	MOVEQ	#0,D1
	RTS

;;	LSR.L	#4,D1
;;	ST	(TAB98-REGS.W,A3,D1.W)
;;	RTS

	CNOP	0,8
CREATABSC5:
	LEA	TABOUTSC5(PC),A0
	MOVE.W	#256-1,D4
	MOVEQ	#0,D3
CRSCR5BUC:
	MOVE.B	D3,D2
	MOVE.W	#$0400,D1

	ADD.B	D2,D2
	ROL.B	#3,D2
	ROXL.B	#2,D2
	BFINS	D2,D1{30:2}
	MOVE.B	D2,D0
	ROR.B	#4,D2
	ADDX.B	D2,D2
	BFINS	D2,D1{28:2}
	OR.B	D2,D0
	ROL.B	#3,D2
	ROXL.B	#2,D2
	BFINS	D2,D1{26:2}
	OR.B	D2,D0
	ROR.B	#4,D2
	ADDX.B	D2,D2
	BFINS	D2,D1{24:2}
	OR.B	D2,D0
	BFINS	D0,D1{22:2}

	MOVE.W	D1,(A0)+
	ADDQ.B	#1,D3
	DBF	D4,CRSCR5BUC
	RTS
FINOUTSC5:
TABOUSC5SIZ=(FINOUTSC5-INIOUTSC5)-2
	DS.B	$200-TABOUSC5SIZ
TABOUTSC5:DS.W	$110



;	-----------

	CNOP	0,8
IN98C:
	MOVE.L	A2,D1
	SUB.L	#DIRVRAM,D1
	TST.B	D1
	BNE.S	IVRAM98C
	AND.L	#$1FFFF,D1
	LEA	(DIRVRAM.L,D1.L),A2
IVRAM98C:
	MOVEQ	#0,D1
	MOVE.B	(A2)+,D1
POINTC:
	RTS


	CNOP	0,8
VRAM98C:
	AND.L	#$1FFFF,D1
	LEA	(DIRVRAM.L,D1.L),A2
	MOVE.L	A2,D1
	SUB.L	#DIRVRAM,D1
	BRA.S	CRAM98C

	CNOP	0,8		; Screen 6
OUT98C:
	MOVE.B	D1,D2
	MOVE.L	A2,D1
	SUB.L	#DIRVRAM,D1
	TST.B	D1
	BEQ.S	VRAM98C
CRAM98C:MOVE.B	D2,(A2)+
	LSR.L	#1,D1
	BCS.S	OUT98C2
	LEA	(SCR0+(64*1024*1),D1.L),A4
	LSR.W	#2,D1
	ST	(TAB98-REGS.W,A3,D1.W)
	ST	(TAB98B-REGS.W,A3,D1.W)	; (Cache bank 2.)
	PONBITC	0
	RTS
OUT98C2:
	LEA	(SCR0+(64*1024*1),D1.L),A4
	LSR.W	#2,D1
	ST	(TAB98-REGS.W,A3,D1.W)
	ST	(TAB98B-REGS.W,A3,D1.W)	; (Cache bank 2.)
	PONBITC	4
	RTS

;	-----------

	CNOP	0,8
IN98B:
	MOVE.L	A2,D1
	SUB.L	#DIRVRAM,D1
	TST.B	D1
	BNE.S	IVRAM98B
	AND.L	#$1FFFF,D1
	LEA	(DIRVRAM.L,D1.L),A2
IVRAM98B:


	MOVEQ	#0,D1		; * NEW *
	MOVE.B	(A2)+,D1	; * NEW *
	RTS			; * NEW *


	ADDQ	#1,A2
POINTB:
	ROR.L	#3,D1
	LEA	(SCR0+(32*512*7),D1.W),A4

	LSL.L	#1,D1
	BCS	IN98CONB	; 1xx
	LSL.L	#1,D1
	BCS	IN98CONB2	; 01x
	BMI	IN98B1		; 001
IN98B0:
	MOVEQ	#0,D1
	DARBITB	0
	RTS

IN98CONB:
	LSL.L	#1,D1
	BCS	IN98CONB3	; 11x
	BMI	IN98B5		; 101
IN98B4:
	MOVEQ	#0,D1
	DARBITB	4
	RTS


IN98CONB2:
	BMI	IN98B3		; 011
IN98B2:
	MOVEQ	#0,D1
	DARBITB	2
	RTS

IN98CONB3:
	BMI	IN98B7		; 111
IN98B6:
	MOVEQ	#0,D1
	DARBITB	6
	RTS


IN98B1:
	MOVEQ	#0,D1
	DARBITB	1
	RTS
IN98B3:
	MOVEQ	#0,D1
	DARBITB	3
	RTS
IN98B5:
	MOVEQ	#0,D1
	DARBITB	5
	RTS
IN98B7:
	MOVEQ	#0,D1
	DARBITB	7
	RTS



	CNOP	0,8
VRAM98B:
	AND.L	#$1FFFF,D1
	LEA	(DIRVRAM.L,D1.L),A2
	MOVE.L	A2,D1
	SUB.L	#DIRVRAM,D1
	BRA.S	CRAM98B

	CNOP	0,8		; Screen 8
OUT98B:
	MOVE.B	D1,D2
	MOVE.L	A2,D1
	SUB.L	#DIRVRAM,D1
	TST.B	D1
	BEQ.S	VRAM98B
CRAM98B:MOVE.B	D2,(A2)+

	MOVE.B	(PasScr8Out-$100.W,PC,D2.W),D2

	ROR.L	#3,D1
	LEA	(SCR0+(32*512*7),D1.W),A4
	ST	(TAB98-REGS.W,A3,D1.W)
	ST	(TAB98B-REGS.W,A3,D1.W)	; (Cache bank 2.)


	MOVEQ	#0,D1		; * NEW *
	RTS			; * NEW *


	LSL.L	#1,D1
	BCS	OU98CONB	; 1xx
	LSL.L	#1,D1
	BCS	OU98CONB2	; 01x
	BMI	OUT98B1		; 001
OUT98B0:
	MOVEQ	#0,D1
	PONBITB	0
	RTS

OU98CONB:
	LSL.L	#1,D1
	BCS	OU98CONB3	; 11x
	BMI	OUT98B5		; 101
OUT98B4:
	MOVEQ	#0,D1
	PONBITB	4
	RTS


OU98CONB2:
	BMI	OUT98B3		; 011
OUT98B2:
	MOVEQ	#0,D1
	PONBITB	2
	RTS

OU98CONB3:
	BMI	OUT98B7		; 111
OUT98B6:
	MOVEQ	#0,D1
	PONBITB	6
	RTS


OUT98B1:
	MOVEQ	#0,D1
	PONBITB	1
	RTS
OUT98B3:
	MOVEQ	#0,D1
	PONBITB	3
	RTS
OUT98B5:
	MOVEQ	#0,D1
	PONBITB	5
	RTS
OUT98B7:
	MOVEQ	#0,D1
	PONBITB	7
	RTS



; -------------------------------

	CNOP	0,8
IN99:
	MOVE.L	#OUT99a,DREGOUT99(A3)
	MOVE.B	VDPREGL(A3),D2
	JMP	([IVDPPUNT-$400.W,PC,D2.W*4])

	CNOP	0,8
IVDPPUNT:
	DC.L	IVDP0		; 0
	DC.L	IVDP1
	DC.L	IVDP2
	DC.L	IVDP3
	DC.L	IVDPN
	DC.L	IVDP5
	DC.L	IVDPN
	DC.L	IVDP7
	DC.L	IVDPN		; 8
	DC.L	IVDPN
	DC.L	IVDPN
	DC.L	IVDPN
	DC.L	IVDPN
	DC.L	IVDPN
	DC.L	IVDPN
	DC.L	IVDPN		; F

	CNOP	0,8
OUT9Aa:
	MOVE.L	#OUT9Ab,DREGOUT9A(A3)

	AND.B	#$77,D1
	MOVE.B	D1,DATPAL(A3)
	RTS

OUT9Ab:
	MOVE.L	#OUT9Aa,DREGOUT9A(A3)

	MOVE.B	D1,D2
	AND.B	#$07,D2
	LSL.B	#5,D2
	MOVE.W	DATPAL(A3),D1
	LSR.W	#3,D1
	LSR.B	#4,D1
	OR.B	D2,D1
	MOVE.B	VDPREGP(A3),D2
	AND.B	#$0F,D2
	ADDQ.B	#1,VDPREGP(A3)
; -=-
	MOVE.W	D1,(MSX2Pal-$200.L,D2.W*2)
; -=-
	MOVE.W	D1,(COLORSPR2+2-$400.L,D2.W*4)
	TST.B	PalSplitSeen		; Mid-frame palettes: the copper loads
	BNE.S	OU9ANoHW1		; the colours where they belong.
	MOVE.W	D1,($DFF1A0-$200.L,D2.W*2)
OU9ANoHW1:
; -=-
	SWAP	D0
	MOVE.B	MCAGA+10,D0
	TST.B	D2
	BNE.S	OU9ANoCero
	BTST	#5,DVDP8(A3)
	BNE.S	OU9ANoCero
	EOR.B	D0,D2
	MOVE.W	D1,(COLORMSX2+2-$400.L,D2.W*4)
	SWAP	D0
; -=-
	BRA.S	OU9ACap
OU9ANoCero:
	EOR.B	D0,D2
	TST.B	PalSplitSeen
	BNE.S	OU9ANoHW2
	MOVE.W	D1,($DFF180-$200.L,D2.W*2)
OU9ANoHW2:
	MOVE.W	D1,(COLORMSX2+2-$400.L,D2.W*4)
	SWAP	D0
; -=-
; Palette write during the display: an event for the copper (AcCoRutPal).
OU9ACap:
	MOVE.W	CurLine(A3),D1
	BEQ	OU9ACapX
	CMP.W	#212,D1
	BCC	OU9ACapX
	TST.W	PalEvN
	BEQ.S	OU9ACapN
	SUB.W	PalEvLast,D1		; Same burst (within 8 lines)?
	CMP.W	#8,D1
	BCS.S	OU9ACapU
	MOVE.W	CurLine(A3),D1
OU9ACapN:
	CMP.W	#PALEVMAX,PalEvN
	BCC	OU9ACapX
	MOVE.W	D1,PalEvLast
	ADDQ.W	#1,D1			; From the next line.
	OR.B	#$04,(TabRasCMDS.L,D1.W)
	MOVE.W	D1,PalEvTmp		; (No stack here: A7 is the Restas table.)
	MOVE.W	PalEvN,D1
	ADD.W	D1,D1
	MOVE.W	PalEvTmp,(PalEvLines.L,D1.W)
	ADDQ.W	#1,PalEvN
	MOVE.B	#3,PalSplitSeen
OU9ACapU:
	MOVE.W	PalEvN,D1
	SUBQ.W	#1,D1
	LSL.W	#5,D1			; 32 bytes an event.
	MOVE.L	MSX2Pal+0,(PalEvBuf+0.L,D1.W)
	MOVE.L	MSX2Pal+4,(PalEvBuf+4.L,D1.W)
	MOVE.L	MSX2Pal+8,(PalEvBuf+8.L,D1.W)
	MOVE.L	MSX2Pal+12,(PalEvBuf+12.L,D1.W)
	MOVE.L	MSX2Pal+16,(PalEvBuf+16.L,D1.W)
	MOVE.L	MSX2Pal+20,(PalEvBuf+20.L,D1.W)
	MOVE.L	MSX2Pal+24,(PalEvBuf+24.L,D1.W)
	MOVE.L	MSX2Pal+28,(PalEvBuf+28.L,D1.W)
OU9ACapX:
	MOVEQ	#0,D1
	RTS

; -=*=-

OUT9B:
	SWAP	D2
	MOVE.B	D1,D2
	MOVE.B	VDPREGE(A3),D1
	BMI.S	NOAUINC
	ADDQ.B	#1,VDPREGE(A3)
	BPL.S	NOAUINC
	AND.B	#$7F,VDPREGE(A3)
NOAUINC:
	AND.W	#$007F,D1
	CMP.B	#$11,D1			; NO SE PUEDE ESCRIBIR A SI MISMO.
	BEQ.S	NOESVD2			; NO SE PUEDE ESCRIBIR A SI MISMO.
	AND.W	#$00FF,D2
	JMP	([VDPPUNT.W,PC,D1.W*4])
	CNOP	0,8
NOESVD2:SWAP	D2
	RTS

	CNOP	0,8
OUT99a:
	MOVE.L	#OUT99b,DREGOUT99(A3)
	SWAP	D2
	MOVE.B	D1,D2
	SWAP	D2
	RTS
	CNOP	0,8
OUT99b:
	BMI.S	ESVDP
	MOVE.L	#OUT99a,DREGOUT99(A3)
	SWAP	D2
	AND.B	#$3F,D1
	LSL.W	#8,D1
	MOVE.B	D2,D1
	LEA	([VRAM.W,A3],D1.W),A2
	SWAP	D2
	RTS
ESVDP:
	MOVE.L	#OUT99a,DREGOUT99(A3)
	AND.W	#$007F,D1
	SWAP	D2
	AND.W	#$00FF,D2
	JMP	([VDPPUNT.W,PC,D1.W*4])

	CNOP	0,8
VDPPUNT:
	DC.L	VDP0		; 0
	DC.L	VDP1
	DC.L	VDP2
	DC.L	VDP3
	DC.L	VDP4
	DC.L	VDP5
	DC.L	VDP6
	DC.L	VDP7
	DC.L	VDP8		; 8
	DC.L	VDP9
	DC.L	VDPA
	DC.L	VDPB
	DC.L	VDPC
	DC.L	VDPD
	DC.L	VDPE
	DC.L	VDPF

	DC.L	VDP10		; 10
	DC.L	VDP11
	DC.L	VDP12
	DC.L	VDP13
	DC.L	ARET
	DC.L	ARET
	DC.L	ARET
	DC.L	VDP17
	DC.L	ARET		; 18
	DC.L	ARET
	DC.L	ARET
	DC.L	ARET
	DC.L	ARET
	DC.L	ARET
	DC.L	ARET
	DC.L	ARET

	DC.L	VDP20		; 20
	DC.L	VDP21
	DC.L	VDP22
	DC.L	VDP23
	DC.L	VDP24
	DC.L	VDP25
	DC.L	VDP26
	DC.L	VDP27
	DC.L	VDP28		; 28
	DC.L	VDP29
	DC.L	VDP2A
	DC.L	VDP2B
	DC.L	VDP2C
	DC.L	VDP2D
	DC.L	VDP2Enada
	DC.L	ARET		; 2F

	REPT	16
	DC.L	ARET		; 30-3F.
	ENDR

	REPT	64
	DC.L	ARET		; 40-7F.
	ENDR

	DC.L	ARET
	DC.L	ARET

; -------------------------------


; -----------------------------=> Conversi�n de tablas para Screen 8
	CNOP	0,8
PasScr8Out:	DS.B	$100
PasScr8In:	DS.B	$100
; -----------------------------<=


; -------------------------------------> Outs para FM-Pack
	CNOP	0,8
IN7C:
;;	MOVE.W	#$F00,$DFF180
	MOVE.B	D7C(A3),D1
	RTS

	CNOP	0,8
IN7D:
;;	MOVE.W	#$F0,$DFF180
	MOVE.B	D7C(A3),D1
	AND.W	#$3F,D1
	MOVE.B	(Tabla7C.W,PC,D1.W),D1
	RTS

	CNOP	0,8
OUT7C:
;;	MOVE.W	#$F,$DFF180
	MOVE.B	D1,D7C(A3)
	RTS

OUT7D:
;;	MOVE.W	#-1,$DFF180
	MOVE.B	D1,D2
	MOVE.B	D7C(A3),D1
	AND.W	#$3F,D1
	LEA	(Tabla7C.W,PC,D1.W),A4
	MOVE.B	D2,(A4)
	RTS

	CNOP	0,8
Tabla7C:DCB.B	$44,$FF		; Tabla para FM-Pack
; -------------------------------------<


	CNOP	0,8
IND0:
	ADD.B	#$35,DATD0
	MOVE.B	DATD0,D1
	RTS
DATD0:	DC.W	0


	CNOP	0,8
INB4:
	MOVE.B	DB4(A3),D1
	RTS
	CNOP	0,8
INB5:
	MOVEQ	#0,D1
	MOVE.B	DB4(A3),D1
	MOVE.B	DB5(A3),D2
	LSL.B	#4,D2
	OR.B	D2,D1
	MOVE.B	(TABLAB4,PC,D1.W),D1
	OR.B	#$F0,D1
	RTS

	CNOP	0,8
OUTB4:
	AND.B	#$0F,D1
	MOVE.B	D1,DB4(A3)
	RTS

OUTB5:
	MOVE.B	DB4(A3),D2
	CMP.B	#$0D,D2
	BNE.S	NOES13
	AND.B	#$03,D1
	MOVE.B	D1,DB5(A3)
	RTS
NOES13:
	MOVE.B	D1,D2
	MOVEQ	#0,D1
	MOVE.B	DB5(A3),D1
	LSL.B	#4,D1
	OR.B	DB4(A3),D1
	LEA	(TABLAB4,PC,D1.W),A4
	MOVE.B	D2,(A4)
	RTS

	IFND	TABLAB4
	CNOP	0,8
TABLAB4:
	DC.L	$F6F2F8F4,$F0F2F5F7,$F2F0F1F7,$F8F0F0F0
	DC.L	$F0F0F0F0,$F0F0F0F0,$F0F0F1F3,$F0F1F0F0
;	DC.L	$FAF9F7F0,$F8F2F7F1,$F1F0F3F0,$F7F2F0F0	; 40
	DC.L	$FAF9F7F0,$F0F5F7F1,$F1F0F3F0,$F7F2F0F0	; 80
	DC.L	$F2F1F4FD,$F6F9F6F7,$F6F1F6F0,$F0F3F0F0
; -------------------------------------------------------------
;	DC.L	$F6F2F8F4,$F0F2F5F7,$F2F0F1F7,$F8F0F0F0
;	DC.L	$F0F0F0F0,$F0F0F0F0,$F0F0F1F3,$F0F1F0F0
;	DC.L	$FAF9F700,$50050F04,$0403F3F0,$F7F2F0F0
;	DC.L	$024FF46B,$B6000000,$00000000,$00F3F0F0
; -------------------------------------------------------------
	ENDC
	DS.L	8
; -------------------------------------<=


; -------------------------------------=> Emulaci�n de la Kanji ROM.
OutD8:
	AND.B	#$3F,D1
	MOVE.B	D1,KanjiD8(A3)
	SF	KanjiCnt(A3)
	RTS
OutD9:
	AND.B	#$3F,D1
	MOVE.B	D1,KanjiD9(A3)
	SF	KanjiCnt(A3)
	RTS

InD9:
	MOVEQ	#0,D1
	MOVE.B	KanjiD9(A3),D1
	LSL.W	#6,D1
	OR.B	KanjiD8(A3),D1
	LSL.L	#5,D1
	OR.B	KanjiCnt(A3),D1
	MOVE.L	DirKanji,A4
	LEA	(A4,D1.L),A4

	ADDQ.B	#$1,D1
	AND.B	#$1F,D1
	MOVE.B	D1,KanjiCnt(A3)

	MOVEQ	#0,D1
	MOVE.B	(A4),D1
	RTS
; -------------------------------------<=

; -------------------------------------=> Emulaci�n Caset.
	CNOP	0,8
ED18:
	TST.B	ModoCaset
	BEQ.S	CasetError2
	BSR.S	MiraCtrlStop
	Otra2
; -=-=-
ED19:
	TST.B	ModoCaset
	BEQ.S	CasetError2
	BSR.S	MiraCtrlStop
	MOVE.B	([LoadCaset]),D7
	ADDQ.L	#1,LoadCaset
	SUBQ.W	#1,SizeCaset
	BCS.S	CasetError
	Otra2
; -=-=-
ED1A:
	TST.B	ModoCaset
	BNE.S	CasetError2
	BSR.S	MiraCtrlStop
	Otra2
; -=-=-
	CNOP	0,8
CasetError2:
	BSET	#0,D3
	Otra2
; -=-=-
ED1B:
	TST.B	ModoCaset
	BNE.S	CasetError2
	BSR.S	MiraCtrlStop
	MOVE.B	D7,([SaveCaset])
	ADDQ.L	#1,SaveCaset
	ADDQ.W	#1,SizeCaset
	BMI.S	CasetError
	Otra2
; -=-=-
	CNOP	0,8
MiraCtrlStop:
	BCLR	#0,D3
	BTST	#1,KEY+6(A3)		; Ctrl
	BNE.S	FinCaset
	ADDQ	#4,SP
	BTST	#4,KEY+7(A3)		; F7.
	BEQ.S	CasetError
	SUBQ	#4,SP
FinCaset:
	RTS
; -=-=-
	CNOP	0,8
CasetError:
	MOVE.L	DirCaset,LoadCaset
	MOVE.L	DirCaset,SaveCaset
	MOVE.W	BucCaset,SizeCaset
	BSET	#0,D3
	Otra2
; -------------------------------------<=

; -------------------------------------=> Emulaci�n Rat�n
	CNOP	0,8
ED16:			;	**** MOUSE EMULATION ****
	TST.B	LEEJOY2(A3)
	BEQ.S	FINRAT

	CMP.B	#12,D7
	BEQ.S	LEEDRAT
	CMP.B	#13,D7
	BEQ.S	LEEXRAT		; Registros PAD:
	MOVE.B	YMOUSE,D7	; 12 ->lee mouse 1 y guarda movs. en mem.
	BRA.S	FINRAT		; 13 ->devuelve en A mov. X mouse 1 (de mem)
LEEXRAT:MOVE.B	XMOUSE,D7	; 14 ->devuelve en A mov. Y mouse 1 (de mem)
	BRA.S	FINRAT		; 16 ->idem que el 12 pero mouse 2
LEEDRAT:MOVE.W	$DFF00A,D1	; 17 ->idem que el 13 pero mouse 2
	MOVE.W	D1,YMOUSE	; 18 ->idem que el 14 pero mouse 2
	MOVE.B	ANTMOY,D2
	SUB.B	D2,YMOUSE
	MOVE.B	ANTMOX,D2
	SUB.B	D2,XMOUSE
	MOVE.W	D1,ANTMOY
	MOVE.B	#-1,D7	; PAD(12) devuelve -1
FINRAT:	Otra2

YMOUSE:	DC.B	0
XMOUSE:	DC.B	0
ANTMOY:	DC.B	0
ANTMOX:	DC.B	0

	CNOP	0,8

; Parchear fichero "HINIROM.2" posici�n &H1AE (contiene C3,DD,34)
; -----------------===========----------=====--------------------
; -------------------------------------<=


; -------------------------------------<=
; -------------------------------------<=


; -------------------------------------=> ROM Mappers.

	CNOP	0,8
PagRuts:
	DC.L	OtraInstr
	DC.L	OtraInstr
	DC.L	OtraInstr
	DC.L	OtraInstr
	DC.L	OtraInstr
	DC.L	OtraInstr
	DC.L	OtraInstr
	DC.L	OtraInstr

Mapper0:			; Standard
	DC.L	OtraInstr
	DC.L	OtraInstr
	DC.L	OtraInstr
	DC.L	OtraInstr
	DC.L	OtraInstr
	DC.L	OtraInstr
	DC.L	OtraInstr
	DC.L	OtraInstr

Mapper1:			; Konami 1
	DC.L	OtraInstr
	DC.L	OtraInstr
	DC.L	OtraInstr
	DC.L	OtraInstr
	DC.L	KON18
	DC.L	KON18
	DC.L	OtraInstr
	DC.L	OtraInstr

Mapper2:			; Konami 2
	DC.L	OtraInstr
	DC.L	OtraInstr
	DC.L	Kon24
	DC.L	Kon26
	DC.L	Kon28
	DC.L	Kon2A
	DC.L	OtraInstr
	DC.L	OtraInstr

Mapper3:			; ASCII 1
	DC.L	OtraInstr
	DC.L	OtraInstr
	DC.L	OtraInstr
	DC.L	Asc16
	DC.L	OtraInstr
	DC.L	OtraInstr
	DC.L	OtraInstr
	DC.L	OtraInstr

Mapper4:			; ASCII 2
	DC.L	OtraInstr
	DC.L	OtraInstr
	DC.L	OtraInstr
	DC.L	Asc26
	DC.L	OtraInstr
	DC.L	OtraInstr
	DC.L	OtraInstr
	DC.L	OtraInstr

Mapper5:			; SCC 1
	DC.L	OtraInstr
	DC.L	OtraInstr
	DC.L	SCC14
	DC.L	SCC16
	DC.L	SCC18
	DC.L	SCC1A
	DC.L	OtraInstr
	DC.L	OtraInstr

Mapper6:			; SCC 2
	DC.L	OtraInstr
	DC.L	OtraInstr
	DC.L	SCC24
	DC.L	SCC26
	DC.L	SCC28
	DC.L	SCC2A
	DC.L	OtraInstr
	DC.L	OtraInstr

;	--=--=--=--=--=--

	CNOP	0,8
OtraInstr:
	Otra2

;	--=--=--=--=--=--

Asc26:
	MOVE.L	A4,D1
	SUB.L	PagWrite+12(A3),D1

	AND.W	#$1000,D1		; �P�gina 0 o 1?
	BNE	KON18

	SUB.W	(A7),A5

	BankNum	MaskROM2,NumROM2

	MULU	#$4100,D1
	ADD.L	MapROMBase1(A3),D1
	SUB.L	#$4000,D1

	MOVE.L	D1,PagRead+8+0(A3)
	MOVE.L	D1,SLOTS+(32*1)+8(A3)

	MOVE.W	D1,Resta1+0(A3)
	MOVE.W	D1,SLOTSR+(8*1)+2(A3)

	ADD.L	#$0080,D1

	MOVE.L	D1,PagRead+8+4(A3)
	MOVE.L	D1,SubSLOTS+(32*1)+8(A3)

	MOVE.W	D1,Resta1+8(A3)
	MOVE.W	D1,SubSLOTSR+(8*1)+2(A3)

	ADD.L	#$4001-$80,D1
	MOVE.L	D1,Resta1+0+Desbor+0(A3)
	ADD.L	#$1FFF,D1
	MOVE.L	D1,Resta1+0+Desbor+4(A3)

	ADDQ.L	#$0001,D1
	MOVE.L	D1,Resta1+8+Desbor+0(A3)
	ADD.L	#$1FFF,D1
	MOVE.L	D1,Resta1+8+Desbor+4(A3)

	MOVEQ	#0,D1
	MOVE.W	A5,D1
	CogePag	D1,A5
	Otra2

KON18:
	SUB.W	(A7),A5

	BankNum	MaskROM2,NumROM2

	MULU	#$4100,D1
	ADD.L	MapROMBase1(A3),D1
	SUB.L	#$8000,D1

	MOVE.L	D1,PagRead+16+0(A3)
	MOVE.L	D1,SLOTS+(32*1)+16(A3)

	MOVE.W	D1,Resta2+0(A3)
	MOVE.W	D1,SLOTSR+(8*1)+4(A3)

	ADD.L	#$0080,D1

	MOVE.L	D1,PagRead+16+4(A3)
	MOVE.L	D1,SubSLOTS+(32*1)+16(A3)

	MOVE.W	D1,Resta2+8(A3)
	MOVE.W	D1,SubSLOTSR+(8*1)+4(A3)

	ADD.L	#$8001-$80,D1
	MOVE.L	D1,Resta2+0+Desbor+0(A3)
	ADD.L	#$1FFF,D1
	MOVE.L	D1,Resta2+0+Desbor+4(A3)

	ADDQ.L	#$0001,D1
	MOVE.L	D1,Resta2+8+Desbor+0(A3)
	ADD.L	#$1FFF,D1
	MOVE.L	D1,Resta2+8+Desbor+4(A3)

	MOVEQ	#0,D1
	MOVE.W	A5,D1
	CogePag	D1,A5

	Otra2

; -------------------------------------<=
; -------------------------------------<=

; KonamiSCC ("SCC 1"): bank registers at &H5000-&H57FF, &H7000-&H77FF,
; &H9000-&H97FF and &HB000-&HB7FF only, as on the cartridge (openMSX
; RomKonamiSCC). Any write in the page used to switch it: Monster Hunter
; crashed at boot.
SCC14:
	MOVE.L	A4,D1
	SUB.L	PagWrite+8(A3),D1
	AND.W	#$1800,D1
	CMP.W	#$1000,D1
	BEQ	Pag0S1
	Otra2

SCC16:
	MOVE.L	A4,D1
	SUB.L	PagWrite+12(A3),D1
	AND.W	#$1800,D1
	CMP.W	#$1000,D1
	BEQ	Pag1S1
	Otra2

SCC18:
	MOVE.L	A4,D1
	SUB.L	PagWrite+16(A3),D1
	AND.W	#$1800,D1
	CMP.W	#$1000,D1
	BEQ	Pag2S1
	Otra2

SCC1A:
	MOVE.L	A4,D1
	SUB.L	PagWrite+20(A3),D1
	AND.W	#$1800,D1
	CMP.W	#$1000,D1
	BEQ	Pag3S1
	Otra2

SCC24:
	MOVE.L	A4,D1
	SUB.L	PagWrite+8(A3),D1

	SUB.W	#$5000,D1
	BEQ.S	Pag0S1
	Otra2

KON24:
	MOVE.L	A4,D1
	SUB.L	PagWrite+8(A3),D1

	SUB.W	#$4000,D1
	BEQ.S	Pag0S1
	Otra2


Pag0S1:
	SUB.W	(A7),A5

	BankNum	MaskROM,NumROM

	MULU	#$2080,D1
	ADD.L	MapROMBase1(A3),D1
	SUB.L	#$4000,D1

	MOVE.L	D1,PagRead+8(A3)
	MOVE.L	D1,SLOTS+(32*1)+8(A3)

	MOVE.W	D1,Resta1+0(A3)
	MOVE.W	D1,SLOTSR+(8*1)+2(A3)

	ADD.L	#$4001,D1
	MOVE.L	D1,Resta1+0+Desbor+0(A3)
	ADD.L	#$1FFF,D1
	MOVE.L	D1,Resta1+0+Desbor+4(A3)

	MOVEQ	#0,D1
	MOVE.W	A5,D1
	CogePag	D1,A5
	Otra2

SCC26:
	MOVE.L	A4,D1
	SUB.L	PagWrite+12(A3),D1

	SUB.W	#$7000,D1
	BEQ.S	Pag1S1
	Otra2

KON26:
	MOVE.L	A4,D1
	SUB.L	PagWrite+12(A3),D1

	SUB.W	#$6000,D1
	NOP			; was: BEQ.S	Pag1S1 (zero-length short branch)



Pag1S1:
	SUB.W	(A7),A5

	BankNum	MaskROM,NumROM

	MULU	#$2080,D1
	ADD.L	MapROMBase1(A3),D1
	SUB.L	#$6000,D1

	MOVE.L	D1,PagRead+12(A3)
	MOVE.L	D1,SubSLOTS+(32*1)+8(A3)

	MOVE.W	D1,Resta1+8(A3)
	MOVE.W	D1,SubSLOTSR+(8*1)+2(A3)

	ADD.L	#$6001,D1
	MOVE.L	D1,Resta1+8+Desbor+0(A3)
	ADD.L	#$1FFF,D1
	MOVE.L	D1,Resta1+8+Desbor+4(A3)

	MOVEQ	#0,D1
	MOVE.W	A5,D1
	CogePag	D1,A5
	Otra2

SCC28:
	MOVE.L	A4,D1
	SUB.L	PagWrite+16(A3),D1

	SUB.W	#$9000,D1
	BEQ.S	Pag2S1
	Otra2

KON28:
	MOVE.L	A4,D1
	SUB.L	PagWrite+16(A3),D1

	SUB.W	#$8000,D1
	NOP			; was: BEQ.S	Pag2S1 (zero-length short branch)



Pag2S1:
	SUB.W	(A7),A5

	BankNum	MaskROM,NumROM

	MULU	#$2080,D1
	ADD.L	MapROMBase1(A3),D1
	SUB.L	#$8000,D1

	MOVE.L	D1,PagRead+16(A3)
	MOVE.L	D1,SLOTS+(32*1)+16(A3)

	MOVE.W	D1,Resta2+0(A3)
	MOVE.W	D1,SLOTSR+(8*1)+4(A3)

	ADD.L	#$8001,D1
	MOVE.L	D1,Resta2+0+Desbor+0(A3)
	ADD.L	#$1FFF,D1
	MOVE.L	D1,Resta2+0+Desbor+4(A3)

	MOVEQ	#0,D1
	MOVE.W	A5,D1
	CogePag	D1,A5
	Otra2

SCC2A:
	MOVE.L	A4,D1
	SUB.L	PagWrite+20(A3),D1

	SUB.W	#$B000,D1
	BEQ.S	Pag3S1
	Otra2

KON2A:
	MOVE.L	A4,D1
	SUB.L	PagWrite+20(A3),D1

	SUB.W	#$A000,D1
	NOP			; was: BEQ.S	Pag3S1 (zero-length short branch)



Pag3S1:
	SUB.W	(A7),A5

	BankNum	MaskROM,NumROM

	MULU	#$2080,D1
	ADD.L	MapROMBase1(A3),D1
	SUB.L	#$A000,D1

	MOVE.L	D1,PagRead+20(A3)
	MOVE.L	D1,SubSLOTS+(32*1)+16(A3)

	MOVE.W	D1,Resta2+8(A3)
	MOVE.W	D1,SubSLOTSR+(8*1)+4(A3)

	ADD.L	#$A001,D1
	MOVE.L	D1,Resta2+8+Desbor+0(A3)
	ADD.L	#$1FFF,D1
	MOVE.L	D1,Resta2+8+Desbor+4(A3)

	MOVEQ	#0,D1
	MOVE.W	A5,D1
	CogePag	D1,A5
	Otra2

; -------------------------------------<=
; -------------------------------------<=

Asc16:
	MOVE.L	A4,D1
	SUB.L	PagWrite+12(A3),D1

	SUB.W	#$6800,D1
	BCS	Pag0S1

	SUB.W	#$800,D1
	BCS	Pag1S1

	SUB.W	#$800,D1
	BCS	Pag2S1

	BRA.S	Pag3S1

; -------------------------------------<=
; -------------------------------------<=


	CNOP	0,8
Mapper0b:			; Standard
	DC.L	OtraInstr
	DC.L	OtraInstr
	DC.L	OtraInstr
	DC.L	OtraInstr
	DC.L	OtraInstr
	DC.L	OtraInstr
	DC.L	OtraInstr
	DC.L	OtraInstr

Mapper1b:			; Konami 1
	DC.L	OtraInstr
	DC.L	OtraInstr
	DC.L	OtraInstr
	DC.L	OtraInstr
	DC.L	KON18b
	DC.L	KON18b
	DC.L	OtraInstr
	DC.L	OtraInstr

Mapper2b:			; Konami 2
	DC.L	OtraInstr
	DC.L	OtraInstr
	DC.L	Kon24b
	DC.L	Kon26b
	DC.L	Kon28b
	DC.L	Kon2Ab
	DC.L	OtraInstr
	DC.L	OtraInstr

Mapper3b:			; ASCII 1
	DC.L	OtraInstr
	DC.L	OtraInstr
	DC.L	OtraInstr
	DC.L	Asc16b
	DC.L	OtraInstr
	DC.L	OtraInstr
	DC.L	OtraInstr
	DC.L	OtraInstr

Mapper4b:			; ASCII 2
	DC.L	OtraInstr
	DC.L	OtraInstr
	DC.L	OtraInstr
	DC.L	Asc26b
	DC.L	OtraInstr
	DC.L	OtraInstr
	DC.L	OtraInstr
	DC.L	OtraInstr

Mapper5b:			; SCC 1
	DC.L	OtraInstr
	DC.L	OtraInstr
	DC.L	SCC14b
	DC.L	SCC16b
	DC.L	SCC18b
	DC.L	SCC1Ab
	DC.L	OtraInstr
	DC.L	OtraInstr

Mapper6b:			; SCC 2
	DC.L	OtraInstr
	DC.L	OtraInstr
	DC.L	SCC24b
	DC.L	SCC26b
	DC.L	SCC28b
	DC.L	SCC2Ab
	DC.L	OtraInstr
	DC.L	OtraInstr

;	--=--=--=--=--=--

Asc26b:
	MOVE.L	A4,D1
	SUB.L	PagWrite+12(A3),D1

	AND.W	#$1000,D1		; �P�gina 0 o 1?
	BNE	KON18b

	SUB.W	(A7),A5

	BankNum	MaskROM4,NumROM4

	MULU	#$4100,D1
	ADD.L	MapROMBase2(A3),D1
	SUB.L	#$4000,D1

	MOVE.L	D1,PagRead+8+0(A3)
	MOVE.L	D1,SLOTS+(32*2)+8(A3)

	MOVE.W	D1,Resta1+0(A3)
	MOVE.W	D1,SLOTSR+(8*2)+2(A3)

	ADD.L	#$0080,D1

	MOVE.L	D1,PagRead+8+4(A3)
	MOVE.L	D1,SubSLOTS+(32*2)+8(A3)

	MOVE.W	D1,Resta1+8(A3)
	MOVE.W	D1,SubSLOTSR+(8*2)+2(A3)

	ADD.L	#$4001-$80,D1
	MOVE.L	D1,Resta1+0+Desbor+0(A3)
	ADD.L	#$1FFF,D1
	MOVE.L	D1,Resta1+0+Desbor+4(A3)

	ADDQ.L	#$0001,D1
	MOVE.L	D1,Resta1+8+Desbor+0(A3)
	ADD.L	#$1FFF,D1
	MOVE.L	D1,Resta1+8+Desbor+4(A3)

	MOVEQ	#0,D1
	MOVE.W	A5,D1
	CogePag	D1,A5
	Otra2

KON18b:
	SUB.W	(A7),A5

	BankNum	MaskROM4,NumROM4

	MULU	#$4100,D1
	ADD.L	MapROMBase2(A3),D1
	SUB.L	#$8000,D1

	MOVE.L	D1,PagRead+16+0(A3)
	MOVE.L	D1,SLOTS+(32*2)+16(A3)

	MOVE.W	D1,Resta2+0(A3)
	MOVE.W	D1,SLOTSR+(8*2)+4(A3)

	ADD.L	#$0080,D1

	MOVE.L	D1,PagRead+16+4(A3)
	MOVE.L	D1,SubSLOTS+(32*2)+16(A3)

	MOVE.W	D1,Resta2+8(A3)
	MOVE.W	D1,SubSLOTSR+(8*2)+4(A3)

	ADD.L	#$8001-$80,D1
	MOVE.L	D1,Resta2+0+Desbor+0(A3)
	ADD.L	#$1FFF,D1
	MOVE.L	D1,Resta2+0+Desbor+4(A3)

	ADDQ.L	#$0001,D1
	MOVE.L	D1,Resta2+8+Desbor+0(A3)
	ADD.L	#$1FFF,D1
	MOVE.L	D1,Resta2+8+Desbor+4(A3)

	MOVEQ	#0,D1
	MOVE.W	A5,D1
	CogePag	D1,A5

	Otra2

; -------------------------------------<=
; -------------------------------------<=

; KonamiSCC ("SCC 1"): bank registers at &H5000-&H57FF, &H7000-&H77FF,
; &H9000-&H97FF and &HB000-&HB7FF only, as on the cartridge (openMSX
; RomKonamiSCC). Any write in the page used to switch it: Monster Hunter
; crashed at boot.
SCC14b:
	MOVE.L	A4,D1
	SUB.L	PagWrite+8(A3),D1
	AND.W	#$1800,D1
	CMP.W	#$1000,D1
	BEQ	Pag0S1b
	Otra2

SCC16b:
	MOVE.L	A4,D1
	SUB.L	PagWrite+12(A3),D1
	AND.W	#$1800,D1
	CMP.W	#$1000,D1
	BEQ	Pag1S1b
	Otra2

SCC18b:
	MOVE.L	A4,D1
	SUB.L	PagWrite+16(A3),D1
	AND.W	#$1800,D1
	CMP.W	#$1000,D1
	BEQ	Pag2S1b
	Otra2

SCC1Ab:
	MOVE.L	A4,D1
	SUB.L	PagWrite+20(A3),D1
	AND.W	#$1800,D1
	CMP.W	#$1000,D1
	BEQ	Pag3S1b
	Otra2

SCC24b:
	MOVE.L	A4,D1
	SUB.L	PagWrite+8(A3),D1

	SUB.W	#$5000,D1
	BEQ.S	Pag0S1b
	Otra2

KON24b:
	MOVE.L	A4,D1
	SUB.L	PagWrite+8(A3),D1

	SUB.W	#$4000,D1
	BEQ.S	Pag0S1b
	Otra2



Pag0S1b:
	SUB.W	(A7),A5

	BankNum	MaskROM3,NumROM3

	MULU	#$2080,D1
	ADD.L	MapROMBase2(A3),D1
	SUB.L	#$4000,D1

	MOVE.L	D1,PagRead+8(A3)
	MOVE.L	D1,SLOTS+(32*2)+8(A3)

	MOVE.W	D1,Resta1+0(A3)
	MOVE.W	D1,SLOTSR+(8*2)+2(A3)

	ADD.L	#$4001,D1
	MOVE.L	D1,Resta1+0+Desbor+0(A3)
	ADD.L	#$1FFF,D1
	MOVE.L	D1,Resta1+0+Desbor+4(A3)

	MOVEQ	#0,D1
	MOVE.W	A5,D1
	CogePag	D1,A5
	Otra2

SCC26b:
	MOVE.L	A4,D1
	SUB.L	PagWrite+12(A3),D1

	SUB.W	#$7000,D1
	BEQ.S	Pag1S1b
	Otra2

KON26b:
	MOVE.L	A4,D1
	SUB.L	PagWrite+12(A3),D1

	SUB.W	#$6000,D1
	NOP			; was: BEQ.S	Pag1S1b (zero-length short branch)



Pag1S1b:
	SUB.W	(A7),A5

	BankNum	MaskROM3,NumROM3

	MULU	#$2080,D1
	ADD.L	MapROMBase2(A3),D1
	SUB.L	#$6000,D1

	MOVE.L	D1,PagRead+12(A3)
	MOVE.L	D1,SubSLOTS+(32*2)+8(A3)

	MOVE.W	D1,Resta1+8(A3)
	MOVE.W	D1,SubSLOTSR+(8*2)+2(A3)

	ADD.L	#$6001,D1
	MOVE.L	D1,Resta1+8+Desbor+0(A3)
	ADD.L	#$1FFF,D1
	MOVE.L	D1,Resta1+8+Desbor+4(A3)

	MOVEQ	#0,D1
	MOVE.W	A5,D1
	CogePag	D1,A5
	Otra2

SCC28b:
	MOVE.L	A4,D1
	SUB.L	PagWrite+16(A3),D1

	SUB.W	#$9000,D1
	BEQ.S	Pag2S1b
	Otra2

KON28b:
	MOVE.L	A4,D1
	SUB.L	PagWrite+16(A3),D1

	SUB.W	#$8000,D1
	NOP			; was: BCS.S	Pag2S1b (zero-length short branch)



Pag2S1b:
	SUB.W	(A7),A5

	BankNum	MaskROM3,NumROM3

	MULU	#$2080,D1
	ADD.L	MapROMBase2(A3),D1
	SUB.L	#$8000,D1

	MOVE.L	D1,PagRead+16(A3)
	MOVE.L	D1,SLOTS+(32*2)+16(A3)

	MOVE.W	D1,Resta2+0(A3)
	MOVE.W	D1,SLOTSR+(8*2)+4(A3)

	ADD.L	#$8001,D1
	MOVE.L	D1,Resta2+0+Desbor+0(A3)
	ADD.L	#$1FFF,D1
	MOVE.L	D1,Resta2+0+Desbor+4(A3)

	MOVEQ	#0,D1
	MOVE.W	A5,D1
	CogePag	D1,A5
	Otra2

SCC2Ab:
	MOVE.L	A4,D1
	SUB.L	PagWrite+20(A3),D1

	SUB.W	#$B000,D1
	BEQ.S	Pag3S1b
	Otra2

KON2Ab:
	MOVE.L	A4,D1
	SUB.L	PagWrite+20(A3),D1

	SUB.W	#$A000,D1
	NOP			; was: BEQ.S	Pag3S1b (zero-length short branch)



Pag3S1b:
	SUB.W	(A7),A5

	BankNum	MaskROM3,NumROM3

	MULU	#$2080,D1
	ADD.L	MapROMBase2(A3),D1
	SUB.L	#$A000,D1

	MOVE.L	D1,PagRead+20(A3)
	MOVE.L	D1,SubSLOTS+(32*2)+16(A3)

	MOVE.W	D1,Resta2+8(A3)
	MOVE.W	D1,SubSLOTSR+(8*2)+4(A3)

	ADD.L	#$A001,D1
	MOVE.L	D1,Resta2+8+Desbor+0(A3)
	ADD.L	#$1FFF,D1
	MOVE.L	D1,Resta2+8+Desbor+4(A3)

	MOVEQ	#0,D1
	MOVE.W	A5,D1
	CogePag	D1,A5
	Otra2

; -------------------------------------<=
; -------------------------------------<=

Asc16b:
	MOVE.L	A4,D1
	SUB.L	PagWrite+12(A3),D1

	SUB.W	#$6800,D1
	BCS	Pag0S1b

	SUB.W	#$800,D1
	BCS	Pag1S1b

	SUB.W	#$800,D1
	BCS	Pag2S1b

	BRA.S	Pag3S1b

; -------------------------------------<=
; -------------------------------------<=




; -------------------------------------<=
; -------------------------------------<=

; -------------------------------------<=
; -------------------------------------<=

	CNOP	0,8
	DS.L	20

	CNOP	0,8
MEMORYMAPPER:
	DC.L	RAM00,RAM00
	DC.L	RAM01,RAM01
	DC.L	RAM02,RAM02
	DC.L	RAM03,RAM03

	DC.L	RAM10,RAM10
	DC.L	RAM11,RAM11
	DC.L	RAM12,RAM12
	DC.L	RAM13,RAM13

	REPT	256-8
	DC.L	NOMEM,NORAM
	ENDR

; ------------------------------------------------------------------

	CNOP	0,8
INSCB:
	DC.L	RLCB0,RLCC,RLCD,RLCE,RLCH,RLCL,RLCHL,RLCA	; 00
	DC.L	RRCB,RRCC,RRCD,RRCE,RRCH,RRCL,RRCHL,RRCA	; 08
	DC.L	RLB,RLC,RLD,RLE,RLH,RLL,RLHL,RLA		; 10
	DC.L	RRB,RRC,RRD,RRE,RRH,RRL,RRHL,RRA		; 18
	DC.L	SLAB,SLAC,SLAD,SLAE,SLAH,SLAL,SLAHL,SLAA	; 20
	DC.L	SRAB,SRAC,SRAD,SRAE,SRAH,SRAL,SRAHL,SRAA	; 28
	DC.L	SRRB,SRRC,SRRD,SRRE,SRRH,SRRL,SRRHL,SRRA	; 30
	DC.L	SRLB,SRLC,SRLD,SRLE,SRLH,SRLL,SRLHL,SRLA	; 38
	DC.L	BIT0B,BIT0C,BIT0D,BIT0E,BIT0H,BIT0L,BIT0HL,BIT0A; 40
	DC.L	BIT1B,BIT1C,BIT1D,BIT1E,BIT1H,BIT1L,BIT1HL,BIT1A; 48
	DC.L	BIT2B,BIT2C,BIT2D,BIT2E,BIT2H,BIT2L,BIT2HL,BIT2A; 50
	DC.L	BIT3B,BIT3C,BIT3D,BIT3E,BIT3H,BIT3L,BIT3HL,BIT3A; 58
	DC.L	BIT4B,BIT4C,BIT4D,BIT4E,BIT4H,BIT4L,BIT4HL,BIT4A; 60
	DC.L	BIT5B,BIT5C,BIT5D,BIT5E,BIT5H,BIT5L,BIT5HL,BIT5A; 68
	DC.L	BIT6B,BIT6C,BIT6D,BIT6E,BIT6H,BIT6L,BIT6HL,BIT6A; 70
	DC.L	BIT7B,BIT7C,BIT7D,BIT7E,BIT7H,BIT7L,BIT7HL,BIT7A; 78
	DC.L	RES0B,RES0C,RES0D,RES0E,RES0H,RES0L,RES0HL,RES0A; 80
	DC.L	RES1B,RES1C,RES1D,RES1E,RES1H,RES1L,RES1HL,RES1A; 88
	DC.L	RES2B,RES2C,RES2D,RES2E,RES2H,RES2L,RES2HL,RES2A; 90
	DC.L	RES3B,RES3C,RES3D,RES3E,RES3H,RES3L,RES3HL,RES3A; 98
	DC.L	RES4B,RES4C,RES4D,RES4E,RES4H,RES4L,RES4HL,RES4A; A0
	DC.L	RES5B,RES5C,RES5D,RES5E,RES5H,RES5L,RES5HL,RES5A; A8
	DC.L	RES6B,RES6C,RES6D,RES6E,RES6H,RES6L,RES6HL,RES6A; B0
	DC.L	RES7B,RES7C,RES7D,RES7E,RES7H,RES7L,RES7HL,RES7A; B8
	DC.L	SET0B,SET0C,SET0D,SET0E,SET0H,SET0L,SET0HL,SET0A; C0
	DC.L	SET1B,SET1C,SET1D,SET1E,SET1H,SET1L,SET1HL,SET1A; C8
	DC.L	SET2B,SET2C,SET2D,SET2E,SET2H,SET2L,SET2HL,SET2A; D0
	DC.L	SET3B,SET3C,SET3D,SET3E,SET3H,SET3L,SET3HL,SET3A; D8
	DC.L	SET4B,SET4C,SET4D,SET4E,SET4H,SET4L,SET4HL,SET4A; E0
	DC.L	SET5B,SET5C,SET5D,SET5E,SET5H,SET5L,SET5HL,SET5A; E8
	DC.L	SET6B,SET6C,SET6D,SET6E,SET6H,SET6L,SET6HL,SET6A; F0
	DC.L	SET7B,SET7C,SET7D,SET7E,SET7H,SET7L,SET7HL,SET7A; F8

INSCBIX:
	DC.L	CBX0,NADA,NADA,NADA,NADA,NADA,RLCIX,NADA	; 00
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,RRCIX,NADA	; 08
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,RLIX,NADA		; 10
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,RRIX,NADA		; 18
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,SLAIX,NADA	; 20
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,SRAIX,NADA	; 28
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,SRRIX,NADA	; 30
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,SRLIX,NADA	; 38
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,BIT0IX,NADA	; 40
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,BIT1IX,NADA	; 48
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,BIT2IX,NADA	; 50
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,BIT3IX,NADA	; 58
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,BIT4IX,NADA	; 60
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,BIT5IX,NADA	; 68
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,BIT6IX,NADA	; 70
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,BIT7IX,NADA	; 78
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,RES0IX,NADA	; 80
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,RES1IX,NADA	; 88
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,RES2IX,NADA	; 90
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,RES3IX,NADA	; 98
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,RES4IX,NADA	; A0
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,RES5IX,NADA	; A8
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,RES6IX,NADA	; B0
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,RES7IX,NADA	; B8
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,SET0IX,NADA	; C0
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,SET1IX,NADA	; C8
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,SET2IX,NADA	; D0
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,SET3IX,NADA	; D8
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,SET4IX,NADA	; E0
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,SET5IX,NADA	; E8
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,SET6IX,NADA	; F0
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,SET7IX,NADA	; F8

INSCBIY:
	DC.L	CBY0,NADA,NADA,NADA,NADA,NADA,RLCIY,NADA	; 00
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,RRCIY,NADA	; 08
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,RLIY,NADA		; 10
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,RRIY,NADA		; 18
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,SLAIY,NADA	; 20
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,SRAIY,NADA	; 28
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,SRRIY,NADA	; 30
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,SRLIY,NADA	; 38
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,BIT0IY,NADA	; 40
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,BIT1IY,NADA	; 48
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,BIT2IY,NADA	; 50
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,BIT3IY,NADA	; 58
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,BIT4IY,NADA	; 60
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,BIT5IY,NADA	; 68
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,BIT6IY,NADA	; 70
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,BIT7IY,NADA	; 78
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,RES0IY,NADA	; 80
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,RES1IY,NADA	; 88
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,RES2IY,NADA	; 90
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,RES3IY,NADA	; 98
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,RES4IY,NADA	; A0
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,RES5IY,NADA	; A8
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,RES6IY,NADA	; B0
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,RES7IY,NADA	; B8
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,SET0IY,NADA	; C0
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,SET1IY,NADA	; C8
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,SET2IY,NADA	; D0
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,SET3IY,NADA	; D8
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,SET4IY,NADA	; E0
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,SET5IY,NADA	; E8
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,SET6IY,NADA	; F0
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,SET7IY,NADA	; F8

INSDD:
	DC.L	DD00,NOCO,NOCO,NOCO,NOCO,NOCO,NOCO,NOCO		; 00
	DC.L	NOCO,ADDIXBC,NOCO,NOCO,NOCO,NOCO,NOCO,NOCO	; 08
	DC.L	NOCO,NOCO,NOCO,NOCO,NOCO,NOCO,NOCO,NOCO		; 10
	DC.L	NOCO,ADDIXDE,NOCO,NOCO,NOCO,NOCO,NOCO,NOCO	; 18
	DC.L	NOCO,LDIXN,LDMIX,INCIX,INCHX,DECHX,LDHXN,NOCO	; 20
	DC.L	NOCO,ADDIXIX,LDIXM,DECIX,INCLX,DECLX,LDLXN,NOCO	; 28
	DC.L	NOCO,NOCO,NOCO,NOCO,INCIXM,DECIXM,LDIXMN,NOCO	; 30
	DC.L	NOCO,ADDIXSP,NOCO,NOCO,NOCO,NOCO,NOCO,NOCO	; 38
	DC.L	LDBB,LDBC,LDBD,LDBE,LDBHX,LDBLX,LDBIX,LDBA	; 40
	DC.L	LDCB,LDCC,LDCD,LDCE,LDCHX,LDCLX,LDCIX,LDCA	; 48
	DC.L	LDDB,LDDC,LDDD,LDDE,LDDHX,LDDLX,LDDIX,LDDA	; 50
	DC.L	LDEB,LDEC,LDED,LDEE,LDEHX,LDELX,LDEIX,LDEA	; 58
	DC.L	LDHXB,LDHXC,LDHXD,LDHXE,LDHXH,LDHXL,LDHIX,LDHXA	; 60
	DC.L	LDLXB,LDLXC,LDLXD,LDLXE,LDLXH,LDLXL,LDLIX,LDLXA	; 68
	DC.L	LDIXB,LDIXC,LDIXD,LDIXE,LDIXH,LDIXL,NOCO,LDIXA	; 70
	DC.L	LDAB,LDAC,LDAD,LDAE,LDAHX,LDALX,LDAIX,LDAA	; 78
	DC.L	NOCO,NOCO,NOCO,NOCO,ADDAHX,ADDALX,ADDAIX,NOCO	; 80
	DC.L	NOCO,NOCO,NOCO,NOCO,ADCAHX,ADCALX,ADCAIX,NOCO	; 88
	DC.L	NOCO,NOCO,NOCO,NOCO,SUBHX,SUBLX,SUBIX,NOCO	; 90
	DC.L	NOCO,NOCO,NOCO,NOCO,SBCHX,SBCLX,SBCIX,NOCO	; 98
	DC.L	NOCO,NOCO,NOCO,NOCO,ANDHX,ANDLX,ANDIX,NOCO	; A0
	DC.L	NOCO,NOCO,NOCO,NOCO,XORHX,XORLX,XORIX,NOCO	; A8
	DC.L	NOCO,NOCO,NOCO,NOCO,ORHX,ORLX,ORIX,NOCO		; B0
	DC.L	NOCO,NOCO,NOCO,NOCO,CPHX,CPLX,CPIX,NOCO		; B8
	DC.L	NOCO,NOCO,NOCO,NOCO,NOCO,NOCO,NOCO,NOCO		; C0
	DC.L	NOCO,NOCO,NOCO,RINSCBIX,NOCO,NOCO,NOCO,NOCO	; C8
	DC.L	NOCO,NOCO,NOCO,NOCO,NOCO,NOCO,NOCO,NOCO		; D0
	DC.L	NOCO,NOCO,NOCO,NOCO,NOCO,NOCO,NOCO,NOCO		; D8
	DC.L	NOCO,POPIX,NOCO,EXSPMIX,NOCO,PUSHIX,NOCO,NOCO	; E0
	DC.L	NOCO,JPIX,NOCO,NOCO,NOCO,NOCO,NOCO,NOCO		; E8
	DC.L	NOCO,NOCO,NOCO,NOCO,NOCO,NOCO,NOCO,NOCO		; F0
	DC.L	NOCO,LDSPIX,NOCO,NOCO,NOCO,NOCO,NOCO,NOCO	; F8

INSFD:
	DC.L	FD00,NOCO,NOCO,NOCO,NOCO,NOCO,NOCO,NOCO		; 00
	DC.L	NOCO,ADDIYBC,NOCO,NOCO,NOCO,NOCO,NOCO,NOCO	; 08
	DC.L	NOCO,NOCO,NOCO,NOCO,NOCO,NOCO,NOCO,NOCO		; 10
	DC.L	NOCO,ADDIYDE,NOCO,NOCO,NOCO,NOCO,NOCO,NOCO	; 18
	DC.L	NOCO,LDIYN,LDMIY,INCIY,INCHY,DECHY,LDHYN,NOCO	; 20
	DC.L	NOCO,ADDIYIY,LDIYM,DECIY,INCLY,DECLY,LDLYN,NOCO	; 28
	DC.L	NOCO,NOCO,NOCO,NOCO,INCIYM,DECIYM,LDIYMN,NOCO	; 30
	DC.L	NOCO,ADDIYSP,NOCO,NOCO,NOCO,NOCO,NOCO,NOCO	; 38
	DC.L	LDBB,LDBC,LDBD,LDBE,LDBHY,LDBLY,LDBIY,LDBA	; 40
	DC.L	LDCB,LDCC,LDCD,LDCE,LDCHY,LDCLY,LDCIY,LDCA	; 48
	DC.L	LDDB,LDDC,LDDD,LDDE,LDDHY,LDDLY,LDDIY,LDDA	; 50
	DC.L	LDEB,LDEC,LDED,LDEE,LDEHY,LDELY,LDEIY,LDEA	; 58
	DC.L	LDHYB,LDHYC,LDHYD,LDHYE,LDHYH,LDHYL,LDHIY,LDHYA	; 60
	DC.L	LDLYB,LDLYC,LDLYD,LDLYE,LDLYH,LDLYL,LDLIY,LDLYA	; 68
	DC.L	LDIYB,LDIYC,LDIYD,LDIYE,LDIYH,LDIYL,NOCO,LDIYA	; 70
	DC.L	LDAB,LDAC,LDAD,LDAE,LDAHY,LDALY,LDAIY,LDAA	; 78
	DC.L	NOCO,NOCO,NOCO,NOCO,ADDAHY,ADDALY,ADDAIY,NOCO	; 80
	DC.L	NOCO,NOCO,NOCO,NOCO,ADCAHY,ADCALY,ADCAIY,NOCO	; 88
	DC.L	NOCO,NOCO,NOCO,NOCO,SUBHY,SUBLY,SUBIY,NOCO	; 90
	DC.L	NOCO,NOCO,NOCO,NOCO,SBCHY,SBCLY,SBCIY,NOCO	; 98
	DC.L	NOCO,NOCO,NOCO,NOCO,ANDHY,ANDLY,ANDIY,NOCO	; A0
	DC.L	NOCO,NOCO,NOCO,NOCO,XORHY,XORLY,XORIY,NOCO	; A8
	DC.L	NOCO,NOCO,NOCO,NOCO,ORHY,ORLY,ORIY,NOCO		; B0
	DC.L	NOCO,NOCO,NOCO,NOCO,CPHY,CPLY,CPIY,NOCO		; B8
	DC.L	NOCO,NOCO,NOCO,NOCO,NOCO,NOCO,NOCO,NOCO		; C0
	DC.L	NOCO,NOCO,NOCO,RINSCBIY,NOCO,NOCO,NOCO,NOCO	; C8
	DC.L	NOCO,NOCO,NOCO,NOCO,NOCO,NOCO,NOCO,NOCO		; D0
	DC.L	NOCO,NOCO,NOCO,NOCO,NOCO,NOCO,NOCO,NOCO		; D8
	DC.L	NOCO,POPIY,NOCO,EXSPMIY,NOCO,PUSHIY,NOCO,NOCO	; E0
	DC.L	NOCO,JPIY,NOCO,NOCO,NOCO,NOCO,NOCO,NOCO		; E8
	DC.L	NOCO,NOCO,NOCO,NOCO,NOCO,NOCO,NOCO,NOCO		; F0
	DC.L	NOCO,LDSPIY,NOCO,NOCO,NOCO,NOCO,NOCO,NOCO	; F8

INSED:
	DC.L	ED00,NADA,NADA,NADA,NADA,NADA,NADA,NADA		; 00
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,NADA,NADA		; 08
	DC.L	ED10,ED11,ED12,ED13,ED14,ED15,ED16,NADA		; 10 (ED17 Usado!)
	DC.L	ED18,ED19,ED1A,ED1B,NADA,NADA,NADA,NADA		; 18
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,NADA,NADA		; 20
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,NADA,NADA		; 28
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,NADA,NADA		; 30
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,NADA,NADA		; 38
	DC.L	INBC,OUTCB,SBCHLBC,LDMBC,NEG,RETN,IM0,LDIA	; 40
	DC.L	IINCC,OUTCC,ADCHLBC,LDBCM,NADA,RETI,NADA,LDRA	; 48
	DC.L	INDC,OUTCD,SBCHLDE,LDMDE,NADA,NADA,IM1,LDAI	; 50
	DC.L	INEC,OUTCE,ADCHLDE,LDDEM,NADA,NADA,IM2,LDAR	; 58
	DC.L	INHC,OUTCH,SBCHLHL,LDMHL2,NADA,NADA,NADA,IRRD	; 60
	DC.L	INLC,OUTCL,ADCHLHL,LDHLM2,NADA,NADA,NADA,IRLD	; 68
	DC.L	IINFC,NADA,SBCHLSP,LDMSP,NADA,NADA,NADA,NADA	; 70
	DC.L	INAC,OUTCA,ADCHLSP,LDSPM,NADA,NADA,NADA,NADA	; 78
	DC.L	NADA,NADA,NADA,OTIR,NADA,NADA,NADA,NADA		; 80
	DC.L	NADA,NADA,NADA,OTDR,NADA,NADA,NADA,NADA		; 88
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,NADA,NADA		; 90
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,NADA,NADA		; 98
	DC.L	LDI,CPI,INI,OUTI,NADA,NADA,NADA,NADA		; A0
	DC.L	LDD,ICPD,IND,OUTD,NADA,NADA,NADA,NADA		; A8
	DC.L	LDIR,CPIR,INIR,OTIR,NADA,NADA,NADA,NADA		; B0
	DC.L	LDDR,CPDR,INDR,OTDR,NADA,NADA,NADA,NADA		; B8
	DC.L	NADA,MULUBAB,NADA,MULUWHLBC,MULUBAB,NADA,NADA,NADA	; C0
	DC.L	NADA,MULUBAC,NADA,NADA,NADA,MULUBAC,NADA,NADA	; C8
	DC.L	NADA,MULUBAD,NADA,NADA,NADA,MULUBAD,NADA,NADA	; D0
	DC.L	NADA,MULUBAE,NADA,NADA,NADA,MULUBAE,NADA,NADA	; D8
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,NADA,NADA		; E0
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,NADA,NADA		; E8
	DC.L	NADA,NADA,NADA,MULUWHLSP,NADA,NADA,NADA,NADA	; F0
	DC.L	NADA,NADA,NADA,NADA,NADA,NADA,NADA,NADA		; F8

********************************************************************

; ------------------------------------------------------------------	
	CNOP	0,4
OUTXX:	RTS
	CNOP	0,4
OUT00:
	CMP.L	Desbor+4+4(A7),A5
	BGT.S	OUT0C
OUT00Rut:
	RTS
	CNOP	0,4
OUT0C:	MOVE.B	D1,D2
	SUBQ.W	#1,A5
	MOVE.W	A5,D1
	SUB.W	4(A7),D1
	CogePag	D1,A5
	MOVE.L	(A7),A4				; Dir para el RTS
	LEA	Restas-4(A3,D1.W*8),A7
	MOVE.L	A4,(A7)				; Dir para el RTS
	MOVE.B	D2,D1
	MOVE.B	(A5)+,D2
	TST.B	D1
	JMP	([OUTS-$400.W,PC,D2.W*4])	; Salta a puntero de emulaci�n.
; ------------------------------------------------------------------	
	CNOP	0,4
IN00:
	CMP.L	Desbor+4+4(A7),A5
	BGT.S	IN0C
IN00Rut:
	RTS
	CNOP	0,4
IN0C:	SUBQ.W	#1,A5
	MOVE.W	A5,D1
	SUB.W	4(A7),D1
	CogePag	D1,A5
	MOVE.L	(A7),A4				; Dir para el RTS
	LEA	Restas-4(A3,D1.W*8),A7
	MOVE.L	A4,(A7)				; Dir para el RTS
	MOVE.B	(A5)+,D2
	JMP	([Ins-$400.W,PC,D2.W*4])	; Salta a puntero de emulaci�n.
	CNOP	0,4
; ------------------------------------------------------------------	

; -------------------------------------------------------------------
; *******************************************************************
; -------------------------------------------------------------------

	CNOP	0,8
INS:
	DC.L	IN00,InXX,InXX,InXX,InXX,InXX,InXX,InXX		; 00
	DC.L	InXX,InXX,InXX,InXX,InXX,InXX,InXX,InXX		; 08
	DC.L	InXX,InXX,InXX,InXX,InXX,InXX,InXX,InXX		; 10
	DC.L	InXX,InXX,InXX,InXX,InXX,InXX,InXX,InXX		; 18
	DC.L	InXX,InXX,InXX,InXX,InXX,InXX,InXX,InXX		; 20
	DC.L	InXX,InXX,InXX,InXX,InXX,InXX,InXX,InXX		; 28
	DC.L	InXX,InXX,InXX,InXX,InXX,InXX,InXX,InXX		; 30
	DC.L	InXX,InXX,InXX,InXX,InXX,InXX,InXX,InXX		; 38
	DC.L	InXX,InXX,InXX,InXX,InXX,InXX,InXX,InXX		; 40
	DC.L	InXX,InXX,InXX,InXX,InXX,InXX,InXX,InXX		; 48
	DC.L	InXX,InXX,InXX,InXX,InXX,InXX,InXX,InXX		; 50
	DC.L	InXX,InXX,InXX,InXX,InXX,InXX,InXX,InXX		; 58
	DC.L	InXX,InXX,InXX,InXX,InXX,InXX,InXX,InXX		; 60
	DC.L	InXX,InXX,InXX,InXX,InXX,InXX,InXX,InXX		; 68
	DC.L	InXX,InXX,InXX,InXX,InXX,InXX,InXX,InXX		; 70
	DC.L	InXX,InXX,InXX,InXX,IN7C,IN7D,InXX,InXX		; 78
	DC.L	InXX,InXX,InXX,InXX,InXX,InXX,InXX,InXX		; 80
	DC.L	InXX,InXX,InXX,InXX,InXX,InXX,InXX,InXX		; 88
	DC.L	IN90,InXX,InXX,InXX,InXX,InXX,InXX,InXX		; 90
	DC.L	IN98,IN99,InXX,InXX,InXX,InXX,InXX,InXX		; 98
	DC.L	INA0,INA1,INA2,InXX,InXX,InXX,InXX,InXX		; A0
	DC.L	INA8,INA9,INAA,InXX,InXX,InXX,InXX,InXX		; A8
	DC.L	InXX,InXX,InXX,InXX,INB4,INB5,InXX,InXX		; B0
	DC.L	InXX,InXX,InXX,InXX,InXX,InXX,InXX,InXX		; B8
	DC.L	InXX,InXX,InXX,InXX,InXX,InXX,InXX,InXX		; C0
	DC.L	InXX,InXX,InXX,InXX,InXX,InXX,InXX,InXX		; C8
	DC.L	IND0,IND0,IND0,IND0,IND0,InXX,InXX,InXX		; D0
	DC.L	InXX,InXX,InXX,InXX,InXX,InXX,InXX,InXX		; D8
	DC.L	InXX,InXX,InXX,InXX,InXX,InXX,InXX,InXX		; E0
	DC.L	InXX,InXX,InXX,InXX,InXX,InXX,InXX,InXX		; E8
	DC.L	InXX,InXX,InXX,InXX,InXX,InXX,InXX,InXX		; F0
	DC.L	InXX,InXX,InXX,InXX,INFC,INFD,INFE,INFF		; F8

	CNOP	0,8
OUTS:
	DC.L	OUT00,OutXX,OutXX,OutXX,OutXX,OutXX,OutXX,OutXX	  ; 00
	DC.L	OutXX,OutXX,OutXX,OutXX,OutXX,OutXX,OutXX,OutXX	  ; 08
	DC.L	OutXX,OutXX,OutXX,OutXX,OutXX,OutXX,OutXX,OutXX	  ; 10
	DC.L	OutXX,OutXX,OutXX,OutXX,OutXX,OutXX,OutXX,OutXX	  ; 18
	DC.L	OutXX,OutXX,OutXX,OutXX,OutXX,OutXX,OutXX,OutXX	  ; 20
	DC.L	OutXX,OutXX,OutXX,OutXX,OutXX,OutXX,OutXX,OutXX	  ; 28
	DC.L	OutXX,OutXX,OutXX,OutXX,OutXX,OutXX,OutXX,OutXX	  ; 30
	DC.L	OutXX,OutXX,OutXX,OutXX,OutXX,OutXX,OutXX,OutXX	  ; 38
	DC.L	OutXX,OutXX,OutXX,OutXX,OutXX,OutXX,OutXX,OutXX	  ; 40
	DC.L	OutXX,OutXX,OutXX,OutXX,OutXX,OutXX,OutXX,OutXX	  ; 48
	DC.L	OutXX,OutXX,OutXX,OutXX,OutXX,OutXX,OutXX,OutXX	  ; 50
	DC.L	OutXX,OutXX,OutXX,OutXX,OutXX,OutXX,OutXX,OutXX	  ; 58
	DC.L	OutXX,OutXX,OutXX,OutXX,OutXX,OutXX,OutXX,OutXX	  ; 60
	DC.L	OutXX,OutXX,OutXX,OutXX,OutXX,OutXX,OutXX,OutXX	  ; 68
	DC.L	OutXX,OutXX,OutXX,OutXX,OutXX,OutXX,OutXX,OutXX	  ; 70
	DC.L	OutXX,OutXX,OutXX,OutXX,OUT7C,OUT7D,OutXX,OutXX	  ; 78
	DC.L	OutXX,OutXX,OutXX,OutXX,OutXX,OutXX,OutXX,OutXX	  ; 80
	DC.L	OutXX,OutXX,OutXX,OutXX,OutXX,OutXX,OutXX,OutXX	  ; 88
	DC.L	OUT90,OUT91,OutXX,OutXX,OutXX,OutXX,OutXX,OutXX	  ; 90
	DC.L	OUT98,OUT99a,OUT9Aa,OUT9B,OutXX,OutXX,OutXX,OutXX ; 98
	DC.L	OUTA0,OUTA1,OutXX,OutXX,OutXX,OutXX,OutXX,OutXX	  ; A0
	DC.L	OUTA8,OutXX,OUTAA,OUTAB,OutXX,OutXX,OutXX,OutXX	  ; A8
	DC.L	OutXX,OutXX,OutXX,OutXX,OUTB4,OUTB5,OutXX,OutXX	  ; B0
	DC.L	OutXX,OutXX,OutXX,OutXX,OutXX,OutXX,OutXX,OutXX	  ; B8
	DC.L	OutXX,OutXX,OutXX,OutXX,OutXX,OutXX,OutXX,OutXX	  ; C0
	DC.L	OutXX,OutXX,OutXX,OutXX,OutXX,OutXX,OutXX,OutXX	  ; C8
	DC.L	OutXX,OutXX,OutXX,OutXX,OutXX,OutXX,OutXX,OutXX	  ; D0
	DC.L	OutXX,OutXX,OutXX,OutXX,OutXX,OutXX,OutXX,OutXX	  ; D8
	DC.L	OutXX,OutXX,OutXX,OutXX,OutXX,OutXX,OutXX,OutXX	  ; E0
	DC.L	OutXX,OutXX,OutXX,OutXX,OutXX,OutXX,OutXX,OutXX	  ; E8
	DC.L	OutXX,OutXX,OutXX,OutXX,OutXX,OutXX,OutXX,OutXX	  ; F0
	DC.L	OutXX,OutXX,OutXX,OutXX,OUTFC,OUTFD,OUTFE,OUTFF	  ; F8
********************************************************************



	CNOP	0,8
; Mask screen edges (PrefMask): the display window is 8 dots wider than the
; 256 picture dots (3 left, 5 right, measured in WinUAE), so hiding 8 dots
; each side moves its edges in by these.
EDGEL=11
EDGER=13
Act_Adjust:
	IFD	TRACE
	TRVLOG	$FD,MidAdj
	TRVLOG	$FC,TSplit+1
	TRVLOG	$FB,TopR8
	ENDC
	MOVE.B	MidAdj,D2		; R#18 of the playfield (MIDSAMPLE: a split
	AND.W	#$000F,D2		; may change it below: Lilly's Saga HUD).

	MOVE.W	(AdjustBuf,D2.W*4),AdjustX+10
	MOVE.B	(AdjustBuf+2,D2.W*4),VERPAN+3
	MOVE.B	(AdjustBuf+2,D2.W*4),VERPAN+7
	TST.B	PrefMask		; Mask screen edges (menu): the window 8
	BEQ.S	ActAdjNoMask		; dots narrower each side, where games
	ADD.B	#EDGEL,VERPAN+3		; redraw columns while they scroll
	SUB.B	#EDGER,VERPAN+7		; (Lilly's Saga).
ActAdjNoMask:

	BTST	#1,TopR8		; Playfield R#8 (MIDSAMPLE).
	BNE	Act_AdjCon

	MOVE.L	(AdjustSpr.w,PC,D2.W*4),D1

	LEA	SPRIT0+1,A0
	LEA	SPRIT0b+1,A1

	MOVE.B	D1,8(A0)
	MOVE.B	D1,(NEXSPR*1)+8(A0)
	MOVE.B	D1,8(A1)
	MOVE.B	D1,(NEXSPR*1)+8(A1)
	SWAP	D1
	MOVE.B	D1,(A0)
	MOVE.B	D1,(NEXSPR*1)(A0)
	MOVE.B	D1,(A1)
	MOVE.B	D1,(NEXSPR*1)(A1)
	ADD.W	#$20,D1
	SWAP	D1
	MOVE.B	D1,(NEXSPR*2)+8(A0)
	MOVE.B	D1,(NEXSPR*3)+8(A0)
	MOVE.B	D1,(NEXSPR*2)+8(A1)
	MOVE.B	D1,(NEXSPR*3)+8(A1)
	SWAP	D1
	MOVE.B	D1,(NEXSPR*2)(A0)
	MOVE.B	D1,(NEXSPR*3)(A0)
	MOVE.B	D1,(NEXSPR*2)(A1)
	MOVE.B	D1,(NEXSPR*3)(A1)
	ADD.W	#$20,D1
	SWAP	D1
	MOVE.B	D1,(NEXSPR*4)+8(A0)
	MOVE.B	D1,(NEXSPR*5)+8(A0)
	MOVE.B	D1,(NEXSPR*4)+8(A1)
	MOVE.B	D1,(NEXSPR*5)+8(A1)
	SWAP	D1
	MOVE.B	D1,(NEXSPR*4)(A0)
	MOVE.B	D1,(NEXSPR*5)(A0)
	MOVE.B	D1,(NEXSPR*4)(A1)
	MOVE.B	D1,(NEXSPR*5)(A1)
	ADD.W	#$20,D1
	SWAP	D1
	MOVE.B	D1,(NEXSPR*6)+8(A0)
	MOVE.B	D1,(NEXSPR*7)+8(A0)
	MOVE.B	D1,(NEXSPR*6)+8(A1)
	MOVE.B	D1,(NEXSPR*7)+8(A1)
	SWAP	D1
	MOVE.B	D1,(NEXSPR*6)(A0)
	MOVE.B	D1,(NEXSPR*7)(A0)
	MOVE.B	D1,(NEXSPR*6)(A1)
	MOVE.B	D1,(NEXSPR*7)(A1)
	RTS
	CNOP	0,8
Act_AdjCon:
	MOVE.W	#INISPR2*$100+$D8,D1
	LEA	SPRIT0+1,A4
	MOVE.B	D1,(A4)
	MOVE.B	D1,(NEXSPR*1)(A4)
	MOVE.B	D1,(NEXSPR*2)(A4)
	MOVE.B	D1,(NEXSPR*3)(A4)
	MOVE.B	D1,(NEXSPR*4)(A4)
	MOVE.B	D1,(NEXSPR*5)(A4)
	MOVE.B	D1,(NEXSPR*6)(A4)
	MOVE.B	D1,(NEXSPR*7)(A4)
	LEA	SPRIT0b+1,A4
	MOVE.B	D1,(A4)
	MOVE.B	D1,(NEXSPR*1)(A4)
	MOVE.B	D1,(NEXSPR*2)(A4)
	MOVE.B	D1,(NEXSPR*3)(A4)
	MOVE.B	D1,(NEXSPR*4)(A4)
	MOVE.B	D1,(NEXSPR*5)(A4)
	MOVE.B	D1,(NEXSPR*6)(A4)
	MOVE.B	D1,(NEXSPR*7)(A4)
	RTS



;   ---------------------------------------------------------------------
;  -=====================================================================-
; <***********************************************************************>
;  -=====================================================================-
;   ---------------------------------------------------------------------




;	 ----------------------
;	/  V   V  DDD    PPPP  \
;	|  V   V  D  D   P   P |   -*  Emulador VDP Y9938 v3.07  *-
;	|  V   V  D   D  PPPP  |
;	|   V V   D  D   P     |    Por: Juan Antonio G�mez G�lvez.
;	\    V    DDD    P     /
;	 ----------------------

;		-*(  Ejecutar bajo MC68020 o superior. )*-

IniPant=$30-5

INISPR2=INIPANT-14
FINSPR2=INISPR2


	CNOP	0,8
; <=---------------------------------------------------------=>

; ---------------------------------------=> Screen 0,1,2,3
ModoTxt:
	MOVE.L	(A7)+,RetOut(A3)

	MOVE.W	#$0003,MCAGA+2
	MOVEM.L	D0-D2/A0-A1,BUFER(A3)
	LEA	DIRSPRITES,A0
	JSR	CREASPRITES
	MOVEM.L	BUFER(A3),D0-D2/A0-A1

	MOVE.L	#VDP12mT,VDPPunt+($12*4)
	MOVE.L	#VDP17,VDPPUNT+($17*4)

	MOVE.L	#VDP2Enada,VDPPUNT+($2E*4)
	BCLR	#0,DVDPS2(A3)		; Ejecuci�n SI terminada.

	JSR	([DirModoChg.W,A3])		; Actualiza Bit-Planos en VRAM.
	MOVE.L	#ModoChgRET,DirModoChg(A3)

;;	MOVE.B	D1,ScrModo(A3)
	MOVE.L	#IN98,DREGIN98(A3)
	MOVE.L	#OUT98,DREGOUT98(A3)
	TST.B	V5All
	BNE.S	V5AllKeep1		; (A label: the MOVE's size depends on the layout.)
	MOVE.L	#OUT98M,DREGOUT98(A3)
V5AllKeep1:

	MOVE.L	RetOut(A3),-(A7)

	RTS
; ---------------------------------------<=

; ---------------------------------------=> Screen 0b
	CNOP	0,4
ModoTxtX:
	MOVE.L	(A7)+,RetOut(A3)

	MOVE.W	#$0003,MCAGA+2
	MOVEM.L	D0-D2/A0-A1,BUFER(A3)
	LEA	DIRSPRITES,A0
	JSR	CREASPRITES
	MOVEM.L	BUFER(A3),D0-D2/A0-A1

	MOVE.L	#VDP12mT,VDPPunt+($12*4)
	MOVE.L	#VDP17,VDPPUNT+($17*4)

	MOVE.L	#VDP2Enada,VDPPUNT+($2E*4)
	BCLR	#0,DVDPS2(A3)		; Ejecuci�n SI terminada.

	JSR	([DirModoChg.W,A3])		; Actualiza Bit-Planos en VRAM.
	MOVE.L	#ModoChgRET,DirModoChg(A3)

;;	MOVE.B	D1,ScrModo(A3)
	MOVE.L	#IN98X,DREGIN98(A3)
	MOVE.L	#OUT98X,DREGOUT98(A3)
	TST.B	V5All
	BNE.S	V5AllKeep2		; (A label: the MOVE's size depends on the layout.)
	MOVE.L	#OUT98XM,DREGOUT98(A3)
V5AllKeep2:

	MOVE.L	RetOut(A3),-(A7)

	RTS
; ---------------------------------------<=

; ---------------------------------------=> Screen 4
	CNOP	0,4
ModoTxt4:
	MOVE.L	(A7)+,RetOut(A3)

	MOVE.W	#$000F,MCAGA+2
	MOVEM.L	D0-D2/A0-A1,BUFER(A3)
	LEA	DIRSPRITES2,A0
	JSR	CREASPRITES
	MOVEM.L	BUFER(A3),D0-D2/A0-A1

	MOVE.L	#VDP12,VDPPunt+($12*4)
	MOVE.L	#VDP17,VDPPUNT+($17*4)

	MOVE.L	#VDP2Enada,VDPPUNT+($2E*4)
	BCLR	#0,DVDPS2(A3)		; Ejecuci�n SI terminada.

	JSR	([DirModoChg.W,A3])		; Actualiza Bit-Planos en VRAM.
	MOVE.L	#ModoChgRET,DirModoChg(A3)

;;	MOVE.B	D1,ScrModo(A3)
	MOVE.L	#IN98X,DREGIN98(A3)
	MOVE.L	#OUT98X,DREGOUT98(A3)
	TST.B	V5All
	BNE.S	V5AllKeep3		; (A label: the MOVE's size depends on the layout.)
	MOVE.L	#OUT98XM,DREGOUT98(A3)
V5AllKeep3:

	MOVE.L	RetOut(A3),-(A7)

	RTS
; ---------------------------------------<=

; ---------------------------------------=> Screen 6
	CNOP	0,4
ModoGfx6:
	MOVE.L	(A7)+,RetOut(A3)
	ST	V5All			; (SCR0 reused: SCREEN 5/7 planes gone.)

	MOVE.W	#$000F,MCAGA+2
	MOVEM.L	D0-D2/A0-A1,BUFER(A3)
	LEA	DIRSPRITES2,A0
	JSR	CREASPRITES
	MOVEM.L	BUFER(A3),D0-D2/A0-A1

M6Cap:	MOVE.L	#VDP12,VDPPunt+($12*4)
	MOVE.L	#VDP17,VDPPUNT+($17*4)

	MOVE.L	#VDP2E,VDPPUNT+($2E*4)
	MOVE.L	#Modo6Dats,MSXVideoMode(A3)
	BCLR	#0,DVDPS2(A3)		; Ejecuci�n SI terminada.

;	JSR	([DirModoChg.W,A3])		; Actualiza Bit-Planos en VRAM.
;	BSR	ActPlanos6			; Actualiza VRAM en Bit-Planos.
;	MOVE.L	#ModoChg6a0,DirModoChg(A3)

;;	MOVE.B	D1,ScrModo(A3)
	MOVE.L	#IN98C,DREGIN98(A3)
	MOVE.L	#OUT98C,DREGOUT98(A3)

	MOVE.L	RetOut(A3),-(A7)

	RTS
; ---------------------------------------<=

; ---------------------------------------=> Screen 5
	CNOP	0,4
ModoGfx5:
	MOVE.L	(A7)+,RetOut(A3)

	MOVE.W	#$000F,MCAGA+2
	MOVEM.L	D0-D2/A0-A1,BUFER(A3)
	LEA	DIRSPRITES2,A0
	JSR	CREASPRITES
	MOVEM.L	BUFER(A3),D0-D2/A0-A1

M5Cap:	MOVE.L	#VDP12,VDPPunt+($12*4)
	MOVE.L	#VDP17,VDPPunt+($17*4)	; *m5

	MOVE.L	#VDP2E,VDPPUNT+($2E*4)
	MOVE.L	#Modo5Dats,MSXVideoMode(A3)
	BCLR	#0,DVDPS2(A3)			; Ejecuci�n SI terminada.

	JSR	([DirModoChg.W,A3])		; Actualiza Bit-Planos en VRAM.
	BSR	ActPlanos5			; Actualiza VRAM en Bit-Planos.
	MOVE.L	#ModoChg5a0,DirModoChg(A3)

;;	MOVE.B	D1,ScrModo(A3)
	MOVE.L	#IN98A,DREGIN98(A3)
	MOVE.L	#OUT98A,DREGOUT98(A3)
	TST.B	MSplitSeen
	BNE.S	M5AT
	ST	SCRTDirty		; (Plain OUT98A: SCREENT may go stale,
	SF	M5Tracked		; and the SCREEN 4 cache.)
	BRA.S	M5NoAT
M5AT:	MOVE.L	#OUT98AT,DREGOUT98(A3)
	ST	M5Tracked
M5NoAT:
	SWAP	D2
	MOVEQ	#$17,D1
	MOVE.B	VDPLINY(A3),D2

	MOVE.L	RetOut(A3),-(A7)

	JMP	([VDPPUNT.W,PC,D1.W*4])
; ---------------------------------------<=

; ---------------------------------------=> Screen 7
	CNOP	0,4
ModoGfx7:
	MOVE.L	(A7)+,RetOut(A3)

	MOVE.W	#$000F,MCAGA+2
	MOVEM.L	D0-D2/A0-A1,BUFER(A3)
	LEA	DIRSPRITES2,A0
	JSR	CREASPRITES
	MOVEM.L	BUFER(A3),D0-D2/A0-A1

M7Cap:	MOVE.L	#VDP12,VDPPunt+($12*4)
	MOVE.L	#VDP17,VDPPUNT+($17*4)	; *m7

	MOVE.L	#VDP2E,VDPPUNT+($2E*4)
	MOVE.L	#Modo7Dats,MSXVideoMode(A3)
	BCLR	#0,DVDPS2(A3)		; Ejecuci�n SI terminada.

	JSR	([DirModoChg.W,A3])		; Actualiza Bit-Planos en VRAM.
	BSR	ActPlanos7			; Actualiza VRAM en Bit-Planos.
	MOVE.L	#ModoChg7a0,DirModoChg(A3)

;;	MOVE.B	D1,ScrModo(A3)
	MOVE.L	#IN98A,DREGIN98(A3)
	SF	M5Tracked
	ST	SCRTDirty
	MOVE.L	#OUT98A,DREGOUT98(A3)
	SWAP	D2
	MOVEQ	#$17,D1
	MOVE.B	VDPLINY(A3),D2

	MOVE.L	RetOut(A3),-(A7)

	JMP	([VDPPUNT.W,PC,D1.W*4])
; ---------------------------------------<=

; ---------------------------------------=> Screen 8
	CNOP	0,4
ModoGfx8:
	MOVE.L	(A7)+,RetOut(A3)
	ST	V5All			; (SCR0 reused: SCREEN 5/7 planes gone.)

	MOVE.W	#$000F,MCAGA+2
	MOVEM.L	D0-D2/A0-A1,BUFER(A3)
	LEA	DIRSPRITES2,A0
	JSR	CREASPRITES
	MOVEM.L	BUFER(A3),D0-D2/A0-A1

M8Cap:	MOVE.L	#VDP12,VDPPunt+($12*4)
M8Chap:	MOVE.L	#VDP17,VDPPUNT+($17*4)	; *m8

	MOVE.L	#VDP2E,VDPPUNT+($2E*4)
	MOVE.L	#Modo8Dats,MSXVideoMode(A3)
	BCLR	#0,DVDPS2(A3)		; Ejecuci�n SI terminada.

;	JSR	([DirModoChg.W,A3])		; Actualiza Bit-Planos en VRAM.
;	BSR	ActPlanos8			; Actualiza VRAM en Bit-Planos.
;	MOVE.L	#ModoChg8a0,DirModoChg(A3)

;;	MOVE.B	D1,ScrModo(A3)
	MOVE.L	#IN98B,DREGIN98(A3)
	MOVE.L	#OUT98B,DREGOUT98(A3)
	SWAP	D2
	MOVEQ	#$17,D1
	MOVE.B	VDPLINY(A3),D2

	MOVE.L	RetOut(A3),-(A7)

	JMP	([VDPPUNT.W,PC,D1.W*4])
; ---------------------------------------<=

; <=---------------------------------------------------------=>

; <=---------------------------------------------------------=>
	CNOP	0,8
TabScr:
	DC.L	PRINT1,ModoTxt	; 1 1G	00 000
	DC.L	PRINT2,ModoTxt	; 2 2G	00 001
	DC.L	PRINT4S,ModoTxt4	; 4 3G	00 010 (PRINT4S: split)
	DC.L	PRINT5,ModoGfx5	; 5 4G	00 011
	DC.L	PRINT6,ModoGfx6	; 6 5G	00 100
	DC.L	PRINT7,ModoGfx7	; 7 6G	00 101
	DC.L	PrtRET,NoCamScr	;	00 110
	DC.L	PRINT8,ModoGfx8	; 8 7G	00 111
	DC.L	PRINT3,ModoTxt	; 3 M	01 000  (Modo MULTI)
	REPT	7
	DC.L	PrtRET,NoCamScr
	ENDR
	DC.L	PRINT0,ModoTxt	; 0 1T	10 000  (Modo 40 columnas)
	DC.L	PRINT0,ModoTxtX
	DC.L	PRINT9,ModoTxtX	; 1 2T	10 010  (Modo 80 columnas)
	REPT	5+8
	DC.L	PRINT0,ModoTxtX
	ENDR
; <=---------------------------------------------------------=>

; <=---------------------------------------------------------=>
VDP0:
	IFD	TRACE
	TRVLOG	$00,D2
	ENDC
	MOVEQ	#$0,D1
	BTST	#4,D2
	BEQ.S	HORINTACT
	MOVE.W	#$8010,D1
HORINTACT:
;;	MOVE.W	D1,([Dir_Scan])
	MOVE.W	D1,Int_H4+2
; ---
	MOVE.B	D2,DVDP0(A3)
	MOVE.W	D2,D1
	SWAP	D2
	AND.B	#$0E,D1
	LSR.B	#1,D1
	MOVE.B	DVDP1(A3),D2
	AND.B	#$18,D2
	OR.B	D2,D1
	MOVE.L	(TABScr.W,PC,D1.W*8),RVDP(A3)
	CMP.B	ScrModo(A3),D1
	BNE.S	SiCamScr0
	RTS
SiCamScr0:
	MODESW
	JMP	([TABScr+4.W,PC,D1.W*8])
NoCamScr:RTS
; <=---------------------------------------------------------=>
VDP1:
	IFD	TRACE
	TRVLOG	$01,D2
	ENDC
	MOVE.B	DVDP1(A3),D1		; BL (display enable) changed during the
	EOR.B	D2,D1			; display: those lines show the border
	BTST	#6,D1			; (Lilly's Saga turns it off for ~2 lines
	BEQ.S	VDP1NoBl		; at its HUD split while it switches the
	MOVE.W	CurLine(A3),D1		; tables; the copper used to show the
	BEQ.S	VDP1NoBl		; half-switched line). From the line after
	CMP.W	#210,D1			; next: Lilly keeps its last ground line
	BCC.S	VDP1NoBl		; and the two above its HUD go blank, as
	ADDQ.W	#2,D1			; openMSX shows them.
	OR.B	#$08,(TabRasCMDS.L,D1.W)
	MOVE.B	#1,(BlankTab.L,D1.W)	; 1: blank,
	BTST	#6,D2
	BEQ.S	VDP1BlOff
	MOVE.B	#2,(BlankTab.L,D1.W)	; 2: display again.
VDP1BlOff:
	MOVE.B	#3,PalSplitSeen		; Colours via the copper from line 0.
VDP1NoBl:
	SF	S5Valid			; 5th sprite flag: recompute.
	MOVE.W	#$0100,D1
	BTST	#6,D2
	BEQ.S	VDP1C0
	MOVE.W	#$8100,D1
VDP1C0:
	MOVE.W	D1,MCOPP96+2
	MOVE.B	D2,DVDP1(A3)
	MOVE.W	D2,D1
	SWAP	D2
	AND.B	#$18,D1
	MOVE.B	DVDP0(A3),D2
	AND.B	#$0E,D2
	LSR.B	#1,D2
	OR.B	D2,D1
	MOVE.L	(TABScr.W,PC,D1.W*8),RVDP(A3)
	CMP.B	ScrModo(A3),D1
	BNE.S	SiCamScr1
	RTS
SiCamScr1:
	MODESW
	JMP	([TABScr+4.W,PC,D1.W*8])
; <=---------------------------------------------------------=>
;VDP8:
	BTST	#1,D2
	BNE.S	VDP8Con0
	MOVE.B	#$3,COSPR2(A3)

	MOVE.L	A0,-(SP)
	LEA	MSX2Pal+2(PC),A0
	LEA	$DFF1A0+2,A4
	MOVE.W	(A0)+,(A4)+
	REPT	7
	MOVE.L	(A0)+,(A4)+
	ENDR
	MOVE.L	(SP)+,A0
	MOVE.W	#$003F,$DFF104

	BRA.S	VDP8Con1
	CNOP	0,8
VDP8Con0:
	CLR.W	$DFF104
	LEA	$DFF1A0+2,A4
	CLR.W	(A4)+
	REPT	7
	CLR.L	(A4)+
	ENDR

VDP8Con1:
	MOVE.B	D2,DVDP8(A3)
	SWAP	D2
	RTS
; ---
VDP8:
	IFD	TRACE
	TRVLOG	$08,D2
	ENDC
	RSPLITCHK	DVDP8

	MOVE.B	D2,DVDP8(A3)
	BTST	#1,D2
	BEQ	VDP8CON
	CMP.W	#192,CurLine(A3)	; Sprites off during the display: left to
	BCS	VDP8CON2		; the render (Act_Adjust, MIDSAMPLE's R#8).
					; Hiding them here hid them for the whole
					; Amiga frame (Lilly's Saga HUD, line 173).

	MOVE.W	#INISPR2*$100+$D8,D1
	LEA	SPRIT0+1,A4
	MOVE.B	D1,(A4)
	MOVE.B	D1,(NEXSPR*1)(A4)
	MOVE.B	D1,(NEXSPR*2)(A4)
	MOVE.B	D1,(NEXSPR*3)(A4)
	MOVE.B	D1,(NEXSPR*4)(A4)
	MOVE.B	D1,(NEXSPR*5)(A4)
	MOVE.B	D1,(NEXSPR*6)(A4)
	MOVE.B	D1,(NEXSPR*7)(A4)
	LEA	SPRIT0b+1,A4
	MOVE.B	D1,(A4)
	MOVE.B	D1,(NEXSPR*1)(A4)
	MOVE.B	D1,(NEXSPR*2)(A4)
	MOVE.B	D1,(NEXSPR*3)(A4)
	MOVE.B	D1,(NEXSPR*4)(A4)
	MOVE.B	D1,(NEXSPR*5)(A4)
	MOVE.B	D1,(NEXSPR*6)(A4)
	MOVE.B	D1,(NEXSPR*7)(A4)
	LEA	$DFF140,A4
	MOVE.W	D1,(A4)
	MOVE.W	D1,$08(A4)
	MOVE.W	D1,$10(A4)
	MOVE.W	D1,$18(A4)
	MOVE.W	D1,$20(A4)
	MOVE.W	D1,$28(A4)
	MOVE.W	D1,$30(A4)
	MOVE.W	D1,$38(A4)
	BRA	VDP8CON2
VDP8CON:
	MOVE.B	#$3,COSPR2(A3)

	MOVE.B	MidAdj,D2		; Playfield R#18 (Lilly's Saga sets R#18
					; just after re-enabling sprites).
	AND.W	#$000F,D2
	MOVE.L	(AdjustSpr.w,PC,D2.W*4),D1
SPR2On:
	BTST	#0,$DFF005
	BNE.S	VDP8Slow

	CMP.B	#IniPant+1,$DFF006
	BHI	VDP8Fast
VDP8Slow:
	MOVEM.L	A0/A1,BUFER(A3)
	LEA	SPRIT0+1,A0
	LEA	SPRIT0b+1,A1
	LEA	$DFF140,A4

	MOVE.L	D1,(A4)
	MOVE.L	D1,$08(A4)
	MOVE.B	D1,8(A0)
	MOVE.B	D1,(NEXSPR*1)+8(A0)
	MOVE.B	D1,8(A1)
	MOVE.B	D1,(NEXSPR*1)+8(A1)
	SWAP	D1
	MOVE.B	D1,(A0)
	MOVE.B	D1,(NEXSPR*1)(A0)
	MOVE.B	D1,(A1)
	MOVE.B	D1,(NEXSPR*1)(A1)
	ADD.W	#$20,D1
	SWAP	D1
	MOVE.L	D1,$10(A4)
	MOVE.L	D1,$18(A4)
	MOVE.B	D1,(NEXSPR*2)+8(A0)
	MOVE.B	D1,(NEXSPR*3)+8(A0)
	MOVE.B	D1,(NEXSPR*2)+8(A1)
	MOVE.B	D1,(NEXSPR*3)+8(A1)
	SWAP	D1
	MOVE.B	D1,(NEXSPR*2)(A0)
	MOVE.B	D1,(NEXSPR*3)(A0)
	MOVE.B	D1,(NEXSPR*2)(A1)
	MOVE.B	D1,(NEXSPR*3)(A1)
	ADD.W	#$20,D1
	SWAP	D1
	MOVE.L	D1,$20(A4)
	MOVE.L	D1,$28(A4)
	MOVE.B	D1,(NEXSPR*4)+8(A0)
	MOVE.B	D1,(NEXSPR*5)+8(A0)
	MOVE.B	D1,(NEXSPR*4)+8(A1)
	MOVE.B	D1,(NEXSPR*5)+8(A1)
	SWAP	D1
	MOVE.B	D1,(NEXSPR*4)(A0)
	MOVE.B	D1,(NEXSPR*5)(A0)
	MOVE.B	D1,(NEXSPR*4)(A1)
	MOVE.B	D1,(NEXSPR*5)(A1)
	ADD.W	#$20,D1
	SWAP	D1
	MOVE.L	D1,$30(A4)
	MOVE.L	D1,$38(A4)
	MOVE.B	D1,(NEXSPR*6)+8(A0)
	MOVE.B	D1,(NEXSPR*7)+8(A0)
	MOVE.B	D1,(NEXSPR*6)+8(A1)
	MOVE.B	D1,(NEXSPR*7)+8(A1)
	SWAP	D1
	MOVE.B	D1,(NEXSPR*6)(A0)
	MOVE.B	D1,(NEXSPR*7)(A0)
	MOVE.B	D1,(NEXSPR*6)(A1)
	MOVE.B	D1,(NEXSPR*7)(A1)

	MOVEM.L	BUFER(A3),A0/A1
VDP8CON2:
	MOVEQ	#0,D1
	SWAP	D2
	RTS

VDP8Fast:
	LEA	$DFF140,A4
	MOVE.L	D1,(A4)
	MOVE.L	D1,$08(A4)
	ADD.L	#$200000,D1
	MOVE.L	D1,$10(A4)
	MOVE.L	D1,$18(A4)
	ADD.L	#$200000,D1
	MOVE.L	D1,$20(A4)
	MOVE.L	D1,$28(A4)
	ADD.L	#$200000,D1
	MOVE.L	D1,$30(A4)
	MOVE.L	D1,$38(A4)
	MOVEQ	#0,D1
	SWAP	D2
	RTS

; <=---------------------------------------------------------=>
VDP9:
	MOVE.B	D2,DVDP9(A3)
; ---
	BTST	#3,D2
	BNE.S	VD9Con2
	SF	NPla5+7				; Modo interlazado.
	SF	NPla6+7
	SF	NPla7+7
	MOVE.B	#$10,NPla8+7
	BRA.S	VD9Con3
	CNOP	0,8
VD9Con2:
	MOVE.B	#4,NPla5+7
	MOVE.B	#4,NPla6+7
	MOVE.B	#4,NPla7+7
	MOVE.B	#$14,NPla8+7
VD9Con3:
; ---
;	MOVE.B	#((INIPANT+212)&$FF),D1		; Modo 192 o 212
;	BTST	#7,D2
;	BNE.S	VD9CON
;	MOVE.B	#((INIPANT+192)&$FF),D1
;VD9CON:	MOVE.B	D1,VERPAN+6
;	MOVE.B	D1,Ver9+6
; ---
	TST.B	SCRFREC(A3)
	BEQ.S	VD9CON1
	MOVEQ	#0,D1
	BTST	#1,D2
	BEQ.S	VD9CON0
	MOVE.W	#$20,D1
VD9CON0:MOVE.W	D1,$DFF1DC
VD9CON1:
; ---
	SWAP	D2
	RTS
; <=---------------------------------------------------------=>
VDP2:
	IFD	TRACE
	IFD	TRAPR2			; Debug: freeze on R#2 = TRAPR2.
	CMP.B	#TRAPR2,D2
	BNE.S	VDP2NoTrap
	JMP	TraceFreeze
VDP2NoTrap:
	ENDC
	TRVLOG	$02,D2
	ENDC
	TSPLITCHK	DVDP2
	MOVE.B	D2,DVDP2(A3)
	MOVE.W	D2,D1
	AND.B	#$7F,D1
	MULU	#$400,D1
	MOVE.L	D1,PVDP2(A3)
	MOVEQ	#$17,D1
	MOVE.B	VDPLinY(A3),D2
	JMP	([VDPPUNT.W,PC,D1.W*4])
	SWAP	D2
	RTS
; <=---------------------------------------------------------=>
VDPA:
	TSPLITCHK	DVDP3
	MOVE.B	D2,DVDP3(A3)
	MOVE.B	DVDP3+1(A3),D2
VDP3:
	TSPLITCHK	DVDP3+1
	MOVE.B	D2,DVDP3+1(A3)
	MOVE.W	DVDP3(A3),D1
	AND.W	#$07FF,D1
	MULU	#$40,D1
	CMP.L	PVDP3(A3),D1
	BEQ.S	NOCAM3
	ST	ACTODO(A3)
NOCAM3:	MOVE.L	D1,PVDP3(A3)
	MOVEQ	#0,D1
	MOVE.W	DVDP3(A3),D1
	AND.W	#$0780,D1
	MULU	#$40,D1
	CMP.L	PVDP3B(A3),D1
	BEQ.S	NOCAM3B
	MOVE.L	D1,PVDP3B(A3)		; (Full redraw: RendTabCheck.)
NOCAM3B:MOVEQ	#0,D1
	SWAP	D2
	RTS
; <=---------------------------------------------------------=>
VDP4:
	TSPLITCHK	DVDP4+1
	MOVE.W	D2,DVDP4(A3)
	MOVE.W	D2,D1
	AND.B	#$3F,D1
	MULU	#$800,D1
	CMP.L	PVDP4(A3),D1
	BEQ.S	NOCAM4
	ST	ACTODO(A3)
NOCAM4:	MOVE.L	D1,PVDP4(A3)
	MOVEQ	#0,D1
	MOVE.W	D2,D1
	AND.B	#$3C,D1
	MULU	#$800,D1
	CMP.L	PVDP4B(A3),D1
	BEQ.S	NOCAM4B
	MOVE.L	D1,PVDP4B(A3)		; (Full redraw: RendTabCheck.)
NOCAM4B:MOVEQ	#0,D1
	SWAP	D2
	RTS
; <=---------------------------------------------------------=>
VDPB:
	SF	S5Valid			; 5th sprite flag: recompute.
	MOVE.B	D2,DVDP5(A3)
	MOVE.B	DVDP5+1(A3),D2
VDP5:
	SF	S5Valid			; 5th sprite flag: recompute.
	CMP.W	#192,CurLine(A3)	; Table moved in VBlank: no more 5S this
	BCS.S	VDP5Disp		; frame (the beam checks no lines there).
	MOVE.W	#192,S5Next		; Uridium resets its HUD table at VBlank
VDP5Disp:				; and polls S#0 at once for the line 63 split.
	CMP.B	DVDP5+1(A3),D2
	BEQ.S	VDP5Same
	BANDPEND
VDP5Same:
	MOVE.B	D2,DVDP5+1(A3)
	MOVE.W	DVDP5(A3),D1
	AND.W	#$03FF,D1
	MULU	#$80,D1
	MOVE.L	D1,PVDP5(A3)
	MOVE.W	CurLine(A3),D1		; Sprite tables changed mid-frame
	CMP.W	#SNAPTOP,D1		; between the two snapshots: split
	BLE.S	NoSplit5			; there (IMPSPR draws two passes).
	CMP.W	#SNAPLIN,D1
	BGT.S	NoSplit5
	TST.W	SprSplit
	BNE.S	NoSplit5
	MOVE.W	D1,SprSplit
NoSplit5:
	IFD	TRACE
	TRVLOG	5,D2
	ENDC
	MOVEQ	#0,D1
	SWAP	D2
	RTS
; <=---------------------------------------------------------=>
VDP6:
	MOVE.W	D2,D1
	AND.B	#$3F,D1
	MULU	#$800,D1
	CMP.L	PVDP6(A3),D1
	BEQ.S	NOCAM6
	MOVE.L	D1,PVDP6(A3)		; (Full conversion: TRANSSPR decides.)
	BANDPEND
	MOVE.W	CurLine(A3),D1		; Sprite tables changed mid-frame
	CMP.W	#SNAPTOP,D1		; between the two snapshots: split
	BLE.S	NoSplit6			; there (IMPSPR draws two passes).
	CMP.W	#SNAPLIN,D1
	BGT.S	NoSplit6
	TST.W	SprSplit
	BNE.S	NoSplit6
	MOVE.W	D1,SprSplit
NoSplit6:
	IFD	TRACE
	TRVLOG	6,D2
	ENDC
NOCAM6:
	MOVEQ	#0,D1
	SWAP	D2
	RTS
; <=---------------------------------------------------------=>
VDP7ecs:
	MOVE.B	D2,DVDP7(A3)
	MOVE.W	D2,D1
	AND.W	#$0F,D1
	LSR.B	#4,D2

;;	MOVE.W	(MSXPAL.W,PC,D1.W*2),$DFF180	; Borde.
;;	MOVE.W	(MSXPAL.W,PC,D2.W*2),$DFF182	; Lapiz. (solo scr 0)

	LEA	(MSX2Pal.W,PC,D1.W*2),A4
	MOVE.L	A4,COL00
	LEA	(MSX2Pal.W,PC,D2.W*2),A4
	MOVE.L	A4,COL01

	SWAP	D2
	RTS
; -----
VDP7:
	MOVE.B	D2,DVDP7(A3)
	MOVE.W	D2,D1
	AND.W	#$0F,D1
	LSR.B	#4,D2

;;	MOVE.W	(MSXPAL.W,PC,D1.W*2),$DFF180	; Borde.
;;	MOVE.W	(MSXPAL.W,PC,D2.W*2),$DFF182	; Lapiz. (solo scr 0)

	LEA	(MSX2Pal.W,PC,D1.W*2),A4
	MOVE.L	A4,COL00
	LEA	(MSX2Pal.W,PC,D2.W*2),A4
	MOVE.L	A4,COL01


	SWAP	D0
	MOVE.W	#16-1,D0
	LEA	MSX2Pal+(16*2)(PC),A4
	MOVE.B	D1,MCAGA+10
VDP7BUC:
	MOVE.B	D0,D2
	EOR.B	D1,D2
	MOVE.W	-(A4),(COLORMSX2+2.L,D2.W*4)
;;	MOVE.W	(A4),($DFF180.L,D2.W*2)
	DBF	D0,VDP7BUC
;;	LSL.W	#8,D1
;;	MOVE.B	#$11,D1
;;	MOVE.W	D1,$DFF10C
	SWAP	D0

ARET:	SWAP	D2
	RTS
COL00:	DC.L	MSX2Pal
COL01:	DC.L	MSX2Pal
	CNOP	0,8
; <=---------------------------------------------------------=>
VDPC:
	MOVE.B	D2,DVDPC(A3)
	MOVE.W	D2,D1
	AND.B	#$0F,D1
	LSR.B	#4,D2
	LEA	(MSX2Pal.W,PC,D2.W*2),A4
	MOVE.L	A4,COL02
	LEA	(MSX2Pal.W,PC,D1.W*2),A4
	MOVE.L	A4,COL03
	SWAP	D2
	RTS
COL02:	DC.L	MSX2Pal
COL03:	DC.L	MSX2Pal
	CNOP	0,8
; <=---------------------------------------------------------=>
VDPD:
	MOVE.W	D2,FLASH(A3)
	SWAP	D2
	RTS
; <=---------------------------------------------------------=>
VDPE:					; Byte alto de VRAM
	MOVE.B	D2,D1
	AND.W	#$0007,D1
	SWAP	D1
	LSR.L	#2,D1
	ADD.L	#DIRVRAM,D1
	MOVE.L	D1,VRAM(A3)
	MOVE.L	A2,D1
	SUB.L	#DIRVRAM,D1
	AND.W	#$3FFF,D1
	LEA	([VRAM.W,A3],D1.W),A2
	MOVEQ	#0,D1
	SWAP	D2
	RTS
; <=---------------------------------------------------------=>
MVDPX:	MACRO
	MOVE.B	D2,\1(A3)
	SWAP	D2
	RTS
	ENDM
; <=---------------------------------------------------------=>
VDPF:	AND.B	#$0F,D2
	MVDPX	VDPREGL			; Registro de lectura.
VDP10:	MVDPX	VDPREGP			; Registro de paleta.
VDP11:	MVDPX	VDPREGE			; Registro de escritura.
; <=---------------------------------------------------------=>


;	-----------------------=>  VDP ($13)  Line Interrupt Line.
VDP13:
	IFD	TRACE
	TRVLOG	$13,D2
	ENDC
	MOVE.B	D2,VDPIntY(A3)		; Interrupci�n de scaning.

	MOVEQ	#0,D1
	MOVE.B	D2,D1
	SUB.B	VDPLinY(A3),D1		; HorLine = (Int Y)-(Lin Y)

	MOVE.W	D1,HorLine(A3)

	SWAP	D2
	RTS
;	-----------------------<=

Dir_Scan:DC.L	TabCop5+(TabCop5Add)+$E



; <=---------------------------------------------------------=>
VDP12mT:
	RSPLITCHK	VDPAdjust
	MOVE.B	D2,VDPAdjust(A3)
	SWAP	D2
	RTS
VDP12:
	RSPLITCHK	VDPAdjust
	MOVE.B	D2,VDPAdjust(A3)

	MOVE.W	CurLine(A3),D1
	ADDQ.W	#1,D1
	OR.B	#$02,(TabRasCMDS,D1.W)		; Act. Adjust X
	MOVE.B	D2,(TabRasDATA+3,D1.W*8)	; VDP ($12)

	SWAP	D2
	RTS


	MOVE.B	D2,VDPAdjust(A3)
	AND.W	#$000F,D2

;;	MOVE.W	(AdjustBuf.w,PC,D2.W*4),COPPER2+10
;;	MOVE.W	(AdjustBuf.w,PC,D2.W*4),COPPER2b+10
;;	MOVE.B	(AdjustBuf+2.w,PC,D2.W*4),Ver2+3
;;	MOVE.B	(AdjustBuf+2.w,PC,D2.W*4),Ver2+7
;;	MOVE.B	(AdjustBuf+2.w,PC,D2.W*4),Ver2b+3
;;	MOVE.B	(AdjustBuf+2.w,PC,D2.W*4),Ver2b+7

;	MOVE.W	(AdjustBuf.w,PC,D2.W*4),AdjustX+10
;	MOVE.W	(AdjustBuf.w,PC,D2.W*4),$DFF102
;	MOVE.B	(AdjustBuf+2.w,PC,D2.W*4),VERPAN+3
;	MOVE.W	VERPAN+2,$DFF08E
;	MOVE.B	(AdjustBuf+2.w,PC,D2.W*4),VERPAN+7
;	MOVE.W	VERPAN+6,$DFF090

;;	MOVE.W	(AdjustBuf2.w,PC,D2.W*4),COPPER0+10
;;	MOVE.W	(AdjustBuf2.w,PC,D2.W*4),COPPER9+10
;;	MOVE.B	(AdjustBuf2+2.w,PC,D2.W*4),Ver0+3
;;	MOVE.B	(AdjustBuf2+3.w,PC,D2.W*4),Ver0+7
;;	MOVE.B	(AdjustBuf2+2.w,PC,D2.W*4),Ver9+3
;;	MOVE.B	(AdjustBuf2+3.w,PC,D2.W*4),Ver9+7

	BTST	#1,DVDP8(A3)
	BNE	VDP8CON2

	MOVE.L	(AdjustSpr.w,PC,D2.W*4),D1
	BRA	SPR2On


AdjustSpr:
	DC.W	INISPR2*$100+$50,FINSPR2*$100+$82	;  0
	DC.W	INISPR2*$100+$4F,FINSPR2*$100+$83	; -1
	DC.W	INISPR2*$100+$4F,FINSPR2*$100+$82	; -2
	DC.W	INISPR2*$100+$4E,FINSPR2*$100+$83	; -3
	DC.W	INISPR2*$100+$4E,FINSPR2*$100+$82	; -4
	DC.W	INISPR2*$100+$4D,FINSPR2*$100+$83	; -5
	DC.W	INISPR2*$100+$4D,FINSPR2*$100+$82	; -6
	DC.W	INISPR2*$100+$4C,FINSPR2*$100+$83	; -7
	DC.W	INISPR2*$100+$54,FINSPR2*$100+$82	;  8
	DC.W	INISPR2*$100+$53,FINSPR2*$100+$83	;  7
	DC.W	INISPR2*$100+$53,FINSPR2*$100+$82	;  6
	DC.W	INISPR2*$100+$52,FINSPR2*$100+$83	;  5
	DC.W	INISPR2*$100+$52,FINSPR2*$100+$82	;  4
	DC.W	INISPR2*$100+$51,FINSPR2*$100+$83	;  3
	DC.W	INISPR2*$100+$51,FINSPR2*$100+$82	;  2
	DC.W	INISPR2*$100+$50,FINSPR2*$100+$83	;  1

; <=---------------------------------------------------------=>
VDP17m5:
	NOINT
	IInsBuc
	RSPLITCHK	VDPLinY
	MOVE.B	D2,VDPLinY(A3)			; Registro de Scroll.
	MOVEM.L	D0/D1/D3/A0,BUFER(A3)

; -=-=-
V17Buc0:CMP.B	#$67,$DFF007
	BCC.S	V17Buc0
; -=-=-
	MOVE.B	ScanningY(A3),D1
V17Buc2:CMP.B	$DFF006,D1
	BEQ.S	V17Buc2
; -=-=-
V17Buc1:
	CMP.B	#IniPant-1,$DFF006
	BEQ.S	V17Buc1
;;;	BCS.S	V17Con1
; -=-=-
	MOVE.B	DVDP2(A3),D3
	AND.W	#$0060,D3
	LSL.W	#3,D3
	MOVE.B	D2,D3

	MOVE.W	Ant_Rest(PC),D0
	MOVE.W	D3,Ant_Rest

	MOVE.B	$DFF006,D1
	MOVE.B	D1,ScanningY(A3)
	SUB.B	#INIPANT-1,D1

	ADD.B	D1,D3
	ADD.B	D1,D0
	BNE.S	V17Con0
	ADD.W	#$0100,D0
V17Con0:
	SUB.W	D0,D3

	LSL.W	#5,D3

ModC52:	SUBQ.W	#8,D3

	MOVE.W	D3,D0
	SWAP	D3
	MOVE.W	D0,D3
	MOVE.L	D3,$DFF108
; -=-=-
V17Con1:
; -=-=-
ModC50:	MOVEQ	#-8,D0			; Calcula Nuevo Fin de p�gina en copper.
	MOVE.L	Cop_Rest(PC),A0
	MOVE.W	D0,(A0)
	MOVE.W	D0,4(A0)
	MOVE.W	#255,D0
	SUB.B	D2,D0
	MULU	#TabCop5Add,D0
	LEA	(TabCop5+$4+$2,D0.W),A0
ModC51:	MOVE.W	#(-32*256)-8,D0
	MOVE.W	D0,(A0)
	MOVE.W	D0,4(A0)
	MOVE.L	A0,Cop_Rest
; -=-=-
	MOVE.B	DVDP2(A3),D0		; Pone Bit-Panos en copper.
	AND.W	#$0060,D0
	LSL.W	#3,D0
	MOVE.B	D2,D0

	MULU	#32,D0
	ADD.L	#SCR0,D0
	LEA	PLANO5+2,A0
	MOVE.L	#(32*1024),D1

	MOVE.W	D0,4(A0)
	SWAP	D0
	MOVE.W	D0,(A0)
	SWAP	D0
	ADD.L	D1,D0
	MOVE.W	D0,12(A0)
	SWAP	D0
	MOVE.W	D0,8(A0)
	SWAP	D0
	ADD.L	D1,D0
	MOVE.W	D0,20(A0)
	SWAP	D0
	MOVE.W	D0,16(A0)
	SWAP	D0
	ADD.L	D1,D0
	MOVE.W	D0,28(A0)
	SWAP	D0
	MOVE.W	D0,24(A0)
; -=-=-
	MOVEM.L	BUFER(A3),D0/D1/D3/A0
	FInsBuc

	MOVEQ	#$13,D1
	MOVE.B	VDPIntY(A3),D2
	JMP	([VDPPunt.W,PC,D1.W*4])
	SWAP	D2
	SIINT
	RTS


; -=-=-
	CNOP	0,8
Cop_Rest:DC.L	TabCop5+$4+$2
Ant_Rest:DC.W	0
; -=-=-

; -=-=-=-=-=-=-=-=-=-=-=-=-

VDP17m7:
	NOINT
	IInsBuc
	RSPLITCHK	VDPLinY
	MOVE.B	D2,VDPLinY(A3)			; Registro de Scroll.
	MOVEM.L	D0/D1/D3/A0,BUFER(A3)

; -=-=-
V17Buc70:CMP.B	#$67,$DFF007
	BCC.S	V17Buc70
; -=-=-
	MOVE.B	ScanningY(A3),D1
V17Buc72:CMP.B	$DFF006,D1
	BEQ.S	V17Buc72
; -=-=-
V17Buc71:
	CMP.B	#IniPant-1,$DFF006
	BEQ.S	V17Buc71
;;	BCS.S	V17Con71
; -=-=-
	MOVE.B	DVDP2(A3),D3
	AND.W	#$0020,D3
	LSL.W	#3,D3
	MOVE.B	D2,D3

	MOVE.W	Ant_Rest(PC),D0
	MOVE.W	D3,Ant_Rest

	MOVE.B	$DFF006,D1
	MOVE.B	D1,ScanningY(A3)
	SUB.B	#INIPANT-1,D1

	ADD.B	D1,D3
	ADD.B	D1,D0
	BNE.S	V17Con70
	ADD.W	#$0100,D0
V17Con70:
	SUB.W	D0,D3

	LSL.W	#6,D3

ModC72:	SUBQ.W	#8,D3

	MOVE.W	D3,D0
	SWAP	D3
	MOVE.W	D0,D3
	MOVE.L	D3,$DFF108
; -=-=-
V17Con71:
; -=-=-
ModC70:	MOVEQ	#-8,D0			; Calcula Nuevo Fin de p�gina en copper.
	MOVE.L	Cop_Rest(PC),A0
	MOVE.W	D0,(A0)
	MOVE.W	D0,4(A0)
	MOVE.W	#255,D0
	SUB.B	D2,D0
	MULU	#TabCop5Add,D0
	LEA	(TabCop5+$4+$2,D0.W),A0
ModC71:	MOVE.W	#(-64*256)-8,D0
	MOVE.W	D0,(A0)
	MOVE.W	D0,4(A0)
	MOVE.L	A0,Cop_Rest
; -=-=-
	MOVE.B	DVDP2(A3),D0		; Pone Bit-Panos en copper.
	AND.W	#$0020,D0
	LSL.W	#3,D0
	MOVE.B	D2,D0

	MULU	#64,D0
	ADD.L	#SCR0,D0
	LEA	PLANO7+2,A0
	MOVE.L	#(64*512),D1

	MOVE.W	D0,4(A0)
	SWAP	D0
	MOVE.W	D0,(A0)
	SWAP	D0
	ADD.L	D1,D0
	MOVE.W	D0,12(A0)
	SWAP	D0
	MOVE.W	D0,8(A0)
	SWAP	D0
	ADD.L	D1,D0
	MOVE.W	D0,20(A0)
	SWAP	D0
	MOVE.W	D0,16(A0)
	SWAP	D0
	ADD.L	D1,D0
	MOVE.W	D0,28(A0)
	SWAP	D0
	MOVE.W	D0,24(A0)
; -=-=-
	MOVEM.L	BUFER(A3),D0/D1/D3/A0
	FInsBuc

	MOVEQ	#$13,D1
	MOVE.B	VDPIntY(A3),D2
	JMP	([VDPPunt.W,PC,D1.W*4])
	SWAP	D2
	SIINT
	RTS
; -=-=-

; -=-=-=-=-=-=-=-=-=-=-=-=-

VDP17m8:
	NOINT
	IInsBuc
	RSPLITCHK	VDPLinY
	MOVE.B	D2,VDPLinY(A3)			; Registro de Scroll.
	MOVEM.L	D0/D1/D3/A0,BUFER(A3)

; -=-=-
V17Buc80:CMP.B	#$67,$DFF007
	BCC.S	V17Buc80
; -=-=-
	MOVE.B	ScanningY(A3),D1
V17Buc82:CMP.B	$DFF006,D1
	BEQ.S	V17Buc82
; -=-=-
V17Buc81:
	CMP.B	#IniPant-1,$DFF006
	BEQ.S	V17Buc81
;;;	BCS.S	V17Con81
; -=-=-
	MOVE.B	DVDP2(A3),D3
	AND.W	#$0020,D3
	LSL.W	#3,D3
	MOVE.B	D2,D3

	MOVE.W	Ant_Rest(PC),D0
	MOVE.W	D3,Ant_Rest

	MOVE.B	$DFF006,D1
	MOVE.B	D1,ScanningY(A3)
	SUB.B	#INIPANT-1,D1

	ADD.B	D1,D3
	ADD.B	D1,D0
	BNE.S	V17Con80
	ADD.W	#$0100,D0
V17Con80:
	SUB.W	D0,D3

	LSL.W	#5,D3

ModC82:	SUBQ.W	#8,D3

	MOVE.W	D3,D0
	SWAP	D3
	MOVE.W	D0,D3
	MOVE.L	D3,$DFF108
; -=-=-
V17Con81:
; -=-=-
ModC80:	MOVEQ	#-8,D0			; Calcula Nuevo Fin de p�gina en copper.
	MOVE.L	Cop_Rest(PC),A0
	MOVE.W	D0,(A0)
	MOVE.W	D0,4(A0)
	MOVE.W	#255,D0
	SUB.B	D2,D0
	MULU	#TabCop5Add,D0
	LEA	(TabCop5+$4+$2,D0.W),A0
ModC81:	MOVE.W	#(-32*256)-8,D0
	MOVE.W	D0,(A0)
	MOVE.W	D0,4(A0)
	MOVE.L	A0,Cop_Rest
; -=-=-
	MOVE.B	DVDP2(A3),D0		; Pone Bit-Panos en copper.
	AND.W	#$0020,D0
	LSL.W	#3,D0
	MOVE.B	D2,D0

	MULU	#32,D0
	ADD.L	#SCR0,D0
	LEA	PLANO8+2,A0
	MOVE.L	#(32*512),D1

	MOVE.W	D0,4(A0)
	SWAP	D0
	MOVE.W	D0,(A0)
	SWAP	D0
	ADD.L	D1,D0
	MOVE.W	D0,12(A0)
	SWAP	D0
	MOVE.W	D0,8(A0)
	SWAP	D0
	ADD.L	D1,D0
	MOVE.W	D0,20(A0)
	SWAP	D0
	MOVE.W	D0,16(A0)
	SWAP	D0
	ADD.L	D1,D0
	MOVE.W	D0,28(A0)
	SWAP	D0
	MOVE.W	D0,24(A0)
	SWAP	D0
	ADD.L	D1,D0
	MOVE.W	D0,36(A0)
	SWAP	D0
	MOVE.W	D0,32(A0)
	SWAP	D0
	ADD.L	D1,D0
	MOVE.W	D0,44(A0)
	SWAP	D0
	MOVE.W	D0,40(A0)
	SWAP	D0
	ADD.L	D1,D0
	MOVE.W	D0,52(A0)
	SWAP	D0
	MOVE.W	D0,48(A0)
	SWAP	D0
	ADD.L	D1,D0
	MOVE.W	D0,60(A0)
	SWAP	D0
	MOVE.W	D0,56(A0)
; -=-=-
	MOVEM.L	BUFER(A3),D0/D1/D3/A0
	FInsBuc

	MOVEQ	#$13,D1
	MOVE.B	VDPIntY(A3),D2
	JMP	([VDPPunt.W,PC,D1.W*4])
	SWAP	D2
	SIINT
	RTS
; -=-=-

; -=-=-=-=-=-=-=-=-=-=-=-=-

;	-----------------------=>  VDP ($17)  Hardware Vertical Scroll
VDP17:
	RSPLITCHK	VDPLinY
	MOVE.B	D2,VDPLinY(A3)			; Registro de Scroll.

	MOVEQ	#0,D1
	MOVE.B	VDPIntY(A3),D1
	SUB.B	D2,D1			; HorLine = (Int Y)-(Lin Y)
	MOVE.W	D1,HorLine(A3)


	MOVE.W	DesLinY(A3),D1
	CMP.W	CurLine(A3),D1
	BGE.S	VDP17Con0
	OR.B	#$01,(TabRasCMDS.L,D1.W)	; Activa Desbor. anterior
VDP17Con0:


	MOVE.W	CurLine(A3),D1
	ADDQ.W	#1,D1
	OR.B	#$01,(TabRasCMDS,D1.W)		; Act. Scroll Y
	MOVE.B	D2,(TabRasDATA+4,D1.W*8)	; VDP ($17)
	MOVE.B	DVDP2(A3),(TabRasDATA+1,D1.W*8)	; VDP (2)


	MOVEQ	#0,D1
	SUB.B	D2,D1
	CMP.W	CurLine(A3),D1
	BLE.S	VDP17Con1
	MOVE.B	D2,(TabRasDATA+4,D1.W*8)	; VDP ($17)
	MOVE.B	DVDP2(A3),(TabRasDATA+1,D1.W*8)	; VDP (2)
	MOVE.W	D1,DesLinY(A3)
	SWAP	D2
	RTS
VDP17Con1:
	ST	DesLinY+1(A3)
	SWAP	D2
	RTS

;	-----------------------<=

; -=-=-=-=-=-=-=-=-=-=-=-=-

; <=---------------------------------------------------------=>

	CNOP	0,8
ModoChg6a0:
ActPlanos6:
ModoChg8a0:
ActPlanos8:
	RTS

; <=---------------------------------------------------------=>

SIZEX=512/8	; Bytes horizontales.	(Siempre pares)
SIZEY=512	; Lineas verticales

	CNOP	0,8
ModoChg5Dat:
	DC.L	((SIZEX*SIZEY)/2)-1
	DC.L	SCR0+(SIZEX*SIZEY*0)
	DC.L	SCR0+(SIZEX*SIZEY*1)
	DC.L	SCR0+(SIZEX*SIZEY*2)
	DC.L	DIRVRAM
	DC.L	SCR0+(SIZEX*SIZEY*3)

; <=---------------------------------------------------------=>

	CNOP	0,8
ModoChg5a0:
ModoChg7a0:

	TST.B	DirPrefs+$6B		; Refresh 100% Graphics.
	BNE.S	ModChg50Con
	RTS
ModChg50Con:
	TST.B	Pl5Dirty		; VRAM = planes unless a VDP command drew
	BNE.S	ModChg5Go		; in them (OUT98A writes both).
	RTS
ModChg5Go:
	SF	Pl5Dirty

	NOINT
	MOVEM.L	D0-D7/A0-A2/A4-A5,BUFER(A3)

	MOVEM.L	ModoChg5Dat(PC),D7/A0/A1/A2/A4/A5

P4_BUC:
	MOVEQ	#4-1,D6
	MOVE.W	(A0)+,D0
	MOVE.W	(A1)+,D1
	MOVE.W	(A2)+,D2
	MOVE.W	(A5)+,D3
P4_BUC0:
	ADD.W	D3,D3
	ADDX.L	D4,D4		; Colores impares
	ADD.W	D2,D2
	ADDX.L	D4,D4
	ADD.W	D1,D1
	ADDX.L	D4,D4
	ADD.W	D0,D0
	ADDX.L	D4,D4

	ADD.W	D3,D3
	ADDX.L	D4,D4		; Colores pares.
	ADD.W	D2,D2
	ADDX.L	D4,D4
	ADD.W	D1,D1
	ADDX.L	D4,D4
	ADD.W	D0,D0
	ADDX.L	D4,D4

	DBF	D6,P4_BUC0

	MOVEQ	#4-1,D6
P4_BUC1:
	ADD.W	D3,D3
	ADDX.L	D5,D5		; Colores impares
	ADD.W	D2,D2
	ADDX.L	D5,D5
	ADD.W	D1,D1
	ADDX.L	D5,D5
	ADD.W	D0,D0
	ADDX.L	D5,D5

	ADD.W	D3,D3
	ADDX.L	D5,D5		; Colores pares.
	ADD.W	D2,D2
	ADDX.L	D5,D5
	ADD.W	D1,D1
	ADDX.L	D5,D5
	ADD.W	D0,D0
	ADDX.L	D5,D5

	DBF	D6,P4_BUC1

	MOVEM.L	D4-D5,(A4)
	ADDQ	#8,A4

	DBF	D7,P4_BUC

	MOVEM.L	BUFER(A3),D0-D7/A0-A2/A4-A5
	SIINT

	RTS



; <=---------------------------------------------------------=>

	CNOP	0,8
ActPlanos5:
ActPlanos7:

	TST.B	DirPrefs+$6B		; Refresh 100% Graphics.
	BNE.S	ActPla7Con
	RTS
ActPla7Con:

	NOINT
	MOVEM.L	D0-D7/A0-A2/A4-A5,BUFER(A3)
	MOVE.L	A6,ActPA6
	TST.B	V5All			; All of VRAM (start, after SCREEN 6/8)...
	BNE.S	ActPlaAll
	SUB.L	A6,A6			; ...or the 1 KB blocks written since.
ActPlaBlk:
	CMP.W	#128,A6
	BCC	ActPlaFin
	TST.B	(VBlk5.L,A6.W)
	BEQ.S	ActPlaNx
	SF	(VBlk5.L,A6.W)
	CMP.W	SCRTBLo,A6		; (SCREENT only for its page's blocks.)
	BCS.S	ActPlaNoT
	CMP.W	SCRTBHi,A6
	BCC.S	ActPlaNoT
	ST	SCRTDirty
ActPlaNoT:
	MOVE.L	A6,D7
	LSL.L	#8,D7			; 256 plane bytes per 1 KB of VRAM.
	LEA	(SCR0.L,D7.L),A0
	LEA	(SCR0+(SIZEX*SIZEY*1),D7.L),A1
	LEA	(SCR0+(SIZEX*SIZEY*2),D7.L),A2
	LEA	(SCR0+(SIZEX*SIZEY*3),D7.L),A5
	LSL.L	#2,D7
	LEA	(DIRVRAM.L,D7.L),A4
	MOVE.W	#(1024/8)-1,D7
	MOVE.L	#ActPlaNx,ActPRet
	BRA.S	PU4_BUC
ActPlaNx:
	ADDQ.W	#1,A6
	BRA.S	ActPlaBlk
ActPlaAll:
	SF	V5All
	ST	SCRTDirty
	LEA	VBlk5,A0
	MOVEQ	#(128/4)-1,D7
ActPlaClr:
	CLR.L	(A0)+
	DBF	D7,ActPlaClr
	MOVEM.L	ModoChg5Dat(PC),D7/A0/A1/A2/A4/A5
	MOVE.L	#ActPlaFin,ActPRet

PU4_BUC:
	MOVEQ	#4-1,D6
	MOVEM.L	(A4)+,D4-D5
PU4_BUC0:
	ADD.L	D4,D4		; Colores impares
	ADDX.B	D3,D3
	ADD.L	D4,D4
	ADDX.B	D2,D2
	ADD.L	D4,D4
	ADDX.B	D1,D1
	ADD.L	D4,D4
	ADDX.B	D0,D0

	ADD.L	D4,D4		; Colores pares.
	ADDX.B	D3,D3
	ADD.L	D4,D4
	ADDX.B	D2,D2
	ADD.L	D4,D4
	ADDX.B	D1,D1
	ADD.L	D4,D4
	ADDX.B	D0,D0

	DBF	D6,PU4_BUC0

	MOVEQ	#4-1,D6
PU4_BUC1:
	ADD.L	D5,D5		; Colores impares
	ADDX.W	D3,D3
	ADD.L	D5,D5
	ADDX.W	D2,D2
	ADD.L	D5,D5
	ADDX.W	D1,D1
	ADD.L	D5,D5
	ADDX.W	D0,D0

	ADD.L	D5,D5		; Colores pares.
	ADDX.W	D3,D3
	ADD.L	D5,D5
	ADDX.W	D2,D2
	ADD.L	D5,D5
	ADDX.W	D1,D1
	ADD.L	D5,D5
	ADDX.W	D0,D0

	DBF	D6,PU4_BUC1

	MOVE.W	D0,(A0)+
	MOVE.W	D1,(A1)+
	MOVE.W	D2,(A2)+
	MOVE.W	D3,(A5)+
	DBF	D7,PU4_BUC
	JMP	([ActPRet.L])		; (No BSR here: one call level.)
ActPlaFin:
	MOVE.L	ActPA6,A6
	MOVEM.L	BUFER(A3),D0-D7/A0-A2/A4-A5
	SIINT

	RTS
ActPA6:		DC.L	0
ActPRet:	DC.L	0
V5All:		DC.B	$FF		; SCR0 planes: convert all of VRAM.
Pl5Dirty:	DC.B	0		; SCR0 planes drawn by VDP commands.
		EVEN

; <=---------------------------------------------------------=>

;  --------------------------------------------------------------------
; <********************************************************************>
;  --------------------------------------------------------------------

	CNOP	0,4
PRINT8ecs:
	MOVE.L	#COPPER8E,NEXTCOPP

	MOVEQ	#0,D1
	MOVE.B	VDPLINY(A3),D1
	MOVE.W	#255,D0
	SUB.W	D1,D0
	ADD.W	#INIPANT,D0
	MOVE.B	D0,COOR8E
	MOVE.B	D0,COOR8BE
	ADDQ.B	#1,COOR8BE
	MOVE.L	#$01A00000,COOR8E-4
	LSR.W	#4,D0
	LSR.W	#4,D0
	BEQ.S	BIEN8
	MOVE.L	#$FFDFFFFE,COOR8E-4
BIEN8:
	MOVE.B	DVDP2(A3),D0
	AND.W	#$0020,D0
	LSL.W	#3,D0
	OR.B	VDPLINY(A3),D0
	MULU	#32,D0
	ADD.L	#SCR0,D0
	MOVE.L	#(32*512),D1
	MOVE.W	#$E0,D3
	ADD.L	D1,D0
	MOVEQ	#1-1,D2
	LEA	PLANO8E,A1
	JSR	HACEPLANOS
	ADD.L	D1,D0
	MOVEQ	#2-1,D2
	JSR	HACEPLANOS
	ADD.L	D1,D0
	MOVEQ	#2-1,D2
	JSR	HACEPLANOS
	RTS

; -=-=-

	CNOP	0,8
PRINT8:	MOVE.L	#COPPER8,NEXTCOPP	; No mover.
	MOVE.L	#SPRMODE6,RSPR(A3)

	BSR	Act_Adjust
; -=-=-
	ST	ScanningY(A3)
; -=-=-
	BTST	#3,DVDP9(A3)
	BEQ	NoInterlaz8

	MOVE.B	DVDP2(A3),D0		; Pone Bit-Panos en copper.
	AND.W	#$0020,D0
	LSL.W	#3,D0
	MOVE.B	VDPLinY(A3),D0

	MULU	#32,D0
	ADD.L	#SCR0,D0
	LEA	PLANO8+2,A0
	MOVE.L	#(32*512),D1

	MOVE.W	D0,4(A0)
	SWAP	D0
	MOVE.W	D0,(A0)
	SWAP	D0
	ADD.L	D1,D0
	MOVE.W	D0,12(A0)
	SWAP	D0
	MOVE.W	D0,8(A0)
	SWAP	D0
	ADD.L	D1,D0
	MOVE.W	D0,20(A0)
	SWAP	D0
	MOVE.W	D0,16(A0)
	SWAP	D0
	ADD.L	D1,D0
	MOVE.W	D0,28(A0)
	SWAP	D0
	MOVE.W	D0,24(A0)
	SWAP	D0
	ADD.L	D1,D0
	MOVE.W	D0,36(A0)
	SWAP	D0
	MOVE.W	D0,32(A0)
	SWAP	D0
	ADD.L	D1,D0
	MOVE.W	D0,44(A0)
	SWAP	D0
	MOVE.W	D0,40(A0)
	SWAP	D0
	ADD.L	D1,D0
	MOVE.W	D0,52(A0)
	SWAP	D0
	MOVE.W	D0,48(A0)
	SWAP	D0
	ADD.L	D1,D0
	MOVE.W	D0,60(A0)
	SWAP	D0
	MOVE.W	D0,56(A0)
NoInterlaz8:
; -=-=-

	BSR	PasaPun8Bpl


	BRA	SPRMODE6

	RTS


; -------------------------------=> Actualiza VRAM PUN8 a BPL8 (realtime)
	CNOP	0,4
PasaPun8Bpl:

	LEA	Scr0,A0
	LEA	PasPun8Fast,A2
	LEA	TablaPun8Bpl,A5
	LEA	DirVRAM,A6

	LEA	Tab98,A4

	MOVE.W	#(32*512),D2
	MOVEQ	#(8*4),D3
	MOVE.W	#$0100,D6

	MOVE.W	#(($800*8)/4)-1,D5
PaPu8BpBuc1:
	TST.L	(A4)+
	BNE.S	PaPu8BpRut

	ADDQ	#4,A0
	ADD.W	D3,A6

	DBF	D5,PaPu8BpBuc1
	RTS

	CNOP	0,4
PaPu8BpRut:
	CLR.L	-4(A4)

	MOVE.W	#(4)-1,D4
	MOVEQ	#0,D7
PaPu8BpBuc:
	MOVE.B	(A6)+,D7
	MOVE.L	(A5,D7.W*8),D0
	MOVE.L	4(A5,D7.W*8),D1

PaPuMac:MACRO
	ADD.W	D6,D7
	MOVE.B	(A6)+,D7
	BEQ.S	\@EsCero
	OR.L	(A5,D7.W*8),D0
	OR.L	4(A5,D7.W*8),D1
\@EsCero:
	ENDM

	REPT	7
	PaPuMac
	ENDR

	MOVEQ	#0,D7


	MOVE.B	D0,(A2)+
	LSR.W	#8,D0
	MOVE.B	D0,4-1(A2)
	SWAP	D0
	MOVE.B	D0,8-1(A2)
	LSR.W	#8,D0
	MOVE.B	D0,12-1(A2)

	MOVE.B	D1,16-1(A2)
	LSR.W	#8,D1
	MOVE.B	D1,20-1(A2)
	SWAP	D1
	MOVE.B	D1,24-1(A2)
	LSR.W	#8,D1
	MOVE.B	D1,28-1(A2)

	DBF	D4,PaPu8BpBuc

	MOVE.L	-4(A2),(A0)+
	LEA	-4(A0,D2.W),A1
	MOVE.L	(A2)+,(A1)
	ADD.W	D2,A1
	MOVE.L	(A2)+,(A1)
	ADD.W	D2,A1
	MOVE.L	(A2)+,(A1)
	ADD.W	D2,A1
	MOVE.L	(A2)+,(A1)
	ADD.W	D2,A1
	MOVE.L	(A2)+,(A1)
	ADD.W	D2,A1
	MOVE.L	(A2)+,(A1)
	ADD.W	D2,A1
	MOVE.L	(A2)+,(A1)

	SUB.W	D3,A2

	DBF	D5,PaPu8BpBuc1
	RTS

	CNOP	0,16
PasPun8Fast:	DS.L	8

; -------------------------------<=


; -------------------------------<=
; -------------------------------<=

	CNOP	0,8
VDP2Escr8:
	MOVEM.L	D0-D7/A0-A6,BUFER(A3)

	MOVE.B	D2,DVDPREG(A3)

	LSR.B	#4,D2

	CMP.B	#$0D,D2		; HMMM
	BEQ.S	COPIA8

	CMP.B	#$09,D2		; LMMM
	BEQ.S	COPIA8


	CMP.B	#$0C,D2		; HMMV
	BEQ	COPYVDP8

	CMP.B	#$08,D2		; LMMV
	BEQ	COPYVDP8



	MOVEM.L	BUFER(A3),D0-D7/A0-A6
	JMP	Torna8

COPIA8:
	MOVE.W	DVDPSY(A3),D0
	MULU	#256,D0
	ADD.W	DVDPSX(A3),D0
	LEA	(DIRVRAM,D0.L),A0

	MOVE.W	DVDPDY(A3),D0
	MULU	#256,D0
	ADD.W	DVDPDX(A3),D0
	LEA	(DIRVRAM,D0.L),A1

	MOVE.L	D0,D5

	MOVE.W	DVDPNX(A3),D0
	AND.W	#$00FF,D0
	BNE.S	RECON0
	MOVE.W	#$100,D0
RECON0:
	MOVE.L	#$100,D2
	SUB.W	D0,D2

	MOVE.W	DVDPNY(A3),D1
	AND.W	#$01FF,D1
	BNE.S	RECON1
	MOVE.W	#$200,D1
RECON1:

	SUBQ.W	#1,D0
	SUBQ.W	#1,D1
; ------------------------------- PRUEBA ABAJO
	MOVE.B	DVDPREG(A3),D3
	AND.B	#$0F,D3
	BTST	#3,D3
	BNE.S	Tc8Continua

	CMP.B	#8,D3
	BEQ.S	Nc8Bucle1

c8Bucle1:
	MOVE.W	D0,D4
c8Bucle0:
	MOVE.B	(A0)+,(A1)+
	MOVE.L	D5,D6
	LSR.L	#3,D6
	ST	(Tab98,D6.L)
	ADDQ.L	#1,D5
	DBF	D4,c8Bucle0
	ADD.W	D2,A0
	ADD.W	D2,A1
	ADD.L	D2,D5
	DBF	D1,c8Bucle1

	MOVEM.L	BUFER(A3),D0-D7/A0-A6
	SWAP	D2
	RTS

Nc8Bucle1:
	MOVE.W	D0,D4
Nc8Bucle0:
	MOVE.B	(A0)+,D3
	NOT.B	D3
	MOVE.B	D3,(A1)+
	MOVE.L	D5,D6
	LSR.L	#3,D6
	ST	(Tab98,D6.L)
	ADDQ.L	#1,D5
	DBF	D4,Nc8Bucle0
	ADD.W	D2,A0
	ADD.W	D2,A1
	ADD.L	D2,D5
	DBF	D1,Nc8Bucle1

	MOVEM.L	BUFER(A3),D0-D7/A0-A6
	SWAP	D2
	RTS

Tc8Continua:
	CMP.B	#$0C,D3
	BEQ.S	TNc8Bucle1

Tc8Bucle1:
	MOVE.W	D0,D4
Tc8Bucle0:
	MOVE.B	(A0)+,D3
	BEQ.S	Tc8Cont
	MOVE.B	D3,(A1)
Tc8Cont:
	ADDQ	#1,A1
	MOVE.L	D5,D6
	LSR.L	#3,D6
	ST	(Tab98,D6.L)
	ADDQ.L	#1,D5
	DBF	D4,Tc8Bucle0
	ADD.W	D2,A0
	ADD.W	D2,A1
	ADD.L	D2,D5
	DBF	D1,Tc8Bucle1

	MOVEM.L	BUFER(A3),D0-D7/A0-A6
	SWAP	D2
	RTS

TNc8Bucle1:
	MOVE.W	D0,D4
TNc8Bucle0:
	MOVE.B	(A0)+,D3
	BEQ.S	TNc8Cont
	NOT.B	D3
	MOVE.B	D3,(A1)
TNc8Cont:
	ADDQ	#1,A1
	MOVE.L	D5,D6
	LSR.L	#3,D6
	ST	(Tab98,D6.L)
	ADDQ.L	#1,D5
	DBF	D4,TNc8Bucle0
	ADD.W	D2,A0
	ADD.W	D2,A1
	ADD.L	D2,D5
	DBF	D1,TNc8Bucle1

	MOVEM.L	BUFER(A3),D0-D7/A0-A6
	SWAP	D2
	RTS
; ------------------------------- PRUEBA ARRIBA

COPYVDP8:
	MOVE.W	DVDPSY(A3),D0
	MULU	#256,D0
	ADD.W	DVDPSX(A3),D0
	LEA	(DIRVRAM,D0.L),A0

	MOVE.W	DVDPDY(A3),D0
	MULU	#256,D0
	ADD.W	DVDPDX(A3),D0
	LEA	(DIRVRAM,D0.L),A1

	MOVE.L	D0,D5

	MOVE.W	DVDPNX(A3),D0
	AND.W	#$00FF,D0
	BNE.S	RECON0z
	MOVE.W	#$100,D0
RECON0z:
	MOVE.L	#$100,D2
	SUB.W	D0,D2

	MOVE.W	DVDPNY(A3),D1
	AND.W	#$01FF,D1
	BNE.S	RECON1z
	MOVE.W	#$200,D1
RECON1z:

	SUBQ.W	#1,D0
	SUBQ.W	#1,D1

	MOVE.B	DVDPCL(A3),D7

c8Bucle1z:
	MOVE.W	D0,D4
c8Bucle0z:
	MOVE.B	D7,(A1)+
	MOVE.L	D5,D6
	LSR.L	#3,D6
	ST	(Tab98,D6.L)
	ADDQ.L	#1,D5
	DBF	D4,c8Bucle0z
	ADD.W	D2,A0
	ADD.W	D2,A1
	ADD.L	D2,D5
	DBF	D1,c8Bucle1z

	MOVEM.L	BUFER(A3),D0-D7/A0-A6
	SWAP	D2
	RTS





; -------------------------------<=
; -------------------------------<=


	CNOP	0,8
PRINT5:
	MOVE.L	#COPPER5,NEXTCOPP
	MOVE.L	#SPRMODE5,RSPR(A3)

	BSR	Act_Adjust
; -=-=-
	ST	ScanningY(A3)
; -=-=-
	BTST	#3,DVDP9(A3)
	BEQ.S	NoInterlaz5

	MOVE.B	DVDP2(A3),D0		; Pone Bit-Panos en copper.
	AND.W	#$0060,D0
	LSL.W	#3,D0
	MOVE.B	VDPLinY(A3),D0

	MULU	#32,D0
	ADD.L	#SCR0,D0
	LEA	PLANO5+2,A0
	MOVE.L	#(32*1024),D1

	MOVE.W	D0,4(A0)
	SWAP	D0
	MOVE.W	D0,(A0)
	SWAP	D0
	ADD.L	D1,D0
	MOVE.W	D0,12(A0)
	SWAP	D0
	MOVE.W	D0,8(A0)
	SWAP	D0
	ADD.L	D1,D0
	MOVE.W	D0,20(A0)
	SWAP	D0
	MOVE.W	D0,16(A0)
	SWAP	D0
	ADD.L	D1,D0
	MOVE.W	D0,28(A0)
	SWAP	D0
	MOVE.W	D0,24(A0)
NoInterlaz5:
; -=-=-

	BRA	SPRMODE5

	RTS


; ---
	CNOP	0,8
SPR_ECS:
	LEA	DIRSPRITES2,A0
	JSR	CREASPRITES

	LEA	BUFERSPR2-2,A0
	MOVE.L	A0,NUMSPR2
	JSR	CLEARSPR2
	RTS
; ---

	CNOP	0,8
SPRMODE5:
	CMP.W	#3,DirPrefs+$16
	BNE.S	NoModo3fr
	SUBQ.B	#1,Modo3fDat
	BNE.S	SiModo3fr
	MOVE.B	#3,Modo3fDat
	RTS
Modo3fDat:DC.B	3
	CNOP	0,8
NoModo3fr:
	TST.W	DirPrefs+$16
	BEQ.S	SPR_ECS
SiModo3fr:
	LEA	ContaSPR2(PC),A4
	BTST	#0,(A4)
	BEQ.S	SPRMODE5con

	CMP.W	#$01,DirPrefs+$16
	BEQ	SPRMODE51f
SPRMODE5con:
	ADDQ.B	#1,(A4)
	MOVE.B	(A4),D0
	AND.W	#$0003,D0

	LEA	4(A4,D0.W*8),A4
	LSR.B	#1,D0
	BCS	SPRMODE5b

	MOVE.L	(A4),A0
	MOVE.L	A0,NUMSPR2
	PERFMARK
	JSR	CLEARSPR2
	PERFSUB	4			; 4: CLEARSPR2
	RTS

	CNOP	0,8
SPRMODE5b:
	LEA	REGS(PC),A3
	BTST	#1,TopR8	; Sprites on (playfield R#8, MIDSAMPLE).
	BEQ.S	SISPRASC

	SUBQ.B	#1,COSPR2(A3)
	BCC.S	SISPRASC
	SF	COSPR2(A3)
SISPRASC:
	MOVE.L	A4,-(SP)
	PERFMARK
	BSR	BITPLASPR
	PERFSUB	0			; 0: BITPLASPR (patterns)
	BSR	BITSPRCOL
	PERFSUB	1			; 1: BITSPRCOL (colours, attributes)
	MOVE.L	(SP)+,A4

	MOVE.L	-4(A4),A0
	JSR	CREASPRITES
	PERFSUB	2			; 2: CREASPRITES

	LEA	REGS(PC),A3
	TST.B	COSPR2(A3)
	BEQ	SPR2OFF

	MOVE.L	(A4)+,A5
	MOVE.L	A5,NUMSPR2
	ADDQ	#2,A5
	MOVE.L	(A4),A6
	JSR	IMPSPR2
	PERFSUB	3			; 3: IMPSPR2 (draw)
SPR2OFF:
	RTS

	CNOP	0,8
SPRMODE51f:
	LEA	REGS(PC),A3
	BTST	#1,TopR8	; Sprites on (playfield R#8, MIDSAMPLE).
	BEQ.S	SISPRASC1f

	SUBQ.B	#1,COSPR2(A3)
	BCC.S	SISPRASC1f
	SF	COSPR2(A3)
SISPRASC1f:
	BSR	BITPLASPR
	BSR	BITSPRCOL

	LEA	REGS(PC),A3
	TST.B	COSPR2(A3)
	BEQ.S	SPR2OFF1f

	LEA	DIRSPRITES2,A0
	JSR	CREASPRITES

	LEA	BUFERSPR2-2,A0
	MOVE.L	A0,NUMSPR2
	JSR	CLEARSPR2
	LEA	BUFERSPR2,A5
	LEA	SPRIT0+16,A6
	JSR	IMPSPR2
SPR2OFF1f:
	RTS



	CNOP	0,8
ContaSPR2:
	DC.W	1,0
	DC.L	BUFERSPR2-2	; 0
	DC.L	DIRSPRITES2
	DC.L	BUFERSPR2-2	; 1
	DC.L	SPRIT0+16
	DC.L	BUFERSPR2b-2	; 2
	DC.L	DIRSPRITES2b
	DC.L	BUFERSPR2b-2	; 3
	DC.L	SPRIT0b+16


	CNOP	0,8
SPRMODE6:
	IFD	TRACE
	ADDQ.L	#1,TraceHdr+56		; Debug: SPRMODE6 calls.
	MOVE.W	DirPrefs+$16,TraceHdr+70
	MOVE.B	REGS+COSPR2,TraceHdr+72
	ENDC
	CMP.W	#3,DirPrefs+$16
	BNE.S	NoModo63fr
	SUBQ.B	#1,Modo3fDat
	BNE.S	SiModo63fr
	MOVE.B	#3,Modo3fDat
	RTS
	CNOP	0,8
NoModo63fr:
	TST.W	DirPrefs+$16
	BEQ	SPR_ECS
SiModo63fr:
	LEA	ContaSPR2(PC),A4
	BTST	#0,(A4)
	BEQ.S	SPRMODE6con

	CMP.W	#$01,DirPrefs+$16
	BEQ	SPRMODE61f
SPRMODE6con:
	ADDQ.B	#1,(A4)
	MOVE.B	(A4),D0
	AND.W	#$0003,D0

	LEA	4(A4,D0.W*8),A4
	LSR.B	#1,D0
	BCS.S	SPRMODE6b

	MOVE.L	(A4),A0
	MOVE.L	A0,NUMSPR2
	JSR	CLEARSPR2
	RTS

	CNOP	0,8
SPRMODE6b:
	LEA	REGS(PC),A3
	BTST	#1,TopR8	; Sprites on (playfield R#8, MIDSAMPLE).
	BEQ.S	SISPRASC6

	SUBQ.B	#1,COSPR2(A3)
	BCC.S	SISPRASC6
	SF	COSPR2(A3)
SISPRASC6:
;	MOVE.L	A4,-(SP)
;;	BSR	BITPLASPR6
;;	BSR	BITSPRCOL6
;	MOVE.L	(SP)+,A4

	MOVE.L	-4(A4),A0
	JSR	CREASPRITES

	LEA	REGS(PC),A3
	TST.B	COSPR2(A3)
	BEQ.S	SPR2OFF6

	MOVE.L	(A4)+,A5
	MOVE.L	A5,NUMSPR2
	ADDQ	#2,A5
	MOVE.L	(A4),A6
	IFD	TRACE
	ADDQ.L	#1,TraceHdr+60		; Debug: IMPSPR2 calls (mode 6).
	ENDC
	JSR	IMPSPR2
	RTS
SPR2OFF6:
	IFD	TRACE
	ADDQ.L	#1,TraceHdr+64		; Debug: sprites off.
	ENDC
	RTS

	CNOP	0,8
SPRMODE61f:
	LEA	REGS(PC),A3
	BTST	#1,TopR8	; Sprites on (playfield R#8, MIDSAMPLE).
	BEQ.S	SISPRASC1fb

	SUBQ.B	#1,COSPR2(A3)
	BCC.S	SISPRASC1fb
	SF	COSPR2(A3)
SISPRASC1fb:
;;	BSR	BITPLASPR
;;	BSR	BITSPRCOL

	LEA	REGS(PC),A3
	TST.B	COSPR2(A3)
	BEQ.S	SPR2OFF1fb

	LEA	DIRSPRITES2,A0
	JSR	CREASPRITES

	LEA	BUFERSPR2-2,A0
	MOVE.L	A0,NUMSPR2
	JSR	CLEARSPR2
	LEA	BUFERSPR2,A5
	LEA	SPRIT0+16,A6
	JSR	IMPSPR2
SPR2OFF1fb:
	RTS




;  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

	CNOP	0,8
PRINT7:
	MOVE.L	#COPPER7,NEXTCOPP
	MOVE.L	#SPRMODE5,RSPR(A3)

	BSR	Act_Adjust
; -=-=-
	ST	ScanningY(A3)
; -=-=-
	BTST	#3,DVDP9(A3)
	BEQ.S	NoInterlaz7

	MOVE.B	DVDP2(A3),D0		; Pone Bit-Panos en copper.
	AND.W	#$0020,D0
	LSL.W	#3,D0
	MOVE.B	VDPLinY(A3),D0

	MULU	#64,D0
	ADD.L	#SCR0,D0
	LEA	PLANO7+2,A0
	MOVE.L	#(64*512),D1

	MOVE.W	D0,4(A0)
	SWAP	D0
	MOVE.W	D0,(A0)
	SWAP	D0
	ADD.L	D1,D0
	MOVE.W	D0,12(A0)
	SWAP	D0
	MOVE.W	D0,8(A0)
	SWAP	D0
	ADD.L	D1,D0
	MOVE.W	D0,20(A0)
	SWAP	D0
	MOVE.W	D0,16(A0)
	SWAP	D0
	ADD.L	D1,D0
	MOVE.W	D0,28(A0)
	SWAP	D0
	MOVE.W	D0,24(A0)
NoInterlaz7:
; -=-=-

	BRA	SPRMODE5

	RTS

;  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*


	CNOP	0,8
BITPLASPR:
	LEA	REGS(PC),A6
	MOVE.L	PVDP6(A6),D0		; Puntero Gfx Sprits VRAM
	MOVE.L	D0,-(SP)
	LSR.L	#2,D0
	LEA	(SCR0.L,D0.L),A0
	MOVE.L	#(64*512),D1
	MOVE.L	A0,A1
	ADD.L	D1,A1
	MOVE.L	A1,A2
	ADD.L	D1,A2
	MOVE.L	A2,A3
	ADD.L	D1,A3

	LSR.W	#6,D0
	LEA	(TABSPR.L,D0.W),A6

	LEA	DIRVRAM,A4
	ADD.L	(SP)+,A4

	LEA	TABLAP4B(PC),A5
	MOVE.W	#$100,D6

	MOVEQ	#(64/8)-1,D5
P4_BUCI:
	TST.B	(A6)+
	BNE.S	REDESPR

	ADD.W	#16*4,A0
	ADD.W	#16*4,A1
	ADD.W	#16*4,A2
	ADD.W	#16*4,A3
	ADD.W	#(8*4*8),A4

	DBF	D5,P4_BUCI
	RTS

	CNOP	0,8
REDESPR:
	SF	-1(A6)
	MOVEM.L	D5/A6,-(SP)
BPL4PUN:
	LEA	(256*4*2)(A5),A6
	MOVEQ	#$0,D5

	MOVE.W	#(16)-1,D7
P4BBUC:
	MOVE.L	(A0)+,D0
	MOVE.L	(A1)+,D1
	MOVE.L	(A2)+,D2
	MOVE.L	(A3)+,D3

	MOVE.B	D0,D5
	MOVE.L	(A5,D5.W*4),D4
	MOVE.B	D1,D6
	OR.L	(A5,D6.W*4),D4
	MOVE.B	D2,D5
	OR.L	(A6,D5.W*4),D4
	MOVE.B	D3,D6
	OR.L	(A6,D6.W*4),D4
	MOVE.L	D4,$0C(A4)

	LSR.W	#8,D0
	LSR.W	#8,D1
	LSR.W	#8,D2
	LSR.W	#8,D3

	MOVE.L	(A5,D0.W*4),D4
	MOVE.B	D1,D6
	OR.L	(A5,D6.W*4),D4
	OR.L	(A6,D2.W*4),D4
	MOVE.B	D3,D6
	OR.L	(A6,D6.W*4),D4
	MOVE.L	D4,$08(A4)

	SWAP	D0
	SWAP	D1
	SWAP	D2
	SWAP	D3

	MOVE.B	D0,D5
	MOVE.L	(A5,D5.W*4),D4
	MOVE.B	D1,D6
	OR.L	(A5,D6.W*4),D4
	MOVE.B	D2,D5
	OR.L	(A6,D5.W*4),D4
	MOVE.B	D3,D6
	OR.L	(A6,D6.W*4),D4
	MOVE.L	D4,$04(A4)

	LSR.W	#8,D0
	LSR.W	#8,D1
	LSR.W	#8,D2
	LSR.W	#8,D3

	MOVE.L	(A5,D0.W*4),D4
	MOVE.B	D1,D6
	OR.L	(A5,D6.W*4),D4
	OR.L	(A6,D2.W*4),D4
	MOVE.B	D3,D6
	OR.L	(A6,D6.W*4),D4
	MOVE.L	D4,(A4)
	ADD.W	#$10,A4
	DBF	D7,P4BBUC

	MOVEM.L	(SP)+,D5/A6
	DBF	D5,P4_BUCI
	RTS


B4PMAC:	MACRO
	MOVEQ	#0,D2
	MOVE.B	D0,D1
	BFINS	D1,D2{31-\1:1}
	LSR.B	#1,D1
	BFINS	D1,D2{27-\1:1}
	LSR.B	#1,D1
	BFINS	D1,D2{23-\1:1}
	LSR.B	#1,D1
	BFINS	D1,D2{19-\1:1}
	LSR.B	#1,D1
	BFINS	D1,D2{15-\1:1}
	LSR.B	#1,D1
	BFINS	D1,D2{11-\1:1}
	LSR.B	#1,D1
	BFINS	D1,D2{07-\1:1}
	LSR.B	#1,D1
	BFINS	D1,D2{03-\1:1}
	MOVE.L	D2,(\2)+
	ENDM


CREATABB4P:
	LEA	TABLAP4B+(256*4*0),A0
	LEA	TABLAP4B+(256*4*1),A1
	LEA	TABLAP4B+(256*4*2),A2
	LEA	TABLAP4B+(256*4*3),A3

	MOVEQ	#0,D0
	MOVE.W	#256-1,D7
P4BBUC0:
	B4PMAC	0,A0
	B4PMAC	1,A1
	B4PMAC	2,A2
	B4PMAC	3,A3

	ADDQ.B	#1,D0
	DBF	D7,P4BBUC0
	RTS	

	CNOP	0,8
TABLAP4B:DS.B	256*4*4
	ds.b	20

; ------------------

	CNOP	0,8
BITSPRCOL:
	LEA	REGS(PC),A3
	LEA	DIRVRAM,A4

	MOVE.L	PVDP5(A3),D0		; Coordenadas sprites.
	ADD.L	D0,A4			; Coordenadas sprites Bpl.
	MOVE.W	DVDP5(A3),D1
	AND.W	#$0003,D1
	MULU	#$80,D1
	ADD.W	#512,D1
	SUB.W	D1,A4
	SUB.L	D1,D0
	LSR.L	#2,D0
	LEA	(SCR0.L,D0.L),A0
	MOVE.L	#(64*512),D1
	MOVE.L	A0,A1
	ADD.L	D1,A1
	MOVE.L	A1,A2
	ADD.L	D1,A2
	MOVE.L	A2,A3
	ADD.L	D1,A3

	LSR.W	#6,D0
	LEA	(TABSPR.L,D0.W),A6

	LEA	TABLAP4B(PC),A5
	MOVE.W	#$100,D6


	MOVEQ	#(3)-1,D5
P4_BUC3I:
	TST.B	(A6)+
	BNE.S	COORSPR

	ADD.W	#64,A0
	ADD.W	#64,A1
	ADD.W	#64,A2
	ADD.W	#64,A3
	ADD.W	#(8*8*4),A4

	DBF	D5,P4_BUC3I
	RTS

	CNOP	0,8
COORSPR:
	SF	-1(A6)
	MOVEM.L	D5/A6,-(SP)
BPL4PUN2:
	LEA	(256*4*2)(A5),A6
	MOVEQ	#$0,D5

	MOVE.W	#(16)-1,D7
P4BBUC2:
	MOVE.L	(A0)+,D0
	MOVE.L	(A1)+,D1
	MOVE.L	(A2)+,D2
	MOVE.L	(A3)+,D3

	MOVE.B	D0,D5
	MOVE.L	(A5,D5.W*4),D4
	MOVE.B	D1,D6
	OR.L	(A5,D6.W*4),D4
	MOVE.B	D2,D5
	OR.L	(A6,D5.W*4),D4
	MOVE.B	D3,D6
	OR.L	(A6,D6.W*4),D4
	MOVE.L	D4,$0C(A4)

	LSR.W	#8,D0
	LSR.W	#8,D1
	LSR.W	#8,D2
	LSR.W	#8,D3

	MOVE.L	(A5,D0.W*4),D4
	MOVE.B	D1,D6
	OR.L	(A5,D6.W*4),D4
	OR.L	(A6,D2.W*4),D4
	MOVE.B	D3,D6
	OR.L	(A6,D6.W*4),D4
	MOVE.L	D4,$08(A4)

	SWAP	D0
	SWAP	D1
	SWAP	D2
	SWAP	D3

	MOVE.B	D0,D5
	MOVE.L	(A5,D5.W*4),D4
	MOVE.B	D1,D6
	OR.L	(A5,D6.W*4),D4
	MOVE.B	D2,D5
	OR.L	(A6,D5.W*4),D4
	MOVE.B	D3,D6
	OR.L	(A6,D6.W*4),D4
	MOVE.L	D4,$04(A4)

	LSR.W	#8,D0
	LSR.W	#8,D1
	LSR.W	#8,D2
	LSR.W	#8,D3

	MOVE.L	(A5,D0.W*4),D4
	MOVE.B	D1,D6
	OR.L	(A5,D6.W*4),D4
	OR.L	(A6,D2.W*4),D4
	MOVE.B	D3,D6
	OR.L	(A6,D6.W*4),D4
	MOVE.L	D4,(A4)
	ADD.W	#$10,A4
	DBF	D7,P4BBUC2

	MOVEM.L	(SP)+,D5/A6
	DBF	D5,P4_BUC3I
	RTS


; -------------------------------------------------------

	CNOP	0,8
PRINT6:
	MOVE.B	DVDP7(A3),D1
	AND.W	#$0003,D1
	MOVE.W	(MSX2Pal.W,PC,D1.W*2),D0
	MOVE.W	D0,COLORMSX2+2		; Color del Borde.

PRINT6ecs:
	MOVE.L	#COPPER6,NEXTCOPP
	MOVE.L	#SPRMODE6,RSPR(A3)

	BSR	Act_Adjust

ModC60:	MOVEQ	#-8,D1
	MOVE.L	Cop_Rest,A4
	MOVE.W	D1,(A4)
	MOVE.W	D1,4(A4)

ModC61:	MOVE.W	#(-64*256)-8,D1
	MOVE.W	#255,D0
	SUB.B	VDPLINY(A3),D0
	MULU	#TabCop5Add,D0
	LEA	(TabCop5+4+2,D0.W),A4
	MOVE.L	A4,Cop_Rest
	MOVE.W	D1,(A4)
	MOVE.W	D1,4(A4)


	MOVE.B	DVDP2(A3),D0
	AND.W	#$0060,D0
	LSL.W	#3,D0
	OR.B	VDPLINY(A3),D0
	MULU	#64,D0
	ADD.L	#SCR0,D0

	MOVE.L	#(64*1024),D1
	MOVEQ	#2-1,D2
	MOVE.W	#$E0,D3
	LEA	PLANO6,A1
	JSR	HACEPLANOS

	BRA	SPRMODE6

	RTS



; -------------------------------------------------
; -------------------------------------------------
; -------------------------------------------------
; -------------------------------------------------
; -------------------------------------------------

; ---------------------------------------------------------

; SCPATT row,base: pattern row (row register: pattern line, base: the
; sprite's pattern in VRAM) as 32 bits, leftmost pixel in bit 31 (16 wide
; with SI, doubled with MAG), into the row register. Uses D1.
SCPATT:	MACRO
	MOVEQ	#0,D1
	MOVE.B	(\2,\1.W),D1
	TST.B	SCSI
	BEQ.S	\@8
	LSL.W	#8,D1
	MOVE.B	16(\2,\1.W),D1
	TST.B	SCMag
	BEQ.S	\@16
	MOVEQ	#0,\1			; 16 -> 32 bits.
	MOVE.B	D1,\1
	MOVE.W	(SCDbl.L,\1.W*2),\1
	LSR.W	#8,D1
	MOVE.W	(SCDbl.L,D1.W*2),D1
	SWAP	D1
	MOVE.W	\1,D1
	MOVE.L	D1,\1
	BRA.S	\@E
\@16:	SWAP	D1			; 16 bits.
	MOVE.L	D1,\1
	BRA.S	\@E
\@8:	TST.B	SCMag
	BEQ.S	\@8b
	MOVE.W	(SCDbl.L,D1.W*2),D1	; 8 -> 16 bits.
	SWAP	D1
	MOVE.L	D1,\1
	BRA.S	\@E
\@8b:	ROR.L	#8,D1			; 8 bits.
	MOVE.L	D1,\1
\@E:
	ENDM

IVDP0:
	SF	PetInt38+1(A3)

	MOVE.B	Estado(A3),D1
	SF	Estado(A3)
	TST.B	SCPend			; Sprite collision of the last frame.
	IFND	NOSPRCOL		; (A/B: -DNOSPRCOL=1: same code size, never
	BNE	SCCalc			; checks.)
	ELSEIF
	BRA.W	SCBack
	ENDC
SCBack:
;;	BFTST	$DFF00E{1:6}		; Colisi�n de sprites?
;;	BNE.S	SiDetecSpr

; 5th sprite flag (TMS9918 / V9938 sprite mode 1, as openMSX SpriteChecker):
; S#0 reads 5S (bit 6) and the 5th sprite's number (bits 4-0) once the beam
; has passed a line with more than 4 sprites. Reading clears it and the next
; such line sets it again, with its own 5th sprite. MSX1 games use this as a
; raster split (Uridium polls S#0 for $5C: 5S + sprite #28).
; D2 is saved: its byte 1 and high word belong to the Z80 core.
	MOVE.L	D2,S5D2
	TST.B	S5Valid
	BNE.S	S0Have
	BRA	S5Calcula		; No BSR: A7 is not a stack here.
S0Have:
	MOVE.W	S5Next,D2		; Next line not reported yet.
S0Buc:	CMP.W	CurLine(A3),D2
	BGT.S	S0Nada			; Beam not there yet.
	CMP.W	#192,D2
	BCC.S	S0Nada
	CMP.B	#$FF,(S5Tab.L,D2.W)
	BNE.S	S0Si
	ADDQ.W	#1,D2
	BRA.S	S0Buc
S0Si:	AND.B	#$A0,D1
	OR.B	#$40,D1
	OR.B	(S5Tab.L,D2.W),D1
	ADDQ.W	#1,D2
S0Nada:	MOVE.W	D2,S5Next
; Idle poll: the same IN instruction (A5) reading the same S#0 again. The
; answer can only change at a line boundary (5S, VBlank, line interrupt),
; so end the line now instead of emulating the rest of the busy loop
; (Uridium waits ~60 lines a frame for its 5S split this way).
	CMP.L	S0LastA5,A5
	BNE.S	S0Idle0
	CMP.B	S0LastV,D1
	BNE.S	S0Idle1
	ADDQ.B	#1,S0IdleN
	CMP.B	#2,S0IdleN
	BCS.S	S0IdleX
	CLR.W	(A3)			; Cycles left in this line: none.
	BRA.S	S0IdleX
S0Idle0:MOVE.L	A5,S0LastA5
S0Idle1:MOVE.B	D1,S0LastV
	SF	S0IdleN
S0IdleX:
	MOVE.L	S5D2,D2
	RTS

; S5Tab[line] = number of the 5th sprite on that display line, or $FF.
S5Calcula:
	ST	S5Valid
	MOVEM.L	D0-D1/D3-D7/A0-A1,S5Save
	LEA	S5Tab,A1		; No 5th sprite on any line yet.
	MOVEQ	#(192/4)-1,D0
	MOVEQ	#-1,D1
S5TabClr:
	MOVE.L	D1,(A1)+
	DBF	D0,S5TabClr
	MOVE.B	DVDP0(A3),D2		; Mode 1 sprites: G1, G2, MC only
	AND.B	#$0C,D2			; (M4, M5 clear) and not text (M1).
	BNE	S5Fin
	BTST	#4,DVDP1(A3)
	BNE	S5Fin
	BTST	#1,DVDP8(A3)		; SPD: sprites disabled.
	BNE	S5Fin
	LEA	S5Cnt,A1		; Per-line counters.
	MOVEQ	#(256/4)-1,D0
S5Clr:	CLR.L	(A1)+
	DBF	D0,S5Clr
	LEA	S5Cnt,A1
	MOVE.L	PVDP5(A3),A0		; Sprite attribute table.
	ADD.L	#DIRVRAM,A0
	MOVEQ	#8,D5			; Height: 8, 16 (SI), x2 (MAG).
	BTST	#1,DVDP1(A3)
	BEQ.S	S5NoSI
	MOVEQ	#16,D5
S5NoSI:	BTST	#0,DVDP1(A3)
	BEQ.S	S5NoMag
	ADD.W	D5,D5
S5NoMag:
	MOVEQ	#0,D7			; Sprite number.
S5Spr:	MOVEQ	#0,D3
	MOVE.B	(A0),D3			; Y
	CMP.B	#208,D3			; End of the list.
	BEQ.S	S5Fin
	ADDQ.W	#1,D3			; Shown from line Y+1...
	CMP.W	#$E1,D3			; ...Y >= $E0 starts above line 0.
	BCS.S	S5Pos
	SUB.W	#256,D3
S5Pos:	MOVE.W	D5,D4
	SUBQ.W	#1,D4
S5Lin:	TST.W	D3
	BMI.S	S5Sig
	CMP.W	#192,D3
	BCC.S	S5Sig
	ADDQ.B	#1,(A1,D3.W)
	CMP.B	#5,(A1,D3.W)
	BNE.S	S5Sig
	MOVE.B	D7,(S5Tab.L,D3.W)	; This sprite is the line's 5th.
S5Sig:	ADDQ.W	#1,D3
	DBF	D4,S5Lin
	ADDQ.W	#4,A0
	ADDQ.W	#1,D7
	CMP.W	#32,D7
	BCS.S	S5Spr
S5Fin:	MOVEM.L	S5Save,D0-D1/D3-D7/A0-A1
	BRA	S0Have
SiDetecSpr:
	OR.B	#$20,D1
	RTS

; Sprite collision flag (S#0 bit 5), as the VDP and openMSX SpriteChecker:
; set when two sprites shown on the same display line have a set pattern
; pixel in the same visible column. Only the first 4 (mode 1) / 8 (mode 2)
; sprites of a line are shown; the list ends at Y = 208 / 216; EC moves a
; sprite 32 pixels left; in mode 2, CC or IC in the line's colour byte leave
; the sprite out. No collisions with sprites or the display off, or in text
; modes. Checked once a frame, at the first S#0 read after the frame (the
; BIOS interrupt handler's), on the sprite tables as they are then; the
; read clears the bit (Estado). L'Abbaye des Morts only runs its hit test
; when the bit is set.
; No stack (A7 is the Restas table): registers saved in SCSave, back by BRA.
SCCalc:
	IFD	PERF
	ADDQ.L	#1,SCCalls		; (PERF dump: checks run.)
	ENDC
	SF	SCPend
	SF	SCHit
	SF	SCCutOK
	MOVEM.L	D0-D7/A0-A6,SCSave
	TST.B	SCDblOK
	BNE.S	SCDblY
	LEA	SCDbl,A0		; SCDbl[b] = b with each bit doubled.
	MOVEQ	#0,D0
SCDblB:	MOVEQ	#0,D1
	MOVEQ	#7,D2
SCDblC:	LSL.W	#2,D1
	BTST	D2,D0
	BEQ.S	SCDblD
	OR.W	#3,D1
SCDblD:	DBF	D2,SCDblC
	MOVE.W	D1,(A0)+
	ADDQ.W	#1,D0
	CMP.W	#256,D0
	BNE.S	SCDblB
	ST	SCDblOK
SCDblY:
	MOVE.B	DVDP1(A3),D0
	BTST	#6,D0			; Display off.
	BEQ	SCEnd
	BTST	#4,D0			; Text mode.
	BNE	SCEnd
	BTST	#1,DVDP8(A3)		; SPD: sprites off.
	BNE	SCEnd
	MOVEQ	#8,D6			; Height: 8, 16 (SI), x2 (MAG).
	BTST	#1,D0
	SNE	SCSI
	BEQ.S	SCNoSI
	MOVEQ	#16,D6
SCNoSI:	BTST	#0,D0
	SNE	SCMag
	BEQ.S	SCNoMag
	ADD.W	D6,D6
SCNoMag:MOVE.W	D6,SCH
	MOVE.B	DVDP0(A3),D0		; Mode 2: G3-G7 (M4 or M5).
	AND.B	#$0C,D0
	SNE	SCM2
	MOVE.W	#192,SCNL
	MOVEQ	#4,D1
	MOVE.W	#208,D4
	TST.B	SCM2
	BEQ.S	SCMode1
	MOVEQ	#8,D1
	MOVE.W	#216,D4
	BTST	#7,DVDP9(A3)		; 212 lines.
	BEQ.S	SCMode1
	MOVE.W	#212,SCNL
SCMode1:MOVE.W	D1,SCLim
	MOVE.L	PVDP5(A3),D0		; Attribute table (mode 2: A8, A7 from
	TST.B	SCM2			; R#5 not used, colours 512 bytes below).
	BEQ.S	SCSat1
	AND.L	#$1FE7F,D0
SCSat1:	MOVE.W	D4,SCStop
	LEA	DIRVRAM,A0
	ADD.L	D0,A0
	LEA	-$200(A0),A1		; Colours (mode 2).
	LEA	DIRVRAM,A2
	ADD.L	PVDP6(A3),A2		; Pattern table.
; 1. The sprites on screen, in table order (SCSpr, for the per-line limit).
; Those that can collide also go into SCList, sorted by top: a pixel in the
; pattern and (mode 2) a line without CC or IC. Parked blank sprites and
; the CC half of layered colour sprites can't.
	LEA	SCSpr,A4
	MOVEQ	#0,D5			; Sprites collected.
	MOVEQ	#0,D2			; ...that can collide.
	MOVEQ	#32-1,D3
SCGet:	MOVEQ	#0,D0
	MOVE.B	(A0),D0			; Y
	CMP.W	D4,D0			; End of the list.
	BEQ	SCGot
	ADDQ.W	#1,D0			; Shown from line Y+1; one that would
	MOVE.W	D0,D1			; run past line 255 starts above line 0.
	ADD.W	D6,D1
	CMP.W	#256,D1
	BLE.S	SCTop
	SUB.W	#256,D0
SCTop:	CMP.W	SCNL,D0			; Below the display: never shown.
	BGE	SCNext
	MOVE.W	D0,(A4)
	MOVEQ	#0,D0
	MOVE.B	1(A0),D0		; X
	TST.B	SCM2
	BNE.S	SCX
	BTST	#7,3(A0)		; Mode 1 EC.
	BEQ.S	SCX
	SUB.W	#32,D0
SCX:	MOVE.W	D0,2(A4)
	MOVEQ	#0,D0
	MOVE.B	2(A0),D0		; Pattern.
	TST.B	SCSI
	BEQ.S	SCPat
	AND.B	#$FC,D0
SCPat:	LSL.W	#3,D0
	LEA	(A2,D0.W),A6
	MOVE.L	A6,4(A4)
	MOVE.L	A1,8(A4)
	MOVE.L	(A6),D1			; Any pixel?
	OR.L	4(A6),D1
	TST.B	SCSI
	BEQ.S	SCBlank
	OR.L	8(A6),D1
	OR.L	12(A6),D1
	OR.L	16(A6),D1
	OR.L	20(A6),D1
	OR.L	24(A6),D1
	OR.L	28(A6),D1
SCBlank:TST.L	D1
	BEQ	SCKeep
	TST.B	SCM2
	BEQ.S	SCCan
	MOVEQ	#8-1,D1			; Mode 2: a line without CC and IC?
	TST.B	SCSI
	BEQ.S	SCCcL
	MOVEQ	#16-1,D1
SCCcL:	MOVE.B	(A1,D1.W),D0
	AND.B	#$60,D0
	BEQ.S	SCCan
	DBF	D1,SCCcL
	BRA	SCKeep
SCCan:	LEA	SCList,A3			; Insert into SCList, by top.
	MOVE.W	D2,D7
	LSL.W	#5,D7
	ADD.W	D7,A3
	MOVE.W	(A4),D0
SCIns:	CMP.L	#SCList,A3
	BEQ.S	SCInsW
	CMP.W	-32(A3),D0
	BGE.S	SCInsW
	MOVE.L	-32(A3),(A3)
	MOVE.L	-28(A3),4(A3)
	MOVE.L	-24(A3),8(A3)
	MOVE.L	-20(A3),12(A3)
	MOVE.L	-16(A3),16(A3)
	SUB.W	#32,A3
	BRA.S	SCIns
SCInsW:	MOVE.W	2(A4),D7		; Columns: X to X + width, from X - 32
	MOVE.W	D7,16(A3)		; if some line has EC (mode 2).
	ADD.W	D6,D7
	MOVE.W	D7,18(A3)
	TST.B	SCM2
	BEQ.S	SCInsE
	MOVEQ	#8-1,D7
	TST.B	SCSI
	BEQ.S	SCEcL
	MOVEQ	#16-1,D7
SCEcL:	TST.B	(A1,D7.W)
	BMI.S	SCEcY
	DBF	D7,SCEcL
	BRA.S	SCInsE
SCEcY:	SUB.W	#32,16(A3)
SCInsE:	MOVE.W	D0,(A3)			; Top,
	ADD.W	D6,D0
	MOVE.W	D0,2(A3)		; bottom (one past),
	MOVE.W	2(A4),4(A3)		; X,
	MOVE.W	D5,6(A3)		; number in SCSpr,
	MOVE.L	4(A4),8(A3)		; pattern,
	MOVE.L	A1,12(A3)		; colours.
	ADDQ.W	#1,D2
SCKeep:	ADD.W	#16,A4
	ADDQ.W	#1,D5
SCNext:	ADDQ.W	#4,A0
	ADD.W	#16,A1
	DBF	D3,SCGet
SCGot:	CMP.W	#2,D2			; Fewer than two can collide.
	BCS	SCEnd
	MOVE.W	D5,SCN
	MOVE.W	D2,SCM
; 2. Sweep SCList: for sprite J, the earlier ones (by top) whose lines reach
; J's top; all are SCH high, so the first that ends above J ends the scan.
; Then columns close enough; 3. then line by line.
	MOVEQ	#1,D7
SCJ:	CMP.W	SCM,D7
	BGE	SCEnd
	MOVE.W	D7,D1
	LSL.W	#5,D1
	LEA	SCList,A4
	ADD.W	D1,A4
	LEA	-32(A4),A5
	MOVE.W	D7,D6
	SUBQ.W	#1,D6
	MOVE.W	(A4),D0			; Top of J,
	MOVE.W	16(A4),D3		; its columns.
	MOVE.W	18(A4),D4
SCI:	CMP.W	2(A5),D0		; I ends above J: so do all before it.
	BGE.S	SCJNx
	CMP.W	16(A5),D4		; Columns overlap?
	BLE.S	SCIf
	CMP.W	18(A5),D3
	BLT.S	SCPair
SCIf:	SUB.W	#32,A5
	DBF	D6,SCI
SCJNx:	ADDQ.W	#1,D7
	BRA.S	SCJ
SCPair:	TST.W	D0			; Lines both cover: D0 (J's top, from
	BPL.S	SCP1			; line 0) to I's bottom (to the end of
	MOVEQ	#0,D0			; the display), less one.
SCP1:	MOVE.W	2(A5),D1
	CMP.W	SCNL,D1
	BLE.S	SCP2
	MOVE.W	SCNL,D1
SCP2:	CMP.W	D1,D0
	BGE	SCINx
	MOVE.W	D1,SCHi
	MOVE.W	6(A4),D1		; The later one in the table decides
	CMP.W	6(A5),D1		; whether both are shown on a line.
	BCC.S	SCP3
	MOVE.W	6(A5),D1
SCP3:	MOVE.B	D1,SCRk
SCL:	MOVE.W	D0,D2			; Pattern rows.
	SUB.W	(A5),D2
	MOVE.W	D0,D3
	SUB.W	(A4),D3
	TST.B	SCMag
	BEQ.S	SCR1
	LSR.W	#1,D2
	LSR.W	#1,D3
SCR1:	MOVE.W	4(A5),D4		; X of I and J.
	MOVE.W	4(A4),D5
	TST.B	SCM2
	BEQ.S	SCVis
	MOVE.L	12(A5),A6		; Mode 2: the line's colour bytes.
	MOVE.B	(A6,D2.W),D1
	AND.B	#$60,D1			; CC or IC
	BNE	SCLNx
	TST.B	(A6,D2.W)		; EC
	BPL.S	SCE1
	SUB.W	#32,D4
SCE1:	MOVE.L	12(A4),A6
	MOVE.B	(A6,D3.W),D1
	AND.B	#$60,D1
	BNE	SCLNx
	TST.B	(A6,D3.W)
	BPL.S	SCVis
	SUB.W	#32,D5
SCVis:	TST.B	SCCutOK			; Both shown on line D0 (among the
	BEQ	SCCutMk			; first SCLim there)?
SCCutBk:MOVE.B	(SCCut.L,D0.W),D1
	CMP.B	SCRk,D1
	BLS	SCLNx
	MOVE.L	8(A5),A6		; Row patterns, leftmost pixel in bit 31.
	SCPATT	D2,A6
	MOVE.L	8(A4),A6
	SCPATT	D3,A6
	SUB.W	D4,D5			; D5 = Xj - Xi.
	BMI.S	SCDNeg
	CMP.W	#32,D5
	BGE	SCLNx
	LSR.L	D5,D3
	AND.L	D3,D2			; Common pixels, column 0 at Xi.
	BRA.S	SCClip
SCDNeg:	NEG.W	D5
	CMP.W	#32,D5
	BGE	SCLNx
	LSR.L	D5,D2
	AND.L	D3,D2			; Column 0 at Xj.
	SUB.W	D5,D4
SCClip:	TST.L	D2
	BEQ.S	SCLNx
	TST.W	D4			; Left of the screen: not shown.
	BPL.S	SCClip2
	MOVE.W	D4,D5
	NEG.W	D5
	CMP.W	#32,D5
	BGE.S	SCLNx
	MOVEQ	#-1,D1
	LSR.L	D5,D1
	AND.L	D1,D2
SCClip2:MOVE.W	#256,D5			; Right of column 255: not shown.
	SUB.W	D4,D5
	CMP.W	#32,D5
	BGE.S	SCClip3
	MOVEQ	#-1,D1
	LSR.L	D5,D1
	NOT.L	D1
	AND.L	D1,D2
SCClip3:TST.L	D2
	BNE	SCHitY
SCLNx:	ADDQ.W	#1,D0
	CMP.W	SCHi,D0
	BLT	SCL
SCINx:	MOVE.W	(A4),D0			; Back to the sweep.
	MOVE.W	16(A4),D3
	MOVE.W	18(A4),D4
	BRA	SCIf

; SCCut[line] = number (in SCSpr) of the first sprite not shown on that line
; (every sprite counts, blank or not). Built once per check, when a pair
; first reaches the pixel test. Keeps D0, D2-D7, A4, A5.
SCCutMk:
	MOVEM.L	D0/D2-D3,SCCutSv
	LEA	SCCnt,A6
	MOVEQ	#(256/4)-1,D1
SCCutC:	CLR.L	(A6)+			; SCCnt: 0,
	DBF	D1,SCCutC
	MOVEQ	#(256/4)-1,D1		; SCCut: $FF.
SCCutF:	MOVE.L	#-1,(A6)+
	DBF	D1,SCCutF
	LEA	SCSpr,A6
	MOVEQ	#0,D3			; Sprite number.
SCCutS:	MOVE.W	(A6),D0			; Lines D0..D0+SCH-1, clipped.
	MOVE.W	SCH,D2
	SUBQ.W	#1,D2
SCCutL:	TST.W	D0
	BMI.S	SCCutN
	CMP.W	SCNL,D0
	BGE.S	SCCutX
	ADDQ.B	#1,(SCCnt.L,D0.W)
	MOVE.B	(SCCnt.L,D0.W),D1
	CMP.B	SCLim+1,D1
	BLS.S	SCCutN
	CMP.B	#$FF,(SCCut.L,D0.W)
	BNE.S	SCCutN
	MOVE.B	D3,(SCCut.L,D0.W)
SCCutN:	ADDQ.W	#1,D0
	DBF	D2,SCCutL
SCCutX:	ADD.W	#16,A6
	ADDQ.W	#1,D3
	CMP.W	SCN,D3
	BLT.S	SCCutS
	ST	SCCutOK
	MOVEM.L	SCCutSv,D0/D2-D3
	BRA	SCCutBk
SCHitY:	ST	SCHit
SCEnd:	MOVEM.L	SCSave,D0-D7/A0-A6
	IFD	SCDISCARD		; (Cost A/B: check, but report nothing.)
	SF	SCHit
	ENDC
	TST.B	SCHit
	BEQ	SCBack
	OR.B	#$20,D1
	BRA	SCBack

IVDP0Spr:
	MOVE.B	Estado(A3),D1
	MOVE.B	#$20,Estado(A3)		; Colisi�n de sprites ON.
	RTS

; -------------------------------------------------

IVDP1:
	SF	PetInt38(A3)

	MOVE.B	DVDPS1(A3),D1
	BCLR	#0,DVDPS1(A3)		; Interrupci�n Horizontal.
;	BCHG	#7,DVDPS1(A3)		; Lightpen.
;	BSET	#2,D1			; Activaci�n modo MSX2+
	RTS

; -------------------------------------------------

IVDP2:
	MOVE.B	DVDPS2(A3),D2
	OR.B	#$6C,D2		;  Timing X e Y Off. (no usados a 1)

	MOVE.W	CurLine(A3),D1		; Line * 256 + position (the whole line:
	LSL.L	#8,D1			; PAL lines 256-312 are VBlank too).
	MOVE.B	1(A3),D1

	CMP2.L	(Timming_Y.W,PC),D1
	BCS.S	NoTimming_Y
	BCLR	#6,D2			; Pone timing Y
NoTimming_Y:

	CMP2.B	(Timming_X.W,PC),D1
	BCS.S	NoTimming_X
	BCLR	#5,D2			; Pone timing X
NoTimming_X:

;d;	BCHG	#7,DVDPS2(A3)		; TR Realizada
	BFINS	D2,DVDPS2(A3){0:1}	; Copia 'Blt bit' en 'TR bit'

	BCHG	#4,DVDPS2(A3)		; Detectado color.
;;;	BCHG	#1,DVDPS2(A3)		; Muestra de campo.

	MOVEQ	#0,D1
	MOVE.B	D2,D1
	RTS

; -------------------------------------------------
IVDP2tr:
	MOVE.B	DVDPS2(A3),D2
	OR.B	#$EC,D2		; TR Realizada, Timing X e Y Off. (no usados a 1)

	MOVE.W	CurLine(A3),D1		; Line * 256 + position (the whole line:
	LSL.L	#8,D1			; PAL lines 256-312 are VBlank too).
	MOVE.B	1(A3),D1

	CMP2.L	(Timming_Y.W,PC),D1
	BCS.S	NoTimming_Ytr
	BCLR	#6,D2			; Pone timing Y
NoTimming_Ytr:

	CMP2.B	(Timming_X.W,PC),D1
	BCS.S	NoTimming_Xtr
	BCLR	#5,D2			; Pone timing X
NoTimming_Xtr:

	BCHG	#4,DVDPS2(A3)		; Detectado color.
;;;	BCHG	#1,DVDPS2(A3)		; Muestra de campo.

	MOVEQ	#0,D1
	MOVE.B	D2,D1
	RTS

	CNOP	0,8
Timming_Y:	DC.L	0,212*256
Timming_X:	DC.B	$2A,$FE

; -------------------------------------------------
; -------------------------------------------------

IVDP2060:
	MOVE.B	DVDPS2(A3),D2
	OR.B	#$6C,D2		;  Timing X e Y Off. (no usados a 1)

	MOVE.W	CurLine(A3),D1		; Line * 256 + position (the whole line:
	LSL.L	#8,D1			; PAL lines 256-312 are VBlank too).
	MOVE.B	1(A3),D1

	CMP.L	(Timming_Y+4.W,PC),D1
	BCC.S	NoTimming_Y060
	CMP.L	(Timming_Y.W,PC),D1
	BCS.S	NoTimming_Y060
	BCLR	#6,D2			; Pone timing Y
NoTimming_Y060:

	CMP.B	(Timming_X+1.W,PC),D1
	BCC.S	NoTimming_X060
	CMP.B	(Timming_X.W,PC),D1
	BCS.S	NoTimming_X060
	BCLR	#5,D2			; Pone timing X
NoTimming_X060:

;d;	BCHG	#7,DVDPS2(A3)		; TR Realizada
	BFINS	D2,DVDPS2(A3){0:1}	; Copia 'Blt bit' en 'TR bit'

	BCHG	#4,DVDPS2(A3)		; Detectado color.
;;;	BCHG	#1,DVDPS2(A3)		; Muestra de campo.

	MOVEQ	#0,D1
	MOVE.B	D2,D1
	RTS

; -------------------------------------------------
IVDP2tr060:
	MOVE.B	DVDPS2(A3),D2
	OR.B	#$EC,D2		; TR Realizada, Timing X e Y Off. (no usados a 1)

	MOVE.W	CurLine(A3),D1		; Line * 256 + position (the whole line:
	LSL.L	#8,D1			; PAL lines 256-312 are VBlank too).
	MOVE.B	1(A3),D1

	CMP.L	(Timming_Y+4.W,PC),D1
	BCC.S	NoTimming_Ytr060
	CMP.L	(Timming_Y.W,PC),D1
	BCS.S	NoTimming_Ytr060
	BCLR	#6,D2			; Pone timing Y
NoTimming_Ytr060:

	CMP.B	(Timming_X+1.W,PC),D1
	BCC.S	NoTimming_Xtr060
	CMP.B	(Timming_X.W,PC),D1
	BCS.S	NoTimming_Xtr060
	BCLR	#5,D2			; Pone timing X
NoTimming_Xtr060:

	BCHG	#4,DVDPS2(A3)		; Detectado color.
;;;	BCHG	#1,DVDPS2(A3)		; Muestra de campo.

	MOVEQ	#0,D1
	MOVE.B	D2,D1
	RTS

; -------------------------------------------------
; -------------------------------------------------

IVDPN:
	NOT.B	POPIN
	MOVE.B	POPIN,D1

	RTS
	CNOP	0,8
POPIN:	DC.W	0

; -------------------------------------------------

IVDP3:
	MOVE.W	$DFF00A,D1
	RTS

; -------------------------------------------------

IVDP5:
	MOVE.W	$DFF00A,D1
	LSR.W	#8,D1
	RTS

; -------------------------------------------------

IVDP7:
	BTST	#0,DVDPS2(A3)		; �Ejecuci�n terminada?
	BNE.S	IVDP7Con
	MOVE.B	COLREAD(A3),D1
	RTS
	CNOP	0,8
IVDP7Con:
	MOVEM.L	D0-D7/A0-A6,BUFER(A3)
	MOVE.L	(SP)+,PilaIVDP7

	MOVE.L	MODOPantV7(PC),A4

	MOVE.W	DVDPSY2(A3),D1
	MULU	$2A(A4),D1
	MOVEQ	#0,D0
	MOVE.W	DVDPSX2(A3),D0
	MOVE.W	D0,D4
	MOVE.W	$28(A4),D2
	LSR.W	D2,D0
	ADD.L	D0,D1

	NOT.W	D4
	AND.W	$28(A4),D4
	MULU	$20(A4),D4

	MOVE.B	$22(A4),D3
	JSR	([$24.W,A4])
	LSR.B	D4,D1
	AND.B	D3,D1
	MOVE.B	D1,COLREAD(A3)


	MOVEQ	#1,D0
	BTST	#2,DVDPARG(A3)
	BEQ.S	vLMCMDESX
	MOVEQ	#-1,D0
vLMCMDESX:
	ADD.W	D0,DVDPSX2(A3)


	SUBQ.W	#1,CONTA2CX(A3)
	BNE.S	vLMCMCON0

	MOVE.W	DVDPSX(A3),DVDPSX2(A3)
	MOVE.W	DVDPNX(A3),CONTA2CX(A3)


	MOVEQ	#1,D0
	BTST	#3,DVDPARG(A3)
	BEQ.S	vLMCMDESY
	MOVEQ	#-1,D0
vLMCMDESY:
	ADD.W	D0,DVDPSY2(A3)

	SUBQ.W	#1,CONTA2C(A3)
	BNE.S	vLMCMCON0
	BCLR	#0,DVDPS2(A3)		; Ejecuci�n terminada.
vLMCMCON0:


	MOVE.L	PilaIVDP7(PC),-(SP)
	MOVEM.L	BUFER(A3),D0-D7/A0-A6
	MOVE.B	COLREAD(A3),D1
	RTS

PilaIVDP7:	DC.L	0
MODOPantV7:	DC.L	MODO5DATS

; ---------------------------------------------------------
; -------------------------------------------------
; -------------------------------------------------


;	 ----------------------------
;	- Emulaci�n de Screens 0,1,2 -
;	 ----------------------------

	CNOP	0,8
PRINT0:
	MOVE.L	#COPPER0,NEXTCOPP
	MOVE.W	([COL00.W,PC]),COLOR0+2	; Color del Borde.
	MOVE.W	([COL01.W,PC]),COLOR0+6	; Color del Lapiz.
	TST.B	ACTODO(A3)
	BNE	ACTUALIZA0
	BSR	PREPARATXT0	; Actualiza Gfx De caracteres ya impresos.
	BSR	COPIATXT0	; Actualiza Pantalla.
	RTS

	CNOP	0,8
PRINT9:
	MOVE.L	#COPPER9,NEXTCOPP
	MOVE.W	([COL00.W,PC]),COLOR9+2	 ; Color del Borde.
	MOVE.W	([COL01.W,PC]),COLOR9+6	 ; Color del Lapiz.
	MOVE.W	([COL02.W,PC]),COLOR9+14 ; Color del Lapiz 2.
	MOVE.W	([COL03.W,PC]),COLOR9+10 ; Color del Lapiz 3.
	BSR	MIRAFLASH
	TST.B	ACTODO(A3)
	BNE	ACTUALIZA9
	BSR	PREPARATXT9	; Actualiza Gfx De caracteres ya impresos.
	BSR	COPIATXT9	; Actualiza Pantalla.
	RTS

*****************************************************

	CNOP	0,8
PRINT1:
	MOVEQ	#0,D1
	MOVE.B	MCAGA+10,D1
	LSL.W	#1,D1
	ADD.W	#$180,D1
	MOVE.W	D1,COLOR2
	MOVE.W	D1,COLOR2B
	MOVE.W	([COL00.W,PC]),COLOR2+2	 ; Color del Borde.
	MOVE.W	([COL00.W,PC]),COLOR2B+2 ; Color del Borde.
	BSR	TRANSSPR	; Actualiza Gfx Sprites.
	BSR	IMPSPR		; Actualiza Coor. Sprites
	BSR	MIRACOLOR	; Actualiza Color de caracteres ya impresos.
	TST.B	ACTODO(A3)
	BNE.S	ACTUTODO1
	BSR	PREPARATXT1	; Actualiza Gfx De caracteres ya impresos.
	BSR	TRANSBLT1	; Actualiza Gfx y colores de Caracteres.
	BSR	COPIATXT1	; Actualiza Pantalla.
	BSR	BorraSprTab	; Borra Tabla de actualizaci�n de Sprites.
	RTS

	CNOP	0,8
ACTUTODO1:
	BSR	TRANSBLT1	; Actualiza Gfx y colores de Caracteres.
	BSR	ACTUALIZA1	; Actualiza pantalla al 100%
	BSR	BorraSprTab	; Borra Tabla de actualizaci�n de Sprites.
	RTS

************************************************************

	CNOP	0,8
PRINT2:
	IFD	TRACE
	ADDQ.L	#1,TraceHdr+48		; Debug: SCREEN 2 redraws.
	ENDC
	MOVEQ	#0,D1
	MOVE.B	MCAGA+10,D1
	LSL.W	#1,D1
	ADD.W	#$180,D1
	MOVE.W	D1,COLOR2
	MOVE.W	D1,COLOR2B
	MOVE.W	([COL00.W,PC]),COLOR2+2	 ; Color del Borde.
	MOVE.W	([COL00.W,PC]),COLOR2B+2 ; Color del Borde.


	MOVE.W	#($800*4*2),SumaBpl	; Truco de UN SOLO Banco
	MOVE.W	#($100),SumaVRAM
; (Shared pattern/colour blocks: see TBloque.)
NoEsTruco:


	BSR	TRANSSPR	; Actualiza Gfx Sprites.
	BSR	IMPSPR		; Actualiza Coor. Sprites
	JSR	RendTabCheck
	TST.B	ACTODOB(A3)
	BNE	ACTUTODO2
	BSR	COPIATXT	; Actualiza Pantalla.
	BSR	PREPARATXT	; Actualiza Gfx De caracteres ya impresos.
	BSR	TRANSBLT	; Actualiza Gfx y colores de Caracteres.
	BSR	BorraSprTab	; Borra Tabla de actualizaci�n de Sprites.
	JMP	Planos2			; (The bank's screen: SCREEN 2 only.)

	CNOP	0,8
ACTUTODO2:
	IFD	TRACE
	ADDQ.L	#1,TraceHdr+52		; Debug: full SCREEN 2 redraws.
	ENDC
	BSR	TRANSBLT	; Actualiza Gfx y colores de Caracteres.
	BSR	ACTUALIZA	; Actualiza pantalla al 100%
	BSR	BorraSprTab	; Borra Tabla de actualizaci�n de Sprites.
	JMP	Planos2

************************************************************

	CNOP	0,8
PRINT3:
	MOVEQ	#0,D1
	MOVE.B	MCAGA+10,D1
	LSL.W	#1,D1
	ADD.W	#$180,D1
	MOVE.W	D1,COLOR2
	MOVE.W	D1,COLOR2B
	MOVE.W	([COL00.W,PC]),COLOR2+2	 ; Color del Borde.
	MOVE.W	([COL00.W,PC]),COLOR2B+2 ; Color del Borde.
	BSR	TRANSSPR	; Actualiza Gfx Sprites.
	BSR	IMPSPR		; Actualiza Coor. Sprites

	TST.B	ACTODO(A3)
	BNE.S	ActuTodo3

	BSR	PreparaTxt3	; Actualiza Gfx De caracteres ya impresos.
	BSR	CopiaTexto3	; Actualiza Pantalla.
	BSR	BorraSprTab	; Borra Tabla de actualizaci�n de Sprites.
	RTS

	CNOP	0,8
ActuTodo3:
	BSR	Actualiza3	; Actualiza Pantalla al 100%.
	BSR	BorraSprTab	; Borra Tabla de actualizaci�n de Sprites.
	RTS

************************************************************

	CNOP	0,8
PRINT4:
	MOVE.L	#COPPER4,NEXTCOPP

; -=-=-
	BSR	Act_Adjust
; -=-=-
	MOVEQ	#0,D1
	MOVE.B	MCAGA+10,D1
	LSL.W	#1,D1
	ADD.W	#$180,D1
	MOVE.W	D1,COLOR4
	MOVE.W	([COL00.W,PC]),COLOR4+2	 ; Color del Borde.
; -=-=-
	MOVEQ	#0,D0			; Pone Bit-Panos en copper.
	MOVE.B	VDPLinY(A3),D0

	MOVE.B	#255,D1
	SUB.B	D0,D1
	ADD.B	#IniPant+1,D1
	BCC.S	NoDesbPla4
	MOVEQ	#-1,D1
NoDesbPla4:
	SUBQ.B	#1,D1
	MOVE.B	D1,Plano4b-4


	MULU	#(32*4),D0
	ADD.L	#SCREEN,D0
	LEA	PLANO4+2,A0
	MOVEQ	#(32),D1

	MOVE.W	D0,4(A0)
	SWAP	D0
	MOVE.W	D0,(A0)
	SWAP	D0
	ADD.L	D1,D0
	MOVE.W	D0,12(A0)
	SWAP	D0
	MOVE.W	D0,8(A0)
	SWAP	D0
	ADD.L	D1,D0
	MOVE.W	D0,20(A0)
	SWAP	D0
	MOVE.W	D0,16(A0)
	SWAP	D0
	ADD.L	D1,D0
	MOVE.W	D0,28(A0)
	SWAP	D0
	MOVE.W	D0,24(A0)
; -=-=-

	MOVE.W	#($800*4*2),SumaBpl	; Truco de UN SOLO Banco
	MOVE.W	#($100),SumaVRAM
; (Shared pattern/colour blocks: see TBloque.)
NoEsTruco2:
	PERFMARK

	LEA	REGS(PC),A3
	JSR	RendTabCheck
	TST.B	ACTODOB(A3)
	BNE	ACTUTODO4
	TST.B	BankSw			; Other cache bank: copy the screen.
	BNE	ACTUTODO4


	LEA	DIRVRAM,A0
	ADD.L	PVDP2(A3),A0		; Tabla de texto.
	MOVEQ	#(4)-1,D7
	BSR	COPIATXT4	; Actualiza Pantalla.

	MOVE.W	#((32*8*4)/4)-1,D0
	MOVE.W	#(4)-1,D3
	BSR	PREPARATXT4	; Actualiza Gfx De caracteres ya impresos.
	MOVE.W	#((32*8*4)/4)-1,D0
	BSR	TRANSBLT4	; Actualiza Gfx y colores de Caracteres.

	PERFSUB	5			; 5: SCREEN 4 tiles (partial)
	BRA	SPRMODE6		; (No BSR: one call level here.)
; -=-=-
	CNOP	0,8
ACTUTODO4:
	MOVE.W	#((32*8*4)/4)-1,D0
	BSR	TRANSBLT4	; Actualiza Gfx y colores de Caracteres.
	LEA	REGS(PC),A3
	LEA	DIRVRAM,A0
	ADD.L	PVDP2(A3),A0		; Tabla de texto.
	MOVEQ	#(4)-1,D6
	BSR	ACTUALIZA4	; Actualiza pantalla al 100%

	PERFSUB	6			; 6: SCREEN 4 full redraw
	BRA	SPRMODE6
	RTS

************************************************************

	CNOP	0,8
TRANSSPR:
	LEA	REGS(PC),A3
	MOVE.B	DATOSPR,D0
	AND.B	#$02,D0
	MOVE.B	DVDP1(A3),D1
	AND.B	#$02,D1
	CMP.B	D1,D0
	BEQ.S	NOCAMS
	ST	ACTSPR(A3)
NOCAMS:	MOVE.B	D1,DATOSPR
	MOVE.L	PVDP6(A3),D0		; Pattern table not the one converted
	CMP.L	SprLastP6,D0		; last: full conversion. Decided here,
	BEQ.S	SprP6Same		; not on each R#6 write: Uridium switches
	MOVE.L	D0,SprLastP6		; R#6 for its HUD and back every frame.
	ST	ACTSPR(A3)
SprP6Same:
	TST.B	D1		; Mira si es imprimir spr de 8*8 o 16*16
	BEQ	TRANSSPR8
	JMP	TRANSSPR16S		; (+ split slots, at the end)

;  --------------------------------------------------------------------
; <********************************************************************>
;  --------------------------------------------------------------------

	CNOP	0,8
; ----------------------------->  Actualiza Gfx de caracteres en pantalla.
PREPARATXT0:
	LEA	REGS(PC),A3
	LEA	TAB98(PC),A5
	MOVE.L	PVDP4(A3),D0		; Tabla Gfx Caracteres VRAM
	LSR.L	#3,D0
	ADD.W	D0,A5

	MOVE.L	A5,A0
	MOVE.L	A5,A1
	ADD.W	#(32*8),A1
	MOVE.W	#(((32*8)/4)/2)-1,D0
PREBUC00:
	TST.L	(A0)+
	BNE.S	PREPRUT0
	TST.L	-(A1)
	DBNE	D0,PREBUC00
	TST.W	D0
	BPL.S	PREPRUT0
	RTS
	CNOP	0,8
PREPRUT0:
	LEA	DIRVRAM,A0
	ADD.L	PVDP2(A3),A0		; Tabla de texto.
	LEA	TXT2(PC),A1
	MOVEQ	#0,D1
	MOVE.W	#((40*24)/4)-1,D0
PREPBUC0:
	MOVE.L	(A0)+,D2

	MOVE.B	D2,D1
	TST.B	(A5,D1.W)
	BEQ.S	PONULO00
	NOT.B	D1
	MOVE.B	D1,3(A1)
PONULO00:LSR.W	#8,D2
	TST.B	(A5,D2.W)
	BEQ.S	PONULO10
	NOT.B	D2
	MOVE.B	D2,2(A1)
PONULO10:SWAP	D2
	MOVE.B	D2,D1
	TST.B	(A5,D1.W)
	BEQ.S	PONULO20
	NOT.B	D1
	MOVE.B	D1,1(A1)
PONULO20:LSR.W	#8,D2
	TST.B	(A5,D2.W)
	BEQ.S	PONULO30
	NOT.B	D2
	MOVE.B	D2,(A1)
PONULO30:ADDQ.W	#4,A1
	DBF	D0,PREPBUC0

	LEA	TAB98(PC),A6
	MOVE.L	PVDP4(A3),D0		; Tabla Gfx Caracteres VRAM
	LSR.L	#3,D0
	ADD.W	#256,D0
	ADD.W	D0,A6

	MOVEM.L	CEROSR(PC),D0-D7/A0-A5
	MOVEM.L	D0-D7/A0-A5,-(A6)
	MOVEM.L	D0-D7/A0-A5,-(A6)
	MOVEM.L	D0-D7/A0-A5,-(A6)
	MOVEM.L	D0-D7/A0-A5,-(A6)
	MOVEM.L	D0-D7,-(A6)
	RTS

	CNOP	0,8
CEROSR:	DS.L	20
; -----------------------------<

	CNOP	0,8
; ----------------------------->  Imprime  Gfx de caracteres en pantalla.
ACTUALIZA0:
	LEA	REGS(PC),A3

	SF	ACTODO(A3)

	LEA	DIRVRAM,A1
	MOVE.L	A1,A0
	ADD.L	PVDP2(A3),A0		; Tabla de caracteres.
	ADD.L	PVDP4(A3),A1		; Tabla Gfx Caracteres VRAM

	LEA	SCREEN,A2			; Pantalla Destino Amiga.
	LEA	TXT2(PC),A4		; Tabla de texto actual en planos.
	MOVEQ	#0,D1
	MOVE.W	#(40*24)-1,D0
BUC0B:
	MOVE.B	(A0)+,D1
	MOVE.B	D1,(A4)+
	MOVEM.L	(A1,D1.W*8),D2-D3
	MOVE.B	D2,(40*24*3)(A2)
	LSR.W	#8,D2
	MOVE.B	D2,(40*24*2)(A2)
	SWAP.W	D2
	MOVE.B	D2,(40*24*1)(A2)
	LSR.W	#8,D2
	MOVE.B	D2,(A2)+
	MOVE.B	D3,(40*24*7)-1(A2)
	LSR.W	#8,D3
	MOVE.B	D3,(40*24*6)-1(A2)
	SWAP	D3
	MOVE.B	D3,(40*24*5)-1(A2)
	LSR.W	#8,D3
	MOVE.B	D3,(40*24*4)-1(A2)
	DBF	D0,BUC0B

	LEA	TAB98(PC),A6
	MOVE.L	PVDP4(A3),D0		; Tabla Gfx Caracteres VRAM
	LSR.L	#3,D0
	ADD.W	#256,D0
	ADD.W	D0,A6

	MOVEM.L	CEROSR(PC),D0-D7/A0-A5
	MOVEM.L	D0-D7/A0-A5,-(A6)
	MOVEM.L	D0-D7/A0-A5,-(A6)
	MOVEM.L	D0-D7/A0-A5,-(A6)
	MOVEM.L	D0-D7/A0-A5,-(A6)
	MOVEM.L	D0-D7,-(A6)
	RTS
; -----------------------------<

	CNOP	0,8
; ----------------------------->  Imprime caracteres en pantalla.
COPIATXT0:
	LEA	REGS(PC),A3
	LEA	DIRVRAM,A1
	MOVE.L	A1,A0
	ADD.L	PVDP2(A3),A0		; Tabla de caracteres.
	ADD.L	PVDP4(A3),A1		; Tabla Gfx Caracteres VRAM

	LEA	SCREEN,A2			; Pantalla Destino Amiga.
	LEA	TXT2(PC),A3		; Tabla de texto actual en planos.
	MOVE.W	#((40*24)/4)-1,D0
	MOVEQ	#0,D1
	BRA.S	BUC0

	CNOP	0,8
BUC0:
	CMP.L	(A0)+,(A3)+
	BNE.S	COPIA0R0
	ADDQ.W	#4,A2
	DBF	D0,BUC0
	RTS

	CNOP	0,8
COPIA0R0:
	MOVE.L	-4(A0),D4
	MOVE.L	-4(A3),D5

	ADDQ.W	#3,A2

	MOVE.B	D4,D1
	CMP.B	D5,D1
	BEQ.S	COPIA0R1
	MOVE.B	D1,-1(A3)
	BSR.S	COPIA0
COPIA0R1:
	SUBQ.W	#1,A2
	LSR.W	#8,D4
	LSR.W	#8,D5
	MOVE.B	D4,D1
	CMP.B	D5,D1
	BEQ.S	COPIA0R2
	MOVE.B	D1,-2(A3)
	BSR.S	COPIA0
COPIA0R2:
	SUBQ.W	#1,A2
	SWAP	D4
	SWAP	D5
	MOVE.B	D4,D1
	CMP.B	D5,D1
	BEQ.S	COPIA0R3
	MOVE.B	D1,-3(A3)
	BSR.S	COPIA0
COPIA0R3:
	SUBQ.W	#1,A2
	LSR.W	#8,D4
	LSR.W	#8,D5
	MOVE.B	D4,D1
	CMP.B	D5,D1
	BEQ.S	COPIA0R4
	MOVE.B	D1,-4(A3)
	BSR.S	COPIA0
COPIA0R4:
	ADDQ.W	#4,A2
	DBF	D0,BUC0
	RTS

	CNOP	0,8
COPIA0:
	MOVEM.L	(A1,D1.W*8),D2-D3

	MOVE.B	D2,(40*24*3)(A2)
	LSR.W	#8,D2
	MOVE.B	D2,(40*24*2)(A2)
	SWAP.W	D2
	MOVE.B	D2,(40*24*1)(A2)
	LSR.W	#8,D2
	MOVE.B	D2,(A2)

	MOVE.B	D3,(40*24*7)(A2)
	LSR.W	#8,D3
	MOVE.B	D3,(40*24*6)(A2)
	SWAP	D3
	MOVE.B	D3,(40*24*5)(A2)
	LSR.W	#8,D3
	MOVE.B	D3,(40*24*4)(A2)
	RTS
; -----------------------------<

	CNOP	0,8
; ----------------------------->  Actualiza Gfx de caracteres en pantalla.
MIRAFLASH:
	SUBQ.B	#1,FLASH(A3)
	BPL.S	MIRET
	SF	FLASH(A3)
	BTST	#4,NBIT9+6
	BNE.S	MODO4COL
MODO2COL:
	MOVE.B	FLASH+1(A3),D1
	BEQ.S	DOSCOL
	AND.B	#$0F,D1
	LSL.B	#3,D1
	MOVE.B	D1,FLASH(A3)
	BEQ.S	MODO4COL
DOSCOL:	MOVE.B	#$92,NBIT9+6
MIRET:	RTS
	CNOP	0,8
MODO4COL:
	MOVE.B	FLASH+1(A3),D1
	LSR.B	#4,D1
	LSL.B	#3,D1
	MOVE.B	D1,FLASH(A3)
	BEQ.S	MODO2COL
	MOVE.B	#$A2,NBIT9+6
	RTS
	CNOP	0,8
; -----------------------------<

	CNOP	0,8
; ----------------------------->  Actualiza Gfx de caracteres en pantalla.
PREPARATXT9:
	LEA	REGS(PC),A3
	LEA	TAB98(PC),A5
	MOVE.L	PVDP4(A3),D0		; Tabla Gfx Caracteres VRAM
	LSR.L	#3,D0
	ADD.W	D0,A5

	MOVE.L	A5,A0
	MOVE.L	A5,A1
	ADD.W	#(32*8),A1
	MOVE.W	#(((32*8)/4)/2)-1,D0
PREBUC09:
	TST.L	(A0)+
	BNE.S	PREPRUT9
	TST.L	-(A1)
	DBNE	D0,PREBUC09
	TST.W	D0
	BPL.S	PREPRUT9
	RTS
	CNOP	0,8
PREPRUT9:
	LEA	DIRVRAM,A0
	ADD.L	PVDP2(A3),A0		; Tabla de texto.
	MOVE.B	DVDP2(A3),D1
	AND.W	#$0003,D1
	MULU	#$400,D1
	SUB.W	D1,A0
	LEA	TXT2(PC),A1
	MOVEQ	#0,D1
	MOVE.W	#((80*27)/4)-1,D0
PREPBUC9:
	MOVE.L	(A0)+,D2

	MOVE.B	D2,D1

	TST.B	(A5,D1.W)
	BEQ.S	PONULO09
	NOT.B	D1
	MOVE.B	D1,3(A1)
PONULO09:LSR.W	#8,D2
	TST.B	(A5,D2.W)
	BEQ.S	PONULO19
	NOT.B	D2
	MOVE.B	D2,2(A1)
PONULO19:SWAP	D2
	MOVE.B	D2,D1
	TST.B	(A5,D1.W)
	BEQ.S	PONULO29
	NOT.B	D1
	MOVE.B	D1,1(A1)
PONULO29:LSR.W	#8,D2
	TST.B	(A5,D2.W)
	BEQ.S	PONULO39
	NOT.B	D2
	MOVE.B	D2,(A1)
PONULO39:ADDQ.W	#4,A1
	DBF	D0,PREPBUC9

	LEA	TAB98(PC),A6
	MOVE.L	PVDP4(A3),D0		; Tabla Gfx Caracteres VRAM
	LSR.L	#3,D0
	ADD.W	#256,D0
	ADD.W	D0,A6

	MOVEM.L	CEROSR9(PC),D0-D7/A0-A5
	MOVEM.L	D0-D7/A0-A5,-(A6)
	MOVEM.L	D0-D7/A0-A5,-(A6)
	MOVEM.L	D0-D7/A0-A5,-(A6)
	MOVEM.L	D0-D7/A0-A5,-(A6)
	MOVEM.L	D0-D7,-(A6)
	RTS

	CNOP	0,8
CEROSR9:DS.L	20
; -----------------------------<

	CNOP	0,8
; ----------------------------->  Imprime  Gfx de caracteres en pantalla.
ACTUALIZA9:
	LEA	REGS(PC),A3

	SF	ACTODO(A3)

	LEA	DIRVRAM,A1
	MOVE.L	A1,A0
	ADD.L	PVDP2(A3),A0		; Tabla de caracteres.
	MOVE.B	DVDP2(A3),D1
	AND.W	#$0003,D1
	MULU	#$400,D1
	SUB.W	D1,A0
	ADD.L	PVDP4(A3),A1		; Tabla Gfx Caracteres VRAM

	LEA	SCREEN,A2			; Pantalla Destino Amiga.
	LEA	TXT2(PC),A4		; Tabla de texto actual en planos.
	MOVEQ	#0,D1
	MOVE.W	#(80*27)-1,D0
BUC9B:
	MOVE.B	(A0)+,D1
	MOVE.B	D1,(A4)+
	MOVEM.L	(A1,D1.W*8),D2-D3
	MOVE.B	D2,(80*27*3)(A2)
	LSR.W	#8,D2
	MOVE.B	D2,(80*27*2)(A2)
	SWAP.W	D2
	MOVE.B	D2,(80*27*1)(A2)
	LSR.W	#8,D2
	MOVE.B	D2,(A2)+
	MOVE.B	D3,(80*27*7)-1(A2)
	LSR.W	#8,D3
	MOVE.B	D3,(80*27*6)-1(A2)
	SWAP	D3
	MOVE.B	D3,(80*27*5)-1(A2)
	LSR.W	#8,D3
	MOVE.B	D3,(80*27*4)-1(A2)
	DBF	D0,BUC9B


	LEA	DIRVRAM,A0
	ADD.L	PVDP3(A3),A0		; Tabla de caracteres.
	MOVE.W	DVDP3(A3),D1
	AND.W	#$0007,D1
	MULU	#$40,D1
	SUB.W	D1,A0
	LEA	SCREEN+(80*27*8),A2	; Pantalla Destino Amiga.
	LEA	TABCOL9(PC),A1
	MOVE.W	#(68)-1,D0
BUC9YA:
	MOVE.L	(A0)+,D2
	MOVE.L	D2,(A1)+
	REPT	32
	ADD.L	D2,D2
	SCS	(A2)+
	ENDR
	DBF	D0,BUC9YA


	LEA	TAB98(PC),A6
	MOVE.L	PVDP4(A3),D0		; Tabla Gfx Caracteres VRAM
	LSR.L	#3,D0
	ADD.W	#256,D0
	ADD.W	D0,A6

	MOVEM.L	CEROSR9(PC),D0-D7/A0-A5
	MOVEM.L	D0-D7/A0-A5,-(A6)
	MOVEM.L	D0-D7/A0-A5,-(A6)
	MOVEM.L	D0-D7/A0-A5,-(A6)
	MOVEM.L	D0-D7/A0-A5,-(A6)
	MOVEM.L	D0-D7,-(A6)
	RTS

	CNOP	0,8
TABCOL9:DS.B	300
; -----------------------------<

	CNOP	0,8
; ----------------------------->  Imprime caracteres en pantalla.
COPIATXT9:
	LEA	REGS(PC),A3
	LEA	DIRVRAM,A0
	ADD.L	PVDP3(A3),A0		; Tabla de caracteres.
	MOVE.W	DVDP3(A3),D1
	AND.W	#$0007,D1
	MULU	#$40,D1
	SUB.W	D1,A0
	LEA	SCREEN+(80*27*8),A2	; Pantalla Destino Amiga.
	LEA	TABCOL9(PC),A1
	MOVE.W	#32,D1
	MOVE.W	#(68)-1,D0
BUC9YS:
	CMP.L	(A0)+,(A1)+
	BNE.S	CAMBI9
	ADD.W	D1,A2
	DBF	D0,BUC9YS
	BRA	NOCAMBI9
	CNOP	0,8
CAMBI9:
	MOVE.L	-4(A0),D2
	MOVE.L	D2,-4(A1)
	REPT	32
	ADD.L	D2,D2
	SCS	(A2)+
	ENDR
	DBF	D0,BUC9YS
NOCAMBI9:

	LEA	DIRVRAM,A1
	MOVE.L	A1,A0
	ADD.L	PVDP2(A3),A0		; Tabla de caracteres.
	MOVE.B	DVDP2(A3),D1
	AND.W	#$0003,D1
	MULU	#$400,D1
	SUB.W	D1,A0
	ADD.L	PVDP4(A3),A1		; Tabla Gfx Caracteres VRAM

	LEA	SCREEN,A2			; Pantalla Destino Amiga.
	LEA	TXT2(PC),A3		; Tabla de texto actual en planos.
	MOVE.W	#((80*27)/4)-1,D0
	MOVEQ	#0,D1
	BRA.S	BUC9

	CNOP	0,8
BUC9:
	CMP.L	(A0)+,(A3)+
	BNE.S	COPIA9R0
	ADDQ.W	#4,A2
	DBF	D0,BUC9
	RTS

	CNOP	0,8
COPIA9R0:
	MOVE.L	-4(A0),D4
	MOVE.L	-4(A3),D5

	ADDQ.W	#3,A2

	MOVE.B	D4,D1
	CMP.B	D5,D1
	BEQ.S	COPIA9R1
	MOVE.B	D1,-1(A3)
	BSR.S	COPIA9
COPIA9R1:
	SUBQ.W	#1,A2
	LSR.W	#8,D4
	LSR.W	#8,D5
	MOVE.B	D4,D1
	CMP.B	D5,D1
	BEQ.S	COPIA9R2
	MOVE.B	D1,-2(A3)
	BSR.S	COPIA9
COPIA9R2:
	SUBQ.W	#1,A2
	SWAP	D4
	SWAP	D5
	MOVE.B	D4,D1
	CMP.B	D5,D1
	BEQ.S	COPIA9R3
	MOVE.B	D1,-3(A3)
	BSR.S	COPIA9
COPIA9R3:
	SUBQ.W	#1,A2
	LSR.W	#8,D4
	LSR.W	#8,D5
	MOVE.B	D4,D1
	CMP.B	D5,D1
	BEQ.S	COPIA9R4
	MOVE.B	D1,-4(A3)
	BSR.S	COPIA9
COPIA9R4:
	ADDQ.W	#4,A2
	DBF	D0,BUC9
	RTS

	CNOP	0,8
COPIA9:
	MOVEM.L	(A1,D1.W*8),D2-D3

	MOVE.B	D2,(80*27*3)(A2)
	LSR.W	#8,D2
	MOVE.B	D2,(80*27*2)(A2)
	SWAP.W	D2
	MOVE.B	D2,(80*27*1)(A2)
	LSR.W	#8,D2
	MOVE.B	D2,(A2)

	MOVE.B	D3,(80*27*7)(A2)
	LSR.W	#8,D3
	MOVE.B	D3,(80*27*6)(A2)
	SWAP	D3
	MOVE.B	D3,(80*27*5)(A2)
	LSR.W	#8,D3
	MOVE.B	D3,(80*27*4)(A2)
	RTS
; -----------------------------<

	CNOP	0,8
; ----------------------------->  Actualiza Gfx de caracteres en pantalla.
PREPARATXT1:
PreparaTxt3:
	LEA	REGS(PC),A3
	LEA	TAB98(PC),A5
	MOVE.L	PVDP4(A3),D0		; Tabla Gfx Caracteres VRAM
	LSR.L	#3,D0
	ADD.W	D0,A5

	MOVE.L	A5,A0
	MOVE.L	A5,A1
	ADD.W	#(32*8),A1
	MOVE.W	#(((32*8)/4)/2)-1,D0
PREBUC01:
	TST.L	(A0)+
	BNE.S	PREPRUT1
	TST.L	-(A1)
	DBNE	D0,PREBUC01
	TST.W	D0
	BPL.S	PREPRUT1
	RTS
	CNOP	0,8
PREPRUT1:
	LEA	DIRVRAM,A0
	ADD.L	PVDP2(A3),A0		; Tabla de texto.
	LEA	TXT2(PC),A1
	MOVEQ	#0,D1
	MOVE.W	#((32*24)/4)-1,D0
PREPBUC1:
	MOVE.L	(A0)+,D2

	MOVE.B	D2,D1
	TST.B	(A5,D1.W)
	BEQ.S	PONULO01
	NOT.B	D1
	MOVE.B	D1,3(A1)
PONULO01:LSR.W	#8,D2
	TST.B	(A5,D2.W)
	BEQ.S	PONULO11
	NOT.B	D2
	MOVE.B	D2,2(A1)
PONULO11:SWAP	D2
	MOVE.B	D2,D1
	TST.B	(A5,D1.W)
	BEQ.S	PONULO21
	NOT.B	D1
	MOVE.B	D1,1(A1)
PONULO21:LSR.W	#8,D2
	TST.B	(A5,D2.W)
	BEQ.S	PONULO31
	NOT.B	D2
	MOVE.B	D2,(A1)
PONULO31:ADDQ.W	#4,A1
	DBF	D0,PREPBUC1
	RTS
; -----------------------------<

	CNOP	0,8
; ----------------------------->  Actualiza color de caracteres ya impresos.
MIRACOLOR:
	LEA	REGS(PC),A3
	LEA	DIRVRAM,A0
	ADD.L	PVDP3(A3),A0		; Tabla Colores Caracteres VRAM
	LEA	TAB98(PC),A2
	MOVE.L	PVDP4(A3),D0		; Tabla Gfx Caracteres VRAM
	LSR.L	#3,D0
	ADD.W	D0,A2
	LEA	COLSCR1,A1
	MOVEQ	#-1,D1
	MOVEQ	#-1,D2
	MOVEQ	#32-1,D0
COLIBUC1:
	CMP.B	(A0)+,(A1)+
	BEQ.S	COLORIGUAL
	MOVEM.L	D1-D2,(A2)
COLORIGUAL:
	ADDQ	#8,A2
	DBF	D0,COLIBUC1
	RTS
; -----------------------------<

	CNOP	0,8
; ----------------------------->  Transforma Vram MSX a GfxBlt Amiga.
TRASF1:	MACRO
	MOVE.W	(A0),D1
	MOVE.B	D7,D1
	MOVE.L	(A1,D1.L*4),D2
	ADDQ	#1,A0
	MOVEP.L	D2,\1(A2)
	ENDM
TRANSBLT1:
	LEA	REGS(PC),A3
	LEA	DIRVRAM,A0
	MOVE.L	A0,A4
	ADD.L	PVDP4(A3),A0		; Tabla Gfx Caracteres VRAM
	ADD.L	PVDP3(A3),A4		; Tabla Colores Caracteres VRAM

	LEA	TABLA7E,A1
	LEA	GFXCA,A2
	MOVE.W	#$40,D3
	MOVEQ	#0,D1

	TST.B	Modo060(A3)		; Mira si es un 060.
	BNE	TRANSBLT1060

	TST.B	ACTODO(A3)
	BNE	TRANSCHEC1

	LEA	TAB98(PC),A5
	MOVE.L	PVDP4(A3),D0		; Tabla Gfx Caracteres VRAM
	LSR.L	#3,D0
	ADD.W	D0,A5
	LEA	COLSCR1(PC),A6
	MOVE.W	#($40*4),D5
	MOVE.W	#(4*8),D6
	MOVEQ	#(32)-1,D4
TRASFBUC31:
	MOVE.B	(A4)+,D7
	MOVEQ	#((8)/4)-1,D0
	CMP.B	(A6)+,D7
	BNE	OTROCOL1	
TRASFBUC21:
	TST.L	(A5)+
	BNE.S	TRANSCHECK1
	ADD.W	D6,A0
	ADD.W	D5,A2
	DBF	D0,TRASFBUC21
	DBF	D4,TRASFBUC31
	RTS
	CNOP	0,8
TRANSCHECK1:
	TST.B	-4(A5)
	BEQ.S	NOCOP01
	BSR.S	TRANSCOPY1
NOCOP01:ADD.W	D3,A2
	ADDQ.W	#8,A0
	TST.B	-3(A5)
	BEQ.S	NOCOP11
	BSR.S	TRANSCOPY1
NOCOP11:ADD.W	D3,A2
	ADDQ.W	#8,A0
	TST.B	-2(A5)
	BEQ.S	NOCOP21
	BSR.S	TRANSCOPY1
NOCOP21:ADD.W	D3,A2
	ADDQ.W	#8,A0
	TST.B	-1(A5)
	BEQ.S	NOCOP31
	BSR.S	TRANSCOPY1
NOCOP31:ADD.W	D3,A2
	ADDQ.W	#8,A0
	CLR.L	-4(A5)
	DBF	D0,TRASFBUC21
	DBF	D4,TRASFBUC31
	RTS
	CNOP	0,8
TRANSCOPY1:
	TRASF1	$00
	TRASF1	$08
	TRASF1	$10
	TRASF1	$18
	TRASF1	$20
	TRASF1	$28
	TRASF1	$30
	TRASF1	$38
	SUBQ.W	#8,A0
	RTS
	CNOP	0,8
OTROCOL1:
	MOVE.B	D7,-1(A6)
	MOVEQ	#(8)-1,D0
TRASFBUCB1:
	TRASF1	$00
	TRASF1	$08
	TRASF1	$10
	TRASF1	$18
	TRASF1	$20
	TRASF1	$28
	TRASF1	$30
	TRASF1	$38
	ADD.W	D3,A2
	DBF	D0,TRASFBUCB1
	CLR.L	(A5)+
	CLR.L	(A5)+
	DBF	D4,TRASFBUC31
	RTS
	CNOP	0,8
TRANSCHEC1:
	SF	ACTODO(A3)
	MOVEQ	#(32)-1,D4
TRASFBUC01:
	MOVE.B	(A4)+,D7
	MOVEQ	#(8)-1,D0
TRASFBUC1:
	TRASF1	$00
	TRASF1	$08
	TRASF1	$10
	TRASF1	$18
	TRASF1	$20
	TRASF1	$28
	TRASF1	$30
	TRASF1	$38
	ADD.W	D3,A2
	DBF	D0,TRASFBUC1
	DBF	D4,TRASFBUC01

	LEA	TAB98(PC),A6
	MOVE.L	PVDP4(A3),D0		; Tabla Gfx Caracteres VRAM
	LSR.L	#3,D0
	ADD.W	#256,D0
	ADD.W	D0,A6

	MOVEM.L	CEROSR1(PC),D0-D7/A0-A5
	MOVEM.L	D0-D7/A0-A5,-(A6)
	MOVEM.L	D0-D7/A0-A5,-(A6)
	MOVEM.L	D0-D7/A0-A5,-(A6)
	MOVEM.L	D0-D7/A0-A5,-(A6)
	MOVEM.L	D0-D7,-(A6)
	RTS

	CNOP	0,8
CEROSR1:DS.L	20
	CNOP	0,8
COLSCR1:DS.B	36


TRASF16:MACRO
	MOVE.W	(A0),D1
	MOVE.B	D7,D1
	MOVE.L	(A1,D1.L*4),D2
	ADDQ	#1,A0
	MOVE.B	D2,\1+6(A2)
	LSR.W	#8,D2
	MOVE.B	D2,\1+4(A2)
	SWAP	D2
	MOVE.B	D2,\1+2(A2)
	LSR.W	#8,D2
	MOVE.B	D2,\1(A2)
	ENDM

	CNOP	0,8
TRANSBLT1060:

	TST.B	ACTODO(A3)
	BNE	TRANSCHEC16

	LEA	TAB98(PC),A5
	MOVE.L	PVDP4(A3),D0		; Tabla Gfx Caracteres VRAM
	LSR.L	#3,D0
	ADD.W	D0,A5
	LEA	COLSCR1(PC),A6
	MOVE.W	#($40*4),D5
	MOVE.W	#(4*8),D6
	MOVEQ	#(32)-1,D4
TRASFBUC316:
	MOVE.B	(A4)+,D7
	MOVEQ	#((8)/4)-1,D0
	CMP.B	(A6)+,D7
	BNE	OTROCOL16	
TRASFBUC216:
	TST.L	(A5)+
	BNE.S	TRANSCHECK16
	ADD.W	D6,A0
	ADD.W	D5,A2
	DBF	D0,TRASFBUC216
	DBF	D4,TRASFBUC316
	RTS
	CNOP	0,8
TRANSCHECK16:
	TST.B	-4(A5)
	BEQ.S	NOCOP016
	BSR.S	TRANSCOPY16
NOCOP016:ADD.W	D3,A2
	ADDQ.W	#8,A0
	TST.B	-3(A5)
	BEQ.S	NOCOP116
	BSR.S	TRANSCOPY16
NOCOP116:ADD.W	D3,A2
	ADDQ.W	#8,A0
	TST.B	-2(A5)
	BEQ.S	NOCOP216
	BSR.S	TRANSCOPY16
NOCOP216:ADD.W	D3,A2
	ADDQ.W	#8,A0
	TST.B	-1(A5)
	BEQ.S	NOCOP316
	BSR.S	TRANSCOPY16
NOCOP316:ADD.W	D3,A2
	ADDQ.W	#8,A0
	CLR.L	-4(A5)
	DBF	D0,TRASFBUC216
	DBF	D4,TRASFBUC316
	RTS
	CNOP	0,8
TRANSCOPY16:
	TRASF16	$00
	TRASF16	$08
	TRASF16	$10
	TRASF16	$18
	TRASF16	$20
	TRASF16	$28
	TRASF16	$30
	TRASF16	$38
	SUBQ.W	#8,A0
	RTS
	CNOP	0,8
OTROCOL16:
	MOVE.B	D7,-1(A6)
	MOVEQ	#(8)-1,D0
TRASFBUCB16:
	TRASF16	$00
	TRASF16	$08
	TRASF16	$10
	TRASF16	$18
	TRASF16	$20
	TRASF16	$28
	TRASF16	$30
	TRASF16	$38
	ADD.W	D3,A2
	DBF	D0,TRASFBUCB16
	CLR.L	(A5)+
	CLR.L	(A5)+
	DBF	D4,TRASFBUC316
	RTS
	CNOP	0,8
TRANSCHEC16:
	SF	ACTODO(A3)
	MOVEQ	#(32)-1,D4
TRASFBUC016:
	MOVE.B	(A4)+,D7
	MOVEQ	#(8)-1,D0
TRASFBUC16:
	TRASF16	$00
	TRASF16	$08
	TRASF16	$10
	TRASF16	$18
	TRASF16	$20
	TRASF16	$28
	TRASF16	$30
	TRASF16	$38
	ADD.W	D3,A2
	DBF	D0,TRASFBUC16
	DBF	D4,TRASFBUC016

	LEA	TAB98(PC),A6
	MOVE.L	PVDP4(A3),D0		; Tabla Gfx Caracteres VRAM
	LSR.L	#3,D0
	ADD.W	#256,D0
	ADD.W	D0,A6

	MOVEM.L	CEROSR1(PC),D0-D7/A0-A5
	MOVEM.L	D0-D7/A0-A5,-(A6)
	MOVEM.L	D0-D7/A0-A5,-(A6)
	MOVEM.L	D0-D7/A0-A5,-(A6)
	MOVEM.L	D0-D7/A0-A5,-(A6)
	MOVEM.L	D0-D7,-(A6)
	RTS
; -----------------------------<

	CNOP	0,8
; ----------------------------->  Copia Caracteres en Pantalla.
COPIATXT1:
	LEA	TXT2(PC),A1

	LEA	REGS(PC),A3
	LEA	DIRVRAM,A0
	ADD.L	PVDP2(A3),A0		; Tabla de texto.

	LEA	SCREEN,A4			; Pantalla Destino Amiga.
	LEA	GFXCA,A5

	LEA	$DFF002,A6
ESPBLTT1:BTST	#$E,(A6)
	BNE.S	ESPBLTT1
	MOVE.W	#$0DFC,$40-2(A6)	; Datos para Blitter.
	MOVE.W	#$8000,$42-2(A6)
	MOVE.W	#0,$64-2(A6)
	MOVE.W	#0,$62-2(A6)
	MOVE.W	#32-2,$66-2(A6)
	MOVE.L	#-1,$44-2(A6)

	MOVE.W	#(32*4*8)-32,D5
	MOVE.W	#(32*$40)+1,D3
	MOVEQ	#$E,D7
	MOVE.W	#(8*3)-1,D0
COPIABUC1Z:
	MOVE.W	#(32/4)-1,D4
COPIABUCZ:
	CMP.L	(A0)+,(A1)+
	BEQ.S	NOCOPIA2Z

	MOVE.L	-4(A0),D2
	MOVE.L	D2,D6
	MOVEQ	#0,D1
	SWAP	D2
	CMP.W	-4(A1),D2
	BEQ.S	NOCOPIA22Z
	MOVE.B	D2,D1
	LSL.W	#3,D1
	LEA	(A5,D1.W*8),A2
	LSR.W	#8,D2
	LSL.W	#3,D2
	LEA	(A5,D2.W*8),A3
ESPBLTP2Z:
	BTST	D7,(A6)
	BNE.S	ESPBLTP2Z
	MOVEM.L	A2-A4,$4C-2(A6)
	MOVE.W	D3,$58-2(A6)
NOCOPIA22Z:
	SWAP	D2
	CMP.W	-2(A1),D2
	BEQ.S	COPIADO2Z
	MOVEQ	#0,D1
	MOVE.B	D2,D1
	LSL.W	#3,D1
	LEA	(A5,D1.W*8),A2
	LSR.W	#8,D2
	LSL.W	#3,D2
	LEA	(A5,D2.W*8),A3
	ADDQ	#2,A4
ESPBLTP2BZ:
	BTST	D7,(A6)
	BNE.S	ESPBLTP2BZ
	MOVEM.L	A2-A4,$4C-2(A6)
	SUBQ	#2,A4
	MOVE.W	D3,$58-2(A6)
COPIADO2Z:
	MOVE.L	D6,-4(A1)
NOCOPIA2Z:
	ADDQ	#4,A4
	DBF	D4,COPIABUCZ
	ADD.W	D5,A4
	DBF	D0,COPIABUC1Z
	RTS
; -----------------------------<

	CNOP	0,8
; ----------------------------->  Imprime  Gfx de caracteres en pantalla.
ACTUALIZA1:
	LEA	TXT2(PC),A1

	LEA	REGS(PC),A3
	LEA	DIRVRAM,A0
	ADD.L	PVDP2(A3),A0		; Tabla de texto.

	LEA	SCREEN,A4			; Pantalla Destino Amiga.
	LEA	GFXCA,A5

	LEA	$DFF002,A6
ESPBLTA1:BTST	#$E,(A6)
	BNE.S	ESPBLTA1
	MOVE.W	#$0DFC,$40-2(A6)	; Datos para Blitter.
	MOVE.W	#$8000,$42-2(A6)
	MOVE.W	#0,$64-2(A6)
	MOVE.W	#0,$62-2(A6)
	MOVE.W	#32-2,$66-2(A6)
	MOVE.L	#-1,$44-2(A6)

	MOVE.W	#(32*4*8)-32,D5
	MOVE.W	#(32*$40)+1,D3
	MOVEQ	#$E,D7
	MOVE.W	#(8*3)-1,D0
COPIABUCA1Z:
	MOVE.W	#(32/2)-1,D4
COPIABUCAZ:
	MOVE.W	(A0)+,D2
	MOVE.W	D2,(A1)+
	MOVEQ	#0,D1
	MOVE.B	D2,D1
	LSL.W	#3,D1
	LEA	(A5,D1.W*8),A2
	LSR.W	#8,D2
	LSL.W	#3,D2
	LEA	(A5,D2.W*8),A3
ESPBLTPAZ:
	BTST	D7,(A6)
	BNE.S	ESPBLTPAZ
	MOVEM.L	A2-A4,$4C-2(A6)
	MOVE.W	D3,$58-2(A6)
	ADDQ	#2,A4
	DBF	D4,COPIABUCAZ
	ADD.W	D5,A4
	DBF	D0,COPIABUCA1Z
	RTS
; -----------------------------<

	CNOP	0,8
; ----------------------------->  Imprime  Gfx de caracteres en pantalla.
Actualiza3:
	LEA	TXT2(PC),A1

	LEA	REGS(PC),A3
	LEA	DIRVRAM,A0
	MOVE.L	A0,A5
	ADD.L	PVDP2(A3),A0		; Tabla de texto.
	ADD.L	PVDP4(A3),A5		; Tabla de Colores.

	LEA	SCREEN,A4		; Pantalla Destino Amiga.
	LEA	TABLA7E,A6		; Tabla de conversi�n de Gfx (MSX=>Amiga)

	MOVE.L	#$0000F000,D1
	MOVE.W	#(32*8*4)-32,D7
	MOVEQ	#0,D2
	MOVEQ	#(6)-1,D6
Act3Buc02:
	MOVEQ	#(4)-1,D5
Act3Buc01:
	MOVEQ	#(32)-1,D4
Act3Buc00:
	MOVE.B	(A0)+,D2
	MOVE.B	D2,(A1)+
	LEA	(A5,D2.W*8),A2

	MOVE.B	(A2)+,D1			; Parte de Arriba
	MOVE.L	(A6,D1.L*4),D0

	MOVE.B	D0,(32*3)(A4)
	MOVE.B	D0,(32*3)+(32*4*1)(A4)
	MOVE.B	D0,(32*3)+(32*4*2)(A4)
	MOVE.B	D0,(32*3)+(32*4*3)(A4)
	LSR.W	#8,D0
	MOVE.B	D0,(32*2)(A4)
	MOVE.B	D0,(32*2)+(32*4*1)(A4)
	MOVE.B	D0,(32*2)+(32*4*2)(A4)
	MOVE.B	D0,(32*2)+(32*4*3)(A4)
	SWAP	D0
	MOVE.B	D0,32(A4)
	MOVE.B	D0,32+(32*4*1)(A4)
	MOVE.B	D0,32+(32*4*2)(A4)
	MOVE.B	D0,32+(32*4*3)(A4)
	LSR.W	#8,D0
	MOVE.B	D0,(A4)+
	MOVE.B	D0,(32*4*1)-1(A4)
	MOVE.B	D0,(32*4*2)-1(A4)
	MOVE.B	D0,(32*4*3)-1(A4)

	MOVE.B	(A2)+,D1			; Parte de Abajo
	MOVE.L	(A6,D1.L*4),D0

	MOVE.B	D0,(32*4*4)+(32*3)-1(A4)
	MOVE.B	D0,(32*4*4)+(32*3)+(32*4*1)-1(A4)
	MOVE.B	D0,(32*4*4)+(32*3)+(32*4*2)-1(A4)
	MOVE.B	D0,(32*4*4)+(32*3)+(32*4*3)-1(A4)
	LSR.W	#8,D0
	MOVE.B	D0,(32*4*4)+(32*2)-1(A4)
	MOVE.B	D0,(32*4*4)+(32*2)+(32*4*1)-1(A4)
	MOVE.B	D0,(32*4*4)+(32*2)+(32*4*2)-1(A4)
	MOVE.B	D0,(32*4*4)+(32*2)+(32*4*3)-1(A4)
	SWAP	D0
	MOVE.B	D0,(32*4*4)+32-1(A4)
	MOVE.B	D0,(32*4*4)+32+(32*4*1)-1(A4)
	MOVE.B	D0,(32*4*4)+32+(32*4*2)-1(A4)
	MOVE.B	D0,(32*4*4)+32+(32*4*3)-1(A4)
	LSR.W	#8,D0
	MOVE.B	D0,(32*4*4)-1(A4)
	MOVE.B	D0,(32*4*4)+(32*4*1)-1(A4)
	MOVE.B	D0,(32*4*4)+(32*4*2)-1(A4)
	MOVE.B	D0,(32*4*4)+(32*4*3)-1(A4)

	DBF	D4,Act3Buc00
	ADD.W	D7,A4
	ADDQ.W	#(2),A5
	DBF	D5,Act3Buc01
	SUBQ.W	#(2*4),A5
	DBF	D6,Act3Buc02


	SF	ACTODO(A3)


	LEA	TAB98(PC),A6
	MOVE.L	PVDP4(A3),D0		; Tabla Gfx Caracteres VRAM
	LSR.L	#3,D0
	ADD.W	#256,D0
	ADD.W	D0,A6

	MOVEM.L	CEROSR1(PC),D0-D7/A0-A5
	MOVEM.L	D0-D7/A0-A5,-(A6)
	MOVEM.L	D0-D7/A0-A5,-(A6)
	MOVEM.L	D0-D7/A0-A5,-(A6)
	MOVEM.L	D0-D7/A0-A5,-(A6)
	MOVEM.L	D0-D7,-(A6)
	RTS
; -----------------------------<

	CNOP	0,8
; ----------------------------->  Imprime  Gfx de caracteres en pantalla.
CopiaTexto3:
	LEA	TXT2(PC),A1

	LEA	REGS(PC),A3
	LEA	DIRVRAM,A0
	MOVE.L	A0,A5
	ADD.L	PVDP2(A3),A0		; Tabla de texto.
	ADD.L	PVDP4(A3),A5		; Tabla de Colores.

	LEA	SCREEN,A4		; Pantalla Destino Amiga.
	LEA	TABLA7E,A6		; Tabla de conversi�n de Gfx (MSX=>Amiga)

	MOVE.L	#$0000F000,D1
	MOVE.W	#(32*8*4)-32,D7
	MOVEQ	#0,D2
	MOVEQ	#(6)-1,D6
Copia3Buc02:
	MOVEQ	#(4)-1,D5
Copia3Buc01:
	MOVEQ	#(32)-1,D4
Copia3Buc00:
	CMP.B	(A0)+,(A1)+
	BNE.S	Copia3Con
	ADDQ.W	#1,A4
	DBF	D4,Copia3Buc00
	ADD.W	D7,A4
	ADDQ.W	#(2),A5
	DBF	D5,Copia3Buc01
	SUBQ.W	#(2*4),A5
	DBF	D6,Copia3Buc02


	LEA	TAB98(PC),A6
	MOVE.L	PVDP4(A3),D0		; Tabla Gfx Caracteres VRAM
	LSR.L	#3,D0
	ADD.W	#256,D0
	ADD.W	D0,A6

	MOVEM.L	CEROSR1(PC),D0-D7/A0-A5
	MOVEM.L	D0-D7/A0-A5,-(A6)
	MOVEM.L	D0-D7/A0-A5,-(A6)
	MOVEM.L	D0-D7/A0-A5,-(A6)
	MOVEM.L	D0-D7/A0-A5,-(A6)
	MOVEM.L	D0-D7,-(A6)
	RTS

	CNOP	0,8
Copia3Con:
	MOVE.B	-1(A0),D2
	MOVE.B	D2,-1(A1)
	LEA	(A5,D2.W*8),A2

	MOVE.B	(A2)+,D1			; Parte de Arriba
	MOVE.L	(A6,D1.L*4),D0

	MOVE.B	D0,(32*3)(A4)
	MOVE.B	D0,(32*3)+(32*4*1)(A4)
	MOVE.B	D0,(32*3)+(32*4*2)(A4)
	MOVE.B	D0,(32*3)+(32*4*3)(A4)
	LSR.W	#8,D0
	MOVE.B	D0,(32*2)(A4)
	MOVE.B	D0,(32*2)+(32*4*1)(A4)
	MOVE.B	D0,(32*2)+(32*4*2)(A4)
	MOVE.B	D0,(32*2)+(32*4*3)(A4)
	SWAP	D0
	MOVE.B	D0,32(A4)
	MOVE.B	D0,32+(32*4*1)(A4)
	MOVE.B	D0,32+(32*4*2)(A4)
	MOVE.B	D0,32+(32*4*3)(A4)
	LSR.W	#8,D0
	MOVE.B	D0,(A4)+
	MOVE.B	D0,(32*4*1)-1(A4)
	MOVE.B	D0,(32*4*2)-1(A4)
	MOVE.B	D0,(32*4*3)-1(A4)

	MOVE.B	(A2)+,D1			; Parte de Abajo
	MOVE.L	(A6,D1.L*4),D0

	MOVE.B	D0,(32*4*4)+(32*3)-1(A4)
	MOVE.B	D0,(32*4*4)+(32*3)+(32*4*1)-1(A4)
	MOVE.B	D0,(32*4*4)+(32*3)+(32*4*2)-1(A4)
	MOVE.B	D0,(32*4*4)+(32*3)+(32*4*3)-1(A4)
	LSR.W	#8,D0
	MOVE.B	D0,(32*4*4)+(32*2)-1(A4)
	MOVE.B	D0,(32*4*4)+(32*2)+(32*4*1)-1(A4)
	MOVE.B	D0,(32*4*4)+(32*2)+(32*4*2)-1(A4)
	MOVE.B	D0,(32*4*4)+(32*2)+(32*4*3)-1(A4)
	SWAP	D0
	MOVE.B	D0,(32*4*4)+32-1(A4)
	MOVE.B	D0,(32*4*4)+32+(32*4*1)-1(A4)
	MOVE.B	D0,(32*4*4)+32+(32*4*2)-1(A4)
	MOVE.B	D0,(32*4*4)+32+(32*4*3)-1(A4)
	LSR.W	#8,D0
	MOVE.B	D0,(32*4*4)-1(A4)
	MOVE.B	D0,(32*4*4)+(32*4*1)-1(A4)
	MOVE.B	D0,(32*4*4)+(32*4*2)-1(A4)
	MOVE.B	D0,(32*4*4)+(32*4*3)-1(A4)

	DBF	D4,Copia3Buc00
	ADD.W	D7,A4
	ADDQ.W	#(2),A5
	DBF	D5,Copia3Buc01
	SUBQ.W	#(2*4),A5
	DBF	D6,Copia3Buc02


	LEA	TAB98(PC),A6
	MOVE.L	PVDP4(A3),D0		; Tabla Gfx Caracteres VRAM
	LSR.L	#3,D0
	ADD.W	#256,D0
	ADD.W	D0,A6

	MOVEM.L	CEROSR1(PC),D0-D7/A0-A5
	MOVEM.L	D0-D7/A0-A5,-(A6)
	MOVEM.L	D0-D7/A0-A5,-(A6)
	MOVEM.L	D0-D7/A0-A5,-(A6)
	MOVEM.L	D0-D7/A0-A5,-(A6)
	MOVEM.L	D0-D7,-(A6)
	RTS
; -----------------------------<

	CNOP	0,8
; ----------------------------->  Actualiza Gfx de caracteres en pantalla.
PREPARATXT:
	MOVE.W	#(3)-1,D3
PREPARATXT4:			; D3 = screen blocks - 1 (3 or 4 blocks of 8 rows)
	LEA	REGS(PC),A3
	MOVE.L	Txt2Ptr,A1		; Name shadow of the bank (RendTabCheck).
	MOVEQ	#0,D1
	MOVEQ	#0,D7			; Block.
PREPBLQ:
	BSR	TBloque			; A4/A5: this block's dirty flags.
	MOVE.L	A4,A0			; Anything changed in its tables?
	MOVEQ	#(256/4)-1,D0
PRECHK0:TST.L	(A0)+
	BNE.S	PREPRUT
	DBF	D0,PRECHK0
	MOVE.L	A5,A0
	MOVEQ	#(256/4)-1,D0
PRECHK1:TST.L	(A0)+
	BNE.S	PREPRUT
	DBF	D0,PRECHK1
	ADD.W	#256,A1			; No: skip its 256 names.
	BRA	PREPSIG
	CNOP	0,8
PREPRUT:
	LEA	DIRVRAM,A0
	ADD.L	PVDP2(A3),A0		; Tabla de texto.
	MOVE.W	D7,D0
	LSL.W	#8,D0
	ADD.W	D0,A0			; This block's names.
	MOVE.W	#((32*8)/4)-1,D0
PREPBUC:
	MOVE.L	(A0)+,D2

	MOVE.B	D2,D1
	TST.B	(A4,D1.W)
	BNE.S	PONULO0B
	TST.B	(A5,D1.W)
	BEQ.S	PONULO0
PONULO0B:NOT.B	D1
	MOVE.B	D1,3(A1)
PONULO0:LSR.W	#8,D2
	TST.B	(A4,D2.W)
	BNE.S	PONULO1B
	TST.B	(A5,D2.W)
	BEQ.S	PONULO1
PONULO1B:NOT.B	D2
	MOVE.B	D2,2(A1)
PONULO1:SWAP	D2
	MOVE.B	D2,D1
	TST.B	(A4,D1.W)
	BNE.S	PONULO2B
	TST.B	(A5,D1.W)
	BEQ.S	PONULO2
PONULO2B:NOT.B	D1
	MOVE.B	D1,1(A1)
PONULO2:LSR.W	#8,D2
	TST.B	(A4,D2.W)
	BNE.S	PONULO3B
	TST.B	(A5,D2.W)
	BEQ.S	PONULO3
PONULO3B:NOT.B	D2
	MOVE.B	D2,(A1)
PONULO3:ADDQ.W	#4,A1
	DBF	D0,PREPBUC
PREPSIG:
	ADDQ.W	#1,D7
	CMP.W	D3,D7
	BLS	PREPBLQ
	RTS

	CNOP	0,4
SumaVRAM:DC.W	$100			; (No longer used: see TBloque.)
TBlqUlt:DC.W	0			; Last screen block (TRANSBLT).

; Tables of SCREEN 2/4 screen block t (D7.W) with the TMS9918/V9938 masks:
; colour  = PVDP3B + ((t & (R#3>>5)) << 11), only R#3 bits 5-6 masking the
;           block (bits 0-4 masking characters is not supported);
; pattern = PVDP4B + ((t & R#4) << 11), R#4 bits 0-1.
; Standard values (R#3=$FF, R#4=3) give the usual contiguous 2Kb blocks;
; Uridium uses R#3=$1F/$9F, one colour table for all blocks. v3.1 assumed
; pattern = colour +/- $2000 and contiguous blocks.
; Out: A0 = colour table in DIRVRAM, D4.L = pattern - colour,
; A4/A5 = TAB98 dirty flags of the colour/pattern table. Uses D5/D6.
TBloque:
	MOVEQ	#0,D6
	MOVE.B	DVDP3+1(A3),D6		; R#3
	LSR.B	#5,D6
	AND.W	D7,D6
	AND.W	#3,D6
	LSL.L	#8,D6
	LSL.L	#3,D6
	ADD.L	PVDP3B(A3),D6		; Colour table of the block.
	MOVEQ	#0,D5
	MOVE.W	DVDP4(A3),D5		; R#4
	AND.W	D7,D5
	AND.W	#3,D5
	LSL.L	#8,D5
	LSL.L	#3,D5
	ADD.L	PVDP4B(A3),D5		; Pattern table of the block.
	LEA	DIRVRAM,A0
	ADD.L	D6,A0
	MOVE.L	D5,D4
	SUB.L	D6,D4
	LSR.L	#3,D6
	LSR.L	#3,D5
	MOVE.L	TabFlagPtr,A4		; Flags of the cache bank in use.
	ADD.L	D6,A4
	MOVE.L	TabFlagPtr,A5
	ADD.L	D5,A5
	RTS
; -----------------------------<

	CNOP	0,8
; ----------------------------->  Transforma Vram MSX a GfxBlt Amiga.
TRASF:	MACRO
	MOVE.W	(A0,D4.L),D1
	MOVE.B	(A0)+,D1
	MOVE.L	(A1,D1.L*4),D2
	MOVEP.L	D2,\1(A2)
	ENDM
TRANSBLT:
	MOVE.W	#((32*8*3)/4)-1,D0
TRANSBLT4:			; D0 = characters/4 - 1: 3 or 4 blocks of 256.
	LEA	REGS(PC),A3
	ADDQ.W	#1,D0
	LSR.W	#6,D0
	SUBQ.W	#1,D0
	MOVE.W	D0,TBlqUlt
	LEA	TABLA7E,A1
	MOVE.L	GfxCaPtr,A2		; Cache bank in use (RendTabCheck).
	MOVE.W	#$40,D3
	MOVEQ	#0,D1
	MOVEQ	#0,D7			; Block.

	TST.B	Modo060(A3)		; Mira si es un 060.
	BNE	TRANSBLT46

	TST.B	ACTODOB(A3)
	BNE	TRANSCHEC
TRBLQ:
	BSR	TBloque
	MOVE.W	#($40*4),D5
	MOVE.W	#(4*8),D6
	MOVE.W	#(256/4)-1,D0
TRASFBUC2:
	TST.L	(A4)+
	BNE.S	TRANSCheckB
	TST.L	(A5)+
	BNE.S	TRANSCHECK
	ADD.W	D6,A0
	ADD.W	D5,A2
	DBF	D0,TRASFBUC2
	BRA	TRSIG
	CNOP	0,8
TRANSCheckB:
	ADDQ.W	#4,A5
TRANSCHECK:
	TST.B	-4(A4)
	BNE.S	NOCOP0
	TST.B	-4(A5)
	BEQ.S	NOCOP0B
NOCOP0:	BSR.S	TRANSCOPY
NOCOP0B:ADD.W	D3,A2
	ADDQ.W	#8,A0
	TST.B	-3(A4)
	BNE.S	NOCOP1
	TST.B	-3(A5)
	BEQ.S	NOCOP1B
NOCOP1:	BSR.S	TRANSCOPY
NOCOP1B:ADD.W	D3,A2
	ADDQ.W	#8,A0
	TST.B	-2(A4)
	BNE.S	NOCOP2
	TST.B	-2(A5)
	BEQ.S	NOCOP2B
NOCOP2:	BSR.S	TRANSCOPY
NOCOP2B:ADD.W	D3,A2
	ADDQ.W	#8,A0
	TST.B	-1(A4)
	BNE.S	NOCOP3
	TST.B	-1(A5)
	BEQ.S	NOCOP3B
NOCOP3:	BSR.S	TRANSCOPY
NOCOP3B:ADD.W	D3,A2
	ADDQ.W	#8,A0
	DBF	D0,TRASFBUC2
TRSIG:
	ADDQ.W	#1,D7
	CMP.W	TBlqUlt(PC),D7
	BLS	TRBLQ
	BRA	TRCLRTODO

; Clear the dirty flags only after every block is done: blocks can share
; their tables (R#3/R#4 masks), so clearing while rendering block 0 hid the
; changes from blocks 1-3 (Chikubi Ninja, SCREEN 4 with R#3=$9F R#4=0).
TRCLRTODO:
	MOVEQ	#0,D7
TRCLRB:	BSR	TBloque
	MOVEQ	#(256/4)-1,D0
TRCLRL:	CLR.L	(A4)+
	CLR.L	(A5)+
	DBF	D0,TRCLRL
	ADDQ.W	#1,D7
	CMP.W	TBlqUlt(PC),D7
	BLS	TRCLRB
	RTS
	CNOP	0,8
TRANSCOPY:
	TRASF	$00
	TRASF	$08
	TRASF	$10
	TRASF	$18
	TRASF	$20
	TRASF	$28
	TRASF	$30
	TRASF	$38
	SUBQ.W	#8,A0
	RTS
	CNOP	0,8
TRANSCHEC:
	SF	ACTODOB(A3)
TRCBLQ:
	BSR	TBloque
	MOVE.W	#256-1,D0
TRASFBUC:
	TRASF	$00
	TRASF	$08
	TRASF	$10
	TRASF	$18
	TRASF	$20
	TRASF	$28
	TRASF	$30
	TRASF	$38
	ADD.W	D3,A2
	DBF	D0,TRASFBUC
	ADDQ.W	#1,D7
	CMP.W	TBlqUlt(PC),D7
	BLS	TRCBLQ
	BRA	TRCLRTODO

	CNOP	0,8
CEROSR2:DS.L	20

TRASF6:	MACRO
	MOVE.W	(A0,D4.L),D1
	MOVE.B	(A0)+,D1
	MOVE.L	(A1,D1.L*4),D2
	MOVE.B	D2,\1+6(A2)
	LSR.W	#8,D2
	MOVE.B	D2,\1+4(A2)
	SWAP	D2
	MOVE.B	D2,\1+2(A2)
	LSR.W	#8,D2
	MOVE.B	D2,\1(A2)
	ENDM

	CNOP	0,8
TRANSBLT46:

	TST.B	ACTODOB(A3)
	BNE	TRANSCHEC6
TRBLQ6:
	BSR	TBloque
	MOVE.W	#($40*4),D5
	MOVE.W	#(4*8),D6
	MOVE.W	#(256/4)-1,D0
TRASFBUC26:
	TST.L	(A4)+
	BNE.S	TRANSCheckB6
	TST.L	(A5)+
	BNE.S	TRANSCHECK6
	ADD.W	D6,A0
	ADD.W	D5,A2
	DBF	D0,TRASFBUC26
	BRA	TRSIG6
	CNOP	0,8
TRANSCheckB6:
	ADDQ.W	#4,A5
TRANSCHECK6:
	TST.B	-4(A4)
	BNE.S	NOCOP06
	TST.B	-4(A5)
	BEQ.S	NOCOP0B6
NOCOP06:BSR.S	TRANSCOPY6
NOCOP0B6:ADD.W	D3,A2
	ADDQ.W	#8,A0
	TST.B	-3(A4)
	BNE.S	NOCOP16
	TST.B	-3(A5)
	BEQ.S	NOCOP1B6
NOCOP16:BSR.S	TRANSCOPY6
NOCOP1B6:ADD.W	D3,A2
	ADDQ.W	#8,A0
	TST.B	-2(A4)
	BNE.S	NOCOP26
	TST.B	-2(A5)
	BEQ.S	NOCOP2B6
NOCOP26:BSR.S	TRANSCOPY6
NOCOP2B6:ADD.W	D3,A2
	ADDQ.W	#8,A0
	TST.B	-1(A4)
	BNE.S	NOCOP36
	TST.B	-1(A5)
	BEQ.S	NOCOP3B6
NOCOP36:BSR.S	TRANSCOPY6
NOCOP3B6:ADD.W	D3,A2
	ADDQ.W	#8,A0
	DBF	D0,TRASFBUC26
TRSIG6:
	ADDQ.W	#1,D7
	CMP.W	TBlqUlt(PC),D7
	BLS	TRBLQ6
	BRA	TRCLRTODO
	CNOP	0,8
TRANSCOPY6:
	TRASF6	$00
	TRASF6	$08
	TRASF6	$10
	TRASF6	$18
	TRASF6	$20
	TRASF6	$28
	TRASF6	$30
	TRASF6	$38
	SUBQ.W	#8,A0
	RTS
	CNOP	0,8
TRANSCHEC6:
	SF	ACTODOB(A3)
TRCBLQ6:
	BSR	TBloque
	MOVE.W	#256-1,D0
TRASFBUC6:
	TRASF6	$00
	TRASF6	$08
	TRASF6	$10
	TRASF6	$18
	TRASF6	$20
	TRASF6	$28
	TRASF6	$30
	TRASF6	$38
	ADD.W	D3,A2
	DBF	D0,TRASFBUC6
	ADDQ.W	#1,D7
	CMP.W	TBlqUlt(PC),D7
	BLS	TRCBLQ6
	BRA	TRCLRTODO

; -----------------------------<

	CNOP	0,8
TABLABUF:
	DC.L	BUFTXT2
	DC.L	BUFTXT1

	CNOP	0,8
; ----------------------------->  Copia Caracteres en Pantalla.
COPIATXT:
	LEA	REGS(PC),A3
	LEA	DIRVRAM,A0
	ADD.L	PVDP2(A3),A0		; Tabla de texto.

	LEA	TABLABUF(PC),A2
	MOVE.L	4(A2),A1

	MOVEQ	#32,D1
	MOVEQ	#((32*24)/32)-1,D0
COPYBUF:
	MOVEM.L	(A0)+,D2-D7/A4-A5
	MOVEM.L	D2-D7/A4-A5,(A1)
	ADD.W	D1,A1
	DBF	D0,COPYBUF

	MOVE.L	(A2),A0
	MOVE.L	4(A2),(A2)
	MOVE.L	A0,4(A2)
	MOVE.L	(A2),A0			; This frame's names, not last frame's:
					; with a screen per cache bank (Uridium's
					; two table sets) last frame's names belong
					; to the other set. (As SCREEN 4.)

	MOVEQ	#(3)-1,D7
COPIATXT4:

	MOVE.L	Txt2Ptr,A1		; Name shadow of the bank (RendTabCheck).
	MOVE.L	ScreenPtr,A4		; Screen of the bank (RendTabCheck).
	MOVE.L	GfxCaPtr,A5		; Cache bank in use (RendTabCheck).

	LEA	$DFF002,A6
ESPBLTT2:BTST	#$E,(A6)
	BNE.S	ESPBLTT2
	MOVE.W	#$0DFC,$40-2(A6)	; Datos para Blitter.
	MOVE.W	#$8000,$42-2(A6)
	MOVE.W	#0,$64-2(A6)
	MOVE.W	#0,$62-2(A6)
	MOVE.W	#32-2,$66-2(A6)
	MOVE.L	#-1,$44-2(A6)

	MOVE.W	#(32*4*8)-32,D5
	MOVE.W	#(32*$40)+1,D3
;;;	MOVEQ	#(3)-1,D7		; Est� mas arriba.
COPIABUC2:
	MOVE.W	#(8)-1,D0
COPIABUC1:
	MOVE.W	#(32/4)-1,D4
COPIABUC:
	CMP.L	(A0)+,(A1)+
	BEQ.S	NOCOPIA2

	MOVE.L	-4(A0),D2
	MOVE.L	D2,D6
	MOVEQ	#0,D1
	SWAP	D2
	CMP.W	-4(A1),D2
	BEQ.S	NOCOPIA22
	MOVE.B	D2,D1
	LSL.W	#3,D1
	LEA	(A5,D1.W*8),A2
	LSR.W	#8,D2
	LSL.W	#3,D2
	LEA	(A5,D2.W*8),A3
ESPBLTP2:
	BTST	#$E,(A6)
	BNE.S	ESPBLTP2
	MOVEM.L	A2-A4,$4C-2(A6)
	MOVE.W	D3,$58-2(A6)
NOCOPIA22:
	SWAP	D2
	CMP.W	-2(A1),D2
	BEQ.S	COPIADO2
	MOVEQ	#0,D1
	MOVE.B	D2,D1
	LSL.W	#3,D1
	LEA	(A5,D1.W*8),A2
	LSR.W	#8,D2
	LSL.W	#3,D2
	LEA	(A5,D2.W*8),A3
	ADDQ	#2,A4
ESPBLTP2B:
	BTST	#$E,(A6)
	BNE.S	ESPBLTP2B
	MOVEM.L	A2-A4,$4C-2(A6)
	SUBQ	#2,A4
	MOVE.W	D3,$58-2(A6)
COPIADO2:
	MOVE.L	D6,-4(A1)
NOCOPIA2:
	ADDQ	#4,A4
	DBF	D4,COPIABUC
	ADD.W	D5,A4
	DBF	D0,COPIABUC1
	ADD.W	SumaBpl(PC),A5
	DBF	D7,COPIABUC2
	RTS

	CNOP	0,8
SumaBpl:DC.W	($800*4*2)

	CNOP	0,8
CONTA3:	DC.W	(32*24)/32
	CNOP	0,8
BUFTXT1:DS.B	40*30
	EVEN
BUFTXT2:DS.B	40*30
	EVEN
TXT2:	DS.B	80*30
	EVEN
; -----------------------------<

	CNOP	0,8
; ----------------------------->  Imprime  Gfx de caracteres en pantalla.
ACTUALIZA:
	LEA	REGS(PC),A3
	LEA	DIRVRAM,A0
	ADD.L	PVDP2(A3),A0		; Tabla de texto.

	MOVE.L	A0,A6
	MOVE.L	TABLABUF(PC),A1

	MOVEQ	#32,D1
	MOVEQ	#((32*24)/32)-1,D0
COPYBUF2:
	MOVEM.L	(A6)+,D2-D7/A4-A5
	MOVEM.L	D2-D7/A4-A5,(A1)
	ADD.W	D1,A1
	DBF	D0,COPYBUF2

	MOVEQ	#(3)-1,D6
ACTUALIZA4:
	MOVE.L	Txt2Ptr,A1		; Name shadow of the bank (RendTabCheck).
	MOVE.L	ScreenPtr,A4		; Screen of the bank (RendTabCheck).
	MOVE.L	GfxCaPtr,A5		; Cache bank in use (RendTabCheck).

	LEA	$DFF002,A6
ESPBLTA2:BTST	#$E,(A6)
	BNE.S	ESPBLTA2
	MOVE.W	#$0DFC,$40-2(A6)	; Datos para Blitter.
	MOVE.W	#$8000,$42-2(A6)
	MOVE.W	#0,$64-2(A6)
	MOVE.W	#0,$62-2(A6)
	MOVE.W	#32-2,$66-2(A6)
	MOVE.L	#-1,$44-2(A6)

	MOVE.W	#(32*4*8)-32,D5
	MOVE.W	#(32*$40)+1,D3
	MOVEQ	#$E,D7

;;;	MOVEQ	#(3)-1,D6		; Est� mas arriba.
COPIABUCB2:
	MOVEQ	#(8)-1,D0
COPIABUCB1Z:
	MOVE.W	#(32/2)-1,D4
COPIABUCBZ:
	MOVE.W	(A0)+,D2
	MOVE.W	D2,(A1)+
	MOVEQ	#0,D1
	MOVE.B	D2,D1
	LSL.W	#3,D1
	LEA	(A5,D1.W*8),A2
	LSR.W	#8,D2
	LSL.W	#3,D2
	LEA	(A5,D2.W*8),A3
ESPBLTPBZ:
	BTST	D7,(A6)
	BNE.S	ESPBLTPBZ
	MOVEM.L	A2-A4,$4C-2(A6)
	MOVE.W	D3,$58-2(A6)
	ADDQ	#2,A4
	DBF	D4,COPIABUCBZ
	ADD.W	D5,A4
	DBF	D0,COPIABUCB1Z
	ADD.W	SumaBpl(PC),A5
	DBF	D6,COPIABUCB2
	RTS
; -----------------------------<

	CNOP	0,8
; ----------------------------->  Crea Copper con Spites de 16*16.
SPRADD=68
IMPSPR:
SPR16:
	LEA	TABLASPR(PC),A0
	MOVEQ	#(4*8)-1,D0
	MOVEQ	#0,D1
	MOVEQ	#0,D2
	MOVEQ	#0,D3
	MOVEQ	#0,D4
	MOVEQ	#0,D5
	MOVEQ	#0,D6
	MOVEQ	#0,D7
SPRTABBUC:
	MOVEM.L	D1-D7,(A0)
	MOVEM.L	D1-D7,(7*4)(A0)
	ADD.W	#(7*4*2),A0
	DBF	D0,SPRTABBUC

	LEA	TABLASPR2(PC),A0
	MOVE.L	#$04040404,D1
	MOVE.L	D1,D2
	MOVE.L	D1,D3
	MOVE.L	D1,D4
	MOVE.W	#(4*8),D5
	MOVEQ	#7-1,D0
SPRTABBUC2:
	MOVEM.L	D1-D4,(A0)
	MOVEM.L	D1-D4,(4*4)(A0)
	ADD.W	D5,A0
	DBF	D0,SPRTABBUC2

	MOVE.L	NEXTCOL,A3
	MOVE.L	8(A3),A0	 ; Lineas de Copper a restaurar.
	MOVE.L	#$01A00000,D0
	MOVE.L	D0,D1
	MOVE.L	D0,D2
	MOVE.L	D0,D3
SPRTABBUC3:
	MOVE.L	(A0)+,D7
	BEQ.S	FINSPRTAB3
	MOVE.L	D7,A1
	MOVEM.L	D0-D3,(A1)
	BRA.S	SPRTABBUC3
FINSPRTAB3:

	LEA	REGS(PC),A3
	LEA	DIRVRAM,A0
	MOVE.L	A0,A1
	ADD.L	PVDP5(A3),A0	; Coordenadas sprites.
	TST.B	SnapOK			; Mid-frame snapshot (MiraInterSnap).
	BEQ.S	ImpSprNoSnap
	LEA	SprSnap+512,A0
ImpSprNoSnap:
	LEA	TABLASPR(PC),A6	; Tabla de lineas usadas por sprits.
	MOVE.L	NEXTCOL,A3
	MOVE.L	4(A3),A2	; Inicio Copper. (Coor: -15)
	MOVE.L	8(A3),A5	; Lineas de Copper a restaurar.
	MOVE.L	#$40000,D4

	LEA	REGS(PC),A1
	BTST	#1,DVDP1(A1)	; Mira si es imprimir spr de 8*8 o 16*16
	BEQ	SPR8

	IFD	TRACE
	TRVLOG	$FE,SplitOK
	ENDC
	MOVE.L	GFXSPR,A1	; Sprites en formato Amiga.
	MOVE.W	#32-1,D6
	MOVE.W	#0,SprWinLo		; Whole screen...
	MOVE.W	#$7FFF,SprWinHi
	SF	SprPass2
	TST.B	SplitOK
	BEQ.S	SPR16BUC
	MOVE.L	A0,SprSatM		; ...or the top snapshot above the
	LEA	SprSnapT+512,A0		; split, then (FINSPR16) the main one
	MOVE.W	SprSplit,SprWinHi	; below it.
	ADD.W	#14,SprWinHi
	ST	SprPass2
	TST.L	GFXSPRT			; Top table's own pattern slots.
	BEQ.S	SPR16BUC
	MOVE.L	GFXSPRT,A1
SPR16BUC:
	MOVEM.L	SPRDATS(PC),D0-D3

	MOVEQ	#0,D5
	MOVE.B	(A0)+,D0	; MSX Y
	CMP.B	#208,D0
	BEQ.S	NOMASPR
	ADD.B	#15,D0		; �Se ve en pantalla?
	CMP.W	#(192+15),D0
	BGE.S	OTROSPRI
	CMP.W	SprWinLo,D0		; In this pass's part of the screen?
	BLT	OTROSPRI
	CMP.W	SprWinHi,D0
	BGE	OTROSPRI

	MOVE.B	D0,D5
	ADD.B	#INIPANT-15+3,D0 ; Suma Coor Y , �Se ve en pantalla?
	BCS.S	OTROSPRI

	SUBQ.B	#2,D0
	LSL.W	#8,D0		; Coor Y inicial Amiga.
	MOVE.B	(A0)+,D0	; MSX X

	MOVE.W	D0,D1
	ADD.W	#$1000,D1
	BCC.S	NOSALPAN
	MOVE.W	#$FF00,D1
NOSALPAN:
	SF	D1
	LSR.B	#1,D0
	ROXL.B	#1,D1		; Amiga Y final y bit 0 de X

	TST.B	1(A0)		; �Modo Coor. X=X-32?
	BPL.S	SPRNONEG
	SUB.B	#16,D0
SPRNONEG:
	ADD.B	#$50,D0		; Amiga X  (Amiga Y,X en .w)

	MOVEQ	#8-1,D7
	LEA	-1(A6,D5.W),A4
CHESPRBUC:
	TST.L	(A4)
	BNE.S	NOSPRLIBRE
	TST.L	14(A4)
	BEQ.S	SPRLIBRE
NOSPRLIBRE:
	ADD.W	#(192+16+16),A4
	ADD.L	D4,D0
	ADD.L	D4,D0
	ADD.L	D4,D1
	ADD.L	D4,D1
	ADD.L	D4,D2
	ADDQ.B	#1,D3
	DBF	D7,CHESPRBUC
OTROSPR:
	ADDQ.W	#2,A0
	DBF	D6,SPR16BUC
NOMASPR:
	BRA	FINSPR16

	CNOP	0,8
OTROSPRI:
	ADDQ.W	#3,A0
	DBF	D6,SPR16BUC
	BRA	FINSPR16

	CNOP	0,8
SPRLIBRE:
	LEA	(TABLASPR2.W,PC,D5.W),A3
	TST.B	(A3)
	BNE.S	CONTSPR
	TST.B	-1(A3)
	BEQ.S	OTROSPR
	SUBQ.W	#1,A3
	SUBQ.W	#1,D5
CONTSPR:
	SUBQ.B	#1,(A3)

;;	MOVE.L	D0,(A4)
;;	MOVEP.L	D0,05(A4)
;;	MOVEP.L	D0,11(A4)

	MOVE.L	D0,(A4)+
	MOVE.L	D0,(A4)+
	MOVE.L	D0,(A4)+
	MOVE.L	D0,(A4)+
	MOVE.W	D0,(A4)

	MULU	#SPRADD,D5
	LEA	(A2,D5.W),A4	; Coge Direcci�n Y del Copper.

	MOVEQ	#0,D5
	MOVE.B	(A3),D5
	LSL.W	#4,D5
	ADD.W	D5,A4
	MOVE.L	A4,(A5)+

	MOVE.B	(A0)+,D5
	AND.W	#$00FC,D5
	MULU	#9,D5
	LEA	(A1,D5.W*2),A3	; Coge puntero Gfx Sprit.
	TST.B	-3(A3)
	BEQ.S	NOSUMAS
	ADD.W	#$1200,A3
NOSUMAS:
	MOVE.B	(A0)+,D5
	AND.W	#$000F,D5	; �Es de color trasparente?
	BNE.S	NOSPRTRAS
	LEA	(-18*4)(A1),A3
NOSPRTRAS:
	LSR.B	#1,D3
	BCC.S	NOSPR2
	SUBQ.W	#2,A3
	ADD.L	#$20000,D3
NOSPR2:
	SUBQ.B	#1,D3
	BMI.S	SPRBIEN
RESTASPR:
	ADD.L	D4,D3
	ADD.L	D4,D3
	DBF	D3,RESTASPR
SPRBIEN:
	MOVE.W	(MSX2Pal.W,PC,D5.W*2),D3
	MOVE.W	A3,D2
	MOVEM.L	D0-D3,(A4)
	DBF	D6,SPR16BUC
FINSPR16:
	TST.B	SprPass2		; Split: now the part below it.
	BEQ.S	FinSpr16b
	SF	SprPass2
	MOVE.L	SprSatM,A0
	MOVE.W	SprSplit,SprWinLo
	MOVE.W	#$7FFF,SprWinHi
	MOVE.W	#32-1,D6
	MOVE.L	GFXSPR,A1
	BRA	SPR16BUC
FinSpr16b:
	CLR.L	(A5)+
	MOVE.L	NEXTCOL,A4
	MOVE.L	ACTUCOL,NEXTCOL
	MOVE.L	A4,ACTUCOL
	LEA	REGS(PC),A3
NOPONER2:
	CMP.B	#$1A,$DFF006	; Mira Timming Y.
	BEQ.S	NOPONER2
	MOVE.L	(A4),$DFF084
	MOVE.L	(A4),NEXTCOPP
	RTS

	CNOP	0,8
SPRDATS:
	DC.L	$01400000	; Usado para Control 1.
	DC.L	$01420000	; Usado para Control 2.
	DC.L	$01220000	; Usado para Dir. Gfx Sprit.
	DC.L	$01A20000	; Usado para Colores Sprit.

	CNOP	0,8
MSX1PAL:DC.W	$0000,$0000,$02C2,$06E6
	DC.W	$022E,$046E,$0A22,$04CE
	DC.W	$0E22,$0E66,$0CC2,$0CC8
	DC.W	$0282,$0C4A,$0AAA,$0EEE

	CNOP	0,8
MSX2Pal:	DC.W	$0000,$0000,$02C2,$06E6
	DC.W	$022E,$046E,$0A22,$04CE
	DC.W	$0E22,$0E66,$0CC2,$0CC8
	DC.W	$0282,$0C4A,$0AAA,$0EEE

	CNOP	0,8
GFXSPR:		DC.L	NOSPRIT+(24*4)
GFXSPR8:	DC.L	NOSPRIT+(24*4)
NEXTCOL:	DC.L	COPSPRDATB
ACTUCOL:	DC.L	COPSPRDAT
DATOSPR:	DC.L	0
COPSPRDAT:
	DC.L	COPPER2
	DC.L	COPSPR2
	DC.L	TABLASPR3A
COPSPRDATB:
	DC.L	COPPER2B
	DC.L	COPSPR2B
	DC.L	TABLASPR3B
	DC.L	0

	DC.L	0
TABLASPR:	DS.B	(32+192)*8
	CNOP	0,8
	DC.L	0
TABLASPR2:	DCB.B	32+192,4
	CNOP	0,8
	DC.L	0
TABLASPR3A:	DS.B	38*4
	CNOP	0,8
	DC.L	0
TABLASPR3B:	DS.B	38*4
	DC.L	0,0
; -----------------------------<

	CNOP	0,8
; ----------------------------->  Crea Copper con Spites de 8*8.
SPR8:
	MOVE.L	GFXSPR8,A1	; Sprites en formato Amiga.
	MOVE.W	#32-1,D6
SPR8BUC:
	MOVEM.L	SPRDATS(PC),D0-D3

	MOVEQ	#0,D5
	MOVE.B	(A0)+,D0	; MSX Y
	CMP.B	#208,D0
	BEQ.S	NOMASPR8
	ADD.B	#15,D0		; �Se ve en pantalla?
	CMP.W	#(192+15),D0
	BGE.S	OTROSPRI8

	MOVE.B	D0,D5
	ADD.B	#INIPANT-15+3,D0 ; Suma Coor Y , �Se ve en pantalla?
	BCS.S	OTROSPRI8

	SUBQ.B	#2,D0
	LSL.W	#8,D0		; Coor Y inicial Amiga.
	MOVE.B	(A0)+,D0	; MSX X

	MOVE.W	D0,D1
	ADD.W	#$0800,D1
	BCC.S	NOSALPAN8
	MOVE.W	#$FF00,D1
NOSALPAN8:
	SF	D1
	LSR.B	#1,D0
	ROXL.B	#1,D1		; Amiga Y final y bit 0 de X

	TST.B	1(A0)		; �Modo Coor. X=X-32?
	BPL.S	SPRNONEG8
	SUB.B	#16,D0
SPRNONEG8:
	ADD.B	#$50,D0		; Amiga X  (Amiga Y,X en .w)

	MOVEQ	#8-1,D7
	LEA	-1(A6,D5.W),A4
CHESPRBUC8:
	TST.L	(A4)
	BNE.S	NOSPRLIBRE8
	TST.L	6(A4)
	BEQ.S	SPRLIBRE8
NOSPRLIBRE8:
	ADD.W	#(192+16+16),A4
	ADD.L	D4,D0
	ADD.L	D4,D0
	ADD.L	D4,D1
	ADD.L	D4,D1
	ADD.L	D4,D2
	ADDQ.B	#1,D3
	DBF	D7,CHESPRBUC8
OTROSPR8:
	ADDQ.W	#2,A0
	DBF	D6,SPR8BUC
NOMASPR8:
	BRA	FINSPR8

	CNOP	0,8
OTROSPRI8:
	ADDQ.W	#3,A0
	DBF	D6,SPR8BUC
	BRA	FINSPR8

	CNOP	0,8
SPRLIBRE8:
	LEA	(TABLASPR2.W,PC,D5.W),A3
	TST.B	(A3)
	BNE.S	CONTSPR8
	TST.B	-1(A3)
	BEQ.S	OTROSPR8
	SUBQ.W	#1,A3
	SUBQ.W	#1,D5
CONTSPR8:
	SUBQ.B	#1,(A3)

;;	MOVE.W	D0,(A4)
;;	MOVEP.L	D0,2(A4)

	MOVE.L	D0,(A4)+
	MOVE.L	D0,(A4)+
	MOVE.W	D0,(A4)

	MULU	#SPRADD,D5
	LEA	(A2,D5.W),A4	; Coge Direcci�n Y del Copper.

	MOVEQ	#0,D5
	MOVE.B	(A3),D5
	LSL.W	#4,D5
	ADD.W	D5,A4
	MOVE.L	A4,(A5)+

	MOVEQ	#0,D5
	MOVE.B	(A0)+,D5
	MULU	#9*2,D5
	LEA	(A1,D5.W*2),A3	; Coge puntero Gfx Sprit.
	TST.B	-3(A3)
	BEQ.S	NOSUMAS8
	ADD.W	#$1200*2,A3
NOSUMAS8:
	MOVE.B	(A0)+,D5
	AND.W	#$000F,D5	; �Es de color trasparente?
	BNE.S	NOSPRTRAS8
	LEA	(-9*4)(A1),A3
NOSPRTRAS8:
	LSR.B	#1,D3
	BCC.S	NOSPR28
	SUBQ.W	#2,A3
	ADD.L	#$20000,D3
NOSPR28:
	SUBQ.B	#1,D3
	BMI.S	SPRBIEN8
RESTASPR8:
	ADD.L	D4,D3
	ADD.L	D4,D3
	DBF	D3,RESTASPR8
SPRBIEN8:
	MOVE.W	(MSX2Pal.W,PC,D5.W*2),D3
	MOVE.W	A3,D2
	MOVEM.L	D0-D3,(A4)
	DBF	D6,SPR8BUC
FINSPR8:
	CLR.L	(A5)+
	MOVE.L	NEXTCOL,A4
	MOVE.L	ACTUCOL,NEXTCOL
	MOVE.L	A4,ACTUCOL
	LEA	REGS(PC),A3
;	TST.B	ACTODO(A3)
;	BNE.S	NOPONER28
;	MOVE.L	(A4),$DFF084
;NOPONER28:
	MOVE.L	(A4),NEXTCOPP
	RTS

	CNOP	0,8
; ----------------------------->  Transforma Sprites 16*16 MSX en Sprites Amiga.
PONSPR:	MACRO
	MOVE.B	\1,\2+12(A4)
	LSR.W	#8,\1
	MOVE.B	\1,\2+08(A4)
	SWAP	\1
	MOVE.B	\1,\2+04(A4)
	LSR.W	#8,\1
	MOVE.B	\1,\2+00(A4)
	ENDM
TRANSSPR16:
	LEA	REGS(PC),A3
	MOVE.L	GFXSPR,A1
	LEA	DIRVRAM,A0
	ADD.L	PVDP6(A3),A0		; Tabla Gfx Sprits VRAM
	MOVE.W	#64-1,D0
	MOVE.W	#(18*4),D1

	TST.B	ACTSPR(A3)
	BNE	SPRCOPBUC

	LEA	TAB98,A2
	MOVE.L	PVDP6(A3),D2
	LSR.L	#3,D2
	ADD.W	D2,A2

	MOVE.W	#(4*8),D2
SPRCOPBUC2:
	TST.L	(A2)+
	BNE.S	SPRCOPIA
	ADD.W	D2,A0
	ADD.W	D1,A1
	DBF	D0,SPRCOPBUC2
	RTS

	CNOP	0,8
SPRCOPIA:
	MOVE.L	A1,A4
	NOT.B	-3(A1)
	BEQ.S	NOSUMAS2
	ADD.W	#$1200,A4
NOSUMAS2:
	MOVEM.L	(A0)+,D4-D7
	PONSPR	D4,00
	PONSPR	D5,16
	PONSPR	D6,32
	PONSPR	D7,48
	MOVEM.L	(A0)+,D4-D7
	PONSPR	D4,01
	PONSPR	D5,17
	PONSPR	D6,33
	PONSPR	D7,49
	ADD.W	D1,A1
;;;	CLR.L	-4(A2)
	DBF	D0,SPRCOPBUC2
	RTS

	CNOP	0,8
SPRCOPBUC:
	MOVE.L	A1,A4
	NOT.B	-3(A1)
	BEQ.S	NOSUMAS1
	ADD.W	#$1200,A4
NOSUMAS1:
	MOVEM.L	(A0)+,D4-D7
	PONSPR	D4,00
	PONSPR	D5,16
	PONSPR	D6,32
	PONSPR	D7,48
	MOVEM.L	(A0)+,D4-D7
	PONSPR	D4,01
	PONSPR	D5,17
	PONSPR	D6,33
	PONSPR	D7,49
	ADD.W	D1,A1
	DBF	D0,SPRCOPBUC
	SF	ACTSPR(A3)
	RTS


	CNOP	0,8
CEROSRS:DS.L	20
; -----------------------------<

	CNOP	0,8
; ----------------------------->  Transforma Sprites 8*8 MSX en Sprites Amiga.
PONSPR8:MACRO
	MOVE.B	\1,\2+12(A4)
	LSR.W	#8,\1
	MOVE.B	\1,\2+08(A4)
	SWAP	\1
	MOVE.B	\1,\2+04(A4)
	LSR.W	#8,\1
	MOVE.B	\1,\2+00(A4)
	ENDM
TRANSSPR8:
	LEA	REGS(PC),A3
	MOVE.L	GFXSPR8,A1
	LEA	DIRVRAM,A0
	ADD.L	PVDP6(A3),A0		; Tabla Gfx Sprits VRAM
	MOVE.W	#64-1,D0
	MOVE.W	#(18*4*2),D1

	TST.B	ACTSPR(A3)
	BNE	SPRCOPBUC8

	LEA	TAB98,A2
	MOVE.L	PVDP6(A3),D2
	LSR.L	#3,D2
	ADD.W	D2,A2

	MOVE.W	#(4*8),D2
SPRCOPBUC28:
	TST.L	(A2)+
	BNE.S	SPRCOPIA8
	ADD.W	D2,A0
	ADD.W	D1,A1
	DBF	D0,SPRCOPBUC28
	RTS

	CNOP	0,8
SPRCOPIA8:
	MOVE.L	A1,A4
	NOT.B	(9*4*3)-3(A1)
	NOT.B	(9*4*2)-3(A1)
	NOT.B	(9*4)-3(A1)
	NOT.B	-3(A1)
	BEQ.S	NOSUMAS28
	ADD.W	#$1200*2,A4
NOSUMAS28:
	MOVEM.L	(A0)+,D4-D7
	PONSPR8	D4,00
	PONSPR8	D5,16
	PONSPR8	D6,36
	PONSPR8	D7,52
	MOVEM.L	(A0)+,D4-D7
	PONSPR8	D4,72
	PONSPR8	D5,88
	PONSPR8	D6,108
	PONSPR8	D7,124
	ADD.W	D1,A1
;;;	CLR.L	-4(A2)
	DBF	D0,SPRCOPBUC28
	RTS

	CNOP	0,8
SPRCOPBUC8:
	MOVE.L	A1,A4
	NOT.B	(9*4*3)-3(A1)
	NOT.B	(9*4*2)-3(A1)
	NOT.B	(9*4)-3(A1)
	NOT.B	-3(A1)
	BEQ.S	NOSUMAS18
	ADD.W	#$1200*2,A4
NOSUMAS18:
	MOVEM.L	(A0)+,D4-D7
	PONSPR8	D4,00
	PONSPR8	D5,16
	PONSPR8	D6,36
	PONSPR8	D7,52
	MOVEM.L	(A0)+,D4-D7
	PONSPR8	D4,72
	PONSPR8	D5,88
	PONSPR8	D6,108
	PONSPR8	D7,124
	ADD.W	D1,A1
	DBF	D0,SPRCOPBUC8
	SF	ACTSPR(A3)
	RTS
; -----------------------------<

; -----------------------------> Borra actualizaci�n de tabla de Sprites
	CNOP	0,8
BorraSprTab:
	LEA	TAB98(PC),A6
	MOVE.L	PVDP6(A3),D0		; Tabla Gfx Sprites VRAM
	LSR.L	#3,D0
	ADD.W	#256,D0
	ADD.W	D0,A6

	MOVEM.L	CEROSRS(PC),D0-D7/A0-A5
	MOVEM.L	D0-D7/A0-A5,-(A6)
	MOVEM.L	D0-D7/A0-A5,-(A6)
	MOVEM.L	D0-D7/A0-A5,-(A6)
	MOVEM.L	D0-D7/A0-A5,-(A6)
	MOVEM.L	D0-D7,-(A6)
	RTS
; -----------------------------<


; ---------------------	; F F ; ---------------- ;
; ---------------------	; I I ; ---------------- ;
; ---------------------	; N N ; ---------------- ;







PagRead=-32
PagWrite=$10
Restas=-96+4
Desbor=-160-Restas

Punts=PagRead
Tipos=PagWrite

	CNOP	0,8
	DS.L	16


		DC.W	0
PauseDat=-$146	DC.B	0	;-$146
PauseKey=-$145	DC.B	0	;-$145

DesLinY=-$144	DC.W	0	;-$144(A3)
HaltDat=-$142	DC.B	0	;-$142(A3)
fps60Dat=-$141	DC.B	0	;-$141(A3)
RetOut=-$140	DC.L	0	;-$140(A3)
CurLine=-$13C	DC.W	0	;-$13C(A3)
HorLine=-$13A	DC.W	0	;-$13A(A3)
;			 ^ ^ ^ ^
	DC.W	0	;-$13C(A3)
	DC.B	0	;-$13A(A3)	PauseKey
	DC.B	0	;-$139(A3)	PauseDat

	DC.B	0	;-$138(A3)	Contador 2
	DC.B	0	;-$137(A3)	KanjiD9
	DC.B	0	;-$136(A3)	KanjiD8
	DC.B	0	;-$135(A3)	KanjiCnt

	DC.L	0	;-$134(A3)	RVDP	Salto Rutina Impresi�n

	DC.L	0	; -304(A3)	PVDP2
	DC.L	0	; -300(A3)	PVDP3
	DC.L	0	; -296(A3)	PVDP4
	DC.L	0	; -292(A3)	PVDP5
	DC.L	0	; -288(A3)	PVDP6
	DC.L	0	; -284(A3)	PVDP3B
	DC.L	0	; -280(A3)	PVDP4B

	DS.L	16	; -276(A3)	BUFER	(16*4 Bytes)
	DC.W	0	; -212(A3)	Contador 1
	DC.B	0	; -210(A3)	PRINTER
	DC.B	0	; -209(A3)	R
	DC.B	0	; -208(A3)	DFFFF
	DC.B	0	; -207(A3)	DInsBuc
	DC.W	0	; -206(A3)	FLASH
	DC.W	0	; -204(A3)	DVDP3
	DC.W	0	; -202(A3)	DVDP5
	DC.B	0	; -200(A3)	DB5
	DC.B	0	; -199(A3)	DB4
	DC.B	0	; -198(A3)	DVDPARG
	DC.B	0	; -197(A3)	VDPIntY
	DC.W	0	; -196(A3)	DVDPSX
	DC.W	0	; -194(A3)	DVDPSY
	DC.W	0	; -192(A3)	DVDPDX
	DC.W	0	; -190(A3)	DVDPDY
	DC.W	0	; -188(A3)	DVDPNX
	DC.W	0	; -186(A3)	DVDPNY
	DC.B	0	; -184(A3)	DVDP8
	DC.B	0	; -183(A3)	DVDP9
	DC.B	0	; -182(A3)	DVDP2
	DC.B	0	; -181(A3)	VDPLINY
	DC.W	0	; -180(A3)	DATPAL
	DC.B	0	; -178(A3)	VDPAdjust
	DC.B	0	; -177(A3)	VDPREGL
	DC.B	0	; -176(A3)	VDPREGP
	DC.B	0	; -175(A3)	VDPREGE
	DC.L	0	; -174(A3)	DirModoChg
	DC.L	0	; -170(A3)	Ant_PC
	DC.W	0	; -166(A3)	RESAB
	DC.B	3	; -164(A3)	DFC
	DC.B	2	; -163(A3)	DFD
	DC.B	1	; -162(A3)	DFE
	DC.B	0	; -161(A3)	DFF

	DC.L	0,0	; -160(A3)	DIRPAG0		Desbor.
	DC.L	0,0	; -152(A3)	DIRPAG1
	DC.L	0,0	; -144(A3)	DIRPAG2
	DC.L	0,0	; -136(A3)	DIRPAG3
	DC.L	0,0	; -128(A3)
	DC.L	0,0	; -120(A3)
	DC.L	0,0	; -112(A3)
	DC.L	0,0	; -104(A3)

	DS.L	16	; -96(A3)	Resta0+4	Restas.

	DC.L	0	; -32(A3)	PagRead
	DC.L	0	; -28(A3)
	DC.L	0	; -24(A3)
	DC.L	0	; -20(A3)
	DC.L	0	; -16(A3)
	DC.L	0	; -12(A3)
	DC.L	0	; -08(A3)
	DC.L	0	; -04(A3)
REGS:
	DC.W	0	;    (A3)	Cycles
	DC.W	0	;   2(A3)	HL
	DC.W	0	;   4(A3)	BC
	DC.W	0	;   6(A3)	DE
	DC.B	0	;   8(A3)	PAUSA
	DC.B	0	;   9(A3)	RUNINT
	DC.B	0	;  $A(A3)	I
	DC.B	0	;  $B(A3)	IFF
	DC.B	0	;  $C(A3)	D99
	DC.B	0	;  $D(A3)	DA0
	DC.B	0	;  $E(A3)	ESTADO
	DC.B	0	;  $F(A3)	DA8	Slots (Out $A8)

	DC.L	0	; $10(A3)	PagWrite
	DC.L	0	; $14(A3)		
	DC.L	0	; $18(A3)		
	DC.L	0	; $1C(A3)		
	DC.L	0	; $20(A3)
	DC.L	0	; $24(A3)		
	DC.L	0	; $28(A3)		
	DC.L	0	; $2C(A3)		

	DC.W	0	; $30(A3)	MaskROM3
	DC.W	0	; $32(A3)	MaskROM3

	DC.B	0	; $34(A3)	PAA
	DC.B	0	; $35(A3)	ACTODO
	DC.B	0	; $36(A3)	DVDP0
	DC.B	0	; $37(A3)	DVDP1

	DC.L	0	; $38(A3)	VRAM

	DC.B	0	; $3C(A3)	DATOJOY1
	DC.B	0	; $3D(A3)	DATOJOY2
	DC.B	0	; $3E(A3)	LEEJOY2
	DC.B	0	; $3F(A3)	ACTSPR

	DC.B	$FF	; $40(A3)	Teclado MSX 0	(KEY)
	DC.B	$FF	; $41(A3)	Teclado MSX 1
	DC.B	$FF	; $42(A3)	Teclado MSX 2
	DC.B	$FF	; $43(A3)	Teclado MSX 3
	DC.B	$FF	; $44(A3)	Teclado MSX 4
	DC.B	$FF	; $45(A3)	Teclado MSX 5
	DC.B	$FF	; $46(A3)	Teclado MSX 6
	DC.B	$FF	; $47(A3)	Teclado MSX 7
	DC.B	$FF	; $48(A3)	Teclado MSX 8
	DCB.B	7,$FF

	DC.L	SPRMODE5; $50(A3)	RSPR  Emulaci�n MSX2 Sprits.
	DC.L	0	; $54(A3)	MapROMBase1
	DC.L	0	; $58(A3)	MapROMBase2
	DC.W	0	; $5C(A3)	MaskROM
	DC.W	0	; $5E(A3)	MaskROM2

	DS.B	16	; $60(A3)	PSG  (Sounds 0-15)

	DC.W	0	; $70(A3)	CONTPILA
	DC.B	0	; $72(A3)	Int_EI_H
	DC.B	0	; $73(A3)	Int_EI_V
	DC.W	0	; $74(A3)	Relen
	DC.B	0	; $76(A3)	IntDesbor
	DC.B	0	; $77(A3)
	DC.B	0	; $78(A3)	INTERDAT
	DC.B	0	; $79(A3)	CapsLock
	DC.B	0	; $7A(A3)	SCRMODO
	DC.B	0	; $7B(A3)	ACTODOB

	DC.B	0	; $7C(A3)	Flags_Par  (TAB_Flags)
	DC.B	0	; $7D(A3)	Flags_Push
	DC.B	0	; $7E(A3)	Flags_Pop
	DC.B	0	; $7F(A3)	Flags_DAA

	DS.B	$480	; $80(A3)	(TAB_Flags)

; -----------------------------------------------

			; $500(A3) / -$20(A4)  Memory Mapper.
	DC.W	0,0,0,0
	DC.W	0,0,0,0
	DC.W	0,0,0,0
	DC.W	0,0,0,0
SLOT0:			; $520(A3)		SLOTS:
	DC.L	NOMEM-$0000,NORAM-$0000
	DC.L	NOMEM-$4000,NORAM-$4000
	DC.L	NOMEM-$8000,NORAM-$8000
	DC.L	NOMEM-$C000,NORAM-$C000
SLOT1:			; $540(A3)
	DC.L	NOMEM-$0000,NORAM-$0000
	DC.L	NOMEM-$4000,NORAM-$4000
	DC.L	NOMEM-$8000,SCCKO-$8000
	DC.L	NOMEM-$C000,NORAM-$C000
SLOT2:			; $560(A3)
	DC.L	NOMEM-$0000,NORAM-$0000
	DC.L	NOMEM-$4000,NORAM-$4000
	DC.L	NOMEM-$8000,SCCKO-$8000
	DC.L	NOMEM-$C000,NORAM-$C000
SLOT3:			; $580(A3)
	DC.L	RAM03-$0000,RAM03-$0000
	DC.L	RAM02-$4000,RAM02-$4000
	DC.L	RAM01-$8000,RAM01-$8000
	DC.L	RAM00-$C000,RAM00-$C000

			; $5A0(A3) / -$20(A4)  Restas
	DC.W	0,0,0,0
	DC.W	0,0,0,0
	DC.W	0,0,0,0
	DC.W	0,0,0,0
			; $5C0(A3) (A4)	SUBSLOTS:
SUBSLOT0:
	DC.L	ROM20-$0000,NORAM-$0000
	DC.L	ROM21-$4000,NORAM-$4000
	DC.L	NOMEM-$8000,NORAM-$8000
	DC.L	ESROM-$C000,NORAM-$C000
SUBSLOT1:		; $5E0(A3)
	DC.L	ROM22-$0000,NORAM-$0000
	DC.L	NOMEM-$4000,NORAM-$4000
	DC.L	NOMEM-$8000,NORAM-$8000
	DC.L	ESROM-$C000,NORAM-$C000
SUBSLOT2:		; $600(A3)
	DC.L	NOMEM-$0000,NORAM-$0000
	DC.L	NOMEM-$4000,NORAM-$4000
	DC.L	NOMEM-$8000,NORAM-$8000
	DC.L	ESROM-$C000,NORAM-$C000
SUBSLOT3:		; $620(A3)
	DC.L	NOMEM-$0000,NORAM-$0000
	DC.L	NOMEM-$4000,NORAM-$4000
	DC.L	NOMEM-$8000,NORAM-$8000
	DC.L	ESROM-$C000,NORAM-$C000

;   ---------------------------------------------------------------------

	REPT	8
	DC.L	OtraInstr	; $640(A3)	Slot 0 Mapper Base
	DC.L	OtraInstr	; $660(A3)	Slot 1 Mapper Base
	DC.L	OtraInstr	; $680(A3)	Slot 2 Mapper Base
	DC.L	OtraInstr	; $6A0(A3)	Slot 3 Mapper Base
	ENDR

;   ---------------------------------------------------------------------

	DC.L	0	; $6C0(A3)	DIRPILA
	DC.B	0	; $6C4(A3)	DVDP7
	DC.B	0	; $6C5(A3)	DVDPC
	DC.B	0	; $6C6(A3)	DVDPCL
	DC.B	0	; $6C7(A3)	DVDPS2
	DC.W	0	; $6C8(A3)	MMAND
	DC.B	0	; $6CA(A3)	MMOR
	DC.B	0	; $6CB(A3)	DVDPS1
	DC.W	0	; $6CC(A3)	CONTA2C
	DC.W	0	; $6CE(A3)	CONTA2CX
	DC.L	0	; $6D0(A3)	DVDPSX2 y DVDPSY2
	DC.L	0	; $6D4(A3)	DVDPSX2 y DVDPSY2
	DC.L	0	; $6D8(A3)	DVDPSX2 y DVDPSY2
	DC.L	0	; $6DC(A3)	MSXVideoMode
	DC.B	0	; $6E0(A3)	DVDPREG
	DC.B	0	; $6E1(A3)	COLREAD
	DC.W	0	; $6E2(A3)	PetInt38
	DC.B	0	; $6E4(A3)	COSPR2
	DC.B	0	; $6E5(A3)	Tipo_Int
	DC.B	0	; $6E6(A3)	ModoInt
	DC.B	0	; $6E7(A3)	MULTEC
	DC.B	0	; $6E8(A3)	SCRFREC
	DC.B	0	; $6E9(A3)
	DC.W	0	; $6EA(A3)	CONTA3CX
	DC.B	0	; $6EC(A3)	D7C
	DC.B	0	; $6ED(A3)	Modo_EI
	DC.B	0	; $6EE(A3)	ScanningY
	DC.B	0	; $6EF(A3)	Modo060
	DC.L	0	; $6F0(A3)	(was CPUCopyBufer: see CPUCopyBuf)
	DC.B	0	; $6F4(A3)	DatDAA
	DC.B	0	; $6F5(A3)
	DC.W	0	; $6F6(A3)	DVDP4

;	*=*=*  USA POR LA PARTE DE ARRIBA *=*=*   Haz caso Juan.

;   ---------------------------------------------------------------------

FREGS:	DS.B	$800-(FREGS-REGS)
;	 ------------------------------------------------------------
;	**  Tablas de instrucciones del Z-80A Simulado por MC68020  **
;	 ------------------------------------------------------------
INSTR:			; $800(A3)

	IFEQ	Key_ON

	DC.L	NOP,LDBCN,LDBCA,INCBC,INCB,DECB,LDBN,IRLCA	; 00
	DC.L	EXAF,ADDHLBC,LDABC,DECBC,INCC,DECC,LDCN,IRRCA	; 08
	DC.L	DJNZ,LDDEN,LDDEA,INCDE,INCD,DECD,LDDN,IRRA	; 10
	DC.L	JR,ADDHLDE,LDADE,DECDE,INCE,DECE,LDEN,IRLA	; 18
	DC.L	JRZ,LDHLN,LDMHL,INCHL,INCH,DECH,LDHN,DAA	; 20
	DC.L	JRNZ,ADDHLHL,LDHLM,DECHL,INCL,DECL,LDLN,ICPL	; 28
	DC.L	JRNC,LDSPN,LDMA,INCSP,INCHLM,DECHLM,LDHLMN,SCF	; 30
	DC.L	JRC,ADDHLSP,LDAM,DECSP,INCA,DECA,LDAN,CCF	; 38
	DC.L	LDBB,LDCB,LDBD,LDBE,LDBH,LDBL,LDBHL,LDBA	; 40
	DC.L	LDBC,LDCC,LDCD,LDCE,LDCH,LDCL,LDCHL,LDCA	; 48
	DC.L	LDDB,LDDC,LDDD,LDDE,LDDH,LDDL,LDDHL,LDDA	; 50
	DC.L	LDEB,LDEC,LDED,LDEE,LDEH,LDEL,LDEHL,LDEA	; 58
	DC.L	LDHB,LDHC,LDHD,LDHE,LDHH,LDHL,LDHHL,LDHA	; 60
	DC.L	LDLB,LDLC,LDLD,LDLH,LDLE,LDLL,LDLHL,LDLA	; 68
	DC.L	LDHLB,LDHLC,LDHLD,LDHLE,LDHLH,LDHLL,HALT,LDHLA	; 70
	DC.L	LDAB,LDAC,LDAD,LDAE,LDAH,LDAL,LDAHL,LDAA	; 78
	DC.L	ADDAB,ADDAC,ADDAD,ADDAE,ADDAH,ADDAL,ADDAHL,ADDAA; 80
	DC.L	ADCAB,ADCAC,ADCAD,ADCAE,ADCAH,ADCAL,ADCAHL,ADCAA; 88
	DC.L	SUBB,SUBC,SUBD,SUBE,SUBH,SUBL,SUBHL,SUBA	; 90
	DC.L	SBCB,SBCC,SBCD,SBCE,SBCH,SBCL,SBCHL,SBCA	; 98
	DC.L	ANDB,ANDC,ANDD,ANDE,ANDH,ANDL,ANDHL,ANDA	; A0
	DC.L	XORB,XORC,XORD,XORE,XORH,XORL,XORHL,XORA	; A8
	DC.L	ORB,ORC,ORD,ORE,ORH,ORL,ORHL,ORA		; B0
	DC.L	CPB,CPC,CPD,CPE,CPH,CPL,CPHL,CPA		; B8
	DC.L	RETNZ,POPBC,JPNZ,CALL,CALLNZ,PUSHBC,ADDAN,RST0	; C0
	DC.L	RETZ,IRET,JPZ,RINSCB,CALLZ,JP,ADCAN,RST8	; C8
	DC.L	RETNC,POPDE,JPNC,OUTNA,CALLNC,PUSHDE,SUBN,RST10	; D0
	DC.L	RETC,EXX,JPC,INAN,CALLC,RINSDD,SBCN,RST18	; D8
	DC.L	RETPO,POPHL,JPPO,EXSPHL,CALLPO,PUSHHL,ANDN,RST20; E0
	DC.L	RETPE,JPHL,JPPE,EXDEHL,CALLPE,RINSED,XORN,RST28	; E8
	DC.L	RETP,POPAF,JPP,DI,CALLP,PUSHAF,ORN,RST30	; F0
	DC.L	RETM,LDSPHL,JPM,EI,CALLM,RINSFD,CPN,RST38	; F8
	DS.L	256

	ELSEIF

	DC.L	NOP,LDBCN,LDBCA,INCBC,INCB,DECB,LDBN,IRLCA	; 00
	DC.L	EXAF,ADDHLBC,LDABC,DECBC,INCC,DECC,LDCN,IRRCA	; 08
	DC.L	DJNZ,LDDEN,LDDEA,INCDE,INCD,DECD,LDDN,IRLA	; 10
	DC.L	JR,ADDHLDE,LDADE,DECDE,INCE,DECE,LDEN,IRRA	; 18
	DC.L	JRNZ,LDHLN,LDMHL,INCHL,INCH,DECH,LDHN,DAA	; 20
	DC.L	JRZ,ADDHLHL,LDHLM,DECHL,INCL,DECL,LDLN,ICPL	; 28
	DC.L	JRNC,LDSPN,LDMA,INCSP,INCHLM,DECHLM,LDHLMN,SCF	; 30
	DC.L	JRC,ADDHLSP,LDAM,DECSP,INCA,DECA,LDAN,CCF	; 38
	DC.L	LDBB,LDBC,LDBD,LDBE,LDBH,LDBL,LDBHL,LDBA	; 40
	DC.L	LDCB,LDCC,LDCD,LDCE,LDCH,LDCL,LDCHL,LDCA	; 48
	DC.L	LDDB,LDDC,LDDD,LDDE,LDDH,LDDL,LDDHL,LDDA	; 50
	DC.L	LDEB,LDEC,LDED,LDEE,LDEH,LDEL,LDEHL,LDEA	; 58
	DC.L	LDHB,LDHC,LDHD,LDHE,LDHH,LDHL,LDHHL,LDHA	; 60
	DC.L	LDLB,LDLC,LDLD,LDLE,LDLH,LDLL,LDLHL,LDLA	; 68
	DC.L	LDHLB,LDHLC,LDHLD,LDHLE,LDHLH,LDHLL,HALT,LDHLA	; 70
	DC.L	LDAB,LDAC,LDAD,LDAE,LDAH,LDAL,LDAHL,LDAA	; 78
	DC.L	ADDAB,ADDAC,ADDAD,ADDAE,ADDAH,ADDAL,ADDAHL,ADDAA; 80
	DC.L	ADCAB,ADCAC,ADCAD,ADCAE,ADCAH,ADCAL,ADCAHL,ADCAA; 88
	DC.L	SUBB,SUBC,SUBD,SUBE,SUBH,SUBL,SUBHL,SUBA	; 90
	DC.L	SBCB,SBCC,SBCD,SBCE,SBCH,SBCL,SBCHL,SBCA	; 98
	DC.L	ANDB,ANDC,ANDD,ANDE,ANDH,ANDL,ANDHL,ANDA	; A0
	DC.L	XORB,XORC,XORD,XORE,XORH,XORL,XORHL,XORA	; A8
	DC.L	ORB,ORC,ORD,ORE,ORH,ORL,ORHL,ORA		; B0
	DC.L	CPB,CPC,CPD,CPE,CPH,CPL,CPHL,CPA		; B8
	DC.L	RETNZ,POPBC,JPNZ,JP,CALLNZ,PUSHBC,ADDAN,RST0	; C0
	DC.L	RETZ,IRET,JPZ,RINSCB,CALLZ,CALL,ADCAN,RST8	; C8
	DC.L	RETNC,POPDE,JPNC,OUTNA,CALLNC,PUSHDE,SUBN,RST10	; D0
	DC.L	RETC,EXX,JPC,INAN,CALLC,RINSDD,SBCN,RST18	; D8
	DC.L	RETPO,POPHL,JPPO,EXSPHL,CALLPO,PUSHHL,ANDN,RST20; E0
	DC.L	RETPE,JPHL,JPPE,EXDEHL,CALLPE,RINSED,XORN,RST28	; E8
	DC.L	RETP,POPAF,JPP,DI,CALLP,PUSHAF,ORN,RST30	; F0
	DC.L	RETM,LDSPHL,JPM,EI,CALLM,RINSFD,CPN,RST38	; F8
	DS.L	256

	ENDC

;   ---------------------------------------------------------------------
	DS.L	20
;   ---------------------------------------------------------------------

DREGIN98=(INS+($98*4))-REGS
DREGOUT98=(OUTS+($98*4))-REGS
DREGOUT99=(OUTS+($99*4))-REGS
DREGOUT9A=(OUTS+($9A*4))-REGS

;   ---------------------------------------------------------------------
;  -=====================================================================-
; <***********************************************************************>
;  -=====================================================================-
;   ---------------------------------------------------------------------



	CNOP	0,4
; Line interrupt line reached: FH (S#1 bit 0). With IE1 on (R#0 bit 4) it
; stays up to 7 lines or until S#1 is read, and requests the interrupt.
; With IE1 off it only shows during the matching line, as in openMSX:
; Jailbreak polls FH with IE1 off right after setting R#19, while Zanac EX's
; VBlank handler must not see a match from line 208 (it would take its
; line-interrupt path in VBlank: page 1 shown, sprites off).
InterHor:
	BSET	#0,DVDPS1(A3)		; Petici�n de Interrupci�n Horizontal.
	MOVE.B	#7,PetInt38(A3)		; Petici�n de Interrupci�n.
	BTST	#4,DVDP0(A3)
	BNE.S	InterHorX
	MOVE.B	#2,PetInt38(A3)		; IE1 off: cleared at the next line (1 would
					; clear it here, before the line runs).
InterHorX:
	JMP	([JumpCurLine.W,PC,D1.W*4])

	CNOP	0,8
MiraInter:
	TST.B	BandSplitP		; A split asked for a band here.
	BEQ.S	MiraInterBRet
	JMP	MiraInterBSplit
MiraInterBRet:
	ADDQ.B	#1,CurLine+1(A3)
	MOVE.W	CurLine(A3),D1
	CMP.W	HorLine(A3),D1		; �Generar Line Int.?
	BEQ.S	InterHor
	JMP	([JumpCurLine.W,PC,D1.W*4])

MiraInter0:
	ADDQ.B	#1,RFrame		; (LD A,R)
	SF	S5Valid			; 5th sprite flag: new frame.
	CLR.W	S5Next

;;	SF	PetInt38+1(A3)
;;	BCLR	#7,Estado(A3)		; Petici�n de Interrupci�n Vertical.


	MOVE.B	OverDat,VERPAN+6
	MOVE.B	OverDat,Ver9+6

	MOVE.B	DVDP2(A3),TabRasDATA+1	 ; VDP (2)
	MOVE.B	VDPAdjust(A3),TabRasDATA+3 ; VDP ($12)
	MOVE.B	VDPLinY(A3),TabRasDATA+4 ; VDP ($17)
	OR.B	#$03,TabRasCMDS		 ; Adjust + Scroll Y

	MOVEQ	#0,D1
	SUB.B	VDPLinY(A3),D1
	MOVE.W	D1,DesLinY(A3)
	MOVE.B	VDPLinY(A3),(TabRasDATA+4,D1.W*8) ; VDP ($17)
	MOVE.B	DVDP2(A3),(TabRasDATA+1,D1.W*8)	; VDP (2)
MiraInterBuc:
	ADD.W	#HPeriod,(A3)		; Suma Cyclos de 1 linea.
	BMI.W	MiraInter
	IFD	CORRCHK
	JMP	CorrTest
CorrRet:
	ENDC
	TST.W	PetInt38(A3)
	BNE.S	FastInterRun
	JMP	([A3,D2.W*8])		; Vuelta al Z-80 emul.

	CNOP	0,4
MiraInter255:
	MOVE.W	#(VPeriodPAL-255)*HPeriod,D1	; Suma Cyclos de x lineas PAL.
	BTST	#1,DVDP9(A3)
	BNE.S	EsModoPal
	MOVE.W	#(VPeriodNTSC-255)*HPeriod,D1	; Suma Cyclos de x lineas NTSC.
EsModoPal:
	ADD.W	D1,(A3)
	BMI	MiraInter
	TST.W	PetInt38(A3)
	BNE.S	FastInterRun
	JMP	([A3,D2.W*8])		; Vuelta al Z-80 emul.


	CNOP	0,4
FastInterRun:
	TST.B	PetInt38(A3)
	BEQ	InterRunV

	SUBQ.B	#1,PetInt38(A3)
	BNE.S	FaInRuCon
	BCLR	#0,DVDPS1(A3)		; Quita Petici�n de Interrupci�n Horizontal.
	TST.B	PetInt38+1(A3)
	BNE	InterRunV
	BRA	InterX
FaInRuCon:
	BTST	#4,DVDP0(A3)		; �Interrupci�n Horizontal?
	BNE	InterRun
	TST.B	PetInt38+1(A3)
	BNE	InterRunV
	BRA	InterX


ZALI:	SUBQ	#1,A5
	CLR.L	DIRCONTI+2
	SUBQ.B	#1,CurLine+1(A3)
	JMP	SALIR

;	------------------------=> Modo "Fast CPU"
	CNOP	0,4
ModoFastCPU:
	TST.B	fps60Dat(A3)		; �Se ha desbordado el frame?
	BEQ.S	EmulaGfx

	SUBQ.B	#1,CurLine+1(A3)

	ADD.W	#HPeriod,(A3)
	BMI	MiraInter

	JMP	([A3,D2.W*8])		; Vuelta al Z-80 emul.
;	------------------------<=

MiraInter192:
	IFND	NOSEG
	SEGCLOSE
	ENDC
	CMP.B	#1,DirPrefs+$7E
	BEQ.S	ModoFastCPU

EmulaGfx:
	BTST	#2,Key+14(A3)		; �Help Pulsada?
	BEQ.S	ZALI


	MOVE.B	#((INIPANT+224)&$FF),OverDat


;	-----------------------------
	MOVEM.L	D0-D7/A0-A7,Bufer(A3)
	LEA	BufBasura(PC),A7
PausaBuc:
;	---
	BSR	Emula1Frame
;	---
	LEA	Regs(PC),A3

	BTST	#3,KEY+$E(A3)		; Modo MSX PAUSE
	BNE.S	PauseFin

	BTST	#3,PauseKey(A3)
	BEQ.S	PauseFin

	NOT.B	PauseDat(A3)
PauseFin:
	MOVE.B	KEY+$E(A3),PauseKey(A3)

	TST.B	PauseDat(A3)		; Modo MSX PAUSE
	BNE.S	PausaBuc
;	---
	MOVEM.L	Bufer(A3),D0-D7/A0-A7
;	-----------------------------

	BTST	#7,DVDP9(A3)		; �Modo 192?
	BNE	MiraInterBuc

	MOVE.B	#((INIPANT+192)&$FF),OverDat

	BRA.S	MiraInterVB	


	CNOP	0,4
MiraInter212:
	BTST	#7,DVDP9(A3)		; �Modo 212?
	BEQ	MiraInterBuc

	MOVE.B	#((INIPANT+212)&$FF),OverDat		; Modo 192 o 212

	NOP			; was: BRA.S	MiraInterVB (zero-length short branch)


	CNOP	0,4
MiraInterVB:

InterVer:
	ST	SCPend			; Sprite collisions: check at next S#0.
	BSET	#7,Estado(A3)		; Petici�n de Interrupci�n Vertical.
	ST	PetInt38+1(A3)

	ADD.W	#HPeriod,(A3)
	BMI	MiraInter
InterRunV:
	BTST	#5,DVDP1(A3)		; �Interrupci�n Vertical?
	BEQ.S	InterX

InterRun:
	TST.B	IFF(A3)			; �Modo DI?
	BNE.S	SiInterRun
InterX:	JMP	([A3,D2.W*8])		; Vuelta al Z-80 emul.

SiInterRun:

	SF	IFF(A3)			; ( DI ) Interrupciones OFF.

;	----------------------=>  Mira si estamos en Halt y procede...
	TST.B	HaltDat(A3)
	BEQ.S	NoModoHalt
	SF	HaltDat(A3)
	ADDQ.W	#1,A5
NoModoHalt:
;	----------------------<=

;	----------------
	SUBQ.W	#1,A5
	SUB.W	(A7),A5
	MOVE.W	A5,D2
;	----------------
	SUBQ.W	#7,(A3)			; * Resta Cycles *
;	----------------
	MOVEQ	#0,D1
	SUBQ.W	#2,D0
	MOVE.W	D0,D1
	CogePagE D1,A6
	move.b	d2,(a6)
	MOVE.W	D0,D1
	ADDQ.W	#1,D1
	CogePagE D1,A4
	lsr.w	#8,d2
	move.b	d2,(a4)

	MOVE.W	#$0100,D2
	MOVE.L	PagRead(A3),A4
	LEA	$38(A4),A5
	LEA	RESTA0(A3),A7
;	----------------
	TST.B	ModoInt(A3)
	BNE.S	NoModo1
	Otra2
;	----------------
NoModo1:
	BMI.S	SiModo2			; �Es Modo IM 0?
	LEA	$66(A4),A5
	Otra2
;	----------------
SiModo2:
	MOVE.W	I(A3),D1
	ST	D1
	CogePag	D1,A4
	MOVE.W	(A4),D1
	ROR.W	#8,D1
	CogePag	D1,A5
	LEA	Restas(A3,D1.W*8),A7
	Otra2
;	----------------




;	----------------
	CNOP	0,4
JumpCurLine:
	DC.L	MiraInter0S	; 0 (-> MiraInter0)
	REPT	7
	DC.L	MiraInterBuc	; 1 -> 7
	ENDR
	DC.L	MiraInterSnapT	; 8: sprite snapshot, top of the screen
	REPT	7
	DC.L	MiraInterBuc	; 9 -> 15
	ENDR
	DC.L	MiraInterBand	; 16: mode 2 band snapshot
	REPT	15
	DC.L	MiraInterBuc	; 17 -> 31
	ENDR
	DC.L	MiraInterBand	; 32: mode 2 band snapshot
	REPT	15
	DC.L	MiraInterBuc	; 33 -> 47
	ENDR
	DC.L	MiraInterBand	; 48: mode 2 band snapshot
	REPT	15
	DC.L	MiraInterBuc	; 49 -> 63
	ENDR
	DC.L	MiraInterBand	; 64: mode 2 band snapshot
	REPT	15
	DC.L	MiraInterBuc	; 65 -> 79
	ENDR
	DC.L	MiraInterBand	; 80: mode 2 band snapshot
	REPT	15
	DC.L	MiraInterBuc	; 81 -> 95
	ENDR
	DC.L	MiraInterSnap	; 96: sprite snapshot (+ band)
	REPT	15
	DC.L	MiraInterBuc	; 97 -> 111
	ENDR
	DC.L	MiraInterBand	; 112: mode 2 band snapshot
	REPT	15
	DC.L	MiraInterBuc	; 113 -> 127
	ENDR
	DC.L	MiraInterBand	; 128: mode 2 band snapshot
	REPT	15
	DC.L	MiraInterBuc	; 129 -> 143
	ENDR
	DC.L	MiraInterBand	; 144: mode 2 band snapshot
	REPT	15
	DC.L	MiraInterBuc	; 145 -> 159
	ENDR
	DC.L	MiraInterBand	; 160: mode 2 band snapshot
	REPT	15
	DC.L	MiraInterBuc	; 161 -> 175
	ENDR
	DC.L	MiraInterBand	; 176: mode 2 band snapshot
	REPT	15
	DC.L	MiraInterBuc	; 177 -> 191
	ENDR

	DC.L	MiraInter192	; 192

	REPT	212-193
	DC.L	MiraInterBuc	; 193 -> 211
	ENDR

	DC.L	MiraInter212	; 212

	REPT	255-213
	DC.L	MiraInterBuc	; 213 -> 254
	ENDR

	DC.L	MiraInter255	; 255
;	----------------

;	----------------
	CNOP	0,8
		DS.L	80	; No Quitar. (Va delante de BufBasura)
BufBasura:	DS.L	20
;	----------------


; ---------------------------------=> Emulaci�n de 1 Frame.
	CNOP	0,4
Emula1Frame:
	IFD	PERF
	JSR	PerfStamp		; A: Z80 frame done.
	MOVE.L	PerfNow,PerfA
	ENDC

	BSR	Wait60fps

	IFD	PERF
	JSR	PerfStamp		; B: waited for the Amiga frame.
	MOVE.L	PerfNow,PerfB
	ENDC

	JSR	ActCopperLine	; *Z0*

	LEA	Regs(PC),A3
	JSR	Act_Hardware

	TST.L	KeyScrPtr		; Scripted test input (CLI key script).
	BEQ.S	NoKeyScr
	JSR	KeyScrRun
NoKeyScr:

	IFD	PERFSPACE
; Test input that doesn't depend on window focus: Space (MSX row 8 bit 0,
; 0 = pressed) for 5 frames every 100 MSX frames from frame PERFSPACE on.
	ADDQ.L	#1,PerfFrN
	MOVE.L	PerfFrN,D1
	SUB.L	#PERFSPACE,D1
	BCS.S	PerfSpOff
	DIVU	#100,D1
	SWAP	D1
	CMP.W	#5,D1
	BCC.S	PerfSpOff
	BCLR	#0,KEY+8(A3)
	BRA.S	PerfSpFin
PerfFrN:	DC.L	0
PerfSpOff:
	BSET	#0,KEY+8(A3)
PerfSpFin:
	ENDC
	IFD	PERFKEY0
; Test input: "0" (MSX row 0 bit 0) for 10 frames from frame PERFKEY0
; (Monster Hunter: "push 0 to use SCC" on its title).
	MOVE.L	PerfFrN,D1
	SUB.L	#PERFKEY0,D1
	CMP.L	#10,D1
	BCC.S	PerfK0Off
	BCLR	#0,KEY+0(A3)
	BRA.S	PerfK0Fin
PerfK0Off:
	BSET	#0,KEY+0(A3)
PerfK0Fin:
	ENDC
	IFD	PERFDOWN
; Test input: a cursor key (MSX row 8 bit PERFDBIT: 4 left, 5 up, 6 down
; (default), 7 right) for 5 frames at frames PERFDOWN, +20 and +40.
; Relevo's Snowboarding: down x3 in its menu; BUN-GA-RUA: left (English)
; on its title. Then Space (PERFSPACE).
	IFND	PERFDBIT
PERFDBIT=6
	ENDC
	MOVE.L	PerfFrN,D1
	SUB.L	#PERFDOWN,D1
	BCS.S	PerfDnOff
	CMP.L	#60,D1
	BCC.S	PerfDnOff
	DIVU	#20,D1
	SWAP	D1
	CMP.W	#5,D1
	BCC.S	PerfDnOff
	BCLR	#PERFDBIT,KEY+8(A3)
	BRA.S	PerfDnFin
PerfDnOff:
	BSET	#PERFDBIT,KEY+8(A3)
PerfDnFin:
	ENDC

	IFD	PERF
	JSR	PerfStamp		; C: copper + hardware updates.
	MOVE.L	PerfNow,PerfC
	ENDC

	TST.W	Refresh(PC)
	BNE.S	RefrCon
	MOVE.W	DirPrefs+$14,Refresh

	IFD	PERF
	MOVE.B	ScrModo(A3),PerfIntMin	; Screen mode of the last render,
	MOVE.B	DVDP0(A3),PerfIntMin+1	; and R#0.
	ENDC
	MOVE.B	ScrModo(A3),D1		; Another mode than the last render
	CMP.B	LastRend,D1		; (MODESW may have kept the caches).
	BEQ.S	RendSame
	MOVE.B	D1,LastRend
	ST	ACTODO(A3)
	ST	ACTODOB(A3)
RendSame:
	JSR	([RVDP.W,A3])		; Emulaci�n del VDP.
	TST.W	SnapPend		; Key-script SNAP: hold this frame.
	BEQ.S	NoSnapDo
	JSR	KeySnapDo
NoSnapDo:
	IFD	PERF
	JSR	PerfStamp		; D: VDP render done.
	MOVE.L	PerfNow,PerfD
	ADDQ.L	#1,PerfRec+24
	JSR	PerfFrame
	ENDC
	RTS
RefrCon:
	SUBQ.W	#1,Refresh
	IFD	PERF
	MOVE.L	PerfC,PerfD		; Frame skipped: no render.
	JSR	PerfFrame
	ENDC
	RTS


Refresh:DC.W	0

; ---------------------------------=> Espera a 60fps
	CNOP	0,4
Wait60fps:
	LEA	Regs(PC),A3
	CMP.B	#2,DirPrefs+$7E		; �Modo Turbo?
	BEQ.S	NoWait60fps

	TST.B	fps60Dat(A3)
	BEQ.S	NoWait60fps

;;OFROFO:
;;	BTST	#6,$BFE001
;;	BEQ.S	OFROFO

;;EWCCFT:
;;	CMP.B	#$FF,$DFF006
;;	BNE.S	EWCCFT


	MOVE.B	#2,fps60Dat(A3)
Wait60fpsBuc:
	CMP.B	#2,fps60Dat(A3)
	BEQ.S	Wait60fpsBuc
NoWait60fps:
	MOVE.B	#1,fps60Dat(A3)
	RTS
; ---------------------------------<=



;  -=====================================================================-
; <***********************************************************************>
;  -=====================================================================-


; ***********************************************************
	DC.L	0
	CNOP	0,8
VBlk5:	DS.B	128		; VRAM 1 KB blocks written outside SCREEN 5/7.
TAB98:	DS.B	$800*8	; VRAM de 128Kb !!!!
	DC.L	0
	CNOP	0,8
	DS.B	512	; Seguridad!
TABSPR:	DS.B	512	; VRAM de 128Kb !!!
	DS.B	512	; Seguridad!
	DS.L	8

	IFNE	(TAB98-REGS)>$7FFE
	FAIL	"(TAB98-REGS) > 32Kb"
	ENDC
	CNOP	0,8
TAB98B:	DS.B	$800*8	; Dirty flags of cache bank 2 (GFXCA2).
	DC.L	0
	IFNE	(TAB98B-REGS)>$7FFE
	FAIL	"(TAB98B-REGS) > 32Kb"
	ENDC
; ***********************************************************





;   ---------------------------------------------------------------------
;  -=====================================================================-
; <***********************************************************************>
;  -=====================================================================-
;   ---------------------------------------------------------------------





	CNOP	0,8
VDP20:	MVDPX	DVDPSX+1
VDP21:	MVDPX	DVDPSX
VDP22:	MVDPX	DVDPSY+1
VDP23:	MVDPX	DVDPSY
VDP24:	MVDPX	DVDPDX+1
VDP25:	MVDPX	DVDPDX
VDP26:	MVDPX	DVDPDY+1
VDP27:	MVDPX	DVDPDY
VDP28:	MVDPX	DVDPNX+1
VDP29:	MVDPX	DVDPNX
VDP2A:	MVDPX	DVDPNY+1
VDP2B:	MVDPX	DVDPNY
VDP2D:	MVDPX	DVDPARG
; <=---------------------------------------------------------=>
VDP2C:
	IFD	TRACE
	TRVLOG	$2C,D2			; (Trace: CPU colour bytes, LMMC/HMMC data.)
	ENDC
	ST	Pl5Dirty
	ST	SCRTDirty
	MOVE.B	D2,DVDPCL(A3)
	MOVE.B	DVDPREG(A3),D2
	BTST	#0,DVDPS2(A3)		; �Ejecuci�n terminada?
	BEQ.S	V2CNoCopy

	IInsBuc
	MOVEM.L	D0-D7/A0-A6,BUFER(A3)

	MOVE.L	MSXVideoMode(A3),A4

	MOVEQ	#0,D1
	MOVE.B	D2,D1
	LSR.B	#4,D1
	JMP	([COMANDOS.W,PC,D1.W*4])

	CNOP	0,8
V2CNoCopy:
	SWAP	D2
	RTS

; <=---------------------------------------------------------=>
	CNOP	0,8
VDP2Enada:
	MOVE.B	D2,DVDPREG(A3)
	BCLR	#0,DVDPS2(A3)		; Ejecuci�n terminada.
	CLR.W	CONTA2C(A3)
	SWAP	D2
	RTS
; -=*=*=-
	CNOP	0,8
VDP2E:
	ST	Pl5Dirty		; Commands draw in the planes only.
	ST	SCRTDirty
	CMP.B	#$07,ScrModo(A3)
	BNE.S	Torna8
	JMP	VDP2Escr8
Torna8:

	IInsBuc
	MOVEM.L	D0-D7/A0-A6,BUFER(A3)

	MOVE.B	D2,DVDPREG(A3)
	BCLR	#0,DVDPS2(A3)		; Ejecuci�n terminada.
	CLR.W	CONTA2C(A3)

	MOVE.L	DVDPSX(A3),DVDPSX2(A3)
	MOVE.L	DVDPDX(A3),DVDPDX2(A3)
	MOVE.L	DVDPNX(A3),DVDPNX2(A3)

	MOVE.L	MSXVideoMode(A3),A4

	MOVE.L	$04(A4),D1
	AND.L	D1,DVDPSX2(A3)
	AND.L	D1,DVDPDX2(A3)
	AND.L	D1,DVDPNX2(A3)

	LEA	$DFF002,A2

	MOVEQ	#0,D1
	MOVE.B	D2,D1
	LSR.B	#4,D1
	JMP	([COMANDOS.W,PC,D1.W*4])

	CNOP	0,8
COMANDOS:
	DC.L	STOP	; 0	STOP
	DC.L	STOP	; 1
	DC.L	STOP	; 2
	DC.L	STOP	; 3
	DC.L	POINT	; 4	POINT
	DC.L	PSET	; 5	PSET
	DC.L	STOP	; 6	SRCH
	DC.L	LINE	; 7	LINE
	DC.L	LMMV	; 8	Paint Punto.
	DC.L	LMMM	; 9	Copia de VRAM a punto.
	DC.L	LMCM	; A	Copia a la CPU.
	DC.L	LMMC	; B	Copia CPU a la VRAM.
	DC.L	HMMV	; C	Paint Byte.
	DC.L	HMMM	; D	Copia de VRAM a Byte.
	DC.L	YMMM	; E	Copia de VRAM a Byte. (Solo Y)
	DC.L	HMMC	; F	Copia de CPU a VRAM a Byte.

; ------------------------------------------------

	CNOP	0,8
STOP:
	MOVEM.L	BUFER(A3),D0-D7/A0-A6
	FInsBuc
	SWAP	D2
	RTS

; ------------------------------------------------

	CNOP	0,8
YMMM:
	AND.W	#$FFFE,DVDPDX2(A3)		; Mascara de X dots.
	BTST	#2,DVDPARG(A3)
	BEQ.S	NoYMMMMaskX
	OR.W	#$0001,DVDPDX2(A3)		; Mascara de X dots.
NoYMMMMaskX:

	MOVE.W	DVDPDX2(A3),DVDPSX2(A3)
	CLR.W	DVDPNX2(A3)

	MOVE.L	(A7)+,RetOut(A3)
	BSR	CALCULAR
	MOVE.L	RetOut(A3),-(A7)

	OR.W	#$0FCA,D0

	AND.W	#$000F,D2
	JMP	([OPERACIONES.W,PC,D2.W*4])

; ------------------------------------------------

	CNOP	0,8
HMMV:
	AND.W	#$FFFE,DVDPNX2(A3)		; Mascara de X dots.
	AND.W	#$FFFE,DVDPDX2(A3)		; Mascara de X dots.
	BTST	#2,DVDPARG(A3)
	BEQ.S	NoHMMVMaskX
	OR.W	#$0001,DVDPDX2(A3)		; Mascara de X dots.
NoHMMVMaskX:

LMMV:
	CLR.W	DVDPSX2(A3)
	MOVE.L	(A7)+,RetOut(A3)
	BSR	CALCULAR
	MOVE.L	RetOut(A3),-(A7)

	OR.W	#$03CA,D0
	AND.W	#$0FFF,D1

	AND.W	#$000F,D2
	JMP	([OPERACIONES.W,PC,D2.W*4])

; ------------------------------------------------

	CNOP	0,8
POINT:
	MOVE.W	DVDPSY2(A3),D1
	MULU	$2A(A4),D1
	MOVEQ	#0,D0
	MOVE.W	DVDPSX2(A3),D0
	MOVE.W	D0,D4
	MOVE.W	$28(A4),D2
	LSR.W	D2,D0
	ADD.L	D0,D1

	NOT.W	D4
	AND.W	$28(A4),D4
	MULU	$20(A4),D4

	MOVE.B	$22(A4),D3
	JSR	([$24.W,A4])
	LSR.B	D4,D1
	AND.B	D3,D1
	MOVE.B	D1,COLREAD(A3)
	BRA	V2EMAL

; ------------------------------------------------

	CNOP	0,8
PSET:
	MOVE.W	#1,DVDPNX2(A3)
	MOVE.W	#1,DVDPNY2(A3)
	MOVE.L	(A7)+,RetOut(A3)
	BSR	CALCULAR
	MOVE.L	RetOut(A3),-(A7)

	OR.W	#$03CA,D0
	AND.W	#$0FFF,D1
	AND.W	#$000F,D2
	JMP	([OPERACIONES.W,PC,D2.W*4])

; ------------------------------------------------

	CNOP	0,8
LMCM:
	BSET	#0,DVDPS2(A3)		; Ejecuci�n no terminada.
	BNE	V2EMAL

	MOVE.L	A4,MODOPantV7

	MOVE.W	DVDPNX2(A3),CONTA2CX(A3)
	MOVE.W	DVDPNY2(A3),CONTA2C(A3)

	BRA	V2EMAL

; ------------------------------------------------

	CNOP	0,8
HMMC:
	MOVE.W	$1C(A4),D0
	SUBQ.B	#1,D0

	MOVE.W	$1A(A4),D1		; Mascara de X dots.
	AND.W	D1,DVDPDX2(A3)
	AND.W	D1,DVDPNX2(A3)

	AND.W	#$000F,D2
	MOVE.L	(LMMCPunteros.W,PC,D2.W*4),A0

	MOVE.B	DVDPCL(A3),D2

	BRA.S	HMMCont
; -=-=-=-
	CNOP	0,8
LMMC:
	MOVEQ	#0,D0

	AND.W	#$000F,D2
	MOVE.L	(LMMCPunteros.W,PC,D2.W*4),A0

	MOVE.B	DVDPCL(A3),D2
	MOVE.W	$30(A4),D1
	ROL.B	D1,D2
HMMCont:
	BSET	#0,DVDPS2(A3)		; Ejecuci�n no terminada.
	BNE	NoIniLMMC


	MOVE.W	DVDPNX2(A3),CONTA2CX(A3)
	BNE.S	LMMCNoCeroX
	MOVE.W	$0C(A4),CONTA2CX(A3)
LMMCNoCeroX:
	MOVE.W	CONTA2CX(A3),CONTA3CX(A3)

	MOVE.W	DVDPNY2(A3),CONTA2C(A3)
	BNE.S	LMMCNoCeroY
	MOVE.W	$0E(A4),CONTA2C(A3)
LMMCNoCeroY:


	MOVE.W	DVDPDY2(A3),D1
	MULU	$0C(A4),D1
	MOVEQ	#0,D7
	MOVE.W	DVDPDX2(A3),D7
	ADD.L	D7,D1

	MOVEQ	#0,D6
	MOVEQ	#$1,D5
	BTST	#2,DVDPARG(A3)
	BEQ.S	LMMCDESX
	MOVEQ	#-1,D5

	MOVE.W	$0C(A4),D6
	ADD.W	CONTA2CX(A3),D6

	BTST	#3,DVDPARG(A3)
	BEQ.S	LMMCDESY

	MOVE.W	$0C(A4),D6
	SUB.W	CONTA2CX(A3),D6
	NEG.L	D6

	BRA.S	LMMCDESY
	CNOP	0,4
LMMCDESX:
	MOVE.W	$0C(A4),D6
	SUB.W	CONTA2CX(A3),D6
	BTST	#3,DVDPARG(A3)
	BEQ.S	LMMCDESY
	MOVE.W	$0C(A4),D6
	ADD.W	CONTA2CX(A3),D6
	NEG.L	D6
LMMCDESY:


	MOVE.W	$10(A4),D4
	MOVE.L	$2C(A4),A5

	MOVEM.L	D1/D4/D5/D6/A5,CPUCopyBuf

NoIniLMMC:

	JMP	(A0)

	CNOP	0,8
LMMCPunteros:
	DC.L	LMMCImp		; 0
	DC.L	LMMCAnd		; 1
	DC.L	LMMCOr		; 2
	DC.L	LMMCXor		; 3
	DC.L	LMMCImp		; 4
	DC.L	LMMCAnd		; 5
	DC.L	LMMCOr		; 6
	DC.L	LMMCXor		; 7
	DC.L	LMMCTImp	; 8
	DC.L	LMMCTAnd	; 9
	DC.L	LMMCTOr		; A
	DC.L	LMMCTXor	; B
	DC.L	LMMCTImp	; C
	DC.L	LMMCTAnd	; D
	DC.L	LMMCTOr		; E
	DC.L	LMMCTXor	; F


LMMCRut:MACRO

	MOVEM.L	CPUCopyBuf,D1/D4/D5/D6/A5

\@LMMCBuc1:

	MOVE.L	A5,A6
	MOVE.W	D4,D7

	IFC	"Cero","\1"
	BFTST	D2{24:D7}
	BNE.S	\@LMMCopy
	ROL.B	D7,D2
	BRA.S	\@NoLMMCopy
	CNOP	0,4
\@LMMCopy:
	ENDC

	SUBQ.B	#1,D7
	MOVEQ	#0,D3
\@LMMCBuc0:

	ROL.B	#1,D2			; Pone en Bit 0 el bit a copiar.

	IFC	"Xor","\2"

	BCC.S	\@NoCopy

	BFTST	(A6){D1:1}
	BEQ.S	\@SiCopy

	OR.B	#$01,D2			; Lo pone de 0 a 1 tras el Xor.

	ENDC

	IFC	"And","\2"
	BCS.S	\@NoCopy
	ENDC

	IFC	"Or","\2"
	BCC.S	\@NoCopy
	ENDC

\@SiCopy:

	BFINS	D2,(A6){D1:1}
\@NoCopy:
	OR.B	D2,D3
	SUB.L	$16(A4),A6
	DBF	D7,\@LMMCBuc0
	BFINS	D3,(A6){D1:1}
\@NoLMMCopy:

	ADD.L	D5,CPUCopyBuf

	SUBQ.W	#1,CONTA2CX(A3)
	BNE.S	\@NoResXLMMC

	ADD.L	D6,CPUCopyBuf

	SUBQ.W	#1,CONTA2C(A3)
	BEQ.S	\@LMMCFinalizar

	MOVE.W	CONTA3CX(A3),CONTA2CX(A3)

\@NoResXLMMC:
	ADDQ.L	#1,D1
	DBF	D0,\@LMMCBuc1

	LSR.L	#8,D1
	TST.W	$1E(A4)
	BEQ.S	\@NoRotes
	LSR.L	#1,D1
\@NoRotes:
	ST	(TABSPR.L,D1.W)


	MOVEM.L	BUFER(A3),D0-D7/A0-A6
	FInsBuc
	SWAP	D2
	RTS

\@LMMCFinalizar:
	BCLR	#0,DVDPS2(A3)		; Ejecuci�n SI terminada.
	IFD	TRVLMMC
	CMP.W	#TRVLMMC,CONTA3CX(A3)
	BNE.S	\@nt
	ST	TrvLmmcDone
\@nt:
	ENDC
	MOVEM.L	BUFER(A3),D0-D7/A0-A6
	FInsBuc
	SWAP	D2
	RTS

	ENDM


	CNOP	0,8
LMMCImp:	LMMCRut	Copy,Imp
LMMCAnd:	LMMCRut	Copy,And
LMMCOr:		LMMCRut	Copy,Or
LMMCXor:	LMMCRut	Copy,Xor
LMMCTImp:	LMMCRut	Cero,Imp
LMMCTAnd:	LMMCRut	Cero,And
LMMCTOr:	LMMCRut	Cero,Or
LMMCTXor:	LMMCRut	Cero,Xor




;	CNOP	0,8
;HMMC:
;	MOVE.W	$1C(A4),CHAPUZ
;	MOVE.B	DVDPCL(A3),D5
;	MOVE.W	$20(A4),D0
;	ROL.B	D0,D5
;	MOVE.B	D5,DVDPCL(A3)
;LMMC:
;	BSET	#0,DVDPS2(A3)		; Ejecuci�n no terminada.
;
;	TST.W	CONTA2C(A3)
;	BNE.S	LMMCCON2
;
;	CLR.W	DVDPSX2(A3)
;	MOVE.W	DVDPNX2(A3),CONTA2CX(A3)
;	BNE.S	LMMCDESBX
;	MOVE.W	$0C(A4),CONTA2CX(A3)
;LMMCDESBX:
;	MOVE.W	DVDPNY2(A3),CONTA2C(A3)
;	BNE.S	LMMCCON2
;	MOVE.W	$0E(A4),CONTA2C(A3)
;
;LMMCCON2:
;	MOVE.W	#1,DVDPNX2(A3)
;	MOVE.W	#1,DVDPNY2(A3)
;	BSR	CALCULAR
;
;	BTST	#2,DVDPARG(A3)
;	BEQ.S	LMMCDESX
;	SUBQ.W	#1,DVDPDX2(A3)
;	BRA.S	LMMCDESXB
;	CNOP	0,8
;LMMCDESX:
;	ADDQ.W	#1,DVDPDX2(A3)
;LMMCDESXB:
;	SUBQ.W	#1,CONTA2CX(A3)
;	BNE.S	LMMCCON0
;
;	SUBQ.W	#1,CONTA2C(A3)
;	BNE.S	LMMCCON1
;	BCLR	#0,DVDPS2(A3)		; Ejecuci�n terminada.
;LMMCCON1:
;
;	BTST	#3,DVDPARG(A3)
;	BEQ.S	LMMCDESY
;	SUBQ.W	#1,DVDPDY2(A3)
;	BRA.S	LMMCDESYB
;	CNOP	0,8
;LMMCDESY:
;	ADDQ.W	#1,DVDPDY2(A3)
;LMMCDESYB:
;
;	MOVE.W	DVDPDX(A3),DVDPDX2(A3)
;	MOVE.W	DVDPNX(A3),CONTA2CX(A3)
;	BNE.S	LMMCCON0
;	MOVE.W	$0C(A4),CONTA2CX(A3)
;LMMCCON0:
;
;	OR.W	#$03CA,D0
;	AND.W	#$0FFF,D1
;	AND.W	#$000F,D2
;	JMP	([OPERACIONES.W,PC,D2.W*4])
;
;	CNOP	0,8
;CHAPUZ:	DC.W	0,0

; ------------------------------------------------

	CNOP	0,8
HMMM:
	AND.W	#$FFFE,DVDPNX2(A3)		; Mascara de X dots.
	AND.W	#$FFFE,DVDPSX2(A3)		; Mascara de X dots.
	AND.W	#$FFFE,DVDPDX2(A3)		; Mascara de X dots.
	BTST	#2,DVDPARG(A3)
	BEQ.S	NoHMMMMaskX
	OR.W	#$0001,DVDPSX2(A3)		; Mascara de X dots.
	OR.W	#$0001,DVDPDX2(A3)		; Mascara de X dots.
NoHMMMMaskX:

LMMM:
	MOVE.L	(A7)+,RetOut(A3)
	BSR	CALCULAR
	MOVE.L	RetOut(A3),-(A7)

	OR.W	#$0FCA,D0

	AND.W	#$000F,D2
	JMP	([OPERACIONES.W,PC,D2.W*4])

; ------------------------------------------------

	CNOP	0,8
V2EMAL:
	MOVEM.L	BUFER(A3),D0-D7/A0-A6
	FInsBuc
	SWAP	D2
	RTS

; ------------------------------------------------

	CNOP	0,8
OPERACIONES:
	DC.L	IMP	; 0
	DC.L	AND	; 1
	DC.L	OR	; 2
	DC.L	XOR	; 3
	DC.L	NOT	; 4
	DC.L	V2EMAL	; 5
	DC.L	V2EMAL	; 6
	DC.L	V2EMAL	; 7
	DC.L	TIMP	; 8
	DC.L	TAND	; 9
	DC.L	TOR	; A
	DC.L	TXOR	; B
	DC.L	TNOT	; C
	DC.L	V2EMAL	; D
	DC.L	V2EMAL	; E
	DC.L	V2EMAL	; F


; ------------------------------------------------

	CNOP	0,8
CALCULAR:
	BTST	#2,DVDPARG(A3)
	BEQ.S	NODESBORX

	MOVE.W	DVDPNX2(A3),D0
	BNE.S	V2ENOES0DESX
	MOVE.W	$0C(A4),D0
V2ENOES0DESX:
	SUBQ.W	#1,D0
	SUB.W	D0,DVDPSX2(A3)
	SUB.W	D0,DVDPDX2(A3)
	BCC.S	NODESBORX
	MOVE.W	DVDPDX2(A3),D1
	CLR.W	DVDPDX2(A3)
	NEG.W	D1
	SUB.W	D1,D0
	MOVE.W	D0,DVDPNX2(A3)
NODESBORX:

	MOVE.W	$0C(A4),D1
	SUB.W	DVDPDX2(A3),D1
	MOVE.W	DVDPNX2(A3),D0
	BNE.S	V2ENOES0DESX2
	MOVE.W	$0C(A4),D0
V2ENOES0DESX2:
	SUB.W	D0,D1
	BCC.S	NODESBORX2
	NEG.W	D1
	SUB.W	D1,D0
	MOVE.W	D0,DVDPNX2(A3)
NODESBORX2:

	MOVE.L	$12(A4),A0		; Source X,Y
	MOVE.L	A0,A1			; Destino X,Y
	MOVEQ	#0,D0
	MOVE.W	DVDPSY2(A3),D0
	MOVE.W	$08(A4),D3		; Y * Size lado.
	LSL.W	D3,D0
	ADD.L	D0,A0
	MOVEQ	#0,D0
	MOVE.W	DVDPSX2(A3),D0
	DIVU	#16,D0
	ADD.W	D0,A0
	ADD.W	D0,A0
	SWAP	D0

	MOVEQ	#0,D1
	MOVE.W	DVDPDY2(A3),D1
	MOVE.W	$08(A4),D3	; Y * Size lado.
	LSL.W	D3,D1
	ADD.L	D1,A1
	MOVEQ	#0,D1
	MOVE.W	DVDPDX2(A3),D1
	DIVU	#16,D1
	ADD.W	D1,A1
	ADD.W	D1,A1
	SWAP	D1

	MOVE.W	$0A(A4),D3		; Size de X
	LSR.W	#1,D3
	MOVE.W	DVDPNX2(A3),D4
	BNE.S	V2ENOES0X
	MOVE.W	$0C(A4),D4
V2ENOES0X:

	CMP.W	D1,D0
	BGT	MODODES

	MOVE.W	D4,D6			; Calcula Mascara.
	ADD.W	DVDPDX2(A3),D6
	SUBQ.W	#1,D6
	NOT.W	D6
	AND.W	#$000F,D6
	MOVEQ	#-1,D5
	LSR.L	D1,D5
	LSL.W	D6,D5


	ADD.W	D1,D4
	MOVE.W	D4,D6
	LSR.W	#4,D4
	AND.W	#$000F,D6
	BEQ.S	V2ESCEPX
	ADDQ.W	#1,D4
V2ESCEPX:
	SUB.W	D4,D3			; Modulo.
	LSL.W	#1,D3

	MOVE.W	D4,D6
	LSL.W	#1,D6

	ROR.L	#6,D4
	MOVE.W	DVDPNY2(A3),D4		; Size de Y
	BNE.S	V2ENOES0Y
	MOVE.W	$0E(A4),D4
V2ENOES0Y:
; -----------------------------
	MOVE.W	D4,D7		; Prepara tabla para SPR.
	SWAP	D7
	MOVE.W	DVDPDY2(A3),D7
	TST.W	$1E(A4)
	BEQ.S	TABSPRCON
	LSR.W	#1,D7
	BCC.S	TABSPRCONQ1
	SWAP	D7
	ADDQ.W	#2,D7
	LSR.W	#1,D7
	SWAP	D7
	BRA.S	TABSPRCON
TABSPRCONQ1:
	SWAP	D7
	ADDQ.W	#1,D7
	LSR.W	#1,D7
	SWAP	D7
TABSPRCON:
	LEA	(TABSPR.L,D7.W),A5
	SWAP	D7
	BTST	#3,DVDPARG(A3)
	BEQ.S	TABSPRCON0
	SUB.W	D7,A5
	ADDQ	#1,A5
TABSPRCON0:
	SUBQ.W	#1,D7
	BPL.S	TABSPRBUC
	MOVEQ	#0,D7
TABSPRBUC:
	ST	(A5)+
	DBF	D7,TABSPRBUC
; -----------------------------
	SUB.W	D0,D1

	BTST	#3,DVDPARG(A3)
	BEQ.S	NODESBORY

	MOVE.W	D6,D3
	ADD.W	$0A(A4),D3		; ** Size 1 linea.
	NEG.W	D3

NODESBORY:
	ROL.L	#6,D4

	ROR.W	#4,D1
	AND.W	#$F000,D1
	CLR.W	D0
	RTS

	CNOP	0,8
MODODES:
	MOVE.W	D4,D6			; Calcula Mascara.
	ADD.W	DVDPSX2(A3),D6
	SUBQ.W	#1,D6
	NOT.W	D6
	AND.W	#$000F,D6
	MOVEQ	#-1,D5
	LSR.L	D0,D5
	LSL.W	D6,D5


	ADD.W	D0,D4
	MOVE.W	D4,D6
	LSR.W	#4,D4
	AND.W	#$000F,D6
	BEQ.S	V2ESCEPXD
	ADDQ.W	#1,D4
V2ESCEPXD:
	SUB.W	D4,D3			; Modulo.
	LSL.W	#1,D3

	MOVE.W	D4,D6
	LSL.W	#1,D6

	ROR.L	#6,D4
	MOVE.W	DVDPNY2(A3),D4		; Size de Y
	BNE.S	V2ENOES0YD
	MOVE.W	$0E(A4),D4
V2ENOES0YD:
; -----------------------------
	MOVE.W	D4,D7		; Prepara tabla para SPR.
	SWAP	D7
	MOVE.W	DVDPDY2(A3),D7
	TST.W	$1E(A4)
	BEQ.S	TABSPRCOND
	LSR.W	#1,D7
	BCC.S	TABSPRCONQ2
	SWAP	D7
	ADDQ.W	#2,D7
	LSR.W	#1,D7
	SWAP	D7
	BRA.S	TABSPRCOND
TABSPRCONQ2:
	SWAP	D7
	ADDQ.W	#1,D7
	LSR.W	#1,D7
	SWAP	D7
TABSPRCOND:
	LEA	(TABSPR.L,D7.W),A5
	SWAP	D7
	BTST	#3,DVDPARG(A3)
	BEQ.S	TABSPRCON0D
	SUB.W	D7,A5
	ADDQ	#1,A5
TABSPRCON0D:
	SUBQ.W	#1,D7
	BPL.S	TABSPRBUCD
	MOVEQ	#0,D7
TABSPRBUCD:
	ST	(A5)+
	DBF	D7,TABSPRBUCD
; -----------------------------
	SUB.W	D0,D1
	NEG.W	D1

	LEA	-2(A0,D6.W),A0
	LEA	-2(A1,D6.W),A1

	BTST	#3,DVDPARG(A3)
	BNE.S	NODESBORYD

	MOVE.W	D6,D3
	ADD.W	$0A(A4),D3		; ** Size 1 linea.
	NEG.W	D3

NODESBORYD:
	ROL.L	#6,D4

	SWAP	D5

	ROR.W	#4,D1
	AND.W	#$F000,D1
	MOVE.W	D1,D0
	BSET	#1,D1
	RTS


; ------------------------------------------------

	CNOP	0,8
TIMP:
	MOVE.B	#$CA,D0
	BRA.S	TIMPES
	CNOP	0,8
TAND:
	MOVE.B	#$80,D0
	BRA.S	TIMPES
	CNOP	0,8
TOR:
	MOVE.B	#$EA,D0
	BRA.S	TIMPES
	CNOP	0,8
TXOR:
	MOVE.B	#$5A,D0
	BRA.S	TIMPES
	CNOP	0,8
TNOT:
	MOVE.B	#$CA,D0
	BRA.S	TIMPES

	CNOP	0,8
TIMPES:
	BTST	#$E,(A2)
	BNE.S	TIMPES

	MOVE.W	D3,$64-2(A2)	; A	Mascara.
	MOVE.W	D3,$66-2(A2)	; D	Destino!
	MOVE.W	D3,$60-2(A2)	; C	(mask OR passes)

	MOVE.B	DVDPCL(A3),D6
	AND.B	$22(A4),D6
	SNE	D6
	EXT.W	D6

; Transparent logical ops (TIMP, TAND...): the destination pixel is kept
; where the SOURCE pixel is colour 0, as on the V9938 and in openMSX. The
; mask M is the OR of the source's mask plane and all its colour planes
; (A0 points at the mask plane, planes follow), pre-shifted to the
; destination when COPIA does not shift its A channel (ascending), into
; TMASK (A0 - plane size); COPIA then blits (M&B)|(!M&C) per plane.
; v3.1 used source plane 0 alone as M (unshifted copies or descending:
; plane 0 itself), so even colours were transparent: Lilly's Saga text.
	MOVE.L	#-1,$44-2(A2)	; No first/last word masks here.
	MOVE.W	D1,D7
	AND.W	#$0002,D7		; BLTCON1: only DESC.
	MOVE.W	D7,$42-2(A2)
	MOVE.W	D1,D7
	AND.W	#$F000,D7		; ASH = BSH, unless COPIA shifts
	MOVE.W	D0,D2			; A itself (descending copies:
	AND.W	#$F000,D2		; MODODES sets D0 = BSH).
	BEQ.S	TIMPSH
	MOVEQ	#0,D7
TIMPSH:
	MOVE.W	D7,D2
	OR.W	#$09F0,D7		; A,D:   D = A
	OR.W	#$0BFA,D2		; A,C,D: D = A | C
	MOVE.L	A0,A6
	MOVE.L	A0,A5
	SUB.L	$16(A4),A5		; M: same offset in the mask plane.
	MOVE.W	D7,$40-2(A2)
	MOVE.L	A6,$50-2(A2)	; A = source plane 0
	MOVE.L	A5,$54-2(A2)	; D = M
	MOVE.W	D4,$58-2(A2)	; Size
	MOVE.W	$10(A4),D7
	SUBQ.W	#1,D7			; Then OR in every colour plane.
TIMPOR:
	ADD.L	$16(A4),A6
TIMPB:
	BTST	#$E,(A2)
	BNE.S	TIMPB
	MOVE.W	D2,$40-2(A2)
	MOVE.L	A6,$50-2(A2)	; A = next source plane
	MOVE.L	A5,$48-2(A2)	; C = M
	MOVE.L	A5,$54-2(A2)	; D = M
	MOVE.W	D4,$58-2(A2)	; Size
	DBF	D7,TIMPOR
TIMPB2:
	BTST	#$E,(A2)
	BNE.S	TIMPB2

	BRA	COPIA

; ------------------------------------------------

	CNOP	0,8
IMP:
	MOVE.B	#$CA,D0
	BRA.S	IMPES
	CNOP	0,8
AND:
	MOVE.B	#$80,D0
	BRA.S	IMPES
	CNOP	0,8
OR:
	MOVE.B	#$EA,D0
	BRA.S	IMPES
	CNOP	0,8
XOR:
	MOVE.B	#$5A,D0
	BRA.S	IMPES
	CNOP	0,8
NOT:
	MOVE.B	#$CA,D0
	BRA.S	IMPES

	CNOP	0,8
IMPES:
	BTST	#$E,(A2)
	BNE.S	IMPES

	NEG.W	D6
	MOVE.W	D6,$64-2(A2)	; A	Mascara.
	MOVE.L	#MASKFF,A5
	MOVE.W	D3,$66-2(A2)	; D	Destino!
	MOVEQ	#-1,D6

COPIA:
	MOVE.W	D0,$40-2(A2)
	MOVE.W	D1,$42-2(A2)

	MOVE.L	D5,$44-2(A2)	; A (Mascara)

	MOVE.W	D3,$62-2(A2)	; B	Origen.
	MOVE.W	D3,$60-2(A2)	; C	Destino.

	MOVE.B	DVDPCL(A3),D5
	AND.B	$22(A4),D5
	SNE	D7
	EXT.W	D7
	MOVE.W	$10(A4),D0
	MOVE.W	D6,$74-2(A2)	; A DAT
V2EBUCLE:
	MOVE.W	D7,$72-2(A2)	; B DAT

	MOVE.L	A5,$50-2(A2)	; A
	MOVE.L	A0,$4C-2(A2)	; B
	MOVE.L	A1,$48-2(A2)	; C
	MOVE.L	A1,$54-2(A2)	; D
	MOVE.W	D4,$58-2(A2)	; Size

	LSR.B	#1,D5
	ROXR.B	D7
	ASR.B	#7,D7
	EXT.W	D7

	ADD.L	$16(A4),A0		; Suma Size de 1 plano
	ADD.L	$16(A4),A1		; Suma Size de 1 plano
ESPBLTMQB:BTST	#$E,(A2)
	BNE.S	ESPBLTMQB

	DBF	D0,V2EBUCLE

;	TST.W	CHAPUZ(PC)
;	BEQ.S	NOCHAPUZ
;	SUBQ.W	#1,CHAPUZ
;	BEQ.S	NOCHAPUZ
;	MOVE.B	DVDPCL(A3),D5
;	MOVE.W	$20(A4),D0
;	ROL.B	D0,D5
;	MOVE.B	D5,DVDPCL(A3)
;	BRA	LMMCCON2
;NOCHAPUZ:

	MOVEM.L	BUFER(A3),D0-D7/A0-A6
	FInsBuc

	SWAP	D2
	RTS
; <=---------------------------------------------------------=>


	CNOP	0,8
LINE:
	MOVE.W	DVDPDX2(A3),D0	; Pasa datos VDP-MSX a Blitter-Amiga.
	MOVE.W	DVDPDY2(A3),D1
	MOVE.W	DVDPNX2(A3),D4
	MOVE.W	DVDPNY2(A3),D5
	MOVE.W	D0,D2
	MOVE.W	D1,D3
	BTST	#0,DVDPARG(A3)
	BEQ.S	CARALARGA
	EXG.L	D4,D5
CARALARGA:
	BTST	#2,DVDPARG(A3)
	BEQ.S	MAJCON0
	NEG.W	D4
MAJCON0:ADD.W	D4,D2
	BTST	#3,DVDPARG(A3)
	BEQ.S	MINCON0
	NEG.W	D5
MINCON0:ADD.W	D5,D3

	AND.W	$04(A4),D0
	AND.W	$06(A4),D1
	AND.W	$04(A4),D2
	AND.W	$06(A4),D3

	MOVE.L	$12(A4),A0
	LEA	$DFF002,A6
	MOVE.W	$0A(A4),D6

*************************************************************************
*                           RUTINA DE LINEAS                            *
*************************************************************************
;Needs:
; 	a0    	planept		d5 y d6 se modifican.
; 	a6    	$dff002
; 	d0/d1 	x,y start pos
; 	d2/d3 	x,y end   pos
; 	d6    	Width of plane
;	d7	0=Borra. 1=Escribe.
DL_MInterns = $Ca
DrawLine:	
;Registros para dibujado de lineas
	move.w	d6,d4
	cmp.w	d1,d3			;   drawing only from top to bottom is
	bge.s	y1ly2			;   necessary for:
	exg	d0,d2			;   a: up-down differences (same koords)
	exg	d1,d3			;   b: blitter invert bit (only at top of line)
y1ly2:	sub.w	d1,d3			;d3:yd
; here we could do an optimization with special shifts
; depending on the DL_Width value ... i know it, but please, let it be.
	mulu	d4,d1			;   use muls for neg y-vals
	add.l	d1,a0		        ;   please don't use add.w here!
	moveq	#0,d1			;d1:quant-counter
	sub.w	d0,d2			;d2:xd
	bge.s	.xdpos
	addq.w	#2,d1			;   set bit 1 of quant-counter (here it could be a moveq)
	neg.w	d2
.xdpos:	moveq	#$f,d4			;   d4 full cleaned (for later oktants move.b)
	and.w	d0,d4
	lsr.w	#3,d0	         	;   yeah, on byte (necessary for bchg) ....
	add.w	d0,a0			;   ... blitter ands automagically
	ror.w	#4,d4			;d4:shift
	or.w	#$b00+DL_MInterns,d4	;   bltcon0-codes
	swap	d4
	cmp.w	d2,d3			;   which delta is the biggest?
	bge.w	.dygdx
	addq.w	#1,d1			;   set bit 0 of quant-counter
	exg	d2,d3			;   exchange xd with yd
.dygdx:
	add.w	d2,d2			;d2:xd*2
	move.w	d2,d0			;d0:save for $52(a6)
	sub.w	d3,d0			;d0:xd*2-yd
	addx.w	d1,d1			;Bit0:sign-bit
	move.b	oktants(pc,d1.w),d4	;   in low byte of d4 (upper byte cleaned above)
	swap	d2
	move.w	d0,d2
	sub.w	d3,d2			;d2:2*(xd-yd)
	moveq	#6,d1			;d1:shiftval(not necessary) + testval for the blitter
	lsl.w	d1,d3			;d3:BLTSIZE
	add.w	#$42,d3
.wb:
	btst	d1,(a6)			;   waiting for the blitter ...
	bne.s	.wb
	move.w	d6,$60-2(a6)
	move.w	d6,$66-2(a6)
	move.w	#$8000,$74-2(a6)
	move.w	#$ffff,$44-2(a6)
	move.l	d4,$40-2(a6)		;   writing to the blitter regs as fast as possible.
	move.l	d2,$62-2(a6)
	move.w	d0,$52-2(a6)

	MOVE.W	$10(A4),D6			; Numero de bit-planos.
	MOVE.B	DVDPCL(A3),D5
	SNE	D7
	EXT.W	D7
LINEBUC:
	move.l	d4,$40-2(a6)		;   writing to the blitter regs as fast as possible.
	move.w	d0,$52-2(a6)
	move.w	d7,$72-2(a6)
	move.l	a0,$48-2(a6)
	move.l	a0,$54-2(a6)		;   shit-word buffer pt.
	move.w	d3,$58-2(a6)

	LSR.B	#1,D5
	ROXR.B	D7
	ASR.B	#7,D7
	EXT.W	D7
	ADD.L	$16(A4),A0		; Suma Size de 1 plano
ESPBLTMLI:
	BTST	d1,(A6)
	BNE.S	ESPBLTMLI
	DBF	D6,LINEBUC
	BRA	V2EMAL
; ------------- oktant-table --------------------------------------------
SML=0
	CNOP	0,8
oktants:
	dc.b	SML+1,SML+1+$40
	dc.b	SML+17,SML+17+$40
	dc.b	SML+9,SML+9+$40
	dc.b	SML+21,SML+21+$40
*********************************************


; <=---------------------------------------------------------=>

	CNOP	0,8
MODO7DATS:
	DC.L	0		;
	DC.W	$01FF		; $04  Size X. Mask
	DC.W	$01FF		; $06  Size Y. Mask
	DC.W	$6		; $08  Bits a rotar.
	DC.W	64		; $0A  Size X.
	DC.W	512		; $0C  Max copy X
	DC.W	512		; $0E  Max copy Y
	DC.W	4		; $10  N�mero de planos
	DC.L	SCR0-(64*512)	; $12  Inicio plano Mascara.
	DC.L	(64*512)	; $16  Size de 1 plano
	DC.W	$FFFE		; $1A  Mascara para X dots
	DC.W	2		; $1C  N�mero de dots en Byte.
	DC.W	0		; $1E  Rotaci�n para TABSPR.
	DC.W	4		; $20  Rotaci�n para CPU Copy.
	DC.B	$0F		; $22  Mascara color.
	DC.B	0		; $23  
	DC.L	POINTA		; $24  Rutina  IN A,(98)
	DC.W	$0001		; $28  Mascara Dot Point.
	DC.W	512/2		; $2A  X Bytes en VRAM.
	DC.L	SCR0+(64*512*3)	; $2C  Ultimo plano.
	DC.W	4		; $30  Rotar bits en LMMC


	CNOP	0,8
MODO5DATS:
	DC.L	0		;
	DC.W	$00FF		; $04  Size X. Mask
	DC.W	$03FF		; $06  Size Y. Mask
	DC.W	$5		; $08  Bits a rotar.
	DC.W	32		; $0A  Size X.
	DC.W	256		; $0C  Max copy X
	DC.W	1024		; $0E  Max copy Y
	DC.W	4		; $10  N�mero de planos
	DC.L	SCR0-(64*512)	; $12  Inicio plano Mascara.
	DC.L	(64*512)	; $16  Size de 1 plano
	DC.W	$FFFE		; $1A  Mascara para X dots
	DC.W	2		; $1C  N�mero de dots en Byte.
	DC.W	1		; $1E  Rotaci�n para TABSPR.
	DC.W	4		; $20  Rotaci�n para CPU Copy.
	DC.B	$0F		; $22  Mascara color.
	DC.B	0		; $23  
	DC.L	POINTA		; $24  Rutina  IN A,(98)
	DC.W	$0001		; $28  Mascara Dot Point.
	DC.W	256/2		; $2A  X Bytes en VRAM.
	DC.L	SCR0+(32*1024*3); $2C  Ultimo plano.
	DC.W	4		; $30  Rotar bits en LMMC


	CNOP	0,8
MODO6DATS:
	DC.L	0		;
	DC.W	$01FF		; $04  Size X. Mask
	DC.W	$03FF		; $06  Size Y. Mask
	DC.W	$6		; $08  Bits a rotar.
	DC.W	64		; $0A  Size X.
	DC.W	512		; $0C  Max copy X
	DC.W	1024		; $0E  Max copy Y
	DC.W	2		; $10  N�mero de planos
	DC.L	SCR0-(64*1024)	; $12  Inicio plano Mascara.
	DC.L	(64*1024)	; $16  Size de 1 plano
	DC.W	$FFFC		; $1A  Mascara para X dots
	DC.W	4		; $1C  N�mero de dots en Byte.
	DC.W	1		; $1E  Rotaci�n para TABSPR.
	DC.W	2		; $20  Rotaci�n para CPU Copy.
	DC.B	$03		; $22  Mascara color.
	DC.B	0		; $23  
	DC.L	POINTC		; $24  Rutina  IN A,(98)
	DC.W	$0003		; $28  Mascara Dot Point.
	DC.W	512/4		; $2A  X Bytes en VRAM.
	DC.L	SCR0+(64*1024*1); $2C  Ultimo plano.
	DC.W	6		; $30  Rotar bits en LMMC


	CNOP	0,8
MODO8DATS:
	DC.L	0		;
	DC.W	$00FF		; $04  Size X. Mask
	DC.W	$01FF		; $06  Size Y. Mask
	DC.W	$5		; $08  Bits a rotar.
	DC.W	32		; $0A  Size X.
	DC.W	256		; $0C  Max copy X
	DC.W	512		; $0E  Max copy Y
	DC.W	8		; $10  N�mero de planos
	DC.L	SCR0-(32*512)	; $12  Inicio plano Mascara.
	DC.L	(32*512)	; $16  Size de 1 plano
	DC.W	$FFFF		; $1A  Mascara para X dots
	DC.W	1		; $1C  N�mero de dots en Byte.
	DC.W	0		; $1E  Rotaci�n para TABSPR.
	DC.W	0		; $20  Rotaci�n para CPU Copy.
	DC.B	$FF		; $22  Mascara color.
	DC.B	0		; $23  
	DC.L	POINTB		; $24  Rutina  IN A,(98)
	DC.W	$0000		; $28  Mascara Dot Point.
	DC.W	256/1		; $2A  X Bytes en VRAM.
	DC.L	SCR0+(32*512*7)	; $2C  Ultimo plano.
	DC.W	0		; $30  Rotar bits en LMMC




;   ---------------------------------------------------------------------
;  -=====================================================================-
; <***********************************************************************>
;  -=====================================================================-
;   ---------------------------------------------------------------------



;	 -------------------------------------
;	- Rutinas Amiga (Intertupci�n VBlank) -
;	 -------------------------------------


; -------------------------------------> Interrupcion de Vblank de Amiga.
	CNOP	0,8
Inter:
	MOVE.W	#$2700,SR
	IFD	HANGCHK
	MOVE.L	D0,-(SP)		; (HANGCHK: SR at 4(SP), PC at 6(SP).)
	MOVE.W	TrvFrame,D0
	CMP.W	HangLastF,D0
	BEQ.S	HangSame
	MOVE.W	D0,HangLastF
	CLR.W	HangCnt
	BRA.S	HangDone
HangSame:
	ADDQ.W	#1,HangCnt
	CMP.W	#150,HangCnt		; No MSX frame for 3 s:
	BNE.S	HangDone
	MOVE.L	6(SP),HangPC		; note where it was and go to HangGo.
	MOVE.W	4(SP),HangSR
	MOVE.L	#HangGo,6(SP)
HangDone:
	MOVE.L	(SP)+,D0
	ENDC
	BTST	#5,$DFF01F
	BEQ	VDP_Emul
	MOVE.W	#$0020,$DFF09C
	IFD	PERF
	ADDQ.L	#1,PerfTick		; VBlank (line 0): speed counter clock.
	MOVE.L	D0,-(SP)
	MOVE.L	$DFF004,D0
	LSR.L	#8,D0
	AND.W	#$1FF,D0
	CMP.W	PerfIntMax,D0		; Latency check: lines past 0.
	BLS.S	PerfIntNoMax
	MOVE.W	D0,PerfIntMax
PerfIntNoMax:
	MOVE.L	(SP)+,D0
	ENDC
	IFD	PERF
	MOVE.L	A0,-(SP)		; PC sample (profile): the interrupted
	MOVE.L	PerfPCPtr,A0		; PC, 2 bytes into the exception frame.
	MOVE.L	4+2(SP),(A0)+
	CMP.L	#PerfPCEnd,A0
	BCS.S	PerfPCv
	LEA	PerfPCBuf,A0
PerfPCv:	MOVE.L	A0,PerfPCPtr
	ADDQ.L	#1,PerfPCCnt
	MOVE.L	(SP)+,A0
	ENDC
	IFD	PERFTICKS
	CMP.L	#PERFTICKS,PerfTick	; Optional escape after n VBlanks, even if
	BNE.S	PerfNoEsc		; the emulation hangs: RTE into SALIR (back
	MOVE.W	(SP),DIRCONTI		; to the menu, which writes perf.bin),
	MOVE.L	2(SP),DIRCONTI+2	; as the Ctrl+Alt exit (SISALIR2) does.
	CLR.W	(SP)
	MOVE.L	#SALIR,2(SP)
	SF	DERSTACK
PerfNoEsc:
	ENDC
	NOP
	RTE

; -------------------------------------> Interrupcion de Copper.
	CNOP	0,8
VDP_Emul:
	MOVE.L	A3,-(SP)
	IFD	PERF
	MOVE.L	A0,-(SP)		; PC sample (profile): the interrupted
	MOVE.L	PerfPCPtr,A0		; PC, 2 bytes into the exception frame.
	MOVE.L	8+2(SP),(A0)+
	CMP.L	#PerfPCEnd,A0
	BCS.S	PerfPCc
	LEA	PerfPCBuf,A0
PerfPCc:	MOVE.L	A0,PerfPCPtr
	ADDQ.L	#1,PerfPCCnt
	MOVE.L	(SP)+,A0
	ENDC


	MOVE.L	NextCopp,$dff084


	LEA	Regs,A3
; ---
	BTST	#3,DVDP9(A3)
	BEQ.S	NoEntrelaz
	BCLR	#5,DVDP2(A3)
	BCLR	#1,DVDPS2(A3)
	TST.B	$DFF004
	BPL.S	NoEntrelaz
	BSET	#5,DVDP2(A3)
	BSET	#1,DVDPS2(A3)
NoEntrelaz:

	LEA	Regs(PC),A3
; ------------------------------>
	SUBQ.B	#1,fps60Dat(A3)
	BCC.S	fps60NoDes
	SF	fps60Dat(A3)
fps60NoDes:
; ------------------------------<

	MOVE.L	(SP)+,A3

	MOVE.W	#$0010,$DFF09C
	NOP
	RTE







;	--------------------------
;	Rutina para reset y salir.
;	--------------------------

; -------------------------------------> Exit, Reset y Hard Reset.
	CNOP	0,8
Mira_Teclas:

; ----------------------------=> Contador 2.
	TST.B	Contador2(A3)
	BNE.S	ModoAntiCrak

	ADDQ	#4,SP			; Perteneca a la rutina.

ModoAntiCrak:
; ----------------------------<=

	BTST	#2,KEY+14(A3)		; Help
	BNE	NOSALIR

	TST.B	MULTEC(A3)		; (Modo Multi-key)
	BNE.S	SISALIR2

	BTST	#1,KEY+6(A3)		; Ctrl
	BNE.S	SISALIR

	BTST	#2,KEY+6(A3)		; Alt Izdo.
	BNE.S	SISALIR

	MOVE.L	VBRPun,A0
	MOVE.L	#INTER,$6C(A0)
	CLR.W	DIRCONTI
	MOVE.L	#BUCLE,DIRCONTI+2
	CLR.W	(SP)
	MOVE.L	#HARDRESET,2(SP)
	MOVE.W	#$7FFF,$DFF09A
	MOVE.W	#$0070,$DFF09C
	NOP
	RTE
;	----------------
	CNOP	0,8
SISALIR:
	BTST	#1,KEY+6(A3)		; Ctrl
	BEQ.S	NOSALIR

	BTST	#2,KEY+6(A3)		; Alt Izdo.
	BEQ.S	NOSALIR
SISALIR2:
	MOVE.W	(SP),DIRCONTI
	MOVE.L	2(SP),DIRCONTI+2
	CLR.W	(SP)
	MOVE.L	#SALIR,2(SP)
	SF	DERSTACK
	MOVE.W	#$0070,$DFF09C
	NOP
	RTE
;	----------------
	CNOP	0,8
NOSALIR:
	SUBQ	#4,SP
	RTS
; -------------------------------------<


; -------------------------------------> Chequea Desbordamiento de SP.
;	MOVEQ	#0,D1
;	MOVE.W	D0,D1
;	CogePagE D1,A4
;	CMP.L	A6,A4
;	BEQ.S	NODESSP
;
;	MOVE.L	A4,A6
;	MOVE.W	(SP),DIRCONTI
;	MOVE.L	2(SP),DIRCONTI+2
;	CLR.W	(SP)
;	MOVE.L	#SALIR,2(SP)
;	ST	DERSTACK
;	MOVE.W	#$0070,$DFF09C
;	NOP
;	RTE
;	CNOP	0,8
;NODESSP:
; -------------------------------------<


;	----------------
BUCINF:	BRA.S	BUCINF
	CNOP	0,8
Pausa_Dat:DC.L	BUCINF
Pet_Inter:DC.W	0,0
;	----------------

; -------------------------------------<


;   ---------------------------------------------------------------------
;  -=====================================================================-
; <***********************************************************************>
;  -=====================================================================-
;   ---------------------------------------------------------------------


; -------------------------------------> Actualiza MSX2 Hardware.
	CNOP	0,8
Act_Hardware:
; -------------------------------------> Actualiza Color de borde.
	MOVE.W	#$1A0,D1
	BTST	#5,DVDP8(A3)
	BNE.S	COLORBCON
	CLR.W	D1
	MOVE.B	MCAGA+10,D1
	LSL.W	#1,D1
	ADD.W	#$180,D1
COLORBCON:
	MOVE.W	D1,COLBORDE
	MOVE.W	([COL00]),COLBORDE+2	;	 Color del Borde.
; -------------------------------------<

; -------------------------------------> Apaga Motor de Disquetera.
	TST.B	CONTASEC
	BMI.S	CONTASECON
	SUBQ.B	#1,CONTASEC
	BCC.S	CONTASECON
	OR.B	#$F8,$BFD100
	MOVE.W	#6,D0
	JSR	RETARDO
	AND.B	#$87,$BFD100
	MOVE.W	#6,D0
	JSR	RETARDO
	OR.B	#$F8,$BFD100
	NOP
CONTASECON:
; -------------------------------------<

; -------------------------------------> Actualiza mantisa del teclado.
	TST.B	CapsLock(A3)
	BEQ.S	NoCapsLock
	SUBQ.B	#1,CapsLock(A3)
	BNE.S	NoCapsLock
	BSET	#3,KEY+6(A3)
NoCapsLock:
 	TST.B	$BFEC01
	BEQ.S	INTERCON
	JSR	MTECLADO
	NOP
	NOP
	TST.B	$BFEC01
	BEQ.S	INTERCON
	BSR	MTECLADO
INTERCON:
; -------------------------------------<

; -------------------------------------> Actualiza estado de JoySticks.
	BSR	TESTEAJOY
; -------------------------------------<

; -------------------------------------> Emulaci�n de Sonido.
	MOVE.B	SFXCHIP,D0
	BEQ.S	EsPSG
	CMPI.B	#3,D0
	BEQ.S	EsFMPak
	JSR	TocaSCC
	BRA.S	SfxFin
EsFMPak:BSR	TocaFMPak
	BRA.S	SfxFin
EsPSG:	BSR	TocaPSG
SfxFin:

; -------------------------------------<

; -------------------------------------> Retardo de la emulaci�n.
;	MOVE.W	VELOCID,D0		; Retardo.
;	SUBQ.W	#1,D0
;	BMI.S	NOVELOCID
;	LSL.W	#2,D0
;	JSR	RETARDO
;;;;	MOVE.W	#$0070,$DFF09C
;NOVELOCID:
; -------------------------------------<
	RTS
; -------------------------------------<

;   ---------------------------------------------------------------------
;  -=====================================================================-
; <***********************************************************************>
;  -=====================================================================-
;   ---------------------------------------------------------------------

;   ---------------------------------------------------------------------



;	 --------------------------
;	- Emulaci�n de teclado MSX -	Por Juan Antonio G�mez.
;	 --------------------------

	CNOP	0,8
CapsON:
	BTST	#6,PAA(A3)
	BEQ.S	CapsRet
	MOVE.B	#5,CapsLock(A3)
	BCLR	#3,KEY+6(A3)
CapsRet:RTS

	CNOP	0,8
CapsOFF:
	BTST	#6,PAA(A3)
	BNE.S	CapsRet
	MOVE.B	#5,CapsLock(A3)
	BCLR	#3,KEY+6(A3)
	RTS

	CNOP	0,8
MTECLADO:
	MOVEQ	#0,D0
	MOVE.B	$BFEC01,D0
	NOP
	NOP
	SF	$BFEC01
	NOP
	NOP
	MOVE.W	#4,D2
	OR.B	#$40,$BFEE01		; CIAA Libre
TRETARDO:
	MOVE.B	$DFF006,D1
TRETARDOB:
	CMP.B	$DFF006,D1
	BEQ.S	TRETARDOB
	DBF	D2,TRETARDO
	AND.B	#$BF,$BFEE01		; CIAA Libre
	TST.L	KeyScrPtr		; Scripted test run: only the key script
	BNE.S	MTESAL			; types (handshake done, matrix untouched).
	ADDQ.W	#1,D2
	NOT.B	D0
	LSR.B	#$01,D0
	BCS.S	NOTECLA
	MOVE.B	TECLADO(PC,D0.W*2),D2
	MOVE.B	TECLADO+1(PC,D0.W*2),D0
	BMI	CapsON
	BCLR	D2,KEY(A3,D0.W)
	RTS
	CNOP	0,8
NOTECLA:
	MOVE.B	TECLADO(PC,D0.W*2),D2
	MOVE.B	TECLADO+1(PC,D0.W*2),D0
	BMI	CapsOFF
	TST.B	MULTEC(A3)
	BNE.S	MTESAL
	BSET	D2,KEY(A3,D0.W)
MTESAL:	RTS

	CNOP	0,8
TECLADO:
	DC.B	7,01,1,00,2,00,3,00,4,00,5,00,6,00,7,00	; 00 - BIT , POS
	DC.B	0,01,1,01,0,00,2,01,3,01,4,01,0,00,3,09	; 08
	DC.B	6,04,4,05,2,03,7,04,1,05,6,05,2,05,6,03	; 10
	DC.B	4,04,5,04,5,01,6,01,0,00,4,09,5,09,6,09	; 18
	DC.B	6,02,0,05,1,03,3,03,4,03,5,03,7,03,0,04	; 20
	DC.B	1,04,1,02,0,02,5,02,0,00,7,09,0,10,1,10	; 28
	DC.B	3,06,7,05,5,05,0,03,3,05,7,02,3,04,2,04	; 30
	DC.B	2,02,3,02,4,02,0,00,7,10,2,10,3,10,4,10	; 38
	DC.B	0,08,5,07,3,07,7,07,7,07,2,07,3,08,0,00	; 40
	DC.B	0,00,0,00,5,10,0,00,5,08,6,08,7,08,4,08	; 48
	DC.B	5,06,6,06,7,06,0,07,1,07,6,07,4,07,1,08	; 50
	DC.B	2,08,3,08,3,06,5,02,2,09,0,09,1,09,2,14	; 58
	DC.B	0,06,0,06,0,-1,1,06,2,06,4,06,0,14,1,14	; 60
	DC.B	0,00,0,00,0,00,0,00,0,00,0,00,0,00,0,00	; 68
	DC.B	0,00,0,00,0,00,0,00,0,00,0,00,0,00,0,00	; 70
	DC.B	0,00,0,00,0,00,0,00,0,00,0,00,0,00,0,00	; 78

	DS.W	$80	<-- Seguridad.

; -----------------------------<


;	 --------------------------------
;	- Lee puertos 0 y 1 del JoyStick -
;	 --------------------------------

	CNOP	0,8
TesteaJoy:
	BSR.S	TesteaJoyRut
	TST.B	SwapJoyD
	BEQ.S	TesteaJoyRet
	MOVE.B	DATOJOY1(A3),D1
	MOVE.B	DATOJOY2(A3),DATOJOY1(A3)
	MOVE.B	D1,DATOJOY2(A3)
TesteaJoyRet:
; -------------------------------------> Contador de tiempo 2.
	LEA	DirPrefs+$7F-$5216,A0
	MOVEQ	#0,D1
	MOVE.B	$5216(A0),D1
	LSR.B	#5,D1
	ADD.W	D1,Contador1(A3)
	BCC.S	Conta2Fin
	MOVE.L	$1C3*8(A3),$1CD*8(A3)
Conta2Fin:
; -------------------------------------<
	RTS

	CNOP	0,8
TesteaJoyRut:
	LEA	REGS,A3
	TST.L	KeyScrPtr		; Scripted test run: no host joystick or
	BEQ.S	TJoyHost		; mouse (moving the mouse over WinUAE
	ST	DATOJOY1(A3)		; read as MSX joystick 2).
	ST	DATOJOY2(A3)
	RTS
TJoyHost:

	IFEQ	Key_ON
	MOVE.L	([KeyBase],$08.w),A0
	JMP	(A0)				; Salto a Key
	ELSEIF

	MOVE.W	$DFF00C,D0		; Puerto B.
	BSR	LEEJOY

	MOVE.B	D2,D1
	BTST	#7,$BFE001
	BNE.S	NOB1_E
	BSET	#4,D1
NOB1_E:
	MOVE.W	#$FF00,$DFF034
	NOP
	BTST	#4,$DFF016
	BNE.S	NOB2C_E
	BSET	#5,D1
NOB2C_E:
	MOVE.W	#$FF00,$DFF034
	NOP
	BTST	#6,$DFF016
	BNE.S	NOB2_E
	BSET	#5,D1
NOB2_E:
	BTST	#0,KEY+$E(A3)
	BNE.S	NOB2B_E
	BSET	#5,D1
NOB2B_E:

	TST.B	LEEJOY2(A3)
	BNE.S	ESMOUSE

	NOT.B	D1
	MOVE.B	D1,DATOJOY1(A3)

; -----

	MOVE.W	$DFF00A,D0		; Puerto A.
	BSR	LEEJOY
	MOVE.B	D2,D1

	BTST	#6,$BFE001
	BNE.S	NOB1_F
	BSET	#4,D1
NOB1_F:
	MOVE.W	#$FF00,$DFF034
	NOP
	BTST	#0,$DFF016
	BNE.S	NOB2_F
	BSET	#5,D1
NOB2_F:
	MOVE.W	#$FF00,$DFF034
	NOP
	BTST	#2,$DFF016
	BNE.S	NOB2C_F
	BSET	#5,D1
NOB2C_F:
	BTST	#1,KEY+$E(A3)
	BNE.S	NOB2B_F
	BSET	#5,D1
NOB2B_F:
	NOT.B	D1
	MOVE.B	D1,DATOJOY2(A3)
	RTS

	CNOP	0,8
ESMOUSE:
	BTST	#6,$BFE001
	BNE.S	NOB1_FB
	BSET	#4,D1
NOB1_FB:
	MOVE.W	#$FF00,$DFF034
	NOP
	BTST	#0,$DFF016
	BNE.S	NOB2_FB
	BSET	#5,D1
NOB2_FB:
	MOVE.W	#$FF00,$DFF034
	NOP
	BTST	#2,$DFF016
	BNE.S	NOB2C_FB
	BSET	#5,D1
NOB2C_FB:
	BTST	#1,KEY+$E(A3)
	BNE.S	NOB2B_FB
	BSET	#5,D1
NOB2B_FB:
	NOT.B	D1
	MOVE.B	D1,DATOJOY1(A3)
	ST	DATOJOY2(A3)
	RTS

; -------------------------------
;	Lectura del Joystick.

;	Resultado en D2.b de la siguiente forma:
;	Bit 0=Derecha.
;	Bit 1=Izquierda.
;	Bit 2=Abajo.
;	Bit 3=Arriba.

	CNOP	0,8
LEEJOY:
	MOVE.W	D0,D1
	LSL.B	#2,D1
	AND.B	#$08,D1
	MOVE.B	D1,D2		; Derecha.

	LSR.W	#7,D1
	AND.B	#$04,D1
	OR.B	D1,D2		; Izquierda.

	MOVE.W	D0,D1
	LSR.W	#1,D1
	EOR.W	D1,D0

	MOVE.W	D0,D1
	LSL.B	#1,D1
	AND.B	#$02,D1
	OR.B	D1,D2		; Abajo.

	LSR.W	#8,D0
	AND.B	#$01,D0
	OR.B	D0,D2		; Arriba.
	RTS

	ENDC

; ***********************************************************



;   ---------------------------------------------------------------------
;  -=====================================================================-
; <***********************************************************************>
;  -=====================================================================-
;   ---------------------------------------------------------------------


;	-------------------------
;	Emulaci�n de MSX2 Sprits.
;	-------------------------


SIZSPR=(8)
;NEXSPR=(8*256*2)+32
LINSPR=8*2


SPR2PMAC:MACRO
	ADD.W	D5,A3			; Siguiente l�nea Y de Pantalla.
	DBF	D1,SPR2PBUC0		; Siguiente l�nea Y de Sprit.
	DBF	D0,SPR2PBUC		; Siguiente Sprit.
	MOVE.L	SPR2_Pila(PC),SP
	RTS
	CNOP	0,8
	ENDM


	CNOP	0,8
IMPSPR2:
;;	LEA	BUFERSPR2(PC),A5
;;	LEA	SPRIT0+16,A6

	TST.B	BandOn			; Multiplexed sprites: by bands.
	BEQ.S	IMPSPR2n
	TST.W	BandN
	BEQ.S	IMPSPR2n
	JMP	IMPSPR2B
IMPSPR2n:
	SF	BandPass
	LEA	SPR2TABLA(PC),A1
	LEA	REGS,A3
; ---
	MOVE.W	DVDP5(A3),D1		; Coordenadas Sprites.
	TST.B	DirPrefs+$64
	BEQ.S	NoBase20
	MOVE.W	AntVDP5(PC),D1		; *.*
NoBase20:
	AND.W	#$03FC,D1
	MULU	#$80,D1
	LEA	(DIRVRAM.L,D1.L),A4
	LEA	-512(A4),A0
IMPSPR2c:				; (IMPSPR2B: A4/A0 = a band snapshot.)
	MOVE.L	A4,A3
; ---
	MOVE.B	#216,D6
	MOVEQ	#32-1,D5		; 32 Sprits a imprimir.
SPR2PBUC1:
	CMP.B	(A3),D6
	ADDQ	#4,A3
	DBEQ	D5,SPR2PBUC1
; ---
	MOVEQ	#32-2,D0		; 32 Sprits a imprimir.
	SUB.W	D5,D0
	MOVE.W	D0,([NUMSPR2])
	BMI	SPR2RET
; ---
	MOVE.B	REGS+VDPLINY,D7
	TST.B	DirPrefs+$64
	BEQ.S	NoBase21
	MOVE.B	AntLinY(PC),D7		; *.*
NoBase21:
	TST.B	BandPass		; By bands: the band's own R#23.
	BEQ.S	NoBandLinY
	MOVE.B	BandLinYCur,D7
NoBandLinY:
; ---
	MOVE.L	REGS+PVDP6,D6
	TST.B	DirPrefs+$64
	BEQ.S	NoBase22
	MOVE.L	AntPVDP6(PC),D6		; *.*
NoBase22:
	ADD.L	#DIRVRAM+16,D6		; Sprites en formato Amiga.
; ---
	MOVE.W	#LINSPR,D5

	MOVEQ	#0,D2
	MOVEQ	#0,D4

	MOVE.L	SP,SPR2_Pila

; ---------------------------------------
	LEA	SPR2_16b(PC),SP
	TST.B	BandPass
	BEQ.S	SprBandN16
	LEA	SPR2_16Xb(PC),SP	; (Bands: lines clipped to the band.)
SprBandN16:
	CLR.W	SprECOff		; First colour line: (A0)...
	MOVE.W	#16,SprNL
	BTST	#1,REGS+DVDP1		; Mira si es imprimir spr de 8*8 o 16*16
	BEQ.S	SprBandSiz
	TST.B	BandLater		; (Buffer flag: first band only.)
	BNE.S	EsModoSPR16
	SF	-4(A5)			; 16*16.
	BRA.S	EsModoSPR16
SprBandSiz:
	TST.B	BandLater
	BNE.S	SprBandS8
	ST	-4(A5)			; Datos de bufer para 8*8 o 16*16
SprBandS8:
	LEA	SPR2_8b(PC),SP
	TST.B	BandPass
	BEQ.S	SprBandN8
	LEA	SPR2_8Xb(PC),SP
SprBandN8:
	SUB.L	#16,D6			; Sprites en formato Amiga.
	SUBQ.W	#8,A0
	MOVE.W	#8,SprECOff		; ...or 8(A0) with 8*8 sprites.
	MOVE.W	#8,SprNL
EsModoSPR16:
; ---------------------------------------

;;	MOVEQ	#32-1,D0		; 32 Sprits a imprimir.
SPR2PBUC:
	MOVE.L	A6,A3
	MOVEQ	#15,D1
	ADD.B	(A4)+,D1

	SUB.B	D7,D1

	CMP.W	#224+15,D1	; (Sin Oversan es '212+15')
	BLT.S	SPRPCON1
SPR2Skip:
	ADDQ.W	#3,A4
	ADD.W	#16,A0
	SUBQ.W	#1,([NUMSPR2])
	DBF	D0,SPR2PBUC		; Siguiente Sprit.
	MOVE.L	SPR2_Pila(PC),SP
	RTS

	CNOP	0,8
SPRPCON1:
	TST.B	BandPass		; Band: only sprites with lines in
	BEQ.S	SprBandOK		; [BandLo, BandHi), clipped by the
	MOVE.W	D1,D3			; X line loops (SprD1Hi/Lo: values
	SUB.W	#14,D3			; of the line counter D1 to draw).
	CMP.W	BandHi(PC),D3		; First line >= the band's end.
	BGE.S	SPR2Skip
	ADD.W	SprNL(PC),D3
	CMP.W	BandLo(PC),D3		; Last line < the band's start.
	BLE.S	SPR2Skip
	MOVE.W	D3,D2
	SUBQ.W	#1,D2
	SUB.W	BandLo(PC),D2
	MOVE.W	D2,SprD1Hi
	SUB.W	BandHi(PC),D3
	MOVE.W	D3,SprD1Lo
	MOVEQ	#0,D2
SprBandOK:
	LSL.W	#4,D1		; Coordenada Y.
	ADD.W	D1,A3


	MOVE.B	(A4)+,D4	; Coordenada X.
	MOVE.W	SprECOff(PC),D1
	BTST	#7,(A0,D1.W)		; EC: X - 32.
	BNE.S	SprEC
SprECx:
	LEA	(TABCORX.W,PC,D4.W*8),A2
	MOVE.L	(A2)+,A1
	ADD.W	(A2)+,A3
	MOVE.W	(A2)+,D4
SprECd:
	MOVE.L	A1,(A5)+	; Tabla de punteros a usar.
	MOVE.L	A3,(A5)+	; Dir. Chip a copiar Gfx.


;	MOVE.L	GFXSPR,A2	; Sprites en formato Amiga.
;	MOVE.B	(A4)+,D1
;	AND.W	#$00FC,D1
;	MULU	#(18),D1
;	ADD.L	D1,A2
;
;	TST.B	-3(A2)
;	BEQ.S	SPRNOSUM
;	ADD.W	#$1200,A2
;SPRNOSUM:

	JMP	SPR2_16-SPR2_16b(A7)	; Sprits de 16*16 o 8*8.
; ---
SprEC:	SUB.W	#32,D4
	BCC.S	SprECx			; X 32-255: X - 32 as usual.
	CMP.W	#-16,D4			; Off the left edge: not drawn
	BLE.S	SprECskip		; (Lilly's Saga's curtains).
	LEA	TABCORX(PC),A2		; Partly: at X=0, pattern shifted
	MOVE.L	(A2)+,A1		; left by the rest.
	ADD.W	(A2)+,A3
	MOVEQ	#16,D1
	SUB.W	D4,D1
	MOVE.W	D1,D4
	BRA.S	SprECd
SprECskip:
	MOVEQ	#0,D4
	ADDQ.W	#2,A4			; Pattern, unused byte.
	ADD.W	#16,A0			; Its colour lines.
	SUBQ.W	#1,([NUMSPR2])
	DBF	D0,SPR2PBUC		; Siguiente Sprit.
	MOVE.L	SPR2_Pila(PC),SP
	RTS
SprECOff:	DC.W	0
		CNOP	0,4
SprLastP6:	DC.L	-1		; R#6 table last converted (TRANSSPR).
; ---
	CNOP	0,8
SPR2PBUC0:
	JMP	(A7)
; ---
	CNOP	0,8
SPR2_16:
	MOVE.L	D6,A2			; Sprits en VRAM
	MOVE.B	(A4)+,D1
	AND.W	#$00FC,D1
	LSL.W	#3,D1
	ADD.W	D1,A2

	ADDQ	#1,A4

	NOP

	MOVEQ	#16-1,D1		; 16 Lineas Y de 1 sprit a imprimir.
SPR2_16b:
	MOVEQ	#0,D3
	MOVE.W	-16(A2),D3		; 1 linea GFX sprit.
	MOVE.B	(A2)+,D3		; 1 linea GFX sprit.
	LSL.L	D4,D3			; Rota a su coordenada X.
	MOVE.B	(A0)+,D2		; N� de color.
	MOVE.B	D2,(A5)+
	JMP	([A1,D2.W*4])		; Salto a impresi�n.
; ---
	CNOP	0,8
SPR2RET:RTS

; ---
	CNOP	0,8
SPR2_8:
	MOVE.L	D6,A2			; Sprits en VRAM
	MOVE.B	(A4)+,D1
	AND.W	#$00FF,D1
	LSL.W	#3,D1
	ADD.W	D1,A2

	ADDQ	#1,A4

	ADDQ	#8,A0

	MOVEQ	#8-1,D1			; 8 Lineas Y de 1 sprit a imprimir.
SPR2_8b:
	MOVEQ	#0,D3
	MOVE.B	(A2)+,D3
	LSL.W	#8,D3
	LSL.L	D4,D3			; Rota a su coordenada X.
	MOVE.B	(A0)+,D2		; N� de color.
	MOVE.B	D2,(A5)+
	JMP	([A1,D2.W*4])		; Salto a impresi�n.
; --------------------------------------------
; Band copies (IMPSPR2B): lines outside the band get colour 0 (nothing drawn,
; nothing for CLEARSPR2 to clear).
	CNOP	0,8
SPR2_16X:
	MOVE.L	D6,A2
	MOVE.B	(A4)+,D1
	AND.W	#$00FC,D1
	LSL.W	#3,D1
	ADD.W	D1,A2

	ADDQ	#1,A4

	NOP

	MOVEQ	#16-1,D1
SPR2_16Xb:
	MOVEQ	#0,D3
	MOVE.W	-16(A2),D3
	MOVE.B	(A2)+,D3
	LSL.L	D4,D3
	MOVE.B	(A0)+,D2
	CMP.W	SprD1Hi(PC),D1
	BGT.S	SPR2_16Xz
	CMP.W	SprD1Lo(PC),D1
	BGE.S	SPR2_16Xd
SPR2_16Xz:
	MOVEQ	#0,D2
SPR2_16Xd:
	MOVE.B	D2,(A5)+
	JMP	([A1,D2.W*4])
	CNOP	0,8
SPR2_8X:
	MOVE.L	D6,A2
	MOVE.B	(A4)+,D1
	AND.W	#$00FF,D1
	LSL.W	#3,D1
	ADD.W	D1,A2

	ADDQ	#1,A4

	ADDQ	#8,A0

	MOVEQ	#8-1,D1
SPR2_8Xb:
	MOVEQ	#0,D3
	MOVE.B	(A2)+,D3
	LSL.W	#8,D3
	LSL.L	D4,D3
	MOVE.B	(A0)+,D2
	CMP.W	SprD1Hi(PC),D1
	BGT.S	SPR2_8Xz
	CMP.W	SprD1Lo(PC),D1
	BGE.S	SPR2_8Xd
SPR2_8Xz:
	MOVEQ	#0,D2
SPR2_8Xd:
	MOVE.B	D2,(A5)+
	JMP	([A1,D2.W*4])
	IFNE	(SPR2_16X-SPR2_16Xb)-(SPR2_16-SPR2_16b)
	FAIL	"SPR2_16X entry"
	ENDC
	IFNE	(SPR2_8X-SPR2_8Xb)-(SPR2_8-SPR2_8b)
	FAIL	"SPR2_8X entry"
	ENDC
	IFNE	(SPR2_8-SPR2_8b)-(SPR2_16-SPR2_16b)
	FAIL	"SPR2_8 entry"
	ENDC
SprNL:		DC.W	16		; Lines of a sprite (16 or 8).
SprD1Hi:	DC.W	0
SprD1Lo:	DC.W	0
BandLo:		DC.W	0		; Band being drawn (IMPSPR2B).
BandHi:		DC.W	0
; --------------------------------------------

; --------------------------------------------
	CNOP	0,8
CreaCoorSprits:
	MOVE.W	#INISPR2*$100+$50,Sprit0
	MOVE.W	#FINSPR2*$100+$02,Sprit0+8

	MOVE.W	#INISPR2*$100+$50,Sprit1
	MOVE.W	#FINSPR2*$100+$82,Sprit1+8

	MOVE.W	#INISPR2*$100+$70,Sprit2
	MOVE.W	#FINSPR2*$100+$02,Sprit2+8

	MOVE.W	#INISPR2*$100+$70,Sprit3
	MOVE.W	#FINSPR2*$100+$82,Sprit3+8

	MOVE.W	#INISPR2*$100+$90,Sprit4
	MOVE.W	#FINSPR2*$100+$02,Sprit4+8

	MOVE.W	#INISPR2*$100+$90,Sprit5
	MOVE.W	#FINSPR2*$100+$82,Sprit5+8

	MOVE.W	#INISPR2*$100+$B0,Sprit6
	MOVE.W	#FINSPR2*$100+$02,Sprit6+8

	MOVE.W	#INISPR2*$100+$B0,Sprit7
	MOVE.W	#FINSPR2*$100+$82,Sprit7+8


	MOVE.W	#INISPR2*$100+$50,Sprit0b
	MOVE.W	#FINSPR2*$100+$02,Sprit0b+8

	MOVE.W	#INISPR2*$100+$50,Sprit1b
	MOVE.W	#FINSPR2*$100+$82,Sprit1b+8

	MOVE.W	#INISPR2*$100+$70,Sprit2b
	MOVE.W	#FINSPR2*$100+$02,Sprit2b+8

	MOVE.W	#INISPR2*$100+$70,Sprit3b
	MOVE.W	#FINSPR2*$100+$82,Sprit3b+8

	MOVE.W	#INISPR2*$100+$90,Sprit4b
	MOVE.W	#FINSPR2*$100+$02,Sprit4b+8

	MOVE.W	#INISPR2*$100+$90,Sprit5b
	MOVE.W	#FINSPR2*$100+$82,Sprit5b+8

	MOVE.W	#INISPR2*$100+$B0,Sprit6b
	MOVE.W	#FINSPR2*$100+$02,Sprit6b+8

	MOVE.W	#INISPR2*$100+$B0,Sprit7b
	MOVE.W	#FINSPR2*$100+$82,Sprit7b+8
	RTS
; --------------------------------------------

; --------------------------------------------
	CNOP	0,8
CREATABCORX:
	LEA	TABCORX,A5
	MOVEQ	#0,D0
	MOVE.W	#256-1,D7
CRTACORXBUC:
	MOVE.L	D0,D4
	DIVU	#64,D4
	MOVE.W	D4,D6
	MULU	#OTRSPR,D6

	LEA	SPR2TABLA(PC),A1
	CLR.W	D4
	SWAP	D4
	CMP.W	#48,D4
	BLT.S	SPRCON0
	LEA	SPR2TABLA2(PC),A1
SPRCON0:
	MOVE.L	A1,(A5)+
	DIVU	#16,D4
	LSL.W	#1,D4
	ADD.W	D4,D6
	MOVE.W	D6,(A5)+
	SWAP	D4
	MOVE.W	#16,D1
	SUB.W	D4,D1
	MOVE.W	D1,(A5)+

	ADDQ.B	#1,D0
	DBF	D7,CRTACORXBUC
	RTS
; ---
	CNOP	0,8
AntVDP5:	DC.W	0	; Coordenadas de los Sprites.
AntPVDP6:	DC.L	0	; Gr�ficos de los Sprites.
AntLinY:	DC.B	0	; Scroll por Hardware.
; ---
	CNOP	0,8
SPRA0:
SPRB0:
SPRC0:
SPRD0:
	SPR2PMAC
SPRA1:
	OR.L	D3,(A3)
	NOT.L	D3
	AND.L	D3,(SIZSPR)(A3)
	AND.L	D3,(NEXSPR)(A3)
	AND.L	D3,(NEXSPR+SIZSPR)(A3)
	SPR2PMAC
SPRA2:
	OR.L	D3,(SIZSPR)(A3)
	NOT.L	D3
	AND.L	D3,(A3)
	AND.L	D3,(NEXSPR)(A3)
	AND.L	D3,(NEXSPR+SIZSPR)(A3)
	SPR2PMAC
SPRA3:
	OR.L	D3,(SIZSPR)(A3)
	OR.L	D3,(A3)
	NOT.L	D3
	AND.L	D3,(NEXSPR)(A3)
	AND.L	D3,(NEXSPR+SIZSPR)(A3)
	SPR2PMAC
SPRA4:
	OR.L	D3,(NEXSPR)(A3)
	NOT.L	D3
	AND.L	D3,(A3)
	AND.L	D3,(SIZSPR)(A3)
	AND.L	D3,(NEXSPR+SIZSPR)(A3)
	SPR2PMAC
SPRA5:
	OR.L	D3,(NEXSPR)(A3)
	OR.L	D3,(A3)
	NOT.L	D3
	AND.L	D3,(SIZSPR)(A3)
	AND.L	D3,(NEXSPR+SIZSPR)(A3)
	SPR2PMAC
SPRA6:
	OR.L	D3,(SIZSPR)(A3)
	OR.L	D3,(NEXSPR)(A3)
	NOT.L	D3
	AND.L	D3,(A3)
	AND.L	D3,(NEXSPR+SIZSPR)(A3)
	SPR2PMAC
SPRA7:
	OR.L	D3,(SIZSPR)(A3)
	OR.L	D3,(NEXSPR)(A3)
	OR.L	D3,(A3)
	NOT.L	D3
	AND.L	D3,(NEXSPR+SIZSPR)(A3)
	SPR2PMAC
SPRA8:
	OR.L	D3,(NEXSPR+SIZSPR)(A3)
	NOT.L	D3
	AND.L	D3,(A3)
	AND.L	D3,(SIZSPR)(A3)
	AND.L	D3,(NEXSPR)(A3)
	SPR2PMAC
SPRA9:
	OR.L	D3,(NEXSPR+SIZSPR)(A3)
	OR.L	D3,(A3)
	NOT.L	D3
	AND.L	D3,(SIZSPR)(A3)
	AND.L	D3,(NEXSPR)(A3)
	SPR2PMAC
SPRAA:
	OR.L	D3,(SIZSPR)(A3)
	OR.L	D3,(NEXSPR+SIZSPR)(A3)
	NOT.L	D3
	AND.L	D3,(A3)
	AND.L	D3,(NEXSPR)(A3)
	SPR2PMAC
SPRAB:
	OR.L	D3,(SIZSPR)(A3)
	OR.L	D3,(NEXSPR+SIZSPR)(A3)
	OR.L	D3,(A3)
	NOT.L	D3
	AND.L	D3,(NEXSPR)(A3)
	SPR2PMAC
SPRAC:
	OR.L	D3,(NEXSPR)(A3)
	OR.L	D3,(NEXSPR+SIZSPR)(A3)
	NOT.L	D3
	AND.L	D3,(A3)
	AND.L	D3,(SIZSPR)(A3)
	SPR2PMAC
SPRAD:
	OR.L	D3,(NEXSPR)(A3)
	OR.L	D3,(NEXSPR+SIZSPR)(A3)
	OR.L	D3,(A3)
	NOT.L	D3
	AND.L	D3,(SIZSPR)(A3)
	SPR2PMAC
SPRAE:
	OR.L	D3,(SIZSPR)(A3)
	OR.L	D3,(NEXSPR)(A3)
	OR.L	D3,(NEXSPR+SIZSPR)(A3)
	NOT.L	D3
	AND.L	D3,(A3)
	SPR2PMAC
SPRAF:
	OR.L	D3,(NEXSPR+SIZSPR)(A3)
	OR.L	D3,(NEXSPR)(A3)
	OR.L	D3,(SIZSPR)(A3)
	OR.L	D3,(A3)
	SPR2PMAC
; ---
SPRB1:
	OR.L	D3,(A3)
	SPR2PMAC
SPRB2:
	OR.L	D3,(SIZSPR)(A3)
	SPR2PMAC
SPRB3:
	OR.L	D3,(SIZSPR)(A3)
	OR.L	D3,(A3)
	SPR2PMAC
SPRB4:
	OR.L	D3,(NEXSPR)(A3)
	SPR2PMAC
SPRB5:
	OR.L	D3,(NEXSPR)(A3)
	OR.L	D3,(A3)
	SPR2PMAC
SPRB6:
	OR.L	D3,(SIZSPR)(A3)
	OR.L	D3,(NEXSPR)(A3)
	SPR2PMAC
SPRB7:
	OR.L	D3,(SIZSPR)(A3)
	OR.L	D3,(NEXSPR)(A3)
	OR.L	D3,(A3)
	SPR2PMAC
SPRB8:
	OR.L	D3,(NEXSPR+SIZSPR)(A3)
	SPR2PMAC
SPRB9:
	OR.L	D3,(NEXSPR+SIZSPR)(A3)
	OR.L	D3,(A3)
	SPR2PMAC
SPRBA:
	OR.L	D3,(SIZSPR)(A3)
	OR.L	D3,(NEXSPR+SIZSPR)(A3)
	SPR2PMAC
SPRBB:
	OR.L	D3,(SIZSPR)(A3)
	OR.L	D3,(NEXSPR+SIZSPR)(A3)
	OR.L	D3,(A3)
	SPR2PMAC
SPRBC:
	OR.L	D3,(NEXSPR)(A3)
	OR.L	D3,(NEXSPR+SIZSPR)(A3)
	SPR2PMAC
SPRBD:
	OR.L	D3,(NEXSPR)(A3)
	OR.L	D3,(NEXSPR+SIZSPR)(A3)
	OR.L	D3,(A3)
	SPR2PMAC
SPRBE:
	OR.L	D3,(SIZSPR)(A3)
	OR.L	D3,(NEXSPR)(A3)
	OR.L	D3,(NEXSPR+SIZSPR)(A3)
	SPR2PMAC
SPRBF:
	OR.L	D3,(NEXSPR+SIZSPR)(A3)
	OR.L	D3,(NEXSPR)(A3)
	OR.L	D3,(SIZSPR)(A3)
	OR.L	D3,(A3)
	SPR2PMAC
; ---

; ---
SPRC1:
	SWAP	D3
	OR.W	D3,(A3)
	NOT.W	D3
	AND.W	D3,(SIZSPR)(A3)
	AND.W	D3,(NEXSPR)(A3)
	AND.W	D3,(NEXSPR+SIZSPR)(A3)
	SWAP	D3
	OR.W	D3,(RESSPR)(A3)
	NOT.W	D3
	AND.W	D3,(SIZSPR)+(RESSPR)(A3)
	AND.W	D3,(NEXSPR)+(RESSPR)(A3)
	AND.W	D3,(NEXSPR+SIZSPR)+(RESSPR)(A3)
	SPR2PMAC
SPRC2:
	SWAP	D3
	OR.W	D3,(SIZSPR)(A3)
	NOT.W	D3
	AND.W	D3,(A3)
	AND.W	D3,(NEXSPR)(A3)
	AND.W	D3,(NEXSPR+SIZSPR)(A3)
	SWAP	D3
	OR.W	D3,(SIZSPR)+(RESSPR)(A3)
	NOT.W	D3
	AND.W	D3,(RESSPR)(A3)
	AND.W	D3,(NEXSPR)+(RESSPR)(A3)
	AND.W	D3,(NEXSPR+SIZSPR)+(RESSPR)(A3)
	SPR2PMAC
SPRC3:
	SWAP	D3
	OR.W	D3,(SIZSPR)(A3)
	OR.W	D3,(A3)
	NOT.W	D3
	AND.W	D3,(NEXSPR)(A3)
	AND.W	D3,(NEXSPR+SIZSPR)(A3)
	SWAP	D3
	OR.W	D3,(SIZSPR)+(RESSPR)(A3)
	OR.W	D3,(RESSPR)(A3)
	NOT.W	D3
	AND.W	D3,(NEXSPR)+(RESSPR)(A3)
	AND.W	D3,(NEXSPR+SIZSPR)+(RESSPR)(A3)
	SPR2PMAC
SPRC4:
	SWAP	D3
	OR.W	D3,(NEXSPR)(A3)
	NOT.W	D3
	AND.W	D3,(A3)
	AND.W	D3,(SIZSPR)(A3)
	AND.W	D3,(NEXSPR+SIZSPR)(A3)
	SWAP	D3
	OR.W	D3,(NEXSPR)+(RESSPR)(A3)
	NOT.W	D3
	AND.W	D3,(RESSPR)(A3)
	AND.W	D3,(SIZSPR)+(RESSPR)(A3)
	AND.W	D3,(NEXSPR+SIZSPR)+(RESSPR)(A3)
	SPR2PMAC
SPRC5:
	SWAP	D3
	OR.W	D3,(NEXSPR)(A3)
	OR.W	D3,(A3)
	NOT.W	D3
	AND.W	D3,(SIZSPR)(A3)
	AND.W	D3,(NEXSPR+SIZSPR)(A3)
	SWAP	D3
	OR.W	D3,(NEXSPR)+(RESSPR)(A3)
	OR.W	D3,(RESSPR)(A3)
	NOT.W	D3
	AND.W	D3,(SIZSPR)+(RESSPR)(A3)
	AND.W	D3,(NEXSPR+SIZSPR)+(RESSPR)(A3)
	SPR2PMAC
SPRC6:
	SWAP	D3
	OR.W	D3,(SIZSPR)(A3)
	OR.W	D3,(NEXSPR)(A3)
	NOT.W	D3
	AND.W	D3,(A3)
	AND.W	D3,(NEXSPR+SIZSPR)(A3)
	SWAP	D3
	OR.W	D3,(SIZSPR)+(RESSPR)(A3)
	OR.W	D3,(NEXSPR)+(RESSPR)(A3)
	NOT.W	D3
	AND.W	D3,(RESSPR)(A3)
	AND.W	D3,(NEXSPR+SIZSPR)+(RESSPR)(A3)
	SPR2PMAC
SPRC7:
	SWAP	D3
	OR.W	D3,(SIZSPR)(A3)
	OR.W	D3,(NEXSPR)(A3)
	OR.W	D3,(A3)
	NOT.W	D3
	AND.W	D3,(NEXSPR+SIZSPR)(A3)
	SWAP	D3
	OR.W	D3,(SIZSPR)+(RESSPR)(A3)
	OR.W	D3,(NEXSPR)+(RESSPR)(A3)
	OR.W	D3,(RESSPR)(A3)
	NOT.W	D3
	AND.W	D3,(NEXSPR+SIZSPR)+(RESSPR)(A3)
	SPR2PMAC
SPRC8:
	SWAP	D3
	OR.W	D3,(NEXSPR+SIZSPR)(A3)
	NOT.W	D3
	AND.W	D3,(A3)
	AND.W	D3,(SIZSPR)(A3)
	AND.W	D3,(NEXSPR)(A3)
	SWAP	D3
	OR.W	D3,(NEXSPR+SIZSPR)+(RESSPR)(A3)
	NOT.W	D3
	AND.W	D3,(RESSPR)(A3)
	AND.W	D3,(SIZSPR)+(RESSPR)(A3)
	AND.W	D3,(NEXSPR)+(RESSPR)(A3)
	SPR2PMAC
SPRC9:
	SWAP	D3
	OR.W	D3,(NEXSPR+SIZSPR)(A3)
	OR.W	D3,(A3)
	NOT.W	D3
	AND.W	D3,(SIZSPR)(A3)
	AND.W	D3,(NEXSPR)(A3)
	SWAP	D3
	OR.W	D3,(NEXSPR+SIZSPR)+(RESSPR)(A3)
	OR.W	D3,(RESSPR)(A3)
	NOT.W	D3
	AND.W	D3,(SIZSPR)+(RESSPR)(A3)
	AND.W	D3,(NEXSPR)+(RESSPR)(A3)
	SPR2PMAC
SPRCA:
	SWAP	D3
	OR.W	D3,(SIZSPR)(A3)
	OR.W	D3,(NEXSPR+SIZSPR)(A3)
	NOT.W	D3
	AND.W	D3,(A3)
	AND.W	D3,(NEXSPR)(A3)
	SWAP	D3
	OR.W	D3,(SIZSPR)+(RESSPR)(A3)
	OR.W	D3,(NEXSPR+SIZSPR)+(RESSPR)(A3)
	NOT.W	D3
	AND.W	D3,(RESSPR)(A3)
	AND.W	D3,(NEXSPR)+(RESSPR)(A3)
	SPR2PMAC
SPRCB:
	SWAP	D3
	OR.W	D3,(SIZSPR)(A3)
	OR.W	D3,(NEXSPR+SIZSPR)(A3)
	OR.W	D3,(A3)
	NOT.W	D3
	AND.W	D3,(NEXSPR)(A3)
	SWAP	D3
	OR.W	D3,(SIZSPR)+(RESSPR)(A3)
	OR.W	D3,(NEXSPR+SIZSPR)+(RESSPR)(A3)
	OR.W	D3,(RESSPR)(A3)
	NOT.W	D3
	AND.W	D3,(NEXSPR)+(RESSPR)(A3)
	SPR2PMAC
SPRCC:
	SWAP	D3
	OR.W	D3,(NEXSPR)(A3)
	OR.W	D3,(NEXSPR+SIZSPR)(A3)
	NOT.W	D3
	AND.W	D3,(A3)
	AND.W	D3,(SIZSPR)(A3)
	SWAP	D3
	OR.W	D3,(NEXSPR)+(RESSPR)(A3)
	OR.W	D3,(NEXSPR+SIZSPR)+(RESSPR)(A3)
	NOT.W	D3
	AND.W	D3,(RESSPR)(A3)
	AND.W	D3,(SIZSPR)+(RESSPR)(A3)
	SPR2PMAC
SPRCD:
	SWAP	D3
	OR.W	D3,(NEXSPR)(A3)
	OR.W	D3,(NEXSPR+SIZSPR)(A3)
	OR.W	D3,(A3)
	NOT.W	D3
	AND.W	D3,(SIZSPR)(A3)
	SWAP	D3
	OR.W	D3,(NEXSPR)+(RESSPR)(A3)
	OR.W	D3,(NEXSPR+SIZSPR)+(RESSPR)(A3)
	OR.W	D3,(RESSPR)(A3)
	NOT.W	D3
	AND.W	D3,(SIZSPR)+(RESSPR)(A3)
	SPR2PMAC
SPRCE:
	SWAP	D3
	OR.W	D3,(SIZSPR)(A3)
	OR.W	D3,(NEXSPR)(A3)
	OR.W	D3,(NEXSPR+SIZSPR)(A3)
	NOT.W	D3
	AND.W	D3,(A3)
	SWAP	D3
	OR.W	D3,(SIZSPR)+(RESSPR)(A3)
	OR.W	D3,(NEXSPR)+(RESSPR)(A3)
	OR.W	D3,(NEXSPR+SIZSPR)+(RESSPR)(A3)
	NOT.W	D3
	AND.W	D3,(RESSPR)(A3)
	SPR2PMAC
SPRCF:
	SWAP	D3
	OR.W	D3,(NEXSPR+SIZSPR)(A3)
	OR.W	D3,(NEXSPR)(A3)
	OR.W	D3,(SIZSPR)(A3)
	OR.W	D3,(A3)
	SWAP	D3
	OR.W	D3,(NEXSPR+SIZSPR)+(RESSPR)(A3)
	OR.W	D3,(NEXSPR)+(RESSPR)(A3)
	OR.W	D3,(SIZSPR)+(RESSPR)(A3)
	OR.W	D3,(RESSPR)(A3)
	SPR2PMAC
; ---
SPRD1:
	SWAP	D3
	OR.W	D3,(A3)
	SWAP	D3
	OR.W	D3,(RESSPR)(A3)
	SPR2PMAC
SPRD2:
	SWAP	D3
	OR.W	D3,(SIZSPR)(A3)
	SWAP	D3
	OR.W	D3,(SIZSPR)+(RESSPR)(A3)
	SPR2PMAC
SPRD3:
	SWAP	D3
	OR.W	D3,(SIZSPR)(A3)
	OR.W	D3,(A3)
	SWAP	D3
	OR.W	D3,(SIZSPR)+(RESSPR)(A3)
	OR.W	D3,(RESSPR)(A3)
	SPR2PMAC
SPRD4:
	SWAP	D3
	OR.W	D3,(NEXSPR)(A3)
	SWAP	D3
	OR.W	D3,(NEXSPR)+(RESSPR)(A3)
	SPR2PMAC
SPRD5:
	SWAP	D3
	OR.W	D3,(NEXSPR)(A3)
	OR.W	D3,(A3)
	SWAP	D3
	OR.W	D3,(NEXSPR)+(RESSPR)(A3)
	OR.W	D3,(RESSPR)(A3)
	SPR2PMAC
SPRD6:
	SWAP	D3
	OR.W	D3,(SIZSPR)(A3)
	OR.W	D3,(NEXSPR)(A3)
	SWAP	D3
	OR.W	D3,(SIZSPR)+(RESSPR)(A3)
	OR.W	D3,(NEXSPR)+(RESSPR)(A3)
	SPR2PMAC
SPRD7:
	SWAP	D3
	OR.W	D3,(SIZSPR)(A3)
	OR.W	D3,(NEXSPR)(A3)
	OR.W	D3,(A3)
	SWAP	D3
	OR.W	D3,(SIZSPR)+(RESSPR)(A3)
	OR.W	D3,(NEXSPR)+(RESSPR)(A3)
	OR.W	D3,(RESSPR)(A3)
	SPR2PMAC
SPRD8:
	SWAP	D3
	OR.W	D3,(NEXSPR+SIZSPR)(A3)
	SWAP	D3
	OR.W	D3,(NEXSPR+SIZSPR)+(RESSPR)(A3)
	SPR2PMAC
SPRD9:
	SWAP	D3
	OR.W	D3,(NEXSPR+SIZSPR)(A3)
	OR.W	D3,(A3)
	SWAP	D3
	OR.W	D3,(NEXSPR+SIZSPR)+(RESSPR)(A3)
	OR.W	D3,(RESSPR)(A3)
	SPR2PMAC
SPRDA:
	SWAP	D3
	OR.W	D3,(SIZSPR)(A3)
	OR.W	D3,(NEXSPR+SIZSPR)(A3)
	SWAP	D3
	OR.W	D3,(SIZSPR)+(RESSPR)(A3)
	OR.W	D3,(NEXSPR+SIZSPR)+(RESSPR)(A3)
	SPR2PMAC
SPRDB:
	SWAP	D3
	OR.W	D3,(SIZSPR)(A3)
	OR.W	D3,(NEXSPR+SIZSPR)(A3)
	OR.W	D3,(A3)
	SWAP	D3
	OR.W	D3,(SIZSPR)+(RESSPR)(A3)
	OR.W	D3,(NEXSPR+SIZSPR)+(RESSPR)(A3)
	OR.W	D3,(RESSPR)(A3)
	SPR2PMAC
SPRDC:
	SWAP	D3
	OR.W	D3,(NEXSPR)(A3)
	OR.W	D3,(NEXSPR+SIZSPR)(A3)
	SWAP	D3
	OR.W	D3,(NEXSPR)+(RESSPR)(A3)
	OR.W	D3,(NEXSPR+SIZSPR)+(RESSPR)(A3)
	SPR2PMAC
SPRDD:
	SWAP	D3
	OR.W	D3,(NEXSPR)(A3)
	OR.W	D3,(NEXSPR+SIZSPR)(A3)
	OR.W	D3,(A3)
	SWAP	D3
	OR.W	D3,(NEXSPR)+(RESSPR)(A3)
	OR.W	D3,(NEXSPR+SIZSPR)+(RESSPR)(A3)
	OR.W	D3,(RESSPR)(A3)
	SPR2PMAC
SPRDE:
	SWAP	D3
	OR.W	D3,(SIZSPR)(A3)
	OR.W	D3,(NEXSPR)(A3)
	OR.W	D3,(NEXSPR+SIZSPR)(A3)
	SWAP	D3
	OR.W	D3,(SIZSPR)+(RESSPR)(A3)
	OR.W	D3,(NEXSPR)+(RESSPR)(A3)
	OR.W	D3,(NEXSPR+SIZSPR)+(RESSPR)(A3)
	SPR2PMAC
SPRDF:
	SWAP	D3
	OR.W	D3,(NEXSPR+SIZSPR)(A3)
	OR.W	D3,(NEXSPR)(A3)
	OR.W	D3,(SIZSPR)(A3)
	OR.W	D3,(A3)
	SWAP	D3
	OR.W	D3,(NEXSPR+SIZSPR)+(RESSPR)(A3)
	OR.W	D3,(NEXSPR)+(RESSPR)(A3)
	OR.W	D3,(SIZSPR)+(RESSPR)(A3)
	OR.W	D3,(RESSPR)(A3)
	SPR2PMAC
; ---



	CNOP	0,8
SPR2TABLA:
	REPT	8+8
	DC.L	SPRB0,SPRB1,SPRB2,SPRB3,SPRB4,SPRB5,SPRB6,SPRB7
	DC.L	SPRB8,SPRB9,SPRBA,SPRBB,SPRBC,SPRBD,SPRBE,SPRBF
	ENDR
;	REPT	8
;	DC.L	SPRA0,SPRA1,SPRA2,SPRA3,SPRA4,SPRA5,SPRA6,SPRA7
;	DC.L	SPRA8,SPRA9,SPRAA,SPRAB,SPRAC,SPRAD,SPRAE,SPRAF
;	ENDR
SPC2TABLA:
	REPT	16
	DC.L	SPCA0,SPCA1,SPCA2,SPCA3,SPCA4,SPCA5,SPCA6,SPCA7
	DC.L	SPCA8,SPCA9,SPCAA,SPCAB,SPCAC,SPCAD,SPCAE,SPCAF
	ENDR

; ---

SPR2TABLA2:
	REPT	8+8
	DC.L	SPRD0,SPRD1,SPRD2,SPRD3,SPRD4,SPRD5,SPRD6,SPRD7
	DC.L	SPRD8,SPRD9,SPRDA,SPRDB,SPRDC,SPRDD,SPRDE,SPRDF
	ENDR
;	REPT	8
;	DC.L	SPRC0,SPRC1,SPRC2,SPRC3,SPRC4,SPRC5,SPRC6,SPRC7
;	DC.L	SPRC8,SPRC9,SPRCA,SPRCB,SPRCC,SPRCD,SPRCE,SPRCF
;	ENDR
SPC2TABLA2:
	REPT	16
	DC.L	SPCB0,SPCB1,SPCB2,SPCB3,SPCB4,SPCB5,SPCB6,SPCB7
	DC.L	SPCB8,SPCB9,SPCBA,SPCBB,SPCBC,SPCBD,SPCBE,SPCBF
	ENDR


	CNOP	0,8
SPR2_Pila:DC.L	0
	CNOP	0,8
TABCORX:
	DS.B	(260*8)
	DC.L	0

;  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*


;	-----------------------
;	Borrado de MSX2 Sprits.
;	-----------------------

SPC2PMAC:MACRO
	ADD.W	D5,A3			; Siguiente l�nea Y de Pantalla.
	DBF	D1,SPC2PBUC0		; Siguiente l�nea Y de Sprit.
	DBF	D0,SPC2PBUC		; Siguiente Sprit.
	RTS
	CNOP	0,8
	ENDM


	CNOP	0,8
CLEARSPR2:
;;	LEA	BUFERSPR2-2(PC),A0

	MOVE.W	#LINSPR,D5
	MOVE.W	#$0100,D2

;;	MOVEQ	#32-1,D0		; 32 Sprits a imprimir.
	MOVE.W	(A0),D0
	BMI.S	SPC2RET
	MOVE.W	#-1,(A0)+
; ---------------------------------
	MOVEQ	#16-1,D7
	TST.B	-4(A0)
	BEQ.S	SPC2PBUC
	MOVEQ	#8-1,D7
; ---------------------------------
SPC2PBUC:
	MOVEM.L	(A0)+,A2/A3
	MOVE.W	D7,D1			; 16 o 8 Lineas Y de 1 sprit a imprimir.
SPC2PBUC0:
	MOVE.B	(A0)+,D2		; N� de color.
	JMP	([A2,D2.W*4])		; Salto a impresi�n.
SPC2RET:RTS
	CNOP	0,8
SPCA0:
SPCB0:
	SPC2PMAC
SPCA1:
	CLR.L	(A3)
	SPC2PMAC
SPCA2:
	CLR.L	(SIZSPR)(A3)
	SPC2PMAC
SPCA3:
	CLR.L	(A3)
	CLR.L	(SIZSPR)(A3)
	SPC2PMAC
SPCA4:
	CLR.L	(NEXSPR)(A3)
	SPC2PMAC
SPCA5:
	CLR.L	(A3)
	CLR.L	(NEXSPR)(A3)
	SPC2PMAC
SPCA6:
	CLR.L	(SIZSPR)(A3)
	CLR.L	(NEXSPR)(A3)
	SPC2PMAC
SPCA7:
	CLR.L	(A3)
	CLR.L	(SIZSPR)(A3)
	CLR.L	(NEXSPR)(A3)
	SPC2PMAC
SPCA8:
	CLR.L	(NEXSPR+SIZSPR)(A3)
	SPC2PMAC
SPCA9:
	CLR.L	(A3)
	CLR.L	(NEXSPR+SIZSPR)(A3)
	SPC2PMAC
SPCAA:
	CLR.L	(SIZSPR)(A3)
	CLR.L	(NEXSPR+SIZSPR)(A3)
	SPC2PMAC
SPCAB:
	CLR.L	(A3)
	CLR.L	(SIZSPR)(A3)
	CLR.L	(NEXSPR+SIZSPR)(A3)
	SPC2PMAC
SPCAC:
	CLR.L	(NEXSPR)(A3)
	CLR.L	(NEXSPR+SIZSPR)(A3)
	SPC2PMAC
SPCAD:
	CLR.L	(A3)
	CLR.L	(NEXSPR)(A3)
	CLR.L	(NEXSPR+SIZSPR)(A3)
	SPC2PMAC
SPCAE:
	CLR.L	(SIZSPR)(A3)
	CLR.L	(NEXSPR)(A3)
	CLR.L	(NEXSPR+SIZSPR)(A3)
	SPC2PMAC
SPCAF:
	CLR.L	(A3)
	CLR.L	(SIZSPR)(A3)
	CLR.L	(NEXSPR)(A3)
	CLR.L	(NEXSPR+SIZSPR)(A3)
	SPC2PMAC

; ---

SPCB1:
	CLR.W	(A3)
	CLR.W	(RESSPR)(A3)
	SPC2PMAC
SPCB2:
	CLR.W	(SIZSPR)(A3)
	CLR.W	(SIZSPR)+(RESSPR)(A3)
	SPC2PMAC
SPCB3:
	CLR.W	(A3)
	CLR.W	(SIZSPR)(A3)
	CLR.W	(RESSPR)(A3)
	CLR.W	(SIZSPR)+(RESSPR)(A3)
	SPC2PMAC
SPCB4:
	CLR.W	(NEXSPR)(A3)
	CLR.W	(NEXSPR)+(RESSPR)(A3)
	SPC2PMAC
SPCB5:
	CLR.W	(A3)
	CLR.W	(NEXSPR)(A3)
	CLR.W	(RESSPR)(A3)
	CLR.W	(NEXSPR)+(RESSPR)(A3)
	SPC2PMAC
SPCB6:
	CLR.W	(SIZSPR)(A3)
	CLR.W	(NEXSPR)(A3)
	CLR.W	(SIZSPR)+(RESSPR)(A3)
	CLR.W	(NEXSPR)+(RESSPR)(A3)
	SPC2PMAC
SPCB7:
	CLR.W	(A3)
	CLR.W	(SIZSPR)(A3)
	CLR.W	(NEXSPR)(A3)
	CLR.W	(RESSPR)(A3)
	CLR.W	(SIZSPR)+(RESSPR)(A3)
	CLR.W	(NEXSPR)+(RESSPR)(A3)
	SPC2PMAC
SPCB8:
	CLR.W	(NEXSPR+SIZSPR)(A3)
	CLR.W	(NEXSPR+SIZSPR)+(RESSPR)(A3)
	SPC2PMAC
SPCB9:
	CLR.W	(A3)
	CLR.W	(NEXSPR+SIZSPR)(A3)
	CLR.W	(RESSPR)(A3)
	CLR.W	(NEXSPR+SIZSPR)+(RESSPR)(A3)
	SPC2PMAC
SPCBA:
	CLR.W	(SIZSPR)(A3)
	CLR.W	(NEXSPR+SIZSPR)(A3)
	CLR.W	(RESSPR)+(SIZSPR)(A3)
	CLR.W	(NEXSPR+SIZSPR)+(RESSPR)(A3)
	SPC2PMAC
SPCBB:
	CLR.W	(A3)
	CLR.W	(SIZSPR)(A3)
	CLR.W	(NEXSPR+SIZSPR)(A3)
	CLR.W	(RESSPR)(A3)
	CLR.W	(SIZSPR)+(RESSPR)(A3)
	CLR.W	(NEXSPR+SIZSPR)+(RESSPR)(A3)
	SPC2PMAC
SPCBC:
	CLR.W	(NEXSPR)(A3)
	CLR.W	(NEXSPR+SIZSPR)(A3)
	CLR.W	(NEXSPR)+(RESSPR)(A3)
	CLR.W	(NEXSPR+SIZSPR)+(RESSPR)(A3)
	SPC2PMAC
SPCBD:
	CLR.W	(A3)
	CLR.W	(NEXSPR)(A3)
	CLR.W	(NEXSPR+SIZSPR)(A3)
	CLR.W	(RESSPR)(A3)
	CLR.W	(NEXSPR)+(RESSPR)(A3)
	CLR.W	(NEXSPR+SIZSPR)+(RESSPR)(A3)
	SPC2PMAC
SPCBE:
	CLR.W	(SIZSPR)(A3)
	CLR.W	(NEXSPR)(A3)
	CLR.W	(NEXSPR+SIZSPR)(A3)
	CLR.W	(SIZSPR)+(RESSPR)(A3)
	CLR.W	(NEXSPR)+(RESSPR)(A3)
	CLR.W	(NEXSPR+SIZSPR)+(RESSPR)(A3)
	SPC2PMAC
SPCBF:
	CLR.W	(A3)
	CLR.W	(SIZSPR)(A3)
	CLR.W	(NEXSPR)(A3)
	CLR.W	(NEXSPR+SIZSPR)(A3)
	CLR.W	(RESSPR)(A3)
	CLR.W	(SIZSPR)+(RESSPR)(A3)
	CLR.W	(NEXSPR)+(RESSPR)(A3)
	CLR.W	(NEXSPR+SIZSPR)+(RESSPR)(A3)
	SPC2PMAC



	CNOP	0,8
NUMSPR2:DC.L	0
	DC.W	0
	DC.W	-1
BUFERSPR2:
	REPT	100		; (34; sprite bands draw a sprite once per band.)
	DC.L	SPC2TABLA,SPRIT0+16,0,0,0,0
	ENDR

	CNOP	0,8
	DC.L	0
	DC.W	0
	DC.W	-1
BUFERSPR2b:
	REPT	100		; (34; sprite bands draw a sprite once per band.)
	DC.L	SPC2TABLA,SPRIT0b+16,0,0,0,0
	ENDR

;  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
;  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

;   ---------------------------------------------------------------------
;  -=====================================================================-
; <***********************************************************************>
;  -=====================================================================-
;   ---------------------------------------------------------------------


;	 ----------------------------------
;	- Emulaci�n de Disquetera MSX v1.0 -	Por Juan Antonio G�mez.
;	 ----------------------------------

MIRAUNI:MACRO
	MOVE.L	#DISKIOREQ0,BDISKIOREQ
	AND.W	#$0001,\1
	TST.B	(UNIDADES.W,PC,\1.W)
	BEQ	ERNODISCO
	LSR.B	#1,\1
	BCC.S	\@
	MOVE.L	#DISKIOREQ1,BDISKIOREQ
\@:
	ENDM

ED10:				; DRIVES  $????
	SF	D4
	CMP.W	#4,UNIDADA
	BEQ.S	NOMASDR0
	ADDQ.B	#1,D4
NOMASDR0:
	CMP.W	#4,UNIDADB
	BEQ.S	NOMASDR
	BTST	#1,KEY+6(A3)
	BEQ.S	NOMASDR
	ADDQ.B	#1,D4
NOMASDR:
	Otra2

; -==================================================================-

ED11:				; DSKIO   $4010
;	ST	ACTUPANT
;	BRA.S	ESPCONTA
;	CNOP	0,8
;	DC.L	"JAGG"
;ESPCONTA:
;	TST.B	ACTUPANT
;	BNE.S	ESPCONTA
	NOINT


	LEA	UNIDADA(PC),A4
	MOVE.B	D7,D1
	AND.W	#$0001,D1
	CMP.W	#5,(A4,D1.W*2)
	BNE	ED11DRV


; -(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)
; -(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)
	TST.L	DIRVD0
	BNE.S	rSIDISCO
	MOVE.B	#2,D7
	BSET	#0,D3
	SIINT
	Otra2

	CNOP	0,8
rSIDISCO:
	BCLR	#1,$BFE001			; Filtro ON
	MOVEM.L	D0-D4/A0-A2,BUFER(A3)

	MOVE.L	PagRead+(2*4)(A3),PUNTER
	MOVE.L	PagRead+(3*4)(A3),PUNTER+4
	MOVE.L	PagWrite+(2*4)(A3),TIPOST
	MOVE.L	PagWrite+(3*4)(A3),TIPOST+4
	MOVE.L	SLOT3+(1*8)+0,PagRead+(2*4)(A3)
	MOVE.L	SubSLOT3+(1*8)+0,PagRead+(3*4)(A3)
	MOVE.L	SLOT3+(1*8)+4,PagWrite+(2*4)(A3)
	MOVE.L	SubSLOT3+(1*8)+4,PagWrite+(3*4)(A3)

	BTST	#0,D3
	BNE	rGRABAR		; ES GRABAR.

	MOVEQ	#0,D2
	MOVE.W	D6,D2

	MOVE.W	D5,D3
	LSR.W	#8,D3
	SUBQ.W	#1,D3
	BMI	rERDISCO

	MOVE.L	DIRVD0,A0
	MULU	#$200,D2
	ADD.L	D2,A0

rBUCOPYDS:
	MOVE.W	#$200-1,D0
rBUCOPYDS2:
	CogePagE D4,A4
	MOVE.B	(A0)+,(A4)+
	ADDQ.W	#1,D4
	DBF	D0,rBUCOPYDS2
	DBF	D3,rBUCOPYDS
	
	MOVE.L	PUNTER+0,PagRead+(2*4)(A3)
	MOVE.L	PUNTER+4,PagRead+(3*4)(A3)
	MOVE.L	TIPOST+0,PagWrite+(2*4)(A3)
	MOVE.L	TIPOST+4,PagWrite+(3*4)(A3)

	MOVEM.L	BUFER(A3),D0-D4/A0-A2
	BSET	#1,$BFE001			; Filtro OFF
	BCLR	#0,D3
	SIINT
	Otra2
; *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
	CNOP	0,8
rERDISCO:
	MOVE.L	PUNTER+0,PagRead+(2*4)(A3)
	MOVE.L	PUNTER+4,PagRead+(3*4)(A3)
	MOVE.L	TIPOST+0,PagWrite+(2*4)(A3)
	MOVE.L	TIPOST+4,PagWrite+(3*4)(A3)

	MOVEM.L	BUFER(A3),D0-D4/A0-A2
	BSET	#1,$BFE001			; Filtro OFF
	BSET	#0,D3
	MOVE.B	#6,D7
	SIINT
	Otra2
; *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
rGRABAR:
	TST.B	MVDPROT(PC)
	BEQ.S	rGRABARCON

	MOVE.L	PUNTER+0,PagRead+(2*4)(A3)
	MOVE.L	PUNTER+4,PagRead+(3*4)(A3)
	MOVE.L	TIPOST+0,PagWrite+(2*4)(A3)
	MOVE.L	TIPOST+4,PagWrite+(3*4)(A3)

	MOVEM.L	BUFER(A3),D0-D4/A0-A2
	BSET	#1,$BFE001			; Filtro OFF

	TST.B	DirPrefs+$78
	BEQ.S	rGraModNorm

	ST	ProtectDat
	JMP	ZALI		; Avisar al intentar grabar en PROT.

rGraModNorm:
	BSET	#0,D3
	MOVE.B	#0,D7
	SIINT
	Otra2


rGRABARCON:
	MOVEQ	#0,D2
	MOVE.W	D6,D2

	MOVE.W	D5,D3
	LSR.W	#8,D3
	SUBQ.W	#1,D3
	BMI	rERDISCO

	MOVE.L	DIRVD0,A0
	MULU	#$200,D2
	ADD.L	D2,A0
rgBUCOPYDS:
	MOVE.W	#$200-1,D0
rgBUCOPYDS2:
	CogePag	D4,A4
	MOVE.B	(A4)+,(A0)+
	ADDQ.W	#1,D4
	DBF	D0,rgBUCOPYDS2
	DBF	D3,rgBUCOPYDS

	MOVE.L	PUNTER+0,PagRead+(2*4)(A3)
	MOVE.L	PUNTER+4,PagRead+(3*4)(A3)
	MOVE.L	TIPOST+0,PagWrite+(2*4)(A3)
	MOVE.L	TIPOST+4,PagWrite+(3*4)(A3)

	ST	MVDMODIFI			; MVD se ha modificado!

	MOVEM.L	BUFER(A3),D0-D4/A0-A2
	BSET	#1,$BFE001			; Filtro OFF
	BCLR	#0,D3
	SIINT
	Otra2
; -(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)
; -(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)

ED11DRV:
	MOVE.L	SP,PILADIS
	MOVE.L	PILA,SP
	MOVEM.L	D0-D7/A0-A6,-(SP)
	BSR	WBON
; *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
	MOVEM.L	(SP),D0-D7/A0-A6

	MIRAUNI	D7

	MOVE.L	BDISKIOREQ,A1
	MOVE.W	#12,28(A1)		; Comando REMOVE.
	MOVE.L	#0,36(A1)		; Sectores a leer.
	MOVE.L	#0,44(A1)		; Sector inicial.
	MOVE.L	#0,40(A1)		; Bufer de memoria.
	MOVE.L	$4.w,A6
	JSR	-$1C8(A6)		; Mira ni no hay disco.

	MOVEM.L	(SP),D0-D7/A0-A6
	BTST	#0,D3
	BNE	GRABAR		; ES GRABAR.

	MOVEQ	#0,D2
	MOVE.W	D6,D2

	MOVE.W	D5,D3
	LSR.W	#8,D3
	SUBQ.W	#1,D3
	BMI	ERDISCO

;;	MOVE.W	D5,D6
;;	MOVE.W	#18,D5
;;	CMP.B	#$F8,D6
;;	BEQ.S	BUCOPYDS
;;	MOVE.W	#9,D5
BUCOPYDS:
	MOVEM.L	D2-D5/A4,-(SP)
	MOVE.L	BDISKIOREQ,A1
	MOVE.W	#2,28(A1)		; Comando Read.
	MOVE.L	#1*$200,36(A1)		; Sectores a leer.

;;	MOVEQ	#0,D6
;;	MOVE.W	D2,D6
;;	DIVU	#9,D6
;;	SWAP	D6
;;	MOVE.W	D6,D7
;;	SWAP	D6
;;	MULU	D5,D6
;;	ADD.W	D7,D6

	MOVE.L	D2,D6		; Solo quitar esta.

	LSL.L	#6,D6
	LSL.L	#3,D6

	MOVE.L	D6,44(A1)		; Sector inicial.
	MOVE.L	#BUFERSEC,40(A1)	; Bufer de memoria.
	MOVE.L	$4.w,A6
	JSR	-$1C8(A6)		; Lee Sectores.
	MOVEM.L	(SP)+,D2-D5/A4
	TST.L	D0
	BNE	ERLEERDISCO

	LEA	BUFERSEC(PC),A0
	LEA	REGS,A3
	MOVE.W	#$200-1,D0
BUCOPYDS2:
	CogePagE D4,A4
	MOVE.B	(A0)+,(A4)+
	ADDQ.W	#1,D4
	DBF	D0,BUCOPYDS2
	ADDQ.W	#1,D2
	DBF	D3,BUCOPYDS

	MOVEM.L	(SP)+,D0-D7/A0-A6
	BCLR	#0,D3
	BRA	FINED11
; *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
	CNOP	0,8
ERLEERDISCO:
	MOVEM.L	(SP)+,D0-D7/A0-A6
	BSET	#0,D3
	MOVE.B	#4,D7
	BRA.S	FINED11
; *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
	CNOP	0,8
ERDISCO:
	MOVEM.L	(SP)+,D0-D7/A0-A6
	BSET	#0,D3
	MOVE.B	#6,D7
	BRA.S	FINED11
; *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
	CNOP	0,8
FINED11:
	MOVE.B	#(1*56),CONTASEC	; Motor OFF.
	BSR	WBOFF
	MOVE.L	PILADIS,SP
	MOVE.W	#$86E0,$DFF096		; Bpl off
	MOVE.W	INTENA2,$DFF09A
	SIINT
	Otra2
; *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-* -------------------=> GRABAR.
GRABAR:
	MOVE.L	BDISKIOREQ,A1
	MOVE.W	#15,28(A1)
	MOVE.L	$4.w,A6
	JSR	-$1C8(A6)
	MOVE.L	BDISKIOREQ,A1
	TST.L	32(A1)
	BNE	ERDISCOPROT

	MOVEM.L	(SP),D0-D7/A0-A6
	MOVEQ	#0,D2
	MOVE.W	D6,D2

	MOVE.W	D5,D3
	LSR.W	#8,D3
	SUBQ.W	#1,D3
	BMI	ERNODISCO

;;	MOVE.W	D5,D6
;;	MOVE.W	#18,D5
;;	CMP.B	#$F8,D6
;;	BEQ.S	GBUCOPYDS
;;	MOVE.W	#9,D5
GBUCOPYDS:
	LEA	BUFERSEC(PC),A0
	LEA	REGS,A3
	MOVE.W	#$200-1,D0
GBUCOPYDS2:
	CogePag	D4,A4
	MOVE.B	(A4)+,(A0)+
	ADDQ.W	#1,D4
	DBF	D0,GBUCOPYDS2

	MOVEM.L	D2-D5/A4,-(SP)
	MOVE.L	BDISKIOREQ,A1
	MOVE.W	#3,28(A1)		; Comando Write.
	MOVE.L	#1*$200,36(A1)		; Sectores a leer.

;;	MOVEQ	#0,D6
;;	MOVE.W	D2,D6
;;	DIVU	#9,D6
;;	SWAP	D6
;;	MOVE.W	D6,D7
;;	SWAP	D6
;;	MULU	D5,D6
;;	ADD.W	D7,D6

	MOVE.L	D2,D6		; Solo quitar esta.

	LSL.L	#6,D6
	LSL.L	#3,D6

	MOVE.L	D6,44(A1)		; Sector inicial.
	MOVE.L	#BUFERSEC,40(A1)	; Bufer de memoria.
	MOVE.L	$4.w,A6
	JSR	-$1C8(A6)		; Salva Sectores.
	MOVEM.L	(SP)+,D2-D5/A4
	TST.L	D0
	BNE	ERLEERDISCO
	ADDQ.W	#1,D2
	DBF	D3,GBUCOPYDS

	MOVE.L	BDISKIOREQ,A1
	MOVE.W	#4,28(A1)		; Comando UpDate.
	MOVE.L	$4.w,A6
	JSR	-$1C8(A6)		; Actualiza Sectores.

	MOVEM.L	(SP)+,D0-D7/A0-A6
	BCLR	#0,D3
	BRA	FINED11
; *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
	CNOP	0,8
ERDISCOPROT:
	MOVEM.L	(SP)+,D0-D7/A0-A6
	BSET	#0,D3
	MOVE.B	#0,D7
	BRA	FINED11
; *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

; -==================================================================-

ED12:				; DSKCHG  $4013
;	ST	ACTUPANT
;	BRA.S	ESPCONTA2
;	CNOP	0,8
;	DC.L	"JAGG"
;ESPCONTA2:
;	TST.B	ACTUPANT
;	BNE.S	ESPCONTA2
	NOINT


	LEA	UNIDADA(PC),A4
	MOVE.B	D7,D1
	AND.W	#$0001,D1
	CMP.W	#5,(A4,D1.W*2)
	BNE	ED12DRV


; -(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)
; -(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)
	TST.L	DIRVD0
	BNE.S	rSIDISCO2
	MOVE.B	#2,D7
	BSET	#0,D3
	SIINT
	Otra2

	CNOP	0,8
rSIDISCO2:
	BCLR	#0,D3
	AND.W	#$00FF,D5
	bra	ed13
; -(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)
; -(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)

ED12DRV:
	MOVE.L	SP,PILADIS
	MOVE.L	PILA,SP
	MOVEM.L	D0-D7/A0-A6,-(SP)
	BSR	WBON
; *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
	CMP.B	ULTDIS,D7
	BEQ.S	QNODRIVES2
	TST.B	UNIDADES
	BEQ.S	QNODRIVES1
	LEA	DISKIOREQ0,A1
	MOVE.W	#$9,28(A1)
	MOVE.L	#$0,36(A1)
	MOVE.L	$4,A6
	JSR	-$1C8(A6)		; Motor OFF.
QNODRIVES1:
	TST.B	UNIDADES+1
	BEQ.S	QNODRIVES2
	LEA	DISKIOREQ1,A1
	MOVE.W	#$9,28(A1)
	MOVE.L	#$0,36(A1)
	MOVE.L	$4,A6
	JSR	-$1C8(A6)		; Motor OFF.
QNODRIVES2:
	MOVEM.L	(SP),D0-D7/A0-A6
	MOVE.B	D7,ULTDIS
	MIRAUNI	D7

	MOVE.L	BDISKIOREQ,A1
	MOVE.W	#12,28(A1)		; Comando REMOVE.
	MOVE.L	#0,36(A1)		; Sectores a leer.
	MOVE.L	#0,44(A1)		; Sector inicial.
	MOVE.L	#0,40(A1)		; Bufer de memoria.
	MOVE.L	$4.w,A6
	JSR	-$1C8(A6)		; Mira ni no hay disco.

	MOVE.L	BDISKIOREQ,A1
	MOVE.W	#14,28(A1)
	MOVE.L	$4.w,A6
	JSR	-$1C8(A6)
	MOVE.L	BDISKIOREQ,A1
	TST.L	32(A1)
	BEQ	SIDISCO2
ERNODISCO:
	MOVE.B	#(1*56),CONTASEC	; Motor OFF.
	MOVEM.L	(SP)+,D0-D7/A0-A6
	MOVE.B	#2,D7
	BSET	#0,D3
; *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
	BSR	WBOFF
	MOVE.L	PILADIS,SP
	MOVE.W	#$86E0,$DFF096		; Bpl off
	MOVE.W	INTENA2,$DFF09A
	SIINT
	Otra2
SIDISCO2:
	MOVE.L	BDISKIOREQ,A1
	MOVE.W	#5,28(A1)		; Comando Clear.
	MOVE.L	$4.w,A6
	JSR	-$1C8(A6)		; Borra bufer.

	MOVE.B	#(1*56),CONTASEC	; Motor OFF.
	MOVEM.L	(SP)+,D0-D7/A0-A6
	BCLR	#0,D3
	AND.W	#$00FF,D5
; *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
	BSR	WBOFF
	MOVE.L	PILADIS,SP
	MOVE.W	#$86E0,$DFF096		; Bpl off
	MOVE.W	INTENA2,$DFF09A
; -==================================================================-
ED13:				; GETDPB  $4016
	MOVE.W	D5,D1
	LSR.W	#8,D1
	CMP.B	#$F8,D1
	BEQ.S	ESUNACARA
	CogePag	D4,A4
	ADDQ.W	#1,A4
	MOVE.L	DPBBUFER+$00,(A4)+
	MOVE.L	DPBBUFER+$04,(A4)+
	MOVE.L	DPBBUFER+$08,(A4)+
	MOVE.L	DPBBUFER+$0C,(A4)+
	MOVE.W	DPBBUFER+$10,(A4)+
	SIINT
	Otra2
ESUNACARA:
	CogePag	D4,A4
	ADDQ.W	#1,A4
	MOVE.L	DPBBUFER2+$00,(A4)+
	MOVE.L	DPBBUFER2+$04,(A4)+
	MOVE.L	DPBBUFER2+$08,(A4)+
	MOVE.L	DPBBUFER2+$0C,(A4)+
	MOVE.W	DPBBUFER2+$10,(A4)+
	SIINT
	Otra2

; -==================================================================-
ED14:				; CHOICE  $4019
	CLR.W	D4
	Otra2
; -==================================================================-

ED15:				; DSKFMT  $401C
;	ST	ACTUPANT
;	BRA.S	ESPCONTA3
;	CNOP	0,8
;	DC.L	"JAGG"
;ESPCONTA3:
;	TST.B	ACTUPANT
;	BNE.S	ESPCONTA3
	NOINT


	LEA	UNIDADA(PC),A4
	MOVE.B	D7,D1
	AND.W	#$0001,D1
	CMP.W	#5,(A4,D1.W*2)
	BNE	ED15DRV

; -(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)
; -(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)
	BSET	#0,D3
	MOVE.B	#4,D7
	SIINT
	Otra2
; -(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)
; -(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)-(*)

ED15DRV:
	MOVE.L	SP,PILADIS
	MOVE.L	PILA,SP
	MOVEM.L	D0-D7/A0-A6,-(SP)
	BSR	WBON
; *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
	MOVEM.L	(SP),D0-D7/A0-A6

	LSR.W	#8,D6
	MIRAUNI	D6

	MOVE.L	BDISKIOREQ,A1
	MOVE.W	#12,28(A1)		; Comando REMOVE.
	MOVE.L	#0,36(A1)		; Sectores a leer.
	MOVE.L	#0,44(A1)		; Sector inicial.
	MOVE.L	#0,40(A1)		; Bufer de memoria.
	MOVE.L	$4.w,A6
	JSR	-$1C8(A6)		; Mira ni no hay disco.

	MOVE.L	BDISKIOREQ,A1
	MOVE.W	#14,28(A1)
	MOVE.L	$4.w,A6
	JSR	-$1C8(A6)
	MOVE.L	BDISKIOREQ,A1
	TST.L	32(A1)
	BNE	ERNODISCO

	MOVE.L	BDISKIOREQ,A1
	MOVE.W	#15,28(A1)
	MOVE.L	$4.w,A6
	JSR	-$1C8(A6)
	MOVE.L	BDISKIOREQ,A1
	TST.L	32(A1)
	BNE	ERDISCOPROT

	MOVEQ	#0,D2
	MOVEM.L	D2-D3,-(SP)
	MOVE.L	BDISKIOREQ,A1
	MOVE.W	#11,28(A1)		; Comando Format.
	MOVE.L	#9*$200,36(A1)		; Sectores a leer.
	MOVE.L	D2,44(A1)		; Sector inicial.
	MOVE.L	#PISTA0,40(A1)		; Bufer de memoria.
	MOVE.L	$4.w,A6
	JSR	-$1C8(A6)		; Salva Sectores.
	MOVEM.L	(SP)+,D2-D3
	TST.L	D0
	BNE	ERLEERDISCO

	ADD.L	#($200*9),D2
	MOVE.W	#(80*2)-2,D3
FORBUC:
	MOVEM.L	D2-D3,-(SP)
	MOVE.L	BDISKIOREQ,A1
	MOVE.W	#11,28(A1)		; Comando Format.
	MOVE.L	#9*$200,36(A1)		; Sectores a leer.
	MOVE.L	D2,44(A1)		; Sector inicial.
	MOVE.L	#PISTA1,40(A1)		; Bufer de memoria.
	MOVE.L	$4.w,A6
	JSR	-$1C8(A6)		; Salva Sectores.
	MOVEM.L	(SP)+,D2-D3
	TST.L	D0
	BNE	ERLEERDISCO
	ADD.L	#($200*9),D2
	DBF	D3,FORBUC

	MOVEM.L	(SP)+,D0-D7/A0-A6
	BCLR	#0,D3
	BRA	FINED11

; -==================================================================-

	CNOP	0,8
; ------------------------------=>
WBON:
	MOVE.L	PagRead+(2*4)(A3),PUNTER
	MOVE.L	PagRead+(3*4)(A3),PUNTER+4
	MOVE.L	PagWrite+(2*4)(A3),TIPOST
	MOVE.L	PagWrite+(3*4)(A3),TIPOST+4
	MOVE.L	SLOT3+(1*8)+0,PagRead+(2*4)(A3)
	MOVE.L	SubSLOT3+(1*8)+0,PagRead+(3*4)(A3)
	MOVE.L	SLOT3+(1*8)+4,PagWrite+(2*4)(A3)
	MOVE.L	SubSLOT3+(1*8)+4,PagWrite+(3*4)(A3)

	MOVE.W	#$01A0,Int_VDN
	MOVE.W	#$01A0,Int_VD0
	MOVE.W	#$01A0,Int_VD9
	MOVE.W	#$01A0,Int_VD2
	MOVE.W	#$01A0,Int_VD2B
	MOVE.W	#$01A0,Int_VD4
	MOVE.W	#$01A0,Int_VD5
	MOVE.W	#$01A0,Int_VD8
	MOVE.W	#$01A0,Int_CL0
	MOVE.W	#$01A0,Int_CL1

	MOVE.L	NEXTCOPP,D1
	MOVE.W	D1,MCSALTO1+2
	SWAP	D1
	MOVE.W	D1,MCSALTO0+2
	MOVEQ	#0,D1
	ST	INTWB
	TST.B	MULTEC(A3)
	BNE.S	NOBORTEC
	MOVEQ	#-1,D0
	MOVE.L	D0,KEY+0(A3)
	MOVE.L	D0,KEY+4(A3)
	MOVE.L	D0,KEY+8(A3)
	MOVE.L	D0,KEY+12(A3)
NOBORTEC:
	MOVE.W	$DFF01C,INTENA2
	OR.W	#$8000,INTENA2
	MOVE.W	#$7FFF,$DFF09A
	OR.W	#$8000,DMACON
	MOVE.W	DMACON,D1
	NOT.W	D1
	MOVE.W	D1,$DFF096
	MOVE.W	#$7FFF,$DFF09C
	OR.W	#$8000,INTENA
	OR.W	#$8000,INTREQ

	MOVE.L	vBlank,([VBRPun],$6C.W)

	MOVE.W	#$0020,$DFF09C
ESPERAF:BTST	#$05,$DFF01F
	BEQ.S	ESPERAF
	MOVE.W	#$0084,MCSALTO0
	MOVE.W	#$0086,MCSALTO1
	MOVE.W	#$7FFF,$DFF09C
	MOVE.W	DMACON,$DFF096
	MOVE.W	INTREQ,$DFF09C
	MOVE.W	INTENA,$DFF09A
	RTS
; ------------------------------=>
	CNOP	0,8
WBOFF:
	MOVE.L	PUNTER+0,PagRead+(2*4)(A3)
	MOVE.L	PUNTER+4,PagRead+(3*4)(A3)
	MOVE.L	TIPOST+0,PagWrite+(2*4)(A3)
	MOVE.L	TIPOST+4,PagWrite+(3*4)(A3)

	MOVE.W	#$009C,Int_VDN
	MOVE.W	#$009C,Int_VD0
	MOVE.W	#$009C,Int_VD9
	MOVE.W	#$009C,Int_VD2
	MOVE.W	#$009C,Int_VD2B
	MOVE.W	#$009C,Int_VD4
	MOVE.W	#$009C,Int_VD5
	MOVE.W	#$009C,Int_VD8
	MOVE.W	#$009C,Int_CL0
	MOVE.W	#$009C,Int_CL1

	MOVE.W	$DFF01C,INTENA
	MOVE.W	#$7FFF,$DFF09A
	MOVE.W	$DFF01E,INTREQ
	MOVE.W	#$7FFF,$DFF09C
;;	MOVE.W	$DFF002,DMACON

	MOVE.L	#Inter,([VBRPun],$6C.W)

	MOVE.W	#$0020,$DFF09C
ESPERAG:BTST	#$05,$DFF01F
	BEQ.S	ESPERAG
	MOVE.W	#$01A0,MCSALTO0
	MOVE.W	#$01A0,MCSALTO1
	MOVE.W	#$8640,$DFF096
ESPBLIF:BTST	#$06,$DFF002
	BNE.S	ESPBLIF
	JSR	DATOSINIT
	SF	INTWB
	RTS
; ------------------------------=>

	CNOP	0,8
DPBBUFER:
	DC.B	$F9		; Media Descriptor.
	DC.B	$00,$02		; Sector Size (2^n)
	DC.B	(512/32)-1	; (Sector Size/32)-1
	DC.B	4		; Numero bits ???
	DC.B	2-1		; (Sectores por Cluster)-1
	DC.B	1+1		; (Numero de un bits en CLUSMSK)+1
	DC.B	1,0		; Primer sector del Fat.
	DC.B	2		; Numero de FATs
	DC.B	$70		; Numero de entradas de directorios (Max.254)
	DC.B	$0E,$00		; Numero de primer sector de datos.
	DC.B	$CA,$02		; (Numero de Clusters)+1
	DC.B	3
	DC.B	$07,$00
	CNOP	0,8
DPBBUFER2:
	DC.B	$F8		; Media Descriptor.
	DC.B	$00,$02		; Sector Size (2^n)
	DC.B	(512/32)-1	; (Sector Size/32)-1
	DC.B	4		; Numero bits ???
	DC.B	2-1		; (Sectores por Cluster)-1
	DC.B	1+1		; (Numero de un bits en CLUSMSK)+1
	DC.B	1,0		; Primer sector del Fat.
	DC.B	2		; Numero de FATs
	DC.B	$70		; Numero de entradas de directorios (Max.254)
	DC.B	$0C,$00		; Numero de primer sector de datos.
	DC.B	$63,$01		; (Numero de Clusters)+1
	DC.B	2
	DC.B	$05,$00
	CNOP	0,8
CONTASEC:	DC.B	0
ACTUPANT:	DC.B	0
INTWB:		DC.B	0
ULTDIS:		DC.B	0
	CNOP	0,8
PILADIS:	DC.L	0
PUNTER:		DC.L	0,0
TIPOST:		DC.L	0,0

	CNOP	0,8
UNIDADA:	DC.W	0
UNIDADB:	DC.W	0
UNIDADES:	DC.B	0,0
BDISKIOREQ:	DC.L	DISKIOREQ0

	CNOP	0,8
MFMDISK:DC.B	"mfm.device",0,0
	CNOP	0,8
RADDISK:DC.B	"statram.device",0,0
	CNOP	0,8
DISKIOREQ0:	DS.L	20+2
	CNOP	0,8
DISKPORT0:	DS.L	8+2

	CNOP	0,8
DISKIOREQ1:	DS.L	20+2
	CNOP	0,8
DISKPORT1:	DS.L	8+2

	CNOP	0,8
BUFERSEC:	DS.B	512
		DS.B	20

	CNOP	0,8
PISTA0:
	DC.L	$EBFE9041,$4D494741,$0,$2020100,$27000A0,$5F90300
	DC.L	$9000200,$D0ED,$5359C032,$D0C03656,$2336C031
	DC.L	$1FF511AB,$C00E0FCD,$7DF33CCA,$63C01100,$10E1ACD
	DC.L	$7DF32101,$22B9C0,$21003F11,$ABC00E27,$CD7DF3C3
	DC.L	$158C0,$CD000079,$E6FEFE02,$C26AC03A,$D0C0A7CA
	DC.L	$22401185,$C0CD77C0,$E07CD7D,$F318B41A,$B7C8D55F
	DC.L	$E06CD7D,$F3D11318,$F2426F6F,$74206572,$726F720D
	DC.L	$A507265,$73732061,$6E79206B,$65792066,$6F722072
	DC.L	$65747279,$D0A0000,$4D535844,$4F532020,$53595300,$0
	DCB.L	$3F,$0
	DCB.L	$12,$0
	DC.L	$F9FFFF00
	DS.B	$5FC
	DC.L	$F9FFFF00
	DS.B	$9FC
	CNOP	0,8
PISTA1:	DS.B	512*9
	CNOP	0,8


;   ---------------------------------------------------------------------
;  -=====================================================================-
; <***********************************************************************>
;  -=====================================================================-
;   ---------------------------------------------------------------------


;	 --------------------------------
;	- Emulaci�n de la Impresora v1.0 - Por Sergi Mart�nez.
;	 --------------------------------

	CNOP	0,8
OUT90:
	BTST	#0,D1			; Mandar dato cuando "strobe"
	BNE.S	OU90C
	MOVE.B	PRINTER(A3),$BFE101
OU90C:	RTS

OUT91:
	MOVE.B	D1,PRINTER(A3)		; Dato a la impresora.
	RTS

IN90:
	BTST	#0,$BFD000		; Se�al "busy"
	BEQ.S	IN90C
	MOVE.B	#$92,D1
	RTS
	CNOP	0,8
IN90C:
	MOVE.B	#$90,D1
	RTS


;   ---------------------------------------------------------------------
;  -=====================================================================-
; <***********************************************************************>
;  -=====================================================================-
;   ---------------------------------------------------------------------


;	 ------------------------
;	- Emulaci�n del PSG v2.0 -	Base por Sergi Mart�nez.
;	 ------------------------	Actualizaci�n por Juan Antonio G�mez.

FREC:	MACRO
	MOVE.W	PSG+\1(A3),D1
	ROR.W	#8,D1
	LSL.W	#4,D1
	BNE.S	\@SOBU
	MOVEQ	#16,D1
\@SOBU:	MOVE.W	D1,\2
	RTS
	ENDM


CANAL:	MACRO
	MOVEQ	#0,D1
	LSR.B	#1,D2
	BCS.S	\@NOVOL
	MOVE.B	PSG+8+\1(A3),D1
	BTST	#4,D1
	BEQ.S	\@ESOND
	MOVE.B	OndaVol+1(PC),D1
	LSR.B	#1,D1
\@ESOND:AND.W	#$000F,D1
	LSL.B	#1,D1
\@NOVOL:MOVE.W	D1,\2
	ENDM


VOLUM:	MACRO
	BTST	#4,D2
	BEQ.S	\@ONDA
	MOVE.B	OndaVol+1(PC),D2
	LSR.B	#1,D2
\@ONDA:	MOVE.B	D2,D1
	MOVE.B	PSG+7(A3),D2
	BTST	#\1,D2
	BNE.S	\@NOSA
	AND.W	#$000F,D1
	LSL.B	#1,D1
	MOVE.W	D1,\2
\@NOSA:	BTST	#\1+3,D2
	BEQ.S	HAYRUID
	RTS
	ENDM



	CNOP	0,8
SOUND0:
SOUND1:	FREC	0,$DFF0A6
SOUND2:
SOUND3:	FREC	2,$DFF0B6
SOUND4:
SOUND5:	FREC	4,$DFF0C6

SOUND6:
	MOVE.B	D2,D1
	MOVE.B	PSG+7(A3),D2
	AND.B	#%00111000,D2
	EOR.B	#%00111000,D2
	BEQ.S	NOSOU6
	AND.W	#$3F,D1
	LSL.B	#2,D1
	ADD.W	#128,D1
	MOVE.W	D1,$DFF0D6
NOSOU6:	RTS

	
	CNOP	0,8
SOUND7:
	CANAL	0,$DFF0A8
	CANAL	1,$DFF0B8
	CANAL	2,$DFF0C8

	MOVE.B	PSG+7(A3),D2
	MOVE.B	D2,D1
	AND.B	#%00111000,D1
	EOR.B	#%00111000,D1
	BNE.S	SIHAYRUID
	MOVE.L	#ONDA1,$DFF0D0	; ** Cuando no hay ruido **
	MOVE.W	#1,$DFF0D4
	MOVE.W	#1,$DFF0D6
	MOVE.W	#0,$DFF0D8
	RTS
SIHAYRUID:
	MOVE.L	#RUIDO,$DFF0D0	; ** Cuando SI hay ruido **
	MOVE.W	#5000,$DFF0D4	; Size.
	BRA	HAYRUID


SOUND8:	VOLUM	0,$DFF0A8
SOUND9:	VOLUM	1,$DFF0B8
SOUND10:VOLUM	2,$DFF0C8

	CNOP	0,8
HAYRUID:
	MOVE.B	D2,D1
	LSL.W	#8,D1
	SF	D2
	BTST	#3+8,D1
	BNE.S	NORUC1
	MOVE.B	PSG+8(A3),D1
	LSL.B	#4,D1

	BCC.S	NORUC1b
	MOVE.B	OndaVol+1(PC),D1
	LSL.B	#3,D1
NORUC1b:
	MOVE.B	D1,D2
NORUC1:	BTST	#4+8,D1
	BNE.S	NORUC2
	MOVE.B	PSG+9(A3),D1
	LSL.B	#4,D1

	BCC.S	NORUC2b
	MOVE.B	OndaVol+1(PC),D1
	LSL.B	#3,D1
NORUC2b:
	CMP.B	D1,D2
	BHI.S	NORUC2
	MOVE.B	D1,D2
NORUC2:	BTST	#5+8,D1
	BNE.S	NORUC3
	MOVE.B	PSG+10(A3),D1
	LSL.B	#4,D1

	BCC.S	NORUC3b
	MOVE.B	OndaVol+1(PC),D1
	LSL.B	#3,D1
NORUC3b:
	CMP.B	D1,D2
	BHI.S	NORUC3
	MOVE.B	D1,D2
NORUC3:	MOVEQ	#0,D1
	MOVE.B	D2,D1
	LSR.W	#3,D1
	SUBQ.W	#7,D1
	BCS.S	NORUC4
	MOVE.W	D1,$DFF0D8
	RTS
NORUC4:	CLR.W	$DFF0D8
	RTS


SOUND11:RTS
SOUND12:RTS
SOUND13:
	MOVE.W	#31,OndaVol
	RTS

SOUND14:RTS

SOUND15:BTST	#6,D2
	BNE.S	ES_PORT2
	MOVE.B	DATOJOY1(A3),PSG+$E(A3)
	RTS
ES_PORT2:
	MOVE.B	DATOJOY2(A3),PSG+$E(A3)
	RTS


	CNOP	0,8
TocaPSG:
	MOVEM.W	D1-D2,-(SP)
	MOVE.B	PSG+7(A3),D1

	TST.W	OndaVol(PC)
	BEQ.S	NoOnda
	SUBQ.W	#4,OndaVol
	BCC.S	NoOnda
	CLR.W	OndaVol
NoOnda:
	BTST	#0,D1
	BNE.S	NoOnda0
	BTST	#4,PSG+8(A3)
	BEQ.S	NoOnda0
	MOVE.W	OndaVol(PC),$DFF0A8
NoOnda0:
	BTST	#1,D1
	BNE.S	NoOnda1
	BTST	#4,PSG+9(A3)
	BEQ.S	NoOnda1
	MOVE.W	OndaVol(PC),$DFF0B8
NoOnda1:
	BTST	#2,D1
	BNE.S	NoOnda2
	BTST	#4,PSG+10(A3)
	BEQ.S	NoOnda2
	MOVE.W	OndaVol(PC),$DFF0C8
NoOnda2:

	LSL.W	#8,D1
	SF	D2
	BTST	#3+8,D1
	BNE.S	tNORUC1
	MOVE.B	PSG+8(A3),D1
	LSL.B	#4,D1

	BCC.S	tNORUC1b
	MOVE.B	OndaVol+1(PC),D1
	LSL.B	#3,D1
tNORUC1b:
	MOVE.B	D1,D2
tNORUC1:
	BTST	#4+8,D1
	BNE.S	tNORUC2
	MOVE.B	PSG+9(A3),D1
	LSL.B	#4,D1

	BCC.S	tNORUC2b
	MOVE.B	OndaVol+1(PC),D1
	LSL.B	#3,D1
tNORUC2b:
	CMP.B	D1,D2
	BHI.S	tNORUC2
	MOVE.B	D1,D2
tNORUC2:
	BTST	#5+8,D1
	BNE.S	tNORUC3
	MOVE.B	PSG+10(A3),D1
	LSL.B	#4,D1

	BCC.S	tNORUC3b
	MOVE.B	OndaVol+1(PC),D1
	LSL.B	#3,D1
tNORUC3b:
	CMP.B	D1,D2
	BHI.S	tNORUC3
	MOVE.B	D1,D2
tNORUC3:
	MOVEQ	#0,D1
	MOVE.B	D2,D1
	LSR.W	#3,D1
	SUBQ.W	#7,D1
	BCC.S	tNORUC4
	MOVEQ	#0,D1
tNORUC4:
	MOVE.W	D1,$DFF0D8
	MOVEM.W	(SP)+,D1-D2
	RTS

	CNOP	0,8
OndaVol:DC.W	0,0

; ----------------------------------------------<


;   ---------------------------------------------------------------------
;  -=====================================================================-
; <***********************************************************************>
;  -=====================================================================-
;   ---------------------------------------------------------------------


;	 ----------------------------
;	- Emulaci�n del FM-Pack v0.1 -	Por Juan Antonio G�mez.
;	 ----------------------------


MFMPak:	MACRO
	MOVE.L	#ONDA,\2	; Onda
	MOVE.W	#01,\2+$4	; Size

	MOVE.B	$30+\1(A0),D0
	NOT.W	D0
	AND.W	#$000F,D0

	BTST	#4,$20+\1(A0)	; On/Off
	BNE.S	\@EsOn
	MOVEQ	#$0,D0
\@EsOn:
	MOVE.W	D0,\2+$8	; Volum

	MOVE.B	\1(A0),D2
	AND.W	#$000F,D2

	MOVE.B	$20+\1(A0),D1
	LSR.W	#1,D1
	AND.W	#$0007,D1
	MOVE.W	$20+\1(A0),D0
	MOVE.B	$10+\1(A0),D0
	NOT.W	D0
	AND.W	#$01FF,D0
	MOVE.W	(TABFRE,PC,D0.W*2),D0
\@TT:
	LSL.W	D1,D0
	MOVE.W	D0,\2+$6	; Frec.
	ENDM



	CNOP	0,8
TocaFMPak:
	MOVEM.L	D0-D2/A0,-(SP)
	LEA	TABLA7C,A0


	MFMPak	4,$DFF0A0
	MFMPak	0,$DFF0B0
	MFMPak	1,$DFF0C0
	MFMPak	2,$DFF0D0


; ---
	MOVEM.L	(SP)+,D0-D2/A0
	RTS

TABFRE:
	DCB.W	$AD-$00,212
	DCB.W	$B7-$AD,200
	DCB.W	$C2-$B7,189
	DCB.W	$CD-$C2,178
	DCB.W	$D9-$CD,168
	DCB.W	$E6-$D9,159
	DCB.W	$F4-$E6,150
	DCB.W	$103-$F4,141
	DCB.W	$112-$103,133
	DCB.W	$122-$112,252*2
	DCB.W	$134-$122,208*2
	DCB.W	$146-$134,224*2

	DCB.W	$220-$146,224*2



;   ---------------------------------------------------------------------
;  -=====================================================================-
; <***********************************************************************>
;  -=====================================================================-
;   ---------------------------------------------------------------------


;	 ------------------------
;	- Emulaci�n del SCC v1.0 -	Por Juan Antonio G�mez.
;	 ------------------------

	CNOP	0,8
TocaSCC:
	SUBQ.B	#1,D0
	BNE	EsSCCPlus


MSCC:	MACRO
	LEA	\2,A1
	MOVEQ	#0,D2
	LSR.B	#1,D1
	BCC.S	\@SCCOFF

	MOVE.W	$80+(\1*2)(A0),D0
	ROR.W	#8,D0
	AND.W	#$0FFF,D0

	MOVE.B	$8A+\1(A0),D2
	AND.W	#$000F,D2
	LSL.W	#2,D2

	MOVE.L	#SCONDA0+(\1*$20),(A1)
	MOVE.W	#16,4(A1)
	CMP.W	#128,D0
	BGE.S	\@SFRC
	SUB.B	$8A+\1(A0),D2
	MOVE.L	#SONDA\1,(A1)
	MOVE.W	#8,4(A1)
	LSL.W	#1,D0
	BNE.S	\@SFRC
	MOVEQ	#2,D0
\@SFRC:	MOVE.W	D0,6(A1)
\@SCCOFF:
	MOVE.W	D2,8(A1)
	ENDM


MSCC2:	MACRO
	LEA	\2,A1
	MOVEQ	#0,D2
	LSR.B	#1,D1
	BCS.S	\@SCCON
\@SCCOFF:
	MOVE.W	$80+(4*2)(A0),D0
	ROR.W	#8,D0
	AND.W	#$0FFF,D0

	MOVE.B	$8A+4(A0),D2
	AND.W	#$000F,D2
	LSL.W	#2,D2

	MOVE.L	#SCONDA0+(3*$20),(A1)
	MOVE.W	#16,4(A1)
	CMP.W	#128,D0
	BGE.S	\@SFRC2
	SUB.B	$8A+4(A0),D2
	MOVE.L	#SONDA3,(A1)
	MOVE.W	#8,4(A1)
	LSL.W	#1,D0
	BNE.S	\@SFRC2
	MOVEQ	#2,D0
\@SFRC2:MOVE.W	D0,6(A1)
	MOVE.W	D2,8(A1)

	BRA	\3
	CNOP	0,8
\@SCCON:
	MOVE.W	$80+(\1*2)(A0),D0
	ROR.W	#8,D0
	AND.W	#$0FFF,D0

	MOVE.B	$8A+\1(A0),D2
	AND.W	#$000F,D2
	BEQ	\@SCCOFF
	LSL.W	#2,D2

	MOVE.L	#SCONDA0+(\1*$20),(A1)
	MOVE.W	#16,4(A1)
	CMP.W	#128,D0
	BGE.S	\@SFRC
	SUB.B	$8A+\1(A0),D2
	MOVE.L	#SONDA\1,(A1)
	MOVE.W	#8,4(A1)
	LSL.W	#1,D0
	BNE.S	\@SFRC
	MOVEQ	#2,D0
\@SFRC:	MOVE.W	D0,6(A1)
	MOVE.W	D2,8(A1)

\@SCCFIN:
	ENDM


	MOVEM.L	D3-D7/A0-A1,-(SP)

	LEA	SCCKO+$1800,A0
	LEA	SCONDA0,A1

	TST.B	Modo060(A3)		; Mira si es un 060.
	BNE.S	EsSCC060

	MOVEP	00+32*0(A0),D0
	MOVEP	08+32*0(A0),D1
	MOVEP	16+32*0(A0),D2
	MOVEP	24+32*0(A0),D3
	MOVEM.L	D0-D3,(32*5)+(16*0)(A1)
	MOVEP	00+32*1(A0),D0
	MOVEP	08+32*1(A0),D1
	MOVEP	16+32*1(A0),D2
	MOVEP	24+32*1(A0),D3
	MOVEM.L	D0-D3,(32*5)+(16*1)(A1)
	MOVEP	00+32*2(A0),D0
	MOVEP	08+32*2(A0),D1
	MOVEP	16+32*2(A0),D2
	MOVEP	24+32*2(A0),D3
	MOVEM.L	D0-D3,(32*5)+(16*2)(A1)
	MOVEP	00+32*3(A0),D0
	MOVEP	08+32*3(A0),D1
	MOVEP	16+32*3(A0),D2
	MOVEP	24+32*3(A0),D3
	MOVEM.L	D0-D3,(32*5)+(16*3)(A1)

	BRA	EsSCCCont
	CNOP	0,8
EsSCC060:

SCC060:	MACRO
	MOVE.W	(A0)+,\1
	MOVE.B	(A0)+,\1
	ADDQ.W	#1,A0
	SWAP	\1
	MOVE.W	(A0)+,\1
	MOVE.B	(A0)+,\1
	ADDQ.W	#1,A0
	ENDM

	SCC060	D0
	SCC060	D1
	SCC060	D2
	SCC060	D3
	MOVEM.L	D0-D3,(32*5)+(16*0)(A1)
	SCC060	D0
	SCC060	D1
	SCC060	D2
	SCC060	D3
	MOVEM.L	D0-D3,(32*5)+(16*1)(A1)
	SCC060	D0
	SCC060	D1
	SCC060	D2
	SCC060	D3
	MOVEM.L	D0-D3,(32*5)+(16*2)(A1)
	SCC060	D0
	SCC060	D1
	SCC060	D2
	SCC060	D3
	MOVEM.L	D0-D3,(32*5)+(16*3)(A1)

	LEA	SCCKO+$1800,A0
EsSCCCont:

	MOVEM.L	(A0)+,D0-D7
	MOVEM.L	D0-D7,(A1)
	MOVEM.L	(A0)+,D0-D7
	MOVEM.L	D0-D7,(32*1)(A1)
	MOVEM.L	(A0)+,D0-D7
	MOVEM.L	D0-D7,(32*2)(A1)
	MOVEM.L	(A0)+,D0-D7
	MOVEM.L	D0-D7,(32*3)(A1)

	LEA	SCCKO+$1800,A0
	MOVE.B	$8F(A0),D1
	BTST	#4,D1
	BEQ	NOSCC4

	MSCC2	0,$DFF0A0,SCC0
	MSCC2	1,$DFF0B0,SCC1
	MSCC2	2,$DFF0C0,SCC2
	MSCC2	3,$DFF0D0,SCC3
	MOVEM.L	(SP)+,D3-D7/A0-A1
	RTS
	CNOP	0,8
NOSCC4:
	MSCC	0,$DFF0A0
SCC0:	MSCC	1,$DFF0B0
SCC1:	MSCC	2,$DFF0C0
SCC2:	MSCC	3,$DFF0D0
SCC3:	MOVEM.L	(SP)+,D3-D7/A0-A1
	RTS


;	----
;	SCC+
;	----

MSCCP:	MACRO
	LEA	\2,A1
	MOVEQ	#0,D2
	LSR.B	#1,D1
	BCC.S	\@SCCOFF

	MOVE.W	$A0+(\1*2)(A0),D0
	ROR.W	#8,D0
	AND.W	#$0FFF,D0

	MOVE.B	$AA+\1(A0),D2
	AND.W	#$000F,D2
	LSL.W	#2,D2

	MOVE.L	#SCONDA0+(\1*$20),(A1)
	MOVE.W	#16,4(A1)
	CMP.W	#128,D0
	BGE.S	\@SFRC
	SUB.B	$AA+\1(A0),D2
	MOVE.L	#SONDA\1,(A1)
	MOVE.W	#8,4(A1)
	LSL.W	#1,D0
	BNE.S	\@SFRC
	MOVEQ	#2,D0
\@SFRC:	MOVE.W	D0,6(A1)
\@SCCOFF:
	MOVE.W	D2,8(A1)
	ENDM


MSCCP2:	MACRO
	LEA	\2,A1
	MOVEQ	#0,D2
	LSR.B	#1,D1
	BCS.S	\@SCCON
\@SCCOFF:
	MOVE.W	$A0+(4*2)(A0),D0
	ROR.W	#8,D0
	AND.W	#$0FFF,D0

	MOVE.B	$AA+4(A0),D2
	AND.W	#$000F,D2
	LSL.W	#2,D2

	MOVE.L	#SCONDA0+(4*$20),(A1)
	MOVE.W	#16,4(A1)
	CMP.W	#128,D0
	BGE.S	\@SFRC2
	SUB.B	$AA+4(A0),D2
	MOVE.L	#SONDA4,(A1)
	MOVE.W	#8,4(A1)
	LSL.W	#1,D0
	BNE.S	\@SFRC2
	MOVEQ	#2,D0
\@SFRC2:MOVE.W	D0,6(A1)
	MOVE.W	D2,8(A1)

	BRA	\3
	CNOP	0,8
\@SCCON:
	MOVE.W	$A0+(\1*2)(A0),D0
	ROR.W	#8,D0
	AND.W	#$0FFF,D0

	MOVE.B	$AA+\1(A0),D2
	AND.W	#$000F,D2
	BEQ	\@SCCOFF
	LSL.W	#2,D2

	MOVE.L	#SCONDA0+(\1*$20),(A1)
	MOVE.W	#16,4(A1)
	CMP.W	#128,D0
	BGE.S	\@SFRC
	SUB.B	$AA+\1(A0),D2
	MOVE.L	#SONDA\1,(A1)
	MOVE.W	#8,4(A1)
	LSL.W	#1,D0
	BNE.S	\@SFRC
	MOVEQ	#2,D0
\@SFRC:	MOVE.W	D0,6(A1)
	MOVE.W	D2,8(A1)

\@SCCFIN:
	ENDM



	CNOP	0,8
EsSCCPlus:
	MOVEM.L	D3-D7/A0-A1,-(SP)

	LEA	SCCKO+$3800,A0
	LEA	SCONDA0,A1

	TST.B	Modo060(A3)		; Mira si es un 060.
	BNE.S	EsSCCP060

	MOVEP	00+32*0(A0),D0
	MOVEP	08+32*0(A0),D1
	MOVEP	16+32*0(A0),D2
	MOVEP	24+32*0(A0),D3
	MOVEM.L	D0-D3,(32*5)+(16*0)(A1)
	MOVEP	00+32*1(A0),D0
	MOVEP	08+32*1(A0),D1
	MOVEP	16+32*1(A0),D2
	MOVEP	24+32*1(A0),D3
	MOVEM.L	D0-D3,(32*5)+(16*1)(A1)
	MOVEP	00+32*2(A0),D0
	MOVEP	08+32*2(A0),D1
	MOVEP	16+32*2(A0),D2
	MOVEP	24+32*2(A0),D3
	MOVEM.L	D0-D3,(32*5)+(16*2)(A1)
	MOVEP	00+32*3(A0),D0
	MOVEP	08+32*3(A0),D1
	MOVEP	16+32*3(A0),D2
	MOVEP	24+32*3(A0),D3
	MOVEM.L	D0-D3,(32*5)+(16*3)(A1)
	MOVEP	00+32*4(A0),D0
	MOVEP	08+32*4(A0),D1
	MOVEP	16+32*4(A0),D2
	MOVEP	24+32*4(A0),D3
	MOVEM.L	D0-D3,(32*5)+(16*4)(A1)

	BRA	EsSCCPCont
	CNOP	0,8
EsSCCP060:
	SCC060	D0
	SCC060	D1
	SCC060	D2
	SCC060	D3
	MOVEM.L	D0-D3,(32*5)+(16*0)(A1)
	SCC060	D0
	SCC060	D1
	SCC060	D2
	SCC060	D3
	MOVEM.L	D0-D3,(32*5)+(16*1)(A1)
	SCC060	D0
	SCC060	D1
	SCC060	D2
	SCC060	D3
	MOVEM.L	D0-D3,(32*5)+(16*2)(A1)
	SCC060	D0
	SCC060	D1
	SCC060	D2
	SCC060	D3
	MOVEM.L	D0-D3,(32*5)+(16*3)(A1)
	SCC060	D0
	SCC060	D1
	SCC060	D2
	SCC060	D3
	MOVEM.L	D0-D3,(32*5)+(16*4)(A1)

	LEA	SCCKO+$3800,A0
EsSCCPCont:

	MOVEM.L	(A0)+,D0-D7
	MOVEM.L	D0-D7,(A1)
	MOVEM.L	(A0)+,D0-D7
	MOVEM.L	D0-D7,(32*1)(A1)
	MOVEM.L	(A0)+,D0-D7
	MOVEM.L	D0-D7,(32*2)(A1)
	MOVEM.L	(A0)+,D0-D7
	MOVEM.L	D0-D7,(32*3)(A1)
	MOVEM.L	(A0)+,D0-D7
	MOVEM.L	D0-D7,(32*4)(A1)

	LEA	SCCKO+$3800,A0
	MOVE.B	$AF(A0),D1
	BTST	#4,D1
	BEQ	NOSCCP4

	MSCCP2	0,$DFF0A0,SCCP0
	MSCCP2	1,$DFF0B0,SCCP1
	MSCCP2	2,$DFF0C0,SCCP2
	MSCCP2	3,$DFF0D0,SCCP3
	MOVEM.L	(SP)+,D3-D7/A0-A1
	RTS
	CNOP	0,8
NOSCCP4:
	MSCCP	0,$DFF0A0
SCCP0:	MSCCP	1,$DFF0B0
SCCP1:	MSCCP	2,$DFF0C0
SCCP2:	MSCCP	3,$DFF0D0
SCCP3:	MOVEM.L	(SP)+,D3-D7/A0-A1
	RTS



;   ---------------------------------------------------------------------
;  -=====================================================================-
; <***********************************************************************>
;  -=====================================================================-
;   ---------------------------------------------------------------------




; -----------------------------------------------------------------
; =================================================================
; *****************************************************************
; ***								***
; ***            Rutinas para manejar CopperLine		***
; ***								***
; *****************************************************************
; =================================================================
; -----------------------------------------------------------------


	CNOP	0,8
ActCopperLine:
	LEA	Regs,A3
; ----------------------------------=> Pone datos de posible desbordamiento de BG.
	MOVE.W	DesLinY(A3),D1
	OR.B	#$01,(TabRasCMDS.L,D1.W)
	ST	DesLinY+1(A3)
; ----------------------------------<=


; ----------------------------------=> Borra CopperLine de frame anterior.
	MOVE.L	TabRasRESTdos,A0
	MOVE.W	(A0),D0
	BMI.S	AcCoCon0
	MOVE.W	#-1,(A0)+
AcCoBuc0:
	MOVE.W	#$009C,([A0])
	ADDQ.W	#4,A0
	DBF	D0,AcCoBuc0
AcCoCon0:
; ----------------------------------<=

; ----------------------------------=> CopperLine Base.
	MOVE.L	TabRasRESTDos,A2	; Guarda punteros para Borrar CopperLine usados.
	ADDQ.W	#2,A2
	MOVE.L	CopperOptsDos,A3	; Puntero a ChipMen para Rutinas.
	MOVE.L	CopperLineDos,A5	; Puntero a CopperLine actual.

	LEA	TabRasCMDS,A6
	MOVE.W	#(212)-1,D6
	MOVEQ	#0,D7
AcCoBuc:
	TST.B	(A6)+
	BNE	AcCoRut
AcCoRet:
	ADDQ.B	#1,D7
	DBF	D6,AcCoBuc
; ----------------------------------<=




; ----------------------------------=> Intercambia Base de Tablas dobles.
;	MOVE.L	TabRasRESTDos,A0
;	MOVE.L	TabRasRESTUno,TabRasRESTDos
;	MOVE.L	A0,TabRasRESTUno
;
;	MOVE.L	CopperOptsDos,A0
;	MOVE.L	CopperOptsUno,CopperOptsDos
;	MOVE.L	A0,CopperOptsUno
;
;	MOVE.L	CopperLineDos,A0
;	MOVE.L	CopperLineUno,CopperLineDos
;	MOVE.L	A0,CopperLineUno
; ----------------------------------<=
	RTS

; ----------------------------------=>
	CNOP	0,8
AcCoRut:
	MOVE.B	-(A6),D5
	SF	(A6)+

	MOVE.W	D7,D1

	MULU	#(CoppLineSize),D1
	LEA	$0A(A5,D1.W),A4

	MOVE.L	A3,D3
	MOVE.W	D3,(A4)+
	SWAP	D3
	MOVE.W	D3,-6(A4)

	LEA	(CoppLineSize)(A5,D1.W),A4
	MOVE.L	A4,-(SP)

	SUBQ.W	#4,A4
	MOVE.W	#$008A,(A4)

	MOVE.L	A4,(A2)+
	ADDQ.W	#1,([TabRasRESTDos])

	IFEQ	ColorDebug			;*;
	MOVE.L	#$01800A00,(A3)+		;*;
	ENDC					;*;



	LSR.B	#1,D5
	CALLCS	AcCoRutGBY

	LSR.B	#1,D5
	CALLCS	AcCoRutAdjust

	LSR.B	#1,D5
	CALLCS	AcCoRutPal

	LSR.B	#1,D5
	CALLCS	AcCoRutBlank



	IFEQ	ColorDebug			;*;
	MOVE.W	#$0180,(A3)+			;*;
	MOVE.W	ColBorde+2,(A3)+		;*;
	ENDC					;*;


	MOVE.L	(SP)+,D3

	MOVE.W	#$0086,(A3)+
	MOVE.W	D3,(A3)+
	MOVE.W	#$0084,(A3)+		; Retorno Copper 
	SWAP	D3
	MOVE.W	D3,(A3)+

	MOVE.L	#$008A0000,(A3)+

	BRA	AcCoRet
; ----------------------------------<=

; Palette for line D7 (line 0: PalTop, else its OUT9Ab event): one MOVE per
; COLORMSX2 entry (its register; entry k = MSX colour k EOR MCAGA+10), not
; the border's $180 (COLBORDE).
AcCoRutPal:
	MOVEM.L	D1-D2/D4/A0-A1,-(SP)
	LEA	PalTop,A0
	TST.W	D7
	BEQ.S	ACPalGo
	MOVE.W	PalEvN,D1
ACPalFind:
	SUBQ.W	#1,D1
	BMI.W	ACPalFin
	CMP.W	(PalEvLines.L,D1.W*2),D7
	BNE.S	ACPalFind
	LSL.W	#5,D1
	LEA	(PalEvBuf.L,D1.W),A0
ACPalGo:
	MOVEQ	#0,D4
	MOVE.B	MCAGA+10,D4
	LEA	COLORMSX2,A1
	MOVEQ	#0,D1
ACPalBuc:
	MOVE.W	(A1),D2
	CMP.W	#$0180,D2
	BEQ.S	ACPalNx
	MOVE.W	D2,(A3)+
	MOVE.W	D1,D2
	EOR.B	D4,D2
	AND.W	#$0F,D2
	BNE.S	ACPalCol
	BTST	#5,REGS+DVDP8		; MSX colour 0 with TP off: transparent,
	BNE.S	ACPalCol		; so the border colour (COLBORDE does
	MOVE.W	D4,D2			; the same for the frame; palette[0] here
	AND.W	#$0F,D2			; showed Lilly's yellow colour 0).
ACPalCol:
	MOVE.W	(A0,D2.W*2),(A3)+
ACPalNx:
	ADDQ.W	#4,A1
	ADDQ.W	#1,D1
	CMP.W	#16,D1
	BCS.S	ACPalBuc
	TST.W	D7			; Line 0 on AGA (not SCREEN 8): the blank
	BNE.S	ACPalFin		; bank, colours 32-47, all the border
	CMP.W	#$01FC,MCAGA		; colour (BPLCON3 bank 1, then back).
	BNE.S	ACPalFin
	CMP.B	#$07,REGS+ScrModo
	BEQ.S	ACPalFin
	MOVE.L	#$01062C40,(A3)+
	MOVE.W	#$0180,D1
ACPalBk:
	MOVE.W	D1,(A3)+
	MOVE.W	ColBorde+2,(A3)+
	ADDQ.W	#2,D1
	CMP.W	#$01A0,D1
	BCS.S	ACPalBk
	MOVE.L	#$01060C40,(A3)+
ACPalFin:
	MOVEM.L	(SP)+,D1-D2/D4/A0-A1
	RTS

; Display disabled from line D7 (R#1 BL, BlankTab 1): every COLORMSX2
; register to the border colour (bitplane DMA stays on, so the planes' line
; pointers keep moving). Enabled again (BlankTab 2): the palette in effect at
; that line (the last palette event at or above it, else PalTop).
AcCoRutBlank:
	MOVEM.L	D1-D2/D4/A0-A1,-(SP)
	MOVE.B	(BlankTab.L,D7.W),D1
	CLR.B	(BlankTab.L,D7.W)
	CMP.W	#$01FC,MCAGA		; AGA, not SCREEN 8: switch the planes to
	BNE.S	ACBlEcs			; the blank bank (colours 32-47, filled
	CMP.B	#$07,REGS+ScrModo	; at line 0 by AcCoRutPal) and back: one
	BEQ.S	ACBlEcs			; MOVE each, so it fits in the blanking.
	MOVE.W	#$010C,(A3)+		; BPLCON4 as MASTERCOPPER has it (its
	MOVE.W	MCAGA+10,D2		; BPLAM is R#7's colour: the hardware
	CMP.B	#1,D1			; does the colour EOR), and to blank,
	BNE.S	ACBlOn4			; with the bank bit too (32-47).
	EOR.W	#$2000,D2
ACBlOn4:
	MOVE.W	D2,(A3)+
	BRA.W	ACBlFin
ACBlEcs:
	LEA	COLORMSX2,A1
	MOVEQ	#0,D2
	CMP.B	#1,D1
	BNE.S	ACBlOn
ACBlBuc:
	MOVE.W	(A1),D1
	CMP.W	#$0180,D1
	BEQ.S	ACBlNx
	MOVE.W	D1,(A3)+
	MOVE.W	ColBorde+2,(A3)+
ACBlNx:
	ADDQ.W	#4,A1
	ADDQ.W	#1,D2
	CMP.W	#16,D2
	BCS.S	ACBlBuc
	BRA.S	ACBlFin
ACBlOn:
	CMP.B	#2,D1
	BNE.S	ACBlFin
	LEA	PalTop,A0
	MOVEQ	#0,D1
ACBlEv:
	CMP.W	PalEvN,D1
	BCC.S	ACBlGo
	CMP.W	(PalEvLines.L,D1.W*2),D7
	BCS.S	ACBlGo
	MOVE.W	D1,D4
	LSL.W	#5,D4
	LEA	(PalEvBuf.L,D4.W),A0
	ADDQ.W	#1,D1
	BRA.S	ACBlEv
ACBlGo:
	MOVEQ	#0,D4
	MOVE.B	MCAGA+10,D4
ACBlPal:
	MOVE.W	(A1),D1
	CMP.W	#$0180,D1
	BEQ.S	ACBlPNx
	MOVE.W	D1,(A3)+
	MOVE.W	D2,D1
	EOR.B	D4,D1
	AND.W	#$0F,D1
	BNE.S	ACBlCol
	BTST	#5,REGS+DVDP8		; Colour 0, TP off: the border colour.
	BNE.S	ACBlCol
	MOVE.W	D4,D1
	AND.W	#$0F,D1
ACBlCol:
	MOVE.W	(A0,D1.W*2),(A3)+
ACBlPNx:
	ADDQ.W	#4,A1
	ADDQ.W	#1,D2
	CMP.W	#16,D2
	BCS.S	ACBlPal
ACBlFin:
	MOVEM.L	(SP)+,D1-D2/D4/A0-A1
	RTS

AcCoRutAdjust:

;	CMP.B	#$07,Regs+ScrModo	; �Es Screen 8?
;	BEQ.S	AcCoAdjRet

	LEA	(TabRasDATA.L,D7.W*8),A0

	MOVE.B	3(A0),D1		; VDP ($12)
	AND.W	#$000F,D1
	MOVE.W	#$0102,(A3)+
	MOVE.W	(AdjustBuf.W,PC,D1.W*4),(A3)+

	MOVE.W	VERPAN+2,D4
	MOVE.B	(AdjustBuf+2.w,PC,D1.W*4),D4
	TST.B	PrefMask		; (Mask screen edges, as Act_Adjust.)
	BEQ.S	ACAdjM1
	ADD.B	#EDGEL,D4
ACAdjM1:
	MOVE.W	#$008E,(A3)+
	MOVE.W	D4,(A3)+

	MOVE.W	VERPAN+6,D4
	MOVE.B	(AdjustBuf+2.w,PC,D1.W*4),D4
	TST.B	PrefMask
	BEQ.S	ACAdjM2
	SUB.B	#EDGER,D4
ACAdjM2:
	MOVE.W	#$0090,(A3)+
	MOVE.W	D4,(A3)+
AcCoAdjRet:
	RTS

	CNOP	0,8
AdjustBuf:
	DC.W	$8800,$A100	;  0
	DC.W	$44FF,$A000	; -1
	DC.W	$44EE,$9F00	; -2
	DC.W	$44DD,$9E00	; -3
	DC.W	$44CC,$9D00	; -4
	DC.W	$44BB,$9C00	; -5
	DC.W	$44AA,$9B00	; -6
	DC.W	$4499,$9A00	; -7
	DC.W	$8888,$A900	;  8
	DC.W	$8877,$A800	;  7
	DC.W	$8866,$A700	;  6
	DC.W	$8855,$A600	;  5
	DC.W	$8844,$A500	;  4
	DC.W	$8833,$A400	;  3
	DC.W	$8822,$A300	;  2
	DC.W	$8811,$A200	;  1

AdjustBuf2:
	DC.W	$CC77,$78B8	;  0
	DC.W	$CC66,$77B7	; -1
	DC.W	$CC55,$76B6	; -2
	DC.W	$CC44,$75B5	; -3
	DC.W	$CC33,$74B4	; -4
	DC.W	$CC22,$73B3	; -5
	DC.W	$CC11,$72B2	; -6
	DC.W	$CC00,$71B1	; -7
	DC.W	$CCFF,$80C0	;  8
	DC.W	$CCEE,$7FBF	;  7
	DC.W	$CCDD,$7EBE	;  6
	DC.W	$CCCC,$7DBD	;  5
	DC.W	$CCBB,$7CBC	;  4
	DC.W	$CCAA,$7BBB	;  3
	DC.W	$CC99,$7ABA	;  2
	DC.W	$CC88,$79B9	;  1

; ----------------------------------<=



	CNOP	0,8
AcCoRutGBY:
	LEA	(TabRasDATA.L,D7.W*8),A0

	MOVEQ	#0,D1
	MOVE.B	Regs+ScrModo,D1
	JMP	([TabScrBGY.W,PC,D1.W*4])
ActCopRet:
	RTS


	CNOP	0,4
AcCoRutGBY5:
	MOVE.B	1(A0),D1	; VDP (2)
	AND.W	#$0060,D1
	LSL.W	#3,D1
	MOVE.B	4(A0),D1	; VDP ($17)
	ADD.B	D7,D1

	MULU	#32,D1
	ADD.L	#SCR0,D1

NexBpl5=(32*1024)

	MOVE.W	#$00E2,(A3)+
	MOVE.W	D1,(A3)+
	SWAP	D1
	MOVE.W	#$00E0,(A3)+
	MOVE.W	D1,(A3)+
	SWAP	D1
	ADD.L	#NexBpl5,D1
	MOVE.W	#$00E6,(A3)+
	MOVE.W	D1,(A3)+
	SWAP	D1
	MOVE.W	#$00E4,(A3)+
	MOVE.W	D1,(A3)+
	SWAP	D1
	ADD.L	#NexBpl5,D1
	MOVE.W	#$00EA,(A3)+
	MOVE.W	D1,(A3)+
	SWAP	D1
	MOVE.W	#$00E8,(A3)+
	MOVE.W	D1,(A3)+
	SWAP	D1
	ADD.L	#NexBpl5,D1
	MOVE.W	#$00EE,(A3)+
	MOVE.W	D1,(A3)+
	SWAP	D1
	MOVE.W	#$00EC,(A3)+
	MOVE.W	D1,(A3)+
	RTS


	CNOP	0,4
AcCoRutGBY6:
	MOVE.B	1(A0),D1	; VDP (2)
	AND.W	#$0060,D1
	LSL.W	#3,D1
	MOVE.B	4(A0),D1	; VDP ($17)
	ADD.B	D7,D1

	MULU	#64,D1
	ADD.L	#SCR0,D1

NexBpl6=(64*1024)

	MOVE.W	#$00E2,(A3)+
	MOVE.W	D1,(A3)+
	SWAP	D1
	MOVE.W	#$00E0,(A3)+
	MOVE.W	D1,(A3)+
	SWAP	D1
	ADD.L	#NexBpl6,D1
	MOVE.W	#$00E6,(A3)+
	MOVE.W	D1,(A3)+
	SWAP	D1
	MOVE.W	#$00E4,(A3)+
	MOVE.W	D1,(A3)+
	RTS


	CNOP	0,4
AcCoRutGBY7:
	MOVE.B	1(A0),D1	; VDP (2)
	AND.W	#$0020,D1
	LSL.W	#3,D1
	MOVE.B	4(A0),D1	; VDP ($17)
	ADD.B	D7,D1

	MULU	#64,D1
	ADD.L	#SCR0,D1

NexBpl7=(64*512)

	MOVE.W	#$00E2,(A3)+
	MOVE.W	D1,(A3)+
	SWAP	D1
	MOVE.W	#$00E0,(A3)+
	MOVE.W	D1,(A3)+
	SWAP	D1
	ADD.L	#NexBpl7,D1
	MOVE.W	#$00E6,(A3)+
	MOVE.W	D1,(A3)+
	SWAP	D1
	MOVE.W	#$00E4,(A3)+
	MOVE.W	D1,(A3)+
	SWAP	D1
	ADD.L	#NexBpl7,D1
	MOVE.W	#$00EA,(A3)+
	MOVE.W	D1,(A3)+
	SWAP	D1
	MOVE.W	#$00E8,(A3)+
	MOVE.W	D1,(A3)+
	SWAP	D1
	ADD.L	#NexBpl7,D1
	MOVE.W	#$00EE,(A3)+
	MOVE.W	D1,(A3)+
	SWAP	D1
	MOVE.W	#$00EC,(A3)+
	MOVE.W	D1,(A3)+
	RTS


	CNOP	0,4
AcCoRutGBY8:
	MOVE.B	1(A0),D1	; VDP (2)
	AND.W	#$0020,D1
	LSL.W	#3,D1
	MOVE.B	4(A0),D1	; VDP ($17)
	ADD.B	D7,D1

	MULU	#32,D1
	ADD.L	#SCR0,D1

NexBpl8=(32*512)

	MOVE.W	#$00E2,(A3)+
	MOVE.W	D1,(A3)+
	SWAP	D1
	MOVE.W	#$00E0,(A3)+
	MOVE.W	D1,(A3)+
	SWAP	D1
	ADD.L	#NexBpl8,D1
	MOVE.W	#$00E6,(A3)+
	MOVE.W	D1,(A3)+
	SWAP	D1
	MOVE.W	#$00E4,(A3)+
	MOVE.W	D1,(A3)+
	SWAP	D1
	ADD.L	#NexBpl8,D1
	MOVE.W	#$00EA,(A3)+
	MOVE.W	D1,(A3)+
	SWAP	D1
	MOVE.W	#$00E8,(A3)+
	MOVE.W	D1,(A3)+
	SWAP	D1
	ADD.L	#NexBpl8,D1
	MOVE.W	#$00EE,(A3)+
	MOVE.W	D1,(A3)+
	SWAP	D1
	MOVE.W	#$00EC,(A3)+
	MOVE.W	D1,(A3)+
	SWAP	D1
	ADD.L	#NexBpl8,D1
	MOVE.W	#$00F2,(A3)+
	MOVE.W	D1,(A3)+
	SWAP	D1
	MOVE.W	#$00F0,(A3)+
	MOVE.W	D1,(A3)+
	SWAP	D1
	ADD.L	#NexBpl8,D1
	MOVE.W	#$00F6,(A3)+
	MOVE.W	D1,(A3)+
	SWAP	D1
	MOVE.W	#$00F4,(A3)+
	MOVE.W	D1,(A3)+
	SWAP	D1
	ADD.L	#NexBpl8,D1
	MOVE.W	#$00FA,(A3)+
	MOVE.W	D1,(A3)+
	SWAP	D1
	MOVE.W	#$00F8,(A3)+
	MOVE.W	D1,(A3)+
	SWAP	D1
	ADD.L	#NexBpl8,D1
	MOVE.W	#$00FE,(A3)+
	MOVE.W	D1,(A3)+
	SWAP	D1
	MOVE.W	#$00FC,(A3)+
	MOVE.W	D1,(A3)+
	RTS


	CNOP	0,4
AcCoRutGBY4:
	TST.B	MSplitOn5		; Above a SCREEN 5 / 4 split: SCREENT.
	BEQ.S	AcCoGBY4t
	CMP.W	MSplitL,D7
	BCC.S	AcCoGBY4t
	MOVE.W	D7,D1
	MULU	#(32*4),D1
	ADD.L	#SCREENT,D1
	BRA.S	AcCoGBY4w
AcCoGBY4t:
	MOVE.W	TSplit,D1		; Below a table split: SCREENB,
	BEQ.S	AcCoGBY4n		; drawn in display order (HUDSplit4).
	CMP.W	D1,D7
	BCS.S	AcCoGBY4n
	NEG.W	D1
	ADD.W	D7,D1
	MULU	#(32*4),D1
	ADD.L	#SCREENB,D1
	BRA.S	AcCoGBY4w
AcCoGBY4n:
	MOVEQ	#0,D1
	MOVE.B	4(A0),D1	; VDP ($17)
	ADD.B	D7,D1

	MULU	#(32*4),D1
	ADD.L	#SCREEN,D1
AcCoGBY4w:

NexBpl4=(32)

	MOVE.W	#$00E2,(A3)+
	MOVE.W	D1,(A3)+
	SWAP	D1
	MOVE.W	#$00E0,(A3)+
	MOVE.W	D1,(A3)+
	SWAP	D1
	ADD.L	#NexBpl4,D1
	MOVE.W	#$00E6,(A3)+
	MOVE.W	D1,(A3)+
	SWAP	D1
	MOVE.W	#$00E4,(A3)+
	MOVE.W	D1,(A3)+
	SWAP	D1
	ADD.L	#NexBpl4,D1
	MOVE.W	#$00EA,(A3)+
	MOVE.W	D1,(A3)+
	SWAP	D1
	MOVE.W	#$00E8,(A3)+
	MOVE.W	D1,(A3)+
	SWAP	D1
	ADD.L	#NexBpl4,D1
	MOVE.W	#$00EE,(A3)+
	MOVE.W	D1,(A3)+
	SWAP	D1
	MOVE.W	#$00EC,(A3)+
	MOVE.W	D1,(A3)+
	RTS





	CNOP	0,8
TabScrBGY:
	DC.L	ActCopRet	; 1 1G	00 000
	DC.L	ActCopRet	; 2 2G	00 001
	DC.L	AcCoRutGBY4	; 4 3G	00 010
	DC.L	AcCoRutGBY5	; 5 4G	00 011
	DC.L	AcCoRutGBY6	; 6 5G	00 100
	DC.L	AcCoRutGBY7	; 7 6G	00 101
	DC.L	ActCopRet	;	00 110
	DC.L	AcCoRutGBY8	; 8 7G	00 111
	DC.L	ActCopRet	; 3 M	01 000  (Modo MULTI)
	REPT	7
	DC.L	ActCopRet
	ENDR
	DC.L	ActCopRet	; 0 1T	10 000  (Modo 40 columnas)
	DC.L	ActCopRet
	DC.L	ActCopRet	; 1 2T	10 010  (Modo 80 columnas)
	REPT	5+8
	DC.L	ActCopRet
	ENDR

; ------------------------------ ;
		CNOP	0,8
CopperOptsUno:	DC.L	CopperOpts1
CopperOptsDos:	DC.L	CopperOpts0

CopperLineUno:	DC.L	CopperLine1
CopperLineDos:	DC.L	CopperLine0

TabRasRESTUno:	DC.L	TabRasREST1-2
TabRasRESTDos:	DC.L	TabRasREST0-2

TabRasCMDS:	DS.B	260
BlankTab:	DS.B	260		; Per line: 1 display off, 2 on (R#1 BL).
		EVEN
TabRasDATA:	DS.L	260*2

		DC.L	-1	<=- No Quitar.
TabRasREST0:	DS.L	260	--------------
		DC.L	-1	<=- No Quitar.
TabRasREST1:	DS.L	260	--------------
		DC.L	0

; ------------------------------ ;




;   ---------------------------------------------------------------------
;  -=====================================================================-
; <***********************************************************************>
;  -=====================================================================-
;   ---------------------------------------------------------------------



;	 -----------------
;	- Datos y rutinas -
;	 -----------------

	CNOP	0,8
CEROS:	DS.L	20

	CNOP	0,8
CREATAB7E:
	LEA	TABLAND,A0
	LEA	TABLA7E,A1
	MOVEQ	#0,D4
	MOVE.W	#256-1,D5
CET7EB0:
	MOVEQ	#0,D6
	MOVEQ	#$10-1,D2
CET7EB1:
	MOVEQ	#0,D7
	MOVEQ	#$10-1,D3
CET7EB2:
	MOVE.L	D4,D0
	MOVE.L	D4,D1
	NOT.L	D1
	AND.L	(A0,D6.W*4),D0
	AND.L	(A0,D7.W*4),D1
	OR.L	D1,D0

;;	MOVE.L	D0,(A1)+

	MOVE.B	D0,(A1)
	LSR.W	#8,D0
	MOVE.B	D0,1(A1)
	SWAP	D0
	MOVE.B	D0,2(A1)
	LSR.W	#8,D0
	MOVE.B	D0,3(A1)
	ADDQ.W	#4,A1

	ADDQ.W	#1,D7
	DBF	D3,CET7EB2
	ADDQ.W	#1,D6
	DBF	D2,CET7EB1
	ADD.L	#$01010101,D4
	DBF	D5,CET7EB0
	RTS

TABLAND:
	DC.L	$00000000,$000000FF,$0000FF00,$0000FFFF
	DC.L	$00FF0000,$00FF00FF,$00FFFF00,$00FFFFFF
	DC.L	$FF000000,$FF0000FF,$FF00FF00,$FF00FFFF
	DC.L	$FFFF0000,$FFFF00FF,$FFFFFF00,$FFFFFFFF

;	-----

	CNOP	0,8
CalCheck:
	LEA	ROM10,A0
	MOVEQ	#0,D0
	MOVE.W	#(CheckSumBuc/16)-1,D1
BUCCALCHEC:
	ADD.L	(A0)+,D0
	ADD.L	(A0)+,D0
	ADD.L	(A0)+,D0
	ADD.L	(A0)+,D0
	DBF	D1,BUCCALCHEC
	RTS

;	-----

	CNOP	0,8
PRINT:
	LEA	TEXTO0+((40*1)+10)+$284,A0
	MOVE.L	#$12175357,D7
	MOVE.L	#("JUAN"+$12175357)*-1,D0
	MOVE.L	#(" ANT"+$12175357)*-1,D1
	NEG.L	D0
	SUB.L	D7,D0
	MOVE.L	#("ONIO"+$12175357)*-1,D2
	MOVE.L	#(" GOM"+$12175357)*-1,D3
	NEG.L	D1
	SUB.L	D7,D1
	MOVE.L	#("EZ G"+$12175357)*-1,D4
	NEG.L	D2
	SUB.L	D7,D2
	MOVE.L	#("ALVE"+$12175357)*-1,D5
	NEG.L	D3
	SUB.L	D7,D3
	MOVE.L	#("Z * "+$12175357)*-1,D6
	NEG.L	D4
	SUB.L	D7,D4
	NEG.L	D5
	SUB.L	D7,D5
	NEG.L	D6
	SUB.L	D7,D6
	MOVEM.L	D0-D6,-$284(A0)
	SUB.W	#$284+((40*1)+10),A0
	MOVE.L	A0,A4
	LEA	PANT+(40*2),A1
	MOVEQ	#(2)-1,D5
BUCPRI3:
	MOVEQ	#(40)-1,D4
BUCPRI2:
	MOVE.B	(A4)+,D6
	BEQ.S	PRIRET
	MOVE.L	A1,-(SP)
	BSR	PRINTCA
	MOVE.L	(SP)+,A1
	ADD.W	#1,A1
	DBF	D4,BUCPRI2
	ADD.W	#(40*11),A1
	DBF	D5,BUCPRI3
	RTS
;	D6=ASCII.	A1=Destino.  (Letra 8*8)
PRINTCA:
	LEA	FONT,A0
	SUB.B	#$20,D6
	BCS	PRIRET
	AND.L	#$00FF,D6
	DIVU	#40,D6		; Letras por linea
	MOVE.W	D6,D7
	SWAP	D6
	MULU	#40*8,D7	; Size 1 linea de letras.
	ADD.W	D7,A0
	ADD.W	D6,A0
	MOVE.L	A0,A2
	ADD.W	#(40*16),A2
	SUB.W	#1,D2
PRINTCAC:
	MOVE.L	A1,A3
	ADD.W	#(40*24),A3
	MOVE.W	#8-1,D7	; Size Y de 1 letra.
	MOVE.W	#40,D6
PRINTCAB:
	MOVE.B	(A0),(A1)
	MOVE.B	(A2),(A3)
	ADD.W	D6,A0		; 1 linea Tabla Font
	ADD.W	D6,A1		; 1 linea Pant.
	ADD.W	D6,A2		; 1 linea Tabla Font
	ADD.W	D6,A3		; 1 linea Pant.
	DBF	D7,PRINTCAB
PRIRET:	RTS
		CNOP	0,8
;;			|----------------------------------------|
TEXTO0:		DC.B	"      *  AMIMSX2 EMULATOR  V2.5  *      "
		DC.B	"  *  BY:  JUAN ANTONIO GOMEZ GALVEZ  *  "
;;			|----------------------------------------|
	EVEN
********************************************************

	CNOP	0,8
; ------------------------------->   Congela/Descongela Input.device
CONGELA:
	MOVE.L	4.W,A6
	JSR	-$29A(A6)		; CreateMsgPort
	MOVE.L	D0,MSGPORT
	BEQ	CERROR
	MOVE.L	D0,A0
	MOVE.L	#$30,D0
	JSR	-$28E(A6)		; CreateIORequest
	MOVE.L	D0,IOREQ
	BEQ	CERROR
	LEA	TIMERNOM,A0
	MOVE.L	D0,A1
	MOVEQ	#0,D0
	MOVEQ	#0,D1
	JSR	-$1BC(A6)		; OpenDevice
	TST.L	D0
	BNE	CERROR
	MOVE.L	IOREQ,A1
	MOVE.W	#9,$1C(A1)
	LEA	BUFCEROS,A2
	MOVE.L	A2,$28(A1)
	MOVE.L	#INTEXTO,$A(A2)
	MOVE.B	#$7F,$9(A2)
	MOVE.L	#INPRG,$12(A2)
	JSR	-$1C8(A6)		; DoIO
	MOVEQ	#0,D0
	RTS
; -----------------------------------------

; -----------------------------------------
	IFEQ	Key_ON
Cambio:
	MOVEQ	#0,D0
	ADDQ.W	#2,A0
	MOVEQ	#0,D1
CambioBuc:
	MOVE.B	(A0)+,D0
	BEQ.S	CambioRet
	MOVE.L	(A2,D0.W*8),D2
	MOVE.B	(A0)+,D1
	MOVE.L	(A2,D1.W*8),D3
	MOVE.L	D3,(A2,D0.W*8)
	MOVE.L	D2,(A2,D1.W*8)
	BRA.S	CambioBuc
CambioRet:
	RTS
	ENDC
; -----------------------------------------

; -----------------------------------------
	CNOP	0,8
DESCONGELA:
	IFEQ	Key_ON
	LEA	Instr+4,A2
	MOVE.L	([A0,$738.W],$30.W),A0
	BSR	Cambio
	ENDC

	TST.L	IOREQ
	BEQ.S	INRETS

	ST	INDATO
	NOP
	NOP
INBUCT2:
	TST.B	INDATO
	BEQ.S	INBUCT2

	MOVE.L	4.W,A6
	MOVE.L	IOREQ,A1
	MOVE.W	#$A,$1C(A1)
	JSR	-$1C8(A6)
	MOVE.L	IOREQ,A0
	JSR	-$294(A6)
	MOVE.L	MSGPORT,A0
	JSR	-$2A0(A6)
	MOVEQ	#0,D0
INRETS:	RTS

	CNOP	0,8
INPRG:
	ST	INDATO
INBUCT:
	CMPI.B	#1,4(A0)
	BNE.S	INCONT
	SF	INDATO
INCONT:
	MOVE.L	(A0),D0
	MOVE.L	D0,A0
	BNE.S	INBUCT
	MOVEQ	#0,D0
	RTS

	CNOP	0,8
CERROR:	MOVEQ	#-1,D0
	RTS

	CNOP	0,8
MSGPORT:	DC.L	0
IOREQ:		DC.L	0
TIMERNOM:	DC.B	"input.device",0,0
INTEXTO:	DC.B	"MSX Emulator matando input.device!!!",0,0
INDATO:		DC.B	0,0
	CNOP	0,8
BUFCEROS:	DS.L	$20
		DC.L	0
	CNOP	0,8
; --------------------------------<


; -------------------------------------------------------------------
; *******************************************************************
; -------------------------------------------------------------------


	CNOP	0,8
DP0=$8000	; 00(A0): Direccion Copper.   08(A0): Bytes de 1 Plano.
DP1=$C000	; 04(A0): Direccion Pant.     0C(A0): Bit-Planos. (DP0,1)
CREAPLANOS:
	MOVE.W	#$E0,D3
CRPBUC00:
	TST.L	(A0)
	BEQ	CRPRET
	MOVE.L	(A0)+,A1
	MOVEM.L	(A0)+,D0-D2
	TST.W	D2
	SUB.W	#1,D2
	BPL.S	CRPCON00
	BTST	#$E,D2
	BEQ.S	CRPCON01
	ADD.W	#4,D3
CRPCON01:
	AND.W	#$3FFF,D2
	BSR	HACEPLANOS2
	BRA.S	CREAPLANOS
CRPCON00:
	BSR	HACEPLANOS
	BRA.S	CREAPLANOS
HACEPLANOS:			; A1=COPPER.   D0=Direccion. D1=PLANOSIZE.
	SWAP	D0		; D2=Planos-1. D3=DIRBPLH/L
	MOVE.W	D3,(A1)+
	MOVE.W	D0,(A1)+
	ADD.W	#2,D3
	SWAP	D0
	MOVE.W	D3,(A1)+
	MOVE.W	D0,(A1)+
	ADD.W	#2,D3
	ADD.L	D1,D0
	DBF	D2,HACEPLANOS
CRPRET:	RTS
HACEPLANOS2:			; Igual que antes pero Dual Playfield.
	SWAP	D0
	MOVE.W	D3,(A1)+
	MOVE.W	D0,(A1)+
	ADD.W	#2,D3
	SWAP	D0
	MOVE.W	D3,(A1)+
	MOVE.W	D0,(A1)+
	ADD.W	#2,D3
	ADD.L	D1,D0
	ADD.W	#4,D3
	DBF	D2,HACEPLANOS2
	RTS
CREASALTO:			; A0=COPPER-List.   D0=Direccion
	MOVE.W	D0,$6(A0)
	SWAP	D0
	MOVE.W	D0,$2(A0)
	RTS
;	00(A0): Direccion de Copper.	08(A0): Numero Colores. (DP0,1)
;	04(A0): Direccion de Colores.	(Todos en x.L)
CREACOLORES:
	MOVE.W	#$180,D1
CRCBUC00:
	TST.L	(A0)
	BEQ	CRPRET
	MOVEM.L	(A0)+,A1-A2
	MOVE.L	(A0)+,D0
	SUB.W	#1,D0
	TST.W	D0
	BPL.S	CRCBUC01
	MOVE.W	#$190,D1
	BTST	#$E,D0
	BEQ.S	CRCBUC01A
	MOVE.W	#$1A0,D1
CRCBUC01A:
	AND.W	#$3FFF,D0
CRCBUC01:
	MOVE.W	D1,(A1)+
	MOVE.W	(A2)+,(A1)+
	ADD.W	#$02,D1
	DBF	D0,CRCBUC01
	BRA.S	CREACOLORES	
;	00(A0): Direccion del Copper.	08(A0): Numero Sprit (0-7)
;	04(A0): Direccion GFX Sprit.	(Todos en x.L)
CREASPRITES:
	TST.L	(A0)
	BEQ	CRPRET
	MOVE.W	#$120,D2
	MOVE.L	(A0)+,A1
	MOVEM.L	(A0)+,D0-D1
	LSL.W	#2,D1
	ADD.L	D1,D2	
	MOVE.W	D2,(A1)+
	SWAP	D0
	MOVE.W	D0,(A1)+
	ADD.L	#2,D2
	MOVE.W	D2,(A1)+
	SWAP	D0
	MOVE.W	D0,(A1)+
	BRA.S	CREASPRITES
;	00(A0): Direccion del Copper.	08(A0): Dir. Salto.
CREASALTOS:
	TST.L	(A0)
	BEQ	CRPRET
	MOVE.L	(A0)+,A1
	MOVE.L	(A0)+,D0
	MOVE.W	D0,$6(A1)
	SWAP	D0
	MOVE.W	D0,$2(A1)
	BRA.S	CREASALTOS	
RETARDO:			; D0=Retardo.
	MOVE.W	D0,-(SP)
	MOVE.B	$DFF006,D0
RETARDOB:
	CMP.B	$DFF006,D0
	BEQ.S	RETARDOB
	MOVE.W	(SP)+,D0
	DBF	D0,RETARDO
	RTS
; -----**************()**************-----
	CNOP	0,8
DIRPLANOS:
	DC.L	PLANO,PANT,(40*24),2
	DC.L	PLANO0,SCREEN,192,1
	DC.L	PLANO9,SCREEN,(80*27*8),2
	DC.L	PLANO4,SCREEN,(32),4
	DC.L	PLANO4b,SCREEN,(32),4
	DC.L	PLANO2,SCREEN,(32),4
	DC.L	PLANO2B,SCREEN,(32),4
	DC.L	PLANO5,SCR0,(64*512),4
;;;	DC.L	PLANO5B,SCR0,(64*512),4
	DC.L	PLANO7,SCR0,(64*512),4
	DC.L	PLANO6,SCR0,(64*1024),2
	DC.L	PLANO8,SCR0,(32*512),8
	DC.L	PLANO8E,SCR0,(32*512),5
	DC.L	0
DIRCOLORES:
	DC.L	COLORMSX2,MSX1PAL,16
	DC.L	COLORSPR2,MSX1PAL,16+DP1
	DC.L	0
DIRSPRITES2:
	DC.L	DIRSPRIT0,SPRIT0,0
	DC.L	DIRSPRIT1,SPRIT1,1
	DC.L	DIRSPRIT2,SPRIT2,2
	DC.L	DIRSPRIT3,SPRIT3,3
	DC.L	DIRSPRIT4,SPRIT4,4
	DC.L	DIRSPRIT5,SPRIT5,5
	DC.L	DIRSPRIT6,SPRIT6,6
	DC.L	DIRSPRIT7,SPRIT7,7
	DC.L	0
DIRSPRITES2b:
	DC.L	DIRSPRIT0,SPRIT0b,0
	DC.L	DIRSPRIT1,SPRIT1b,1
	DC.L	DIRSPRIT2,SPRIT2b,2
	DC.L	DIRSPRIT3,SPRIT3b,3
	DC.L	DIRSPRIT4,SPRIT4b,4
	DC.L	DIRSPRIT5,SPRIT5b,5
	DC.L	DIRSPRIT6,SPRIT6b,6
	DC.L	DIRSPRIT7,SPRIT7b,7
	DC.L	0
DIRSPRITES:
	DC.L	DIRSPRIT0,NOSPRIT,0
	DC.L	DIRSPRIT1,NOSPRIT,1
	DC.L	DIRSPRIT2,NOSPRIT,2
	DC.L	DIRSPRIT3,NOSPRIT,3
	DC.L	DIRSPRIT4,NOSPRIT,4
	DC.L	DIRSPRIT5,NOSPRIT,5
	DC.L	DIRSPRIT6,NOSPRIT,6
	DC.L	DIRSPRIT7,NOSPRIT,7
	DC.L	0
DIRSALTOS:
	DC.L	SALTO4,SALTO5
	DC.L	SALTO5,MASTERCOPPER
	DC.L	SALTO6,SALTO5
	DC.L	SALTO7,SALTO5
	DC.L	SALTO8,SALTO5
	DC.L	SALTO8E,SALTO5

	DC.L	ZALTO4,CopperLine0
	DC.L	ZALTO5,CopperLine0
	DC.L	ZALTO6,CopperLine0
	DC.L	ZALTO7,CopperLine0
	DC.L	ZALTO8,CopperLine0

	DC.L	ScrModeCopp,CopperRet
	DC.L	0



	CNOP	0,8
PaletaG7:
	DC.W	$0000,$0004,$0009,$000E,$0200,$0204,$0209,$020E
	DC.W	$0400,$0404,$0409,$040E,$0600,$0604,$0609,$060E
	DC.W	$0800,$0804,$0809,$080E,$0A00,$0A04,$0A09,$0A0E
	DC.W	$0C00,$0C04,$0C09,$0C0E,$0E00,$0E04,$0E09,$0E0E
	DC.W	$0020,$0024,$0029,$002E,$0220,$0224,$0229,$022E
	DC.W	$0420,$0424,$0429,$042E,$0620,$0624,$0629,$062E
	DC.W	$0820,$0824,$0829,$082E,$0A20,$0A24,$0A29,$0A2E
	DC.W	$0C20,$0C24,$0C29,$0C2E,$0E20,$0E24,$0E29,$0E2E
	DC.W	$0040,$0044,$0049,$004E,$0240,$0244,$0249,$024E
	DC.W	$0440,$0444,$0449,$044E,$0640,$0644,$0649,$064E
	DC.W	$0840,$0844,$0849,$084E,$0A40,$0A44,$0A49,$0A4E
	DC.W	$0C40,$0C44,$0C49,$0C4E,$0E40,$0E44,$0E49,$0E4E
	DC.W	$0060,$0064,$0069,$006E,$0260,$0264,$0269,$026E
	DC.W	$0460,$0464,$0469,$046E,$0660,$0664,$0669,$066E
	DC.W	$0860,$0864,$0869,$086E,$0A60,$0A64,$0A69,$0A6E
	DC.W	$0C60,$0C64,$0C69,$0C6E,$0E60,$0E64,$0E69,$0E6E
	DC.W	$0080,$0084,$0089,$008E,$0280,$0284,$0289,$028E
	DC.W	$0480,$0484,$0489,$048E,$0680,$0684,$0689,$068E
	DC.W	$0880,$0884,$0889,$088E,$0A80,$0A84,$0A89,$0A8E
	DC.W	$0C80,$0C84,$0C89,$0C8E,$0E80,$0E84,$0E89,$0E8E
	DC.W	$00A0,$00A4,$00A9,$00AE,$02A0,$02A4,$02A9,$02AE
	DC.W	$04A0,$04A4,$04A9,$04AE,$06A0,$06A4,$06A9,$06AE
	DC.W	$08A0,$08A4,$08A9,$08AE,$0AA0,$0AA4,$0AA9,$0AAE
	DC.W	$0CA0,$0CA4,$0CA9,$0CAE,$0EA0,$0EA4,$0EA9,$0EAE
	DC.W	$00C0,$00C4,$00C9,$00CE,$02C0,$02C4,$02C9,$02CE
	DC.W	$04C0,$04C4,$04C9,$04CE,$06C0,$06C4,$06C9,$06CE
	DC.W	$08C0,$08C4,$08C9,$08CE,$0AC0,$0AC4,$0AC9,$0ACE
	DC.W	$0CC0,$0CC4,$0CC9,$0CCE,$0EC0,$0EC4,$0EC9,$0ECE
	DC.W	$00E0,$00E4,$00E9,$00EE,$02E0,$02E4,$02E9,$02EE
	DC.W	$04E0,$04E4,$04E9,$04EE,$06E0,$06E4,$06E9,$06EE
	DC.W	$08E0,$08E4,$08E9,$08EE,$0AE0,$0AE4,$0AE9,$0AEE
	DC.W	$0CE0,$0CE4,$0CE9,$0CEE,$0EE0,$0EE4,$0EE9,$0EEE



	CNOP	0,8
	IFEQ	TOTAL
MULTIKEY:	DC.B	0
SCRFRECD:	DC.B	0
LEEJOY2D:	DC.B	0
MVDPROT:	DC.B	0
FILTRO:		DC.B	0
DIRVD0:		DC.L	0
DMACON:		DC.W	0
INTENA:		DC.W	0
INTENA2:	DC.W	0
IntenaTr:	DC.W	0
INTREQ:		DC.W	0
vBlank:		DC.L	0
WBCOPP:		DC.L	0
	ENDC
ActDosROM:	DC.L	0
DERSTACK:	DC.B	0
SwapJoyD:	DC.B	0
		DC.W	0
VBRPun:		DC.L	0
NEXTCOPP:	DC.L	COPPERN
CHECKSUM:	DC.L	0
VELOCID:	DC.W	0
DIRCONTI:	DC.W	0
		DC.L	BUCLE
PILA:		DC.L	0
AMITECLAS:	DS.B	20
DEBUG:		DS.L	16
SFXCHIP:	DC.B	0
PAGIND:		DC.B	0
OverDat:	DC.B	0,0

		DS.L	10	; Seguridad.

; ---------------------------------------=> Sprite snapshots and split.
; Kept after the original code so that its layout stays as it was.

; Sprite snapshots at display lines SNAPTOP and SNAPLIN (JumpCurLine), in
; sprite mode 1 only (see SNAPSPR): the attribute table as the beam saw it.
; IMPSPR draws from SprSnap instead of VRAM at the end of the frame (Chikubi
; Ninja ends the list with Y=216 under its HUD and in VBlank); SprSnapT is
; the table above a mid-frame R#5/R#6 split (Uridium's HUD: SprSplit,
; IMPSPR, SprSlotsT).
; Scanline handlers may only change D1: the rest is the Z80 core's.
	CNOP	0,4
MiraInterSnapT:
	IFD	TRACE
	TRVLOG	$F8,DVDP5+1(A3)
	ENDC
	SNAPSPR	SprSnapT,SnapTOK,SnapT6
	JMP	MiraInterBuc
	CNOP	0,4
MiraInterSnap:
	IFD	TRACE
	TRVLOG	$F9,DVDP5+1(A3)
	ENDC
	MIDSAMPLE
	BANDSHOT
	SNAPSPR	SprSnap,SnapOK,SnapM6
	JMP	MiraInterBuc
	CNOP	0,4
MiraInterBand:
	MIDSAMPLE
	BANDSHOT
	JMP	MiraInterBuc
	CNOP	0,4
MiraInterBSplit:			; (Before CurLine moves on: the band
	ADDQ.B	#1,CurLine+1(A3)	; starts at the next line.)
	BANDSHOT
	SUBQ.B	#1,CurLine+1(A3)
	JMP	MiraInterBRet


; Line 0: new frame for the sprite snapshots, then MiraInter0.
	CNOP	0,4
MiraInter0S:
	CLR.W	TSplit			; Table split: new frame.
	CLR.W	SegStart		; Register split segments too.
	CLR.W	SegBest
	SF	SegSeen
	CLR.W	MSplitL			; Mode split too (regime: MSplitSeen).
	MOVE.B	#$A1,Ver2+3		; SCREEN 1-3 window: masked edges or not.
	MOVE.B	#$A1,Ver2+7
	TST.B	PrefMask
	BEQ.S	FrMaskNo
	MOVE.B	#$A1+EDGEL,Ver2+3
	MOVE.B	#$A1-EDGER,Ver2+7
FrMaskNo:
	MOVE.W	Ver2+2,Ver2B+2
	MOVE.W	Ver2+6,Ver2B+6
	MOVE.L	MSX2Pal+0,PalTop+0	; Palette at the frame's top (AcCoRutPal).
	MOVE.L	MSX2Pal+4,PalTop+4
	MOVE.L	MSX2Pal+8,PalTop+8
	MOVE.L	MSX2Pal+12,PalTop+12
	MOVE.L	MSX2Pal+16,PalTop+16
	MOVE.L	MSX2Pal+20,PalTop+20
	MOVE.L	MSX2Pal+24,PalTop+24
	MOVE.L	MSX2Pal+28,PalTop+28
	CLR.W	PalEvN
	TST.B	PalSplitSeen
	BEQ.S	PalS0None
	SUBQ.B	#1,PalSplitSeen
	OR.B	#$04,TabRasCMDS		; Line 0: the top palette.
PalS0None:
	TST.B	MSplitSeen
	BEQ.S	MS0None
	SUBQ.B	#1,MSplitSeen
MS0None:
	MIDSAMPLE			; (Lilly's Saga: sprites off and adjust 0
					; for its HUD at line ~173.)
	CLR.W	BandN			; Sprite bands: on with line interrupts
	MOVE.B	DVDP0(A3),D1		; in sprite mode 2 (SCREEN 4-8).
	AND.B	#$1C,D1
	CMP.B	#$10,D1
	SHI	BandOn
	BANDSHOT
	IFD	PERFSTOP
	ADDQ.L	#1,PerfStopN
	CMP.L	#PERFSTOP,PerfStopN
	BNE.S	PerfGo
	JMP	ZALI
PerfStopN:	DC.L	0
PerfGo:
	ENDC
	IFD	TRACE
	TRVLOG	$FF,SnapTOK
	ADDQ.W	#1,TrvFrame
	IFD	TRVSTOP
	CMP.W	#TRVSTOP,TrvFrame	; Optional trigger: N frames.
	BNE.S	TrvGo
	JMP	TraceFreeze
TrvGo:
	ENDC
	IFD	TRVLMMC
	TST.B	TrvLmmcDone		; Optional trigger: the frame after an
	BEQ.S	TrvGo2			; LMMC TRVLMMC dots wide finished.
	JMP	TraceFreeze
TrvGo2:
	ENDC
	ENDC
	SF	SnapOK			; Sprite snapshots: new frame.
	SF	SnapTOK
	CLR.W	SprSplit
	JMP	MiraInter0

; SCREEN 2/4 character cache: two banks (GFXCA/TAB98, GFXCA2/TAB98B), each
; for one table set (colour base, pattern base, R#3, R#4), decided here at
; render time. The set last drawn: nothing to do. The other bank's set: use
; that bank, no conversion; SCREEN 2 has a screen per bank and only copies
; changed names, SCREEN 4 copies the whole screen (BankSw). A new set: it
; takes the other bank, full conversion (ACTODOB). A full redraw asked for
; elsewhere (screen mode change) keeps the bank and forgets the other one.
; Uridium flips two fixed sets every frame; Lilly's Saga switches tables for
; its HUD (PRINT4S draws the playfield's). Sets A3 = REGS. Uses D0/D1/A0.
	CNOP	0,4
RendTabCheck:
	LEA	REGS,A3
	SF	BankSw
	MOVE.W	BankAct(PC),D0		; D0 = bank in use * 12.
	LEA	BankKeys(PC),A0
	TST.B	ACTODOB(A3)
	BEQ	RTCChk
	MOVEQ	#12,D1			; Full redraw anyway: the other bank
	SUB.W	D0,D1			; is forgotten, this one gets the set.
	MOVE.L	#-1,(A0,D1.W)
	BRA	RTCSet
RTCChk:	BSR	RTCSame
	BEQ	RTCFin			; Same set as last drawn.
	MOVEQ	#12,D0
	SUB.W	BankAct(PC),D0		; The other bank...
	BSR	RTCSame
	BEQ	RTCOther
	ST	ACTODOB(A3)		; ...gets the new set: full conversion.
	BRA	RTCSet
RTCOther:
	ST	BankSw			; ...has it: copy the screen.
RTCSet:	MOVE.L	PVDP3B(A3),(A0,D0.W)
	MOVE.L	PVDP4B(A3),4(A0,D0.W)
	MOVE.B	DVDP3+1(A3),8(A0,D0.W)
	MOVE.B	DVDP4+1(A3),9(A0,D0.W)
	MOVE.W	D0,BankAct
	MOVE.L	#GFXCA,GfxCaPtr
	MOVE.L	#TAB98,TabFlagPtr
	MOVE.L	#SCREEN,ScreenPtr
	MOVE.L	#TXT2,Txt2Ptr
	TST.W	D0
	BEQ	RTCFin
	MOVE.L	#GFXCA2,GfxCaPtr
	MOVE.L	#TAB98B,TabFlagPtr
	CMP.B	#1,ScrModo(A3)		; SCREEN 2: the bank has its own screen
	BNE	RTCFin			; and name shadow (Planos2).
	MOVE.L	#SCREEN2B,ScreenPtr
	MOVE.L	#TXT2B,Txt2Ptr
RTCFin:	RTS
RTCSame:				; Z: bank D0 holds the current set.
	MOVE.L	PVDP3B(A3),D1
	CMP.L	(A0,D0.W),D1
	BNE.S	RTCSNo
	MOVE.L	PVDP4B(A3),D1
	CMP.L	4(A0,D0.W),D1
	BNE.S	RTCSNo
	MOVE.B	DVDP3+1(A3),D1
	CMP.B	8(A0,D0.W),D1
	BNE.S	RTCSNo
	MOVE.B	DVDP4+1(A3),D1
	CMP.B	9(A0,D0.W),D1
RTCSNo:	RTS
		CNOP	0,4
BankKeys:	DC.L	-1,-1,0		; Per bank: colour, pattern base, R#3/R#4.
		DC.L	-1,-1,0
BankAct:	DC.W	0		; Bank in use * 12.
TXT2B:		DS.B	80*30		; Name shadow of bank 2 (SCREEN 2).
		EVEN
BankSw:		DC.B	0		; Switched to the other bank this frame.
		EVEN
GfxCaPtr:	DC.L	GFXCA		; Cache bank in use,
TabFlagPtr:	DC.L	TAB98		; its dirty flags,
ScreenPtr:	DC.L	SCREEN		; screen
Txt2Ptr:	DC.L	TXT2		; and name shadow (SCREEN 2 only).

; SCREEN 2: bitplanes of both copper lists on the bank's screen.
	CNOP	0,4
Planos2:
	MOVE.L	ScreenPtr,D0
	LEA	PLANO2+2,A0
	BSR.S	Planos2Set
	LEA	PLANO2B+2,A0
Planos2Set:
	MOVEQ	#4-1,D1
	MOVE.L	D0,-(SP)
Planos2Buc:
	MOVE.W	D0,4(A0)
	SWAP	D0
	MOVE.W	D0,(A0)
	SWAP	D0
	ADD.L	#32,D0
	ADDQ.W	#8,A0
	DBF	D1,Planos2Buc
	MOVE.L	(SP)+,D0
	RTS

; SCREEN 4 with a table split (TSplit, see TSPLITCHK). Lilly's Saga: at line
; ~174 its HUD switches to R#2=$26, R#4=$13, R#10=$02 and R#23=$4F, and back
; in VBlank. Here (line 192) the registers hold the HUD set: the playfield is
; drawn by PRINT4 with the set saved at the split (the cache, dirty flags and
; RendTabCheck stay on it), then HUDSplit4 draws the lines below the split.
	CNOP	0,4
PRINT4S:
	BSR	MSplitFill		; SCREEN 5 above a mode split.
	TST.W	TSplit
	BNE.S	PRINT4Sp
	JMP	PRINT4
PRINT4Sp:
	LEA	REGS,A3
	MOVE.B	DVDP2(A3),TB_DVDP2	; Keep the HUD set...
	MOVE.B	VDPLinY(A3),TB_LinY
	MOVE.W	DVDP3(A3),TB_DVDP3
	MOVE.W	DVDP4(A3),TB_DVDP4
	MOVE.L	PVDP2(A3),TB_PVDP2
	MOVE.L	PVDP3(A3),TB_PVDP3
	MOVE.L	PVDP3B(A3),TB_PVDP3B
	MOVE.L	PVDP4(A3),TB_PVDP4
	MOVE.L	PVDP4B(A3),TB_PVDP4B
	MOVE.B	TA_DVDP2,DVDP2(A3)	; ...draw with the playfield set...
	MOVE.B	TA_LinY,VDPLinY(A3)
	MOVE.W	TA_DVDP3,DVDP3(A3)
	MOVE.W	TA_DVDP4,DVDP4(A3)
	MOVE.L	TA_PVDP2,PVDP2(A3)
	MOVE.L	TA_PVDP3,PVDP3(A3)
	MOVE.L	TA_PVDP3B,PVDP3B(A3)
	MOVE.L	TA_PVDP4,PVDP4(A3)
	MOVE.L	TA_PVDP4B,PVDP4B(A3)
	JSR	PRINT4
	LEA	REGS,A3
	MOVE.B	TB_DVDP2,DVDP2(A3)	; ...and back to the HUD set.
	MOVE.B	TB_LinY,VDPLinY(A3)
	MOVE.W	TB_DVDP3,DVDP3(A3)
	MOVE.W	TB_DVDP4,DVDP4(A3)
	MOVE.L	TB_PVDP2,PVDP2(A3)
	MOVE.L	TB_PVDP3,PVDP3(A3)
	MOVE.L	TB_PVDP3B,PVDP3B(A3)
	MOVE.L	TB_PVDP4,PVDP4(A3)
	MOVE.L	TB_PVDP4B,PVDP4B(A3)
	BSR	HUDSplit4
	LEA	REGS,A3
	RTS

; SCREEN 5 above a mode split (MODESW): display lines 0..MSplitL-1 from the
; SCR0 planes (VRAM line page*256 + (y + R#23) & 255, 32 bytes a plane) into
; SCREENT in SCREEN 4's layout (4 interleaved planes of 32 bytes a line).
	CNOP	0,4
MSplitFill:
	SF	MSplitOn5
	TST.W	MSplitL
	BEQ	MSFRet
	CMP.B	#3,MSplitTop
	BNE	MSFRet
	TST.B	DirPrefs+$6B		; (Planes kept: Refresh 100% Graphics.)
	BEQ	MSFRet
	ST	MSplitOn5
	MOVEM.L	D0-D7/A0-A2,-(SP)
	MOVE.W	MSplitL,D0		; Key: split line, R#2, R#23.
	SWAP	D0
	MOVE.B	MS_DVDP2,D0
	LSL.W	#8,D0
	MOVE.B	MS_LinY,D0
	TST.B	SCRTDirty		; SCREENT still valid: no copy (chip
	BNE.S	MSFCopy			; to chip is slow).
	CMP.L	MSFKey,D0
	BEQ	MSFDone
MSFCopy:
	SF	SCRTDirty
	MOVE.L	D0,MSFKey
	MOVEQ	#0,D0			; This page's VRAM range and blocks.
	MOVE.B	MS_DVDP2,D0
	AND.W	#$60,D0
	LSR.W	#5,D0
	MOVE.W	D0,D1
	LSL.W	#5,D1			; 32 blocks of 1 KB a page.
	MOVE.W	D1,SCRTBLo
	ADD.W	#32,D1
	MOVE.W	D1,SCRTBHi
	MOVEQ	#15,D1
	LSL.L	D1,D0			; 32 KB a page.
	MOVE.L	D0,SCRTLo
	ADD.L	#$8000,D0
	MOVE.L	D0,SCRTHi
	MOVEQ	#0,D0
	MOVE.B	MS_DVDP2,D0
	AND.W	#$60,D0
	LSL.W	#3,D0			; Page * 256 lines.
	MOVEQ	#0,D6
	MOVE.B	MS_LinY,D6
	LEA	SCREENT,A1
	MOVE.W	MSplitL,D7
	SUBQ.W	#1,D7
	MOVEQ	#0,D5
MSFLin:
	MOVE.W	D5,D1
	ADD.W	D6,D1
	AND.W	#$FF,D1
	ADD.W	D0,D1
	MULU	#32,D1
	LEA	(SCR0.L,D1.L),A0
	MOVEQ	#4-1,D4
MSFPla:
	MOVE.L	A0,A2
	MOVE.L	(A2)+,(A1)+
	MOVE.L	(A2)+,(A1)+
	MOVE.L	(A2)+,(A1)+
	MOVE.L	(A2)+,(A1)+
	MOVE.L	(A2)+,(A1)+
	MOVE.L	(A2)+,(A1)+
	MOVE.L	(A2)+,(A1)+
	MOVE.L	(A2)+,(A1)+
	ADD.L	#SIZEX*SIZEY,A0		; Next plane.
	DBF	D4,MSFPla
	ADDQ.W	#1,D5
	DBF	D7,MSFLin
MSFDone:
	MOVEM.L	(SP)+,D0-D7/A0-A2
MSFRet:	RTS

MsNewW:		DC.W	0
MSplitL:	DC.W	0		; First line in the new mode, 0: none.
MsOld:		DC.B	0
MSplitTop:	DC.B	0		; Mode above the split.
MS_DVDP2:	DC.B	0		; R#2 / R#23 there.
MS_LinY:	DC.B	0
MSplitSeen:	DC.B	0		; Frames left in the split regime.
; LMMC state: D1/D4/D5/D6/A5, 20 bytes. It used to be CPUCopyBufer(A3), a
; 4-byte slot at REGS+$6F0, so every LMMC overwrote DatDAA (DAA) and DVDP4
; (R#4: TBloque then took block 3's patterns from block 0, BUN-GA-RUA's HUD).
CPUCopyBuf:	DS.L	5
MSplitOn5:	DC.B	0		; SCREENT shown this render.
		EVEN
PalDbgBlk:
PalSplitSeen:	DC.B	0		; Frames left with mid-frame palettes.
		EVEN
PALEVMAX=6
PalEvN:		DC.W	0		; Palette events this frame (OUT9Ab).
PalEvTmp:	DC.W	0
PalEvLast:	DC.W	0		; Line of the last event's first write.
PalEvLines:	DS.W	PALEVMAX	; Line each event applies from.
PalEvBuf:	DS.B	32*PALEVMAX	; Its 16 colours (as MSX2Pal).
PalTop:		DS.W	16		; Palette at the frame's top.
PalDbgEnd:
SCRTDirty:	DC.B	$FF		; SCREEN 5/7 planes written since the copy.
		EVEN
MSFKey:		DC.L	-1		; Split line, R#2, R#23 of the copy.
SCRTLo:		DC.L	0		; VRAM range of the page copied,
SCRTHi:		DC.L	$20000
SCRTBLo:	DC.W	0		; and its 1 KB blocks.
SCRTBHi:	DC.W	128
LastRend:	DC.B	$FF		; Mode of the last render.
M5Tracked:	DC.B	0		; This SCREEN 5 stay marks the SCREEN 4 cache.
		EVEN

; ---------------------------------------=> Key script (CLI test hook).
; Records of 8 bytes: frame (MSX frames since power on), keyboard matrix
; row, key mask, hold frames; frame -1 ends the list. A key is down (its
; matrix bits 0) during [frame, frame + hold) and released once after.
; The keys stay usable from the Amiga keyboard otherwise.
	CNOP	0,4
KeyScrRun:
	MOVEM.L	D0-D3/A0-A1,-(SP)
	ADDQ.L	#1,KeyFrN
	MOVE.L	KeyFrN,D3
	MOVE.L	KeyScrPtr,A0
	LEA	KEY(A3),A1
KeyScrBuc:
	MOVE.L	(A0)+,D0		; Frame.
	CMP.L	#-1,D0
	BEQ.S	KeyScrFin
	MOVEQ	#0,D1
	MOVE.B	(A0)+,D1		; Row.
	MOVE.B	(A0)+,D2		; Mask.
	ADDQ.W	#2,A0			; (Hold: read below.)
	CMP.B	#$FF,D1			; Row $FF: snapshot marker.
	BEQ.S	KeyScrSnap
	CMP.B	#$FE,D1			; Row $FE: option (applied at load).
	BEQ.S	KeyScrNx
	CMP.L	D0,D3			; Not yet.
	BCS.S	KeyScrBuc
	SUB.L	D0,D3			; Frames since the press...
	MOVEQ	#0,D0
	MOVE.W	-2(A0),D0
	CMP.L	D0,D3
	BCS.S	KeyScrDn		; ...while held,
	BEQ.S	KeyScrUp		; released just once.
	BRA.S	KeyScrNx
KeyScrDn:
	NOT.B	D2
	AND.B	D2,(A1,D1.W)
	BRA.S	KeyScrNx
KeyScrUp:
	OR.B	D2,(A1,D1.W)
KeyScrNx:
	MOVE.L	KeyFrN,D3
	BRA.S	KeyScrBuc
KeyScrFin:
	MOVEM.L	(SP)+,D0-D3/A0-A1
	RTS
; SNAP: at its frame, hold the emulation for 'hold' Amiga frames with the
; power LED on (CIA-A PRA bit 1 low), so the harness captures exactly this
; MSX frame (it watches the LED in WinUAE's status bar).
KeyScrSnap:
	CMP.L	D0,D3
	BNE.S	KeyScrNx
	MOVE.W	-2(A0),SnapPend		; Freeze after this frame's render.
	BRA.S	KeyScrNx
; SNAP freeze, after the render: hold the finished frame for SnapPend Amiga
; frames with the power LED on (CIA-A PRA bit 1 low), so the harness captures
; exactly this MSX frame (it watches the LED in WinUAE's status bar).
KeySnapDo:
	MOVEM.L	D0/D2,-(SP)
	MOVE.B	$BFE001,-(SP)
	BSET	#1,$BFE201		; (DDRA: LED bit an output.)
	BCLR	#1,$BFE001		; LED on.
	MOVE.W	SnapPend,D2
	MOVE.W	D2,SnapHold
	CLR.W	SnapPend
	SUBQ.W	#1,D2
KeySnapF:
	MOVE.L	$DFF004,D0		; Wait for a new Amiga frame: past line 20,
	LSR.L	#8,D0
	AND.W	#$1FF,D0
	CMP.W	#20,D0
	BCS.S	KeySnapF
KeySnapG:
	MOVE.L	$DFF004,D0		; then back to the top.
	LSR.L	#8,D0
	AND.W	#$1FF,D0
	CMP.W	#20,D0
	BCC.S	KeySnapG
	DBF	D2,KeySnapF
	MOVE.B	(SP)+,D0
	AND.B	#$02,D0			; LED back as it was.
	BCLR	#1,$BFE001
	OR.B	D0,$BFE001
	MOVE.W	SnapHold,D2		; Still frozen as long again with the LED
	SUBQ.W	#1,D2			; dark, so the capture sees each SNAP end
KeySnapH:				; even when the next one is a frame away
	MOVE.L	$DFF004,D0		; (consecutive-frame bursts; WinUAE warp
	LSR.L	#8,D0			; mode makes Amiga frames short).
	AND.W	#$1FF,D0
	CMP.W	#20,D0
	BCS.S	KeySnapH
KeySnapI:
	MOVE.L	$DFF004,D0
	LSR.L	#8,D0
	AND.W	#$1FF,D0
	CMP.W	#20,D0
	BCC.S	KeySnapI
	DBF	D2,KeySnapH
	MOVEM.L	(SP)+,D0/D2
	RTS
SnapPend:	DC.W	0
SnapHold:	DC.W	0

KeyScrPtr:	DC.L	0		; Loaded script (Menu), 0: none.
KeyFrN:		DC.L	0		; MSX frames since power on.
KEYSCRMAX=256
KeyScr:		DS.B	KEYSCRMAX*8
		DC.L	-1		; (Guard.)
KEYNOM:		DS.B	256		; CLI key script file name.
		EVEN

; Display lines TSplit..191 (211 in 212-line mode) from the current tables (R#2, R#3/R#10, R#4,
; R#23), straight from VRAM into SCREENB (128 bytes a line, 4 interleaved
; planes of 32 bytes, as SCREEN), line TSplit first. No cache: meant for a
; HUD of a few lines. TABLA7E gives the 4 plane bytes of a pattern/colour
; pair, plane 0 in the high byte (as TRASF).
	CNOP	0,4
HUDSplit4:
	MOVEM.L	D0-D7/A0-A6,-(SP)
	LEA	REGS,A3
	LEA	SCREENB,A1
	LEA	TABLA7E,A2
	MOVE.W	TSplit,D7		; Display line.
	MOVE.W	#192,D6			; Last display line + 1: 212 with LN
	BTST	#7,DVDP9(A3)		; (R#9 bit 7). Space Manbow's ground
	BEQ.S	HUDS4N192		; strip is lines 196-211, below a table
	MOVE.W	#212,D6			; split at line 81.
HUDS4N192:
HUDS4Lin:
	MOVEQ	#0,D0
	MOVE.B	VDPLinY(A3),D0		; VRAM line = display line + R#23.
	ADD.W	D7,D0
	AND.W	#$FF,D0
	MOVE.W	D0,D1
	LSR.W	#3,D1			; Name row 0-31.
	AND.W	#7,D0			; Line in the character.
	LEA	DIRVRAM,A4
	ADD.L	PVDP2(A3),A4
	MOVE.W	D1,D2
	LSL.W	#5,D2
	ADD.W	D2,A4			; This row's names.
	LSR.W	#3,D1			; Block 0-3 (TBloque's masks).
	MOVEQ	#11,D4
	MOVEQ	#0,D3
	MOVE.B	DVDP4+1(A3),D3		; Pattern: PVDP4B + ((t & R#4) << 11).
	AND.W	D1,D3
	AND.W	#3,D3
	LSL.L	D4,D3
	ADD.L	PVDP4B(A3),D3
	LEA	DIRVRAM,A5
	ADD.L	D3,A5
	ADD.W	D0,A5
	MOVEQ	#0,D3
	MOVE.B	DVDP3+1(A3),D3		; Colour: PVDP3B + ((t & (R#3>>5)) << 11).
	LSR.B	#5,D3
	AND.W	D1,D3
	AND.W	#3,D3
	LSL.L	D4,D3
	ADD.L	PVDP3B(A3),D3
	LEA	DIRVRAM,A6
	ADD.L	D3,A6
	ADD.W	D0,A6
	MOVEQ	#32-1,D5
HUDS4Col:
	MOVEQ	#0,D1
	MOVE.B	(A4)+,D1
	LSL.W	#3,D1			; Name * 8.
	MOVEQ	#0,D2
	MOVE.B	(A5,D1.W),D2		; Pattern byte...
	LSL.W	#8,D2
	MOVE.B	(A6,D1.W),D2		; ...and colour byte.
	MOVE.L	(A2,D2.L*4),D3
	MOVE.B	D3,96(A1)		; Plane 3.
	LSR.L	#8,D3
	MOVE.B	D3,64(A1)		; Plane 2.
	LSR.L	#8,D3
	MOVE.B	D3,32(A1)		; Plane 1.
	LSR.W	#8,D3
	MOVE.B	D3,(A1)+		; Plane 0.
	DBF	D5,HUDS4Col
	ADD.W	#(32*4)-32,A1
	ADDQ.W	#1,D7
	CMP.W	D6,D7
	BCS	HUDS4Lin
	MOVEM.L	(SP)+,D0-D7/A0-A6
	RTS

		CNOP	0,4
SegSeen:	DC.B	0		; Register split this frame (RSPLITCHK),
SegR8:		DC.B	0		; and the longest segment's R#8,
SegAdj:		DC.B	0		; R#18,
SegLinY:	DC.B	0		; R#23,
SegStart:	DC.W	0		; current segment's first line,
SegBest:	DC.W	0		; longest segment's length.
SegSv:		DC.L	0
TSplit:		DC.W	0		; First line with the new tables, 0: none.
TA_DVDP2:	DC.B	0		; Tables above the split (playfield)...
TA_LinY:	DC.B	0
TA_DVDP3:	DC.W	0
TA_DVDP4:	DC.W	0
TA_PVDP2:	DC.L	0
TA_PVDP3:	DC.L	0
TA_PVDP3B:	DC.L	0
TA_PVDP4:	DC.L	0
TA_PVDP4B:	DC.L	0
TB_DVDP2:	DC.B	0		; ...and below it (PRINT4S).
TB_LinY:	DC.B	0
TB_DVDP3:	DC.W	0
TB_DVDP4:	DC.W	0
TB_PVDP2:	DC.L	0
TB_PVDP3:	DC.L	0
TB_PVDP3B:	DC.L	0
TB_PVDP4:	DC.L	0
TB_PVDP4B:	DC.L	0

; Sprite mode 2 by bands: BandBuf holds the sprite tables as they were at
; lines 0, 16, ... (BANDSHOT); each is drawn by the IMPSPR2 core for its 16
; lines only (the last one down to the bottom). The buffer for CLEARSPR2 is
; filled by all passes and its count is their total.
	CNOP	0,4
IMPSPR2B:
	MOVE.L	NUMSPR2,BandReal	; The real count word...
	MOVE.L	#BandCnt,NUMSPR2	; ...and one per pass.
	CLR.W	BandTotal
	CLR.W	BandK
	SF	BandLater
	ST	BandPass
IMPS2BBuc:
	MOVE.W	BandK,D0
	CMP.W	BandN,D0
	BCC	IMPS2BFin
	LEA	BandLine,A1		; From its first line...
	MOVE.W	(A1,D0.W*2),BandLo
	ADDQ.W	#1,D0
	MOVE.W	#256,D1			; ...to the next band's (the last
	CMP.W	BandN,D0		; one to the bottom).
	BCC.S	IMPS2BHi
	MOVE.W	(A1,D0.W*2),D1
IMPS2BHi:
	MOVE.W	D1,BandHi
	SUBQ.W	#1,D0
	MULU	#640,D0
	LEA	BandBuf+512,A4
	ADD.L	D0,A4
	LEA	-512(A4),A0
	MOVE.W	BandK,D0
	LEA	BandR8,A1		; Sprites off on this band's lines:
	BTST	#1,(A1,D0.W)		; nothing to draw.
	BNE.S	IMPS2BSkip
	LEA	BandLinY,A1
	MOVE.B	(A1,D0.W),BandLinYCur
	LEA	SPR2TABLA(PC),A1
	JSR	IMPSPR2c		; (A5 moves on through all passes.)
	MOVE.W	BandCnt,D0
	ADDQ.W	#1,D0
	ADD.W	D0,BandTotal
	ST	BandLater
IMPS2BSkip:
	ADDQ.W	#1,BandK
	BRA	IMPS2BBuc
IMPS2BFin:
	MOVE.L	BandReal,A0
	MOVE.W	BandTotal,D0
	SUBQ.W	#1,D0
	MOVE.W	D0,(A0)
	MOVE.L	A0,NUMSPR2
	SF	BandPass
	SF	BandLater
	RTS

BANDMAX=24				; 12 steps of 16 lines + splits.
TopR8:		DC.B	0		; Playfield R#8 (sprites on/off, SPD),
MidAdj:		DC.B	0		; R#18,
MidLinY:	DC.B	0		; R#23 (MIDSAMPLE).
		EVEN
BandOn:		DC.B	0		; Bands this frame (MiraInter0S).
BandPass:	DC.B	0		; Drawing by bands (IMPSPR2B).
BandLater:	DC.B	0		; Not the first band.
		EVEN
BandN:		DC.W	0		; Snapshots taken.
BandK:		DC.W	0
BandCnt:	DC.W	0
BandTotal:	DC.W	0
BandReal:	DC.L	0
BandLinY:	DS.B	BANDMAX		; R#23 at each band snapshot.
		EVEN
BandLine:	DS.W	BANDMAX		; First line of each band.
BandSplitP:	DC.B	0		; Band asked for at the next line.
		EVEN
BandLinYCur:	DC.B	0
BandR8:		DS.B	BANDMAX		; R#8 at each band snapshot.
		EVEN

	IFD	PERF
; Time stamp in PAL colour clocks: (VBlank interrupts (PerfTick) * 313 +
; VPOSR line) * 227 + horizontal position. Keeps every register.
PerfStamp:
	MOVEM.L	D0-D1,-(SP)
PerfStBuc:
	MOVE.L	PerfTick,D1
	MOVE.L	$DFF004,D0		; V8 (bit 16), V7-V0 (bits 15-8).
	CMP.L	PerfTick,D1
	BNE.S	PerfStBuc
	MOVE.L	D0,-(SP)
	LSR.L	#8,D0
	AND.L	#$1FF,D0
	CMP.W	PerfVMax,D0
	BLS.S	PerfStPos
	MOVE.W	D0,PerfVMax		; Longest frame seen.
PerfStPos:
	MULU.L	#313,D1
	ADD.L	D1,D0
	MULU.L	#227,D0			; Colour clocks per line.
	MOVE.L	(SP)+,D1
	AND.L	#$FF,D1
	ADD.L	D1,D0
	MOVE.L	D0,PerfNow
	MOVEM.L	(SP)+,D0-D1
	RTS

; Accumulate one frame: core = A - last D, wait = B - A, other = C - B,
; render = D - C. Every PERFWIN frames a record goes to PerfRing.
PERFWIN=250
PerfFrame:
	MOVEM.L	D0-D1/A0-A1,-(SP)
	LEA	PerfRec,A0
	TST.L	PerfLast
	BEQ.S	PerfFrNoCore		; First frame: no core time yet.
	MOVE.L	PerfA,D0
	SUB.L	PerfLast,D0
	ADD.L	D0,8(A0)		; core
	TST.L	4(A0)
	BNE.S	PerfFrNoCore
	MOVE.L	PerfLast,PerfWin0	; Window starts at the last D.
	MOVE.L	PerfTick,PerfTick0
PerfFrNoCore:
	MOVE.L	PerfB,D0
	SUB.L	PerfA,D0
	ADD.L	D0,12(A0)		; wait
	MOVE.L	PerfC,D0
	SUB.L	PerfB,D0
	ADD.L	D0,16(A0)		; other
	MOVE.L	PerfD,D0
	SUB.L	PerfC,D0
	ADD.L	D0,20(A0)		; render
	MOVE.L	PerfD,PerfLast
	TST.L	PerfWin0
	BEQ.S	PerfFrFin
	ADDQ.L	#1,4(A0)		; frames
	CMP.L	#PERFWIN,4(A0)
	BCS.S	PerfFrFin
	MOVE.L	PerfD,D0		; Window done: elapsed, ticks.
	SUB.L	PerfWin0,D0
	MOVE.L	D0,(A0)
	MOVE.L	PerfTick,D0
	SUB.L	PerfTick0,D0
	MOVE.L	D0,28(A0)
	MOVE.L	PerfPtr,A1
	MOVEQ	#16-1,D0
PerfFrCop:
	MOVE.L	(A0),(A1)+
	CLR.L	(A0)+
	DBF	D0,PerfFrCop
	CMP.L	#PerfRingEnd,A1
	BCS.S	PerfFrRing
	LEA	PerfRing,A1
PerfFrRing:
	MOVE.L	A1,PerfPtr
	ADDQ.L	#1,PerfCount
	CLR.L	PerfWin0
PerfFrFin:
	MOVEM.L	(SP)+,D0-D1/A0-A1
	RTS

		CNOP	0,4
PerfNow:	DC.L	0
PerfA:		DC.L	0
PerfB:		DC.L	0
PerfC:		DC.L	0
PerfD:		DC.L	0
PerfLast:	DC.L	0
PerfWin0:	DC.L	0
PerfTick0:	DC.L	0
PerfRec:	DS.L	16			; elapsed, frames, core, wait, other,
						; render, renders, VBlank ints,
						; PERFSUB 0-7 (colour clocks)
PerfSubT:	DC.L	0
PerfSv:		DS.L	4		; PERFSTAMPI / PERFSUB register saves.
PerfHdr:	DC.L	"APRF"
PerfCount:	DC.L	0			; Records written.
PerfPtr:	DC.L	PerfRing
PerfTick:	DC.L	0			; VBlank interrupts (Inter).
PerfVMax:	DC.W	0			; Highest VPOSR line seen.
PerfIntMin:	DC.W	0			; ScrModo, R#0 of the last render.
PerfIntMax:	DC.W	0			; Latest VBlank int line.
PerfCPU:	DC.W	0			; AttnFlags, Modo060.
PerfRing:	DS.L	16*128
PerfRingEnd:
PerfPCBase:	DC.L	Emula1Frame	; Profile: anchor for the listing,
PerfPCCnt:	DC.L	0		; samples taken,
PerfPCPtr:	DC.L	PerfPCBuf	; next slot,
PerfPCEnd0:
	ENDC

	CNOP	0,4
TRANSSPR16S:
	JSR	TRANSSPR16
; Split (see IMPSPR): pattern slots used only by sprites above the split
; are converted from the top snapshot's pattern table into GFXSPR, and back
; from R#6's table once that is over. Uridium: HUD patterns 128-236 from
; R#6=$03 above line 63, ship and bullets from R#6=$07 below. Slots used
; on both sides go to a free slot for the top sprites (remap). Also sets
; SplitOK for IMPSPR.
SprSlotsT:
	LEA	REGS(PC),A3
	SF	SplitOK
	TST.W	SprSplit
	BEQ.S	SpSlNoSplit
	TST.B	SnapTOK
	BEQ.S	SpSlNoSplit
	TST.B	SnapOK
	BEQ.S	SpSlNoSplit
	ST	SplitOK
SpSlNoSplit:
	TST.B	SprTInit		; GFXSPRT: 8x8 buffer + 96, if all of
	BNE.S	SpSlTOK			; it shares GFXSPR's 64 KB bank (the
	ST	SprTInit		; copper only sets sprite pointers' low
	MOVE.L	GFXSPR8,D0		; words).
	ADD.L	#24*4,D0
	MOVE.L	D0,D1
	SUB.L	#18*4,D1
	MOVE.L	D0,D2
	ADD.L	#$1200+(64*18*4),D2
	MOVE.L	GFXSPR,D3
	SWAP	D1
	SWAP	D2
	SWAP	D3
	CMP.W	D3,D1
	BNE.S	SpSlTOK
	CMP.W	D3,D2
	BNE.S	SpSlTOK
	MOVE.L	D0,GFXSPRT
	MOVE.L	GFXSPR8,A1		; Empty sprite before the slots (the
	MOVEQ	#(24)-1,D1		; transparent-colour sprites use it).
SpSlTClr:
	CLR.L	(A1)+
	DBF	D1,SpSlTClr
SpSlTOK:
	LEA	SlotMark,A0		; 0 none, 1 top only, 2 below (wins)
	MOVEQ	#(64/4)-1,D0
SpSlClr:CLR.L	(A0)+
	DBF	D0,SpSlClr
	TST.B	SplitOK
	BEQ	SpSlConv
	LEA	SlotMark,A0
	MOVE.W	SprSplit,D2
	ADD.W	#14,D2			; Top pass: Y+15 < split+14.
	LEA	SprSnapT+512,A1
	MOVEQ	#32-1,D0
SpSlTop:MOVEQ	#0,D1
	MOVE.B	(A1),D1
	CMP.B	#208,D1
	BEQ.S	SpSlTopF
	ADD.B	#15,D1
	CMP.W	D2,D1
	BCC.S	SpSlTopN
	MOVEQ	#0,D3
	MOVE.B	2(A1),D3
	LSR.B	#2,D3
	TST.B	(A0,D3.W)
	BNE.S	SpSlTopN
	MOVE.B	#1,(A0,D3.W)
SpSlTopN:
	ADDQ.W	#4,A1
	DBF	D0,SpSlTop
SpSlTopF:
	MOVE.W	SprSplit,D2		; Main pass: Y+15 >= split.
	LEA	SprSnap+512,A1
	MOVEQ	#32-1,D0
SpSlBot:MOVEQ	#0,D1
	MOVE.B	(A1),D1
	CMP.B	#208,D1
	BEQ	SpSlBotF		; (End of the list: on to the top fix-ups.)
	ADD.B	#15,D1
	CMP.W	D2,D1
	BCS.S	SpSlBotN
	MOVEQ	#0,D3
	MOVE.B	2(A1),D3
	LSR.B	#2,D3
	MOVE.B	#2,(A0,D3.W)
SpSlBotN:
	ADDQ.W	#4,A1
	DBF	D0,SpSlBot
SpSlBotF:
	TST.L	GFXSPRT
	BNE	SpSlOwn
; Top sprites on a slot the bottom ones use (mark 2): a free slot (mark 0,
; from 63 down) gets their pattern (mark 3, SlotSrc = their slot), and the
; pattern number in SprSnapT is changed to it. One per conflicting slot.
	LEA	SlotRemap,A2
	MOVEQ	#(64/4)-1,D0
SpSlRClr:
	CLR.L	(A2)+
	DBF	D0,SpSlRClr
	LEA	SlotRemap,A2
	MOVE.W	SprSplit,D2
	ADD.W	#14,D2
	LEA	SprSnapT+512,A1
	MOVEQ	#32-1,D0
SpSlRem:MOVEQ	#0,D1
	MOVE.B	(A1),D1
	CMP.B	#208,D1
	BEQ.S	SpSlConv
	ADD.B	#15,D1
	CMP.W	D2,D1			; Top sprites only.
	BCC.S	SpSlRemN
	MOVEQ	#0,D3
	MOVE.B	2(A1),D3
	LSR.B	#2,D3
	CMP.B	#2,(A0,D3.W)		; Slot taken by the bottom table?
	BNE.S	SpSlRemN
	MOVEQ	#0,D4
	MOVE.B	(A2,D3.W),D4		; Already remapped this frame?
	BNE.S	SpSlRemP
	MOVEQ	#64-1,D4		; Free slot.
SpSlFree:
	TST.B	(A0,D4.W)
	BEQ.S	SpSlGot
	DBF	D4,SpSlFree
	BRA.S	SpSlRemN		; None free: as before.
SpSlGot:
	MOVE.B	#3,(A0,D4.W)
	MOVE.L	A0,-(SP)
	LEA	SlotSrc,A0
	MOVE.B	D3,(A0,D4.W)
	MOVE.L	(SP)+,A0
	ADDQ.W	#1,D4
	MOVE.B	D4,(A2,D3.W)
SpSlRemP:
	SUBQ.W	#1,D4
	LSL.B	#2,D4
	AND.B	#$03,2(A1)		; New pattern number (16x16: slot * 4).
	OR.B	D4,2(A1)
SpSlRemN:
	ADDQ.W	#4,A1
	DBF	D0,SpSlRem
SpSlConv:
	LEA	SlotMark,A0
	LEA	SlotFromT,A2
	MOVE.L	GFXSPR,A1
	MOVEQ	#0,D3			; Slot.
SpSlBuc:
	MOVE.W	D3,D2			; Source slot: this one...
	CMP.B	#1,(A0,D3.W)
	BEQ.S	SpSlTopT
	CMP.B	#3,(A0,D3.W)
	BNE.S	SpSlNoT
	MOVE.L	A0,-(SP)		; ...or a remapped top pattern.
	LEA	SlotSrc,A0
	MOVE.B	(A0,D3.W),D2
	MOVE.L	(SP)+,A0
SpSlTopT:
	MOVE.L	SnapT6,D1		; Top only: from the top table.
	ST	(A2,D3.W)
	BRA.S	SpSlDo
SpSlNoT:
	TST.B	(A2,D3.W)
	BEQ	SpSlSig
	SF	(A2,D3.W)		; Was from the top table: back.
	MOVE.L	PVDP6(A3),D1
SpSlDo:	MOVEM.L	D3/A0-A2,-(SP)
	LEA	DIRVRAM,A0
	ADD.L	D1,A0
	MOVE.W	D2,D1
	LSL.W	#5,D1
	ADD.W	D1,A0			; 32 bytes per 16x16 pattern.
	MULU	#(18*4),D3
	ADD.L	D3,A1			; 72 bytes per GFXSPR slot.
	MOVE.L	A1,A4
	NOT.B	-3(A1)
	BEQ.S	SpSlNoS
	ADD.W	#$1200,A4
SpSlNoS:
	MOVEM.L	(A0)+,D4-D7
	PONSPR	D4,00
	PONSPR	D5,16
	PONSPR	D6,32
	PONSPR	D7,48
	MOVEM.L	(A0)+,D4-D7
	PONSPR	D4,01
	PONSPR	D5,17
	PONSPR	D6,33
	PONSPR	D7,49
	MOVEM.L	(SP)+,D3/A0-A2
SpSlSig:
	ADDQ.W	#1,D3
	CMP.W	#64,D3
	BCS	SpSlBuc
	RTS

; Split with GFXSPRT: each slot a top sprite uses is converted there from the
; top table (SnapT6), once per frame; GFXSPR keeps R#6's patterns. Then the
; slot loop only puts back slots an earlier fallback frame borrowed.
SpSlOwn:
	LEA	SlotTDone,A2
	MOVEQ	#(64/4)-1,D0
SpSlOClr:
	CLR.L	(A2)+
	DBF	D0,SpSlOClr
	LEA	SlotTDone,A2
	MOVE.W	SprSplit,D2
	ADD.W	#14,D2
	LEA	SprSnapT+512,A1
	MOVEQ	#32-1,D0
SpSlOBuc:
	MOVEQ	#0,D1
	MOVE.B	(A1),D1
	CMP.B	#208,D1
	BEQ	SpSlOFin
	ADD.B	#15,D1
	CMP.W	D2,D1			; Top sprites only.
	BCC	SpSlONxt
	MOVEQ	#0,D3
	MOVE.B	2(A1),D3
	LSR.B	#2,D3
	TST.B	(A2,D3.W)
	BNE	SpSlONxt
	ST	(A2,D3.W)
	MOVEM.L	D0/D2/A1-A2,-(SP)
	LEA	DIRVRAM,A0
	ADD.L	SnapT6,A0
	MOVE.W	D3,D1
	LSL.W	#5,D1
	ADD.W	D1,A0			; 32 bytes per 16x16 pattern.
	MOVE.L	GFXSPRT,A1
	MULU	#(18*4),D3
	ADD.L	D3,A1			; 72 bytes per slot.
	MOVE.L	A1,A4
	NOT.B	-3(A1)
	BEQ.S	SpSlONoS
	ADD.W	#$1200,A4
SpSlONoS:
	MOVEM.L	(A0)+,D4-D7
	PONSPR	D4,00
	PONSPR	D5,16
	PONSPR	D6,32
	PONSPR	D7,48
	MOVEM.L	(A0)+,D4-D7
	PONSPR	D4,01
	PONSPR	D5,17
	PONSPR	D6,33
	PONSPR	D7,49
	MOVEM.L	(SP)+,D0/D2/A1-A2
SpSlONxt:
	ADDQ.W	#4,A1
	DBF	D0,SpSlOBuc
SpSlOFin:
	LEA	SlotMark,A0		; Nothing for GFXSPR but restores.
	MOVEQ	#(64/4)-1,D0
SpSlOClr2:
	CLR.L	(A0)+
	DBF	D0,SpSlOClr2
	BRA	SpSlConv
; ---------------------------------------<=



; --------------------------------
CodeHi:
	SECTION	BPL,DATA_C
; --------------------------------

	CNOP	0,8
ONDA:	DC.B	127,-128
ONDA1:	DC.B	127,127
	CNOP	0,8
SCONDA0:DS.B	32
SCONDA1:DS.B	32
SCONDA2:DS.B	32
SCONDA3:DS.B	32
SCONDA4:DS.B	32
SONDA0:	DS.B	16
SONDA1:	DS.B	16
SONDA2:	DS.B	16
SONDA3:	DS.B	16
SONDA4:	DS.B	16

	CNOP	0,8
RUIDO:	INCBIN	"Gfx/Sample-ruido.raw"

	CNOP	0,8
	DCB.B	80,$FF
MASKFF:	DCB.B	80,$FF

	IFEQ	MENU
	CNOP	0,8
MSXPIC:	INCBIN	"Gfx/AmiMSX_Logo.raw"	; 351*45
	CNOP	0,8
MatraPic:INCBIN	"Gfx/MatraLogo.raw"	; 360*201
	CNOP	0,8
BUSYGFX:dc.w	$0000,$0000
	dc.w	$0400,$07C0
	dc.w	$0000,$07C0
	dc.w	$0100,$0380
	dc.w	$0000,$07E0
	dc.w	$07C0,$1FF8
	dc.w	$1FF0,$3FEC
	dc.w	$3FF8,$7FDE
	dc.w	$3FF8,$7FBE
	dc.w	$7FFC,$FF7F
	dc.w	$7EFC,$FFFF
	dc.w	$7FFC,$FFFF
	dc.w	$3FF8,$7FFE
	dc.w	$3FF8,$7FFE
	dc.w	$1FF0,$3FFC
	dc.w	$07C0,$1FF8
	dc.w	$0000,$07E0
	dc.w	$0000,$0000
	dc.w	$0000,$0000
	dc.w	$0000,$0000
	ENDC


	CNOP	0,8
MASTERCOPPER:
	DC.W	$0100,0
MCAGA:
	DC.W	$01FC,$000F
	DC.W	$0106,$0C40
	DC.W	$010C,$0011
; -------------------------------------------
DIRSPRIT0:	DS.W	4
DIRSPRIT1:	DS.W	4
DIRSPRIT2:	DS.W	4
DIRSPRIT3:	DS.W	4
DIRSPRIT4:	DS.W	4
DIRSPRIT5:	DS.W	4
DIRSPRIT6:	DS.W	4
DIRSPRIT7:	DS.W	4
MCOPP96:	DC.W	$0096,$0000
; -------------------------------------------
		DC.W	$1401,$FFFE
COLORSPR2:	DS.W	16*2
COLORMSX2:	DS.W	16*2
COLBORDE:	DC.W	$0180,0
; -------------------------------------------
		DC.W	$1801,$FFFE
MCSALTO0:	DC.W	$01A0,0
MCSALTO1:	DC.W	$01A0,0
; -------------------------------------------
VerPan:		DC.W	$8E,(INIPANT*$100)+$99,$90,(((INIPANT+212)&$FF)*$100)+$A1
AdjustX:	DC.W	$0092,$0040,$0094,$00B8,$0102,$8800
		DC.W	$0104,$003F		; Spr sobre Bpl.
; -------------------------------------------
		DC.W	$1A51,$FFFE
		DC.W	$008A,$0000
		DC.L	$FFFFFFFE

ScrModeCopp:	DC.W	$0084,0,$0086,0


; -------------------------------------------
	CNOP	0,8
COPPERN:
	DC.W	$0108,-MOD,$010A,-MOD
CNXOR:	DC.W	$010C,$0011

	DC.W	$0096,$0020		; Sprites OFF

	DC.W	$0100,$0000,$0102,$0000
	DC.W	$0092,$0038,$0094,$00D0
	DC.W	$008E,$2B31,$0090,$2BC9

	DC.W	$0180,$0000,$0182,$0ECA
	DC.W	$0184,$0962,$0186,$0642
; -=-=-
	DC.W	$B021,$FFFE
	DC.W	$0096,$8020		; Sprites ON

	DC.W	$C021,$FFFE
Int_VDN:DC.W	$009C,$8010		; Emulaci�n del VDP
	DC.L	$FFFFFFFE
	DC.L	$FFFFFFFE


PLANO:	DS.W	2*4 
	DC.W	$8121,$FFFE,$0180,$0B6E
	DC.W	$8221,$FFFE,$0180,$0518
	DC.W	$8401,$FFFE,$0096,$8100,$0100,$2200
	DC.W	$9B01,$FFFE,$0096,$0100,$0100,$0000
	DC.W	$9C21,$FFFE,$0180,$0518
	DC.W	$9E21,$FFFE,$0180,$0B6E
	DC.W	$9F21,$FFFE,$0180,$0000


	CNOP	0,8
FONT:	DCB.L	$8,$0
	DC.L	$3C000000,$0,$C3624,$1C22000E,$2200000,$0
	DC.L	$C043C3C,$243C3C3E,$3C3C0000,$78,$3C3E3C
	DC.L	$383C3C3C,$8245A,$2056000C,$4101200,$2,$120C4446
	DC.L	$6660600E,$66661818,$400108C,$24666466,$64606060
	DC.L	$80024,$182C0004,$C180C08,$4,$3F1C080C,$663C7C1E
	DC.L	$3C3E1010,$83C0808,$76667A60,$66707060,$80024
	DC.L	$C1A0008,$C180C1C,$1C0008,$3F0C1006,$3E06663C
	DC.L	$66060000,$10000430,$6E7E6460,$66606064,$5A
	DC.L	$2350000,$4101208,$C001810,$120C2046,$6066678
	DC.L	$66661818,$83C0800,$66666666,$64606066,$80024
	DC.L	$1C220000,$2200000,$8001000,$C0C7E3C,$43C3C30
	DC.L	$3C3C1000,$4001020,$22243C3C,$383C203C,$0,$0,$0
	DC.L	$8000000,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0
	DCB.L	$3,$0
	DC.L	$243C3C22,$2041443C,$3C3C3C5C,$3C242422,$22243E08
	DC.L	$101010,$0,$0,$0,$0,$66180664,$60636666,$66666620
	DC.L	$1866666B,$14660410,$20080000,$0,$0,$0,$0
	DC.L	$66180678,$607F7666,$6666647A,$1866666B,$1C240810
	DC.L	$10081818,$0,$0,$0,$0,$7E180678,$606B6E66
	DC.L	$7C627A0C,$1866247F,$1C181010,$8081020,$0,$0,$0
	DC.L	$0,$66182464,$60636666,$606C640C,$18661863
	DC.L	$14182010,$4081062,$0,$0,$0,$0,$243C1822
	DC.L	$3C22223C,$202C263A,$103C0041,$22107C08,$10103C
	DCB.L	$F,$0
	DC.L	$8000000,$0,$0,$0,$0,$0,$0,$42000000,$0,$0
	DC.L	$22510000,$4100000,$3,$12080042,$42424240
	DC.L	$42420000,$84,$424042,$44424242,$41224,$8000002
	DC.L	$8081E08,$5,$21102220,$8,$0,$8002040,$52000200
	DC.L	$2000000,$40000,$20500002,$1200,$A,$8200402
	DC.L	$420212,$42400808,$10421014,$8000600,$80800
	DC.L	$40000,$2050004,$1222,$220014,$4000800,$40000024
	DC.L	$0,$20000808,$10000200,$2,$24,$8000000,$8081E00
	DC.L	$28,$21001020,$48,$0,$10421000,$8000000,$2000000
	DC.L	$40000,$22450000,$4100008,$4000830,$12120042
	DC.L	$2424250,$42420808,$8002010,$44424242,$44424042
	DC.L	$0,$8000000,$0,$C000000,$0,$0,$10,$0,$0,$0,$0,$0
	DCB.L	$8,$0
	DC.L	$42424244,$40222242,$42424262,$42424241,$55424014
	DC.L	$60280808,$0,$0,$0,$0,$8,$141000,$40,$0,$2A000A00
	DC.L	$50000000,$0,$0,$0,$0,$0,$800,$246,$14,$5A1400
	DC.L	$28000020,$0,$0,$0,$0,$0,$141000,$204060A,$5A00
	DC.L	$242800,$14000850,$0,$0,$0,$0,$4208,$80800,$6020A
	DC.L	$2414,$2A005000,$A000804,$0,$0,$0,$0,$42422444
	DC.L	$42414442,$40584046,$8421822,$55080214,$6280842
	DCB.L	$E,$0

	CNOP	0,8
PANT:	DS.B	40*24*2
	DS.L	10
	EVEN
; *****************************************************************

MOD=8

	CNOP	0,8
COPPER0:
	DC.W	$0092,$0028,$0094,$00C0,$0102,$CCFF
	DC.W	$0108,-MOD,$010A,-MOD
C0XOR:	DC.W	$010C,$0011
	DC.W	$0104,$0000
Ver0:	DC.W	$008E,(INIPANT*$100)+$80,$0090,(((INIPANT+192)&$FF)*$100)+$C0
COLOR0:	DC.W	$180,0,$0182,$0
PLANO0:	DS.W	1*4

PANPOS:	SET	INIPANT
	DC.W	(PANPOS*$100)+$01,$FFFE,$0100,$1200
ModSC0:
	REPT	24
	DC.W	(PANPOS*$100)+$21,$FFFE
	DC.W	$0108,(040*23)-MOD
PANPOS:	SET	PANPOS+7
	IFNE	PANPOS>$FF
	DC.W	$FFDF,$FFFE
PANPOS:	SET	(PANPOS&$FF)
	ENDC
	DC.W	(PANPOS*$100)+$21,$FFFE
	DC.W	$0108,(-40*24*7)-MOD
PANPOS:	SET	PANPOS+1
	IFNE	PANPOS>$FF
	DC.W	$FFDF,$FFFE
PANPOS:	SET	(PANPOS&$FF)
	ENDC
	ENDR
Int_VD0:DC.W	$009C,$8010		; Emulaci�n del VDP
	DC.L	$FFFFFFFE
; ------------------------------------------------ ;
	CNOP	0,8
COPPER9:
	DC.W	$0092,$0028,$0094,$00C0,$0102,$CCFF
	DC.W	$0108,-MOD,$010A,-MOD
C9XOR:	DC.W	$010C,$0011
	DC.W	$0104,$0000
Ver9:	DC.W	$008E,(INIPANT*$100)+$80,$0090,(((INIPANT+192)&$FF)*$100)+$C0
COLOR9:	DC.W	$180,0,$182,0,$184,0,$186,0
PLANO9:	DS.W	2*4

PANPOS:	SET	INIPANT
NBIT9:	DC.W	(PANPOS*$100)+$01,$FFFE,$0100,$9200
ModSC9:
	REPT	27
	DC.W	(PANPOS*$100)+$21,$FFFE
	DC.W	$0108,(080*26)-MOD,$010A,(-80)-MOD
PANPOS:	SET	PANPOS+7
	IFNE	PANPOS>$FF
	DC.W	$FFDF,$FFFE
PANPOS:	SET	(PANPOS&$FF)
	ENDC
	DC.W	(PANPOS*$100)+$21,$FFFE
	DC.W	$0108,(-80*27*7)-MOD,$010A,(0)-MOD
PANPOS:	SET	PANPOS+1
	IFNE	PANPOS>$FF
	DC.W	$FFDF,$FFFE
PANPOS:	SET	(PANPOS&$FF)
	ENDC
	ENDR
Int_VD9:DC.W	$009C,$8010		; Emulaci�n del VDP
	DC.L	$FFFFFFFE

; ------------------------------------------------ ;

	CNOP	0,8
COPPER4:
C4AGA:	DC.W	$0108,(32*3)-MOD,$010A,(32*3)-MOD

COLOR4:	DC.W	$0180,0

PLANO4:	DS.W	4*4

PANPOS:	SET	INIPANT-16

	DC.W	((PANPOS-1)*$100)+$D1,$FFFE,$0100,$4200


ZALTO4:	DC.W	$0084,0,$0086,0		; Salto a CopperLine0/CopperLine1
	DC.W	$008A,0


;;	DC.W	((IniPant+24)*$100)+$D9,$FFFE
Int_H4:	DC.W	$009C,$0000					; $0C


	DC.W	$FED9,$FFFE
Plano4b:DS.W	4*4


	DC.W	$FFD9,$FFFE
Int_VD4:DC.W	$009C,$8010		; Emulaci�n del VDP
	DC.L	$FFFFFFFE


SALTO4:	DC.W	$0080,0,$0082,0
	DC.W	$0088,0
	DC.L	$FFFFFFFE
; ------------------------------------------------ ;

COLSPR:	MACRO
	DC.W	((PANPOS-1)*$100)+$DF,$FFFE			; $00
	DC.W	$01A0,$0000,$01A0,$0000,$01A0,$0000,$01A0,$0000	; $04
	DC.W	$01A0,$0000,$01A0,$0000,$01A0,$0000,$01A0,$0000	; $14
	DC.W	$01A0,$0000,$01A0,$0000,$01A0,$0000,$01A0,$0000	; $24
	DC.W	$01A0,$0000,$01A0,$0000,$01A0,$0000,$01A0,$0000	; $34
PANPOS:	SET	(PANPOS+1)&$FF					; $44
	ENDM


	CNOP	0,8
COPPER2:
	DC.W	$0102,$8800
	DC.W	$0104,$003F
Ver2:	DC.W	$008E,(INIPANT*$100)+$A1,$0090,(((INIPANT+192)&$FF)*$100)+$A1
C2AGA:	DC.W	$0108,(32*3)-MOD,$010A,(32*3)-MOD
COLOR2:	DC.W	$0180,0
PLANO2:	DS.W	4*4

PANPOS:	SET	INIPANT-16

	DC.W	((PANPOS-1)*$100)+$D1,$FFFE,$0100,$4200
ICOPSPR2:
COPSPR2=ICOPSPR2+4+SPRADD
	REPT	(26*8)
	COLSPR
	ENDR
Int_VD2:DC.W	$009C,$8010		; Emulaci�n del VDP
	DC.L	$FFFFFFFE

	DS.B	32*SPRADD	; Seguridad para colores sprites.
	DS.B	1024		; Seguridad.


; Doble copper:

	CNOP	0,8
COPPER2B:
	DC.W	$0102,$8800
	DC.W	$0104,$003F
Ver2B:	DC.W	$008E,(INIPANT*$100)+$A1,$0090,(((INIPANT+192)&$FF)*$100)+$A1
C2BAGA:	DC.W	$0108,(32*3)-MOD,$010A,(32*3)-MOD
COLOR2B:DC.W	$0180,0
PLANO2B:DS.W	4*4

PANPOS:	SET	INIPANT-16

	DC.W	((PANPOS-1)*$100)+$D1,$FFFE,$0100,$4200
ICOPSPR2B:
COPSPR2B=ICOPSPR2B+4+SPRADD
	REPT	(26*8)
	COLSPR
	ENDR
Int_VD2B:DC.W	$009C,$8010		; Emulaci�n del VDP
	DC.L	$FFFFFFFE

	DS.B	32*SPRADD	; Seguridad para colores sprites.
	DS.B	1024		; Seguridad.

; -------------------------------------------------

COLSPR2:MACRO
	DC.W	((PANPOS-1)*$100)+$D1,$FFFE			; $00
	DC.W	$01A0,$0000,$01A0,$0000,$01A0,$0000		; $04
	DC.W	$01A0,$0000,$01A0,$0000,$01A0,$0000		; $10
	DC.W	$01A0,$0000,$01A0,$0000,$01A0,$0000		; $1C
	DC.W	$01A0,$0000,$01A0,$0000,$01A0,$0000		; $28
	DC.W	$01A2,$0000,$01A4,$0000,$01AA,$0000,$01AC,$0000	; $34
	DC.W	$01B2,$0000,$01B4,$0000,$01BA,$0000,$01BC,$0000	; $44
	DC.W	$0108,-MOD,$010A,-MOD				; $54
;;;	DC.W	$009C,$0000					; $5C
PANPOS:	SET	(PANPOS+1)&$FF					; $60
	ENDM


PANPOS:	SET	INIPANT

	CNOP	0,8
COPPER5:
C5AGA:	DC.W	$0108,-MOD,$010A,-MOD

NPLA5:	DC.W	((PANPOS-17)*$100)+$D1,$FFFE,$0100,$4000

	DC.W	((PANPOS-1)*$100)+$61,$FFFE
Plano5:	DS.W	4*4


ZALTO5:	DC.W	$0084,0,$0086,0		; Salto a CopperLine0/CopperLine1
	DC.W	$008A,0


Salto5:	DC.W	$0080,0,$0082,0

TabCop5Add=$10

TabCop5:
	REPT	212+1
	DC.W	((PANPOS-1)*$100)+$D9,$FFFE			; $00
	DC.W	$0108,(-8),$010A,(-8)				; $04
	DC.W	$009C,$0000					; $0C
PANPOS:	SET	(PANPOS+1)&$FF					; $10
	ENDR

Int_VD5:DC.W	$009C,$8010					; $5C

	DC.W	$01A0,0,$01A0,0
	DC.W	$01A0,0

	DC.L	$FFFFFFFE

	DS.B	$10*56



;	DC.W	$01A0,0
;COOR5:	DC.W	$5051,$FFFE
;	DC.W	$0108,(-32*256),$010A,(-32*256)
;COOR5B:	DC.W	$5151,$FFFE,$0108,0,$010A,0
;
;
;	DC.L	$FFFFFFFE
;
;
;ICOPSPR5:
;COPSPR5=ICOPSPR5+4+SPR2ADD
;	REPT	(212+16)
;	COLSPR2
;	ENDR
;
;	DC.L	$FFFFFFFE
;
;	DS.B	44*SPR2ADD	; Seguridad para colores sprites.
;	DS.B	1024		; Seguridad.
;
;
;PANPOS:	SET	INIPANT-16
;
;	CNOP	0,8
;COPPER5B:
;	DC.W	$0092,$0048,$0094,$00C0,$0102,$0000
;	DC.W	$0104,$003F
;C5AGAB:
;	DC.W	$0108,0,$010A,0
;	DC.W	((PANPOS-2)*$100)+$21,$FFFE
;PLANO5B:DS.W	4*4
;	DC.W	((PANPOS-1)*$100)+$D1,$FFFE,$0100,$4000
;ICOPSPR5B:
;COPSPR5B=ICOPSPR5B+4+SPR2ADD
;	REPT	(212+16)
;	COLSPR2
;	ENDR
;
;	DC.L	$FFFFFFFE
;
;	DS.B	44*SPR2ADD	; Seguridad para colores sprites.
;	DS.B	1024		; Seguridad.
;
;ICOP5BUB=ICOPSPR5B-ICOPSPR5
;
;	DC.W	$8051,$FFFE
;	DC.W	$009C,$8010
;

; ------------------

PANPOS:	SET	INIPANT-16

	CNOP	0,8

COPPER7:
	DC.W	$01A0,0,$01A0,0

C7AGA:	DC.W	$0108,-MOD,$010A,-MOD

NPLA7:	DC.W	((PANPOS-17)*$100)+$D1,$FFFE,$0100,$C000

	DC.W	((PANPOS-1)*$100)+$61,$FFFE
PLANO7:	DS.W	4*4


ZALTO7:	DC.W	$0084,0,$0086,0		; Salto a CopperLine0/CopperLine1
	DC.W	$008A,0

SALTO7:	DC.W	$0080,0,$0082,0
	DC.W	$0088,0



	DC.W	$01A0,0
COOR7:	DC.W	$5051,$FFFE
	DC.W	$0108,(-64*256),$010A,(-64*256)
COOR7B:	DC.W	$5151,$FFFE,$0108,0,$010A,0

	DC.L	$FFFFFFFE

; ------------------

PANPOS:	SET	INIPANT-16

	CNOP	0,8
COPPER6:
	DC.W	$01A0,0,$01A0,0

C6AGA:	DC.W	$0108,-MOD,$010A,-MOD

NPLA6:	DC.W	((PANPOS-17)*$100)+$D1,$FFFE,$0100,$A000

	DC.W	((PANPOS-1)*$100)+$61,$FFFE
PLANO6:	DS.W	2*4


ZALTO6:	DC.W	$0084,0,$0086,0		; Salto a CopperLine0/CopperLine1
	DC.W	$008A,0


SALTO6:	DC.W	$0080,0,$0082,0
	DC.W	$0088,0

	DC.W	$01A0,0
COOR6:	DC.W	$5051,$FFFE
	DC.W	$0108,(-64*256),$010A,(-64*256)
COOR6B:	DC.W	$5151,$FFFE,$0108,0,$010A,0
	DC.L	$FFFFFFFE

; ------------------------------------------------ ;

PANPOS:	SET	INIPANT-16

	CNOP	0,8
COPPER8:
C8XOR:	DC.W	$010C,$0022


	dc.l	$01060c40
Scr8Pal:
	dc.l	$01800000,$01820004,$01840009,$0186000e
	dc.l	$01880200,$018a0204,$018c0209,$018e020e
	dc.l	$01900400,$01920404,$01940409,$0196040e
	dc.l	$01980600,$019a0604,$019c0609,$019e060e
	dc.l	$01a00800,$01a20804,$01a40809,$01a6080e
	dc.l	$01a80a00,$01aa0a04,$01ac0a09,$01ae0a0e
	dc.l	$01b00c00,$01b20c04,$01b40c09,$01b60c0e
	dc.l	$01b80e00,$01ba0e04,$01bc0e09,$01be0e0e
	dc.l	$01062c40
	dc.l	$01800020,$01820024,$01840029,$0186002e
	dc.l	$01880220,$018a0224,$018c0229,$018e022e
	dc.l	$01900420,$01920424,$01940429,$0196042e
	dc.l	$01980620,$019a0624,$019c0629,$019e062e
	dc.l	$01a00820,$01a20824,$01a40829,$01a6082e
	dc.l	$01a80a20,$01aa0a24,$01ac0a29,$01ae0a2e
	dc.l	$01b00c20,$01b20c24,$01b40c29,$01b60c2e
	dc.l	$01b80e20,$01ba0e24,$01bc0e29,$01be0e2e
	dc.l	$01064c40
	dc.l	$01800040,$01820044,$01840049,$0186004e
	dc.l	$01880240,$018a0244,$018c0249,$018e024e
	dc.l	$01900440,$01920444,$01940449,$0196044e
	dc.l	$01980640,$019a0644,$019c0649,$019e064e
	dc.l	$01a00840,$01a20844,$01a40849,$01a6084e
	dc.l	$01a80a40,$01aa0a44,$01ac0a49,$01ae0a4e
	dc.l	$01b00c40,$01b20c44,$01b40c49,$01b60c4e
	dc.l	$01b80e40,$01ba0e44,$01bc0e49,$01be0e4e
	dc.l	$01066c40
	dc.l	$01800060,$01820064,$01840069,$0186006e
	dc.l	$01880260,$018a0264,$018c0269,$018e026e
	dc.l	$01900460,$01920464,$01940469,$0196046e
	dc.l	$01980660,$019a0664,$019c0669,$019e066e
	dc.l	$01a00860,$01a20864,$01a40869,$01a6086e
	dc.l	$01a80a60,$01aa0a64,$01ac0a69,$01ae0a6e
	dc.l	$01b00c60,$01b20c64,$01b40c69,$01b60c6e
	dc.l	$01b80e60,$01ba0e64,$01bc0e69,$01be0e6e
	dc.l	$01068c40
	dc.l	$01800080,$01820084,$01840089,$0186008e
	dc.l	$01880280,$018a0284,$018c0289,$018e028e
	dc.l	$01900480,$01920484,$01940489,$0196048e
	dc.l	$01980680,$019a0684,$019c0689,$019e068e
	dc.l	$01a00880,$01a20884,$01a40889,$01a6088e
	dc.l	$01a80a80,$01aa0a84,$01ac0a89,$01ae0a8e
	dc.l	$01b00c80,$01b20c84,$01b40c89,$01b60c8e
	dc.l	$01b80e80,$01ba0e84,$01bc0e89,$01be0e8e
	dc.l	$0106ac40
	dc.l	$018000a0,$018200a4,$018400a9,$018600ae
	dc.l	$018802a0,$018a02a4,$018c02a9,$018e02ae
	dc.l	$019004a0,$019204a4,$019404a9,$019604ae
	dc.l	$019806a0,$019a06a4,$019c06a9,$019e06ae
	dc.l	$01a008a0,$01a208a4,$01a408a9,$01a608ae
	dc.l	$01a80aa0,$01aa0aa4,$01ac0aa9,$01ae0aae
	dc.l	$01b00ca0,$01b20ca4,$01b40ca9,$01b60cae
	dc.l	$01b80ea0,$01ba0ea4,$01bc0ea9,$01be0eae
	dc.l	$0106cc40
	dc.l	$018000c0,$018200c4,$018400c9,$018600ce
	dc.l	$018802c0,$018a02c4,$018c02c9,$018e02ce
	dc.l	$019004c0,$019204c4,$019404c9,$019604ce
	dc.l	$019806c0,$019a06c4,$019c06c9,$019e06ce
	dc.l	$01a008c0,$01a208c4,$01a408c9,$01a608ce
	dc.l	$01a80ac0,$01aa0ac4,$01ac0ac9,$01ae0ace
	dc.l	$01b00cc0,$01b20cc4,$01b40cc9,$01b60cce
	dc.l	$01b80ec0,$01ba0ec4,$01bc0ec9,$01be0ece
	dc.l	$0106ec40
	dc.l	$018000e0,$018200e4,$018400e9,$018600ee
	dc.l	$018802e0,$018a02e4,$018c02e9,$018e02ee
	dc.l	$019004e0,$019204e4,$019404e9,$019604ee
	dc.l	$019806e0,$019a06e4,$019c06e9,$019e06ee
	dc.l	$01a008e0,$01a208e4,$01a408e9,$01a608ee
	dc.l	$01a80ae0,$01aa0ae4,$01ac0ae9,$01ae0aee
	dc.l	$01b00ce0,$01b20ce4,$01b40ce9,$01b60cee
	dc.l	$01b80ee0,$01ba0ee4,$01bc0ee9,$01be0eee
	dc.l	$01060c40

C8AGA:	DC.W	$0108,-8,$010A,-8

NPLA8:	DC.W	((PANPOS-17)*$100)+$D1,$FFFE,$0100,$0010

	DC.W	((PANPOS-1)*$100)+$21,$FFFE
PLANO8:	DS.W	8*4


ZALTO8:	DC.W	$0084,0,$0086,0		; Salto a CopperLine0/CopperLine1
	DC.W	$008A,0


SALTO8:	DC.W	$0080,0,$0082,0
	DC.W	$0088,0

; ------------------------------------------------ ;

PANPOS:	SET	INIPANT-16

	CNOP	0,8
COPPER8E:
	dc.l	$01800000,$0182000f,$01840500,$0186050f
	dc.l	$01880a00,$018a0a0f,$018c0f00,$018e0f0f
	dc.l	$01900050,$0192005f,$01940550,$0196055f
	dc.l	$01980a50,$019a0a5f,$019c0f50,$019e0f5f
	dc.l	$01a000a0,$01a200af,$01a405a0,$01a605af
	dc.l	$01a80aa0,$01aa0aaf,$01ac0fa0,$01ae0faf
	dc.l	$01b000f0,$01b200ff,$01b405f0,$01b605ff
	dc.l	$01b80af0,$01ba0aff,$01bc0ff0,$01be0fff

	DC.W	$0108,0,$010A,0

	DC.W	((PANPOS-17)*$100)+$D1,$FFFE,$0100,$5000

	DC.W	((PANPOS-1)*$100)+$21,$FFFE
PLANO8E:DS.W	5*4

	DC.W	$01A0,0
COOR8E:	DC.W	$5051,$FFFE
	DC.W	$0108,(-32*256),$010A,(-32*256)
COOR8BE:DC.W	$5151,$FFFE,$0108,0,$010A,0

Int_VD8:DC.W	$009C,$8010					; $5C

	DC.L	$FFFFFFFE

SALTO8E:DC.W	$0080,0,$0082,0
	DC.W	$0088,0



; ================================================================

;		DC.W	$3AB1,$FFFE
;CopperLineJmp:	DC.W	$0084,0,$0086,0		; Salto a CopperLine0/CopperLine1
;		DC.W	$008A,0

; -----------------------------=> Los DOS CopperLine en ChipMem.
	CNOP	0,8
CopperLine0:	DCB.L	(CoppLineSize/4)*215,$009C0000

	DC.W	$FC01,$FFFE		; \
Int_CL0:DC.W	$009C,$8010		;  - Actualiza VDP

	DC.L	$FFFFFFFE
; ------------------------
	CNOP	0,8
CopperLine1:	DCB.L	(CoppLineSize/4)*215,$009C0000

	DC.W	$FC01,$FFFE		; \
Int_CL1:DC.W	$009C,$8010		;  - Actualiza VDP
CopperRet:
	DC.L	$FFFFFFFE
; ----------------------------<=

; =----------------------------------------=> Copper Optiones de Linea.
	CNOP	0,8
CopperOpts0:	DS.W	1024*8
CopperOpts1:	DS.W	1024*8
; =----------------------------------------<=

; ================================================================


	CNOP	0,8
	DS.L	8		; Seguridad.


; -=--------------------------------------------------=-

; ------------------------------------------------ ;


; --------------------------------
	SECTION	Sprites,BSS_C
; --------------------------------

	CNOP	0,8
	DS.L	8
	CNOP	0,8
SPRIT0:
	DS.L	4
	DS.B	8*256*2
	DS.L	4
SPRIT1:
	DS.L	4
	DS.B	8*256*2
	DS.L	4
SPRIT2:
	DS.L	4
	DS.B	8*256*2
	DS.L	4
SPRIT3:
	DS.L	4
	DS.B	8*256*2
	DS.L	4
SPRIT4:
	DS.L	4
	DS.B	8*256*2
	DS.L	4
SPRIT5:
	DS.L	4
	DS.B	8*256*2
	DS.L	4
SPRIT6:
	DS.L	4
	DS.B	8*256*2
	DS.L	4
SPRIT7:
	DS.L	4
	DS.B	8*256*2
	DS.L	4

	DS.B	(8*260*2)*2

	CNOP	0,8
SPRIT0b:
	DS.L	4
	DS.B	8*256*2
	DS.L	4
SPRIT1b:
	DS.L	4
	DS.B	8*256*2
	DS.L	4
SPRIT2b:
	DS.L	4
	DS.B	8*256*2
	DS.L	4
SPRIT3b:
	DS.L	4
	DS.B	8*256*2
	DS.L	4
SPRIT4b:
	DS.L	4
	DS.B	8*256*2
	DS.L	4
SPRIT5b:
	DS.L	4
	DS.B	8*256*2
	DS.L	4
SPRIT6b:
	DS.L	4
	DS.B	8*256*2
	DS.L	4
SPRIT7b:
	DS.L	4
	DS.B	8*256*2
	DS.L	4

	DS.B	(8*260*2)*2

	DS.L	1024

NEXSPR=SPRIT1-SPRIT0
OTRSPR=SPRIT2-SPRIT0
RESSPR=(SPRIT2-SPRIT0)-6
BLOSPR=SPRIT0b-SPRIT0

; ------------------------------------------------ ;


; ------------------------------------------------ ;


; --------------------------------
	SECTION	SLOTS,BSS
; --------------------------------

	CNOP	0,8
	DS.B	$100
DirROM:	DS.B	4*($4100)
DirDOS:	DS.B	4*($4000)+$100
NOMEM:	DS.B	(16*1024)
	DS.B	$100
ESROM=NOMEM+1

ROM10=DirROM
ROM11=DirROM+(1*$4100)

ROM20=DirROM
ROM21=DirROM+(1*$4100)
ROM22=DirROM+(2*$4100)

ROM30=DirROM
ROM31=DirROM+(1*$4100)
ROM32=DirROM+(2*$4100)
ROM33=DirROM+(3*$4100)

Disk1=DirDOS
Disk2=DirDOS

CheckSumBuc=(NOMEM-ROM10)


	IFEQ	FM_Pak_ROM
; --------------------------------
	SECTION	FM Pak,DATA
; --------------------------------

FMPak0:	INCBIN	"MSX_Amiga/FMPak.0"
	DS.B	$100
FMPak1:	INCBIN	"MSX_Amiga/FMPak.1"
	DS.B	$100
FMPak2:	INCBIN	"MSX_Amiga/FMPak.2"
	DS.B	$100
FMPak3:	INCBIN	"MSX_Amiga/FMPak.3"
	DS.B	$100
	ENDC


; --------------------------------
	SECTION	RAM,BSS
; --------------------------------
	CNOP	0,8
	DS.B	$100
RAM00:	DS.B	(16*1024)
	DS.B	$100
RAM01:	DS.B	(16*1024)
	DS.B	$100
RAM02:	DS.B	(16*1024)
	DS.B	$100
RAM03:	DS.B	(16*1024)
	DS.B	$100
RAM10:	DS.B	(16*1024)
	DS.B	$100
RAM11:	DS.B	(16*1024)
	DS.B	$100
RAM12:	DS.B	(16*1024)
	DS.B	$100
RAM13:	DS.B	(16*1024)
	DS.B	$100


; --------------------------------
	SECTION	VRAM,BSS
; --------------------------------
	CNOP	0,8
DIRVRAM:DS.B	(1024*128)
	DS.B	$20

	CNOP	0,8
NORAM:	DS.B	(16*1024)-$1700
	CNOP	0,8
SCCKO:	DS.B	(16*1024)
	DS.B	$20


; --------------------------------
	SECTION	GFX,BSS_C
; --------------------------------
	DS.L	10
	CNOP	0,8
TMASK:	DS.B	(1024*64)
MASK:	DS.B	(1024*64)
SCR0:	DS.B	(1024*128)
	DS.L	10
	CNOP	0,8
SCREEN:	DS.B	(32*32*8*4)
	DS.B	12*8
; -------------------------
	CNOP	0,8
BLTBUF:	DS.W	36
; -------------------------
	DS.B	12*8
NOSPRIT:
	DS.B	(5*1024*2)
	DS.B	12*8
NOSPRIT8:
	DS.B	(5*1024*4)
	DS.B	2*1024
NOSPRIT2:
	DS.B	(5*1024*2)
	DS.B	12*8
NOSPRIT28:
	DS.B	(5*1024*4)
	DS.B	2*1024
; --------------------------
GFXCA:	DS.B	64*1024
	DS.L	10
; --------------------------

; --------------------------------
	SECTION	TAB7E,BSS
; --------------------------------
	CNOP	0,8
TABLA7E:	DS.B	256*1024

; ***************************************************

; --------------------------------
	SECTION	SPLIT,BSS_C
; --------------------------------
	CNOP	0,8
SCREENB:	DS.B	(212*32*4)	; Lines below a SCREEN 4 table split.
SCREENT:	DS.B	(212*32*4)	; Lines above a SCREEN 5 / 4 mode split.
	DS.B	12*8

; --------------------------------
	SECTION	BANDS,BSS
; --------------------------------
BandBuf:	DS.B	640*BANDMAX	; Sprite mode 2 band snapshots.

	IFD	PERF
; --------------------------------
	SECTION	PROFILE,BSS
; --------------------------------
PerfPCBuf:	DS.L	16384		; Interrupted PCs (PERF profile).
PerfPCEnd:
	ENDC

; --------------------------------
	SECTION	CACHE2,BSS_C
; --------------------------------
	CNOP	0,8
GFXCA2:	DS.B	64*1024		; Character cache bank 2 (RendTabCheck).
	DS.L	10

; --------------------------------
	SECTION	SCREEN2B,BSS_C
; --------------------------------
	CNOP	0,8
SCREEN2B:	DS.B	(32*32*8*4)	; SCREEN 2 screen of cache bank 2.
	DS.B	12*8

; --------------------------------
	SECTION	SPRCOL,BSS
; --------------------------------
	CNOP	0,4
; Sprite collision tables (SCCalc).
SCSave:		DS.L	15
SCDbl:		DS.W	256		; Byte with every bit doubled.
SCN:		DS.W	1		; Sprites collected.
SCHi:		DS.W	1
SCCutOK:	DS.B	1		; SCCut built this check.
		EVEN
SCCutSv:	DS.L	3
SCM:		DS.W	1		; Sprites that can collide.
SCRk:		DS.B	1		; Later sprite of the pair (SCSpr number).
		EVEN
SCSpr:		DS.B	32*16		; Top.W, X.W, pattern.L, colours.L
SCList:		DS.B	32*32		; Can collide, by top: top.W, bottom.W,
					; X.W, SCSpr number.W, pattern.L, colours.L,
					; columns from.W, to.W (one past; EC included)
SCCnt:		DS.B	256		; Sprites on each line so far,
SCCut:		DS.B	256		; first one not shown there ($FF: none).
