# AmiMSX 4.x roadmap

What is planned after 4.4. Plans, not promises: the order can change, and this file is updated with each release. Details of each problem are in `open_issues.md`; finished work moves to `CHANGES_4.x.md`.

## Shipped in 4.4

The machine per game (MSX2, MSX2+ and turbo R games, ROMs and disks, File Hunter's homebrew included), cartridge SRAM saves for the ASCII8/ASCII16 SRAM cartridges, the remaining VDP command gaps (SRCH, two-colour HMMV, SCREEN 8 drawing commands into video memory), SCREEN 8 speed on the 68030/50 back to its pre-4.3 level, and CPU-drawn SCREEN 2/4 tiles on 68040/060 machines (Lotus F3's judder on the PiStorm); Bombaman's ghosting is gone. See `CHANGES_4.x.md`.

## Next

- **Sound coverage:** first a measured survey (every test title against openMSX), then the gaps that matter most: FM accuracy, MSX-AUDIO (Y8950), PSG/SCC details. Moonsound only as "bring your own sample ROM" on PiStorm/BigMig.
- **MSX turbo R:** an R800 mode for the Z80 core (its timing and multiply instructions), PCM, the turbo R system ROMs (supplied by the user). PiStorm and BigMig only.

## Still open, not yet scheduled

Koei's SRAM cartridges, Shoulder Blade OVERDRIVE title logo, Nemesis 2 cyan stars and a missing ship frame, the rare black screen on the first Power ON after a cartridge change, sprite mode 2 edge cases, CPIR/CPDR per-repeat timing, and the picture size of some MSX2 games on the MSX2+ machine (the game's own choice of video mode). The YJK modes (SCREEN 10-12) wait for a game that uses them.

Menu tidy-up (a tester, 28 Oct): remove the Project menu's Register item (it has done nothing since 4.0, AmiMSX is freeware), the About window's disabled More button (the old contact addresses) and the unused registration windows and texts; and keep the About window's date in step with each release (4.4 still shows October 11th, 2026).

Cartridges (a tester, 30 Oct): Slot 2 is greyed out while an MSX Disk ROM is chosen, so a two-cartridge set-up (a loader in Slot 1 and the game in Slot 2, such as the R-Type FM loader) needs the Disk ROM set to None first; choosing a Slot 2 cartridge should do that, or the disk ROM should move out of the way. The R-Type mapper is done (4.5, branch rtype: Docs/agent_notes/v45_rtype.md). Ashguine 2's FM/MSX-Audio patch (English translation) plays its sound effects but no music.

RTG scanlines (a tester, 30 Oct): their own item in the Options menu, saved with the prefs, and blended scanlines (the row between two lines a dimmed mix of both) beside the hard ones.

## Later

- Speed work on the native AGA display.
- The RTG display (4.5 beta): SCREEN 0, 3, 6 and 7 and the SCREEN 5/8 split screens on RTG, a 60 Hz output for 60 Hz games, blended scanlines and the scanline choice in the prefs.
- Sound output options (Paula 8/14-bit, 16-bit AHI).
