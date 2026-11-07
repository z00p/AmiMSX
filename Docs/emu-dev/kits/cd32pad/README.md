# CD32 pad kit

A small, self-contained routine that reads a CD32 pad (or a pad adapter in its CD32 mode) by driving the joystick port directly. It is for programs that take over the machine, and for programs that run with the operating system but need a read that works on fast CPUs. The lessons behind it are in [chapter 05](../../chapters/05-input.md).

| File | What it is |
|---|---|
| `cd32pad.s` | 68000 asm (Devpac / vasm `-devpac` syntax). Written for the AmiMSX 4.x update (4.1.1 and later); it is not part of Juan Antonio Gómez Gálvez's original AmiMSX, which has no CD32 read. It reads port 2, port 1 or both in one call and returns 7 buttons as 1 = pressed. A plain joystick reads as `$00`. |
| `cd32pad.c`, `cd32pad.h` | The same protocol in C (amiga-gcc), from Arnold for the Amiga. It reads one port per call and returns 7 buttons plus the 2 ID bits. `cd32pad_dirs()` gives the directions. |
| `cd32test.c` | A Shell tool that prints the raw bits and the directions as they change: `cd32test [port] [seconds]`, port 2 by default. |
| `build.sh` | Builds `cd32test` with amiga-gcc and assemble-checks `cd32pad.s` with vasm. |

## How they have been tested

- **The asm read:** in AmiMSX with a KTRL CD32 pad, and this file on its own, called from a Shell tool with the operating system running, on a PiStorm A1200 with the KTRL in port 2 (red, blue and play each seen on their own).
- **The C read:** on the same A1200 and KTRL pad with `cd32test`: the ID bit at rest and each button on its own. This is the version with the volatile fix below; the first published version did not work (see the next section).
- **These standalone copies:** they build and assemble cleanly with no warnings. Run `cd32test` with your own pads before you depend on the read. A held button that shows as every bit at once means the pad is not in CD32 mode, or the read never put it there.

## The compiler trap in the C read

The NDK's `struct Custom` is not declared `volatile`. Written as `custom.potgo = 0x6f00` and `custom.potinp`, gcc -O2 removes the write that pulls pin 5 low (a later POTGO write overwrites it, so the compiler treats the first as dead), and reads POTINP once for all nine bits. The pad never enters CD32 mode, and a held button reads as every bit at once. The first version of this kit had that bug. The fix is one line, with every chip register then reached through it:

    #define CUSTOM ((volatile struct Custom *)&custom)

If you adapt the C, check the compiled code (`m68k-amigaos-objdump -d`) for the POTGO write and for one POTINP read per bit.

## Using it

Call the read once a frame, for a port the user has set to "CD32 pad". Reading twice a frame also works. Take the directions from `JOY0DAT`/`JOY1DAT` as usual; they read the same in both modes.

If the operating system is running, call the read with interrupts off, as `cd32pad.c` does, or allocate the pot bits with `potgo.resource` first. Do not fall back to lowlevel.library's `ReadJoyPort()` on a fast CPU: on a PiStorm it saw the pad but only ever reported red.

## Licence

MIT, see [LICENSE](LICENSE). Unlike the excerpts in the chapters, which keep their projects' terms, this kit may be used in any program. A credit in your documentation would be nice.
