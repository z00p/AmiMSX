# AmiMSX 4.x roadmap

What is planned after 4.4. Plans, not promises: the order can change, and this file is updated with each release. Details of each problem are in `open_issues.md`; finished work moves to `CHANGES_4.x.md`.

## Shipped in 4.4

The machine per game (MSX2, MSX2+ and turbo R games, ROMs and disks, File Hunter's homebrew included), cartridge SRAM saves for the ASCII8/ASCII16 SRAM cartridges, the remaining VDP command gaps (SRCH, two-colour HMMV, SCREEN 8 drawing commands into video memory), SCREEN 8 speed on the 68030/50 back to its pre-4.3 level, and CPU-drawn SCREEN 2/4 tiles on 68040/060 machines (Lotus F3's judder on the PiStorm); Bombaman's ghosting is gone. See `CHANGES_4.x.md`.

## Next

- **Sound coverage:** first a measured survey (every test title against openMSX), then the gaps that matter most: FM accuracy, MSX-AUDIO (Y8950), PSG/SCC details. Moonsound only as "bring your own sample ROM" on PiStorm/BigMig.
- **MSX turbo R:** an R800 mode for the Z80 core (its timing and multiply instructions), PCM, the turbo R system ROMs (supplied by the user). PiStorm and BigMig only.

## Still open, not yet scheduled

Koei's SRAM cartridges, Shoulder Blade OVERDRIVE title logo, Nemesis 2 cyan stars and a missing ship frame, the rare black screen on the first Power ON after a cartridge change, sprite mode 2 edge cases, CPIR/CPDR per-repeat timing, and the picture size of some MSX2 games on the MSX2+ machine (the game's own choice of video mode). The YJK modes (SCREEN 10-12) wait for a game that uses them.

## Later

- Speed work on the native AGA display.
- An optional RTG (Picasso96/CyberGraphX) display, shared with other Amiga emulators (design in progress with Arnold).
- Sound output options (Paula 8/14-bit, 16-bit AHI).
