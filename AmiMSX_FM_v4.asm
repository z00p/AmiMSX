;	 ------------------------------------------------
;	- FMX: MSX-Music (YM2413) by wavetables, v4.0 -
;	 ------------------------------------------------
;
; Each instrument is 8 one-cycle tables (256 signed bytes, one per modulator
; level), made with the chip's log-sine/exp method; envelopes run once a
; frame; the 9 voices are mixed into words and written as bytes to Paula
; channel 3. The PSG keeps channels 0-2 (its noise channel is given up).
; The spec, step for step, is tools/fm_synth.py (class Synth); the tables
; are Sound/fmx.dat (built-in instrument data from emu2413, MIT licence,
; Mitsutaka Okazaki). The custom instrument (registers 00h-07h) is built
; here (FMXBuild) when a game changes it.
;
; Paula output is locked to the frame (313 lines x 227 colour clocks PAL):
; N = 227 samples a frame at period 313, or 313 at period 227 (FMXFast);
; a 60 Hz (NTSC) display has 262 lines and N follows (FMXSetN). The
; DMA loops over a 2N-byte buffer; FMXFrame (from Emula1Frame, just after the
; wait for the Amiga frame) fills the half that plays in the next frame.
;
; Called with all registers saved (FMXSave), so it is free to use them; no
; stack beyond BSR return addresses.

	INCLUDE	"Sound/fmx.i"

CH_CST=0		; carrier state (ST_*)
CH_MST=1		; modulator state
CH_MKEY=2		; modulator runs (key held)
CH_PKEY=3		; key bit last frame
CH_CEG=4		; carrier envelope, 0.375 dB units x 256 (0 = loudest)
CH_MEG=6		; modulator envelope
CH_CPOS=8		; carrier attack curve position
CH_MPOS=10		; modulator attack curve position
CH_FRAC=12		; phase: fraction (16 bits)
CH_IDX=14		; phase: table index (0-255, high byte 0)
CH_GI=16		; gain index last frame (0-63, 63 = silent)
CH_TAB=18		; table last frame (0 = none yet)
CH_SIZE=24

ST_ATT=0
ST_DEC=1
ST_SUS=2
ST_REL=3
ST_OFF=4

FMX_CLIPC=1152		; centre of the 8-bit output table
FMXRBSZ=320		; one ring block (up to 318 samples)
FMXBUFSZ=4*FMXRBSZ	; DMA ring: 4 blocks (FMXAud)

; -------------------------------------> Reset (emulation start).
	CNOP	0,8
FMXInit:
	MOVEM.L	D0-D7/A0-A6,FMXSave
	LEA	FMXDat,A5
	MOVE.W	#227,FMXN		; Paula mode: 227 samples/frame at
	MOVE.W	#313,FMXPer		; period 313, or 313 at period 227.
	MOVE.L	#FMX_K227,FMXK
	MOVE.L	$4.W,A0			; 68040/68060 (also PiStorm, BigMig):
	MOVE.W	$128(A0),D0		; 15.6 kHz.
	AND.W	#$88,D0
	SNE	FMXFast
	TST.B	FMXFast
	BEQ.S	FMXIn227
	MOVE.W	#313,FMXN
	MOVE.W	#227,FMXPer
	MOVE.L	#FMX_K313,FMXK
FMXIn227:
	TST.B	FMXVolOK		; Volume tables: VOLTAB[g][u] =
	BNE.S	FMXInVok		; (signed u * GAIN[g]) >> 4, once.
	LEA	FMXVol,A0
	LEA	FMX_GAIN(A5),A1
	MOVEQ	#64-1,D7
FMXInVg:
	MOVE.W	(A1)+,D1
	MOVEQ	#0,D0
FMXInVu:
	MOVE.B	D0,D2
	EXT.W	D2
	MULS.W	D1,D2
	ASR.L	#4,D2
	MOVE.W	D2,(A0)+
	ADDQ.W	#1,D0
	CMP.W	#256,D0
	BNE.S	FMXInVu
	DBF	D7,FMXInVg
	ST	FMXVolOK
FMXInVok:
	LEA	FMXCh,A0		; Channels: off, silent.
	MOVEQ	#9-1,D7
FMXInCh:
	MOVE.B	#ST_OFF,CH_CST(A0)
	MOVE.B	#ST_OFF,CH_MST(A0)
	CLR.W	CH_MKEY(A0)
	MOVE.W	#$7F00,CH_CEG(A0)
	MOVE.W	#$7F00,CH_MEG(A0)
	CLR.L	CH_CPOS(A0)
	CLR.L	CH_FRAC(A0)
	MOVE.W	#63,CH_GI(A0)
	CLR.L	CH_TAB(A0)
	LEA	CH_SIZE(A0),A0
	DBF	D7,FMXInCh
	LEA	FMXKeyEv,A0
	CLR.L	(A0)+
	CLR.L	(A0)+
	CLR.B	(A0)
	ST	FMXPDirty
	SF	FMXSync
	MOVE.W	#-1,FMXBeam		; (no R#9 50/60 Hz seen yet: the first one
					; resyncs; 0 is NTSC, which the BIOS sets)
	IFD	FMXREC
	TST.L	FMXRecWP		; (check build: first start only)
	BNE.S	FMXInRc
	MOVE.L	#FMXRecW,FMXRecWP
	MOVE.L	#FMXRecO,FMXRecOP
FMXInRc:
	ENDC
	BSR	FMXSetQ
	LEA	FMXBuf,A0		; Silence in the DMA buffer.
	MOVE.W	#(FMXBUFSZ/4)-1,D0
FMXInB:	CLR.L	(A0)+
	DBF	D0,FMXInB
	MOVEM.L	FMXSave,D0-D7/A0-A6
	RTS

; -------------------------------------> Quarter lengths: N*(q+1)/4 - N*q/4.
; Uses D1-D4, A0.
FMXSetQ:
	LEA	FMXQsz,A0
	MOVEQ	#0,D2
	MOVEQ	#1,D3
FMXInQ:	MOVE.W	FMXN,D1
	MULU.W	D3,D1
	LSR.L	#2,D1
	MOVE.W	D1,D4
	SUB.W	D2,D4
	MOVE.W	D4,(A0)+
	MOVE.W	D1,D2
	ADDQ.W	#1,D3
	CMP.W	#5,D3
	BNE.S	FMXInQ
	RTS

; -------------------------------------> N from the frame length (at a resync).
; The display runs PAL (313 lines) or, 'From VDP' with a 60 Hz game, NTSC
; (262; BEAMCON0 PAL bit clear). N samples must last one frame, or the half
; written each frame drifts into the half playing (a click every few frames:
; Lilly's Saga at 60 Hz on BigMig). Period 227 is one sample a line, so N =
; lines; at period 313, 227 (PAL) or 190 (NTSC, 4 colour clocks a frame
; short: it drifts a sample in 78 frames, minutes before it is heard; the
; A1200/030 presets keep PSG at 50 Hz). Measured: the highest line between
; two wraps of the beam (up to two frames, at a resync only). Ends a few
; lines into a frame. Uses D0-D4, A0.
FMXSetN:
	BSR.S	FMXVLin
FMXSN1:	MOVE.W	D0,D1			; To the next wrap...
	BSR.S	FMXVLin
	CMP.W	D1,D0
	BCC.S	FMXSN1
	MOVEQ	#0,D2
FMXSN2:	CMP.W	D2,D0			; ...then the highest line to the one
	BLS.S	FMXSN3			; after.
	MOVE.W	D0,D2
FMXSN3:	MOVE.W	D0,D1
	BSR.S	FMXVLin
	CMP.W	D1,D0
	BCC.S	FMXSN2
FMXSN4:	BSR.S	FMXVLin			; (past line 4: the VBlank counted)
	CMP.W	#4,D0
	BCS.S	FMXSN4
	MOVE.W	#313,D0			; PAL or NTSC.
	CMP.W	#287,D2
	BHI.S	FMXSN5
	MOVE.W	#262,D0
FMXSN5:	MOVE.W	D0,FMXLines
	TST.B	FMXFast
	BNE.S	FMXSN6
	MULU.W	#227,D0			; Period 313: lines * 227 / 313.
	ADD.L	#156,D0
	DIVU.W	#313,D0
FMXSN6:	AND.W	#$FFFE,D0		; (even: Paula counts words)
	MOVE.W	D0,FMXNnom
	MOVE.W	D0,FMXN
	BRA	FMXSetQ
FMXVLin:
	MOVE.L	$DFF004,D0		; Beam line (V8-V0).
	LSR.L	#8,D0
	AND.W	#$1FF,D0
	RTS

; -------------------------------------> AUD3 interrupt (level 4): Paula has
; just taken the block queued last time (its pointer and length) and plays
; it now; queue the one after it, or the same again if the emulation has
; not written it yet (late: a block repeats instead of a jump). The writer
; (FMXFrame) only moves FMXWrite, this only FMXPlay/FMXQueued.
	CNOP	0,4
FMXAud:
	MOVEM.L	D0/A0,-(SP)
	BTST	#2,$DFF01F-1		; INTREQR bit 10 (AUD3)?
	BEQ.S	FMXAuX
	MOVE.W	#$0400,$DFF09C
	MOVE.W	FMXQueued,D0
	MOVE.W	D0,FMXPlay
	ADDQ.W	#1,D0
	AND.W	#3,D0
	CMP.W	FMXWrite,D0
	BNE.S	FMXAuQ
	MOVE.W	FMXPlay,D0		; Underrun: the same block again.
	ADDQ.W	#1,FMXUnder
FMXAuQ:	MOVE.W	D0,FMXQueued
	MOVE.W	(FMXLen,D0.W*2),-(SP)
	MULU	#FMXRBSZ,D0
	LEA	(FMXBuf,D0.L),A0
	MOVE.L	A0,$DFF0D0
	MOVE.W	(SP)+,D0
	LSR.W	#1,D0
	MOVE.W	D0,$DFF0D4
FMXAuX:	MOVEM.L	(SP)+,D0/A0
	NOP
	RTE

; -------------------------------------> Once a frame.
	CNOP	0,8
FMXFrame:
	MOVEM.L	D0-D7/A0-A6,FMXSave
	LEA	FMXDat,A5
	LEA	Tabla7C,A3

	TST.B	FMXSync			; First frame: (re)start channel 3.
	BEQ.S	FMXFrRs
	BTST	#2,$DFF01C		; (AUD3 interrupt off since: back from
	BNE	FMXFrSy			; the menu or Workbench mode: restart)
FMXFrRs:
	BSR	FMXSetN			; (nominal N for this frame length)
	MOVE.W	#$0008,$DFF096
	MOVE.W	#$0400,$DFF09A		; AUD3 interrupt off while setting up.
	LEA	FMXBuf,A0		; Silence in the whole ring.
	MOVE.W	#(FMXBUFSZ/4)-1,D0
FMXFrC0:CLR.L	(A0)+
	DBF	D0,FMXFrC0
	CLR.W	FMXPlay			; Block 0 plays (silence), nothing
	CLR.W	FMXQueued		; queued after it; this frame's mix
	MOVE.W	#1,FMXWrite		; goes to block 1.
	MOVE.W	FMXNnom,D0
	MOVE.W	D0,FMXLen
	MOVE.L	VBRPun,A0		; Level 4 (audio) vector: FMXAud.
	MOVE.L	#FMXAud,$70(A0)
	MOVE.L	#FMXBuf,$DFF0D0
	LSR.W	#1,D0
	MOVE.W	D0,$DFF0D4		; (words)
	MOVE.W	FMXPer,$DFF0D6
	MOVE.W	#64,$DFF0D8
	MOVE.W	#$0400,$DFF09C
	MOVE.W	#$8008,$DFF096		; Paula takes block 0 and asks (AUD3)
	MOVE.W	#$8400,$DFF09A		; for the next at once.
	MOVE.W	FMXVbl,FMXVbl0
	ST	FMXSync
	IFD	FMXREC
	TST.B	FMXRecIn		; (check build) registers at the start
	BNE.S	FMXFrSy
	ST	FMXRecIn
	LEA	Tabla7C,A0
	LEA	FMXRecInit,A1
	MOVEQ	#64/4-1,D0
FMXRcI:	MOVE.L	(A0)+,(A1)+
	DBF	D0,FMXRcI
	ENDC
FMXFrSy:
	MOVE.W	FMXWrite,D0		; This frame's N from the ring's fill:
	SUB.W	FMXQueued,D0		; blocks written and not yet handed to
	SUBQ.W	#1,D0			; Paula. None: 2 samples more, two or
	AND.W	#3,D0			; more: 2 fewer. The emulation's frame
	MOVE.W	FMXNnom,D1		; rate and Paula's clock then agree on
	TST.W	D0			; average, whatever the display (50 Hz,
	BNE.S	FMXFrN1			; 60 Hz with 227/228-clock lines, late
	ADDQ.W	#2,D1			; frames). Pitch is the step per sample:
	BRA.S	FMXFrN3			; unchanged.
FMXFrN1:CMP.W	#2,D0
	BCS.S	FMXFrN3
	SUBQ.W	#2,D1
FMXFrN3:CMP.W	FMXN,D1
	BEQ.S	FMXFrN4
	MOVE.W	D1,FMXN
	BSR	FMXSetQ
FMXFrN4:
	TST.B	FMXPDirty		; Custom instrument changed: rebuild.
	BEQ.S	FMXFrNb
	SF	FMXPDirty
	BSR	FMXBuild
FMXFrNb:
	LEA	FMXMix,A0		; Clear the mix.
	MOVE.W	FMXN,D0
	ADDQ.W	#1,D0
	LSR.W	#1,D0
	SUBQ.W	#1,D0
FMXFrCl:
	CLR.L	(A0)+
	DBF	D0,FMXFrCl

	BSR	FMXSelect		; FMXSel: the voices mixed this frame.
	LEA	FMXCh,A2
	MOVEQ	#0,D7			; D7 = channel (0-8)
FMXChan:
	MOVE.B	$20(A3,D7.W),D0		; Key-on since last frame (OUT 7Dh):
	MOVE.B	D0,FMXR20		; both slots attack from 124.
	LEA	FMXKeyEv,A0
	TST.B	(A0,D7.W)
	BEQ.S	FMXChNe
	SF	(A0,D7.W)
	CLR.W	CH_CST(A2)		; (CST, MST = ST_ATT)
	MOVE.W	#$7C00,CH_CEG(A2)
	MOVE.W	#$7C00,CH_MEG(A2)
	CLR.L	CH_CPOS(A2)
	CLR.L	CH_FRAC(A2)
	MOVE.W	#$0101,CH_MKEY(A2)	; (MKEY, PKEY)
FMXChNe:
	AND.B	#$10,D0			; Key released: carrier releases,
	TST.B	CH_PKEY(A2)		; modulator holds.
	BEQ.S	FMXChNo
	TST.B	D0
	BNE.S	FMXChNo
	MOVE.B	#ST_REL,CH_CST(A2)
	SF	CH_MKEY(A2)
FMXChNo:
	MOVE.B	D0,CH_PKEY(A2)

	MOVEQ	#0,D1			; Instrument and its patch bytes.
	MOVE.B	$30(A3,D7.W),D1
	LSR.B	#4,D1
	MOVE.W	D1,FMXInst
	BEQ.S	FMXChUs
	LEA	FMX_PATCH(A5,D1.W*8),A4
	BRA.S	FMXChPp
FMXChUs:
	MOVE.L	A3,A4			; (user: registers 00h-07h)
FMXChPp:
	MOVEQ	#0,D1			; F-number, block, and
	MOVE.B	$10(A3,D7.W),D1		; bf = block*2 + fnum bit 8.
	MOVE.B	FMXR20,D2
	BTST	#0,D2
	BEQ.S	FMXChF8
	BSET	#8,D1
FMXChF8:
	MOVE.W	D1,FMXFn
	LSR.B	#1,D2
	AND.W	#7,D2
	MOVE.W	D2,FMXBlk
	MOVE.W	D2,D6
	ADD.W	D6,D6
	BTST	#8,D1
	BEQ.S	FMXChBf
	ADDQ.W	#1,D6
FMXChBf:
	TST.B	CH_MKEY(A2)		; Envelopes: modulator (while the
	BEQ.S	FMXChNm			; key is held), carrier.
	MOVEQ	#1,D0
	MOVE.B	4(A4),D3
	MOVE.B	6(A4),D4
	MOVE.B	0(A4),D5
	BSR	FMXEnv
FMXChNm:
	MOVEQ	#0,D0
	MOVE.B	5(A4),D3
	MOVE.B	7(A4),D4
	MOVE.B	1(A4),D5
	BSR	FMXEnv

	MOVE.W	CH_GI(A2),FMXG0		; Gain index: (carrier envelope +
	MOVEQ	#63,D5			; volume*8 + key scaling) / 2.
	CMP.B	#ST_OFF,CH_CST(A2)
	BEQ.S	FMXChG1
	MOVE.B	3(A4),D1
	BSR	FMXKsl
	MOVEQ	#0,D0
	MOVE.B	CH_CEG(A2),D0
	ADD.W	D1,D0
	MOVE.B	$30(A3,D7.W),D1
	AND.W	#$F,D1
	LSL.W	#3,D1
	ADD.W	D1,D0
	LSR.W	#1,D0
	CMP.W	#63,D0
	BHI.S	FMXChG1
	MOVE.W	D0,D5
FMXChG1:
	MOVE.W	D5,CH_GI(A2)
	MOVE.W	D5,FMXG1
	CMP.W	#63,FMXG0
	BNE.S	FMXChAc
	CMP.W	#63,D5
	BEQ	FMXChNx			; Silent before and now: skip.
FMXChAc:
	MOVE.W	FMXSel,D0		; Not among the loudest (lite): the
	BTST	D7,D0			; envelope ran, but no mixing.
	BEQ	FMXChNx
	MOVE.B	2(A4),D1		; Modulator level -> table k.
	BSR	FMXKsl
	MOVEQ	#0,D0
	MOVE.B	CH_MEG(A2),D0
	ADD.W	D1,D0
	CMP.W	#127,D0
	BLS.S	FMXChK
	MOVEQ	#127,D0
FMXChK:	MOVE.B	FMX_MODLV(A5,D0.W),D0
	LSL.W	#8,D0
	MOVE.W	FMXInst,D1
	BEQ.S	FMXChTu
	MOVEQ	#0,D3
	MOVE.B	FMX_G(A5,D1.W),D3
	SUBQ.W	#1,D1
	MOVEQ	#11,D2
	LSL.L	D2,D1
	LEA	FMX_TAB(A5,D1.L),A0
	BRA.S	FMXChTk
FMXChTu:
	MOVEQ	#0,D3
	MOVE.B	FMXUserG,D3
	LEA	FMXUser,A0
FMXChTk:
	ADDA.W	D0,A0			; A0 = table now.
	MOVE.L	CH_TAB(A2),A1		; A1 = table last frame.
	MOVE.L	A0,CH_TAB(A2)
	MOVE.L	A1,D0
	BNE.S	FMXChOt
	MOVE.L	A0,A1
FMXChOt:
	MOVEQ	#0,D1			; Phase step (16.16, table entries):
	MOVE.W	FMXFn,D1		; ((fnum << block) * g * K) >> 4.
	MOVE.W	FMXBlk,D2
	LSL.L	D2,D1
	MULU.L	D3,D1
	MULU.L	FMXK,D1
	LSR.L	#4,D1
	MOVE.L	D1,FMXStep
	MOVE.W	D1,D3			; D3 = fraction step,
	SWAP	D1
	MOVE.B	D1,D6			; D6.B = whole step.

	CMPA.L	A0,A1			; New modulator level: the old table
	BEQ.S	FMXChOne		; fades out and the new one in.
	MOVE.L	A0,FMXTabNew
	MOVE.L	A1,A0
	LEA	FMXXOOld,A4
	BSR	FMXPass
	MOVE.L	FMXTabNew,A0
	LEA	FMXXONew,A4
	BSR	FMXPass
	BRA.S	FMXChSt
FMXChOne:
	LEA	FMXXO0,A4
	BSR	FMXPass
FMXChSt:
	MOVE.W	D2,CH_FRAC(A2)
	MOVE.W	D4,CH_IDX(A2)
FMXChNx:
	LEA	CH_SIZE(A2),A2
	ADDQ.W	#1,D7
	CMP.W	#9,D7
	BNE	FMXChan

	MOVE.W	FMXWrite,D2		; Output: the next ring block, mix >> 4
	CMP.W	FMXPlay,D2		; through the 8-bit table (soft knee).
	BEQ	FMXOuFull		; (Ring full: this frame's FM is dropped;
	MOVE.W	D2,D0			; the voices ran, so the next block
	MULU	#FMXRBSZ,D0		; follows on without a jump.)
	LEA	(FMXBuf,D0.L),A1
	LEA	FMXMix,A0
	LEA	FMX_CLIP+FMX_CLIPC(A5),A4
	MOVE.W	FMXN,D1
	SUBQ.W	#1,D1
FMXOuL:	MOVE.W	(A0)+,D0
	ASR.W	#4,D0
	MOVE.B	(A4,D0.W),(A1)+
	DBF	D1,FMXOuL
	MOVE.W	FMXN,(FMXLen,D2.W*2)	; (length first: FMXAud reads it once
	ADDQ.W	#1,D2			; FMXWrite has moved on)
	AND.W	#3,D2
	MOVE.W	D2,FMXWrite
	BRA.S	FMXOuDone
FMXOuFull:
	ADDQ.W	#1,FMXOver
	LEA	FMXBuf,A1		; (check build: something to log)
	ADDA.W	FMXN,A1
FMXOuDone:
	IFD	FMXCNT			; (test build: ring counters in perf.bin)
	MOVE.W	FMXUnder,DbStopP+2
	MOVE.W	FMXOver,DbStopR+2
	MOVE.W	FMXN,DbStarts+2
	ENDC

	IFD	FMXREC
	MOVE.W	FMXN,D1			; (check build) keep the output.
	SUB.W	D1,A1
	MOVE.L	FMXRecOP,A0
	LEA	(A0,D1.W),A4
	CMP.L	#FMXRecOEnd,A4
	BHI.S	FMXRcO
	SUBQ.W	#1,D1
FMXRcL:	MOVE.B	(A1)+,(A0)+
	DBF	D1,FMXRcL
	MOVE.L	A0,FMXRecOP
FMXRcO:	ADDQ.W	#1,FMXFrN
	ENDC
	MOVEM.L	FMXSave,D0-D7/A0-A6
	RTS

; -------------------------------------> The voices to mix (FMXSel, bit per
; channel). All of them, or (FMXMaxV < 9, 'PSG+FM lite') the FMXMaxV loudest
; by last frame's gain index, a key-on this frame counting as loudest.
; Uses D0-D4, A0, A1.
	CNOP	0,8
FMXSelect:
	MOVE.W	#$1FF,FMXSel
	CMP.W	#9,FMXMaxV
	BCC.S	FMXSeR
	LEA	FMXSelG,A0		; Each channel's rank value.
	LEA	FMXCh,A1
	LEA	FMXKeyEv,A2
	MOVEQ	#9-1,D1
FMXSe1:	MOVE.W	CH_GI(A1),D0
	TST.B	(A2)+
	BEQ.S	FMXSe2
	MOVEQ	#-1,D0
FMXSe2:	MOVE.W	D0,(A0)+
	LEA	CH_SIZE(A1),A1
	DBF	D1,FMXSe1
	CLR.W	FMXSel
	MOVE.W	FMXMaxV,D4		; Pick the lowest FMXMaxV times.
	SUBQ.W	#1,D4
FMXSe3:	LEA	FMXSelG,A0
	MOVE.W	#$7FFF,D2		; best value
	MOVEQ	#-1,D3			; best channel
	MOVEQ	#0,D1
FMXSe4:	MOVE.W	(A0)+,D0
	CMP.W	D2,D0
	BGE.S	FMXSe5
	MOVE.W	D0,D2
	MOVE.W	D1,D3
FMXSe5:	ADDQ.W	#1,D1
	CMP.W	#9,D1
	BNE.S	FMXSe4
	TST.W	D3
	BMI.S	FMXSeR
	CMP.W	#63,D2			; (silent ones aren't worth a slot)
	BEQ.S	FMXSeR
	MOVE.W	FMXSel,D0
	BSET	D3,D0
	MOVE.W	D0,FMXSel
	LEA	FMXSelG,A0
	MOVE.W	#$7FFF,(A0,D3.W*2)
	DBF	D4,FMXSe3
FMXSeR:	RTS

; -------------------------------------> Mix one voice (one table) in 4 quarters.
; A0 = table, A4 = gain index offsets (4 bytes), A2 = channel, D3.W/D6.B =
; step. The gain index moves from FMXG0 to FMXG1 by quarters. Out: D2/D4 =
; the phase after the frame. Uses D0, D1, D5, A1, A6.
	CNOP	0,8
FMXPass:
	MOVE.W	CH_FRAC(A2),D2
	MOVE.W	CH_IDX(A2),D4
	LEA	FMXMix,A6
	MOVEQ	#0,D1			; D1 = quarter
FMXPaQ:	MOVE.W	FMXG1,D0		; g = g0 + ((g1-g0)*(q+1) >> 2)
	SUB.W	FMXG0,D0		;     + offset[q], at most 63.
	MOVE.W	D1,D5
	ADDQ.W	#1,D5
	MULS.W	D5,D0
	ASR.L	#2,D0
	ADD.W	FMXG0,D0
	MOVEQ	#0,D5
	MOVE.B	(A4,D1.W),D5
	ADD.W	D5,D0
	CMP.W	#63,D0
	BCS.S	FMXPaV
	MOVE.L	FMXStep,D5		; Silent quarter: just move the phase
	MOVEQ	#0,D0			; on (phase += step * n).
	MOVE.W	(FMXQsz-FMXDat,A5,D1.W*2),D0
	MULU.L	D0,D5
	SWAP	D4
	MOVE.W	D2,D4
	ADD.L	D5,D4
	MOVE.W	D4,D2
	CLR.W	D4
	SWAP	D4
	AND.W	#$FF,D4
	LEA	(A6,D0.W*2),A6
	BRA.S	FMXPaN
FMXPaV:	LEA	FMXVol,A1
	LSL.W	#8,D0
	ADD.W	D0,D0
	ADDA.W	D0,A1			; A1 = VOLTAB[g]
	MOVE.W	(FMXQsz-FMXDat,A5,D1.W*2),D0
	SUBQ.W	#1,D0
	MOVE.W	D1,FMXQ			; (D1 is needed in the loop)
	MOVEQ	#0,D5
FMXPaL:	ADD.W	D3,D2			; Phase: fraction, then index + carry.
	ADDX.B	D6,D4
	MOVE.B	(A0,D4.W),D5
	MOVE.W	(A1,D5.W*2),D1
	ADD.W	D1,(A6)+
	DBF	D0,FMXPaL
	MOVE.W	FMXQ,D1
FMXPaN:	ADDQ.W	#1,D1
	CMP.W	#4,D1
	BNE	FMXPaQ
	RTS

; -------------------------------------> Envelope of one slot, once a frame.
; D0 = slot (0 carrier, 1 modulator), A2 = channel, D3.B = AR/DR, D4.B =
; SL/RR, D5.B = AM/PM/EG/KR/ML, D6.W = bf, FMXR20 = register 2xh (sustain).
; Uses D1, D2, A1.
	CNOP	0,8
FMXEnv:
	MOVE.B	CH_CST(A2,D0.W),D2
	CMP.B	#ST_OFF,D2
	BEQ	FMXEnR
	TST.B	D2
	BNE.S	FMXEnNa
	MOVE.B	D3,D1			; Attack: next value of the curve for
	LSR.B	#4,D1			; this rate (255 = hold, 0 = done).
	AND.W	#$F,D1
	BSR	FMXRix
	ADD.W	D1,D1
	MOVE.W	FMX_ATTOFF(A5,D1.W),D1
	LEA	FMX_ATT(A5,D1.W),A1
	MOVE.W	CH_CPOS(A2,D0.W*2),D2
	MOVE.B	(A1,D2.W),D1
	CMP.B	#$FF,D1
	BEQ	FMXEnR
	ADDQ.W	#1,D2
	MOVE.W	D2,CH_CPOS(A2,D0.W*2)
	TST.B	D1
	BNE.S	FMXEnAs
	CLR.W	CH_CEG(A2,D0.W*2)
	MOVE.B	#ST_DEC,CH_CST(A2,D0.W)
	RTS
FMXEnAs:
	AND.W	#$FF,D1
	LSL.W	#8,D1
	MOVE.W	D1,CH_CEG(A2,D0.W*2)
	RTS
FMXEnNa:
	CMP.B	#ST_DEC,D2		; Rate: decay DR; sustain 0 (EG) or
	BNE.S	FMXEnNd			; RR; release 5 (sustain on), RR
	MOVE.B	D3,D1			; (EG) or 7.
	BRA.S	FMXEnRt
FMXEnNd:
	CMP.B	#ST_SUS,D2
	BNE.S	FMXEnRl
	MOVEQ	#0,D1
	BTST	#5,D5
	BNE.S	FMXEnR0
	MOVE.B	D4,D1
	BRA.S	FMXEnRt
FMXEnRl:
	MOVEQ	#5,D1
	BTST	#5,FMXR20
	BNE.S	FMXEnR0
	MOVEQ	#7,D1
	BTST	#5,D5
	BEQ.S	FMXEnR0
	MOVE.B	D4,D1
FMXEnRt:
	AND.W	#$F,D1
FMXEnR0:
	BSR	FMXRix
	ADD.W	D1,D1
	MOVE.W	FMX_DEC(A5,D1.W),D1
	ADD.W	CH_CEG(A2,D0.W*2),D1
	CMP.W	#32512,D1
	BLS.S	FMXEnMx
	MOVE.W	#32512,D1
FMXEnMx:
	MOVE.W	D1,CH_CEG(A2,D0.W*2)
	MOVE.B	CH_CST(A2,D0.W),D2	; (FMXRix used D2)
	CMP.B	#ST_DEC,D2
	BNE.S	FMXEnNs
	LSR.W	#8,D1			; Decay reaches SL: sustain.
	LSR.W	#3,D1
	MOVE.B	D4,D2
	LSR.B	#4,D2
	AND.W	#$F,D2
	CMP.W	D2,D1
	BCS.S	FMXEnR
	MOVE.B	#ST_SUS,CH_CST(A2,D0.W)
	RTS
FMXEnNs:
	CMP.B	#ST_REL,D2		; Release reaches silence: off.
	BNE.S	FMXEnR
	CMP.W	#32512,D1
	BCS.S	FMXEnR
	MOVE.B	#ST_OFF,CH_CST(A2,D0.W)
FMXEnR:	RTS

; D1.W = rate (0-15) -> D1.W = table index rh*4 + rl, with key scaling
; (D5 bit 4 = KR, D6 = bf). Rate 0 -> 0. Uses D2.
FMXRix:
	TST.W	D1
	BEQ.S	FMXRiR
	MOVE.W	D6,D2			; rks = KR ? bf : bf >> 2
	BTST	#4,D5
	BNE.S	FMXRiK
	LSR.W	#2,D2
FMXRiK:	ROR.W	#2,D2			; (low byte: rks >> 2)
	ADD.B	D2,D1
	CMP.B	#15,D1
	BLS.S	FMXRiH
	MOVEQ	#15,D1
FMXRiH:	LSL.W	#2,D1
	ROL.W	#2,D2
	AND.W	#3,D2
	OR.W	D2,D1
FMXRiR:	RTS

; D1.B = byte with KL in bits 7-6 -> D1.W = key scale level (0.375 dB units)
; for FMXFn/FMXBlk. Uses D2.
FMXKsl:
	LSR.B	#6,D1
	AND.W	#3,D1
	BEQ.S	FMXKsR
	SUBQ.W	#1,D1
	LSL.W	#7,D1
	MOVE.W	FMXBlk,D2
	LSL.W	#4,D2
	ADD.W	D2,D1
	MOVE.W	FMXFn,D2
	LSR.W	#5,D2
	ADD.W	D2,D1
	MOVE.B	FMX_KSL(A5,D1.W),D1
	AND.W	#$FF,D1
FMXKsR:	RTS

; -------------------------------------> Custom instrument tables.
; As make_tables in tools/fm_synth.py: for each modulator level, 3 cycles
; of 256 points (feedback settles), the 3rd kept as the table.
	CNOP	0,8
FMXBuild:
	LEA	Tabla7C,A3
	LEA	FMXMLT,A0
	MOVEQ	#0,D0
	MOVE.B	(A3),D0
	AND.W	#$F,D0
	MOVE.B	(A0,D0.W),D0		; D0 = modulator multiple (x2)
	MOVEQ	#0,D1
	MOVE.B	1(A3),D1
	AND.W	#$F,D1
	MOVE.B	(A0,D1.W),D1		; D1 = carrier multiple (x2)
	MOVE.L	D0,D2			; g = gcd
	MOVE.L	D1,D3
FMXBuG:	TST.W	D3
	BEQ.S	FMXBuGd
	AND.L	#$FFFF,D2
	DIVU.W	D3,D2
	SWAP	D2
	EXG	D2,D3
	BRA.S	FMXBuG
FMXBuGd:
	MOVE.B	D2,FMXUserG
	DIVU.W	D2,D0			; Phase steps per point: 4*mult/g.
	LSL.W	#2,D0
	MOVE.W	D0,FMXSm
	DIVU.W	D2,D1
	LSL.W	#2,D1
	MOVE.W	D1,FMXSc
	MOVEQ	#0,D0
	MOVE.B	2(A3),D0
	AND.W	#63,D0
	ADD.W	D0,D0
	MOVE.W	D0,FMXTl2		; TL*2
	MOVE.B	3(A3),D0
	MOVE.W	D0,D1
	AND.W	#7,D1
	MOVE.W	D1,FMXFb
	BTST	#3,D0
	SNE	FMXWsM
	BTST	#4,D0
	SNE	FMXWsC
	LEA	FMXUser,A1
	LEA	FMX_MODLEVELS(A5),A2
	MOVEQ	#0,D7
FMXBuLv:
	MOVEQ	#0,D0
	MOVE.B	(A2,D7.W),D0
	ADD.W	FMXTl2,D0
	MOVE.W	D0,FMXAttM
	MOVEQ	#0,D5			; o0
	MOVEQ	#0,D6			; o1
	MOVEQ	#0,D4			; n (0-767)
FMXBuN:	MOVE.W	D4,D0
	AND.W	#$FF,D0
	MULU.W	FMXSm,D0
	TST.W	FMXFb			; Feedback: (o0+o1) >> (9-FB).
	BEQ.S	FMXBuNf
	MOVE.W	D5,D1
	ADD.W	D6,D1
	MOVEQ	#9,D2
	SUB.W	FMXFb,D2
	ASR.W	D2,D1
	ADD.W	D1,D0
FMXBuNf:
	MOVE.W	FMXAttM,D1
	MOVE.B	FMXWsM,D2
	BSR	FMXOp
	MOVE.W	D5,D6
	MOVE.W	D0,D5
	ASR.W	#1,D0			; Carrier: k*sc + 2*(mo >> 1).
	ADD.W	D0,D0
	MOVE.W	D0,D3
	MOVE.W	D4,D0
	AND.W	#$FF,D0
	MULU.W	FMXSc,D0
	ADD.W	D3,D0
	MOVEQ	#0,D1
	MOVE.B	FMXWsC,D2
	BSR	FMXOp
	CMP.W	#512,D4
	BCS.S	FMXBuSk
	ASR.W	#5,D0
	CMP.W	#127,D0
	BLE.S	FMXBuC1
	MOVEQ	#127,D0
FMXBuC1:
	CMP.W	#-127,D0
	BGE.S	FMXBuC2
	MOVE.W	#-127,D0
FMXBuC2:
	MOVE.B	D0,(A1)+
FMXBuSk:
	ADDQ.W	#1,D4
	CMP.W	#768,D4
	BNE.S	FMXBuN
	ADDQ.W	#1,D7
	CMP.W	#8,D7
	BNE	FMXBuLv
	RTS

; One operator sample: D0.W = phase (1024 a cycle), D1.W = attenuation
; (0.375 dB units), D2.B = half-sine flag. Out: D0.W (-4096..4095).
; Uses D1, D3.
FMXOp:	CMP.W	#124,D1
	BCC.S	FMXOpZ
	AND.W	#1023,D0
	MOVE.W	D0,D3
	LSR.W	#8,D3			; quarter
	AND.W	#$FF,D0
	BTST	#0,D3
	BEQ.S	FMXOpE
	NOT.B	D0
FMXOpE:	MOVE.W	FMX_LOGSIN(A5,D0.W*2),D0
	BTST	#1,D3
	BEQ.S	FMXOpP
	TST.B	D2
	BEQ.S	FMXOpN
	MOVE.W	#$FFF,D0
	BRA.S	FMXOpP
FMXOpN:	OR.W	#$8000,D0
FMXOpP:	LSL.W	#4,D1
	ADD.W	D1,D0			; i = log value + attenuation
	MOVE.W	D0,D1
	NOT.B	D1
	AND.W	#$FF,D1
	MOVE.W	FMX_EXP(A5,D1.W*2),D1
	ADD.W	#1024,D1
	MOVE.W	D0,D3
	LSR.W	#8,D3
	AND.W	#$7F,D3
	CMP.W	#15,D3
	BLS.S	FMXOpS
	MOVEQ	#0,D1
	BRA.S	FMXOpG
FMXOpS:	LSR.W	D3,D1
FMXOpG:	TST.W	D0
	BPL.S	FMXOpQ
	NOT.W	D1
FMXOpQ:	ADD.W	D1,D1
	MOVE.W	D1,D0
	RTS
FMXOpZ:	MOVEQ	#0,D0
	RTS
