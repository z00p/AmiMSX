# AmiMSX 4.x roadmap

What is planned after 4.1.2. Details of each problem are in `open_issues.md`; finished work moves to `CHANGES_4.x.md`. From 4.2 the releases are no longer marked beta.

## 4.2

- **Gradius III Legends power-meter boxes:** VDP LINE honours the logical operation (XOR erase). Done on the 4.2 branch.
- **Edge mask:** Auto mask removed; Mask screen edges is Off / 8 / 16 dots, kept per game; the MSX2+ R#25 left mask is always applied. Done on the 4.2 branch.
- **Uridium 2:** enemy ships don't collide with the player's ship. The game's own hit test misses; a trace build comes next. A general sprite-collision fix (lines with sprites on) waits on a branch for this.
- **Jailbreak:** a 2-line strip flickers near the bottom. The drafted double-buffered copper list (`COPLINEDB`) was tested and does not fix it; the new lead is a palette change the game makes at the last display line (line 211).
- **Keyboard mapping regression test.**
- ~~Regression captures in exact colours (GDI output)~~: tried 21 Oct and reverted. With GDI many captures came out black or half drawn; the regression stays on Direct3D, and the GDI config is for one-off colour checks.
- **Bombaman:** ghosting on fast machines.
- **Lotus F3:** car jitter on PiStorm.
- **Manbow 2 title screen:** SCREEN 7/8 planar VRAM mapping (the V9938 interleaves the two 64 KB banks in G6/G7), plus the SCREEN 5/7 command flush when SCREEN 5 is left. Moves to 4.3 if it runs long.

## 4.3

- **MSX2+ YJK modes** (SCREEN 10-12).
- **Per-game defaults** from a game index (mapper, machine, options), for ROMs and disks.
- **Cartridge SRAM** (battery-backed save memory) for the ASCII8/ASCII16 SRAM mappers and similar, saved to a file next to the cartridge. Games such as Lilly's Saga need it for their save menu; today AmiMSX's ASCII mappers switch ROM banks only.

## Still open, not yet scheduled

Head over Heels Remake menu letters, Shoulder Blade OVERDRIVE title logo, Nemesis 2 cyan stars and a missing ship frame, the rare black screen on the first Power ON after a cartridge change, sprite mode 2 edge cases, and the picture size of some MSX2 games on the MSX2+ machine (the game's own choice of video mode).

## Later

- Speed work on the native AGA display.
- An optional RTG (Picasso96/CyberGraphX) display, shared with other Amiga emulators.
- Sound: the FM engine and output options (Paula 8/14-bit, 16-bit AHI).
