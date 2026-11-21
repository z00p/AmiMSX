# AmiMSX 4.x roadmap

What is planned after 4.9. Plans, not promises: the order can change, and this file is updated with each release. Details of each problem are in `open_issues.md`; finished work moves to `CHANGES_4.x.md`.

## Shipped in 5.3

Game saves: the FM-PAC cartridge with its battery SRAM (Slot 1 or 2, FMPAC.PAC) and ASCII 16K-X flash saves (Illusion City), both confirmed on the A1200; F-1 Spirit 3D Special's AGA horizon slab (VDP LINE ends at the screen side); the S#2 TR bit. See `CHANGES_4.x.md`.

## Shipped in 5.2

F-1 Spirit 3D Special (MSX2+) plays (title, photos, Disk B, SP2 in the bends, the player's car); YJK modes (SCREEN 10-12); the ASCII 16K-X mapper and Illusion City; sprite bands with their own pattern table and colours drawn by VDP commands; S#2 HR/VR timed as the V99x8. See `CHANGES_4.x.md`.

## Shipped in 5.1

Two programs: AmiMSX (no turbo R, every CPU) and AmiMSX Turbo R (PiStorm, BigMig) with its own Turbo R AGA and RTG presets and settings; Overclock in steps (+10%, +25%, +50%, Max); new cartridge icons and drawer layout. See `CHANGES_4.x.md`.

## Shipped in 5.0

- MSX turbo R machine (beta, FS-A1GT, own firmware), AmiMSX030 for the 68030, a game on the command line or a project icon (Lupa), KTRL CD32+ pad type, Joystick as Cursor Keys.

## Shipped in 4.9

Z80 fixes (DAA after INC A / DEC A, issue #3; the R800 multiply opcodes do nothing on the Z80), GETDPB's carry, and the preset icons renamed AGA 030, AGA and RTG. See `CHANGES_4.x.md`.

## Shipped in 4.8

Speed on the 68030/50: SCREEN 8 games (Uridium 2 to 98%), SCREEN 4 games with a table split (Space Manbow), and games that wait for the next frame in a short loop (Lilly's Saga to 98%). See `CHANGES_4.x.md`.

## Shipped in 4.7

Quicker controller response on RTG, Smooth Display and the Amiga output, Sound Mix (Classic, Mono, Stereo) for PSG+FM, FM decay and gain fixes, Z80 block instructions that stop at line ends, and the Emulation menu grouped. See `CHANGES_4.x.md`.

## Shipped in 4.6

Your own MSX-Music ROM with its music driver (R-Type's FM music), PSG+FM only for games with FM, R-Type in Slot 2 on the MSX2+, magnified sprites on the Amiga output (Shoulder Blade OVERDRIVE's title), Uridium's status bar, Space Manbow 2's title, and Zanac EX's speed on the 68030. See `CHANGES_4.x.md`.

## Shipped in 4.5

The RTG display with hard and blended scanlines, every MSX screen mode on RTG, SCREEN 5 on VRAM, the R-Type mapper, and the menus rebuilt.

## Shipped in 4.4

The machine per game (MSX2, MSX2+ and turbo R games, ROMs and disks, File Hunter's homebrew included), cartridge SRAM saves for the ASCII8/ASCII16 SRAM cartridges, the remaining VDP command gaps (SRCH, two-colour HMMV, SCREEN 8 drawing commands into video memory), SCREEN 8 speed on the 68030/50 back to its pre-4.3 level, and CPU-drawn SCREEN 2/4 tiles on 68040/060 machines (Lotus F3's judder on the PiStorm); Bombaman's ghosting is gone. See `CHANGES_4.x.md`.

## Next

- **FM sound (5.4):** busy FM music sounds distorted on the A1200 (Illusion City with the FM-PAC, 21 Nov; same with Sound Mix Classic, so it is the FM itself). Leading suspect: the one-cycle tables played at the line rate (~15.6 kHz) fold bright notes' overtones back below 7.8 kHz; measure first (openMSX register log rendered through tools/fm_synth.py vs an openMSX recording). Also the OPLL rhythm mode (register 0Eh, drums): Illusion City plays hi-hat and bass drum with it, which AmiMSX leaves out.
- **Sound coverage:** first a measured survey (every test title against openMSX), then the gaps that matter most: FM accuracy, MSX-AUDIO (Y8950), PSG/SCC details. Moonsound only as "bring your own sample ROM" on PiStorm/BigMig.

## Still open, not yet scheduled

Koei's SRAM cartridges, Nemesis 2 cyan stars, the rare black screen on the first Power ON after a cartridge change, sprite mode 2 edge cases, and the picture size of some MSX2 games on the MSX2+ machine (the game's own choice of video mode). Illusion City's menu box borders have the wrong colours (palette writes and bitplanes match openMSX; next: the Amiga colour registers).

F-1 Spirit 3D Special on RTG (a tester, 18 Nov, 5.2 RC1 on the A1200 PiStorm, RTG preset): it starts now (5.1 didn't), but the race intro pictures (car at the stands, driver close-up) have a bright blue background with heavy horizontal streaks where openMSX has black. Also on the photos: the Konami logo on a pale page with lighter bands at the top and bottom, and the title logo on dark blue with no other text; compare both with openMSX. AGA is fine. WinUAE RTG doesn't reproduce it (its intro matched openMSX), so the next step is a debug build that draws on-screen rows on the A1200 (the RTG frame's state), photographed by a tester.

Game saves that persist (a tester, 18 Nov; Illusion City, English translation ROM v0.3, "works well" on 5.2 RC1 Turbo R AGA). Its save menu (System > save point) offers Quick Save, (FM)PAC SRAM, Game Disk 1, User Disk and Flash ROM. (a) Flash ROM: msxtranslations.com/ic.php says the ROM build saves to the ASCII16-X cartridge's flash (tested on openMSX). AmiMSX already emulates AMD flash commands (program, 64 KB sector erase) and keeps changed sectors in `<cartridge>.flash`, but only for the flash Konami SCC cartridges (4.0, Pampas & Selene); the ASCII 16K-X mapper has no flash writes yet. Next: the ASCII16-X flash chip's commands as openMSX has them, on the same `.flash` file. (b) (FM)PAC SRAM: AmiMSX's FM-PAC in Slot 1 (Sound PSG+FM) is its ROM only; the PAC's 8 KB battery SRAM (unlocked by 4Dh/69h at 5FFEh/5FFFh) isn't emulated, so nothing is kept. (c) User Disk: whether a save to a blank disk image in Drive A works today is not checked yet (it needs a turbo R run to a save point); if it does, it is the workaround for the readme.

F-1 Spirit 3D Special AGA: the far road at the horizon drawn as a flat slab (a tester, 5.2 RC1 and RTG Fix 2 on the A1200). The earlier "stills match openMSX" only covered the scenery, not the road. Cause found: AGA's LINE wrapped at the screen side instead of ending there, and the course's road shapes are drawn with such lines. Confirmed on the A1200 (a tester, 21 Nov: "same as RTG, nearly perfect"). Left, a known issue on AGA and RTG alike: the road's top strip at the horizon drifts away from the rest of the road on bends (photos 21 Nov). Not yet compared with openMSX, so it may be the game's own drawing.

About window (a tester, 28 Oct): keep its date in step with each release (it is typed in by hand). (The menu tidy-up is done: branch menus, Docs/agent_notes/v46_menus.md.)

Cartridges (a tester, 30 Oct): The R-Type mapper is done (4.5, branch rtype: Docs/agent_notes/v45_rtype.md). Ashguine 2's FM/MSX-Audio patch (English translation) should play its music now it finds the ID (WinUAE logs the FM writes): a tester to listen.

After 4.6 (3 Nov): R-Type's FM music sounds thin (an envelope's decay runs past its sustain level, and the output is quiet: it needs an automatic gain). The Z80's block instructions (LDIR, INIR, OTIR) can't be interrupted, so a line interrupt can come up to 16 lines late (Space Manbow 2's title split, now and then). Uridium 2's stars are written across the line where AmiMSX draws the frame, so one-dot stars shimmer. Zanac EX still dips to about 80% on the 68030/50 (HMMC). From reading the code, not yet reproduced: on AGA, LMMC's XOR acts as OR, LMMC ops 4-7 differ from the VDP, and HMMC uses the command's logical op, which the VDP ignores.

Sound on Konami SCC cartridges with FM (2 Nov): with no game settings, a Konami SCC mapper moves Sound to SCC, from PSG+FM too. Batman and Head over Heels are SCC games, so that stays. DEVA is FM, so the ROM database now keeps its Sound as set. Other ROMs with no "OPLL" in the file drop from PSG+FM to PSG, as FM takes the PSG's noise channel (GPSndRule). Exceptions either way go in SOUND_EXCEPTIONS in tools/make_romdb.py: a compressed FM game could need one. Uridium 2 is not a bug: the widely shared ROM is the author's build after the "Music disabled" commit (Maneldemo/Uridium-2-for-msx, 29 Dec 2015). The earlier build b605cd0 (14 Jun 2015) writes PSG and SCC and plays in openMSX. In AmiMSX 4.7 on the A1200 it runs but plays silent, PSG included (a tester, 11 Nov), while Space Manbow has sound: not looked into yet (in openMSX it rewrites every PSG register each frame and enables the SCC around each write).

MSX-Music ROM driver (1 Nov): R-Type calls the ROM at 4110h-4122h (INIOPL, MSTART, MSTOP, RDDATA, OPLDRV, TSTBGM) and plays its FM music with OPLDRV. With the maintainer's own MSXMUSIC.ROM next to AmiMSX that works: the real ROM sits in Slot 1 if it is empty, otherwise in slot 3 RAM, where a game can overwrite it, and R-Type plays FM (WinUAE: 4264 OPLL writes in 65 s, openMSX 4400 in 50 s). Without the file AmiMSX has no driver, C-BIOS music is only a stub, and R-Type stays on the PSG (the ID is left out when a slot uses the R-Type mapper). A rewrite of the driver is still open, for those without the ROM; other games that use OPLDRV find the stubs and play no FM music.

Drive B and .MVD files (a tester, 31 Oct): drive B only takes plain 360K and 720K images, drive A takes .MVD too. Loading an .MVD into B now says so; add support.

Scanlines on the RTG menu (a tester, 31 Oct): a Scanlines in Menu tick is on branch menu-scanlines (a2677db). It looked right in WinUAE and in a first photo, but did not work on the A1200, so it is out of this release.

Multi-disk games (a tester, 31 Oct): find some games that come on several DSK images and add them as test titles, to exercise disk swaps and both drives.

Main window (a tester, 31 Oct): Machine: sits a little tight against the left of its frame.

Overclock in steps (a tester, 12 Nov): on the PiStorm, Emulation > Speed > Overclock made Space Manbow very smooth (its own slowdown gone), but Nemesis 2 ran far too fast with it, much like fMSX's unthrottled build. The guide says Overclock keeps the frame rate, so first find out why Nemesis 2 speeds up (what it paces itself on). Then consider a milder setting: a fixed extra share of Z80 time per frame (say +10-25%) instead of all the time left over.

## Later

- Speed work on the native AGA display.
- The RTG display (4.5 beta): a 60 Hz output for 60 Hz games (SCREEN 0, 3, 6 and 7, the MSX boot animation and the SCREEN 5/8 and SCREEN 8 mode splits are done: branch rtgscreens).
- RTG scanlines over the border (a tester, 31 Oct): while the MSX is running they only cover the middle of the picture, as the boot sequence shows; the border area should get them too.
- Sound output options (Paula 8/14-bit, 16-bit AHI).
- CD32 pads, a second reader (from Arnold/AmiPCEngine): Options gets a per-port choice, "CD32 pad" (today's reader, the default; right for the KTRL CD32) or "KTRL CD32+" (a "low clock" reader, which also suits the Mega Multi, whose Start and C are dead in CD32 mode). Detection from the pad's ID bits proved unreliable, so it's a setting, saved in the prefs, behind a NO_ build switch. The shared routine is the emu-dev-docs CD32 kit 2 (kits/cd32pad/cd32read.s; credit Afrotechmods / FAmiga).
- RTG mode choice (from AmiPCEngine 2.1, its issue #1): the automatic 960x540 can be a mode the monitor can't show. Let the user pick the RTG mode: an RTGMODE ToolType/CLI argument (AUTO, <w>x<h> or a ModeID), a saved ModeID in the prefs (0 = automatic), "Pick mode..." and "Automatic" in the menu, and a fallback to the automatic mode when the chosen one doesn't open. AmiMSX_Rtg_v4.asm has the same mode search, so the shared kit fits: rtg-framework asm/rtgmode.s and rtgmode_data.s (RmParse, RmResolve, RmPick, RmLabel), tested on the A1200.
