;	 --------------------------------------------------
;	- PSX: the PSG in software, mixed with FMX, v4.7 -
;	 --------------------------------------------------
;
; Sound mix (Emulation > Sound Mix, with Sound chip PSG+FM): the PSG (YM2149)
; is made here and mixed with the FMX voices into one 14-bit stream, in the
; centre (Mono) or with the PSG's channels spread a little (Stereo), on all
; four Paula channels: 3 and 2 carry the high byte at volume 64, 0 and 1 the
; low 6 bits at volume 1 (left: 3 + 0, right: 2 + 1). Classic leaves the PSG
; on Paula's voices 0-2 and FMX on channel 3, as before.
;
; The spec, step for step and in the same integer arithmetic, is
; tools/psg_synth.py (class Psg, knee, the AGC_* constants); its tables are
; Sound/psx.i. tools/psg_compare.py and tools/mix_compare.py check the model
; against openMSX. OUTA1 logs the game's register writes (PsgLog: register,
; value, CurLine, the line's cycle count) and PsxFrame plays them at their
; sample: the frame runs from line 192 (Emula1Frame) to line 192.
;
; Called from FMXFrame (all registers saved there); uses D0-D7, A0-A6.

	INCLUDE	"Sound/psx.i"

PSGLOGMAX=1024		; PSG writes a frame (8 bytes each; more are dropped,
			; the registers then catch up at the frame's end)
PSX_TPAL=313*228*4096	; tone ticks (Z80 clock / 16) an MSX frame, 16.16
PSX_TNTSC=262*228*4096
PX_PER=0		; channel: tone period (ticks 16.16)
PX_CNT=4		; counter (ticks 16.16)
PX_OUT=8		; output (0 or FFh)
PX_SIZE=12

; -------------------------------------> Reset (from FMXInit, Sound mix on).
; The noise sequence and bit counts (first time), the registers from the
; PSG's, the envelope held, the high-pass and the gain at rest.
	CNOP	0,4
PsxInit:
	TST.B	PsxTabOK
	BNE.S	PsxInT
	LEA	PsxNoiseTab,A0		; openMSX's LFSR from 1, bit by bit
	MOVEQ	#1,D2			; (bit 0 of BFEXTU offset 0 = the MSB of
	MOVEQ	#0,D1			; the first byte), and 32 bits past the
PsxInN:	MOVE.L	D2,D0			; end so a count never wraps.
	AND.L	#1,D0
	BFINS	D0,(A0){D1:1}
	LSR.L	#1,D2
	TST.L	D0
	BEQ.S	PsxInN1
	EOR.L	#$12000,D2		; (bit 0 into bits 13 and 16)
PsxInN1:ADDQ.L	#1,D1
	CMP.L	#PSX_NOISELEN+32,D1
	BNE.S	PsxInN
	LEA	PsxPop,A0		; Ones in each byte value.
	MOVEQ	#0,D0
PsxInP:	MOVE.W	D0,D1
	MOVEQ	#0,D2
PsxInP1:LSR.B	#1,D1
	BCC.S	PsxInP2
	ADDQ.B	#1,D2
PsxInP2:TST.B	D1
	BNE.S	PsxInP1
	MOVE.B	D2,(A0)+
	ADDQ.W	#1,D0
	CMP.W	#256,D0
	BNE.S	PsxInP
	ST	PsxTabOK
PsxInT:
	LEA	PsxCh,A0		; Channels: period 1, counter 0, low.
	MOVEQ	#3-1,D0
PsxInC:	MOVE.L	#1<<16,PX_PER(A0)
	CLR.L	PX_CNT(A0)
	CLR.B	PX_OUT(A0)
	LEA	PX_SIZE(A0),A0
	DBF	D0,PsxInC
	CLR.L	PsxNpos
	MOVE.L	#1<<14,PsxEper
	CLR.L	PsxEcnt
	MOVE.W	#$1F,PsxEstep
	CLR.W	PsxEatt
	ST	PsxEhold
	SF	PsxEalt
	ST	PsxEheld
	CLR.L	PsxXL
	CLR.L	PsxXR
	CLR.L	PsxYL
	CLR.L	PsxYR
	MOVE.W	#PSX_AGCK0,PsxMxK
	CLR.W	PsxMxN
	CLR.W	PsgLogN
	MOVE.L	#PSX_TPAL,D0		; T for a PAL frame at this N (PsxFrame
	MOVEQ	#0,D1			; redoes it each frame from the nominal
	MOVE.W	FMXN,D1			; N, set at the first restart).
	DIVU.L	D1,D0
	BSR	PsxSetT
	MOVE.B	#$BF,PsxR+7
	LEA	REGS+PSG,A1		; The PSG's registers 0-12; 13 kept
	MOVEQ	#0,D0			; without a restart.
PsxInR:	MOVE.B	(A1,D0.W),D1
	MOVEM.L	D0/A1,-(SP)
	BSR	PsxWrite
	MOVEM.L	(SP)+,D0/A1
	ADDQ.W	#1,D0
	CMP.W	#13,D0
	BNE.S	PsxInR
	MOVE.B	13(A1),PsxR+13
	IFD	PSXREC
	TST.L	PsxRecEP		; (check build: first start only) the
	BNE.S	PsxInRc			; registers at the start.
	MOVE.L	#PsxRecE,PsxRecEP
	MOVE.L	#PsxRecO,PsxRecOP
	MOVE.L	PsxR,PsxRecInit
	MOVE.L	PsxR+4,PsxRecInit+4
	MOVE.L	PsxR+8,PsxRecInit+8
	MOVE.L	PsxR+12,PsxRecInit+12
PsxInRc:
	ENDC
	RTS

; -------------------------------------> T (D0.L, tone ticks a sample 16.16):
; 1/T for the tone fraction and the noise step. Uses D0-D2.
PsxSetT:
	MOVE.L	D0,PsxT
	MOVEQ	#1,D1			; 2^32 / T
	MOVEQ	#0,D2
	DIVU.L	D0,D1:D2
	MOVE.W	D2,PsxInvT
PsxSetN:
	MOVE.L	PsxT,D0			; Noise: bits a sample, 18.14 =
	LSR.L	#2,D0			; (T >> 2) / (2 * period).
	MOVEQ	#$1F,D1
	AND.B	PsxR+6,D1
	BNE.S	PsxSN1
	MOVEQ	#1,D1
PsxSN1:	ADD.L	D1,D1
	DIVU.L	D1,D0
	MOVE.L	D0,PsxNdn
	RTS

; -------------------------------------> A register write: D0.W = register
; (0-13), D1.B = value (Psg.write). Uses D0-D3, A3.
PsxWrite:
	LEA	PsxR,A3
	MOVE.B	D1,(A3,D0.W)
	CMP.W	#6,D0
	BCS.S	PsxWTone
	BEQ.S	PsxSetN
	CMP.W	#11,D0
	BCS.S	PsxWR
	CMP.W	#13,D0
	BCS.S	PsxWEnv
	BEQ.S	PsxWShape
PsxWR:	RTS
PsxWTone:				; Tone period: max(1, fine + 256 *
	LSR.W	#1,D0			; (coarse & 15)) << 16; the counter
	MOVEQ	#$F,D3			; below it.
	AND.B	1(A3,D0.W*2),D3
	LSL.W	#8,D3
	MOVE.B	(A3,D0.W*2),D3
	TST.W	D3
	BNE.S	PsxWT1
	MOVEQ	#1,D3
PsxWT1:	SWAP	D3
	CLR.W	D3
	MULU.W	#PX_SIZE,D0
	LEA	(PsxCh.L,D0.W),A3
	MOVE.L	D3,PX_PER(A3)
	CMP.L	PX_CNT(A3),D3
	BHI.S	PsxWR
	SUBQ.L	#1,D3
	MOVE.L	D3,PX_CNT(A3)
	RTS
PsxWEnv:				; Envelope period: max(1, R#11 + 256 *
	MOVEQ	#0,D3			; R#12) << 14; the counter below it.
	MOVE.B	12(A3),D3
	LSL.W	#8,D3
	MOVE.B	11(A3),D3
	TST.W	D3
	BNE.S	PsxWE1
	MOVEQ	#1,D3
PsxWE1:	MOVEQ	#14,D2
	LSL.L	D2,D3
	MOVE.L	D3,PsxEper
	CMP.L	PsxEcnt,D3
	BHI.S	PsxWR
	SUBQ.L	#1,D3
	MOVE.L	D3,PsxEcnt
	RTS
PsxWShape:				; Shape: attack (bit 2), hold and
	CLR.W	PsxEatt			; alternate, or with continue off
	BTST	#2,D1			; hold, alternating when attacking;
	BEQ.S	PsxWS1			; the envelope restarts from step 31.
	MOVE.W	#$1F,PsxEatt
PsxWS1:	BTST	#3,D1
	BNE.S	PsxWS2
	ST	PsxEhold
	TST.W	PsxEatt
	SNE	PsxEalt
	BRA.S	PsxWS3
PsxWS2:	BTST	#0,D1
	SNE	PsxEhold
	BTST	#1,D1
	SNE	PsxEalt
PsxWS3:	MOVE.W	#$1F,PsxEstep
	SF	PsxEheld
	RTS

; -------------------------------------> Envelope: D1.W steps on
; (Psg._env_steps). Uses D0.
PsxEnvSteps:
	MOVE.W	PsxEstep,D0
	SUB.W	D1,D0
	BPL.S	PsxES9
	TST.B	PsxEhold
	BEQ.S	PsxES2
	TST.B	PsxEalt
	BEQ.S	PsxES1
	EOR.W	#$1F,PsxEatt
PsxES1:	ST	PsxEheld
	MOVEQ	#0,D0
	BRA.S	PsxES9
PsxES2:	TST.B	PsxEalt
	BEQ.S	PsxES3
	BTST	#4,D0
	BEQ.S	PsxES3
	EOR.W	#$1F,PsxEatt
PsxES3:	AND.W	#$1F,D0
PsxES9:	MOVE.W	D0,PsxEstep
	RTS

; -------------------------------------> Tone: the fraction of this sample
; the channel at A3 was high, 0-256, in D0 (Psg._tone: a box filter). Four
; flips or more a sample: 128. Uses D0-D3, A6.
PsxTone:
	MOVE.L	PsxT,D3
	MOVE.L	PX_PER(A3),D1
	MOVE.L	D3,D0
	LSR.L	#2,D0
	CMP.L	D0,D1
	BHI.S	PsxTo1
	MOVE.L	#128,D0
	RTS
PsxTo1:	MOVE.L	PX_CNT(A3),D2
	SUBA.L	A6,A6			; A6 = time high (ticks 16.16)
PsxToL:	MOVE.L	D1,D0
	SUB.L	D2,D0			; D0 = ticks left to the next flip
	CMP.L	D0,D3
	BCS.S	PsxToE			; (the sample ends first)
	TST.B	PX_OUT(A3)
	BEQ.S	PsxTo2
	ADDA.L	D0,A6
PsxTo2:	SUB.L	D0,D3
	MOVEQ	#0,D2
	NOT.B	PX_OUT(A3)
	BRA.S	PsxToL
PsxToE:	ADD.L	D3,D2
	TST.B	PX_OUT(A3)
	BEQ.S	PsxTo3
	ADDA.L	D3,A6
PsxTo3:	MOVE.L	D2,PX_CNT(A3)
	MOVE.L	A6,D0			; ((high >> 8) * 2^32/T) >> 16
	LSR.L	#8,D0
	MULU.W	PsxInvT,D0
	CLR.W	D0
	SWAP	D0
	RTS

; -------------------------------------> Noise: the fraction of this
; sample's bits that were 1, 0-256, in D4 (Psg._noise). Uses D0-D3, A6.
PsxNoise:
	MOVE.L	PsxNpos,D0
	MOVE.L	D0,D1
	MOVEQ	#14,D3
	LSR.L	D3,D1			; D1 = p0
	ADD.L	PsxNdn,D0
	MOVE.L	D0,D2
	LSR.L	D3,D2			; D2 = p1
	CMP.L	#PSX_NOISELEN,D2
	BCS.S	PsxNo1
	SUB.L	#PSX_NOISELEN<<14,D0
PsxNo1:	MOVE.L	D0,PsxNpos
	LEA	PsxNoiseTab,A6
	SUB.L	D1,D2			; D2 = bits gone by
	BNE.S	PsxNo2
	MOVEQ	#0,D4			; None: the current bit.
	BFTST	(A6){D1:1}
	BEQ.S	PsxNoR
	MOVE.L	#256,D4
PsxNoR:	RTS
PsxNo2:	CMP.L	#32,D2
	BLS.S	PsxNo3
	MOVEQ	#32,D2
PsxNo3:	BFEXTU	(A6){D1:D2},D3		; (width 32 = 0: the same)
	LEA	PsxPop,A6
	MOVEQ	#0,D4
	MOVEQ	#4-1,D1
PsxNoC:	MOVEQ	#0,D0
	MOVE.B	D3,D0
	ADD.B	(A6,D0.W),D4
	LSR.L	#8,D3
	DBF	D1,PsxNoC
	LSL.W	#8,D4			; (ones << 8) / bits
	DIVU.W	D2,D4
	AND.L	#$FFFF,D4
	RTS

; -------------------------------------> One PSG channel into D5 (left) and
; D6 (right): \1 = channel. D4 = noise fraction, PsxEv = envelope level.
PSXCH	MACRO
	MOVE.L	#256,D0
	BTST	#\1,PsxR+7		; Tone off: high all the time.
	BNE.S	\@tf
	LEA	PsxCh+\1*PX_SIZE,A3
	BSR	PsxTone
\@tf:	MOVEQ	#0,D1
	MOVE.B	PsxR+8+\1,D1
	BTST	#4,D1
	BEQ.S	\@fx
	MOVE.W	PsxEv,D1
	BRA.S	\@am
\@fx:	AND.W	#15,D1
	MOVE.W	(PsxVol.L,D1.W*2),D1
\@am:	BTST	#\1+3,PsxR+7		; Noise on: tone fraction x noise's.
	BNE.S	\@nn
	MULU.W	D4,D0
	LSR.L	#8,D0
\@nn:	MULU.W	D1,D0
	LSR.L	#8,D0
	TST.B	PsxStereo
	BNE.S	\@st
	ADD.L	D0,D5
	BRA.S	\@x
\@st:	MOVE.L	D0,D1
	MULU.W	#PSXPL\1,D1
	ADD.L	D1,D5
	MULU.W	#PSXPR\1,D0
	ADD.L	D0,D6
\@x:
	ENDM
PSXPL0=6		; Stereo: each channel's share of the left and right
PSXPR0=2		; side in quarters (Psg PAN_STEREO); Mono is 4 and 4,
PSXPL1=4		; so the sum as it is.
PSXPR1=4
PSXPL2=2
PSXPR2=6

; High-pass (about 10 Hz): y += (x - x') << 8 - y >> 8; out y >> 8.
PSXHP	MACRO	; \1 = input/output register, \2 = PsxX?, \3 = PsxY?
	MOVE.L	\1,D0
	SUB.L	\2,D0
	MOVE.L	\1,\2
	LSL.L	#8,D0
	MOVE.L	\3,D1
	MOVE.L	D1,D2
	ASR.L	#PSX_HPSHIFT,D2
	ADD.L	D0,D1
	SUB.L	D2,D1
	MOVE.L	D1,\3
	ASR.L	#8,D1
	MOVE.L	D1,\1
	ENDM

; -------------------------------------> One output sample (Psg.sample):
; D5 = left, D6 = right (mono: D5), in FM mix units. Uses D0-D6, A3, A6.
PsxSample:
	MOVE.L	#256,D4
	MOVE.B	PsxR+7,D0
	AND.B	#$38,D0
	CMP.B	#$38,D0
	BEQ.S	PsxSa1
	BSR	PsxNoise
PsxSa1:	MOVE.W	PsxEstep,D0
	MOVE.W	PsxEatt,D1
	EOR.W	D1,D0
	MOVE.W	(PsxEnv.L,D0.W*2),PsxEv
	MOVEQ	#0,D5
	MOVEQ	#0,D6
	PSXCH	0
	PSXCH	1
	PSXCH	2
	TST.B	PsxEheld		; Envelope: on by T, steps of eper.
	BNE.S	PsxSa3
	MOVE.L	PsxT,D0
	LSR.L	#2,D0
	ADD.L	PsxEcnt,D0
	MOVE.L	PsxEper,D1
	CMP.L	D1,D0
	BCC.S	PsxSa2
	MOVE.L	D0,PsxEcnt
	BRA.S	PsxSa3
PsxSa2:	DIVUL.L	D1,D2:D0		; D0 = steps, D2 = the rest
	MOVE.L	D2,PsxEcnt
	MOVE.W	D0,D1
	BSR	PsxEnvSteps
PsxSa3:	TST.B	PsxStereo
	BEQ.S	PsxSa4
	LSR.L	#2,D5
	LSR.L	#2,D6
	PSXHP	D6,PsxXR,PsxYR
PsxSa4:	PSXHP	D5,PsxXL,PsxYL
	RTS

; -------------------------------------> Once a frame, from FMXFrame (the FM
; voices are in FMXMix): this frame's PSG writes at their samples, the PSG
; into PsxBufL/R, then the mix out to the four rings.
	CNOP	0,4
PsxFrame:
	MOVE.L	#PSX_TPAL,D0		; T from the MSX frame (50 or 60 Hz)
	MOVE.W	#313,D7			; and the nominal N.
	BTST	#1,REGS+DVDP9
	BNE.S	PsxFr1
	MOVE.L	#PSX_TNTSC,D0
	MOVE.W	#262,D7
PsxFr1:	MOVE.W	D7,PsxVP
	MOVEQ	#0,D1
	MOVE.W	FMXNnom,D1
	DIVU.L	D1,D0
	CMP.L	PsxT,D0
	BEQ.S	PsxFr2
	BSR	PsxSetT
PsxFr2:
; Each write's sample: its cycle in the frame (from line 192) * N / the
; frame's cycles. Line k (0-254) ends at (k+1)*228; line 255 is the rest of
; the frame in one go (MiraInter255); (A3) counts the line's cycles down.
	LEA	PsgLog,A0
	MOVE.W	PsgLogN,D6
	LSR.W	#3,D6
	BEQ.S	PsxFrE
	SUBQ.W	#1,D6
	MOVE.W	PsxVP,D5
	MULU.W	#HPeriod,D5		; D5 = the frame's cycles
PsxFrI:	MOVEQ	#0,D0
	MOVE.B	3(A0),D0		; (CurLine: its low byte)
	CMP.W	#255,D0
	BNE.S	PsxFrI1
	MOVE.W	PsxVP,D0		; the rest of the frame: VP lines
	SUBQ.W	#1,D0
PsxFrI1:ADDQ.W	#1,D0
	MULU.W	#HPeriod,D0		; end of the line
	SUB.L	#192*HPeriod,D0		; from line 192 (line 191 ends the
	BGT.S	PsxFrI2			; frame)
	ADD.L	D5,D0
PsxFrI2:MOVE.W	4(A0),D1
	EXT.L	D1
	BPL.S	PsxFrI3			; (overdrawn: at the line's end)
	MOVEQ	#0,D1
PsxFrI3:SUB.L	D1,D0
	BPL.S	PsxFrI4
	MOVEQ	#0,D0
PsxFrI4:CMP.L	D5,D0
	BCS.S	PsxFrI5
	MOVE.L	D5,D0
	SUBQ.L	#1,D0
PsxFrI5:MOVEQ	#0,D1
	MOVE.W	FMXN,D1
	MULU.L	D1,D0
	DIVU.L	D5,D0
	MOVE.W	D0,6(A0)
	ADDQ.W	#8,A0
	DBF	D6,PsxFrI
PsxFrE:	MOVE.W	#$7FFF,6(A0)		; (end: no sample reaches it)

; The samples, applying writes as their sample comes (Psg.frame).
	LEA	PsgLog,A2
	LEA	PsxBufL,A0
	LEA	PsxBufR,A1
	MOVEQ	#0,D7
PsxFrS:	CMP.W	6(A2),D7
	BCS.S	PsxFrS1
	BSR	PsxFrW
	BRA.S	PsxFrS
PsxFrS1:BSR	PsxSample
	MOVE.W	D5,(A0)+
	MOVE.W	D6,(A1)+
	ADDQ.W	#1,D7
	CMP.W	FMXN,D7
	BCS.S	PsxFrS
PsxFrS2:CMP.W	#$7FFF,6(A2)		; Writes for past the end (rounding):
	BEQ.S	PsxFrS3			; applied now.
	BSR	PsxFrW
	BRA.S	PsxFrS2
PsxFrS3:CMP.W	#PSGLOGMAX*8,PsgLogN	; Log full: some writes were dropped;
	BCS.S	PsxFrS4			; the registers as they are now.
	MOVEQ	#0,D0
PsxFrS5:MOVE.B	(REGS+PSG.L,D0.W),D1
	CMP.B	(PsxR.L,D0.W),D1
	BEQ.S	PsxFrS6
	MOVE.W	D0,-(SP)
	BSR	PsxWrite
	MOVE.W	(SP)+,D0
PsxFrS6:ADDQ.W	#1,D0
	CMP.W	#14,D0
	BNE.S	PsxFrS5
PsxFrS4:CLR.W	PsgLogN
	BRA	PsxOut

; The write at A2 (register, value) and on to the next.
PsxFrW:	MOVEQ	#0,D0
	MOVE.B	(A2),D0
	MOVE.B	1(A2),D1
	IFD	PSXREC
	MOVE.L	PsxRecEP,A3		; (check build) frame, sample, register,
	CMP.L	#PsxRecEEnd,A3		; value.
	BCC.S	PsxFrWr
	MOVE.W	FMXFrN,(A3)+
	MOVE.W	6(A2),(A3)+
	MOVE.B	D0,(A3)+
	MOVE.B	D1,(A3)+
	CLR.W	(A3)+
	MOVE.L	A3,PsxRecEP
PsxFrWr:
	ENDC
	BSR	PsxWrite
	ADDQ.W	#8,A2
	RTS

; -------------------------------------> The mix out: FM + PSG, times the
; gain (Q8), the knee, split into the high byte and low 6 bits for the
; next ring block; then the automatic gain from the frame's peak.
PsxOut:
	MOVE.W	FMXWrite,D2
	CMP.W	FMXPlay,D2
	BEQ	PsxOuFull
	MOVE.W	D2,D0
	MULU	#FMXRBSZ,D0
	MOVE.L	D0,PsxBlk
	MOVEQ	#0,D7			; D7 = the frame's peak |mix|
	LEA	FMXBuf,A1		; Left: FM + PSG left into rings 3 (high)
	LEA	FMXBufLL,A2		; and 0 (low).
	ADD.L	D0,A1
	ADD.L	D0,A2
	LEA	PsxBufL,A3
	BSR	PsxOutSide
	TST.B	PsxStereo
	BEQ.S	PsxOu1
	MOVE.L	PsxBlk,D0		; Right (Stereo): rings 2 and 1.
	LEA	FMXBufHR,A1
	LEA	FMXBufLR,A2
	ADD.L	D0,A1
	ADD.L	D0,A2
	LEA	PsxBufR,A3
	BSR	PsxOutSide
PsxOu1:	MOVE.W	FMXWrite,D2
	MOVE.W	FMXN,(FMXLen,D2.W*2)	; (length first: FMXAud reads it once
	ADDQ.W	#1,D2			; FMXWrite has moved on)
	AND.W	#7,D2
	MOVE.W	D2,FMXWrite
	BRA	PsxOu2
PsxOu2:	LSR.L	#4,D7
	MOVE.L	D7,D5
	BSR	PsxAgc
PsxOu3:
	IFD	PSXREC
	ADDQ.W	#1,FMXFrN		; (FMXREC's frame count)
	ENDC
	RTS
PsxOuFull:
	ADDQ.W	#1,FMXOver		; (Ring full: this frame is dropped,
	BRA.S	PsxOu3			; the gain as it was.)

; One side: A3 = PSG samples, FMXMix the FM, out to A1 (high) and A2 (low).
; D7 = the peak so far. Uses D0-D3, A0.
PsxOutSide:
	LEA	FMXMix,A0
	MOVE.W	PsxMxK,D3
	MOVE.W	(PsxAgcQ8.L,D3.W*2),D3
	EXT.L	D3
	MOVE.W	FMXN,D2
	SUBQ.W	#1,D2
	IFD	PSXREC
	MOVE.L	PsxRecOP,A4		; (check build) N, then the 14-bit
	CMP.L	#PsxRecOEnd-1024,A4	; samples of each side (FM, PSG, out).
	BCC.S	PsxOSr
	MOVE.W	FMXN,(A4)+
PsxOSr:
	ENDC
PsxOSL:	MOVE.W	(A0)+,D0
	EXT.L	D0
	MOVE.W	(A3)+,D1
	EXT.L	D1
	IFD	PSXREC
	CMP.L	#PsxRecOEnd-1024,A4	; (check build) FM, PSG, then the
	BCC.S	PsxOSr1			; output below.
	MOVE.W	D0,(A4)+
	MOVE.W	D1,(A4)+
PsxOSr1:
	ENDC
	ADD.L	D1,D0			; FM + PSG
	MOVE.L	D0,D1
	BPL.S	PsxOS1
	NEG.L	D1
PsxOS1:	CMP.L	D1,D7
	BCC.S	PsxOS2
	MOVE.L	D1,D7
PsxOS2:	MULS.L	D3,D0			; x gain >> 8
	ASR.L	#8,D0
	MOVE.L	D0,D1
	BPL.S	PsxOS3
	NEG.L	D1
PsxOS3:	CMP.L	#PSX_KNEE0,D1		; The knee past 6144.
	BLS.S	PsxOS5
	SUB.L	#PSX_KNEE0,D1
	LSR.L	#4,D1
	CMP.L	#PSX_KNEEN-1,D1
	BLS.S	PsxOS4
	MOVE.L	#PSX_KNEEN-1,D1
PsxOS4:	MOVE.W	(PsxKnee.L,D1.L*2),D1
	TST.L	D0
	BPL.S	PsxOS4b
	NEG.W	D1
PsxOS4b:EXT.L	D1
	MOVE.L	D1,D0
PsxOS5:
	IFD	PSXREC
	CMP.L	#PsxRecOEnd-1024,A4
	BCC.S	PsxOSr2
	MOVE.W	D0,(A4)+
PsxOSr2:
	ENDC
	MOVE.L	D0,D1			; High byte (signed), low 6 bits.
	ASR.L	#6,D1
	MOVE.B	D1,(A1)+
	AND.B	#63,D0
	MOVE.B	D0,(A2)+
	DBF	D2,PsxOSL
	IFD	PSXREC
	MOVE.L	A4,PsxRecOP
	ENDC
	RTS

; -------------------------------------> Automatic gain, once a frame
; (mix_compare.agc): D5.W = the frame's peak |mix| >> 4, both sides. Down
; at once while it passes PsxAgcDn for the gain; up a step after
; PSX_AGCHOLD frames under PsxAgcUp, counting frames of PSX_AGCFLOOR or more.
PsxAgc:
	MOVE.W	PsxMxK,D3
	MOVE.W	D3,D4
PsxAgD:	TST.W	D4
	BEQ.S	PsxAgN
	CMP.W	(PsxAgcDn.L,D4.W*2),D5
	BLS.S	PsxAgN
	SUBQ.W	#1,D4
	BRA.S	PsxAgD
PsxAgN:	CMP.W	D3,D4
	BEQ.S	PsxAgU
	MOVE.W	D4,PsxMxK
	CLR.W	PsxMxN
	RTS
PsxAgU:	CMP.W	#PSX_AGCN-1,D3
	BEQ.S	PsxAgR
	CMP.W	#PSX_AGCFLOOR,D5
	BCS.S	PsxAgR
	CMP.W	(PsxAgcUp.L,D3.W*2),D5
	BCC.S	PsxAgZ
	ADDQ.W	#1,PsxMxN
	CMP.W	#PSX_AGCHOLD,PsxMxN
	BCS.S	PsxAgR
	ADDQ.W	#1,PsxMxK
PsxAgZ:	CLR.W	PsxMxN
PsxAgR:	RTS

; -------------------------------------> FMXFrame's restart (FMXFrRs), Sound
; mix: channels 0-2 stopped, their rings silent, then set like channel 3
; on block 0 (FMXFrRs starts all four together). Right side: rings 2/1 in
; Stereo, the left's in Mono.
PsxStart:
	MOVE.W	#$0007,$DFF096
	LEA	FMXBufLL,A0
	MOVE.W	#(3*FMXBUFSZ/4)-1,D0	; (FMXBufLL, FMXBufHR, FMXBufLR in a row)
PsxSt0:	CLR.L	(A0)+
	DBF	D0,PsxSt0
	MOVE.L	#FMXBuf,FMXRingR
	MOVE.L	#FMXBufLL,FMXRingRL
	TST.B	PsxStereo
	BEQ.S	PsxSt1
	MOVE.L	#FMXBufHR,FMXRingR
	MOVE.L	#FMXBufLR,FMXRingRL
PsxSt1:	MOVE.L	#FMXBufLL,$DFF0A0	; 0: left, low
	MOVE.L	FMXRingRL,$DFF0B0	; 1: right, low
	MOVE.L	FMXRingR,$DFF0C0	; 2: right, high
	MOVE.W	FMXNnom,D0
	LSR.W	#1,D0
	MOVE.W	D0,$DFF0A4
	MOVE.W	D0,$DFF0B4
	MOVE.W	D0,$DFF0C4
	MOVE.W	FMXPer,D0
	MOVE.W	D0,$DFF0A6
	MOVE.W	D0,$DFF0B6
	MOVE.W	D0,$DFF0C6
	MOVE.W	#1,$DFF0A8
	MOVE.W	#1,$DFF0B8
	MOVE.W	#64,$DFF0C8
	RTS
