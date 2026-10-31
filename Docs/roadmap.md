# AmiMSX 4.x roadmap

What is planned after 4.5. Plans, not promises: the order can change, and this file is updated with each release. Details of each problem are in `open_issues.md`; finished work moves to `CHANGES_4.x.md`.

## Shipped in 4.5

The RTG display with hard and blended scanlines, every MSX screen mode on RTG, SCREEN 5 on VRAM, the R-Type mapper, and the menus rebuilt.

## Shipped in 4.4

The machine per game (MSX2, MSX2+ and turbo R games, ROMs and disks, File Hunter's homebrew included), cartridge SRAM saves for the ASCII8/ASCII16 SRAM cartridges, the remaining VDP command gaps (SRCH, two-colour HMMV, SCREEN 8 drawing commands into video memory), SCREEN 8 speed on the 68030/50 back to its pre-4.3 level, and CPU-drawn SCREEN 2/4 tiles on 68040/060 machines (Lotus F3's judder on the PiStorm); Bombaman's ghosting is gone. See `CHANGES_4.x.md`.

## Next

- **Sound coverage:** first a measured survey (every test title against openMSX), then the gaps that matter most: FM accuracy, MSX-AUDIO (Y8950), PSG/SCC details. Moonsound only as "bring your own sample ROM" on PiStorm/BigMig.
- **MSX turbo R:** an R800 mode for the Z80 core (its timing and multiply instructions), PCM, the turbo R system ROMs (supplied by the user). PiStorm and BigMig only.

## Still open, not yet scheduled

Koei's SRAM cartridges, Shoulder Blade OVERDRIVE title logo, Nemesis 2 cyan stars and a missing ship frame, the rare black screen on the first Power ON after a cartridge change, sprite mode 2 edge cases, CPIR/CPDR per-repeat timing, and the picture size of some MSX2 games on the MSX2+ machine (the game's own choice of video mode). The YJK modes (SCREEN 10-12) wait for a game that uses them.

About window (a tester, 28 Oct): keep its date in step with each release (it is typed in by hand). (The menu tidy-up is done: branch menus, Docs/agent_notes/v46_menus.md.)

Cartridges (a tester, 30 Oct): The R-Type mapper is done (4.5, branch rtype: Docs/agent_notes/v45_rtype.md). Ashguine 2's FM/MSX-Audio patch (English translation) plays its sound effects but no music.

Manbow 2 title on RTG (a tester, 31 Oct, A1200): nearly right, but a very brief video glitch remains.

Uridium 2 sound (a tester, 31 Oct, A1200): silent on RTG and AGA, with Sound on PSG+FM and on SCC, so not a setting. Trace its sound writes in openMSX alongside Ashguine 2. Also check that Sound moves to SCC by itself when this cartridge is inserted.

R-Type FM (a tester, 31 Oct, A1200): the loader rtype-fm.rom never offers MSX-MUSIC on the MSX2 machine. Debugger at its menu: E050h = FFh (not found), E052h = 0 (its BIOS check passed), FCC1h = 0. It only looks in slot 0-2, where AmiMSX puts the APRLOPLL signature, if EXPTBL says slot 0 is expanded. Find out why FCC1h is not 80h although slot 0 has sub-slots; it may matter to other games that look for MSX-Music. The pair also gives a black screen on the MSX2+ machine, with Sound on PSG and on PSG+FM.

Drive B and .MVD files (a tester, 31 Oct): drive B only takes plain 360K and 720K images, drive A takes .MVD too. Loading an .MVD into B now says so; add support.

Scanlines on the RTG menu (a tester, 31 Oct): a Scanlines in Menu tick is on branch menu-scanlines (a2677db). It looked right in WinUAE and in a first photo, but did not work on the A1200, so it is out of this release.

Multi-disk games (a tester, 31 Oct): find some games that come on several DSK images and add them as test titles, to exercise disk swaps and both drives.

Main window (a tester, 31 Oct): Machine: sits a little tight against the left of its frame.

## Later

- Speed work on the native AGA display.
- The RTG display (4.5 beta): a 60 Hz output for 60 Hz games (SCREEN 0, 3, 6 and 7, the MSX boot animation and the SCREEN 5/8 and SCREEN 8 mode splits are done: branch rtgscreens).
- RTG scanlines over the border (a tester, 31 Oct): while the MSX is running they only cover the middle of the picture, as the boot sequence shows; the border area should get them too.
- Sound output options (Paula 8/14-bit, 16-bit AHI).
