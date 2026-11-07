/* cd32test - show what a CD32 pad sends. Shell tool.
 *   cd32test [port] [seconds]     port 2 (default) or 1, run for 30 s by default; Ctrl-C quits.
 * Prints a line whenever the directions or buttons change.
 * Copyright (c) 2026 z00p. MIT licence, see LICENSE. */
#include <exec/types.h>
#include <dos/dos.h>
#include <proto/exec.h>
#include <proto/dos.h>
#include <graphics/gfxbase.h>
#include <proto/graphics.h>
#include <stdio.h>
#include <stdlib.h>
#include "cd32pad.h"

int main(int argc, char **argv)
{
	int port = argc > 1 ? atoi(argv[1]) : 2;
	int secs = argc > 2 ? atoi(argv[2]) : 30;
	long frames = (long)secs * 50, f;
	unsigned last = ~0u;
	static const char *names[9] = { "blue", "red", "yellow", "green", "fwd", "rev", "play", "id8", "id9" };
	if (port != 1) port = 2;
	printf("CD32 pad on port %d for %d s (Ctrl-C quits). A CD32 pad reads id8=0 id9=1.\n", port, secs);
	for (f = 0; f < frames; f++) {
		unsigned b = cd32pad_read(port), d = cd32pad_dirs(port), v = b | d << 9;
		if (v != last) {
			int i;
			printf("%5ld  raw %03x  %s%s%s%s ", f, b, d & 1 ? "U" : "-", d & 2 ? "D" : "-", d & 4 ? "L" : "-", d & 8 ? "R" : "-");
			for (i = 0; i < 9; i++) if (b & (1u << i)) printf(" %s", names[i]);
			printf("\n");
			last = v;
		}
		if (SetSignal(0, 0) & SIGBREAKF_CTRL_C) break;
		WaitTOF();
	}
	return 0;
}
