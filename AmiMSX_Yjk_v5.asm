; =========================================================================
; (5.2) V9958 YJK (SCREEN 10-12): R#25 bit 3 (YJK) and bit 4 (YAE) on the
; SCREEN 8 display. Four dots a group: Y is each byte's top 5 bits, K the
; low 3 bits of bytes 0 and 1 (low, high), J those of bytes 2 and 3, both
; signed 6-bit. R = Y+J, G = Y+K, B = (5Y-2J-K)/4, each clipped to 0-31
; (MSX turbo R Technical Hand Book 4.6). With YAE a byte with bit 3 set is
; palette colour (byte >> 4) instead (SCREEN 10/11), Y then 4 bits.
; Shown as SCREEN 8 bytes (GGGRRRBB, the nearest of SCREEN 8's 256): the
; AGA planes (PasaPun8Bpl) and the RTG line (RtgBgG7) convert each group
; before the SCREEN 8 path, so sprites, borders, scanlines and the line
; cache work as in SCREEN 8.
; YjkTab: 128 KB, index (J6 << 11 | K6 << 5 | Y), J6/K6 the raw 6 bits,
; built the first time YJK shows (YjkBuild).
; R#25 is taken over the frame (V9R25F: any write since the display
; started), so a game that sets YJK at the top and leaves it lower down
; still converts.
; Not done: sprite colours from the palette in YJK (the hand book 4.6.9),
; more than SCREEN 8's 256 colours on RTG; with YAE, a palette change seen
; by Yjk8Frame is not seen again by YjkBms in the same frame.
; =========================================================================

V9R25F:		DC.B	0		; R#25 ORed over the frame (VDPR25)
YjkBuilt:	DC.B	0
YjkYae:		DC.B	0		; YAE: bit-3 bytes are palette colours
YjkSt8:		DC.B	0		; R#25 AND $18 the AGA planes hold
YjkOn8:		DC.B	0		; this frame's AGA conversion is YJK
		EVEN
YjkSv6:		DC.L	0		; PasaPun8Bpl's banks, the next block
YjkSv3:		DC.L	0
YjkPal16:	DS.B	16		; the palette as SCREEN 8 bytes (YAE)
YjkE:		DS.B	16		; a block's converted even bytes
YjkO:		DS.B	16		; and odd ones

; YjkBuild: YjkTab from YjkQRG/YjkQB, once.
	CNOP	0,4
YjkBuild:
	TST.B	YjkBuilt
	BNE.S	YjkBdX
	MOVEM.L	D0-D7/A0-A2,-(SP)
	LEA	YjkTab,A0
	LEA	YjkQRG+32,A1		; (index -32..62)
	LEA	YjkQB+96,A2		; (index -96..255)
	MOVEQ	#0,D6			; J6 << 6 | K6
YjkBdJK:MOVE.W	D6,D5
	LSR.W	#6,D5
	LSL.B	#2,D5
	ASR.B	#2,D5
	EXT.W	D5			; J
	MOVE.W	D6,D4
	LSL.B	#2,D4
	ASR.B	#2,D4
	EXT.W	D4			; K
	MOVE.W	D5,D3
	ADD.W	D3,D3
	ADD.W	D4,D3
	NEG.W	D3			; -2J-K
	MOVEQ	#0,D7			; Y
YjkBdY:	MOVE.W	D7,D0
	ADD.W	D4,D0
	MOVE.B	(A1,D0.W),D1		; G level
	LSL.B	#3,D1
	MOVE.W	D7,D0
	ADD.W	D5,D0
	OR.B	(A1,D0.W),D1		; R level
	LSL.B	#2,D1
	MOVE.W	D7,D0
	LSL.W	#2,D0
	ADD.W	D7,D0
	ADD.W	D3,D0			; 5Y-2J-K
	OR.B	(A2,D0.W),D1		; B level
	MOVE.B	D1,(A0)+
	ADDQ.W	#1,D7
	CMP.W	#32,D7
	BNE.S	YjkBdY
	ADDQ.W	#1,D6
	CMP.W	#4096,D6
	BNE.S	YjkBdJK
	ST	YjkBuilt
	MOVEM.L	(SP)+,D0-D7/A0-A2
YjkBdX:	RTS

; YjkPal: YjkPal16 from MSX2Pal ($0RGB, nibbles 0,3,5,...,15): R and G
; level (n-1)/2 (0: 0), blue the nearest of 0,5,9,15.
	CNOP	0,4
YjkPal:
	MOVEM.L	D0-D3/A0-A1,-(SP)
	LEA	MSX2Pal,A0
	LEA	YjkPal16,A1
	MOVEQ	#16-1,D3
YjkPlL:	MOVE.W	(A0)+,D0
	MOVE.W	D0,D1
	LSR.W	#4,D1
	AND.W	#15,D1			; G
	MOVE.B	(YjkNbL,PC,D1.W),D2
	LSL.B	#3,D2
	MOVE.W	D0,D1
	LSR.W	#8,D1
	AND.W	#15,D1			; R
	OR.B	(YjkNbL,PC,D1.W),D2
	LSL.B	#2,D2
	AND.W	#15,D0			; B
	OR.B	(YjkNbB,PC,D0.W),D2
	MOVE.B	D2,(A1)+
	DBF	D3,YjkPlL
	MOVEM.L	(SP)+,D0-D3/A0-A1
	RTS
YjkNbL:	DC.B	0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7
YjkNbB:	DC.B	0,0,1,1,1,1,2,2,2,2,2,2,3,3,3,3

; Yjk4: D0-D3.W = a group's bytes 0-3 (0-255) -> D0-D3 their SCREEN 8
; bytes (YjkTab built; YjkYae, YjkPal16 set). Uses D4-D5, A0.
	CNOP	0,4
Yjk4:
	MOVEQ	#0,D4
	MOVE.W	D3,D4
	AND.W	#7,D4
	LSL.W	#3,D4
	MOVE.W	D2,D5
	AND.W	#7,D5
	OR.W	D5,D4
	LSL.W	#3,D4
	MOVE.W	D1,D5
	AND.W	#7,D5
	OR.W	D5,D4
	LSL.W	#3,D4
	MOVE.W	D0,D5
	AND.W	#7,D5
	OR.W	D5,D4
	LSL.L	#5,D4
	LEA	(YjkTab.L,D4.L),A0
	TST.B	YjkYae
	BNE.S	Yjk4A
	LSR.W	#3,D0
	MOVE.B	(A0,D0.W),D0
	LSR.W	#3,D1
	MOVE.B	(A0,D1.W),D1
	LSR.W	#3,D2
	MOVE.B	(A0,D2.W),D2
	LSR.W	#3,D3
	MOVE.B	(A0,D3.W),D3
	RTS
YJKA:	MACRO
	BTST	#3,\1
	BEQ.S	\@y
	LSR.W	#4,\1
	MOVE.B	(YjkPal16.L,\1.W),\1
	BRA.S	\@x
\@y:	LSR.W	#3,\1			; (bit 3 clear: Y's low bit 0)
	MOVE.B	(A0,\1.W),\1
\@x:
	ENDM
Yjk4A:	YJKA	D0
	YJKA	D1
	YJKA	D2
	YJKA	D3
	RTS

; YjkLine: the 256 bytes at A1 (one SCREEN 8 line, logical order) converted
; in place (RTG: RtgBgG7, RfR25 bit 3). D0.B = the line's R#25.
	CNOP	0,4
YjkLine:
	MOVEM.L	D0-D6/A0-A1,-(SP)
	BSR	YjkBuild
	SF	YjkYae
	BTST	#4,D0
	BEQ.S	YjkLn0
	ST	YjkYae
	BSR	YjkPal
YjkLn0:	MOVEQ	#64-1,D6
YjkLnL:	MOVEQ	#0,D0
	MOVEQ	#0,D1
	MOVEQ	#0,D2
	MOVEQ	#0,D3
	MOVE.B	(A1),D0
	MOVE.B	1(A1),D1
	MOVE.B	2(A1),D2
	MOVE.B	3(A1),D3
	BSR	Yjk4
	MOVE.B	D0,(A1)+
	MOVE.B	D1,(A1)+
	MOVE.B	D2,(A1)+
	MOVE.B	D3,(A1)+
	DBF	D6,YjkLnL
	MOVEM.L	(SP)+,D0-D6/A0-A1
	RTS

; YjkSt: this frame's YJK state (R#25 AND $18, 0 without YJK) for a
; SCREEN 8 conversion: YjkOn8, YjkYae, YjkPal16 set, YjkTab built. A0 = the
; state byte that conversion's planes hold. D1.B = -1 (and the state byte
; updated) if they hold another state or, with YAE, another palette: every
; block is to be converted again.
	CNOP	0,4
YjkSt:
	MOVEM.L	D0/D2-D3/A1-A2,-(SP)
	MOVEQ	#0,D1
	MOVEQ	#0,D0
	TST.B	V9958On
	BEQ.S	YjkSt0
	MOVE.B	V9R25F,D0		; (any time in the frame: F-1 Spirit
	AND.B	#$18,D0			; sets YJK at the top, SCREEN 5 lower)
	BTST	#3,D0			; YAE alone: SCREEN 8
	BNE.S	YjkSt0
	MOVEQ	#0,D0
YjkSt0:	TST.B	D0
	SNE	YjkOn8
	BEQ.S	YjkSt1
	BSR	YjkBuild
	SF	YjkYae
	BTST	#4,D0
	BEQ.S	YjkSt1
	ST	YjkYae
	MOVE.L	YjkPal16,YjkPOld	; (the old palette)
	MOVE.L	YjkPal16+4,YjkPOld+4
	MOVE.L	YjkPal16+8,YjkPOld+8
	MOVE.L	YjkPal16+12,YjkPOld+12
	BSR	YjkPal
	LEA	YjkPOld,A1
	LEA	YjkPal16,A2
	MOVEQ	#4-1,D2
YjkStP:	CMPM.L	(A1)+,(A2)+
	DBNE	D2,YjkStP
	BEQ.S	YjkSt1
	ST	D1
YjkSt1:	CMP.B	(A0),D0
	BEQ.S	YjkSt2
	ST	D1
YjkSt2:	MOVE.B	D0,(A0)
	MOVEM.L	(SP)+,D0/D2-D3/A1-A2
	RTS
YjkPOld:	DS.L	4
YjkStB:		DC.B	0		; (the pair split's SCREEN 8 page)
		EVEN

; Yjk8Frame (PRINT8, before PasaPun8Bpl): every block again on a change
; (TAB98 all dirty, P8INV's stamps).
	CNOP	0,4
Yjk8Frame:
	MOVEM.L	D1/A0,-(SP)
	LEA	YjkSt8,A0
	BSR	YjkSt
	TST.B	D1
	BEQ.S	Yjk8X
	P8INV
	LEA	TAB98,A0
	MOVE.W	#($800*8)/4-1,D1
Yjk8Fl:	MOVE.L	#-1,(A0)+
	DBF	D1,Yjk8Fl
Yjk8X:	MOVEM.L	(SP)+,D1/A0
	RTS

; YjkBms (BMSConv8, before its BMSFull test): the same for the pair
; split's SCREEN 8 page (BMSFull: all of it again).
	CNOP	0,4
YjkBms:
	MOVEM.L	D1/A0,-(SP)
	LEA	YjkStB,A0
	BSR	YjkSt
	TST.B	D1
	BEQ.S	YjkBmX
	ST	BMSFull
YjkBmX:	MOVEM.L	(SP)+,D1/A0
	RTS

; YjkBlk8 (PasaPun8Bpl, BMSConv8: a dirty block, YjkOn8): the block's 32 bytes (16
; even at A6, 16 odd at A3) converted into YjkE/YjkO, A6/A3 pointed at them
; for the conversion (YjkSv6/YjkSv3: the banks' next block).
	CNOP	0,4
YjkBlk8:
	MOVEM.L	D0-D6/A0-A2/A4,-(SP)
	MOVE.L	A6,A1
	MOVE.L	A3,A2
	LEA	16(A6),A0
	MOVE.L	A0,YjkSv6
	LEA	16(A3),A0
	MOVE.L	A0,YjkSv3
	LEA	YjkE,A6
	LEA	YjkO,A3
	MOVEQ	#8-1,D6
YjkBkL:	MOVEQ	#0,D0
	MOVEQ	#0,D1
	MOVEQ	#0,D2
	MOVEQ	#0,D3
	MOVE.B	(A1)+,D0
	MOVE.B	(A2)+,D1
	MOVE.B	(A1)+,D2
	MOVE.B	(A2)+,D3
	BSR	Yjk4
	MOVE.B	D0,(A6)+
	MOVE.B	D1,(A3)+
	MOVE.B	D2,(A6)+
	MOVE.B	D3,(A3)+
	DBF	D6,YjkBkL
	LEA	YjkE,A6
	LEA	YjkO,A3
	MOVEM.L	(SP)+,D0-D6/A0-A2/A4
	RTS

YjkQRG:
	DC.B	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	DC.B	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	DC.B	0,0,0,0,1,1,1,1,1,2,2,2,2,3,3,3
	DC.B	3,4,4,4,4,5,5,5,5,6,6,6,6,7,7,7
	DC.B	7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7
	DC.B	7,7,7,7,7,7,7,7,7,7,7,7,7,7,7
YjkQB:
	DC.B	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	DC.B	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	DC.B	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	DC.B	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	DC.B	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	DC.B	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	DC.B	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	DC.B	0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1
	DC.B	1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
	DC.B	1,1,1,1,1,1,1,1,1,1,2,2,2,2,2,2
	DC.B	2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2
	DC.B	2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2
	DC.B	2,2,3,3,3,3,3,3,3,3,3,3,3,3,3,3
	DC.B	3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3
	DC.B	3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3
	DC.B	3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3
	DC.B	3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3
	DC.B	3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3
	DC.B	3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3
	DC.B	3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3
	DC.B	3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3
	DC.B	3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3
	EVEN

	SECTION	YJKT,BSS
YjkTab:	DS.B	4096*32
	SECTION	MSX2,CODE
