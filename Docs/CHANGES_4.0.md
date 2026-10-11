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
- **Sprite mode 2:**
  - sprites are drawn in bands, each with its own R#23 (vertical scroll). Bands with sprites off (R#8 SPD) draw nothing, so Space Manbow's ship no longer lands on the ground row;
  - a new band starts at the line after a sprite register changes. Zanac EX's enemies no longer vanish near its status bar;
  - the EC bit.
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

### Disks

- **Disk images** are read completely. A short read used to leave the MSX booting a partly empty disk (some disk demos failed at random); a file that can't be read in full is now an error.

## Options

- **Per-game settings** (Cartridges > Slot 1 > Save game settings / Forget game settings): the sound chip, sprite refresh and the edge mask, saved next to the cartridge as `<cartridge>.prefs` and applied whenever that cartridge is inserted (menu or command line). A cartridge without one brings the global settings back; Save Prefs always writes the global settings.
- **Mask screen edges** (menu, after "VDP 'TR bit' always ready"): hides 8 dots at each side of the picture, where scrolling games redraw columns (Lilly's Saga). Off by default; it is stored in a block appended to the prefs file, so older prefs files load with it off.

## Defaults

- **Sprites every frame**, as on an MSX (the setting is still in the menu; the A1200 preset uses every 2nd frame).
- **The Matra splash** is off (build with `-DSPLASH=1` to show it).

## System ROMs

- **C-BIOS:** 4.0 ships with C-BIOS 0.29 as its `AmiMSX2.data`, a free BIOS (BSD-style licence) that runs cartridges.
- **Disks and BASIC:** C-BIOS has neither, so they need the original `AmiMSX2.data` from the AmiMSX 3.2 package on Aminet (`misc/emu/AmiMSX`).

## Workbench

- **Presets:** three project icons, AmiMSX A1200, AmiMSX 030 and AmiMSX PiStorm, each with its own settings file.
- **ToolType `PREFS=<file>`:** chooses the settings file. A relative name is taken from the icon's drawer. Save Prefs writes to the same file.

## Building and testing

- **Assembler:** vasm 2.0f replaces Devpac III. `build.sh` refuses branches to `*+n`, after one crashed builds once the code moved.
- **Test hooks:**
  - `AmiMSX <cartridge> [keyscript]` inserts a cartridge in Slot 1 and powers on;
  - `AmiMSX <cartridge> MENU` inserts it and stays in the menu (settings, then Power ON); the Slot 1 label shows the file's name;
  - the key script drives the MSX keyboard and can freeze exact frames for capture.
- **Debug builds:**
  - `TRACE` (instruction ring), `TRACELITE` (event ring only);
  - `PERF` (frame timing and profile);
  - `CORRCHK`, `HANGCHK` and `EXCCHK` (fault finding).
- **Regression:** a tiered suite in WinUAE (smoke, feature, full), with captures compared pixel by pixel against accepted baselines.
- **Cross-checks with openMSX:** consecutive-frame bursts from both emulators (`tools/burst.py`), VDP register and palette logs, palette probes, and an overnight batch (`tools/overnight.py`).
- **Tester:** `winuae/AmiMSX-Tester.ps1`, a Windows launcher for playing in WinUAE (68030 or PiStorm-like speed) with one-click issue reports.
