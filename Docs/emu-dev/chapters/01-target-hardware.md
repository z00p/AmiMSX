# Target hardware

## PiStorm (Emu68), 68030/50 and BigMig compared

*Reading notes (Arnold).* All Arnold figures in these notes were measured on one machine: an A1200 with a PiStorm (CM4) running Emu68, OS 3.2.3, no Zorro cards, with the emulator in `Arnold` (68040, `-O2`) builds. The other builds Arnold ships (`-030`, `-040-Max`, `-060`, `-060-Max`) are built and checked in WinUAE only. We have not timed Arnold on a real 68030/50 or on a BigMig, so this section says what the PiStorm numbers do and do not transfer to, and does not invent figures for the others.

**What the target is for Arnold.** Arnold runs a whole CPC (Z80, CRTC, gate array, and on the Plus the ASIC with sprites and DMA) as C code, draws a chunky 384 x 272 picture, and converts it to 8 bitplanes (chunky-to-planar, c2p) for an AGA screen. Every 20 ms it must finish the emulation, the c2p and the sound for one CPC frame. The budget is therefore about 20 ms a frame; chapter 10 shows the figures per game.

| | PiStorm (Emu68) | 68030/50 | BigMig |
|---|---|---|---|
| CPU code | JIT-translated 68k blocks on an ARM core | real 68030 | not covered here |
| What costs time | block dispatch and branch guesses, not instruction counts ([chapter 10](10-performance-emu68.md)) | instruction counts and cycle timings | not measured by Arnold |
| Chip RAM writes by the CPU | about 0.7 microseconds a long (measured, see below) | not measured | not measured |
| Arnold figures in this book | all of them | none | none |

Two consequences for anyone porting an emulator:

- **Do not carry optimisations across CPUs on instruction counts.** An x86 profile of Arnold (callgrind) cut the Plus sprite merge by 36% in instructions and the PiStorm run came out slower (chapter 10). Use the x86 profile to find what is hot, and the real machine to decide whether a change helps.
- **Keep an exact path.** Because speed work changes code layout and timing, every change in Arnold sits behind a `NO_x` switch that restores the old behaviour byte for byte (chapter 06), so a correctness check never depends on the speed of the machine.

## Chip RAM bandwidth and the CPU

**Problem.** Sonic GX (an Amstrad Plus game that scrolls the whole screen) ran at 29.9 frames a second on the PiStorm A1200 with frame skip, and at 41.2 without it (too slow, 108% of the frame budget). A first guess was that the blitter should do the work, since it copies in the background.

**Measured, per frame (Sonic GX, 1850-frame key script, sound on):**

| | before | after the c2p changes |
|---|---|---|
| c2p time per shown frame | 5274 microseconds (94 lines, 56 microseconds a line) | 2259 microseconds (23 microseconds a line) |
| chip RAM written per shown frame (estimated) | 30.3 KB | 10.0 KB |
| frames shown a second (frame skip 3) | 29.9 | 39.3 |

**What the hardware does.** On the PiStorm the CPU writes a long into chip RAM in about 0.7 microseconds. The blitter copies at two DMA slots a word, so a blitter copy of a picture is slower than the CPU writing the same data, and it only pays if it runs while the emulation core is busy. Moving a display window costs nothing at all (see "Vertical-scroll display shift", chapter 02). So the cheapest chip write is the one you do not do: write only what changed.

**After** (`amiga_sys.c` / `c2p_sh.h`, branch `sonic-speed`, switch `NO_SHADOW`): keep a shadow copy of all 8 planes in fast RAM, convert each 32-pixel group, compare the eight plane longs with the shadow and write only the ones that differ:

    #define C2P_SH_PUT(p, o) \
        if (__builtin_expect(s[(p) * ng] != (o), 0)) { \
            s[(p) * ng] = (o); *(ULONG *)(plane[p] + g4) = (o); w++; }

*Source: Arnold-m68k 1.0, `arnold/src/amiga/c2p_sh.h` (GPL-2.0, derived from Kevin Thacker's Arnold).*

Writing only the planes the picture uses (5, 6 or 8 instead of always 8, `NO_C2P5`) came first and took the chip bytes from 30.3 to 21.5 KB.

**Budget rule we use.** Count chip bytes written per shown frame in the per-frame log (chapter 10). A frame that rewrites everything (a full-screen redraw) was the slowest frame in the run (9.4 ms of c2p, a frame of 20.2 ms); nothing in the CPU-versus-blitter choice changes that, so design for the worst frame, not the average.

**Look up.** Branch `sonic-speed`, notes `SONIC-SPEED.md`, `VSCROLL.md` (blitter rejected in step 0); switches `NO_SHADOW`, `NO_C2P5`.

## Caches and fast RAM

The shadow described above lives in fast RAM, so comparing a line with its shadow never reads chip RAM. The only things that must be in chip RAM are the display buffers: three of them, each taller than the screen (448 rows of 320 pixels left 1.19 MB of chip RAM free; 512 rows of 384 pixels left 0.97 MB). Budget the chip RAM for the buffers before you add display features. We did not measure cache sizes or cache hit rates on the PiStorm; the only memory effect we measured is code layout (chapter 10).
