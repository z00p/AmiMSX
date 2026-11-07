# Target hardware

## PiStorm (Emu68), 68030/50 and BigMig compared

*Reading notes (Arnold).* All Arnold figures in these notes were measured on one machine: an A1200 with a PiStorm (CM4, running Emu68) in the trapdoor slot and no other expansions, OS 3.2.3, with the emulator in `Arnold` (68040, `-O2`) builds. Arnold 1.0 to 1.6 also shipped `-030`, `-040-Max`, `-060` and `-060-Max` builds; since 1.7 only `Arnold` and `Arnold-060` ship (chapter 07). `Arnold-060` is checked in WinUAE and has run on the A1200, but has not been timed on a BigMig. We have not timed Arnold on a real 68030/50 or on a BigMig, so this section says what the PiStorm numbers do and do not transfer to, and does not invent figures for the others.

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

*AmiMSX.* A different shape of emulator gives a different picture of the same machines. AmiMSX is 68k assembly that takes the machine over. On AGA it draws the MSX tiles straight into bitplanes (blitter and CPU, only what changed since the last frame), so there is no chunky picture and no c2p. Its cost per frame is the tiles and sprites that changed, not the screen size.

| | PiStorm (Emu68) | 68030/50 | BigMig |
|---|---|---|---|
| AmiMSX figures | the player's timing logs (A1200) | WinUAE's 68030 config only; no real 68030/50 timed | measured on the machine (4.0) |
| SCREEN 4 scrolling game, AGA render | Space Manbow, live drawing: 76 beam lines median, 163 at the 99th percentile (6 of 728 frames late) | Lilly's Saga at 87% of full speed (72% with the software sound mix) | 120 to 140 lines from about line 252, so the drawing lands partly in the next frame |
| RTG, input read to end of drawing | 50 lines median (3 ms), 99th percentile 9 ms | not measured | not measured |

What carries over to other projects: on the fast machines the frame's work is short, and the time goes in *when* it is done, not in doing it (chapter 05, controller lag). On the BigMig the drawing still crosses the frame start, which is why the double buffer exists (chapter 02). Presets per machine (chapter 07) keep the 68030 away from features it cannot afford, such as the software sound mix (chapter 04), the double buffer and 60 Hz from the VDP.

*AmiPCEngine.* The third project measured on the same A1200 PiStorm, and its figures do not transfer either. AmiPCEngine is 68k assembly with the operating system frozen in play. On the PiStorm the CPU was never its limit: speed work that gained 75% on WinUAE's 68030/50 config changed nothing on the A1200, where the frames lost on AGA were the renderer's chip RAM writes, and the RTG output is busy 13 to 28% of the frame ([chapter 10](10-performance-emu68.md#what-a-speed-up-buys-depends-on-the-machine-amipcengine), [chapter 12](12-rtg.md#measure-before-tuning-rtg-is-busy-13-to-28-of-the-frame-on-a-pistorm)). Its 68030 figures come from WinUAE only. It has none from a real 68030/50 or a BigMig either.

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
