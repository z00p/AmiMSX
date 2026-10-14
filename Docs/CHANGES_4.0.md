# AmiMSX 4.0: changes since 3.1 (draft)

Draft for the release notes and the Aminet readme. Nothing is published until the author agrees (see `release_4.0.md`).

AmiMSX 4.0 is based on the AmiMSX 3.1 source by Juan Antonio Gómez Gálvez (RED Soft). The aim of this version is accuracy first: a fast 68030 or 68040 is the baseline, and PiStorm (Emu68) systems have speed to spare.

## Emulation

### Z80

- **POP and RET** from tables in ROM read the right bytes across 256-byte page boundaries. Barbarian's fighters were corrupted.
- **RLD and RRD** on ROM read the ROM byte (the write is ignored, as on a Z80). Ianna unpacks its hero's graphics this way; every second pixel came out transparent, so the hero was drawn in stripes.
- **Flags:** NEG and CPL set the flags as a real Z80.
- **LD A,R** comes from emulated time, not the Amiga beam, so runs repeat exactly.
- **Timing:** M1 wait states are counted, and a line is the real 228 cycles.
- **D1 register:** scanline handlers no longer leak D1's high word (Barbarian's mode-2 hang).

### VDP

- **Sprite collisions:** S#0 bit 5 is emulated (as openMSX's sprite checker). It is checked once a frame at the first S#0 read. The old menu option "Sprites collisions ON (always)", which reported a collision on every S#0 read (from before collisions were emulated), is gone: with real detection it only broke games, and a prefs file that has it set is ignored. L'Abbaye des Morts' soldiers no longer stick in the scenery.
- **5th sprite flag:** S#0 5S and the sprite number are emulated. Uridium's HUD split depends on it.
- **Mid-frame splits:**
  - sprite attribute snapshots;
  - SCREEN 4 table splits (Lilly's Saga);
  - SCREEN 5/4 mode splits;
  - mid-frame palette changes;
  - register splits: when R#8, R#18 or R#23 change during the display, the largest region's values are used. Uridium 2's HUD no longer hides the sprites, and Nemesis 3's enemies show. A table split ends a region too (Space Manbow, Zanac EX);
  - display off and on during the frame (R#1 BL): those lines show the border colour. Lilly's Saga no longer shows a stray line above its HUD;
  - table splits in 212-line mode render to the last line (Space Manbow's ground).
- **Speed in split-screen games:**
  - a SCREEN 4 table split now redraws only the longs that changed (Space Manbow in play: 68060 61% to 86-90% of real speed, 68030 56% to 71-81%);
  - leaving SCREEN 5 or 7 converts only the 16-line bands that VDP commands drew in since the last switch, not the whole bitmap.
  - the conversions between VRAM and the SCREEN 5/7 bitplanes use lookup tables (4 lookups per 8 pixels instead of 32 bit shifts). Space Manbow's pauses when it switches between SCREEN 4 and 5 are about a third to a half shorter (A1200: 29-38 refreshes over the switch down to 18-27).
- **Sprite mode 2:**
  - sprites are drawn in bands, each with its own R#23 (vertical scroll). Bands with sprites off (R#8 SPD) draw nothing, so Space Manbow's ship no longer lands on the ground row;
  - a new band starts at the line after a sprite register changes. Zanac EX's enemies no longer vanish near its status bar;
  - the EC bit.
  - with sprites every frame, the sprite overlay (Amiga hardware sprites) alternates between two buffers: each frame's sprites are drawn into the one not on screen and shown from the next frame, with that frame's playfield. One buffer, cleared and redrawn while on screen, tore and jittered on fast machines (Space Manbow's ship on BigMig), and a horizontal adjust (R#18) change moved the sprites a frame early;
  - in SCREEN 4 the sprites are drawn before the tiles, and a sprite buffer ready in the top vertical blank is shown in that same frame (the hardware pointers are set as well as the copper's), so sprites and playfield change together. On BigMig the tile pass ends well into the next frame, and the main character of a scrolling game (Lilly's Saga, Bomberman) jittered against the scenery;
  - Power ON and Reset empty the sprite overlay. The last game's sprites used to stay on screen in the next one.
- **Line interrupts:** with IE1 off, the line-interrupt flag (S#1 FH) is set for the matching line only, as openMSX does. Fixes Zanac EX's title. VR is set in the VBlank lines.
- **Mid-frame palettes:** MSX colour 0 with TP off shows the border colour on lines with palette changes, as it does elsewhere.
- **SCREEN 2 and 4:** the R#3 and R#4 table masks apply per screen block.
- **VDP commands:**
  - transparent copies (LMMM with TIMP, TAND, TOR, TXOR and TNOT) work;
  - LMMC no longer corrupts R#4.

### Cartridges

- **ROM sizes:** 48 KB and 64 KB linear ROMs (no mapper) are supported, and so are 4 MB ROMs.
- **Mapper handling:**
  - the mapper is guessed as openMSX does;
  - banks wrap at the ROM's size;
  - KonamiSCC bank registers are decoded as on the cartridge.
- **8 KB ROMs** (12 Oct) load as one 16 KB page, the 8 KB mirrored (Sink King, Nohzdyve, Kralizec 8K Tetris, Battle Tetris).
- **ROM database** (12 Oct): `AmiMSX4.romdb` gives the mapper by SHA-1 for 3,180 MegaROMs (from openMSX's software database, plus local extras). The order is: a saved mapper, then the database, then the file-name tag, then the guess. Each ROM is hashed once; the answer is cached in `AmiMSX4.romcache`. Uwol (ASCII8, guessed as Konami before) now plays.
- **Flash Konami SCC cartridges** (12 Oct): 7FFFh bit 4 enables AMD flash commands (program, 64 KB sector erase) on ROMs over 512 KB. Pampas & Selene now plays, and its saves are kept: the changed sectors go to `<cartridge>.flash` next to the ROM when you return to the menu, and are read back when the cartridge is inserted. The ROM file itself is never changed.

### Disks

- **Disk images** are read completely. A short read used to leave the MSX booting a partly empty disk (some disk demos failed at random); a file that can't be read in full is now an error.
- **Drive B virtual disk** (12 Oct): drive B can hold a disk image of its own (before, a virtual drive B shared drive A's image). Load it from the menu (MSX Virtual Drive > Load Disk File into drive B) or from the CLI (`AmiMSX <disk> B=<image>`). Plain 360/720 KB images. What a game writes to drive B's disk is written back to its image file when you return to the menu, as a real disk keeps it (drive A keeps the MVD quit requester).
- **Disk swap** (12 Oct): Left Amiga swaps the disks in drives A and B during play, and the power LED blinks. For "insert disk 2" prompts and two-disk games.

## Options

- **MSX2+ off for now** (12 Oct): the menu offers MSX and MSX2 only, and an MSX2+ setting (old prefs, key scripts) runs as MSX2. AmiMSX reported a V9958 for MSX2+ but emulated none of it (R#25-27 scroll and mask, YJK modes), so games took their MSX2+ code path and half-worked. Builds with `-DMSX2PLUS=1` keep it, for development.

- **Per-game settings** (Cartridges > Slot 1 > Save game settings / Forget game settings): the sound chip, sprite refresh and the edge mask, saved next to the cartridge as `<cartridge>.prefs` and applied whenever that cartridge is inserted (menu or command line). A cartridge without one brings the global settings back, with the SCC sound chip for a Konami SCC cartridge (mapper SCC 1/2) when the global setting is PSG; Save Prefs always writes the global settings.
- **Mask screen edges** (menu: "Mask screen edges (always)" and "Auto mask (scrolling games)"): hides 7 dots at each side of the picture (8 until 14 Oct 2026), where games that scroll sideways in software redraw columns; a TV's overscan hid them on a real MSX. Auto, the default, masks once a game changes R#18 three or more times within a second, and keeps the mask until Power ON or Reset; other games keep the full picture. Both are stored in the prefs and in the per-game settings, so a game can be forced on or off.
- **Smooth display** (menu, after Audio filter; on in the PiStorm preset): SCREEN 4 is double-buffered. Each frame is drawn off screen (tiles, HUD and mode-split strips, plane pointers, R#18/R#23, palette and sprite pointers) and shown complete at a frame start. On a fast Amiga the render still takes longer than the vertical blank (BigMig: 120-140 lines), so before, the tiles changed during the frame while the scroll registers and sprites changed at the next one, and the scenery jumped against the hero in scrolling games (Lilly's Saga, Space Manbow). It needs about 90 KB more chip RAM and some blitter time to keep the hidden buffer up to date, so it is off in the A1200 and 030 presets, whose display path is unchanged. Other screen modes run as before for now.
- **Audio filter** (menu, after Mask screen edges): keeps the Amiga's low-pass filter (the power LED bit) on while a game runs, which takes the hiss out of the 8-bit FM and PSG output. AmiMSX used the LED as a disk light and turned the filter off; with the option on, the LED just stays lit. On in the PiStorm preset (it has FM), off in the others; also saved per game.

- **Use Japanese ID (60 Hz)** (menu): the BIOS reports a Japanese machine and starts at 60 Hz, the machines most games were written for; with Frequence "From VDP" the display follows. Off: an international machine at 50 Hz. It applies to all three machines; in v3.1 it changed only the ID bytes and kept 50 Hz.

## From Juan's v3.2/v3.5 source (October 2026)

Juan sent his latest source (AmiMSX v3.2, with a v3.5 GUI from 2021). It has no emulation changes; these parts of it are in 4.0:

- **Freeware:** Project > Register does nothing, and About's "More" button (the old postal and web addresses) is disabled. The screen title reads "1994-2000/2009/2021 © GUS Entertainment", and the About box thanks Zener and Sandman, as in his v3.5.
- **No anti-crack counter:** v3.1 counted joystick polls and, with prefs byte $7F at $20 or more, silently turned the Z80's CALL nn into JP nn. Removed, as in v3.2.
- **Closing files:** no Close() call when no file is open.

## Defaults

- **Sprites every frame**, as on an MSX (the setting is still in the menu; the A1200 preset uses every 2nd frame).
- **The Matra splash** is off (build with `-DSPLASH=1` to show it).

## System ROMs

- **C-BIOS:** 4.0 ships with C-BIOS 0.29 as its `AmiMSX2.data`, a free BIOS (BSD-style licence) that runs cartridges.
- **Disks and BASIC:** C-BIOS has neither, so they need the original `AmiMSX2.data` from the AmiMSX 3.2 package on Aminet (`misc/emu/AmiMSX`).

## Workbench

- **Presets:** three project icons, AmiMSX A1200, AmiMSX 030 and AmiMSX PiStorm, each with its own settings file. The PiStorm preset follows the game's display frequency ("From VDP": 60 Hz games at NTSC, full speed) and has the audio filter on; the A1200 and 030 presets stay PAL, without FM, to keep their speed.
- **ToolType `PREFS=<file>`:** chooses the settings file. A relative name is taken from the icon's drawer. Save Prefs writes to the same file.

## Building and testing

- **Assembler:** vasm 2.0f replaces Devpac III. `build.sh` refuses branches to `*+n`, after one crashed builds once the code moved.
- **Test hooks:**
  - `AmiMSX <cartridge> [keyscript]` inserts a cartridge in Slot 1 and powers on;
  - `AmiMSX <cartridge> MENU` inserts it and stays in the menu (settings, then Power ON); the Slot 1 label shows the file's name;
  - `P=<prefs file>` as the second or third argument loads (and saves) that prefs file, as an icon's PREFS ToolType does;
  - the key script drives the MSX keyboard and can freeze exact frames for capture (SNAP), or copy the MSX state at a frame without freezing (DUMP, `STATEDUMP` builds).
- **Debug builds:**
  - `TRACE` (instruction ring), `TRACELITE` (event ring only);
  - `PERF` (frame timing and profile; `PERFLOCAL` writes perf.bin to the current directory, for the Measure scripts);
  - `BANDCHK` (logs VDP commands and checks the SCREEN 5/7 band conversion);
  - `CORRCHK`, `HANGCHK` and `EXCCHK` (fault finding).
- **Regression:** a tiered suite in WinUAE (smoke, feature, full), with captures compared pixel by pixel against accepted baselines.
- **Cross-checks with openMSX:** consecutive-frame bursts from both emulators (`tools/burst.py`), VDP register and palette logs, palette probes, and an overnight batch (`tools/overnight.py`).
- **Tester:** `winuae/AmiMSX-Tester.ps1`, a Windows launcher for playing in WinUAE (68030 or PiStorm-like speed) with one-click issue reports.
