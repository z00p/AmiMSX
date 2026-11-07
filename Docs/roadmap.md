# AmiMSX 4.x roadmap

What is planned after 4.7. Plans, not promises: the order can change, and this file is updated with each release. Details of each problem are in `open_issues.md`; finished work moves to `CHANGES_4.x.md`.

## Shipped in 4.7

Quicker controller response on RTG, Smooth Display and the Amiga output, Sound Mix (Classic, Mono, Stereo) for PSG+FM, FM decay and gain fixes, Z80 block instructions that stop at line ends, and the Emulation menu grouped. See `CHANGES_4.x.md`.

## Shipped in 4.6

Your own MSX-Music ROM with its music driver (R-Type's FM music), PSG+FM only for games with FM, R-Type in Slot 2 on the MSX2+, magnified sprites on the Amiga output (Shoulder Blade OVERDRIVE's title), Uridium's status bar, Space Manbow 2's title, and Zanac EX's speed on the 68030. See `CHANGES_4.x.md`.

## Shipped in 4.5

The RTG display with hard and blended scanlines, every MSX screen mode on RTG, SCREEN 5 on VRAM, the R-Type mapper, and the menus rebuilt.

## Shipped in 4.4

The machine per game (MSX2, MSX2+ and turbo R games, ROMs and disks, File Hunter's homebrew included), cartridge SRAM saves for the ASCII8/ASCII16 SRAM cartridges, the remaining VDP command gaps (SRCH, two-colour HMMV, SCREEN 8 drawing commands into video memory), SCREEN 8 speed on the 68030/50 back to its pre-4.3 level, and CPU-drawn SCREEN 2/4 tiles on 68040/060 machines (Lotus F3's judder on the PiStorm); Bombaman's ghosting is gone. See `CHANGES_4.x.md`.

## Next

- **Sound coverage:** first a measured survey (every test title against openMSX), then the gaps that matter most: FM accuracy, MSX-AUDIO (Y8950), PSG/SCC details. Moonsound only as "bring your own sample ROM" on PiStorm/BigMig.
- **MSX turbo R:** an R800 mode for the Z80 core (its timing and multiply instructions), PCM, the turbo R system ROMs (supplied by the user). PiStorm and BigMig only.

## Still open, not yet scheduled

Koei's SRAM cartridges, Nemesis 2 cyan stars, the rare black screen on the first Power ON after a cartridge change, sprite mode 2 edge cases, and the picture size of some MSX2 games on the MSX2+ machine (the game's own choice of video mode). The YJK modes (SCREEN 10-12) wait for a game that uses them.

About window (a tester, 28 Oct): keep its date in step with each release (it is typed in by hand). (The menu tidy-up is done: branch menus, Docs/agent_notes/v46_menus.md.)

Cartridges (a tester, 30 Oct): The R-Type mapper is done (4.5, branch rtype: Docs/agent_notes/v45_rtype.md). Ashguine 2's FM/MSX-Audio patch (English translation) should play its music now it finds the ID (WinUAE logs the FM writes): a tester to listen.

After 4.6 (3 Nov): R-Type's FM music sounds thin (an envelope's decay runs past its sustain level, and the output is quiet: it needs an automatic gain). The Z80's block instructions (LDIR, INIR, OTIR) can't be interrupted, so a line interrupt can come up to 16 lines late (Space Manbow 2's title split, now and then). Uridium 2's stars are written across the line where AmiMSX draws the frame, so one-dot stars shimmer. Zanac EX still dips to about 80% on the 68030/50 (HMMC). From reading the code, not yet reproduced: on AGA, LMMC's XOR acts as OR, LMMC ops 4-7 differ from the VDP, and HMMC uses the command's logical op, which the VDP ignores.

Sound on Konami SCC cartridges with FM (2 Nov): with no game settings, a Konami SCC mapper moves Sound to SCC, from PSG+FM too. Batman and Head over Heels are SCC games, so that stays. DEVA is FM, so the ROM database now keeps its Sound as set. Other ROMs with no "OPLL" in the file drop from PSG+FM to PSG, as FM takes the PSG's noise channel (GPSndRule). Exceptions either way go in SOUND_EXCEPTIONS in tools/make_romdb.py: a compressed FM game could need one. Uridium 2 is not a bug: that ROM has no sound code (openMSX, Docs/agent_notes/overnight_2026-11-01.md).

MSX-Music ROM driver (1 Nov): R-Type calls the ROM at 4110h-4122h (INIOPL, MSTART, MSTOP, RDDATA, OPLDRV, TSTBGM) and plays its FM music with OPLDRV. With the maintainer's own MSXMUSIC.ROM next to AmiMSX that works: the real ROM sits in Slot 1 if it is empty, otherwise in slot 3 RAM, where a game can overwrite it, and R-Type plays FM (WinUAE: 4264 OPLL writes in 65 s, openMSX 4400 in 50 s). Without the file AmiMSX has no driver, C-BIOS music is only a stub, and R-Type stays on the PSG (the ID is left out when a slot uses the R-Type mapper). A rewrite of the driver is still open, for those without the ROM; other games that use OPLDRV find the stubs and play no FM music.

Drive B and .MVD files (a tester, 31 Oct): drive B only takes plain 360K and 720K images, drive A takes .MVD too. Loading an .MVD into B now says so; add support.

Scanlines on the RTG menu (a tester, 31 Oct): a Scanlines in Menu tick is on branch menu-scanlines (a2677db). It looked right in WinUAE and in a first photo, but did not work on the A1200, so it is out of this release.

Multi-disk games (a tester, 31 Oct): find some games that come on several DSK images and add them as test titles, to exercise disk swaps and both drives.

Main window (a tester, 31 Oct): Machine: sits a little tight against the left of its frame.

## Later

- Speed work on the native AGA display.
- The RTG display (4.5 beta): a 60 Hz output for 60 Hz games (SCREEN 0, 3, 6 and 7, the MSX boot animation and the SCREEN 5/8 and SCREEN 8 mode splits are done: branch rtgscreens).
- RTG scanlines over the border (a tester, 31 Oct): while the MSX is running they only cover the middle of the picture, as the boot sequence shows; the border area should get them too.
- Sound output options (Paula 8/14-bit, 16-bit AHI).
