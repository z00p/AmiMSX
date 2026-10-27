# AmiMSX 4.x: changes since 3.1

AmiMSX 4.x is a community update of AmiMSX by Juan Antonio Gómez Gálvez (GUS Entertainment / RED Soft), made with his permission. It is built from his v3.1 source, with parts of his later v3.2/v3.5 source. The aim of this version is accuracy first. The low-spec target is a 68030 at 50 MHz with fast RAM; PiStorm (Emu68), BigMig and other fast CPUs have speed to spare and get the costlier features (FM sound, 60 Hz, smooth display).

Please report problems as issues at https://github.com/z00p/AmiMSX/issues.

## 4.4 (27 Oct 2026)

- **Per-game machine:** an MSX2, MSX2+ or turbo R game without its own settings file starts on that machine (turbo R games on the MSX2+). ROMs are recognised by the ROM database (openMSX's software database, by SHA-1), disks by a new disk database (`AmiMSX4.diskdb`, by a quick sum of the image). File Hunter's MSXdev and homebrew games are in both databases, as MSX2 at most (File Hunter's machine is the player's choice, not a requirement). A game's own settings file now keeps the machine too. FM sound and the Japanese ID stay with the presets.
- **Cartridge SRAM:** the battery-backed save memory of the ASCII8 and ASCII16 SRAM cartridges (36 in the ROM database: Hydlide 2, A-Train, Xanadu, Deep Dungeon, Daisenryaku...), kept in `<cartridge>.sram` next to the ROM. The file is the raw 2 or 8 KB, the same as openMSX's, so a save can move between the two. Koei's SRAM cartridges are not done yet. (Lilly's Saga isn't one of them: the free MSXdev version has no saves; they are in the boxed edition.)
- **VDP commands:** SRCH is implemented (MSX-BASIC's PAINT in SCREEN 5 and up uses it), with S#2's BD bit and S#8/S#9. HMMV in SCREEN 5/6/7 keeps each dot's colour of the byte instead of filling with the low nibble (Pampas & Selene's health bars now match openMSX). SCREEN 8 PSET, LINE, YMMM, HMMC and LMMC write video memory; they used to draw on the screen only, and the next conversion undid them. The SCREEN 7/8 memory test (`tools/maptest.sh`) covers them all and matches openMSX byte for byte.
- **Speed:** SCREEN 8 on a 68030/50 is back to its speed before 4.3's memory layout (Uridium 2: about 74% of MSX speed in WinUAE's cycle-exact 030; 4.3 about 68%). VDP command copies work out their addresses once per row and copy by longs, and the sprite tables are copied only where a command changed them.
- **68040/060 (PiStorm, BigMig):** SCREEN 2 and 4 tiles are drawn by the CPU from a character cache in fast RAM, instead of one blit per pair of tiles with a wait for each. Lotus F3's road no longer judders on the PiStorm: every 4th frame, when the game shifts the whole name table, used to finish late. 68030 machines keep the blitter; the pictures are identical.
- **Bombaman:** the sprite ghosting on fast machines is gone (checked on an A1200 PiStorm and BigMig).
- **Tests:** a cartridge SRAM test (`tools/sramtest.sh`), and a frame-timing log in PERF builds for tests on real machines (`tools/read_hw.py`).

## 4.3 (26 Oct 2026)

- **SCREEN 7/8 video memory** is now stored as on the V9938, which interleaves its two 64 KB banks in SCREEN 7 and 8 (logical A at physical (A >> 1) | (A & 1) << 16). Data written in one kind of mode now reads back right in the other. Manbow 2's title screen draws in SCREEN 5 and shows a SCREEN 8 picture above it: the boxes over its logo and the stray line at the top left are gone.
- **Sprites in part of a split screen:** sprites switched on only below a split are shown (Manbow 2's "START" and its arrow). The overlay used to follow the sprite setting of the frame's larger part.
- **VDP command timing:** a command keeps S#2's CE (busy) bit set as long as on a V9938 (openMSX's per-access costs, slower inside the display window); the drawing itself is still done at once. Games that wait for a command now wait the real time: Jailbreak's HUD palette is restored in the border again, not on the last display line (the strip at the bottom of the playfield).
- **VDP commands:** the XOR, AND and NOT logical operations (and their T forms) draw right in the bitplane modes; Head over Heels Remake's menu letters are complete. SCREEN 8: LMMV applies its logical operation, HMMM/LMMM/HMMV/LMMV follow DIX/DIY, and POINT/LMCM read VRAM. SCREEN 5/7 command results reach VRAM before SCREEN 6/8 reuse the planes, and leaving SCREEN 7 writes back the right lines.
- **Z80 timing:** DAA takes 5 cycles (was 1), and a DD/FD prefix before a plain LD r,r' 10 (was 6). Checked against the Z80+M1 column of the timing table at map.grauw.nl: 957 of 959 instructions match (CPIR/CPDR still charge a flat 18 for the whole search).
- **Sprite collisions** (S#0 bit 5) are checked over the lines where sprites are on, not by R#8 at the moment the game reads S#0.
- **Tests:** a keyboard mapping test (`tools/keytest.sh`: every Amiga key through AmiMSX's table, read back by a cartridge), a Z80 timing test (`tools/make_z80time.py`) and a SCREEN 7/8 memory test (`tools/maptest.sh`, compared with openMSX byte for byte).
- **Speed:** SCREEN 8 games that switch modes every frame run a little slower on a 68030/50 (Uridium 2: about 67% of MSX speed in WinUAE's cycle-exact 030, was about 74%).

## 4.2 (21 Oct 2026)

- **Mask screen edges** (Options > Internal Emulation) is now a choice of **Off, 8 dots or 16 dots** at each side of the picture (default Off), kept in the prefs and in the per-game settings. A prefs or per-game file from 4.0/4.1 with the mask on reads as 8 dots. The edges are measured on the 256-dot picture (the display window is the picture's width; 4.0-4.1's "7 dots" really hid 10 at the left and 12 at the right).
- **Auto mask (scrolling games) is gone:** AmiMSX no longer masks the edges by itself when a game scrolls with R#18. It cut off the "1UP"/"2UP" score panel of Uridium 2, which openMSX and a real MSX show in full.
- **MSX2+ left mask (V9958 R#25 MSK)** is always shown on the MSX2+ machine, whatever the mask option says (with 8 or 16 dots the option's mask covers it).
- **Options menu:** the Audio filter and Smooth display items no longer run the PAL/NTSC screen handlers when picked (their menu handler entries were missing).
- **Quitting after a 60 Hz game:** Screen on Exit 'No Change' (the default) now puts the Amiga's own beam timing back (PAL on a PAL machine, from ExecBase's VBlankFrequency) and rebuilds the display. A 60 Hz MSX game sets BEAMCON0 to NTSC, AmigaOS does not restore it, and PAL screens opened afterwards ran at 59.3 Hz and lost their bottom lines (seen in other emulators started after AmiMSX).

## 4.1.2 beta (21 Oct 2026)

- **Z80 interrupts:** a pending interrupt is taken straight after the instruction that follows EI, as on a Z80; it used to wait for the end of the line, so a VBlank interrupt could split a pair of port 99h writes. Uridium 2's SCREEN 8 title picture is drawn right. Line interrupts are checked before VBlank there too.
- **Sprites:** magnified sprites (R#1 MAG) in sprite mode 1: Bit Logic's hero on the intro screen (two 16x16 magnified sprites, drawn unmagnified and so split), Popolon.
- **SCREEN 2/4 tiles:** a tile whose pattern or colour changed is redrawn in the same pass (after the cache update), not by the next frame's pass. The deferred mark (the inverted name in the name shadow) was lost when the game changed the name to its inverse meanwhile: Gradius 2 with the MSX2+ enhancement patch twinkles its star tiles ($FF) while moving them by names, and every star erased to $00 stayed on screen as a dot, in a grid at the tile period. A pattern or colour change now shows in its own frame too.
- **MSX2+ (SCREEN 5):** a game that never writes the V9958 R#26 coarse scroll is displayed exactly as on the MSX2 machine (the same plane layout, 64-bit fetch, modulo and window), so the display window matches the MSX2 machine (Pampas & Selene still looks different on an MSX2+: the game picks another video mode there). The wide layout and the 32-bit fetch are taken only once R#26 is written with a non-zero value (Gradius III Legends), and in a pair-split regime as before.
- **MSX2+ coarse scroll (SCREEN 5, 32-bit fetch):** the bitplane fetch starts at DDFSTRT $38, aligned to the 32-dot fetch unit, and the R#26/R#27 delay is computed as 0..31 for every layout. At DDFSTRT $40 AGA applies the BPLCON1 delay modulo 32 from the middle of a unit, so about half of every 32-dot scroll step showed the picture 32 dots to the right: the row's wrap copy appeared as a column at the left edge and the scroll jumped (Gradius III Legends; also in 4.1 and 4.1.1).
- **Screen pages (SCREEN 5-8):** a page switch (R#2) the game makes in the border is shown from the top of the picture: the copper list already on screen gets the new page's line-0 bitplane pointers, plus a pointer change a few lines below the beam when the picture has started. The switch used to show one Amiga frame late while the game's restore of the hidden page (HMMM) already landed in the visible planes, so on fast machines Barbarian's fighters and the goblin vanished or looked see-through every other frame.
- **Colours:** MSX 3-bit colour levels map to Amiga levels 0, 3, 5, 7, 9, 11, 13, 15 (white is $FFF; it was $EEE, every level a step dark), within 8/255 of openMSX; the MSX1 palette and SCREEN 8's fixed palette follow. Earlier "too bright" reports (Barbarian's sky, Popolon's floor) came from WinUAE's Direct3D output in test captures, not from AmiMSX.

## 4.1.1

- **CD32 pads:** a menu option per joystick port (Options: JoyPort 2 (Joystick) Pad, JoyPort 1 (Mouse port) Pad: Standard (2 buttons) or CD32 pad). With CD32 pad the port is read with the CD32 protocol every frame, forced, no ID check: red = MSX trigger A, blue = trigger B, yellow = Space, green = M, play = F1; the shoulder buttons do nothing. Standard is the plain two-button read, untouched. No auto-detection (4.0's probe failed on real pads and adapters: KTRL CD32, a Mega Multi adapter in CD32 mode). Both ports are read in one pass (~300 us a frame when either is set). Saved with the prefs and in a game's own settings (the per-game file grows by two bytes; 4.0/4.1 files still load).

## 4.1.1 beta (19 Oct 2026)

- **CD32 pads:** a menu option per joystick port (Standard / CD32 pad), saved with the prefs and per game; the auto-detection is gone. A CD32 port is read every frame without an ID check (red = fire 1, blue = fire 2, yellow = Space, green = M, play = F1); a pad that shows all seven buttons pressed (a plain pad, or an adapter in its standard mode) counts as released. The read keeps its registers in memory, not on the stack (the frame interrupt runs on the Z80 core's A7).
- **MSX2+ (SCREEN 5 wide layouts):** sprite tables rebuilt from the planes after a VDP command were read one line off (Pampas & Selene's sprite walking left).

## 4.1 beta (18 Oct 2026)

- **MSX2+ coarse scroll:** R#26 and the two-page scroll (SP2) in SCREEN 5 (wide plane layouts, 32-bit fetch on the MSX2+ machine) and in the tile modes (the name table rotated per row). Gradius III Legends scrolls as on an MSX2+ (set ROM: MSX2+).
- **Bitmap-pair mode splits:** SCREEN 8 over SCREEN 5 and 5 over 8, each part with its own planes and palette (Manbow 2's title screen).
- **Display:** the frame's bitplane DMA follows the BL bit at the top of the display, so a game that blanks the bottom of the screen no longer blanks the whole frame. Dead beam-timed bitmap handlers removed.
- **Sprites:** with sprites every frame, an R#8 "sprites on" write no longer re-positions the overlay with a stale R#18 adjust (Manbow 2's ship jumping back).
- **Smooth display:** a frame that runs late is dropped instead of shown twice, so the music keeps its tempo.
- **Z80:** BIT, IN r,(C), RLD/RRD, CPI/CPD/CPIR/CPDR and DAA flags; RETI leaves IFF alone; IM 0 goes to 38h; OUT (C),0; undefined ED and DD/FD opcodes as NOPs; interrupt and EX (SP),HL timings.
- **MVD drives** are write-enabled by default.
- **CD32 pads:** auto-detection is off (it failed on real pads and adapters); CD32 support returns as a menu option in 4.1.1.

## Emulation

### Z80

- **POP and RET** from tables in ROM read the right bytes across 256-byte page boundaries. Barbarian's fighters were corrupted.
- **RLD and RRD** on ROM read the ROM byte (the write is ignored, as on a Z80). Ianna unpacks its hero's graphics this way; every second pixel came out transparent, so the hero was drawn in stripes.
- **Flags:** NEG and CPL set the flags as a real Z80.
- **LD A,R** comes from emulated time, not the Amiga beam, so runs repeat exactly.
- **Timing:** M1 wait states are counted, and a line is the real 228 cycles.
- **D1 register:** scanline handlers no longer leak D1's high word (Barbarian's mode-2 hang).
- **Core audit** (`Docs/z80_audit.md`, against openMSX 21.0): IM 0 now behaves as RST 38h (it jumped to the NMI vector); RETI no longer enables interrupts; BIT sets P/V and S; IN r,(C), RLD and RRD set P/V to the parity; CPI/CPD set S, CPIR/CPDR set P/V and count their cycles; DAA's S, Z and P/V come from the result; OUT (C),0 and the undocumented ED duplicates (NEG, RETN, IM) exist; undefined ED and DD/FD prefixes cost their cycles; EX (SP),HL, RLD/RRD, the IXH/IXL forms and interrupt acceptance cost the right cycles. H and N are still not modelled. `tools/make_zex.py` makes a self-checking ZEXALL-style test ROM.

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
  - table splits in 212-line mode render to the last line (Space Manbow's ground);
  - a table split on the line right after a mode split (the game's register writes straddled a line) moves to the mode split's line. Space Manbow at 60 Hz showed one garbage line at the edge of its HUD.
- **Speed in split-screen games:**
  - a SCREEN 4 table split now redraws only the longs that changed (Space Manbow in play: 68060 61% to 86-90% of real speed, 68030 56% to 71-81%);
  - leaving SCREEN 5 or 7 converts only the 16-line bands that VDP commands drew in since the last switch, not the whole bitmap;
  - the conversions between VRAM and the SCREEN 5/7 bitplanes use lookup tables (4 lookups per 8 pixels instead of 32 bit shifts). Space Manbow's pauses when it switches between SCREEN 4 and 5 are about a third to a half shorter.
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

### MSX2+ (V9958, phase 1)

- **The MSX2+ machine is back** in the ROM choices. Before, AmiMSX reported a V9958 for MSX2+ but emulated none of it, so games took their MSX2+ code path and half-worked.
- **R#27 fine horizontal scroll** (0-7 dots; sprites don't move) and **R#25 MSK** (the left 8 dots show the border colour) are emulated per display line. Space Manbow scrolls in 2-dot steps under a still score panel, as in openMSX; Nemesis 3 Enhanced, Chikubi Ninja and Pro Yakyuu Family Stadium use them too.
- **MSX2+ only:** both work on the MSX2+ machine alone. On MSX2 the registers are ignored as before, so MSX2 games are unchanged.
- **BIOS:** the MSX2+ BIOS gets the same ID patch as MSX and MSX2 (see Use Japanese ID).
- **R#26 coarse scroll and SP2:** the picture scrolls in 8-dot steps per display line on the MSX2+ machine, wrapping cleanly (Gradius III Legends: the scenery enters from the right), and SP2 (R#25 bit 0 with an odd page) shows the 512-dot two-page line (the Gradius 2 enhancement patch). SCREEN 5 keeps its planes in a wide layout for this (256 KB of chip RAM for the planes; VDP commands draw both copies); SCREEN 2 and 4 rotate the name table instead, so each coarse step redraws the tiles. Needs "Refresh 100% Graphics" (on by default). See `msx2plus_phase2.md`.
- **Not yet:** R#27's wrap at the right edge in the tile modes, R#26 in SCREEN 1/6/7/8, R#27 in SCREEN 2 (Salamander Enhanced) and the YJK modes (SCREEN 10-12). See `msx2plus_plan.md` and `msx2plus_phase2.md`.

### Sound

- **MSX-Music (FM):** the new sound chip "PSG+FM" emulates the YM2413 (FMX). Its 9 voices are built from per-instrument wavetables (the custom instrument is rebuilt on the 68k) and mixed into Paula channel 3; the PSG keeps channels 0-2. Games find MSX-Music through its signature in slot 0-2. The output matches a Python model, checked against openMSX, sample for sample. Cost in Lilly's Saga: about 6% of a frame on a 68060, 8% on a 68030.
- **FM lite:** a second choice that mixes only the 4 loudest voices (key-ons first). Lilly's Saga on the 030: 16 lines a frame instead of 24.
- **FM output:** Paula's AUD3 interrupt takes the next block from a ring of 8, which the emulation keeps two frames ahead. A late frame or two no longer runs the ring dry, and at 60 Hz (263-line frames) playback no longer drifts into the block being written. Both crackled.
- **Sample rate:** 15.6 kHz on a 68040/060, or with Smooth display on (fast CPUs that report a 68020/030); about 11 kHz otherwise.
- **PSG volume:** 3 dB a step, as the YM2149 (it was linear). Quiet notes, fades and echoes were far too loud (volume 7: -6.6 dB instead of -24 dB). The FM/PSG balance is within 1.4 dB of openMSX.
- **Audio filter:** see Options.

### Cartridges

- **ROM sizes:** 48 KB and 64 KB linear ROMs (no mapper) are supported, and so are 4 MB ROMs.
- **Mapper handling:**
  - the mapper is guessed as openMSX does;
  - banks wrap at the ROM's size;
  - KonamiSCC bank registers are decoded as on the cartridge.
- **8 KB ROMs** load as one 16 KB page, the 8 KB mirrored (Sink King, Nohzdyve, Kralizec 8K Tetris, Battle Tetris).
- **ROM database:** `AmiMSX4.romdb` gives the mapper by SHA-1 for 3,180 MegaROMs (from openMSX's software database, plus local extras). The order is: a saved mapper, then the database, then the file-name tag, then the guess. Each ROM is hashed once; the answer is cached in `AmiMSX4.romcache`. Uwol (ASCII8, guessed as Konami before) now plays.
- **Flash Konami SCC cartridges:** 7FFFh bit 4 enables AMD flash commands (program, 64 KB sector erase) on ROMs over 512 KB. Pampas & Selene now plays, and its saves are kept: the changed sectors go to `<cartridge>.flash` next to the ROM when you return to the menu, and are read back when the cartridge is inserted. The ROM file itself is never changed.

### Disks

- **Disk images** are read completely. A short read used to leave the MSX booting a partly empty disk (some disk demos failed at random); a file that can't be read in full is now an error.
- **Drive B virtual disk:** drive B can hold a disk image of its own (before, a virtual drive B shared drive A's image). Load it from the menu (MSX Virtual Drive > Load Disk File into drive B) or from the CLI (`AmiMSX <disk> B=<image>`). Plain 360/720 KB images. What a game writes to drive B's disk is written back to its image file when you return to the menu, as a real disk keeps it (drive A keeps the MVD quit requester).
- **Disk swap:** Left Amiga swaps the disks in drives A and B during play, and the power LED blinks. For "insert disk 2" prompts and two-disk games.

## Display

- **Sprite overlay double-buffered:** with sprites every frame, the overlay (Amiga hardware sprites) alternates between two buffers: each frame's sprites are drawn into the one not on screen and shown from the next frame, with that frame's playfield. One buffer, cleared and redrawn while on screen, tore and jittered on fast machines (Space Manbow's ship on BigMig), and a horizontal adjust (R#18) change moved the sprites a frame early.
- **SCREEN 4 sprites** are drawn before the tiles, so sprites and playfield change together. On BigMig the tile pass ends well into the next frame, and the main character of a scrolling game (Lilly's Saga, Bomberman) jittered against the scenery.
- **Torn sprites:** sprite pointers are not changed while the copper loads them (a column of the last pose or garbage on BigMig). With Smooth display on, the next sprite buffer is not drawn until the last switch has reached the screen (Lilly's Saga's hero was half drawn); the 030 skips that wait and keeps its speed.
- **Power ON and Reset** empty the sprite overlay. The last game's sprites used to stay on screen in the next one.
- **Palette changes** reach the screen at a frame start, through the copper, so a frame is never split between two palettes.
- **Blitter waits** read the busy flag once before the loop, as it may show a cycle late on fast CPUs. Lilly's Saga's transparent glyphs were drawn as solid blocks.
- **Smooth display** (see Options), with fixes for fast CPUs: It switches itself off in a game that plays MSX-Music (FM) until the next Power ON or Reset: a late frame costs a whole Amiga frame with it, and the music slowed (Lilly's Saga, Bombaman); without it a late frame is made up at once.
  - a frame that overruns keeps the last complete frame on screen (it showed a half-drawn one);
  - the copper list is never switched while the copper runs, and per-line lists are not rebuilt while on screen;
  - the first frame starts from a snapshot (Space Manbow's title logo showed over the first game frame on BigMig);
  - its state is cleared at Power ON and Reset, and a SCREEN 4 to 5 switch no longer shows one garbled frame.

## Options

- **ROM:** MSX, MSX2 and MSX2+ (see MSX2+ above).
- **Sound:** PSG, SCC, SCC+, PSG+FM and FM lite (see Sound above).
- **Per-game settings** (Cartridges > Slot 1 > Save game settings / Forget game settings): the sound chip, sprite refresh, the edge mask and the audio filter, saved next to the cartridge as `<cartridge>.prefs` and applied whenever that cartridge is inserted (menu or command line). A cartridge without one brings the global settings back, with the SCC sound chip for a Konami SCC cartridge (mapper SCC 1/2) when the global setting is PSG or PSG+FM. Ejecting the cartridge restores the global settings too. Save Prefs always writes the global settings.
- **Mask screen edges** (Options > Internal Emulation: "Mask screen edges (always)" and "Auto mask (scrolling games)"): hides 7 dots at each side of the picture, where games that scroll sideways in software redraw columns; a TV's overscan hid them on a real MSX. Auto, the default, masks once the playfield's R#18 changes from frame to frame three or more times within a second, and keeps the mask until Power ON or Reset; other games keep the full picture. A split that sets and restores R#18 within each frame (Galious Enhanced) is not a scroll and isn't masked. Both are stored in the prefs and in the per-game settings, so a game can be forced on or off.
- **Audio filter** (Options > Internal Emulation): keeps the Amiga's low-pass filter (the power LED bit) on while a game runs, which takes the hiss out of the 8-bit FM and PSG output. AmiMSX used the LED as a disk light and turned the filter off; with the option on, the LED just stays lit. On in the PiStorm preset; also saved per game.
- **Smooth display** (Options > Internal Emulation, "Smooth display (fast CPUs)"; on in the PiStorm preset): SCREEN 4 is double-buffered. Each frame is drawn off screen (tiles, HUD and mode-split strips, plane pointers, R#18/R#23, palette and sprite pointers) and shown complete at a frame start. On a fast Amiga the render still takes longer than the vertical blank (BigMig: 120-140 lines), so before, the tiles changed during the frame while the scroll registers and sprites changed at the next one, and the scenery jumped against the hero in scrolling games (Lilly's Saga, Space Manbow). It needs about 90 KB more chip RAM and some blitter time to keep the hidden buffer up to date, so it is off in the 030 preset, whose display path is unchanged. Other screen modes run as before.
- **CD32 pads** (joystick port, Amiga port 2): read with the CD32 protocol (pin 5 latches, pin 6 clocks, the buttons come in on pin 9), so a CD32-style pad such as the KTRL CD32 gives red = MSX trigger A, blue = trigger B, yellow = Space, green = M and play = F1; the shoulder buttons do nothing. The pad was detected by its ID bits and the port probed every 16 frames without one; the detection failed on real pads and adapters, so 4.1 switched it off and 4.1.1 replaced it with the per-port menu option (above). The timing uses CIA reads, so it is the same on a 68030 and a PiStorm.
- **Use Japanese ID (60 Hz)** (Options): the BIOS reports a Japanese machine and starts at 60 Hz, the machines most games were written for; with Frequence "From VDP" the display follows. Off: an international machine at 50 Hz. It applies to MSX, MSX2 and MSX2+; in v3.1 it changed only the ID bytes and kept 50 Hz. On in the PiStorm preset.

## From Juan's v3.2/v3.5 source

Juan sent his latest source (AmiMSX v3.2, with a v3.5 GUI from 2021). It has no emulation changes; these parts of it are in 4.0:

- **Freeware:** Project > Register does nothing, and About's "More" button (the old postal and web addresses) is disabled. The screen title reads "1994-2000/2009/2021 © GUS Entertainment", and the About box thanks Zener and Sandman, as in his v3.5.
- **No anti-crack counter:** v3.1 counted joystick polls and, with prefs byte $7F at $20 or more, silently turned the Z80's CALL nn into JP nn. Removed, as in v3.2.
- **Closing files:** no Close() call when no file is open.

## Robustness

- **Clean exits:** if the menu screen or main window can't open (low chip RAM), AmiMSX quits cleanly instead of crashing. On a machine without a 68020, "Continue" in the requester quits (it carried on and crashed).
- **input.device** is closed at exit, and a start-up that fails half way frees what it opened (the exit used a device that was never opened).
- **Workbench mode:** the audio interrupt (AUD3, used by the FM output) goes back to the OS while you are in Workbench mode and is taken again afterwards; the OS vector is saved and restored.
- **Blitter:** an OS blit that ends while AmiMSX takes over the blitter keeps its interrupt request.
- **About:** no gadget call when the About window failed to open.

## Defaults

- **Sprites every frame**, as on an MSX (the setting is still in the main window).
- **Mask screen edges:** Auto.
- **The Matra splash** is off (build with `-DSPLASH=1` to show it).

## System ROMs

- **AmiMSX2.data:** 4.0 ships the original data file (MSX, MSX2 and MSX2+ system ROMs, disk ROM and Kanji), as the earlier AmiMSX packages on Aminet did. Disks and MSX-BASIC work as before.
- **C-BIOS:** `tools/make_cbios_data.py` builds a data file from C-BIOS, a free BIOS that runs cartridges only (no BASIC, no disk ROM). AmiMSX recognises it and skips its SUB-ROM patches.

## Workbench

- **Presets:** two project icons, each with its own settings file:
  - **AmiMSX 030:** the low-spec target, an A1200 or similar with a 68030 at 50 MHz and fast RAM. PSG, PAL, sprites every frame.
  - **AmiMSX PiStorm:** PiStorm (Emu68), BigMig and other fast CPUs. PSG+FM, Frequence "From VDP" (60 Hz games at NTSC, full speed), Use Japanese ID (60 Hz), Audio filter and Smooth display.
- **No 68020 preset:** the A1200 preset of the test builds is gone. A stock 68020 A1200 is not a target; AmiMSX runs on it, but slowly.
- **ToolType `PREFS=<file>`:** chooses the settings file. A relative name is taken from the icon's drawer. Save Prefs writes to the same file.

## Building and testing

- **Assembler:** vasm 2.0f replaces Devpac III. `build.sh` refuses branches to `*+n`, after one crashed builds once the code moved.
- **Version:** "AmiMSX Emulator v4.0" in the menu title, `$VER`, About box and start-up banner, followed by a build reference (date and commit, from `tools/buildid.sh`).
- **Test hooks:**
  - `AmiMSX <cartridge> [keyscript]` inserts a cartridge in Slot 1 and powers on;
  - `AmiMSX <cartridge> MENU` inserts it and stays in the menu (settings, then Power ON); the Slot 1 label shows the file's name;
  - `P=<prefs file>` as the second or third argument loads (and saves) that prefs file, as an icon's PREFS ToolType does;
  - the key script drives the MSX keyboard and can freeze exact frames for capture (SNAP), or copy the MSX state at a frame without freezing (DUMP, `STATEDUMP` builds).
- **Debug builds:**
  - `TRACE` (instruction ring), `TRACELITE` (event ring only);
  - `PERF` (frame timing and profile; `PERFLOCAL` writes perf.bin to the current directory, for the Measure scripts);
  - `BANDCHK` (logs VDP commands and checks the SCREEN 5/7 band conversion);
  - `CORRCHK`, `HANGCHK` and `EXCCHK` (fault finding; `EXCCHK` restores the exception vectors on every exit).
- **Regression:** a tiered suite in WinUAE (smoke, feature, full), with captures compared pixel by pixel against accepted baselines.
- **Cross-checks with openMSX:** consecutive-frame bursts from both emulators (`tools/burst.py`, with `--machine` for the MSX2+), VDP register and palette logs, palette probes, and an overnight batch (`tools/overnight.py`).
- **Tester:** `winuae/AmiMSX-Tester.ps1`, a Windows launcher for playing in WinUAE (68030 or PiStorm-like speed) with one-click issue reports.
