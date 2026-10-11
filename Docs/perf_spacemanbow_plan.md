# Space Manbow performance: deep-dive plan (12 Oct 2026)

Space Manbow (Konami, 1989, MSX2, 1 MB Konami SCC) is much faster in 4.0 than in 3.1, but on a fast Amiga it still doesn't reach real-MSX speed. This plan is for finding out why, and for working out what MSX2+ changes.

## What we know already

- **Display:**
  - SCREEN 4, with sprite mode 2.
  - A table split at line 81 (status page 3Fh, then the playfield at name table 30h/31h). AmiMSX draws the playfield below the split line by line (HUDSplit4).
  - Vertical scroll by R#23, horizontal adjust by R#18, and sprite bands, each with its own R#23.
- **Cost of the SCREEN 4 tile pass:** it's AmiMSX's single biggest renderer cost in this kind of game. In Lilly's Saga's gameplay (also SCREEN 4) on the 060 config, the perf sub-timers show the tile pass (`S4tiles`) at about 98-107 lines per frame, out of 313. The Z80 core is about 103 lines, and FMX about 17.
- **MSX2+ (openMSX, C-BIOS MSX2+, 11 Oct):** the game detects the V9958. It sets R#25 = 02h (mask the left 8 dots) and scrolls horizontally with R#27 (fine scroll, 0-7) from about 16 s. On MSX2 it has no hardware horizontal scroll and redraws the name table instead.
- **AmiMSX has no V9958 support:** nothing handles R#25, R#26 or R#27. So on an MSX2+ BIOS, AmiMSX ignores the fine scroll, and the playfield moves in 8-dot steps.

## Questions the deep dive must answer

1. **Where does the time go?** For each frame on a fast Amiga (WinUAE 68060 config, then PiStorm/BigMig), measure the Z80 core, the SCREEN 4 tile pass, the HUD split, sprite bands, the copper list build, sound, and waiting.
2. **Is the Z80 side close to real hardware?** Compare AmiMSX's Z80 cost per MSX frame with how busy the game's Z80 actually is. In openMSX, measure the idle share: time in its wait-for-interrupt loop, by PC histogram.
3. **Does the tile pass redraw more than changed?** With a horizontal scroll, every name-table shift touches the whole playfield. Count the tiles redrawn per frame against the tiles whose name or pattern actually changed.
4. **MSX2 against MSX2+:** with V9958 scroll support, the MSX2+ path should be much cheaper. The name table is no longer rewritten every 8 dots; a BPLCON1 shift covers the fine scroll and an R#26 page offset the coarse scroll. Is MSX2+ then the faster way to play it?

## Method

1. **Fixed test points.** Make a key script that reaches stage 1 in play and holds the ship, plus an attract-mode run that needs no input. The regression's "play" keys already reach play at 30-60 s.
2. **A perf build with sub-timers** (`-DPERF=1 -DPERFSUBS=1 -DPERFTICKS=...`). Add sub-timers where there are none yet: HUDSplit4, the sprite band renderer, the copper line build, and the Z80 core between VBlanks.
   - Run it on the 060 and 030 configs, with the MSX2 BIOS and with the MSX2+ BIOS (AmiMSX2.data has both), and with sprites set to every frame and every 2nd frame.
3. **A PC profile.** Use the same perf.bin with `tools/read_prof.py` and a listing from the same build, to get the top 30 routines by samples in gameplay.
4. **Tile-pass counters** (perf build): tiles drawn per frame, split into name changed, pattern changed and full redraw (ACTUTODO). Compare these with openMSX's VRAM writes per frame from a VDP I/O log, using the `omsx_vdpio` scripts.
5. **Z80 idle in openMSX:** a PC histogram over 10 s of play gives the share in the wait loop. That is the headroom real hardware has, which AmiMSX's Z80 core must fit into.
6. **Write-up:** a per-frame budget table for each config and BIOS, the top hotspots, and an estimated saving for each candidate fix.

## Likely fixes (to be ranked by the measurements)

| Candidate | Why | Size |
|---|---|---|
| V9958 horizontal scroll (R#25 MSK/SP2, R#26, R#27) mapped to BPLCON1 plus the bitplane pointer | Correct MSX2+ scrolling, and far fewer tile redraws on MSX2+ | Medium |
| SCREEN 4 tile pass: shift instead of redraw when the whole name table moves by one column | The MSX2 scroll rewrites every name; most tiles only move | Medium-large |
| Chip RAM writes: render in fast RAM, then MOVE16 or blitter to chip on 040/060 | Chip writes are slow even on PiStorm | Medium |
| Sprite bands: skip unchanged bands, merge bands | Mode 2 bands are redrawn every frame | Small-medium |
| Z80 core hot opcodes (from the profile) | Depends on the profile | Varies |

## Order

1. Run the measurements on the 060 config: MSX2 and MSX2+, sub-timers, profile, tile counters. About half a day of WinUAE time; can run overnight.
2. V9958 horizontal scroll support. Needed for MSX2+ correctness anyway, and probably the biggest single speed win for this game on 2+.
3. Then the top hotspot from the profile.
