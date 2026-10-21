# Display on AGA

*Reading notes.* The examples come from AmiMSX, which converts the MSX video chip (the VDP) into AGA bitplanes and builds a copper list for every frame. "Commit" references name the AmiMSX development repository. The public repository carries squashed commits, so there the build switch and the symbol name are the stable things to look up; the `Docs/agent_notes/` files are working notes kept in the development repository only. Lessons marked *4.2* are fixes made after the 4.1.2 release.

## Copper lists built per frame, and racing the beam on fast CPUs

### A page switch shown a frame late (Barbarian's fighters vanish every second frame)

**Problem.** In Barbarian (MSX2, SCREEN 5) the fighters were missing or see-through in every second Amiga frame on a PiStorm A1200. A normal WinUAE capture did not show it (chapter 06 explains why). In 12 consecutive live frames from the unfixed build, one fighter was missing in 7 of them.

**What the game does** (read from a reference-emulator log). The fighters are not sprites. They are drawn into a bitmap with triple-buffered pages 0 to 2; page 3 holds the clean arena. The game runs at 25 frames a second. In the frame where it flips, everything happens in the top border after the vertical blank. About line 22 it writes R#2 (the VDP's page register) to show the next page. About line 29 it copies the arena background over the page that was just on screen (HMMM, a VDP block copy). Then it draws the fighters into the third page with the CPU. On a real MSX the restore lands on a page that is no longer shown, so it is never visible.

**Why AmiMSX showed it.** AmiMSX runs one MSX frame, then builds the per-line copper list for that frame. The Amiga shows that list while the Z80 core runs the next MSX frame. The R#2 flip therefore reached the display one Amiga frame late. VRAM writes and VDP commands, however, go straight into the bitplanes. On a fast CPU the Z80 reaches line 29 before the beam has reached the fighters, so the Amiga frame showed the old page with its fighters just erased.

**Before** (`AmiMSX_Main_v3.1.asm`, the R#2 write handler, AmiMSX 4.1.1):

```
	AND.B	#$7F,D1
	MULU	#$400,D1
	MOVE.L	D1,PVDP2(A3)		; remember the page; the copper list
	MOVEQ	#$17,D1			; is rebuilt after the frame
	MOVE.B	VDPLinY(A3),D2
	JMP	([VDPPUNT.W,PC,D1.W*4])
```

*Source: AmiMSX 4.1.1, AmiMSX_Main_v3.1.asm (freeware by Juan Antonio Gómez Gálvez; 4.x changes; used with permission).*

**After** (commits 5d15cdf and 68acad3; trimmed):

```
	MOVE.L	D1,PVDP2(A3)
	TST.B	L0Arm			; armed from the list's build to the
	BEQ.S	VDP2NoL0		; next display start (MiraInter0)
	JMP	VDP2L0
VDP2NoL0:
	...
; VDP2L0 runs inside a Z80 handler, so it uses no stack.
	MOVEQ	#$60,D0
	AND.B	D2,D0			; page bits of R#2
	ADD.W	D0,D0			; page * 64 bytes
	LEA	L0Tab,A0		; line 0's pointer block for each page,
	ADD.W	D0,A0			; precomputed by L0Prep
	MOVE.L	L0Blk,A1		; line 0's block in the list ON SCREEN
	MOVE.W	L0Len,D0
VDP2L0L:
	MOVE.L	(A0)+,(A1)+		; patch it live
	DBF	D0,VDP2L0L
	...				; is the beam already in the picture?
	MOVE.L	$DFF004,D1
	LSR.L	#8,D1
	AND.W	#$1FF,D1		; beam line
	SUB.W	#IniPant,D1		; display line (about)
	BMI	VDP2L0Y			; still before the picture: done
	ADDQ.W	#4,D1			; margin: the copper may be ahead
	...				; else add a pointer event on that line
					; in a spare chip RAM slot (L0Late)
```

*Source: AmiMSX 4.1.2, AmiMSX_Main_v3.1.asm (freeware by Juan Antonio Gómez Gálvez; 4.x changes; used with permission).*

**Why.** The copper list is a program the copper runs once per frame. A change that happens after the list was built has to patch the list that is already on screen, or it arrives a frame late. `L0Prep` runs when the list is built and computes line 0's bitplane-pointer block for each of the four pages. `VDP2L0` copies the right block into the live list when R#2 is written in the border. If the beam is already inside the picture, line 0's block has run for this frame, so a second event a few lines below the beam switches the pointers there. The slot for that event is registered so that the next build clears it. The fix is skipped where it would be wrong: R#23 (vertical scroll) also changed in the border, the list already has a pointer event below line 0, or the page would wrap.

**Evidence.**
- Unfixed build, live-view capture: one fighter missing in 7 of 12 consecutive frames. Fixed build: both fighters in all 12.
- The late path fires on every flip on the 68030 configuration and in 4 of 12 frames on the WinUAE 68060 configuration (the beam is often already in the picture at the flip, even on a fast CPU). Both fighters were present in all 24 frames, and the picture below the event used the right pointers.
- Smoke regression: 15 of 15 titles, 45 of 45 captures identical to the baselines.
- Confirmed afterwards on the real PiStorm A1200: fighters and the goblin solid in play.

**Look up.** Commits c853172 (analysis), 5d15cdf, 68acad3, ed6e595, 5aa7633. Build switches `SNAPLIVE` (see chapter 06), `NOL0` (old behaviour), `L0DEBUG` (red border from the late event's line). Notes: `Docs/agent_notes/barbarian.md`. Known limits: R#23 changed in the border too, pointer splits below line 0, page wrap.

**Rule of thumb.** When the display is built from a snapshot of a finished frame but some state is written straight into the planes, a fast CPU can run ahead of the beam and mix the two. Decide for each kind of write whether it lands in the live display or in the next one, and make them agree.

## Bitplane fetch alignment: DDFSTRT, FMODE and the BPLCON1 delay

### The 32-bit fetch applies the scroll delay modulo 32, from the middle of a unit

**Problem.** Gradius III Legends on the MSX2+ machine (SCREEN 5, scrolled with the V9958's R#26 coarse and R#27 fine registers) showed the whole landscape 32 dots too far right for about half of every 32 dots of scroll. The wrapped part of each row appeared as a rock column at the left edge, then the picture jumped back by 32 dots. It happened in WinUAE and on the real A1200.

**Before** (`AmiMSX_Main_v3.1.asm`, `Adj5Calc`, AmiMSX 4.1.1). The data fetch started at DDFSTRT $40 for every FMODE:

```
Adj5Wrap:
	SUB.W	#32,D2
	AND.W	D1,D2			; V
	...				; delay 32k - V, 1..32
```

**After** (commit f651611; `AmiMSX_V9958_v4.asm` and `AmiMSX_Main_v3.1.asm`):

```
; DdfSync: once per rendered frame the fetch window follows FMODE.
DdfSync:
	CMP.W	#$000D,MCAGA+2		; 32-bit fetch?
	BNE.S	DdfSStd
	MOVE.W	#$0038,AdjustX+2	; DDFSTRT $38: on a unit boundary
	MOVE.W	#$00B0,AdjustX+6	; DDFSTOP $B0: still 9 units, 36 bytes
	RTS
DdfSStd:				; every other FMODE keeps $40 / $B8
	...

; Adj5Calc, tail: f = ((W-1) & 31) + 1, delay = 32 - f  (0..31)
	SUBQ.W	#1,D2
	AND.W	D1,D2
	MOVEQ	#31,D1
	AND.W	D2,D1			; f - 1
	SUB.W	D1,D2			; 32k
	LSR.W	#3,D2			; 4k bytes added to the plane pointers
	NEG.W	D1
	ADD.W	#31,D1			; delay 32 - f
	RTS
```

*Source: AmiMSX 4.1.1 and 4.1.2, AmiMSX_Main_v3.1.asm and AmiMSX_V9958_v4.asm (freeware by Juan Antonio Gómez Gálvez; 4.x changes; used with permission).*

**Why.** With the 32-bit fetch (FMODE $D) AGA takes the BPLCON1 delay modulo the fetch width, 32 low-resolution dots, and counts it from the position of DDFSTRT inside the 16-colour-clock fetch unit. DDFSTRT $40 is 8 clocks into a unit, so the effective delay was (BPLCON1 + 16) and 31. Delays 16 to 32 behaved. Delays 1 to 15 acted as D + 16 instead of D - 16, which moves the picture 32 dots to the right. WinUAE models this (the same offset and mask), so the emulator matched the chips. At DDFSTRT $38, a unit boundary, the delay is simply BPLCON1 and 31, and all 32 offsets inside a 4-byte pointer step are reachable. The old special case for right shifts (delays 33 to 63) is gone, because delays above 31 do not exist with a 32-bit fetch. One formula now serves every plane layout, and it uses no stack.

**Evidence.** A burst of 120 consecutive frames (one MSX frame apart) of the same scene:
- Old build: 32-dot jumps, and the left column for about 55 of the 120 frames.
- New build: the rock moves 1 dot (2 capture pixels) every 3 to 4 frames through more than one full 32-dot cycle, with no jump and no column.
- Regression: of the three Gradius III Legends captures on the MSX2+ machine, two were identical and one changed, the one that had shown the bug. The 15-title smoke tier (45 captures, including Chikubi Ninja, which uses the V9958 mask and R#27) was identical to the baseline.

**Look up.** Commit f651611; `DdfSync`, `Adj5Calc`; notes `Docs/agent_notes/g3scroll.md`. Still open: the SCREEN 8 over SCREEN 5 pair split writes FMODE $D at the split under the frame's $40 window.

**Rule of thumb.** If a scroll delay jumps by exactly the fetch width, check where DDFSTRT falls inside the fetch unit for the FMODE you use, and align it to a unit boundary.

## The frame's DMACON word and the BL (blank) bit

### One frame-wide register written by every R#1 write

**Problem.** Manbow 2's title screen was completely black in WinUAE with the 68030 configuration (every capture from 12 to 36 s) and showed scattered fragments on a PiStorm. The reference emulator showed the logo.

**Before** (`AmiMSX_Main_v3.1.asm`, `VDP1`, the R#1 handler, AmiMSX 4.0):

```
VDP1NoBl:
	SF	S5Valid
	MOVE.W	#$0100,D1		; bitplane DMA off ...
	BTST	#6,D2
	BEQ.S	VDP1C0
	MOVE.W	#$8100,D1		; ... or on, from R#1 bit 6 (BL)
VDP1C0:
	MOVE.W	D1,MCOPP96+2		; the frame's DMACON word, read by the
					; copper at the TOP of the Amiga frame
	MOVE.B	D2,DVDP1(A3)
```

A BL change in the middle of the display took the same exit, after queueing a copper event.

**After** (commit 4c5ab70):

```
MiraInter0:				; the display starts
	MOVE.W	#$0100,D1		; the frame's bitplane DMA is R#1 BL
	BTST	#6,DVDP1(A3)		; as the display starts
	BEQ.S	MI0BlOff
	MOVE.W	#$8100,D1
MI0BlOff:
	MOVE.W	D1,MCOPP96+2
	...
VDP1BlOff:				; a BL change inside the display
	MOVE.B	#3,PalSplitSeen
	SF	S5Valid
	BRA.S	VDP1Set			; copper event only: MCOPP96 is not
					; touched, it keeps the state at line 0
```

*Source: AmiMSX 4.0 and 4.1, AmiMSX_Main_v3.1.asm (freeware by Juan Antonio Gómez Gálvez; 4.x changes; used with permission).*

**Why.** The title screen is a SCREEN 8 logo above line 141 and a SCREEN 5 band below it, with the display blanked around the split. Every frame the game writes R#1 like this: on in the vertical blank, off at line 141, on at 145, off at 181. AmiMSX stored the DMACON word (the master copper list's bitplane-enable word, read once at the top of the Amiga frame) on every R#1 write. The word therefore held the last write the emulated frame had made before the copper list was built, and that write was the "off" at line 181. The copper list is built at line 192, before the next vertical blank's "on", so the bitplane DMA was off for the whole Amiga frame. On the PiStorm the same word was read in the middle of a much shorter Z80 burst, which gave fragments. A mid-frame blank that only recolours (below) can never bring the planes back. Any game that blanks the bottom of its display and writes R#1 last in the frame is affected, not just this title.

**Evidence.** Before: black at every capture from 12 to 36 s on the 68030 configuration. After: the title frame is displayed (at first as scattered dots, which was the next bug, the bitmap-pair split below). A game that blanks its top band and shows the rest still shows the rest: a mid-frame "on" in a frame that started blank turns the DMA on and blanks from line 0 by colours.

**Look up.** Commit 4c5ab70; `MCOPP96`, `MiraInter0`, `VDP1`, `BlankTab`; `Docs/open_issues.md`, the Manbow 2 entry.

### Blanking a few lines in the middle of the picture

**Problem.** Lilly's Saga switches tables for two lines under its HUD with the display turned off (R#1 BL). AmiMSX ignored the mid-frame BL change, so the half-switched line showed as a dotted line at the HUD split, running into the right border.

**Fix.** Keep bitplane DMA on and recolour. A mid-frame BL change becomes an event in the per-line copper list (`AcCoRutBlank`). On AGA, outside SCREEN 8, the event is one write to BPLCON4 that selects a bank of 16 colours pre-filled with the border colour (colours 32 to 47), and one write to switch back. Elsewhere the event writes all 16 colour registers.

```
	CMP.W	#$01FC,MCAGA		; AGA, not SCREEN 8: switch the
	BNE.S	ACBlEcs			; planes to the blank bank and back
	...
	MOVE.W	#$010C,(A3)+		; BPLCON4 as the master list has it
	MOVE.W	MCAGA+10,D2
	CMP.B	#1,D1			; 1 = blank, 2 = display again
	BNE.S	ACBlOn4
	EOR.W	#$2000,D2		; bank bit: colours 32-47
ACBlOn4:
	MOVE.W	D2,(A3)+
```

*Source: AmiMSX 4.1.2, AmiMSX_Main_v3.1.asm, AcCoRutBlank (freeware by Juan Antonio Gómez Gálvez; 4.x changes; used with permission).*

**Why.** One copper MOVE per transition instead of sixteen leaves the copper time for the line's other events. **Evidence:** the stray line above the HUD is gone. Jailbreak and Zanac EX Enhanced, which blank lines at their splits, changed the same way. **Look up:** commit 756f842; `Docs/open_issues.md`, the Lilly's Saga HUD row.

## Mid-frame palette, mode and page splits

The per-line copper list (`ActCopperLine`) gives every display line that has an event a small routine: bitplane pointers for the line (page and vertical scroll), the horizontal adjust (R#18, R#25, R#27), palette changes and blanking. A page split is the Barbarian case above. Palette changes reach the screen at a frame start through the copper, so a frame is never shown with half of one palette and half of another. A mode split is harder, because the two parts need different plane layouts.

### Two bitmap modes in one frame (SCREEN 8 over SCREEN 5)

**Problem.** Manbow 2's title has a SCREEN 8 logo above display line 141 and a SCREEN 5 band below it, each with its own page and vertical scroll, switched by a line interrupt every frame. AmiMSX rendered a frame in one mode with one set of plane pointers, so the logo came out as scattered dots.

**Before.** One buffer (`SCR0`) holds the planes of the mode that rendered last. SCREEN 5 uses 4 planes of 32 KB, SCREEN 8 uses 8 planes of 16 KB, and the two layouts overlap everywhere in the buffer, so it cannot hold a SCREEN 8 page and a SCREEN 5 page at once. The mode that wins is the mode at the end of the emulated frame, which depends on when the last R#0 write lands.

**After** (4.1; design in `Docs/bitmap_mode_split.md`):
- The top page goes into its own 64 KB chip buffer (`SCREENP`: 8 planes of 256 lines of 32 bytes), converted before each render. The frame runs the top mode's copper list, and one copper event at the split line switches to the bottom mode: BPLCON0 (8 planes to 4), BPLCON4, the bottom's plane pointers and its colours.
- Entering the other mode during the split leaves the buffer alone. The game's SCREEN 8 writes made in the vertical blank flag VRAM and nothing else, so the SCREEN 5 planes survive.
- Review found that the first draft emitted the bottom's colours (about 50 MOVEs) before its plane pointers at the split line, so the pointers could arrive after the line's fetch started. The fix emits the pointers first:

```
ACBMSwFmX:
	MOVE.W	#$010C,(A3)+		; BPLCON4 as MASTERCOPPER.
	MOVE.W	MCAGA+10,(A3)+
	BSR	ACBMSwPtr		; the bottom's plane pointers before the
	CMP.B	#1,(BlankTab.L,D7.W)	; colours (review R2 2)
```

*Source: AmiMSX 4.1, AmiMSX_Main_v3.1.asm (freeware by Juan Antonio Gómez Gálvez; 4.x changes; used with permission).*

**Why.** A copper list runs in order at the beam's pace. What must be in place before the line's bitplane fetch (pointers, BPLCON0) goes first. Colours, which tolerate being a few pixels late, go after.

**Evidence.** After the DMACON fix and the split, the 68030 configuration shows the SCREEN 8 logo as a whole picture. Not solved in 4.1.2: the SCREEN 5 band below it (the START prompt) is missing. The cause is outside the display code. The V9938 interleaves SCREEN 7 and 8 across its two 64 KB banks: logical address A lives at physical (A shifted right by 1) OR ((A AND 1) shifted left by 16). AmiMSX stored VRAM linearly in those modes, so the game's SCREEN 8 copies into page 1 overwrote SCREEN 5 page 2. A second bug found on the way: VDP commands in SCREEN 5 and 7 draw only into the planes, and the flush back to VRAM on leaving the mode (`DirModoChg`) had been commented out in two mode-entry routines since the 3.1 import. That fix exists on a branch but was not merged, because on its own it made the title worse. Both are 4.2 items.

**Look up.** `Docs/bitmap_mode_split.md`; commits cbc978e, 22b4fbb, cde7b3a (unmerged flush); notes `Docs/agent_notes/manbow2.md` (branch only); `Docs/open_issues.md`, the Manbow 2 entry.

## Colour levels: mapping the source machine's palette to 12-bit and 24-bit AGA

### 3-bit levels to 4-bit nibbles: white was $EEE

**Problem.** Users saw AmiMSX's colours as brighter and whiter than the reference emulator (Barbarian's sky cream instead of salmon, Popolon's floor white). Two separate causes were found. This lesson is the one in AmiMSX. The other is the capture path (chapter 06).

**Before** (`OUT9Ab`, the palette port, AmiMSX 4.1.1):

```
	MOVE.B	D1,D2
	AND.B	#$07,D2
	LSL.B	#5,D2			; green level n -> 2n
	MOVE.W	DATPAL(A3),D1
	LSR.W	#3,D1
	LSR.B	#4,D1			; red and blue levels n -> 2n
```

The MSX palette has 3 bits per channel (levels 0 to 7). Level n became the 4-bit value 2n, so the top level was 14, white was $EEE, and every level was one step dark.

**After** (commit b43d386):

```
	MOVE.B	D1,D2
	AND.B	#$07,D2
	MOVE.B	(PalLvG-$100.L,D2.W),D2	; green: level -> $G0
	MOVEQ	#0,D1
	MOVE.B	DATPAL(A3),D1		; 0RRR0BBB
	MOVE.W	(PalLvRB.L,D1.W*2),D1	; red and blue -> $0R0B
	OR.B	D2,D1
	...
PalLvG:	DC.B	$00,$30,$50,$70,$90,$B0,$D0,$F0
```

The default tables (`MSX1PAL`, `MSX2Pal`), the SCREEN 8 fixed palette (`PaletaG7`) and the SCREEN 8 sprite palette were converted the same way. White is now $FFF.

*Source: AmiMSX 4.1.1 and 4.1.2, AmiMSX_Main_v3.1.asm (freeware by Juan Antonio Gómez Gálvez; 4.x changes; used with permission).*

**Why.** The reference emulator shows level n as 255 times (n/7) to the power 1/1.1, which is 0, 43, 81, 118, 153, 187, 221, 255. AGA (with LOCT zero) shows nibble times 17. The nearest nibble to each reference level is 0, 3, 5, 7, 9, 11, 13, 15, which shows as 0, 51, 85, 119, 153, 187, 221, 255: at most 8 of 255 away, at level 1. No extra copper writes are needed, because AGA keeps the high-colour bits at zero and the path is the one ECS uses. The table lookup also replaced a shift sequence whose low blue bit was taken from the next byte.

**Evidence.** Colour-bar ROM and game captures from WinUAE with GDI output (the exact Amiga register values), compared with the reference emulator:

| Colour | Reference | 4.1.1 | 4.1.2 |
|---|---|---|---|
| grey level 3 | 118 | 102 | 119 |
| grey level 7 (white) | 255 | 238 | 255 |
| Barbarian sky | 255,187,153 | 238,170,136 | 255,187,153 |
| Popolon floor (colour 14) | 187 | 170 | 187 |

In the 15-title smoke tier, 43 of 45 captures changed and 2 were identical (dark frames). For every pair, at least 99.8% of pixels mapped an old colour to the same new colour, and content and position did not change (`tools/colour_only.py`).

**Look up.** Commits 68ab159 to 7c9cc7f; `PalLvRB`, `PalLvG`; `tools/make_colour_test.py`, `tools/colour_bars.py`, `tools/colour_only.py`, `tools/pal_probe.py`; notes `Docs/agent_notes/colours.md`.

## Edge masks and the display window

### The window was exactly the picture, and the mask offsets hid 10 and 12 dots

*4.2 (after the 4.1.2 release).*

**Problem.** The "mask screen edges" option hides the columns that games redraw while scrolling sideways. It hid more than it said. In Uridium 2 it cut the HUD panel at both ends, because 4.0 also turned the mask on automatically when it saw R#18 change from frame to frame.

**Before** (`AmiMSX_Main_v3.1.asm`, 4.1.1):

```
EDGEL=10			; window edges moved in for "8 dots"
EDGER=12
...
	ADD.B	#EDGEL,VERPAN+3		; window start
	SUB.B	#EDGER,VERPAN+7		; window stop
```

**After** (branch agents412/mask, commits fbcce47 and 1667dc3):

```
EDGEL0=0			; the window IS the 256 picture dots
EDGER0=0
...
MiraInter0S:				; each frame start: Off, 8 or 16 dots
	MOVE.B	PrefMask,D1
	BEQ.S	MaskSet
	CMP.B	#16,D1
	BEQ.S	Mask16
	MOVE.B	#8,D1
Mask16:	ADD.B	#EDGEL0,D1
MaskSet:
	MOVE.B	D1,MaskL
	...
```

*Source: AmiMSX 4.1.1 and 4.2 development, AmiMSX_Main_v3.1.asm (freeware by Juan Antonio Gómez Gálvez; 4.x changes; used with permission).*

**Why.** The old constants came from a measurement in WinUAE that assumed the display window was 8 dots wider than the picture (3 on the left, 5 on the right). Measured against the reference emulator's picture, the window start and stop bytes already describe exactly the 256 picture dots, so "8 dots" moved the edges in by 8 plus the supposed margins. The automatic mode is gone too. The option is Off, 8 or 16 dots each side, saved in the preferences and per game, and the V9958's own mask bit (R#25 MSK) is always honoured.

**Evidence** (Uridium 2's HUD, at 2.125 capture pixels per dot):
- Off: the full panel, as in the reference emulator.
- 8 dots: with the margins of 3 and 5 it hid 10.8 and 13.2 dots; after the change 8.0 and 8.0.
- 16 dots: 16.0 and 16.5 after. The step from 8 to 16 dots was 17 pixels each side, exactly 8 dots, which is how the extra margin showed up.
- Lilly's Saga with 8 dots: the window was 232 dots wide with the margins (256 minus 24) and 240 dots after (256 minus 16), at both 30 and 45 s, with no redraw columns.

**Look up.** Branch agents412/mask; `EDGEL0`, `EDGER0`, `MaskL`, `MaskR`; notes `Docs/agent_notes/mask.md` (branch only). Not checked: the menu, and the 512-dot modes (the window bytes come from one table for all modes, in low-resolution units).

## Intuition screens on OS 3.2: AllocScreenBuffer with Intuition's own bitmaps

*To be written (Arnold).*

## Vertical-scroll display shift with a taller buffer

*To be written (Arnold).*

## NTSC 240-line and PAL 272-line (TALL) screens

*To be written (Arnold).*

## Border colour as colour 0; cropping a 384-pixel picture to 320 lores

*To be written (Arnold).*
