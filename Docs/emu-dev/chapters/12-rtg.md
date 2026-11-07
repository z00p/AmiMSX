# RTG output: showing a chunky frame through Picasso96

*Reading notes (Arnold, from the RTG framework "rtgfw" that ships in Arnold for the Amiga 1.2).* RTG (retargetable graphics) means showing the frame on a Picasso96 or CyberGraphX screen with the OS alive, instead of taking over the AGA chipset. On the PiStorm A1200 this is the VideoCore output under Picasso96; on BigMig it is the MiSTer RTG (untested so far); in WinUAE it is `uaegfx`. It is opt-in: AGA stays the default output. Times are per CPC frame on a PiStorm32 CM4 A1200 (Emu68, Picasso96 2.495, HDMI 1080p at 60 Hz). Chapter 10 describes the measuring method, and chapter 11 the machine.

The framework is a small C module (`rtgfw`, MIT licence) that Arnold vendors into its tree. Excerpts below are from it (MIT) or from Arnold (GPL-2.0).

## Why RTG: a direct chunky copy instead of chunky-to-planar

### The c2p was 4.3 ms of a 13 ms frame

**Problem.** Arnold draws a CPC frame as one byte per pixel (chunky). The AGA screen needs bitplanes, so each frame went through a chunky-to-planar (c2p) conversion into chip RAM: 4.3 ms a frame on the A1200 in Sonic GX, with 18 to 23 frames of 2250 over the 20 ms budget.

**Before** (AGA path, `Sys_ShowFrame`, Arnold-m68k 1.1): c2p of the changed lines into chip RAM, then a screen-buffer flip.

**After** (RTG path, Arnold 1.2): copy the changed chunky lines to the screen bitmap, one byte a pixel, with no conversion at all:

    /* rtgfw: path A, one 8-bit CLUT screen, only changed lines */
    rtg_set_palette(0, lo, n, colours, RTG_RGB24);   /* changed range only */
    rtg_present(chunky, pitch, line_dirty);          /* dirty lines under one lock */

*Source: Arnold 1.2, `arnold/src/amiga/amiga_sys.c`, RTG branch (GPL-2.0), calling rtgfw (MIT).*

**Why.** An RTG board's memory is not chip RAM. On the VideoCore it is ARM-side memory, written at CPU speed, and an 8-bit CLUT screen needs no conversion. A full CPC 384x272 frame copied in **0.16 ms** (16-bit 0.46 ms, 32-bit 0.44 ms; 37% dirty lines: 0.085 ms); the lock and unlock pair costs about 2 us.

**Evidence** (A1200, Sonic GX key script, SKIP=0, sound on, interleaved runs):

| | core | display part | work | frames > 20 ms |
|---|---|---|---|---|
| AGA (c2p) | 9.0 | 4.4 | 13.5 | 18 to 23 of 2250 |
| RTG, 1x picture | 8.9 | 0.28 | 9.2 | 0 |
| RTG, Hard 50% scanlines | 8.8 | 0.55 | 9.35 | 0 |

The core is the same in every run; only the display part changes. On the key script's spring frames (the whole picture moves) the display part is 0.32 ms against 4.5 ms.

**Look up.** rtgfw `BENCH-RESULTS.md`; Arnold `RTG-PILOT.md`; chapter 10 for the method.

## The 8-bit CLUT path and the palette index

### Keep the emulator's palette indices; load the palette once a frame

**Problem.** An RTG screen in 16 or 32 bits needs every pixel converted through a table, and a changed palette rewrites pixels. An 8-bit CLUT screen needs neither, but only if the whole frame fits one 256-entry palette.

**Approach.** Arnold already folds every mid-frame colour change (a CPC pen changed during the frame, even in the middle of a line) into its own palette index when it draws, so each frame is exact to the pixel and already fits one palette, usually under 64 entries. `Palette_Compact` in `render5.c` frees the entries and renumbers the 32 pens in pen order when an entry at 64 or above is taken, with the colours unchanged (only index numbers differ). The RTG path takes the chunky frame and that palette as they are:

- the changed range of the palette goes to the screen once a frame (`LoadRGB32`, via `rtg_set_palette`);
- the border is colour 0, painted around the picture;
- nothing is converted, and a palette change rewrites no pixels.

A per-line palette record would round raster splits to line starts and draw them wrongly, so none was added. Frames that do not fit (more than 256 distinct colours) would need a 16-bit path with per-line runs; rtgfw has it (`rtg_present_ex`) and it is tested, but no Arnold frame has needed it.

**Evidence.** Headless converter test on the core's own frames (Sonic GX 2300 frames and three other commercial-class games; 49 homebrew cartridges, 1500 frames each): the screen, decoded through the CLUT as the board holds it, against the AGA colours, **0 bad pixels** in 8-bit, 32-bit and RGB565 (compared at 565 precision), with lock failures injected every 61st frame. On the real A1200 and in WinUAE the RTG screen was read back in one lock and compared with Arnold's own frame: identical on every grab.

**Look up.** rtgfw `rtg_x_read_frame`; Arnold `tools/rtg/`; switches `RTGGRAB`, `RTGDEPTH`.

## Single buffer against ChangeScreenBuffer on the VideoCore

### Three screen buffers made every frame wait 8-9 ms

**Problem.** The AGA path uses three screen buffers and `ChangeScreenBuffer`, which returns at once. The same design on the A1200's RTG screen made `rtg_present` block for most of a frame, at every depth.

**Before** (`rtgfw.c`, rtgfw v0, 3 buffers): write the next buffer, then flip.

    /* present_common(), after the lines are written and unlocked */
    if (R.nbuf > 1 && !R.degraded) {
        if (ChangeScreenBuffer(R.scr, R.sb[b])) {
            R.safe_out[b] = R.disp_out[b] = 1;
            R.shown = b;
        } else R.st.flips_refused++;
    }

**After** (Arnold 1.2, `buffers = 1`): one screen bitmap, lines written straight into it under the lock, no flip:

    rtg_o.buffers = 1;              /* no AllocScreenBuffer, no ChangeScreenBuffer */
    ...
    rtg_present(chunky, pitch, line_dirty);   /* lock, write dirty lines, unlock */

*Source: rtgfw `src/rtgfw.c` (MIT); Arnold 1.2 `amiga_sys.c` RTG branch (GPL-2.0).*

**Why.** The VideoCore driver's `ChangeScreenBuffer` waits for the 60 Hz display flip inside the call. The copy (0.16 ms), the lock and the wait for the buffer messages together took under 0.7 ms; the rest was the flip.

**Evidence** (bench, A1200, CPC 384x272): 3 buffers, present blocked **8 to 9 ms** on average (min 1.4 ms, max 15.9 ms) at 8, 16 and 32 bit; `DispMessage`s arrived at 60.0 Hz. With one buffer a full-frame present was 0.29 ms (0.17 ms with nothing dirty), and in Arnold the RTG display part is 0.28 ms on average.

**Cost.** A single buffer written at any time can tear where the refresh crosses the copy. The next section removes that without a flip. In WinUAE `uaegfx` replies to the flip at once, so no such wait shows there: **measure on the real board.**

**A failed lock.** `p96LockBitMap` can fail, and the frame is then skipped. Arnold clears its dirty marks after every present, so the skipped frame's lines must stay owed inside the framework (`rtgc_skip`, commit 2d7d1af); before that fix a skip left a stale picture until the lines changed again. The headless test injects a failure every 61st frame to cover it.

**Look up.** rtgfw commit ab66e76 (bench results); `RTGBUF=3` in Arnold re-enables three buffers for tests.

## No tearing without a flip: write at the vertical blank

### Every flip and every pan spins until the blank

**Problem.** To stop tearing we tried the usual fixes on the A1200: the flip moved into its own task, and two pages swapped with `ScrollVPort`. Each one still cost the emulator a third of the CPU or more, or made frames late.

**Why.** The VideoCore driver busy-waits for the display's vertical blank inside `ChangeScreenBuffer` and inside a pan (`ScrollVPort`), and it holds the board while it spins. A bitmap lock in any other task waits for it. So a flip in a helper task still takes the CPU if the task runs above the emulator, and comes late if it runs below. Two details matter for the fix:
- the wait returns right at the start of the blank (bench: within -5 to +10 us of the predicted time);
- a second pan in the same blank returns in about 30 us, and a pan to the page already shown may return at once.

**Evidence** (rtgbench `FLIP`, A1200, 8-bit CPC frame, CPU left for a spin loop in the first 15 ms of each frame):

| Way to present | CPU left | Late or lost frames |
|---|---|---|
| Single buffer, written at once | 100% | none (but it can tear) |
| 3 buffers, `ChangeScreenBuffer` in the emulator task | 36-38% | none |
| Flip task at the emulator's priority +1 / 0 / -1 | 37% / 72% / 68% | at 0 and -1 |
| Vblank-timed single buffer (below) | 98-99% | none |

### Find the blank with a pan pair, then write just after it

**After** (rtgfw `RTG_F_VBLANK`, commit b25c230; Arnold 1.4 `RTGVBL`, on by default for RTG):

    /* the screen is opened two pages tall (SA_Height = 2 * h); page 1 is never meant to be seen */
    vt_pan_pair();        /* pan to page 1 (spins to the blank), then straight back (about 30 us) */
    ...                   /* 9 anchors 2 ms apart; steps may be 1-3 periods; period = shortest step */
    for (;;) {            /* task at the owner's priority +1 */
        vt_wait_until(next_blank + 50 us);
        write the staged dirty lines;   /* under a semaphore, 0.1-0.8 ms */
        load the CLUT if it changed;
        if (a second since the last anchor) re-anchor at next_blank - 300 us;
    }

*Source: rtgfw `src/rtgfw.c` (MIT).*

`rtg_present` itself only copies the emulator's dirty lines into a staging frame and signals the task.

**Why it works.** A CPC frame takes 0.1-0.8 ms to write and the display takes 16.7 ms to scan. Writing starts 50 us after the blank, so the copy stays ahead of the scan: each refresh shows a frame that is wholly old or wholly new. The pan pair marks the blank without the hidden page ever showing, because the pan back happens inside the same blank. The period is measured rather than assumed, so the same code follows a 50 Hz HDMI output.

**Evidence.**
- Bench: write 0.11-0.25 ms; at most 0.37 ms late; anchor error at most 14 us.
- Arnold, Sonic GX on the Plus, RTG with hard 50% scanlines, 2250 frames: core 8.88 ms (including the write task) against 8.55 ms with direct writes; present 0.25 ms against 0.55 ms; 0 frames over 16 ms.
- A tester compared the two on the same game and judged the vblank-timed mode the best of the set.
- At 1080p50 the period measured 19998 us. Sonic GX ran at 49.9 fps with core 9.03 ms and no frame over 16 ms. In 2250 frames the write was at most 0.94 ms late, and all 45 re-anchors were good (error at most 54 us).

**Cost.** One task, one staging frame the size of the picture, and about 0.3 ms a second for the re-anchor. No palette changes within a frame and no per-line flags in this mode. If calibration finds no steady period (WinUAE's `uaegfx` replies to a pan at once), the framework falls back to direct writes and logs it.

**Look up.** rtgfw `bench/panbench.c` (the pan timing parts) and rtgbench `FLIP`. In Arnold: `RTGVBL=0` for direct writes, and the log line `rtgfw: vblank timing: refresh ... us`.

## Read every mode

### Only the first 128 of 588 modes were looked at

**Problem.** On the A1200, no RTG mode above about 400x300 could be chosen, so the scanline screen could not open at 960x540, and Arnold's menu (which wants a 640-wide 8-bit mode) fell back to the AGA screen. It showed at the first double-click on the real machine; WinUAE, with fewer modes, was fine.

**Before** (`rtgfw.c` and Arnold's menu, 26 Oct 2026 morning): a fixed list of 128.

    #define MAXMODES 128
    ...
    while (nm < MAXMODES && (id = NextDisplayInfo(id)) != INVALID_ID)
        if (mode_info(id, &modes[nm]) && fmt_group(modes[nm].fmt)) nm++;

**After** (commit d465b66 / Arnold `Sys_RtgMenuMode`): room for all of them, allocated on the heap:

    #define MAXMODES 2048          /* VideoCore lists 588; the first 128 are the small ones */
    modes = malloc(MAXMODES * sizeof *modes);

*Source: rtgfw `src/rtgfw.c` (MIT); the same fix in Arnold 1.2 `amiga_sys.c` (GPL-2.0).*

**Why.** The VideoCore driver lists 577 RTG modes (588 in all), small ones first. A "should be enough" limit silently hid every big mode. `NextDisplayInfo` has no count, so the limit must be generous, and the code that picks a mode must say in the log how many it saw.

**Evidence.** `rtgbench MODES` on the A1200 lists 577 modes; the sizes of 768 wide or more are 768x432, 768x576, 796x448, 800x450, 800x480, 800x600, 848x480, 854x480, 960x540, 1024x768, 1280x720, 1366x768, 1600x900 and 1920x1200. After the fix the 960x540 mode opens, the menu opens on a 640-wide RTG mode, and the log line "N RTG modes listed" reads 577.

**Look up.** rtgfw commit d465b66; `results/MODES-a1200-*.txt`.

## Exact integer scaling and scanlines

### Pick the mode the board scales by exactly 2

**Problem.** The 1x picture (384x272) opens in the smallest mode that holds it, 400x300, and the board scales that to 1080p by a non-integer factor. A tester's verdict on the 1x RTG picture was "motion better, colour more intense, graphics blocky", and asked for scanline options, including a blended one like the MiSTer's.

**Approach.** A scanline needs the picture at an even scale, so every CPC pixel is 2x2 and every second row is the scanline. The A1200's HDMI output is 1080p. **960x540 is the only VideoCore mode it scales by exactly 2**, so every scanline comes out the same height. 768x576 scales by 1.875, 800x600 by 1.8 and 1280x720 by 1.5, which gives uneven, beating lines. 960x540 holds 384x270 pixels at 2x, so the top and bottom border line of the 272 are cut (the tallest game known draws rows 2 to 266). Without a 960x540 mode, the smallest mode of at least 768x544 is used, with all 272 lines.

**Hard scanlines: the bank of dimmed colours (8-bit).** The core uses CLUT entries 0 to 127. rtgfw keeps the dimmed copies of those 128 colours in entries 128 to 255, at 25, 50 or 75%. The scanline row is then the normal row with bit 7 set in every byte, which a long store does four pixels at a time:

**Before** (the first version, per-pixel word stores, 0.76 ms a frame).

**After** (`rtg_conv.c`, commit 60d7bf0, two sequential passes of long stores, 0.55 ms):

    /* CLUT8 hard, 2x2: the scanline row is the row | 0x80 per byte */
    for (x = w >> 1; x; x--) { uint32_t v = PAIR8(s[0], s[1]); s += 2; acc |= v; *p++ = v; }
    p = (uint32_t *)(d + dbpr); s = s0;
    for (x = w >> 1; x; x--) { *p++ = PAIR8(s[0], s[1]) | 0x80808080u; s += 2; }
    if (acc & 0x80808080u) c->high_lines++;     /* pens of 128 or more would show undimmed */

*Source: rtgfw `src/rtg_conv.c` (MIT).*

**Why.** The palette is loaded once a frame, as without scanlines, and no pixel is converted. Both rows are written in two sequential passes because the board takes sequential writes best: the same two rows written interleaved in one fused loop were faster for Hard (0.61 ms) but slower for the 32-bit blend (1.11 ms against 0.81 ms), so the framework writes row by row.

**Blended scanlines: the in-between row is an average (32-bit).** The row between two lines is h(upper) + h(lower), with h(c) = c x (100 - pct) / 200 per channel, from two half-dimmed table entries per pen. The sum has no carry between channels. An 8-bit CLUT cannot hold every pair of colours, so this needs a 16 or 32-bit screen. A changed line rewrites its own two rows and the blend row above it. A palette change rewrites the frame in 32-bit; that happened in 2 to 3% of frames in the test games.

**Evidence** (A1200, Sonic GX, RTG present per frame):

| Option | present (avg / worst) | written a frame |
|---|---|---|
| Off, 1x CLUT8 | 0.28 / 0.9 ms | 54 KB |
| Hard, 960x540 CLUT8 | 0.55 / 1.3-2.1 ms | 219 KB |
| Blended, BGRA32 | 0.81 / 1.8-2.9 ms | 916 KB |
| Blended, RGB565PC | 1.19 / 2.7 ms | 458 KB |

Blended in 32-bit is faster than in 16-bit even with twice the bytes: RGB565PC needs a byte swap per pixel. Sonic GX over 2250 frames: 0 frames over 20 ms in 14 of 15 runs. The scaling to 1080p costs the CPU nothing. The converter test (121 cases at 2x and 4x, every format, against a per-pixel reference) and a real-board read-back (lines 1 to 270, Hard and Blended) were exact.

**Look up.** rtgfw commits d465b66, 9550c4f, 60d7bf0; Arnold `SCANLINES.md`; switches `SCANLINES=`, `RTGDEPTH=16`, `SCANMODE=<w>x<h>`.

## Host pens over the picture and the dimmed bank

### An on-screen message drawn in pen 255 was black on an RTG screen with scanlines

**Problem.** On a tester's A1200, on the RTG screen with Hard scanlines (the Arnold RTG preset), the fast-forward symbol and the save state messages never appeared, although the log said `osd: >>` every time. On AGA, and on RTG without scanlines, they showed.

**Before** (`amiga_sys.h`, Arnold-m68k 1.4):

    #define SYS_OSD_PEN 255             /* palette entry the host keeps for the label (yellow) */

**After** (`amiga_sys.h`, commit 6c73e97):

    /* 127, not 255: on an 8-bit RTG screen with scanlines, entries 128-255 are the
     * dimmed copies of 0-127, so 255 showed as entry 127 dimmed */
    #define SYS_OSD_PEN 127

*Source: Arnold-m68k 1.5, `arnold/src/amiga/amiga_sys.h` (GPL-2.0, derived from Kevin Thacker's Arnold).*

**Why.** With Hard scanlines on an 8-bit CLUT screen the framework owns entries 128 to 255 (see "Hard scanlines: the bank of dimmed colours" above): entry 128 + i is entry i dimmed, and the framework loads those entries itself from 0 to 127. The host's yellow in entry 255 was never loaded; the screen showed the dimmed copy of entry 127, which nothing used, so black on black. Any pen the host draws over the picture (messages, labels, test overlays) must be below 128, and reserved in the emulator's palette so the core never hands it to a game colour (`Render_MarkPaletteEntryForHostUse`). The core compacts game colours below 64 at each frame's end, so a reserved 127 costs nothing. On AGA, and on RTG without scanlines, all 256 entries are the host's, which is why only this one setting showed it.

**Evidence.** WinUAE with uaegfx, 8-bit, Hard 50% scanlines (no 960x540 mode there, so 800x600 with the picture at 2x): a key script held the fast-forward key for 400 frames, and the window grabs show the yellow ">>" at the top left for the 1.2 s it was held, 1178 pixels in full yellow on the picture rows and 1178 in the dimmed yellow on the scanline rows. AGA and RTG without scanlines show it as before. On the A1200, pen 255 had shown nothing; the fixed build is still to be confirmed there.

**Look up.** Commit 6c73e97; `SYS_OSD_PEN`; rtgfw `rtgc_set_scan` and `rtgc_clut_colour` (`rtg_conv.c`); option `SCANLINES=`.

## Keeping the menu on RTG

### Open the next screen before closing the old one

**Problem.** With the emulation on RTG and the menu on the AGA screen (or Workbench in between), the picture leaves the RTG output at every Help or reload. To the user it looks like a crash.

**Rule.** Open the menu on an RTG screen too (the smallest 8-bit RTG mode at least 640x256, window centred), and from start-up, not only after the first game. Never leave RTG between screens:

- when the menu is reopened (Help, Continue, Power ON, Reset, loading media, Save Prefs), open the **new** screen first and close the old one after;
- file requesters and error requesters open on the RTG screen too (`ASLFR_Screen`, a requester window on the screen) so they do not drag the display back to Workbench;
- when the RTG screen fails, fall back to AGA once and say so in the menu's status line; do not retry on every Help;
- the setting persists until the user unticks it.

**Evidence.** WinUAE and A1200 runs of the menu (Help, Continue, Power ON, Exit) with a log of every screen open and close: 0 gaps where no screen was open, Exit back to Workbench, and the memory after the run not lower than before.

**Look up.** Arnold `menu_detach` / `menu_free` in `amiga_menu.c`; the `tools/rtg/screens_check.py` log checker.

## Pacing on the E-clock, never on the RTG refresh

*Since Arnold 1.7 this rule holds with Paula sound only. With HDMI sound, or no sound, Arnold times its frames to the HDMI refresh instead: see the next section.*

**Rule.** Time the emulation exactly as on the AGA path, on the E-clock through `timer.device` (`UNIT_WAITECLOCK`), 50 or 60 Hz switchable at any time with no jump. Never wait for the RTG flip or refresh: Paula and the E-clock stay the master clock and the display must not stall them. A 50 Hz game on a 60 Hz HDMI output shows one frame in five twice, as it does on any 60 Hz AGA display (chapter 04).

**Evidence.** Bench, A1200: 50 Hz pacing standard deviation 4 us (worst 18 us); switching to 60 Hz with a screen open, 24 us (worst 120 us), 0 late frames. The native VBlank still runs under an RTG screen but the RTG screen has none of its own, so "follow the display" is forced to the emulated machine's rate in RTG mode.

A 50 Hz HDMI output removes the judder. On the test machine the Pi's `config.txt` now uses the Emu68 Imager's 1080p50 entry (`hdmi_group=1`, `hdmi_mode=31`), with `disable_overscan=1`. It affects Workbench and everything else. 60 Hz games then drop one frame in six instead. The vblank-timed writes measured the new 20 ms period by themselves.

## With HDMI sound, time the frames to the HDMI refresh

### Two clocks 0.14% apart lose a frame every second or two

*Arnold.* This is a second take on the rule above. The rule is right while Paula plays the sound, because Paula and the E-clock are then the master clock. Once the sound goes out over HDMI (through AHI and Emu68's HDMI audio driver), the picture and the sound share the HDMI clock, and the E-clock is the odd one out.

**Problem.** On the PiStorm A1200, with an RTG screen at 1080p50 and HDMI sound, Sonic GX's vertical scroll had a slight judder that a tester could feel. Writes timed to the blank (above) had removed the tearing, but not the judder.

**Before** (Arnold 1.6). Frames are paced on the E-clock: one Paula-sized block of 444 samples, 20028 µs, or 49.93 Hz. The HDMI output runs at 50.00 Hz. Each frame is written at the first HDMI blank after it is presented.

**After** (Arnold 1.7, `Sys_PaceLock`, `RTGLOCK=0|1|2` as an argument, ToolType and preference; 1 = lock with HDMI sound or no sound, the default). Each frame is due a fixed time after a predicted HDMI blank, so it is written at the next one:

    if (Sys_PaceLock && Sys_RtgActive) {
        uint32_t u, per;
        unsigned long t1 = Sys_Micros();
        int ok = rtg_x_vbl_next(&u, &per) == RTG_OK && per > 19000 && per < 21000;
        Sys_AudioLock(ok ? per : 0);
        if (ok) {
            ...
            long x = (long)(due - (t1 + u + off0)) % (long)per;   /* due against blank + the start offset */
            if (x > (long)per / 2) x -= per; else if (x <= -(long)per / 2) x += per;
            ...
            due -= x;
        }
    }

*Source: Arnold-m68k 1.8 development, `arnold/src/amiga/amiga_sys.c` (GPL-2.0), calling rtgfw (MIT). The 1.7 code is the same without the late-start offset of chapter 05.*

`rtg_x_vbl_next` returns the time to the next predicted blank and the measured period, from the vertical blank task's anchor (above). `Sys_AudioLock` sets the AHI sample rate to 444 samples per locked frame, so the HDMI sound queue stays at 1 to 2 blocks. Without it, the queue grew to 2 to 4 blocks, which adds 20 to 40 ms of sound lag. The emulated CPC then runs at 50.00 Hz, 0.14% fast, which nobody can hear. With Paula, the lock is off by default. `RTGLOCK=2` turns it on, and then a waiting Paula block is played 2 samples short now and then (about 30% of blocks), with no drops and no underruns.

**Why.** Two clocks 0.14% apart beat about three times in 45 s. Near each crossing the frame ends sit right at the HDMI blank. There, the spread of the emulation's work (7 to 15 ms a frame in Sonic GX) puts two frames into one refresh, again and again, and each lost frame is followed by a repeat. That is the judder. With a lock, every frame is due at the same place in the refresh, so the spread never reaches the blank. The anchor's pan also falls in the emulator's idle time every frame.

**Evidence.** A1200, Sonic GX scroll, 45 s runs, Blended Strong scanlines, HDMI sound:

| Pacing | Frames lost in 45 s | Frame start to the picture's write |
|---|---|---|
| E-clock (not locked), 9 runs | 14 to 42 (about 27 on average) | about 19.0 ms on average, swinging from about 10 to 30 ms |
| Locked to the HDMI refresh, 6 runs | 0 to 1 | about 19.7 ms, the same every frame |

With Paula and no lock, 10 to 13 frames were lost per 45 s. The lock costs about 0.7 ms of lag on average and removes the swing. Chapter 05's late start then wins back about 4 ms. WinUAE's RTG has no steady blank, so the lock never engages there: test it on the real machine.

**Look up.** `Sys_PaceLock`, `Sys_AudioLock`, `rtg_x_vbl_next`; notes `Docs/agent_notes/sonic16.md`, `rtg17.md`.

### The rule underneath: follow the clock the sound runs on

*Arnold, AmiPCEngine and AmiMSX.* The old rule and the new lock are the same rule: pace the emulation on the clock that the sound runs on. If the sound drifts against the frames, it underruns or piles up. If the picture drifts against the output, a frame repeats now and then. The sound is heard at once, the repeated frame less so.

- **Paula sound:** the chipset is the master clock. Arnold without HDMI sound paces on the E-clock. AmiPCEngine and AmiMSX take the machine over and pace on the Amiga's native vertical blank or a copper tick, which still runs under an RTG screen ("What AmiMSX did instead" below).
- **HDMI sound:** the HDMI output is the master clock, so Arnold 1.7 locks to the HDMI blank (above). This needs a way to find that blank. Arnold uses the vertical blank task's pan pair, which needs the operating system, so a takeover emulator cannot use it.

The cost of following Paula on a 50 Hz HDMI output is computed here, not measured. A PAL A1200 frame is 313 lines of 227 colour clocks, 20.032 ms (49.92 Hz). The measured 1080p50 period is 19.998 ms. That is 34 µs of drift a frame, so one HDMI refresh should show a picture twice about every 12 s, and the write point moves right through the scan-out in that time. Nobody has reported or filmed it yet in AmiPCEngine, so it is an expectation and not a result. Arnold's unlocked runs above lost more frames than this beat alone gives, because the spread of the emulation's work adds to it.

### A missed pan back showed a black frame

**Problem.** With the lock on, the tester saw an occasional black frame flash. The lock wasn't the cause: it happened unlocked too, just rarely.

**Before** (rtgfw up to Arnold 1.6). The anchor finds the blank by panning to page 1 and straight back to page 0. Page 1 held only the border colour, black. If the pan back missed its blank, page 1 stayed on screen for a whole refresh.

**After** (rtgfw 51b11dc, in Arnold 1.7). Just before each anchor, page 1 gets a copy of the picture now on page 0 (about 1 ms in the vertical blank task, right after a write). A late pan back now repeats a frame instead of showing black. The calibration is also tried twice before it gives up.

**Why.** A pan pair is the only blank signal the Emu68 VideoCore driver gives, and it can be held up. Wrapping it in `Forbid()` did not help: 3 held pans in 3 runs, against 0 in 3 runs without it. So the hold-up is an interrupt or the board side, not another task. A rare fault that can't be stopped can still be made harmless.

**Evidence.** 19 runs of 45 s before the fix had 6 pans back that took about 20 ms instead of about 30 µs, so 6 black frames, in 3 runs. After the fix, a screenshot of the two-page screen mid-run showed page 1 holding a full frame. The tester reported no black frame, and found the locked build "the most responsive of everything tried". The anchor's own 20 ms spin remains, 0 to 3 times in 45 s, now as a repeated frame.

**A measurement trap.** The first logs counted every palette load as a "merged" frame, because setting the palette also set the "pending" flag. Sonic GX loads its palette 71 times in 45 s, so every run looked as if it had about 71 lost frames. Count only the frames, and check a counter against a case where you know the answer before reading meaning into it.

**Look up.** rtgfw `vt_mirror`, `vt_pan_pair`; test switches `PANMIRROR=0`, `PANFORBID=1`; notes `Docs/agent_notes/rtg17.md`.

## What AmiMSX did instead: RTG inside a takeover emulator (AmiMSX)

*AmiMSX.* An earlier version of this section planned AmiMSX's RTG the Arnold way: an OS-alive play loop, a chunky renderer per mode, palettes as CLUT banks, the display code as a library. AmiMSX 4.5 shipped RTG without any of that, and the takeover stayed. It is an alternative for an emulator that owns the machine:

- **Open the screen before the takeover, then never call the OS in play.** With the OS still running, the program opens the Picasso96 screen, locks its bitmap briefly and keeps the address. In play each MSX frame is written straight into that memory. There are no OS calls, no flips and no palette loads.
- **A 16 or 32-bit screen with the emulator's own colour lookup** instead of an 8-bit CLUT. Palette changes during the frame come from the same line events the AGA copper list is built from, through our own lookup, so the palette-bank scheme planned above was not needed.
- **Only the modes that have an RTG renderer.** RTG covers the common modes; the choice is made per frame (`RtgUse`), and a frame in any other mode is drawn on AGA as before. Players with both outputs connected (HDMI from the PiStorm, AGA through a scaler) see that frame on the AGA display.
- **Pacing stays on the native chipset.** The AGA display still runs under an RTG screen, so the emulator keeps its copper-interrupt tick as the frame clock, at a fixed beam line of the native display (about line 193 on the PiStorm A1200 in RTG mode, line 258 on AGA). This is the takeover version of Arnold's rule above: the master clock is the Amiga's own, never the RTG refresh. The E-clock is not needed, because no task wait is involved.
- **One buffer, written as soon as the frame is emulated** (4.7, chapter 05). With no flip there is nothing to wait for. In the A/B by eye on the PiStorm's HDMI output, asked to look for tearing, the player did not report any.

**Evidence.** PiStorm A1200, RTG over HDMI, the player's timing log (4.7 build): from the input read to the end of the drawing 50 beam lines median, 99th percentile 9 ms. At the median, the emulation and the drawing together take about a sixth of the frame. **Look up.** `AmiMSX_Rtg_v4.asm` (header and `RtgUse`); notes `Docs/agent_notes/v45_rtg.md`.

## A takeover emulator on RTG (AmiPCEngine)

*AmiPCEngine.* The rest of this chapter keeps the OS alive, and the section above lists an OS-alive play loop as the biggest change for a second emulator. There is another route. AmiPCEngine, with a design taken from AmiMSX's RTG build, freezes the OS during play and still shows the game on a Picasso96 screen. The reference emulator here is Mesen 2, and percentages are pixels that differ from it. Commits and `docs/agent_notes/` belong to the AmiPCEngine development repository.

**The shape.** The 16-bit screen is opened and locked once before the takeover, only to read the bitmap's address, row size and real pixel format, and it is unlocked again before play. The lock must not be held across OS calls: that deadlocked the VideoCore now and then (AmiMSX commit e8121f9). In play there are no OS or Picasso96 calls: each frame is composed in fast RAM (16 sprite palettes, full width), and the changed lines are written to the framebuffer at the start of an Amiga vblank. Pacing stays on the Amiga's vblank, there is no flip, and bitplane, sprite and copper DMA are off, so there are no chip RAM writes for display at all.

	LEA	RtgRI,A1
	MOVEQ	#12,D0
	MOVE.L	RtgP96,A6
	JSR	-48(A6)			; p96LockBitMap
	...
	MOVE.L	RtgRI,RtgMem		; the framebuffer, kept for play
	MOVEQ	#0,D0
	MOVE.W	RtgRI+4,D0
	MOVE.L	D0,RtgBpr		; bytes a row

*Source: AmiPCEngine 1.1, src/RTG.asm (freeware by Juan Antonio Gómez Gálvez and z00p; used with permission).*

**Evidence** (A1200 PiStorm, 960x540 RGB565PC, frames / vblanks, guards clean):

| Title | AGA | RTG |
|---|---|---|
| R-Type | 1500 / 1544 | 1500 / 1500 |
| Parodius | 2400 / 2569 | 2400 / 2400 |
| Soldier Blade | 1500 / 1637 | 1500 / 1500 |
| HuZERO | 1500 / 1556 | 1500 / 1500 |
| PCE Invaders | 1500 / 1530 | 1500 / 1500 |

The takeover path has a cost on a slower machine with a slower board. On WinUAE's 68030/50 with `uaegfx`, RTG ran at 12% to 35% of full speed against 32% to 93% on AGA. How much of that is WinUAE's graphics card was not separated.

**Look up.** Commit 7a84eb9; switch `NO_RTG`; notes `docs/agent_notes/rtg.md`.

### The frame-end value of a register is not the frame

**Problem.** R-Type showed no sprites on RTG at first, though AGA did. HuZERO's striped logo was one solid colour.

**Before.** A renderer that composes the whole frame at the end reads each register once, so it sees the last value written. R-Type switches the sprite-enable bit at its raster splits, and at the end of the frame the bit was off. The AGA renderer never looked at that bit.

**After** (`src/RTG.asm`, `RtgCRLog`, and for colours commit 0098c1c, switch `NO_RTGPAL`): each write is logged with its line, and the renderer applies it from the next line, as it does scroll writes.

	; RtgCRLog: a write to VDC R5 (IO.asm, any time): the line it was made on and
	; the new value; it shows from the next line. All registers kept.
		...
		MOVE.W	Regs+ScanLine,(A0)
	.same:	MOVE.W	VDP_Regs+(5*2),2(A0)

For colours, the usual case must stay cheap. The palette at the end of the frame is already right for a game that writes only in the vertical blank, so the log is dropped unchanged:

	CMP.W	RtgPLog,D1		; first write before it?
	BGT.S	.mid
	CLR.W	RtgPLN			; all in the blank: the frame-end colours are right
	BRA.S	.x

If a write falls inside the picture, the renderer undoes the logged writes (last first) to get the colours at the start of the frame, then puts them back line by line, and it draws every line this frame and the next.

*Source: AmiPCEngine 1.1, src/RTG.asm (freeware by Juan Antonio Gómez Gálvez and z00p; used with permission).*

**Why.** Rendering after the frame removes every race with the beam, and it removes the mid-frame state with them. Each register a game can change between lines needs a per-line log in the frame-end renderer. Scroll had one already; the enable bits and colours did not. A hand-written log also needs a rule for two writes on one line: the later replaces the earlier (`NO_RTGFIX`), which kept the log to one entry a line.

**Evidence.** R-Type's sprites on RTG: title, play and attract within 0.9-1.3% of the reference, all from emulation drift. HuZERO's logo striped like the reference's at frames 200 and 300. Games that write colours only in the blank take the old path. The "shows from the next line" rule for colours was not checked line by line against the reference.

**Look up.** Commit 0098c1c; `RtgCRLog`, `RtgPalLog`, `RtgPalStart`, `RtgPalApply`; notes `docs/agent_notes/rtg.md`, `faults.md`, part C.

### Measure before tuning: RTG is busy 13 to 28% of the frame on a PiStorm

**Problem.** The project's policy was to put its effort into RTG speed, and a 68030 RTG run in WinUAE looked poor (above). The question was how much room was left on the real target.

**Before.** A window of debug rows read from a photo: Parodius with 80-93% spare, one title, one scene.

**After.** Run totals from the debug rows in a result file, 8 titles and 2 settings, 16 unattended runs. The method and code are in chapter 06, "[Add the windows up: run totals in a result file](06-testing.md#add-the-windows-up-run-totals-in-a-result-file)". A1200 PiStorm, 1080p50 HDMI, 960x540:

| Title | Busy, scanlines off | Busy, Blended strong |
|---|---|---|
| Parasol Stars | 12.8% | 13.3% |
| Parodius | 12.8% | 13.8% |
| R-Type | 14.2% | 14.9% |
| Soldier Blade | 18.2% | 19.4% |
| Bonk's Revenge | 20.6% | 22.1% |
| Tongueman's Logic | 20.8% | 22.9% |
| Street Fighter II' | 23.1% | 23.5% |
| HuZERO | 24.9% | 28.0% |

**Why.** In the worst title the split is CPU 10%, compose 13%, copy to the board 1.6% (5.0% with Blended strong). The copy, the part the first RTG lessons above were about, is the smallest share. Even the tightest 50-vblank window of the sweep still waits 8666 of about 13180 lines.

**Evidence.** No late frame, and frames = vblanks in all 16 runs. So RTG speed on a PiStorm is not a limit: on this machine more tuning would not add a frame. A 68030 is the limit. The sweep turned a policy into a figure before any tuning job started.

**Look up.** Commit a44eae7; STATUS, "RTG speed sweep on the A1200".

## Pitfalls from this chapter

See the RTG items in [chapter 09](09-pitfalls.md#rtg-output).
