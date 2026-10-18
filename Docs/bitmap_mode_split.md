# Bitmap mode splits: SCREEN 8 over SCREEN 5 (15 Oct 2026)

Manbow 2's title (see the Manbow 2 entry in `open_issues.md`) is a SCREEN 8
logo above display line 141 and a SCREEN 5 band below it, each with its own
page and vertical scroll, switched by a line interrupt every frame and
switched back in the vertical blank. AmiMSX's only mode-split renderer was
SCREEN 5 above SCREEN 4 (MSplitFill), so the frame rendered in one mode with
one set of planes and the logo showed as dots. This document is the design
of the bitmap-pair split (8 over 5, and 5 over 8 on the same path) and
describes the code on branch `cloud/bitmap-mode-split` (from `wave1`, which
has the DMACON fix the title needs). Built with vasm, not yet run.

## What the display path does today

- **SCR0 holds VRAM converted into the current mode's layout.** SCREEN 5:
  4 planes of 32 KB (NexBpl5), 1024 lines of 32 bytes, so the four 32 KB
  pages are contiguous. SCREEN 8: 8 planes of 16 KB (NexBpl8), 512 lines.
  The two layouts overlap everywhere in SCR0, so one buffer can't hold a
  SCREEN 8 page and a SCREEN 5 page at the same time.
- **SCREEN 5 writes go straight into the planes** (OUT98A: five BFINS per
  byte; OUT98AT also sets the TAB98 dirty flags during a split regime).
  VDP commands draw with the blitter into the planes. Entering SCREEN 5
  (ModoGfx5) reconverts the 1 KB blocks written in other modes (VBlk5,
  ActPlanos5) or all of VRAM when SCR0 was reused (V5All).
- **SCREEN 8 writes only flag VRAM** (OUT98B sets TAB98, no write-through)
  and PasaPun8Bpl converts the flagged 32-byte runs into SCR0 when PRINT8
  renders a frame. Entering SCREEN 8 (ModoGfx8) sets V5All: SCR0 belongs to
  SCREEN 8 from then on.
- **The copper.** MASTERCOPPER loads the sprite pointers, DMACON, the 16
  sprite colours and the 16 MSX colours, then jumps to the mode's list
  (NEXTCOPP, applied by the copper interrupt at the end of each display).
  COPPER5 sets the modulo, BPLCON0 (4 planes) and the plane pointers;
  COPPER8 first loads its fixed 256-colour palette (Scr8Pal: all eight AGA
  banks), BPLCON4 $0022, then 8 planes. Both then jump into the per-line
  event list (CopperLine, ActCopperLine): every line with an event gets a
  routine with plane pointers (AcCoRutGBY by the frame's ScrModo, from the
  line's R#2/R#23 in TabRasDATA), R#18, palette and blank changes.
- **Why the title failed.** The frame's end mode is SCREEN 5 (the line-141
  switch comes before the render at line 192, the VBlank switch after), so
  the frame was COPPER5 with SCREEN 5 pointers for every line; the page-0
  SCREEN 8 bytes were reconverted into SCREEN 5 planes each frame (V5All
  set by every SCREEN 8 entry, all of VRAM at every SCREEN 5 entry: the
  slowness), and the sprites were off because the longest segment (the
  logo, sprites off) chose R#8 for the whole frame.

## Design

**Regime.** MODESW records a split as before (MSplitL, MSplitTop, MS_DVDP2,
MS_LinY) and now also whether the two modes are a supported pair (BMSPair:
SCREEN 5 and SCREEN 8, in either order). The regime lasts while splits keep
coming (MSplitSeen, 3 frames). SCR0 belongs to the mode that rendered last
(LastRend), which is the bottom mode as long as the frame ends in it.

**Keeping both conversions alive.** Entering the mode that doesn't own SCR0
during the regime (ModoGfx8 with LastRend = SCREEN 5: BMSK8; ModoGfx5 with
LastRend = SCREEN 8: BMSK5) leaves SCR0 alone: no V5All, no ActPlanos5, and
the port-98h handler is OUT98XM (VRAM, TAB98 and VBlk5 flags, no planes;
reads from VRAM with IN98X). So the SCREEN 8 writes Manbow 2 makes in the
vertical blank flag VRAM and nothing else, and the SCREEN 5 planes of page
2 stay intact. (After the regime, a plain return to SCREEN 5 converts the
flagged blocks as before.)

**The top page: SCREENP.** A new 64 KB chip buffer (section BMSPLIT): 8
planes of 256 lines of 32 bytes, BMSPAGE (8 KB) apart, one page of the top
mode without page bits, so a vertical scroll wraps inside it like the VDP
wraps inside a page. Before the copper build of each render, BMSPrep
converts the top page into it:
- SCREEN 8 top (BMSConv8): PasaPun8Bpl's conversion (TablaPun8Bpl, the
  PaPuMac macro) over the page's 2048 TAB98 flag longs, clearing them (the
  SCREEN 5 bottom doesn't read them); all of them when BMSFull.
- SCREEN 5 top (BMSConv5): PU4_BUC (the C2PTab conversion) per flagged
  8-byte run, flags kept (PasaPun8Bpl clears them for the SCREEN 8 bottom);
  all 4096 runs when BMSFull.
- BMSFull is set when the key changes (top mode, its page, bottom mode:
  BMSKey) or a VDP command ran since the last render (BMSCmd, set in VDP2C):
  commands write VRAM without flags.

**The copper.** The frame runs the top mode's list: COPPER8 for a SCREEN 8
top (its palette loads in the vertical blank, where there is time for 264
MOVEs), COPPER8P for a SCREEN 5 top (COPPER8's list with the SCREEN 8
palette, then SCREEN 5's 48 colours, BPLCON4 and 4 planes: BMSPost copies
the sprite and MSX colours from MASTERCOPPER each render and fills the blank
bank with the border colour). PRINT5 and PRINT8 write BMSList to NEXTCOPP in
one MOVE, so the copper interrupt never sees the wrong list. Per line:
- lines above the split: AcCoRutGBY5T / 8T, pointers into SCREENP from the
  line's R#23 (TabRasDATA; line 0's from MiraInter0, and the top's page
  wrap from DesLinY as before);
- the split line: AcCoBMSw first, then the bottom's normal pointers.
  BMSPrep writes the bottom's registers (R#2, R#23, R#18) into the line's
  TabRasDATA and adds a pointer event at the bottom's page wrap
  (256 - R#23); the top's wrap event, if it falls below the split, gets the
  bottom's registers instead.
- AcCoBMSw, SCREEN 5 below SCREEN 8: BPLCON0 4 planes, BPLCON4 as
  MASTERCOPPER ($0011), then the colours SCREEN 8's palette took: the 16 of
  the palette in effect at that line (PalTop or the last palette event
  above, with the colour-0 / TP rule of AcCoRutPal), the sprites' 16
  (COLORSPR2) and the blank bank 32-47 (the border colour; emitted first
  when the split line itself is blanked by R#1 BL, as Manbow 2's is).
  SCREEN 8 below SCREEN 5: 8 planes, BPLCON4 $0022, Scr8Pal's bank 0 and
  the first 16 of bank 1 (the colours SCREEN 5's palette, sprites and blank
  bank overwrote). The modulo is -8 in both modes, so it isn't touched.
- AcCoRutPal skips SCREEN 8 top lines (the MSX palette and the line-0 blank
  bank would overwrite Scr8Pal).

**Sprites.** BANDSHOT notes a band with sprites on (BandSprOn); the
SPRMODE5/6 gates draw the overlay when one exists even if the longest
segment's R#8 (TopR8) has them off. The bands themselves already skip
sprites-off lines and use each band's R#23.

## Costs (68030/50)

- Per frame in the regime: BMSPrep's tests, the flagged runs of the top
  page (Manbow 2: ~220 bytes a frame, ~7 runs, negligible), the split
  event's ~54 copper MOVEs, and ModoGfx5's ActPlanos5 over the 1 KB blocks
  the SCREEN 8 writes touched (1-2 blocks). The per-frame full reconversion
  of VRAM is gone, so the title should run far faster than before.
- Once per regime, page or command: the whole top page, 64 KB through
  PasaPun8Bpl's tables (about 10 ms) or 32 KB through PU4_BUC (about 5 ms).
- Chip RAM: 64 KB more.

## Limitations and follow-ups

- **R#1 BL above a SCREEN 8 top:** AcCoRutBlank chooses its method by the
  frame's ScrModo (the bottom), so a blank inside the SCREEN 8 top would use
  the BPLCON4 bank (colours 32-47, which are SCREEN 8 colours there). Manbow
  2 blanks only below the split.
- **VDP commands in the non-owner mode** (a command in SCREEN 5 time while
  SCR0 is SCREEN 8's, or the reverse) still draw into SCR0's planes. The
  Konami lead-in's fades happen before the regime (single mode).
- **The split line:** AcCoBMSw's MOVEs start in the horizontal blank before
  the line and run into its first part, so the left of the split line can
  show the new colours arriving. Manbow 2's split line is blanked.
- **COPPER8P's colours** are copied at render time; the copper may read
  them in the vertical blank: a torn palette for one frame when they
  change. Double-buffer the block if it shows.
- **SCREEN 6 and 7** (512 pixels wide) need the same structure plus
  BPLCON0's HIRES bit, DDFSTRT/DDFSTOP and the planes' 64-byte lines in
  SCREENP (two pages of it). Same-width pairs (7 over 6) would be the cheap
  ones; 8 over 7 changes the fetch too. Not done: TabScrBGYT has no entries
  for them and BMSPair only accepts 5/8.
- **Three modes in a frame**, or a split that moves every frame: the first
  split of the frame is the one taken, as MODESW already did.
- **Interlace** (R#9 IL) in either half: not considered.
- **ECS:** the regime is AGA only (MCAGA check); ECS keeps the old path.

## With MSX2+ phase 2 step 2 (cloud/msx2plus-step2)

Step 2 gives SCREEN 5 on the MSX2+ machine a 32-bit bitplane fetch, its
own per-line modulo and wide plane layouts in SCR0, chosen at every SCREEN
5 entry. Merged as is, the two branches assemble but clash in four places
(`review_msx2plus_step2.md`, section 2.2): the keep path in ModoGfx5 fell
into step 2's layout block, ModoGfx8's layout reset forced a plane rebuild
every frame, FMODE flipped between the halves, and the split line's event
lacked R#26. The reconciliation (branch `review/msx2plus-step2`): the keep
paths skip the layout code, the mode entries leave FMODE alone in the
regime (BMSPost sets the top's, AcCoBMSw emits the bottom's with its
modulo), R#26 goes into the split event, and a SCREEN 5 top is refused on
the MSX2+ machine (SCREENP has 32-byte rows and 64-bit fetch; no title
needs 5 over 8 there).

## Other users

Titles in `tests/titles.csv` with both SCREEN 5 and SCREEN 8 and mode
splits: M_Jailbreak_Kon, 001_Manbow2, 026_HeadoverHeelsRemake (Konami-style
lead-ins and title screens); M_Uridium2_SCC uses SCREEN 8 too. Any other
title tagged `split:mode` is unaffected unless its pair is 5/8: BMSPrep
returns at once otherwise, and the SCREEN 5 / 4 path (MSplitFill) is
untouched.

## What to test (WinUAE, then hardware)

1. **Build:** `sh build.sh` on the branch (the draft assembles with vasm,
   `-DTRACE=1` too).
2. **Manbow 2's title:** `python tools/burst.py 001_Manbow2 20..40 --keys
   none` on the 030 config against openMSX (`build/bursts/scroll_r2_mb2`
   has the before): the logo solid in SCREEN 8 colours above line 141,
   the START prompt and the ship in the SCREEN 5 band (lines 145-180),
   black at 141-144 and 181-211, the logo scrolling with R#23 = ECh (rows
   236-255 then 0-120, the wrap at display line 20). Then the same on the
   PiStorm preset (60 Hz, Smooth display off in SCREEN 5).
3. **The lead-in and play:** the frames before the title (SCREEN 5 fades)
   and the cave in play must be unchanged: regress ids 001_Manbow2 with the
   play baseline.
4. **Jailbreak and Head over Heels Remake** (SCREEN 5 and 8, mode splits):
   `python tools/regress.py ids:M_Jailbreak_Kon,026_HeadoverHeelsRemake` and
   a look at their title and lead-in screens against openMSX, since their
   splits may now take the pair path.
5. **The SCREEN 5 / 4 split and plain SCREEN 8:** Lilly's Saga, Space
   Manbow (MSplitFill, unchanged) and Uridium 2 (SCREEN 8, no split) must be
   pixel-identical: `python tools/regress.py smoke`.
6. **Sprites:** Space Manbow's status bar (sprites off over a short top)
   and Zanac EX must not change: BandSprOn only adds a reason to draw.
7. **5 over 8:** no known title; a test ROM (tools/make_cmd_test.py as a
   base) that puts SCREEN 5 above a SCREEN 8 band would exercise COPPER8P,
   BMSConv5 and the SCREEN 8 switch at the split.
8. **Speed:** the 030 frame rate on the title before and after
   (tools/sm_perf.py); the per-frame VRAM reconversion is gone.

## Risks

- The regime hooks change which port-98h handler SCREEN 8 and SCREEN 5 use
  while a split is active; a wrong LastRend at the first frame of a regime
  would leave SCR0 half converted. The first 8-over-5 frame still takes the
  old full-conversion path once (LastRend is SCREEN 5 then), which is right.
- AcCoRutGBY runs for every line event of every mode; the added test is one
  TST per event. TabScrBGYT must stay in step with TabScrBGY's layout.
- The copper switch block was checked by hand against COPPER5/COPPER8 and
  MASTERCOPPER; a wrong register or order shows at once as a mis-coloured
  or blank band below the split.
- BandSprOn changes the overlay gate for every band game: a game with
  sprites on in a band and off in the longest segment now draws the band's
  sprites, which is what the VDP shows.
