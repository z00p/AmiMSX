# Review: MSX2+ phase 2 step 2 (cloud/msx2plus-step2) and its fit with the bitmap-pair mode split (cloud/bitmap-mode-split)

Review R1, 15 Oct 2026, session A2. Branch `review/msx2plus-step2`: this
document, a merge of both branches, and one commit that reconciles them.
Everything assembles with vasm (step 2 alone 572,244 bytes as its document
says; the merge plus the fixes 576,608; TRACE too; master's warning set).
Nothing has run.

## 1. Step 2 on its own (Task I)

Read: `Docs/msx2plus_phase2.md` sections 1-9, the diff against `wave1`
(667 lines in the main source, the new `AmiMSX_V9958_v4.asm`), and the
places it hooks: ModoGfx5/6/7/8, PRINT5, ActPlanos5, the command engine
(CALCULAR, MODODES, LMMC, LINE, TIMP, BLTSZ), BITPLASPR/BITSPRCOL,
MSplitFill, AcCoRut/AcCoRutGBY5/AcCoRutAdjust, the tile passes (NtSrc).

**The design holds.** The three hardware facts in section 3 (no horizontal
wrap in the Amiga fetch, pointer alignment per fetch width, the BPLCON1
delay range) are right, and the resolution (32-bit fetch, 4-byte pointer
steps, a row followed by its copy) is the only way to get a seamless R#26
wrap out of the copper without a per-frame copy of the screen. The
half-row trick for the blitter (a rectangle of NY rows becomes 2NY
half-rows at the same stride, so the copy is written for free, and DIY up
starts at the copy) is neat and correct for every rectangle the MSX can
ask for, because commands clip at 256 dots. I checked by hand:

- `OUT98W`: bit offset 2a + 2(a & ~127) = column*2 + line*512, copy +256
  bits; `OUT98P`: pair row*1024 + odd*256 + column*2 (+$40000 for pages
  2-3), copy +512 bits; `PlRowOff` for layout 2 moves line bit 9 to bit 8
  and tests the odd page through the saved word: all consistent with the
  layouts in section 9.1 and with `POINTW/P`.
- `BLTSZ`: BLTSIZV then BLTSIZH, so the blit starts on the second write;
  needed because 2 x 1024 rows do not fit BLTSIZE. AGA only by
  construction.
- `CALCULAR`/`MODODES`: the doubled row count, the DIY-up start at the
  copy, source and destination both walking copies. `LMMC` writes the copy
  per pixel and marks TABSPR for the rectangle up front. `LINE` drawn twice.
- `ActPlanos5` with V5All in a wide layout: every VBlk5 flag set, then the
  block path (`ActPlaBlkW`, `PU4W_ROW`); `P4W_BAND` for the bands commands
  drew in. `BITPLASPR`/`BITSPRCOL` step over the copy after 16 words.
- `VDPR26`: records the frame's writes (`R26Ev`) and, in SCREEN 5 on the
  V9958, an adjust and a pointer event at the next line. (`MOVEQ #0,D1`
  before `BRA VDPR9Ev` is harmless: `VDPR9Ev` reloads CurLine.) D2's high
  word survives (`MOVE.W R26EvN,D2` touches the low word; the value byte is
  restored from `V9R26`).
- `NtSrc`: the rotated copy is built once a frame per table and SP2 state
  (`NtKey` uses PVDP2's low byte, always 0 for a 1 KB-aligned table), the
  per-row R#26 from the frame's events, SP2 columns past 31 from the other
  32 KB half. `HUDSplit4` goes through it too. The Dbuf double buffer reads
  no name table of its own, so it is covered by `COPIATXT4`/`ACTUALIZA4`.
- The MSX2 machine and ECS are untouched by construction: `V9Scr5` is only
  set on the MSX2+ machine on AGA, `PlMode` stays 0 and every new test is
  on a zero flag.

**Findings (none blocking):**

1. **Manbow 2's title on the MSX2+ machine gets much slower with step 2
   alone.** Every frame: ModoGfx8 (VBlank) does `PlSet 0`, then ModoGfx5
   (line 141) finds `PlWant` (1) differs from `PlMode` (0), sets V5All and
   rebuilds all planes in the wide layout: the 0.2-0.3 s rebuild of
   section 9.3, every frame, instead of today's per-frame 128 KB
   reconversion (20-40 ms). The picture was already wrong before step 2
   (the bitmap-pair split is what fixes it); section 9.5 test 5 says
   "unchanged pictures", which is true, but the speed is not. With the
   bitmap-pair split merged and the fixes below, the regime keeps SCR0 and
   its layout, so neither rebuild happens. Without the split branch, a
   cheap guard would be: ModoGfx8/6 call `PlSet 0` only when they set
   V5All for a real stay (they do set it), and ModoGfx5 compares against
   `PlWant` only when `V5All` is clear; but that is the split branch's
   job, so I did not change step 2 for it.
2. **A layout switch in `Pl5Frame` is mid-render.** PRINT5 runs after
   ActCopperLine, so the frame's copper pointers were built with the old
   `PlMode` (`Pl5DispOff`) and the planes are then rebuilt in the new one:
   one garbled frame at each SP2 on/off or SCREEN 5 entry that changes
   layout. One frame, once per switch; moving the switch before the copper
   build (where BMSPrep sits) would remove it.
3. **`TabCop5` is dead on AGA.** COPPER5 jumps into the per-line event list
   at ZALTO5 and never reaches `Salto5`/`TabCop5`, so the per-line modulo
   lives in `C5AGA` alone (which `Mode5Mod` also patches). Section 2's "the
   per-line copper list `TabCop5` sets BPLxMOD -8 every line" describes the
   ECS layout. No functional effect; the 213-entry patch loop is wasted
   work on a mode entry.
4. **`MODESW` clears `V9Scr5`** on every mode write during the display, so
   in a SCREEN 5/4 split (Space Manbow on MSX2+) the copper build at line
   192 sees it clear and `AcCoRutGBY5` takes the MSX2 form for the SCREEN
   5 lines above the split. That is right (MSplitFill copies them into
   SCREENT, drawn by GBY4), and MCAGA's FMODE is SCREEN 4's; just noting
   that `V9Scr5` means "the last mode entry was SCREEN 5 on the V9958",
   not "SCREEN 5 on the V9958 is on screen".
5. **Chip RAM:** +128 KB (SCR0 256 KB). With the split's SCREENP (+64 KB)
   the total is about 1.12 MB on the 4.0 layout; the guide should say so.
6. **Section 9.5 test 3** (commands in the wide layouts) is the one to run
   first: the half-row trick is exact but every command path was touched,
   and a wrong copy shows only once R#26 scrolls.

## 2. Fit with the bitmap-pair mode split (Task J)

### 2.1 What each branch changes

| Area | Step 2 | Bitmap-pair split |
|---|---|---|
| SCR0 | 256 KB; layouts 0/1/2 (32/64/128-byte rows), chosen at ModoGfx5 and PRINT5 (`Pl5Frame`) | Untouched; a separate 64 KB `SCREENP` (32-byte rows, 8 KB planes) for the page above the split |
| ModoGfx5 | Restructured: `Pl5Want`, `PlSet`, `Mode5Layout` (descriptor, port-98h handlers, modulo), then `ActPlanos5` | A keep path (`BMSK5`): no `ActPlanos5`, handlers `OUT98XM`/`IN98X`, when SCR0 is SCREEN 8's |
| ModoGfx8 (and 6, 7) | `PlSet 0` (and V5All as before) | A keep path (`BMSK8`): no V5All, `OUT98XM`, when SCR0 is SCREEN 5's |
| PRINT5 | `JSR Pl5Frame` after Act_Adjust | The NEXTCOPP choice (`BMSList`) at its start |
| AcCoRutGBY5 | `Pl5DispOff`, `PlSizeL`, the R#26 pointer step (`Adj5Calc`, `AdjCur`) | Untouched; `AcCoRutGBY` dispatches top lines to `AcCoRutGBY5T/8T` (SCREENP) and inserts `AcCoBMSw` at the split line |
| FMODE (MCAGA+2) | $000D at ModoGfx5 on MSX2+/AGA (32-bit bitplane fetch), $000F at the other mode entries | Not touched (assumed 64-bit for both halves) |
| Per-line modulo | `Mode5Mod` (C5AGA, TabCop5): -8 or stride-36 | Not touched (assumed -8 for both halves) |
| TabRasDATA | +7 = R#26 | Writes +1, +3, +4, +5, +6 for the split line and wrap events |
| MSplitFill, BITPLASPR, ActPlanos5 | Layout-aware (`PlRowOff`, `PlSkipW`) | Untouched |
| Tile modes | `NtSrc` | Untouched |

`git merge-tree --write-tree` of the two is **textually clean** in both
orders (one hunk from each lands in ModoGfx5 without overlapping lines),
and the merged tree assembles. Semantically it is not clean; four things
go wrong in the merge as the tools produce it.

### 2.2 Clashes

1. **ModoGfx5's keep path falls into the layout block.** The split's
   `BRA.S M5NoAT` was written for wave1, where M5NoAT was followed by the
   tail. In step 2 M5NoAT is followed by `Pl5Want`/`Mode5Layout` (which
   reselects `DREGOUT98` to OUT98A/W/P, undoing the keep path's OUT98XM)
   and `BSR ActPlanos5` (which rebuilds SCR0 from VRAM in SCREEN 5's
   layout, over the SCREEN 8 planes in a 5-over-8 regime). Fix: the keep
   path jumps past the block (`M5Keep`, before the tail).
2. **ModoGfx8's `PlSet 0` defeats the keep path on MSX2+.** In an
   8-over-5 regime the VBlank entry into SCREEN 8 resets `PlMode` to 0
   while SCR0 holds the wide layout; the line-141 entry into SCREEN 5 then
   sees `PlWant` (1) differ, sets V5All and rebuilds every frame: finding
   1 of section 1, now with the split's keep logic switched off by it.
   Fix: `PlSet 0` only when SCR0 is really given to SCREEN 8 (not on the
   `BMSK8` path).
3. **FMODE and the modulo differ between the halves on MSX2+.** The split
   runs the frame on COPPER8 (64-bit fetch, modulo -8) and assumed the
   SCREEN 5 bottom needs the same. With step 2 the SCREEN 5 bottom on the
   V9958 needs FMODE $000D and modulo `Mod5Cur` (stride - 36), and
   `MCAGA+2` is rewritten by every mode entry ($000F at the VBlank SCREEN
   8 entry, $000D at the line-141 SCREEN 5 entry), so whichever the copper
   reads at the top of the Amiga frame decides the fetch width of the
   whole frame: a sheared top or a sheared bottom, changing from frame to
   frame. Fix: in the regime the mode entries leave `MCAGA+2` alone,
   `BMSPost` sets it for the top ($000F: SCREEN 8, or SCREEN 5 on MSX2),
   and `AcCoBMSw` emits FMODE and the modulo for the bottom (SCREEN 5:
   $000F/-8, or $000D/`Mod5Cur` when `V9Scr5`).
4. **R#26 missing from the split line's event.** `BMSPrep` copies R#2,
   R#18, R#23, R#27 and R#25 into the split line's TabRasDATA; step 2
   reads R#26 at +7, so the bottom would lose its R#26 at the split. Fix:
   copy `V9R26` to +7 (the wrap event copies all 8 bytes already).

Two things are not clashes but limits of the pair, and the fix commit
makes them explicit:

- **SCREENP keeps 32-byte rows.** The page above the split is converted
  from VRAM by `BMSConv8` (PasaPun8Bpl's conversion) and `BMSConv5`
  (`PU4_BUC`), never read from SCR0, so step 2's wide layouts do not reach
  it, and `MSplitFill` (SCREEN 5 over 4, which does read SCR0) is step
  2's business and already layout-aware. The top half therefore has no
  R#26 wrap: a SCREEN 8 top never had R#26, and a SCREEN 5 top on the
  MSX2+ machine would be shown with 64-bit fetch while `AcCoRutAdjust`
  computes the V9958 delay. **The fix commit refuses a SCREEN 5 top when
  `V9958On`** (`BMSPrep` falls back to the old single-mode frame); 5 over
  8 stays MSX2-only until SCREENP grows a wide layout. No title needs it.
- **The R#18/R#27 delay of SCREEN 8 top lines on MSX2+** is computed by
  `Adj5Calc` (32-bit form) while the top is fetched 64-bit. For R#26 = 0
  the two forms give the same BPLCON1 (k = 0, D = 32 + s18 + R#27), so an
  MSX2 game such as Manbow 2 on the MSX2+ machine is right; only a SCREEN
  8 top with R#26 would differ, and SCREEN 8 R#26 is not supported by
  either branch.

### 2.3 Merge order and the changes needed

**Merge step 2 first, then the bitmap-pair split, then the reconciliation
commit** (`review/msx2plus-step2` has exactly that: 1a54d05, the merge
8110cfc, then the fix). Reasons: step 2 is the larger change and already
carries wave1; its ModoGfx5 restructure is the thing the split's hooks
must adapt to (the reverse order would mean rewriting step 2's hunk around
the keep path); and the split's switch event needs step 2's symbols
(`Mod5Cur`, `V9Scr5`). The fix commit (`patch_fit.py` in the session's
scratchpad reproduces it) changes only the split's code plus two guards
in step 2's mode entries:

- ModoGfx5: keep path `BRA M5Keep` (new label before the tail); the
  `MOVE.W #$000D,MCAGA+2` skipped while `BMSPair` and `MSplitSeen`.
- ModoGfx8: `MOVE.W #$000F,MCAGA+2` and `PlSet 0` skipped on the `BMSK8`
  path.
- BMSPrep: `V9R26` into the split line's event; a SCREEN 5 top refused on
  the MSX2+ machine.
- BMSPost: `MCAGA+2 = $000F` for the frame.
- AcCoBMSw (SCREEN 5 below SCREEN 8): FMODE and BPL1MOD/BPL2MOD for the
  bottom, $000D and `Mod5Cur` when `V9Scr5` (6 more copper MOVEs).

If the split is merged **without** step 2 (wave1 + J), none of this is
needed: the four clashes are all step 2's new state. If step 2 is merged
without the split, finding 1 of section 1 stands (Manbow 2's title on
MSX2+ crawls) until the split lands.

### 2.4 What to test for the pair

On top of each branch's own list (`msx2plus_phase2.md` 9.5,
`bitmap_mode_split.md`):

1. Manbow 2's title on the **MSX2+ machine** (it is an MSX2 game, but a
   user may pick MSX2+): the logo above line 141 and the SCREEN 5 band
   below, no shear in either half, frame after frame (the FMODE fix), and
   the title's frame rate (no per-frame rebuild: finding 1).
2. Gradius III Legends on MSX2+ with Smooth display off: unchanged by the
   split (no mode split there), R#26 scrolling as step 2 intends.
3. Space Manbow on MSX2+ (SCREEN 5 over 4, the other split path):
   unchanged.
4. A SCREEN 5 over SCREEN 8 test ROM on the MSX2+ machine shows the old
   single-mode frame (refused on purpose), and the split on the MSX2
   machine.
