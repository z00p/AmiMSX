# Performance on Emu68

## JIT branch prediction and code layout

*Reading notes (Arnold).* Times are per CPC frame on a PiStorm A1200 (Emu68, `Arnold` 68040 `-O2` build, Sonic GX key script, sound on, no frame skip). "Work" is the whole frame, "c2p" the chunky-to-planar conversion, and "core" is work minus c2p (the CPC emulation and its drawing into the chunky buffer). The budget is 20 ms a frame. Chapter 01 describes the machine; the measuring method is the last section of this chapter.

### On Emu68, the shape of the branches matters more than the instruction count

**Problem.** After the x86 instruction counts had been cut, Sonic GX's spring frames (the whole picture moves) still cost 19.4 ms of work on the A1200, and 566 of 2250 frames ran over 20 ms.

**What Emu68 does** (read from Emu68's public source; it is MPL-2.0 and we only read it, nothing is copied). It translates 68k code to ARM in blocks. There is no chaining: every block ends by returning to a dispatcher that finds the next block from the 68k PC, first by a "last PC" test, then in a 4-way cache of 128 sets indexed by address bits 2 to 8, then through a slow hash list. A conditional branch is translated as "taken" only when it goes backward by less than 128 bytes; every other conditional branch is translated as "not taken", and when that guess is wrong the block is left and the dispatcher runs. `BRA` and `BSR` within 8191 bytes are followed inline. Calls through a register (`jsr (a0)`) cannot be followed.

So hot C code should keep its usual path on the fall-through side of forward branches, keep hot loops under 128 bytes, and avoid calls through pointers. gcc's function common-subexpression elimination turns `jsr _f` into `jsr (a0)`, so we compile with `-fno-function-cse`. These values are from the Emu68 version we tested; check them again after an Emu68 update.

**Before** (`crtc.c`, Arnold-m68k 0.8): the Plus cell loop made about 5 wrong guesses per cell (sprite-column test, stamp checks, step test, a 198-byte loop). The main loop made 3 to 4 per Z80 instruction. The shadow c2p took the "equal, no write" branch for most planes, which the translator had marked as the rare side.

**After** (`hint.h`, `c2p_sh.h`, branch `perf50`, switches `NO_EMUBR`, `NO_HINTS`, `NO_SPRINL`, `NO_SPRLINE`):

    #define ARN_LIKELY(x)   __builtin_expect(!!(x), 1)
    #define ARN_UNLIKELY(x) __builtin_expect(!!(x), 0)
    ...
    /* c2p: no branches in the pixel part; the usual "equal" case falls
       through, the rare write is out of line */
    if (__builtin_expect(s[(p) * ng] != (o), 0)) { ... }

*Source: Arnold-m68k 1.0, `arnold/src/cpc/hint.h`, `arnold/src/amiga/c2p_sh.h` (GPL-2.0, derived from Kevin Thacker's Arnold).*

**Why.** Each wrong guess costs a trip through the dispatcher. The gain hardly shows in an x86 profile: the same changes cut x86 instructions by only 6% (spring frames 60.3 to 56.5 million).

**Evidence** (A1200, Sonic GX, 2250 frames, ms):

| build | spring work | spring core | all-frames core | frames over 20 ms |
|---|---|---|---|---|
| 0.8 | 19.42 | 15.27 | 12.59 | 566 |
| source changes above, `-fno-function-cse` | 16.42 | 13.20 | 10.68 | 29 |

The c2p change was checked against the old loop on 2 million random lines (0 mismatches), and all the changes against whole-run frame checksums (chapter 06).

**Look up.** Branch `perf50`, commits b3d3eb1 and 0bec162, `PERF50.md`, switches above.

### The same code runs faster or slower depending on where the linker puts it

**Problem.** Two sprite-merge changes cut x86 instructions (the mask merge by 36%) and made the A1200 run slower. Even more telling: adding the even-pixel merge to the binary but never calling it (`-DSPREVEN_STEP=99`) made the core slower, 12.90 to 13.66 ms.

**Why.** The translation cache is indexed by address bits 2 to 8, a 512-byte period. When more than four hot blocks start at addresses that share those bits, each dispatch takes the slow path. Moving code by a few bytes changes which blocks collide. In our runs an 8-byte shift swung the core by about 0.9 ms (7%). The same binary also varied by up to 0.6 ms between runs, probably because the system's own code (interrupts, timer, audio) shares the same sets at a load-address-dependent offset.

**Before.** Build with and without the change; run each once.

**After** (`asic.c`, commit ace315a, switch `NO_SPRPAD`): put every function on a 64-byte boundary (`-falign-functions=64`) for the A/B comparison, then scan padding in front of the changed code for the shipped layout:

    #define SPR_PAD 72   /* best of 0/32/72/120/160 in an A1200 scan */
    void ASIC_LayoutPad(void) { __asm__ volatile (".space " SPR_STR(SPR_PAD) ", 0x4e"); }

*Source: Arnold-m68k 1.0, `arnold/src/cpc/asic.c` (GPL-2.0, derived from Kevin Thacker's Arnold).*

**Evidence** (ms, core on spring frames / over the whole run; the change is the even-pixel merge):

| | reference | change |
|---|---|---|
| default layout | 16.98 / 12.90 | 17.51 / 13.25 (looks slower) |
| change compiled in, never called | | 18.27 / 13.66 |
| every function aligned to 64 | 18.35 / 13.83 | 17.53 / 13.35 (a real gain) |
| 120 bytes of padding added | | 16.47 / 12.62 |
| 232 bytes of padding added | | 17.15 / 13.05 |

Aligning everything to 64 is itself about 1 ms slower than the lucky default layout, because every function entry then falls into only 8 of the 128 sets. It is a fair way to compare two builds that add no hot functions, not a way to ship.

**Rules we follow.** (1) Compare two builds only with fixed alignment, two runs each, in turn. (2) When the final code is in, scan a few paddings and keep the best. (3) Any code change re-rolls the layout, so re-measure after a merge. After the branch shaping above and the PGO build below, the effect shrank: variants padded by 0 and 120 bytes were within 0.1 ms of each other.

**Look up.** Commits d3bee57, ace315a, f159302, 72894cd; `SPRITES.md`; switches `NO_SPREVEN`, `NO_SPRPAD`, `NO_SPRCOL`.

## Aligned A/B builds before judging an optimisation

*Reading notes.* The layout lesson above is the reason for this section. The method in short: fix the layout (align to 64, or scan paddings), run each build at least twice in turn on an idle machine, compare the medians, and treat a whole-run difference under about 0.6 ms as noise. The aligned A/B is the reliable result; the default-layout comparisons around it disagreed with it by up to 0.9 ms.

### A worked A/B: per-column sprite sets

**Problem.** Plus sprites made spring frames 2 to 4 ms slower than running frames. The merge walked all 16 sprite bits for every column (about 13 iterations a call, 3 sprites covering the column, 1 with a non-empty row).

**After** (`asic.c`, commit f159302, switch `NO_SPRCOL`): the column-mask builder also records, per CRTC column, the set of sprites covering it (cleared through a list of used columns), and the merge walks only those bits with a find-first-set instruction.

**Evidence.** Both builds aligned to 64 so the layout is fixed. Even-pixel merge only: 17.85 / 13.35 and 17.75 / 13.34 ms (spring core / whole run). With column sets: 16.00 / 12.99 and 15.92 / 12.99. That is **1.8 ms less on springs and 0.35 ms less over the run**, two runs each. x86 callgrind agreed in direction (75.2 to 62.3 million instructions on spring frames) but not in size. The change is exact: whole-run frame checksums were identical on four games, and a check build that ran the new merge against the full loop on every call reported 0 mismatches.

**Look up.** `SPRITES.md`; switches `NO_SPREVEN`, `NO_SPRCOL`.

## Profile-guided gcc builds recorded in WinUAE

**Problem.** The shipped build ran with whatever block layout and branch order gcc chose. Shaping the branches in the source gave about 2 ms; the compiler could give more if it knew which paths are hot.

**How we build** (gcc 6.5 from the amiga-gcc toolchain, see chapter 07):

1. Build an instrumented binary with `-fprofile-generate=<directory on the Amiga>`. The environment variable that redirects the profile directory is ignored on AmigaOS (no POSIX I/O), so the directory is part of the option. `libgcov` exists for the 68020 multilib only if it is linked explicitly.
2. Run it in WinUAE (not on the A1200) on a training set: six runs, about two minutes in all (Sonic GX scrolling and springs, Ghouls'n Ghosts GX, Puzzle Bobble, Burnin' Rubber, Head over Heels). The profile holds how often each branch is taken, which does not depend on the CPU, so a profile recorded on an emulated 68040 is valid for the PiStorm.
3. Rebuild every variant with `-fprofile-use=<directory>` and `-fno-function-cse -fno-unroll-loops -fno-peel-loops`. The build without unrolling and peeling was the faster one (our reading: unrolled loops outgrow Emu68's 128-byte loop rule).

**Evidence** (A1200, Sonic GX, 2250 frames, ms):

| build | spring core | all-frames core | frames over 20 ms |
|---|---|---|---|
| shaped source, no profile | 13.20 | 10.68 | 29 |
| with PGO | 11.16 | 8.92 | 1 |
| with PGO, no unrolling or peeling | 10.54 | 8.60 | 2 |

Final release builds, two A1200 runs: spring work 13.8 and 14.0, whole run 12.05, no frame over 20 ms. The 0.8 build in between: 487 and 506 frames over 20 ms, worst frame 24.3 and 45.5 ms. Ghouls'n Ghosts GX core went from 10.26 to 6.52 ms.

**Traps.**
- **The profile is keyed by function order and line number.** Add a function in the middle of `cpc.c` and every function after it loses its profile (coverage-mismatch warnings; the code is silently slower). Put new functions at the end of the file. After a change, build old and new with the existing profile and compare the disassembly object by object: identical objects need no new profile. Re-record when hot code changed. We pass `-Wno-error=coverage-mismatch` for builds that only changed cold code.
- **A new source file changes the profile count** (48 profile files became 51 when three modules were added for 1.0), so re-record before a release.
- **Test exactness with the `NO_x` switches, never with timings.** A PGO build and a switch build are different binaries; the exactness tests compare picture checksums (chapter 06).

**Look up.** Branch `perf50`; `PERF50.md`; the profile scripts under `tools/perf50`; commit 401e9a5 (profile re-recorded for 1.0).

## CPU writes vs the blitter on PiStorm; c2p and chip-write budgets

**Problem.** Converting the picture to bitplanes cost nearly as much as the emulation. Sonic GX with every frame drawn used 108% of the frame budget (0.6 release).

**What the hardware does.** The PiStorm CPU writes chip RAM at about 0.7 microseconds a long. The blitter copies at two DMA slots a word. For a copy that does not overlap CPU work the CPU wins, so we never used the blitter for c2p or scrolling. The numbers behind this and the changed-longs-only method are in chapter 01 ("Chip RAM bandwidth and the CPU").

**Budget table** (A1200, Sonic GX, no frame skip):

| step | core ms | c2p ms | chip KB per shown frame | budget used |
|---|---|---|---|---|
| 0.6 release | 14.9 | 6.7 | 30.3 | 108% |
| changed longs only (shadow in fast RAM) | 14.8 | 2.9 | 12.7 | 88% |
| quiet CRTC cycles drawn in one run, scroll table | 12.9 | 2.8 | | 79% |
| branch shaping and PGO (1.0, work 12.05 ms) | 8.7 | | | 60% |

The CRTC step (switch `NO_DEFER`, commit dd72fd4) draws the cycles between two events in one run instead of one instruction at a time. The soft-scroll step (switch `NO_SCROLL_TABLE`) replaces a loop by four table lookups, checked exact on 280 million random inputs.

**When the whole picture moves vertically**, chapter 02 ("Vertical-scroll display shift") moves a display window instead of the pixels. On a spring (frames 2198 to 2212) it cut chip writes from 23.8 to 13.0 KB a frame and c2p from 5.49 to 4.00 ms. A first version that searched every offset for a match cost 267 microseconds a frame and made the whole run slower (48.3 against 49.3 frames a second); voting with a hash table of row hashes cost 88 microseconds.

**Look up.** `SONIC-SPEED.md`, `VSCROLL.md`, `PERF50.md`.

## Measuring per frame on real hardware

**Problem.** Whole-run averages hide the frames that matter. A game that averages 49.9 frames a second can still miss the 20 ms deadline on 566 frames, and sound and scrolling show it where a mean does not.

**What we log, per frame** (`host_amiga.c`, a `frames.txt` written on the Amiga next to the run's snapshots): the time of the whole frame ("work"), the time in c2p, and the number of chip longs written. At the end a "done" file adds the maximum work time, a histogram, the number of frames over 20 ms ("late"), skipped frames, audio underruns and drops, and the search and shift counts of the display shift. A small Python reader prints the same figures for every run: spring work, spring core, whole-run work and core, late frames.

**How we run it.** A script on the Amiga starts the program with a key script that plays the same moves every time (a fixed number of frames, 1850 or 2250), writes the log, and leaves the machine at Workbench. Runs of two builds are interleaved (A, B, A, B), because the same binary can differ by up to 0.6 ms between runs. Example, the cost of the sound fixes: 12.69 and 12.34 ms core before, 12.60 and 12.42 ms after, run in the order before, after, before, after. No measurable cost.

**Reading the log.**
- Core (work minus c2p) separates emulation from display.
- Frames over 20 ms are listed by number. The same few frames recurring (a full-screen redraw at frame 389, c2p 8.3 to 9.4 ms) mean a real worst case, not noise.
- Run the same script once more with the display audit switched on (chapter 06) to prove the picture is still right.

**Before you measure.** Make sure nothing else is running on the machine (another session's program, a stuck network copy), and record the machine's CPU clock with the figures ([chapter 11](11-test-machine.md)).

**Look up.** `SONIC-SPEED.md`; the A1200 run scripts and the log reader under `tools/vscroll` and `tools/sprites` in the development repository.
