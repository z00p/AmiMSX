# Bitmap-mode R#2/R#23 writes: already events at the MSX line (15 Oct 2026)

Task K asked for SCREEN 5-8 page (R#2) and vertical scroll (R#23) writes to be recorded at the MSX line they were written at and built into the copper line list at the render, instead of being applied at the Amiga beam line by VDP17m5/m7/m8, so that Jailbreak's splits land on the right line and a page flip in VBlank shows in the same frame as the sprites. Reading the code first: that is already how it works. The beam-timed handlers are unreachable, and the theory in `Docs/open_issues.md` (and section 6 of `Docs/sprite_ghosting.md`, which repeated it) described dead code. This document sets the record straight, says what in the bitmap path still depends on the beam, and gives the draft code on branch `cloud/bitmap-line-events`: the dead code removed, the per-line copper list double-buffered in every mode (`-DCOPLINEDB=1`), and a PERF counter that tells whether Jailbreak's late frames are the cause.

Nothing was run on an Amiga. The claims about the code are from reading it; the claim about Jailbreak is a hypothesis for the measurement in section 6.

## Summary

- **The event path exists.** An R#23 write goes to VDP17, an R#2 write to VDP2, which jumps to VDP17 with the current R#23. VDP17 sets bit 0 of TabRasCMDS for the next MSX line (CurLine + 1) and stores R#2 and R#23 in that line's TabRasDATA; it also marks the line where the 256-line VRAM page wraps (DesLinY). At MSX line 0, MiraInter0 records the frame's starting R#2, R#18 and R#23 as line 0's event, so writes made in the VBlank (a page flip in the interrupt handler) are the frame top. At the render (Emula1Frame, after Wait60fps), ActCopperLine turns each marked line into a copper routine: AcCoRutGBY5/6/7/8 write the bitplane pointers for that display line from `page << 8 | R#23 + line`, and the copper runs the list from the next Amiga frame start, each routine at the end of the line before its display line. The page flip and the sprites of the same MSX frame therefore show at the same Amiga frame start, as long as the sprite switch is written before line 0 (`Docs/sprite_ghosting.md`).
- **The beam-timed handlers are dead.** VDP17m5, m7 and m8 waited for the beam, wrote BPL1MOD/BPL2MOD for a one-line jump and patched page-end entries in TabCop5. Every mode entry installs VDP17 (`M5Cap`, `M7Cap`, `M8Chap`: the `*m5` comments mark where the m-handlers once were), and TabCop5 is never executed: COPPER5 jumps to the per-line list (ZALTO5) before reaching it. The repository's history begins with this state (efb6aea), so the change predates it. The code is removed in this branch, with PRINT6's writes into TabCop5, the ECS start-up patches of that code, Dir_Scan and the ScanningY stores.
- **What still depends on the beam in bitmap modes.** Without Smooth display there is one per-line list (CopperLine0), rebuilt in place by ActCopperLine. When a frame runs late (Wait60fps returns at once because the copper interrupt has already come) the rebuild starts wherever the beam is: the lines the copper has already run keep last frame's events, the lines below get the new ones, and the copper may even read a slot while it is being written. One frame is a mix; the next is right. That gives a strip of rows with the wrong page or scroll for a frame or two, when the emulation hovers at full load, which is Jailbreak on the 030 (a 212-line SCREEN 5 game with commands every frame). Smooth display avoids this for SCREEN 4 with its own list swap (DbSwapLines) and a wait (DbLineSafe); the other modes have neither.
- **Draft fix.** `-DCOPLINEDB=1`: at the end of Emula1Frame the list just built becomes the one the mode's copper jumps to (the two words of ZALTO4-8), and the lists are swapped so the next frame builds the other. 20 instructions a frame, no chip RAM (both lists and both routine areas exist already), nothing while Smooth display is on. Dead-code removal costs nothing at run time (it never ran) and saves 1.6 KB.
- **Diagnostic.** PERF builds count ActCopperLine runs and those that begin with the beam inside the display window (AclN, AclLate, perf.bin after DbCommits). A Jailbreak run on the 030 config with a non-zero AclLate share supports the theory; with the COPLINEDB build the strip should go. If AclLate is zero and the strip stays, the cause is elsewhere (section 6).

## 1. The path, line by line

| Where | What | When it takes effect |
|---|---|---|
| VDP2 (R#2) | TSPLITCHK (SCREEN 4 table split), DVDP2/PVDP2, then VDP17 with D2 = R#23 | |
| VDP17 (R#23, all modes) | RSPLITCHK (register-split segments, MIDSAMPLE), VDPLinY; HorLine for the line interrupt; `TabRasCMDS[CurLine + 1] |= 1`, TabRasDATA+1 = R#2, +4 = R#23; the wrap line 256 - R#23 if still ahead (DesLinY, its data too) | display line CurLine + 1 of the next Amiga frame |
| MiraInter0 (MSX line 0) | `TabRasCMDS[0] |= 3`: R#2, R#18, R#27, R#25, R#23 of the frame start; DesLinY and its data | line 0 |
| ActCopperLine (Emula1Frame, after Wait60fps) | restores last frame's used slots (TabRasREST), then for each marked line writes a routine into CopperOpts (GBY: AcCoRutGBY5-8, the 2/4/8 plane pointers; Adjust: BPLCON1 and the window; Pal; Blank) and points the line's slot at it (COP2LC in the slot, COPJMP2 in its last word) | the slot's WAIT is line 42 + k at hpos $C1, the end of the line before display line k |
| COPPER5/6/7/8 | ZALTOx jumps to the list at line 26; MASTERCOPPER's AdjustX/VERPAN and the mode's PLANO5 (interlace only) at the frame top | |

Events written at MSX lines 192-211 are built (the list has 212 slots) and show in 212-line mode. Writes at lines 212-255 land at indexes 213-256, which ActCopperLine never reads: correct, since line 0's record carries the state they leave. (Those bits are never cleared either; harmless.)

So a page flip written at MSX line 212 of frame N-1 is line 0's event of frame N, built at N's line 192, shown at the Amiga frame start after that render, which is the frame start the sprites of N switch at when their pass ends before line 0. At 50 Hz on a fast CPU they coincide every frame. At 60 Hz the sprite switch straddles line 0 (`Docs/sprite_ghosting.md`); the page flip never does, because ActCopperLine runs before the sprite pass and its result is read at line 26.

## 2. The dead code

VDP17m5 (SCREEN 5), m7 (SCREEN 7) and m8 (SCREEN 8): wait for hpos $67, for the beam to leave the line of the last split (ScanningY), compute the difference between the new and old VRAM line at the beam line, write it as BPL1MOD/BPL2MOD (a jump for one line), move the page-end entry in TabCop5 (Cop_Rest, the entry at 255 - R#23 getting a -32*256-8 modulo), set PLANO5 for the next frame, then re-run the R#19 handler. None of it is reached: `VDPPunt[$17]` is VDP17 in every mode, and nothing else jumps to them. TabCop5, the per-line WAIT/modulo list after ZALTO5 in COPPER5, is never run by the copper, so PRINT6's and the ECS set-up's writes into it (ModC50-ModC72, ModSC5Buc) change nothing. Removed: the three handlers with Cop_Rest and Ant_Rest, PRINT6's ModC60/ModC61 block, the ECS patches of ModC5x/6x/7x, Dir_Scan, and the three `ST ScanningY` stores in PRINT5/7/8 (the REGS field stays). TabCop5 and its ECS loop are left (data, 3.4 KB; a later tidy).

Why it matters beyond tidiness: two analyses took the dead handlers for the live path. The Jailbreak theory ("timed from the Amiga beam") and the sprite-ghosting document's section 6 ("the page flip shows a frame before the sprites") are both wrong, and the PERF hooks that document added to log bitmap splits sat in the dead handlers and never fired. Both are corrected on their branches.

## 3. What remains beam-dependent

1. **The in-place rebuild of the per-line list (all modes without Smooth display).** ActCopperLine writes CopperLine0's slots and CopperOpts0's routines while the copper may be running them. Emula1Frame reaches it after Wait60fps, which waits for the copper interrupt at the end of the display (line 255): on a frame that finished in time the rebuild runs in the blank, before line 26 of the next frame, and all is well. On a frame that overran (fps60Dat already 0: the 030 on a heavy game, a fast CPU on a heavy 60 Hz frame), Wait60fps returns at once and the rebuild runs with the beam somewhere in the display: slots above the beam have run with last frame's events (TabRasREST has even restored their no-op), slots below get this frame's, and a slot being rewritten as the copper reaches it can send the copper into a half-written routine. The frame shows a seam at the beam line between two frames' pages and scrolls; the next frame is complete. Jailbreak flips page and scroll at line interrupts and in VBlank every frame, so a mixed frame shows rows of the other page: "rows of the wrong scenery flash", "a 2-line strip changes for 4 frames", at the lines where the beam happened to be.
2. **The sprite overlay switch** at 60 Hz (`Docs/sprite_ghosting.md`, `-DSPREARLY=1`).
3. **MASTERCOPPER's frame-top registers** (AdjustX, VERPAN, the sprite pointers, PLANO5/7 for interlace) written by the render: read by the copper at lines 0-26 only, so a late render changes the next frame's top, never the current frame's middle. Not a tear.
4. **Smooth display (SCREEN 4)** has none of 1: DbPost swaps the lists after the render (DbSwapLines) and DbSnap points ZALTO4 at the list just built; DbLineSafe waits before a rebuild until the beam is past the list's end. Bitmap modes stop it (DbStop) and fall back to 1.

Not beam-dependent, but worth knowing for Jailbreak: the MSX line at which the game's split lands depends on the emulated interrupt timing (the line interrupt is raised per line; the handler's first write lands at the next line boundary or later, and the event takes effect one line after that), which is deterministic frame to frame in AmiMSX. The real VDP applies a register written during a line from the next line as well. If the strip survives the fix, compare the write lines against openMSX's log (section 6).

## 4. The draft: a double-buffered line list (`-DCOPLINEDB=1`)

CopLineFlip, called at both exits of Emula1Frame (after the render, and on a skipped frame):

- nothing while DbOn (Smooth display runs its own swap in DbPost, and its first frame expects CopperLineDos to be the list just built);
- waits while the beam is in lines 24-28 (the copper reads ZALTOx at line 26; two words);
- writes the address of CopperLineDos, the list ActCopperLine just built, into the jump of every mode (ZALTO4-8, high and low word);
- DbSwapLines: CopperLineDos/Uno, CopperOptsDos/Uno and TabRasRESTDos/Uno swap, so the next ActCopperLine builds and clears the other list.

With it, the list the copper runs in frame F+1 was finished before F+1 began, whatever the beam was doing during the build; a late frame's rebuild touches only the list the copper is not running. Two renders in one Amiga frame (catching up) both complete their lists; the copper takes the later one. The restore of used slots (TabRasREST) is per list and so stays right.

Interaction with Smooth display: when it starts (PRINT4S, DbPre sets DbOn inside the render), CopLineFlip has not run in that frame yet, so DbPost's first frame sees the state it expects. When it stops, DbReset forces CopperLineDos back to CopperLine0 and ZALTO4 to it, whichever list was just built, as it did before this change: one frame may show a list that is a frame old at the switch, a pre-existing one-frame glitch at Smooth display stops, not made worse. From then on CopLineFlip alternates again.

68030 cost: 20 instructions and two chip reads a frame, no wait in practice (the flip runs after the render, which starts after line 255; a late frame can land in lines 24-28 and wait up to 5 lines, 0.3 ms, rarely). PERF: two longs a frame. Chip RAM: none. Release builds without the option: the dead code is gone, otherwise unchanged.

What it does not do: build the list earlier than the render. On a fast CPU the Z80 reaches line 192 early in the Amiga frame and the build could happen then, as `-DSPREARLY=1` does for the sprite pass; the list would still show from the next frame start. There is no gain in the common case, so it stays where it is.

## 5. Build status

vasm 2.0e (WebAssembly, see `Docs/sprite_ghosting.md` section 7); the maintainer's 2.0f for anything that ships.

| Options | Result |
|---|---|
| none | 561,748 bytes (1,620 less than master: the removed handlers), 13 warnings as before |
| `-DCOPLINEDB=1` | builds |
| `-DPERF=1` | builds (AclN/AclLate, perf.bin after DbCommits; `tools/pal_probe.py` tail updated) |
| `-DCOPLINEDB=1 -DPERF=1` | builds |

`build.sh`'s branch check passes. Reading the counters: `pal_probe.blocks(open(f,'rb').read())['acl']` is two big-endian longs, rebuilds and late rebuilds.

## 6. What to test

1. **Regression first, plain build:** `python tools/regress.py smoke` on the 030 config must be pixel-identical to the baselines: the removed code never ran, so any change is a mistake in the removal.
2. **Is Jailbreak late?** PERF build (`-DPERF=1`), 70 s of Jailbreak on the 030 config with the play keys; `tools/read_perf.py` for the load (over 100% = frames overrun) and AclLate against AclN. The flicker theory needs AclLate > 0; the DispLog holds (2 and more) say the same thing from the other side.
3. **The fix:** `-DCOPLINEDB=1`, the same run, then a 16-frame burst at 60 s (`tools/burst.py`, the night-1010 point) against openMSX: the 2-line strip on top of the orange buildings should be steady. `python tools/regress.py feature:split:scroll` and `feature:split:tables` on the 030 config: captures should stay identical to the baselines except where a baseline caught a mixed frame (Jailbreak's 60 s capture: the one-line strip under the orange blocks noted on 3 Oct). On WinUAE 060 at 60 Hz (From VDP), Uridium 2 and Manbow 2 in play, for a seam at the HUD line.
4. **If the strip stays with AclLate = 0:** log the MSX lines of Jailbreak's R#2/R#23 writes per frame (TRACE build, TRVLOG $02/$17) against `tools/omsx_vdpio.tcl` at the same frames, and the line of its R#19 interrupt. A line of difference there is the interrupt path, not the copper.
5. **Smooth display:** Lilly's Saga and Space Manbow on the PiStorm preset with the COPLINEDB build: unchanged (CopLineFlip is idle while DbOn), including the mode switches in Space Manbow's intro (DbStop/DbReset) and a Power ON in play.

Regression titles with a page or scroll split in a bitmap mode (tests/titles.csv, `mode:S5/S7/S8` with `split:scroll`, `scroll:R#23` or `split:tables`): 001_Manbow2, 031_KnightLoreRemake, BombJack, M_Barbarian_A16, M_Ianna_A16, M_Jailbreak_Kon, M_Lilly_A16, M_Uridium2_SCC, R2K_GaliousEnh, R2K_SpaceManbow, R2K_ZanacEx, R2K_ZanacExEnh, R2_Batman, R2_BunGaRua, R2_Delta (`python tools/regress.py feature:split:scroll`, `feature:split:tables`). SCREEN 4 with Smooth display is unaffected; SCREEN 4 without it (the 030 preset, FM games) gets the same list swap.

Risks: the ZALTOx words are written by the CPU while the copper could read them; the wait covers lines 24-28 and the copper reads at 26, but a frame whose beam position is unknown (INTWB, Workbench mode) writes without waiting, as the other copper writes do. DbReset's forced CopperLine0 at a Smooth display stop is unchanged and keeps its one-frame glitch. The removal is of code that the assembler shows unreferenced (the build fails on a dangling label); TabCop5's data and its ECS loop stay as they were.
