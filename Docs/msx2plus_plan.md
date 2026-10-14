# MSX2+ (V9958) plan

Research of 14 Oct 2026: which games use V9958 features, measured in openMSX on an MSX2+ (the AmiMSX2.data MSX2+ ROMs, Sanyo PHC-70FD set, and C-BIOS MSX2+), and how AmiMSX can show them.

## What games use

- **Test set (82 titles, 60 s each with their key scripts):**
  - Space Manbow: R#25 MSK and R#27 fine scroll (2-dot steps), changed at display lines 24-31, below the score panel.
  - Nemesis 3 Enh: MSK and R#27, reset at lines 168-176 (bottom panel still).
  - Salamander Enh: the same as Nemesis 3 Enh, but in SCREEN 2.
  - Chikubi Ninja: MSK and R#27, cleared at lines 160-161.
  - The other 78 use nothing from the V9958.
- **Share collection (277 cartridges: enhanced, msx2, Top 30 Modern/Classics; 45 s each):**
  - Space Manbow (three copies): MSK and scroll.
  - grad2tr (patched Gradius 2): MSK, SP2 (512-dot two-page scroll), and scroll in half its frames.
  - salamall (Salamander): SP2.
  - Pro Yakyuu Family Stadium - Pennant Race: WTE, MSK, and scroll throughout.
- **Nothing found uses:** the YJK modes (SCREEN 10-12), the CMD bit, or turbo. The ROM set has no turbo (PHC-70FD).
- **No speed gain for Space Manbow:** its MSX2+ path writes as much VRAM as the MSX2 path (750 KB in 30 s on both). MSX2+ makes it smoother (2-dot steps), not faster.

## Today

- **R#25-27:** ignored. VDPPUNT entries $19-$1B point to ARET.
- **S#1:** the V9958 ID is already reported when the machine is MSX2+ (DVDPS1).
- **MSX2+ machine setting:** clamped to MSX2 unless built with -DMSX2PLUS=1 (CLAMPM).
- **ID patch:** skipped for the MSX2+ BIOS, so it boots as a Japanese 60 Hz machine.

## Phases

1. **R#27 fine scroll and R#25 MSK, per line:**
   - New register handlers modelled on VDP12 (R#18). They set TabRasCMDS bit 1 and store into TabRasDATA, and AcCoRutAdjust emits BPLCON1 and DIWSTRT (+8 for MSK). R#27 does not move sprites.
   - Installed only on the MSX2+ machine, so MSX2 games are unchanged.
   - SCREEN 2 gets the CopperLine jump that modes 4-8 have (Salamander).
   - The MSX2+ setting is back in the menu, with the same ID patch as the MSX1/MSX2: international ID and 50 Hz, or Japanese ID and 60 Hz with "Use Japanese ID (60 Hz)".
   - The right edge shows over-fetch garbage until phase 2, so mask the right 8 dots while MSK is on. "Mask screen edges" already covers it.
   - Covers Space Manbow, Nemesis 3 Enh, Salamander Enh, Chikubi Ninja and Pro Yakyuu. CPU cost: a few copper words.
2. **True wrap, R#26 coarse scroll and SP2:**
   - SCREEN 4 plane rows go from 32 to 40 bytes, with bytes 32-39 a copy of columns 0-7. Every 32*4 constant changes, including Dbuf, HUDSplit4 and MSplitFill.
   - SP2 needs the second page alongside.
   - For grad2tr (Gradius 2), and completeness.
3. **Only if a game needs it:**
   - YJK SCREEN 10-12, on the PiStorm preset: a table lookup on top of the SCREEN 8 path.
   - CMD-bit commands in tile modes.

## Testing

- **openMSX reference:** machine AmiMSX_MSX2P_Disk (local, git-ignored). tools/burst.py and regress.py need a --machine option.
- **Space Manbow:** 2-dot x steps (tools/motion.py), lines 0-30 still.
- **Nemesis 3 Enh, Salamander Enh, Chikubi Ninja:** the bottom panel stays still.
- **MSX2 regression suite:** unchanged.
- **Scans:** build/msx2plus_fable/scan2p.py (test set) and build/msx2plus_scan/scan.py (share folders).
