# AmiMSX 4.x roadmap

What is planned after 4.2. Plans, not promises: the order can change, and this file is updated with each release. Details of each problem are in `open_issues.md`; finished work moves to `CHANGES_4.x.md`. Releases are no longer marked beta from 4.2.

## 4.3

- **Uridium 2:** enemy ships don't collide with the player's ship. The game's own hit test misses; a trace build comes next. A general sprite-collision fix (lines with sprites on) waits on a branch for this.
- **Jailbreak:** a 2-line strip flickers near the bottom. The drafted double-buffered copper list (`COPLINEDB`) was tested and does not fix it; the new lead is a palette change the game makes at the last display line (line 211).
- **Keyboard mapping regression test.**
- **Speed baseline:** percentage of real MSX speed for the heaviest titles (Lilly's Saga, Space Manbow, Manbow 2, BUN-GA-RUA, Barbarian, Gradius III MSX2+), measured on the real PiStorm A1200 (measurement build run remotely, timings read back) and on WinUAE's cycle-exact 68030/50, calibrated against a user report (Lilly's Saga at about 68% on a Blizzard 030/50, issue #1). Run at each release and before and after speed work.
- **Z80 timing audit** against the Z80+M1 cycle table (map.grauw.nl), every opcode incl. block instructions, interrupt acknowledge and DD CB (GitHub issue #2).
- **Bombaman:** ghosting on fast machines.
- **Lotus F3:** car jitter on PiStorm.
- **Manbow 2 title screen:** SCREEN 7/8 planar VRAM mapping (the V9938 interleaves the two 64 KB banks in G6/G7), plus the SCREEN 5/7 command flush when SCREEN 5 is left. Moves to 4.4 if it runs long.

## Shipped in 4.2

The Gradius III power-meter boxes (VDP LINE logical operations), the edge mask (Off / 8 / 16 dots, per game; Auto mask removed) and the PAL/NTSC timing restored on quit. See `CHANGES_4.x.md`.

## 4.4

- **MSX2+ YJK modes** (SCREEN 10-12).
- **Per-game defaults** from a game index (mapper, machine, options), for ROMs and disks.
- **Cartridge SRAM** (battery-backed save memory) for the ASCII8/ASCII16 SRAM mappers and similar, saved to a file next to the cartridge. Games such as Lilly's Saga need it for their save menu; today AmiMSX's ASCII mappers switch ROM banks only.

## Still open, not yet scheduled

Head over Heels Remake menu letters, Shoulder Blade OVERDRIVE title logo, Nemesis 2 cyan stars and a missing ship frame, the rare black screen on the first Power ON after a cartridge change, sprite mode 2 edge cases, and the picture size of some MSX2 games on the MSX2+ machine (the game's own choice of video mode).

## Later

- Speed work on the native AGA display.
- An optional RTG (Picasso96/CyberGraphX) display, shared with other Amiga emulators.
- Sound: the FM engine and output options (Paula 8/14-bit, 16-bit AHI).
