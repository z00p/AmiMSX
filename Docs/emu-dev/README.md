# Writing emulators for the Amiga: notes from the PiStorm A1200

Practical notes from two emulator projects for AGA Amigas:

- **AmiMSX 4.x**: an MSX/MSX2/MSX2+ emulator in 68k assembly. It is a community update of Juan Antonio Gómez Gálvez's AmiMSX ([GitHub](https://github.com/z00p/AmiMSX), Aminet `misc/emu/AmiMSX4`).
- **Arnold for the Amiga**: an Amstrad CPC/CPC Plus emulator in C, ported from Kevin Thacker's Arnold ([GitHub](https://github.com/z00p/arnold-amiga), Aminet `misc/emu/Arnold-m68k`).

Both projects target a real A1200 with a PiStorm (Emu68), a 68030/50 A1200, and the BigMig/MiSTer Minimig core. They are developed with WinUAE and a reference emulator on a PC, and tested on the real machine. Much of the work was done by AI coding agents working alongside a human tester. These notes are for both kinds of reader: developers starting a similar project, and agents briefed to work on one.

Commit hashes and `Docs/agent_notes/` files referred to in the lessons belong to the development repositories; the public repositories carry squashed release commits, so look up the build switch or symbol name there.

Each lesson shows real code **before and after** a fix, the symptom it caused, and the evidence that the fix worked. See [STYLE.md](STYLE.md).

## Chapters

| # | Chapter | Main contributor |
|---|---|---|
| 01 | [Target hardware](chapters/01-target-hardware.md) | Arnold |
| 02 | [Display on AGA](chapters/02-display-on-aga.md) | AmiMSX (Arnold adds OS-screen topics) |
| 03 | [CPU cores in 68k](chapters/03-cpu-cores.md) | both |
| 04 | [Sound](chapters/04-sound.md) | Arnold |
| 05 | [Input](chapters/05-input.md) | AmiMSX |
| 06 | [Testing](chapters/06-testing.md) | both |
| 07 | [Toolchains and release](chapters/07-toolchains-release.md) | both |
| 08 | [Agent workflow](chapters/08-agent-workflow.md) | both |
| 09 | [Pitfalls checklist](chapters/09-pitfalls.md) | both |
| 10 | [Performance on Emu68](chapters/10-performance-emu68.md) | Arnold |

Sections marked *To be written* are placeholders for the other project's material.

## Licence

The text is CC BY 4.0. Code excerpts keep their source project's terms, which are given under each example. See [LICENSE.md](LICENSE.md).
