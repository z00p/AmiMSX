# Review R5: Task K, bitmap line events (`cloud/bitmap-line-events`, 15 October 2026)

Reviewed: commit 82b581a (author A1) and `Docs/bitmap_line_events.md`.
Branch `review/bitmap-line-events` = the author's commit plus the three
draft corrections below (all under `-DCOPLINEDB`; the release build is
byte-identical to the author's, 561,748 bytes). Nothing was run on an
Amiga: the findings come from reading the code and assembling the variants.

**Verdict.** The dead-code removal is correct and safe to merge: every
removed handler, store and patch is unreachable, and no data layout
changed. The analysis that the R#2/R#23 event path already exists and
that the beam-timed handlers never ran is right. The `COPLINEDB` draft is
the right idea but, as written, protects the wrong copper line in the
modes it is for and still rebuilds a running list on consecutive late
frames; corrected on this branch, still untested. K is based on master,
not wave1, and merges into wave1 without conflicts.

## 1. The removal: every item traced

| Removed | Where it was reachable from | Evidence (wave1) |
|---|---|---|
| `VDP17m5`, `VDP17m7`, `VDP17m8` | only by a `VDPPunt[$17]` entry | The initial table has `VDP17` at $17 (line 7894). Every mode entry stores `VDP17` there (9662, 9695, 9728, 9762, 9793 `*m5`, 9835 `*m7`, 9872 `*m8`), and the ECS set-up patches `M8Chap` to `VDP17` as well (1067). No `DC.L VDP17m*`, no `JMP`/`BSR`, nothing in the menu, saves or GadToolsBox sources (`git grep` over wave1). The saved-state format does not store `VDPPunt` pointers. |
| `Cop_Rest`, `Ant_Rest` | the three handlers and `PRINT6ecs`'s `ModC60/61` block | both removed together; no other reader |
| `ModC50-52`, `ModC60/61`, `ModC70-72` ECS patches (startup, 1047-1064) | they patched immediates inside the dead handlers | dead with them |
| `Dir_Scan` (DC.L into TabCop5) | one commented-out use in VDP0 (9929) | no live reference |
| `ST ScanningY(A3)` in PRINT5/7/8 | read only by `V17Buc2/72/82` in the dead handlers | the REGS field $6EE stays, so the state block, the menu and the perf dump layout are unchanged |
| `PRINT6ecs`'s `ModC60/61` writes into `TabCop5` | data the copper never executes | see below |

`TabCop5` is unreachable: COPPER5 is `C5AGA`, the WAIT at line 26, `Plano5`,
then `ZALTO5` (`COP2LC` load and `COPJMP2`, line 42), so the copper leaves
for the per-line list before `Salto5`/`TabCop5`, in AGA and ECS alike (the
ECS set-up changes nothing in that path; its `ModSC5Buc` loop only writes
the data, left in place as the author says). The per-line list ends in
its own `WAIT $FC01` + `INTREQ` and `$FFFFFFFE`, so nothing returns to
COPPER5 either.

The code moved by the removal (1,620 bytes) is referenced through
labels only: PC-relative `.W` displacements still assemble (the build is
the proof) and the `CNOP` alignments belong to the surviving labels.
`tools/pal_probe.py`'s tail list is updated for the 8 new perf.bin bytes,
and the other perf readers (`classic_cmp.py`, `motion.py`) go through
`pal_probe.blocks`, so they follow.

## 2. The COPLINEDB draft: three corrections (applied here)

1. **Wrong wait window for the modes it is for.** `IniPant` is 43. In
   COPPER4 the jump `ZALTO4` sits after a WAIT at `INIPANT-16-1` = line 26.
   In COPPER5/6/7/8 the second WAIT of `NPLAx` is at `PANPOS-1` =
   `IniPant-1` = line 42 (hpos $61, $21 in SCREEN 8), and `ZALTO5-8` follow
   it: the copper reads those two words at **line 42**, not 26. The
   draft waited for lines 24-28 only, so in SCREEN 5-8 (Jailbreak's case) a
   flip at line 42 could split the high and low word of the address and
   send the copper into a mixed pointer. `CopLineFlip` now waits for 24-28
   and 40-44.
2. **A late flip still leaves a running list to be rebuilt.** When the flip
   happens after the copper's read (beam past line 24/42), the copper
   keeps running the old list to the end of the display; the swap makes
   that old list `CopperLineDos`, and the next `ActCopperLine` rebuilds it.
   If that next frame is late too (Wait60fps returns at once: the author's
   own scenario, Jailbreak hovering at full load), the rebuild overlaps the
   copper's run of it, the hazard the draft was meant to remove. The
   document's claim "a late frame's rebuild touches only the list the
   copper is not running" holds only for an isolated late frame. Fix:
   `CopLineFlip` records a late flip (`CopFlipLate`, with the VBlank count
   `CopFlipV`), and `CopLineSafe`, called before `ActCopperLine` next to
   `DbLineSafe`, waits until the beam is past the list's end ($FC) or a
   VBlank has passed, exactly as `DbLineSafe` does for Smooth display.
   Cost: nothing on a frame in time (the flag is clear); on a late frame a
   wait that the in-place rebuild would otherwise have spent on a torn
   frame. The AclLate counter stays meaningful: it counts the frames this
   wait now covers.
3. **`DbReset` resets `ZALTO4` only.** At every emulation start it forces
   `CopperLineDos` = `CopperLine0` and `ZALTO4` to it; `CREASALTOS` set
   `ZALTO5-8` to `CopperLine0` once at program start. With COPLINEDB the
   flip moves `ZALTO5-8` too, so a new game (or a Power ON) after a game
   that left them at `CopperLine1` showed a list built for the previous
   game for one frame, and the first flip then showed the list built one
   frame earlier than `CopperLineDos`. `DbReset` now resets all five and
   the late flag under COPLINEDB.

Checked and found right: the flip's placement at both exits of
`Emula1Frame` (`ActCopperLine` runs before the Refresh skip, so a skipped
frame has a built list to show); `DbSwapLines` swapping the restore table
with the list, so `TabRasREST` stays per list; the DbOn gate and the
Smooth display transitions (DbStop before the render, the flip after it,
one stale frame at a stop as before); no stack or A3 assumptions (the flip
runs from Emula1Frame); `INTWB` (Workbench mode) skipping the beam waits.
Both copper lists carry the `$FC01` INTREQ, so `Wait60fps` works with
either on screen.

Still to keep in mind: the two-word write of a copper jump by the CPU is
inherently a race with the copper; the waits make it safe only when the
beam position is read in the same frame as the write (true here: the
check and the writes are a few hundred cycles apart, lines are 64 µs).

## 3. The document

- "the copper reads ZALTOx at line 26" and "the copper runs the list from
  line 26": line 26 is SCREEN 4; SCREEN 5-8 read the jump at line 42, and
  the first slot WAIT is `$2AC1` (line 42, hpos $C1) in every mode.
  Display line 0 is Amiga line 43 (`IniPant`).
- Section 4's "a late frame's rebuild touches only the list the copper is
  not running": only after a flip that came before the read; see 2.2.
- Section 6 and the open_issues rows are otherwise consistent with the
  code. The `-DSPREARLY` and `sprite_ghosting.md` cross-references were not
  re-checked (that document is on another branch).

## 4. Base branch

K branches from master (fdb9c9d), not from wave1. `git merge-tree` of
wave1 and K reports no conflict, so it can go into wave1 as it is. Note
for the test plan: a "K build" lacks everything in wave1 (DbCommitF, the
DMACON display-enable change, the R#8 overlay change, scroll-r2, cd32-r2).

## 5. Space Manbow's tile corruption (SCREEN 4, MSX2+, wave-1/step-1 builds)

- **Not K's.** The plain K build changes no instruction that runs: the
  removed code never executed. So K neither causes nor hides the
  corruption; "not seen with K" is explained by K being a master build,
  without wave1's changes, rather than by anything K does.
- **Would COPLINEDB make it better or worse?** The SCREEN 4 tile data
  (GFXCA, COPIATXT4's blits, DbCatch, HUDSplit4's per-line draw into
  SCREENB) is untouched by the line list; COPLINEDB only decides which
  per-line list the copper runs. Without Smooth display (the 030 preset)
  Space Manbow's table split at line 81 is a per-line event that points
  the bitplanes at SCREENB from that line; a torn or half-built list on a
  late frame shows the wrong buffer or the wrong line of it for part of
  the frame, which reads as a band of scrambled tiles, with the ground
  strip (drawn into the same buffer, below) intact or not depending on
  where the tear is. If the tester's corruption is of that kind (it comes
  and goes per frame, bands rather than individual tiles, worse when the
  emulation is at full load), COPLINEDB makes it better. If the tiles are
  wrong as tiles (the same wrong tile every frame, or garbage within an
  8x8 cell), it is the cache or the blits (`-DTILECHK` on
  `cloud/tilecache-check` is the tool), and COPLINEDB changes nothing.
  With Smooth display (PiStorm preset) COPLINEDB is idle, so no effect
  either way. Suspects in wave1 for a tile-level corruption: DbCommitF
  (the back buffer handed over while a blit or the tile pass still writes
  it) and the DMACON display-enable change; a bisect over wave1's commits
  with the Manbow play keys on the 030 config is the direct test.

## 6. What to test (adds to the author's section 6)

1. Plain build: `python tools/regress.py smoke` identical to the baselines
   (nothing executable changed).
2. `-DCOPLINEDB=1 -DPERF=1`, Jailbreak 70 s on the 030 config: AclLate
   against AclN, and the 60 s strip in a 16-frame burst. A visible copper
   glitch (a frame of garbage from the top) would mean the jump write
   still raced; it should not with the 40-44 window.
3. The same build on the PiStorm preset: Space Manbow's intro (DbStop and
   a mode switch into SCREEN 5), then a Power ON in play, then Lilly's
   Saga: the DbReset change must leave the first frames clean.
4. SCREEN 4 without Smooth display (030 preset, FM off): Space Manbow and
   Lilly's Saga at full load; the split line must not wander.
