# SCREEN 7/8 planar VRAM mapping: design (4.3 / 4.4 decision, 24 Oct 2026)

## The hardware
In G6 and G7 (SCREEN 7 and 8) the V9938 interleaves its two 64 KB banks: logical address A
(what the CPU and the command engine use) is physical (A >> 1) | (A & 1) << 16, so even bytes
are in bank 0 and odd bytes in bank 1. All other modes use logical = physical. A game that
writes in one kind of mode and shows or reads in the other sees the bytes permuted. The
reference emulator does this; AmiMSX stores VRAM linearly in every mode.

## Who needs it
Manbow 2's title (branch agents412/manbow2, notes Docs/agent_notes/manbow2.md): START is drawn
by HMMM in SCREEN 5 into page 2, then the title runs a SCREEN 8 over SCREEN 5 pair split and
three SCREEN 8 HMMMs move the logo. With linear storage the SCREEN 8 writes land on SCREEN 5's
page 2 (START is overwritten) and SCREEN 5 page 1's UI shows as SCREEN 8 rows 236-255 (the
magenta boxes over the logo, the stray line at the top left). A game that stays in SCREEN 7/8
(or never crosses) is unaffected, which is why this has not shown elsewhere.
Also on that branch, not merged: the ModoGfx6/8 flush of SCREEN 5/7 command bands to VRAM
(DirModoChg, commented out since 3.1; smoke 14/15 identical). It is correct on its own and is
the first layer of this fix.

## Approach: store VRAM physically, map in G6/G7 only
DIRVRAM becomes physical. Modes 0-6 are unchanged (logical = physical). In SCREEN 7/8 every
access by logical address goes through the map. Paths (AmiMSX_Main_v3.1.asm unless noted):

1. **CPU port 98h** in/out: SCREEN 7 shares IN98A/OUT98A/OUT98AT/VRAM98A with SCREEN 5, so it
   gets its own copies; SCREEN 8: IN98B/OUT98B/VRAM98B. The VRAM pointer (A2)+ becomes a
   logical counter with the physical address computed per byte (even: bank 0 + A/2, odd:
   bank 1 + A/2): a few instructions per byte. The TAB98B dirty-block marks use the physical
   block.
2. **VRAM to planes** on entering G6/G7 and in the pair split: PasaPun8Bpl, COPYVDP8, COPIA8,
   BMSConv8 (SCREEN 8); V5All/PlSet with MODO7DATS and BMSConv5 when the top is SCREEN 7. Rows
   read two sources, even bytes from bank 0 and odd bytes from bank 1.
3. **Planes to VRAM** when SCREEN 7 is left (ModoChg5a0 with SCREEN 7's layout) and in the
   commit of command bands (Pl5Band): write through the map.
4. **VDP commands in G6/G7** (VDP2Escr8 for SCREEN 8; the SCREEN 7 command paths that touch
   VRAM; POINT/LMCM via POINTA/POINTB; SRCH): map each VRAM byte.
5. **Sprites in G6/G7**: the attribute, colour and pattern tables are at logical addresses:
   TRANSSPR8/16(M), BITSPRCOL, SCSat1 (collisions), SpSl*, SNAPSPR, IMPSPR2's table reads. Map
   the table reads (a table of 32 attributes, 16 bytes of colours per sprite, 8/32 bytes
   of pattern: cheap).
6. **Debug and dumps** (StDR, U2TRAP, BANDSHOT, trace VRAM dumps): dump physical, decode in
   the Python readers (tools/read_trace.py, render_scr5.py) when the mode is G6/G7.
7. **Mode switches** need no data movement (storage is physical), which is the point: the pair
   split can render both halves from the same VRAM every frame.

## Cost and risk
- Speed: one extra address step per CPU VRAM byte in SCREEN 7/8 and a two-source inner loop
  in the conversions; SCREEN 8 games (Uridium 2, Gradius III MSX2+ parts) to be re-measured.
- Risk: every SCREEN 7/8 path changes; a missed path shows as permuted bytes. Mitigation: a
  test cartridge (as tools/make_keytest.py) that writes known bytes in SCREEN 5, reads them
  back in SCREEN 8 and SCREEN 7 (and the reverse), draws with each command in each mode and
  logs the reads, compared with the reference emulator byte for byte; plus the full
  regression and Manbow 2 / Uridium 2 / Gradius III bursts.
- Size: about 25 routines; likely a full working day of focused work including the test
  cartridge and regression, more if the sprite paths hide surprises.

## Recommendation
Do it as one branch in this order: (1) merge the manbow2 flush; (2) the test cartridge and
its reference log; (3) port 98h and sprites (they decide whether a game runs); (4) conversions
and commands; (5) dumps. Ship it in 4.3 only if the full regression is clean; otherwise 4.4
(the roadmap's fallback).
