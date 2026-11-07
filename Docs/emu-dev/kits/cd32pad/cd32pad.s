; cd32pad.s - read CD32 pads on both Amiga joystick ports, hardware banging.
; Copyright (c) 2026 z00p. MIT licence, see LICENSE.
; Written in October 2026 for the AmiMSX 4.x update (in 4.1.1 and later) and
; made standalone here. It is new code: Juan Antonio Gomez Galvez's original
; AmiMSX (3.1) has no CD32 read.
; Devpac / vasm (-devpac) syntax, 68000 and up.
;
; ReadCD32Pads
;   in:  d0.b = ports to read: bit 1 = port 2 (joystick port), bit 0 = port 1
;               (mouse port). A port left out is never driven.
;   out: d0.b = port 2 buttons, d1.b = port 1 buttons, 1 = pressed:
;               bit 0 blue, 1 red, 2 yellow, 3 green,
;               4 right shoulder, 5 left shoulder, 6 play
;         $00 for a port not read, or a port that doesn't answer as a pad.
;   Everything else is preserved. Directions are not read here: take them
;   from JOY0DAT/JOY1DAT as usual (they work the same in CD32 mode).
;
; Call it once a frame, e.g. from the vertical blank (twice a frame works
; too). It takes about 300 us, nearly all of it the latch wait (below). It
; owns POTGO and CIA-A DDRA bits 6/7 while it runs, so with the OS alive call
; it with interrupts off (or allocate the pot bits with potgo.resource).
; lowlevel.library's ReadJoyPort() is no substitute on fast CPUs: on a
; PiStorm it only ever reported red.
; It saves d2-d4 on the stack; if your code runs interrupts on a borrowed A7
; (AmiMSX does: the Z80 core's), keep them in memory instead.
;
; The protocol: with pin 5 driven low (POTGO DATxX = 0) the pad latches its
; buttons and puts them on pin 9 (POTINP DATxY), one per clock pulse on
; pin 6 (CIA-A PRA bit 7 for port 2, bit 6 for port 1, made outputs):
; blue, red, yellow, green, right, left, play; 0 = pressed. The pad's
; shift register (a 4021: parallel load while pin 5 is high, shift on a
; rising clock edge once it is low) clocks on pin 6, so:
;  - pin 6 is driven high BEFORE pin 5 goes low. In plain mode a held red
;    button pulls pin 6 low; if the Amiga only drove it high after the pad
;    had switched to shift mode, that rise would be a clock edge and every
;    bit would come out one place early whenever red was held;
;  - pin 5 has the pot capacitor on it (47 nF) and needs a few lines to
;    fall, hence the 200-read wait;
;  - every wait is a CIA read: one E cycle (~1.4 us) on any CPU, so the
;    timing is the same on a 68000, an 060 or a PiStorm.
; A plain joystick (or an adapter in its standard mode) answers every clock
; with the same pin 9 level: all seven "buttons" pressed whenever its fire 2
; is held. A real pad can't show that, so that reads as no pad ($00).

CIAAPRA		= $BFE001
CIAADDRA	= $BFE201
POTGO		= $DFF034
POTINP		= $DFF016

ReadCD32Pads:
	movem.l	d2-d4,-(sp)
	moveq	#0,d3			; d3 = the CIA-A PRA bits to clock (pin 6)
	move.w	#$FF00,d4		; d4 = POTGO: pin 5 low on each port read
	btst	#1,d0
	beq.s	.no2
	move.b	#$80,d3
	and.w	#$6FFF,d4		; port 2: DATRX = 0 (pin 5 low), OUTRY = 0 (pin 9 in)
.no2:	btst	#0,d0
	beq.s	.no1
	or.b	#$40,d3
	and.w	#$F6FF,d4		; port 1: DATLX = 0, OUTLY = 0
.no1:	moveq	#0,d0
	moveq	#0,d1
	tst.b	d3
	beq	.done
	or.b	d3,CIAAPRA		; pin 6: high, then an output, held high
	or.b	d3,CIAADDRA		; while pin 5 falls (no clock edge)
	move.w	d4,POTGO		; pin 5 low: the pad latches its buttons
	move.w	#200-1,d2
.latch:	tst.b	CIAAPRA			; ~300 us for pin 5 to fall
	dbf	d2,.latch
	moveq	#7-1,d2
.bit:	lsr.b	#1,d0			; port 2: the first button out ends in bit 0
	btst	#6,POTINP		; pin 9 (DATRY, bit 14): 1 = released
	beq.s	.lo2
	bset	#6,d0
.lo2:	lsr.b	#1,d1
	btst	#2,POTINP		; port 1 pin 9 (DATLY, bit 10)
	beq.s	.lo1
	bset	#6,d1
.lo1:	eor.b	d3,CIAAPRA		; clock low...
	tst.b	CIAAPRA
	tst.b	CIAAPRA
	tst.b	CIAAPRA
	eor.b	d3,CIAAPRA		; ...and high: the next button
	tst.b	CIAAPRA
	tst.b	CIAAPRA
	tst.b	CIAAPRA
	dbf	d2,.bit
	move.w	#$FF00,POTGO		; pin 5 high: plain joystick mode again
	not.b	d3
	and.b	d3,CIAADDRA		; pin 6 an input again
	not.b	d0			; 1 = pressed
	and.b	#$7F,d0
	not.b	d1
	and.b	#$7F,d1
	cmp.b	#$7F,d0			; all seven at once: a plain joystick
	bne.s	.ok2
	moveq	#0,d0
.ok2:	cmp.b	#$7F,d1
	bne.s	.ok1
	moveq	#0,d1
.ok1:	not.b	d3			; ports not asked for: $00
	btst	#7,d3
	bne.s	.r2
	moveq	#0,d0
.r2:	btst	#6,d3
	bne.s	.done
	moveq	#0,d1
.done:	movem.l	(sp)+,d2-d4
	rts
