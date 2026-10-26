# AmiMSX 4.x roadmap

What is planned after 4.3. Plans, not promises: the order can change, and this file is updated with each release. Details of each problem are in `open_issues.md`; finished work moves to `CHANGES_4.x.md`.

## Shipped in 4.3

The SCREEN 7/8 video memory layout (Manbow 2's title screen), VDP command timing (Jailbreak), several VDP command fixes (Head over Heels Remake's letters), the Z80 timing audit (957 of 959), and tests for the keyboard mapping, the Z80 timing and the SCREEN 7/8 memory. See `CHANGES_4.x.md`.

## 4.4

- **VDP commands still missing:** SRCH; HMMV in SCREEN 5/7 with two different nibbles; SCREEN 8 LINE, PSET, HMMC, LMMC and YMMM drawing into VRAM. The SCREEN 7/8 memory test (`tools/maptest.sh`, FULL=1) shows each against openMSX.
- **Cartridge SRAM** (battery-backed save memory) for the ASCII8/ASCII16 SRAM mappers and similar, saved to a file next to the cartridge. Lilly's Saga needs it for its save menu.
- **Per-game defaults** from a game index (mapper, machine, options), for ROMs and disks.
- **Speed:** win back the SCREEN 8 cost on the 68030/50 (Uridium 2).
- **Bombaman** ghosting and **Lotus F3** jitter on fast machines (need tests on real hardware).

## After 4.4

- **Sound coverage:** first a measured survey (every test title against openMSX), then the gaps that matter most: FM accuracy, MSX-AUDIO (Y8950), PSG/SCC details. Moonsound only as "bring your own sample ROM" on PiStorm/BigMig.
- **MSX turbo R:** an R800 mode for the Z80 core (its timing and multiply instructions), PCM, the turbo R system ROMs (supplied by the user). PiStorm and BigMig only.

## Still open, not yet scheduled

Shoulder Blade OVERDRIVE title logo, Nemesis 2 cyan stars and a missing ship frame, the rare black screen on the first Power ON after a cartridge change, sprite mode 2 edge cases, CPIR/CPDR per-repeat timing, and the picture size of some MSX2 games on the MSX2+ machine (the game's own choice of video mode). The YJK modes (SCREEN 10-12) wait for a game that uses them.

## Later

- Speed work on the native AGA display.
- An optional RTG (Picasso96/CyberGraphX) display, shared with other Amiga emulators (design in progress with Arnold).
- Sound output options (Paula 8/14-bit, 16-bit AHI).
