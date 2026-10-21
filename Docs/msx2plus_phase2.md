# MSX2+ phase 2: R#26 coarse scroll and SP2 (design, 15 Oct 2026)

Phase 1 (commit 84aa492) shows R#27 fine scroll and R#25 MSK per display line on the MSX2+ machine. This document designs phase 2 of `msx2plus_plan.md`: R#26 horizontal coarse scroll (8-dot steps) and SP2 (R#25 bit 0, the 512-dot two-page scroll), for SCREEN 5 and the tile modes, in AmiMSX's copper and plane architecture. It ends with what the first step on this branch implements and how to test it.

## 1. What the V9958 does (openMSX 21.0, SDLRasterizer.cc, CharacterConverter.cc)

- **R#26** (bits 0-5): the picture is scrolled left by `8 * (R#26 & 31)` dots. Screen dot x shows dot `(x + 8*(R#26 & 31)) mod 256` of the line. Sprites do not move. Changes take effect at the next line. Text modes ignore it.
- **R#27** (bits 0-2): the picture is shifted right by R#27 dots, on top of R#26. Phase 1 does this already. Combined: screen dot x shows dot `x + 8*(R#26 & 31) - R#27`.
- **SP2** (R#25 bit 0): openMSX enables it only when R#2 bit 5 is also set (`isMultiPageScrolling`). The line is then 512 dots wide: the even page (R#2's page with bit 5 cleared) followed by the odd page (bit 5 set), and `R#26 & 63` scrolls over it in 8-dot steps; bit 5 of R#26 therefore selects which page is on the left. The wrap is at 512 dots. Name tables (tile modes) work the same: the two name tables are the two 32 KB halves of VRAM (bit 15), and columns wrap from one table into the other.
- **Without SP2** the wrap is within the one page (256 dots) in every mode.
- **Tile modes:** name column `c` of the row is `(c + R#26) & 31`; with SP2 the name table flips (bit 15) when the column wraps past 31.
- **MSK** (R#25 bit 1): the left 8 dots show the border colour. Phase 1.

## 2. How AmiMSX shows SCREEN 5 today

- **Planes:** all of VRAM (128 KB) is kept as 4 bitplanes in chip RAM (`SCR0`, 32 KB a plane, 1024 rows of 32 bytes: VRAM line y is plane row y). A fifth "mask" plane (`SCR0-$8000`, in `MASK`) marks non-zero pixels for the blitter. Port-98h writes (`OUT98A`) do five BFINS per VRAM byte; VDP commands run on the blitter straight in the planes (`MODO5DATS`: 32 bytes a row, 32 KB a plane, 1024 rows) and VRAM is rebuilt from the planes when needed (`BITPLASPR`, `IN98A`, `ModoChg5a0`); CPU-written 1 KB blocks go the other way (`ActPlanos5`, `PU4_BUC`). `MSplitFill` copies plane rows for a SCREEN 5/4 mode split.
- **Display:** AGA 64-bit fetch (FMODE $000F), DDFSTRT $40, DDFSTOP $B8: five 8-byte fetches, 40 bytes a line, so the per-line copper list `TabCop5` sets BPLxMOD -8 every line (0 on ECS, where the fetch is 32 bytes). The bitplane pointers for a line come from the copper line events: `AcCoRutGBY5` (TabRasCMDS bit 0: frame start, R#23/R#2 writes, the vertical wrap line) writes `SCR0 + (page*256 + (R#23 + y)) * 32` into BPLxPT.
- **Horizontal position:** `AcCoRutAdjust` (bit 1) writes BPLCON1 and DIWSTRT/DIWSTOP per event line. The data is delayed by D lores dots, D = 32 + s18 + R#27, where s18 is R#18's shift (-7..+8); R#18 also moves the window (`AdjustBuf`), R#27 does not. At D = 32 data dot 0 is at the window's left edge; D > 32 shows what the Amiga fetched before the line in the left D-32 dots (MSK and "Mask screen edges" hide it).
- **R#26:** stored in `V9R26`, not shown. That is the Gradius III bug: the game draws new columns into a wrapping 256-dot buffer and scrolls it with R#26, so without R#26 the scenery grows from the left edge behind the ship.

## 3. The problem

Three hardware facts decide the design.

1. **No horizontal wrap.** The Amiga fetches a line linearly. To show dots `8n..255` then `0..8n-1` of one row, the row's start must follow its end in chip RAM. With 32-byte rows the bytes after a row are the next row: a pointer offset of n bytes shows the right 8n dots one line too low (a one-line shear at a moving seam).
2. **Pointer alignment.** In 64-bit fetch mode BPLxPT is 8-byte aligned (64 dots); in 32-bit mode 4 bytes (32 dots); in 16-bit mode 2 bytes (16 dots). The remainder has to come from BPLCON1.
3. **Delay range.** BPLCON1 gives 0-63 dots on AGA, but only D <= 32 shows fetched data at the left edge (D = 32 - the dots skipped at the start of the fetch). With the fetch starting at DDFSTRT $40 the picture has 32 dots of slack; starting the fetch 64 dots earlier would need DDFSTRT $20, which takes the DMA slots of hardware sprites 3-7 (AmiMSX uses them). So with 64-bit fetch and 8-byte pointer steps, offsets of 33-63 dots within a step are unreachable, and half of the R#26 values cannot be shown.

**Resolution: 32-bit fetch (FMODE $000D: bitplanes 32-bit, sprites stay 64-bit) in SCREEN 5 on the MSX2+ machine.** Pointer steps of 4 bytes (32 dots) and D in 1..32 reach every offset. DDFSTRT/DDFSTOP stay $40/$B8: 8 fetch units start before DDFSTOP and the hardware does one more, so 9 x 4 = 36 bytes a line (the same rule gives today's 5 x 8 = 40 in 64-bit mode), and the per-line modulo becomes 32 - 36 = -4 (`W5FETCH` in the source; see Tests if the picture shears). Bitplane DMA then uses 36 slots a line instead of 20, of 227; the CPU runs from fast RAM, so this is not measurable.

**The formula.** Per event line, with n = R#26 & 31, W = (8n - R#27 - s18) & 255 (the data offset the window must show at its left edge; s18 is R#18's shift, which also moves the window as today):

- W in 0..224: V = (W - 32) & 255, k = ((V + 32) >> 5) & 7, D = (32k - V) & 255 (1..32). Pointer = row + 4k, BPLCON1 = D. The window shows fetched dots (32 - D)..(287 - D): all inside the 36 bytes.
- W in 225..255 (a right shift of 1..31 dots, as R#27/R#18 give today): k = 0, D = 288 - W (33..63). This is phase 1's behaviour, with the pre-fetch dots on the left.
- n = 0, R#27 = 0, R#18 = 0 gives k = 0, D = 32: exactly today's picture, so the MSX2 look is the reference for the position.

The second case exists only while rows are 32 bytes (step 1 below); with the wide layout (step 2) the first formula covers 0..255 and k = 7 wraps through the row's copy.

## 4. Design: SCREEN 5

### 4.1 Events (step 1, done on this branch)

- `TabRasDATA+7` carries R#26 next to R#18 (+3), R#27 (+5), R#25 (+6). `VDPR26` stores `V9R26` (bits 0-5) and, in SCREEN 5 on the MSX2+ machine (`V9Scr5`), records an adjust event (bit 1) and a pointer event (bit 0, with the current R#2 and R#23) at the next line. `VDPR25`, `VDPR27` and `VDP12` (R#18) record the same pair there, so the pointer step follows the delay. R#23/R#2 events (`VDP17`, the wrap line) are unchanged. The frame start (`MiraInter0`) fills +7 too.
- `ActCopperLine` keeps the adjust state in effect (`AdjCur`: the last adjust event's data at or above the line; line 0 always has one). `AcCoRutGBY5` adds 4k from it to the plane pointers; `AcCoRutAdjust` writes D as BPLCON1. Both use `Adj5Calc` (the formula above) and `AdjCon1` (the AGA BPLCON1 encoding phase 1 already used).
- `ModoGfx5` sets `V9Scr5`, FMODE $000D and patches `TabCop5` and `C5AGA` to the 32-bit modulo (`Mode5Mod`, only when the value changes; `COPPER6` shares `TabCop5`, so `ModoGfx6` restores -8). On MSX2, on ECS and in every other mode nothing changes.
- Cost: one event per register write (a few copper words), `Adj5Calc` about 40 instructions per event line. Nothing in the Z80 or VRAM paths.
- Result: R#26 scrolls per line, sprites still, with a one-line shear in the right `W` dots where the row wraps (the next row's start shows there). Gradius III's scenery enters from the right; the seam moves left as R#26 grows and for R#26 = 29..31 the left 8-24 dots show pre-fetch data instead (hidden by MSK where the game sets it).

### 4.2 True wrap: 64-byte rows (step 2)

The row must be followed by a copy of itself. Rows become 64 bytes: bytes 32-63 repeat bytes 0-31. Then pointer = row + 4k for k = 0..7 and the 36 fetched bytes (up to byte 63) never leave the row. This removes the shear, the left pre-fetch dots of R#27 (the plan's "right edge garbage" item) and the W >= 225 special case.

Touch points (all SCREEN 5, selected at `ModoGfx5` when `V9958On`; the MSX2 machine keeps the 32-byte layout):

- **Memory:** `SCR0` 256 KB (4 planes of 64 KB), the mask plane 64 KB (`MASK` has it; `SCR0-$10000`), `TMASK` 64 KB as now. Chip RAM grows by 128 KB; the 4.0 build uses 923 KB of chip today (hunk sizes), so about 1.05 MB: fine on a 2 MB A1200, but the AmiMSX.guide should say so. `SCREEN 7` would need the same if R#26 is ever done there.
- **Address mapping:** plane byte of VRAM address a = `(a >> 7) * 64 + ((a & 127) >> 2)`, bit `(a & 3) * 2`; every writer writes the byte at +0 and +32. Writers: `OUT98A`/`OUT98AT` (four more BFINS: 8 instead of 4, plus the mask), `PU4_BUC`/`ActPlanos5` (write each plane word twice, +32 after each 16 words), the blitter command engine (next point), `MSplitFill` (read with stride 64), `BITPLASPR`/`BITSPRCOL`/`IN98A`/`POINTA`/`ModoChg5a0` (read 32 bytes, skip 32).
- **Command engine:** a second descriptor `MODO5WDATS` with "bits to rotate" 6 (y * 64), plane size 64 KB, mask plane `SCR0-$10000`, and the duplicate written by treating each 64-byte row as two 32-byte half-rows: a rectangle of NY rows becomes 2*NY half-rows with the same 32-byte stride and X range, for the source as well (its right half holds the same data). The MSX clips commands at 256 dots, so no rectangle crosses the half-row boundary. Per-pixel paths (PSET, LINE, LMMC, LMMV with logical ops done by the CPU) write both halves. TIMP's mask pass (`TMASK`) doubles the same way. Blitter time doubles for commands; see Cost.
- **Copper:** `AcCoRutGBY5` row * 64, `NexBpl5` 64 KB, `PLANO5` (interlace), `TabCop5` modulo 64 - 36 = 28, the vertical wrap unchanged (event line).
- **Layout switch:** on entering SCREEN 5 the planes are rebuilt from VRAM as on a SCREEN 6/8 to 5 change today (`V5All`, about 0.1-0.2 s on a 68030/50: 128 KB through `PU4_BUC` plus 256 KB of chip writes). The 1 KB dirty-block logic (`VBlk5`) stays.

### 4.3 SP2 (step 3)

With SP2 the virtual line is [even page | odd page] (512 dots) and R#26 is 0..63. Layout: 512 page-pair rows of 128 bytes: `even(32) | odd(32) | even(32) | odd(32)` (64 KB a plane again, so the same 256 KB). Pointer = pair row * 128 + 4k with k = 0..15 from `W = (8*(R#26 & 63) - R#27 - s18) & 511`; the fetch reaches byte 60 + 35 = 95 < 128. Without SP2 the 4.2 layout `page row | page row` is needed instead (an odd page would show after an even one), so the two layouts differ and SP2 on/off (R#25 bit 0, or R#2 bit 5 while R#25 bit 0 is set) is a plane rebuild like a mode change. grad2tr and salamall set SP2 once at start, so that is one rebuild.

The command engine's half-row trick holds: a command on page p writes p's two copies, 64 bytes apart in the 128-byte pair row, so a rectangle of NY rows becomes 2*NY rows at a 64-byte stride ("bits to rotate" 7 for the pair row, the copy at +64).

### 4.4 Cost (SCREEN 5)

| Path | 68030/50 (A1200 accelerator) | PiStorm/Emu68 (A1200) |
|---|---|---|
| Step 1 (events + copper) | Under 0.1 ms a frame | Nil |
| Port 98h write, wide layout | 5 BFINS now about 3 us (chip read-modify-write); 9 BFINS about 5.5 us. Gradius III writes one 8-dot column (about 100 bytes) every 24 frames: nil. A game writing 500 bytes a frame: +1.2 ms (6% of a 50 Hz frame) | The same: BFINS to chip RAM is bound by the 7 MHz chip bus, not the CPU |
| Blitter commands, wide layout | Twice the destination words: a full-screen HMMM (212 x 32 bytes x 4 planes) from about 7.6 ms of blitter DMA to 15 ms, still asynchronous | Same |
| `ActPlanos5` dirty blocks | +50% (two writes a word) | Same (chip writes) |
| Plane rebuild on SCREEN 5 entry | Twice the chip writes: about 0.15 s on top of today's | About 0.1 s (chip bound) |
| Chip RAM | +128 KB | +128 KB |

The write doubling is the price of the wrap. It applies only to the MSX2+ machine, which the user picks for the handful of MSX2+ titles, so the MSX2 path and the 030 preset's MSX2 games are untouched.

## 5. Design: tile modes (SCREEN 1, 2, 4)

The tile pass (`PREPRUT1`, `COPYBUF`, `HUDSplit4`, the Dbuf double buffer) renders name-table tiles into `SCREEN` (4 interleaved planes of 32 bytes a line, 128 bytes a line). Here no memory doubling is needed:

- **R#26:** rotate at render time. Screen column c takes name `(c + n) & 31` of the row, n = R#26 & 31; with SP2 the name table flips to the other 32 KB half when the column wraps, exactly as `CharacterConverter::getNamePtr`. A change of n marks every tile dirty (one full redraw: 768 tile copies from the cache, about 3-4 ms of chip writes on an 030; grad2tr changes R#26 every few frames, so expect a few % of CPU while it scrolls). Per-line R#26 (a HUD at n = 0 under a scrolling playfield) is a table split in AmiMSX terms: the HUD rows are drawn by `HUDSplit4` with their own n, like R#2 splits today.
- **True wrap for R#27 (the plan's item):** rows go from 32 to 40 bytes (4 interleaved planes: 160 bytes a line), bytes 32-39 a copy of the row's first 8 bytes (after rotation), so the right edge shows the wrapped dots instead of the next row with R#27 and R#18. Every 32*4 constant changes (`SCREEN`, `SCREENB/T`, `DBROWBYTES`, `MSplitFill`'s destination, `HUDSplit4`), and the per-line modulo (`C4AGA`, now 32*3-8) becomes 40*3 = 120 with the 40-byte fetch. The copy costs 8 of 32 columns (+25% tile writes) when the rows are rebuilt; cheaper: a blitter copy of columns 0-7 per changed row. Only on the MSX2+ machine.
- **Fetch mode:** the tile modes keep 64-bit fetch; the rotation is in the data, so D stays 25..47 as in phase 1.
- Covers Gradius 2 (grad2tr: SCREEN 4, SP2, MSK, scroll), Salamander (salamall: SP2 in SCREEN 2) and Nemesis 3 Enh's R#27 wrap. SCREEN 2 first needs the per-line copper list phase 1 noted (`COPPER2`).

## 6. What phase 2 does not do

- SCREEN 6, 7, 8 with R#26: no title found uses it; the SCREEN 7 layout (64-byte rows, 512 dots) would need 128-byte rows.
- R#26 above a SCREEN 5/4 mode split (`MSplitFill`): the split copy ignores it.
- The YJK modes, CMD bit, WTE (phase 3 of the plan).

## 7. Order of work

1. **Step 1 (cloud/msx2plus-phase2):** events, 32-bit fetch, pointer step and delay in SCREEN 5 behind `V9958On`.
2. **Step 2 (cloud/msx2plus-step2, section 9):** the 64-byte layout for SCREEN 5 (4.2), SP2 (4.3) and the tile modes by name rotation (5).
3. **Next:** pointer-based tile scrolling and the R#27 wrap in the tile modes (9.4).

## 9. Step 2 as implemented (branch cloud/msx2plus-step2, 15 Oct 2026)

Code: `AmiMSX_V9958_v4.asm` (new, included from the main source) plus hooks in the main source. Builds to 572,244 bytes, 13 warnings as master.

### 9.1 SCREEN 5 layouts (`PlMode`)

- **Layouts.** 0: 32-byte rows, 32 KB planes (MSX2, ECS, SCREEN 7). 1: 64-byte rows, the row then its copy (R#26 wraps at 256). 2: 128-byte page-pair rows, even|odd|even|odd (SP2, wrap at 512, R#26 0-63). 1 and 2 have 64 KB planes; `SCR0` is 256 KB, the mask plane is `MASK` (64 KB) and `TMASK` the transparent-op scratch. Chip RAM: about 1.05 MB in all.
- **Who picks it.** `ModoGfx5`: layout 0 unless the MSX2+ machine on AGA with "Refresh 100% Graphics" (the planes must be rebuildable from VRAM); then `PlWant`, which `PRINT5` sets every frame from R#25 bit 0 and R#2 bit 5 (`Pl5Want`, as openMSX's `isMultiPageScrolling`). A layout change is: planes to VRAM for the bands commands drew in (`ModoChg5a0`), `PlSet`, a full VRAM to planes rebuild (`ActPlanos5` with `V5All`), then the descriptor, port 98h handlers and copper modulo (`Mode5Layout`). `PRINT5` switches only after the state has differed for two frames (`Sp2Cnt`), so a game flipping the SP2 page every frame keeps one layout. SCREEN 7 and 6/8 entries put layout 0 back (SCREEN 7 with a rebuild).
- **Address mapping.** `PlRowOff` (VRAM line to the plane byte of its first copy; +32 in layout 2 for an odd page), `PlAddrOff` (VRAM address), `Pl5DispOff` (the display: the pair row's start in layout 2). Port 98h: `OUT98W/P` (+T variants for the SCREEN 4/5 split tracking) write the row and its copy, ten BFINS instead of five; `IN98W/P`, `POINTW/P` read the first copy with the `DARBITW` macro (64 KB plane steps). `PU4W_ROW` converts a 1 KB block, `P4W_BAND` a 16-line band. `BITPLASPR`/`BITSPRCOL` step over the copy after each line's 16 words. `MSplitFill` reads with the layout's stride.
- **VDP commands (blitter).** The wide descriptors `Modo5WDats`/`Modo5PDats` carry: $0A the half-row size (32 or 64; the copy is the next half-row), $3C the doubled-layout flag, $32 the LMMC row stride in bits, $34 the LMMC routine table (`LMMCPunterosW/P`: every pixel also into the copy), $38/$3A the LINE stride and twin offset. `CALCULAR`/`MODODES` take the line offset from `PlRowOff`, double the row count, and for DIY up start at the copy (the half-rows then walk down in memory, so both copies of every row are visited); `BLTSZ` writes BLTSIZV/BLTSIZH for the taller blits. LMMC marks the sprite tables for the whole rectangle at the start, since the bit offset no longer gives the line. LINE is drawn twice. The MSX clips commands at 256 dots, so no span crosses a half-row.
- **Display.** `AcCoRutGBY5` and the interlace pointers use `Pl5DispOff` plus the R#26 step from `Adj5Calc`, which in layout 2 works modulo 512 (k up to 15, pointer +60 bytes, fetch to byte 95 of 128). The per-line modulo is stride - 36 (28, 92; -4 with 32-byte rows). The step-1 right-shift special case stays only for layout 0.

### 9.2 Tile modes (SCREEN 2 and 4)

- `NtSrc` hands the tile pass (`PRINT4`'s `COPIATXT4`/`ACTUALIZA4`, `PREPRUT`, SCREEN 2's `COPIATXT`/`ACTUALIZA`, `HUDSplit4`) a 1 KB copy of the name table rotated by R#26: screen column c takes name `(n + c) & 31`; with SP2 (R#25 bit 0 and R#2 bit 5) `n` counts to 63 and columns past 31 come from the other 32 KB half's table (bit 15), as openMSX's `CharacterConverter`. `n` is per name row: the R#26 in effect at the row's first display line (`row*8 - R#23`), from the frame's start value and its R#26 writes (`R26Ev`, up to 16 a frame). Changed names redraw their tiles through the existing shadow compare, so a step of R#26 is a full tile redraw. With R#26 = 0 and SP2 off the VRAM table is used directly: nothing changes.
- The design's 40-byte rows (R#27 wrap in the tile modes) and the pointer-based 64-byte tile rows are not done; see 9.4.

### 9.3 Costs

| Path | 68030/50 | PiStorm |
|---|---|---|
| Port 98h write, layouts 1/2 | 10 BFINS (chip read-modify-write): about 5.5 us a byte, from 3 | The same (chip bus bound) |
| Blitter commands | Twice the destination words (half-rows): a full-screen HMMM about 15 ms of blitter, from 7.6; the CPU waits on the blitter in the engine | Same |
| Block/band conversions | Two writes a word (+50%); the sprite-table reads unchanged | Same |
| Layout switch (SCREEN 5 entry on MSX2+, SP2 on/off) | About 0.2-0.3 s: planes to VRAM for dirty bands, VRAM to planes with the copies | About 0.1 s |
| Copper (R#26, pointer step) | Under 0.1 ms a frame | Nil |
| Tile modes, R#26 step | `NtSrc` about 0.5 ms (1024 names), then a 768-tile redraw: about 14 ms of blitter copies (the same as Space Manbow's own name-table rewrites every 8 frames) | Blitter bound: the same 14 ms |
| Tile modes, R#26 and SP2 off | Nil | Nil |

### 9.4 Not done / next

- Tile modes: pointer-based coarse scroll (64-byte tile rows, tiles blitted twice, free R#26 steps) and the 40-byte rows for the R#27 wrap; both change every 32*4 constant of the tile buffers (SCREEN, SCREENB/T, Dbuf). Until then grad2tr's R#26 steps cost a full redraw.
- SCREEN 1 and the multicolour mode (R#26 applies there too in openMSX): the same `NtSrc` hook, not wired.
- SCREEN 6/7/8 R#26; R#26 above a SCREEN 5/4 mode split.
- With "Refresh 100% Graphics" off, SCREEN 5 keeps the 32-byte rows (step 1's seam): the planes could not be rebuilt for a layout change.

### 9.4a Boot hang fixed (cloud/msx2plus-step2-fix, 16 Oct 2026)

Found on the PC: with step 2 the MSX2+ machine never booted Gradius III Legends (a stale SCREEN 0 frame with the cursor from about 15 s, the moment the game sets up SCREEN 5). Two causes, both conventions of the Z80 core that step 2 broke:

- **One call level on the Restas A7.** While the Z80 core runs, A7 points at the Restas page table; a port or line handler may make one first-level call (its return address goes to the page's scratch long), and anything pushed deeper lands on another page's Restas or Desbor entry and derails the Z80. Step 2's VDP command engine (CALCULAR, COPIA's BLTSZ, the LMMC start, LINE) and the plane conversions (ActPlaBlkW, P4W_BAND) called `PlRowOff` with JSR/BSR and pushed registers: the game's first SCREEN 5 command corrupted the table. Fix: `PLROWOFF`, an inline macro with no stack and no other register (by the other macros in the main source); BLTSZ, the LMMC start and LINE keep their temporaries in memory (`BltSzTmp`, `LmmcSv`); `P4W_BAND` is entered and left by JMP. `PlRowOff` the subroutine stays for the frame-level callers (ActCopperLine, PRINT5, MSplitFill, the sprite-table readers), where A7 is a stack.
- **BUFER during the render.** The frame loop saves the Z80's D0-D7/A0-A7 in BUFER around Emula1Frame. `Pl5Frame` (PRINT5, the SP2 layout switch) called `ModoChg5a0` and `ActPlanos5`, which save and restore their own registers in BUFER, so the Z80 image was replaced by PRINT5's registers. Fix: Pl5Frame copies BUFER to `PlBufSv` around the two calls. (This path runs only when the SP2 state changes; the boot hang was the first cause.)

A `-DCORRCHK=1` TRACE build (CorrTest, every line) would have caught the first at once; worth running on any change inside the command engine or the mode-entry code.

### 9.5 Tests (WinUAE, then hardware), MSX2+ machine, Refresh 100% Graphics on

1. **Gradius III Legends:** the scenery enters from the right, with no seam and no shear anywhere in the wrap; sprites still; R#27 steps every 3 frames; the left 8 dots are border where the game sets MSK. Compare the title and play screens with the MSX2 machine for position and colours (the 32-bit fetch: `W5FETCH`).
2. **grad2tr (Gradius 2 patch):** SP2 play: the two name tables form one 512-dot line that wraps; the scroll steps; the HUD (table split, if any) stays still. Watch for a hiccup every R#26 step on the 030 (the full tile redraw). Also the original Gradius 2 on the MSX2+ machine: unchanged (no R#26).
3. **VDP commands in the wide layouts:** `tools/make_cmd_test.py` (and the Ianna test) on the MSX2+ machine: HMMM/LMMM/HMMV/LMMV/YMMM with DIX/DIY all four ways, TIMP, LMMC/HMMC, LINE, PSET/POINT, and a read-back through port 98h after each. A wrong copy shows as the right half of the picture differing from the left once R#26 scrolls: scroll the screen with R#26 after the test (a small BASIC `VDP(27)=n` loop) and compare both halves.
4. **Layout switches:** SCREEN 5 to 7 and back, 5 to 8 and back, HELP to the menu and back, a game toggling SP2 (BASIC `VDP(26)` bit 0 with page 1): one rebuild, then clean.
5. **SCREEN 4/5 splits** (Space Manbow) and **Manbow 2** (SCREEN 5/8) on the MSX2+ machine: unchanged pictures (the copy paths through `MSplitFill` and `BITPLASPR`).
6. **MSX2 machine:** `python tools/regress.py smoke` and `feature:cmd` unchanged by construction (`PlMode` 0; only `BLTSZ`, `CALCULAR` and the readers gained tests on a zero flag).

### 9.6 Risks

- The half-row trick relies on the blitter walking copies in the DIY direction; a DIY-up copy that writes one copy only would show as the right half lagging after a vertical scroll copy. The test in 9.5.3 covers it.
- BLTSIZV/BLTSIZH (ECS and AGA registers) are used only in layouts 1/2 (AGA by construction).
- `POINTW/P` and `OUT98P`'s bit arithmetic (page bits 15/16) is new; a wrong pair offset shows as page 1 drawing into page 0's rows.
- The SP2 layout shows the even page first whatever page R#2 names: a game with SP2 set but displaying an even page is shown through the pair layout only after the two-frame debounce lets it in; openMSX shows no multi-page then. Such a game would look wrong in the right part while scrolled; none is known.
- `NtSrc` uses the R#26 at a row's first display line; a game changing R#26 mid-row would show one value for the row.

### 9.7 The 32-bit fetch and the wide layout only once R#26 scrolls (4.1.2, 19 Oct 2026)

Two A1200 reports (4.1/4.1.1) said the picture has a different size or position with ROM = MSX2+ than with MSX2, for Pampas & Selene (SCREEN 5, never writes R#25-27) as much as for grad2tr. WinUAE shows no shift (the MSX2+ and MSX2 captures of Pampas at 45 s are pixel-identical outside the sprite), so if the A1200 does, it is in what the AGA chips make of the 32-bit fetch (FMODE $D) at the same DDFSTRT $40 as the 64-bit one: WinUAE models the fetch-unit alignment of an unaligned DDFSTRT (`delayoffset`, which cancels at $40) and the hardware may not, and only a photo can settle it. Rather than calibrate a constant for the 32-bit fetch, step 2 now stays on the MSX2 path until a game needs the other one:

- `V9R26Used` (VDPR26, ModoGfx5): set once R#26 (any of its 6 bits: with SP2, 32 is a real 256-dot scroll) is written non-zero in SCREEN 5 on the MSX2+ machine; cleared at Power ON and recomputed from R#26 at every SCREEN 5 entry.
- `Pl5Want` asks for layout 1 only with `V9R26Used` (layout 2 with SP2 as before), so a game that never scrolls keeps the MSX2 layout: the same planes, port-98h handlers, command descriptor and sprite-table readers as the MSX2 machine (the 4.1 reader bug would not have reached Pampas & Selene).
- `Mode5Fetch` (Mode5Layout, and PRINT5 every frame through Pl5Frame) sets `V9Fm32` (the 32-bit fetch and the 36-byte modulo) only with `V9Scr5` and `V9R26Used`; otherwise the 64-bit fetch's modulo (stride - 40: -8 in the MSX2 layout, as always). It writes FMODE itself ($000D or $000F) only where FMODE is this mode's to set (`V9Fm32Ok`: not a pair-split regime, where the top's is BMSPost's and the bottom's AcCoBMSw's, as in 4.1.1). `V9Fm32` is the state in force: `AcCoRutAdjust` (Adj5Calc's delay), `AcCoRutGBY5` (the pointer step) and `AcCoBMSw` (the pair split's FMODE) test it instead of `V9Scr5`.
- The switch happens at the frame after the first scrolling write (the same place as the SP2 layout switch, with its one-frame mismatch between the copper list already built and the new modulo, which the 0.2 s plane rebuild hides anyway). Gradius III Legends writes R#26 from the start of play; grad2tr is a tile-mode game, untouched by this.

So an MSX2+ machine running a game without R#26/SP2 displays SCREEN 5 exactly as the MSX2 machine, by construction. **A1200 check:** Pampas & Selene (and any other SCREEN 5 game) must now look the same with ROM = MSX2 and ROM = MSX2+, same size and position. If it still differs, the cause is not the fetch and must be in the MSX2+ BIOS (its 50/60 Hz and the ID patch) rather than in AmiMSX's display. Gradius III Legends in play (R#26 in use, the 32-bit fetch) is the one place a hardware offset of the 32-bit fetch would still show, as a picture shifted against the MSX2 build's title screen; that is the constant to calibrate in `Adj5Calc` if the chips disagree with WinUAE.

## 8. Summary for testing (step 1)

- **Build:** `AmiMSX_Main_v3.1.asm` assembles cleanly with vasm (WASM build in the cloud, 563,368 bytes on master; this branch adds the step 1 code). `W5FETCH` (36) is the only calibration constant.
- **WinUAE / hardware, MSX2+ machine, Gradius III Legends (disk, MSX-MUSIC, RAM mapper, floppy):**
  1. Title and play as before (R#26 = 0: the picture must be at the MSX2 position, no shear). If every line is sheared by 4 bytes the fetch count is wrong: set `W5FETCH` to 40 (or 32 and see Risks).
  2. In play, the scenery enters from the right edge and the ship is not covered. Expect a one-line vertical seam that moves left in 8-dot steps every 24 frames (step 1 only), and 8-24 border/pre-fetch dots on the left when R#26 is 29-31.
  3. Sprites do not move with the scroll; R#27 still steps every 3 frames.
  4. HELP to the menu and back, SCREEN 5 <-> SCREEN 6/7/8 switches: `TabCop5`'s modulo must come back (-8) for SCREEN 6.
- **openMSX reference:** machine AmiMSX_MSX2P_Disk with the disk; `tools/burst.py --machine` for consecutive frames once `g3l.keys` reaches play.
- **Regression (tests/titles.csv):** MSX2 titles unchanged by construction (`V9958On` off); run `smoke` once. MSX2+ titles affected: R2K_SpaceManbow (SCREEN 4/5 split, R#27), 001_Manbow2 (SCREEN 5/8, R#23 scroll), 100_ChikubiNinja, R2K_Nemesis3Enh, R2K_SalamanderEnh on the MSX2+ machine: no R#26 writes expected (openMSX scans), so identical captures; 020_GradiusIIILegends: new baseline.
- **Risks:**
  - The fetch count in 32-bit mode (36 assumed): visible at once as a shear. If the hardware fetches 32, DDFSTOP must move to $C0 for the extra unit.
  - The picture position at D = 32 in 32-bit mode is assumed equal to 64-bit mode's (same DDFSTRT). A constant offset shows against the MSX2 build and is fixed in `Adj5Calc`.
  - Pointer alignment: row * 32 + 4k is 4-byte aligned (`SCR0` is 8-aligned).
  - `TabCop5` is shared with SCREEN 6; the restore in `ModoGfx6` covers the switch, the menu path re-enters through `ModoGfx5`.
  - Events written in VBlank (lines 212-255) land in unused table lines, as phase 1's do; the frame start rewrites line 0.
