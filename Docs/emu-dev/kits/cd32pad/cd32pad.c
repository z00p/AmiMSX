/* cd32pad.c - read a CD32 pad on an Amiga joystick port by hand.
 * Copyright (c) 2026 z00p. MIT licence, see LICENSE.
 *
 * From Arnold for Amiga (amiga_joy.c), where it is used on an A1200 with a
 * PiStorm (68040 class, very fast) and a KTRL CD32 pad. cd32pad.s is the
 * same protocol in asm, from AmiMSX 4.x.
 *
 * The protocol (as games use it, cf. Codetapper's CD32 pad notes): pin 5 low
 * selects CD32 mode; pin 6 (fire 1) becomes the clock, driven by us; the
 * buttons come out one per clock on pin 9 (POTINP, low = pressed). Order:
 * blue, red, yellow, green, forward, reverse, play, then two ID bits.
 *
 * Why not lowlevel.library's ReadJoyPort(): on the PiStorm it saw the pad but
 * only ever reported red, because its reads outrun the pad on a fast CPU.
 * Here every delay is a run of CIA register reads, which take real Amiga time
 * (about 1.4 us each) whatever the CPU, so the timing holds on any machine.
 *
 * The one subtle point: drive pin 6 HIGH as an output BEFORE pulling pin 5
 * low. If pin 6 is still an input when pin 5 falls, a held red button pulls
 * the clock line low and the pad sees a spurious clock (the bits come out
 * shifted by one). */
#include <exec/types.h>
#include <hardware/custom.h>
#include <hardware/cia.h>
#include <proto/exec.h>
#include "cd32pad.h"

extern struct Custom custom;
extern struct CIA ciaa;

/* The NDK's struct Custom is not volatile: through it, gcc -O2 drops the
 * POTGO write below (a later one overwrites it) and reads POTINP once for all
 * nine bits. So every chip register goes through a volatile pointer. */
#define CUSTOM ((volatile struct Custom *)&custom)

unsigned cd32pad_read(int port)
{
	volatile UBYTE *pra = &ciaa.ciapra, *ddra = &ciaa.ciaddra;
	/* port 2: clock = CIA-A PRA bit 7 (fire), pin 5 = POTGO OUTRX/DATRX,
	 *         data = pin 9 = POTINP DATRY (bit 14)
	 * port 1: clock = CIA-A PRA bit 6, pin 5 = OUTLX/DATLX, data = DATLY (bit 10) */
	UBYTE clk = port == 1 ? 0x40 : 0x80;
	UWORD mode = port == 1 ? 0xf200 : 0x6f00;   /* that port's pin 5 an output, low */
	UWORD data = port == 1 ? 0x0400 : 0x4000;
	unsigned bits = 0;
	int i, d;
	UBYTE dummy;

	Disable();
	*pra |= clk;                    /* clock high first... */
	*ddra |= clk;                   /* ...then the fire line becomes an output */
	for (d = 0; d < 4; d++) dummy = *pra;
	CUSTOM->potgo = mode;            /* pin 5 low: CD32 mode */
	for (d = 0; d < 25; d++) dummy = *pra;
	for (i = 0; i < 9; i++) {
		for (d = 0; d < 10; d++) dummy = *pra;
		if (!(CUSTOM->potinp & data)) bits |= 1u << i;
		*pra &= ~clk;               /* clock pulse: the next bit */
		for (d = 0; d < 4; d++) dummy = *pra;
		*pra |= clk;
	}
	*ddra &= ~clk;                  /* fire line back to an input */
	CUSTOM->potgo = 0xff00;          /* pin 5 high again: normal 2-button mode */
	Enable();
	(void)dummy;
	return bits;
}

unsigned cd32pad_dirs(int port)
{
	UWORD j = port == 1 ? CUSTOM->joy0dat : CUSTOM->joy1dat;
	unsigned m = 0;
	if (((j >> 9) ^ (j >> 8)) & 1) m |= 1;   /* up */
	if (((j >> 1) ^ j) & 1) m |= 2;          /* down */
	if (j & 0x0200) m |= 4;                  /* left */
	if (j & 0x0002) m |= 8;                  /* right */
	return m;
}
