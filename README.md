# AmiMSX 4.1 (beta)

AmiMSX is an MSX, MSX2 and MSX2+ emulator for the Amiga, written in 68020 assembly by Juan Antonio Gómez Gálvez (GUS Entertainment / RED Soft). Version 4.0 is a community update, released with his permission. It is built from his v3.1 source, with parts of his v3.2/v3.5 source.

4.0 puts accuracy first. The low-spec target is a 68030/50 with fast RAM, and PiStorm (Emu68), BigMig and other fast machines get FM sound, 60 Hz and smooth display on top. See [Docs/CHANGES_4.0.md](Docs/CHANGES_4.0.md) for what changed since 3.1, and [Docs/AmiMSX4.readme](Docs/AmiMSX4.readme) for requirements and installation.

## Running it

The release archive (Aminet `misc/emu`) holds the AmiMSX drawer: the program, `AmiMSX2.data` (MSX system ROMs), `AmiMSX2.mapper`, `AmiMSX4.romdb`, the AmigaGuide and two preset icons. "AmiMSX 030" is for a 68030/50; "AmiMSX PiStorm" is for PiStorm, BigMig and other fast CPUs.

## Games it runs well

Tested on a PiStorm A1200 and in the regression suite: homebrew such as Manbow 2, Lilly's Saga, Chikubi Ninja, Delta, Neon Revenant, BUN-GA-RUA, Pampas & Selene, Uridium, Night Knight, Nogalious, Sword of IANNA and Gradius III Legends (MSX2+), and enhanced Konami classics (community patches; bring your own original) such as Space Manbow, Nemesis 3 Enhanced, Salamander Enhanced, Usas Enhanced and Zanac Ex Enhanced.

## Building

- **Assembler:** [vasm](http://sun.hasenbraten.de/vasm/) 2.0f or later, the 68k Motorola-syntax version. Put the Windows binary at `tools/vasmm68k_mot.exe`, or change `build.sh`.
- **Build:** `sh build.sh` assembles `AmiMSX_Main_v3.1.asm` (which includes the other sources) into `build/AmiMSX`.
- **Linux without a native vasm** (cloud sessions): `node tools/vasm_wasm.mjs -devpac -nocase -m68020 -Fhunkexe -nosym -maxerrors=0 -o build/AmiMSX AmiMSX_Main_v3.1.asm` runs the npm WebAssembly build of vasm (`romdev-toolchain-vasm`, unpacked in `tools/vasm-wasm/`); it matches the include names' case for Linux without touching the sources.
- **Release:** `python tools/make_release.py` stages the drawer, and `winuae/make_lha.ps1` packs it with the Amiga's `lha` in WinUAE.

## Testing

`tools/regress.py` runs the regression suite in WinUAE (captures compared pixel by pixel with baselines), and `tools/burst.py` compares consecutive frames with openMSX. See [Docs/regression.md](Docs/regression.md). Test ROMs are not included.

## Credits

- **AmiMSX:** Juan Antonio Gómez Gálvez (GUS Entertainment / RED Soft).
- **Icons and graphics:** Multivac.
- **Thanks:** Zener and Sandman.
- **FM instrument data** (`Sound/fmx.dat`): built-in instrument data from emu2413 by Mitsutaka Okazaki (MIT licence).
- **Mapper database** (`AmiMSX4.romdb`): built from openMSX's software database.

## Reporting problems

4.0 is a beta: please report any game that misbehaves, so it can be triaged for the next update. Open an issue with the game, the AmiMSX settings and the machine (CPU, accelerator or emulator). See [CONTRIBUTING.md](CONTRIBUTING.md).
