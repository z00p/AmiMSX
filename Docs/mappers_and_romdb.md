# ROM mappers and a ROM database (12 Oct 2026)

What AmiMSX 4.0 can map today, what MSX software needs (openMSX's software database), how the maintainer's sets fare, and a plan for picking the mapper and settings from a database.

Sources: `AmiMSX_Main_v3.1.asm`, `AmiMSX_Menu_v3.1.asm`, `AmiMSX2.mapper`, openMSX 21.0's `tools/openmsx/share/softwaredb.xml`, the ROMs in `run/Roms`, the MSX Top 100 on a local drive, and the maintainer's MSX/MSX2 sets on a local drive and a local drive. The ROMs were read with Python (SHA-1, AmiMSX's checksum, a port of GuessMapper); nothing was run in WinUAE.

## Summary

- **Mappers:** AmiMSX has 6, plus Standard: Konami, Konami SCC (two decodes), ASCII8, ASCII16 and a 16 KB "Konami 1". Since 12 Oct, Konami SCC also has a flash mode for ROMs over 512 KB.
- **Size limits:** a ROM must be 16 KB to 4 MB. Bank numbers are 8-bit, so ROMs on 8 KB-bank mappers can reach 2 MB, and ASCII16 can reach 4 MB.
- **Coverage:** openMSX's database lists 2,717 MSX titles. 2,445 of them have a dump of a type AmiMSX maps. The rest are mostly 16 KB ROMs that sit at 8000h, many of them BASIC programs (246 titles), the SRAM variants of ASCII8/ASCII16 and Koei (38 titles), and about 30 one-off mappers.
- **The guess:** for 79 of the 314 known megaROMs in the maintainer's sets (25%), the guess picks the wrong mapper. Most of these are ASCII16 or ASCII8 games guessed as Konami SCC. This is the main case for a database.
- **8 KB ROMs:** AmiMSX refuses every 8 KB ROM ("Bad MSX Cartridge size"). That is 4 of the Top 100 and 61 images in the maintainer's commercial sets.
- **Top 100:** 84 entries are ROMs. 76 of them load with the right mapper today. Of the 76:
  - Deep Dungeon has no SRAM;
  - Uwol, Monster Hunter and MSX Wings get the right mapper only from a tag in the file name.

  These 8 don't:
  - 4 are 8 KB;
  - 2 are over 4 MB (Neon Horizon and MSX Legends, both ASCII16-X);
  - 2 are 16 KB BASIC ROMs that AmiMSX maps at the wrong address.
- **AmiMSX's checksum:** the 29-bit word sum gave no collisions among the 381 megaROMs in the maintainer's sets. The database itself only has SHA-1s, though. So a full database needs SHA-1 on the Amiga, and the sum can only key entries the generator has actually seen.

## 1. What AmiMSX supports today

### Mapper tables

`DirPrefs+$76` (Slot 1) and `+$77` (Slot 2) index tables of 8 longwords, one per 8 KB page of the Z80 address space (0000h, 2000h ... E000h). Each entry is the write handler for that page. The tables are `Mapper0`..`Mapper6` for Slot 1 and `Mapper0b`..`Mapper6b` for Slot 2. Bank setters:

- `Pag0S1`..`Pag3S1`: 8 KB banks at 4000h/6000h/8000h/A000h.
- `Asc26`/`KON18`: 16 KB banks at 4000h/8000h.

| Index | Menu name | Write decode | openMSX type |
|---|---|---|---|
| 0 | Standard | none | Mirrored / Normal (plain ROM) |
| 1 | Konami 1 | any write in 8000h-BFFFh selects the 16 KB bank at 8000h (`KON18`); 4000h-7FFFh fixed | none exactly; the 8000h half of `16kb` (Generic 16 KB). The shipped mapper file has one Konami 1 entry: the checksum the old `MegaROMsId` table gives for Andorogynus (ASCII16 in openMSX, with one `16kb` dump) |
| 2 | Konami 2 | any write in 6000h-7FFFh, 8000h-9FFFh, A000h-BFFFh selects that 8 KB page's bank; a write to exactly 4000h selects 4000h-5FFFh | `Konami` (Konami4, no SCC) |
| 3 | ASCII 1 | 6000h/6800h/7000h/7800h-7FFFh select 4000h/6000h/8000h/A000h (handler named `Asc16`, but it is ASCII8) | `ASCII8` |
| 4 | ASCII 2 | 6000h-6FFFh selects 16 KB at 4000h, 7000h-7FFFh at 8000h (`Asc26`) | `ASCII16` |
| 5 | SCC 1 | 5000h-57FFh, 7000h-77FFh, 9000h-97FFh, B000h-B7FFh (as on the cartridge; fixed in 4.0) | `KonamiSCC` |
| 6 | SCC 2 | exactly 5000h, 7000h, 9000h, B000h | `KonamiSCC` (a stricter, legacy decode) |

"Konami 1" and "Konami 2" are AmiMSX's own names. Konami 2 is openMSX's `Konami` (often called Konami4). Konami 1 is not a Konami mapper at all. AmiMSX doesn't mirror megaROM banks into 0000h-3FFFh or C000h-FFFFh (openMSX added that for the Konami types).

### Flash Konami SCC (12 Oct)

- **What it does:** `SCC16` traps writes to 7FFFh (`FlashReg`). Bit 4 set turns on `FlashOn`, and from then on writes in 4000h-BFFFh go to an AMD flash command machine (`FlashW`):
  - unlock AAh at xAAAh, then 55h at x555h;
  - A0h: program one byte (AND into the image);
  - 80h + unlock + 30h: erase the 64 KB sector (8 banks).
- **Timing:** every operation completes instantly.
- **When it applies:** only if `NumROM` > 64 (ROMs over 512 KB), and only in Slot 1 (the `b` handlers have no flash).
- **Saves:** they change the image in memory but are not written to disk.
- **Gaps against openMSX's `KonamiUltimateCollection`:** this covers its flash commands, but not its offset register or its other mode bits (Konami4 mode, mapper disable). Pampas & Selene and DEVA (`RBSC_Flash_KonamiSCC`) need no more than this.
- **Manbow 2:** at exactly 512 KB it stays outside the gate.

### Sizes and bank counts

- **File size:** `MiraMSXCartSize` accepts 16 KB to 4 MB (at most 256 × 16 KB). The tail past the last whole 16 KB is loaded but not counted. Under 16 KB is refused.
- **Bank numbers** are read with `MOVE.B` (`BankNum`):
  - 8 KB-bank mappers (Konami, SCC, ASCII8) reach 256 × 8 KB = 2 MB, and `MaskROM` is capped at FFh;
  - ASCII16 and the 16 KB setters reach 256 × 16 KB = 4 MB.
- **Odd sizes:** a bank number below the bank count is used as is, and anything higher is masked (so 1088 KB Barbarian works).
- **Which ROMs get a mapper:** ≤ 32 KB is plain. 16 KB goes at 4000h, or at 8000h if the INIT address has bit 15 set. 32 KB goes at 4000h-BFFFh. 48/64 KB linear ROMs (no "AB" at 0, "AB" at 4000h) map from 0000h with no mapper (`MiraLin`). Every other ROM of 48 KB or more uses the selected mapper.

### How the mapper is chosen (Menu)

`InsertSl1` → `MiraCheckCart`:

1. **Size:** under 48 KB, or a linear 48/64 KB ROM: Standard.
2. **Saved choice** (`MiConMapper` → `MiChCaRut`): look the cartridge's checksum up in `AmiMSX2.mapper`.
3. **File-name tag** (`TagMapper`): `[KonamiSCC]`, `[SCC]`, `[Konami]`, `[Konami4]`, `[ASCII8]`, `[ASCII16]` (any case). `[auto]` and others are ignored.
4. **Guess** (`GuessMapper`, openMSX's method):
   - counts `LD (nn),A` writes to each mapper's register addresses;
   - ties go to the later type in the order ASCII8, ASCII16, Konami, Konami SCC;
   - when nothing matches it falls back to SCC 1.

The code returned is the index minus 1 (0 = Konami 1 ... 5 = SCC 2). Per-game `<cartridge>.prefs` files hold sound and sprite settings, not the mapper.

## 2. What MSX software needs (openMSX database)

- **Scope:** the `MSX`, `MSX2` and `TURBO-R` entries only. ColecoVision (631 dumps) and SVI (11) are left out, which leaves 7,463 SHA-1s across 2,717 titles. No SHA-1 appears under two types.
- **Commercial or homebrew:** the database has no homebrew flag. Here, "commercial" means year ≤ 1995 and "homebrew" year ≥ 1996.

### Types AmiMSX maps

| openMSX type | Dumps | Titles | Commercial | Homebrew | No year |
|---|---|---|---|---|---|
| Mirrored (plain) | 3,941 | 1,561 | 969 | 547 | 45 |
| KonamiSCC | 1,258 | 489 | 316 | 159 | 14 |
| ASCII8 | 657 | 357 | 264 | 89 | 4 |
| ASCII16 | 577 | 315 | 278 | 30 | 7 |
| Konami | 392 | 97 | 76 | 20 | 1 |
| Normal (64 KB / start address) | 91 | 57 | 23 | 34 | 0 |
| page12 (32 KB at 4000h) | 11 | 9 | 9 | 0 | 0 |

### Types AmiMSX lacks or only partly has

"Only" = titles whose every dump is of this type (no supported alternative).

| openMSX type | Dumps | Titles | Comm. / Home | Only | Status in AmiMSX | Notable titles |
|---|---|---|---|---|---|---|
| page2 (16 KB at 8000h) | 282 | 246 | 162 / 49 | 218 | Partial: right only if INIT ≥ 8000h; BASIC ROMs (INIT 0, TEXT 8010h) land at 4000h | BASIC-program carts, type-ins, Bakerman, Mission2Mir |
| GenericKonami | 43 | 34 | 31 / 2 | 4 | Close to Konami 2 (4000h page also switchable) | Arkanoid 2, AshGuine Story I-III, Craze, Dragon Quest 2, Pit Stop |
| 16kb (Generic 16 KB) | 25 | 21 | 19 / 2 | 0 | Konami 1 does the 8000h half | Andorogynus, Acrojet, Fantasy Zone 2, King's Knight, Magical Stones |
| 8kB (Generic 8 KB) | 23 | 12 | 8 / 2 | 3 | Konami 2 covers 6000h-BFFFh | Vampire Killer, Zanac A.I., Hydlide 3, Uchu Yohei (2023), Flight Deck |
| KoeiSRAM32 | 24 | 17 | 17 / 0 | 16 | None (banks are ASCII8-like, SRAM 8 KB pages) | Nobunaga no Yabou series, Genghis Khan, Sangokushi, Royal Blood, Daikoukai Jidai, Inindo |
| ASCII8SRAM8 | 16 | 10 | 10 / 0 | 6 | Banks only (ASCII 1), no SRAM | Xanadu, Heroes of the Lance, Ultima III, Deep Dungeon 2, Game Master 2 (one dump) |
| ASCII16SRAM2 | 12 | 5 | 5 / 0 | 4 | Banks only (ASCII 2) | Hydlide 2, Daisenryaku, Super Daisenryaku, Harry Fox MSX Special |
| ASCII8SRAM2 | 5 | 5 | 5 / 0 | 4 | Banks only (ASCII 1) | Deep Dungeon 1/2, Dires, Kisei, Elthlead |
| ASCII16SRAM8 | 3 | 1 | 1 / 0 | 1 | Banks only | A-Train |
| manbow2 / Manbow2_2 | 12 | 3 | 0 / 3 | 1 | SCC 1 runs them; flash off at ≤ 512 KB | Manbow 2, Lotus F3, Pengo |
| KonamiUltimateCollection | 5 | 2 | 0 / 2 | 0 | Partial (flash mode, no offset register) | Konami Ultimate Collection, Pampas and Selene |
| RBSC_Flash_KonamiSCC | 1 | 1 | 0 / 1 | 1 | Works (flash mode) | Angelic Warrior DEVA |
| ASCII16-X | 3 | 2 | 1 / 1 | 1 | None; also over 4 MB | MSX Legends (2025), an Illusion City dump |
| Synthesizer | 10 | 1 | 1 / 0 | 1 | None (DAC) | Konami's Synthesizer |
| R-Type | 8 | 2 | 2 / 0 | 0 | None | R-Type, Quinpl |
| MatraCompilation | 6 | 5 | 0 / 5 | 0 | None | Konami / Casio compilations (2010), Cardwork Orange |
| Zemina 25/80/90/126-in-1 | 12 | 7 | 1 / 1 | 3 | None | Game World multicarts |
| Mirrored4000 | 3 | 2 | 2 / 0 | 1 | None | Flash Point, Super Chess |
| GameMaster2 | 2 | 1 | 1 / 0 | 0 | None (Konami-like banks + SRAM) | Konami's Game Master 2 |
| CrossBlaim, HarryFox, SuperLodeRunner, Majutsushi, Halnote, Wizardry | 2-3 each | 1 each | all commercial | 2 | None | Cross Blaim, Harry Fox Yuki no Maou, Super Lode Runner, Hai no Majutsushi (DAC), Halnote (SRAM), Wizardry (SRAM) |
| WonderKid, SuperSwangi, Arc, dooly, Playball, NettouYakyuu | 1-2 each | 1-2 each | all commercial | 1 | None | Wonder Kid, Aliens 2, Super Altered Beast, ARC, Dooly, Playball (samples), Nettou Yakyuu '88 (samples) |
| ReproCartridgeV1/V2 | 3 | 3 | 3 / 0 | 1 | None | Metal Gear repro carts |
| YAMANOOTO, HamarajaNight, RetroHardMultiCart31in1, MatraInk | 1-2 each | 1-2 each | homebrew | 3 | None | Nightstalker (2024), Best of Hamaraja Night (2010), 31-in-1 multicarts (2019), INK |
| AlQuran(Decoded), AlAlamiah30-in-1, MSXWrite, Keyboardmaster | 1-3 each | 1-3 each | mixed | 4 | None | Non-game ROMs |

**Not in the database at all.** NEO-8/NEO-16 (a concept mapper in openMSX, used by no game yet), MegaFlashROM SCC+ (a flash cartridge extension), FM-PAC (MSX-Music with 8 KB SRAM: a sound device, not a game mapper) and Panasoft (machine-internal ROMs). Hydlide 2 appears as ASCII16SRAM2 above.

**Per title:**

| Era | MegaROM titles: a supported dump exists | None | Plain titles: supported | Not (mostly page2) |
|---|---|---|---|---|
| Commercial (≤ 1995) | 742 | 40 | 812 | 149 |
| Homebrew (≥ 1996) | 286 | 5 | 535 | 37 |
| No year | 25 | 6 | 45 | 35 |

So the MSX homebrew scene sticks to the four standard megaROM types. The newer exceptions are flash Konami SCC carts (Pampas, DEVA, Manbow 2), ASCII16-X (over 4 MB), Yamanooto and the Matra compilations.

## 3. The maintainer's sets

### MSX Top 100 (`top_MSX1.tsv`, files on `R:`)

84 entries are ROMs, 15 disks and 1 a tape. 81 of the 84 ROMs are in the database.

| # | Title | Size | openMSX type | AmiMSX today | Problem |
|---|---|---|---|---|---|
| 3 | Neon Horizon | 8 MB | not in DB (ASCII16-X per msx.org) | Refused (over 4 MB) | Needs ASCII16-X and > 4 MB; its music is OPL4 (PSG without it) |
| 67 | MSX Legends | 8.6 MB | ASCII16-X | Refused (over 4 MB) | Same |
| 36, 57, 59, 84 | Sink King, Nohzdyve, Kralizec 8K Tetris, Kralizec Battle Tetris | 8 KB | Mirrored | Refused (under 16 KB) | 8 KB support |
| 96, 97 | Bakerman, Mission2Mir | 16 KB | page2 (BASIC, INIT 0, TEXT 8010h) | Mapped at 4000h | Wrong page; also need MSX-BASIC (not in C-BIOS) |
| 56 | Deep Dungeon | 128 KB | ASCII8SRAM2 | ASCII 1 (guess right) | No SRAM |
| 2 | Pampas & Selene | 2 MB | not in DB (KonamiUltimateCollection by test) | SCC 1 + flash | Runs since 12 Oct; saves in memory only |
| 40 | Angelic Warrior DEVA | 2 MB | RBSC_Flash_KonamiSCC | SCC 1 (tag) + flash | Runs; saves in memory only |
| 18 | Lotus F3 | 128 KB | manbow2 | SCC 1 (tag) | Runs (set 2) |
| 14 | Uwol | 256 KB | ASCII8 | ASCII 1 from the tag; the guess says Konami 2 | Tag-dependent |
| 54 | Monster Hunter | 128 KB | KonamiSCC | SCC 1 from the tag; the guess says Konami 2 | Tag-dependent |
| 78 | MSX Wings | 3.97 MB | ASCII16 | ASCII 2 from the tag; the guess says SCC 1 | Tag-dependent |
| 100 | Chikubi Ninja | 64 KB | not in DB | Standard (linear) | None |

The ROMs not listed above get the right mapper or placement today.

### `run/Roms` (82 files)

- **In the database:** 67. Not in it:
  - 9 test ROMs (`T_*`);
  - Pampas & Selene, Neon Horizon, DELTA (4 MB, `[ASCII16]` tag), Neon Revenant MSX1/MSX2 (`[ASCII8]` tags), Chikubi Ninja.
- **Wrong mapper:** `014_UwolQuestforMoney.rom` has no tag, so AmiMSX guesses Konami 2. openMSX says ASCII8. This is not checked in WinUAE.
- **Missing or partial mapper types:**
  - `R2_LotusF3` (manbow2);
  - `R2_DEVA` (RBSC flash);
  - `002_PampasSeleneTheMazeofD` (KonamiUltimateCollection);
  - `R2_NeonHorizon` (over 4 MB).
- **From the saved file:** `R2K_KingsValley2` gets SCC 2, which works.

### The wider sets (No-Intro MSX/MSX2, aftermarket, Top 100, run/Roms)

- **Images:** 1,372 unique. The database knows 1,349 of them (98%).
- **MegaROMs:** 381 take the megaROM path, and the database knows 371 of them.
  - **Supported types (314):** the guess is wrong for 79 (25%): 54 ASCII16, 22 ASCII8, 2 Konami and 1 Konami SCC. Most come out as Konami SCC (the tie rule and the fallback) or as Konami.
  - **Unsupported types (57):** Koei, the SRAM variants, R-Type, Game Master 2 and others.
- **8 KB images:** 71 (61 in the commercial sets). All are refused today.
- **"OPLL":** 36 images contain the string, the signature MSX-Music games look for.

## 4. How a cartridge is identified today

### Checksum (`CalCheckCart`)

The checksum is computed straight after loading (and after xpk/IMP!/stc unpacking), before the 8 KB pages are spaced out to $2080:

```
sum = 0
for each big-endian 16-bit word in the first PagCart * 16 KB of the file:
    sum += word            (32-bit, unsigned)
CheckId = sum & 1FFFFFFFh  (29 bits)
```

`PagCart` = file size / 16 KB, rounded down. So bytes past the last whole 16 KB are not counted, and an 8 KB file would sum to 0. The Python port matches the source's own table: the `MegaROMsId` table (commented out in the Menu source) lists Nemesis 2 as `06521A69`, Nemesis 3 as `0256E6AB` and Salamander as `0815423B`, which are the sums of `R2K_Nemesis2/3` and `R2K_Salamander`.

### `AmiMSX2.mapper` (the saved-mapper database)

This file is a saved-mapper database keyed by that checksum, and it already ships with 39 entries.

| Offset | Size | Contents |
|---|---|---|
| 00h | 16 | `"AmiMSX2",0,"Mappers",0` (the load checks `"Mapp"` at 08h) |
| 10h | word | Number of entries (the save stops at FFFFh) |
| 12h | word | 0 |
| 14h | long | Registered user number (`FFFF9D1B` here) |
| 18h | 4 × n | Entries: bits 31-29 = mapper code (index − 1, so 0-5 used, 6-7 free), bits 28-0 = checksum |

- **Lookup:** a linear scan; low word first, then the full 29 bits.
- **Saving:** Save Mapper ID appends to or updates the file.
- **The shipped entries:**
  - by mapper: 15 ASCII 1, 6 Konami 2, 6 ASCII 2, 6 SCC 1, 5 SCC 2, 1 Konami 1;
  - 26 match ROMs in the maintainer's No-Intro sets, and all 26 agree with openMSX. Three SRAM games are saved with their nearest bank type: Game Master II as Konami 2, Xanadu as ASCII 1, Royal Blood as ASCII 1;
  - the copy in a local drive is identical.
- **Limit:** with 3 bits there is room for only 2 more mappers.

### Collisions

- **MegaROMs:** across the 1,372 images, none of the 381 shares a sum with another.
- **Other equal sums:** only the 8 KB files (all 0) and two overdumps (16,385 and 16,417 bytes) that equal their good dumps in the counted part.
- **Odds for the whole database:** about 3,500 non-plain dumps in 2^29 sums. For random values that gives roughly a 1% chance of any collision. The sum doesn't change when words are reordered, but a collision only matters if the two ROMs need different mappers. Keying on sum plus `PagCart` makes it rarer still.
- **The catch:** the sum can only be computed from a ROM file. openMSX's database has SHA-1s only, so a sum-keyed table covers just the ROMs the generator has been given.

## 5. Proposal: a ROM database for AmiMSX

### Keys

- **Section S (sum):** the 29-bit sum plus `PagCart`, for every ROM the generator can read (the maintainer's sets: about 380 megaROMs). Free on the Amiga, because `CalCheckCart` already runs.
- **Section H (SHA-1):** the first 4 bytes of the SHA-1, for every non-plain database dump (3,522 SHA-1s). 3-, 4- and 5-byte prefixes are all unique across the database, and a false match on an unknown ROM has odds of about 1 in 1.2 million.
  - **When:** only on the megaROM path, or for a 16 KB ROM with INIT 0, and only when there is no saved or section-S hit.
  - **Where:** over the file data before the pages are spaced out (next to `CalCheckCart`), using the full file length.
  - **Cache:** the result goes into the saved-mapper file, so each ROM is hashed once.
- **Cost estimate** (not measured): about 1,500 instructions per 64-byte block.
  - A1200 (68020, 14 MHz): about 1 s per 128 KB, so 4 s for 512 KB and about 30 s for 4 MB.
  - 68030/50: about 4× faster.
  - PiStorm/Emu68: negligible.

  A prefs setting would control it: SHA-1 identify = Auto (always on 030 and up; on the 020 up to 512 KB), Always or Never.

### File: `AmiMSX4.romdb` (big-endian, generated)

| Part | Layout | Size |
|---|---|---|
| Header | `"AMXROMDB"`, version.w, nS.w, nH.w, nNames.w, offsets | 24 bytes |
| Section S | sum.l, pages.w, mapper.b, hints.b; sorted (binary search) | 8 × ~400 = 3 KB |
| Section H | sha1[0..3].l, mapper.b, hints.b; sorted | 6 × 3,522 = 21 KB |
| Names | openMSX type names for mappers AmiMSX lacks (for the message) | under 1 KB |

That is about 25 KB in all. Titles are optional and would go in a separate file of about 100 KB.

- **mapper.b:** the AmiMSX table index: 0 Standard, 1-6 as today, new ones from 7. `80h + n` = a known type AmiMSX doesn't emulate (n indexes Names). The menu can then say "needs the Cross Blaim mapper" instead of running a wrong guess.
- **hints.b:**
  - bits 0-1: machine (0 MSX1 or unknown, 1 MSX2, 2 turbo R);
  - bit 2: MSX-Music (FM);
  - bit 3: SCC+;
  - bits 4-6: SRAM (0 none, 1 = 2 KB, 2 = 8 KB, 3 = 16 KB, 4 = 32 KB);
  - bit 7: flash.

### Lookup order on insert

1. **Size rules:**
   - 8 KB: mirrored to 16 KB (new);
   - up to 32 KB: plain, except page2 BASIC (below);
   - linear 48/64 KB: Standard.
2. **Saved user choice:** the saved-mapper file.
3. **Section S** (sum + pages).
4. **Section H** (SHA-1 prefix). Store the hit in the saved-mapper file with a "from database" flag, so an explicit user choice stays distinct and wins.
5. **File-name tag.** It sits below the database because tags can be coarser than the database (`MSX Legends[ASCII16]` is really ASCII16-X).
6. **The guess.**

**The saved file:** the current one has room for only 2 more mapper codes. Use a new `AmiMSX4.mapper` with 8-byte records (sum.l, pages.w, index.b, flags.b). Read the old `AmiMSX2.mapper` on first run and convert it.

### Generator: `tools/make_romdb.py` (plan)

- **Inputs:**
  - `--db` (default `tools/openmsx/share/softwaredb.xml`);
  - `--scan DIR ...` (ROM folders and zips, read in memory);
  - `--mapfile AmiMSX2.mapper` (import the old entries);
  - `--out run/AmiMSX4.romdb`;
  - `--titles` (optional names file).
- **Steps:**
  1. Parse the database; keep MSX/MSX2/TURBO-R.
  2. Map each type to an AmiMSX index, or to 80h+n.
  3. Hints:
     - machine from `<system>`;
     - SRAM and flash from the type name;
     - FM from remarks (weak) and, for scanned files, from an "OPLL" search;
     - SCC+ from writes to BFFEh (optional).
  4. For each scanned file:
     - compute the AmiMSX sum (port of `CalCheckCart`), `PagCart` and SHA-1;
     - take the type from the database, or else from a file-name tag;
     - skip files with neither (the Amiga guesses those).
  5. Drop any (sum, pages) pair that two different mappers share (they fall back to SHA-1), and report it.
  6. Write the sections sorted, big-endian.
- **Self-test:**
  - run every scanned file through the Amiga lookup order and compare the result with openMSX;
  - check that the 4-byte SHA-1 prefixes are unique;
  - test vectors: Nemesis 2 = `06521A69`, Nemesis 3 = `0256E6AB`.
- **Report:** counts per type, plus the unsupported titles found in the scanned sets.

### Machine and sound settings

Per-game `.prefs` files already hold the sound chip (`DirPrefs+$1D`: 0 PSG, 1 SCC, 2 SCC+, 3 PSG+FM), MSX2 sprites and the edge mask. Two of their 12 bytes are spare. Order of precedence: the `.prefs` file, then database/heuristic hints, then the global settings.

- **SCC:** a Konami SCC mapper turns SCC on. This exists already (`GPLoadNone`, mappers 5/6). Extend it to the flash SCC types and to SCC+ when hints bit 3 is set.
- **FM:**
  - **The signal:** "OPLL" in the ROM means the game looks for MSX-Music.
  - **The rule:** switch PSG → PSG+FM once FMX is in the build.
  - **Cost:** the check costs nothing if it is added to `GuessMapper`'s byte loop, which already reads the whole ROM.
  - **Top 100 games with "OPLL":** Uwol, Lilly's Saga, Head over Heels, Batman, DEVA, Dreams Puzzle, Heroes Arena, J.E.T.P.A.C., Vectroids, Bomb Jack, Barbarian.
  - **Conflicts:** Head over Heels, Batman, DEVA and Vectroids are also Konami SCC carts. Keep SCC for those unless the maintainer's `.prefs` file says otherwise.
- **Machine:** the database's `<system>` (MSX2 needed). Show it as a warning when the machine is MSX1. MSX2+ isn't marked in the database.
- **SRAM:** when the SRAM types exist, keep it in `<cartridge>.sram` next to the ROM, in the same way as `.prefs`. Flash carts could save their changed 64 KB sectors to the same file.

## 6. Implementation order

The handler pattern is the same for each mapper:

- a 32-byte table of 8 page handlers, appended after `Mapper6`/`Mapper6b` (`DirPrefs+$76` is used × 32);
- bank setters reused from `Pag0S1`..`Pag3S1` and `KON18`/`Asc26`, with slot 2 copies;
- a menu item and a code in the saved-mapper file.

Effort: tiny = table entries only; small = up to half a day; medium = 1-2 days.

| Step | Work | Top 100 | Wider sets / database | Effort |
|---|---|---|---|---|
| 1 | Accept 8 KB ROMs: mirror them to 16 KB at load (placement as today) | #36, #57, #59, #84 | 61 commercial images | Small |
| 2 | ROM database, SHA-1, `AmiMSX4.mapper` and the "needs mapper X" message | Removes the tag dependence of #14, #54, #78; fixes the untagged Uwol in `run/Roms` | Fixes 79 of 314 wrong guesses | Medium |
| 3 | Generic 8 KB, Generic 16 KB (make Konami 1 the full version) and GenericKonami, done with step 2 so database codes map one to one | - | 67 titles (7 have no other dump) | Tiny |
| 4 | Page-2 BASIC ROMs: map at 8000h when INIT is 0 and TEXT ≥ 8000h, or when the database says page2 | #96, #97 (need the original `AmiMSX2.data`: C-BIOS has no BASIC) | 246 titles, 45 images in the sets | Small |
| 5 | SRAM: ASCII8SRAM2/8, ASCII16SRAM2/8, Koei; `.sram` file | #56 | 38 titles (Xanadu, Hydlide 2, A-Train, Koei) | Small-medium |
| 6 | ASCII16-X and ROMs over 4 MB (12-bit banks from data plus address bits; larger size and bank limits) | #3, #67 | 2 titles (both 2025) | Medium-large. Needs about 9 MB of RAM, so in practice only PiStorm/BigMig |
| 7 | Flash: gate it on the database type, not size (so Manbow 2 at 512 KB gets it too); add Slot 2; save sectors to disk; the KonamiUltimateCollection offset register | #1, #2, #18, #40 saves | 6 titles | Medium |
| 8 | Rare commercial mappers: R-Type, Cross Blaim, Harry Fox, Super Lode Runner, Wonder Kid, Super Swangi, Zemina, Dooly, Mirrored4000 | - | 1-3 titles each | Small each |
| 9 | SRAM/DAC specials: Game Master 2, Halnote, Wizardry, Majutsushi, Synthesizer, Playball, Nettou Yakyuu; and Yamanooto | - | 1 title each | Medium each; low value |

Steps 1-4 cover every Top 100 ROM except the two ASCII16-X titles, and they fix a quarter of the commercial megaROMs. Before coding steps 6-9, check the exact register decodes in openMSX's source (`src/memory/Rom*.cc`). The table above only summarises them.
