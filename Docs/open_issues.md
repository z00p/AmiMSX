# AmiMSX open issues: theories (3 Oct 2026)

Each entry gives the symptom, what openMSX shows, the theory, how to confirm it, and the likely fix. Confidence is my estimate. The evidence files are in `build/issues/`. VDP activity was logged with `tools/omsx_vdpio.tcl` and decoded with `tools/vdpio_decode.py`.

## Summary

| Issue | Theory | Confidence | Fix size |
|---|---|---|---|
| Space Manbow: ground strip missing | SCREEN 4 renderer draws 24 name rows; the game shows rows 24-31 through vertical scroll in 212-line mode | High | Medium |
| Space Manbow: enemies missing | Mid-screen R#5 switch in sprite mode 2 isn't supported (two-pass split is mode 1 only) | High | Medium |
| Jailbreak: flashing scenery | Bitmap-mode R#23 / R#2 splits are timed from the Amiga beam, not the MSX line | High | Medium |
| Uridium 2: ship drop-outs | "2 frames" sprite mode samples one of two alternating sprite tables | High | Small (setting), see L'Abbaye |
| L'Abbaye: sprites over the story page | Stale story screen while gameplay sprites are live | Medium | Unknown |
| MSX Unleashed: "Internal error in ..." | Z80 fault drops into BASIC's error handler; possibly fixed by the POP/RET fix | Medium | Check first |
| Snake and Rhino: page turn tiles | SCREEN 2 two-bank tile cache misses an update during the page turn | Low | Unknown |
| Snake and Rhino: colours | The game's MSX2 palette (written in openMSX at 4.3 s) never set in AmiMSX: probably an MSX1 machine type | Medium | Small |
| Metal Gear: stuck on the radio call | Needs trigger B (M) | Confirmed in probe | Done (key script) |
| DEVA: "needs 128 Kb of mapped RAM" | Mapper size detection fails on AmiMSX's unmirrored 128 KB mapper | High (runs in openMSX with 1 MB) | Small |

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

## Uridium 2 (M_Uridium2_SCC, KonamiSCC)

**Symptom.** The player ship drops out in some frames. openMSX only hides it during the death sequence.

**openMSX:**
- SCREEN 8, 192 lines.
- Bottom split for the HUD (page flip plus R#23/R#18).
- Horizontal scroll by R#18 plus HMMM copies.
- R#5 alternates between FFh and F7h every frame, in VBlank: two sprite attribute tables shown on alternate frames.

**Theory.** AmiMSX's default "2 frames" sprite setting (DirPrefs+$16 = 2) draws the mode-2 sprite overlay every other frame, so it always samples the same one of the two tables. Anything the game puts in only one table, such as when it rotates sprites to keep within 8 per line, shows intermittently or not at all.
- **Confirm:** run with sprites every frame (the key-script `option sprites 1` works since 1863a1f).
- **Fix:** default to sprites every frame in the 030/50 and Emu68 builds. That first needs the L'Abbaye story-page issue checked, since it showed up with sprites every frame.

## L'Abbaye des Morts: sprites over the story page

**Symptom.** In some AmiMSX runs, crusader sprites show over the story text page.

**openMSX.** Through the whole story page, sprites 0-7 are parked at Y = 193 (below the 192 lines), and sprite 8 is the Y = 208 end marker. At 30.5 s, when play starts, they move to gameplay positions.

**Theory.** The sprites AmiMSX shows look like gameplay sprites, so AmiMSX is probably still showing the story screen after the game has drawn the play screen: a stale tile screen while the sprites are live. One possible cause is a screen update skipped while the display is blanked (R#1 BL), or the "Refresh 100%" setting being off. It is probably not the sprite renderer itself.
- **Confirm:** PERF dump at those frames (MSX frame ~1300-1550): the attribute table and name table against what's on screen.
- **Fix:** depends on the cause.

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
- **DEVA:** not a stall. Both emulators show the game's "ERROR: You need at least 128 Kb of mapped RAM". openMSX's C-BIOS MSX2 machine has a 512 KB mapper in a sub-slot and is refused too; with `-ext ram1mb` (a 1 MB mapper in its own slot) the game runs ("VR testing facility"). AmiMSX has an 8-segment (128 KB) mapper with segments 8 and up mapped to NOMEM/NORAM; a real 128 KB mapper mirrors them (segment AND 7), and size detection relies on that wrap. **Fix:** a 512 KB mapper (32 segments, mirrored above that), as in openMSX; cheap on 030/040 and PiStorm machines. Also check what the mapper ports FCh-FFh return when read (real MSX2s return the segment with the unused upper bits set).
- **Zanac Ex:** plays normally in AmiMSX and openMSX (probe captures at 38-56 s); the old title-screen problem was probably the Konami SCC decode fixed in 9e000a8. Confirm the title screen in the overnight captures.
- **Z80:** H and N flags not modelled; DAA wrong without a tracked add or subtract. Nothing known depends on them yet (L'Abbaye didn't). Plan if needed: lazy flags. The add/subtract handlers already store A before the operation (PARDAAS/PARDAAR into DatDAA). Also store which kind it was, and on PUSH AF compute N from the kind and H from A before, A after and the carry (H = (A ^ operand ^ result) & 10h, with the operand recovered from A and the result). That costs one byte store per ALU operation, with nothing extra until a game reads F.
- **PERF builds:** with the sub-timers on (-DPERFSUBS=1), some code layouts hang at boot. Not stack, flags or registers.
- **Triton:** the launch sequence is still unknown (waiting for the user).
