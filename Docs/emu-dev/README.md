# Claude and the Art of Writing Emulators for the Amiga

*Notes from the PiStorm A1200*

Practical notes from three emulator projects for AGA Amigas:

- **AmiMSX 4.x**: an MSX/MSX2/MSX2+ emulator in 68k assembly. It is a community update of Juan Antonio Gómez Gálvez's AmiMSX ([GitHub](https://github.com/z00p/AmiMSX), Aminet `misc/emu/AmiMSX4`).
- **Arnold for the Amiga**: an Amstrad CPC/CPC Plus emulator in C, ported from Kevin Thacker's Arnold ([GitHub](https://github.com/z00p/arnold-amiga), Aminet `misc/emu/Arnold-m68k`).
- **AmiPCEngine**: a PC Engine / TurboGrafx-16 emulator in 68k assembly, by Juan Antonio Gómez Gálvez and z00p ([GitHub](https://github.com/z00p/AmiPCEngine), Aminet `misc/emu/AmiPCEngine`).

All three projects target a real A1200 with a PiStorm (Emu68), a 68030/50 A1200, and the BigMig/MiSTer Minimig core. They are developed with WinUAE and a reference emulator on a PC, and tested on the real machine. Much of the work was done by AI coding agents working alongside a human tester. These notes are for both kinds of reader: developers starting a similar project, and agents briefed to work on one.

Commit hashes and `Docs/agent_notes/` files (`docs/agent_notes/` in AmiPCEngine) referred to in the lessons belong to the development repositories; the public repositories carry squashed release commits, so look up the build switch or symbol name there.

Each lesson shows real code **before and after** a fix, the symptom it caused, and the evidence that the fix worked. See [STYLE.md](STYLE.md).

## Key lessons

1. **Profile on the target, per frame, not in WinUAE.** Emu68's JIT and the chip bus behind it do not follow WinUAE's timing model. Instruction counts mislead on Emu68: an 8-byte shift in code layout moved one core by about 0.9 ms (7%) through translation-cache set collisions. Timestamp each phase of the frame with a hardware timer (CIA-B TOD or the beam position). Log the timestamps per frame to a file, or draw them as hex rows on the screen for a photo. Compare medians and high percentiles, not single runs. See [Two loops](chapters/06-testing.md#two-loops-the-pc-loop-and-the-hardware-loop), [Debug rows on the screen](chapters/06-testing.md#debug-rows-on-the-screen-measuring-from-a-photo), [Measuring per frame on real hardware](chapters/10-performance-emu68.md#measuring-per-frame-on-real-hardware) and [JIT branch prediction and code layout](chapters/10-performance-emu68.md#jit-branch-prediction-and-code-layout).
2. **Input latency is set by the order of the frame loop.** Measure from the pad sample to the first displayed line that reflects it, and log where each frame waits before changing anything. Then apply the fixes in order of cost:
   - Start the emulated frame at the guest's vertical blank, where games poll input, not at its line 0. This is free.
   - Show the frame as soon as it is emulated.
   - Where the frame has slack, delay the start or the input read by the measured worst-case emulation time plus a margin. This is valid only when the display time is fixed (AGA live drawing, or RTG locked to the blank).

   All three projects found their lag in different places. See [Controller lag (AmiMSX)](chapters/05-input.md#controller-lag-measure-the-frame-then-reorder-it-amimsx), [Cutting input lag (AmiPCEngine)](chapters/05-input.md#cutting-input-lag-amipcengine) and [Controller lag (Arnold)](chapters/05-input.md#controller-lag-the-frame-boundary-and-a-late-start-arnold).
3. **Accept a change only on the real display chain and controller.** A timing log measures the emulator, not the picture. With the double buffer off, AmiMSX's log showed 6 late frames in 728, yet the scrolling visibly juddered through the scaler. Scripted input bypasses the port hardware: a swapped CD32 bit order and a stuck direction showed up only with a real pad. Sign off with an A/B on the real machine, the real scaler and display, and a real controller. See [A faster path is not a better one until someone has looked at it](chapters/05-input.md#a-faster-path-is-not-a-better-one-until-someone-has-looked-at-it) and [What works and what doesn't](chapters/06-testing.md#what-works-and-what-doesnt).

## Chapters

| # | Chapter | Main contributor |
|---|---|---|
| 01 | [Target hardware](chapters/01-target-hardware.md) | Arnold |
| 02 | [Display on AGA](chapters/02-display-on-aga.md) | AmiMSX (Arnold adds OS-screen topics, AmiPCEngine colour 0, sprite priority and redraw flags) |
| 03 | [CPU cores in 68k](chapters/03-cpu-cores.md) | all three |
| 04 | [Sound](chapters/04-sound.md) | Arnold, AmiPCEngine |
| 05 | [Input](chapters/05-input.md) | AmiMSX (all three add controller lag; Arnold adds a CD32 read in C) |
| 06 | [Testing](chapters/06-testing.md) | all three |
| 07 | [Toolchains and release](chapters/07-toolchains-release.md) | AmiMSX, Arnold (AmiPCEngine adds one vasm lesson) |
| 08 | [Agent workflow](chapters/08-agent-workflow.md) | both |
| 09 | [Pitfalls checklist](chapters/09-pitfalls.md) | all three |
| 10 | [Performance on Emu68](chapters/10-performance-emu68.md) | Arnold, AmiPCEngine |
| 11 | [Testing on the real A1200: the machine and its tools](chapters/11-test-machine.md) | A1200 setup notes (3D game-port lessons are in the appendix) |
| 12 | [RTG output](chapters/12-rtg.md) | Arnold (rtgfw, MIT), AmiPCEngine |

## Code kits

Small routines taken out of the projects so they can be used on their own, under the MIT licence:

- [kits/cd32pad](kits/cd32pad/README.md): reads a CD32 pad by hand, timed with CIA reads so it works on any CPU. In 68k asm (from AmiMSX) and in C (from Arnold), with a Shell test tool.

## Licence

The text is CC BY 4.0. Code excerpts keep their source project's terms, which are given under each example. The code kits are MIT. See [LICENSE.md](LICENSE.md).
