/* cd32pad.h - read a CD32 pad on an Amiga joystick port by hand.
 * Copyright (c) 2026 z00p. MIT licence, see LICENSE. */
#ifndef CD32PAD_H
#define CD32PAD_H

/* Button bits returned by cd32pad_read() (bit set = pressed). */
#define CD32_BLUE     0x001
#define CD32_RED      0x002
#define CD32_YELLOW   0x004
#define CD32_GREEN    0x008
#define CD32_FORWARD  0x010   /* right shoulder */
#define CD32_REVERSE  0x020   /* left shoulder */
#define CD32_PLAY     0x040
#define CD32_ID8      0x080   /* ID bits: a CD32 pad reads ID8 = 0, ID9 = 1 */
#define CD32_ID9      0x100

/* port: 2 = the joystick port (the usual one), 1 = the mouse port.
 * Returns the 7 buttons and the 2 ID bits. Runs with interrupts off for
 * about 250 us. Call it once a frame, and only for a port the user has
 * set to "CD32 pad": on a plain joystick it drives the fire line as a clock. */
unsigned cd32pad_read(int port);

/* Directions come from the normal joystick register in either mode.
 * Returns bits: 1 up, 2 down, 4 left, 8 right. */
unsigned cd32pad_dirs(int port);

#endif
