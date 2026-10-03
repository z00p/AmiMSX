# AmiMSX open issues: theories (3 Oct 2026)

Each entry gives the symptom, what openMSX shows, the theory, how to confirm it, and the likely fix. Confidence is my estimate. The evidence files are in `build/issues/`. VDP activity was logged with `tools/omsx_vdpio.tcl` and decoded with `tools/vdpio_decode.py`.

## Summary

| Issue | Theory | Confidence | Fix size |
|---|---|---|---|
| Space Manbow: ground strip missing | SCREEN 4 renderer draws 24 name rows; the game shows rows 24-31 through vertical scroll in 212-line mode | High | Medium |
| Space Manbow: enemies missing | Mid-screen R#5 switch in sprite mode 2 isn't supported (two-pass split is mode 1 only) | High | Medium |
| Jailbreak: flashing scenery | Bitmap-mode R#23 / R#2 splits are timed from the Amiga beam, not the MSX line | High | Medium |
| Uridium 2: ship and sprites missing for seconds | Fixed 3 Oct: the HUD's sprites-off R#8 write (line 167, no table change) was sampled as the playfield's | Fixed | Register-split segments (longest wins) |
| Debug builds (TRACE, PERFSUBS) hang at boot | Fixed 3 Oct: a `BNE.S *+10` landed mid-instruction once a MOVE.L to DREGOUT98(A3) grew to 12 bytes | Fixed | Labels; build.sh rejects `*+n` branches |
| L'Abbaye: sprites over the story page | Not reproducible since 89427e6: AmiMSX's attribute table matches openMSX (all parked at Y = 193) | Resolved | - |
| MSX Unleashed: "Internal error in ..." | Z80 fault into BASIC's error handler; probably fixed by the POP/RET fix (at 60 s it now shows demo part 2) | Medium | Confirm with a 70 s+ capture |
| Snake and Rhino: page turn tiles | SCREEN 2 two-bank tile cache misses an update during the page turn | Low | Unknown |
| Snake and Rhino: colours | The game's MSX2 palette (written in openMSX at 4.3 s) never set in AmiMSX: probably an MSX1 machine type | Medium | Small |
| Metal Gear: stuck on the radio call | Needs trigger B (M) | Confirmed: in play at 92 s | Done |

## Space Manbow (R2K_SpaceManbow, KonamiSCC)

**Symptom.** In AmiMSX the rocky ground strip at the bottom is a dark blue band, and many enemies are missing.

**openMSX, during play (36 s):**
- About 4 lines after the VBlank interrupt the game switches to SCREEN 5 (R#0 = 16h), with page R#2 = 3Fh and R#23 = C0h.
- At about line 80 after VBlank, just before the display, it returns to SCREEN 4 (R#0 = 04h/14h) with:
  - R#23 = 24h (vertical scroll by 36 lines);
  - R#18 = 0Ch;
  - R#2 = 30h or 31h (name table at C000h or C400h, two 1 KB tables);
  - a line interrupt in R#19.
- At that interrupt, R#5 (sprite attribute table) changes mid-screen: E7h→EFh or F7h→FFh, alternating per frame.
- R#9 = 80h: 212 lines.
- No VDP commands are used. VRAM is written by the CPU (36-915 bytes a frame through port 98h, R#14 = 3).

**Ground strip.** With 212 lines and R#23 = 24h, display lines 220-255 of the 256-line name space come from name-table rows 24-31. That's why the game uses 1 KB name tables, not 768 bytes. AmiMSX's SCREEN 2/4 tile pass covers `32*24` names (PREPRUT1, COPYBUF and others), so rows 24-31 are never drawn: the empty band.
- **Confirm:** dump AmiMSX's SCREEN buffer at a play frame; rows 24-31 will be missing.
- **Fix:** in SCREEN 4 (and SCREEN 2 on the V9938) with 212 lines or a non-zero R#23, render 32 name rows and wrap the vertical scroll at 256 lines, not 192. Also the G3 pattern/colour tables: rows 24-31 use the fourth table block, masked by R#4/R#3 like the other three.

**Enemies.** AmiMSX supports a mid-frame sprite table switch (R#5/R#6) only for sprite mode 1. The snapshots and the two-pass IMPSPR read mode-1 tables; IMPSPR2 (mode 2) reads one table for the whole frame. Space Manbow draws its sprites from two attribute tables, one above the split and one below, so one set is lost.
- **Evidence (openMSX, 36 s):** four attribute tables in use (R#5 = E7h/EFh and F7h/FFh, a pair per frame). The table used above the split holds the sprites at Y = 80-150, the one below holds Y = 170-204; unused sprites sit at Y = 40. A renderer using one table per frame draws one half's enemies only.
- **Fix:** extend the mode-1 split to IMPSPR2: snapshot the mode-2 attribute and colour tables at the R#5 change line, and draw two passes (or bands) split at that line.

## Jailbreak (M_Jailbreak_Kon, Konami)

**Symptom.** In play, rows of the wrong scenery flash at the top of the playfield (the 60 s capture varies from run to run).

**openMSX:**
- SCREEN 5, 212 lines (R#9 = 82h).
- Each frame, at line interrupts, it flips between page 1 scrolled (R#2 = 3Fh, R#23 = 82h) and page 0 unscrolled (R#2 = 1Fh, R#23 = 0) for the HUD.
- The map scrolls with HMMM copies and an LMMM with TIMP.

**Theory.** In SCREEN 5, AmiMSX applies an R#23 write (VDP17m5) at the current Amiga beam line: it waits on `$DFF006` and records ScanningY. So where the split lands depends on how far emulation is ahead of or behind the Amiga display, not on the MSX line the game wrote at. When the timing drifts, the other page or scroll shows for a few lines: the flashing, and the run-to-run variation.
- **Confirm:** log the MSX line of each R#23/R#2 write (CurLine) next to the Amiga line used. They will differ, and the difference will vary.
- **Fix:** handle bitmap-mode R#23 and R#2 splits like the mid-frame palette and mode splits: record them as events at the emulated MSX line (TabRasCMDS) and build the copper split from those. That's deterministic, and it doesn't busy-wait on the beam (which also costs time).

## Uridium 2 (M_Uridium2_SCC, KonamiSCC): fixed 3 Oct 2026

**Symptom.** The player ship, and at times every sprite, missing for seconds at a time, in both sprite settings. openMSX only hides the ship during the death sequence.

**openMSX:**
- SCREEN 8, 192 lines, horizontal scroll by R#18 plus HMMM copies.
- R#5 alternates between FFh and F7h every frame, in VBlank: two sprite attribute tables, shown on alternate frames.
- HUD split by line interrupt (R#19 = A7h, display line 167): R#2 = 1Fh, R#23 = 0Ah, R#18 = 00h and R#8 = 2Ah (sprites off). The VBlank handler restores the playfield values.

**Cause (AmiMSX event ring, trace-lite build frozen at 39 s).** On frames where the playfield page is also 1Fh, the line-167 R#2 write changes nothing, so no table split was recorded. MIDSAMPLE then kept sampling and took the HUD's R#8 = 2Ah as the playfield's (TopR8 = 2Ah every frame). The overlay counted down and turned off, and R#18 was sampled as the HUD's 00h as well.

**Fix: register-split segments.**
- **Segments:** a change of R#8, R#18 or R#23 on display lines 16-191 (RSPLITCHK) ends a segment. Lines 0-15 count as the frame's own setup, and there are no segments after a table split.
- **Choice:** at line 192 (SEGCLOSE, before the render), the longest segment's MIDSAMPLE values are used.
- **Why not simply stop at the first change:** that broke Bun-Ga-Rua. It turns sprites off above line 79 and on below for its play area, so stopping at the first change kept the sprites-off top, and the heroine vanished.
- **Results:**
  - Uridium 2: with sprites every frame, the 30-57 s film shows the ship and enemies in every capture except the death explosion.
  - Regression (split titles): Uridium 2 at 60 s shows the ship and Nemesis 3 at 45 s shows enemies, both missing in the baselines. Bun-Ga-Rua is unchanged.
  - Chikubi Ninja: the enemies moved a few pixels against the scenery (game state unchanged: 45 s identical, and each capture is its own run). It writes R#18 = F9h/FAh (fine X scroll) for the play area and 00h at line 160 for its panel. The old sample (line 176) took 00h, so sprites ignored the play area's fine scroll, and R#18 moves sprites with the background on the VDP. Now correct; baselines accepted for Chikubi Ninja, Uridium 2 and Nemesis 3.
  - Jailbreak at 60 s: a one-line strip under the orange blocks differs. That's where its known split-timing problem is, so the baseline is kept until the Jailbreak fix.

**Still to check.** "2 frames" mode always draws one of the two alternating tables. Film it for the A1200 preset.

## Debug builds hanging at boot: fixed 3 Oct 2026

TRACE and PERFSUBS builds hung on a blue screen from 1863a1f on, and so did a release build with 4 bytes added at the wrong place.
- **Found by** an exception catcher (`-DEXCCHK`): a Line-F exception at the second word of `MOVE.L #OUT98M,DREGOUT98(A3)`.
- **Cause.** The instruction is skipped with `BNE.S *+10` (added in 1ee3275), which assumes it is 8 bytes. DREGOUT98 is OUTS - REGS: once that passes -32 KB, vasm encodes a 32-bit displacement, the MOVE grows to 12 bytes, and the branch lands on $FFFF.
- **Fix.** The three skips (and two safe `BLS.S *+8`) now use labels. `build.sh` refuses `B.. *+n` branches.
- **Debug tools added:**
  - `TRACELITE` (event ring only, full speed);
  - `CORRCHK` (code addresses in the page tables);
  - `HANGCHK` (VBlank watchdog);
  - `EXCCHK` (exception catcher, PC into the ring).
  - The ring now wraps before TrvRegs, which TraceFreeze overwrites.

## L'Abbaye des Morts: sprites over the story page (resolved)

Seen in runs with the old "collisions always on" option, and in builds before the POP/RET (1863a1f) and LD A,R (89427e6) fixes. With the current build, at frame 1400 the attribute table matches openMSX exactly: sprites 0-7 parked at Y = 193, sprite 8 = Y 208. No sprites show at 24-30 s with sprites drawn every frame or every 2nd frame.

## MSX Unleashed (R2_Unleashed, Konami)

**Symptom.** It runs into the credits scroller, then fills the screen with "Internal error in ..." by 65 s.

**openMSX.** Runs (dvik & joyrex logo, then the title). Mapper: openMSX's database says Konami (no SCC); AmiMSX's guess agrees.

**Theory.** "Internal error in <line>" is MSX-BASIC's error 51 message, not the demo's. The Z80 has left the demo and ended up in BASIC's error handler, so this is a CPU-level fault. Candidates:
1. The POP/RET 256-byte page-crossing bug fixed in 1863a1f (scrollers often read data with `LD SP,src / POP`). This is the most likely.
2. Undocumented instructions (IXH/IXL, SLL, OUT (C),0).
3. The H and N flags, which AmiMSX doesn't model (DAA after an operation it doesn't track).
- **Confirm:** run the current build to 70 s; if it still fails, use a TRACE build with TRACEFR around the crash to get the last Z80 instructions.

## Snake and Rhino in the Sketch (041)

**Page turns (symptom).** On the 2nd/3rd book page, AmiMSX shows half-updated tiles. openMSX is clean.

**Page turns (theory).** The SCREEN 2 tile cache has two banks, one per table set (added for Uridium). If the game updates the tables of the set that isn't shown and then switches R#3/R#4, the bank's dirty flags must cover those writes. A path that marks only TAB98 (or clears flags before every block is redrawn) would leave half-updated tiles. Low confidence: needs a VDP log across a page turn and an AmiMSX dump of the tile cache.

**Colours.** openMSX shows grey paper with grey rule lines; AmiMSX shows white paper with cyan lines. In openMSX the game writes a full 16-colour palette through port 9Ah at 4.3 s, and again later (65 writes after start-up), so it recolours SCREEN 2 on an MSX2. AmiMSX's palette handler (OUT9Ab) updates COLORMSX2 and the colour registers in every mode, and mode changes don't reset the palette. So the likely cause is that the game never writes the palette in AmiMSX, because it finds an MSX1 there (the machine type in the harness prefs, or how the game detects an MSX2).
- **Confirm:** check MSX2Pal in an AmiMSX PERF dump after 5 s, and AmiMSX's machine type for this run.

## Metal Gear (R2K_MetalGear)

The opening transceiver call waits for trigger B: M (or N) advances it. RETURN, ESC, F1-F5, SELECT, STOP and TAB don't (probe captures in `build/regress/mgprobe`). `tests/keys/metalgear.keys` now presses M from 58 to 96 s, then moves. Its shot times (60, 85 s) need moving to about 100 and 108 s once the overnight run is done.

## Other open items

- **Lilly's Saga:** 1-line seams at the edges of the 16-line sprite bands.
- **Uridium:** HUD colours differ from openMSX (white digits, single-colour logo).
- **DEVA: works in AmiMSX** (in play at 30 s in the 3 Oct full run). The "ERROR: You need at least 128 Kb of mapped RAM" message comes from openMSX's C-BIOS MSX2 machine (512 KB mapper in a sub-slot); with `-ext ram1mb` it runs there too. AmiMSX's 128 KB mapper is accepted. If more RAM is ever needed, a 512 KB mapper with segment mirroring would match openMSX.
- **Zanac Ex:** plays normally (full run, 3 Oct); the old title-screen problem was probably the Konami SCC decode fixed in 9e000a8.
- **Z80:** H and N flags not modelled; DAA wrong without a tracked add or subtract. Nothing known depends on them yet (L'Abbaye didn't). Plan if needed: lazy flags. The add/subtract handlers already store A before the operation (PARDAAS/PARDAAR into DatDAA). Also store which kind it was, and on PUSH AF compute N from the kind and H from A before, A after and the carry (H = (A ^ operand ^ result) & 10h, with the operand recovered from A and the result). That costs one byte store per ALU operation, with nothing extra until a game reads F.
- **PERF builds:** with the sub-timers on (-DPERFSUBS=1), some code layouts hang at boot. Not stack, flags or registers.
- **Triton:** after the title it shows a galaxy map ("Upgrade your ship or choose a planet to attack", buttons Upgrade/Password/Quit, start planet Ithaki at the bottom left). The map is random from the R register, and is the same every run since 89427e6. One RIGHT press puts a blinking red circle cursor just right of Ithaki, on a spot with no visible planet. Space 3 s later doesn't launch. Next: try moving the cursor onto a planet (UP/RIGHT combinations), or RETURN as the confirm key; ask the user for the exact sequence.

## Run-to-run variation (full run, 3 Oct 2026)

52 of 66 titles were pixel-identical across two runs. The ones that varied: Bomb Jack, Zanac, Zanac Ex, Zanac Ex Enhanced, Triton, Alien Attack, Universe Unknown, Bit Logic, Knight Lore, Sacred Valley, Bold, Invasion and io.

**Cause found:** AmiMSX's `LD A,R` returned the Amiga's horizontal beam position (`$DFF007`), so every game that seeds randomness from the R register ran differently on each run. R is now derived from the emulated time (line, cycles left in it, frame counter). Re-calibrated with that build (89427e6): 12 of the 13 are now pixel-identical across runs, including the Zanac family, Bomb Jack and Triton.

**Still varying: io (disk).** Its 60 s capture differs only in the phase of an animated element (a few frames). Likely cause: disk loading time. If AmiMSX's disk routines wait on real AmigaDOS reads while MSX frames keep counting, the load time varies with host disk speed and shifts everything after it. That also fits io's earlier variation at its 20 s logo transition. Low priority; marked unstable in the baseline.
