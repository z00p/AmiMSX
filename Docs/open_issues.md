# AmiMSX open issues: theories (3 Oct 2026)

Each entry gives the symptom, what openMSX shows, the theory, how to confirm it, and the likely fix. Confidence is my estimate. The evidence files are in `build/issues/`. VDP activity was logged with `tools/omsx_vdpio.tcl` and decoded with `tools/vdpio_decode.py`.

## Summary

| Issue | Theory | Confidence | Fix size |
|---|---|---|---|
| Space Manbow: ground strip missing | Fixed 3 Oct: the playfield is below a table split (R#2 3Fh to 30h at line 81), drawn by HUDSplit4, which stopped at line 192; now 212 with R#9 LN | Fixed | - |
| Zanac EX: sprites flicker / vanish near the status bar | Fixed 10 Oct (546c8e5). The sprite bands were 16 lines each, so the status bar's sprites-off band ran on into the playfield; frames where the game's split came a line or two late lost the sprite entirely (one-frame vanish = flicker). A sprite-register change now starts a band at the next line. Confirmed with 16 consecutive frames against openMSX (`build/strips/zanacex_prenew.png`) | Fixed | - |
| Uridium (MSXdev 2014): HUD title and score characters drawn with rows missing | Open (11 Oct, user report from the smoke run's WinUAE window). The 'URIDIUM' logo and the Score digits lose rows; 'Zinc' looks complete. The HUD sits above the mid-frame table/sprite split (per-block table masks, two cache banks, HUD sprites in GFXSPRT); its colours already differed from openMSX (white digits, single-colour logo). Compare against openMSX VRAM at the same frame | Medium | Unknown |
| Zanac (MSX1): enemy ("AI") ships drawn green with black outlines on the round 1 field. Should they be green? | Open (11 Oct, user report from the 030 WinUAE window, `build/zanac_ai_ships_user_1011.png`). To check: same moment in openMSX, and the sprite colour bytes in the SAT (sprite colour vs. colour 0 / transparent handling, or the same colour-conversion difference as Barbarian's sky) | Low | Unknown |
| Head over Heels Remake (026, KonamiSCC): menu text drawn with letters missing | Open (12 Oct, top-30 baseline at 45 s, `build/top30_45s.png`). The menu lines show only some letters. Compare with openMSX at the same moment (VRAM name/pattern tables); likely a SCREEN 2 pattern cache or colour-table update | Medium | Unknown |
| Uridium 2: no sense of speed in the opening space scene (stars) | Open (12 Oct, user report). Motion study (tools/motion_study.py, 24 and 30 s): openMSX pans the whole view +1 dot per frame, AmiMSX 0. **VRAM is right:** at the same MSX frame (1273) both emulators hold the same 8 bitmap stars in page 1 (openMSX shows page 1 then; AmiMSX dump build/perf/M_Uridium2_SCC_u2vram.bin, openMSX dumps build/u2omsx/). **The motion is R#18:** in vblank (1 line after the IRQ) the game sets the playfield's R#18 one step further each frame (0Ch, 0Dh, 0Eh...), and about line 187 sets 00h for the HUD (openMSX I/O log, build/u2omsx/u2.vdpio.txt). AmiMSX writes R#18 per line into the copper (AcCoRutAdjust: BPLCON1 + window), so the open question is which value reaches the playfield lines in SCREEN 8: next, log R#18 writes by CurLine (BANDCHK build, VDP12/MiraInter0 entries) | Medium | Unknown |
| Nemesis 2: stray cyan dots on the play-select screen and in play | Open (11 Oct, user report). openMSX shows none. 8-frame bursts in play: AmiMSX had one cyan dot that never moved (90 s), openMSX none. The starfield scrolls by rotating each star's pattern byte (and shifting the tile row on a wrap), so a missed SCREEN 2 cache update would leave exactly such a dot. A perf dump showed no error (screen buffer one frame behind VRAM, consistent). Next: a dump taken at render time (VRAM + screen buffer together), and the frame where a dot appears. tests/keys/n2play.keys reaches play (Space through the story); the regression's 'play' keys never leave the story, so its captures miss gameplay | Medium | Unknown |
| Nemesis 2: ship missing for one frame in the hangar intro | Open (11 Oct). 16-frame burst at 17 s: frame 4 has no ship; openMSX at the same scene shows it every frame (not frame-locked, so possibly timing). Check with n2play keys | Low | Unknown |
| Ianna: hero drawn in vertical stripes | Fixed 11 Oct. The hero is drawn with LMMC (TIMP, DIX 1) from bytes the game makes with RLD/RRD straight on its ROM graphics. AmiMSX's RLD/RRD read (HL) through the write pointer (the NORAM dummy for ROM), so A never got the nibble and every second pixel was 0 (transparent). Found by tracing the R#44 byte stream (trace build: TRVLOG $2C, -DTRVLMMC=24 freezes after the first 24-dot LMMC) against openMSX's; test ROMs tools/make_cmd_test.py and tools/make_ianna_test.py confirmed LMMC/HMMM themselves were right | Fixed | - |
| Barbarian: sprite flicker | Not reproduced (10-11 Oct): 16 consecutive frames at 22/28/34/40/45 s in two runs show clean frames; the only A-B-A change is the fighter's walk cycle | Low | - |
| Barbarian: sky colour (cream/white, openMSX salmon/peach) | Open, narrowed 11 Oct. tools/pal_probe.py at MSX frame 1960: AmiMSX's MSX palette (MSX2Pal, PalTop) is identical to openMSX's (4 = 754, 5 = 743), no palette events are active, and the copper's gameplay palette routine holds the right Amiga values (COLOR04 $E86, COLOR05 $EA8). So the MSX side is right and the difference is on the Amiga display side. Leads: (1) the copper routine area still holds the title screen's gradient palette ($200..$EE8); check whether any line slot reaches it; (2) the AGA colour path (MCAGA index EOR, 8-bit LOCT); (3) other titles' skies are also brighter than openMSX (Lilly: cyan vs light blue), so compare the whole colour conversion with openMSX | Medium | Unknown |
| Lilly's Saga: dotted line at the HUD split, into the right border | Fixed 11 Oct. The game turns the display off (R#1 BL) for two lines while it switches tables; AmiMSX ignored mid-frame BL and showed the half-switched line. BL changes during the display now blank lines (AGA: one BPLCON4 write to a border-coloured bank; ECS: colour MOVEs). Also fixed: colour 0 with TP off showed palette 0 on lines with copper palettes (Lilly's sky coin was black, openMSX yellow). Jailbreak and Zanac EX Enhanced split lines changed the same way | Fixed | - |
| Pampas & Selene - The Maze of Demons (2023, 2 MB ROM): black screen after Power ON | Fixed 12 Oct: flash Konami SCC mapper (7FFFh bit 4 enables AMD flash commands: unlock, program, 64 KB sector erase, all instant; ROMs over 512 KB only). The game now boots and plays (1 erase, 162 programs at its first save setup). Saves live in memory only (not written to disk yet). History: (11 Oct, user report on BigMig, AmiMSX 4.0 PiStorm prefs, Slot 1 = the .rom, Slot 2 = Disk ROM (DOS), MSX2, 256 KB, SCC). Screen stays black. The ROM is 2,097,152 bytes - larger than the usual 512 KB/1 MB megaROMs: check which mapper the size/guess picks (openMSX: look up the SHA1 in its softwaredb; the game is likely ASCII16 or a newer 'Pampas' mapper), whether AmiMSX supports 2 MB on that mapper, and the disk ROM is ruled out: still black with Disk ROM None / Slot 2 empty, MSX2+ BIOS, 2048 KB RAM, PSG (user retest 11 Oct). So it is the cartridge itself: mapper detection/support for this 2 MB ROM (SHA1 b6d3a4dd336dc20e942b0ec800ef9c10aba95a02). Compare with openMSX boot. Note: the Top 30 launcher icon for this game starts fMSX, not AmiMSX. **Found 11 Oct (openMSX):** with the autodetected KonamiSCC mapper openMSX hangs the same way (black screen): the game polls for a flash chip (its save support) in a loop at about CE13h. With `-romtype KonamiUltimateCollection` (Konami SCC banking plus an AMD flash chip and its command/status protocol) it reaches the title and plays. Its SHA1 is not in openMSX's database. So AmiMSX needs a KonamiUltimateCollection-style mapper (SCC banks + flash ID/status reads, writes optional) for this ROM; added to the suite as 002_PampasSeleneTheMazeofD (romtype KonamiUltimateCollection) | Fixed | - |
| Jailbreak: 2-line strip flickers near the bottom | Open (11 Oct). night-1010 burst at 60 s: a full-width 2-line strip on top of the orange buildings changes for 4 frames in AmiMSX only. Probably the known beam-timed R#23 split | Medium | Unknown |
| Zanac EX: status bar edge wobbles 1-2 lines | Open (10 Oct). The playfield's first line moves 1-2 MSX lines in 4 of 16 AmiMSX frames (once with a junk line) against 1 of 32 in openMSX: the line at which the game's split writes take effect varies more. Compare R#2/R#23/R#19 write lines per frame (TRVLOG trace vs omsx_vdpio). Plain Zanac EX also runs at 79-90% speed on the 030 config (Enhanced ~100%) | Medium | Unknown |
| Space Manbow: sprites missing / misplaced | Fixed 10 Oct. (1) Sampling stopped at the table split at line 30, so the frame took the status bar's sprites-off R#8; table splits now end a segment. (2) The sprite-mode-2 bands used one R#23 for all bands: the ship was drawn with the status bar's C0h and landed on the ground row. Each band now has its own R#23, and bands with sprites off (SPD) are skipped, so nothing shows over the status bar | Fixed | - |
| Jailbreak: flashing scenery | Bitmap-mode R#23 / R#2 splits are timed from the Amiga beam, not the MSX line | High | Medium |
| Uridium 2: ship and sprites missing for seconds | Fixed 3 Oct: the HUD's sprites-off R#8 write (line 167, no table change) was sampled as the playfield's | Fixed | Register-split segments (longest wins) |
| Debug builds (TRACE, PERFSUBS) hang at boot | Fixed 3 Oct: a `BNE.S *+10` landed mid-instruction once a MOVE.L to DREGOUT98(A3) grew to 12 bytes | Fixed | Labels; build.sh rejects `*+n` branches |
| L'Abbaye: sprites over the story page | Not reproducible since 89427e6: AmiMSX's attribute table matches openMSX (all parked at Y = 193) | Resolved | - |
| MSX Unleashed: "Internal error in ..." | Z80 fault into BASIC's error handler; probably fixed by the POP/RET fix (at 60 s it now shows demo part 2) | Medium | Confirm with a 70 s+ capture |
| Snake and Rhino: CONTROLS page garbled | Known, narrow: a race in the game. It draws the page with interrupts on, setting each VRAM address with two port-99h writes; in AmiMSX the VBlank interrupt lands between them, and the BIOS handler's S#0 read resets the latch, so colour bytes go to the pattern table. openMSX's timing misses that 2-instruction window. Accepted as a known issue (3 Oct) | Known | Timing study if other games show it |
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
- **What it really was (3 Oct 2026):** AmiMSX's VRAM has rows 24-31 (rendered with tools/render_scr4_full.py), and the SCREEN 4 tile pass covers 32 rows. The R#2 change at line 81 (status page 3Fh to name table 30h/31h) is a table split, so the playfield (lines 81-211) is drawn line by line by HUDSplit4 into SCREENB, which stopped at line 192. Lines 192-211 showed the backdrop. Fixed: HUDSplit4 runs to line 212 in 212-line mode.
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

## Zanac EX: title shows the graphics pages (fixed 3 Oct 2026)

**Symptom.** From about 6 to 14 s AmiMSX showed VRAM page 1 (the game's graphics sheets), with sprites off, instead of the title being built on page 0. openMSX keeps the display blanked while it builds, then shows the title.

**Cause** (event ring and a full trace frozen on the R#2 = 3Fh write):
- During the title the game sets R#23 = 30h with R#19 = 0, so the line-interrupt line is (0 - 30h) & 255 = 208, with line interrupts off (IE1 = 0).
- AmiMSX raised FH (S#1 bit 0) at line 208 anyway and held it for 7 lines.
- The VBlank interrupt at line 212 found FH set, so the game's handler (4BEEh, bank 14) took its line-interrupt path. With VR (S#2 bit 6) set, that path selects page 1 (R#2 = 3Fh), R#23 = D8h, R#19 = E4h and sprites off.

**Fix.** With IE1 off, InterHor shows FH only during the matching line (cleared at the next line). With IE1 on, nothing changed: FH stays up to 7 lines or until read, and requests the interrupt.
- openMSX does the same, measured with a probe on status reads. Zanac's handler reads S#1 = 00h after a match at line ~208.
- Jailbreak sets R#19 and then polls FH with IE1 off (4350h: `IN A,(99h) / RRCA / JR NC`). A first fix that never raised FH with IE1 off left Jailbreak on a black screen.
- Zanac's title and its GAME START menu now match openMSX.

**Also seen.** The VR timing in IVDP2 uses only the line's low byte, so lines 256-312 (still in VBlank) report VR clear. It is not involved here, but needs fixing (see Other open items).

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

- **VR flag (S#2 bit 6) after line 255:** IVDP2 compares only the line's low byte, so PAL lines 256-312 read as in the display (VR clear).
- **Chikubi Ninja:** enemies vanish near the hero (user report, 3 Oct). Check the 8-sprites-per-line handling and collisions (off in the defaults).
- **Zanac EX:** the score area at the top in play may differ from openMSX (user report, 3 Oct). Compare.

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

**Disk demos failing together (4 Oct 2026): fixed 10 Oct.** In the overnight run and two re-runs the same night, bold, invasion, io and akin2 failed: the MSX-DOS prompt, a blank screen or no capture. On 10 Oct the byte-identical binary passed, and the disk images were unchanged, so it wasn't the code.
- **Not the emulated disk reads:** a DSKIO read on the MVD drive copies from the image in RAM (DIRVD0), with no host I/O and no emulated time.
- **The weak point was loading the image:** the 720 KB read in LOADVD never checked its result, and AmigaDOS Read may return less than asked or fail. A short read left the rest of the image empty, so DOS booted but couldn't load the demo, which matches the symptoms.
- **Fix:** READFILE now reads until all bytes are in (or end of file or an error) and reports a short read. The disk loader treats a short read as an error ("File read error: aborted.") and leaves the drive empty.
- **After the fix:** all five disk demos match their baselines at every capture (10 Oct). The 4 Oct failures were never reproduced, so the short read is the likely cause, not a proven one.

**Still varying: io (disk).** Its 60 s capture differs only in the phase of an animated element (a few frames). Likely cause: disk loading time. If AmiMSX's disk routines wait on real AmigaDOS reads while MSX frames keep counting, the load time varies with host disk speed and shifts everything after it. That also fits io's earlier variation at its 20 s logo transition. Low priority; marked unstable in the baseline.

## Lilly's Saga: save-slot menu text as solid blocks, Smooth display off (open, 14 Oct 2026)

- **Seen:** PiStorm A1200, release candidate 188a9a0, Lilly's Saga reloaded with Smooth display off. The SELECT SLOT boxes show '(LOCKED)' and 'NEW!' with letters drawn as solid blocks. The same symptom was seen on BigMig before 76a3bed. With Smooth display on, the PiStorm shows the menu correctly.
- **What draws it:** the glyphs are drawn once with VDP commands (LMMM with TIMP and TXOR, page 3 to page 2) in SCREEN 5, not with the SCREEN 4 tile cache (Fable, openMSX log).
- **Already tried:** BBUSY dummy reads before every blitter wait (8af1d95).
- **To check:** the command engine's blitter path for transparent copies on fast CPUs: the mask chain in TIMPES, the BLTxPT/BLTCON set-up between planes, and whether something writes the same chip RAM during a running blit (the SCREEN 5 band conversion, CPU fallback paths). Run tools/make_cmd_test.py's ROM on the PiStorm and compare with WinUAE.

## Lotus F3: the car jitters while moving (open, 14 Oct 2026)

- **Seen:** PiStorm A1200, release candidate (video 14 Oct). The player's car jitters while it moves.
- **To check:** compare against openMSX with tools/burst.py, logging the car's sprite X/Y per frame and the road's split registers. It may be the same root as Bombaman's ghosting or Manbow 2's ship jumping back (a sprite shown at a stale position for a frame).

## CD32-style pad: direction and fire not together (open, 14 Oct 2026)

- **Seen:** PiStorm A1200 with a KTRL CD32 pad in the joystick port. In Pampas & Selene you can't move left or right and jump at the same time. It wasn't noticed on BigMig (different controller set-up).
- **To check:** AmiMSX's joystick read (LEEJOY, TesteaJoyRut). It reads port 2 through JOY1DAT and the fire button through CIA-A $BFE001 bit 7, plus POTGO for the second button. A CD32 pad answers the CD32 protocol (button shift register clocked through POTGO/CIA). If AmiMSX writes POTGO ($DFF034 = $FF00) every read, the pad may switch modes and drop either the direction or the button. Also check which MSX key or trigger Pampas & Selene uses to jump: trigger A, trigger B, the space key or Up (then it is about diagonals, not buttons), and whether a plain Amiga joystick behaves the same. Note: $FF00 in POTGO drives pins 5 and 9 high, which is the state that keeps a CD32 pad in plain joystick mode, so the POTGO theory is weak; change the read only with a pad to test against.

## Lilly's Saga: occasional music slow-down with Smooth display (open, 14 Oct 2026)

- **Seen:** PiStorm A1200, PiStorm preset (60 Hz, Smooth display). The picture and sound are good, but the music slows now and then.
- **Analysis (Fable, openMSX profile; build/lilly_slow/):**
  - **The game's load:** it rewrites the whole name table each frame and flips pages, with a HUD table split at line 174.
  - **Seam frames:** walking, every 4th frame the column shift changes 171-186 tile pairs. Each pair is one blitter copy, about 110-120 lines on the blitter.
  - **The next frame:** DbCatch copies 18-22 changed rows, about 130 lines.
  - **Result:** those two frames land at 200-250 of the 252 lines available, so some are late.
  - **Why one late frame costs a whole Amiga frame:** the commit only takes effect at the next VBlank, and DbPre waits for it before drawing. The game's VBlank music driver then ticks once in two Amiga frames, which is the tempo drop. DbLineSafe and a third per-line list wouldn't change this.
- **Fixes (exact emulation):**
  1. **Skip-commit catch-up:** when a frame overran, keep drawing the next MSX frame into the same back buffer and commit that one. The display drops a frame instead of repeating one, and the emulation holds 60 fps.
  2. **Make seam frames fit:** do the DbCatch copy and the tile path with the CPU from fast-RAM shadows on 040/060/PiStorm, and overlap CPU-only work with DbCatch.
  3. **Room loads:** a long-write pattern-cache layout.
- **Quick check on hardware:** play the same stretch with Smooth display off. If the music no longer slows, the commit wait is confirmed and fix 1 is the one to do.
- **Diagnostics for the Measure build:**
  - late-frame count;
  - lines waited in DbPre and DbLineSafe;
  - maximum frame length;
  - DbCatch rows and tile blits per window.

## Manbow 2 (001_Manbow2): corrupt intro screens, ship jumps back (open, 14 Oct 2026)

- **Seen:** on the PiStorm A1200 (release candidate 188a9a0, PiStorm preset). The intro screens are drawn corrupted: the title logo shows as scattered dots and broken lines instead of solid artwork (photo 14 Oct). In play (SCREEN 5-style scrolling cave, HUD on top) the ship moves normally but now and then jumps back 3-4 dots while it moves.
- **Not MSX2+:** the V9958 scans show Manbow 2 never touches R#25-27 or the YJK modes; it is a plain MSX2 game.
- **To do (post-release):** compare the intro against openMSX frame by frame (tools/burst.py) for the screen mode, VDP commands (the logo is probably drawn or revealed with LMMM/LMMC/HMMV or a dissolve) and the page/R#2 flips; for the ship, log the sprite X per frame against openMSX: a jump back of 3-4 dots suggests a stale sprite attribute (the mode-2 band snapshot or the double-buffered overlay showing the previous frame's position), an R#18 adjust applied to sprites, or the scroll compensation the game does.

## Bombaman: sprite ghosting on fast machines (open, 14 Oct 2026)

- **Seen:** on BigMig and the PiStorm A1200 (PiStorm preset and others), at 50 and 60 Hz. Moving characters look doubled or see-through to the eye. The RetroTink 4K genlocks to the Amiga's rate, so it isn't frame-rate conversion.
- **Slow-motion video (240 fps camera):** each captured frame shows one sharp character, and the movement looks normal frame by frame. The pose changes every 1-2 display frames; openMSX holds idle poses about 20 frames, but the tester may have been steering.
- **Checked:** openMSX with the real MSX2 ROMs shows the same walk animation (the head bob is the game's own). Fixed in 4.0 without curing it: sprite pointers not rewritten while the copper loads them (SprBeamOK), the sprite-buffer switch wait, palette changes at frame starts.
- **To do (post-release):** a Fable review of the sprite path in SCREEN 5 without smooth display (SPR1DBL, CREASPRITES, DIRSPRIT in MASTERCOPPER, the sprite overlay buffers), what an eye integrates that a camera doesn't (a sprite shown in two positions within one displayed frame, e.g. a mid-frame pointer or position change, or the overlay showing the previous buffer for part of the frame), and a diagnostic for BigMig/PiStorm.

## DEVA: the hero's head is missing (14 Oct 2026)

- **Seen:** a tester, in the WinUAE regression window. The robot hero shows body and legs but no head (helmet, face).
- **Not a regression:** the baseline captures from before the 4.0 display work show the same headless hero, and build 8af1d95 matches them pixel for pixel.
- **Reference:** openMSX on the real-ROM machine (AmiMSX_MSX2_Disk; the C-BIOS machines stop at "You need at least 128 Kb of mapped RAM") shows a dark helmet with a skin-coloured face on top of the body.
- **To check:** whether the head is a separate sprite, which sprite mode the game uses (tests/titles.csv says MSX1, but the game wants 128 KB of mapper RAM), the sprites-per-line limit and its priority order, and colour mixing (the CC bit in sprite mode 2).

## Gradius III Legends: disk write and display (open, 14 Oct 2026)

- **Seen:** a tester on real hardware. "Disk write protected" at start: the game writes to its disk, and the MVD drive defaults to write-protected ($61=$FF). Unprotecting the drive cures it.
- **Also seen (video, 4.5 s):** the game runs in SCREEN 5 (openMSX scan: S5 1298 of 1736 frames, 30 bitmap VDP commands). Ship, enemies, bullets and scenery draw. Then the scenery breaks up into horizontal lines, row by row, and vanishes, leaving the star field. Then the screen goes blank and "STAGE 01 / REST 00" appears. The video doesn't show whether the line break-up is the game's own wipe (e.g. a line-by-line HMMV/LMMV clear) or a missing VDP command.
- **To do (post-release):** get the tester's list of what is wrong. Reproduce the same moment in openMSX on AmiMSX_MSX2_Disk with tools/burst.py (disk titles now run there; the C-BIOS machines have no disk ROM) and compare frame by frame. Log VDP commands (tools/omsx_cmdlog.tcl) across the transition. Also consider whether presets should default to an unprotected MVD drive.

## Second fire button not seen with a CD32-style pad (open, 14 Oct 2026)

- **Seen:** a tester, KTRL CD32 pad, Gradius 2 (grad2tr): the second button doesn't select the power-up.
- **Checked (game side):** Gradius 2's input routine (ROM $5D40) writes PSG R#15=$8F (joystick port 1), reads R#14 for the stick and both triggers (AND $3F), then ORs in $20 (trigger B) when M or N is pressed (SNSMAT row 4, bits 2-3). So power-up select is MSX trigger B, or the M/N keys.
- **Checked (AmiMSX side):** TesteaJoyRut maps Amiga port 2 to MSX joystick 1. Trigger B is set from POTINP DATRY (pin 9) or DATRX (pin 5) after writing POTGO=$FF00, or from Left Amiga. INA2 and SOUND15 return DATOJOY1 for R#15 bit 6 = 0. This is the usual Amiga second-button read, so the emulator path looks right.
- **To check:** whether Left Amiga or M selects the power-up for the tester (this splits pad from emulator). Whether the KTRL's blue button shows on pin 9 in plain joystick mode in other two-button Amiga games. Whether a fast CPU needs a longer gap between the POTGO write and the POTINP read (one NOP now). Whether anything else (input.device via potgo.resource) rewrites POTGO while AmiMSX runs. Same pad as the Pampas & Selene report above.
