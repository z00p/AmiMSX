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
; (5.4) Rhythm mode (0Eh bit 5): FMXRhythm plays the five drums in channels
; 7-9's place. Bass drum and tom-tom are table voices at twice the gain (as
; on the chip); hi-hat, snare and cymbal are one loop on the chip's phase
; bits and noise.

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
FMX_MIXMAX=(FMX_CLIPC-1)*16	; (5.4) largest mix value the table takes
FMX_LVN=128		; (5.4) band-limited tables kept (256 bytes each)
FMX_LVDSZ=136*FMX_LVMAX	; (5.4) their directory: a byte a table and level
FMXRBSZ=320		; one ring block (up to 318 samples)
FMXBUFSZ=8*FMXRBSZ	; DMA ring: 8 blocks (FMXAud)

; -------------------------------------> Reset (emulation start).
	CNOP	0,8
FMXInit:
	MOVEM.L	D0-D7/A0-A6,FMXSave
	LEA	FMXDat,A5
	CLR.L	FMXAgcK			; (4.7) Gain x1, no count (and FMXAgcN).
	MOVE.W	#227,FMXN		; Paula mode: 227 samples/frame at
	MOVE.W	#313,FMXPer		; period 313, or 313 at period 227.
	MOVE.L	#FMX_K227,FMXK
	MOVE.L	$4.W,A0			; 68040/68060 (PiStorm's Emu68 says so)
	MOVE.W	$128(A0),D0		; or 'Smooth display (fast CPUs)' on (the
	AND.W	#$88,D0			; PiStorm preset; a BigMig's TG68K core
	SNE	FMXFast			; reports a 68020): 15.6 kHz.
	SNE	FMXHQ			; (5.4) the 2x mix: 040/060 (PiStorm) with
	CLR.L	FMXMix2H
	CLR.L	FMXMix2H+4
	CLR.L	FMXMix2H+8
	TST.B	PrefDbuf		; Smooth display on (the PiStorm presets)
	BNE.S	FMXInDb			; only: it takes ~115 lines a frame on a
	SF	FMXHQ			; 68060 with all nine voices (Lilly: 100 to
	BRA.S	FMXInFs			; 89% speed in WinUAE).
FMXInDb:
	ST	FMXFast
FMXInFs:
	MOVEQ	#0,D0			; (5.4) The rhythm tables' rate: 0 11.3
	TST.B	FMXFast			; kHz, 1 15.6, 2 twice that (FMXHQ).
	BEQ.S	FMXIn227
	MOVE.W	#313,FMXN
	MOVE.W	#227,FMXPer
	MOVE.L	#FMX_K313,FMXK
	MOVEQ	#1,D0
	TST.B	FMXHQ
	BEQ.S	FMXIn227
	MOVEQ	#2,D0
FMXIn227:
	MOVE.L	D0,D1
	MULU.W	#4*32,D1		; (4 key-scale rows of 32)
	ADD.L	#FMX_BDHIT,D1
	ADD.L	A5,D1
	MOVE.L	D1,FMXBdRow
	MULU.W	#3*16,D0		; (3 drums of 8 words)
	ADD.L	#FMX_DRLEV,D0
	ADD.L	A5,D0
	MOVE.L	D0,FMXDrLev
	MOVE.L	#FMXVol,FMXVolP
	MOVEQ	#1,D0
	MOVE.L	D0,FMXNoise
	CLR.L	FMXDrPh
	CLR.L	FMXDrPh+4
	CLR.L	FMXDrPh+8
	BSR	FMXDrQuiet
	MOVE.W	#9,FMXChans
	TST.B	FMXVolOK		; Volume tables: VOLTAB[g][u] =
	BNE.S	FMXInVok		; (signed u * GAIN[g]) >> 4, once.
	LEA	FMXVolD,A0		; (5.4) first 8 steps at twice the gain
	LEA	FMX_GAIN(A5),A1		; (drums), then FMXVol.
	MOVEQ	#8-1,D7
FMXInVh:
	MOVE.W	(A1)+,D1
	ADD.W	D1,D1
	MOVEQ	#0,D0
FMXInVi:
	MOVE.B	D0,D2
	EXT.W	D2
	MULS.W	D1,D2
	ASR.L	#4,D2
	MOVE.W	D2,(A0)+
	ADDQ.W	#1,D0
	CMP.W	#256,D0
	BNE.S	FMXInVi
	DBF	D7,FMXInVh
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
	CLR.L	(A0)			; (5.4) (and the drums')
	ST	FMXPDirty
	CLR.L	FMXPm			; (5.4) vibrato at phase 0, no
	CLR.W	FMXLvNx			; band-limited tables yet.
	LEA	FMXLvDir,A0
	MOVE.W	#FMX_LVDSZ/4-1,D0
FMXInLv:
	CLR.L	(A0)+
	DBF	D0,FMXInLv
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
	SF	FMXMixOn		; (4.7) Sound mix (PrefMix): 0 automatic
	MOVE.B	FMXMixRun,D0		; = Mono on a fast CPU (FMXFast), else
	TST.B	FMXMixNew		; Classic; 1 Classic, 2 Mono, 3 Stereo.
	BEQ.S	FMXInX3			; Chosen at Power ON / Reset only: on
	SF	FMXMixNew		; Continue the running mix stays (a switch
	MOVE.B	PrefMix,D0		; mid-game left the PSG on the other path).
	BNE.S	FMXInX1
	MOVEQ	#1,D0
	TST.B	FMXFast
	BEQ.S	FMXInX1
	MOVEQ	#2,D0
FMXInX1:SUBQ.B	#1,D0
	MOVE.B	D0,FMXMixRun
FMXInX3:MOVE.B	D0,FMXMixOn		; (0 Classic, 1 Mono, 2 Stereo)
	BNE.S	FMXInX4
	SF	FMXPsg			; (5.4) Classic: Sound PSG on Paula's
	BRA.S	FMXInX2			; voices as before, no FMX.
FMXInX4:CMP.B	#2,D0
	SEQ	PsxStereo
	BSR	PsxInit
FMXInX2:
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
	MOVE.L	$DFF004,D0		; Beam line (V8-V0): until two reads agree.
	LSR.L	#8,D0			; (5.4) A long read is two word reads, and
	AND.W	#$1FF,D0		; across line 255 -> 256 it gave line 0: a
FMXVL1:	MOVE.W	D0,D3			; false wrap, so PAL measured as NTSC (203
	MOVE.L	$DFF004,D0		; of 400 measurements on WinUAE's 030, 60
	LSR.L	#8,D0			; on its 060) and N came out a sixth short.
	AND.W	#$1FF,D0
	CMP.W	D3,D0
	BNE.S	FMXVL1
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
	BEQ	FMXAuX
	MOVE.W	#$0400,$DFF09C
	MOVE.W	FMXQueued,D0
	MOVE.W	D0,FMXPlay
	ADDQ.W	#1,D0
	AND.W	#7,D0
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
	TST.B	FMXMixOn		; (4.7) Sound mix: channels 0-2 take
	BEQ	FMXAuX			; the same block of their rings.
	MOVE.W	D0,$DFF0A4
	MOVE.W	D0,$DFF0B4
	MOVE.W	D0,$DFF0C4
	SUB.L	#FMXBuf,A0
	MOVE.L	A0,D0
	ADD.L	#FMXBufLL,D0
	MOVE.L	D0,$DFF0A0
	MOVE.L	A0,D0
	ADD.L	FMXRingRL,D0
	MOVE.L	D0,$DFF0B0
	MOVE.L	A0,D0
	ADD.L	FMXRingR,D0
	MOVE.L	D0,$DFF0C0
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
	TST.B	FMXMixOn		; (4.7) Sound mix: channels 0-2 too.
	BEQ.S	FMXFrR1
	BSR	PsxStart
FMXFrR1:
	MOVE.W	#$0400,$DFF09C
	MOVE.W	#$8008,D0
	TST.B	FMXMixOn
	BEQ.S	FMXFrR2
	MOVE.W	#$800F,D0
FMXFrR2:MOVE.W	D0,$DFF096		; Paula takes block 0 and asks (AUD3)
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
	SUBQ.W	#1,D0			; Paula. Fewer than 2: 2 samples more,
	AND.W	#7,D0			; more than 2: 2 fewer. The emulation's
	MOVE.W	FMXNnom,D1		; frame rate and Paula's clock then agree
	CMP.W	#2,D0			; on average, whatever the display (50
	BEQ.S	FMXFrN3			; Hz, 60 Hz with 227/228-clock lines),
	BHI.S	FMXFrN1			; with 2 frames in hand for late ones
	ADDQ.W	#2,D1			; (BigMig, PiStorm). Pitch is the step
	BRA.S	FMXFrN3			; per sample: unchanged.
FMXFrN1:SUBQ.W	#2,D1
FMXFrN3:
	IFD	FMXREC
	MOVE.W	FMXNnom,D1		; (check build) a fixed N, for fmx_check.py.
	ENDC
	CMP.W	FMXN,D1
	BEQ.S	FMXFrN4
	MOVE.W	D1,FMXN
	BSR	FMXSetQ
FMXFrN4:
	TST.B	FMXPDirty		; Custom instrument changed: rebuild.
	BEQ.S	FMXFrNb
	SF	FMXPDirty
	BSR	FMXBuild
	LEA	FMXLvDir+120*FMX_LVMAX,A0	; (5.4) and forget its band-limited
	MOVEQ	#8*FMX_LVMAX/4-1,D0	; tables.
FMXFrLv:
	CLR.L	(A0)+
	DBF	D0,FMXFrLv
FMXFrNb:
	LEA	FMXMix,A0		; Clear the mix.
	MOVE.W	FMXN,D0
	ADDQ.W	#1,D0
	LSR.W	#1,D0
	SUBQ.W	#1,D0
FMXFrCl:
	CLR.L	(A0)+
	DBF	D0,FMXFrCl
	TST.B	FMXHQ			; (5.4) and the 2x mix (2N words).
	BEQ.S	FMXFrNh
	LEA	FMXMix2,A0
	MOVE.W	FMXN,D0
	SUBQ.W	#1,D0
FMXFrC2:
	CLR.L	(A0)+
	DBF	D0,FMXFrC2
FMXFrNh:
	TST.B	FMXPsg			; (5.4) Sound PSG through the mix: no FM.
	BNE	FMXChHd
	MOVE.W	#9,FMXChans
	BTST	#5,$E(A3)		; (5.4) Rhythm mode: channels 7-9 are the
	BNE.S	FMXFrRy			; drums' on the chip, never instruments.
	SF	FMXDrEv			; (Played as ones, the drum pitch slides
	BSR	FMXDrQuiet		; were Illusion City's screech, 6 -> 2.6
	BRA.S	FMXFrMl			; kHz every 1.1 s.)
FMXFrRy:
	MOVE.W	#6,FMXChans
	LEA	FMXKeyEv+6,A0
	LEA	FMXCh+6*CH_SIZE,A1
	MOVEQ	#3-1,D0
FMXFrRh:
	SF	(A0)+
	MOVE.W	#63,CH_GI(A1)		; (nothing to select)
	LEA	CH_SIZE(A1),A1
	DBF	D0,FMXFrRh
FMXFrMl:

	MOVE.L	FMXPm,D0		; (5.4) the vibrato LFO: this frame's
	MOVE.L	D0,D1			; phase, then on by the frame's length.
	SWAP	D1
	AND.W	#7,D1
	MOVE.W	D1,FMXPmPh
	MOVEQ	#0,D1
	MOVE.W	FMXN,D1
	MULU.L	#FMX_PMK,D1
	ADD.L	D1,D0
	MOVE.L	D0,FMXPm
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
	CLR.W	FMXLvl
	TST.B	FMXHQ			; (5.4) twice the samples: half the step.
	BEQ.S	FMXChS1
	MOVE.L	D1,D0			; And the table's level: an octave less
	LSR.L	#1,D0			; while a sample steps over an entry.
	MOVEQ	#0,D2
FMXChLv:
	CMP.L	#FMX_LVSTEP,D0
	BLS.S	FMXChLd
	ADDQ.W	#1,D2
	LSR.L	#1,D0
	CMP.W	#FMX_LVMAX,D2
	BNE.S	FMXChLv
FMXChLd:
	MOVE.W	D2,FMXLvl
	BTST	#6,1(A4)		; Vibrato (the carrier's PM bit):
	BEQ.S	FMXChPm
	MOVE.W	FMXFn,D0		; step += ((delta << block) * g * K) >> 5,
	LSR.W	#3,D0			; delta by fnum's top 3 bits and phase.
	AND.W	#$38,D0
	ADD.W	FMXPmPh,D0
	MOVE.B	FMX_PMTAB(A5,D0.W),D0
	EXTB.L	D0
	MOVE.W	FMXBlk,D2
	ASL.L	D2,D0
	MULS.L	D3,D0
	MULS.L	FMXK,D0
	ASR.L	#5,D0
	ADD.L	D0,D1
FMXChPm:
	LSR.L	#1,D1
FMXChS1:
	MOVE.L	D1,FMXStep
	MOVE.W	D1,D3			; D3 = fraction step,
	SWAP	D1
	MOVE.B	D1,D6			; D6.B = whole step.

	CMPA.L	A0,A1			; New modulator level: the old table
	BEQ.S	FMXChOne		; fades out and the new one in.
	MOVE.L	A0,FMXTabNew
	MOVE.L	A1,A0
	BSR	FMXLevel
	LEA	FMXXOOld,A4
	BSR	FMXPass
	MOVE.L	FMXTabNew,A0
	BSR	FMXLevel
	LEA	FMXXONew,A4
	BSR	FMXPass
	BRA.S	FMXChSt
FMXChOne:
	BSR	FMXLevel
	LEA	FMXXO0,A4
	BSR	FMXPass
FMXChSt:
	MOVE.W	D2,CH_FRAC(A2)
	MOVE.W	D4,CH_IDX(A2)
FMXChNx:
	LEA	CH_SIZE(A2),A2
	ADDQ.W	#1,D7
	CMP.W	FMXChans,D7
	BNE	FMXChan
	CMP.W	#9,D7
	BEQ.S	FMXChNr
	BSR	FMXRhythm		; (5.4) the drums.
FMXChNr:
	TST.B	FMXHQ
	BEQ.S	FMXChHd
	BSR	FMXDown			; (5.4) 2x mix -> FMXMix.
FMXChHd:

	IFD	TURBOR
	BSR	PcmFrame		; (turbo R) the PCM into the mix.
	ENDC
	TST.B	FMXMixOn		; (4.7) Sound mix: the PSG in software
	BEQ.S	FMXOuCl			; and the 14-bit mix out (PsxFrame).
	BSR	PsxFrame
	BRA	FMXOuEnd
FMXOuCl:
	MOVE.W	FMXWrite,D2		; Output: the next ring block, mix >> 4
	CMP.W	FMXPlay,D2		; through the 8-bit table (soft knee).
	BEQ	FMXOuFull		; (Ring full: this frame's FM is dropped;
	MOVE.W	D2,D0			; the voices ran, so the next block
	MULU	#FMXRBSZ,D0		; follows on without a jump.)
	LEA	(FMXBuf,D0.L),A1
	LEA	FMXMix,A0
	LEA	FMX_CLIP+FMX_CLIPC(A5),A4
	MOVE.W	FMXAgcK,D0		; (4.7) The automatic gain's table
	MULU	#2*FMX_CLIPC,D0		; (x1 to x4, 3 dB steps), and this
	ADD.L	D0,A4			; frame's peak: highest D5, lowest D6.
	MOVEQ	#0,D5
	MOVEQ	#0,D6
	MOVE.W	FMXN,D1
	SUBQ.W	#1,D1
FMXOuL:	MOVE.W	(A0)+,D0
	ASR.W	#4,D0
	IFD	TURBOR
	CMP.W	#FMX_CLIPC-1,D0		; (5.4) FM + PCM can pass the table's
	BLE.S	FMXOuT1			; range.
	MOVE.W	#FMX_CLIPC-1,D0
FMXOuT1:
	CMP.W	#-FMX_CLIPC,D0
	BGE.S	FMXOuT2
	MOVE.W	#-FMX_CLIPC,D0
FMXOuT2:
	ENDC
	MOVE.B	(A4,D0.W),(A1)+
	CMP.W	D0,D5
	BGE.S	FMXOuHi
	MOVE.W	D0,D5
FMXOuHi:
	CMP.W	D0,D6
	BLE.S	FMXOuLo
	MOVE.W	D0,D6
FMXOuLo:
	DBF	D1,FMXOuL
	NEG.W	D6
	CMP.W	D6,D5
	BGE.S	FMXOuPk
	MOVE.W	D6,D5
FMXOuPk:
	BSR	FMXAgc
	MOVE.W	FMXN,(FMXLen,D2.W*2)	; (length first: FMXAud reads it once
	ADDQ.W	#1,D2			; FMXWrite has moved on)
	AND.W	#7,D2
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
FMXOuEnd:
	MOVEM.L	FMXSave,D0-D7/A0-A6
	RTS


	IFD	TURBOR
; -------------------------------------> (turbo R) The PCM, once a frame,
; into FMXMix: each DAC write (PcmLog, from OUTA4/OUTA5) at its sample as
; PsxFrame places the PSG's, the level held between writes. A frame without
; writes adds nothing (a level held would only be an offset). Uses D0-D7,
; A0-A2.
	CNOP	0,4
PcmFrame:
	MOVE.W	PcmLogN,D6
	LSR.W	#3,D6
	BEQ	PcmFrX
	MOVE.W	#313,D4			; D4 = the MSX frame's lines,
	BTST	#1,REGS+DVDP9
	BNE.S	PcmFr1
	MOVE.W	#262,D4
PcmFr1:	MOVE.W	D4,D5
	MULU.W	#HPeriod,D5		; D5 = its cycles.
	LEA	PcmLog,A0
	SUBQ.W	#1,D6
PcmFrI:	MOVEQ	#0,D0
	MOVE.B	3(A0),D0		; (CurLine: its low byte)
	CMP.W	#255,D0
	BNE.S	PcmFrI1
	MOVE.W	D4,D0			; the rest of the frame
	SUBQ.W	#1,D0
PcmFrI1:ADDQ.W	#1,D0
	MULU.W	#HPeriod,D0		; end of the line
	SUB.L	#192*HPeriod,D0		; from line 192
	BGT.S	PcmFrI2
	ADD.L	D5,D0
PcmFrI2:MOVE.W	4(A0),D1
	EXT.L	D1
	BPL.S	PcmFrI3
	MOVEQ	#0,D1
PcmFrI3:SUB.L	D1,D0
	BPL.S	PcmFrI4
	MOVEQ	#0,D0
PcmFrI4:CMP.L	D5,D0
	BCS.S	PcmFrI5
	MOVE.L	D5,D0
	SUBQ.L	#1,D0
PcmFrI5:MOVEQ	#0,D1
	MOVE.W	FMXN,D1
	MULU.L	D1,D0
	DIVU.L	D5,D0
	MOVE.W	D0,6(A0)
	ADDQ.W	#8,A0
	DBF	D6,PcmFrI
	MOVE.W	#$7FFF,6(A0)		; (end: no sample reaches it)
	LEA	PcmLog,A2
	LEA	FMXMix,A1
	MOVE.W	PcmLev,D2
	MOVE.W	FMXN,D3
	MOVEQ	#0,D7
PcmFrS:	CMP.W	6(A2),D7
	BCS.S	PcmFrS1
	BSR.S	PcmFrW
	BRA.S	PcmFrS
PcmFrS1:ADD.W	D2,(A1)+
	ADDQ.W	#1,D7
	CMP.W	D3,D7
	BCS.S	PcmFrS
PcmFrS2:CMP.W	#$7FFF,6(A2)		; Writes past the end (rounding).
	BEQ.S	PcmFrS3
	BSR.S	PcmFrW
	BRA.S	PcmFrS2
PcmFrS3:MOVE.W	D2,PcmLev
	CLR.W	PcmLogN
PcmFrX:	RTS
PcmFrW:	MOVEQ	#0,D0			; D2 = the write's level.
	MOVE.B	1(A2),D0
	SUB.W	#128,D0
	MULS.W	#PCMGAIN,D0
	MOVE.W	D0,D2
	ADDQ.W	#8,A2
	RTS
	ENDC
; (4.7) Automatic gain, once a frame after the output (tools/fm_synth.py
; Synth.agc). D5.W = the frame's peak |mix >> 4|. Down at once while the
; peak passes AGCDN for the gain; up a step after FMX_AGCHOLD frames under
; AGCUP, counting only frames with a peak of FMX_AGCFLOOR or more (silence
; keeps the gain). Uses D3, D4.
FMXAgc:
	MOVE.W	FMXAgcK,D3
	MOVE.W	D3,D4
FMXAgD:	TST.W	D4
	BEQ.S	FMXAgN
	CMP.W	FMX_AGCDN(A5,D4.W*2),D5
	BLS.S	FMXAgN
	SUBQ.W	#1,D4
	BRA.S	FMXAgD
FMXAgN:	CMP.W	D3,D4
	BEQ.S	FMXAgU
	MOVE.W	D4,FMXAgcK
	CLR.W	FMXAgcN
	RTS
FMXAgU:	CMP.W	#4,D3
	BEQ.S	FMXAgR
	CMP.W	#FMX_AGCFLOOR,D5
	BCS.S	FMXAgR
	CMP.W	FMX_AGCUP(A5,D3.W*2),D5
	BCC.S	FMXAgZ
	ADDQ.W	#1,FMXAgcN
	CMP.W	#FMX_AGCHOLD,FMXAgcN
	BCS.S	FMXAgR
	ADDQ.W	#1,FMXAgcK
FMXAgZ:	CLR.W	FMXAgcN
FMXAgR:	RTS

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
	TST.B	FMXHQ
	BNE	FMXPassH
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
FMXPaV:	MOVE.L	FMXVolP,A1
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

; -------------------------------------> (5.4) FMXPass at twice the rate (68040/060).
; As FMXPass, but 2N samples into FMXMix2, each interpolated between two
; table entries: v = t + ((next - t) * (fraction >> 10) >> 6). Without it the
; nearest-entry steps hiss (bass) and bright notes fold back below 7.8 kHz.
; Uses D0, D1, D5, A1, A6 (D7 kept).
	CNOP	0,8
FMXPassH:
	MOVE.L	D7,-(SP)
	MOVE.W	CH_FRAC(A2),D2
	MOVE.W	CH_IDX(A2),D4
	LEA	FMXMix2,A6
	MOVEQ	#0,D1			; D1 = quarter
FMXPhQ:	MOVE.W	FMXG1,D0
	SUB.W	FMXG0,D0
	MOVE.W	D1,D5
	ADDQ.W	#1,D5
	MULS.W	D5,D0
	ASR.L	#2,D0
	ADD.W	FMXG0,D0
	MOVEQ	#0,D5
	MOVE.B	(A4,D1.W),D5
	ADD.W	D5,D0
	CMP.W	#63,D0
	BCS.S	FMXPhV
	MOVE.L	FMXStep,D5		; Silent quarter: just the phase.
	MOVEQ	#0,D0
	MOVE.W	(FMXQsz-FMXDat,A5,D1.W*2),D0
	ADD.W	D0,D0
	MULU.L	D0,D5
	SWAP	D4
	MOVE.W	D2,D4
	ADD.L	D5,D4
	MOVE.W	D4,D2
	CLR.W	D4
	SWAP	D4
	AND.W	#$FF,D4
	LEA	(A6,D0.W*2),A6
	BRA.S	FMXPhN
FMXPhV:	MOVE.L	FMXVolP,A1
	LSL.W	#8,D0
	ADD.W	D0,D0
	ADDA.W	D0,A1			; A1 = VOLTAB[g]
	MOVE.W	(FMXQsz-FMXDat,A5,D1.W*2),D0
	ADD.W	D0,D0
	SUBQ.W	#1,D0
	MOVE.W	D1,FMXQ
FMXPhL:	ADD.W	D3,D2			; Phase: fraction, then index + carry.
	ADDX.B	D6,D4
	MOVE.B	(A0,D4.W),D5		; this entry
	MOVE.W	D4,D1
	ADDQ.B	#1,D1
	MOVE.B	(A0,D1.W),D1		; the next (the table wraps)
	EXT.W	D5
	EXT.W	D1
	SUB.W	D5,D1
	MOVE.W	D2,D7			; the fraction's top 6 bits
	LSR.W	#8,D7
	LSR.W	#2,D7
	MULS.W	D7,D1
	ASR.W	#6,D1
	ADD.W	D5,D1
	AND.W	#$FF,D1
	MOVE.W	(A1,D1.W*2),D1
	ADD.W	D1,(A6)+
	DBF	D0,FMXPhL
	MOVE.W	FMXQ,D1
FMXPhN:	ADDQ.W	#1,D1
	CMP.W	#4,D1
	BNE	FMXPhQ
	MOVE.L	(SP)+,D7
	RTS

; -------------------------------------> (5.4) A table less FMXLvl octaves.
; In: A0 = one of the 136 tables (15 built-in instruments, the custom one
; and the bass drum, 8 each: channel 7 fades from a drum's as rhythm mode
; ends). Out: A0 = it band-limited. Each level is the one before
; through (-1 0 9 16 9 0 -1) / 32 round the cycle, spread 1, 2, 4... entries
; (fm_synth level_table). Made when first wanted, kept in FMX_LVN slots
; reused in turn; FMXLvDir says which slot (+1) has [table * 5 + level - 1].
; Only A0 changes.
	CNOP	0,8
FMXLevel:
	TST.W	FMXLvl
	BNE.S	FMXLvGo
	RTS
FMXLvGo:
	MOVEM.L	D0-D7/A1-A4,-(SP)
	MOVE.L	A0,D0			; table number: built-in 0-119,
	SUB.L	A5,D0
	CMP.L	#15*8*256,D0
	BCS.S	FMXLvId
	SUB.L	#FMX_BDTAB,D0		; bass drum 128-135,
	CMP.L	#8*256,D0
	BCC.S	FMXLvCu
	ADD.L	#16*8*256,D0
	BRA.S	FMXLvId
FMXLvCu:MOVE.L	A0,D0			; custom 120-127.
	SUB.L	#FMXUser,D0
	ADD.L	#15*8*256,D0
FMXLvId:
	LSR.L	#8,D0
	MULU.W	#FMX_LVMAX,D0
	LEA	FMXLvDir,A2
	ADDA.L	D0,A2			; A2 = its directory entries
	MOVEQ	#1,D7			; D7 = this level's spread
	MOVE.W	FMXLvl,D6		; D6 = levels to go
FMXLvNxt:
	MOVEQ	#0,D0
	MOVE.B	(A2),D0
	BEQ.S	FMXLvNew
	SUBQ.W	#1,D0			; there already
	LSL.L	#8,D0
	LEA	FMXLvTab,A0
	ADDA.L	D0,A0
	BRA	FMXLvOn
FMXLvNew:
	MOVEQ	#0,D5
	MOVE.W	FMXLvNx,D5		; the next slot in turn, but never the
FMXLvSl:				; one being filtered.
	MOVE.L	D5,D0
	LSL.L	#8,D0
	LEA	FMXLvTab,A1
	ADDA.L	D0,A1			; A1 = the slot
	ADDQ.W	#1,D5
	AND.W	#FMX_LVN-1,D5
	CMPA.L	A0,A1
	BEQ.S	FMXLvSl
	MOVE.W	D5,FMXLvNx
	LSR.L	#8,D0			; D0 = slot: whoever had it hasn't now.
	LEA	FMXLvOwn,A3
	MOVEQ	#0,D1
	MOVE.W	(A3,D0.L*2),D1
	LEA	FMXLvDir,A4
	ADDA.L	D1,A4
	MOVE.W	D0,D2
	ADDQ.W	#1,D2
	CMP.B	(A4),D2
	BNE.S	FMXLvOw
	CLR.B	(A4)
FMXLvOw:
	MOVE.B	D2,(A2)
	MOVE.L	A2,D1
	SUB.L	#FMXLvDir,D1
	MOVE.W	D1,(A3,D0.L*2)

	MOVEQ	#0,D0			; D0 = entry i
	MOVEQ	#0,D4			; D4 = a wrapped index
FMXLvFl:MOVE.B	(A0,D0.W),D1		; 16 * u[i] + 16
	EXT.W	D1
	ASL.W	#4,D1
	ADD.W	#16,D1
	MOVE.B	D0,D4			; + 9 * (u[i+d] + u[i-d])
	ADD.B	D7,D4
	MOVE.B	(A0,D4.W),D2
	EXT.W	D2
	MOVE.B	D0,D4
	SUB.B	D7,D4
	MOVE.B	(A0,D4.W),D3
	EXT.W	D3
	ADD.W	D3,D2
	ADD.W	D2,D1
	ASL.W	#3,D2
	ADD.W	D2,D1
	MOVE.B	D0,D4			; - u[i+3d] - u[i-3d]
	ADD.B	D7,D4
	ADD.B	D7,D4
	ADD.B	D7,D4
	MOVE.B	(A0,D4.W),D2
	EXT.W	D2
	SUB.W	D2,D1
	MOVE.B	D0,D4
	SUB.B	D7,D4
	SUB.B	D7,D4
	SUB.B	D7,D4
	MOVE.B	(A0,D4.W),D2
	EXT.W	D2
	SUB.W	D2,D1
	ASR.W	#5,D1			; / 32, held in a byte.
	CMP.W	#127,D1
	BLE.S	FMXLvC1
	MOVEQ	#127,D1
FMXLvC1:
	CMP.W	#-128,D1
	BGE.S	FMXLvC2
	MOVEQ	#-128,D1
FMXLvC2:
	MOVE.B	D1,(A1,D0.W)
	ADDQ.W	#1,D0
	CMP.W	#256,D0
	BNE.S	FMXLvFl
	MOVE.L	A1,A0
FMXLvOn:
	ADDQ.L	#1,A2			; the next level: twice the spread.
	ADD.W	D7,D7
	SUBQ.W	#1,D6
	BNE	FMXLvNxt
	MOVEM.L	(SP)+,D0-D7/A1-A4
	RTS

; -------------------------------------> (5.4) The 2x mix down to N samples.
; Half-band filter (-1 0 9 16 9 0 -1) / 32, ending on every second sample;
; the last 6 samples are kept for the next frame. Held inside the clip
; tables' range (the filter can overshoot a full mix). Uses D0-D2, A0, A1.
	CNOP	0,8
FMXDown:
	LEA	FMXMix2H+2,A0
	LEA	FMXMix,A1
	MOVE.W	FMXN,D0
	SUBQ.W	#1,D0
FMXDnL:	MOVE.W	4(A0),D1
	EXT.L	D1
	MOVE.W	8(A0),D2
	EXT.L	D2
	ADD.L	D2,D1			; 9 * (b + d)
	MOVE.L	D1,D2
	LSL.L	#3,D1
	ADD.L	D2,D1
	MOVE.W	6(A0),D2		; + 16 * c
	EXT.L	D2
	LSL.L	#4,D2
	ADD.L	D2,D1
	MOVE.W	(A0),D2			; - a - e
	EXT.L	D2
	SUB.L	D2,D1
	MOVE.W	12(A0),D2
	EXT.L	D2
	SUB.L	D2,D1
	ASR.L	#5,D1
	CMP.W	#FMX_MIXMAX,D1
	BLE.S	FMXDn1
	MOVE.W	#FMX_MIXMAX,D1
FMXDn1:	CMP.W	#-FMX_MIXMAX,D1
	BGE.S	FMXDn2
	MOVE.W	#-FMX_MIXMAX,D1
FMXDn2:	MOVE.W	D1,(A1)+
	ADDQ.W	#4,A0
	DBF	D0,FMXDnL
	LEA	FMXMix2H,A1		; The last 6 for the next frame
	SUBQ.W	#2,A0			; (A0 was 2 past the first of them).
	MOVE.L	(A0)+,(A1)+
	MOVE.L	(A0)+,(A1)+
	MOVE.L	(A0)+,(A1)+
	RTS

; -------------------------------------> (5.4) No drum sounding. Uses D0, A0.
FMXDrQuiet:
	LEA	FMXDrGI,A0
	MOVEQ	#63,D0
	MOVE.W	D0,(A0)+
	MOVE.W	D0,(A0)+
	MOVE.W	D0,(A0)+
	MOVE.W	D0,(A0)+
	MOVE.W	D0,(A0)
	RTS

; -------------------------------------> (5.4) The five drums (Synth.drums).
; The chip's slots are the channels' own: ch 7 BD (both), ch 8 HH (modulator)
; and SD (carrier), ch 9 TOM (modulator) and CYM (carrier); so a key held
; into or out of rhythm mode carries on. Uses all but A5; A3 as on entry.
	CNOP	0,8
FMXRhythm:
	FMXDRKEYS
	MOVE.B	D1,FMXDrKey
	MOVE.B	FMXDrEv,FMXDrHit
	SF	FMXDrEv
	SF	FMXDrOn
	BTST	#2,FMXDrHit		; Key-on: BD, TOM and SD start their
	BEQ.S	FMXRy1			; phase; HH and CYM run on.
	CLR.L	FMXCh+8*CH_SIZE+CH_FRAC
FMXRy1:	BTST	#3,FMXDrHit
	BEQ.S	FMXRy2
	CLR.L	FMXDrPh+4
FMXRy2:
	MOVEQ	#6,D7			; BD's modulator: full at the key-on
	BSR	FMXDrChn		; (FMXBdHit plays its first millisecond),
	BTST	#4,FMXDrHit		; runs while the key is held.
	BEQ.S	FMXRy3
	CLR.L	CH_FRAC(A2)
	CLR.L	CH_TAB(A2)
	CLR.W	CH_MEG(A2)
	CLR.W	CH_MPOS(A2)
	MOVE.B	#ST_DEC,CH_MST(A2)
	BRA.S	FMXRy4
FMXRy3:	BTST	#4,FMXDrKey
	BEQ.S	FMXRy5
FMXRy4:	MOVE.L	A5,A4
	ADDA.L	#FMX_DRPATCH,A4
	MOVEQ	#1,D0
	MOVE.B	4(A4),D3
	MOVE.B	6(A4),D4
	MOVE.B	0(A4),D5
	BSR	FMXEnv
FMXRy5:
	LEA	FMXDrT,A6		; Each drum: key, envelope, gain index.
	LEA	FMXDrGI,A0
FMXRyD:	MOVE.W	(A0),FMXDrG0-FMXDrGI(A0)	; (last frame's)
	MOVEQ	#0,D7
	MOVE.B	(A6)+,D7
	BSR	FMXDrChn
	MOVE.L	A5,A4
	ADDA.L	#FMX_DRPATCH-6*8,A4
	LEA	(A4,D7.W*8),A4		; its patch
	MOVEQ	#0,D0
	MOVE.B	(A6)+,D0		; its slot
	MOVEQ	#0,D1
	MOVE.B	1(A6),D1		; its volume * 8
	MOVE.B	(A3,D1.W),D1
	TST.W	D0
	BEQ.S	FMXRyV
	LSR.B	#4,D1
FMXRyV:	AND.W	#$F,D1
	LSL.W	#3,D1
	MOVE.W	D1,D7			; D7 = volume
	MOVE.B	(A6),D2
	AND.B	FMXDrHit,D2
	BEQ.S	FMXRyNh
	MOVE.B	#ST_DEC,CH_CST(A2,D0.W)	; Key-on: every drum's attack (rates
	CLR.W	CH_CEG(A2,D0.W*2)	; 10-15) is over in 4 ms: full level
	CLR.W	CH_CPOS(A2,D0.W*2)	; from the frame's start.
	LSR.W	#1,D1
	MOVE.W	D1,FMXDrG0-FMXDrGI(A0)
FMXRyNh:
	MOVE.B	(A6),D2
	AND.B	FMXDrKey,D2
	BNE.S	FMXRyKy
	CMP.B	#ST_REL,CH_CST(A2,D0.W)	; No key: release.
	BCC.S	FMXRyKy
	MOVE.B	#ST_REL,CH_CST(A2,D0.W)
FMXRyKy:
	MOVEQ	#5,D3			; AR/DR, SL/RR, flags (carrier's +1)
	SUB.W	D0,D3
	MOVE.B	2(A4,D3.W),D4
	MOVE.B	-4(A4,D3.W),D5
	MOVE.B	(A4,D3.W),D3
	BSR	FMXEnv
	MOVEQ	#63,D1
	CMP.B	#ST_OFF,CH_CST(A2,D0.W)
	BEQ.S	FMXRyG
	MOVEQ	#0,D2
	MOVE.B	CH_CEG(A2,D0.W*2),D2
	ADD.W	D7,D2
	LSR.W	#1,D2
	CMP.W	D1,D2
	BCC.S	FMXRyG
	MOVE.W	D2,D1
FMXRyG:	MOVE.W	D1,(A0)+
	ADDQ.L	#2,A6
	CMPA.L	#FMXDrT+5*4,A6
	BNE	FMXRyD

	LEA	FMXCh+6*CH_SIZE,A2	; The channels' keys, for leaving rhythm
	MOVE.B	FMXDrKey,D0		; mode: BD, SD, CYM.
	BTST	#4,D0
	SNE	CH_MKEY(A2)
	SNE	CH_PKEY(A2)
	BTST	#3,D0
	SNE	CH_SIZE+CH_MKEY(A2)
	SNE	CH_SIZE+CH_PKEY(A2)
	BTST	#1,D0
	SNE	2*CH_SIZE+CH_MKEY(A2)
	SNE	2*CH_SIZE+CH_PKEY(A2)
	CLR.L	CH_SIZE+CH_TAB(A2)
	CLR.L	2*CH_SIZE+CH_TAB(A2)

	MOVE.L	#FMXVolD,FMXVolP	; Bass drum and tom-tom: 8 steps up.
	MOVE.W	FMXDrG0,D0		; Bass drum.
	MOVE.W	FMXDrGI,D1
	MOVE.W	D0,FMXG0
	MOVE.W	D1,FMXG1
	AND.W	D1,D0
	CMP.W	#63,D0
	BEQ	FMXRyT
	ST	FMXDrOn
	MOVEQ	#6,D7
	BSR	FMXDrChn
	MOVEQ	#0,D0
	MOVE.B	CH_MEG(A2),D0		; (at most 127; no key scaling)
	MOVE.B	FMX_MODLV(A5,D0.W),D0
	LSL.W	#8,D0
	MOVE.L	A5,A0
	ADDA.L	#FMX_BDTAB,A0
	ADDA.W	D0,A0			; A0 = table now,
	MOVE.L	CH_TAB(A2),A1		; A1 = last frame's.
	MOVE.L	A0,CH_TAB(A2)
	MOVE.L	A1,D0
	BNE.S	FMXRyBo
	MOVE.L	A0,A1
FMXRyBo:
	MOVEQ	#2,D3
	BSR	FMXDrStep
	BTST	#4,FMXDrHit
	BEQ.S	FMXRyBn
	MOVE.L	A0,FMXBdBase
	BSR	FMXBdHit
	MOVEQ	#6,D7
	BSR	FMXDrChn
	MOVE.L	FMXBdBase,A0
	MOVE.L	A0,A1			; (a key-on: one table)
	MOVEQ	#2,D3
	BSR	FMXDrStep
FMXRyBn:
	CMPA.L	A0,A1
	BEQ.S	FMXRyB1
	MOVE.L	A0,FMXTabNew
	MOVE.L	A1,A0
	LEA	FMXXOOld,A4
	BSR	FMXPass
	MOVE.L	FMXTabNew,A0
	LEA	FMXXONew,A4
	BSR	FMXPass
	BRA.S	FMXRyB2
FMXRyB1:
	LEA	FMXXO0,A4
	BSR	FMXPass
FMXRyB2:
	MOVE.W	D2,CH_FRAC(A2)
	MOVE.W	D4,CH_IDX(A2)

FMXRyT:	MOVE.W	FMXDrG0+3*2,D0		; Tom-tom: a sine, multiple 5.
	MOVE.W	FMXDrGI+3*2,D1
	MOVE.W	D0,FMXG0
	MOVE.W	D1,FMXG1
	AND.W	D1,D0
	CMP.W	#63,D0
	BEQ.S	FMXRyN
	ST	FMXDrOn
	MOVEQ	#8,D7
	BSR	FMXDrChn
	MOVEQ	#10,D3
	BSR	FMXDrStep
	MOVE.L	A5,A0
	ADDA.L	#FMX_TOMTAB,A0
	LEA	FMXXO0,A4
	BSR	FMXPass
	MOVE.W	D2,CH_FRAC(A2)
	MOVE.W	D4,CH_IDX(A2)

FMXRyN:	MOVE.L	#FMXVol,FMXVolP
	MOVEQ	#8,D7			; Hi-hat, snare, cymbal: their steps.
	BSR	FMXDrChn
	MOVEQ	#2,D3
	BSR	FMXDrStep
	MOVE.L	D1,-(SP)
	MOVEQ	#7,D7
	BSR	FMXDrChn
	MOVEQ	#2,D3
	BSR	FMXDrStep
	MOVE.L	D1,D3			; D3 = HH and SD's,
	MOVE.L	(SP)+,D4		; D4 = CYM's.
	MOVE.L	FMXDrPh,D0
	MOVE.L	FMXDrPh+4,D1
	MOVE.L	FMXDrPh+8,D2
	MOVE.W	FMXDrGI+1*2,D6		; All three silent: just the phases.
	AND.W	FMXDrG0+1*2,D6
	AND.W	FMXDrGI+2*2,D6
	AND.W	FMXDrG0+2*2,D6
	AND.W	FMXDrGI+4*2,D6
	AND.W	FMXDrG0+4*2,D6
	CMP.W	#63,D6
	BNE.S	FMXRyNs
	MOVEQ	#0,D6
	MOVE.W	FMXN,D6
	TST.B	FMXHQ
	BEQ.S	FMXRyN1
	ADD.W	D6,D6
FMXRyN1:
	MULU.L	D6,D3
	MULU.L	D6,D4
	ADD.L	D3,D0
	ADD.L	D3,D1
	ADD.L	D4,D2
	BRA	FMXRyNe
FMXRyNs:
	ST	FMXDrOn
	MOVE.L	FMXNoise,D5		; D5 = noise register
	LEA	FMXMix,A6
	TST.B	FMXHQ
	BEQ.S	FMXRyN2
	LEA	FMXMix2,A6
FMXRyN2:
	CLR.W	FMXQ			; By quarters (FMXQ):
FMXRyQ:
	MOVE.W	FMXDrGI+1*2,D6		; g = g0 + ((g1-g0)*(q+1) >> 2)
	SUB.W	FMXDrG0+1*2,D6
	MOVE.W	FMXQ,D7
	ADDQ.W	#1,D7
	MULS.W	D7,D6
	ASR.L	#2,D6
	ADD.W	FMXDrG0+1*2,D6
	MOVE.W	FMX_GAIN(A5,D6.W*2),D6
	MOVE.W	D6,FMXDrQg
	MOVE.W	FMXDrGI+2*2,D6
	SUB.W	FMXDrG0+2*2,D6
	MOVE.W	FMXQ,D7
	ADDQ.W	#1,D7
	MULS.W	D7,D6
	ASR.L	#2,D6
	ADD.W	FMXDrG0+2*2,D6
	MOVE.W	FMX_GAIN(A5,D6.W*2),D6
	MOVE.W	D6,FMXDrQg+2
	MOVE.W	FMXDrGI+4*2,D6
	SUB.W	FMXDrG0+4*2,D6
	MOVE.W	FMXQ,D7
	ADDQ.W	#1,D7
	MULS.W	D7,D6
	ASR.L	#2,D6
	ADD.W	FMXDrG0+4*2,D6
	MOVE.W	FMX_GAIN(A5,D6.W*2),D6
	MOVE.W	D6,FMXDrQg+4
	MOVE.L	FMXDrLev,A2		; the 8 sums of the three drums,
	LEA	FMXDrLut,A1
FMXRyLu:
	MOVE.W	(A2),D7
	MULS.W	FMXDrQg,D7
	ASR.L	#8,D7
	MOVE.W	16(A2),D6
	MULS.W	FMXDrQg+2,D6
	ASR.L	#8,D6
	ADD.W	D6,D7
	MOVE.W	32(A2),D6
	MULS.W	FMXDrQg+4,D6
	ASR.L	#8,D6
	ADD.W	D6,D7
	MOVE.W	D7,(A1)+
	ADDQ.L	#2,A2
	CMPA.L	#FMXDrLutE,A1
	BNE.S	FMXRyLu
	LEA	FMXDrLut,A1
	MOVE.W	FMXQ,D7
	MOVE.W	(FMXQsz-FMXDat,A5,D7.W*2),D7
	TST.B	FMXHQ
	BEQ.S	FMXRyN3
	ADD.W	D7,D7
FMXRyN3:
	LEA	(A6,D7.W*2),A2		; A2 = the quarter's end
	MOVE.L	A5,A0
	ADDA.L	#FMX_SHORT,A0
	BRA.S	FMXRyLc
	CNOP	0,4
FMXRyL:	ADD.L	D3,D0			; Phases (2^24 a cycle), then
	ADD.L	D3,D1
	ADD.L	D4,D2
	MOVE.L	D0,D6			; short noise from HH's phase bits 2-7
	SWAP	D6			; and CYM's 3-5,
	AND.W	#63,D6
	MOVE.L	D2,D7
	SWAP	D7
	AND.W	#$E,D7
	LSL.W	#5,D7
	OR.W	D7,D6
	MOVEQ	#0,D7
	MOVE.B	(A0,D6.W),D7		; (4 or 0)
	BTST	#22,D1			; SD's phase bit 8,
	BEQ.S	FMXRyL1
	ADDQ.W	#2,D7
FMXRyL1:
	LSR.L	#1,D5			; the noise bit.
	BCC.S	FMXRyL2
	EOR.L	#$400100,D5
	ADDQ.W	#1,D7
FMXRyL2:
	MOVE.W	(A1,D7.W*2),D6
	ADD.W	D6,(A6)+
FMXRyLc:
	CMPA.L	A2,A6
	BNE.S	FMXRyL
	MOVE.W	FMXQ,D6
	ADDQ.W	#1,D6
	MOVE.W	D6,FMXQ
	CMP.W	#4,D6
	BNE	FMXRyQ
	MOVE.L	D5,FMXNoise
FMXRyNe:
	MOVE.L	D0,FMXDrPh
	MOVE.L	D1,FMXDrPh+4
	MOVE.L	D2,FMXDrPh+8

	TST.B	FMXHQ			; Five drums at twice the gain can pass
	BNE.S	FMXRyX			; the output table (FMXDown holds the 2x
	TST.B	FMXDrOn			; mix inside it).
	BEQ.S	FMXRyX
	LEA	FMXMix,A0
	MOVE.W	#FMX_MIXMAX,D1
	MOVE.W	#-FMX_MIXMAX,D2
	MOVE.W	FMXN,D0
	SUBQ.W	#1,D0
FMXRyC:	MOVE.W	(A0)+,D3
	CMP.W	D1,D3
	BGT.S	FMXRyCh
	CMP.W	D2,D3
	BLT.S	FMXRyCl
	DBF	D0,FMXRyC
	RTS
FMXRyCh:
	MOVE.W	D1,-2(A0)
	DBF	D0,FMXRyC
	RTS
FMXRyCl:
	MOVE.W	D2,-2(A0)
	DBF	D0,FMXRyC
FMXRyX:	RTS

; OUT 7Dh to 0Eh or 26h-28h (from O7DDr): D2.B = value, A4 = the register.
;  A drum key going off -> on is kept until the next frame.
FMXDrWr:
	FMXDRKEYS
	MOVE.B	D1,FMXDrWas
	MOVE.B	D2,(A4)
	FMXDRKEYS
	MOVE.B	FMXDrWas,D2
	NOT.B	D2
	AND.B	D1,D2
	OR.B	D2,FMXDrEv
	RTS

; D7.W = channel (6-8) -> A2, FMXFn, FMXBlk, FMXR20, D6.W = bf. Uses D1, D2.
FMXDrChn:
	MOVE.W	D7,D1
	MULU.W	#CH_SIZE,D1
	LEA	FMXCh,A2
	ADDA.L	D1,A2
	MOVEQ	#0,D1
	MOVE.B	$10(A3,D7.W),D1
	MOVE.B	$20(A3,D7.W),D2
	MOVE.B	D2,FMXR20
	BTST	#0,D2
	BEQ.S	FMXDcF
	BSET	#8,D1
FMXDcF:	MOVE.W	D1,FMXFn
	MOVEQ	#$F,D6
	AND.W	D2,D6			; (block, F-number bit 8)
	LSR.B	#1,D2
	AND.W	#7,D2
	MOVE.W	D2,FMXBlk
	RTS

; D3.L = g, FMXFn, FMXBlk -> D1 and FMXStep = the step, as FMXPass wants
; it also in D3.W and D6.B. Uses D2.
FMXDrStep:
	MOVEQ	#0,D1
	MOVE.W	FMXFn,D1
	MOVE.W	FMXBlk,D2
	LSL.L	D2,D1
	MULU.L	D3,D1
	MULU.L	FMXK,D1
	LSR.L	#4,D1
	TST.B	FMXHQ
	BEQ.S	FMXDsN
	LSR.L	#1,D1
FMXDsN:	MOVE.L	D1,FMXStep
	MOVE.W	D1,D3
	MOVE.L	D1,D6
	SWAP	D6
	RTS

; BD key-on: its first 32 samples from the tables of the modulator's attack
; and decay (FMX_BDHIT), added as the difference from the voice's one table
; (FMXBdBase), from phase 0 as the voice. D3.W, D6.B = step.
; Uses D0-D7, A0-A2, A4, A6.
FMXBdHit:
	MOVE.W	FMXG1,D0		; The first quarter's gain.
	SUB.W	FMXG0,D0
	EXT.L	D0
	ASR.L	#2,D0
	ADD.W	FMXG0,D0
	CMP.W	#63,D0
	BCC	FMXBhX
	MOVE.L	FMXVolP,A1
	LSL.W	#8,D0
	ADD.W	D0,D0
	ADDA.W	D0,A1
	MOVEQ	#0,D0			; The row: key scaling (bf >> 2).
	MOVE.B	$26(A3),D0
	AND.W	#$F,D0
	LSR.W	#2,D0
	LSL.W	#5,D0
	MOVE.L	FMXBdRow,A4
	ADDA.W	D0,A4
	MOVE.L	A5,A2
	ADDA.L	#FMX_BDTAB,A2
	LEA	FMXMix,A6
	TST.B	FMXHQ
	BEQ.S	FMXBh1
	LEA	FMXMix2,A6
FMXBh1:	MOVEQ	#0,D2
	MOVEQ	#0,D4
	MOVE.W	#32-1,FMXQ
FMXBhL:	ADD.W	D3,D2
	ADDX.B	D6,D4
	MOVEQ	#0,D1
	MOVE.B	(A4)+,D1
	LSL.W	#8,D1
	MOVE.B	D4,D1
	MOVE.L	A2,A0
	BSR.S	FMXBhS
	MOVE.W	D5,D0
	MOVE.W	D4,D1
	MOVE.L	FMXBdBase,A0
	BSR.S	FMXBhS
	SUB.W	D5,D0
	ADD.W	D0,(A6)+
	SUBQ.W	#1,FMXQ
	BPL.S	FMXBhL
FMXBhX:	RTS
; A0 = table, D1.W = index, D2.W = fraction -> D5.W, at this gain.
FMXBhS:	MOVE.B	(A0,D1.W),D5
	EXT.W	D5
	TST.B	FMXHQ
	BEQ.S	FMXBhT
	ADDQ.B	#1,D1
	MOVE.B	(A0,D1.W),D1
	EXT.W	D1
	SUB.W	D5,D1
	MOVE.W	D2,D7
	LSR.W	#8,D7
	LSR.W	#2,D7
	MULS.W	D7,D1
	ASR.W	#6,D1
	ADD.W	D1,D5
FMXBhT:	AND.W	#$FF,D5
	MOVE.W	(A1,D5.W*2),D5
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
	BNE	FMXEnNa
	MOVE.B	D3,D1			; Attack: next value of the curve for
	LSR.B	#4,D1			; this rate (255 = hold, 0 = done).
	AND.W	#$F,D1
	BSR	FMXRix
	TST.W	D0			; (5.4) The modulator's attack at rate 15
	BEQ.S	FMXEnA1			; takes no time on the chip: it decays from
	CMP.W	#15*4,D1		; the key-on, so this frame has its decay.
	BCS.S	FMXEnA1			; (Else a note held for under two frames
	TST.W	CH_CPOS(A2,D0.W*2)	; froze it at full level: Illusion City's
	BNE.S	FMXEnA1			; instrument 12, 3-7 dB too bright.)
	CLR.W	CH_CEG(A2,D0.W*2)
	MOVE.B	#ST_DEC,CH_CST(A2,D0.W)
	MOVEQ	#ST_DEC,D2
	BRA	FMXEnNa
FMXEnA1:
	ADD.W	D1,D1
	MOVE.W	FMX_ATTOFF+2(A5,D1.W),D2	; (4.7) This curve's length: the rate
	MOVE.W	FMX_ATTOFF(A5,D1.W),D1	; can change mid-attack (patch, pitch)
	SUB.W	D1,D2			; to a shorter curve; past its end the
	LEA	FMX_ATT(A5,D1.W),A1	; attack is done.
	CMP.W	CH_CPOS(A2,D0.W*2),D2
	BLS.S	FMXEnAz
	MOVE.W	CH_CPOS(A2,D0.W*2),D2
	MOVE.B	(A1,D2.W),D1
	CMP.B	#$FF,D1
	BEQ	FMXEnR
	ADDQ.W	#1,D2
	MOVE.W	D2,CH_CPOS(A2,D0.W*2)
	TST.B	D1
	BNE.S	FMXEnAs
FMXEnAz:
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
	LSL.W	#8,D2			; (4.7) Stop at SL: a frame's step can be
	LSL.W	#3,D2			; much bigger than the distance left (a
	MOVE.W	D2,CH_CEG(A2,D0.W*2)	; fast DR with SL 0 silenced a
	MOVE.B	#ST_SUS,CH_CST(A2,D0.W)	; harpsichord in a frame or two).
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

	INCLUDE	"AmiMSX_Psx_v4.asm"	; (4.7) Sound mix: the PSG in software.
