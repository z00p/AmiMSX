# AmiMSX regression set 2: candidate titles

*Research date: 1 October 2026. This was web research only. Nothing was downloaded or installed.*

## Summary

This list proposes software for a second AmiMSX regression set. Each entry is chosen for the MSX hardware behaviour it stresses. The 34 ROMs already in the regression set are not repeated as new finds; they only appear where they help a comparison. Cross-reference used: the maintainer's MSX Top 100 list. Titles marked **(have)** are already in the maintainer's collection.

Main findings:

- **The best freely available stress tests are demos, not games.** msx.org keeps a list of 25 productions "known to be hard to emulate" (Unknown Reality, Bombaman, TNI's Bounce, Maggoo's scrollers, Aleste 2, SD Snatcher and others). The MSX1 demos *io* (Logon System) and *MSX Unleashed* (Dvik & Joyrex) are documented as failing on many real machines and emulators because they depend on exact cycle and VDP timing.
- ***io* has a built-in pass/fail check.** At start-up it uses the 5th-sprite flag (S#0 bit 6) as a raster trigger and prints "sync by 5S accurate" when the timing is right. AmiMSX already emulates 5S for Uridium, so this is the most directly useful single test.
- **Modern MSX2 homebrew increasingly uses heavy techniques.** Examples: Neon Horizon (about 20 line interrupts per frame plus page swapping), DELTA (4 MB ASCII16 with an SCC in a separate slot, a 3D engine and page flipping), Angelic Warrior DEVA (freeware since December 2025; SCREEN 4 multidirectional parallax and sprite masking) and Maiden's Extreme Fist (MSX2 with SCC).
- **There are many "same game, different hardware" pairs for Part 2.** Free ones: Neon Revenant (separate MSX1, MSX2, turbo R and V9990 ROMs), Monster Hunter (PSG, or SCC when the KonamiSCC mapper is chosen), Chikubi Ninja (already tested; R#18 path on MSX2, R#26/27 path on MSX2+) and Uridium vs Uridium 2. There are also free community patches for Konami ROMs: Maze of Galious MSX2, Vampire Killer SCC, and smooth-scroll patches for Salamander, Nemesis 3 and Gradius 2. Those patches are free, but the base ROMs are commercial.
- **Some areas fall outside AmiMSX's current scope:**
  - **No FM sound:** the v3.1 guide lists only PSG, SCC and SCC+. MSX-MUSIC, MSX-AUDIO and OPL4 titles are listed for completeness only.
  - **No V9958 (MSX2+ VDP):** YJK, R#25, R#26 and R#27 titles mainly show whether the MSX2 fallback works.
  - **Sprite collision:** the v3.1 guide says sprite collisions and expanded sprites are not emulated. The source shows collision as an optional mode, so check the current state before reading collision-based results.

Availability legend used in the tables:

| Tag | Meaning |
|---|---|
| **FREE** | Homebrew, freeware, MSXdev entry or demo with an author/official download page. **Can go in the test set.** |
| **FREE-PATCH** | The patch is free, but it needs a commercial base ROM you must own. |
| **FREE-DEMO** | A free demo version of a commercial game. |
| **GREY** | Freely circulated, but the licence or IP status is unclear (fan ports of commercial IP, or a former pay-download). |
| **COMM** | Commercial only. Listed as a reference torture test, not for the free set. |

"Unverified" means I could not confirm the claim from a source during this research.

---

## Part 1: titles that push the hardware hardest

### 1A. Demos (all FREE unless noted). These are the strongest emulator tests.

| Title | Year | Author | Machine | Media | Tricks stressed | Avail. | Source |
|---|---|---|---|---|---|---|---|
| **io** | 2015 | Logon System (Overflow, CeD, aKi/Factor6) | MSX1 | Disk (zip) | **5S flag (S#0 bit 6) used as a raster trigger.** Assumes exactly 313 lines × 228 cycles per line and constant-time frame code. Screen 1 with per-line switching between 8 charsets and colour tables. Self-check message "sync by 5S accurate". Fails on several real MSX1s and on turbo modes. openMSX needed a fix to report 5S at the moment the VDP reads the offending sprite (PR #2211). | FREE | [pouet 65232](https://www.pouet.net/prod.php?which=65232), [openMSX PR #2211](https://github.com/openMSX/openMSX/pull/2211) |
| **MSX Unleashed** | 2006 | Dvik & Joyrex | MSX1 | Disk | Effects "never seen before on MSX1": 105-colour images, horizontal bars and a **border scroller**, all raster tricks. The authors say no emulator showed every effect correctly at release, and some effects fail on MSX2+ and turbo R. | FREE | [pouet 30853](https://www.pouet.net/prod.php?which=30853), [msx.org](https://www.msx.org/news/software/en/msx-unleashed) |
| **Bold** | 2009 | Dvik & Joyrex | MSX1 | 64 KB demo (zip) | Character-mode effects (roulette, checker zoom, plasma, tunnel) with **sprite overlays masking blockiness**, parallax, and heavy VRAM streaming. Ranked #1 MSX demo on pouet. | FREE | [pouet 54051](https://www.pouet.net/prod.php?which=54051) |
| **Invasion of the Big Pixels** | 2008 | Noice | MSX1 (64K RAM / 16K VRAM) | Executable | Plasma and dithering at full rate. Pure MSX1, so a good TMS9918 colour and pattern throughput test. | FREE | [pouet 52340](https://www.pouet.net/prod.php?which=52340) |
| **Riyadh** | 2001 | Bandwagon | MSX1 | Disk | Pseudo-3D effects in the style of mid-90s consoles. Assembly 2001 winner. | FREE | [pouet 7662](https://www.pouet.net/prod.php?which=7662) |
| **Avaakkus** | 1998 | Lieves!Tuore | MSX (exact generation unverified) | .lha / .dsk | Low-res effects and a well-regarded Z80 3D part. On msx.org's "hard to emulate" list. | FREE | [pouet 9897](https://www.pouet.net/prod.php?which=9897), [msx.org testing](https://www.msx.org/articles/testing-methods) |
| **Unknown Reality** | 1994 | NOP | MSX2, 256K RAM | Disk (scene.org 7z) | **Pixel-accurate horizontal splits.** openMSX was among the first emulators to run it glitch-free. Needs MSX-MUSIC plus MSX-AUDIO with 256K, so audio will be missing on AmiMSX. | FREE (originally sold, now on scene.org) | [pouet 30145](https://www.pouet.net/prod.php?which=30145), [openMSX features](https://openmsx.org/features.html) |
| **TNI Bounce** | 2004 | TNI | MSX2 + MSX-MUSIC | Disk | Multi-layer bouncing raster effects. Exposed a display bug fixed in openMSX 0.5.0. On the msx.org hard-to-emulate list. | FREE | [msx.org](https://www.msx.org/news/mrc/en/mrc-bounce-challenge-14th-entry-tni) |
| **Syntax Infinity** | 2009 | Tulou & Traktor | MSX2 (128K/128K), **PAL 50 Hz only** | Disk | Full-screen effects with tight CPU timing. Reported to break on MiSTer's MSX core (music speeds up, effects missing) and "does not run properly in emulators". | FREE | [pouet 52983](https://www.pouet.net/prod.php?which=52983), [MiSTer issue #26](https://github.com/MiSTer-devel/MSX_MiSTer/issues/26) |
| **Baltak Rampage** | 2016 | Traktor | MSX2 | Disk | VDP-bound effects. An open openMSX bug reports a wrong palette in the 2nd torus part and a 1-pixel offset in the greetings (blueMSX is correct), which suggests palette or adjust timing. | FREE | [pouet 67102](https://www.pouet.net/prod.php?which=67102), [openMSX #1015](https://github.com/openMSX/openMSX/issues/1015) |
| **Woei demo** | 1999-2009 | Team Bomba | MSX2, 128K | Disk + source | Logo and scroll, rotating background grid. **Needs MoonSound**, so no sound on AmiMSX. | FREE (with source) | [teambomba.net/woei](https://www.teambomba.net/woei.html) |
| **Maggoo's Vertical Sync Scroller / VScreen / Overscan scroller / 20th Anniversary demo** | ~2003 | Maggoo | MSX2 | Disk + source | Full-screen vertical scroll timed to vsync. Said "not to work on any emulator" except pixel-accurate openMSX. VScreen is a SCREEN 4 any-direction scroll engine; there is also an **overscan** (border removal) scroller with source. | FREE, but the original site is gone, so current download location is unverified | [msx.org](https://www.msx.org/news/websites/en/maggoos-msx-page), [msx.org testing](https://www.msx.org/articles/testing-methods) |

Other titles on msx.org's hard-to-emulate list whose details I did not verify: 20th anniversary demo (Maggoo), Almost Real (Mayhem), FAC Demo V, Multiplex (Maina), No Waste (Xelasoft), Relax (Anma), Sphere (Infinite), SWISS Demo, Turnix (FCS).

### 1B. Free homebrew and freeware games

| Title | Year | Author | Machine | Media | Tricks stressed | Avail. | Source |
|---|---|---|---|---|---|---|---|
| **Tales of Popolon** | 2017 | Santi Ontañón (Brain Games) | MSX1 | 32 KB ROM, 16 KB RAM | **Raycasting 3D engine on TMS9918.** Constant pattern/name-table streaming, CPU-bound, so it is a good performance/optimisation regression test. Open source. | FREE | [MSXdev'17 #4](https://www.msxdev.org/2017/03/22/msxdev17-4th-entry-tales-of-popolon/) |
| **XSpelunker** | 2017-ish | Santi Ontañón | MSX1 | ROM (size unverified) | Procedurally generated levels, Spelunky-like. Open source. Lower priority. | FREE | [Santi's blog](https://santiontanon.blogspot.com/2017/09/making-msx-games.html) |
| **Lotus F3** (have) | 2007 | Dvik & Joyrex (the maintainer's top-list says Kralizec; MSXdev and Generation-MSX credit dvik & joyrex) | MSX1 | 128 KB **Konami SCC** | **MSX1 smooth scrolling** (top-down racer) plus PSG+SCC music. | FREE (MSXdev'07) | [msx.org](https://www.msx.org/news/software/en/msxdev07-lotus-f3), [generation-msx](https://www.generation-msx.nl/software/dvik-joyrex-productions/lotus-f3/release/3749/) |
| **Maiden's Extreme Fist "BUN-GA-RUA"** (have) | 2024 | Retromixis (Tohji Murakata) | MSX2 (64K RAM, 128K VRAM) | 512 KB **Konami SCC** | MSX2 graphics with an SCC soundtrack. MSXdev24 winner (best sound). | FREE (MSXdev24 ROM; the later cartridge/SD edition is commercial) | [generation-msx](https://www.generation-msx.nl/software/retromixis-games/maidens-extreme-fist-bun-ga-rua/8564/), [msxdev](https://www.msxdev.org/2024/10/25/msxdev24-13-maidens-extreme-fist-bun-ga-rua/) |
| **DELTA** | 2026 | Bik5 (Jacco Bikker, Peter van Dranen) | MSX2, NTSC preferred | **4 MB ASCII16** + **SCC in another slot** | Custom 3D engine ("MSX3D"), real-time RLE decompression, **page flipping**, 20 fps. VGM playback in game; SCC menu music, so it needs a separate Konami SCC cartridge. Slows down on PAL. | FREE (MSXdev25 #30, 4th) | [author page](https://jacco.ompf2.com/delta-dodge-engage-launch-target-assault/), [msxdev](https://www.msxdev.org/2026/02/21/msxdev25-30-delta/) |
| **Neon Horizon** (have) | 2026 | Norakomi & Wolf | MSX2 + **OPL4 cartridge** | ROM, "ASCII16-X" per msx.org (the maintainer's dump is 8 MB and guessed as ASCII16; confirm the mapper) | SCREEN 5, road motion by **page swapping between pages 0/1 with different palettes**, **about 20 line interrupts plus VDP copies for 3-layer parallax**, 12-sprite characters, 60 fps. MSXdev25 winner. OPL4 is required, so sound will be absent. Whether it runs at all without OPL4 is unverified. | FREE (MSXdev25) | [msx.org #40](https://www.msx.org/news/challenges/en/msxdev25-40-neon-horizon) |
| **Angelic Warrior DEVA** (have) | 2020 (freeware 15 Dec 2025) | Team Deva | MSX2 / 2+ / turbo R, 128 KB | 2 MB MegaROM **with SRAM** (mapper unverified; the maintainer's file is tagged KonamiSCC) | **SCREEN 4 multidirectional parallax scrolling**, sprite masking (player passes behind pillars). Sound is MSX-MUSIC and/or MSX-AUDIO; whether there is a PSG fallback is unverified. | FREE (MRC download from the authors) | [msx.org freeware news](https://www.msx.org/news/software/en/angelic-warrior-deva-becomes-freeware), [arcade-history](https://www.arcade-history.com/?n=angelic-warrior-deva&page=detail&id=317921) |
| **Akin** | 1995 | Parallax (published by Sunrise) | MSX2 (MSX-MUSIC likely; unverified) | 2 × DSK | **Scrolling by VDP command copy** (HMMM-style blits) with optimisations, plus big animated sprites. | FREE (all Parallax games declared freeware, 2021) | [grauw scrolling guide](https://map.grauw.nl/articles/scrolling.php), [msx.org](https://www.msx.org/news/en/parallax-games-freeware), [MRC download](https://www.msx.org/downloads/akin) |
| **Bombaman / Bombaman Extra Ammo** (have Bombaman) | 2004 / 2008 | Team Bomba | MSX2, 128K/128K (the Team Bomba index lists Extra Ammo as MSX2+) | DSK | On msx.org's hard-to-emulate list (the specific trick is unverified). Needs MSX-MUSIC, MSX-AUDIO **or** MoonSound, so it may refuse to start on AmiMSX. | FREE | [teambomba.net](https://www.teambomba.net/bombaman.html) |
| **Batman - Free Edition** (have) | 2014 / free 2023 | FX Software | MSX2 | 752 KB Konami SCC (per the maintainer's dump) | Isometric V9938 rendering with lots of VRAM copying. | FREE (author blog) | [msx.org](https://www.msx.org/news/remakes/en/batman-msx2-remake-announced), [announcement](https://x.com/Dalekamistoso/status/1678367190406385666) |
| **Sonyc** | 1995 (freeware 2003) | Analogy (Manuel Pazos, Elvis Gallegos) | **MSX2+** (or MSX2 with V9958), 128K, **MSX-MUSIC required** | Disk | **R#26/R#27 horizontal hardware scroll.** Out of scope for AmiMSX (no V9958, no FM). Listed for completeness. | FREE (Sonic IP fan game, declared freeware by the authors) | [msx.org](https://www.msx.org/news/software/en/sonyc-goes-freeware), [grauw](https://map.grauw.nl/articles/scrolling.php) |
| **Megadoom** | 1993 | FCS / First Class Software | MSX2+ recommended (runs reduced on MSX2) | Disk (LZH on MRC) | **SCREEN 12 (YJK) plus scrolling.** Useful as an MSX2-fallback check. | On the MRC download DB; licence not stated (unverified) | [MRC](https://www.msx.org/downloads/games/shooters/megadoom), [MSX FAQ](https://www.faq.msxnet.org/msx2p.html) |
| **Manbow 2** (have) | 2007 | Norakomi / TNI (Sunrise) | MSX2 | 512 KB Konami SCC | Space Manbow-style splits and sprite handling. Named in an msx.org thread as a test for "interrupt and splitscreen". | GREY (once free on Sunrise's site, later a €4.95 download, no longer sold) | [msx.org TN-VDP thread](https://www.msx.org/forum/msx-talk/general-discussion/good-demos-for-testing-the-tn-vdp), [msx.org article](https://www.msx.org/articles/manbow-2) |
| **Super Mario World (MSX)** | 2020 | Daemos and MRC members | MSX2 | Large MegaROM (4 MB ASCII16 per Bikker's DELTA page) | Smooth-scrolling platform engine pushing MSX2. | GREY (Nintendo IP) | [GoNintendo](https://gonintendo.com/stories/368845-fan-takes-6-years-to-port-super-mario-world-to-the-msx) |

### 1C. Commercial reference titles (COMM: known torture tests, not for the free set)

| Title | Year | Publisher | Machine | Media | Tricks stressed | Source |
|---|---|---|---|---|---|---|
| **Space Manbow** | 1989 | Konami | MSX2 (better on 2+) | Konami SCC megaROM | SCREEN 4 with 8-pixel coarse scroll plus **R#18 adjust** for pixel scroll (**R#27 on MSX2+**, which fixes the border "chopping"). **Mid-screen sprite-table switching by polling line interrupts**, giving up to 64 sprites. | [grauw](https://map.grauw.nl/articles/scrolling.php), [msx.org thread](https://www.msx.org/forum/development/msx-development/spacemanbow-scrolling), [Wikipedia](https://en.wikipedia.org/wiki/Space_Manbow) |
| **Aleste** | 1988 | Compile | MSX2 | MegaROM | **R#23 vertical scroll** plus **sprite splits** that double the visible sprites. | [grauw](https://map.grauw.nl/articles/scrolling.php), [msx.org sprite split](https://www.msx.org/forum/msx-talk/development/sprite-split-0?page=2) |
| **Aleste 2** | 1989 | Compile | MSX2 | Disk | **4-bit PSG samples via rapid R#8 volume writes**, MSX-MUSIC. On msx.org's hard-to-emulate list. | [grauw PSG samples](https://map.grauw.nl/articles/psg_sample.php), [generation-msx](https://www.generation-msx.nl/software/compile/aleste-2/1246/) |
| **Psycho World** | 1988 | Hertz | MSX2 | MegaROM | Smooth horizontal scroll with set-adjust that **hides the jerky edges**; MSX-MUSIC + PSG. | [msx.org forum](https://msx.org/forum/msx-talk/general-discussion/top-scrolling-platform-games-on-the-msx?page=4), [VGMRips](https://vgmrips.net/packs/pack/psycho-world-msx2-fm) |
| **Quarth** | 1989 | Konami | MSX2 | Konami SCC | R#23 scroll, a **split screen** and blitter waits (FRS's TurboFix fixes "splitscreen" and "blitter wait" under turbo). | [grauw](https://map.grauw.nl/articles/scrolling.php), [FRS patches](https://frs.badcoffee.info/patches.html) |
| **SD Snatcher** | 1990 | Konami | MSX2 | Disk + **SCC+ cartridge with 64 KB RAM** | SCC+ (SCC-I) mode; on msx.org's hard-to-emulate list. | [MSX FAQ SCC](https://www.faq.msxnet.org/scc.html), [msx.org testing](https://www.msx.org/articles/testing-methods) |
| **Snatcher** | 1988 | Konami | MSX2 | Disk + SCC+ Sound Cartridge | SCC+ mode. | [MSX FAQ SCC](https://www.faq.msxnet.org/scc.html) |
| **Metal Gear 2: Solid Snake** | 1990 | Konami | MSX2 | Konami SCC megaROM | SCC, large Konami mapper ROM, no scrolling. | [msxblue SCC list](http://www.msxblue.com/manual/scc_c.htm) |
| **Nemesis 2 / Salamander / Nemesis 3 / F1 Spirit / Parodius** | 1987-88 | Konami | MSX1 | Konami SCC megaROMs | SCC; character-scroll engines and sprite flicker rotation. | [msxblue SCC list](http://www.msxblue.com/manual/scc_c.htm) |
| **Mechanical Brain** | 1996 | Studio Sequence | MSX2 | Disk (availability unverified) | Sprites used "for literally everything"; **sprite splits for more than 32 sprites**. | [msx.org sprite split](https://www.msx.org/forum/msx-talk/development/sprite-split-0?page=2) |
| **Hydefos** | (unverified) | (unverified) | MSX2 | (unverified) | Sprite split; 18 sprites used just for **border masking**. | [msx.org sprite split](https://www.msx.org/forum/msx-talk/development/sprite-split-0?page=2) |
| **Sex Bomb Bunny** | 1999 | Matra | MSX2 | Disk | **Moves display start mid-frame (R#18 / R#23 vertical adjust) during line interrupts**, which exposed an openMSX double-IRQ bug (PR #2191). A free demo version is on File-Hunter, but it is unverified whether it is downloadable or online-only. | [openMSX PR #2191](https://github.com/openMSX/openMSX/pull/2191), [File-Hunter demo](https://www.file-hunter.com/Homebrew/?id=sexbombbunny) |
| **Xevious: Fardraut Saga** | 1988 | Namcot / Compile | MSX2 | MegaROM | One of only 4 cartridge games with **MSX-AUDIO**; needs MSX-AUDIO in slot 1. | [MSX-AUDIO list](http://www.msxblue.com/manual/msxaudio_c.htm) |
| **Laydock 2: Last Attack** | 1991 | T&E Soft | **MSX2+** | Disk | Scroll + SCREEN 11/12. Possibly the most MSX2+-exclusive game. Uses a sample player and SAT double-buffering (from FRS's patch notes). | [MSX FAQ 2+](https://www.faq.msxnet.org/msx2p.html), [FRS patches](https://frs.badcoffee.info/patches.html) |
| **F1 Spirit 3D Special** | 1991 | Konami | MSX2+ | Disk | **R#26/27** used for the 3D effect, plus SCREEN 12 images. | [grauw](https://map.grauw.nl/articles/scrolling.php) |
| **Sea Sardine Side II** | 1991 | MSX Magazine (ASCII) | MSX2+ | Disk | R#26/27 horizontal scroll. | [MSX FAQ 2+](https://www.faq.msxnet.org/msx2p.html) |
| **Illusion City / Seed of Dragon** | 1991 / 1990 | Microcabin / Riverhill | MSX2+ / turbo R | Disk | On msx.org's hard-to-emulate list. Notably *not* using hardware scroll. | [msx.org testing](https://www.msx.org/articles/testing-methods), [msx.org forum](https://www.msx.org/forum/msx-talk/software/msx-2-2-plus-turbo-r-compatible-games-particularities) |

**Category gaps:**

- **Collision-flag splits:** the 5S / collision-flag MSX1 split technique is well documented (and AmiMSX already handles Uridium's S#0 = $5C poll). Apart from *io*, I found **no confirmed commercial game** that uses collision-flag splits.
- **Interlace and overscan:** no released game using them was identified. Maggoo's overscan scroller is the only concrete candidate.

### 1D. Non-game test programs (useful alongside)

- **VATT (VRAM Access Timing Tester):** measures safe OUT spacing per screen mode on TMS9918/V99x8. [msx.org thread](https://www.msx.org/forum/msx-talk/development/vatt-vram-access-timing-tester?page=3)
- **T471.COM:** the line-interrupt latch test written for openMSX PR #2191 (Sex Bomb Bunny case). [PR #2191](https://github.com/openMSX/openMSX/pull/2191)
- **P27:** a mid-line R#23 split test from openMSX issue #1984 / PR #2202. [PR #2202](https://github.com/openMSX/openMSX/pull/2202)

---

## Part 2: games with a plain and an enhanced version

| Game | Plain version | Enhanced version(s) | What differs | Avail. | Source |
|---|---|---|---|---|---|
| **Neon Revenant** | MSX1 edition: 512 KiB ASCII8, PSG, 32K RAM / 16K VRAM | MSX2 edition (512 KiB ASCII8, PSG). Turbo R edition (512 KiB, MSX-MUSIC + PSG). V9990 edition (1 MiB, turbo R + GFX9000). V9968 "HC" edition (2 MiB). | Same pseudo-3D rail shooter with chipset-specific backgrounds. **Best free MSX1-vs-MSX2 pair**: identical mapper, so differences isolate the VDP. Final release 20 Sep 2026; licence "unspecified", ROMs freely downloadable from GitHub releases. | FREE | [GitHub](https://github.com/kanon-ai/NEON_REVENANT), [Indie Retro News](https://www.indieretronews.com/2026/09/neon-revenant-in-dev-native-msx-pseudo.html) |
| **Monster Hunter** (have) | 128 KB with a plain Konami mapper: PSG | Same ROM with **KonamiSCC mapper**: SCC music | SCC only appears when the mapper is set to KonamiSCC, so it tests mapper selection and the SCC path with one file. The mapper guess currently says Konami (no SCC). | FREE (MSXdev'06 winner) | [msx.org](https://www.msx.org/news/software/en/msxdev06-10-monster-hunter), [msxdev'06](https://www.msxdev.org/msxdev-archive/msxdev06/) |
| **Chikubi Ninja** (already tested) | MSX2: smooth scroll via **set-adjust (R#18)** | MSX2+ / turbo R: **hardware scroll (R#26/27)** | Run the existing test ROM explicitly as MSX2 to pin the R#18 path. | FREE | [msx.org](https://www.msx.org/news/challenges/en/MSXdev25-21-ChikubiNinja) |
| **Uridium** (MSXdev14) vs **Uridium 2** (both already tested) | MSX1 version | MSX2 "demake" with multidirectional 256-colour scroll, SCC | Already covered. Mentioned as the existing reference pair. | FREE | (existing set) |
| **Maiden's Extreme Fist** (have) | MSXdev24 ROM, SCC | Cartridge/SD edition with **SCC and Yamanooto stereo** soundtracks, save/load and bug fixes | Sound-device variants. Only the MSXdev ROM is free. | FREE / COMM | [generation-msx](https://www.generation-msx.nl/software/retromixis-games/maidens-extreme-fist-bun-ga-rua/release/8564) |
| **Westen House** vs **Westen House EX** (base already tested) | 48 KB MSX1, PSG | 128 KB MSX1, new PSG score, 50% larger map, in-game save | Same engine, larger ROM and mapper use. Low hardware value, but a cheap mapper-size test. | FREE (open source) | [GitHub westen-ex](https://github.com/santiontanon/westen-ex) |
| **Bombaman** | MSX-MUSIC | MSX-AUDIO or MoonSound | Selectable sound device. Only useful once FM is emulated. | FREE | [teambomba.net](https://www.teambomba.net/bombaman.html) |
| **The Maze of Galious** | 128 KB MSX1, PSG (Konami) | **MSX2 patch**: 512 KB, SCREEN 5 graphics, SCC music, dual PSG, voices, turbo CPU/VDP options, Joymega | Whole MSX1-to-MSX2 conversion. Same game across MSX1 tiles and V9938 bitmap, PSG and SCC. | FREE-PATCH (IPS on GitHub) | [msx.org](https://www.msx.org/news/remakes/en/maze-of-galious-msx2) |
| **Vampire Killer** | MSX2, PSG (Konami mapper) | **SCC patch** (Jan van Valburg, 2018), with FRS TurboFix included | Same ROM, PSG vs re-arranged SCC music. Needs SCC-mapper handling. | FREE-PATCH | [msx.org](https://www.msx.org/news/translations/en/vampire-killer-scc), [download](https://www.msx.org/downloads/vampire-killer-patch-to-scc) |
| **Salamander** | MSX1 SCC original | **Enhanced patch** (Victor Martínez and others, 2016): smooth scroll on MSX2/2+, "Cool Colors" and per-stage MSX2 palettes, a voice set via a **second SCC** | MSX1 char scroll vs MSX2 smooth scroll and palette. Two SCCs at once. | FREE-PATCH | [msx.org](https://www.msx.org/news/software/en/konamis-salamander-pimped-up), [GitHub bladeba](https://github.com/bladeba/MSX/tree/master/Enhanced%20Games) |
| **Nemesis 3** | MSX1 SCC original | **Enhanced patch** (2018): smooth scroll (MSX2+, turbo R recommended), new graphics, voice set via second SCC | As Salamander. | FREE-PATCH | [msx.org](https://www.msx.org/news/remakes/en/nemesis-3) |
| **Nemesis (Gradius) / Galious / USAS / Zanac-EX / Valis 2** | Originals | "Enhanced" patches in Victor Martínez's repo (Nemesis ENHANCED has SCC with a PSG fallback when P is held at boot) | Smooth scroll and colour upgrades. Users report mapper-RAM dependencies. | FREE-PATCH | [GitHub bladeba](https://github.com/bladeba/MSX/tree/master/Enhanced%20Games), [msx.org](https://www.msx.org/forum/msx-talk/software/nemesis-gradius-enhanced-ips-patch?page=4) |
| **Gradius 2 / Nemesis 2** | MSX1 SCC original | **sd_snatcher's patch** (2009): DynamicVsync on MSX1/2. On MSX2+/turbo R, **smooth scroll using high-speed VRAM transfer via the WTE bit of R#25** | Same ROM behaves differently per VDP. Also exercises R#25 (V9958 only). | FREE-PATCH | [msx.org](https://www.msx.org/news/software/en/gradius-2-enhancement-patch) |
| **FRS patch set** (Space Manbow, Metal Gear 1/2, Quarth, King's Valley II, Maze of Galious, Vampire Killer, Salamander, Laydock 2, Valis II and more) | Originals | TurboFix, DynamicVsync, "CoolColors" MSX2 palette for MSX1 games, V9958 register fix (Space Manbow), full turbo R support (Valis II), enhanced sprite multiplexing (King's Valley II, Metal Gear 1) | Many are "same game, MSX1 palette vs MSX2 palette" or "Z80 vs turbo" pairs. | FREE-PATCH | [FRS patches](https://frs.badcoffee.info/patches.html) |
| **Knightmare, Nemesis, Antarctic Adventure, Hyper Rally, Twinbee, Yie Ar Kung-Fu, Road Fighter, etc.** | Original Konami PSG ROMs | Community **SCC hacks** | PSG vs SCC on the same ROM. | FREE-PATCH / GREY | [msxblue SCC list](http://www.msxblue.com/manual/scc_c.htm) |
| **King's Valley II** | MSX1 version (SCC) | MSX2 version (SCC) | Konami's own MSX1 and MSX2 builds of the same game, with MSX2 graphics. | COMM | [msxblue SCC list](http://www.msxblue.com/manual/scc_c.htm) |
| **Zanac → Zanac-EX** | MSX1, 1986 | MSX2, 1986/87 | Improved graphics **with smooth scrolling** and extended music. | COMM | [Wikipedia](https://en.wikipedia.org/wiki/Zanac) |
| **Golvellius → Shin Maou Golvellius** | MSX1, 1987 | MSX2, 1988 (different layouts, Master System-style graphics). On MSX2+, a SCREEN 12 intro. | MSX1 vs MSX2 vs 2+ presentation. | COMM | [Wikipedia](https://en.wikipedia.org/wiki/Golvellius), [msx.org](https://www.msx.org/forum/msx-talk/software/msx-2-2-plus-turbo-r-compatible-games-particularities) |
| **Space Manbow** | MSX2 (R#18 scroll, border chopping) | MSX2+ (R#27 scroll, clean border) | Same disk/ROM, different VDP path. | COMM | [grauw](https://map.grauw.nl/articles/scrolling.php) |
| **Aleste 2** | PSG with R#8 samples | MSX-MUSIC | Sound-device variant. | COMM | [generation-msx](https://www.generation-msx.nl/software/compile/aleste-2/1246/) |
| **Fray in Magical Adventure** | MSX2 | turbo R: PCM voice samples (ADPCM decoded by the R800), extra opening/ending graphics, faster play | MSX2 vs turbo R. | COMM | [TCRF](https://tcrf.net/Fray:_In_Magical_Adventure_(MSX2)), [msx.org](https://www.msx.org/forum/msx-talk/graphics-and-music/fray-msx2-vs-turbor) |
| **Gekisou Nyancle Racing / Quinpl** | MSX2 | MSX2+: a SCREEN 12 title image | Small YJK-only branch. Good for testing V9958 detection. | COMM | [msx.org](https://www.msx.org/forum/msx-talk/software/msx-2-2-plus-turbo-r-compatible-games-particularities) |
| **Megadoom** | MSX2 (reduced) | MSX2+ (SCREEN 12 plus scroll) | V9958 detection and fallback. | see 1B | [MRC](https://www.msx.org/downloads/games/shooters/megadoom) |

---

## Recommended starter set (all freely available)

This set is picked for AmiMSX's current scope (MSX1/MSX2, PSG + SCC/SCC+, six ROM mapper types, disk). Items 1-4 are demos, 5-12 are games, and 13-14 are stretch items.

| # | Title | Why it's in | What to look for |
|---|---|---|---|
| 1 | **io** (Logon System, MSX1 disk) | The only free title with a **self-reported pass/fail** for 5S timing. It also checks line length (228 cycles per line, 313 lines in PAL). | The start-up message should read "sync by 5S accurate". Check the screen-1 per-line charset/colour-table switching for tearing. Run at Real speed (Turbo breaks it on real hardware too) and in PAL. |
| 2 | **MSX Unleashed** (Dvik & Joyrex, MSX1) | Border scroller, raster bars and 105-colour images: the hardest documented MSX1 raster tricks. | Bars and border scroller should be stable lines (no jitter, no vertical drift). Compare against a real-hardware YouTube capture. Expect some parts to be imperfect even in openMSX. |
| 3 | **Bold** (Dvik & Joyrex, MSX1) | Heavy pattern/colour-table streaming with sprite overlays. Single 64 KB file. | Sprite overlays line up with the character-mode effects (no 1-line offsets). Frame pacing stays smooth. Good as a performance benchmark too (fps on 030 vs 060). |
| 4 | **Invasion of the Big Pixels** (Noice, MSX1) | Pure TMS9918 plasma/dither throughput, 16K VRAM. | No missing rows or columns in the plasma. Colours correct in the MSX1 palette. |
| 5 | **Tales of Popolon** (MSXdev'17, 32 KB ROM) | CPU-bound raycaster that streams the name table every frame. An ideal **optimisation regression** title, and open source. | Wall columns have no garbage. Measure fps before and after Z80-core changes. |
| 6 | **Lotus F3** (MSXdev'07, 128 KB KonamiSCC) **(have)** | MSX1 smooth scrolling by pattern tricks, plus SCC music. | The scroll has no mid-screen tearing. The SCC uses all 5 channels; AmiMSX drops channel 5, so note which instruments vanish. |
| 7 | **Monster Hunter** (MSXdev'06, 128 KB) **(have)** | Same ROM, PSG on the Konami mapper, SCC on the KonamiSCC mapper. | Run it twice. With KonamiSCC you should hear SCC music; with plain Konami it should be PSG-only and otherwise identical. Note the current mapper guess (Konami) misses the SCC. |
| 8 | **Neon Revenant** (MSX1 + MSX2 editions, 512 KiB ASCII8) | The one free game with **identical mapper and logic across MSX1 and MSX2 builds**. | Run both editions. Gameplay timing should match; only backgrounds and colours differ. Any desync points at VDP or machine-type handling rather than the mapper. |
| 9 | **Maiden's Extreme Fist BUN-GA-RUA** (MSXdev24, 512 KB KonamiSCC) **(have)** | Modern MSX2 action game with SCC. Exercises the V9938 and SCC together. | Sprite priority and colour in fights, SCC music, no slowdown with many sprites. |
| 10 | **Angelic Warrior DEVA** (freeware 2025, 2 MB with SRAM) **(have)** | SCREEN 4 **multidirectional parallax** and sprite masking (border masking, player behind pillars). | Confirm the mapper and SRAM first (the file tag says KonamiSCC; unverified). Check the parallax layers for 1-pixel jitter and the sprite masks at the screen edges. Music needs FM, so check whether it plays silently or hangs. |
| 11 | **DELTA** (MSXdev25, 4 MB ASCII16 + SCC in a second slot) | The largest ASCII16 ROM in the set, **page flipping**, a 3D engine, and **SCC as a separate cartridge** (not in the game's mapper). | Run in NTSC. Page flips should be clean (no half-drawn frames). The menu SCC music needs an SCC configured in another slot; check AmiMSX can do "ASCII16 game + standalone SCC". |
| 12 | **Akin** (Parallax 1995, freeware, 2 × DSK) | Scrolling done with the **VDP command engine** (block copies), from a disk game. | Scroll speed and correctness of HMMM/LMMM blits. Disk loading between levels. Check whether it asks for MSX-MUSIC. |
| 13 | **Neon Horizon** (MSXdev25) **(have)**, stretch | About 20 line interrupts per frame plus page swapping plus 3-layer parallax copies: the heaviest line-IRQ load found. | First check it boots without OPL4 (unverified). Then check the parallax bands are stable and the road animates (palette and page swapping are correct). |
| 14 | **Batman - Free Edition** (FX Software, MSX2) **(have)**, optional | V9938 isometric engine with many VRAM copies. A quieter "does a normal MSX2 game still work" control. | Room redraw correctness and speed. |

Not in the starter set, and why:

- **Unknown Reality, Woei, Bombaman, Sonyc:** they need FM or MoonSound, or a V9958.
- **Syntax Infinity and Baltak Rampage:** add them once the PAL timing work is done. They are excellent PAL-timing tests.
- **Free patches (Galious MSX2, Salamander, Nemesis 3, Gradius 2):** they need commercial base ROMs you must own. They are the best Part 2 additions if those dumps are available.

---

## Sources

- msx.org: Testing methods (list of hard-to-emulate software): https://www.msx.org/articles/testing-methods
- msx.org: Good demos for testing the TN-VDP: https://www.msx.org/forum/msx-talk/general-discussion/good-demos-for-testing-the-tn-vdp
- Grauw: A guide to scrolling game engines on MSX: https://map.grauw.nl/articles/scrolling.php
- Grauw: Screensplit programming guide: https://map.grauw.nl/articles/split_guide.php
- Grauw: Playing samples on the PSG: https://map.grauw.nl/articles/psg_sample.php
- msx.org: spacemanbow & scrolling: https://www.msx.org/forum/development/msx-development/spacemanbow-scrolling
- msx.org: More than 32 sprites on 9918/9938: https://www.msx.org/forum/msx-talk/development/more-than-32-sprites-on-99189938
- msx.org: Sprite split: https://www.msx.org/forum/msx-talk/development/sprite-split-0?page=2
- msx.org: MSX1 games with smooth scroll: https://www.msx.org/forum/development/msx-development/msx1-games-smooth-scroll
- msx.org: Best demos: https://www.msx.org/forum/msx-talk/software/best-demos
- openMSX PR #2211 (5S/collision flag timing, io demo): https://github.com/openMSX/openMSX/pull/2211
- openMSX PR #2202 (mid-line R#23, P27 test): https://github.com/openMSX/openMSX/pull/2202
- openMSX PR #2191 (line IRQ latch, Sex Bomb Bunny, T471.COM): https://github.com/openMSX/openMSX/pull/2191
- openMSX issue #1015 (Baltak Rampage): https://github.com/openMSX/openMSX/issues/1015
- MiSTer MSX issue #26 (Syntax Infinity): https://github.com/MiSTer-devel/MSX_MiSTer/issues/26
- pouet: io https://www.pouet.net/prod.php?which=65232 · Bold https://www.pouet.net/prod.php?which=54051 · MSX Unleashed https://www.pouet.net/prod.php?which=30853 · Invasion of the Big Pixels https://www.pouet.net/prod.php?which=52340 · Riyadh https://www.pouet.net/prod.php?which=7662 · Avaakkus https://www.pouet.net/prod.php?which=9897 · Unknown Reality https://www.pouet.net/prod.php?which=30145 · Syntax Infinity https://www.pouet.net/prod.php?which=52983 · Baltak Rampage https://www.pouet.net/prod.php?which=67102 · MSX top list https://www.pouet.net/toplist.php?type=demo&platform=107
- msx.org: TNI Bounce: https://www.msx.org/news/mrc/en/mrc-bounce-challenge-14th-entry-tni
- msx.org: Maggoo's MSX page: https://www.msx.org/news/websites/en/maggoos-msx-page
- Team Bomba: https://www.teambomba.net/ · https://www.teambomba.net/bombaman.html · https://www.teambomba.net/woei.html
- MSXdev'17 Tales of Popolon: https://www.msxdev.org/2017/03/22/msxdev17-4th-entry-tales-of-popolon/
- Santi Ontañón blog (XRacing scroll, MSX games): http://santiontanon.blogspot.com/2019/04/smooth-scroll-in-xracing.html
- Lotus F3: https://www.msx.org/news/software/en/msxdev07-lotus-f3 · https://www.generation-msx.nl/software/dvik-joyrex-productions/lotus-f3/release/3749/
- MSXdev24 results: https://www.msx.org/news/challenges/en/msxdev24-results
- Maiden's Extreme Fist: https://www.generation-msx.nl/software/retromixis-games/maidens-extreme-fist-bun-ga-rua/8564/ · https://www.msxdev.org/2024/10/25/msxdev24-13-maidens-extreme-fist-bun-ga-rua/
- MSXdev25 Neon Horizon: https://www.msx.org/news/challenges/en/msxdev25-40-neon-horizon
- DELTA: https://jacco.ompf2.com/delta-dodge-engage-launch-target-assault/ · https://www.msxdev.org/2026/02/21/msxdev25-30-delta/
- Chikubi Ninja: https://www.msx.org/news/challenges/en/MSXdev25-21-ChikubiNinja
- Neon Revenant: https://github.com/kanon-ai/NEON_REVENANT
- Angelic Warrior DEVA: https://www.msx.org/news/software/en/angelic-warrior-deva-becomes-freeware
- Parallax freeware / Akin: https://www.msx.org/news/en/parallax-games-freeware · https://www.msx.org/downloads/akin
- Sonyc: https://www.msx.org/news/software/en/sonyc-goes-freeware
- Megadoom: https://www.msx.org/downloads/games/shooters/megadoom
- Manbow 2: https://www.msx.org/articles/manbow-2 · https://www.msx.org/forum/msx-talk/software/space-manbow-2-where
- Batman (FX): https://www.msx.org/news/remakes/en/batman-msx2-remake-announced
- Monster Hunter: https://www.msx.org/news/software/en/msxdev06-10-monster-hunter
- Westen House EX: https://github.com/santiontanon/westen-ex
- Ultimate MSX FAQ, MSX2+: https://www.faq.msxnet.org/msx2p.html · SCC: https://www.faq.msxnet.org/scc.html
- msx.org: MSX2 / 2+ / turbo R particularities: https://www.msx.org/forum/msx-talk/software/msx-2-2-plus-turbo-r-compatible-games-particularities
- msxblue SCC games: http://www.msxblue.com/manual/scc_c.htm · MSX-AUDIO games: http://www.msxblue.com/manual/msxaudio_c.htm
- FRS patches: https://frs.badcoffee.info/patches.html
- Maze of Galious MSX2: https://www.msx.org/news/remakes/en/maze-of-galious-msx2
- Vampire Killer SCC: https://www.msx.org/news/translations/en/vampire-killer-scc
- Salamander enhanced: https://www.msx.org/news/software/en/konamis-salamander-pimped-up
- Nemesis 3 enhanced: https://www.msx.org/news/remakes/en/nemesis-3
- Gradius 2 enhancement: https://www.msx.org/news/software/en/gradius-2-enhancement-patch
- Enhanced games repo: https://github.com/bladeba/MSX/tree/master/Enhanced%20Games
- Wikipedia: Space Manbow https://en.wikipedia.org/wiki/Space_Manbow · Zanac https://en.wikipedia.org/wiki/Zanac · Golvellius https://en.wikipedia.org/wiki/Golvellius · Aleste https://en.wikipedia.org/wiki/Aleste
- Fray: https://tcrf.net/Fray:_In_Magical_Adventure_(MSX2)
- Psycho World: https://vgmrips.net/packs/pack/psycho-world-msx2-fm
- Aleste 2: https://www.generation-msx.nl/software/compile/aleste-2/1246/
- VATT: https://www.msx.org/forum/msx-talk/development/vatt-vram-access-timing-tester?page=3
- Sex Bomb Bunny demo: https://www.file-hunter.com/Homebrew/?id=sexbombbunny
- Super Mario World MSX: https://gonintendo.com/stories/368845-fan-takes-6-years-to-port-super-mario-world-to-the-msx
