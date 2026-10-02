# Test set 2: first full pass

- **Date:** 2 Oct 2026.
- **Build:** 37f2c86 (M1-wait timing), auto-Space (`PERFSPACE=700`).
- **Config:** WinUAE 68030 (`AmiMSX-030.uae`).
- **Shots:** 18, 30, 45 and 65 s.
- **Harness:** `winuae/run_set2.ps1`.
- **Sheets:** `build/strips/set2_part1-4.png`; one folder per title under `build/strips/set2/`.

Auto-Space only presses Space, so "waits for a key" isn't a fault. Those titles get a per-title input script in the tiered regression.

## Konami originals and patched versions (R2K)

| Title | Result | Notes |
|---|---|---|
| Maze of Galious | OK | In play |
| Galious Enhanced (MSX2 patch) | OK | Options screen, then play in SCREEN 5 |
| Gradius 2 | OK | In play |
| King's Valley 2 | OK | Play and demo loop |
| Metal Gear | Waits | Transceiver intro needs a key |
| Nemesis 2 | OK | In play |
| Nemesis 3 / Enhanced | OK | Intro and demo |
| Salamander / Enhanced | OK | Play; GAME OVER with no input |
| Space Manbow | OK | In play |
| Usas / Enhanced | OK | In play, no input |
| Vampire Killer / SCC patch | OK | In play |
| Zanac | OK | In play |
| Zanac Ex | Check | Play is OK; the title at 18 s is a jumble of tiles. Compare with openMSX. |
| Zanac Ex Enhanced | OK | In play |

## Homebrew and demos (R2, disks)

| Title | Result | Notes |
|---|---|---|
| Batman (FX) | Waits | Menu needs ENTER |
| BUN-GA-RUA | Fault | Black title: SCREEN 5/4 mode split. Fixed in the mode-split work; palette bands remain (mid-frame palette writes). |
| Angelic Warrior DEVA | Check | Same in-game frame at 30, 45 and 65 s. Could be a stall or a character standing still with no input. |
| DELTA (ASCII16 tag) | OK | Racing, road and page flips look right |
| Lotus F3 | OK | In play, at the start line |
| Monster Hunter (KonamiSCC tag) | OK | Title, then play |
| Neon Horizon | Out of scope | 8 MB, over the 4 MB cartridge limit ("bad cartridge size") |
| Neon Revenant MSX1 / MSX2 (ASCII8 tag) | OK | Both editions in play |
| Tales of Popolon | OK | Raycaster in play |
| MSX Unleashed (ROM) | Fault | Runs into the credits scroller, then fills the screen with "Internal error in ..." by 65 s |
| Akin (disk 1) | OK | Game graphics |
| akin2 disk | OK | Actually a Pumpkin Adventure III promo (from the download) |
| Bold (disk) | OK | Demo parts progress |
| Invasion of the Big Pixels (disk) | OK | Plasma and dither parts progress |
| io (disk) | OK | Passes its start-up checks after the timing fix; effects run |

## Follow-ups

1. MSX Unleashed "Internal error".
2. DEVA: stall or idle.
3. Zanac Ex title.
4. Mid-frame palette writes through the copper (BUN-GA-RUA logo bands, io per-line colours).
5. Input scripts for Metal Gear and Batman.
